(use-package cape
  :ensure t
  :bind ("C-c p" . cape-prefix-map)
  :init
  ;; first function returning a result wins
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'cape-history)
  (add-hook 'completion-at-point-functions #'cape-elisp-block))

(use-package corfu
  :ensure t
  :init
  (setq corfu-cycle t
        corfu-auto t
        corfu-auto-prefix 2
        corfu-auto-delay 0.2
        corfu-quit-at-boundary 'separator
        corfu-quit-no-match 'separator
        corfu-echo-documentation 0.25
        corfu-preview-current 'insert
        corfu-preselect-first nil
        corfu-popupinfo-delay '(0.8 . 0.8))
  :config
  (global-corfu-mode)
  (corfu-history-mode)
  (corfu-popupinfo-mode 1))

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles partial-completion))))
  (completion-category-defaults nil)
  (completion-pcm-leading-wildcard t))
