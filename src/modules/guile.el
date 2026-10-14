;;; guile.el --- Guile Scheme and Guix development -*- lexical-binding: t -*-

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

;; Guile Scheme and Guix development, with the REPL in the middle of the
;; workflow instead of at the end of it.
;;
;; The REPL:
;;
;;   `C-c g r'   start or switch to the current project's REPL.  In a Guix
;;               buffer that is a Guix REPL (`guix repl', or whatever
;;               Emacs-Guix's `guix-repl-guile-program' builds when it knows
;;               where the Guix sources are), elsewhere it is a plain
;;               `guile'.  The project root is on Guile's load path, so
;;               `(use-modules (my project))' just works, and the REPL is
;;               kept per project.
;;   `C-c g R'   restart the REPL (after breaking the running image).
;;   `C-c g e'   evaluate the definition at point, `C-c g E' the region or
;;               the buffer, `C-c g b' load the file into the REPL,
;;               `C-c g i' interrupt a runaway evaluation.
;;   `C-c g x'   run the file as a script, with the project root on the load
;;               path, for those times a reproduction is faster than a REPL.
;;
;; Ares RS and arei are the second engine, for the asynchronous
;; image-oriented workflow:
;;
;;   `C-c g a'   start the Ares RS nREPL server for the project and connect
;;               arei to it as soon as it publishes its port (and, when
;;               `guile-ares-rs' still has to be built, the server buffer is
;;               the build log).
;;   `C-c g A'   connect arei to an already running server.
;;   `C-c g d'   jump back to the debugger buffer after an exception.
;;   `C-c g t'   run the project's tests inside the running image.
;;
;; `heks-emacs-scheme-repl-backend' decides which engine is used: the default
;; `auto' prefers arei when the Ares server is installed and falls back to
;; Geiser, so an existing installation is used while a full one is not.
;; Geiser's own bindings (`C-c C-z', `C-c C-a', ...) stay available in the
;; buffers that use it; arei keeps its `C-c C-e'/`C-c C-t'/`C-c M-m' maps.
;;
;; Checking and formatting use the project's own tools, on save:
;;
;;   * `heks-emacs-guix-lint-flymake' runs `guix lint' on the package defined
;;     in the buffer, so Guix's checkers (synopsis, inputs, formatting,
;;     CVEs, ...) appear as Flymake diagnostics.  `guix lint' loads the whole
;;     Guix module tree, so the backend runs on save and lints the file on
;;     disk, not on every keystroke.
;;   * `heks-emacs-guix-style-flymake' runs `guix style' on a copy of the
;;     buffer and reports the lines it would rewrite.
;;   * `C-c g L' lints the buffer with output you can click through,
;;     `C-c g f' formats it in place, `C-c g S' applies one of Guix's styling
;;     rules (`inputs', `arguments', `git-source') and reloads the buffer.
;;   * `guix-devel-mode' is enabled in Guix buffers, which brings Emacs-Guix's
;;     own C-c . bindings: lint (`C-c . l'), build the package definition
;;     (`C-c . b'), its source (`C-c . s'), download it (`C-c . d') and
;;     `C-c . u' to insert a `use-modules' clause for a module at point.
;;
;; Folding is Hideshow, with the keys the Tree-sitter folding uses everywhere
;; else (`C-c v ...'), because this Emacs has no Scheme grammar.  A Scheme
;; buffer is a sequence of top-level forms, so each of those is a block:
;; collapsing the definition you are in works from anywhere inside it,
;; `C-c v m' collapses the file to one line per definition and `C-c v r'
;; brings it back.
;;
;; Project tasks stay Maak's: `C-c w r', `C-c w f', `C-c w t' and `C-c w d'
;; run the project's `repl', `fmt', `test' and `dev' tasks, and `C-c m r'
;; (`maak-run-task') lists everything the closest `maak.scm' exports.
;; `C-c g t' is the same idea from inside the image, for the arei workflow.

;;; Code:

(require 'cl-lib)
(require 'flymake)
(require 'hideshow)
(require 'scheme)

;;;
;;; Customization
;;;

(defcustom heks-emacs-scheme-repl-backend 'auto
  "REPL engine used for Guile buffers.

`auto' uses arei when the Ares RS server is installed and Geiser
otherwise, `arei' forces the Ares workflow and `geiser' forces Geiser."
  :type '(choice (const :tag "Ares when available, else Geiser" auto)
                 (const :tag "Ares RS (arei)" arei)
                 (const :tag "Geiser" geiser))
  :group 'heks-emacs)

(defcustom heks-emacs-scheme-guix-repl-p t
  "Whether Guix buffers get a Guix REPL instead of a plain Guile one.

Guix's own modules are only importable from a Guix REPL, so this is what
makes `(use-modules (guix packages))' work at the REPL of a package
buffer."
  :type 'boolean
  :group 'heks-emacs)

(defcustom heks-emacs-guix-program "guix"
  "Name of the `guix' executable."
  :type 'string
  :group 'heks-emacs)

(defcustom heks-emacs-ares-server-command nil
  "Command list starting the Ares RS nREPL server.

When nil, a locally installed `ares-nrepl' is used, and `guix shell'
builds `guile-ares-rs' when there is none; the upstream spelling of the
latter is

  guix shell guile-next guile-ares-rs -- \\
    guile -c \\='((@ (ares server) run-nrepl-server))\\='"
  :type '(repeat string)
  :group 'heks-emacs)

(defcustom heks-emacs-guix-lint-checkers nil
  "Checkers passed to `guix lint' with -c.

nil means every checker the installed Guix provides; `guix lint
--list-checkers' lists the names.  Network checks are always disabled
(-n), because linting runs on every save."
  :type '(repeat string)
  :group 'heks-emacs)

(defcustom heks-emacs-guix-lint-flymake t
  "Whether `guix lint' runs as a Flymake backend in Guix buffers."
  :type 'boolean
  :group 'heks-emacs)

(defcustom heks-emacs-guix-style-flymake t
  "Whether `guix style' reports formatting drift as a Flymake backend."
  :type 'boolean
  :group 'heks-emacs)

(defcustom heks-emacs-guix-style-rules '("format" "inputs" "arguments" "git-source")
  "Styling rules offered by `heks-emacs-guix-style-apply-rule'."
  :type '(repeat string)
  :group 'heks-emacs)

;;;
;;; Where are we?
;;;

(defun heks-emacs-guix-project-root (&optional dir)
  "Return the root of the Guix project around DIR, or nil.

A directory counts as a Guix project when it holds a channel or
manifest file, or when it looks like a Guix checkout (both a `gnu' and a
`guix' sub-directory)."
  (let ((dir (file-name-as-directory (expand-file-name (or dir default-directory))))
        (found nil))
    (while (and (not found) dir)
      (when (or (cl-some (lambda (name) (file-exists-p (expand-file-name name dir)))
                         '("guix.scm" "manifest.scm" ".guix-channel"))
                (and (file-directory-p (expand-file-name "gnu" dir))
                     (file-directory-p (expand-file-name "guix" dir))))
        (setq found dir))
      (let ((parent (file-name-directory (directory-file-name dir))))
        (setq dir (unless (equal parent dir) parent))))
    (or found
        (when (fboundp 'project-root)
          (ignore-errors (project-root (project-current nil dir)))))))

(defun heks-emacs-guix-buffer-p ()
  "Return non-nil when the current buffer defines Guix packages.

A Guix package file defines something public and mentions Guix, in
whichever order (the `use-modules' clause usually comes first).  The check
is textual on purpose: it must work on a buffer that has never been loaded
by Guile, which is exactly when linting it is useful."
  (and (derived-mode-p 'scheme-mode)
       (save-excursion
         (goto-char (point-min))
         (when (re-search-forward "^\\s-*(define-public\\b" nil t)
           (save-excursion
             (goto-char (point-min))
             (and (re-search-forward "(guix\\b" nil t) t))))))

;;;
;;; Reading the buffer
;;;

(defun heks-emacs-scheme--forms ()
  "Return the top-level forms of the buffer as (FORM START END) triples.

A malformed buffer yields whatever could be read before the error, so a
half-written definition never breaks the callers."
  (let ((forms '()))
    (save-excursion
      (goto-char (point-min))
      (condition-case nil
          (catch 'done
            (while t
              (forward-comment (point-max))
              (when (eobp) (throw 'done nil))
              (let ((start (point)))
                (push (list (read (current-buffer)) start (point)) forms))))
        (error nil)))
    (nreverse forms)))

(defun heks-emacs-scheme--definition-region ()
  "Return (START END) of the top-level definition around point, or nil.

A definition enclosing point wins over one merely preceding it, so point
anywhere inside a package definition finds that package."
  (let* ((point (point))
         (definitions
          (cl-loop for (form start end) in (heks-emacs-scheme--forms)
                   when (memq (car-safe form) '(define define-public))
                   collect (cons start end)))
         (enclosing (cl-find-if (lambda (region) (and (>= point (car region))
                                                     (<= point (cdr region))))
                                definitions))
         (preceding (cl-find-if (lambda (region) (< (cdr region) point))
                                (reverse definitions))))
    (or enclosing preceding)))

(defun heks-emacs-scheme-module-name ()
  "Return the module name of the current buffer, or nil.

The name is a list of symbols, as in `(define-module (gnu packages base))'."
  (let ((form (cl-find-if (lambda (entry) (eq 'define-module (car-safe (nth 0 entry))))
                          (heks-emacs-scheme--forms))))
    (car-safe (cdr-safe (nth 0 form)))))

(defun heks-emacs-scheme-definition-name ()
  "Return the name of the definition at point, or nil."
  (let ((form (cl-find-if (lambda (entry)
                            (and (memq (car-safe (nth 0 entry)) '(define define-public))
                                 (let ((region (cons (nth 1 entry) (nth 2 entry))))
                                   (and (>= (point) (car region)) (<= (point) (cdr region))))))
                          (heks-emacs-scheme--forms))))
    (car-safe (cdr-safe (nth 0 form)))))

(defun heks-emacs-guix-package-expression ()
  "Return a `guix lint' -e expression for the package defined at point.

The expression loads the buffer's file and then refers to the package
through its module: loading it first makes the expression work whether or
not the file sits where Guix would look for a module with that name (a
scratch file, or a channel whose file is named differently), and it is
what makes the diagnostic come back with the location of the definition.
Return nil when the buffer is not a Guix package file."
  (when (heks-emacs-guix-buffer-p)
    (let ((module (heks-emacs-scheme-module-name))
          (name (heks-emacs-scheme-definition-name))
          (file buffer-file-name))
      (when (and module name file)
        (format "(begin (load %S) (@ (%s) %s))"
                file (mapconcat #'symbol-name module " ") name)))))

(defun heks-emacs-guix-lint-load-path ()
  "Return the directory to hand to `guix lint' with -L.

The project root is used when there is one, since that is what makes the
buffer's own module importable."
  (or (heks-emacs-guix-project-root)
      (when buffer-file-name (file-name-directory (expand-file-name buffer-file-name)))
      default-directory))

;;;
;;; Interpreting the output of the Guix tools
;;;

(defun heks-emacs-guix--strip-escapes (string)
  "Return STRING without ANSI escapes or terminal hyperlinks.

Guix colourises its diagnostics and, on a terminal, wraps the file name
in an OSC 8 hyperlink, which would hide the FILE:LINE:COLUMN structure
this module reads.  The processes started here ask for plain output, and
this makes the reading work even when something still decorates it."
  (when string
    (let ((stripped string))
      ;; OSC 8 hyperlinks, terminated by BEL or by ST (escape backslash).
      (setq stripped (replace-regexp-in-string
                      "\e\\]8;;[^\a\e]*\\(?:\a\\|\e\\\\\\)" "" stripped))
      ;; Anything else, such as colours.
      (setq stripped (replace-regexp-in-string "\e\\[[0-9;?]*[a-zA-Z]" "" stripped))
      stripped)))

(defun heks-emacs-guix--parse-lint-output (output)
  "Parse the OUTPUT of `guix lint' into (FILE LINE COLUMN MESSAGE) entries.

Each diagnostic is printed on its own line as FILE:LINE:COLUMN:MESSAGE,
where FILE is the file the diagnostic belongs to, which is not
necessarily the file that was linted."
  (let ((entries '()))
    (dolist (line (split-string (heks-emacs-guix--strip-escapes output) "\n" t))
      (when (string-match "\\`\\(.*\\):\\([0-9]+\\):\\([0-9]+\\): \\(.*\\)\\'" line)
        (push (list (match-string 1 line)
                    (string-to-number (match-string 2 line))
                    (string-to-number (match-string 3 line))
                    (match-string 4 line))
              entries)))
    (nreverse entries)))

(defun heks-emacs-guix--entry-belongs-to-p (entry file root)
  "Return non-nil when ENTRY describes FILE, resolved against ROOT.

`guix lint' prints absolute paths when the file was loaded by absolute
path, and paths relative to the load path when one was given (-L), which
is why FILE is also resolved against ROOT."
  (and file
       (let ((entry-file (nth 0 entry)))
         (or (equal entry-file file)
             (equal (expand-file-name entry-file root) file)
             (equal (expand-file-name entry-file root) (file-truename file))))))

(defun heks-emacs-guix--line-position (line &optional column)
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

(defun heks-emacs-guix--line-ferrors (error)
  "Return a one-line description of the Guix ERROR output, or nil.

`guix lint' reports the problems it cannot attach to a file (a module
that fails to load, say) on standard error instead of in the diagnostic
format.  Emacs' own `Process ...' notices land in that buffer too, and a
Guile prompt is not an error either."
  (car (seq-filter (lambda (line)
                     (and (string-match-p "\\`[^ \t\n]" line)
                          (not (string-match-p "\\`\\(?:Process \\|Enter \\|scheme@\\)" line))))
                   (split-string (heks-emacs-guix--strip-escapes error) "\n" t))))

(defun heks-emacs-guix--number-ranges (numbers)
  "Group the sorted NUMBERS into (FIRST . LAST) ranges."
  (let ((ranges '()))
    (dolist (number numbers)
      (let ((last (car ranges)))
        (if (and last (= number (1+ (cdr last))))
            (setcdr last number)
          (push (cons number number) ranges))))
    (nreverse ranges)))

(defun heks-emacs-guix--style-changed-lines (original styled)
  "Return the line numbers of ORIGINAL that differ in STYLED.

`diff' computes them, which keeps this independent of how much
`guix style' rewrote."
  (let ((original-file (make-temp-file "heks-guix-style-original" nil ".scm"))
        (styled-file (make-temp-file "heks-guix-style-styled" nil ".scm")))
    (unwind-protect
        (progn
          (write-region original nil original-file nil 'silent)
          (write-region styled nil styled-file nil 'silent)
          (with-temp-buffer
            (call-process "diff" nil t nil
                          "--old-line-format=%dn\n"
                          "--new-line-format="
                          "--unchanged-line-format="
                          original-file styled-file)
            (let ((lines '()))
              (goto-char (point-min))
              (while (re-search-forward "\\([0-9]+\\)" nil t)
                (push (string-to-number (match-string 1)) lines))
              (sort lines #'<))))
      (delete-file original-file)
      (delete-file styled-file))))

;;;
;;; Flymake backends
;;;

(defvar-local heks-emacs-guix-lint-process nil
  "Running `guix lint' process of the buffer, if any.")

(defvar-local heks-emacs-guix-style-process nil
  "Running `guix style' process of the buffer, if any.")

(defun heks-emacs-guix--start-backend (process-var command report)
  "Run COMMAND asynchronously and hand its output to REPORT.

PROCESS-VAR is the buffer-local variable holding the process, which is
replaced by the new one: linting a buffer that has been edited in the
meantime is pointless, and Flymake starts a new run on every change
anyway.  REPORT is called with the standard output and standard error of
the finished process."
  (when (process-live-p (symbol-value process-var))
    (delete-process (symbol-value process-var)))
  (let ((output (generate-new-buffer " *heks-guix-out*"))
        (errors (generate-new-buffer " *heks-guix-err*"))
        (source (current-buffer))
        (proc nil))
    ;; A pipe, so that the Guix tools do not think they are talking to a
    ;; terminal and decorate their output, and a plain environment for the
    ;; same reason.
    (let ((process-environment (cons "TERM=dumb" (cons "NO_COLOR=1" process-environment))))
      (setq proc (make-process
                  :name "heks-guix"
                  :buffer output
                  :stderr errors
                  :noquery t
                  :connection-type 'pipe
                  :command command
                  :sentinel
                  (lambda (process _event)
                    (when (memq (process-status process) '(exit signal))
                      (let ((output-text (with-current-buffer output (buffer-string)))
                            (error-text (with-current-buffer errors (buffer-string))))
                        (kill-buffer output)
                        (kill-buffer errors)
                        (when (buffer-live-p source)
                          (with-current-buffer source
                            (set process-var nil)
                            (funcall report output-text error-text)))))))))
    (set process-var proc)))

(defun heks-emacs-guix-lint-backend (report-fn &rest _args)
  "Flymake backend checking the Guix package in the buffer with `guix lint'.

The installed Guix is the authority here, so this complements rather than
reimplements it (see `heks-emacs-guix-lint-checkers' to select a subset
of the checkers).  Files are linted from disk, which is why the backend
stays quiet while the buffer has unsaved changes."
  (heks-emacs-guix-lint-backend--reset)
  (let ((expression (heks-emacs-guix-package-expression))
        (file buffer-file-name))
    (cond
     ((or (not heks-emacs-guix-lint-flymake)
          (null expression)
          (null file)
          (buffer-modified-p))
      (funcall report-fn nil))
     (t
      (let ((root (heks-emacs-guix-lint-load-path)))
        (heks-emacs-guix--start-backend
         'heks-emacs-guix-lint-process
         (append (list heks-emacs-guix-program "lint" "-n")
                 (when heks-emacs-guix-lint-checkers
                   (list "-c" (mapconcat #'identity heks-emacs-guix-lint-checkers ",")))
                 (list "-L" root "-e" expression))
         (lambda (output error)
           (funcall report-fn
                    (heks-emacs-guix--lint-diagnostics output error file root)))))))))

(defun heks-emacs-guix-lint-backend--reset ()
  "Stop the linting process of the buffer, if it is still running."
  (when (process-live-p heks-emacs-guix-lint-process)
    (delete-process heks-emacs-guix-lint-process))
  (setq heks-emacs-guix-lint-process nil))

(defun heks-emacs-guix--lint-diagnostics (output error file root)
  "Return Flymake diagnostics for the lint OUTPUT of FILE.

ERROR is the standard error of `guix lint'.  Which stream carries the
diagnostics depends on the Guix version and on whether a load path was
given, so both are read; ROOT is where relative paths in them are
resolved.  Whatever cannot be attached to a file is reported at the top
of the buffer instead."
  (let ((entries (cl-remove-if-not
                  (lambda (entry) (heks-emacs-guix--entry-belongs-to-p entry file root))
                  (append (heks-emacs-guix--parse-lint-output output)
                          (heks-emacs-guix--parse-lint-output error)))))
    (if entries
        (mapcar (lambda (entry)
                  (let ((position (heks-emacs-guix--line-position (nth 1 entry) (nth 2 entry))))
                    (flymake-make-diagnostic (current-buffer) position position
                                             :warning (nth 3 entry))))
                entries)
      (let ((message (heks-emacs-guix--line-ferrors error)))
        (when message
          (list (flymake-make-diagnostic (current-buffer) (point-min) (point-min)
                                         :error message)))))))

(defun heks-emacs-guix-style-backend (report-fn &rest _args)
  "Flymake backend reporting the lines `guix style' would reformat.

`guix style' rewrites files in place, so the check runs on a copy of the
buffer: unsaved edits are covered, and the buffer is never touched."
  (when (process-live-p heks-emacs-guix-style-process)
    (delete-process heks-emacs-guix-style-process))
  (setq heks-emacs-guix-style-process nil)
  (let* ((original (buffer-substring-no-properties (point-min) (point-max)))
         (temp (make-temp-file "heks-guix-style" nil ".scm")))
    (if (or (not heks-emacs-guix-style-flymake)
            (not (heks-emacs-guix-buffer-p))
            (string-empty-p (string-trim original)))
        (progn
          (delete-file temp)
          (funcall report-fn nil))
      (write-region original nil temp nil 'silent)
      (heks-emacs-guix--start-backend
       'heks-emacs-guix-style-process
       (list heks-emacs-guix-program "style" "-f" temp)
       (lambda (_output _error)
         (let ((styled (when (file-exists-p temp)
                         (with-temp-buffer
                           (insert-file-contents temp)
                           (buffer-string)))))
           (when (file-exists-p temp)
             (delete-file temp))
           (funcall report-fn
                    (when styled
                      (heks-emacs-guix--style-diagnostics original styled)))))))))

(defun heks-emacs-guix--style-diagnostics (original styled)
  "Return Flymake diagnostics for the lines STYLED changed in ORIGINAL."
  (when (not (equal original styled))
    (mapcar (lambda (range)
              (let ((start (heks-emacs-guix--line-position (car range)))
                    (end (heks-emacs-guix--line-position (cdr range))))
                (flymake-make-diagnostic
                 (current-buffer) start (min (point-max) (1+ end)) :warning
                 (if (= (car range) (cdr range))
                     (format "line %d: `guix style' would reformat this line"
                             (car range))
                   (format "lines %d-%d: `guix style' would reformat these lines"
                           (car range) (cdr range))))))
            (heks-emacs-guix--number-ranges (heks-emacs-guix--style-changed-lines
                                             original styled)))))

(defun heks-emacs-scheme-setup-flymake ()
  "Register the Guix backends in the current buffer.

`guix lint' and `guix style' load the whole Guix module tree, which takes
seconds, so they run on save rather than on every change."
  (add-hook 'flymake-diagnostic-functions #'heks-emacs-guix-lint-backend nil t)
  (add-hook 'flymake-diagnostic-functions #'heks-emacs-guix-style-backend nil t)
  (setq-local flymake-no-changes-timeout nil
              flymake-start-on-flymake-mode nil)
  (flymake-mode 1))

;;;
;;; The REPL
;;;

(defun heks-emacs-scheme-ares-server-installed-p ()
  "Return non-nil when the Ares RS server is installed locally."
  (and (executable-find "ares-nrepl") t))

(defun heks-emacs-scheme-ares-server-command ()
  "Return the command list that starts the Ares RS nREPL server.

`heks-emacs-ares-server-command' wins when set, otherwise a local
`ares-nrepl' and finally `guix shell', which builds the server on first
use."
  (or heks-emacs-ares-server-command
      (cond ((executable-find "ares-nrepl") (list "ares-nrepl"))
            ((executable-find heks-emacs-guix-program)
             (list heks-emacs-guix-program "shell" "guile-ares-rs" "--" "ares-nrepl")))))

(defun heks-emacs-scheme-backend ()
  "Return the REPL backend in use, `arei' or `geiser'."
  (pcase heks-emacs-scheme-repl-backend
    ('arei 'arei)
    ('geiser 'geiser)
    (_ (if (heks-emacs-scheme-ares-server-installed-p) 'arei 'geiser))))

(defun heks-emacs-scheme-guix-binary ()
  "Return a `geiser-guile-binary' value providing Guix's own modules.

Emacs-Guix knows where the Guix sources live and how to put them on the
load path; a bare `guix repl' also brings Guix's modules, and is what is
left when that knowledge is missing.  Return nil when there is no Guix."
  (when heks-emacs-scheme-guix-repl-p
    (ignore-errors (require 'guix-repl nil t))
    (cond ((and (fboundp 'guix-repl-guile-program)
                (stringp (bound-and-true-p guix-scheme-directory))
                (not (string-empty-p (bound-and-true-p guix-scheme-directory)))
                ;; `guix-repl-guile-program' puts `guix-scheme-directory' on
                ;; the command line, and returns nil (or a broken command)
                ;; when Emacs-Guix could not read it.
                (ignore-errors (guix-repl-guile-program))))
          ((executable-find heks-emacs-guix-program)
           (list heks-emacs-guix-program "repl")))))

(defun heks-emacs-scheme-repl ()
  "Start or switch to the REPL of the current project.

The REPL is a Guix REPL in a Guix buffer (see
`heks-emacs-scheme-guix-repl-p'), and a plain Guile REPL otherwise; the
project root goes on Guile's load path either way.  With arei as the
backend this just points at the Ares connection instead, since that REPL
lives in its own buffer."
  (interactive)
  (if (eq (heks-emacs-scheme-backend) 'arei)
      (if (and (fboundp 'arei-connected-p) (ignore-errors (arei-connected-p)))
          (arei-switch-to-connection-buffer)
        (message "arei (Ares RS) is the backend here; `C-c g a' starts the server and connects"))
    (unless (derived-mode-p 'scheme-mode)
      (user-error "Open a Scheme buffer first"))
    ;; arei advises against Geiser's completion when both are installed, so
    ;; `geiser-mode' is turned on here, for the buffers that use Geiser.
    (geiser-mode 1)
    (geiser-repl-switch)))

(defun heks-emacs-scheme-repl-restart ()
  "Restart the REPL of the current project.

With Geiser this restarts the Guile process.  With arei this restarts the
Ares RS server, which is what gives a fresh image; a server started
outside Emacs cannot be stopped from here, and is reported as such."
  (interactive)
  (if (or (heks-emacs-scheme-geiser-buffer-p)
          (eq (heks-emacs-scheme-backend) 'geiser))
      (geiser-repl-restart-repl)
    (let* ((root (or (heks-emacs-guix-project-root)
                     (and buffer-file-name
                          (heks-emacs--locate-project-file '(".nrepl-port") default-directory))
                     default-directory))
           (buffer (heks-emacs-scheme-ares-server-buffer root)))
      (unless (comint-check-proc buffer)
        (user-error "No Ares RS server is managed by Emacs here; start one with `C-c g a'"))
      (when (get-buffer-process buffer)
        (delete-process (get-buffer-process buffer)))
      ;; The dead connection would otherwise stay in the session list.
      (ignore-errors
        (sesman-quit-session 'Arei (sesman-current-session 'Arei)))
      (run-with-timer 1 nil (lambda () (heks-emacs-scheme-ares-start))))))

(defun heks-emacs-scheme-ares-connect ()
  "Connect arei to the Ares RS server of the current project.

arei reads the port the server publishes in the project's `.nrepl-port'
file, so this works without answering any question."
  (interactive)
  (unless (derived-mode-p 'scheme-mode)
    (user-error "Open a Scheme buffer first: arei sessions are project scoped"))
  (unless (fboundp 'arei--start)
    (ignore-errors (require 'arei nil t)))
  (unless (fboundp 'arei--start)
    (user-error "arei is not available; install `emacs-arei' first"))
  (unless (bound-and-true-p arei-mode)
    (arei-mode 1))
  (let ((default-directory (file-name-as-directory
                            (or (heks-emacs-guix-project-root)
                                (heks-emacs--locate-project-file '(".nrepl-port") default-directory)
                                default-directory))))
    (message "Connecting arei...")
    (unless (arei--start nil)
      (user-error "No Ares RS server answered; start one with `C-c g a'"))))

(defun heks-emacs-scheme-ares-server-buffer (root)
  "Return the buffer holding the Ares RS server of ROOT.

The whole path is in the name, so that two checkouts with the same
directory name do not share a server buffer."
  (format "*ares-nrepl:%s*" (directory-file-name (expand-file-name root))))

(defun heks-emacs-scheme-ares-root ()
  "Return the directory the Ares RS server should run in."
  (or (heks-emacs-guix-project-root)
      (and buffer-file-name
           (heks-emacs--locate-project-file
            '("guix.scm" "manifest.scm" "guile.scm" ".nrepl-port") default-directory))
      default-directory))

(defun heks-emacs-scheme-ares-start ()
  "Start the Ares RS nREPL server and connect arei to it.

The server runs in the project root, so that it picks up the project's
modules and publishes its port there, and its output goes to a dedicated
buffer, which doubles as the build log when `guix shell' has to build
`guile-ares-rs' first.  arei is connected as soon as the port appears, so
no second command is needed; when a server is already running for this
project, this just connects to it."
  (interactive)
  (let* ((command (heks-emacs-scheme-ares-server-command))
         (root (heks-emacs-scheme-ares-root))
         (buffer (heks-emacs-scheme-ares-server-buffer root))
         (source (current-buffer)))
    (if (comint-check-proc buffer)
        (progn
          (message "An Ares server is already running for %s; connecting to it"
                   (abbreviate-file-name root))
          (heks-emacs-scheme-ares--await-port root source))
      (unless command
        (user-error "No Ares RS server found; install `guile-ares-rs' or set `heks-emacs-ares-server-command'"))
      (let ((default-directory (file-name-as-directory root)))
        (apply #'make-comint-in-buffer "ares-nrepl" buffer (car command) nil (cdr command)))
      (display-buffer buffer)
      (message "Starting the Ares server in %s..." (abbreviate-file-name root))
      (heks-emacs-scheme-ares--await-port root source))))

(defun heks-emacs-scheme-ares--await-port (root source &optional tries)
  "Connect arei once ROOT holds a usable `.nrepl-port', or give up.

SOURCE is the Scheme buffer the connection belongs to, and TRIES counts
the attempts made so far; the server is given a minute, which is not
enough when `guix shell' has to build it, hence the hint to run it again
by hand."
  (let ((tries (or tries 0)))
    (run-with-timer
     1 nil
     (lambda ()
       (cond
        ((> tries 60)
         (message "The Ares server did not publish a port; see the %s buffer"
                  (heks-emacs-scheme-ares-server-buffer root)))
        ((file-exists-p (expand-file-name ".nrepl-port" root))
         (if (buffer-live-p source)
             (with-current-buffer source
               (condition-case err
                   (heks-emacs-scheme-ares-connect)
                 (error (message "arei could not connect: %s" (error-message-string err)))))
           (message "The Ares server is up; connect with `C-c g A'")))
        (t
         (heks-emacs-scheme-ares--await-port root source (1+ tries))))))))

(defun heks-emacs-scheme-arei-debugger ()
  "Pop to the arei debugger buffer of the current session."
  (interactive)
  (let ((buffer (and (fboundp 'arei--debugger-buffer)
                     (bound-and-true-p arei-mode)
                     (ignore-errors (arei--debugger-buffer)))))
    (if (buffer-live-p buffer)
        (pop-to-buffer buffer)
      (user-error "No arei debugger buffer yet; run code that signals an error first"))))

;;;
;;; Evaluating, loading and testing
;;;

(defun heks-emacs-scheme-geiser-buffer-p ()
  "Return non-nil when Geiser is driving the current buffer."
  (and (boundp 'geiser-mode) geiser-mode))

(defun heks-emacs-scheme-eval-definition (&optional and-go)
  "Evaluate the definition at point in the REPL.

AND-GO switches to the REPL afterwards, as with `geiser-eval-definition'."
  (interactive "P")
  (if (heks-emacs-scheme-geiser-buffer-p)
      (geiser-eval-definition and-go)
    (let ((region (heks-emacs-scheme--definition-region)))
      (unless region
        (user-error "No top-level definition at point"))
      (arei-evaluate-region (car region) (cdr region)))))

(defun heks-emacs-scheme-eval-region-or-buffer ()
  "Evaluate the active region, or the whole buffer, in the REPL."
  (interactive)
  (cond
   ((heks-emacs-scheme-geiser-buffer-p)
    (if (use-region-p)
        (geiser-eval-region (region-beginning) (region-end))
      (geiser-eval-buffer)))
   ((use-region-p)
    (arei-evaluate-region (region-beginning) (region-end)))
   (t (arei-evaluate-buffer))))

(defun heks-emacs-scheme-load-buffer ()
  "Load the current file into the REPL."
  (interactive)
  (let ((file (or buffer-file-name (user-error "The buffer is not visiting a file"))))
    (save-buffer)
    (if (heks-emacs-scheme-geiser-buffer-p)
        (geiser-load-file file)
      (arei-evaluate-buffer))))

(defun heks-emacs-scheme-interrupt ()
  "Interrupt the evaluation running at the REPL."
  (interactive)
  (if (heks-emacs-scheme-geiser-buffer-p)
      (geiser-repl-interrupt)
    (arei-interrupt-evaluation)))

(defun heks-emacs-scheme-test ()
  "Run the tests of the current project.

With a live arei session this loads the project's tests into the running
image and runs them there, which is the whole point of the image
workflow.  Otherwise the project's own test task is used (`maak test',
see `heks-emacs-project-start-test')."
  (interactive)
  (if (and (eq (heks-emacs-scheme-backend) 'arei)
           (fboundp 'arei-testing-run)
           (ignore-errors (sesman-current-session 'Arei)))
      (progn
        (ignore-errors (arei-testing-load-project-tests))
        (arei-testing-run))
    (heks-emacs-project-start-test)))

(defun heks-emacs-scheme-run-script ()
  "Run the current file as a Guile script.

The project root goes on the load path and the output lands in the usual
compilation buffer, so a failing script is one click away from its
backtrace."
  (interactive)
  (let* ((file (or buffer-file-name (user-error "The buffer is not visiting a file")))
         (root (file-name-as-directory (or (heks-emacs-guix-project-root) default-directory)))
         (command (mapconcat #'shell-quote-argument
                             (list (or (executable-find "guile") "guile")
                                   "-L" root file)
                             " "))
         (default-directory root))
    (save-buffer)
    (compile command)))

;;;
;;; Linting and formatting
;;;

(when (require 'ansi-osc nil t)
  ;; The Guix tools hyperlink the file name of every diagnostic; with this
  ;; filter those become real hyperlinks in the compilation buffer that
  ;; `C-c g L' fills (this is the arrangement Guix's own manual suggests).
  (add-hook 'compilation-filter-hook #'ansi-osc-compilation-filter))

(defun heks-emacs-guix-lint-buffer ()
  "Run `guix lint' on the package defined in the buffer and show the output.

The compilation buffer makes every diagnostic clickable; the Flymake
backend shows the same diagnostics without leaving the buffer."
  (interactive)
  (let ((expression (heks-emacs-guix-package-expression))
        (root (heks-emacs-guix-lint-load-path)))
    (unless expression
      (user-error "No package definition found in this buffer"))
    (let ((default-directory (file-name-as-directory root)))
      (compile (mapconcat #'shell-quote-argument
                          (append (list heks-emacs-guix-program "lint" "-n")
                                  (when heks-emacs-guix-lint-checkers
                                    (list "-c" (mapconcat #'identity
                                                          heks-emacs-guix-lint-checkers ",")))
                                  (list "-L" root "-e" expression))
                          " ")))))

(defun heks-emacs-guix-style-apply-rule (rule)
  "Apply the `guix style' styling RULE to the current buffer.

The rules are Guix's own (`inputs', `arguments', `git-source', ...; see
`heks-emacs-guix-style-rules' and `guix style -l').  They rewrite the
file, so the buffer is saved first and reloaded once the rule has been
applied."
  (interactive (list (completing-read "Styling rule: " heks-emacs-guix-style-rules
                                      nil t nil nil (car heks-emacs-guix-style-rules))))
  (let ((file buffer-file-name)
        (source (current-buffer))
        (buffer (get-buffer-create "*guix style*")))
    (unless file
      (user-error "The buffer is not visiting a file"))
    (when (buffer-modified-p)
      (user-error "Save the buffer first: `guix style' rewrites the file"))
    (with-current-buffer buffer (erase-buffer))
    (let ((default-directory (file-name-directory file)))
      (message "Applying the `%s' Guix styling rule to %s..."
               rule (file-name-nondirectory file))
      (make-process
       :name "guix style"
       :command (list heks-emacs-guix-program "style" "-S" rule file)
       :buffer buffer
       :noquery t
       :sentinel
       (lambda (process _event)
         (when (memq (process-status process) '(exit signal))
           (if (and (eq (process-status process) 'exit)
                    (zerop (process-exit-status process))
                    (buffer-live-p source))
               (with-current-buffer source
                 (revert-buffer :ignore-auto :noconfirm)
                 (message "Applied the `%s' styling rule (see *guix style*)" rule))
             (message "`guix style -S %s' failed; see the *guix style* buffer" rule))))))))

;;;
;;; Folding
;;;

(defun heks-emacs-scheme-fold-close ()
  "Hide the definition at point."
  (interactive)
  (hs-hide-block))

(defun heks-emacs-scheme-fold-open ()
  "Show the definition at point, and everything inside it."
  (interactive)
  (hs-show-block))

(defun heks-emacs-scheme-fold-close-all ()
  "Hide every top-level form of the buffer."
  (interactive)
  (hs-hide-all))

(defun heks-emacs-scheme-fold-open-all ()
  "Show everything in the buffer."
  (interactive)
  (hs-show-all))

(defun heks-emacs-scheme-fold-toggle ()
  "Toggle hiding of the definition at point."
  (interactive)
  (hs-toggle-hiding))

;;;
;;; Keys and setup
;;;

(defvar heks-emacs-scheme-mode-map
  (let ((map (make-sparse-keymap)))
    ;; The REPL and evaluation.
    (define-key map (kbd "C-c g r") #'heks-emacs-scheme-repl)
    (define-key map (kbd "C-c g R") #'heks-emacs-scheme-repl-restart)
    (define-key map (kbd "C-c g a") #'heks-emacs-scheme-ares-start)
    (define-key map (kbd "C-c g A") #'heks-emacs-scheme-ares-connect)
    (define-key map (kbd "C-c g d") #'heks-emacs-scheme-arei-debugger)
    (define-key map (kbd "C-c g e") #'heks-emacs-scheme-eval-definition)
    (define-key map (kbd "C-c g E") #'heks-emacs-scheme-eval-region-or-buffer)
    (define-key map (kbd "C-c g b") #'heks-emacs-scheme-load-buffer)
    (define-key map (kbd "C-c g i") #'heks-emacs-scheme-interrupt)
    (define-key map (kbd "C-c g x") #'heks-emacs-scheme-run-script)
    ;; Testing, linting and formatting.
    (define-key map (kbd "C-c g t") #'heks-emacs-scheme-test)
    (define-key map (kbd "C-c g L") #'heks-emacs-guix-lint-buffer)
    (define-key map (kbd "C-c g f") #'heks-emacs-guix-fmt)
    (define-key map (kbd "C-c g S") #'heks-emacs-guix-style-apply-rule)
    ;; The historical binding for formatting a Guix buffer.
    (define-key map (kbd "C-c i f") #'heks-emacs-guix-fmt)
    ;; Folding, with the keys the Tree-sitter folding uses elsewhere.
    (define-key map (kbd "C-c v c") #'heks-emacs-scheme-fold-close)
    (define-key map (kbd "C-c v o") #'heks-emacs-scheme-fold-open)
    (define-key map (kbd "C-c v O") #'heks-emacs-scheme-fold-open)
    (define-key map (kbd "C-c v m") #'heks-emacs-scheme-fold-close-all)
    (define-key map (kbd "C-c v r") #'heks-emacs-scheme-fold-open-all)
    (define-key map (kbd "C-c v a") #'heks-emacs-scheme-fold-toggle)
    map)
  "Keymap with the Guile and Guix extras, installed in `scheme-mode-map'.")

;; arei is the richer client -- debugger, macroexpansion, test runner, module
;; reload -- but it needs an Ares RS server process, which `C-c g a' starts
;; and `C-c g t' then runs the project's tests against.
(use-package arei
  :ensure (:host github :repo "abcdw/emacs-arei" :branch "master")
  :demand t
  :hook ((scheme-mode . arei-mode)))

(use-package geiser
  :ensure t
  :init
  (setq geiser-active-implementations '(guile)
        ;; arei advises against Geiser's completion when both are installed,
        ;; so `geiser-mode' is turned on by `heks-emacs-scheme-repl' instead,
        ;; in the buffers that use Geiser.
        geiser-mode-auto-p nil
        ;; One REPL per project, and its root on Guile's load path: that is
        ;; what makes project modules importable at once.
        geiser-repl-per-project-p t
        geiser-repl-use-other-window t
        geiser-repl-add-project-paths t)
  :config
  (defun heks-emacs-scheme--geiser-project ()
    "Project directory of the current buffer, for Geiser's REPL."
    (ignore-errors (project-root (project-current nil))))
  (setq geiser-repl-current-project-function #'heks-emacs-scheme--geiser-project))

(use-package geiser-guile
  :ensure t
  :config
  ;; A failed evaluation should show where it failed.
  (setq geiser-guile-debug-show-bt t
        geiser-guile-debug-show-full-bt t
        geiser-guile-debug-backwards-backtrace t
        geiser-guile-show-debug-help t))

(defun heks-emacs-scheme-mode-setup ()
  "Set up a Scheme buffer for Guile and Guix work."
  (use-local-map (make-composed-keymap heks-emacs-scheme-mode-map
                                       (current-local-map)))
  (when (heks-emacs-guix-buffer-p)
    ;; Guix's own modules, and the highlighting and commands of Emacs-Guix
    ;; (C-c . l to lint, C-c . b to build, C-c . u to use a module).
    (when (fboundp 'guix-devel-mode)
      (guix-devel-mode 1))
    (let ((binary (heks-emacs-scheme-guix-binary)))
      (when binary
        (setq-local geiser-guile-binary binary)))
    (heks-emacs-scheme-setup-flymake))
  ;; A Scheme buffer is a sequence of top-level forms, so each one is a
  ;; block: collapsing the definition you are in then works from anywhere
  ;; inside it, which is not what Hideshow guesses by default.
  (setq-local hs-block-start-regexp "^("
              hs-forward-sexp-function #'forward-sexp)
  (hs-minor-mode 1))

(add-hook 'scheme-mode-hook #'heks-emacs-scheme-mode-setup)

(provide 'heks-emacs/guile)

;;; guile.el ends here
