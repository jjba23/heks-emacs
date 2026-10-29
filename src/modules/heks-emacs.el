;;; heks-emacs.el --- heks-emacs configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; heks-emacs configuration for Emacs

;;; Code:

(defgroup heks ()
  "HEKS-EMACS customization group."
  :group 'tools)

(defcustom heks/clone-dir nil
  "The directory where the HEKS-EMACS source code is located."
  :type 'string)

(defcustom heks/notes-dir nil
  "The directory where the Org notes should be stored."
  :type 'string)


(defun heks/notes-directory ()
  "Return the directory the Org notes live in, or nil when none is set.

`heks/notes-dir' is a string the user's own configuration gives a
value to, because no checkout can know where somebody keeps their notes: the
bridge installed next to this configuration sets it.  A directory that was
never set -- or set to nothing -- is not a directory, and nil is how a caller
says so rather than building a path out of it, which is what pointing
the notes at an empty string would do."
  (let ((directory (and (stringp heks/notes-dir)
                        (string-trim heks/notes-dir))))
    (when (and directory (not (string-empty-p directory)))
      (file-truename (string-replace "$HOME" "~" directory)))))

(defcustom heks/theme nil
  "The name of the Emacs theme to use, acording to HEKS-EMACS palette."
  :type 'symbol)

(defcustom heks/font-mono "IBM Plex Mono"
  "The font family to use for monospaced fonts."
  :type 'string)

(defcustom heks/font-sans "IBM Plex Sans"
  "The font family to use for sans-serif fonts."
  :type 'string)

(defcustom heks/font-serif "IBM Plex Serif"
  "The font family to use for serif fonts."
  :type 'string)

(defcustom heks/base-font-size 11.4
  "Base font size, in points, for buffers and UI chrome.

Every face whose size HEKS-EMACS sets is expressed relative to this
value, and this value itself is scaled by `tekengrootte-scale' (see
`heks/font-height')."
  :type 'number)

(defcustom heks/prose-scale 1.0
  "Relative size of the `variable-pitch' (prose) face.

Org and Markdown body text uses this face.  A value of 1.0 keeps prose
at the base size, values below 1.0 make it smaller and values above
1.0 make it larger."
  :type 'number)

(defcustom heks/window-divider-contrast 0.45
  "How far window separators are blended toward the theme foreground.

0.0 makes separators invisible, 1.0 paints them with the foreground
color.  This is used for every theme not listed in
`heks/window-divider-colors', so separators stay visible
regardless of which palette is active."
  :type 'number)

(defcustom heks/window-divider-colors
  '((dracula . "#6272a4"))
  "Alist of theme names to explicit window separator colors.

Themes that are not listed get a separator color derived from their
background and foreground, guaranteeing a visible separator in every
palette."
  :type '(alist :key-type symbol :value-type (string :tag "Color")))

(defcustom heks/window-divider-places t
  "Where dividers between windows are displayed.

`t' displays dividers on the right and on the bottom of windows,
`right-only' only separates horizontally split windows and
`bottom-only' only separates vertically split windows."
  :type '(choice (const :tag "Right and bottom" t)
                 (const :tag "Right only" right-only)
                 (const :tag "Bottom only" bottom-only)))

(defcustom heks/standup-people '("Joe" "Giga" "Yury" "Semih" "Soroush" "Eduard" "Andrian" "Viktoria" "René")
  "The people's names to be used for random standup order."
  :type '(repeat string))

(defcustom heks/standup-buffer-name "*Random Standup Order*"
  "The name of the buffer where we should show a random standup order."
  :type 'string)

(defun heks/joe-reconfigure ()
  "Rebuild GNU Guix Joe's configs."
  (interactive)
  (let ((default-directory (string-replace "$HOME" "~" heks/clone-dir)))
    (async-shell-command "maak jr")))

(defun heks/full-reconfigure ()
  "Fully Rebuild GNU Guix Joe's configs and Joe's user."
  (interactive)
  (let ((default-directory (string-replace "$HOME" "~" heks/clone-dir)))
    (async-shell-command "maak fr")))

(defun heks/sys-reconfigure ()
  "Rebuild GNU Guix Joe's configs."
  (interactive)
  (let ((default-directory (string-replace "$HOME" "~" heks/clone-dir)))
    (async-shell-command "maak sr")))

(defun heks/sys-update ()
  "Update GNU Guix packages."
  (interactive)
  (let ((default-directory (string-replace "$HOME" "~" heks/clone-dir)))
    (async-shell-command "maak update")))

(defun heks/uuidgen ()
  "Generate a UUID (Universally Unique Identifier) and yank it to kill ring."
  (interactive)
  (let ((uid (string-replace "\n" "" (shell-command-to-string "uuidgen"))))
    (message (format "generated UUID: %s" uid))
    (kill-new uid)))

(defun heks/uuidgen-string ()
  "Generate a UUID (Universally Unique Identifier) string.

This function executes the `uuidgen` command-line utility and returns
the generated UUID as a string, removing any trailing newline character
that the command might produce.  It relies on the `uuidgen` program
being available in your system's `exec-path`."
  (string-replace "\n" "" (shell-command-to-string "uuidgen")))

(defun heks/do-in-project (f)
  "Execute a function F with the root directory of a project as its argument.

F: A function that accepts a single argument, which will be the root
   directory of the current version control project (a string).

This function uses `vc-root-dir` to determine the root directory of the
version control system (like Git, Mercurial, etc.) associated with the
currently visited file or the current directory.  If a project root is
found, it then calls the provided function F, passing the root directory
as the sole argument.  If no version control root directory is found, F
will be called with `nil`.

This function is useful for performing actions that need to be executed
within the context of a project's root directory, such as running build
commands, formatters, or linters."
  (funcall f (vc-root-dir)))

(defun async-shell-to-buffer (cmd buf-name)
  "Execute a shell command asynchronously and display its output in a buffer.

CMD: The shell command to execute (a string).
BUF-NAME: The name of the buffer to display the output in (a string).

This function creates a new buffer with the given BUF-NAME and then
executes the CMD using `async-shell-command`.  The standard output and
standard error of the command are redirected to the newly created
buffer, allowing the user to continue working in Emacs while the
command runs in the background.  The buffer will be displayed when the
command starts producing output."
  (let ((output-buffer (generate-new-buffer buf-name)))
    (async-shell-command cmd output-buffer output-buffer)))

(defun heks/project-start-repl-process ()
  "Start a REPL process for the current project using `make repl`.

This command attempts to locate the root directory of the current project
and then executes `make repl` within that directory in an asynchronous
shell process.  The output and interaction will be
available in a dedicated buffer named \"repl:PROJECT-ROOT\", where
PROJECT-ROOT is the name of the project's root directory.

It relies on `heks/do-in-project` to determine the project root. Before
running the `make` command, it inserts a separator and a message
indicating the start of the project REPL session, along with the
project directory, into the output buffer. If a buffer with the same
name already exists, it is automatically closed without prompting.

This command is designed to easily initiate a project-specific REPL
environment defined by a `Makefile` with a `repl` target, facilitating
interactive development and testing."
  (interactive)
  (heks/do-in-project (lambda(root-dir)
                       (let* ((sep "==============================================")
                              (msg (format "%s\nstarting a project REPL process for %s\n%s\n" sep root-dir sep))
                              (cmd (format "echo \"%s\" && cd %s && maak repl" msg root-dir))
                              (buf-name (format "repl:%s" root-dir)))
                         (ignore-errors
                           (with-current-buffer buf-name
                             (progn
                               (set-buffer-modified-p nil)
                               (kill-matching-buffers-no-ask buf-name))))
                         (async-shell-to-buffer cmd buf-name)))))

(defun heks/project-fmt ()
  "Start the formatting process for the current project using `make fmt`.

This command attempts to find the root directory of the current project
and then executes `make fmt` within that directory in an asynchronous
shell process.  The output of the formatting process will be displayed
in a dedicated buffer named \"fmt:PROJECT-ROOT\", where PROJECT-ROOT is
the name of the project's root directory.

It uses `heks/do-in-project` to identify the project root. Before
running the `make` command, it prints a separator and a message
indicating the start of the formatting process, along with the project
directory, in the output buffer. If a buffer with the same name
already exists, it is automatically closed without prompting.

This command is intended to easily initiate a project-wide code
formatting procedure defined by a `Makefile` with an `fmt` target,
helping to maintain consistent code style across the project."
  (interactive)
  (heks/do-in-project (lambda(root-dir)
                       (let* ((sep "==============================================")
                              (msg (format "%s\nstarting format process for %s\n%s\n" sep root-dir sep))
                              (cmd (format "echo \"%s\" && cd %s && maak fmt" msg root-dir))
                              (buf-name (format "fmt:%s" root-dir)))
                         (ignore-errors
                           (with-current-buffer buf-name
                             (progn
                               (set-buffer-modified-p nil)
                               (kill-matching-buffers-no-ask buf-name))))
                         (async-shell-to-buffer cmd buf-name)))))

(defun heks/project-start-dev ()
  "Start a development session for the current project using `make dev`.

This command attempts to locate the root directory of the current project
and then executes `make dev` within that directory in an asynchronous
shell process.  The output and interaction will be
available in a dedicated buffer named \"dev:PROJECT-ROOT\", where
PROJECT-ROOT is the name of the project's root directory.

It relies on `heks/do-in-project` to determine the project root. Before
running the `make` command, it inserts a separator and a message
indicating the start of the project DEV session, along with the
project directory, into the output buffer. If a buffer with the same
name already exists, it is automatically closed without prompting.

This command is designed to easily initiate a project-specific DEV
environment defined by a `Makefile` with a `dev` target, facilitating
interactive development and testing."
  (interactive)
  (heks/do-in-project (lambda(root-dir)
                       (let* ((sep "==============================================")
                              (msg (format "%s\nstarting a dev session for %s\n%s\n" sep root-dir sep))
                              (cmd (format "echo \"%s\" && cd %s && maak dev" msg root-dir))
                              (buf-name (format "dev:%s" root-dir)))
                         (ignore-errors
                           (with-current-buffer buf-name
                             (progn
                               (set-buffer-modified-p nil)
                               (kill-matching-buffers-no-ask buf-name))))
                         (async-shell-to-buffer cmd buf-name)))))

(defun heks/project-start-test ()
  "Start the test suite for the current project using `make test`.

This command attempts to locate the root directory of the current project
and then executes `make test` within that directory in an asynchronous
shell process.  The output of the test execution will be displayed in a
dedicated buffer named \"test:PROJECT-ROOT\", where PROJECT-ROOT is the
name of the project's root directory.

It uses `heks/do-in-project` to identify the project root. Before
running the `make` command, it prints a separator and a message
indicating the start of the testing process, along with the project
directory, in the output buffer. If a buffer with the same name
already exists, it is automatically closed without prompting.

This command is intended to easily initiate the project's test suite,
as defined by a `Makefile` with a `test` target, facilitating the
process of verifying the project's functionality."
  (interactive)
  (heks/do-in-project (lambda(root-dir)
                       (let* ((sep "==============================================")
                              (msg (format "%s\nstarting tests for %s\n%s\n" sep root-dir sep))
                              (cmd (format "echo \"%s\" && cd %s && maak test" msg root-dir))
                              (buf-name (format "test:%s" root-dir)))
                         (ignore-errors
                           (with-current-buffer buf-name
                             (progn
                               (set-buffer-modified-p nil)
                               (kill-matching-buffers-no-ask buf-name))))
                         (async-shell-to-buffer cmd buf-name)))))


(defun heks/guix-fmt ()
  "Format the current buffer in place using `guix style`.

This command will:
1. Determine the absolute path of the current buffer's file.
2. Execute the `guix style` command with the `-f` (format) option,
   applying the Guix code style to the file.
3. Revert the buffer, reloading the formatted content from disk.
4. Display informative messages in the minibuffer indicating the
   start and completion of the formatting process.

Note: This command assumes that the `guix` command-line utility is
installed and accessible in your system's `exec-path'.  The file name is
quoted, so a path with spaces in it does not turn into several arguments."
  (interactive)
  (let ((path (file-truename (or buffer-file-name
                                 (user-error "The buffer is not visiting a file")))))
    (message "formatting current buffer with Guix style")
    (shell-command (format "guix style -f %s" (shell-quote-argument path)))
    (revert-buffer :ignore-auto :noconfirm)
    (message "formatted current buffer with Guix style")))

(defun heks/new-buffer-with-json (buffer-name data)
  "Create a new buffer with JSON data, format it, and switch to it.

Creates a new buffer with the specified BUFFER-NAME and inserts the
JSON string DATA into it.  It then attempts to set the major mode to
`js-json-mode` and pretty-print the JSON data with ordered keys.
Finally, it switches to the newly created buffer and scrolls to the top.

BUFFER-NAME: The name of the new buffer (a string).
DATA: A string containing JSON data."
  (get-buffer-create buffer-name)
  (with-current-buffer buffer-name
    (insert data)
    (ignore-errors
      (js-json-mode)
      (json-pretty-print-buffer-ordered)))
  (switch-to-buffer buffer-name)
  (scroll-down 10000))


(defun guix-package-location-on-mark ()
  "Report where the Guix package named by the active region is defined.

Emacs-Guix answers this from its own index of the Guix checkout, so it is
only available where Emacs-Guix is installed; elsewhere the region is
reported as unanswerable rather than as an error from a missing library."
  (interactive)
  (unless (and (require 'guix nil t)
               (require 'guix-package nil t))
    (user-error "Emacs-Guix is not installed, so package locations are unknown here"))
  (unless (use-region-p)
    (user-error "Select the name of a Guix package first"))
  (let* ((target-package (buffer-substring-no-properties (region-beginning) (region-end)))
         (loc (guix-package-location target-package))
         (clean-loc (if (not loc)
                        (format "Error! Could not find %s as valid Guix package" target-package)
                      (format "Found package %s at: %s" target-package (car (string-split loc ":"))))))
    (message clean-loc)))

(defun hugot-shuffle (ls)
  "Fast vector-based shuffle, return LS in a shuffled way."
  (let* ((vec (seq-into ls 'vector))
         (length (length vec))
         (n 0))
    (while (< n length)
      (let ((i (+ n (random (- length n))))
            (tmp (aref vec n)))
        (setf (aref vec n) (aref vec i)
              (aref vec i) tmp))
      (cl-incf n))
    (if (vectorp ls)
        vec
      (seq-into vec 'list))))

(defun heks/print-random-standup-order ()
  "Prints a random order of names from `heks/standup-people` in a new buffer."
  (interactive)
  (unless heks/standup-people
    (error "heks/standup-people is not a list.  Please check its definition"))
  (when (> 0 (length heks/standup-people))
    (error "The list of standup people is empty"))
  (ignore-errors (kill-buffer heks/standup-buffer-name))

  (let ((shuffled-people (hugot-shuffle (copy-sequence heks/standup-people))))
    (get-buffer-create heks/standup-buffer-name)
    (with-current-buffer heks/standup-buffer-name
      (insert "* Random Standup Order\n\n")
      (insert "Generated on: " (format-time-string "%Y-%m-%d %H:%M:%S") "\n\n")

      (dolist (person shuffled-people)
        (insert (format "%s\n" person)))
      (org-mode))
    (switch-to-buffer heks/standup-buffer-name)))

(defun heks/dired-copy-marked-files-content ()
  "Concatenate and copy contents of all marked files in Dired to the clipboard."
  (interactive)
  (let ((files (dired-get-marked-files))
        (contents ""))
    (dolist (file files)
      (unless (file-directory-p file)
        (setq contents
              (concat contents
                      (format "=== FILE: %s ===\n" (file-name-nondirectory file))
                      (with-temp-buffer
                        (insert-file-contents file)
                        (buffer-string))
                      "\n\n"))))
    (kill-new contents)
    (message "Copied contents of %d files to clipboard." (length files))))


(defun heks/clean-comment-numbers (start end)
  "Interactively prompt (y/n) to remove line numbers from comment lines.
Supports C-style (//), Lisp (;;), SQL (--), Shell/Python (#), and docstars (*).
Operates on the selected region, or from point to the end of the buffer."
  (interactive
   (if (use-region-p)
       (list (region-beginning) (region-end))
     (list (point) (point-max))))
  (perform-replace
   "^\\(\\s-*\\(?://+\\|#+\\|;+\\|\\*+\\|--+\\)\\s-*\\)[0-9]+\\.\\s-*"
   "\\1"
   t    ; query-flag: t enables interactive y/n prompting
   t    ; regexp-flag: treat search string as regex
   nil  ; delimited
   nil  ; repeat-count
   nil  ; map
   start end))

;;
;; ====== JVM build tooling (Maven / Gradle / Spring Boot) ======
;;

(require 'cl-lib)

(defun heks/locate-project-file (names &optional start-dir)
  "Return the closest directory at or above START-DIR that holds one of NAMES.

NAMES is a file name or a list of file names, such as a `pom.xml' or a
`build.gradle' file, and START-DIR defaults to `default-directory'.
Return nil when no such directory exists."
  (let ((names (if (listp names) names (list names)))
        (dir (file-truename (or start-dir default-directory))))
    (catch 'found
      (while dir
        (when (cl-some (lambda (name) (file-exists-p (expand-file-name name dir))) names)
          (throw 'found dir))
        (let ((parent (file-name-directory (directory-file-name dir))))
          (setq dir (unless (equal parent dir) parent))))
      nil)))

(defun heks/jvm-build-program (root wrapper default)
  "Return the build program to run in ROOT.

Wants the project WRAPPER script (e.g. mvnw) when it is executable,
otherwise falls back to DEFAULT (e.g. mvn)."
  (let ((wrapper (expand-file-name wrapper root)))
    (if (file-executable-p wrapper) wrapper default)))

(defun heks/jvm-run-build (root program &rest arguments)
  "Compile the build command for ROOT using PROGRAM and ARGUMENTS."
  (let ((default-directory root)
        (command (mapconcat #'identity (cons (shell-quote-argument program) arguments) " ")))
    (compile command)))

;; The goals and tasks worth a description, because they are the ones a
;; Maven or Gradle project actually gets built with.  Everything else can
;; still be typed: the prompt completes against this list but does not
;; insist on it.
(defconst heks/maven-goals
  '(("validate"       . "Check the POM and its parents resolve")
    ("compile"        . "Compile the sources")
    ("test"           . "Run the unit tests")
    ("package"        . "Build the artefact")
    ("verify"         . "Run every check the build defines")
    ("install"        . "Install into the local repository")
    ("clean"          . "Delete the build output")
    ("clean install"   . "Clean, then install")
    ("clean verify"    . "Clean, then run every check")
    ("dependency:tree" . "Show the dependency tree")
    ("dependency:analyze" . "Report used and declared dependencies")
    ("versions:display-dependency-updates" . "List newer dependency versions")
    ("versions:display-plugin-updates" . "List newer plugin versions")
    ("help:effective-pom" . "Show the POM with inheritance applied")
    ("surefire-report:report" . "Write the test report for the browser")
    ("spring-boot:run" . "Run the Spring Boot application")
    ("spring-boot:build-image" . "Build a container image")
    ("quarkus:dev"    . "Run the Quarkus application in dev mode"))
  "Common Maven goals, with what they do, offered by the Maven commands.")

(defvar heks/maven-goal-history nil
  "Maven goals that have been run from this Emacs.")

(defvar heks/gradle-task-history nil
  "Gradle tasks that have been run from this Emacs.")

(defconst heks/gradle-tasks
  '(("build"        . "Assemble and test the project")
    ("test"         . "Run the unit tests")
    ("check"        . "Run every verification task")
    ("assemble"     . "Assemble the artefacts")
    ("clean"        . "Delete the build directory")
    ("bootRun"      . "Run the Spring Boot application")
    ("run"          . "Run the application")
    ("dependencies" . "Show the dependency tree")
    ("dependencyUpdates" . "List newer dependency versions")
    ("publishToMavenLocal" . "Install into the local Maven repository")
    ("installDist"  . "Write a runnable installation")
    ("jib"          . "Build a container image from the application"))
  "Common Gradle tasks, with what they do.")

(defun heks/jvm-read (what table history default)
  "Read a WHAT from TABLE, mentioning what each one does.

HISTORY is where the answers are remembered and DEFAULT is what an empty
answer means.  Anything can be typed: the table is a crib, not a
restriction, because a build always has goals that are its own."
  (let ((answer (completing-read
                 (format "%s (default %s): " what default)
                 table nil nil nil history default)))
    (if (string-empty-p answer) default answer)))

(defun heks/maven-run (goal)
  "Run Maven GOAL for the closest Maven project.

Prefers the project's `mvnw' wrapper over a system-wide `mvn' and reuses
the compilation buffer, so a second run of the same goal reuses the
window instead of opening another one."
  (interactive (list (heks/jvm-read "Maven goal" heks/maven-goals
                                           'heks/maven-goal-history "test")))
  (let ((root (heks/locate-project-file "pom.xml")))
    (unless root
      (user-error "No pom.xml found above %s" default-directory))
    (heks/jvm-run-build root
                           (heks/jvm-build-program root "mvnw" "mvn")
                           goal)))

(defun heks/maven-dependency-tree ()
  "Show the dependency tree of the closest Maven project."
  (interactive)
  (heks/maven-run "dependency:tree"))

(defun heks/maven-menu ()
  "Choose a Maven goal by what it does instead of by its name."
  (interactive)
  (heks/maven-run
   (heks/jvm-read "Maven goal" heks/maven-goals
                         'heks/maven-goal-history "test")))

(defun heks/gradle-run (task)
  "Run Gradle TASK for the closest Gradle project.

Understands both Groovy (`build.gradle') and Kotlin (`build.gradle.kts')
projects, and prefers the `gradlew' wrapper."
  (interactive (list (heks/jvm-read "Gradle task" heks/gradle-tasks
                                           'heks/gradle-task-history "test")))
  (let ((root (heks/locate-project-file '("build.gradle" "build.gradle.kts"))))
    (unless root
      (user-error "No build.gradle or build.gradle.kts found above %s" default-directory))
    (heks/jvm-run-build root
                           (heks/jvm-build-program root "gradlew" "gradle")
                           task)))

(defun heks/gradle-menu ()
  "Choose a Gradle task by what it does instead of by its name."
  (interactive)
  (heks/gradle-run
   (heks/jvm-read "Gradle task" heks/gradle-tasks
                         'heks/gradle-task-history "test")))

(defun heks/spring-boot-run ()
  "Run the Spring Boot application of the current project.

Uses Maven (`spring-boot:run') for Maven projects and Gradle (`bootRun')
for Gradle projects."
  (interactive)
  (cond ((heks/locate-project-file "pom.xml")
         (heks/maven-run "spring-boot:run"))
        ((heks/locate-project-file '("build.gradle" "build.gradle.kts"))
         (heks/gradle-run "bootRun"))
        (t (user-error "No pom.xml or Gradle build found above %s" default-directory))))

(defun heks/jvm-goal-at-point ()
  "Run the Maven goal named at point.

Point is normally on an `<artifactId>' or an `<execution>' when one wants
this, so the goal is read from the buffer: the enclosing element's text
is offered as the goal to run."
  (interactive)
  (let ((goal (or (thing-at-point 'symbol t)
                  (read-string "Maven goal: " nil 'heks/maven-goal-history))))
    (heks/maven-run goal)))

(defun heks/jvm-refresh-project ()
  "Make the tooling re-read the JVM project of the current buffer.

A Java buffer with a language server asks the server to re-import the
build; anywhere else Maven or Gradle is asked to parse the build file,
which is what reports a broken POM or a missing plugin."
  (interactive)
  (cond ((and (bound-and-true-p eglot-java-mode)
              (fboundp 'eglot-java-project-build-refresh))
         (call-interactively #'eglot-java-project-build-refresh))
        ((heks/locate-project-file "pom.xml")
         (heks/maven-run "validate"))
        ((heks/locate-project-file '("build.gradle" "build.gradle.kts"))
         (heks/gradle-run "tasks"))
        (t (user-error "No Maven or Gradle project above %s" default-directory))))

;; The goals a project is built with, under the name each tool gives the
;; same idea: Maven has a `package' goal and Gradle an `assemble' task,
;; and somebody who wants the artefact should not have to remember which
;; of the two words their project answers to.  These are the ones a build
;; is actually run with; everything else is still there in the Maven and
;; Gradle menus, which complete against their full crib.
(defconst heks/jvm-goals
  '(("test"         "test"           "test"         "Run the tests")
    ("package"      "package"        "assemble"     "Build the artefact")
    ("verify"       "verify"         "check"        "Run every check the build defines")
    ("clean"        "clean"          "clean"        "Delete the build output")
    ("dependencies" "dependency:tree" "dependencies" "Show the dependency tree"))
  "The goals a JVM project is built with, as (WHAT MAVEN GRADLE \"what it does\").

WHAT is what the person wants, and the two names after it are what each
build tool calls it.  `heks/jvm-run' reads this, so that `C-c j t'
runs the tests of a Maven project and of a Gradle project alike.")

(defvar heks/jvm-goal-history nil
  "Goals that have been run from this Emacs by what they do.")

(defun heks/jvm-goal-for (what tool)
  "Return what TOOL calls the goal WHAT, or nil when neither knows it.

TOOL is the symbol `maven' or `gradle'; WHAT is one of the names in
`heks/jvm-goals'."
  (let* ((entry (assoc what heks/jvm-goals #'equal))
         (name (pcase tool
                 ('maven (nth 1 entry))
                 ('gradle (nth 2 entry)))))
    (or name (user-error "No %s goal is defined for %s" tool what))))

(defun heks/jvm--read-table ()
  "Return `heks/jvm-goals' as the alist `completing-read' wants.

The goal's own name is what is chosen, and what it does is the
annotation beside it."
  (mapcar (lambda (entry) (cons (nth 0 entry) (nth 3 entry)))
          heks/jvm-goals))

(defun heks/jvm--project ()
  "Return the closest JVM project above `default-directory' as (TOOL . ROOT).

A directory can hold both a `pom.xml' and a `build.gradle' -- a Maven
project being migrated, most often -- and the one nearer to the file
being edited is the one its author is working with."
  (let ((maven (heks/locate-project-file "pom.xml"))
        (gradle (heks/locate-project-file '("build.gradle" "build.gradle.kts"))))
    (cond ((and maven (or (null gradle) (>= (length maven) (length gradle))))
           (cons 'maven maven))
          (gradle (cons 'gradle gradle))
          (t nil))))

(defun heks/jvm-run (what)
  "Run the goal WHAT for the JVM project of the current buffer.

WHAT is what the goal is for -- `test', `package', `verify', `clean' or
`dependencies' -- and which build tool runs it is decided by the project
itself, `pom.xml' or a Gradle build."
  (interactive (list (heks/jvm-read "Goal" (heks/jvm--read-table)
                                           'heks/jvm-goal-history "test")))
  (let ((project (heks/jvm--project)))
    (unless project
      (user-error "No pom.xml or Gradle build found above %s" default-directory))
    (pcase (car project)
      ('maven (heks/maven-run (heks/jvm-goal-for what 'maven)))
      ('gradle (heks/gradle-run (heks/jvm-goal-for what 'gradle))))))

(defun heks/jvm-test ()
  "Run the tests of the JVM project of this buffer."
  (interactive)
  (heks/jvm-run "test"))

(defun heks/jvm-package ()
  "Build the artefact of the JVM project of this buffer."
  (interactive)
  (heks/jvm-run "package"))

(defun heks/jvm-verify ()
  "Run every check the JVM project of this buffer defines."
  (interactive)
  (heks/jvm-run "verify"))

(defun heks/jvm-clean ()
  "Delete the build output of the JVM project of this buffer."
  (interactive)
  (heks/jvm-run "clean"))

(defun heks/jvm-dependencies ()
  "Show what the JVM project of this buffer depends on."
  (interactive)
  (heks/jvm-run "dependencies"))

(defun heks/jvm-build ()
  "Choose what to do to the JVM project of this buffer, by what it does.

This is the one menu that works in a Maven project and a Gradle project
alike: it offers what a build is for, and the project answers with its
own goal."
  (interactive)
  (heks/jvm-run
   (heks/jvm-read "Goal" (heks/jvm--read-table)
                         'heks/jvm-goal-history "test")))

;;
;; ====== Debugging a JVM project (Maven, Gradle, Spring Boot) ======
;;

(require 'url)
(require 'json)

;; `dape' speaks the Debug Adapter Protocol, not JDWP (the protocol the
;; JVM itself exposes), so debugging Java or Kotlin needs something that
;; translates one into the other.  That something is Eclipse `java-debug',
;; the adapter VS Code's Java extension and `lsp-java' both run -- a
;; single jar, `com.microsoft.java.debug.plugin-*.jar'.  `heks/jvm-debug'
;; looks for it in the usual places below and, failing that, tries to
;; fetch the latest one itself (`heks/java-debug-ensure-jar') into
;; `heks/java-debug-cache-dir' -- a best-effort convenience, built
;; from nothing but `url' and `json' (already part of Emacs), that never
;; stands in the way of pointing `heks/java-debug-jar' or
;; `HEKS_JAVA_DEBUG_JAR' at one by hand instead.
(defcustom heks/java-debug-jar
  (car (seq-filter
        #'identity
        (list (let ((env (getenv "HEKS_JAVA_DEBUG_JAR")))
                (and env (file-exists-p env) env))
              (car (file-expand-wildcards
                    "~/.local/share/nvim/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar"))
              (car (file-expand-wildcards
                    "~/.cache/lsp-java/*/com.microsoft.java.debug.plugin-*.jar"))
              (car (file-expand-wildcards
                    "~/.emacs.d/.cache/lsp/java-debug/com.microsoft.java.debug.plugin-*.jar")))))
  "Path to the `java-debug' adapter jar.

`heks/jvm-debug' runs it as `dape''s DAP server.  Nil when none of
the usual places holds it, in which case `heks/jvm-debug' tries
`heks/java-debug-ensure-jar' before giving up."
  :type '(choice (file :tag "Path to the jar") (const :tag "not found" nil))
  :group 'heks)

(defcustom heks/java-debug-cache-dir
  (expand-file-name "java-debug/" user-emacs-directory)
  "Where `heks/java-debug-ensure-jar' caches a jar it fetched itself.

Only looked at, and only written to, when `heks/java-debug-jar' is
nil and none of its own auto-detected paths holds one either."
  :type 'directory
  :group 'heks)

(defcustom heks/java-debug-port 5005
  "The JDWP port a JVM run by `heks/jvm-debug' listens on.

`heks/jvm-debug' starts the project suspended on this port and
attaches `dape' to it through `heks/java-debug-jar'."
  :type 'integer
  :group 'heks)

(defun heks/java-debug-cached-jar ()
  "Return a `java-debug' jar already sitting in the cache dir, or nil."
  (car (file-expand-wildcards
        (expand-file-name "com.microsoft.java.debug.plugin-*.jar"
                           heks/java-debug-cache-dir))))

(defun heks/java-debug-latest-asset-url ()
  "Return the download URL of the latest `java-debug' adapter jar, or nil.

Asks GitHub's release API for the project's latest release and picks out
the one asset shaped like the adapter jar.  Returns nil, rather than
signalling, on anything unexpected -- no network, a changed API, no
matching asset -- because fetching the jar is a convenience and never
the only way to get one (see `heks/java-debug-jar')."
  (condition-case nil
      (with-temp-buffer
        (url-insert-file-contents
         "https://api.github.com/repos/microsoft/java-debug/releases/latest")
        (let* ((json (json-parse-buffer :object-type 'alist :array-type 'list))
               (assets (alist-get 'assets json)))
          (cl-loop for asset in assets
                   for name = (alist-get 'name asset)
                   when (and name
                             (string-match-p
                              "\\`com\\.microsoft\\.java\\.debug\\.plugin-.*\\.jar\\'"
                              name))
                   return (alist-get 'browser_download_url asset))))
    (error nil)))

(defun heks/java-debug-ensure-jar (&optional force)
  "Return a `java-debug' adapter jar, fetching one if none is known yet.

Prefers `heks/java-debug-jar' and whatever it auto-detected, then a
jar already cached from a previous fetch, and only then downloads the
latest one into `heks/java-debug-cache-dir' -- quietly, and never
signalling an error itself, so that `heks/jvm-debug' stays the one
place that reports not having a debugger to run.  With FORCE (or a
prefix argument), fetches a new one even over a cached jar."
  (interactive "P")
  (or (and (not force) heks/java-debug-jar)
      (and (not force) (heks/java-debug-cached-jar))
      (let ((url (heks/java-debug-latest-asset-url)))
        (when url
          (make-directory heks/java-debug-cache-dir t)
          (let ((target (expand-file-name (file-name-nondirectory url)
                                           heks/java-debug-cache-dir)))
            (condition-case err
                (progn
                  (url-copy-file url target t)
                  (message "Fetched the `java-debug' adapter into %s" target)
                  (setq heks/java-debug-jar target))
              (error
               (message "Could not fetch the `java-debug' adapter: %s"
                        (error-message-string err))
               nil)))))))

(defun heks/jvm-debug-agent (port)
  "Return the JVM argument that suspends a JVM for a debugger on PORT.

`suspend=y' is what makes this reliable rather than a race: the JVM does
not run a line of the program until something attaches on PORT, so a
breakpoint in, say, a Spring `@PostConstruct' is never too late to set."
  (format "-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=*:%d" port))

(defun heks/jvm-debug ()
  "Debug the JVM project of this buffer with `dape'.

Starts the project the way `heks/spring-boot-run' and
`heks/jvm-run' do, except suspended on
`heks/java-debug-port' until a debugger attaches, and then attaches
`dape' to it through the `java-debug' adapter, fetched by
`heks/java-debug-ensure-jar' when nothing else already provides
one.  Works for Java and for Kotlin alike, because the debugger is
attached to the running JVM rather than reading either language's source
directly."
  (interactive)
  (unless (heks/java-debug-ensure-jar)
    (user-error "No `java-debug' adapter found, and none could be fetched; \
set `heks/java-debug-jar' or `HEKS_JAVA_DEBUG_JAR', or get one \
yourself and run `M-x heks/java-debug-ensure-jar'"))
  (require 'dape)
  (let* ((project (heks/jvm--project))
         (root (cdr project))
         (agent (heks/jvm-debug-agent heks/java-debug-port)))
    (unless project
      (user-error "No pom.xml or Gradle build found above %s" default-directory))
    (pcase (car project)
      ('maven
       (heks/jvm-run-build root
                              (heks/jvm-build-program root "mvnw" "mvn")
                              "spring-boot:run"
                              (shell-quote-argument (format "-Dspring-boot.run.jvmArguments=%s" agent))))
      ('gradle
       (heks/jvm-run-build root
                              (heks/jvm-build-program root "gradlew" "gradle")
                              "bootRun"
                              (format "-Dorg.gradle.jvmargs=%s" (shell-quote-argument agent)))))
    (message "Waiting for %s to listen on %d before attaching `dape'..."
             (car project) heks/java-debug-port)
    (run-at-time
     2 nil
     (lambda ()
       (dape (list :name "java-attach"
                   :command "java"
                   :command-args (list "-jar" heks/java-debug-jar)
                   :port heks/java-debug-port
                   :request "attach"
                   :hostName "localhost"
                   :cwd root
                   :sourcePaths (list (expand-file-name "src/main/java" root)
                                      (expand-file-name "src/main/kotlin" root))))))))

;;
;; ====== Formatting, wherever the buffer is ======
;;

;; Formatting is the one editing action every language has, so it gets one
;; key and one command: the language decides who does the work.  A
;; language module can teach this dispatcher a new formatter by adding a
;; predicate and a command to `heks/format-dispatch'.

(defvar heks/format-dispatch nil
  "Extra formatters, tried before the generic ones.

Each entry is (PREDICATE . COMMAND): when PREDICATE holds in the buffer
being formatted, COMMAND does the formatting.  A language module adds its
own formatter here, so that the key the user already knows keeps working
in the buffer that language owns.")

(defun heks/format-buffer ()
  "Format the current buffer with the best formatter it has.

In order: the language's own formatter from
`heks/format-dispatch' (Guix style for Scheme, for instance), the
language server when one manages the buffer, then `format-all', which
knows how to call prettier, black, gofmt and the rest from a single
interface.  Buffers with none of those say so rather than pretending."
  (interactive)
  (cond
   ((let ((entry (seq-find (lambda (entry) (funcall (car entry)))
                           heks/format-dispatch)))
      (when entry (call-interactively (cdr entry)))))
   ((and (fboundp 'eglot-managed-p) (eglot-managed-p))
    (call-interactively #'eglot-format-buffer))
   ((fboundp 'format-all-region-or-buffer)
    (call-interactively #'format-all-region-or-buffer))
   (t (user-error "No formatter is configured for %s" major-mode))))

(defun heks/format-file ()
  "Format the whole buffer, saving it first when it has unsaved edits."
  (interactive)
  (when (buffer-modified-p) (save-buffer))
  (heks/format-buffer))

;;
;; ====== Folding, wherever the buffer is ======
;;

;; Folding is the one editing action that every buffer can have and almost
;; none of them bind the same way: Tree-sitter modes fold with
;; `treesit-fold', the Lisp-like ones with Hideshow, Org and Outline with
;; their own invisible text, and each of those packages has picked its own
;; keys.  `kirigami' is the interface that knows all of them, so these
;; commands are the one set of keys on top of it: `C-c v c' closes the fold
;; at point in a Java file, a Scheme file and an Org file alike, and
;; `C-c v r' reveals everything in any of them.
;;
;; They exist rather than binding kirigami's commands directly so that the
;; key letters stay this configuration's own (`r' reveals, `t' toggles) and
;; so that the error in a buffer with nothing to fold says which mode is
;; missing.

(defun heks/fold--call (what command)
  "Run the folding COMMAND, saying WHAT is not possible without kirigami."
  (unless (require 'kirigami nil t)
    (user-error "%s: the kirigami package is not installed" what))
  (call-interactively command))

;; Org folds with its own text properties, which kirigami's outline
;; handlers do not reliably undo, so Org buffers are folded by Org's own
;; (outline-compatible) commands and everything else goes through kirigami.

(defun heks/fold--org-p ()
  "Non-nil when the current buffer is an Org buffer."
  (derived-mode-p 'org-mode))

(defun heks/fold--org-heading ()
  "Move to the heading that owns point, or signal when there is none."
  (unless (ignore-errors (org-back-to-heading t))
    (user-error "No heading to fold here")))

(defun heks/fold--org-folded-p ()
  "Non-nil when the entry under the heading at point is folded."
  (save-excursion
    (heks/fold--org-heading)
    (org-fold-folded-p (line-end-position))))

(defun heks/fold--org-open ()
  "Unfold the heading at point and show its children."
  (save-excursion
    (heks/fold--org-heading)
    (outline-show-entry)
    (outline-show-children)))

(defun heks/fold--org-close ()
  "Fold the subtree of the heading at point."
  (heks/fold--org-heading)
  (outline-hide-subtree))

(defun heks/fold-toggle ()
  "Fold or unfold the block at point, whatever folds the buffer."
  (interactive)
  (if (heks/fold--org-p)
      (if (heks/fold--org-folded-p)
          (heks/fold--org-open)
        (heks/fold--org-close))
    (heks/fold--call "Toggling a fold" #'kirigami-toggle-fold)))

(defun heks/fold-open ()
  "Unfold the block at point, whatever folds the buffer."
  (interactive)
  (if (heks/fold--org-p)
      (heks/fold--org-open)
    (heks/fold--call "Opening a fold" #'kirigami-open-fold)))

(defun heks/fold-open-recursive ()
  "Unfold the block at point and everything inside it."
  (interactive)
  (if (heks/fold--org-p)
      (save-excursion
        (heks/fold--org-heading)
        (outline-show-subtree))
    (heks/fold--call "Opening a fold recursively"
                           #'kirigami-open-fold-rec)))

(defun heks/fold-close ()
  "Fold the block at point, whatever folds the buffer."
  (interactive)
  (if (heks/fold--org-p)
      (heks/fold--org-close)
    (heks/fold--call "Closing a fold" #'kirigami-close-fold)))

(defun heks/fold-open-all ()
  "Unfold the whole buffer, whatever folds it."
  (interactive)
  (if (heks/fold--org-p)
      (outline-show-all)
    (heks/fold--call "Opening every fold" #'kirigami-open-folds)))

(defun heks/fold-close-all ()
  "Fold everything foldable in the buffer, whatever folds it."
  (interactive)
  (if (heks/fold--org-p)
      (org-overview)
    (heks/fold--call "Closing every fold" #'kirigami-close-folds)))

;;
;; ====== External tools as Flymake backends ======
;;

;; A language tool is almost always a command line program whose output
;; names a file, a line, a column and a message, and the same few lines of
;; glue turn every one of them into a Flymake backend.  Two shapes cover
;; what these tools do:
;;
;;   * a *checker* reports diagnostics and has nothing to say when the code
;;     is fine (`guix lint', `guild compile', `go vet', `cargo clippy') --
;;     `heks/tool-diagnostic-backend';
;;   * a *formatter* rewrites the file, and the lines it was not happy with
;;     are the diagnostics (`guix style', `gofmt', `rustfmt', `nixfmt') --
;;     `heks/tool-drift-backend'.
;;
;; Both run asynchronously, both use a pipe rather than a pty and both turn
;; colour off, because a tool that believes it is talking to a terminal
;; decorates its output -- an OSC 8 hyperlink around the file name, for
;; instance -- in a way that hides the FILE:LINE:COLUMN structure read here.
;; Both also run the tool on a *copy* of the buffer when the tool has to see
;; a file on disk, so unsaved edits are checked and the buffer is never
;; touched; the copy is what makes the REPL-first workflow possible, where
;; code is evaluated long before it is saved.

(require 'cl-lib)
(require 'flymake)
(require 'seq)

(defvar-local heks/tool-processes nil
  "Alist mapping the name of a tool to the process running for this buffer.

Buffer-local, so that one buffer of a project does not cancel the tool
another buffer is running, and so that a backend replaces its own previous
run without touching anyone else's.")

(defun heks/tool-available-p (program)
  "Return non-nil when PROGRAM is an executable on `exec-path'."
  (and program (stringp program) (executable-find program) t))

(defun heks/tool-path (program)
  "Return the absolute name of PROGRAM, or PROGRAM itself when not found."
  (or (executable-find program) program))

(defun heks/strip-escapes (string)
  "Return STRING without ANSI colours or OSC 8 terminal hyperlinks.

Tools colour their diagnostics and, on a terminal, wrap the file name in an
OSC 8 hyperlink, which would hide the FILE:LINE:COLUMN structure the parsers
below read.  The processes started here ask for plain output, and this makes
the reading work even when something still decorates it."
  (when string
    (let ((stripped string))
      ;; OSC 8 hyperlinks, terminated by BEL or by ST (escape backslash).
      (setq stripped (replace-regexp-in-string
                      "\e\\]8;;[^\a\e]*\\(?:\a\\|\e\\\\\\)" "" stripped))
      ;; Anything else, such as colours.
      (setq stripped (replace-regexp-in-string "\e\\[[0-9;?]*[a-zA-Z]" "" stripped))
      stripped)))

(defconst heks/tool-diagnostic-regexp
  "\\`\\(.+?\\):\\([0-9]+\\):\\([0-9]+\\):[ \t]*\\(.*\\)\\'"
  "Regexp matching a FILE:LINE:COLUMN: MESSAGE diagnostic.")

(defconst heks/tool-severity-regexp
  "\\`\\(warning\\|error\\|note\\|fatal[^:]*\\): \\(.*\\)\\'"
  "Regexp matching the severity prefix some tools put before a message.")

(defun heks/tool-severity (message)
  "Return (SEVERITY . MESSAGE) for the raw diagnostic MESSAGE.

Most tools prefix theirs with `warning:', `error:' or `note:'; the prefix
becomes the Flymake severity and is removed from the text.  A message
without a prefix is a warning, which is the safe assumption: a checker that
says nothing about severity is reporting something to look at."
  (if (string-match heks/tool-severity-regexp message)
      (cons (intern (concat ":" (downcase (match-string 1 message))))
            (match-string 2 message))
    (cons :warning message)))

(defun heks/parse-diagnostics (text)
  "Parse TEXT into (FILE LINE COLUMN SEVERITY MESSAGE) entries.

TEXT is read as the output of the usual compilers and linters, one
diagnostic per line.  Lines that carry no location, such as the frames of a
backtrace, are ignored, so a tool that fails hard does not turn its
backtrace into diagnostics."
  (let ((entries '()))
    (dolist (line (split-string (heks/strip-escapes text) "\n" t))
      (when (string-match heks/tool-diagnostic-regexp line)
        ;; Every piece is taken out of the match data before anything else
        ;; looks at a string: `heks/tool-severity' matches a regexp of
        ;; its own, and that would overwrite the line, column and file name
        ;; read here.
        (let* ((file (match-string 1 line))
               (number (string-to-number (match-string 2 line)))
               (column (string-to-number (match-string 3 line)))
               (severity (heks/tool-severity (match-string 4 line))))
          (push (list file number column (car severity) (cdr severity)) entries))))
    (nreverse entries)))

(defconst heks/tool-noise-regexp
  "\\`\\(?:Backtrace:\\|In .*:\\|[ \t]*[0-9]+:[0-9]+ \\|;;; \\|Process \\|Enter \\|scheme@\\|guile> \\)"
  "Regexp matching the lines of a tool's error output that say nothing.

Backtraces are made of frame lines and of `In some/module.scm:' headers,
and Emacs adds its own `Process ...' notices to the same stream; the useful
sentence is the one that is left.")

(defun heks/tool-error-line (text)
  "Return the sentence explaining why a tool failed, or nil."
  (car (last (seq-filter (lambda (line)
                           (not (string-match-p heks/tool-noise-regexp line)))
                         (split-string (heks/strip-escapes text) "\n" t)))))

(defun heks/line-position (line &optional column)
  "Return the buffer position of LINE and COLUMN, both one-based.

Positions past the end of a line are clamped, because a diagnostic can
point anywhere in a file that changed since it was produced."
  (save-excursion
    (goto-char (point-min))
    (forward-line (max 0 (1- line)))
    (let ((start (point)))
      (when (and column (> column 0))
        (forward-char (min (1- column) (- (line-end-position) start))))
      (point))))

(defun heks/tool--process (name)
  "Return the process tool NAME is running for this buffer, if any."
  (cdr (assoc name heks/tool-processes)))

(defun heks/tool-stop (name)
  "Stop what tool NAME is running for this buffer, if anything."
  (when-let* ((process (heks/tool--process name)))
    (when (process-live-p process)
      (delete-process process))
    (setf (alist-get name heks/tool-processes) nil)))

(defun heks/tool-run (name command report &optional directory env)
  "Run COMMAND asynchronously for tool NAME and call REPORT on its output.

REPORT is called with the standard output and the standard error of the
finished process whenever the buffer is still alive, so that a backend can
report nothing when its buffer is gone.  A tool that is still running is
stopped first: its answer would describe an older version of the buffer,
and Flymake starts a new run on every change anyway.  DIRECTORY is where
COMMAND runs, which matters because tools print the paths of their
diagnostics relative to it, and ENV holds extra environment entries such
as `GUILE_AUTO_COMPILE=0'."
  (heks/tool-stop name)
  (let ((source (current-buffer))
        (output (generate-new-buffer (format " *%s out*" name)))
        (errors (generate-new-buffer (format " *%s err*" name)))
        (default-directory (file-name-as-directory (or directory default-directory)))
        ;; A plain environment, so that the tools do not decorate their
        ;; output, and a pipe rather than a pty for the same reason.
        (process-environment (append (list "TERM=dumb" "NO_COLOR=1")
                                     env process-environment)))
    (setf (alist-get name heks/tool-processes)
          (make-process
           :name name
           :buffer output
           :stderr errors
           :noquery t
           :connection-type 'pipe
           :command command
           :sentinel
           (lambda (process _event)
             (when (memq (process-status process) '(exit signal))
               (let ((text (with-current-buffer output (buffer-string)))
                     (problems (with-current-buffer errors (buffer-string))))
                 (kill-buffer output)
                 (kill-buffer errors)
                 (when (buffer-live-p source)
                   (with-current-buffer source
                     (when (eq (heks/tool--process name) process)
                       (setf (alist-get name heks/tool-processes) nil))
                     (funcall report text problems))))))))))

(defun heks/tool-entries-for (text file &optional root)
  "Return the diagnostics in TEXT that belong to FILE.

An entry counts when the name it carries is FILE, is FILE resolved against
ROOT (tools print paths relative to the directory they run in), or merely
has the same base name as FILE: tools also print paths relative to a load
path, and a tool that was handed a copy of the buffer prints the name of
that copy."
  (let ((basename (file-name-nondirectory file)))
    (seq-filter
     (lambda (entry)
       (let ((name (nth 0 entry)))
         (or (equal name file)
             (equal (file-name-nondirectory name) basename)
             (and root (file-name-absolute-p name)
                  (equal (file-truename name) (file-truename (expand-file-name file)))))))
     (heks/parse-diagnostics text))))

(defun heks/tool-diagnostic-list (text file root &optional origin)
  "Return Flymake diagnostics for the diagnostics of FILE in TEXT.

ORIGIN names the tool that reported them, the way Eglot names the server a
problem came from.  Emacs builds the string the user sees out of a
diagnostic's origin, code and message, one after the other, and a missing
piece still takes its separator with it -- a diagnostic with no origin
renders with the gap in front of it, which is why the tool is always
named."
  (mapcar (lambda (entry)
            (let ((position (heks/line-position (nth 1 entry) (nth 2 entry))))
              (flymake-make-diagnostic (current-buffer) position position
                                       (nth 3 entry)
                                       (list origin nil (nth 4 entry)))))
          (heks/tool-entries-for text file root)))

(defun heks/tool-number-ranges (numbers)
  "Group the sorted NUMBERS into (FIRST . LAST) ranges."
  (let ((ranges '()))
    (dolist (number numbers)
      (let ((last (car ranges)))
        (if (and last (= number (1+ (cdr last))))
            (setcdr last number)
          (push (cons number number) ranges))))
    (nreverse ranges)))

(defun heks/tool-changed-lines (original rewritten)
  "Return the one-based line numbers of ORIGINAL that differ in REWRITTEN.

`diff' computes them, which keeps this independent of how much the
formatter rewrote."
  (let ((before (make-temp-file "heks-drift-before"))
        (after (make-temp-file "heks-drift-after")))
    (unwind-protect
        (progn
          (write-region original nil before nil 'silent)
          (write-region rewritten nil after nil 'silent)
          (with-temp-buffer
            (call-process "diff" nil t nil
                          "--old-line-format=%dn\n"
                          "--new-line-format="
                          "--unchanged-line-format="
                          before after)
            (let ((lines '()))
              (goto-char (point-min))
              (while (re-search-forward "\\([0-9]+\\)" nil t)
                (push (string-to-number (match-string 1)) lines))
              (sort lines #'<))))
      (delete-file before)
      (delete-file after))))

(defun heks/tool-drift-diagnostics (original rewritten what)
  "Return Flymake diagnostics for the lines the formatter WHAT changed.

A formatter usually moves a whole argument list around at once, so a range
is reported as one diagnostic rather than as one per line: fifteen
diagnostics for one rewrapped `inputs' clause is noise."
  (when (not (equal original rewritten))
    (mapcar (lambda (range)
              (let ((start (heks/line-position (car range)))
                    (end (heks/line-position (cdr range))))
                (flymake-make-diagnostic
                 (current-buffer) start (min (point-max) (1+ end)) :warning
                 (list what nil
                       (if (= (car range) (cdr range))
                           (format "would reformat line %d" (car range))
                         (format "would reformat lines %d-%d"
                                 (car range) (cdr range)))))))
            (heks/tool-number-ranges
             (heks/tool-changed-lines original rewritten)))))

(defun heks/tool-copy-buffer (suffix)
  "Write the buffer to a temporary file with SUFFIX and return its name.

What the backends hand to a tool: the tool sees what the buffer holds right
now, including the edits that have not been saved yet."
  (let ((file (make-temp-file "heks-tool" nil suffix)))
    (write-region (point-min) (point-max) file nil 'silent)
    file))

(defun heks/tool-diagnostic-backend (name report-fn spec)
  "Flymake backend for tool NAME, which reports diagnostics about a file.

SPEC describes the tool as a plist:

  :command  function of the file name to check, returning the command
            list.  It is handed a copy of the buffer when :copy is non-nil
            and the file on disk otherwise.
  :applies  function of no arguments; the backend reports nothing when it
            returns nil, which is how a tool that is not installed, or a
            buffer it has nothing to say about, stays quiet.
  :root     function of no arguments returning the directory to run in and
to resolve relative file names against; it defaults to `default-directory'.
  :suffix   file name suffix for the copy of the buffer.
  :copy     non-nil to check a copy of the buffer rather than the file on
disk.  A checker that only needs to read the file can use the file
itself, but one that must parse it -- a compiler in particular -- cannot
read a buffer that has never been saved, and those are the interesting
edits.
  :env      extra environment entries for the process.
  :what     the name of the tool as it appears in a diagnostic, for
            instance \"guix lint\".
  :cleanup  function of the file name to run once the tool is done with
            it.  A compilers leaves its output behind, and that belongs
            neither in the project nor in the temporary directory for
            ever.

The diagnostics of other files are dropped: a tool that reports on the
whole project would otherwise cover the buffer in problems that belong to
somebody else's code."
  (heks/tool-stop name)
  (if (not (funcall (plist-get spec :applies)))
      (funcall report-fn nil)
    (let* ((file buffer-file-name)
           (root (file-name-as-directory
                  (or (and (plist-get spec :root) (funcall (plist-get spec :root)))
                      default-directory)))
           (copy (and (plist-get spec :copy) (heks/tool-copy-buffer (plist-get spec :suffix))))
           (target (or copy file)))
      (heks/tool-run
       name
       (funcall (plist-get spec :command) target)
       (lambda (text problems)
         (when copy (ignore-errors (delete-file copy)))
         (when-let* ((cleanup (plist-get spec :cleanup)))
           (ignore-errors (funcall cleanup target)))
         (let* ((what (or (plist-get spec :what) name))
                (diagnostics (heks/tool-diagnostic-list
                              (concat text "\n" problems) target root what)))
           (funcall report-fn
                    (or diagnostics
                        ;; What the tool could not attach to a line -- a
                        ;; module that will not load, say -- is on standard
                        ;; error; reporting it at the top of the buffer
                        ;; beats reporting nothing at all.
                        (when (string-empty-p (string-trim text))
                          (when-let* ((message (heks/tool-error-line problems)))
                            (list (flymake-make-diagnostic
                                   (current-buffer) (point-min) (point-min)
                                   :error (list what nil message))))))))))
       root
       (plist-get spec :env))))

(defun heks/tool-drift-backend (name report-fn spec)
  "Flymake backend reporting the lines the formatter NAME would rewrite.

SPEC is a plist:

  :command  function of the file name to format, returning the command
            list.  The formatter rewrites that file in place, which is why
            it is handed a copy of the buffer: the buffer is never touched
            and unsaved edits are covered, so the drift is reported as the
            code is written rather than after it is saved.
  :applies  function of no arguments, as for
            `heks/tool-diagnostic-backend'.
  :suffix   file name suffix for the copy, which some formatters use to
            decide what language they are looking at.
  :root     function of no arguments returning the directory to run in.
  :env      extra environment entries for the process.
  :what     the name of the formatter as it appears in the diagnostic and
            in the message `heks/tool-format-buffer' prints, for
            instance \"guix style\"."
  (heks/tool-stop name)
  (let ((original (when (and (funcall (plist-get spec :applies))
                              (not (string-empty-p (string-trim (buffer-substring-no-properties
                                                                  (point-min) (point-max))))))
                    (buffer-substring-no-properties (point-min) (point-max))))
        (copy (heks/tool-copy-buffer (plist-get spec :suffix)))
        (root (and (plist-get spec :root) (funcall (plist-get spec :root)))))
    (if (not original)
        (progn
          (delete-file copy)
          (funcall report-fn nil))
      (heks/tool-run
       name
       (funcall (plist-get spec :command) copy)
       (lambda (_text _problems)
         (let ((rewritten (when (file-exists-p copy)
                            (with-temp-buffer
                              (insert-file-contents copy)
                              (buffer-string)))))
           (when (file-exists-p copy)
             (delete-file copy))
           (funcall report-fn
                    (when rewritten
                      (heks/tool-drift-diagnostics
                       original rewritten
                       (or (plist-get spec :what) name))))))
       (or root default-directory)
       (plist-get spec :env)))))

(defun heks/tool-format-buffer (spec)
  "Format the current buffer in place with the formatter in SPEC.

SPEC is the plist `heks/tool-drift-backend' takes, minus `:applies'
and `:what': the file on disk is handed to the formatter and the buffer is
reloaded from it, so the two agree again."
  (let ((file (or buffer-file-name (user-error "The buffer is not visiting a file"))))
    (unless (file-writable-p (file-truename file))
      (user-error "%s is not writable" (abbreviate-file-name file)))
    (when (buffer-modified-p)
      (save-buffer))
    (let ((name (format "heks-format-%s" (file-name-nondirectory file)))
          (source (current-buffer)))
      (message "Formatting with %s..." (or (plist-get spec :what) name))
      (heks/tool-run
       name
       (funcall (plist-get spec :command) (file-truename file))
       (lambda (_text problems)
         (when (buffer-live-p source)
           (with-current-buffer source
             (if (string-empty-p (string-trim problems))
                 (progn
                   (revert-buffer :ignore-auto :noconfirm)
                   (message "Formatted with %s" (or (plist-get spec :what) name)))
               (message "%s failed: %s" (or (plist-get spec :what) name)
                        (or (heks/tool-error-line problems) "see its buffer"))))))
       (file-name-directory file)
       (plist-get spec :env)))))

;;
;; ====== Databases (PostgreSQL / MongoDB) ======
;;

;; `sql.el' defines these as `defcustom's.  Declaring them here tells the
;; byte-compiler that binding them is a *dynamic* binding, which is what
;; `sql-postgres' reads when it builds the connection.
(defvar sql-server)
(defvar sql-user)
(defvar sql-database)
(defvar sql-port)

(defun heks/run-in-terminal (name program &rest arguments)
  "Run PROGRAM with ARGUMENTS in a dedicated terminal buffer called NAME.

Uses a real pseudo-terminal (`term') so that interactive REPLs and
database shells behave exactly as they do outside Emacs, and reuses an
existing session buffer when it is still alive."
  (require 'term)
  (let ((buffer-name (format "*%s*" name)))
    (if (comint-check-proc buffer-name)
        (pop-to-buffer buffer-name)
      (when (get-buffer buffer-name)
        (kill-buffer buffer-name))
      (pop-to-buffer (apply #'make-term name program nil arguments)))))

(defun heks/sql-postgres ()
  "Open a PostgreSQL session using the built-in `sql.el' client.

Connection details come from the `sql.el' settings (`sql-server',
`sql-user', `sql-database' and `sql-port') when those are set, and
otherwise from the usual `PGHOST', `PGUSER', `PGDATABASE' and `PGPORT'
environment variables.  `sql.el' prompts for anything that is still
missing."
  (interactive)
  (require 'sql)
  (let ((sql-server (or (default-value 'sql-server) (getenv "PGHOST")))
        (sql-user (or (default-value 'sql-user) (getenv "PGUSER")))
        (sql-database (or (default-value 'sql-database) (getenv "PGDATABASE")))
        (sql-port (or (default-value 'sql-port)
                      (let ((port (getenv "PGPORT")))
                        (and port (string-to-number port))))))
    (sql-postgres)))

(defun heks/mongosh (&optional uri)
  "Open a MongoDB `mongosh' REPL in a terminal buffer.

URI defaults to the `MONGODB_URI' environment variable when set,
otherwise `mongosh' connects to the default local server."
  (interactive
   (list (read-string "MongoDB URI (empty for default): "
                      (or (getenv "MONGODB_URI") ""))))
  (unless (executable-find "mongosh")
    (user-error "Cannot find the `mongosh' executable in `exec-path'"))
  (apply #'heks/run-in-terminal "mongosh" "mongosh"
         (unless (string-empty-p (or uri "")) (list uri))))

;; Every setting used to be spelled `heks-emacs-NAME'.  A bridge written
;; before the rename still sets those, so they stay as aliases.
(define-obsolete-variable-alias 'heks-emacs-notes-roam-dir 'heks/notes-dir "2026-10")
(define-obsolete-variable-alias 'heks-emacs-ai-provider 'heks/ai-provider "2026-10")
(define-obsolete-variable-alias 'heks-emacs-ai-copilot-model 'heks/ai-copilot-model "2026-10")
(define-obsolete-variable-alias 'heks-emacs-ai-deepseek-model 'heks/ai-deepseek-model "2026-10")
(define-obsolete-variable-alias 'heks-emacs-ai-deepseek-key-file 'heks/ai-deepseek-key-file "2026-10")
(define-obsolete-variable-alias 'heks-emacs-ai-eca-prepare 'heks/ai-eca-prepare "2026-10")
(define-obsolete-variable-alias 'heks-emacs-ai-eca-prepare-delay 'heks/ai-eca-prepare-delay "2026-10")
(define-obsolete-variable-alias 'heks-emacs-fold-indicator-fade 'heks/fold-indicator-fade "2026-10")
(define-obsolete-variable-alias 'heks-emacs-duplicates-min-lines 'heks/duplicates-min-lines "2026-10")
(define-obsolete-variable-alias 'heks-emacs-duplicates-across-files-only 'heks/duplicates-across-files-only "2026-10")
(define-obsolete-variable-alias 'heks-emacs-duplicates-file-regexp 'heks/duplicates-file-regexp "2026-10")
(define-obsolete-variable-alias 'heks-emacs-duplicates-max-file-size 'heks/duplicates-max-file-size "2026-10")
(define-obsolete-variable-alias 'heks-emacs-duplicates-max-files 'heks/duplicates-max-files "2026-10")
(define-obsolete-variable-alias 'heks-emacs-duplicates-buffer-name 'heks/duplicates-buffer-name "2026-10")
(define-obsolete-variable-alias 'heks-emacs-treesit-grammar-directory 'heks/treesit-grammar-directory "2026-10")
(define-obsolete-variable-alias 'heks-emacs-treesit-install-grammars 'heks/treesit-install-grammars "2026-10")
(define-obsolete-variable-alias 'heks-emacs-guix-program 'heks/guix-program "2026-10")
(define-obsolete-variable-alias 'heks-emacs-scheme-guile-program 'heks/scheme-guile-program "2026-10")
(define-obsolete-variable-alias 'heks-emacs-scheme-guild-program 'heks/scheme-guild-program "2026-10")
(define-obsolete-variable-alias 'heks-emacs-scheme-guix-repl-p 'heks/scheme-guix-repl-p "2026-10")
(define-obsolete-variable-alias 'heks-emacs-scheme-guile-warning-level 'heks/scheme-guile-warning-level "2026-10")
(define-obsolete-variable-alias 'heks-emacs-scheme-guile-compile-flymake 'heks/scheme-guile-compile-flymake "2026-10")
(define-obsolete-variable-alias 'heks-emacs-guix-lint-flymake 'heks/guix-lint-flymake "2026-10")
(define-obsolete-variable-alias 'heks-emacs-guix-style-flymake 'heks/guix-style-flymake "2026-10")
(define-obsolete-variable-alias 'heks-emacs-guix-lint-checkers 'heks/guix-lint-checkers "2026-10")
(define-obsolete-variable-alias 'heks-emacs-guix-style-rules 'heks/guix-style-rules "2026-10")
(define-obsolete-variable-alias 'heks-emacs-clone-dir 'heks/clone-dir "2026-10")
(define-obsolete-variable-alias 'heks-emacs-notes-dir 'heks/notes-dir "2026-10")
(define-obsolete-variable-alias 'heks-emacs-theme 'heks/theme "2026-10")
(define-obsolete-variable-alias 'heks-emacs-font-mono 'heks/font-mono "2026-10")
(define-obsolete-variable-alias 'heks-emacs-font-sans 'heks/font-sans "2026-10")
(define-obsolete-variable-alias 'heks-emacs-font-serif 'heks/font-serif "2026-10")
(define-obsolete-variable-alias 'heks-emacs-base-font-size 'heks/base-font-size "2026-10")
(define-obsolete-variable-alias 'heks-emacs-prose-scale 'heks/prose-scale "2026-10")
(define-obsolete-variable-alias 'heks-emacs-window-divider-contrast 'heks/window-divider-contrast "2026-10")
(define-obsolete-variable-alias 'heks-emacs-window-divider-colors 'heks/window-divider-colors "2026-10")
(define-obsolete-variable-alias 'heks-emacs-window-divider-places 'heks/window-divider-places "2026-10")
(define-obsolete-variable-alias 'heks-emacs-standup-people 'heks/standup-people "2026-10")
(define-obsolete-variable-alias 'heks-emacs-standup-buffer-name 'heks/standup-buffer-name "2026-10")
(define-obsolete-variable-alias 'heks-emacs-java-debug-jar 'heks/java-debug-jar "2026-10")
(define-obsolete-variable-alias 'heks-emacs-java-debug-cache-dir 'heks/java-debug-cache-dir "2026-10")
(define-obsolete-variable-alias 'heks-emacs-java-debug-port 'heks/java-debug-port "2026-10")
(define-obsolete-variable-alias 'heks-emacs-import-into-notes 'heks/import-into-notes "2026-10")
(define-obsolete-variable-alias 'heks-emacs-import-title-from-heading 'heks/import-title-from-heading "2026-10")
(define-obsolete-variable-alias 'heks-emacs-preview-buffer-name 'heks/preview-buffer-name "2026-10")
(define-obsolete-variable-alias 'heks-emacs-preview-follow-on-save 'heks/preview-follow-on-save "2026-10")
(define-obsolete-variable-alias 'heks-emacs-render-toc-headings 'heks/render-toc-headings "2026-10")
(define-obsolete-variable-alias 'heks-emacs-scheme-lint-enabled 'heks/scheme-lint-enabled "2026-10")
(define-obsolete-variable-alias 'heks-emacs-shfmt-program 'heks/shfmt-program "2026-10")
(define-obsolete-variable-alias 'heks-emacs-shfmt-flymake 'heks/shfmt-flymake "2026-10")
(define-obsolete-variable-alias 'heks-emacs-shfmt-arguments 'heks/shfmt-arguments "2026-10")

(provide 'heks/heks-emacs)

;;; heks-emacs.el ends here
