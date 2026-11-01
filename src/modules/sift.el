;;; sift.el --- sift: one formatter and linter for the three Lisps -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; sift is the formatter and the linter of the Lisp dialects this
;; configuration edits -- Scheme, Emacs Lisp and Common Lisp -- in one Guile
;; program.  It holds a file to forty-odd rules, each with a code
;; (`SIFT012'), a severity and, for many of them, a fix; it reads the rules a
;; project sets in its own `sift.yaml'; and it is the same program a pipeline
;; runs, so what a buffer is told here is what a build will be told.
;;
;; The editor side of it is not this configuration's to write.  It is the
;; `sift' package -- the `emacs/' directory of the same repository, installed
;; by Elpaca like every other package here -- and what the package does is
;; everything that talks to the program:
;;
;;   * `sift-flymake' runs `sift lint --stdin --format=json' on the buffer's
;;     own text and turns each finding into a diagnostic that carries the
;;     rule's code and name, so `sift-fix-at-point' fixes that rule and
;;     `sift-explain-at-point' opens the page that says what it wants.  The
;;     text goes to sift on standard input, so what is judged is what has been
;;     typed, saved or not, and nothing is written anywhere;
;;   * `sift-format-buffer', `sift-fix-buffer' and `sift-fix-at-point' send the
;;     buffer to the program and replace it with the answer, in one change
;;     group, so none of them saves the file and one `undo' takes it back;
;;   * `sift-check-buffer', `sift-lint' and `sift-ci' ask the question a
;;     pipeline asks -- is this file formatted, what does the whole project
;;     fail on -- and `sift-explain' prints a rule's page by name;
;;   * and it speaks the Language Server Protocol: `sift lsp'.  This module
;;     registers it with Eglot for the three Lisps (see
;;     `heks/sift-register-lsp'), so opening a Scheme, Emacs Lisp or Common
;;     Lisp file starts sift as the server of that buffer -- the same program
;;     the Flymake backend runs -- and the server's code actions are sift's
;;     own fixes, and ~textDocument/formatting~ is `sift format'.  What is
;;     *not* handed over is the drift: the server publishes lint findings and
;;     not formatting ones, so `heks/sift-drift-backend' keeps reporting
;;     them.  Nor is the Flymake backend left to say the same thing twice:
;;     when the server is sift, `sift-flymake' stands aside (see
;;     `heks/sift--eglot-stand-aside').
;;
;; What this module is, then, is what this configuration says to that, and the
;; shape of it is small on purpose:
;;
;;   * the program, and nothing else about it.  `sift-executable' is the one
;;     setting, and the configuration gives it the first of the two that
;;     answers: the `sift' on the `PATH', or the launcher of the checkout in
;;     ~/Hacking/sift -- a machine where sift is only a checkout still gets
;;     everything, which is how this configuration is developed;
;;   * the keys, in this configuration's grammar rather than the package's.
;;     `sift-mode' is turned on -- it is what puts sift's commands in a buffer,
;;     and writing a mode of our own to do it would be the duplication this
;;     module exists to end -- but its keymap is not the package's: the
;;     `C-c s' prefix is taken out of it, because `C-c s' is the snippets topic
;;     here, and the three actions are given the letters the scheme already
;;     promises -- `C-c g a' fixes the rule reported at point, `C-c g A'
;;     applies every fix, `C-c g H' explains it.  A minor mode's map answers
;;     in every buffer the mode is on in, so those three keys now work in
;;     Emacs Lisp and Common Lisp as well as in Scheme, which is one thing
;;     better than the Scheme-only bindings they replace.  Formatting keeps
;;     the keys it had: `C-c i f' in every buffer sift formats, and `C-c g f'
;;     in a Scheme buffer, where the fallback to Emacs' own indentation lives;
;;   * the drift report, which is the one thing the package does not have.
;;     `heks/sift-drift-backend' marks the lines `sift format' would rewrite:
;;     the disagreement `sift check' -- and so a pipeline running `sift ci' --
;;     fails a build over, reported while the code is being written rather
;;     than after it is committed.  It is built from `heks/tool-drift-backend',
;;     the same factory the shell and Terraform formatters come from, so it
;;     runs asynchronously, keeps its process to itself, and touches nothing:
;;     the formatter rewrites a *copy* of the buffer and the two are compared.
;;
;; Which dialect a buffer is comes from its major mode, as everything else
;; here does, and only the dialects sift knows are touched -- a Scheme file, an
;; Emacs Lisp file and a Common Lisp file, and nothing else.  Where sift is not
;; installed the whole module bows out and the modules that were here before it
;; are still what they were: the Guile compiler and `guix lint' check a Scheme
;; buffer, and `C-c i f' falls back to Emacs' own indentation.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

;; The package, which is where everything that talks to sift lives (see the
;; commentary).  It is not required here, and that is deliberate: a module
;; that required it would fail to load on the first start of a configuration
;; that is still building it.  Every function below reaches it by name, and
;; every backend bows out while it is not there.
(declare-function sift--dialect "sift" ())
(declare-function sift-mode "sift" (&optional arg))
(declare-function sift-flymake "sift" (report-fn &rest _arguments))
(declare-function sift-flymake-mode "sift" (&optional arg))
(declare-function sift-format-buffer "sift" ())
(declare-function sift--format-before-save "sift" ())
(declare-function sift-fix-at-point "sift" ())
(declare-function sift-fix-buffer "sift" ())
(declare-function sift-explain-at-point "sift" ())
(declare-function sift-eglot-contact "sift" (&rest _arguments))
(defvar sift-mode-map)
(defvar sift-executable)

;; Eglot is Emacs's own, and only what is asked of it here is declared: which
;; server serves which mode, and which buffer a server is managing.
(declare-function eglot-current-server "eglot" (&optional buffer))
(declare-function eglot-managed-p "eglot" (&optional buffer))
(declare-function jsonrpc-process "jsonrpc" (object))
(declare-function jsonrpc--process "jsonrpc" (object))
(defvar eglot-server-programs)
(defvar sift-format-style)
(defvar sift-comment-align)
(defvar sift-extra-arguments)

;; The tool plumbing of `modules/heks-emacs.el': the buffer-local register of
;; processes, and the factory that turns an answer the formatter wrote into
;; the diagnostics of the drift it reports.
(declare-function heks/tool-stop "heks-emacs" (name))
(declare-function heks/tool-drift-backend "heks-emacs" (name report-fn spec))
;; Defined by `modules/heks-emacs.el', which is loaded before any module; the
;; nil here is so that this file can also be loaded on its own, which the
;; test suite does.
(defvar heks/format-dispatch nil
  "Extra formatters, tried before the generic ones (see `heks-emacs.el').")

(defgroup heks/sift nil
  "The sift formatter and linter."
  :group 'heks)

(defcustom heks/sift-format-dialects '("scheme")
  "The dialects whose buffers `sift format' formats.

Scheme alone by default, and the reason is not that sift cannot format the
other two: it is that a Scheme buffer had a formatter here before
(`guix style') and the other two had Emacs' own indentation, and sift's idea
of how Emacs Lisp is laid out is its own -- a whole file of it arrives as a
diff.  Adding \"elisp\" or \"cl\" to this list is how a person who wants that
says so; it changes the drift backend, the format key and the before-save
hook together, since they are one answer."
  :type '(repeat string)
  :group 'heks/sift)

(defcustom heks/sift-lint-flymake t
  "Whether sift's findings are Flymake diagnostics in this buffer.

It applies to the three dialects sift knows -- Scheme, Emacs Lisp and Common
Lisp -- and it needs nothing but the one program: the buffer is sent to it on
standard input, so an unsaved buffer is judged as it is written."
  :type 'boolean
  :group 'heks/sift)

(defcustom heks/sift-format-flymake t
  "Whether the lines sift would reformat are Flymake diagnostics.

Drift is the disagreement between the buffer and `sift format', which is
what `sift check' -- and so a pipeline running `sift ci' -- fails over.  It
is reported while the code is written rather than after it is committed, and
the buffer is never touched by the check: the formatter runs on a copy and
the two are compared."
  :type 'boolean
  :group 'heks/sift)

;;
;; ====== Which program, and which dialect ======
;;

(defconst heks/sift-checkout (expand-file-name "~/Hacking/sift")
  "The sift checkout this configuration is developed against, if any.

It is where the configuration's own author keeps the program and its Emacs
package, and it is a convenience rather than a requirement: a machine without
it has sift on its `PATH' and nothing here notices.")

(defun heks/sift--checkout-program ()
  "Return the launcher of the checkout, when this machine has one."
  (let ((launcher (expand-file-name "bin/sift" heks/sift-checkout)))
    (and (file-executable-p launcher) launcher)))

(defun heks/sift-program-path ()
  "Return the sift program to run, as an absolute name when one is found.

`sift-executable' is the setting -- the package's own, since the package is
what runs it -- and this answers with the program that name points at,
falling back to the checkout for the machine where sift is not installed."
  (let ((program (or (bound-and-true-p sift-executable) "sift")))
    (or (executable-find program)
        (and (file-executable-p program) program)
        (heks/sift--checkout-program)
        program)))

(defun heks/sift-available-p ()
  "Return non-nil when sift is installed."
  (let ((program (heks/sift-program-path)))
    (and program (file-executable-p program) t)))

(defconst heks/sift-modes
  '(scheme-mode scheme-ts-mode emacs-lisp-mode lisp-mode lisp-data-mode)
  "The major modes sift is the tool of.

The three dialects as Emacs opens them: a Scheme file in the mode it is
openable in (with or without Tree-sitter), an Emacs Lisp file, and a Common
Lisp file in the mode of the language and in the one a Lisp data file comes
up in.  It is the list Eglot is given (see `heks/sift-register-lsp'); which
dialect a buffer is is the package's own table, which is what
`heks/sift-dialect' reads.")

(defun heks/sift-dialect ()
  "Return the sift dialect of the current buffer, or nil.

It is read from the major mode rather than guessed from the text: sift
refuses to guess for the same reason, and a `.scm' file that holds Emacs
Lisp is a question only the person editing it can answer.  The table that
answers it is the package's, so a mode the package has learned about is a
mode this configuration knows without being told."
  (and (fboundp 'sift--dialect) (sift--dialect)))

(defun heks/sift-applies-p ()
  "Return non-nil when sift has something to say about this buffer.

There are two halves of sift to have: the program, which the buffer is sent
to, and the package, which is what sends it.  A buffer gets nothing from one
without the other, so both are asked -- the package's own Flymake mode is the
name the second half is known by, and it is not there on the first start of a
configuration that is still building it."
  (and (heks/sift-available-p)
       (fboundp 'sift-flymake-mode)
       (heks/sift-dialect)
       t))

(defun heks/sift-formats-p ()
  "Return non-nil when sift is the formatter of this buffer.

`heks/sift-format-dialects' says which dialects those are -- Scheme alone
until someone says otherwise -- and `heks/sift-applies-p' says whether there
is a program to do it with."
  (and (heks/sift-applies-p)
       (member (heks/sift-dialect) heks/sift-format-dialects)
       t))

(defun heks/sift-lint-applies-p ()
  "Return non-nil when sift's findings belong as diagnostics in this buffer."
  (and heks/sift-lint-flymake (heks/sift-applies-p)))

(defun heks/sift-format-applies-p ()
  "Return non-nil when the drift of this buffer is worth reporting."
  (and heks/sift-format-flymake (heks/sift-formats-p)))

(defconst heks/sift-suffixes
  '(("scheme" . ".scm") ("elisp" . ".el") ("cl" . ".lisp"))
  "The file name suffix a copy of a buffer of each dialect is given.

The copy the drift backend hands the formatter is read as the Lisp it is,
which is what the dialect says and what the suffix agrees with; sift is told
the dialect as well, so the two cannot disagree about the same file.")

(defun heks/sift-suffix ()
  "Return the file name suffix of the current buffer's dialect."
  (or (cdr (assoc (heks/sift-dialect) heks/sift-suffixes)) ".scm"))

;;
;; ====== The drift the formatter would leave ======
;;

(defun heks/sift--format-arguments ()
  "Return the arguments the formatter is given on top of the file name.

The dialect is not optional -- sift will not guess it -- and the three
settings it is given here are the ones the package passes to
`sift-format-buffer' too, so that the answer the drift backend compares
against is the one the format key would write."
  (append (list (concat "--dialect=" (heks/sift-dialect)))
          (when (bound-and-true-p sift-format-style)
            (list (concat "--style=" sift-format-style)))
          (when (bound-and-true-p sift-comment-align)
            (list "--comment-align"))
          (bound-and-true-p sift-extra-arguments)))

(defun heks/sift--format-command (file)
  "Return the `sift format' command that rewrites FILE in place."
  (append (list (heks/sift-program-path) "format" "--write")
          (heks/sift--format-arguments)
          (list file)))

(defun heks/sift-drift-backend (report-fn &rest _arguments)
  "Flymake backend reporting the lines `sift format' would rewrite.

REPORT-FN is the callback Flymake hands every backend: it is given the
diagnostics of this run, or nil when there is no drift to report.

Drift is the disagreement between the buffer and `sift format', which is
what `sift check' and a pipeline running `sift ci' fail over.  The formatter
is handed a copy of the buffer -- named for the dialect, so that it is read
as the Lisp it is -- and asked to rewrite it in place; the copy and the
buffer are compared and the lines that differ are the findings, grouped into
ranges: a rewrapped argument list is one thing to look at rather than
fifteen.

Nothing is written to the buffer and nothing is saved: the copy is what is
rewritten, and it is deleted when sift is done with it.  The formatter runs
in the buffer's own directory, so the `sift.yaml' that says the line length
and the bracket style is the project's own -- the same answer a build gets,
arriving while the code is being written."
  (heks/tool-drift-backend
   "sift-format" report-fn
   (list :applies #'heks/sift-format-applies-p
         :suffix (heks/sift-suffix)
         :command #'heks/sift--format-command
         ;; sift is a Guile program: a first run of a checkout would
         ;; otherwise compile its own modules and say so on standard error,
         ;; which is where a failure is read from.
         :env '("GUILE_AUTO_COMPILE=0")
         :what "sift")))

;;
;; ====== Where it is wired in ======
;;

(defun heks/sift--format-before-save ()
  "Format the buffer before saving it, when `sift-format-on-save' says so.

The setting is the package's.  The hook is this module's, and it is here
because the package's own -- which `sift-mode' adds -- formats whichever
dialect the mode is on in, while which dialects are formatted rather than
only checked is this configuration's `heks/sift-format-dialects'.  The
package's hook is taken back out in `heks/sift-setup', where it is added."
  (when (and (bound-and-true-p sift-format-on-save) (heks/sift-formats-p))
    (sift-format-buffer)))

(defun heks/sift--mnemonic-keys ()
  "Give `sift-mode-map' this configuration's keys instead of the package's.

The package binds its commands under `C-c s' -- `C-c s f' formats, `C-c s x'
applies every fix, `C-c s a' the fix at point, `C-c s e' explains the rule --
and `C-c s' is the snippets topic here, so the whole prefix is taken out of
the map and the commands the scheme already names are bound to their own
letters: `a' the fix of the rule reported here, `A' every fix, `H' what that
rule wants.  `C-c g f' and `C-c i f' are left as they are -- formatting was
already the configuration's, in a Scheme buffer and in every buffer sift
formats.

What is not bound is the rest of the package's prefix: `sift-lint',
`sift-ci', `sift-check-buffer', `sift-format-region' and `sift-code-actions'
are `M-x' commands here.  The questions they ask -- is this file formatted,
what would a build say -- are already answered by the drift report, by
`C-c i f' and by the language server's own actions, and inventing a letter
for a command the scheme does not have an action for is how a keymap stops
being readable."
  (define-key sift-mode-map (kbd "C-c s") nil)
  (define-key sift-mode-map (kbd "C-c g a") #'sift-fix-at-point)
  (define-key sift-mode-map (kbd "C-c g A") #'sift-fix-buffer)
  (define-key sift-mode-map (kbd "C-c g H") #'sift-explain-at-point))

;; The map is the package's, and it exists once the package has loaded, so
;; this runs then rather than at the moment this file is read.
(with-eval-after-load 'sift (heks/sift--mnemonic-keys))

(defun heks/sift-setup ()
  "Turn sift on in the current buffer.

`sift-mode' is the package's mode: it puts sift's commands in the buffer --
`C-c g a', `C-c g A' and `C-c g H', in the letters this configuration gives
those actions (see `heks/sift--mnemonic-keys') -- and it adds a before-save
hook of its own, which is taken back out here and replaced by
`heks/sift--format-before-save', because which dialects are formatted rather
than only checked is `heks/sift-format-dialects' and not the mode's business.

`sift-flymake-mode' is the reporting half: it registers `sift-flymake' and
starts Flymake, and it bows out of a buffer with no dialect -- which is why
this is only called for the three Lisps.  The drift backend is added beside
it where sift is the formatter of the buffer.

The check runs when Flymake decides to run it, which is the buffer's own
business: a Scheme buffer sets its timing in `modules/guile.el' and checks on
save, since the Guix tools and the Guile compiler are slow; an Emacs Lisp or
Common Lisp buffer keeps Flymake's own, where sift answers in the few dozen
milliseconds it takes a Guile program to start."
  (when (heks/sift-applies-p)
    (sift-mode 1)
    (remove-hook 'before-save-hook #'sift--format-before-save t)
    (when (heks/sift-formats-p)
      (add-hook 'before-save-hook #'heks/sift--format-before-save nil t))
    (when (heks/sift-lint-applies-p)
      (sift-flymake-mode 1)
      (when (heks/sift-format-applies-p)
        (add-hook 'flymake-diagnostic-functions
                  #'heks/sift-drift-backend nil t)))
    ;; A buffer that is set up again while sift's server is already managing
    ;; it would otherwise carry both ways of hearing the same findings.
    (heks/sift--eglot-stand-aside)))

;; The three dialects are the three modes, and the module says what it has to
;; say in each of them.  `scheme-mode' is the one this file does not hook:
;; `modules/guile.el' sets a Scheme buffer up for Guile and calls
;; `heks/sift-setup' as part of that, since a Scheme buffer has more to set up
;; than its checker.
(add-hook 'emacs-lisp-mode-hook #'heks/sift-setup)
(add-hook 'lisp-mode-hook #'heks/sift-setup)

;;
;; ====== The language server ======
;;

;; sift speaks the Language Server Protocol, and this is the configuration's
;; answer to which server serves a Lisp: sift, for all five modes, through
;; the contact the package keeps, which is `sift-executable' followed by
;; `lsp' -- the same program the Flymake backend runs and the same one a
;; build runs.  What the server answers with is worth knowing before it is
;; turned on in a buffer: its diagnostics are the findings of `sift lint'
;; (the reader's own, on a file that does not parse), its code actions are
;; sift's fixes, and `textDocument/formatting' is `sift format'.  It does
;; *not* publish formatting findings, so the drift report is still this
;; module's to make.

(defun heks/sift-register-lsp ()
  "Give Eglot `sift lsp' for the three Lisps this configuration edits.

The registration is made when Eglot loads, because that is when
`eglot-server-programs' exists.  Connecting is not something to ask for:
`heks/eglot-ensure' is on the major mode hooks of the four modes the three
dialects open in (see `modules/eglot.el'), so a Scheme, Emacs Lisp or
Common Lisp file is served as soon as it is opened.  `M-x eglot' -- or
`C-c i e' -- is then what a buffer no hook reached is given by hand.  A
machine without the package is not a reason to leave the entry out: the
contact is a symbol resolved at connect time, and the package says that it
is missing better than a registration that silently is not there."
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 (cons heks/sift-modes #'sift-eglot-contact))))

(heks/sift-register-lsp)

(defun heks/sift--server-process (server)
  "Return the process behind the Eglot SERVER, or nil.

An Eglot server wraps the process it started, and the accessor of that
process is not the same name on every Emacs this configuration runs on:
`jsonrpc-process' up to Emacs 30, and `jsonrpc--process' from the version
that turned the connection into a class.  Both are asked, and a server that
is nothing yet answers nil."
  (cond ((null server) nil)
        ((fboundp 'jsonrpc-process)
         (ignore-errors (jsonrpc-process server)))
        ((fboundp 'jsonrpc--process)
         (ignore-errors (jsonrpc--process server)))))

(defun heks/sift-eglot-p ()
  "Return non-nil when the language server of this buffer is sift.

Eglot keeps the connection it made in `eglot-current-server', and the
command it started is on the process behind it: the contact registered for
the Lisps is the package's, whose command is `sift-executable' followed by
`lsp'.  A buffer with no server, or with a server that is something else,
answers nil."
  (when-let* (((fboundp 'eglot-managed-p))
              ((eglot-managed-p))
              (process (heks/sift--server-process
                        (ignore-errors (eglot-current-server)))))
    (equal "sift"
           (file-name-nondirectory
            (or (car (process-command process)) "")))))

(defun heks/sift--eglot-stand-aside ()
  "Let the sift server report what `sift-flymake' was reporting.

`sift lsp' publishes the findings of `sift lint' as LSP diagnostics, which
Eglot's own Flymake backend turns into the marginal notes `sift-flymake'
makes from the same program -- so a buffer with both says every finding
twice, which is the one thing this configuration refuses to do about a
diagnostic.  The server is the one that keeps them here, and the drift
report stays: the server sends lint findings and not formatting ones.

This runs at the end of `eglot-managed-mode-hook', after the function of
`modules/dev-flymake.el' that puts a buffer's checkers back beside the
server's: the point is to take one of them away again."
  (when (heks/sift-eglot-p)
    (remove-hook 'flymake-diagnostic-functions #'sift-flymake t)))

;; The depth is what makes the order: `heks/flymake-keep-backends' puts the
;; buffer's checkers back at the default depth, and this takes `sift-flymake'
;; out again after it has.
(add-hook 'eglot-managed-mode-hook #'heks/sift--eglot-stand-aside 90)

(defun heks/sift-format-key-p ()
  "Return non-nil when `C-c i f' should format this buffer with sift."
  (and (heks/sift-formats-p)
       (not (derived-mode-p 'scheme-mode 'scheme-ts-mode))))

;; `C-c i f' is the one format key of the configuration, and it is a table the
;; buffer answers: this is the entry for the dialects sift formats.  Scheme is
;; left to `modules/guile.el', which owns that buffer's formatter and knows
;; what to do where sift is not installed -- Emacs' own indentation -- and
;; which this entry would otherwise steal the key from.
(add-to-list 'heks/format-dispatch
             (cons #'heks/sift-format-key-p #'sift-format-buffer))

;;
;; ====== The package ======
;;

;; `sift` is the editor side of the program (see the commentary), and this is
;; the whole of what the configuration asks of it: the package itself, from
;; the repository that holds both halves.  Its `:files' is the `emacs/'
;; directory alone -- the rest of that repository is the program, which is
;; installed as a program and not as a package.
;;
;; `:init' is where the machine is asked which program to run.  The package
;; defaults to the `sift' on the `PATH', which is right for everyone whose sift
;; is installed; the configuration knows one more place it can be, and hands
;; it over when the name on the `PATH' answers with nothing.
(use-package sift
  :ensure (:host github :repo "jjba23/sift" :branch "trunk"
                 :files ("emacs/sift.el"))
  :demand t
  :init
  (unless (executable-find (or (bound-and-true-p sift-executable) "sift"))
    (when-let* ((checkout (heks/sift--checkout-program)))
      (setq sift-executable checkout))))

(provide 'heks/sift)

;;; sift.el ends here
