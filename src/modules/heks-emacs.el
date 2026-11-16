;;; heks-emacs.el --- heks-emacs configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; heks-emacs configuration for Emacs

;;; Code:

(defgroup heks ()
  "HEKS-EMACS customization group."
  :group 'tools)

(defconst heks/version "1.35.0"
  "The version of this configuration.

It is the number in the release notes' newest section and the tag on the
commit, and `heks/about' is where a reader finds it without opening the
changelog.  One number, named in one place: the release is the diff
between this and the tag before it.")

(defconst heks/module-declarations
  '(
    ;; `heks-emacs.el' is loaded by `init.el' before the list -- it is where
    ;; the settings, the version and this table live -- and `darwin.el' is
    ;; loaded by name on macOS only; the check wants a declaration for every
    ;; file in `src/modules', so the two are declared first.
    (:module heks-emacs
     :purpose "The configuration itself: its version, its settings, its about, its project tasks."
     :topics ())
    (:module darwin
     :purpose "The things that are only true on macOS, loaded before the modules that read them."
     :topics ())
    (:module ai
     :purpose "Two front ends, GPTel and ECA, over the provider a project records."
     :topics ("x"))
    (:module common-lisp
     :purpose "Common Lisp, through SLY and SBCL."
     :topics ())
    (:module completion
     :purpose "The minibuffer and the completion at point: Vertico and Corfu."
     :topics ("p"))
    (:module consult
     :purpose "Consult's searching commands, which read whatever has been typed."
     :topics ())
    (:module dashboard
     :purpose "The start screen, which says where a session can begin."
     :topics ("SPC"))
    (:module dev-langs
     :purpose "The modes of the languages this configuration edits."
     :topics ())
    (:module dev-tools
     :purpose "Editing helpers, the doctor, and the tools that belong to no language."
     :topics ("!" "c" "e" "t" "z"))
    (:module dev-flymake
     :purpose "Flymake's checkers, and keeping them beside a language server."
     :topics ())
    (:module dev-hover
     :purpose "The documentation that follows the pointer."
     :topics ("i"))
    (:module dev-formats
     :purpose "Data formats, the JVM languages, and the debugger."
     :topics ("b" "j"))
    (:module dev-kubernetes
     :purpose "Kubernetes, and reading the JSON log a container writes."
     :topics ("C-c" "C-f" "C-g" "C-t" "U" "u"))
    (:module dev-folding
     :purpose "Folding and navigation, by Hideshow and Tree-sitter."
     :topics ())
    (:module dev-project
     :purpose "The project: its tasks, EditorConfig, Maak, Terraform, SQL and the languages in it."
     :topics ("m" "w"))
    (:module dd
     :purpose "Burning an ISO to a device, for when there is no dd in the muscle memory."
     :topics ())
    (:module dired
     :purpose "Dired, with the extras that make a directory a place to work."
     :topics ())
    (:module duplicates
     :purpose "The code a project writes more than once."
     :topics ())
    (:module editor
     :purpose "The editor itself: editing as root, growing the region, jumping by its letter."
     :topics ("#" "z"))
    (:module eglot
     :purpose "The language server, and which server each language gets."
     :topics ("i" "j"))
    (:module emacs-core
     :purpose "The key scheme, the settings, and the base the other modules are read on."
     :topics ("!" "#" "d" "h" "i" "j" "l" "t" "v" "w"))
    (:module irc
     :purpose "IRC, through Circe."
     :topics ())
    (:module git
     :purpose "Git, through Magit, with delta drawing its diffs."
     :topics ())
    (:module github-repo
     :purpose "A GitHub repository's settings, captured, applied and verified."
     :topics ())
    (:module go
     :purpose "Go, through go-mode."
     :topics ())
    (:module guile
     :purpose "Guile, Guix and Artanis: the REPL, the debugger and its traps."
     :topics ("g" "s"))
    (:module help
     :purpose "The documentation of what is at point, and the tour for a new reader."
     :topics ("h"))
    (:module import
     :purpose "A Markdown file or region, read into the notes as Org."
     :topics ("n"))
    (:module libs
     :purpose "The libraries the rest of the packages are built on."
     :topics ())
    (:module notes
     :purpose "The notes: one Org file per note, its topics and its index pages."
     :topics ("n"))
    (:module notes-graph
     :purpose "The notes as a graph in the browser, and as a folding outline."
     :topics ("n"))
    (:module notes-auto
     :purpose "The two things a note used to need a person for: its tags and its backlinks."
     :topics ("n"))
    (:module agenda
     :purpose "The day: the agenda, the habits and the birthdays."
     :topics ("n"))
    (:module bookmarks
     :purpose "bookmarks.org: the categories a bookmark is filed under, and the way in."
     :topics ("n"))
    (:module contacts
     :purpose "contacts.org: the people, their addresses and their birthdays."
     :topics ("n"))
    (:module macros
     :purpose "Recorded macros, and the package that shows how one was recorded."
     :topics ())
    (:module mail
     :purpose "Gnus."
     :topics ("o"))
    (:module maps
     :purpose "Maps, through osm."
     :topics ())
    (:module markdown
     :purpose "Markdown, read twice: rendered to look at, and imported to work in."
     :topics ())
    (:module misc
     :purpose "The odds and ends: the diary, speed-type, a PDF of a buffer."
     :topics (";"))
    (:module music
     :purpose "A fretboard to write a chord on, and orpheus over MPD to play it."
     :topics ())
    (:module onefetch
     :purpose "A repository as onefetch describes it."
     :topics ("w"))
    (:module openapi
     :purpose "An OpenAPI specification: read, checked, and the request it describes."
     :topics ("a"))
    (:module org
     :purpose "Org, and the agenda's own commands."
     :topics ("C-#" "n"))
    (:module plot
     :purpose "Diagrams, through Mermaid."
     :topics ("C-d"))
    (:module present
     :purpose "A document presented, and a deck exported."
     :topics ("r"))
    (:module proofreading
     :purpose "Spelling, wherever a sentence is being written."
     :topics ("t"))
    (:module render
     :purpose "A document as a themed page, with no network."
     :topics ("r"))
    (:module rust
     :purpose "Rust: Cargo's tasks, and a debugged crate."
     :topics ("R"))
    (:module search
     :purpose "The search, the jumps, and the occurrences of the symbol at point."
     :topics ("w" "z"))
    (:module shell
     :purpose "Eshell with this configuration's prompt, and how a shell script is checked."
     :topics ())
    (:module sift
     :purpose "sift: the formatter and the linter of the three Lisps."
     :topics ("g"))
    (:module snippets
     :purpose "Tempel's snippets, and the Scheme ones written for this configuration."
     :topics ("s"))
    (:module theme
     :purpose "The palettes, and the gallery that compares them."
     :topics ("r"))
    (:module ui
     :purpose "The look of it: faces, separators, the readable faces, text scale and padding."
     :topics ("f" "t"))
    (:module veritas
     :purpose "The Veritas test runner, from a Scheme buffer."
     :topics ("g")))
  "What each module is, and the part of the key scheme it owns.

A module is a file in `src/modules/', and this is what it says about
itself: the sentence a reader needs to know whether it is the file they
want, and the topic letters of `heks/key-topics' whose keys may be bound
in it.  The rule the check holds it to is the one the key scheme has
always implied -- a key about notes goes in `notes.el' -- so the topics
are declared here, `test/heks-emacs-modules.el' fails when a module binds
a key under a topic it did not declare, when a topic has no owner, and
when a module file and a declaration disagree, and `docs/modules.org'
carries the same table for a reader.

A topic may have several owners, because a topic is a subject rather than
a file: `C-c n' is the notes system, and `agenda.el', `notes.el',
`bookmarks.el' and the rest of that system each own it because each binds
keys under it.  What is not allowed is a key under a topic nobody
declared, which is what makes the sentence above a claim rather than a
comment.")

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

(defun heks/about ()
  "Show what this Emacs is running, in one buffer.

Which Emacs, which modules are loaded, which palette and font, which AI
provider a session uses and which version of this configuration it is:
the question a bug report starts with, answered from the running Emacs
rather than from this file's prose.  It is the one place the answers are
read together, so nothing here is a setting a second time; a value that
was never given -- no theme, no provider, no notes directory -- says so
rather than being left out."
  (interactive)
  (let* ((buffer (get-buffer-create "*heks about*"))
         (theme (or (car custom-enabled-themes) heks/theme))
         (provider (ignore-errors (heks/ai-provider)))
         (modules (if (boundp 'heks/modules) (length heks/modules) 0))
         (notes (ignore-errors (heks/notes-directory)))
         (rows (list (cons "The configuration" heks/version)
                     (cons "Emacs" emacs-version)
                     (cons "Built for" system-configuration)
                     (cons "The palette (a theme)" (or theme "the default"))
                     (cons "The font" (format "%s %s" heks/font-mono heks/base-font-size))
                     (cons "The modules loaded" modules)
                     (cons "The AI provider" (or provider "none"))
                     (cons "The notes" (or notes "not set"))
                     (cons "This directory" user-emacs-directory))))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer))
      (insert (format "heks-emacs %s\n\n" heks/version)
              "Everything below is read from the running Emacs, which is what a bug\n"
              "report asks for first; `C-c h f' and `C-c h v' answer the rest.\n\n")
      (dolist (row rows)
        (insert (format "%-24s %s\n" (car row) (cdr row))))
      (insert "\nThe keys, and what each letter of one means: ~C-c h d~ explains\n"
              "the key at point, and ~C-c h t~ walks the first five.\n")
      (special-mode)
      (goto-char (point-min)))
    (display-buffer buffer)
    buffer))

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

(defun heks/project-root (&optional directory)
  "Return the root of the project DIRECTORY is in, or nil when it is in none.

The `project' API answers -- the same `project-root' that
`project-find-file' uses -- so a project is found the way Emacs finds one
rather than by a rule of this configuration's own.  DIRECTORY defaults to
`default-directory', and a directory in no project answers nil instead of
guessing: the callers that can work without a project say so themselves
(see `heks/terraform-root').

This replaced `vc-root-dir', which is asked the same question and answers
nil unless VC happens to be turned on in the buffer (`vc-deduce-backend'
looks at the buffer's own VC state), so a key pressed in a buffer that had
no file answered nothing at all."
  (let ((directory (expand-file-name (or directory default-directory))))
    (when-let* ((project (project-current nil directory)))
      (file-name-as-directory (expand-file-name (project-root project))))))

(defcustom heks/project-task-command "maak"
  "The command that runs a task of the project a buffer is in.

It is `maak' because that is what the projects this configuration is
developed with call their task runner.  A project whose tasks are a
`Makefile`'s sets this to \"make\", and one whose runner is named
something else sets it to that: the keys do not change."
  :type 'string
  :group 'heks)

(defcustom heks/project-task-names
  '((dev . "dev") (test . "test") (fmt . "fmt") (repl . "repl"))
  "What each project task is called where the project defines it.

The keys name what a task is *for* -- `heks/project-start-test' is the
tests -- and this says what the project calls that task, so a project
whose target is `serve' rather than `dev' says so here instead of being
edited."
  :type '(alist :key-type symbol :value-type string)
  :group 'heks)

(defun heks/project-task (task)
  "Return the name the current project gives TASK."
  (or (alist-get task heks/project-task-names) (symbol-name task)))

(defun heks/project-run (task &optional interactive)
  "Run the project's TASK, showing what it says in a compilation buffer.

TASK is a symbol: `dev', `test', `fmt' or `repl'.  It runs in the
project's root (`heks/project-root') with the command and the task quoted
one by one rather than pasted into a command line, and its output is a
compilation buffer like every other build here: `C-c ! n' walks the
errors, `g' runs it again, and the escape codes a tool writes are colours.

INTERACTIVE runs the task in a comint buffer instead
(`compilation-shell-minor-mode'), which is what a REPL or a server needs:
its output is still a compilation buffer's, and what it asks for can be
typed at it.

A task that is still running is shown rather than started a second time --
pressing the key while the development server is up puts point in its
buffer, which is the answer one wants -- and pressing it after the task
ended runs it again."
  (let ((root (heks/project-root)))
    (unless root
      (user-error "No project above %s" default-directory))
    (let* ((name (heks/project-task task))
           (buffer-name (format "%s:%s" name (abbreviate-file-name root)))
           (running (get-buffer buffer-name)))
      (if (and running (get-buffer-process running))
          (pop-to-buffer running)
        (let ((default-directory root)
              (compilation-buffer-name-function
               (lambda (_mode) buffer-name)))
          (compile (concat (shell-quote-argument heks/project-task-command)
                           " " (shell-quote-argument name))
                   interactive))))))

(defun heks/project-start-repl-process ()
  "Start the project's REPL task, `repl' unless the project says otherwise.

It runs in a comint buffer (see `heks/project-run'), so the REPL can be
typed at, and a REPL that is already running is shown rather than started
twice."
  (interactive)
  (heks/project-run 'repl 'interactive))

(defun heks/project-fmt ()
  "Run the project's formatting task, `fmt' unless the project says otherwise.

The output is a compilation buffer (see `heks/project-run'), which is
where a formatter's complaints arrive as lines to walk with `C-c ! n'."
  (interactive)
  (heks/project-run 'fmt))

(defun heks/project-start-dev ()
  "Start the project's development task, `dev' unless the project says so.

It runs in a comint buffer (see `heks/project-run'), so a server that
asks something can be answered, and a server that is already up is shown
rather than started twice."
  (interactive)
  (heks/project-run 'dev 'interactive))

(defun heks/project-start-test ()
  "Run the project's tests, which is its `test' task unless it says otherwise.

The output is a compilation buffer (see `heks/project-run'), so a failing
test is a line `C-c ! n' walks to rather than text to read."
  (interactive)
  (heks/project-run 'test))


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
                    "~/.vscode/extensions/vscjava.vscode-java-debug-*/extension/server/com.microsoft.java.debug.plugin-*.jar"))
              (car (file-expand-wildcards
                    "~/.vscode-server/extensions/vscjava.vscode-java-debug-*/extension/server/com.microsoft.java.debug.plugin-*.jar"))
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

(defun heks/java-debug-cached-jar ()
  "Return a `java-debug' jar already sitting in the cache dir, or nil."
  (car (file-expand-wildcards
        (expand-file-name "com.microsoft.java.debug.plugin-*.jar"
                           heks/java-debug-cache-dir))))

(defun heks/java-debug-jar-available ()
  "Return the `java-debug' plugin jar that is already on this machine, or nil.

`heks/java-debug-jar' is the configured or auto-detected one;
`heks/java-debug-cached-jar' is a jar put in `heks/java-debug-cache-dir'
by hand.  Neither is downloaded: the plugin is distributed inside the
VS Code Java extension and the `java-debug-adapter' mason package, not
as a release asset of its own."
  (or heks/java-debug-jar (heks/java-debug-cached-jar)))

(defun heks/java-debug-ensure-jar (&optional _force)
  "Return the `java-debug' plugin jar, or nil when it is not installed.

The jar is a plugin for Eclipse JDT LS, not a standalone DAP server: it
is what gives JDT LS the `vscode.java.resolveClasspath' and
`vscode.java.startDebugSession' commands that `dape''s `jdtls'
configuration calls.  It is distributed inside the VS Code Java
extension and the `java-debug-adapter' mason package, so this looks where
those unpack it (see `heks/java-debug-jar') and in
`heks/java-debug-cache-dir'; it does not fetch from the network, because
the project publishes no release asset.  With FORCE, the same answer is
returned -- there is nothing to refresh."
  (interactive "P")
  (heks/java-debug-jar-available))

(defun heks/jvm-main-class (&optional buffer)
  "Return the class the main function of BUFFER's file lives in, or nil.

Kotlin puts a file's top-level functions in a class named after the file
with `Kt' appended, so `Main.kt' in `com.example.app' is
`com.example.app.MainKt'; a Java file's class is its own name.  The
package is read from the file, because the class the JVM is asked for is
the qualified one.  A file that names its class otherwise -- Kotlin's
`@file:JvmName' -- is what the prefix argument to `heks/jvm-debug' is
for: the prompt starts with this answer and takes another."
  (with-current-buffer (or buffer (current-buffer))
    (when-let* ((file buffer-file-name)
                (base (file-name-base file)))
      (let ((package (save-excursion
                       (goto-char (point-min))
                       (when (re-search-forward
                              "^[ \t]*package[ \t]+\\([A-Za-z0-9_.]+\\)" nil t)
                         (match-string 1)))))
        (concat (if package (concat package ".") "")
                base
                (if (string-match-p "\\.kt\\'" file) "Kt" ""))))))

(defun heks/jvm--java-files (directory)
  "Return the Java files under DIRECTORY, or nil when it is not there."
  (when (file-directory-p directory)
    (directory-files-recursively directory "\\.java\\'")))

(defun heks/jvm--java-host (&optional root)
  "Return a buffer visiting a Java file of the project at ROOT, or nil.

JDT LS is started for a Java buffer, and that buffer's Eglot server is
what `dape' asks for the classpath and for a debug port.  The current
buffer is used when it is a Java one; otherwise the first Java file of
`src/main/java', `src/test/java' or the project, leaving out the build
directories.  A Kotlin-only project has no such buffer, which is the one
case this configuration cannot debug through JDT LS."
  (let* ((project (heks/jvm--project))
         (root (file-name-as-directory
                (or root (and project (cdr project)) default-directory))))
    (cond ((derived-mode-p 'java-mode 'java-ts-mode)
           (current-buffer))
          (t
           (let ((file (or (car (heks/jvm--java-files
                                 (expand-file-name "src/main/java" root)))
                           (car (heks/jvm--java-files
                                 (expand-file-name "src/test/java" root)))
                           (car (seq-remove
                                 (lambda (file)
                                   (string-match-p "/\\(?:target\\|build\\|out\\)/"
                                                   file))
                                 (heks/jvm--java-files root))))))
             (and file (find-file-noselect file)))))))

(defun heks/jvm--eglot-server (buffer)
  "Return BUFFER's Eglot/JDT LS server, starting it when it is not running.

The `java-debug' plugin is a JDT LS bundle, so the server has to have
been started with it: `heks/eglot-java-init-opts' puts it in the
initialization options, and the capability check here says whether this
server got it.  A server started before the jar was found does not, and
is restarted with `C-c i R'."
  (require 'eglot)
  (require 'eglot-java nil t)
  (with-current-buffer buffer
    (when (fboundp 'eglot-java-mode)
      (eglot-java-mode 1))
    ;; `eglot-ensure' is a no-op in some non-interactive paths; the
    ;; `eglot' command is the one that guesses the contact and starts the
    ;; server, and it is what a person would run.
    (unless (eglot-current-server)
      (call-interactively #'eglot))
    (let ((tries 300))
      (while (and (not (eglot-current-server)) (> tries 0))
        (sit-for 0.2)
        (setq tries (1- tries))))
    (let ((server (eglot-current-server)))
      (unless server
        (user-error "Eglot did not start for %s; its log is `C-c i E'"
                    (buffer-file-name buffer)))
      (unless (seq-contains-p (eglot--server-capable
                               :executeCommandProvider :commands)
                              "vscode.java.resolveClasspath")
        (user-error "JDT LS is running without the `java-debug' plugin; set `heks/java-debug-jar' and restart the server with `C-c i R'"))
      server)))

(defun heks/jvm--main-class (server root &optional named)
  "Return NAMED, or the Java main class JDT LS finds in ROOT.

`vscode.java.resolveMainClass' is the JDT LS command that lists the main
classes of the project named by ROOT's directory.  The first is the
answer when the user did not name one; a Kotlin-only project has none,
and the caller says to use a prefix argument."
  (or named
      (ignore-errors
        (let ((classes (eglot-execute-command
                        server "vscode.java.resolveMainClass"
                        (file-name-nondirectory (directory-file-name root)))))
          (and (> (length classes) 0)
               (plist-get (aref classes 0) :mainClass))))))

(defun heks/jvm--project-name (server root)
  "Return the JDT LS project name for ROOT, or its directory name.

JDT LS names an imported project after the Maven/Gradle project, and
`vscode.java.resolveMainClass' is the command that says which one the
main class belongs to.  A Kotlin-only project has no Java main class for
that command to answer with, so the directory name is the fallback --
which is the artifactId in the projects this is used on."
  (or (ignore-errors
        (let ((classes (eglot-execute-command
                        server "vscode.java.resolveMainClass"
                        (file-name-nondirectory (directory-file-name root)))))
          (and (> (length classes) 0)
               (plist-get (aref classes 0) :projectName))))
      (file-name-nondirectory (directory-file-name root))))

(defun heks/jvm-debug (&optional main-class)
  "Debug the JVM project of this buffer with `dape' and JDT LS.

The session is dape's `jdtls' configuration: it asks Eglot's JDT LS for
the project's classpath and for a debug port (`vscode.java.resolveClasspath'
and `vscode.java.startDebugSession'), and attaches to that port.  The
`java-debug' plugin is what gives JDT LS those commands; it is loaded as
a JDT LS bundle by `heks/eglot-java-init-opts', from the jar
`heks/java-debug-jar' names or finds.

Eglot runs in a Java buffer of the project, because that is what JDT LS
manages.  Without a prefix argument the main class is the one JDT LS
finds; with one, the prompt offers `heks/jvm-main-class' -- a Kotlin
`Main.kt' is `MainKt' -- and the class named is the one debugged.  A
Kotlin-only project has no Java buffer for JDT LS, and says so rather
than starting a session that cannot work."
  (interactive
   (list (when current-prefix-arg
           (let ((class (read-string "Main class: "
                                     (or (heks/jvm-main-class) ""))))
             (unless (string-empty-p class) class)))))
  (require 'dape)
  (let* ((project (heks/jvm--project))
         (root (and project (cdr project)))
         (host (and root (heks/jvm--java-host root))))
    (unless project
      (user-error "No pom.xml or Gradle build found above %s" default-directory))
    (unless host
      (user-error "No Java source in %s; JDT LS debugs through a Java buffer.  Add one, or use a Kotlin debug adapter"
                  root))
    (unless (heks/java-debug-ensure-jar)
      (user-error "No `java-debug' plugin jar found; JDT LS needs it.  Put one in %s or set `heks/java-debug-jar'"
                  heks/java-debug-cache-dir))
    (let ((server (heks/jvm--eglot-server host)))
      (with-current-buffer host
        (let ((config (copy-tree (alist-get 'jdtls dape-configs))))
          (unless config
            (user-error "This dape has no `jdtls' configuration; update dape"))
          ;; The three values the `jdtls' configuration normally computes
          ;; are strings here: the functions in it are not JSON, and the
          ;; `fn' it runs would send them to JDT LS as they are.
          (setq config (plist-put config :filePath (buffer-file-name host)))
          ;; Start the program paused: a session that runs to the end before
          ;; the first breakpoint can be placed is a session that cannot be
          ;; debugged, and a breakpoint in `main' is the one every trip
          ;; starts with.
          (setq config (plist-put config :stopOnEntry t))
          (setq config (plist-put config :projectName
                                  (heks/jvm--project-name server root)))
          (let ((class (heks/jvm--main-class server root main-class)))
            (unless class
              (user-error "No main class found; name one with `C-u C-c j d'"))
            (setq config (plist-put config :mainClass class)))
          (dape config))))))

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
`heks/format-dispatch' (sift for Scheme, for instance), the
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
;;     are the diagnostics (`shfmt', `gofmt', `rustfmt', `nixfmt') --
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
            ;; `-U0' hunk headers, not GNU's line formats: BSD diff (macOS)
            ;; has only the former.
            (call-process "diff" nil t nil "-U0" before after)
            (let ((lines '()))
              (goto-char (point-min))
              (while (re-search-forward
                      "^@@ -\\([0-9]+\\)\\(?:,\\([0-9]+\\)\\)? " nil t)
                (let ((first (string-to-number (match-string 1)))
                      (count (if (match-string 2)
                                 (string-to-number (match-string 2))
                               1)))
                  (dotimes (offset count)
                    (push (+ first offset) lines))))
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
            instance \"shfmt\"."
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
(define-obsolete-variable-alias 'heks-emacs-guix-lint-checkers 'heks/guix-lint-checkers "2026-10")
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
(define-obsolete-variable-alias 'heks-emacs-import-into-notes 'heks/import-into-notes "2026-10")
(define-obsolete-variable-alias 'heks-emacs-import-title-from-heading 'heks/import-title-from-heading "2026-10")
(define-obsolete-variable-alias 'heks-emacs-preview-buffer-name 'heks/preview-buffer-name "2026-10")
(define-obsolete-variable-alias 'heks-emacs-preview-follow-on-save 'heks/preview-follow-on-save "2026-10")
(define-obsolete-variable-alias 'heks-emacs-render-toc-headings 'heks/render-toc-headings "2026-10")
(define-obsolete-variable-alias 'heks-emacs-shfmt-program 'heks/shfmt-program "2026-10")
(define-obsolete-variable-alias 'heks-emacs-shfmt-flymake 'heks/shfmt-flymake "2026-10")
(define-obsolete-variable-alias 'heks-emacs-shfmt-arguments 'heks/shfmt-arguments "2026-10")

(provide 'heks/heks-emacs)

;;; heks-emacs.el ends here
