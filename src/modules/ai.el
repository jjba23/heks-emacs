(use-package gptel
  :ensure t
  :after (f)
  :config
  (setq
   gptel-model 'gemini-pro
   gptel-backend (gptel-make-gemini "Gemini"
                   :key (lambda() (f-read-text "~/.secrets/gemini"))
                   :stream t)))

;; Provides an interactive AI coding assistant within Emacs.
(use-package eca
  :ensure t)
