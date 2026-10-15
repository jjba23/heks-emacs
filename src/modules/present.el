;;; present.el --- Presenting a buffer  -*- lexical-binding: t -*-

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; heks-emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; heks-emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with heks-emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A presentation is a document read one section at a time, and this
;; configuration already renders documents (`modules/render.el'), so what is
;; here is the reading of one: where its sections begin, and what to show
;; when they are shown one at a time.
;;
;; There are two ways to present, because there are two things a person
;; wants when they stand up in front of a room:
;;
;;   * in Emacs, `org-present' narrows the buffer to one heading at a time
;;     and scales the text up.  That is what `C-c r P' does to an Org note,
;;     and it is the honest answer for a note, because the text was written
;;     in Emacs and is being read in Emacs;
;;   * in the browser, a deck: one `<section>' per section, the arrow keys
;;     and the space bar to walk them, a number to know where one is, and a
;;     print stylesheet so that printing gives one slide per page.  Emacs
;;     cannot style a projected page -- the theme's faces are made for code
;;     and prose -- and a browser can, so this is what everything that is
;;     not Org gets.
;;
;; Both read the same document, and neither needs a tool from outside
;; Emacs: no reveal.js, no pandoc, no network.  A slide is a section of the
;; file that was already being written, which is the point -- a deck one has
;; to write twice is a deck one stops writing.
;;
;; How a document says where its slides begin:
;;
;;   * Markdown: a line of three or more dashes on its own
;;     (`---', which is a horizontal rule);
;;   * Org: its headings.  The level is the shallowest one that appears more
;;     than once -- a file with one `*' title and several `**' sections has
;;     its slides at `**' -- and whatever comes before the first of them is
;;     the title slide.
;;
;; A buffer that is neither Markdown nor Org is refused rather than turned
;; into a deck with one slide in it.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(declare-function heks-emacs-markdown-to-html "render")
(declare-function heks-emacs-render--org-body "render")
(declare-function heks-emacs-render-markdown-p "render")
(declare-function heks-emacs-render-palette "render")
(declare-function heks-emacs-render-highlight-css "render")
(declare-function heks-emacs-render-title "render")
(declare-function heks-emacs-render--escape "render")

(defgroup heks-emacs-present nil
  "Showing a document one section at a time."
  :group 'tools)

;;
;; ====== Where a document's slides begin ======
;;

(defconst heks-emacs-present--markdown-boundary
  "^\\([-*_]\\)\\1\\{2,\\}[ \t]*$"
  "The line that separates two slides of a Markdown deck.

A thematic break, which is what `---' on its own line already means, so
that a deck is a document that also reads as one.")

(defun heks-emacs-present--org-level (text)
  "Return the heading level a deck of the Org TEXT is written in.

The shallowest level that occurs more than once: a file that has one `*'
title and several `**' sections means the sections to be its slides, and a
file of flat `*' headings means those.  nil when TEXT has no heading."
  (let ((counts (make-hash-table)))
    (dolist (line (split-string text "\n"))
      (when (string-match "\\`\\(\\*+\\)[ \t]+" line)
        (let ((level (length (match-string 1 line))))
          (puthash level (1+ (gethash level counts 0)) counts))))
    (let ((levels (sort (hash-table-keys counts) #'<)))
      (or (seq-find (lambda (candidate) (> (gethash candidate counts) 1)) levels)
          (car levels)))))

(defun heks-emacs-present--org-boundary (text)
  "Return the regular expression that starts a slide of the Org TEXT.

A heading exactly as many stars deep as the deck's level, and not the
first stars of a deeper one: `** x' is a slide where `*** x' is not."
  (format "^\\*\\{%d\\}\\(?:[ \t]\\|$\\)" (or (heks-emacs-present--org-level text) 1)))

(defun heks-emacs-present--split (text pattern)
  "Return TEXT cut before each match of PATTERN, empty pieces left out."
  (let ((position 0)
        (at 0)
        (pieces nil))
    (while (string-match pattern text position)
      (when (> (match-beginning 0) at)
        (push (substring text at (match-beginning 0)) pieces))
      (setq at (match-beginning 0)
            position (match-end 0)))
    (push (substring text at) pieces)
    (delq nil (mapcar (lambda (piece)
                        (let ((trimmed (string-trim piece)))
                          (unless (string-empty-p trimmed) trimmed)))
                      (nreverse pieces)))))

(defun heks-emacs-present-format (&optional buffer)
  "Return the format of BUFFER, which is `markdown', `org' or nil.

nil is the answer for a buffer that has no way to say where a slide ends,
and it is an answer rather than a guess: a deck of one slide is not a
presentation."
  (with-current-buffer (or buffer (current-buffer))
    (cond ((heks-emacs-render-markdown-p) 'markdown)
          ((eq major-mode 'org-mode) 'org)
          (t nil))))

(defun heks-emacs-present-slides (&optional buffer)
  "Return BUFFER's slides, as the pieces of its own text.
Each piece is still written in the buffer's format: it is rendered on its
own, so that a slide is a well-formed fragment rather than a slice of one."
  (with-current-buffer (or buffer (current-buffer))
    (pcase (heks-emacs-present-format)
      ('markdown (heks-emacs-present--split (buffer-string)
                                            heks-emacs-present--markdown-boundary))
      ('org (heks-emacs-present--split (buffer-string)
                                       (heks-emacs-present--org-boundary (buffer-string))))
      (_ nil))))

(defun heks-emacs-present-slide-html (slide format)
  "Return SLIDE, written in FORMAT, as the HTML of one slide.

An Org slide is exported on its own, so what the file's own `#+' lines set
up applies to the file's preview rather than to every slide of it; a
Markdown slide is rendered by the renderer the preview uses, images and
links included, because that renderer works on a string."
  (pcase format
    ('markdown (heks-emacs-markdown-to-html slide))
    ('org (with-temp-buffer
            (insert slide)
            (org-mode)
            (or (heks-emacs-render--org-body (current-buffer))
                (format "<pre class=\"plain\">%s</pre>"
                        (heks-emacs-render--escape slide)))))))

;;
;; ====== The deck ======
;;

(defconst heks-emacs-present-deck-script
  "(function () {
  var slides = Array.prototype.slice.call(document.querySelectorAll('.slide'));
  var counter = document.getElementById('counter');
  if (!slides.length) { return; }
  var at = Math.min(slides.length, Math.max(1, parseInt(location.hash.replace('#/', ''), 10) || 1)) - 1;

  function show(number) {
    at = Math.min(slides.length - 1, Math.max(0, number));
    slides[at].scrollIntoView({block: 'start', behavior: 'auto'});
    counter.textContent = (at + 1) + ' / ' + slides.length;
    history.replaceState(null, '', '#/' + (at + 1));
  }

  function key(event) {
    var target = event.target;
    if (target.closest && target.closest('input, textarea, [contenteditable]')) { return; }
    switch (event.key) {
      case 'ArrowRight': case 'ArrowDown': case 'PageDown':
      case ' ': case 'Enter':
        event.preventDefault(); show(at + 1); break;
      case 'ArrowLeft': case 'ArrowUp': case 'PageUp': case 'Backspace':
        event.preventDefault(); show(at - 1); break;
      case 'Home': event.preventDefault(); show(0); break;
      case 'End': event.preventDefault(); show(slides.length - 1); break;
    }
  }

  document.addEventListener('keydown', key);
  document.getElementById('next').addEventListener('click', function () { show(at + 1); });
  document.getElementById('prev').addEventListener('click', function () { show(at - 1); });
  show(at);
})();"
  "The navigation a deck carries, in the deck's own file.

It is the whole of the JavaScript here: no framework, no network, and
nothing that a reader who would rather scroll cannot ignore.")

(defun heks-emacs-present-deck-stylesheet ()
  "Return the stylesheet a deck carries.

It is built from the colours of the current theme, like the stylesheet of
a rendered document -- the two are meant to look like each other -- and it
carries the code colouring of whatever the slides fontified."
  (let ((palette (heks-emacs-render-palette)))
    (concat
     (format "
:root { color-scheme: light dark; }
html, body { margin: 0; padding: 0; }
body { background: %s; color: %s; line-height: 1.5;
       font-family: system-ui, sans-serif; }
.slide { box-sizing: border-box; min-height: 100vh; display: flex;
         flex-direction: column; justify-content: center;
         padding: 3rem clamp(1.2rem, 6vw, 7rem);
         font-size: clamp(1.05rem, 0.85rem + 0.8vw, 1.75rem); }
.slide + .slide { border-top: 1px solid %s; }
.slide > :first-child { margin-top: 0; }
.slide > :last-child { margin-bottom: 0; }
.slide h1 { font-size: clamp(1.9rem, 1.2rem + 2.6vw, 3.6rem); margin: 0 0 0.5em;
            line-height: 1.15; }
.slide h2 { font-size: clamp(1.5rem, 1rem + 1.8vw, 2.6rem); margin: 0 0 0.5em; }
.slide h3 { font-size: clamp(1.25rem, 0.9rem + 1.2vw, 1.9rem); margin: 0 0 0.5em; }
.slide p, .slide ul, .slide ol, .slide blockquote, .slide table, .slide pre
  { margin: 0.5em 0; }
.slide ul, .slide ol { padding-left: 1.4em; }
.slide li { margin: 0.15em 0; }
.slide img { max-width: 100%%; max-height: 70vh; }
.slide code, .slide pre { font-family: ui-monospace, monospace; font-size: 0.85em; }
.slide code { background: %s; padding: 0.1em 0.35em; border-radius: 4px; }
.slide pre.code { background: %s; border: 1px solid %s; border-radius: 6px;
                  padding: 0.7em 0.9em; overflow-x: auto; }
.slide pre.code code { background: none; padding: 0; }
.slide table { border-collapse: collapse; }
.slide th, .slide td { border: 1px solid %s; padding: 0.3em 0.6em; text-align: left; }
.slide th { background: %s; }
.slide blockquote { border-left: 4px solid %s; padding-left: 1em; color: %s; }
.slide a { color: %s; }
.controls { position: fixed; left: 50%%; bottom: 0.9rem; transform: translateX(-50%%);
            display: flex; align-items: center; gap: 0.6rem;
            padding: 0.25rem 0.6rem; border-radius: 999px;
            background: %s; border: 1px solid %s; font-size: 0.85rem;
            opacity: 0.25; transition: opacity 0.2s; }
.controls:hover, .controls:focus-within { opacity: 1; }
.controls button { font: inherit; color: %s; background: none; border: none;
                   cursor: pointer; line-height: 1; }
.controls button:focus-visible { outline: 2px solid %s; outline-offset: 2px; }
.counter { color: %s; font-variant-numeric: tabular-nums; }

@media print {
  /* One slide per page, and the controls are a thing of the screen. */
  @page { size: 13.333in 7.5in; margin: 0.4in; }
  .slide { min-height: 0; border-top: none;
           break-after: page; page-break-after: always; }
  .slide:last-child { break-after: auto; page-break-after: auto; }
  .slide pre.code { overflow: visible; white-space: pre-wrap; }
  .controls { display: none; }
}
"
             ;; the page
             (plist-get palette :background) (plist-get palette :foreground)
             ;; the line between two slides
             (plist-get palette :border)
             ;; inline code and a fenced block
             (plist-get palette :surface) (plist-get palette :surface)
             (plist-get palette :border)
             ;; tables
             (plist-get palette :border) (plist-get palette :surface)
             ;; a quote
             (plist-get palette :border) (plist-get palette :muted)
             ;; links
             (plist-get palette :accent)
             ;; the controls
             (plist-get palette :surface) (plist-get palette :border)
             (plist-get palette :foreground) (plist-get palette :accent)
             (plist-get palette :muted))
     ;; The colours of the code, one rule per face the slides used.
     (heks-emacs-render-highlight-css))))

(defun heks-emacs-present-deck-document (title slides)
  "Return a whole deck as one HTML document.

TITLE is what the tab says and SLIDES is a list of fragments of HTML, one
per slide.  Every slide is a `section', which is what it is, and the
navigation is a pair of buttons plus the arrow keys, so that a deck can be
walked with a keyboard, with a clicker that sends arrow keys, or with a
finger."
  (format "<!DOCTYPE html>
<html lang=\"en\">
<head>
<meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<title>%s</title>
<style>%s</style>
</head>
<body>
<main class=\"deck\">
%s
</main>
<nav class=\"controls\" aria-label=\"Slides\">
<button id=\"prev\" type=\"button\" aria-label=\"Previous slide\">&#8249;</button>
<span class=\"counter\" id=\"counter\" role=\"status\" aria-live=\"polite\">1 / %d</span>
<button id=\"next\" type=\"button\" aria-label=\"Next slide\">&#8250;</button>
</nav>
<script>%s</script>
</body>
</html>
"
          (heks-emacs-render--escape title)
          (heks-emacs-present-deck-stylesheet)
          (mapconcat #'identity
                     (cl-loop for slide in slides
                              for number from 1
                              collect (format (concat "<section class=\"slide\" id=\"slide-%d\""
                                                      " aria-label=\"Slide %d\">\n%s\n</section>")
                                              number number slide))
                     "\n")
          (length slides)
          heks-emacs-present-deck-script))

(defun heks-emacs-present-deck-html (&optional buffer)
  "Return BUFFER as a whole deck, or refuse to when it has no slides.

The refusal is the point: a buffer that says nowhere where a slide begins
is not a deck, and a page with the whole file on one slide is worse than
being told so."
  (let* ((source (or buffer (current-buffer)))
         (format (heks-emacs-present-format source))
         (slides (and format (heks-emacs-present-slides source))))
    (unless format
      (user-error "A deck is made of a Markdown or Org document, and this is %s"
                  (buffer-local-value 'major-mode source)))
    (unless slides
      (user-error "This document says nowhere where a slide begins%s"
                  (if (eq format 'markdown)
                      " (a line of three or more dashes starts one)"
                    "")))
    (with-current-buffer source
      (let ((heks-emacs-render--base-directory
             (and buffer-file-name (file-name-directory buffer-file-name))))
        (heks-emacs-present-deck-document
         (heks-emacs-render-title source)
         (mapcar (lambda (slide) (heks-emacs-present-slide-html slide format)) slides))))))

(defvar heks-emacs-present--files nil
  "Alist of buffer name to the file its deck was written to.

The file is written once per buffer and rewritten after that, so that
reloading the tab shows what the buffer says now rather than opening one
more file each time the deck changes.")

(defun heks-emacs-present-deck-file (&optional buffer)
  "Write BUFFER's deck to a file and return its name."
  (let* ((source (or buffer (current-buffer)))
         (key (buffer-name source))
         (known (assoc key heks-emacs-present--files))
         (file (or (cdr known)
                   (make-temp-file "heks-emacs-deck-" nil ".html"))))
    (unless known
      (push (cons key file) heks-emacs-present--files))
    (write-region (heks-emacs-present-deck-html source) nil file nil 'silent)
    file))

(defun heks-emacs-present-deck (&optional buffer)
  "Show BUFFER as a deck in the browser.

Save the document and reload the tab to show it again after an edit: the
deck is written to the same file each time, so the tab keeps its place."
  (interactive)
  (let* ((source (or buffer (current-buffer)))
         (file (heks-emacs-present-deck-file source))
         (slides (length (heks-emacs-present-slides source))))
    (browse-url (browse-url-file-url file))
    (message "%d slides of %s in the browser: %s"
             slides (heks-emacs-render-title source) file)))

(defun heks-emacs-present-deck-export (&optional buffer)
  "Write BUFFER's deck next to its file, as a `.deck.html' file to keep.

This is the one to use before a talk on a machine that is not this one:
the file carries its stylesheet and its navigation, so any browser opens
it without a server, a network or Emacs."
  (interactive)
  (let* ((source (or buffer (current-buffer)))
         (file (or (buffer-local-value 'buffer-file-name source)
                   (user-error "This buffer is not visiting a file")))
         (target (concat (file-name-sans-extension file) ".deck.html")))
    (write-region (heks-emacs-present-deck-html source) nil target)
    (message "Wrote %s" target)
    target))

;;
;; ====== Presenting in Emacs ======
;;;

(defvar-local heks-emacs-present--mode-line nil
  "The mode line this buffer had before it was presented.")

(defun heks-emacs-present-hide-mode-line ()
  "Hide the mode line while presenting, and put it back afterwards.

`org-present-mode' runs this both ways, so what was there before the talk
is what comes back after it."
  (if org-present-mode
      (progn
        (setq heks-emacs-present--mode-line mode-line-format)
        (setq mode-line-format nil))
    (when heks-emacs-present--mode-line
      (setq mode-line-format heks-emacs-present--mode-line))))

(defun heks-emacs-present-in-emacs ()
  "Present this Org note in Emacs, one heading at a time.

`org-present' does the work: it narrows the buffer to a subtree, scales
the text up and takes `SPC' and the arrow keys for the next and previous
heading.  `q' leaves it, and the mode line is hidden while it lasts,
because it is not part of what is being shown."
  (interactive)
  (require 'org-present)
  (unless (bound-and-true-p org-present-mode)
    (org-present)))

(defun heks-emacs-present ()
  "Present this buffer: in Emacs when it is an Org note, elsewhere in a browser.

Emacs can show an Org note one heading at a time with its own faces, which
is the right thing for a note, and it has no way to style a projected
page, which is what a Markdown deck wants; so an Org buffer is presented
here and anything else as a deck in the browser."
  (interactive)
  (if (eq major-mode 'org-mode)
      (heks-emacs-present-in-emacs)
    (heks-emacs-present-deck)))

(defun heks-emacs-present-insert-slide ()
  "Start the next slide of this document, at point.

What a boundary for a slide is depends on the document: a line of dashes
in Markdown, and in Org a heading at the level this file's slides are at,
since that is where a deck of it begins."
  (interactive)
  (pcase (heks-emacs-present-format)
    ('markdown
     (unless (bolp) (newline))
     (insert "\n---\n\n"))
    ('org
     (let ((level (or (heks-emacs-present--org-level (buffer-string)) 1)))
       (unless (bolp) (newline))
       (insert "\n" (make-string level ?*) " ")))
    (_ (user-error "Slides are a Markdown or Org thing, and this is %s" major-mode))))

;;
;; ====== The keys ======
;;;

(use-package org-present
  :ensure t
  :hook ((org-present-mode . heks-emacs-present-hide-mode-line))
  :bind (:map org-present-mode-keymap
              ;; A presentation is left with `q' everywhere else in the
              ;; world, and `C-c C-q' is a long way to reach when one is
              ;; standing up.  (`SPC' and the arrow keys are the package's
              ;; own; nothing is taken from them.)
              ("q" . org-present-quit)))

(use-package emacs
  :ensure nil
  :bind (("C-c r d" . heks-emacs-present-deck)
         ("C-c r D" . heks-emacs-present-deck-export)
         ("C-c r P" . heks-emacs-present)
         ("C-c r n" . heks-emacs-present-insert-slide)))

(provide 'heks-emacs/present)

;;; present.el ends here
