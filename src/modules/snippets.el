;;; snippets.el --- Snippets configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Snippets configuration for Emacs

;;; Code:

;; Tempel is a tiny template package for Emacs, which uses the syntax of the Emacs Tempo library.
(use-package tempel
  :ensure (:host github :repo "minad/tempel" :branch "main")
  :bind (("C-c s c" . tempel-complete)
         ("C-c s i" . tempel-insert)
         ("C-c s x" . tempel-expand))
  :init
  (setopt tempel-path '("~/.emacs.d/snippets/*.eld")))

(provide 'heks/snippets)

;;; snippets.el ends here
