;;; heks-emacs-lint.el --- Parse the configuration's Elisp  -*- lexical-binding: t -*-

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

;; The cheap half of checking the configuration, and the half that does not
;; need anything installed: every `.el' file is read form by form, and the
;; module list in `init.el' is compared with the files that are there.  A
;; parenthesis that closed a macro too early, or a module that was renamed
;; without its entry in the list, is caught here in a second rather than
;; when the configuration quietly stops loading a file.
;;
;;   emacs -Q --batch -l test/heks-emacs-lint.el
;;
;; `maak lint' runs it; `maak verify' goes on to load the whole thing.

;;; Code:

(setq load-prefer-newer t)
(require 'cl-lib)
(require 'seq)

(defvar heks-lint--dir
  (file-name-as-directory (expand-file-name (or (getenv "HEKS_LINT_DIR") default-directory)))
  "The checkout to lint.")

(defvar heks-lint--passed 0)
(defvar heks-lint--failed 0)

(defun heks-lint--check (label value &rest expected-given)
  "Record that LABEL holds when VALUE equals the first of EXPECTED-GIVEN."
  (let ((expected (if expected-given (car expected-given) t)))
    (if (equal value expected)
        (progn (setq heks-lint--passed (1+ heks-lint--passed))
               (message "  ok   %s" label))
      (setq heks-lint--failed (1+ heks-lint--failed))
      (message "  FAIL %s -> %S (expected %S)" label value expected))))

(defun heks-lint--elisp-files ()
  "Return the Elisp files of the configuration."
  (append (directory-files (expand-file-name "src" heks-lint--dir) t "\\`[^.#].*\\.el\\'")
          (directory-files (expand-file-name "src/modules" heks-lint--dir) t "\\.el\\'")
          (directory-files (expand-file-name "test" heks-lint--dir) t "\\.el\\'")))

(defun heks-lint--read-file (file)
  "Read every form of FILE and return (FORMS . ERROR).

Reading is the check: a file that reads is a file Emacs can load, and the
position of the error is what makes a mistake findable."
  (with-temp-buffer
    (insert-file-contents file)
    ;; The language's own syntax, so that `forward-comment' and `read' see
    ;; what Emacs sees.  In `fundamental-mode' a comment is not a comment,
    ;; and the one that closes these files looks like the file ending inside
    ;; a form.
    (emacs-lisp-mode)
    (let ((forms 0) (failure nil))
      (condition-case err
          (progn
            (goto-char (point-min))
            (while (progn (forward-comment (point-max)) (not (eobp)))
              (read (current-buffer))
              (setq forms (1+ forms))))
        ;; The loop only reads where there is something left, so running out
        ;; of input means the file ends *inside* a form: a paren that was
        ;; never closed.  This is the mistake the lint exists to catch, so it
        ;; is not an ordinary end of file.
        (end-of-file (setq failure (format "ends inside a form (line %d)"
                                           (line-number-at-pos))))
        (error (setq failure (format "%s at %d"
                                     (error-message-string err)
                                     (line-number-at-pos)))))
      (cons forms failure))))

(defun heks-lint--forms (file)
  "Return the top-level forms of FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let (all)
      (condition-case _err
          (while (progn (forward-comment (point-max)) (not (eobp)))
            (push (read (current-buffer)) all))
        (error nil))
      (nreverse all))))

(defun heks-lint--module-list ()
  "Return the module names `init.el' claims to load."
  (let* ((form (cl-find-if (lambda (form)
                             (and (eq (car-safe form) 'setq)
                                  (eq (nth 1 form) 'heks/modules)))
                           (heks-lint--forms (expand-file-name "src/init.el" heks-lint--dir))))
         (value (nth 2 form)))
    (when (and (consp value) (eq (car value) 'quote))
      (setq value (nth 1 value)))
    value))

(message "== every file reads ==")
(heks-lint--check "some files were found" (> (length (heks-lint--elisp-files)) 20))
(dolist (file (heks-lint--elisp-files))
  (let* ((result (heks-lint--read-file file))
         (label (file-relative-name file heks-lint--dir)))
    (heks-lint--check (format "%s reads (%d forms)" label (car result))
                      (cdr result) nil)))

(message "\n== the module list matches the files ==")
(let ((modules (heks-lint--module-list)))
  (heks-lint--check "init.el lists its modules" (and modules t))
  (dolist (module modules)
    (heks-lint--check (format "modules/%s.el is there" module)
                      (file-exists-p (expand-file-name (format "src/modules/%s.el" module)
                                                       heks-lint--dir))))
  ;; And the other way round: a module file nobody loads is dead weight.
  (let ((on-disk (mapcar (lambda (file) (intern (file-name-base file)))
                         (directory-files (expand-file-name "src/modules" heks-lint--dir)
                                          t "\\`[^.#].*\\.el\\'"))))
    (dolist (file on-disk)
      (heks-lint--check (format "modules/%s.el is loaded by init.el" file)
                        (and (or (memq file modules)
                                 ;; The bridge module is loaded by name, not
                                 ;; from the list.
                                 (eq file 'heks-emacs))
                             t)))))

(message "\n== %d passed, %d failed ==" heks-lint--passed heks-lint--failed)
(when (> heks-lint--failed 0)
  (kill-emacs 1))

;;; heks-emacs-lint.el ends here
