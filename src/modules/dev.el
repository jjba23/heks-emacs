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
;; of environment variables based on directory.  The environment a project
;; needs is its own topic, `C-c e', which Docker and the databases used to
;; share with it.
(use-package direnv
  :ensure t
  :bind (("C-c e d" . direnv-mode)
         ("C-c e a" . direnv-allow)))

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
;; allowing management of containers and images.  Containers are their own
;; topic: `C-c c d' starts Docker and `C-c d p' is a database.
(use-package docker
  :ensure t
  :bind (("C-c c d" . docker)))

;; Scheme, Guile and Guix development live in `modules/guile.el': Geiser for
;; the REPL, the completion, the debugger and the call hierarchy; the Guile
;; compiler and `guix lint' for checking, `guix style' for formatting, and
;; the folding keys shared with the other languages.  Guix is optional
;; there: without it the module is a plain Guile setup.

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
  ;; `compile' can be loaded before Elpaca has activated `fancy-compilation'
  ;; (an early `require', such as Flymake's, does that), so load it here
  ;; instead of assuming that it is already there.
  (when (require 'fancy-compilation nil t)
    (fancy-compilation-mode)))

;; Provides a library for making HTTP requests from Emacs Lisp.
(use-package request
  :ensure t)

;; Sets up a collection of Flymake backends for various languages,
;; enabling on-the-fly syntax checking and linting.
(use-package flymake-collection
  :ensure t
  ;; Deferred loading has to be forced here: the package is only reachable
  ;; through the `:hook' entries below, and adding
  ;; `flymake-collection-hook-setup' to `after-init-hook' -- as the package
  ;; suggests -- does not work with Elpaca, which installs the library while
  ;; `after-init-hook' is already running, so that entry is never reached and
  ;; no backend would ever be registered.  Loading it up front and calling the
  ;; setup from `:config' registers every backend the library configures.
  :demand t
  :config
  (flymake-collection-hook-setup)
  :hook (;; The backends are registered globally above; Flymake itself still has
         ;; to be started per buffer.  SQL uses the `sql-lint' backend from the
         ;; package defaults.
         (emacs-lisp-mode . flymake-mode)
         (sql-mode . flymake-mode)))

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
  ;; No keys: formatting is `C-c i f' everywhere, and this is the last
  ;; resort that key falls back to when the buffer has no language server
  ;; and no language-specific formatter.  The commands are kept in the
  ;; autoloads, because the dispatcher decides at call time.
  :commands (format-all-region-or-buffer format-all-buffer format-all-mode)
  :config
  (setq-default format-all-formatters
                '(("CSS"     (prettierd))
                  ("HTML" (prettierd)))))

(use-package just-mode
  :ensure t)

(use-package justl
  :ensure t)

;;
;; ====== JVM: Java, Kotlin, Maven, Gradle and Spring ======
;;

;; Kotlin through Tree-sitter.  The `.kts' association also covers the
;; Gradle Kotlin DSL files (`build.gradle.kts', `settings.gradle.kts').
(use-package kotlin-ts-mode
  :ensure t
  :mode (("\\.kt\\'" . kotlin-ts-mode)
         ("\\.kts\\'" . kotlin-ts-mode)))

;; Groovy is the language of classic Gradle build scripts and of
;; Jenkinsfiles, both of which are plain Groovy with a declarative shape.
(use-package groovy-mode
  :ensure t
  :mode (("\\.gradle\\'" . groovy-mode)
         ("\\`Jenkinsfile\\'" . groovy-mode)
         ("\\`Jenkinsfile\\..+\\'" . groovy-mode)))

;; `pom.xml' already opens in nxml-mode (XML files carrying a declaration
;; are detected through `magic-mode-alist'), so what is left is Maven's own
;; four-space indentation, applied buffer-locally.
(defun heks-emacs-pom-xml-setup ()
  "Apply Maven conventions when visiting a `pom.xml' file."
  (when (and buffer-file-name
             (string= "pom.xml" (file-name-nondirectory buffer-file-name)))
    (setq-local nxml-child-indent 4)
    (setq-local nxml-attribute-indent 4)
    (setq-local tab-width 4)
    (setq-local indent-tabs-mode nil)))

(add-to-list 'auto-mode-alist '("pom\\.xml\\'" . nxml-mode))
(add-hook 'nxml-mode-hook #'heks-emacs-pom-xml-setup)

;; Spring Boot configuration lives either in `application*.properties'
;; (already handled by `conf-javaprop-mode') or in `application*.yml',
;; which the YAML mode above takes care of.

(use-package pandoc-mode :ensure t)

;; TODO work on debugger support (use GUD? Realgud? DAPE?)
;; (use-package dape
;;   :ensure t
;;   :init (setq dape-buffer-window-arrangement 'gud))

(use-package graphql-mode
  :ensure t
  :mode ("\\.graphql\\'" "\\.graphqls\\'"))

(use-package kubed
  :ensure (:host github :repo "eshelyaron/kubed" :branch "master"))

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
  ;; No keys either: `C-c v c/o/r/t' dispatch to whichever folding engine
  ;; the buffer has, and kirigami is the fallback for the modes that have
  ;; neither Tree-sitter folds nor Hideshow.
  :commands (kirigami-open-fold
             kirigami-open-fold-rec
             kirigami-open-folds
             kirigami-close-fold
             kirigami-close-folds
             kirigami-toggle-fold
             kirigami-mode)
  :config
  ;; kirigami answers with the first engine in its list whose mode is on,
  ;; and `outline-minor-mode' is on in almost every buffer here.  In the
  ;; buffers where `hs-minor-mode' was turned on deliberately -- a Scheme
  ;; buffer, which folds its definitions with it -- that deliberate choice
  ;; has to win, or `C-c v c' folds headings that a Scheme file does not
  ;; have.  The list is reordered rather than rewritten, so an engine
  ;; kirigami adds later is still used wherever Hideshow is off.
  (setq kirigami-fold-list
        (append (seq-filter (lambda (entry) (memq 'hs-minor-mode (car entry)))
                            kirigami-fold-list)
                (seq-remove (lambda (entry) (memq 'hs-minor-mode (car entry)))
                            kirigami-fold-list))))

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

(use-package editorconfig
  :ensure nil
  :config
  (editorconfig-mode 1))

(use-package maak.el
  :ensure (:host codeberg :repo "jjba23/maak.el" :branch "trunk")
  :demand t
  :bind ("C-c m r" . maak-run-task))

(use-package meson-mode
  :ensure (:host github :repo "wentasah/meson-mode" :branch "master"))

;;
;; ====== Terraform and HCL ======
;;

;; Generic HCL: `.hcl' files (including `.terraform.lock.hcl') and Nomad jobs.
(use-package hcl-mode
  :ensure t
  :mode ("\\.hcl\\'" "\\.nomad\\'"))

(use-package terraform-mode
  :ensure t
  :mode (("\\.tf\\'" . terraform-mode)
         ("\\.tfvars\\'" . terraform-mode))
  :hook ((terraform-mode . heks-emacs-terraform-setup))
  :custom
  (terraform-indent-level 2)
  :config
  ;; `terraform fmt' on save and `terraform-ls' over Eglot, both guarded on
  ;; the executable being available so that visiting a .tf file never
  ;; fails on a machine without the Terraform toolchain.
  (defun heks-emacs-terraform-setup ()
    "Enable Terraform formatter and language server when available."
    (when (executable-find terraform-command)
      (terraform-format-on-save-mode 1))
    (when (executable-find "terraform-ls")
      (heks/eglot-ensure))))

;;
;; ====== Databases: SQL, PostgreSQL and MongoDB ======
;;

;; SQL editing: PostgreSQL is the default dialect, keywords are upper-cased
;; as they are typed, and Flymake lints the buffer with `sql-lint' when that
;; tool is installed (see the flymake-collection setup above).
(use-package sql
  :ensure nil
  :mode (("\\.sql\\'" . sql-mode))
  ;; Leave `sql-postgres-login-params' at its default: it already offers the
  ;; database names of the server for completion.  `sql.el' reads the
  ;; `sql-server', `sql-port', `sql-user' and `sql-database' variables when
  ;; it connects, which `heks-emacs-sql-postgres' fills in from the
  ;; environment.
  :custom
  (sql-product 'postgres))

(use-package sqlup-mode
  :ensure t
  :hook (sql-mode . sqlup-mode))

;; `mongosh' scripts are JavaScript; `C-c d m' (see `heks-emacs-mongosh')
;; opens an interactive shell in a real terminal buffer.
(add-to-list 'auto-mode-alist '("\\.mongo\\(sh\\)?\\'" . js-mode))

(provide 'heks-emacs/dev)

;;; dev.el ends here
