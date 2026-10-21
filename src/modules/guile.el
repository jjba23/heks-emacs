;;; guile.el --- Guile Scheme development -*- lexical-binding: t -*-

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

;; Guile Scheme development, with the REPL in the middle of the workflow
;; rather than at the end of it.  Geiser drives it, and *nothing here needs
;; Guix*: on a machine without it this is a plain Guile setup -- a `guile'
;; REPL, the Guile compiler as the checker, Emacs' own indentation as the
;; formatter -- which is what makes it usable on macOS.  Where Guix *is*
;; installed it adds what only it can give: a Guix REPL, so that
;; `(use-modules (guix packages))' works, `guix lint' and `guix style', and
;; the C-c . bindings of Emacs-Guix in Guix buffers.
;;
;; The REPL (`C-c g r' starts or switches to the one of the current
;; project; `C-c g R' restarts it):
;;
;;   `C-c g r'   a Guix REPL (`guix repl') in a buffer that defines
;;               packages, a plain `guile' one elsewhere, one REPL per
;;               project, with the project root on Guile's load path so that
;;               `(use-modules (my project))' just works.  It is that REPL
;;               that evaluating or loading asks for: with none running,
;;               `C-c g e', `C-c g E' and `C-c g b' start the project's one
;;               rather than stopping to say there is none.  `C-c g r' is
;;               for wanting to *be* at the prompt; the commands that need a
;;               REPL no longer ask to be preceded by it.
;;   `C-c g e'   evaluate the definition at point, `C-c g E' the region or
;;               the buffer, `C-c g b' load the file, `C-c g k' interrupt a
;;               runaway evaluation, `C-c g x' run the file as a script.
;;   `C-c g s'   point the REPL at the module of this buffer.
;;   `C-c g d'   return to the debugger buffer after an exception, where
;;               Geiser's debugger shows the backtrace and its restarts.
;;
;; Geiser's own database answers the navigation questions, so this is a
;; code intelligence setup with no language server in it:
;;
;;   `C-c g g'   go to the definition of the symbol at point, which is what
;;               `M-.' does -- the same command, `xref-find-definitions'.
;;               `M-s .' asks the other question the same backend answers:
;;               not where a name is, but which names there are that match
;;               a pattern, from the definitions of the project's files and
;;               from the names the REPL has loaded.
;;               Nothing about a Scheme definition is done by a key: what
;;               `M-.' asks in a Scheme buffer is a backend, and that
;;               backend knows both the REPL -- which has loaded the symbol
;;               and knows the file and line it read it from -- and the
;;               files of the project, which are searched for a symbol the
;;               REPL has never seen.  `M-?' asks the same backend where a
;;               name is used: the callers the REPL knows, or the places
;;               the files mention it.
;;   `C-c g h'   its documentation.
;;   `C-c g c'   who calls it; `C-c g C' what it calls (a call hierarchy).
;;   `C-c g m'   a menu of its generic methods, for a generic function.
;;
;; Completion in the buffer and at the prompt is Geiser's, through
;; `completion-at-point', which reaches Corfu here like any other source;
;; `geiser-autodoc-mode' puts the signature of the symbol at point in the
;; echo area.  Geiser turns itself on in Scheme buffers
;; (`geiser-mode-auto-p'), so none of this needs a command to start.
;;
;; Checking and formatting run on save, from the project's own tools:
;;
;;   * `heks-emacs-guix-lint-backend' runs `guix lint' on the package
;;     defined in the buffer, so Guix's checkers (synopsis, inputs,
;;     formatting, CVEs, ...) arrive as Flymake diagnostics.
;;   * `heks-emacs-guix-style-backend' reports the lines `guix style' would
;;     rewrite, in any Scheme buffer of a machine that has Guix: drift in a
;;     Guix library file is as interesting as drift in a package file.
;;   * `heks-emacs-guile-compile-backend' runs the Guile compiler
;;     (`guild compile') where Guix is not the authority -- every other
;;     Scheme buffer.  It is a real checker: it reports unbound and unused
;;     variables, unused imports and arity mismatches, and it is the whole
;;     checking story on a machine without Guix.
;;   * `C-c g L' lints the buffer with output you can click through,
;;     `C-c g f' formats it in place, `C-c g S' applies one of Guix's
;;     styling rules (`inputs', `arguments', `git-source') and reloads the
;;     buffer.  `C-c i f' is the historical binding for formatting.
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
;; Tests stay the project's: `C-c g t' runs its `test' task, which is Maak's
;; when the project has a `maak.scm' (`C-c m r' lists the tasks a project
;; defines).

;;; Code:

(require 'apropos)
(require 'cl-lib)
(require 'flymake)
(require 'hideshow)
(require 'scheme)
(require 'seq)
(require 'xref)

;;;
;;; Customization
;;;

(defcustom heks-emacs-guix-program "guix"
  "Name of the `guix' executable."
  :type 'string
  :group 'heks-emacs)

(defcustom heks-emacs-scheme-guile-program "guile"
  "Name of the `guile' executable."
  :type 'string
  :group 'heks-emacs)

(defcustom heks-emacs-scheme-guild-program "guild"
  "Name of the `guild' executable, the entry point of Guile's tools."
  :type 'string
  :group 'heks-emacs)

(defcustom heks-emacs-scheme-guix-repl-p t
  "Whether Guix buffers get a Guix REPL instead of a plain Guile one.

Guix's own modules are importable from a Guix REPL whatever the load path
is; this is what makes `(use-modules (guix packages))' work at the REPL of
a package buffer.  It has no effect where Guix is not installed."
  :type 'boolean
  :group 'heks-emacs)

(defcustom heks-emacs-scheme-guile-warning-level 'high
  "How much the Guile compiler warns about.

The levels are Guile's own: `low' reports arity mismatches and unbound
variables, `medium' adds import problems and `high' also reports unused
variables and unused modules -- which is what makes the checker useful as
a reviewer of one's own code.  It applies both to the REPL, where Geiser
reports on each evaluation, and to the Flymake backend."
  :type '(choice (const :tag "Nothing" none)
                 (const :tag "Low (arity, unbound variables)" low)
                 (const :tag "Medium (also import problems)" medium)
                 (const :tag "High (also unused variables and modules)" high))
  :set (lambda (symbol value)
         ;; Geiser reports Guile's warnings at the REPL, so the two levels
         ;; are kept in step: there is one place to say how much is
         ;; reported, and the REPL is not a second, quieter checker that
         ;; disagrees with the buffer.
         (set-default symbol value)
         (when (boundp 'geiser-guile-warning-level)
           (set-default 'geiser-guile-warning-level value)))
  :group 'heks-emacs)

(defcustom heks-emacs-scheme-guile-compile-flymake t
  "Whether the Guile compiler checks Scheme buffers as a Flymake backend."
  :type 'boolean
  :group 'heks-emacs)

(defcustom heks-emacs-guix-lint-flymake t
  "Whether `guix lint' runs as a Flymake backend in Guix buffers."
  :type 'boolean
  :group 'heks-emacs)

(defcustom heks-emacs-guix-style-flymake t
  "Whether `guix style' reports formatting drift as a Flymake backend."
  :type 'boolean
  :group 'heks-emacs)

(defcustom heks-emacs-guix-lint-checkers nil
  "Checkers passed to `guix lint' with -c.

nil means every checker the installed Guix provides; `guix lint
--list-checkers' lists the names.  Network checks are always disabled
(-n), because linting runs on every save."
  :type '(repeat string)
  :group 'heks-emacs)

(defcustom heks-emacs-guix-style-rules '("format" "inputs" "arguments" "git-source")
  "Styling rules offered by `heks-emacs-guix-style-apply-rule'."
  :type '(repeat string)
  :group 'heks-emacs)

;;;
;;; What is installed, and where are we
;;;

(defun heks-emacs-guix-available-p ()
  "Return non-nil when the `guix' command is installed."
  (heks-emacs-tool-available-p heks-emacs-guix-program))

(defun heks-emacs-guile-available-p ()
  "Return non-nil when the Guile tools are installed."
  (and (heks-emacs-tool-available-p heks-emacs-scheme-guile-program)
       (heks-emacs-tool-available-p heks-emacs-scheme-guild-program)
       t))

(defun heks-emacs-guix-project-root (&optional dir)
  "Return the root of the Guix project around DIR, or nil.

A directory counts as a Guix project when it holds a channel or manifest
file, or when it looks like a Guix checkout (both a `gnu' and a `guix'
sub-directory)."
  (let ((dir (file-name-as-directory (expand-file-name (or dir default-directory))))
        (found nil))
    (while (and (not found) dir)
      (when (or (seq-some (lambda (name) (file-exists-p (expand-file-name name dir)))
                          '("guix.scm" "manifest.scm" ".guix-channel"))
                (and (file-directory-p (expand-file-name "gnu" dir))
                     (file-directory-p (expand-file-name "guix" dir))))
        (setq found dir))
      (let ((parent (file-name-directory (directory-file-name dir))))
        (setq dir (unless (equal parent dir) parent))))
    found))

(defun heks-emacs-scheme-project-root (&optional dir)
  "Return the root of the Scheme project around DIR, or nil.

The Guix project root wins when there is one (it is the more specific
answer, and it is the one a channel wants); otherwise the project Emacs
knows about from `project.el'."
  (or (heks-emacs-guix-project-root dir)
      (when (fboundp 'project-root)
        (ignore-errors (project-root (project-current nil dir))))))

(defun heks-emacs-scheme-load-path ()
  "Return the directory to put on Guile's load path for this buffer.

The project root, since that is what makes the buffer's own module
importable; a file outside any project contributes its own directory."
  (or (heks-emacs-scheme-project-root)
      (when buffer-file-name (file-name-directory (expand-file-name buffer-file-name)))
      default-directory))

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
                   when (memq (car-safe form) '(define define-public define-syntax define-record-type))
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
                            (and (memq (car-safe (nth 0 entry))
                                       '(define define-public define-syntax))
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

;;;
;;; The Guile compiler
;;;

(defun heks-emacs-scheme-guile-warning-flag ()
  "Return the -W flag matching `heks-emacs-scheme-guile-warning-level'."
  (pcase heks-emacs-scheme-guile-warning-level
    ('none "-W0")
    ('low "-W1")
    ('medium "-W2")
    (_ "-W3")))

(defun heks-emacs-guile-compile-applies-p ()
  "Return non-nil when the Guile compiler has something to say here.

It bows out of Guix package buffers as soon as Guix is installed: those
import Guix's own modules, which a plain `guild' cannot resolve, and `guix
lint' is both able and better informed about them.  In every other Scheme
buffer it applies, including the library files of a Guix checkout, whose
modules its own load path does resolve."
  (and heks-emacs-scheme-guile-compile-flymake
       (heks-emacs-guile-available-p)
       (derived-mode-p 'scheme-mode)
       (not (and (heks-emacs-guix-available-p) (heks-emacs-guix-buffer-p)))))

(defun heks-emacs-guile-compile-backend (report-fn &rest _args)
  "Flymake backend compiling the buffer with `guild compile'.

The compiler is the authority on whether Guile code is sound, and it is
the only checker here that does not need Guix.  It runs on a copy of the
buffer, so code that has been typed but not saved is checked as well;
`GUILE_AUTO_COMPILE=0' keeps it from building a `.go' file for `guild'
itself on every run."
  (heks-emacs-tool-diagnostic-backend
   "guile-compile" report-fn
   (list
    :what "guile"
    :applies #'heks-emacs-guile-compile-applies-p
    :copy t
    :suffix ".scm"
    :root #'heks-emacs-scheme-load-path
    :env '("GUILE_AUTO_COMPILE=0" "GUILE_WARN_DEPRECATED=no")
    :command (lambda (file)
               (list (heks-emacs-tool-path heks-emacs-scheme-guild-program)
                     "compile"
                     (heks-emacs-scheme-guile-warning-flag)
                     "-L" (heks-emacs-scheme-load-path)
                     "-o" (concat file ".go")
                     file))
    :cleanup (lambda (file) (delete-file (concat file ".go"))))))

;;;
;;; The Guix tools
;;;

(defun heks-emacs-guix-lint-applies-p ()
  "Return non-nil when `guix lint' can be run on this buffer.

It cannot: `guix lint' reads the file from disk, so a buffer with unsaved
changes would be linted as it was, and a diagnostic on a line that has
moved is worse than no diagnostic.  It has nothing to say either when the
buffer defines no package."
  (and heks-emacs-guix-lint-flymake
       (heks-emacs-guix-available-p)
       (heks-emacs-guix-buffer-p)
       buffer-file-name
       (not (buffer-modified-p))))

(defun heks-emacs-guix-lint-backend (report-fn &rest _args)
  "Flymake backend checking the Guix package in the buffer with `guix lint'.

The installed Guix is the authority on Guix packages, so this complements
rather than reimplements it (see `heks-emacs-guix-lint-checkers' to select
a subset of the checkers)."
  (heks-emacs-tool-diagnostic-backend
   "guix-lint" report-fn
   (list
    :what "guix lint"
    :applies #'heks-emacs-guix-lint-applies-p
    :root #'heks-emacs-scheme-load-path
    :command (lambda (file)
               (let ((root (heks-emacs-scheme-load-path))
                     (expression (heks-emacs-guix-package-expression)))
                 (append (list (heks-emacs-tool-path heks-emacs-guix-program) "lint" "-n")
                         (when heks-emacs-guix-lint-checkers
                           (list "-c" (mapconcat #'identity heks-emacs-guix-lint-checkers ",")))
                         (list "-L" root "-e" expression)))))))

(defun heks-emacs-guix-style-applies-p ()
  "Return non-nil when `guix style' has an opinion about this buffer.

Any Scheme file, not just one that defines packages: `guix style' is the
formatter of a Guix checkout's library files too."
  (and heks-emacs-guix-style-flymake
       (heks-emacs-guix-available-p)
       (derived-mode-p 'scheme-mode)))

(defun heks-emacs-guix-style-backend (report-fn &rest _args)
  "Flymake backend reporting the lines `guix style' would reformat.

`guix style' rewrites files in place, so the check runs on a copy of the
buffer: unsaved edits are covered, and the buffer is never touched."
  (heks-emacs-tool-drift-backend
   "guix-style" report-fn
   (list
    :what "guix style"
    :applies #'heks-emacs-guix-style-applies-p
    :suffix ".scm"
    :root #'heks-emacs-scheme-load-path
    :command (lambda (file)
               (list (heks-emacs-tool-path heks-emacs-guix-program) "style" "-f" file)))))

(defun heks-emacs-scheme-format-spec ()
  "Return the formatter to use for this buffer.

Guix's own formatter where Guix is installed, which is what a Guix
checkout, a channel and a package want; nothing where it is not, and
`heks-emacs-scheme-format-buffer' falls back to Emacs' indentation."
  (when (heks-emacs-guix-available-p)
    (list :what "guix style"
          :command (lambda (file)
                     (list (heks-emacs-tool-path heks-emacs-guix-program) "style" "-f" file)))))

;;;
;;; Flymake setup
;;;

(defun heks-emacs-scheme-setup-flymake ()
  "Register the checkers of the current Scheme buffer.

The Guix tools load the whole Guix module tree and the Guile compiler
reads a file, so these run on save (`flymake-start-on-save-buffer') rather
than on every keystroke; the checker that applies to the buffer answers,
and the others stay silent."
  (when heks-emacs-scheme-guile-compile-flymake
    (add-hook 'flymake-diagnostic-functions #'heks-emacs-guile-compile-backend nil t))
  (when (heks-emacs-guix-available-p)
    (add-hook 'flymake-diagnostic-functions #'heks-emacs-guix-lint-backend nil t)
    (add-hook 'flymake-diagnostic-functions #'heks-emacs-guix-style-backend nil t))
  (setq-local flymake-no-changes-timeout nil
              flymake-start-on-flymake-mode nil)
  (flymake-mode 1))

;;;
;;; The REPL
;;;

(defun heks-emacs-scheme-guile-binary ()
  "Return a `geiser-guile-binary' value for the current buffer, or nil.

In a Guix buffer that is a `guix repl', whose module setup is the point:
it is what lets the REPL of a package buffer import Guix's own modules.
Everywhere else nil, and Geiser starts a plain `guile'."
  (when (and heks-emacs-scheme-guix-repl-p
             (heks-emacs-guix-available-p)
             (heks-emacs-guix-buffer-p))
    (list heks-emacs-guix-program "repl")))

(defun heks-emacs-scheme--with-repl-program (function)
  "Call FUNCTION with this buffer's REPL program bound as Geiser expects.

Geiser reads `geiser-guile-binary' while it starts the process, so a
dynamic binding is enough -- and it keeps the choice per buffer, which is
where it belongs.  Geiser's own variables are only defined once geiser and
its Guile flavour are loaded, which happens on the first REPL rather than
at startup, so they are loaded here; reading them before they exist is what
a first `C-c g r' in a fresh Emacs would otherwise do.

`guix repl' takes `-q' and `-L' but not the `-l' that Geiser adds for an
init file written for plain Guile, so that one is dropped when the REPL is
a Guix REPL."
  (require 'geiser-repl)
  (require 'geiser-mode)
  (require 'geiser-guile nil t)
  (let* ((guix-repl (heks-emacs-scheme-guile-binary))
         (geiser-guile-binary (or guix-repl (bound-and-true-p geiser-guile-binary)))
         (geiser-guile-init-file (if guix-repl
                                     nil
                                   (bound-and-true-p geiser-guile-init-file))))
    (funcall function)))

(defun heks-emacs-scheme-repl--start ()
  "Start this buffer's REPL, or switch to the one already running.

The program is picked per buffer -- a Guix REPL in a Guix buffer, a plain
`guile' one elsewhere (see `heks-emacs-scheme--with-repl-program') -- and
Geiser makes the part that matters: one REPL per project, and it is
already running."
  (heks-emacs-scheme--with-repl-program
   (lambda ()
     (geiser-mode 1)
     (geiser-repl-switch))))

(defun heks-emacs-scheme-repl ()
  "Start or switch to the REPL of the current project.

The REPL belongs to the project (`geiser-repl-per-project-p'), with the
project root on Guile's load path, so a second visit to the same project
lands in the REPL that is already running.  In a Guix buffer that REPL is
a Guix one; see `heks-emacs-scheme-guix-repl-p'."
  (interactive)
  (unless (derived-mode-p 'scheme-mode)
    (user-error "Open a Scheme buffer first"))
  (heks-emacs-scheme-repl--start))

(defun heks-emacs-scheme-repl-needed (function)
  "Call FUNCTION with this buffer's REPL running, and return what it returns.

What is asked of a REPL is not always *the* REPL: a definition is
evaluated in it, a file is loaded into it, and a command that does one of
those two is a way of asking for one.  So the REPL of the project is
started here when none is running, rather than the evaluation stopping to
say that it cannot be done without one -- the same REPL `C-c g r' opens,
started by the wanting rather than by the choosing.

Geiser reads this buffer's program while it starts the process, and a
REPL that is slow to come up is waited for, bounded, so that a machine
where the program is missing is told that rather than left waiting.

Starting a REPL shows it, and `save-current-buffer' is what keeps that
showing from moving the point of the command that asked for it: what is
evaluated is the definition at point in *this* buffer, and a REPL that
made it the current one would have `C-c g e' evaluate the prompt."
  (unless (heks-emacs-scheme-repl-connected-p)
    (save-current-buffer
      (heks-emacs-scheme-repl--start)
      (let ((tries 0))
        (while (and (not (heks-emacs-scheme-repl-connected-p)) (< tries 100))
          (accept-process-output nil 0.05)
          (setq tries (1+ tries))))
      (unless (heks-emacs-scheme-repl-connected-p)
        (user-error "No REPL for %s could be started; see `C-c g r'"
                    heks-emacs-scheme-guile-program))))
  (funcall function))

(defun heks-emacs-scheme-repl-restart ()
  "Restart the REPL of the current project.

This is what gives a fresh image after the running one has been broken.
Geiser does the work; the same REPL program is picked as `C-c g r'
picks."
  (interactive)
  (heks-emacs-scheme--with-repl-program #'geiser-repl-restart-repl))

(defun heks-emacs-scheme-repl-switch-to-module ()
  "Point the REPL at the module of the current buffer.

The module of a file that has just been loaded is already in the REPL;
this is for the times another one should be, without importing it by hand
at the prompt."
  (interactive)
  (let ((module (heks-emacs-scheme-module-name)))
    (unless module
      (user-error "No `define-module' in this buffer"))
    (geiser-repl-switch-to-module module)))

;;;
;;; Evaluating, loading and debugging
;;;

(defun heks-emacs-scheme-eval-definition (&optional and-go)
  "Evaluate the definition at point in the REPL.

AND-GO switches to the REPL afterwards, as with `geiser-eval-definition'.
A project that is not running a REPL gets one: see
`heks-emacs-scheme-repl-needed'."
  (interactive "P")
  (heks-emacs-scheme-repl-needed
   (lambda () (geiser-eval-definition and-go))))

(defun heks-emacs-scheme-eval-region-or-buffer ()
  "Evaluate the active region, or the whole buffer, in the REPL.

The REPL is started if there is none, as `C-c g e' starts it."
  (interactive)
  (heks-emacs-scheme-repl-needed
   (lambda ()
     (if (use-region-p)
         (geiser-eval-region (region-beginning) (region-end))
       (geiser-eval-buffer)))))

(defun heks-emacs-scheme-load-buffer ()
  "Load the current file into the REPL, starting one if there is none."
  (interactive)
  (let ((file (or buffer-file-name (user-error "The buffer is not visiting a file"))))
    (save-buffer)
    (heks-emacs-scheme-repl-needed (lambda () (geiser-load-file file)))))

(defun heks-emacs-scheme-interrupt ()
  "Interrupt the evaluation running at the REPL."
  (interactive)
  (geiser-repl-interrupt))

(defun heks-emacs-scheme-debugger ()
  "Switch to the Geiser debugger buffer of the last failed evaluation.

A failed evaluation drops into the debugger, which shows the backtrace and
Guile's restarts; this comes back to it after having looked at something
else, which is the point of a debugger that lives in a buffer."
  (interactive)
  (if (and (fboundp 'geiser-debug-active-p) (geiser-debug-active-p))
      (geiser-debug-switch-to-buffer)
    (user-error "No debugger to return to; run code that signals an error first")))

(defun heks-emacs-scheme-documentation ()
  "Show the documentation of the symbol at point."
  (interactive)
  (geiser-doc-symbol-at-point))

;;;
;;; Finding a definition, and where a name is used
;;;
;;; All of it is `xref': `M-.' is `xref-find-definitions' in a Scheme buffer
;;; as it is in every other buffer, `M-?' is `xref-find-references', and
;;; what this section gives them is a backend -- the answers they look for
;;; and the fallbacks for the places that have none.  A key of this
;;; configuration's own that jumped to a definition would be a second way to
;;; do what `M-.' does, learned on its own and working on its own; the
;;; commands stay Emacs's and what knows about Scheme is put behind them.
;;;
;;; Two sources of answers, and the REPL is asked first because its answer is
;;; the better one: it knows the file and the line of the symbols of the
;;; modules it has loaded, which is what makes it right about a module of
;;; Guile's or Guix's own that this project merely imports.  What it cannot
;;; answer is a symbol that has never been loaded -- Guix's modules are
;;; loaded when a package uses them, and reading code is not running it --
;;; and in the other case there is no REPL at all, a Scheme file opened on
;;; its own.  Then the files answer: the project is searched for the
;;; `define' head that names the symbol, and a symbol defined in several
;;; files arrives as a list to choose from, in `consult-xref'.  What neither
;;; source has is left to `dumb-jump', which is the wider search the rest of
;;; the configuration gives a buffer that has no language server.

(defconst heks-emacs-scheme-file-extensions
  '("*.scm" "*.ss" "*.sld")
  "The extensions of the Scheme sources searched for a definition.

Guile's own, which is what the modules of a project are written in.  A name
defined in a file with another extension is not found where the files are
searched, and `dumb-jump' (see `heks-emacs-scheme-xref-backend') is the
wider search that follows this one.")

(defconst heks-emacs-scheme-definition-forms
  "[(]define[^[:space:]()]*[[:space:]]+[(]?%s"
  "How the head of a definition of a name looks, as a search pattern.

The name goes where the `%s' is.  It matches the head of a `define' of any
kind -- `define', `define-public', `define*', `define-syntax',
`define-record-type', `define-values', `define-method', and the rest --
because the name comes right after the defining word in all of them.  The
pattern is written so that one string is a pattern for `rg' and `grep -E' as
well as for Emacs, which reads the hits back: a literal parenthesis as
`[(]', whitespace as `[[:space:]]'.  A searcher and Emacs that disagreed
about what was found would be a search whose hits Emacs then judged
unfound.")

(defconst heks-emacs-scheme-definition-hit-regexp
  "\\`\\(.+?\\):\\([0-9]+\\):\\(.*\\)\\'"
  "Regexp matching the `FILE:LINE:REST' line a search tool answers with.

Both of the searchers are given the arguments that make them print this,
which is one line per hit: the name of the file, the line, and the line
itself.")

(defun heks-emacs-scheme-definition-line-p (line name)
  "Return non-nil when LINE is the line of a definition of NAME.

What a search cannot tell apart is a name being defined and a name being
used, which is why every hit is read back here: the head has to end where
the name ends -- at a space, or at the closing parenthesis of `(define
(name) ...)' -- so that the line of a call of `greet' is not offered as
its definition.  The end of the name is checked against those characters rather
than at a word boundary because `publish!' and `empty?' are names, and
there is no word boundary after the last character of either."
  (string-match-p (concat (format heks-emacs-scheme-definition-forms
                                  (regexp-quote name))
                          "\\([[:space:])]\\|\\'\\)")
                  line))

(defun heks-emacs-scheme-definition-column (line name)
  "Return the column at which LINE defines NAME, or nil.

The column is what `xref' moves to, so it is where the name being defined
is, not where the name first appears: a line can mention a name before
defining it."
  (let ((head (string-match (format heks-emacs-scheme-definition-forms
                                    (regexp-quote name))
                            line)))
    (and head (string-match (regexp-quote name) line head))))

(defun heks-emacs-scheme--search-files (pattern &optional only-matching)
  "Return the hits of PATTERN in the Scheme files of this project.

Ripgrep does the searching where it is installed, and `grep -E' does it
where it is not, over the Scheme files of `heks-emacs-scheme-load-path':
the project root, or the directory of the file being edited when it is in
no project Emacs knows.  Each hit is a list of the file it is in, the line
it is on and the text of that line -- with ONLY-MATCHING non-nil, the text
is what matched rather than the line it was found on.  A project with
neither searcher installed answers with nothing, which is all the question
can be answered with."
  (let* ((root (file-name-as-directory (expand-file-name (heks-emacs-scheme-load-path))))
         (ripgrep (heks-emacs-tool-available-p "rg"))
         (program (if ripgrep "rg" "grep"))
         (args (append (if ripgrep
                           (list "--no-heading" "--line-number" "--with-filename"
                                 "--color=never")
                         (list "-r" "-n" "--exclude-dir=.git"))
                       (when only-matching
                         (list (if ripgrep "--only-matching" "-o")))
                       (cl-mapcan (lambda (extension)
                                    (if ripgrep
                                        (list "--glob" extension)
                                      (list (concat "--include=" extension))))
                                  heks-emacs-scheme-file-extensions)
                       (list "--" pattern)))
         (text (with-temp-buffer
                 (apply #'process-file (heks-emacs-tool-path program)
                        nil (list t nil) nil args)
                 (buffer-string)))
         (hits '()))
    (dolist (line (split-string text "\n" t))
      (when (string-match heks-emacs-scheme-definition-hit-regexp line)
        (push (list (expand-file-name (match-string 1 line) root)
                    (string-to-number (match-string 2 line))
                    (match-string 3 line))
              hits)))
    (nreverse hits)))

(defun heks-emacs-scheme--hits-ordered (hits)
  "Return HITS ordered, with the file being read in front.

A name defined in the file one is reading is usually the one meant, so the
hits of that file come first; the rest are ordered by file and line, which
is what makes the same question asked twice answer the same way."
  (let* ((here (and buffer-file-name (expand-file-name buffer-file-name)))
         (sorted (sort (copy-sequence hits)
                       (lambda (one other)
                         (if (equal (nth 0 one) (nth 0 other))
                             (< (nth 1 one) (nth 1 other))
                           (string< (nth 0 one) (nth 0 other)))))))
    (append (seq-filter (lambda (hit) (equal (nth 0 hit) here)) sorted)
            (seq-remove (lambda (hit) (equal (nth 0 hit) here)) sorted))))

(defun heks-emacs-scheme-definitions-in-files (name)
  "Return the definitions of NAME in the files of this project, as xrefs.

The project is searched for the head of a `define' of NAME, and every hit
is read back and kept only if it really defines it: a search cannot tell a
name being defined from a name being used.  What is left is ordered with
the definitions of the buffer being edited first (see
`heks-emacs-scheme--hits-ordered')."
  (mapcar (lambda (hit)
            (xref-make (string-trim (nth 2 hit))
                       (xref-make-file-location (nth 0 hit) (nth 1 hit)
                                                (heks-emacs-scheme-definition-column
                                                 (nth 2 hit) name))))
          (heks-emacs-scheme--hits-ordered
           (seq-filter (lambda (hit)
                         (heks-emacs-scheme-definition-line-p (nth 2 hit) name))
                       (heks-emacs-scheme--search-files
                        (format heks-emacs-scheme-definition-forms
                                (regexp-quote name)))))))

(defconst heks-emacs-scheme-name-character-regexp
  "[a-zA-Z0-9!$%&*/:<=>?^_~+.@-]"
  "Regexp matching one character a Scheme name can be made of.

What tells a mention of a name from a mention of a longer name it is part
of: `greet' is not mentioned by `greeting', because the character after it
is a character a name can be made of.  A word boundary cannot say that,
because `1+', `string-append' and `set-x!' are names and a word boundary
falls in the middle of all three.  `.` and `-` are characters of a name for
the same reason, and the list is Guile's own `char-set:scheme-name'.")

(defun heks-emacs-scheme-mention-line-p (line name)
  "Return non-nil when LINE mentions NAME as a name of its own.

Every occurrence of NAME in LINE is looked at -- a line can mention it
more than once -- and the one that is a name of its own is what makes the
answer true.  The characters in front of and behind it are what decide
that, and the two ends of the line count as neither."
  (let ((start 0)
        (found nil))
    (while (and (not found) (string-match (regexp-quote name) line start))
      (let ((head (match-beginning 0))
            (tail (match-end 0)))
        (setq start (1+ head))
        (setq found (and (or (zerop head)
                             (not (string-match-p
                                   heks-emacs-scheme-name-character-regexp
                                   (substring line (1- head) head))))
                         (or (= tail (length line))
                             (not (string-match-p
                                   heks-emacs-scheme-name-character-regexp
                                   (substring line tail (1+ tail)))))))))
    found))

(defun heks-emacs-scheme-mentions-in-files (name)
  "Return the places NAME is mentioned in the files of this project, as xrefs.

This is what `M-?' answers with where the REPL has no callers to give: the
places the name is written are what the files know, and it is the REPL
that knows which of them call it.  The search and the order are the ones
the definitions are found with, so the file being read comes first here
too, and the definition of the name is one of the places it is mentioned."
  (mapcar (lambda (hit)
            (xref-make (string-trim (nth 2 hit))
                       (xref-make-file-location (nth 0 hit) (nth 1 hit)
                                                (string-match (regexp-quote name)
                                                              (nth 2 hit)))))
          (heks-emacs-scheme--hits-ordered
           (seq-filter (lambda (hit)
                         (heks-emacs-scheme-mention-line-p (nth 2 hit) name))
                       (heks-emacs-scheme--search-files (regexp-quote name))))))

(defconst heks-emacs-scheme-defined-name-forms
  "[(]define[^[:space:]()]*[[:space:]]+[(]?[^[:space:]()]+"
  "How the head of a definition looks, with the name itself in the match.

Where `heks-emacs-scheme-definition-forms' has a hole in it for the name,
this one asks for whatever is in that place, because the question it
answers -- which names does this project define -- is asked before there is
a name to put in it.  It is a pattern for `rg', for `grep -E' and for
Emacs alike, and the searchers are asked for the match alone, so what
comes back is the head of a definition rather than the line it is on.")

(defconst heks-emacs-scheme-defined-name-regexp
  "\\`[(]define[^[:space:]()]*[[:space:]]+[(]?\\([^[:space:]()]+\\)"
  "Regexp reading the name out of the head above.

The head is what `heks-emacs-scheme-defined-name-forms' matched: the word
that defines, the opening parenthesis of the name when a name is what
follows, and the name.")

(defconst heks-emacs-scheme-defined-names-lifetime 60
  "How long an answer of `heks-emacs-scheme-defined-names' stays good.

Reading the names is a search of every Scheme file of the project and the
reading of its hits in Emacs, and the names are what the prompt of `M-.'
completes from, so they are asked for every time a jump is asked for: a
sixth of a second over Guile's own 346 Scheme files, and more over a
project the size of Guix's.  A minute old is good enough for a list of
names to type into a prompt -- a name added to the project within the
minute is not offered, and is still found by the search the jump itself
does -- and it is what keeps the same question from being asked twice in
the time it takes to make two jumps.")

(defvar heks-emacs-scheme--defined-names-cache nil
  "The last answer of `heks-emacs-scheme-defined-names' as (ROOT TIME NAMES).

The directory the names were read from is kept with them, so that moving
to another project asks the question again rather than being answered with
the names of the one before.")

(defun heks-emacs-scheme-defined-names ()
  "Return the names the Scheme files of this project define.

The names are read out of the heads of the `define's the files hold, so a
`define' of any kind is one name and a name defined twice is one name.
They are the names `M-.' can be given when there is no name at point to
look up: `C-u M-.' asks for one, and what can be asked for of a project is
what its files define in it.  The answer is remembered for
`heks-emacs-scheme-defined-names-lifetime' seconds -- see there for why."
  (let* ((root (file-name-as-directory (expand-file-name (heks-emacs-scheme-load-path))))
         (cached heks-emacs-scheme--defined-names-cache)
         (fresh (and cached
                     (equal (nth 0 cached) root)
                     (< (- (float-time) (nth 1 cached))
                        heks-emacs-scheme-defined-names-lifetime))))
    (if fresh
        ;; Including the answer that no file defines anything: a project of
        ;; Scheme files that are not Scheme files is asked once, not once a
        ;; jump.
        (nth 2 cached)
        (let ((names '()))
          (dolist (hit (heks-emacs-scheme--search-files
                        heks-emacs-scheme-defined-name-forms t))
            (when (string-match heks-emacs-scheme-defined-name-regexp (nth 2 hit))
              (push (match-string 1 (nth 2 hit)) names)))
          (setq names (sort (delete-dups names) #'string<))
          (setq heks-emacs-scheme--defined-names-cache
                (list root (float-time) names))
          names))))

;;;
;;; The names that match a pattern, rather than one name that is asked for
;;;
;;; `xref-find-apropos' asks a question of another kind from the one every
;;; jump asks: not where a name is, but which names there are that match a
;;; pattern, and where each of them is.  What the files of a project can
;;; answer is read out of the heads of their `define's -- the same reading a
;;; single name is found with, asked of every definition the project has
;;; rather than of one name -- and the pattern is read here, in Emacs,
;;; rather than handed to a searcher: a searcher's patterns are not Emacs's,
;;; and the pattern of this question *is* the question, so there is nothing
;;; to quote for it the way the name of a jump is quoted.

(defun heks-emacs-scheme-definition-name (line)
  "Return the name of the definition head LINE holds, or nil.

The head has to begin the line, indentation aside, for the same reason a
hit is read back when a single name is looked for: a `define' that is
mentioned inside another form, or commented out, is not the definition of
anything this project can be jumped to.  It is the same name
`heks-emacs-scheme-defined-names' reads, out of the same head, and the
indentation is stepped over here because a searcher that is asked for the
line it found a head on prints the whole line."
  (let ((head (string-trim-left line)))
    (when (string-match heks-emacs-scheme-defined-name-regexp head)
      (match-string 1 head))))

(defun heks-emacs-scheme-definitions-in-files-matching (pattern)
  "Return the definitions in this project's files whose name matches PATTERN.

The answer is a list of (NAME . XREF): the name the head of the definition
defines, and the jump to it, whose line is the head itself -- the name,
the arguments and the body, which is the signature that makes a list of
definitions that match a pattern worth reading.  NAME is kept beside the
definition because the names the REPL answers with are read against these
(see `xref-backend-apropos'): a name both sources have is a name to be
offered once.

PATTERN is read the way `xref-find-apropos' reads one -- a regexp, or a
list of words that all have to appear (`xref-apropos-regexp').  The search
itself is made with the head of a `define' of any name at all, and every
head it answers with is read and matched here: one search answers a
pattern of any kind, and the searchers cannot be given the pattern to
answer with themselves.  What comes back is ordered the way the
definitions of one name are, with the file being read first."
  (let ((regexp (xref-apropos-regexp pattern)))
    (seq-remove
     #'null
     (mapcar
      (lambda (hit)
        (let* ((line (nth 2 hit))
               (name (heks-emacs-scheme-definition-name line)))
          (when (and name (string-match-p regexp name))
            (cons name
                  (xref-make (string-trim line)
                             (xref-make-file-location
                              (nth 0 hit) (nth 1 hit)
                              (heks-emacs-scheme-definition-column line name)))))))
      (heks-emacs-scheme--hits-ordered
       (heks-emacs-scheme--search-files heks-emacs-scheme-defined-name-forms))))))

(defun heks-emacs-scheme-xref-backend ()
  "Return this configuration's backend when the buffer is a Scheme one.

`xref' picks a backend by running the functions of
`xref-backend-functions' in turn and taking the first that answers, so
this is one of those.  It is put at the front of the hook, so that what
answers `M-.' in a Scheme buffer is this backend and not whichever one was
added to the hook last -- `dumb-jump' is the one the rest of the
configuration adds (see `dev-flymake.el') -- and the other backends are not thrown
away: the methods below ask `dumb-jump' themselves when the REPL and the
files have nothing to say."
  (when (derived-mode-p 'scheme-mode 'geiser-repl-mode) 'heks-emacs-scheme))

;; A depth rather than a flag: a negative depth is a place at the front of
;; the hook, and a backend added later would otherwise be the one that
;; answers first.  The function says nil in every buffer that is not a
;; Scheme one, so nothing else is affected by its being there.
(add-hook 'xref-backend-functions #'heks-emacs-scheme-xref-backend -90)

(cl-defmethod xref-backend-identifier-at-point ((_backend (eql heks-emacs-scheme)))
  "Return the name at point, read the way Scheme reads it.

Geiser's own reader, because a Scheme name can be made of the characters
-- `?', `!', `->' -- that a reader which knows words alone stops at, and
the reader of a Scheme buffer in an Emacs without Geiser is
`thing-at-point', which is what every other command there would name it
with."
  (heks-emacs-scheme--symbol-at-point))

(cl-defmethod xref-backend-identifier-completion-table ((_backend (eql heks-emacs-scheme)))
  "Return the names the Scheme files of this project define.

A jump with no name at point to look up asks for one, and the names the
project's own files define are the ones it can be answered with.  The REPL
is not asked for them even when it is running: the point of the question
is a name the code being read mentions -- about to be written, and not
loaded yet -- which is exactly what a REPL cannot complete."
  (heks-emacs-scheme-defined-names))

(cl-defmethod xref-backend-definitions ((_backend (eql heks-emacs-scheme)) identifier)
  "Return the definitions of IDENTIFIER: the REPL's, or the files'.

The REPL is asked first, and its answer is used when it names a file that
is on this machine: it is the source of the code that is running, so it is
right about a symbol of a module of Guile's or of Guix's own that this
project only imports, which no search of this project's files can find.
Where it has no answer -- a symbol whose module has never been loaded, a
name in a `use-modules' clause, or a buffer opened with no REPL at all --
the files answer instead, and where they have nothing, `dumb-jump' is
asked: it looks for a name wherever it appears in the shape of a
definition rather than only in the head of a `define', which is what finds
the names this cannot -- one bound by a `let', the accessor a record
declares."
  (or (heks-emacs-scheme--repl-definition identifier)
      (heks-emacs-scheme--repl-module identifier)
      (heks-emacs-scheme-definitions-in-files identifier)
      (heks-emacs-scheme--dumb-jump identifier)))

(cl-defmethod xref-backend-references ((_backend (eql heks-emacs-scheme)) identifier)
  "Return the places IDENTIFIER is used: the REPL's callers, or the files'.

`M-?' in a Scheme buffer used to answer with nothing, because the places a
name is used are the callers the REPL knows and nothing else, and a
project that is being read rather than run has no REPL to know them.  What
the REPL says is asked first, since it is reading the code that is
running; where there is no REPL, or it has no callers for the name, every
file of the project that mentions the name is offered instead."
  (or (heks-emacs-scheme--repl-callers identifier)
      (heks-emacs-scheme-mentions-in-files identifier)))

(cl-defmethod xref-backend-apropos ((_backend (eql heks-emacs-scheme)) pattern)
  "Return what matches PATTERN: the definitions of the files, and the REPL's names.

`xref-find-apropos' (`M-s .') asks a question of another kind from the one
`M-.' asks: not where one name is, but which names there are that match a
pattern, and where each of them is -- a name half remembered, a family of
names, the names of a project that mentions a word.  Both of the sources
this backend has answer it.

The files of the project are read for the heads of the definitions whose
name matches, and a definition arrives with its head as the line of its
jump: the name, the arguments, the body, which is what one is looking at a
list of matches for.  The REPL answers with the names it has loaded, which
is the half no search of this project can give -- the names of Guile's own
and of the libraries the project uses are names defined in files this
project does not hold -- and where such a name is is asked of the REPL
when it is jumped to (see `heks-emacs-scheme--repl-name'), so that the
list of matches is one question rather than one per name.

A name both sources answer for is offered once, with the files' answer,
because the files know the line the head is on and the name is what the
REPL knows; the names the REPL alone has come after them, in the order
Guile sorted them in."
  (let* ((matching (heks-emacs-scheme-definitions-in-files-matching pattern))
         (names (heks-emacs-scheme--repl-names pattern))
         (answered (mapcar #'car matching)))
    (append (mapcar #'cdr matching)
            (mapcar (lambda (name)
                      (xref-make name (heks-emacs-scheme--repl-name name)))
                    (seq-remove (lambda (name) (member name answered)) names)))))

;;;
;;; The REPL's answers
;;;
;;; Geiser's own questions, asked with Geiser's own accessors, and every
;;; answer read the same way: what it says about a file is only worth
;;; something if the file is here (a REPL started from a source tree this
;;; machine does not have can name the file the code was read from and send
;;; one nowhere), and what it says about a line is a line rather than a
;;; column, because that is all Guile keeps.

(defun heks-emacs-scheme-repl-connected-p ()
  "Say whether a REPL is running that this buffer can ask.

Geiser's commands stop and offer to start one when there is none -- see
`geiser-repl--connection*', which is what Geiser itself asks -- and a key
that jumps to a definition should not have to: the files can answer."
  (and (fboundp 'geiser-repl--connection*) (geiser-repl--connection*) t))

(defun heks-emacs-scheme--symbol-at-point ()
  "Return the name at point, as Geiser reads it, or nil.

Geiser's own reader -- the one its commands look a name up with, so that
`M-.' and `C-c g h' name the same thing -- and `thing-at-point' where
Geiser is not loaded: a buffer with no Geiser in it still has files to
answer with.  The name comes back as a string, which is what `xref'
carries; the `symbol' Geiser makes is for its own questions."
  (let ((name (or (and (fboundp 'geiser--symbol-at-point)
                       (geiser--symbol-at-point))
                  (thing-at-point 'symbol 'no-properties))))
    (and name (symbolp name) (symbol-name name))))

(defun heks-emacs-scheme--definition-head-regexp (name)
  "Return a regexp matching the head that defines NAME.

Geiser's own two patterns where Geiser is loaded -- the one for the shapes
a `define' head comes in, and the one for the names that arrive as a list,
`define-syntaxes' and `define-values' -- because a jump that lands where
Geiser's own jump lands is the point of this backend."
  (if (fboundp 'geiser-edit--def-re)
      (concat "\\(" (geiser-edit--def-re name) "\\|" (geiser-edit--def-re* name) "\\)")
    (format heks-emacs-scheme-definition-forms (regexp-quote name))))

(defun heks-emacs-scheme--file-location (file name line)
  "Return where NAME is defined in FILE, as (LINE COLUMN TEXT).

LINE is the line the REPL named, or nil where it named none, and the head
that defines NAME is looked for at or after it -- and from the beginning
of the file when it is not there, which is where this parts company with
Geiser's own jump: Geiser goes to the line it was told and then to the
first definition in the file, which is not always the one it was told
about.  TEXT is the text of the line that was landed on, and nil where the
file holds no head that defines NAME at all, whose caller then says the
name itself instead."
  (if (not (and (file-regular-p file) (file-readable-p file)))
      (list (or line 1) 0 nil)
    (with-temp-buffer
      (insert-file-contents file)
      (let* ((regexp (heks-emacs-scheme--definition-head-regexp name))
             (reported (save-excursion
                         (goto-char (point-min))
                         (when line (forward-line (1- (max 1 line))))
                         (point)))
             (found nil))
        (goto-char reported)
        (when (re-search-forward regexp nil t) (setq found (match-beginning 0)))
        (unless found
          (goto-char (point-min))
          (when (re-search-forward regexp nil t) (setq found (match-beginning 0))))
        (if found
            (progn
              (goto-char found)
              ;; Onto the name itself, which is where a jump should land:
              ;; the head begins one character, its parenthesis, to the left.
              (when (re-search-forward (concat (regexp-quote name)
                                               "\\([[:space:])]\\|\\'\\)")
                                       (line-end-position) t)
                (goto-char (match-beginning 0)))
              (list (line-number-at-pos) (current-column)
                    (string-trim (buffer-substring-no-properties
                                  (line-beginning-position) (line-end-position)))))
          (list (or line 1) 0 nil))))))

(defun heks-emacs-scheme--location-p (location)
  "Return LOCATION when it is a location, and nil when it is not one.

What Geiser's own jump reads as a location (`geiser-edit--try-edit'): it
arrives as a list -- a file, a line and the rest, or an empty list for a
symbol with no place Guile can name -- and Guile's `#f' is not one, because
a `#f' comes back through the protocol as the keyword `:f' rather than as
nothing at all.  Guile answers `#f' for a symbol it has and cannot place (a
procedure written in C, whose module it knows and whose file it does not)
and for a caller it knows no place for, so both of the answers this backend
reads -- a definition and a list of callers -- can carry one."
  (and (listp location) location))

(defun heks-emacs-scheme--location-xref (location name)
  "Return the xref for LOCATION, the place the REPL gave for NAME, or nil.

Nil is any answer that cannot be jumped to -- a location with no file, a
file that is not on this machine, a file that cannot be read, and, before
any of those, what is not a location at all (see
`heks-emacs-scheme--location-p') -- and the caller reads all of them the
same way, by asking the files instead: they are one nil rather than three
errors because the question they answer is the same one."
  (let* ((location (heks-emacs-scheme--location-p location))
         (file (and location (geiser-edit--location-file location)))
         (reported (and location (geiser-edit--location-line location))))
    (when (and file (file-exists-p file) (file-readable-p file))
      (let* ((place (heks-emacs-scheme--file-location
                     file (or (geiser-edit--location-name location) name) reported))
             (number (nth 0 place))
             (column (nth 1 place)))
        (xref-make (or (nth 2 place) name)
                   (xref-make-file-location file number column))))))

(defun heks-emacs-scheme--repl-definition (identifier)
  "Return the definition the REPL has for IDENTIFIER, as a list of xrefs.

Nil covers all the ways there is no answer to be had: no REPL is running,
the REPL does not know the name (its module was never loaded), the REPL
knows a file that is not on this machine, and the answer names a module
rather than a definition in it -- which is a jump to the top of a file and
nothing more, so the files of this project are asked instead.

The name is asked as a Scheme symbol, which is what Geiser's own commands
give `geiser-edit-symbol-location' and what its questions are written for:
a string becomes a Scheme string on the way to Guile, and a string is not a
name there.  A `#f' with no place to go is one of the answers, since Guile
answers `#f' for a symbol it has and cannot place (see
`heks-emacs-scheme--location-p')."
  (when (heks-emacs-scheme-repl-connected-p)
    (let ((location (ignore-errors
                      (geiser-edit-symbol-location (intern identifier)))))
      (when (listp location)
        (let ((xref (heks-emacs-scheme--location-xref location identifier)))
          (and xref (list xref)))))))

(defun heks-emacs-scheme--repl-module (identifier)
  "Return the module named at point, as an xref, or nil.

A name in a `use-modules' clause -- `(ice-9 popen)' -- has no definition
to jump to, and Geiser's own jump opens the module's file for it; that
answer is kept here, so that the one jump to a definition also goes to a
module, which is what `M-.' did in a Scheme buffer before `xref' did it."
  (when (heks-emacs-scheme-repl-connected-p)
    (let* ((module (ignore-errors (geiser-completion--module-at-point)))
           (location (heks-emacs-scheme--location-p
                      (and module
                           (ignore-errors (geiser-edit-module-location module)))))
           (file (and location (geiser-edit--location-file location))))
      (when (and module file (file-exists-p file) (file-readable-p file))
        (xref-make (format "module %s" module)
                   (xref-make-file-location file 1 0))))))

(defun heks-emacs-scheme--repl-callers (identifier)
  "Return what the REPL says calls IDENTIFIER, as a list of xrefs, or nil.

Geiser's own question, asked the way Geiser's own caller list asks it, and
every caller is turned into the xref of the place it is defined in, with
its signature as the line `consult-xref' shows.  A caller whose file is
not here is dropped rather than offered as a jump that goes nowhere."
  (when (heks-emacs-scheme-repl-connected-p)
    (let ((answer (ignore-errors
                    (geiser-eval--send/result
                     `(:eval (:ge callers (quote (:scm ,identifier))))))))
      (when (listp answer)
        (seq-remove
         #'null
         (mapcar (lambda (caller)
                   (let ((location (cdr (assoc "location" caller)))
                         (signature (cdr (assoc "signature" caller))))
                     (heks-emacs-scheme--location-xref
                      location (or (and (listp signature) (car signature))
                                   identifier))))
                 answer))))))

(defun heks-emacs-scheme--repl-names (pattern)
  "Return the names the REPL has loaded that match PATTERN, or nil.

This is the half of `xref-find-apropos' that no search of the project's
files can answer: the names the running program holds -- Guile's own, a
library the project uses, the project's own modules once they are loaded --
are names whose definitions are in files this project does not hold.  The
question is Guile's `apropos-internal', the one its own `apropos' is built
on, because what is wanted is which of its names match and not which of
them begin with something: that second question is Geiser's completion
(`(completions ...)'), and a fragment of a name is not what it answers.

PATTERN is read here, in Emacs (`xref-apropos-regexp'), so that a name of
the REPL's is a name of the same question as a name of the files', and the
names that come back are matched against that reading before they are
answered with -- the question Guile is asked is a wider one, and this is
what decides (see `heks-emacs-scheme--repl-question')."
  (when (heks-emacs-scheme-repl-connected-p)
    (let* ((regexp (xref-apropos-regexp pattern))
           (answer (ignore-errors
                     (geiser-eval--send/result
                      `(:eval (:scm ,(heks-emacs-scheme--repl-question pattern)))))))
      (when (listp answer)
        (seq-filter (lambda (name) (string-match-p regexp name)) answer)))))

(defun heks-emacs-scheme--repl-question (pattern)
  "Return the Scheme expression that asks the REPL which names match PATTERN.

The answer is the names themselves, sorted, as Scheme strings, which is
what Geiser's own questions come back as.  It is the one question of this
section that is not asked with a Geiser command, and it is asked of the
module `apropos-internal' lives in rather than importing it: the module a
REPL is in is `(guile-user)' or a project's own, and neither is a module
of this configuration's to change.

A pattern of whole words is asked for by its first word alone.  The names
are then read against the whole pattern in Emacs, so what comes back is a
superset of the answer rather than a different one; what cannot be sent is
the regexp Emacs makes of a list of words -- `\\(?:foo\\).*?\\(?:bar\\)' --
which is not a regexp Guile reads as that.  A pattern that is a regexp is
sent as it is, and is read as a Guile regexp on the way: for the patterns
a name is looked for with -- a name, its beginning, a piece of it -- the
two languages read a pattern the same way."
  (let ((print-escape-newlines t)
        (asked (if (string-equal (regexp-quote pattern) pattern)
                   (car (split-string pattern "[ \t]+" t))
                 pattern)))
    (format "(sort (map symbol->string ((@ (ice-9 session) apropos-internal) %s)) string<?)"
            (prin1-to-string asked))))

(cl-defstruct (heks-emacs-scheme--repl-name
               (:constructor heks-emacs-scheme--repl-name (name)))
  "A name the REPL has loaded, whose place is asked for when it is jumped to.

A definition of the files is kept with the place it is in; a name of the
REPL's own is kept as the name alone.  The names a program has loaded are
many and their files are files this project does not hold, so asking where
each of them is would be one question per name of a list one is reading
rather than jumping through.  What is asked when the one that is chosen is
jumped to is the question a jump asks, Geiser's own, which answers with the
file and the line -- and the head that defines the name is looked for
there, so the point lands on the name rather than on the parenthesis in
front of it."
  name)

(cl-defmethod xref-location-marker ((location heks-emacs-scheme--repl-name))
  "Return where the REPL says the name is, or stop with what it said.

Nil is what the REPL has to give for a name it has loaded and cannot name
a place for -- a primitive of Guile's, say -- and the entry is then one
that cannot be jumped to, said as much rather than standing for the first
place the name was searched for.  The question is asked here, on every
jump, rather than kept with the entry: the answer of a question is
remembered by `xref' like any other, and the REPL it was asked of may have
been restarted since -- a name that is no longer loaded is a jump that is
no longer possible."
  (let* ((name (heks-emacs-scheme--repl-name-name location))
         (definition (car (heks-emacs-scheme--repl-definition name))))
    (unless definition
      (user-error "The REPL has no place for `%s'" name))
    (xref-location-marker (xref-item-location definition))))

(cl-defmethod xref-location-group ((_location heks-emacs-scheme--repl-name))
  "Where a name the REPL knows is looked for: the REPL, which is asked."
  "the REPL")

(defun heks-emacs-scheme--dumb-jump (identifier)
  "Return what `dumb-jump' makes of IDENTIFIER, the wider search.

`dumb-jump' searches the project it finds on its own, and answers for the
home directory when it finds none; told which directory this is, it
searches that one."
  (when (and (fboundp 'dumb-jump-xref-activate) (dumb-jump-xref-activate))
    (let ((dumb-jump-project (heks-emacs-scheme-load-path)))
      (xref-backend-definitions 'dumb-jump identifier))))

(defun heks-emacs-scheme-callers ()
  "List what calls the function at point."
  (interactive)
  (geiser-xref-callers))

(defun heks-emacs-scheme-callees ()
  "List what the function at point calls."
  (interactive)
  (geiser-xref-callees))

(defun heks-emacs-scheme-generic-methods ()
  "List the methods of the generic function at point."
  (interactive)
  (geiser-xref-generic-methods))

(defun heks-emacs-scheme-test ()
  "Run the tests of the current project.

The project's own task does it (`maak test' through
`heks-emacs-project-start-test'), so the tests run the way the project
runs them and not in some way invented here."
  (interactive)
  (heks-emacs-project-start-test))

(defun heks-emacs-scheme-run-script ()
  "Run the current file as a Guile script.

The project root goes on the load path and the output lands in the usual
compilation buffer, so a failing script is one click away from its
backtrace, and a script that has been typed but not saved still runs."
  (interactive)
  (let* ((file (or buffer-file-name (user-error "The buffer is not visiting a file")))
         (root (file-name-as-directory (heks-emacs-scheme-load-path)))
         (copy (heks-emacs-tool-copy-buffer (concat (file-name-extension file t))))
         (command (mapconcat #'shell-quote-argument
                             (list (heks-emacs-tool-path heks-emacs-scheme-guile-program)
                                   "-L" root copy)
                             " "))
         (default-directory root)
         (buffer nil))
    (setq buffer (compile command))
    ;; `compile' returns the compilation buffer (or its cons with the
    ;; window) depending on the Emacs version; either way the copy is a
    ;; temporary file and goes away with the run.
    (with-current-buffer (if (consp buffer) (car buffer) buffer)
      (add-hook 'compilation-finish-functions
                (lambda (_buffer _message) (ignore-errors (delete-file copy)))
                nil t))))

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
backend shows the same diagnostics without leaving the buffer, but only
for a saved buffer, and this works either way."
  (interactive)
  (unless (heks-emacs-guix-available-p)
    (user-error "`%s' is not installed" heks-emacs-guix-program))
  (let ((expression (heks-emacs-guix-package-expression))
        (root (heks-emacs-scheme-load-path)))
    (unless expression
      (user-error "No package definition found in this buffer"))
    (let ((default-directory (file-name-as-directory root)))
      (compile (mapconcat #'shell-quote-argument
                          (append (list (heks-emacs-tool-path heks-emacs-guix-program) "lint" "-n")
                                  (when heks-emacs-guix-lint-checkers
                                    (list "-c" (mapconcat #'identity
                                                          heks-emacs-guix-lint-checkers ",")))
                                  (list "-L" root "-e" expression))
                          " ")))))

(defun heks-emacs-scheme-format-buffer ()
  "Format the current buffer in place.

With Guix installed that is `guix style', the formatter of Guix itself.
Without it, the buffer is re-indented the way `scheme-mode' indents Scheme
(which is also what `indent-region' does by hand) and its trailing
whitespace is dropped: there is no canonical Scheme formatter installed,
and this is the one thing that is always right about the indentation."
  (interactive)
  (let ((spec (heks-emacs-scheme-format-spec)))
    (if spec
        (heks-emacs-tool-format-buffer spec)
      (let ((inhibit-message t))
        ;; `indent-region' reports how many lines it changed; a formatter
        ;; says nothing when there is nothing to do, and so does this.
        (save-excursion
          (indent-region (point-min) (point-max))
          (delete-trailing-whitespace)))
      (message "Re-indented the buffer (install Guix for `guix style')"))))

(defun heks-emacs-scheme-buffer-p ()
  "Return non-nil when the current buffer holds Scheme code."
  (derived-mode-p 'scheme-mode))

;; `C-c i f' is the format key in every buffer, and it is a table the
;; buffer answers: in a Scheme one the formatter is the above, which uses
;; `guix style' where Guix is installed and the indentation of
;; `scheme-mode' where it is not.  `C-c g f' stays as the same command
;; under the Guile topic, for the fingers that look for it there.
(add-to-list 'heks-emacs-format-dispatch
             (cons #'heks-emacs-scheme-buffer-p
                   #'heks-emacs-scheme-format-buffer))

(defun heks-emacs-guix-style-apply-rule (rule)
  "Apply the `guix style' styling RULE to the current buffer.

The rules are Guix's own (`inputs', `arguments', `git-source', ...; see
`heks-emacs-guix-style-rules' and `guix style -l').  They rewrite the
file, so the buffer is saved first and reloaded once the rule has been
applied."
  (interactive (list (completing-read "Styling rule: " heks-emacs-guix-style-rules
                                      nil t nil nil (car heks-emacs-guix-style-rules))))
  (unless (heks-emacs-guix-available-p)
    (user-error "`%s' is not installed" heks-emacs-guix-program))
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
       :command (list (heks-emacs-tool-path heks-emacs-guix-program) "style" "-S" rule file)
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
;;; Keys and setup
;;;

;; Folding is not bound here: `heks-emacs-fold-*' (see
;; `modules/heks-emacs.el') dispatches to Hideshow, which is what these
;; buffers use, so a Scheme buffer folds with the same keys as a Java
;; buffer folds with.

(defun heks-emacs-scheme--jump-keys ()
  "Make `M-.' the jump it is everywhere else in a Geiser buffer.

Geiser binds `M-.' to its own `geiser-edit-symbol-at-point' in both of the
maps it makes -- the one a Scheme buffer uses and the one its REPL uses --
and a minor mode's map answers before the buffer's own does.  What that
key does in the rest of Emacs is `xref-find-definitions', and the Scheme
answers are behind it here (see `heks-emacs-scheme-xref-backend'), so the
key is given back to it: the jump stays the command it is everywhere, and
how good it is in Scheme is the backend's business rather than the key's.
`M-,' is left as Geiser binds it, because what it calls is `xref-go-back',
which is the command it is everywhere else too."
  (when (boundp 'geiser-mode-map)
    (define-key geiser-mode-map (kbd "M-.") #'xref-find-definitions))
  (when (boundp 'geiser-repl-mode-map)
    (define-key geiser-repl-mode-map (kbd "M-.") #'xref-find-definitions)))

(defvar heks-emacs-scheme-mode-map
  (let ((map (make-sparse-keymap)))
    ;; The REPL and evaluation: `r' opens it, `R' restarts it, `e' and
    ;; `E' evaluate, `k' stops what it is running, and `s' points it at
    ;; the module of this buffer.  (`k' rather than the `i' this used to
    ;; be: `i' inserts everywhere else in the scheme, and stopping a
    ;; process is what `k' says -- the same letter that shuts a language
    ;; server down under `C-c i'.)
    (define-key map (kbd "C-c g r") #'heks-emacs-scheme-repl)
    ;; A REPL that is already running somewhere else: Geiser connects to
    ;; it by host and port, which is what `o' opens elsewhere.
    (define-key map (kbd "C-c g o") #'geiser-connect)
    (define-key map (kbd "C-c g R") #'heks-emacs-scheme-repl-restart)
    (define-key map (kbd "C-c g s") #'heks-emacs-scheme-repl-switch-to-module)
    (define-key map (kbd "C-c g e") #'heks-emacs-scheme-eval-definition)
    (define-key map (kbd "C-c g E") #'heks-emacs-scheme-eval-region-or-buffer)
    (define-key map (kbd "C-c g b") #'heks-emacs-scheme-load-buffer)
    (define-key map (kbd "C-c g k") #'heks-emacs-scheme-interrupt)
    (define-key map (kbd "C-c g x") #'heks-emacs-scheme-run-script)
    (define-key map (kbd "C-c g d") #'heks-emacs-scheme-debugger)
    ;; Navigation, from Geiser's own database.
    ;; `C-c g g' is the same command `M-.' is -- `xref-find-definitions' --
    ;; because what finds a Scheme definition is the backend this module
    ;; installs (see `heks-emacs-scheme-xref-backend'), not a key.
    (define-key map (kbd "C-c g g") #'xref-find-definitions)
    (define-key map (kbd "C-c g h") #'heks-emacs-scheme-documentation)
    (define-key map (kbd "C-c g c") #'heks-emacs-scheme-callers)
    (define-key map (kbd "C-c g C") #'heks-emacs-scheme-callees)
    ;; `m' is a menu of the methods, which is what `m' is everywhere else.
    (define-key map (kbd "C-c g m") #'heks-emacs-scheme-generic-methods)
    ;; Testing, linting and formatting: `t' tests, `L' lints the Guix
    ;; packages in the buffer, `f' formats it and `S' applies one of
    ;; Guix's styling rules.  Formatting is only bound here for Scheme:
    ;; in every other buffer it is `C-c i f', which asks this command
    ;; when the buffer is a Scheme one.
    (define-key map (kbd "C-c g t") #'heks-emacs-scheme-test)
    (define-key map (kbd "C-c g L") #'heks-emacs-guix-lint-buffer)
    (define-key map (kbd "C-c g f") #'heks-emacs-scheme-format-buffer)
    (define-key map (kbd "C-c g S") #'heks-emacs-guix-style-apply-rule)
    ;; `p' is the package at point: `guix edit', the way `g' is the scheme
    ;; definition at point.  It used to be a global `C-c g l', which made
    ;; the one Guile key that worked outside a Scheme buffer.
    (define-key map (kbd "C-c g p") #'guix-package-location-on-mark)
    ;; The Scheme templates and the recorded macros that go with them.
    ;; They insert Scheme, so they live under the snippets topic rather
    ;; than among the generic text tools, and they are here rather than in
    ;; the global map because they only do something useful in Scheme.
    (define-key map (kbd "C-c s p") #'kbd-scheme-make-parameter)
    (define-key map (kbd "C-c s a") #'kbd-scheme-string-to-symbol-in-alist-access)
    (define-key map (kbd "C-c s h") #'kbd-scheme-hygguile-abstraction)
    map)
  "Keymap with the Guile and Guix extras, installed in `scheme-mode-map'.")

(use-package geiser
  :ensure t
  :init
  (setq geiser-active-implementations '(guile)
        ;; Geiser is the only client here, so it takes over Scheme buffers
        ;; by itself: completion, eldoc, the REPL and the debugger are
        ;; there the moment a `.scm' file is opened.
        geiser-mode-auto-p t
        geiser-mode-autodoc-p t
        geiser-mode-start-repl-p nil
        ;; One REPL per project, and its root on Guile's load path: that is
        ;; what makes project modules importable at once.
        geiser-repl-per-project-p t
        geiser-repl-use-other-window t
        geiser-repl-add-project-paths t)
  :config
  (defun heks-emacs-scheme--geiser-project ()
    "Project directory of the current buffer, for Geiser's REPL."
    (ignore-errors (project-root (project-current nil))))
  (setq geiser-repl-current-project-function #'heks-emacs-scheme--geiser-project)
  ;; Geiser's own two maps are loaded with it, so `M-.' is taken back here
  ;; rather than waiting for the first Scheme buffer.
  (heks-emacs-scheme--jump-keys))

(use-package geiser-guile
  :ensure t
  :config
  ;; A failed evaluation should show where it failed, and the compiler
  ;; should say what it thinks about the code that was just evaluated.
  (setq geiser-guile-debug-show-bt t
        geiser-guile-debug-show-full-bt t
        geiser-guile-debug-backwards-backtrace t
        geiser-guile-show-debug-help t
        geiser-guile-warning-level heks-emacs-scheme-guile-warning-level))

(defun heks-emacs-scheme-mode-setup ()
  "Set up a Scheme buffer for Guile and Guix work."
  (use-local-map (make-composed-keymap heks-emacs-scheme-mode-map
                                       (current-local-map)))
  (heks-emacs-scheme--jump-keys)
  (when (and (heks-emacs-guix-available-p) (heks-emacs-guix-buffer-p))
    ;; Guix's own modules, and the highlighting and commands of Emacs-Guix
    ;; (C-c . l to lint, C-c . b to build, C-c . u to use a module).
    (when (fboundp 'guix-devel-mode)
      (guix-devel-mode 1)))
  ;; A Scheme buffer is a sequence of top-level forms, so each one is a
  ;; block: collapsing the definition you are in then works from anywhere
  ;; inside it, which is not what Hideshow guesses by default.
  (setq-local hs-block-start-regexp "^("
              hs-forward-sexp-function #'forward-sexp)
  (hs-minor-mode 1)
  (heks-emacs-scheme-setup-flymake))

(add-hook 'scheme-mode-hook #'heks-emacs-scheme-mode-setup)

(provide 'heks-emacs/guile)

;;; guile.el ends here
