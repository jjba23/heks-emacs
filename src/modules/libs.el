;;; libs.el --- Libs configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Libs configuration for Emacs

;;; Code:

(use-package transient :ensure t :after (compat))

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
