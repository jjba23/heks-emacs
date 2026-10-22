;;; markdown.el --- Reading a Markdown document  -*- lexical-binding: t -*-

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

;; Markdown is read twice in this configuration: `render.el' turns it into
;; HTML to read, and `import.el' turns it into Org to work in.  What a
;; table is, how deep a list is nested, what a code span keeps out of the
;; rest of the line -- the *reading* of a document rather than what is made
;; of it -- is answered here, once, so that the file previewed and the file
;; imported cannot disagree about the same lines.
;;
;; It is deliberately small and deliberately dumb: a line at a time, no
;; parser library, and no pandoc (a document one can only read where a
;; program was installed is not a document one can always read).  The
;; subset covered is the one documents are written in -- headings, fenced
;; code, tables, lists, blockquotes, thematic breaks, and the inline
;; markup -- which is also the subset both readers cover, and the reason
;; they cover the same one.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defvar heks-emacs-markdown-base-directory nil
  "The directory a document's relative links are resolved against.

Bound while a document is read, so that `![a diagram](images/a.png)' in a
file finds the image that sits next to it rather than one next to the
preview, which lives in a temporary directory, or next to the note an
import wrote, which may live anywhere at all.")

(defun heks-emacs-markdown-resolve-path (url)
  "Return the path URL, a link in a document, names, or nil when it names none.

A link that is not a relative one -- a URL with a scheme, a bare
`#fragment', an absolute path -- is the caller's to pass through
unchanged, and nil is what this returns for it.  A relative one is
resolved against `heks-emacs-markdown-base-directory'."
  (when (and (stringp url)
             (not (string-empty-p url))
             (not (string-match-p "\\`\\([a-zA-Z][a-zA-Z0-9+.-]*:\\|#\\|/\\)" url))
             heks-emacs-markdown-base-directory)
    (expand-file-name url heks-emacs-markdown-base-directory)))

(defun heks-emacs-markdown-split-code-spans (text)
  "Split TEXT at its `code spans', returning (IS-CODE . TEXT) pieces.

Code is found first because inside a code span an asterisk is an asterisk:
`a *b*' is code, not emphasis."
  (let ((start 0) (pieces nil) (length (length text)))
    (while (string-match "`\\([^`]+\\)`" text start)
      (when (> (match-beginning 0) start)
        (push (cons nil (substring text start (match-beginning 0))) pieces))
      (push (cons t (match-string 1 text)) pieces)
      (setq start (match-end 0)))
    (when (< start length)
      (push (cons nil (substring text start)) pieces))
    (nreverse pieces)))

(defun heks-emacs-markdown-indent-of (line)
  "Return the width of the indentation of LINE, counting a tab as four."
  (let ((width 0)
        (index 0))
    (while (and (< index (length line))
                (memq (aref line index) '(?\s ?\t)))
      (setq width (+ width (if (eq (aref line index) ?\t) 4 1)))
      (setq index (1+ index)))
    width))

(defun heks-emacs-markdown-cells (line)
  "Return the cells of a table row LINE."
  (let ((trimmed (string-trim line)))
    (setq trimmed (string-remove-prefix "|" trimmed))
    (setq trimmed (string-remove-suffix "|" trimmed))
    (mapcar #'string-trim (split-string trimmed "|"))))

(defun heks-emacs-markdown-table-p (line next)
  "Return whether LINE starts a table, given the NEXT line.

A table is a row of cells followed by a delimiter row: `| a | b |' then
`|---|:--:|'."
  (and line next
       (string-match-p "|" line)
       ;; A pipe in the delimiter row too: a paragraph with a rule
       ;; under it (`text' then `---') is a setext heading, not a
       ;; one-column table.
       (string-match-p "|" next)
       (string-match-p "\\`[ \t]*|?[ \t]*:?-\\{2,\\}" next)))

;;
;; ====== The things a document defines for its own use ======
;;
;; Markdown has two kinds of line that are not read where they are written
;; but remembered for later: a link written as `[text][label]' is resolved
;; by a `[label]: url' line somewhere else in the file, and a footnote
;; marker in the text is answered by its `[^label]: text' line.  Both are
;; read here, once, so that the page and the note that are made of a
;; document cannot disagree about what a label points at.

(defconst heks-emacs-markdown-link-definition-regexp
  (concat "\\`\\[\\([^]^][^]]*\\)\\]:[ \t]*"
          "\\(?:<\\([^>]+\\)>\\|\\([^ \t]+\\)\\)"
          "\\(?:[ \t]+\"\\([^\"]*\\)\"\\|[ \t]+'\\([^']*\\)'\\)?[ \t]*\\'")
  "Regexp matching a link definition: `[label]: url \"title\"'.")

(defconst heks-emacs-markdown-footnote-definition-regexp
  "\\`\\[\\(\\^[^]]+\\)\\]:[ \t]*\\(.*\\)\\'"
  "Regexp matching a footnote definition: `[^label]: text'.")

(defun heks-emacs-markdown-normalize-label (label)
  "Return LABEL as the key a reference to it is looked up by.

A label is matched without regard to case and without its surrounding
space, which is what makes `[the Docs][docs]' find a `[DOCS]: url' line."
  (downcase (string-trim (replace-regexp-in-string "[ \t\n]+" " " (or label "")))))

(defun heks-emacs-markdown-link-definitions (lines)
  "Return (BODY . LINKS) for the document in LINES.

LINKS is an alist from a normalized label to (URL . TITLE), and BODY is
the lines that are left once the definition lines have been taken out.
A footnote definition is not a link definition and stays in BODY: it is
read where it is written, by the reader that makes a note of it."
  (let ((body nil)
        (links nil)
        (rest lines))
    (while rest
      (let ((trimmed (string-trim (car rest))))
        (if (string-match heks-emacs-markdown-link-definition-regexp trimmed)
            (push (cons (heks-emacs-markdown-normalize-label (match-string 1 trimmed))
                        (cons (or (match-string 2 trimmed) (match-string 3 trimmed))
                              (or (match-string 4 trimmed) (match-string 5 trimmed))))
                  links)
          (push (car rest) body)))
      (setq rest (cdr rest)))
    (cons (nreverse body) (nreverse links))))

(defun heks-emacs-markdown--footnote-text (first following)
  "Return (TEXT . REST) for a footnote whose first line is FIRST.

TEXT is the whole note, with the indented lines under FIRST joined to it
the way the rest of Markdown continues a block, and REST is what is left
of FOLLOWING once they have been read."
  (let ((lines (list first))
        (rest following))
    (while (and rest
                (string-match-p "\\`\\(?:    \\|\t\\)\\S-" (car rest)))
      (push (string-trim (car rest)) lines)
      (setq rest (cdr rest)))
    (cons (string-join (nreverse lines) " ") rest)))

(defun heks-emacs-markdown-definitions (lines)
  "Return (BODY . DEFINITIONS) for the document in LINES.

DEFINITIONS is a plist of `:links' -- an alist from a normalized label to
\(URL . TITLE) -- and `:footnotes' -- an alist from a label to the text
that answers it.  BODY is the lines that are left once the definitions
have been taken out, which is what the readers below work on."
  (let* ((without-links (heks-emacs-markdown-link-definitions lines))
         (rest (car without-links))
         (footnotes nil)
         (kept nil))
    (while rest
      (let ((trimmed (string-trim (car rest))))
        (if (string-match heks-emacs-markdown-footnote-definition-regexp trimmed)
            ;; Both groups are read out before the note is read: reading it
            ;; runs searches of its own, and this one's match data would be
            ;; gone by the time the label was asked for.
            (let* ((label (match-string 1 trimmed))
                   (note (heks-emacs-markdown--footnote-text
                          (match-string 2 trimmed) (cdr rest))))
              (push (cons label (car note)) footnotes)
              (setq rest (cdr note)))
          (push (car rest) kept)
          (setq rest (cdr rest)))))
    (cons (nreverse kept)
          (list :links (cdr without-links) :footnotes (nreverse footnotes)))))

(defconst heks-emacs-markdown-alerts
  '(("NOTE" . "note")
    ("TIP" . "tip")
    ("IMPORTANT" . "important")
    ("WARNING" . "warning")
    ("CAUTION" . "caution"))
  "The kinds of callout GitHub's Markdown writes as a blockquote.

The marker is a blockquote whose first line is `[!NOTE]'; what it is for is
the reader's, and what it is *called* is the stylesheet's.")

(defun heks-emacs-markdown-alert (line)
  "Return the callout kind LINE announces, or nil when it announces none.

LINE is the first line of a blockquote, and the answer is one of the kinds
in `heks-emacs-markdown-alerts'."
  (let ((trimmed (string-trim (or line ""))))
    (when (string-match "\\`\\[!\\([A-Za-z]+\\)\\]" trimmed)
      (cdr (assoc (upcase (match-string 1 trimmed))
                  heks-emacs-markdown-alerts)))))

(defun heks-emacs-markdown-alert-remainder (line)
  "Return what follows the callout marker of LINE, or nil."
  (let ((trimmed (string-trim (or line ""))))
    (when (string-match "\\`\\[![A-Za-z]+\\][ \t]*\\(.*\\)\\'" trimmed)
      (let ((rest (string-trim (match-string 1 trimmed))))
        (unless (string-empty-p rest) rest)))))

(provide 'heks-emacs/markdown)

;;; markdown.el ends here
