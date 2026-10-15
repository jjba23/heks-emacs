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

;; Enhances the compilation buffer with what a terminal gives for free: the
;; ANSI escapes a tool writes become colours instead of `[0m' noise in the
;; middle of a line, the output scrolls as it arrives, and the faces of the
;; buffer come from the theme rather than the package's own palette
;; (`fancy-compilation-override-colors' off).
;;
;; It is loaded up front rather than on the first call of
;; `fancy-compilation-mode', which is what `:commands' asked for and why
;; none of this was happening: what the package does, it does by advising
;; `compile' and `compilation-filter' and by a hook of its own, so a mode
;; that is only loaded when it is called has to be called before the first
;; compilation -- a thing nobody remembers to do, since the escape codes
;; only appear once it is too late.  It is the same trap as the one
;; `flymake-collection' below describes, and answered the same way: load it
;; now, and turn it on in `:config'.
(use-package fancy-compilation
  :ensure t
  :demand t
  :config
  (setq fancy-compilation-override-colors nil)
  (fancy-compilation-mode))

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
  ;; Shell scripts are checked by shellcheck through Emacs's own
  ;; `sh-shellcheck-flymake', which `sh-mode' and `bash-ts-mode' register
  ;; themselves (see `shell.el' for what is said to it).  The package
  ;; defaults disable that one in favour of its own shellcheck backend; both
  ;; are turned around here, so that the library's checker is off and
  ;; Emacs's -- which reads shellcheck's JSON output -- is the one that
  ;; runs.  Two of them would report every problem in the buffer twice.
  (let ((shell (assoc '(sh-mode bash-ts-mode) flymake-collection-hook-config)))
    (when shell
      (setcdr shell '((flymake-collection-shellcheck :disabled t)))))
  :hook (;; The backends are registered globally above; Flymake itself still has
         ;; to be started per buffer.  SQL uses the `sql-lint' backend from the
         ;; package defaults, and shell scripts are set up by `shell.el',
         ;; which starts Flymake with its own checkers.
         (emacs-lisp-mode . flymake-mode)
         (sql-mode . flymake-mode)))

;;
;; ====== The checkers a buffer already has ======
;;

;; Eglot manages Flymake opinionatedly.  When it starts managing a buffer it
;; saves the value of `flymake-diagnostic-functions' and replaces it with a
;; list of its own backend alone -- "completely replacing its value", says
;; its manual -- and it puts the saved value back when it stops managing the
;; buffer.  For as long as a server is there, then, the buffer is checked by
;; the server and by nothing else.  The checkers of this configuration are
;; not the server's to take away: `sh-shellcheck-flymake' is registered by
;; Emacs's own shell modes, the linters of the library above by the modes it
;; covers, and the shfmt drift, the OpenAPI check and the rest by modules
;; here.  None of those can say so where the server would hear it, because
;; each of them is registered on its major mode and knows nothing about
;; servers.
;;
;; So the list is put back together in one place, for every language and
;; every buffer: what Eglot saved is exactly what the buffer had, and every
;; backend of it that is not Eglot's own goes back beside it.  A module says
;; what checks its buffers where it belongs, and connecting a server can
;; neither lose a checker nor make a problem be reported twice.

(defun heks-emacs-flymake-keep-backends ()
  "Put a buffer's own Flymake backends back when Eglot manages it.

Eglot replaces `flymake-diagnostic-functions' with a list of its own
backend alone for as long as it manages a buffer, which is what this
function reads the saved value of.  `eglot--saved-bindings' is where
Eglot keeps it -- the place it takes the list from when it stops
managing the buffer -- and every backend of it that is not
`eglot-flymake-backend' is added to the buffer again.  Flymake is then
asked to check the buffer, because the list Eglot left it with is one it
has never reported on.

Nothing here knows a language: a checker registered on its major mode,
by Emacs or by a module of this configuration, survives a server without
that module saying anything about it."
  (when (eglot-managed-p)
    (let ((own (alist-get 'flymake-diagnostic-functions eglot--saved-bindings)))
      (when own
        (dolist (backend own)
          (unless (eq backend 'eglot-flymake-backend)
            (add-hook 'flymake-diagnostic-functions backend nil t)))
        (flymake-start)))))

(add-hook 'eglot-managed-mode-hook #'heks-emacs-flymake-keep-backends)

;; What `python-flymake' -- Emacs's own backend for Python, which
;; `python-base-mode' registers for every Python buffer -- runs where it
;; does: flake8, installed for this user rather than system-wide.  Nothing
;; here puts that backend in a buffer, because the library's own
;; configuration for Python turns it off in favour of its `pycodestyle'
;; backend, as it used to turn the shellcheck of `shell.el' off; this is
;; what Emacs's backend would run rather than what checks a Python buffer
;; here today.  It is kept because it is what one would change to make that
;; backend (and so flake8) the checker of a Python buffer.
(setq python-flymake-command '("~/.local/bin/flake8" "-"))

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
  ;; The workflow, in the order it is run: `init' once, then `validate' and
  ;; `plan' as often as one likes, and `apply' when the plan is the one that
  ;; was wanted.  They live under the workspace topic because a Terraform
  ;; run is a project task, and they take the letters they take everywhere
  ;; else: `v' validates, `p' previews, `a' applies.
  :bind (("C-c w i" . heks-emacs-terraform-init)
         ("C-c w v" . heks-emacs-terraform-validate)
         ("C-c w p" . heks-emacs-terraform-plan)
         ("C-c w a" . heks-emacs-terraform-apply)
         ("C-c w D" . heks-emacs-terraform-destroy))
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

(defun heks-emacs-terraform-root ()
  "Return the directory the Terraform configuration lives in.

That is the project root when the file being edited is in one, and the
file's own directory otherwise, so that the commands work in a project
Emacs does not recognise as well."
  (or (when-let* ((project (project-current)))
        (project-root project))
      (and buffer-file-name (file-name-directory buffer-file-name))
      default-directory))

(defun heks-emacs-terraform-run (subcommand)
  "Run `terraform SUBCOMMAND' in the configuration being edited.

Run through `compile', so its output is a compilation buffer like every
other build: `g' reruns it, `M-n' and `M-p' walk the errors."
  (let ((root (heks-emacs-terraform-root)))
    (unless (executable-find terraform-command)
      (user-error "%s is not installed, so there is nothing to run" terraform-command))
    (let ((default-directory root))
      (compile (concat (shell-quote-argument terraform-command) " " subcommand)))))

(defun heks-emacs-terraform-init ()
  "Initialise the providers and the state of this configuration."
  (interactive)
  (heks-emacs-terraform-run "init"))

(defun heks-emacs-terraform-validate ()
  "Check that the configuration is internally consistent."
  (interactive)
  (heks-emacs-terraform-run "validate"))

(defun heks-emacs-terraform-plan ()
  "Show what applying the configuration would change."
  (interactive)
  (heks-emacs-terraform-run "plan"))

(defun heks-emacs-terraform-apply ()
  "Apply the configuration, which is what changes the infrastructure."
  (interactive)
  (heks-emacs-terraform-run "apply"))

(defun heks-emacs-terraform-destroy ()
  "Destroy the infrastructure this configuration created.

Terraform asks for the name of the workspace to confirm this itself; the
prompt here is the second one, in the vocabulary of the person asking."
  (interactive)
  (unless (yes-or-no-p (format "Destroy the infrastructure in %s? " (heks-emacs-terraform-root)))
    (user-error "Nothing was destroyed"))
  (heks-emacs-terraform-run "destroy"))

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
