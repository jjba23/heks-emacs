;;; heks-emacs.el --- heks-emacs configuration for Emacs -*- lexical-binding: t -*-

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

;; heks-emacs configuration for Emacs

;;; Code:

(defgroup heks-emacs ()
  "HEKS-EMACS customization group."
  :group 'tools)

(defcustom heks-emacs-clone-dir nil
  "The directory where the HEKS-EMACS source code is located."
  :type 'string)

(defcustom heks-emacs-notes-roam-dir nil
  "The directory where the Org roam notes should be stored."
  :type 'string)

(defcustom heks-emacs-theme nil
  "The name of the Emacs theme to use, acording to HEKS-EMACS palette."
  :type 'symbol)

(defcustom heks-emacs-font-mono "IBM Plex Mono"
  "The font family to use for monospaced fonts."
  :type 'string)

(defcustom heks-emacs-font-sans "IBM Plex Sans"
  "The font family to use for sans-serif fonts."
  :type 'string)

(defcustom heks-emacs-font-serif "IBM Plex Serif"
  "The font family to use for serif fonts."
  :type 'string)

(defcustom heks-emacs-standup-people '("Joe" "Giga" "Yury" "Semih" "Soroush" "Eduard" "Andrian" "Viktoria" "René")
  "The people's names to be used for random standup order."
  :type 'list)

(defcustom heks-emacs-standup-buffer-name "*Random Standup Order*"
  "The name of the buffer where we should show a random standup order."
  :type 'string)

(defun heks-emacs-joe-reconfigure ()
  "Rebuild GNU Guix Joe's configs."
  (interactive)
  (let ((default-directory (string-replace "$HOME" "~" heks-emacs-clone-dir)))
    (async-shell-command "maak jr")))

(defun heks-emacs-full-reconfigure ()
  "Fully Rebuild GNU Guix Joe's configs and Joe's user."
  (interactive)
  (let ((default-directory (string-replace "$HOME" "~" heks-emacs-clone-dir)))
    (async-shell-command "maak fr")))

(defun heks-emacs-sys-reconfigure ()
  "Rebuild GNU Guix Joe's configs."
  (interactive)
  (let ((default-directory (string-replace "$HOME" "~" heks-emacs-clone-dir)))
    (async-shell-command "maak sr")))

(defun heks-emacs-sys-update ()
  "Update GNU Guix packages."
  (interactive)
  (let ((default-directory (string-replace "$HOME" "~" heks-emacs-clone-dir)))
    (async-shell-command "maak update")))

(defun heks-emacs-uuidgen ()
  "Generate a UUID (Universally Unique Identifier) and yank it to kill ring."
  (interactive)
  (let ((uid (string-replace "\n" "" (shell-command-to-string "uuidgen"))))
    (message (format "generated UUID: %s" uid))
    (kill-new uid)))

(defun heks-emacs-uuidgen-string ()
  "Generate a UUID (Universally Unique Identifier) string.

This function executes the `uuidgen` command-line utility and returns
the generated UUID as a string, removing any trailing newline character
that the command might produce.  It relies on the `uuidgen` program
being available in your system's `exec-path`."
  (string-replace "\n" "" (shell-command-to-string "uuidgen")))

(defun heks-emacs-do-in-project (f)
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

(defun heks-emacs-project-start-repl-process ()
  "Start a REPL process for the current project using `make repl`.

This command attempts to locate the root directory of the current project
and then executes `make repl` within that directory in an asynchronous
shell process.  The output and interaction will be
available in a dedicated buffer named \"repl:PROJECT-ROOT\", where
PROJECT-ROOT is the name of the project's root directory.

It relies on `heks-emacs-do-in-project` to determine the project root. Before
running the `make` command, it inserts a separator and a message
indicating the start of the project REPL session, along with the
project directory, into the output buffer. If a buffer with the same
name already exists, it is automatically closed without prompting.

This command is designed to easily initiate a project-specific REPL
environment defined by a `Makefile` with a `repl` target, facilitating
interactive development and testing."
  (interactive)
  (heks-emacs-do-in-project (lambda(root-dir)
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

(defun heks-emacs-project-fmt ()
  "Start the formatting process for the current project using `make fmt`.

This command attempts to find the root directory of the current project
and then executes `make fmt` within that directory in an asynchronous
shell process.  The output of the formatting process will be displayed
in a dedicated buffer named \"fmt:PROJECT-ROOT\", where PROJECT-ROOT is
the name of the project's root directory.

It uses `heks-emacs-do-in-project` to identify the project root. Before
running the `make` command, it prints a separator and a message
indicating the start of the formatting process, along with the project
directory, in the output buffer. If a buffer with the same name
already exists, it is automatically closed without prompting.

This command is intended to easily initiate a project-wide code
formatting procedure defined by a `Makefile` with an `fmt` target,
helping to maintain consistent code style across the project."
  (interactive)
  (heks-emacs-do-in-project (lambda(root-dir)
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

(defun heks-emacs-project-start-dev ()
  "Start a development session for the current project using `make dev`.

This command attempts to locate the root directory of the current project
and then executes `make dev` within that directory in an asynchronous
shell process.  The output and interaction will be
available in a dedicated buffer named \"dev:PROJECT-ROOT\", where
PROJECT-ROOT is the name of the project's root directory.

It relies on `heks-emacs-do-in-project` to determine the project root. Before
running the `make` command, it inserts a separator and a message
indicating the start of the project DEV session, along with the
project directory, into the output buffer. If a buffer with the same
name already exists, it is automatically closed without prompting.

This command is designed to easily initiate a project-specific DEV
environment defined by a `Makefile` with a `dev` target, facilitating
interactive development and testing."
  (interactive)
  (heks-emacs-do-in-project (lambda(root-dir)
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

(defun heks-emacs-project-start-test ()
  "Start the test suite for the current project using `make test`.

This command attempts to locate the root directory of the current project
and then executes `make test` within that directory in an asynchronous
shell process.  The output of the test execution will be displayed in a
dedicated buffer named \"test:PROJECT-ROOT\", where PROJECT-ROOT is the
name of the project's root directory.

It uses `heks-emacs-do-in-project` to identify the project root. Before
running the `make` command, it prints a separator and a message
indicating the start of the testing process, along with the project
directory, in the output buffer. If a buffer with the same name
already exists, it is automatically closed without prompting.

This command is intended to easily initiate the project's test suite,
as defined by a `Makefile` with a `test` target, facilitating the
process of verifying the project's functionality."
  (interactive)
  (heks-emacs-do-in-project (lambda(root-dir)
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


(defun heks-emacs-guix-fmt ()
  "Format the current buffer in place using `guix style`.

This command will:
1. Determine the absolute path of the current buffer's file.
2. Execute the `guix style` command with the `-f` (format) option,
   applying the Guix code style to the file.
3. Revert the buffer, reloading the formatted content from disk.
4. Display informative messages in the minibuffer indicating the
   start and completion of the formatting process.

Note: This command assumes that the `guix` command-line utility is
installed and accessible in your system's `exec-path`."
  (interactive)
  (let ((path (file-truename buffer-file-name)))
    (message "formatting current buffer with Guix style")
    (shell-command (format "guix style -f %s" path))
    (revert-buffer :ignore-auto :noconfirm)
    (message "formatted current buffer with Guix style")))

(defun heks-emacs-new-buffer-with-json (buffer-name data)
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
  (interactive)
  (require 'guix)
  (require 'guix-package)
  (let* ((target-package (buffer-substring (mark) (point)))
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

(defun heks-emacs-print-random-standup-order ()
  "Prints a random order of names from `heks-emacs-standup-people` in a new buffer."
  (interactive)
  (unless heks-emacs-standup-people
    (error "heks-emacs-standup-people is not a list.  Please check its definition"))
  (when (> 0 (length heks-emacs-standup-people))
    (error "The list of standup people is empty"))
  (ignore-errors (kill-buffer heks-emacs-standup-buffer-name))

  (let ((shuffled-people (hugot-shuffle (copy-sequence heks-emacs-standup-people))))
    (get-buffer-create heks-emacs-standup-buffer-name)
    (with-current-buffer heks-emacs-standup-buffer-name
      (insert "* Random Standup Order\n\n")
      (insert "Generated on: " (format-time-string "%Y-%m-%d %H:%M:%S") "\n\n")

      (dolist (person shuffled-people)
        (insert (format "%s\n" person)))
      (org-mode))
    (switch-to-buffer heks-emacs-standup-buffer-name)))

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

(provide 'heks-emacs/heks-emacs)

;;; heks-emacs.el ends here
