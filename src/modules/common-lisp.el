;;; common-lisp.el --- Common Lisp configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Common Lisp configuration for Emacs

;;; Code:

;; Configure the Sly REPL for Common Lisp development
(use-package sly
  :ensure (:host github :repo "joaotavora/sly" :branch "master")
  :demand t
  :init
  (setq inferior-lisp-program "/run/current-system/profile/bin/sbcl"))


(provide 'heks/common-lisp)

;;; common-lisp.el ends here
