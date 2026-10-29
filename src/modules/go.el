;;; go.el --- Go configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Go configuration for Emacs

;;; Code:

(use-package go-mode
  :ensure (:host github :repo "dominikh/go-mode.el" :branch "master")
  :demand t
  :init
  (setq gofmt-command "gofumpt")
  :config
  (add-hook 'go-mode-hook
            (lambda ()
              (setq indent-tabs-mode 1)
              (setq tab-width 4))))

(provide 'heks/go)

;;; go.el ends here
