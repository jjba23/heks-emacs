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

(defcustom heks-emacs-ews-music-directory "~/Muziek"
  "My personal main directory where to read music from."
  :type 'string)

(defcustom heks-emacs-clone-dir nil
  "The directory where the HEKS-EMACS (Supreme Sexp System) source code is located."
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

(defcustom heks-emacs-standup-people '("Joe"
                                       "Marcel"
                                       "Andrei"
                                       "Bram"
                                       "Rasim"
                                       "Thibault")
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
    (error "heks-emacs-standup-people is not a list.  Please check its definition."))
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

;; ------------ Maak tasks ------------
(defgroup maak nil
  "Customizations for the maak task runner."
  :group 'tools)

(defface maak-task-arguments-face
  '((t :inherit font-lock-variable-name-face :italic t))
  "Face used to render task arguments in the minibuffer."
  :group 'maak)

(defface maak-task-documentation-face
  '((t :inherit font-lock-doc-face))
  "Face used to render task docstring annotations in the minibuffer."
  :group 'maak)

(defcustom maak-annotation-padding 4
  "Number of spaces to maintain between columns in the completion view."
  :type 'integer
  :group 'maak)

(defun maak--find-file ()
  "Find the maak.scm file in the current directory or its parents."
  (let ((dir (locate-dominating-file default-directory "maak.scm")))
    (when dir
      (expand-file-name "maak.scm" dir))))

(defun maak--get-tasks (file)
  "Extract task names, arguments, and docstrings from the given maak.scm FILE.
Returns a list of elements: (task-name docstring argument-list)."
  (let (tasks)
    (with-temp-buffer
      (emacs-lisp-mode) ; Activates standard Lisp syntax table for accurate parsing
      (insert-file-contents file)
      (goto-char (point-min))
      (while (re-search-forward "^[[:space:]]*([[:space:]]*define[[:space:]]+(\\([a-zA-Z0-9_-]+\\)" nil t)
        (let ((task (match-string 1))
              (docstring "")
              (args nil))
          (save-excursion
            (goto-char (match-beginning 1))
            (backward-char 1)                     ; Move to the opening '(' of the signature
            (condition-case nil
                (progn
                  (forward-sexp 1)                ; Move past the signature: (task-name arg1 ...)
                  (let ((sig-end (point)))
                    (save-excursion
                      (goto-char (match-end 1))   ; Jump right past the task name inside signature
                      (let ((args-str (buffer-substring-no-properties (point) (1- sig-end))))
                        ;; Split by whitespace to extract argument names
                        (setq args (split-string args-str "[[:space:]\n\r]+" t)))))
                  ;; Move forward to capture optional docstring string literal
                  (forward-comment (point-max))
                  (when (eq (char-after) ?\")
                    (let ((start (point)))
                      (forward-sexp 1)
                      (setq docstring (buffer-substring-no-properties (1+ start) (1- (point)))))))
              (error nil)))
          (push (list task docstring args) tasks)))
      (nreverse tasks))))

(defun maak--make-annotation-function (tasks)
  "Return an annotation function formatted dynamically for TASKS columns."
  (let* ((max-task-len (seq-max (mapcar (lambda (cell) (length (car cell))) tasks)))
         (args-align (+ max-task-len 2))
         ;; Compute width for the third column alignment (Task Name + Arguments)
         (max-total-len (seq-max (mapcar (lambda (cell)
                                           (let ((args (nth 2 cell)))
                                             (+ max-task-len
                                                (if args
                                                    (+ 2 (length (string-join args " ")))
                                                  0))))
                                         tasks)))
         (doc-align (+ max-total-len maak-annotation-padding)))
    (lambda (cand)
      (let* ((meta (assoc cand tasks))
             (doc (nth 1 meta))
             (args (nth 2 meta))
             (args-str (if args (string-join args " ") ""))
             (summary (if (and doc (not (string= doc "")))
                          (car (split-string doc "\n"))
                        "")))
        (concat
         (if args
             (concat (propertize " " 'display `(space :align-to ,args-align))
                     (propertize args-str 'face 'maak-task-arguments-face))
           "")
         (if (not (string= summary ""))
             (concat (propertize " " 'display `(space :align-to ,doc-align))
                     (propertize summary 'face 'maak-task-documentation-face))
           ""))))))

(defun maak-read-task ()
  "Prompt the user to select a task and dynamically input arguments.
Returns a list of the format: (task-name (arg-value1 arg-value2 ...))"
  (let ((file (maak--find-file)))
    (unless file
      (user-error "No maak.scm found in this directory or its parents"))
    (let ((tasks (maak--get-tasks file)))
      (unless tasks
        (user-error "No runnable tasks found in %s" file))
      (let* ((completion-extra-properties
              `(:annotation-function ,(maak--make-annotation-function tasks)))
             (task-name (completing-read "Run maak task: " tasks nil t))
             (meta (assoc task-name tasks))
             (args-meta (nth 2 meta))
             (arg-vals nil))
        ;; Loop and prompt sequentially for each defined task argument
        (dolist (arg args-meta)
          (push (read-string (format "Argument <%s>: " arg)) arg-vals))
        (list task-name (nreverse arg-vals))))))

;;;###autoload
(defun maak-run-task (task args)
  "Select and run a TASK with ARGS from the local maak.scm file."
  (interactive (maak-read-task))
  (let* ((file (maak--find-file))
         (dir (file-name-directory file)))
    (let ((default-directory dir))
      ;; Build safely escaped command list, executing: maak <task> <arg1> <arg2>...
      (let ((command (mapconcat #'shell-quote-argument (cons "maak" (cons task args)) " ")))
        (compile command)))))

(keymap-global-set "C-c m r" #'maak-run-task)

(provide 'heks-emacs/heks-emacs)

;;; heks-emacs.el ends here
