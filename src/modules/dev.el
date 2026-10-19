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

;; `dape' is the client; it needs a real DAP server to drive, which for a
;; JVM project is the `java-debug' adapter that `heks-emacs-jvm-debug'
;; (see `heks-emacs.el') runs and attaches to -- see
;; `heks-emacs-java-debug-jar' for where that jar comes from.
(use-package dape
  :ensure t
  :init (setq dape-buffer-window-arrangement 'right)
  ;; `C-c j d' starts and attaches a JVM project's debugger
  ;; (`heks-emacs-jvm-debug'); `C-c b' is `dape''s own commands once
  ;; attached -- to any debuggee, JVM or otherwise, which is why it is its
  ;; own topic rather than folded into `j'.
  :bind (("C-c j d" . heks-emacs-jvm-debug)
         ("C-c b b" . dape-breakpoint-toggle)
         ("C-c b c" . dape-continue)
         ("C-c b n" . dape-next)
         ("C-c b i" . dape-step-in)
         ("C-c b o" . dape-step-out)
         ("C-c b r" . dape-repl)
         ("C-c b k" . dape-kill)))

(use-package graphql-mode
  :ensure t
  :mode ("\\.graphql\\'" "\\.graphqls\\'"))

(use-package kubed
  :ensure (:host github :repo "eshelyaron/kubed" :branch "master")
  ;; `kubed-prefix-map' is the package's own bundle of direct commands
  ;; (`p' pods, `d' deployments, `j' jobs, `L' logs, `k' the transient
  ;; dispatcher below, and so on -- see `kubed-prefix-map' for the full
  ;; list); `C-c U' opens `kubed-transient' straight away, the discoverable
  ;; menu version of the same commands, for when the mnemonic under
  ;; `C-c u' is not remembered.  Kept off `C-c k'/`C-c K': that is one typo
  ;; away from `C-c k' buffer-killing commands elsewhere, and a stray `D'
  ;; (delete) or `R' (run) landing in the wrong cluster is not a mistake
  ;; worth being one key-chord away from.
  :bind (("C-c u" . kubed-prefix-map)
         ("C-c U" . kubed-transient)))

;;
;; ====== JSON-lines log viewing (pretty-print + field filtering) ======
;;

;; Pretty-prints and filters streaming logs in-place, in whatever buffer is
;; receiving them.  It handles mixed log shapes line by line: a line that
;; parses as a JSON object (Spring Boot style structured logs, among
;; others) is reformatted and can be filtered by field value; any other
;; line -- a plain-text log, a stack trace continuation line, a banner --
;; is left exactly as printed and can still be filtered by a regexp on its
;; raw text.  So it is just as usable on an app that never emits JSON as
;; on one that does, and on buffers mixing both (e.g. a JVM banner
;; followed by JSON log lines).
;;
;; It is a plain minor mode rather than its own process/viewer, so it
;; attaches to any buffer that keeps appending log lines: a `tail -f'
;; process, a `compilation-mode' buffer, or `kubed's own log buffers (see
;; `kubed-logs-setup-hook' below) -- `kubed' manages the `kubectl logs'
;; process itself, this mode only reformats and hides lines in its output.
(defvar-local json-log-view--filter nil
  "Predicate (lambda (PLIST) => bool) selecting visible lines.
PLIST has `:json' (the parsed JSON object, or nil if the line did not
parse as one) and `:text' (the line's original raw text).  Nil means
every line is visible.")

(defvar-local json-log-view--processed-pos nil
  "Marker up to which buffer text has already been pretty-printed.")

(define-minor-mode json-log-view-mode
  "Pretty-print and filter streaming logs in this buffer.

Lines that parse as a JSON object are reformatted in place into a
fixed-width \"timestamp level logger message\" rendering, coloured by
level, and can be hidden (not deleted) by field value with
`json-log-view-filter'.  Lines that are not JSON are left untouched, so
this mode is safe to enable on apps that log plain text, and they can
still be hidden by raw-text regexp with `json-log-view-grep-filter'.
Works incrementally, so it keeps up with a buffer that a process keeps
appending to.

\\{json-log-view-mode-map}"
  :lighter " JSONLog"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c C-f") #'json-log-view-filter)
            (define-key map (kbd "C-c C-g") #'json-log-view-grep-filter)
            (define-key map (kbd "C-c C-c") #'json-log-view-clear-filter)
            (define-key map (kbd "C-c C-t") #'json-log-view-transient)
            map)
  (if json-log-view-mode
      (progn
        (setq json-log-view--processed-pos (copy-marker (point-min)))
        (json-log-view--process-region (point-min) (point-max))
        (add-hook 'after-change-functions #'json-log-view--after-change nil t))
    (remove-hook 'after-change-functions #'json-log-view--after-change t)
    (json-log-view--show-all)))

(defun json-log-view--after-change (&rest _)
  "Reformat any newly appended complete lines."
  (json-log-view--process-region json-log-view--processed-pos (point-max)))

(defun json-log-view--process-region (start end)
  "Reformat every complete log line between START and END."
  (save-excursion
    (goto-char start)
    (let ((inhibit-modification-hooks t))
      (while (re-search-forward "\n" end t)
        (json-log-view--process-line (line-beginning-position 0) (1- (point)))
        (set-marker json-log-view--processed-pos (point))))))

(defun json-log-view--process-line (start end)
  "Reformat the log line between START and END, JSON or not.

A line that parses as a JSON object is replaced by its pretty rendering;
any other line (plain text, stack trace, banner, malformed JSON) is left
exactly as it was.  Either way the line gets an overlay carrying its data
so it can be filtered uniformly."
  (let* ((text (buffer-substring-no-properties start end))
         (obj (and (string-prefix-p "{" (string-trim text))
                   (ignore-errors (json-parse-string text :object-type 'alist))))
         (line (list :json obj :text text))
         (visible (or (null json-log-view--filter)
                      (funcall json-log-view--filter line))))
    (when obj
      (delete-region start end)
      (goto-char start)
      (insert (json-log-view--format obj))
      (setq end (point)))
    (let ((ov (make-overlay start end)))
      (overlay-put ov 'json-log-view-line line)
      (unless visible
        (overlay-put ov 'invisible t)))))

(defun json-log-view--format (obj)
  "Render parsed JSON OBJ as a single colourised log line."
  (let ((level (alist-get 'level obj)))
    (propertize
     (format "%-23s %-5s %-30s %s"
             (or (alist-get 'timestamp obj) (alist-get '@timestamp obj) "")
             (or level "")
             (or (alist-get 'logger_name obj) (alist-get 'logger obj) "")
             (or (alist-get 'message obj) ""))
     'face (pcase level
             ("ERROR" 'error)
             ("WARN" 'warning)
             (_ 'default)))))

(defun json-log-view-filter (field value)
  "Show only log lines whose JSON FIELD equals VALUE.

FIELD and VALUE are read as strings; FIELD is looked up as a JSON key in
each line that parsed as JSON (e.g. \"level\", \"logger_name\").  Lines
that are not JSON never match a field filter and are hidden by it; use
`json-log-view-grep-filter' instead on logs that are not JSON."
  (interactive "sField: \nsValue: ")
  (setq json-log-view--filter
        (lambda (line)
          (when-let* ((obj (plist-get line :json)))
            (equal (format "%s" (alist-get (intern field) obj)) value))))
  (json-log-view--reapply-filter))

(defun json-log-view-grep-filter (regexp)
  "Show only log lines whose raw text matches REGEXP.

Unlike `json-log-view-filter', this works the same whether a line is
JSON or plain text, since it matches against the line as it was
originally printed -- the right tool for apps that do not log JSON."
  (interactive "sFilter regexp: ")
  (setq json-log-view--filter
        (lambda (line) (string-match-p regexp (plist-get line :text))))
  (json-log-view--reapply-filter))

(defun json-log-view-clear-filter ()
  "Remove any active filter, showing every log line again."
  (interactive)
  (setq json-log-view--filter nil)
  (json-log-view--reapply-filter))

(defun json-log-view--reapply-filter ()
  "Recompute visibility of every already-processed line."
  (dolist (ov (overlays-in (point-min) (point-max)))
    (when-let* ((line (overlay-get ov 'json-log-view-line)))
      (overlay-put ov 'invisible
                   (and json-log-view--filter
                        (not (funcall json-log-view--filter line)))))))

(defun json-log-view--show-all ()
  "Make every line in the buffer visible again."
  (dolist (ov (overlays-in (point-min) (point-max)))
    (overlay-put ov 'invisible nil)))

;; `kubed-logs' runs `kubed-logs-setup-hook' in its freshly created log
;; buffer, before starting the `kubectl logs' process -- the log buffer is
;; otherwise plain `fundamental-mode', so this hook is the only place to
;; attach behaviour to it without advising `kubed-logs' itself.
(with-eval-after-load 'kubed
  (add-hook 'kubed-logs-setup-hook #'json-log-view-mode))

;; A small transient gathering the filter commands above, in the same
;; style as `kubed-transient' and its "friends" (`kubed-transient-logs'
;; and so on).  It is meant to be called from inside a buffer that has
;; `json-log-view-mode' on -- i.e. a `kubed' log buffer, or any other log
;; buffer the mode was turned on in by hand -- which is also what its
;; `C-c C-t' binding in `json-log-view-mode-map' is for.
(require 'transient)
(transient-define-prefix json-log-view-transient ()
  "Filter and reset the log view in the current buffer."
  ["Log view"
   ("f" "Filter by JSON field" json-log-view-filter)
   ("g" "Filter by regexp" json-log-view-grep-filter)
   ("c" "Clear filter" json-log-view-clear-filter)])

;; Folded into `kubed-transient' itself, right next to "Logs", so that
;; once you are looking at a log buffer that command opened, filtering it
;; is one more key away through the same menu rather than a separate one
;; to remember.
(with-eval-after-load 'kubed-transient
  (transient-append-suffix 'kubed-transient "l"
    '("f" "Filter log buffer" json-log-view-transient)))

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
