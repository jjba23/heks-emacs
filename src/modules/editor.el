



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

