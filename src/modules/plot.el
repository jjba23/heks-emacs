;;; plot.el --- Graph/Plot configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Graph/Plot configuration for Emacs

;;; Code:

(use-package gnuplot
  :ensure t
  :demand t)


(use-package mermaid-mode
  :ensure t
  :mode ("\\.mermaid\\'" "\\.mmd\\'")
  :init
  (setopt mermaid-mmdc-location "~/.nix-profile/bin/mmdc"
          mermaid-output-format ".png"
          mermaid-flags "-s 3")
  :config
  (setq mermaid-mode-map
        (let ((map mermaid-mode-map))
          (define-key map (kbd "C-c C-c") nil)
          (define-key map (kbd "C-c C-f") nil)
          (define-key map (kbd "C-c C-b") nil)
          (define-key map (kbd "C-c C-r") nil)
          (define-key map (kbd "C-c C-o") nil)
          (define-key map (kbd "C-c C-d") nil)
(define-key map (kbd "C-c C-d c") 'mermaid-compile)
          (define-key map (kbd "C-c C-d f") 'mermaid-compile-file)
          (define-key map (kbd "C-c C-d b") 'mermaid-compile-buffer)
          (define-key map (kbd "C-c C-d r") 'mermaid-compile-region)
          (define-key map (kbd "C-c C-d o") 'mermaid-open-browser)
          ;; `h' is help, as it is under `C-c h' and everywhere else: this
          ;; was `d', which is the debugger and the difference between two
          ;; things.
          (define-key map (kbd "C-c C-d h") 'mermaid-open-doc)
          map)))

(provide 'heks/plot)

;;; plot.el ends here
