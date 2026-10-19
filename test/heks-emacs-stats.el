;;; heks-emacs-stats.el --- Count the configuration's lines and decisions  -*- lexical-binding: t -*-

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

;; A handful of numbers, not a check: how many lines the configuration and
;; its tests have, and how many decisions the module definitions make.
;;
;;   emacs -Q --batch -l test/heks-emacs-stats.el
;;
;; `maak stats' runs it.  The counts are deliberately shallow.  A line is a
;; physical line; a comment is a line whose first non-space character is a
;; semicolon, so documentation strings count as code.  A decision point is
;; an `if', `when' or `unless' (including the `-let*' forms), a clause of
;; `cond', `pcase' or `case', a loop, or a `condition-case' or `catch'.
;; `and' and `or' are counted on their own and are not part of the total.
;; The total is read from the top-level `defun's of `src/modules', which is
;; what the README's complexity paragraph describes.  This reporter is left
;; out of its own test count, since it reports on the checks rather than
;; being one of them.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defvar heks-stats--root
  (file-name-as-directory
   (expand-file-name (or (getenv "HEKS_STATS_DIR") default-directory)))
  "The checkout to count.")

(defvar heks-stats--self
  (and load-file-name (file-truename load-file-name))
  "This file, so that it is not counted as one of the tests.")

(defconst heks-stats--decision-heads
  '(if when unless
       if-let when-let if-let* when-let* while-let
       while dolist dotimes cl-loop
       condition-case catch)
  "Forms that are one decision point each.")

(defun heks-stats--files (directory extension)
  "Return the files ending in EXTENSION directly under DIRECTORY."
  (directory-files (expand-file-name directory heks-stats--root)
                   t (format "\\`[^.#].*%s\\'" (regexp-quote extension))))

(defun heks-stats--lines (file)
  "Return the physical lines of FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((text (buffer-string)))
      (cond
       ((string-empty-p text) nil)
       ((string-suffix-p "\n" text) (butlast (split-string text "\n")))
       (t (split-string text "\n"))))))

(defun heks-stats--count-lines (files)
  "Return the line counts of FILES as (LINES BLANK COMMENTS CODE)."
  (let ((lines 0) (blank 0) (comments 0))
    (dolist (file files)
      (dolist (line (heks-stats--lines file))
        (cl-incf lines)
        (let ((trimmed (string-trim-left line)))
          (cond
           ((string-blank-p trimmed) (cl-incf blank))
           ((eq (aref trimmed 0) ?\;) (cl-incf comments))))))
    (list lines blank comments (- lines blank comments))))

(defun heks-stats--forms (file)
  "Return the top-level forms of FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let (forms)
      (condition-case nil
          (while (progn (forward-comment (point-max)) (not (eobp)))
            (push (read (current-buffer)) forms))
        (error nil))
      (nreverse forms))))

(defvar heks-stats--decisions 0)
(defvar heks-stats--operators 0)

(defun heks-stats--walk (form)
  "Add the decisions and operators in FORM to the running counts."
  (when (consp form)
    (let ((head (car form)))
      (cond
       ((memq head heks-stats--decision-heads)
        (cl-incf heks-stats--decisions)
        (mapc #'heks-stats--walk (cdr form)))
       ((eq head 'cond)
        ;; One decision per clause.
        (cl-incf heks-stats--decisions (length (cdr form)))
        (mapc #'heks-stats--walk (cdr form)))
       ((memq head '(pcase case ecase cl-case))
        ;; The first argument is the value or key, not a clause.
        (cl-incf heks-stats--decisions (length (cddr form)))
        (mapc #'heks-stats--walk (cddr form)))
       ((memq head '(and or))
        (cl-incf heks-stats--operators)
        (mapc #'heks-stats--walk (cdr form)))
       (t (let ((tail form))
            (while (consp tail)
              (heks-stats--walk (car tail))
              (setq tail (cdr tail)))))))))

(defun heks-stats--count-definitions (files)
  "Count top-level `defun's in FILES and walk their bodies.
Return the number of definitions."
  (let ((definitions 0))
    (dolist (file files)
      (dolist (form (heks-stats--forms file))
        (when (eq (car-safe form) 'defun)
          (cl-incf definitions)
          (mapc #'heks-stats--walk (cdddr form)))))
    definitions))

(defun heks-stats--print-row (label files &optional line-counts)
  "Print one line count row for LABEL and FILES.
When LINE-COUNTS is non-nil, also print blank, comment and code counts."
  (if line-counts
      (let ((counts (heks-stats--count-lines files)))
        (princ (format "%-14s %3d files %6d lines %5d blank %5d comments %5d code\n"
                       label (length files)
                       (nth 0 counts) (nth 1 counts) (nth 2 counts) (nth 3 counts))))
    (princ (format "%-14s %3d files %6d lines\n"
                   label (length files)
                   (nth 0 (heks-stats--count-lines files))))))

(let* ((config (append (heks-stats--files "src" ".el")
                       (heks-stats--files "src/modules" ".el")))
       (tests (cl-remove-if (lambda (file)
                              (equal (file-truename file) heks-stats--self))
                            (heks-stats--files "test" ".el")))
       (snippets (heks-stats--files "src/snippets" ".eld"))
       (modules (heks-stats--files "src/modules" ".el")))
  (princ "== lines ==\n")
  (heks-stats--print-row "configuration" config t)
  (heks-stats--print-row "tests" tests t)
  (heks-stats--print-row "snippets" snippets)
  (heks-stats--print-row "elisp" (append config tests))

  (princ "\n== complexity ==\n")
  (princ (format "%-14s %6d\n" "modules" (length modules)))
  (princ (format "%-14s %6d\n" "definitions" (heks-stats--count-definitions modules)))
  (princ (format "%-14s %6d\n" "decisions" heks-stats--decisions))
  (princ (format "%-14s %6d\n" "and/or" heks-stats--operators)))

;;; heks-emacs-stats.el ends here
