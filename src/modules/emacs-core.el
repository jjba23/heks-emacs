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

  :hook ((text-mode . visual-line-mode)
         ((emacs-lisp-mode
           conf-mode
           markdown-mode
           scheme-mode
           diff-mode) . outline-minor-mode))
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

  (setopt treesit-auto-install-grammar 'always) ; EMACS-31
  (setopt treesit-enabled-modes t)              ; EMACS-31

  ;; these might require a manual `M-x treesit-install-language-grammar'
  (add-to-list 'treesit-language-source-alist
               '(kotlin . ("https://github.com/tree-sitter-grammars/tree-sitter-kotlin")))
  (add-to-list 'treesit-language-source-alist
               '(scala . ("https://github.com/tree-sitter/tree-sitter-scala")))

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
          completion-eager-update t               ;; EMACS-31
          completion-eager-display 'auto          ;; EMACS-31
          minibuffer-visible-completions 'up-down ;; EMACS-31
          read-file-name-completion-ignore-case t
          read-buffer-completion-ignore-case t
          completion-ignore-case t
          eldoc-help-at-pt t)

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
  ;; used to be needed pre-Emacs 31
  ;; (setopt treesit-extra-load-path (list "~/.emacs.d/tree-sitter-grammars"))

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

  ;; --- Disable Bidirectional Text Scanning  ---
  ;; If you don’t edit right-to-left languages (like me), Emacs is doing a bunch of work on every redisplay cycle for nothing.
  ;; These settings tell Emacs to assume left-to-right text everywhere and skip the bidirectional parenthesis algorithm:

  (setq-default bidi-display-reordering 'left-to-right
                bidi-paragraph-direction 'left-to-right)

  (setq bidi-inhibit-bpa t)

  ;; --- Skip Fontification During Input ---
  ;; Emacs normally fontifies (syntax-highlights) text even while you’re actively typing.
  ;; This can cause micro-stutters, especially in tree-sitter modes or large buffers.
  ;; One setting fixes it:

  (setq redisplay-skip-fontification-on-input t)

  ;; --- Increase Process Output Buffer for LSP ---
  ;; The default read-process-output-max is 64KB, which is still quite conservative.
  ;; Modern LSP servers like rust-analyzer or clangd routinely send multi-megabyte responses.
  ;; Bumping this reduces the number of read calls Emacs has to make.
  ;; If you use eglot (or lsp-mode), this is basically free performance.

  (setq read-process-output-max (* 6 1024 1024)) ; 6MB

  ;; --- Don’t Render Cursors in Non-Focused Windows ---
  ;; If you have several windows visible, Emacs draws a cursor in each of them – even the ones you’re not working in.
  ;; It also highlights selections in non-focused windows. Two settings to stop that:

  (setq-default cursor-in-non-selected-windows nil)
  (setq highlight-nonselected-windows nil)

  ;; --- Save the Clipboard Before Killing ---
  ;; Here’s a scenario: you copy a URL from your browser, switch to Emacs, kill a line with C-k, and then try to yank the URL you copied earlier with C-y.
  ;; Gone. The kill replaced it on the clipboard.
  ;; This setting makes Emacs save the existing clipboard content into the kill ring before overwriting it:
  ;; Now C-y gets the kill, and M-y gets you back to the URL. Such a small thing, but it eliminates a genuinely annoying problem.

  (setq save-interprogram-paste-before-kill t)

  ;; --- No Duplicates in the Kill Ring ---
  ;; Kill the same line three times and you get three identical entries in the kill ring, wasting slots.
  ;; This deduplicates them:

  (setq kill-do-not-save-duplicates t)

  ;; --- Speedbar ---
  (setopt speedbar-window-default-width 25) ;; EMACS-31
  (setopt speedbar-window-max-width 25)     ;; EMACS-31

  ;; --- VC ---
  (setopt vc-auto-revert-mode t                    ; EMACS-31
          vc-allow-rewriting-published-history t   ; EMACS-31
          vc-dir-auto-hide-up-to-date 'revert)     ; EMACS-31

  ;; -- General niceties ----
  (setopt delete-pair-push-mark t)                    ; EMACS-31: pushes a mark after
                                        ; delete-pair so C-x C-x selects what was inside
  (setopt ibuffer-human-readable-size t)              ; EMACS-31: KB/MB instead of raw byte counts
  (setopt kill-region-dwim 'emacs-word)               ; EMACS-31: C-w with no region kills a word
  (setopt native-comp-async-on-battery-power nil)     ; EMACS-31: stop native-comp jobs on battery
  (setopt view-lossage-auto-refresh t)                ; EMACS-31: live-updating C-h l, great for teaching/debugging
  (setopt display-fill-column-indicator-warning nil)  ; EMACS-31
  (setopt dired-hide-details-hide-absolute-location t); EMACS-31: hide the absolute dir path in dired-hide-details-mode
  (setopt world-clock-sort-order "%FT%T")             ; EMACS-31: sort the world clock sanely
  (setopt zone-all-frames t)                          ; EMACS-31
  (setopt zone-all-windows-in-frame t)                ; EMACS-31
  (setopt uniquify-after-kill-buffer-flag t)          ; EMACS-31: renamed from the -p variant


  ;; --- Persist the Kill Ring Across Sessions ---
  ;; Most configs that use savehist-mode only persist search rings. But savehist can save any variable – including the kill ring.
  ;; Add it and you get clipboard history that survives restarts:

  (setq savehist-additional-variables
        '(search-ring regexp-search-ring kill-ring))

  ;; One thing to watch out for: the kill ring can accumulate text properties (fonts, overlays, etc.) that bloat the savehist file.
  ;; With this you strip them before saving:
  (add-hook 'savehist-save-hook
            (lambda ()
              (setq kill-ring
                    (mapcar #'substring-no-properties
                            (cl-remove-if-not #'stringp kill-ring)))))

  ;; --- Prevent ffap from Pinging Hostnames ---
  ;; Ever had Emacs freeze for a few seconds when you ran find-file-at-point (or a command that uses it internally)?
  ;; If the text under point looks like a hostname – say, something.com in a comment
  ;; ffap tries to ping it to check if it’s reachable. On a slow or firewalled network, that’s a multi-second hang.

  (setq ffap-machine-p-known 'reject)

  ;; --- Faster Mark Popping ---
  ;; The mark ring is one of Emacs’s most underused navigation features.
  ;; Every time you jump somewhere – isearch, M-<, M->, goto-line, imenu, and many more
  ;; Emacs pushes your old position onto the mark ring. C-u C-SPC pops it, jumping you back.
  ;; The annoyance: you need C-u C-SPC every single time.
  ;; With this setting, after the first C-u C-SPC you can keep pressing just C-SPC to continue popping:

  (setq set-mark-command-repeat-pop t)

  ;; --- Trust some directories ---
  (add-to-list 'trusted-content "~/.emacs.d/")
  (add-to-list 'trusted-content "~/Hacking/")
  (add-to-list 'trusted-content "~/Work/")

  ;; --- Auto-Select Help Windows ---
  ;; When you press C-h f or C-h v, Emacs opens the help buffer but leaves your cursor in the original window.
  ;; You almost always want to read the help right away, so you end up pressing C-x o every single time. This fixes it:

  (setq help-window-select t)

  ;; --- Proportional Window Resizing ---
  ;; When you split a window with C-x 2 or C-x 3, Emacs halves the current window.
  ;; If you already have a multi-window layout, this can produce one awkwardly tiny window while others stay large.
  ;; With this setting, all windows in the frame resize proportionally:

  (setq window-combination-resize t)


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
                            (ignore-errors keycast-mode-line))))

  (add-hook 'after-change-major-mode-hook #'my-set-custom-modeline)
  )


(use-package project
  :ensure nil
  :init
  ;; Treat directories with .envrc (direnv) as project roots.
  ;; Essential for Nix/Guix/direnv workflows so project.el knows where the project starts.
  (setq project-vc-extra-root-markers '(".envrc")))

(use-package markdown-ts-mode
  :ensure nil)

(provide 'heks-emacs/emacs-self)

;;; emacs-core.el ends here
