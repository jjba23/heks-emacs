;;; libs.el --- Libs configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Libs configuration for Emacs

;;; Code:

;; `transient' is activated in `init.el', before the modules are read, so
;; that no package loads it ahead of Elpaca's own activation of it (the
;; paragraph there says why).  Declaring it here as well would queue it
;; twice, and Elpaca answers a duplicate queue with a warning that stops
;; the load.

(use-package f :ensure t)

(use-package page-break-lines :ensure t)

(use-package queue
  :ensure (:host github :repo "emacs-straight/queue" :branch "master")
  :demand t)

(use-package elmacro
  :ensure (:host github :repo "Silex/elmacro" :branch "master")
  :demand t
  :config
  (elmacro-mode +1))

(use-package compat
  :ensure (:host github :repo "emacs-compat/compat" :branch "main")
  :demand t)

(use-package aio
  :ensure (:host github :repo "skeeto/emacs-aio" :branch "master")
  :demand t)

(provide 'heks/libs)

;;; libs.el ends here
