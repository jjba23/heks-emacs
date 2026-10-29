;;; macros.el --- Macros for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Macros for Emacs - tips: you can use `elmacro' package, by activating `elmacro-mode'
;; and after having recorded a macro with the F3 - do - F4 dance
;; use `elmacro-show-last-macro'

;;; Code:

(defun kbd-scheme-hygguile-abstraction ()
  "Replace a (selected) string that is a whitespace separated list of CSS classes by a hygguile class set."
  (interactive)
  (kill-region 10305 10346 'region)
  (backward-char 1)
  (delete-char 1 nil)
  (delete-char 1 nil)
  (insert ",(mk-class '(")
  (yank nil)
  (insert "))"))

(defun kbd-scheme-make-parameter ()
  "Replace a (selected) value by a (make-parameter ~a).
Useful for libraries where you want to allow users to redefine values."
  (interactive)
  (kill-region 2350 2361 'region)
  (insert "(make-parameter ")
  (yank nil)
  (insert ")"))

(defun kbd-scheme-string-to-symbol-in-alist-access ()
  "Replace something like (assoc-ref job \"job_id\") by (assq-ref job 'job_id) ."
  (interactive)
  (kill-word 1)
  (insert "assq")
  (forward-sexp 1 (point))
  (forward-sexp 1 (point))
  (forward-sexp 1 (point))
  (backward-sexp 1 (point))
  (delete-char 1 nil)
  (insert "'")
  (forward-sexp 1 (point))
  (delete-char 1 nil))

(provide 'heks/macros)

;;; macros.el ends here
