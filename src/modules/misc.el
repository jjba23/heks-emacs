;;; misc.el --- Misc configuration for Emacs -*- lexical-binding: t -*-

;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; heks-emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; heks-emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with heks-emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Misc configuration for Emacs

;;; Code:

(use-package prodigy
  :ensure t)

(use-package git-riddance
  :ensure (:host codeberg :repo "jjba23/git-riddance.el" :branch "trunk"))

(use-package dagboek
  :ensure (:host codeberg :repo "jjba23/dagboek.el" :branch "trunk")
  :bind (("C-c ; v" . dagboek-today-entry)
         ("C-c ; g" . dagboek-yesterday-entry))
  :custom
  (dagboek-entry-location "~/hacking/private-notes/diary"))

(use-package gptel
  :ensure t
  :after (f)
  :config
  (setq
   gptel-model 'gemini-pro
   gptel-backend (gptel-make-gemini "Gemini"
                                    :key (lambda() (f-read-text "~/.secrets/gemini"))
                                    :stream t)))


(use-package speed-type
  :ensure (:host github :repo "dakra/speed-type"))

(use-package guix :ensure t :demand t)

(use-package pandoc-mode :ensure t)

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

(use-package gnuplot
  :ensure t
  :demand t)

(use-package magit :ensure t :after (transient compat))

(use-package tempel
  :ensure (:host github :repo "minad/tempel" :branch "main")
  :bind (("C-c s c" . tempel-complete)
         ("C-c s i" . tempel-insert)
         ("C-c s x" . tempel-expand))
  :init
  (setopt tempel-path '("~/.emacs.d/snippets/*.eld")))

(use-package super-save
  :ensure t
  :init (setq super-save-auto-save-when-idle t auto-save-default nil make-backup-files nil)
  :config (super-save-mode +1)
  (add-to-list 'super-save-hook-triggers 'find-file-hook))

(use-package rainbow-mode
  :ensure (:host github :repo "emacsmirror/rainbow-mode" :branch "master"))

(use-package mermaid-mode
  :ensure t
  :init
  (setq mermaid-mmdc-location "~/.nix-profile/bin/mmdc")
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
          (define-key map (kbd "C-c C-d c") 'mermaid-compile)
          (define-key map (kbd "C-c C-d f") 'mermaid-compile-file)
          (define-key map (kbd "C-c C-d b") 'mermaid-compile-buffer)
          (define-key map (kbd "C-c C-d r") 'mermaid-compile-region)
          (define-key map (kbd "C-c C-d o") 'mermaid-open-browser)
          (define-key map (kbd "C-c C-d d") 'mermaid-open-doc)
          map)))

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles partial-completion))))
  (completion-category-defaults nil)
  (completion-pcm-leading-wildcard t))

;; TODO work on debugger support (use GUD? Realgud? DAPE?)
;; (use-package dape
;;   :ensure t
;;   :init (setq dape-buffer-window-arrangement 'gud))

(use-package move-text
  :ensure t
  :config (move-text-default-bindings))

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


(use-package helpful
  :ensure t
  :bind (
         ("C-h f" . helpful-callable)
         ("C-h v" . helpful-variable)
         ("C-h k" . helpful-key)
         ("C-c C-d" . helpful-at-point)
         ("C-h F" . helpful-function)
         ("C-h C" . helpful-command)))

(use-package cape
  :ensure t
  :bind ("C-c p" . cape-prefix-map)
  :init
  ;; first function returning a result wins
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'cape-history)
  (add-hook 'completion-at-point-functions #'cape-elisp-block))

(provide 'heks-emacs/misc)

;;; misc.el ends here
