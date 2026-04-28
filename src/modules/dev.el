;;; dev.el --- Dev configuration for Emacs -*- lexical-binding: t -*-

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

;; Dev configuration for Emacs

;;; Code:

;; Configures Emacs for Rust development, providing syntax highlighting,
;; indentation, and other language-specific features.
(use-package rust-mode :ensure t)

(use-package inheritenv :ensure t)

;; Provides a linter for Emacs Lisp packages, helping to ensure code quality
;; and adherence to best practices.
(use-package package-lint :ensure t)

;; Integrates the Black formatter for Python, automatically formatting Python
;; code on save to maintain consistent style.
(use-package python-black
  :ensure t
  :after python
  :hook (python-mode . python-black-on-save-mode-enable-dwim))

;; Configures Emacs for Haskell development, enabling syntax highlighting
;; and other features for Haskell files.
(use-package haskell-mode :ensure t :mode "\\.hs\\'")

;; Sets up Emacs for Scala development using tree-sitter, providing
;; advanced parsing and features for Scala files.
(use-package scala-ts-mode :ensure t :mode "\\.scala\\'")

;; Configures Emacs for Lua development, offering syntax highlighting
;; and basic support for Lua files.
(use-package lua-mode :ensure t :mode "\\.lua\\'")

;; Sets up Emacs for TypeScript development, providing syntax highlighting
;; and other features for TypeScript files.
(use-package typescript-mode :ensure t :mode "\\.ts\\'")

;; Configures Emacs for Nix development using tree-sitter,
;; enabling advanced parsing and features for Nix files.
(use-package nix-ts-mode
  :ensure t
  :mode "\\.nix\\'")

;; Sets up Emacs for TOML file editing, providing syntax highlighting and
;; basic support for TOML files.
(use-package toml-mode :ensure t :mode "\\.toml\\'")

;; Configures Emacs for YAML file editing, offering syntax highlighting and
;; basic support for YAML files.
(use-package yaml-mode :ensure t :mode "\\.\\(e?ya?\\|ra\\)ml\\'")

;; Enables smart handling of parentheses and other delimiters in programming modes,
;; assisting with balanced expressions.
(use-package smartparens
  :ensure t
  :hook ((prog-mode . smartparens-mode))
  :config
  (require 'smartparens-config))

;; Integrates direnv with Emacs, allowing automatic loading and unloading
;; of environment variables based on directory.
(use-package direnv
  :ensure t
  :bind (("C-c d d" . direnv-mode)
         ("C-c d a" . direnv-allow)))

;; Provides aggressive indentation for Lisp-like languages,
;; automatically formatting code as you type.
(use-package aggressive-indent
  :ensure t
  :hook ((emacs-lisp-mode . aggressive-indent-mode)
         ;; in Scheme I usually just use Guix format
         ;; which auto-formats my files nicely
         ;;
         ;;otherwise feel free to turn this on
         ;; (scheme-mode . aggressive-indent-mode)
         (lisp-mode . aggressive-indent-mode)))

;; Configures Emacs for editing Dockerfile and .dockerignore files using tree-sitter.
(use-package dockerfile-ts-mode
  :ensure nil
  :mode (("\\Dockerfile\\'" . dockerfile-ts-mode)
         ("\\.dockerignore\\'" . dockerfile-ts-mode))
  :config
  (setq dockerfile-mode-command "podman"))

;; Provides an interface for interacting with Docker from within Emacs,
;; allowing management of containers and images.
(use-package docker
  :ensure t
  :bind ("C-c d c" . docker))

;; Provides a good Scheme REPL integration with Emacs and Guile Ares
(use-package arei
  :ensure (:host github :repo "abcdw/emacs-arei" :branch "master")
  :demand t
  :hook ((scheme-mode . arei-mode)))

;; Provides Geiser for Scheme/Racket development, with an interactive
;; environment and language support.
(use-package geiser
  :ensure t
  :init
  (setq geiser-active-implementations '(guile))
  (setq geiser-mode-auto-p nil)
  (ignore-errors
    (define-key scheme-mode-map (kbd "C-c i f") #'heks-emacs-guix-fmt)))

;; Specifically provides Geiser support for the Guile Scheme implementation.
(use-package geiser-guile
  :ensure t)

;; Provdes a REPL session management tool for Emacs and more.
(use-package sesman
  :ensure (:host github :repo "vspinu/sesman" :branch "master")
  :demand t)

;; Enhances the compilation buffer with fancy features, improving the
;; readability and usability of compilation output.
(use-package fancy-compilation
  :ensure t
  :commands (fancy-compilation-mode)
  :config
  (setq fancy-compilation-override-colors nil))

;; Provides visual diff highlighting in the margin,
;; showing changes relative to version control.
(use-package diff-hl
  :ensure t
  :config
  (global-diff-hl-mode)
  (setopt diff-hl-margin-symbols-alist
          '((insert . "+") (delete . "-") (change . "~")
            (unknown . "?") (ignored . "i")))
  (diff-hl-margin-mode)
  (ignore-errors
    (add-hook 'magit-post-refresh-hook 'diff-hl-magit-post-refresh)
    (add-hook 'dired-mode-hook
              (lambda () (diff-hl-dired-mode))))
  (ignore-errors
    (set-face-attribute 'diff-hl-change nil
                        :background 'unspecified)
    (set-face-attribute 'diff-hl-insert nil
                        :background 'unspecified)
    (set-face-attribute 'diff-hl-delete nil
                        :background 'unspecified)))

(with-eval-after-load 'compile
  (fancy-compilation-mode))

;; Configures Emacs for Markdown file editing, enabling specific display
;; modes and custom functions for Markdown files.
(use-package markdown-mode
  :ensure t
  :mode "\\.md\\'"
  :hook ((markdown-mode . heks-emacs-markdown-mode))
  :config
  (defun heks-emacs-markdown-mode ()
    (variable-pitch-mode 1)
    (auto-fill-mode 0)
    (visual-line-mode 1)
    (ignore-errors (heks-emacs-set-base-faces))))

;; Provides a library for making HTTP requests from Emacs Lisp.
(use-package request
  :ensure t)

;; Sets up a collection of Flymake backends for various languages,
;; enabling on-the-fly syntax checking and linting.
(use-package flymake-collection
  :ensure t
  :hook ((after-init . flymake-collection-hook-setup)
         (emacs-lisp-mode . flymake-mode)))

;; Configures Emacs for editing JSON files, providing
;; syntax highlighting and formatting.
(use-package json-mode
  :ensure (:host github :repo "json-emacs/json-mode"))

;; Provides interactive ways for working with
;; OpenAPI/Swagger specifications from Emacs.
(use-package swagg
  :ensure (:host github :repo "isamert/swagg.el"))

(use-package format-all
  :ensure t
  :commands format-all-mode
  :bind ("C-c i p" . format-all-region-or-buffer)
  :config
  (setq-default format-all-formatters
                '(("CSS"     (prettierd))
                  ("HTML" (prettierd)))))

(use-package just-mode
  :ensure t)

(use-package justl
  :ensure t)

(use-package kotlin-ts-mode
  :ensure t
  :mode ("\\.kt\\'" "\\.kts\\'"))

(use-package pandoc-mode :ensure t)

;; TODO work on debugger support (use GUD? Realgud? DAPE?)
;; (use-package dape
;;   :ensure t
;;   :init (setq dape-buffer-window-arrangement 'gud))

(use-package graphql-mode
  :ensure t)

(use-package kubernetes
  :ensure (:host github :repo "kubernetes-el/kubernetes-el" :branch "master")
  :commands (kubernetes-overview)
  :config
  (setq kubernetes-poll-frequency 3600
        kubernetes-redraw-frequency 3600))

(use-package dumb-jump
  :ensure t
  :custom
  (dumb-jump-prefer-searcher 'rg)
  (xref-show-definitions-function #'consult-xref)
  :config
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate))

(use-package treesit-fold
  :ensure t
  :commands (treesit-fold-close
             treesit-fold-close-all
             treesit-fold-open
             treesit-fold-toggle
             treesit-fold-open-all
             treesit-fold-mode
             global-treesit-fold-mode
             treesit-fold-open-recursively
             treesit-fold-line-comment-mode)

  :custom
  (treesit-fold-line-count-show t)
  (treesit-fold-line-count-format " ▼")

  :hook ((
          bash-ts-mode
          c++-ts-mode
          c-ts-mode
          cmake-ts-mode
          css-ts-mode
          dockerfile-ts-mode
          elixir-ts-mode
          go-mod-ts-mode
          go-ts-mode
          heex-ts-mode
          html-ts-mode
          java-ts-mode
          js-ts-mode
          json-ts-mode
          kotlin-ts-mode
          lua-ts-mode
          nix-ts-mode
          php-ts-mode
          python-ts-mode
          ruby-ts-mode
          rust-ts-mode
          scala-ts-mode
          toml-ts-mode
          tsx-ts-mode
          tsx-ts-mode
          typescript-ts-mode
          yaml-ts-mode
          ) . treesit-fold-mode)

  :config
  (set-face-attribute 'treesit-fold-replacement-face nil
                      :foreground (face-attribute 'default :foreground)
                      :box nil
                      :weight 'bold))

(use-package kirigami
  :ensure t
  :bind (("C-c v o" . kirigami-open-fold)
         ("C-c v O" . kirigami-open-fold-rec)
         ("C-c v r" . kirigami-open-folds)
         ("C-c v c" . kirigami-close-fold)
         ("C-c v m" . kirigami-close-folds)
         ("C-c v a" . kirigami-toggle-fold)))

(use-package stripspace
  :ensure t
  :hook ((prog-mode . stripspace-local-mode)
         (text-mode . stripspace-local-mode)
         (conf-mode . stripspace-local-mode))

  :custom
  ;; The `stripspace-only-if-initially-clean' option:
  ;; - nil to always delete trailing whitespace.
  ;; - Non-nil to only delete whitespace when the buffer is clean initially.
  ;; (The initial cleanliness check is performed when `stripspace-local-mode'
  ;; is enabled.)
  (stripspace-only-if-initially-clean nil)

  ;; Enabling `stripspace-restore-column' preserves the cursor's column position
  ;; even after stripping spaces. This is useful in scenarios where you add
  ;; extra spaces and then save the file. Although the spaces are removed in the
  ;; saved file, the cursor remains in the same position, ensuring a consistent
  ;; editing experience without affecting cursor placement.
  (stripspace-restore-column t))

(use-package elisp-autofmt
  :ensure t
  :commands (elisp-autofmt-mode elisp-autofmt-buffer)
  :hook (emacs-lisp-mode . elisp-autofmt-mode))


(provide 'heks-emacs/dev)

;;; dev.el ends here
