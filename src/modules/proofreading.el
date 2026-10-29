;;; proofreading.el --- Proof-reading configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Proof-reading configuration for Emacs

;;; Code:

;; Jinx is a fast just-in-time spell-checker for Emacs.
(use-package jinx
  :ensure t
  :demand t
  :bind (("M-$" . jinx-correct)
         ([remap ispell-word] . #'jinx-correct)
         ("C-c t $" . jinx-mode)
         ("C-M-$" . jinx-languages))
  :init
  (setq jinx-languages "en_US nl_NL"))

;; you could enable Jinx mode automatically for certain modes like this:
;; :config
;; (dolist (hook '(text-mode-hook
;;                 prog-mode-hook
;;                 conf-mode-hook
;;                 org-mode-hook
;;                 markdown-mode-hook))
;;   (add-hook hook #'jinx-mode))

(provide 'heks/proofreading)

;;; proofreading.el ends here
