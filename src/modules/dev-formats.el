;;; dev-formats.el --- Data formats, JVM languages and debugging -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>


;;; Commentary:

;; Data formats, JVM languages and debugging.

;;; Code:

(require 'seq)
(require 'subr-x)

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
                  ("HTML" (prettierd))
                  ("Python" (ruff)))))

;; Python is formatted on save by `ruff format' (what `python-black' used to
;; do), and by `C-c i f' through `heks/format-dispatch': the language server
;; (`basedpyright') does not format, so the generic Eglot answer would fail.
(defun heks/python-format-applies-p ()
  "Return non-nil when `ruff' should format this buffer."
  (and (derived-mode-p 'python-base-mode) (executable-find "ruff")))

(add-to-list 'heks/format-dispatch
             (cons #'heks/python-format-applies-p
                   #'format-all-region-or-buffer))

(defun heks/python-format-on-save ()
  "Turn on `format-all-mode' in this Python buffer when `ruff' is installed."
  (when (executable-find "ruff") (format-all-mode 1)))

(add-hook 'python-base-mode-hook #'heks/python-format-on-save)

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
(defun heks/pom-xml-setup ()
  "Apply Maven conventions when visiting a `pom.xml' file.

Besides the indentation this folds elements with Hideshow, shows a
fringe indicator for each foldable element, and starts the XML language
server (`lemminx') when it is installed, which is what checks the file
against the Maven schema."
  (when (and buffer-file-name
             (string= "pom.xml" (file-name-nondirectory buffer-file-name)))
    (setq-local nxml-child-indent 4)
    (setq-local nxml-attribute-indent 4)
    (setq-local tab-width 4)
    (setq-local indent-tabs-mode nil)
    (require 'hideshow)
    (setq-local hs-show-indicators t)
    (hs-minor-mode 1)
    (when (executable-find "lemminx")
      (eglot-ensure))))

(add-to-list 'auto-mode-alist '("pom\\.xml\\'" . nxml-mode))

;; JSON Lines (one JSON value per line, also `.ndjson') is not a single
;; JSON document, so use the plain `js-json-mode' (no tree-sitter parse
;; of the whole buffer, which would flag every line after the first).
(add-to-list 'auto-mode-alist '("\\.\\(?:jsonl\\|ndjson\\)\\'" . js-json-mode))
(add-hook 'nxml-mode-hook #'heks/pom-xml-setup)

;; Spring Boot configuration lives either in `application*.properties'
;; (already handled by `conf-javaprop-mode') or in `application*.yml',
;; which the YAML mode above takes care of.

(use-package pandoc-mode :ensure t)

;; `dape' is the client; it needs a real DAP server to drive, which for a
;; JVM project is the `java-debug' adapter that `heks/jvm-debug'
;; (see `heks-emacs.el') runs and attaches to -- see
;; `heks/java-debug-jar' for where that jar comes from.
;;
;; For C and C++ the server is `gdb' itself: since version 14.1 it speaks
;; the Debug Adapter Protocol (`gdb --interpreter=dap'), so the same dape
;; buffer and the same `C-c b' keys drive a C program and a JVM one.  What
;; this module adds is the part a debugger cannot guess: which binary the
;; build produced, how the project is rebuilt, and -- for a GTK
;; application -- the environment variables that turn a GTK warning from a
;; line in the terminal into a breakpoint that is caught.

(defcustom heks/c-debug-program nil
  "The program `heks/c-debug' starts, or nil to use the one it finds.

Nil means the single executable in the project's build directory, or --
when the build holds several -- the one named after the project.  A
prefix argument to `heks/c-debug' asks for a file instead, which is the
escape hatch for a layout the guess does not know."
  :type '(choice (const :tag "find the built program" nil)
                 (file :tag "a program"))
  :group 'heks)

(defcustom heks/c-debug-args nil
  "The arguments `heks/c-debug' gives the program, in order."
  :type '(repeat string)
  :group 'heks)

(defconst heks/c-debug-build-directories
  '("build" "builddir" "cmake-build-debug" "cmake-build-release")
  "The directories a C project's build output is looked in.

Meson writes to `build/' or `builddir/', CMake to a directory of its
own naming, and this configuration's guess is the four names that cover
what a checkout usually has.")

(defcustom heks/gtk-debug-environment
  '(("G_DEBUG" . "fatal-criticals")
    ("GSK_RENDERER" . "cairo"))
  "The environment `heks/gtk-debug' gives a GTK application.

`G_DEBUG=fatal-criticals' turns a GTK critical -- a widget used after it
was destroyed, a signal connected to nothing -- into an abort, which is
what lets the debugger stop on it instead of printing a line nobody
reads.  `GSK_RENDERER=cairo' asks GTK 4 for its software renderer, so the
program does not start a GPU driver's threads under the debugger; remove
it to debug the renderer itself.  The variables here are added to the
display variables in `heks/gtk-debug-passthrough', because the launch
request's environment is the one the program gets."
  :type '(alist :key-type string :value-type string)
  :group 'heks)

(defconst heks/gtk-debug-passthrough
  '("DISPLAY" "WAYLAND_DISPLAY" "XDG_RUNTIME_DIR" "XDG_SESSION_TYPE"
    "DBUS_SESSION_BUS_ADDRESS" "XAUTHORITY")
  "The environment a GTK program needs to reach the display.

The launch request of a debug adapter describes the program's whole
environment, so the variables the session inherited from the desktop --
which display, which Wayland socket, which session bus -- have to be
named again; without them the program starts under the debugger and
cannot open a window.")

(defun heks/gtk-debug--environment ()
  "Return `heks/gtk-debug-environment' plus the display it was started in."
  (append heks/gtk-debug-environment
          (delq nil
                (mapcar (lambda (name)
                          (let ((value (getenv name)))
                            (and value
                                 (not (string-empty-p value))
                                 (cons name value))))
                        heks/gtk-debug-passthrough))))


(defun heks/c-debug-root (&optional directory)
  "Return the root of the project DIRECTORY is in, or its directory."
  (let ((directory (file-name-as-directory
                    (expand-file-name (or directory default-directory)))))
    (or (ignore-errors
          (when-let* ((project (project-current nil directory)))
            (file-name-as-directory
             (expand-file-name (if (fboundp 'project-root)
                                   (project-root project)
                                 (car (with-no-warnings (project-roots project))))))))
        directory)))

(defun heks/c-debug-source-p (file)
  "Return non-nil when FILE is a source or build artefact, not a program."
  (string-match-p "\\.\\(?:c\\|h\\|cc\\|cpp\\|cxx\\|hpp\\|hh\\|o\\|a\\|so\\(?:\\.[0-9.]+\\)?\\|el\\|py\\|sh\\|txt\\|json\\|md\\|cmake\\|ninja\\|mk\\|log\\)\\'"
                  file))

(defun heks/c-debug-guess-program (&optional root)
  "Return the program this project's build produced, or nil.

The build directories are read for executables that are not sources or
object files.  One is the answer; several are only answered when one is
named after the project, and none is nil -- the caller asks, rather than
starting a debugger on a file that was a guess."
  (or heks/c-debug-program
      (let* ((root (or root (heks/c-debug-root)))
             (binaries
              (seq-mapcat
               (lambda (name)
                 (let ((directory (expand-file-name name root)))
                   (when (file-directory-p directory)
                     (seq-filter (lambda (file)
                                   (and (file-regular-p file)
                                        (file-executable-p file)
                                        (not (heks/c-debug-source-p file))))
                                 (directory-files directory t "\\`[^.].*")))))
               heks/c-debug-build-directories)))
        (cond ((= (length binaries) 1)
               (car binaries))
              ((> (length binaries) 1)
               (let ((name (file-name-nondirectory (directory-file-name root))))
                 (seq-find (lambda (binary)
                             (equal (file-name-nondirectory binary) name))
                           binaries)))
              (t nil)))))

(defun heks/c-debug-build-command (&optional root)
  "Return the command that rebuilds the project at ROOT, or nil.

Meson, CMake and a plain Makefile are the three build systems this
configuration knows how to ask; a project that uses none of them is
built by hand, and the debugger starts the program that is already
there."
  (let* ((root (or root (heks/c-debug-root)))
         (meson (file-exists-p (expand-file-name "meson.build" root)))
         (cmake (file-exists-p (expand-file-name "CMakeLists.txt" root))))
    (cond ((and meson (file-directory-p (expand-file-name "build" root)))
           "meson compile -C build")
          ((and meson (file-directory-p (expand-file-name "builddir" root)))
           "meson compile -C builddir")
          ((and cmake (file-directory-p (expand-file-name "build" root)))
           "cmake --build build")
          ((file-exists-p (expand-file-name "Makefile" root))
           "make")
          (t nil))))

(defun heks/c-debug--debug-build-hint (&optional root)
  "Return the command that would give the project at ROOT a debug build.

Only a build system that has a debug configuration to ask for gets a
hint; a Makefile's flags are the project's own, and this configuration
does not guess them."
  (let* ((root (or root (heks/c-debug-root)))
         (meson (file-exists-p (expand-file-name "meson.build" root)))
         (cmake (file-exists-p (expand-file-name "CMakeLists.txt" root))))
    (cond ((and meson (file-directory-p (expand-file-name "build" root)))
           "meson configure build -Dbuildtype=debug -Ddebug=true")
          ((and meson (file-directory-p (expand-file-name "builddir" root)))
           "meson configure builddir -Dbuildtype=debug -Ddebug=true")
          ((and cmake (file-directory-p (expand-file-name "build" root)))
           "cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug")
          (t nil))))

(defun heks/c-debug--environment-plist (environment)
  "Return ENVIRONMENT as the plist dape wants for `:env'."
  (apply #'append
         (mapcar (lambda (entry)
                   (list (intern (concat ":" (car entry))) (cdr entry)))
                 environment)))

(defun heks/c-debug--dap-capable-p ()
  "Return non-nil when the gdb on `exec-path' speaks the DAP."
  (and (executable-find "gdb")
       (let ((version (ignore-errors (shell-command-to-string "gdb --version"))))
         (and version
              (string-match "GNU gdb[^0-9]*\\([0-9]+\\)\\.\\([0-9]+\\)" version)
              (let ((major (string-to-number (match-string 1 version)))
                    (minor (string-to-number (match-string 2 version))))
                (or (> major 14) (and (= major 14) (>= minor 1))))))))

(defun heks/c-debug--line-info-p (program)
  "Return non-nil when PROGRAM has a line table for its main function.

gdb answers whether a line breakpoint can ever be placed: a binary
compiled without `-g', or stripped, has symbols but no line table, and a
line breakpoint in it stays pending forever.  It is worth one gdb
startup to say so before a session starts, because the session otherwise
looks like it is working while the program runs past every line
breakpoint."
  (when (executable-find "gdb")
    (with-temp-buffer
      (let ((status (ignore-errors
                      (call-process "gdb" nil t nil "-q" "-batch"
                                    "-ex" "info line main" program))))
        (and status (zerop status)
             (string-match-p "^Line [0-9]+ of " (buffer-string)))))))

(defun heks/c-debug--gud (program args root environment)
  "Start PROGRAM under GUD, in ROOT, with ENVIRONMENT set."
  (require 'gdb-mi)
  (let* ((default-directory (file-name-as-directory root))
         (assignments (mapconcat (lambda (entry)
                                   (format "%s=%s"
                                           (car entry)
                                           (shell-quote-argument (cdr entry))))
                                 environment " "))
         (command (concat (if (string-empty-p assignments)
                              ""
                            (concat assignments " "))
                          "gdb -i=mi --args "
                          (mapconcat #'shell-quote-argument
                                     (cons program args) " "))))
    (gdb command)))

(defun heks/c-debug (&optional program args environment)
  "Debug the C program of this project, with dape or GUD.

PROGRAM defaults to the one `heks/c-debug-guess-program' finds in the
build directory; a prefix argument asks for a file instead.  ARGS and
ENVIRONMENT default to `heks/c-debug-args' and no extra environment; the
GTK key passes the variables in `heks/gtk-debug-environment'.

When the gdb is 14.1 or newer, dape drives it over the Debug Adapter
Protocol, so the session is the same `C-c b' buffer and the same
breakpoints as a JVM's; an older gdb is driven by GUD, which is the same
Emacs debugger with fewer faces.  The project is rebuilt first when
`heks/c-debug-build-command' knows how, because debugging a binary from
before the edit is the classic way to chase a bug that is no longer
there."
  (interactive
   (let* ((root (heks/c-debug-root))
          (default (heks/c-debug-guess-program root))
          (program (if (or current-prefix-arg (null default))
                       (read-file-name "Program: " root nil t default)
                     default)))
     (list program nil nil)))
  (let* ((root (heks/c-debug-root))
         (program (expand-file-name
                   (or program
                       (heks/c-debug-guess-program root)
                       (read-file-name "Program: " root nil t))))
         (args (or args heks/c-debug-args))
         (environment (or environment nil))
         (build (heks/c-debug-build-command root)))
    (unless (file-executable-p program)
      (user-error "%s is not an executable" program))
    (unless (heks/c-debug--line-info-p program)
      (message "%s has no line information: line breakpoints will stay pending.%s"
               (file-name-nondirectory program)
               (if-let* ((hint (heks/c-debug--debug-build-hint root)))
                   (format "  Rebuild it with: %s" hint)
                 "")))
    (if (heks/c-debug--dap-capable-p)
        (let ((config (list :name "gdb"
                            :request "launch"
                            :program program
                            :args (vconcat args)
                            :cwd root
                            ;; dape's connection keys are symbols, not
                            ;; keywords: `command', `command-args',
                            ;; `command-cwd' and `compile' are read with
                            ;; `plist-get' against those symbols, and a
                            ;; `:command' is a key dape never looks at.
                            'command "gdb"
                            'command-args (list "--interpreter=dap")
                            'command-cwd root)))
          (when build
            (setq config (plist-put config 'compile build)))
          (when environment
            (setq config (plist-put config :env
                                    (heks/c-debug--environment-plist environment))))
          (dape config))
      (heks/c-debug--gud program args root environment))))

(defun heks/gtk-debug (&optional program)
  "Debug the GTK 4 program of this project, with GTK's warnings fatal.

It is `heks/c-debug' with `heks/gtk-debug-environment': a GTK critical
aborts the program and the debugger stops where it was raised, which is the
only reliable way to get a stack for a warning that would otherwise be a
line on a terminal.  The software renderer is asked for as well, so the
session does not begin inside a GPU driver."
  (interactive
   (let* ((root (heks/c-debug-root))
          (default (heks/c-debug-guess-program root)))
     (list (if (or current-prefix-arg (null default))
               (read-file-name "GTK program: " root nil t default)
             default))))
  (heks/c-debug program nil (heks/gtk-debug--environment)))

(defun heks/gtk-inspector (&optional program)
  "Run the GTK 4 program of this project with the GTK inspector open.

`GTK_DEBUG=interactive' opens the inspector inside the running program:
its picker selects a widget on screen, and the inspector shows that
widget's properties, its CSS and its layout, which is the question a GTK
bug asks first -- what is this widget, and why is it where it is.  The
program runs in a compilation buffer, so its own output is still there."
  (interactive
   (let* ((root (heks/c-debug-root))
          (default (heks/c-debug-guess-program root)))
     (list (if (or current-prefix-arg (null default))
               (read-file-name "GTK program: " root nil t default)
             default))))
  (let* ((root (heks/c-debug-root))
         (program (expand-file-name
                   (or program
                       (heks/c-debug-guess-program root)
                       (read-file-name "GTK program: " root nil t)))))
    (unless (file-executable-p program)
      (user-error "%s is not an executable" program))
    (let ((default-directory (file-name-as-directory root)))
      (compile (format "GTK_DEBUG=interactive %s" (shell-quote-argument program))))
    (message "GTK inspector: its picker selects a widget in the running application")))

(use-package dape
  :ensure t
  :init (setq dape-buffer-window-arrangement 'right)
  ;; `C-c j d' starts and attaches a JVM project's debugger
  ;; (`heks/jvm-debug'); `C-c b' is `dape''s own commands once
  ;; attached -- to any debuggee, JVM or otherwise, which is why it is its
  ;; own topic rather than folded into `j'.  The same topic starts the two
  ;; native debuggers: `d' a C program, `g' a GTK one with its warnings
  ;; fatal, `I' the GTK inspector in a running one.
  :bind (("C-c j d" . heks/jvm-debug)
         ("C-c b d" . heks/c-debug)
         ("C-c b g" . heks/gtk-debug)
         ("C-c b I" . heks/gtk-inspector)
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

(provide 'heks/dev-formats)

;;; dev-formats.el ends here
