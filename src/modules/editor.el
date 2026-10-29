;;; editor.el --- General Editor tweaks and configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; General Editor tweaks and configuration for Emacs

;;; Code:

(use-package super-save
  :ensure t
  :init (setq super-save-auto-save-when-idle t auto-save-default nil make-backup-files nil)
  :config (super-save-mode +1)
  (add-to-list 'super-save-hook-triggers 'find-file-hook))

(use-package rainbow-mode
  :ensure (:host github :repo "emacsmirror/rainbow-mode" :branch "master"))

(use-package move-text
  :ensure t
  :config (move-text-default-bindings))

;; Growing the region by what it is made of: a word, then the string around
;; it, then the form, then the definition -- and back again.  A region one
;; guesses the size of is a region one gets wrong, and this is the keyboard
;; answer to "select this expression" that a mouse gets by dragging.
(use-package expand-region
  :ensure t
  :bind (("C-c z e" . er/expand-region)
         ("C-c z s" . er/contract-region)))

;; Editing a file this user cannot write is a thing that happens to people
;; who edit files for a living: this asks for the privilege it needs, opens
;; the file again through TRAMP and leaves the buffer where it was.  Under
;; the system topic, next to the rest of what needs a password.
(use-package sudo-edit
  :ensure t
  :bind (("C-c # e" . sudo-edit)))

(provide 'heks/editor)

;;; editor.el ends here
