;;; theme.el --- Themes and look/feel for Emacs -*- lexical-binding: t -*-

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

;; Themes and look/feel for Emacs UI/UX/DX

;;; Code:

(use-package ef-themes
  :ensure (:host github :repo "protesilaos/ef-themes" :branch "main")
  :config
  (setq modus-themes-mixed-fonts t
        modus-themes-italic-constructs t)
  (modus-themes-include-derivatives-mode 1)
  (cond ((equal heks-emacs-theme 'ef-dream) (load-theme heks-emacs-theme t))
        ((equal heks-emacs-theme 'ef-bio)
         (setq ef-bio-palette-overrides '((variable fg-main)
                                          (string green-faint)))
         (load-theme heks-emacs-theme t))
        ((equal heks-emacs-theme 'modus-vivendi)
         (load-theme heks-emacs-theme t))
        ((equal heks-emacs-theme 'ef-cyprus)
         (setq ef-cyprus-palette-overrides '((variable fg-main)
                                             (bg-main bg-dim)
                                             (string green-faint)))
         (load-theme heks-emacs-theme t))
        ((equal heks-emacs-theme 'ef-melissa-light)
         (setq ef-melissa-light-palette-overrides '((variable fg-main)
                                                    (string green-warmer)))
         (load-theme heks-emacs-theme t))
        ((equal heks-emacs-theme 'ef-tritanopia-dark) (load-theme heks-emacs-theme t))
        ((equal heks-emacs-theme 'ef-autumn)
         (setq ef-autumn-palette-overrides '((variable fg-main)
                                             (bg-main bg-dim)))
         (load-theme heks-emacs-theme t))))


(use-package solarized-theme
  :ensure (:host github :repo "bbatsov/solarized-emacs" :branch "master")
  :config
  (cond ((equal heks-emacs-theme 'solarized-light) (load-theme heks-emacs-theme t))))

(use-package everforest
  :ensure (:host github :repo "Theory-of-Everything/everforest-emacs" :branch "master2")
  :no-require t
  :config
  (cond ((equal heks-emacs-theme 'everforest-hard-dark)
         (load-theme heks-emacs-theme t))
        ((equal heks-emacs-theme 'everforest-hard-light)
         (load-theme heks-emacs-theme t))))

(use-package gruvbox-theme
  :ensure (:host github :repo "greduan/emacs-theme-gruvbox" :branch "master")
  :config
  (cond ((equal heks-emacs-theme 'gruvbox-dark-hard) (load-theme heks-emacs-theme t))
        ((equal heks-emacs-theme 'gruvbox-light-hard) (load-theme heks-emacs-theme t))))

(use-package dracula-theme
  :ensure t
  :config
  (cond ((equal heks-emacs-theme 'dracula)
         (progn
           (load-theme heks-emacs-theme t)
           ;; Tweak the font size for some headings and titles
           (setq dracula-enlarge-headings t)

           ;; Adjust font size of titles level 1 (default 1.3)
           (setq dracula-height-title-1 1.25)

           ;; Adjust font size of titles level 2 (default 1.1)
           (setq dracula-height-title-2 1.15)

           ;; Adjust font size of titles level 3 (default 1.0)
           (setq dracula-height-title-3 1.05)

           ;; Adjust font size of document titles (default 1.44)
           (setq dracula-height-doc-title 1.4)

           ;; Use less pink and bold on the mode-line and minibuffer (default nil)
           (setq dracula-alternate-mode-line-and-minibuffer nil)))
        ))

(use-package catppuccin-theme
  :ensure t
  :config
  (cond ((equal heks-emacs-theme 'catppuccin-latte)
         (setq catppuccin-italic-comments t)
         (setopt catppuccin-flavor 'latte)
         (load-theme 'catppuccin t))
        ((equal heks-emacs-theme 'catppuccin-mocha)
         (setq catppuccin-italic-comments t)
         (setopt catppuccin-flavor 'mocha)
         (load-theme 'catppuccin t)))
  )

(use-package kaolin-themes
  :ensure t
  :config
  (setq kaolin-themes-bold t
        kaolin-themes-italic t
        kaolin-themes-underline t)


  (setq kaolin-themes-modeline-border nil
        kaolin-themes-underline-wave nil
        kaolin-themes-distinct-metakeys nil
        kaolin-themes-italic-comments t
        kaolin-themes-hl-line-colored t
        kaolin-themes-distinct-fringe t
        kaolin-themes-git-gutter-solid t)

  (cond ((equal heks-emacs-theme 'kaolin-dark)
         (load-theme 'kaolin-dark t))))

(provide 'heks-emacs/theme)

;;; theme.el ends here
