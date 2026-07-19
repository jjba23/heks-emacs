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
  :if (and heks-emacs-theme
           (string-match-p "\\`\\(ef-\\|modus-\\)" (symbol-name heks-emacs-theme)))
  :config
  (setq modus-themes-mixed-fonts t
        modus-themes-italic-constructs t)
  (modus-themes-include-derivatives-mode 1)

  ;; Handle theme-specific overrides dynamically
  (pcase heks-emacs-theme
    ('modus-vivendi-tinted
     (setq modus-vivendi-tinted-palette-overrides '((comment "#928f8a"))))
    ('ef-bio
     (setq ef-bio-palette-overrides '((variable fg-main) (string green-faint))))
    ('ef-cyprus
     (setq ef-cyprus-palette-overrides '((variable fg-main) (bg-main bg-dim) (string green-faint))))
    ('ef-melissa-light
     (setq ef-melissa-light-palette-overrides '((variable fg-main) (string green-warmer))))
    ('ef-autumn
     (setq ef-autumn-palettes-overrides '((variable fg-main) (bg-main bg-dim)))))

  (load-theme heks-emacs-theme t))

(use-package everforest
  :ensure (:host github :repo "Theory-of-Everything/everforest-emacs" :branch "master2")
  :no-require t
  :if (memq heks-emacs-theme '(everforest-dark everforest-light))
  :config
  (load-theme (if (eq heks-emacs-theme 'everforest-dark)
                  'everforest-hard-dark
                'everforest-hard-light)
              t))

(use-package gruvbox-theme
  :ensure (:host github :repo "greduan/emacs-theme-gruvbox" :branch "master")
  :if (memq heks-emacs-theme '(gruvbox-dark gruvbox-light))
  :config
  (load-theme (if (eq heks-emacs-theme 'gruvbox-dark)
                  'gruvbox-dark-hard
                'gruvbox-light-hard)
              t))

(use-package dracula-theme
  :ensure t
  :if (eq heks-emacs-theme 'dracula)
  :config
  (load-theme heks-emacs-theme t)
  (setq dracula-enlarge-headings t
        dracula-height-title-1 1.25
        dracula-height-title-2 1.15
        dracula-height-title-3 1.05
        dracula-height-doc-title 1.4
        dracula-alternate-mode-line-and-minibuffer nil))

(use-package catppuccin-theme
  :ensure t
  :if (memq heks-emacs-theme '(catppuccin-latte catppuccin-mocha))
  :config
  (setq catppuccin-italic-comments t)
  (setopt catppuccin-flavor (if (eq heks-emacs-theme 'catppuccin-latte) 'latte 'mocha))
  (load-theme 'catppuccin t))

(use-package autothemer :ensure t)

(use-package rose-pine
  :ensure (:host github :repo "thongpv87/rose-pine-emacs" :branch "master" :main "rose-pine-color-theme.el")
  :after (autothemer)
  :no-require t
  :if (memq heks-emacs-theme '(rose-pine-moon rose-pine-dawn))
  :config
  (load-theme heks-emacs-theme t))

(use-package kaolin-themes
  :ensure t
  :if (eq heks-emacs-theme 'kaolin-dark)
  :config
  (setq kaolin-themes-bold t
        kaolin-themes-italic t
        kaolin-themes-underline t
        kaolin-themes-modeline-border nil
        kaolin-themes-underline-wave nil
        kaolin-themes-distinct-metakeys nil
        kaolin-themes-italic-comments t
        kaolin-themes-hl-line-colored t
        kaolin-themes-distinct-fringe t
        kaolin-themes-git-gutter-solid t)
  (load-theme 'kaolin-dark t))

(use-package doom-themes
  :ensure t
  :if (memq heks-emacs-theme '(doom-tomorrow-night doom-one nord tokyo-night solarized-light solarized-dark doom-one-light doom-molokai))
  :custom
  (doom-themes-enable-bold t)
  (doom-themes-enable-italic t)
  :config
  ;; Dynamic mapping for mismatched theme names
  (let ((theme (pcase heks-emacs-theme
                 ('nord 'doom-nord)
                 ('tokyo-night 'doom-tokyo-night)
                 ('solarized-light 'doom-solarized-light)
                 ('solarized-dark 'doom-solarized-dark)
                 (_ heks-emacs-theme))))
    (load-theme theme t))

  (doom-themes-visual-bell-config)
  (doom-themes-neotree-config)
  (doom-themes-treemacs-config)
  (doom-themes-org-config))

(use-package kanagawa-theme
  :ensure (:host github :repo "arouene/emacs-kanagawa-theme" :branch "main")
  :if (memq heks-emacs-theme '(kanagawa))
  :config
  (load-theme 'kanagawa t))

(provide 'heks-emacs/theme)

;;; theme.el ends here
