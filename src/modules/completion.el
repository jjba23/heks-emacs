;;; completion.el --- Completion configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Completion configuration for Emacs

;;; Code:

(use-package cape
  :ensure t
  :bind ("C-c p" . cape-prefix-map)
  :init
  ;; Earlier entries in the list are tried first (the hook is appended).
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'cape-elisp-block)
  (add-hook 'completion-at-point-functions #'cape-keyword)
  :config
  ;; Don't let a broken/slow capf wreck the whole popup.
  (advice-add 'eglot-completion-at-point :around #'cape-wrap-buster)
  (advice-add 'eglot-completion-at-point :around #'cape-wrap-nonexclusive))

(use-package corfu
  :ensure t
  :custom
  (corfu-cycle t)
  (corfu-auto t)
  (corfu-auto-prefix 2)
  (corfu-auto-delay 0.15)
  (corfu-quit-at-boundary 'separator)
  (corfu-quit-no-match 'separator)
  (corfu-preview-current 'insert)
  (corfu-preselect 'prompt)
  (corfu-on-exact-match nil)
  (corfu-count 12)
  (corfu-max-width 90)
  (corfu-scroll-margin 3)
  (corfu-popupinfo-delay '(0.8 . 0.4))
  ;; TAB is for completing, not indenting, once a popup is possible.
  (tab-always-indent 'complete)
  (text-mode-ispell-word-completion nil)
  (read-extended-command-predicate #'command-completion-default-include-p)
  :bind (:map corfu-map
              ("TAB"       . corfu-next)
              ([tab]       . corfu-next)
              ("S-TAB"     . corfu-previous)
              ([backtab]   . corfu-previous)
              ("M-SPC"     . corfu-insert-separator)
              ("M-m"       . heks/corfu-move-to-minibuffer)
              ("M-h"       . corfu-popupinfo-toggle)
              ("M-d"       . corfu-popupinfo-documentation)
              ("M-l"       . corfu-popupinfo-location))
  :init
  (global-corfu-mode)
  (corfu-history-mode)
  (corfu-popupinfo-mode)
  (corfu-echo-mode)
  :config
  (with-eval-after-load 'savehist
    (add-to-list 'savehist-additional-variables 'corfu-history))

  ;; Let `M-x' style minibuffer commands get Corfu too, but not where
  ;; a password or other secret is being read.
  (defun heks/corfu-enable-in-minibuffer ()
    (when (and (not (bound-and-true-p vertico--input))
               (not (eq (current-local-map) (bound-and-true-p read-passwd-map))))
      (setq-local corfu-echo-delay nil
                  corfu-popupinfo-delay nil)
      (corfu-mode 1)))
  (add-hook 'minibuffer-setup-hook #'heks/corfu-enable-in-minibuffer 1)

  ;; Transfer the current completion session to the minibuffer
  ;; completion UI (consult/vertico style).
  (defun heks/corfu-move-to-minibuffer ()
    (interactive)
    (pcase completion-in-region--data
      (`(,beg ,end ,table ,pred ,extras)
       (let ((completion-extra-properties extras)
             completion-cycle-threshold completion-cycling)
         (consult-completion-in-region beg end table pred)))))
  (add-to-list 'corfu-continue-commands #'heks/corfu-move-to-minibuffer)

  ;; Quick-select candidates with home-row keys, and show 1-9 indices
  ;; so `M-1'..`M-9' insert a candidate directly.
  (require 'corfu-quick)
  (require 'corfu-indexed)
  (define-key corfu-map (kbd "M-q") #'corfu-quick-complete)
  (define-key corfu-map (kbd "C-q") #'corfu-quick-insert)
  (corfu-indexed-mode 1))

;; Corfu in terminal frames (`emacs -nw').
(use-package corfu-terminal
  :ensure t
  :unless (or (display-graphic-p) (>= emacs-major-version 31))
  :after corfu
  :config (corfu-terminal-mode 1))

;; Snippets as completion candidates alongside LSP/dabbrev results.
(use-package yasnippet-capf
  :ensure t
  :after cape
  :config
  (add-hook 'completion-at-point-functions #'yasnippet-capf 90))

;; Merge sources in code buffers so Eglot results and dabbrev words
;; appear in one list instead of the first capf shadowing the others.
(defun heks/prog-capf-setup ()
  "Set buffer-local capfs merging Eglot, dabbrev and keywords, then files."
  (setq-local completion-at-point-functions
              (list (cape-capf-super
                     (cape-capf-properties #'eglot-completion-at-point
                                           :sort t)
                     #'cape-dabbrev
                     #'cape-keyword)
                    #'cape-file)))
(add-hook 'eglot-managed-mode-hook #'heks/prog-capf-setup)

;; Emoji / symbol completion in prose.
(defun heks/text-capf-setup ()
  "Add buffer-local emoji and TeX completion at the front of the capfs."
  (add-hook 'completion-at-point-functions #'cape-emoji -10 t)
  (add-hook 'completion-at-point-functions #'cape-tex -10 t))
(add-hook 'text-mode-hook #'heks/text-capf-setup)

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles partial-completion))))
  (completion-category-defaults nil)
  (completion-pcm-leading-wildcard t))

(provide 'heks/completion)

;;; completion.el ends here
