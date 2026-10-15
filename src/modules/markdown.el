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

(provide 'heks-emacs/markdown)

;;; markdown.el ends here
