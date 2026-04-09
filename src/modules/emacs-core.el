;;; emacs-core.el --- Configuring Emacs core -*- lexical-binding: t -*-

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

;; Configuring Emacs core
;; This file establishes the baseline behavior for Emacs

;;; Code:



;; Configure Flymake (built-in linter)
(use-package flymake
  :ensure nil
  :bind(("C-c ! b" . flymake-show-buffer-diagnostics)
        ("C-c ! n" . flymake-goto-next-error)
        ("C-c ! p" . flymake-show-project-diagnostics)
        ("C-c ! f" . flymake-mode)))

;; Discoverability: Show available keybindings after a short delay
(use-package which-key
  :ensure nil
  :config
  (setq which-key-sort-order 'which-key-key-order-alpha
        which-key-max-description-length 35)
  ;; Fast enough to be useful, slow enough not to flash
  (setq-default which-key-idle-delay 0.4) 
  (which-key-setup-minibuffer)
  (which-key-mode))

;; (use-package nyan-mode
;;   :ensure t
;;   :demand t
;;   :config
;;   (setq nyan-bar-length 12))

;; Custom modeline package
(use-package modusregel
  :ensure (:host codeberg :repo "jjba23/modusregel" :branch "trunk")
  :demand t)

;; Core Emacs Configuration
;; This block is grouped by logical domains for easier reading.
(use-package emacs
  :ensure nil
  :after (modusregel)
  
  ;; --- Global Keybindings ---
  ;; Note: Custom heks-emacs-* functions must be defined elsewhere
  :bind (("C-x C-b" . ibuffer) ; Use the superior interactive buffer menu
         ("C-c a h" . highlight-compare-buffers)
         ("C-c l d" . toggle-debug-on-error)
         ("C-c l e" . eval-buffer)
         ("C-c C-m C-s" . gnus-group-read-ephemeral-group)
         ("C-c u u" . heks-emacs-uuidgen)
         ("C-c # j" . heks-emacs-joe-reconfigure)
         ("C-c # s" . heks-emacs-sys-reconfigure)
         ("C-c # u" . heks-emacs-sys-update)
         ("C-c # f" . heks-emacs-full-reconfigure)
         ("C-c w r" . heks-emacs-project-start-repl-process)
         ("C-c w f" . heks-emacs-project-fmt)
         ("C-c w t" . heks-emacs-project-start-test)
         ("C-c w d" . heks-emacs-project-start-dev)
         ("C-c w s" . heks-emacs-print-random-standup-order)
         ("C-c g l" . guix-package-location-on-mark)
         ("C-c t a" . sort-lines)
         ("C-c t w" . delete-trailing-whitespace)
         ("C-c t c" . display-fill-column-indicator-mode)
         ("C-c t p" . kbd-scheme-make-parameter)
         ("C-c t m" . kbd-scheme-string-to-symbol-in-alist-access)
         ("C-c t h" . kbd-scheme-hygguile-abstraction))
  
  ;; Soft-wrap lines in text-heavy modes
  :hook ((text-mode . visual-line-mode))
  :custom
  ;; Support opening new minibuffers from inside existing minibuffers.
  (enable-recursive-minibuffers t)
  (minibuffer-prompt-properties
   '(read-only t cursor-intangible t face minibuffer-prompt))
  :config
  ;; --- UI & Visual Tweaks ---
  (setq-default line-spacing 6
                pgtk-wait-for-event-timeout 0 ; Fixes input lag on Wayland/PGTK builds
                electric-indent-inhibit t)

  (setopt treesit-font-lock-level 4           ; Maximum syntax highlighting for tree-sitter
          ring-bell-function #'ignore         ; Disable the annoying visual/audio bell
          frame-resize-pixelwise t            ; Allow smooth, gapless window tiling
          use-dialog-box nil                  ; Force prompts to stay in the minibuffer
          fill-column 78)                     ; Standard column width for indicators/wrapping

  (setq-default cursor-type 'bar)             ; Modern pipe cursor instead of standard block
  (global-hl-line-mode +1)                    ; Highlight current line

  ;; --- Editing & Behavior ---
  (setopt backward-delete-char-untabify-method 'hungry ; Deleting whitespace eats all of it at once
          compilation-always-kill t           ; Auto-kill old compilation processes without prompting
          tab-always-indent 'complete         ; Make TAB fallback to completion if already indented
          text-mode-ispell-word-completion nil
          vc-follow-symlinks t                ; Don't ask to follow symlinks to version-controlled files
          delete-by-moving-to-trash t         ; Use system trash instead of permanent deletion
          tab-width 2
          sentence-end-double-space t
          compile-command "maak --list")

  (setq-default indent-tabs-mode nil)         ; Always use spaces instead of tabs
  (global-prettify-symbols-mode +1)           ; Turn standard strings like "lambda" into "λ"

  (defalias 'yes-or-no-p 'y-or-n-p)           ; Type 'y' instead of 'yes' for prompts

  ;; --- Minibuffer & Completion ---
  (setopt read-extended-command-predicate #'command-completion-default-include-p ; Hide irrelevant commands
          completion-cycle-threshold 3        ; Cycle through options if there are 3 or fewer
          read-file-name-completion-ignore-case t
          read-buffer-completion-ignore-case t
          completion-ignore-case t)

  ;; --- State Preservation ---
  (savehist-mode 1)                           ; Remember minibuffer history across sessions
  (save-place-mode 1)                         ; Remember cursor position in previously opened files
  (global-auto-revert-mode 1)                 ; Auto-update buffers if the file changes on disk
  (delete-selection-mode +1)                  ; Typing replaces highlighted text (modern behavior)

  ;; Remember recently opened files
  (recentf-mode 1)
  (setopt recentf-max-menu-items 100
          recentf-max-saved-items 100)

  ;; --- Integrations & Paths ---

  (setopt safe-local-variable-directories
          ;; Whitelist specific Guix directory to prevent constant local-variable security
          (list (string-replace "$HOME" (getenv "HOME") "$HOME/fork/guix/")))

  ;; Load TreeSitter AST syntax lexer and highlighting
  (setopt treesit-extra-load-path (list "~/.emacs.d/tree-sitter-grammars"))

  ;; --- Window Management ---
  ;; Enable Shift+Arrow keys for easy directional window switching
  (when (fboundp 'windmove-default-keybindings)
    (windmove-default-keybindings))

  ;; Frame transparency (requires a compositor like Wayland or Picom)
  (ignore-errors
    (set-frame-parameter nil 'alpha-background 90)
    (add-to-list 'default-frame-alist '(alpha-background . 90)))

  ;; --- File Management (Dired) ---
  (setopt dired-listing-switches "-lAh --group-directories-first" ; Human readable, dirs at the top
          dired-kill-when-opening-new-dired-buffer t)             ; Keep buffer list clean

  (add-to-list 'set-message-functions 'inhibit-message)
  (add-to-list 'inhibit-message-regexps "replicasets\\.apps is forbidden")

  (add-hook 'dired-mode-hook
            (lambda ()
              (dired-hide-details-mode 1)     ; Hide ownership/permissions by default for cleaner look
              (auto-revert-mode)))            ; Auto-refresh dired when files change

  (add-to-list 'auto-mode-alist '("\\.hbs\\'" . html-mode))

  ;; --- Buffer Placement Rules ---
  ;; Tame window popups. Anatomy of a display-buffer-alist entry:
  ;; (BUFFER-MATCHER LIST-OF-DISPLAY-FUNCTIONS &optional PARAMETERS)
  ;; matchers can be an Emacs buffer name regex string or a mode matcher: (derived-mode . typescript-mode)
  (setq display-buffer-alist '(("\\*Occur\\*"
                                (display-buffer-reuse-mode-window
                                 display-buffer-below-selected)
                                (window-height . fit-window-to-buffer)
                                (dedicated . t))
                               ((derived-mode . completion-list-mode)
                                (display-buffer-use-some-window))))

  ;; --- Custom Modeline Construction ---
  (defun my-set-custom-modeline ()
    "Customize mode-line format using modusregel."
    (setq mode-line-format (list
                            modusregel-leading-str
                            modusregel-buffer-name-expr
                            modusregel-buffer-modified-str
                            modusregel-spacer-str
                            
                            ;; Uncomment if nyan-mode is enabled above
                            ;; modusregel-nyan-expr
                            
                            modusregel-spacer-str
                            modusregel-line-number-str
                            modusregel-spacer-str
                            modusregel-buffer-position-str
                            modusregel-spacer-str
                            modusregel-vc-expr
                            modusregel-major-mode-expr
                            modusregel-spacer-str
                            modusregel-flymake-expr
                            keycast-mode-line)))

  (add-hook 'after-change-major-mode-hook #'my-set-custom-modeline)
  )


(use-package project
  :init
  ;; Treat directories with .envrc (direnv) as project roots.
  ;; Essential for Nix/Guix/direnv workflows so project.el knows where the project starts.
  (setq project-vc-extra-root-markers '(".envrc")))

(provide 'heks-emacs/emacs-self)

;;; emacs-core.el ends here

