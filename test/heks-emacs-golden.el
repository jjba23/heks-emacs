;;; heks-emacs-golden.el --- Compare the renderers with what they produced  -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; The renderers are the part of this configuration whose *output* a
;; person reads, so the one thing worth pinning down is the output itself.
;; `test/heks-emacs-render.el' asserts that a heading becomes a heading;
;; this file asserts that a whole document still becomes the whole page it
;; became last time.  The difference matters: a rule that starts matching
;; one word earlier, a table column that changes its alignment, a response
;; code that stops being escaped -- each of those passes a check that says
;; "there is an `<h1>' in there" and changes every page one reads.
;;
;; Each fixture in `test/fixtures/' is rendered, and the result is
;; compared, line by line, with the page kept in `test/golden/'.  A change
;; then arrives as a diff -- what the renderer now says next to what it
;; said before -- rather than as an invitation to look at a page and guess.
;;
;;   emacs -Q --batch -l test/heks-emacs-golden.el
;;   HEKS_GOLDEN_UPDATE=1 emacs -Q --batch -l test/heks-emacs-golden.el
;;
;; The second form is how a golden file is meant to be updated: it writes
;; what the renderers produce now, so that the change becomes a diff in
;; the commit rather than a surprise later.  Do it only when the new page
;; is the page one wanted, and read the diff before committing it.
;;
;; What is compared is the *body* of the rendering, not the document
;; around it: `heks/html-document' carries a stylesheet built from
;; the colours of the current theme, so a document-sized golden file would
;; fail whenever a palette changed and would say nothing about rendering.
;; The wrapper is checked by `maak verify' on an installed configuration.
;;
;; A Markdown document is read twice in this configuration and this file
;; pins both readings: the page `render.el' makes of it, and the note
;; `import.el' makes.  The second is compared the same way, line by line,
;; because it is also output a person reads -- and one a change to the
;; reading would change— without a page to open and look at.
;;
;; The OpenAPI page is rendered twice, once from a JSON fixture and once
;; from a YAML one.  They are the same specification, so they have one
;; golden file between them: the two languages have to read to the same
;; thing, which is exactly the property that used to be broken (a YAML
;; document was parsed with symbol keys, so every lookup missed and the
;; page came out empty).
;;
;; It exits non-zero when a page has changed, so `maak golden' fails with
;; it.

;;; Code:

(setq load-prefer-newer t)
(require 'cl-lib)
(require 'subr-x)

(defvar heks-golden--passed 0)
(defvar heks-golden--failed 0)
(defvar heks-golden--skipped 0)

(defmacro use-package (&rest _)
  "Stand in for the keybinding macro, which this test does not exercise."
  nil)

(defconst heks-golden--root
  (file-name-as-directory
   (file-name-directory (directory-file-name (file-name-directory load-file-name))))
  "The checkout holding the configuration's source.")

(defconst heks-golden--fixtures
  (expand-file-name "test/fixtures/" heks-golden--root)
  "The documents the renderings are taken from.")

(defconst heks-golden--pages
  (expand-file-name "test/golden/" heks-golden--root)
  "The renderings the fixtures are compared with.")

(add-to-list 'load-path (expand-file-name "src/modules" heks-golden--root))

;; `markdown.el' is the reading of a document, and the renderers are what is
;; made of it.
(load "markdown" nil t)

;; The renderers themselves.  `openapi.el' asks `render.el' for the
;; document it wraps its page in, so it is loaded second.
(load "render" nil t)
;; And the other reading of the same document: the one that makes a note.
(load "import" nil t)

;; YAML is read by a package -- whichever one the configuration installs --
;; so it is looked for where Elpaca leaves it.  A machine without it can
;; still check every JSON fixture; the YAML ones are then reported as
;; skipped rather than passed.
(let ((build (expand-file-name "~/.emacs.d/elpaca/builds/")))
  (dolist (package '("yaml" "yaml-mode"))
    (when (file-directory-p (expand-file-name package build))
      (add-to-list 'load-path (expand-file-name package build)))))
(defvar heks-golden--yaml (and (require 'yaml nil t) t)
  "Whether a YAML reader is installed, which the YAML fixtures need.")

;; `openapi.el' is loaded even when YAML is missing: the JSON fixtures go
;; through the same functions, and a page that cannot be rendered at all
;; has to fail rather than disappear.
(load "openapi" nil t)

;;
;; Comparing a rendering with the page it produced last time.
;;

(defun heks-golden--lines (text)
  "Return TEXT as a list of lines, without the newline that ends it."
  (split-string (string-remove-suffix "\n" text) "\n"))

(defun heks-golden--diff (actual expected &optional limit)
  "Describe how ACTUAL differs from EXPECTED, line by line.

LIMIT, four by default, is how many differing lines are shown; the point
is a diff one can read, not a full one."

  (let* ((limit (or limit 4))
         (actual-lines (heks-golden--lines actual))
         (expected-lines (heks-golden--lines expected))
         (rows (max (length actual-lines) (length expected-lines)))
         (shown 0)
         (found 0))
    (dotimes (index rows)
      (let ((mine (nth index actual-lines))
            (theirs (nth index expected-lines)))
        (unless (equal mine theirs)
          (setq found (1+ found))
          (when (< shown limit)
            (setq shown (1+ shown))
            (when (and (> index 0) (= shown 1))
              (message "       %-4s kept:   %s" index (nth (1- index) expected-lines)))
            (message "       %-4s golden: %s" (1+ index)
                     (if theirs theirs "<nothing: the page ends here>"))
            (message "       %-4s now:    %s" (1+ index)
                     (if mine mine "<nothing: the page ends here>"))))))
    (format "%d line%s differ, of %d"
            found (if (= found 1) "" "s") rows)))

(defun heks-golden--golden-file (page)
  "Return the path of the golden file called PAGE."
  (expand-file-name page heks-golden--pages))

(defconst heks-golden--import-base-directory "/home/someone/docs/"
  "The directory the imported fixture's relative links are resolved against.

A fixed one, and nobody's: a golden file is read on machines that are not
this one, and a note that named the directory this checkout happens to be
in would differ on every other one.  A link in the note is checked for
what it becomes rather than for what it points at.")

(defconst heks-golden--import-id "9e2c5b1a-4d3f-4a7e-8b60-3f2c7d5e9a41"
  "The identifier the imported fixture is given.

Fixed rather than made, because one made of a time and a random number is
new on every run, and a golden file that changes on every run compares
against nothing.")

(defun heks-golden--import (fixture)
  "Return the Org the Markdown of FIXTURE becomes, as an import makes it.

The note is made the way `heks/import-markdown-file' makes one --
the front matter, the identifier and the aliases it asks for, then the
body -- rather than by converting the text alone: the property drawer is
part of the note a person gets, and it is the part most easily written in
a place Org does not read, which is what a golden file is for noticing."
  (let ((file (expand-file-name fixture heks-golden--fixtures))
        ;; A name no file has, so that the identifier written is the fixed
        ;; one rather than one read back out of a note already there.
        (target (make-temp-name (expand-file-name "heks-golden-import-"
                                                  temporary-file-directory))))
    (with-temp-buffer
      (insert-file-contents file)
      (let* ((text (buffer-string))
             (metadata (heks/markdown-metadata text))
             (heks/markdown-base-directory heks-golden--import-base-directory))
        (cl-letf (((symbol-function 'heks/import--id)
                   (lambda () heks-golden--import-id)))
          (heks/markdown-to-org
           text (heks/import--properties metadata target t)))))))

(defun heks-golden--render (fixture)
  "Return the HTML body FIXTURE renders to, through the real dispatcher.

The buffer visits the fixture, so the renderer is chosen the way it is
chosen for a file being read: by the buffer and its name rather than by
anything this file says."
  (let ((file (expand-file-name fixture heks-golden--fixtures)))
    (with-temp-buffer
      (insert-file-contents file)
      (setq buffer-file-name file)
      ;; The mode a real visit would give it, where the package that
      ;; provides it is installed; the file name decides either way.
      (when (and (string-match-p "\\.ya?ml\\'" file)
                 (require 'yaml-mode nil t))
        (yaml-mode))
      (heks/render-body))))

(defun heks-golden--check (fixture page &optional org)
  "Check that FIXTURE still renders as PAGE, and return the rendering.

ORG says that what is compared is the note the import makes of the
document rather than the page the preview makes of it."
  (let ((label (format "%s -> %s" fixture page)))
    (let ((actual (if org (heks-golden--import fixture) (heks-golden--render fixture)))
          (file (heks-golden--golden-file page)))
      (if (getenv "HEKS_GOLDEN_UPDATE")
          (progn
            (make-directory (file-name-directory file) t)
            (with-temp-file file (insert actual))
            (message "  wrote %s (%d bytes)" page (length actual))
            actual)
        (if (not (file-exists-p file))
            (progn
              (setq heks-golden--failed (1+ heks-golden--failed))
              (message "  FAIL %s -> %s does not exist; write it with\n        HEKS_GOLDEN_UPDATE=1 emacs -Q --batch -l test/heks-emacs-golden.el"
                       label page)
              actual)
          (let ((expected (with-temp-buffer
                            (insert-file-contents file)
                            (buffer-string))))
            (if (equal actual expected)
                (progn (setq heks-golden--passed (1+ heks-golden--passed))
                       (message "  ok   %s" label))
              (setq heks-golden--failed (1+ heks-golden--failed))
              (message "  FAIL %s" label)
              (message "       %s" (heks-golden--diff actual expected)))
            actual))))))

(defun heks-golden--skip (fixture page why)
  "Record that FIXTURE could not be rendered as PAGE, because WHY."
  (setq heks-golden--skipped (1+ heks-golden--skipped))
  (message "  skip %s -> %s: %s" fixture page why))

;;
;; The fixtures.
;;

(message "== the renderers, against the pages they produced last time")

(message "\n  a Markdown document")
(heks-golden--check "render-note.md" "render-note.html")

(message "\n  the same document, imported as an Org note")
(heks-golden--check "import-note.md" "import-note.org" :org)

(message "\n  an OpenAPI specification, in the two languages it is written in")
(heks-golden--check "render-petstore.json" "render-petstore.html")
(let ((json (heks-golden--render "render-petstore.json")))
  (if (not heks-golden--yaml)
      (heks-golden--skip "render-petstore.yaml" "render-petstore.html"
                         "no YAML reader is installed (its elpaca build directory was looked in)")
    (let ((yaml (heks-golden--check "render-petstore.yaml" "render-petstore.html")))
      ;; Said out loud because it is the point: two spellings of one
      ;; specification are one document.
      (if (equal json yaml)
          (progn (setq heks-golden--passed (1+ heks-golden--passed))
                 (message "  ok   the YAML and the JSON render as the same page"))
        (setq heks-golden--failed (1+ heks-golden--failed))
        (message "  FAIL the YAML and the JSON render differently")
        (message "       %s" (heks-golden--diff yaml json))))))

;;
;; The verdict.
;;

(message "\n== %d matched, %d changed, %d skipped =="
         heks-golden--passed heks-golden--failed heks-golden--skipped)
(when (> heks-golden--failed 0)
  (message "\nRun HEKS_GOLDEN_UPDATE=1 emacs -Q --batch -l test/heks-emacs-golden.el
to write the pages as they are now, then read the diff it produces.")
  (kill-emacs 1))

;;; heks-emacs-golden.el ends here
