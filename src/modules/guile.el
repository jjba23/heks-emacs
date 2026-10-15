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
;;               `(use-modules (my project))' just works.
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
;;   `C-c g g'   go to the definition of the symbol at point.
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

(require 'cl-lib)
(require 'flymake)
(require 'hideshow)
(require 'scheme)
(require 'seq)

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

(defun heks-emacs-scheme-repl ()
  "Start or switch to the REPL of the current project.

The REPL belongs to the project (`geiser-repl-per-project-p'), with the
project root on Guile's load path, so a second visit to the same project
lands in the REPL that is already running.  In a Guix buffer that REPL is
a Guix one; see `heks-emacs-scheme-guix-repl-p'."
  (interactive)
  (unless (derived-mode-p 'scheme-mode)
    (user-error "Open a Scheme buffer first"))
  (heks-emacs-scheme--with-repl-program
   (lambda ()
     (geiser-mode 1)
     (geiser-repl-switch))))

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

AND-GO switches to the REPL afterwards, as with `geiser-eval-definition'."
  (interactive "P")
  (geiser-eval-definition and-go))

(defun heks-emacs-scheme-eval-region-or-buffer ()
  "Evaluate the active region, or the whole buffer, in the REPL."
  (interactive)
  (if (use-region-p)
      (geiser-eval-region (region-beginning) (region-end))
    (geiser-eval-buffer)))

(defun heks-emacs-scheme-load-buffer ()
  "Load the current file into the REPL."
  (interactive)
  (let ((file (or buffer-file-name (user-error "The buffer is not visiting a file"))))
    (save-buffer)
    (geiser-load-file file)))

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

(defun heks-emacs-scheme-find-definition ()
  "Jump to the definition of the symbol at point."
  (interactive)
  (geiser-edit-symbol-at-point))

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

(defvar heks-emacs-scheme-mode-map
  (let ((map (make-sparse-keymap)))
    ;; The REPL and evaluation: `r' opens it, `R' restarts it, `e' and
    ;; `E' evaluate, `k' stops what it is running, and `s' points it at
    ;; the module of this buffer.  (`k' rather than the `i' this used to
    ;; be: `i' inserts everywhere else in the scheme, and stopping a
    ;; process is what `k' says -- the same letter that shuts a language
    ;; server down under `C-c i'.)
    (define-key map (kbd "C-c g r") #'heks-emacs-scheme-repl)
    (define-key map (kbd "C-c g R") #'heks-emacs-scheme-repl-restart)
    (define-key map (kbd "C-c g s") #'heks-emacs-scheme-repl-switch-to-module)
    (define-key map (kbd "C-c g e") #'heks-emacs-scheme-eval-definition)
    (define-key map (kbd "C-c g E") #'heks-emacs-scheme-eval-region-or-buffer)
    (define-key map (kbd "C-c g b") #'heks-emacs-scheme-load-buffer)
    (define-key map (kbd "C-c g k") #'heks-emacs-scheme-interrupt)
    (define-key map (kbd "C-c g x") #'heks-emacs-scheme-run-script)
    (define-key map (kbd "C-c g d") #'heks-emacs-scheme-debugger)
    ;; Navigation, from Geiser's own database.
    (define-key map (kbd "C-c g g") #'heks-emacs-scheme-find-definition)
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
  (setq geiser-repl-current-project-function #'heks-emacs-scheme--geiser-project))

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
