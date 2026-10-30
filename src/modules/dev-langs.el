;;; dev-langs.el --- Language modes for development -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>


;;; Commentary:

;; Language modes for development.

;;; Code:

;; Configures Emacs for Rust development, providing syntax highlighting,
;; indentation, and other language-specific features.
(use-package rust-mode :ensure t)

(use-package inheritenv :ensure t)

;; Provides a linter for Emacs Lisp packages, helping to ensure code quality
;; and adherence to best practices.
(use-package package-lint :ensure t)

;; Python: `basedpyright' is the language server (see `eglot.el'), `ruff' is
;; the linter and formatter.  Ruff runs as a Flymake backend through
;; `flymake-ruff' rather than as a second server, because Eglot manages one
;; server per buffer; `heks/flymake-keep-backends' keeps the backend next to
;; Eglot's own.  Formatting on save is `ruff format' via `format-all'
;; (see `dev-formats.el').  Both tools read `pyproject.toml'.
(use-package flymake-ruff
  :ensure t
  :commands (flymake-ruff-load))

(defun heks/python-setup ()
  "Check this Python buffer with ruff rather than flake8, when ruff is installed."
  (when (executable-find "ruff")
    (remove-hook 'flymake-diagnostic-functions #'python-flymake t)
    (flymake-ruff-load)))

(add-hook 'python-base-mode-hook #'heks/python-setup)

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

;; Hideshow cannot fold indentation-based YAML, Tree-sitter can: when the
;; grammar is there `yaml-mode' buffers become `yaml-ts-mode' ones, which
;; `treesit-fold' (below) folds, with fringe indicators.
;; The grammar check happens when a buffer opens, not when this file loads,
;; because the grammar directory may be configured after this point.
(defun heks/yaml-ts-mode ()
  "Use `yaml-ts-mode' when its grammar is available, else `yaml-mode'."
  (if (and (fboundp 'yaml-ts-mode)
           (treesit-language-available-p 'yaml))
      (yaml-ts-mode)
    (yaml-mode)))
(add-to-list 'major-mode-remap-alist '(yaml-mode . heks/yaml-ts-mode))

(provide 'heks/dev-langs)

;;; dev-langs.el ends here
