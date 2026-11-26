;;; elixir.el --- Elixir: Mix's tasks, an IEx and a Phoenix page -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Elixir: Mix's tasks, an IEx and a Phoenix page.
;;
;; An Elixir project has one tool that does everything to it -- `mix' --
;; which is the shape Rust's `cargo' and the JVM's build tools have, so the
;; topic is the same shape too: `C-c E' is Elixir, and the letters under it
;; are the scheme's own.  `b' builds, `B' builds what ships, `t' tests, `f'
;; formats, `l' lints, `r' runs an IEx, `e' evaluates, `u' fetches the
;; dependencies, `U' updates them, `T' is their tree, `c' cleans, `d' puts a
;; breakpoint in, and `x' runs the task this project has and this
;; configuration has never heard of.  That last one is not a fallback but
;; the point: an Elixir project's tasks are its own (`ecto.migrate',
;; `phx.server', `credo', `release'), and the key that runs one asks for its
;; name rather than guessing at a list that would be wrong by the next
;; dependency.
;;
;; Everything runs through `compile', so a Mix task is the same compilation
;; buffer as a Cargo or a Maven one: `C-c ! n' walks the errors and `g' runs
;; it again.  The compilation regexps Elixir writes are read by Emacs's own
;; `elixir' rule in `compilation-error-regexp-alist-alist'.
;;
;; The editor support is Emacs's, not a package's: `elixir-ts-mode' for
;; `.ex' and `.exs' and `heex-ts-mode' for the templates Phoenix writes a
;; page in, both folded by `treesit-fold' and both served by Eglot when a
;; language server is installed (see `modules/eglot.el': Next LS and
;; ElixirLS are both looked for).  Formatting is `mix format', the one
;; formatter the language has, reached by `C-c E f' and by `C-c i f' like
;; every other language's (see `heks/format-dispatch').
;;
;; One thing here is Emacs's own and not a library's: `mix format' is a Mix
;; task, so it needs a project to run in, and a file being edited is
;; usually not at the top of one.  `heks/elixir-root' walks up to the
;; nearest `mix.exs' -- the project the file belongs to, which is what mix
;; itself does -- and the formatter runs there.

;;; Code:

(require 'subr-x)

(defconst heks/elixir-manifest "mix.exs"
  "The file that makes a directory an Elixir project.

A project is what has one of these at its root, which is the only
definition worth using: mix itself looks no higher than the nearest one,
and an umbrella's own `mix.exs' is a different project from the
application inside it.")

;;;
;;; The project and its tasks
;;;

(defun heks/elixir-root (&optional directory)
  "Return the directory of the Mix project DIRECTORY is in, or nil.

The nearest `mix.exs' is the answer, because that is the project the file
belongs to -- an application inside an umbrella has a manifest of its own,
and that is the one mix compiles."
  (heks/parent-with heks/elixir-manifest directory))

(defun heks/elixir--mix (arguments &optional environment)
  "Run `mix ARGUMENTS' in this buffer's project, and say what it said.

The run is `heks/run-task', so ARGUMENTS is a list of strings quoted one
by one, ENVIRONMENT is a literal assignment in front of the command
(`MIX_ENV=prod'), and the output goes to a compilation buffer, which is
where every other build in this configuration goes and where the errors
are links."
  (heks/run-task "mix" arguments environment heks/elixir-manifest))

(defun heks/elixir-compile ()
  "Compile this project, by `mix compile'."
  (interactive)
  (heks/elixir--mix '("compile")))

(defun heks/elixir-release ()
  "Build this project's release, by `mix release'.

The release is built in the `prod' environment, which is the one a
release is built in: `MIX_ENV=dev mix release' is a release compiled
against the development configuration, and that is a surprise nobody
wants to have twice."
  (interactive)
  (heks/elixir--mix '("release") "MIX_ENV=prod"))

(defun heks/elixir-test (&optional failed)
  "Run this project's tests, by `mix test'.

With a prefix argument only the tests that failed last time are run
(`mix test --failed'), which is the loop a failing test is fixed in --
the same test, again, without waiting for the ones that passed."
  (interactive "P")
  (heks/elixir--mix (if failed '("test" "--failed") '("test"))))

(defun heks/elixir-lint ()
  "Compile this project with its warnings treated as errors.

Warnings are the linter Elixir itself has -- an unused variable, a
clause that cannot match, a deprecated function -- and a project that
fails `mix compile --warnings-as-errors' is a project whose warnings are
nobody's problem.  A linter the project carries of its own (`credo') is
run by `C-c E x'."
  (interactive)
  (heks/elixir--mix '("compile" "--warnings-as-errors")))

(defun heks/elixir-deps-get ()
  "Fetch the dependencies this project's `mix.lock' pins."
  (interactive)
  (heks/elixir--mix '("deps.get")))

(defun heks/elixir-deps-update ()
  "Update the dependencies of this project, within `mix.exs'."
  (interactive)
  (heks/elixir--mix '("deps.update" "--all")))

(defun heks/elixir-deps-tree ()
  "Show the dependency tree of this project."
  (interactive)
  (heks/elixir--mix '("deps.tree")))

(defun heks/elixir-clean ()
  "Delete this project's build output, by `mix clean'."
  (interactive)
  (heks/elixir--mix '("clean")))

(defun heks/elixir-task (task)
  "Run the Mix TASK named, with its arguments.

The name is split on spaces and handed to mix as arguments, so
`ecto.migrate -r App.Repo' is the task and the argument it needs.  This
is the key for the tasks a project has and this configuration does not
know: `phx.server', `credo', `ecto.rollback', `hex.outdated'."
  (interactive (list (read-string "Mix task: ")))
  (let ((arguments (split-string task " " t)))
    (when (null arguments)
      (user-error "No Mix task named"))
    (heks/elixir--mix arguments)))

(defun heks/elixir-eval (code)
  "Evaluate CODE in this project, by `mix run -e'.

CODE is passed as one argument, so an expression with spaces, quotes or
a `#' in it arrives at `Code.eval_string' as it was written.  The region
is evaluated when there is one, and the minibuffer asks otherwise."
  (interactive
   (list (if (use-region-p)
             (buffer-substring-no-properties (region-beginning) (region-end))
           (read-string "Elixir to evaluate: "))))
  (when (string-empty-p (string-trim code))
    (user-error "Nothing to evaluate"))
  (heks/elixir--mix (list "run" "-e" code)))

;;;
;;; The REPL, and breaking into it
;;;

(defun heks/elixir-iex ()
  "Start this project's IEx, in a terminal buffer of its own.

`iex -S mix' is the session an Elixir project is worked in: the project's
own code is compiled and loaded, its dependencies are there, and its
`Mix.Task's are runnable by name.  It is a real terminal rather than a
comint buffer because IEx brings its own line editor -- history, the
completion of modules and functions, `h' -- and taking that away to
reimplement it in Emacs is a worse trade here than in most languages."
  (interactive)
  (let ((root (or (heks/elixir-root)
                  (user-error "No %s above %s" heks/elixir-manifest
                              default-directory))))
    (unless (executable-find "iex")
      (user-error "iex is not on `exec-path'"))
    (let ((default-directory root))
      (heks/run-in-terminal "iex" "iex" "-S" "mix"))))

(defun heks/elixir-pry ()
  "Insert an `IEx.pry()' breakpoint above this line, at its indentation.

`IEx.pry/0' is a function, so it needs no `require' and works in an IEx
as well as in a test: the code that runs next stops there and the session
takes over, which is what a breakpoint is in a language whose debugger is
the REPL.  The line goes above the one point is on, so the expression
below it is the one evaluated with the session attached."
  (interactive)
  (save-excursion
    (back-to-indentation)
    (let ((column (current-column)))
      (beginning-of-line)
      (insert (make-string column ?\s) "IEx.pry()\n"))))

;;;
;;; Formatting: mix format
;;;

(defun heks/elixir-format-applies-p ()
  "Return non-nil when `mix format' has something to say about this buffer."
  (and (derived-mode-p 'elixir-ts-mode 'heex-ts-mode)
       (heks/tool-available-p "mix")
       (heks/elixir-root)))

(defun heks/elixir-format-command (file)
  "Return the `mix format' command that rewrites FILE in place.

`mix format' reads the project's `.formatter.exs', which is where the
formatter's plugins and its import of a dependency's rules are written --
so it is the project's formatter and not a generic one.  A `.heex' file
is formatted too, when the project's formatter names the LiveView
plugin, which is how Phoenix's own templates are formatted."
  (list (heks/tool-path "mix") "format" file))

(defun heks/elixir-format-buffer ()
  "Format the current buffer in place with `mix format'."
  (interactive)
  (unless (heks/tool-available-p "mix")
    (user-error "`mix' is not installed, so there is nothing to format with"))
  (unless (heks/elixir-root)
    (user-error "No %s above %s" heks/elixir-manifest default-directory))
  (heks/tool-format-buffer
   (list :what "mix format"
         :command #'heks/elixir-format-command
         ;; `mix' works from the project and not from the subdirectory the
         ;; file happens to be in: there is no `mix.exs' down there.
         :root #'heks/elixir-root)))

;; `C-c i f' is the format key in every buffer, and what it runs is the
;; buffer's own answer: an Elixir file is formatted by the project's
;; formatter, which is the only one that knows the project's rules.
(add-to-list 'heks/format-dispatch
             (cons #'heks/elixir-format-applies-p
                   #'heks/elixir-format-buffer))

;;;
;;; The modes
;;;

;; Both are Emacs's own: `elixir-ts-mode' comes with Emacs 29 and
;; `heex-ts-mode', the template language Phoenix writes a page in, with
;; Emacs 30.  Their grammars are built with the others (see
;; `treesit-grammars.el'), and `treesit-fold' folds both of them (see
;; `dev-folding.el').
(use-package elixir-ts-mode
  :ensure nil
  :mode ("\\.ex\\'" "\\.exs\\'"))

(use-package heex-ts-mode
  :ensure nil
  :mode "\\.heex\\'")

;; A `mix.lock' is an Elixir map of the dependencies and the versions they
;; are pinned to, and Emacs opens it as `fundamental-mode'.  What one opens
;; it for is reading a version out of it, and occasionally editing one, so
;; it is opened as the Elixir it is.
(add-to-list 'auto-mode-alist '("\\`mix\\.lock\\'" . elixir-ts-mode))

;;;
;;; The keys
;;;

;; Mix is the project's tool wherever the buffer is, so the keys are global
;; rather than bound to an Elixir buffer's map: a `mix.exs', a `.ex' file,
;; a `.heex' template, a README that says what to run -- the project is
;; found from any of them (`heks/elixir-root' walks up to the manifest), and
;; the key says why when there is none.

(keymap-set global-map "C-c E b" #'heks/elixir-compile)
(keymap-set global-map "C-c E B" #'heks/elixir-release)
(keymap-set global-map "C-c E t" #'heks/elixir-test)
(keymap-set global-map "C-c E f" #'heks/elixir-format-buffer)
(keymap-set global-map "C-c E l" #'heks/elixir-lint)
(keymap-set global-map "C-c E r" #'heks/elixir-iex)
(keymap-set global-map "C-c E e" #'heks/elixir-eval)
(keymap-set global-map "C-c E u" #'heks/elixir-deps-get)
(keymap-set global-map "C-c E U" #'heks/elixir-deps-update)
(keymap-set global-map "C-c E T" #'heks/elixir-deps-tree)
(keymap-set global-map "C-c E c" #'heks/elixir-clean)
(keymap-set global-map "C-c E d" #'heks/elixir-pry)
(keymap-set global-map "C-c E x" #'heks/elixir-task)

(provide 'heks/elixir)

;;; elixir.el ends here
