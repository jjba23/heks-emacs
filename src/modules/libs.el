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
;; the load.  `compat' is activated there for the same reason and a second
;; one: it has to be built before `transient' is, so that the order of the
;; queue is the order the packages compile in.

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

(use-package aio
  :ensure (:host github :repo "skeeto/emacs-aio" :branch "master")
  :demand t)

(provide 'heks/libs)

;;; libs.el ends here
