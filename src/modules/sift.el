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
;; It takes the place of two things that were here before it, and both
;; reasons are worth keeping written down:
;;
;;   * `guix style' was the Scheme formatter and the source of the drift
;;     diagnostics, and it existed only on a machine with Guix, for one
;;     dialect, with no rules and no fixes.  sift formats the same files on a
;;     machine that has Guile and nothing else, in the three dialects, and it
;;     is what checks the formatting too -- the drift this module reports is
;;     `sift format' disagreeing with the buffer, which is exactly the
;;     disagreement `sift check' fails a build over;
;;   * `scheme-lint.el' was this configuration's own reading of a Scheme
;;     buffer, and its own idea of the rules a Scheme file is held to.  It was
;;     a good idea written a second time: sift has the same rules and more
;;     (line length, unused arguments and bindings, SXML, naming, nesting,
;;     reader-prefix breaks), every one of them with a code that can be
;;     explained and a fix where a machine can write one, and it reads Scheme,
;;     Emacs Lisp and Common Lisp rather than Scheme alone.  Two checkers with
;;     two opinions about the same form is how a person learns to ignore both,
;;     so the module is gone and this one is what checks a Scheme buffer.
;;
;; Two Flymake backends come out of it, and they are separate on purpose:
;;
;;   * `heks/sift-lint-backend' runs `sift lint --stdin --format=json' and
;;     turns each finding into a diagnostic that carries the rule's code and
;;     name, so a marginal note says `SIFT012' and `C-c g H' on it opens the
;;     rule's page.  The buffer text goes to sift on standard input, so
;;     unsaved edits are what is judged and nothing is written anywhere;
;;   * `heks/sift-format-backend' runs `sift format --stdin --stdout' on the
;;     buffer and marks the lines the answer would rewrite -- the drift a
;;     pipeline fails on, reported while the code is being written rather than
;;     after it is committed.  The formatter's answer replaces nothing: the
;;     buffer is never touched by a check.
;;
;; The formatting itself is `heks/sift-format-buffer', which is what `C-c g f'
;; and `C-c i f' run in a Scheme buffer; the fixes are `heks/sift-fix-at-point'
;; (`C-c g a', the rule reported on the line under point), `heks/sift-fix-buffer'
;; (`C-c g A', every rule at once); and `heks/sift-explain-rule' (`C-c g H')
;; prints what a code means.  None of them saves the file: each replaces the
;; buffer text in one change group, so one `undo' takes it back.
;;
;; Which dialect a buffer is comes from its major mode, as everything else
;; here does, and only the dialects sift knows are touched -- a Scheme file, an
;; Emacs Lisp file and a Common Lisp file, and nothing else.  Where sift is not
;; installed the whole module bows out and the modules that were here before it
;; are still what they were: the Guile compiler checks a Scheme buffer, and
;; `C-c i f' falls back to Emacs' own indentation.

;;; Code:

(require 'cl-lib)
(require 'flymake)
(require 'json)
(require 'seq)
(require 'subr-x)

;; The tool plumbing of `modules/heks-emacs.el': the buffer-local register of
;; processes, so that a backend stops its own previous run and nobody
;; else's, and the two readers of a tool's output this module converts into
;; diagnostics.
(declare-function heks/tool-stop "heks-emacs" (name))
(declare-function heks/tool-error-line "heks-emacs" (text))
(declare-function heks/tool-drift-diagnostics "heks-emacs" (original rewritten what))
(declare-function heks/line-position "heks-emacs" (line &optional column))
(defvar heks/tool-processes)

(defgroup heks/sift nil
  "The sift formatter and linter."
  :group 'heks)

(defcustom heks/sift-program
  (or (executable-find "sift")
      (let ((checkout (expand-file-name "~/Hacking/sift/bin/sift")))
        (and (file-executable-p checkout) checkout))
      "sift")
  "The sift program to run.

A bare name is looked up on the `exec-path'; an absolute name is used as
it is.  The default is the first of the two that answers, because sift is
one program for three dialects and there is no reason to have to say so
twice: a machine with it installed gets the installed one, and a machine
where it is only a checkout gets the launcher of that checkout."
  :type 'string
  :group 'heks/sift)

(defcustom heks/sift-lint-flymake t
  "Whether sift's findings are Flymake diagnostics in this buffer.

It applies to the three dialects sift knows -- Scheme, Emacs Lisp and
Common Lisp -- and it needs nothing but the one program: the buffer is
sent to it on standard input, so an unsaved buffer is judged as it is
written."
  :type 'boolean
  :group 'heks/sift)

(defcustom heks/sift-format-flymake t
  "Whether the lines sift would reformat are Flymake diagnostics.

Drift is the disagreement between the buffer and `sift format', which is
what `sift check' -- and so a pipeline running `sift ci' -- fails over.
It is reported while the code is written rather than after it is
committed, and the buffer is never touched by the check: the formatter
runs on the text and its answer is only compared."
  :type 'boolean
  :group 'heks/sift)

(defcustom heks/sift-format-dialects '("scheme")
  "The dialects whose buffers `sift format' formats.

Scheme alone by default, and the reason is not that sift cannot format
the other two: it is that a Scheme buffer had a formatter here before
(`guix style') and the other two had Emacs' own indentation, and sift's
idea of how Emacs Lisp is laid out is its own -- a whole file of it
arrives as a diff.  Adding \"elisp\" or \"cl\" to this list is how a
person who wants that says so; it changes the drift backend, the format
key and `heks/sift-format-buffer' together, since they are one answer."
  :type '(repeat string)
  :group 'heks/sift)

(defcustom heks/sift-severity "info"
  "The lowest severity sift reports.

\"info\" is everything sift has, which is what a buffer wants while it is
being written; a person who would rather see only what a build would fail
on sets \"warning\".  nil passes nothing at all, and the project's own
`sift.yaml' decides -- which is the right place for a decision about a
project."
  :type '(choice (const :tag "The project's own setting" nil)
                 (const "error") (const "warning") (const "info"))
  :group 'heks/sift)

(defcustom heks/sift-format-on-save nil
  "Whether sift formats a buffer before saving it.

Off by default: formatting on save is convenient exactly as long as one
trusts the formatter, and a person who has just met sift would rather
press `C-c g f' and look at the diff."
  :type 'boolean
  :group 'heks/sift)

(defcustom heks/sift-extra-arguments nil
  "Extra arguments passed to every sift invocation.

For what a project's own `sift.yaml' cannot say and a buffer wants
anyway, such as a line length while a file is being written."
  :type '(repeat string)
  :group 'heks/sift)

;;
;; ====== What the buffer is, and what sift is told ======
;;

(defconst heks/sift-dialects
  '((scheme-mode . "scheme")
    (scheme-ts-mode . "scheme")
    (emacs-lisp-mode . "elisp")
    (lisp-mode . "cl")
    (lisp-data-mode . "cl"))
  "The dialect sift is told each major mode is written in.

The list is sift's own three (`--dialect' takes scheme, elisp or cl) and
the modes Emacs opens those Lisps in.  A mode that is not here is a mode
sift has nothing to say about, and every backend below bows out of it.")

(defun heks/sift-program-path ()
  "Return the sift program to run, as an absolute name when one is found."
  (or (executable-find heks/sift-program)
      (and (file-executable-p heks/sift-program) heks/sift-program)
      heks/sift-program))

(defun heks/sift-available-p ()
  "Return non-nil when sift is installed."
  (let ((program (heks/sift-program-path)))
    (and program (file-executable-p program) t)))

(defun heks/sift-dialect ()
  "Return the sift dialect of the current buffer, or nil.

It is read from the major mode rather than guessed from the text: sift
refuses to guess for the same reason, and a `.scm' file that holds Emacs
Lisp is a question only the person editing it can answer."
  (cdr (assq major-mode heks/sift-dialects)))

(defun heks/sift-applies-p ()
  "Return non-nil when sift has something to say about this buffer.

The buffer has to be one of the three Lisps, and sift has to be
installed; everything else follows from those two."
  (and (heks/sift-available-p)
       (heks/sift-dialect)
       t))

(defun heks/sift-formats-p ()
  "Return non-nil when sift is the formatter of this buffer.

`heks/sift-format-dialects' says which dialects those are -- Scheme
alone until someone says otherwise -- and `heks/sift-applies-p' says
whether there is a program to do it with."
  (and (heks/sift-applies-p)
       (member (heks/sift-dialect) heks/sift-format-dialects)
       t))

(defun heks/sift-label ()
  "Return the name sift should give this buffer in its findings.

The file it visits, so that a diagnostic names the file it is about; a
buffer with no file -- a scratch buffer, a `*scheme*' from a REPL -- is named
by the buffer, which is all it has."
  (or buffer-file-name (buffer-name)))

(defun heks/sift-environment ()
  "Return the environment sift runs in.

`GUILE_AUTO_COMPILE=0' is the one that matters: sift is a Guile program,
and a first run of a checkout would otherwise spend its time compiling
its own modules and saying so on standard error, which is where this
module reads a failure from.  The other two ask for output without colour,
which is output whose positions can be read."
  (list "GUILE_AUTO_COMPILE=0" "NO_COLOR=1" "TERM=dumb"))

(defun heks/sift--shared-arguments ()
  "Return the arguments every sift invocation shares.

The dialect is not optional -- sift will not guess it -- so this is only
called from places that have already checked for one.  The severity is
here only when `heks/sift-severity' says something, so that a project's
own `sift.yaml' is heard where this configuration has no opinion."
  (append (list (concat "--dialect=" (heks/sift-dialect))
                (concat "--label=" (heks/sift-label)))
          (when heks/sift-severity
            (list (concat "--severity=" heks/sift-severity)))
          heks/sift-extra-arguments))

;;
;; ====== Running it ======
;;
;; Two shapes of call, because there are two kinds of caller.  The commands a
;; person types wait for the answer: a buffer is a few dozen milliseconds of
;; sift's time, and a command that has to be worth its key should be done when
;; it returns.  Flymake does not wait: it runs again on every change, so the
;; text goes to a process and the buffer is handed back at once, the way the
;; external tools of `modules/heks-emacs.el' are run.

(defun heks/sift--failure (result)
  "Return a sentence saying why the sift run in RESULT failed, or nil.

sift's exit status is its answer: 0 is nothing to say, 1 is findings, and
2 is a run that could not be made -- a file that does not parse, an
option it does not know, a checker that does not exist.  The last is the
one with a sentence to show, and the sentence is the last line of what it
wrote on standard error, for the reason `heks/tool-error-line' gives."
  (let ((status (plist-get result :status)))
    (when (and status (not (memq status '(0 1))))
      (or (heks/tool-error-line (plist-get result :stderr))
          (string-trim (or (plist-get result :stderr) ""))
          (format "sift exited %s" status)))))

(defun heks/sift-run (arguments &optional source)
  "Run sift with ARGUMENTS, sending SOURCE to its standard input.

Return a plist of `:status', `:stdout' and `:stderr'.  This waits for the
answer, which is what a command a person typed wants."
  (with-temp-buffer
    (when source (insert source))
    (let* ((errors (make-temp-file "heks-sift-errors-"))
           (process-environment (append (heks/sift-environment)
                                        process-environment))
           (default-directory (file-name-as-directory
                               (expand-file-name default-directory)))
           (status (apply #'call-process-region
                          (point-min) (point-max)
                          (heks/sift-program-path)
                          ;; the buffer holds the input: it is emptied and the
                          ;; answer lands in its place
                          t (list t errors) nil arguments))
           (stdout (buffer-string))
           (stderr (with-temp-buffer
                     (insert-file-contents errors)
                     (buffer-string))))
      (delete-file errors)
      (list :status status :stdout stdout :stderr stderr))))

(defun heks/sift-run-async (name arguments source callback)
  "Run sift with ARGUMENTS on SOURCE, calling CALLBACK with the answer.

NAME is what this run is called in `heks/tool-processes', so that a
second run of the same backend stops the first -- a backend that left its
old processes running would report the findings of an older buffer.
CALLBACK receives the plist `heks/sift-run' returns, and is called in the
buffer the question was asked about."
  (heks/tool-stop name)
  (let* ((origin (current-buffer))
         (output (generate-new-buffer " *sift output*"))
         (errors (generate-new-buffer " *sift errors*"))
         (process-environment (append (heks/sift-environment) process-environment))
         (default-directory (file-name-as-directory (expand-file-name default-directory)))
         (process
          (make-process
           :name name
           :buffer output
           :stderr errors
           :noquery t
           :connection-type 'pipe
           :coding 'utf-8-unix
           :command (cons (heks/sift-program-path) arguments)
           :sentinel
           (lambda (process _event)
             (when (memq (process-status process) '(exit signal))
               (let ((result (list :status (process-exit-status process)
                                   :stdout (with-current-buffer output (buffer-string))
                                   :stderr (with-current-buffer errors (buffer-string)))))
                 (kill-buffer output)
                 (kill-buffer errors)
                 ;; A buffer that was killed while sift was running has
                 ;; nothing left to report into.
                 (when (buffer-live-p origin)
                   (with-current-buffer origin
                     (when (eq (alist-get name heks/tool-processes) process)
                       (setf (alist-get name heks/tool-processes) nil))
                     (funcall callback result)))))))))
    (setf (alist-get name heks/tool-processes) process)
    (process-send-string process source)
    (process-send-eof process)
    process))

;;
;; ====== What it answers, as diagnostics ======
;;

(defun heks/sift--type (severity)
  "Return the Flymake type of a sift SEVERITY.

sift grades a finding `error', `warning' or `info'; Flymake has `:error',
`:warning' and `:note', and the two lists are the same length for the
same reason -- what a reader should do about it."
  (pcase severity
    ("error" :error)
    ("warning" :warning)
    (_ :note)))

(defun heks/sift--diagnostics (json)
  "Turn sift's JSON answer in JSON into Flymake diagnostics for this buffer.

sift counts lines and columns from one, and columns in characters, which
is what `heks/line-position' moves by: a diagnostic lands where the
finding says it is even in a file full of UTF-8.  The rule's code goes
in the diagnostic's code slot and its name in the data, because a
diagnostic is read by three different readers -- the margin, the list of
a buffer's diagnostics, and a command that fixes the rule at point -- and
only the last of them can look in the data."
  (let ((findings (json-parse-string json
                                     :object-type 'alist
                                     :array-type 'list
                                     :null-object nil
                                     :false-object nil))
        (diagnostics '()))
    (dolist (finding findings (nreverse diagnostics))
      (let* ((line (alist-get 'line finding))
             (column (alist-get 'column finding))
             (rule (alist-get 'checker finding))
             (code (alist-get 'code finding))
             (severity (alist-get 'severity finding))
             (message (alist-get 'message finding))
             (begin (heks/line-position line column))
             (end (heks/line-position line (1+ column))))
        (push (flymake-make-diagnostic
               (current-buffer) begin end
               (heks/sift--type severity)
               ;; (ORIGIN CODE MESSAGE), which Emacs renders as
               ;; "sift [SIFT012]: ..."; the rule's name goes at the end of
               ;; the sentence, where it is never in the way of what the
               ;; rule has to say.
               (list "sift" code (format "%s [%s]" message rule))
               (list :rule rule :code code :severity severity))
              diagnostics)))))

(defun heks/sift-lint-applies-p ()
  "Return non-nil when sift's findings belong as diagnostics in this buffer."
  (and heks/sift-lint-flymake (heks/sift-applies-p)))

(defun heks/sift-lint-backend (report-fn &rest _arguments)
  "Flymake backend running `sift lint' on the current buffer.

The buffer's text goes to sift on standard input, so nothing has to be
saved first; the answer comes back as JSON, which is the only shape that
carries the rule's code and name beside the sentence.  The run is
asynchronous, so typing is never held up by it."
  (if (not (heks/sift-lint-applies-p))
      (funcall report-fn nil)
    (let ((source (buffer-substring-no-properties (point-min) (point-max)))
          (origin (current-buffer)))
      (heks/sift-run-async
       "sift-lint"
       (append (list "lint" "--stdin" "--format=json") (heks/sift--shared-arguments))
       source
       (lambda (result)
         (let ((failure (heks/sift--failure result)))
           (cond
            (failure (funcall report-fn :panic failure))
            ((not (buffer-live-p origin)) nil)
            (t
             (with-current-buffer origin
               (condition-case error
                   (funcall report-fn
                            (heks/sift--diagnostics (or (plist-get result :stdout) "")))
                 (error
                  (funcall report-fn :panic
                           (format "sift: its JSON could not be read: %s"
                                   (error-message-string error))))))))))))))

;;
;; ====== The drift the formatter would leave ======
;;

(defun heks/sift-format-applies-p ()
  "Return non-nil when sift is the formatter of this buffer."
  (and heks/sift-format-flymake (heks/sift-formats-p)))

(defun heks/sift-format-backend (report-fn &rest _arguments)
  "Flymake backend reporting the lines `sift format' would rewrite.

The formatter's answer is compared with the buffer and the lines that
differ are the findings, grouped into ranges: a rewrapped argument list is
one thing to look at rather than fifteen.  Nothing is written anywhere --
the text goes to sift and the answer comes back -- so the buffer is never
touched by the check, and its unsaved state is what is being checked."
  (let ((original (unless (string-empty-p
                           (string-trim (buffer-substring-no-properties
                                         (point-min) (point-max))))
                    (buffer-substring-no-properties (point-min) (point-max))))
        (origin (current-buffer)))
    (if (not (and original (heks/sift-format-applies-p)))
        (funcall report-fn nil)
      (heks/sift-run-async
       "sift-format"
       (append (list "format" "--stdin" "--stdout") (heks/sift--shared-arguments))
       original
       (lambda (result)
         (cond
          ;; A file that does not parse has no formatted answer, and the
          ;; reader's own finding is what `heks/sift-lint-backend' reports;
          ;; saying it twice would be two diagnostics for one missing
          ;; parenthesis.
          ((heks/sift--failure result) (funcall report-fn nil))
          ((not (buffer-live-p origin)) nil)
          (t
           (with-current-buffer origin
             (funcall report-fn
                      (heks/tool-drift-diagnostics
                       original (or (plist-get result :stdout) original)
                       "sift"))))))))))

;;
;; ====== Formatting, fixing and explaining ======
;;

(defun heks/sift--replace-buffer (text what)
  "Replace the buffer with TEXT, saying WHAT was done.

One change group, so a single `undo' takes the whole thing back, and the
point kept where it was: a formatter that moved the cursor would make a
person find their place again after every format."
  (let ((point (point)))
    (atomic-change-group
      (let ((inhibit-modification-hooks nil))
        (erase-buffer)
        (insert text)))
    (goto-char (min point (point-max)))
    (message "sift: %s" what)))

(defun heks/sift--format-string (text)
  "Return TEXT as `sift format' writes it, or signal a `user-error'.

A run sift could not finish -- a buffer that does not parse, a dialect it
does not know, a program that is not there -- is said out loud: a
formatter that silently does nothing teaches a person to believe it
worked."
  (let ((result (heks/sift-run
                 (append (list "format" "--stdin" "--stdout")
                         (heks/sift--shared-arguments))
                 text)))
    (if-let* ((failure (heks/sift--failure result)))
        (user-error "sift: %s" failure)
      (plist-get result :stdout))))

(defun heks/sift-format-buffer ()
  "Format the whole buffer with sift.

The text is sent to sift and its answer replaces the buffer: nothing is
written to disk, so the formatting of unsaved code is the formatting of
what is there, and the change is one `undo' away."
  (interactive)
  (unless (heks/sift-formats-p)
    (user-error "sift does not format a %s buffer here" major-mode))
  (let* ((source (buffer-substring-no-properties (point-min) (point-max)))
         (formatted (heks/sift--format-string source)))
    (if (string= formatted source)
        (message "sift: already formatted")
      (heks/sift--replace-buffer formatted "formatted"))))

(defun heks/sift--fix-string (text &optional rule)
  "Return TEXT with sift's fixes applied, or TEXT itself when there are none.

RULE, when given, restricts the fixes to that rule, which is what makes a
fix for the finding under point a different thing from a fix for the whole
buffer: a rule can fire twenty times and a person may want one of them
changed."
  (let ((result (heks/sift-run
                 (append (list "lint" "--fix" "--stdin" "--stdout" "--format=null")
                         (when rule (list (concat "--checker=" rule)))
                         (heks/sift--shared-arguments))
                 text)))
    (if-let* ((failure (heks/sift--failure result)))
        (user-error "sift: %s" failure)
      (plist-get result :stdout))))

(defun heks/sift-fix-buffer ()
  "Apply every fix sift has for the buffer.

The whole-buffer fix, which is `sift fix' with no rule named;
`heks/sift-fix-at-point' is the one that fixes a single finding."
  (interactive)
  (unless (heks/sift-applies-p)
    (user-error "sift has nothing to say about a %s buffer" major-mode))
  (let* ((source (buffer-substring-no-properties (point-min) (point-max)))
         (fixed (heks/sift--fix-string source)))
    (if (string= fixed source)
        (message "sift: nothing to fix")
      (heks/sift--replace-buffer fixed "fixed"))))

(defun heks/sift--rule-of (diagnostic)
  "Return the sift rule a Flymake DIAGNOSTIC was made of, or nil.

A diagnostic that came from somewhere else -- the drift report, which
names a tool rather than a rule, or a finding of another backend -- answers
with nil, which is what tells `heks/sift-fix-at-point' that there is
nothing of sift's to fix here."
  (let ((data (and diagnostic (flymake-diagnostic-data diagnostic))))
    (when (listp data) (plist-get data :rule))))

(defun heks/sift--diagnostic-at-point ()
  "Return the sift finding on the line point is in, or nil.

The findings of a line are asked for, rather than the ones that begin
exactly at point: a diagnostic sits on the form a rule is about, and the
cursor is usually beside it rather than on it.  Of those, the one that
carries a rule wins over the one that does not -- the drift report has no
rule to fix -- and the one point is inside wins over its neighbours.
Outside `flymake-mode' there is nothing to ask, and a buffer that was never
checked has no rule here to fix."
  (when (and (fboundp 'flymake-diagnostics) (bound-and-true-p flymake-mode))
    (let* ((diagnostics (ignore-errors
                          (flymake-diagnostics (line-beginning-position)
                                               (line-end-position))))
           (at-point (seq-filter (lambda (diagnostic)
                                   (and (<= (flymake-diagnostic-beg diagnostic)
                                            (point))
                                        (<= (point)
                                            (flymake-diagnostic-end diagnostic))))
                                 diagnostics)))
      (or (seq-find #'heks/sift--rule-of (append at-point diagnostics))
          (car at-point)
          (car diagnostics)))))

(defun heks/sift-fix-at-point ()
  "Apply the fixes of the sift rule reported on the line under point.

This is the code action a marginal note should have: the rule that fired
there, fixed, and no other."
  (interactive)
  (let ((rule (heks/sift--rule-of (heks/sift--diagnostic-at-point))))
    (unless rule
      (user-error "No sift finding at point"))
    (let* ((source (buffer-substring-no-properties (point-min) (point-max)))
           (fixed (heks/sift--fix-string source rule)))
      (if (string= fixed source)
          (message "sift: `%s' has no fix" rule)
        (heks/sift--replace-buffer fixed (format "fixed `%s'" rule))))))

(defun heks/sift--rule-at-point ()
  "Return the name of the sift rule that applies where point is, or nil.

The rule comes out of the Flymake diagnostic under point where there is
one; a line that merely names a code -- a compilation buffer, a message,
a document about sift -- answers with the rule between brackets, so that
`C-c g H' on a line that says `[if-without-else]' explains it too."
  (or (heks/sift--rule-of (heks/sift--diagnostic-at-point))
      (save-excursion
        (let ((line (buffer-substring-no-properties
                     (line-beginning-position) (line-end-position))))
          (when (string-match "\\[\\([a-z][a-z0-9-]+\\)\\]" line)
            (match-string 1 line))))))

(defun heks/sift-rule-names ()
  "Return the names of every rule sift knows, as a list of strings."
  (let ((result (heks/sift-run (list "list-checkers"))))
    (when (memq (plist-get result :status) '(0 1))
      (delq nil
            (mapcar (lambda (line)
                      (when (string-match "\\`\\([a-z0-9-]+\\) +SIFT[0-9]+" line)
                        (match-string 1 line)))
                    (split-string (plist-get result :stdout) "\n" t))))))

(defun heks/sift-explain (rule)
  "Show sift's own page for RULE in a buffer."
  (interactive
   (list (completing-read "sift rule: " (heks/sift-rule-names) nil nil
                          (heks/sift--rule-at-point))))
  (let* ((result (heks/sift-run (list "explain" rule)))
         (buffer (get-buffer-create "*sift explain*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (if (heks/sift--failure result)
                    (or (string-trim (plist-get result :stderr))
                        (format "sift knows no rule called `%s'" rule))
                  (plist-get result :stdout)))
        (goto-char (point-min))
        (special-mode)))
    (display-buffer buffer)))

(defun heks/sift-explain-rule ()
  "Explain the sift rule reported where point is."
  (interactive)
  (let ((rule (heks/sift--rule-at-point)))
    (if rule
        (heks/sift-explain rule)
      (call-interactively #'heks/sift-explain))))

;;
;; ====== Where the three of them are wired in ======
;;

(defun heks/sift--format-before-save ()
  "Format the buffer before saving it, when `heks/sift-format-on-save' says so."
  (when (and heks/sift-format-on-save (heks/sift-formats-p))
    (heks/sift-format-buffer)))

(defun heks/sift-setup-flymake ()
  "Register sift's backends in the current buffer and start Flymake.

The lint backend goes in wherever sift has a dialect, and the drift
backend only where sift is the formatter of the buffer (see
`heks/sift-format-dialects').  Nothing is registered when sift is not
installed: a backend that answered every question with a panic would be
worse than no backend at all, and the checkers of `modules/guile.el' are
what a machine without sift has.

The check runs when Flymake decides to run it, which is the buffer's own
business: a Scheme buffer sets its timing in `modules/guile.el' and checks
on save, since the Guix tools and the Guile compiler are slow; an Emacs
Lisp or Common Lisp buffer keeps Flymake's own, where sift answers in the
few dozen milliseconds it takes a Guile program to start."
  (when (heks/sift-lint-applies-p)
    (add-hook 'flymake-diagnostic-functions #'heks/sift-lint-backend nil t)
    (when (heks/sift-format-applies-p)
      (add-hook 'flymake-diagnostic-functions #'heks/sift-format-backend nil t))
    (add-hook 'before-save-hook #'heks/sift--format-before-save nil t)
    (flymake-mode 1)))

;; The three dialects are the three modes, and the module says what it has to
;; say in each of them.  `scheme-mode' is the one this file does not hook:
;; `modules/guile.el' sets a Scheme buffer up for Guile and calls
;; `heks/sift-setup-flymake' as part of that, since a Scheme buffer has more
;; to set up than its checker.
(add-hook 'emacs-lisp-mode-hook #'heks/sift-setup-flymake)
(add-hook 'lisp-mode-hook #'heks/sift-setup-flymake)

;; `C-c i f' is the one format key of the configuration, and it is a table the
;; buffer answers: this is the entry for the dialects sift formats.  Scheme is
;; left to `modules/guile.el', which owns that buffer's formatter and knows
;; what to do where sift is not installed -- Emacs' own indentation -- and
;; which this entry would otherwise steal the key from.
(defun heks/sift-format-key-p ()
  "Return non-nil when `C-c i f' should format this buffer with sift."
  (and (heks/sift-formats-p)
       (not (derived-mode-p 'scheme-mode 'scheme-ts-mode))))

(add-to-list 'heks/format-dispatch
             (cons #'heks/sift-format-key-p #'heks/sift-format-buffer))

(provide 'heks/sift)

;;; sift.el ends here
