;;; help.el --- Help configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Help configuration for Emacs

;;; Code:

(use-package helpful
  :ensure t
  ;; Documentation is a topic of its own, so that "what does this do?" is
  ;; one key in every buffer -- the IntelliJ instinct of reaching for the
  ;; documentation without leaving point.  `C-c C-d' used to do this, and
  ;; the Mermaid buffers need that key for their own commands.
  :bind (("C-h f" . helpful-callable)
         ("C-h v" . helpful-variable)
         ("C-h k" . helpful-key)
         ("C-c h h" . helpful-at-point)
         ("C-c h f" . helpful-callable)
         ("C-c h v" . helpful-variable)
         ("C-c h k" . helpful-key)
         ("C-h F" . helpful-function)
         ("C-h C" . helpful-command)))

(provide 'heks/help)

;;; help.el ends here
