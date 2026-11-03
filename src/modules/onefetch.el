;;; onefetch.el --- Every repository of mine, as onefetch describes it -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; `onefetch' is a program that says what a repository has become: the
;; languages it is written in and how much of each, the people who wrote it,
;; when it started, its last change, its commits, its lines of code, the files
;; that churn, its licence and the URL it came from -- beside a piece of ASCII
;; art for its main language, drawn in that language's own colour.  It
;; describes one directory at a time, from a terminal, and it is the thing one
;; opens to remember what a checkout has turned into.
;;
;; This module asks it about every repository of `heks/onefetch-directories'
;; -- `~/Hacking' by default, which is where the checkouts are -- and puts the
;; answers in one buffer, a block per repository, in the order of their names
;; or of the last change.  The screen is a fleet view: what has been worked on
;; lately, what has gone quiet, which repositories are written in what, and
;; what each one is three hundred commits into.
;;
;; What is in a block is onefetch's own output, character for character,
;; escape codes and all.  That is the whole point of doing it this way: the
;; colours -- the magenta of an Emacs Lisp repository, the chips that are each
;; language's colour, the palette, the sparkline, the art -- are not imitated
;; here, they are the program's own, and `ansi-color' turns its escape codes
;; into faces on the text.  A reimplementation would be a different drawing of
;; the same idea, and it would be wrong the first time onefetch changed its
;; mind about a colour.
;;
;; What that costs is time.  onefetch reads a repository's whole history, so a
;; checkout with a million commits takes seconds where the others take a tenth
;; of one, and asking git which commit each checkout is at is a call per
;; repository.  So nothing of it happens in the window: the screen is drawn at
;; once, a process walks the directories and asks git as it goes -- one
;; process, not one per repository -- and the repositories are described as
;; the answers arrive, `heks/onefetch-parallelism' of them at a time.  What was
;; described in this session is remembered, so opening the screen again is
;; instant, and `g' asks again.
;;
;; The screen is a value -- a list of repositories, each a plist of what is
;; known about it -- and drawing it is a function of that list.  Folding a
;; block, filtering, changing the order and a description arriving are all the
;; same operation: the value changes and the screen is drawn again, which is
;; why there is one place where the buffer and the state can disagree, and it
;; is this one.
;;
;; The keys are the ones the screen is read with: `n' and `p' walk the
;; repositories, `TAB' folds the block point is in, `RET' opens it in Magit,
;; `o' in Dired, `b' in a browser, `s' changes the order, `f' shows only the
;; repositories whose name matches, and `m' is onefetch's own options -- the
;; art, the palette, how many authors, which fields to leave out.

;;; Code:

(require 'ansi-color)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defgroup heks/onefetch nil
  "Every repository of mine, as onefetch describes it."
  :group 'tools
  :prefix "heks/onefetch-")

;;;
;;; ====== The settings ======
;;;

(defcustom heks/onefetch-directories '("~/Hacking")
  "The directories whose repositories the screen shows.

Each one is read one level down, which is where checkouts live: a `.git'
found by walking a whole tree is a submodule's or a cache's.  A directory
that is not there is passed over, so a list of this machine's own places is
still a list on another machine."
  :type '(repeat directory)
  :group 'heks/onefetch)

(defcustom heks/onefetch-executable "onefetch"
  "The program that describes a repository."
  :type 'string
  :group 'heks/onefetch)

(defcustom heks/onefetch-arguments '("--true-color" "always")
  "The arguments every call to `heks/onefetch-executable' is given.

The one thing here that is not onefetch's own default is the colour.  Asked
for `auto', onefetch decides from the terminal it is writing to, and a
process whose output Emacs reads is not a terminal, so the chips would be
the eight palette colours in turn rather than each language's own.  Emacs
can show the true colours, and this asks for them.

Everything else onefetch offers on its command line is here as it is on the
command line -- `--number-of-authors', `--no-art', `--disabled-fields' and
the rest -- and `m' in the screen changes the ones worth changing while the
screen is looked at."
  :type '(repeat string)
  :group 'heks/onefetch)

(defcustom heks/onefetch-order 'name
  "The order the repositories are shown in: `name' or `recent'.

`recent' is by the date of the last commit, newest first, which is what
says what one has been working on; a repository with no commit yet has no
date and comes last.  `s' in the screen changes this."
  :type '(choice (const :tag "By name" name)
                 (const :tag "By last change, newest first" recent))
  :group 'heks/onefetch)

(defcustom heks/onefetch-parallelism 4
  "How many repositories are described at once.

onefetch reads a repository's whole history and counts its lines, so the
cost is real and most of it is one program at a time; four is enough to fill
the screen while it is read, and few enough that a checkout with a million
commits is not competing with itself for every core."
  :type 'integer
  :group 'heks/onefetch)

(defcustom heks/onefetch-buffer-name "*heks/onefetch*"
  "The buffer the screen is shown in."
  :type 'string
  :group 'heks/onefetch)

(defcustom heks/onefetch-ssh-config "~/.ssh/config"
  "The ssh configuration that says which machine a host alias stands for."
  :type 'file
  :group 'heks/onefetch)

(defconst heks/onefetch-fields
  '("project" "description" "head" "pending" "version" "created" "languages"
    "dependencies" "authors" "last-change" "contributors" "url" "commits"
    "churn" "lines-of-code" "size" "license")
  "The fields onefetch knows, as `--disabled-fields' names them.

The list is the one `onefetch --disabled-fields nonsense' prints back, which
is the program's own vocabulary: a field that is not in it is a field
onefetch refuses the whole command over rather than quietly leaving out.")

;;;
;;; ====== What the screen is made of ======
;;;
;;; The screen is a list of repositories -- each a plist of what is known
;;; about it -- and drawing it is a function of that list.  Reading the
;;; directories, describing a repository, folding a block, filtering and
;;; changing the order are all the same operation: the value changes and the
;;; screen is drawn again.  What that buys is that there is one place where the
;;; buffer and the state can disagree, and it is this one.

(defvar-local heks/onefetch--repositories nil
  "The repositories of the screen, in the order it shows them.

A repository is a plist: :name, :directory, :head (the commit it is at),
:time (when that was, in seconds), :status (`pending', `running', `done' or
`failed'), :text (what onefetch said, with its colours, or nil while it is
still being asked) and :folded.")

(defvar-local heks/onefetch--queue nil
  "The directories of the repositories waiting to be asked about.")

(defvar-local heks/onefetch--reader nil
  "The process reading the directories, or nil when none is doing it.")

(defvar-local heks/onefetch--running nil
  "The onefetch processes this buffer has started and not heard back from.")

(defvar-local heks/onefetch--filter nil
  "The regexp a repository's name has to match to be shown, or nil.")

(defvar-local heks/onefetch--blocks nil
  "Where each block of the screen is, as (DIRECTORY START END).

Every drawing makes this list again.  It is what says where point may go
back to when the screen is drawn under it, and where the blocks begin, which
is what walking them is.")

(defun heks/onefetch--repository (directory)
  "Return what this buffer knows about DIRECTORY, or nil."
  (seq-find (lambda (repository) (equal (plist-get repository :directory) directory))
            heks/onefetch--repositories))

(defun heks/onefetch--with (repository properties)
  "Return REPOSITORY, a copy of it, with the plist PROPERTIES set in it."
  (let ((copy (copy-sequence repository))
        (rest properties))
    (while rest
      (setq copy (plist-put copy (car rest) (cadr rest))
            rest (cddr rest)))
    copy))

(defun heks/onefetch--update (directory &rest properties)
  "Set PROPERTIES, a plist, of DIRECTORY's repository."
  (setq heks/onefetch--repositories
        (mapcar (lambda (repository)
                  (if (equal (plist-get repository :directory) directory)
                      (heks/onefetch--with repository properties)
                    repository))
                heks/onefetch--repositories)))

;;;
;;; ====== Which repositories ======
;;;

(defun heks/onefetch--git (directory &rest arguments)
  "Return the output of `git' given ARGUMENTS, run in DIRECTORY, or nil.

The output is what the command wrote and nothing else: a call that fails
-- a repository with no commit in it, a directory that is not one -- is nil
rather than an error, because a screen of fifty-three repositories is not
the place for one of them to stop the rest."
  (with-temp-buffer
    (let ((default-directory (file-name-as-directory (expand-file-name directory))))
      (when (eq 0 (apply #'call-process "git" nil t nil arguments))
        (string-trim (buffer-string))))))

(defun heks/onefetch--head (directory)
  "Return (COMMIT . SECONDS) of DIRECTORY's HEAD, or nil when it has none.

A repository that was created and never committed to has a HEAD that names
a branch that is not there.  It is still a repository, and the screen shows
it without a date rather than not at all."
  (when-let* ((output (heks/onefetch--git directory "log" "-1" "--format=%H %ct")))
    (when (string-match "\\`\\([0-9a-f]+\\) \\([0-9]+\\)\\'" output)
      (cons (match-string 1 output) (string-to-number (match-string 2 output))))))

(defun heks/onefetch--roots ()
  "Return the directories of `heks/onefetch-directories' that are there.

A directory that is not there is passed over rather than refused, so that a
list naming this machine's own places is still a list on another machine."
  (seq-filter #'file-directory-p (mapcar #'expand-file-name heks/onefetch-directories)))

(defconst heks/onefetch--read-script
  (concat "for root in \"$@\"; do\n"
          "  for directory in \"$root\"/*/; do\n"
          "    [ -e \"${directory}.git\" ] || continue\n"
          "    printf '%s\\000' \"$directory\"\n"
          "    git -C \"$directory\" log -1 --format='%H %ct' 2>/dev/null | tr -d '\\n'\n"
          "    printf '\\000'\n"
          "  done\n"
          "done\n")
  "The shell that reads the repositories, one level under each directory.

It walks the directories it is given, and for every directory with a `.git'
in it -- the directory of a checkout, or the file a worktree keeps -- it
prints two fields ended by a NUL: the directory, and the commit it is at
with the date of that commit, which is empty for a repository that has no
commit yet.

A NUL ends a field because a directory name may hold anything else,
spaces and newlines included, and a screen of one's own repositories is not
the place to discover that a name had a space in it.  It is one process and
not one per repository: this is what the screen would otherwise be waiting
for.")

(defun heks/onefetch--split-records (text)
  "Return the records in TEXT as (DIRECTORY . REVISION) pairs, and the rest.

TEXT is what the reading has said so far, which is not a whole number of
records: a field may have arrived without the one it belongs with, and the
last one is the beginning of the next record.  That beginning comes back
beside the records, so that it is read again with what comes after it rather
than on its own -- the answer is a pipe, and a pipe says as much as it has
when it has it."
  (let* ((fields (split-string text "\0" nil))
         (rest (car (last fields)))
         (complete (butlast fields))
         (records nil))
    ;; A record is two fields, a directory and a revision.  A field whose
    ;; partner has not arrived is the beginning of a record, not one.
    (when (= 1 (% (length complete) 2))
      (setq rest (concat (car (last complete)) "\0" rest)
            complete (butlast complete)))
    (while (cdr complete)
      (push (cons (pop complete) (pop complete)) records))
    (cons (nreverse records) rest)))

(defun heks/onefetch--read ()
  "Start reading the repositories of `heks/onefetch-directories'.

The reading is a process of its own, so that nothing is waited for: the
screen is drawn at once, and each repository is added to it -- and asked
about -- as it is found.  That is also what a refresh is: what the screen
already says of a repository is kept until the new answer arrives."
  (heks/onefetch--stop-reading)
  (unless (executable-find "git")
    (user-error "git is not installed, so there are no repositories to read"))
  (let* ((buffer (current-buffer))
         (pending "")
         (seen nil)
         (process (make-process
                   :name "heks/onefetch read"
                   :command (append (list "sh" "-c" heks/onefetch--read-script
                                          "heks/onefetch")
                                    (heks/onefetch--roots))
                   :connection-type 'pipe
                   :noquery t
                   :coding 'utf-8-unix
                   :filter (lambda (_process text)
                             (let* ((answer (heks/onefetch--split-records
                                             (concat pending text)))
                                    (records (car answer)))
                               (setq pending (cdr answer))
                               (when (and records (buffer-live-p buffer))
                                 (with-current-buffer buffer
                                   (dolist (record records)
                                     (push (car record) seen)
                                     (heks/onefetch--found (car record) (cdr record))
                                     (heks/onefetch--pump))
                                   (when (get-buffer-window buffer)
                                     (heks/onefetch--render))))))
                   :sentinel (lambda (process _event)
                               (when (and (memq (process-status process) '(exit signal))
                                          (buffer-live-p buffer))
                                 (with-current-buffer buffer
                                   (setq heks/onefetch--reader nil)
                                   ;; A repository that is not there any more
                                   ;; is not on the screen any more -- unless
                                   ;; the reading was given up on, in which case
                                   ;; what it did not reach is still there.
                                   (unless (process-get process 'heks/onefetch-cancelled)
                                     (setq heks/onefetch--repositories
                                           (seq-filter
                                            (lambda (repository)
                                              (member (plist-get repository :directory)
                                                      seen))
                                            heks/onefetch--repositories)))
                                   (heks/onefetch--render)))))))
    (setq heks/onefetch--reader process)
    process))

(defun heks/onefetch--stop-reading ()
  "Stop the process that is reading the repositories, when there is one."
  (let ((process heks/onefetch--reader))
    (when (process-live-p process)
      (process-put process 'heks/onefetch-cancelled t)
      (delete-process process)))
  (setq heks/onefetch--reader nil))

(defun heks/onefetch--found (directory revision)
  "Add DIRECTORY, found at REVISION, to the screen and ask onefetch about it.

REVISION is what git said about it -- the commit and when that was, or
nothing at all for a repository that has no commit.  What the screen already
said of that repository is kept: a refresh should not make the screen go
blank, and a block a reader folded should stay folded."
  (let* ((directory (file-name-as-directory directory))
         (fields (split-string revision " " t))
         (old (heks/onefetch--repository directory))
         (repository
          (heks/onefetch--with
           (list :name (file-name-nondirectory (directory-file-name directory))
                 :directory directory
                 :head (car fields)
                 :time (and (cadr fields) (string-to-number (cadr fields))))
           (if old
               (list :text (plist-get old :text)
                     :message (plist-get old :message)
                     :folded (plist-get old :folded)
                     :status 'pending)
             (list :status 'pending)))))
    (setq heks/onefetch--repositories
          (heks/onefetch--in-order
           (append (seq-remove (lambda (one) (equal (plist-get one :directory) directory))
                               heks/onefetch--repositories)
                   (list repository))))
    (heks/onefetch--ask repository)))

(defun heks/onefetch--in-order (repositories)
  "Return REPOSITORIES in the order `heks/onefetch-order' asks for."
  (if (eq heks/onefetch-order 'recent)
      (sort repositories
            (lambda (one two)
              (let ((one-time (plist-get one :time))
                    (two-time (plist-get two :time)))
                (cond ((and one-time two-time (/= one-time two-time))
                       (> one-time two-time))
                      ((and one-time (not two-time)) t)
                      ((and two-time (not one-time)) nil)
                      (t (string< (plist-get one :name) (plist-get two :name)))))))
    (sort repositories
          (lambda (one two) (string< (plist-get one :name) (plist-get two :name))))))

;;;
;;; ====== Asking onefetch ======
;;;

(defun heks/onefetch--apply-face (beg end face)
  "Put FACE on the text between BEG and END.

`ansi-color' asks a function to do this, and the default one puts an
overlay on the text.  The screen keeps the colours as properties of the
characters instead, so that they are the buffer's own text and not a layer
over it that the next redrawing of the screen would have to put back."
  (put-text-property beg end 'face face))

(defun heks/onefetch--described (output)
  "Return OUTPUT, onefetch's own, with its escape codes turned into faces.

Every sequence that is not a colour -- the one that turns the terminal's
line wrapping off around the drawing -- is deleted, so what comes back is
exactly the characters onefetch printed, in the colours it printed them."
  (with-temp-buffer
    (insert output)
    (let ((ansi-color-apply-face-function #'heks/onefetch--apply-face))
      (ansi-color-apply-on-region (point-min) (point-max)))
    (buffer-string)))

(defun heks/onefetch--reason (status message output)
  "Return why a description failed, in one line, from STATUS, MESSAGE and OUTPUT.

onefetch says what went wrong on standard error, in the shape a Rust program
reports an error in: the error, a blank line, `Caused by:', and the reason
indented under it.  The reason is what the screen shows, because it is the
only line of that which says something about the repository."
  (let ((lines (seq-filter (lambda (line) (not (string-empty-p (string-trim line))))
                           (split-string (concat message "\n" output) "\n"))))
    (cond
     (lines (string-trim (car (last lines))))
     ((zerop status) "onefetch said nothing")
     (t (format "onefetch exited with %s" status)))))

(defvar heks/onefetch--cache (make-hash-table :test #'equal)
  "What onefetch has said, by repository, commit and arguments.

A description is worth keeping for the session it was got in, and for no
longer: the same commit described with the same arguments would be the same
words, and a file on disk would have to say when it stopped being true -- a
working tree that was edited, a branch that was fetched.")

(defun heks/onefetch--cache-key (repository)
  "Return what a description of REPOSITORY depends on, as a key."
  (list (plist-get repository :directory)
        (plist-get repository :head)
        heks/onefetch-arguments))

(defun heks/onefetch--ask (repository)
  "Describe REPOSITORY from `heks/onefetch--cache', or queue it to be asked.

Return non-nil when the answer was already there and has been put in place,
nil when the repository is waiting its turn: what was described in this
session is on the screen at once, and the rest arrives."
  (if-let* ((cached (gethash (heks/onefetch--cache-key repository)
                             heks/onefetch--cache)))
      (progn
        (heks/onefetch--update (plist-get repository :directory)
                               :text cached :status 'done :message nil)
        t)
    (let ((directory (plist-get repository :directory)))
      (when (and (not (eq (plist-get repository :status) 'running))
                 (not (member directory heks/onefetch--queue)))
        (setq heks/onefetch--queue
              (append heks/onefetch--queue (list directory))))
      nil)))

(defun heks/onefetch--describe (&optional only)
  "Ask onefetch about the repositories this buffer cannot describe.

ONLY, when it is given, is a list of directories to limit it to.  A
description that is in `heks/onefetch--cache' is not asked for again: it is
put in place, and the repository shows it at once."
  (unless (executable-find heks/onefetch-executable)
    (user-error "%s is not installed, so there is nothing to ask it"
                heks/onefetch-executable))
  (dolist (repository heks/onefetch--repositories)
    (when (or (null only) (member (plist-get repository :directory) only))
      (heks/onefetch--ask repository)))
  (heks/onefetch--pump))

(defun heks/onefetch--pump ()
  "Start as many repositories as `heks/onefetch-parallelism' allows."
  (while (and heks/onefetch--queue
              (< (length heks/onefetch--running) heks/onefetch-parallelism))
    (heks/onefetch--start (pop heks/onefetch--queue))))

(defun heks/onefetch--start (directory)
  "Ask onefetch about DIRECTORY, in the background."
  (let* ((buffer (current-buffer))
         (output (generate-new-buffer " *heks/onefetch output*"))
         (errors (generate-new-buffer " *heks/onefetch errors*"))
         (process (make-process
                   :name (format "onefetch %s"
                                 (file-name-nondirectory (directory-file-name directory)))
                   :buffer output
                   :stderr errors
                   :command (append (list heks/onefetch-executable)
                                    heks/onefetch-arguments
                                    (list directory))
                   :connection-type 'pipe
                   :noquery t
                   :coding 'utf-8-unix
                   :sentinel (lambda (process _event)
                               (when (memq (process-status process) '(exit signal))
                                 (heks/onefetch--finish process buffer output
                                                        errors))))))
    (process-put process 'heks/onefetch-directory directory)
    (push process heks/onefetch--running)
    (heks/onefetch--update directory :status 'running)))

(defun heks/onefetch--finish (process buffer output errors)
  "Take what PROCESS, onefetch, said, and put it in BUFFER's screen.

OUTPUT is the buffer its output was collected in and ERRORS the one its
standard error was, and both are killed here: they have said what they had
to say, and the screen is what keeps it."
  (let ((status (process-exit-status process))
        (text (with-current-buffer output (buffer-string)))
        (message (string-trim (with-current-buffer errors (buffer-string))))
        (directory (process-get process 'heks/onefetch-directory)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (setq heks/onefetch--running (delq process heks/onefetch--running))
        ;; A process the screen has given up on says nothing: it was killed
        ;; because its answer would have been about arguments that are no
        ;; longer the ones being asked with.
        (unless (process-get process 'heks/onefetch-cancelled)
          (let ((described (and (zerop status)
                                (not (string-empty-p (string-trim text)))
                                (heks/onefetch--described text))))
            (if described
                (progn
                  (when-let* ((repository (heks/onefetch--repository directory)))
                    (puthash (heks/onefetch--cache-key repository)
                             described heks/onefetch--cache))
                  (heks/onefetch--update directory :text described
                                         :status 'done :message nil))
              (heks/onefetch--update directory :status 'failed
                                     :message (heks/onefetch--reason
                                               status message text))))
          (heks/onefetch--pump)
          (when (get-buffer-window buffer)
            (heks/onefetch--render)))))
    (kill-buffer output)
    (kill-buffer errors)))

(defun heks/onefetch--cancel ()
  "Stop the processes this screen started, and what is waiting for one.

A repository whose answer was being fetched is left waiting rather than
answering: what it was being asked has changed, and it will be asked again."
  (heks/onefetch--stop-reading)
  (dolist (process heks/onefetch--running)
    (when-let* ((directory (process-get process 'heks/onefetch-directory)))
      (heks/onefetch--update directory :status 'pending))
    (when (process-live-p process)
      (process-put process 'heks/onefetch-cancelled t)
      (delete-process process)))
  (setq heks/onefetch--running nil
        heks/onefetch--queue nil))

;;;
;;; ====== Drawing it ======
;;;

(defun heks/onefetch--ago (time &optional now)
  "Return TIME, in seconds since the epoch, as onefetch says a date.

NOW is the time to measure from, and is the present when it is not given.
What onefetch says comes from the `time-humanize' crate, and this says the
same things in the same words: `now' for what has just happened, a count and
a unit for the rest, an article where the count is one, and `in' in front of
a date that has not come yet -- `6 hours ago', `a year ago', `in a day'."
  (let* ((delta (- (or now (float-time)) time))
         (past (> delta 0))
         (seconds (abs delta))
         (minutes (round (/ seconds 60)))
         (hours (round (/ seconds 3600)))
         (days (round (/ seconds 86400)))
         (months (max 2 (round (/ seconds (* 30.44 86400)))))
         (years (max 2 (round (/ seconds (* 365.25 86400)))))
         (phrase (cond ((< seconds 45) "now")
                       ((< seconds 90) "a minute")
                       ((< seconds (* 45 60)) (format "%d minutes" minutes))
                       ((< seconds (* 90 60)) "an hour")
                       ((< seconds (* 24 3600)) (format "%d hours" hours))
                       ((< seconds (* 42 3600)) "a day")
                       ((< seconds (* 30 86400)) (format "%d days" days))
                       ((< seconds (* 45 86400)) "a month")
                       ((< seconds (* 365 86400)) (format "%d months" months))
                       ((< seconds (* 545 86400)) "a year")
                       (t (format "%d years" years)))))
    (cond ((equal phrase "now") phrase)
          (past (concat phrase " ago"))
          (t (concat "in " phrase)))))

(defun heks/onefetch--shown ()
  "Return the repositories the screen shows, in the order it shows them."
  (if (or (null heks/onefetch--filter) (string-empty-p heks/onefetch--filter))
      heks/onefetch--repositories
    (seq-filter (lambda (repository)
                  (string-match-p heks/onefetch--filter (plist-get repository :name)))
                heks/onefetch--repositories)))

(defun heks/onefetch--heading (repository)
  "Return the heading line of REPOSITORY, as text with its faces.

It says the repository's name, when it last changed, and -- while onefetch
has not answered yet -- an ellipsis, which is this module's own way of
saying that the block under it is still being written."
  (let ((status (plist-get repository :status))
        (time (plist-get repository :time)))
    (concat (propertize (if (plist-get repository :folded) "▸" "▾") 'face 'bold)
            " "
            (propertize (plist-get repository :name) 'face 'bold)
            (if time
                (concat (propertize "  ·  " 'face 'shadow)
                        (propertize (heks/onefetch--ago time) 'face 'shadow))
              "")
            (if (memq status '(pending running))
                (concat (propertize "  ·  " 'face 'shadow)
                        (propertize "…" 'face 'shadow))
              ""))))

(defun heks/onefetch--key-hints ()
  "Return the keys the screen is read with, as a list of what they do."
  (append '("g again" "r this one" "RET Magit" "o dired" "b browser"
            "TAB fold" "s order")
          (if heks/onefetch--filter '("F everything") '("f filter"))
          (when (fboundp 'heks/onefetch-menu) '("m onefetch's options"))))

(defun heks/onefetch--render-header ()
  "Insert what the screen is, how far it has got, and the keys that read it."
  (let* ((total (length heks/onefetch--repositories))
         (shown (length (heks/onefetch--shown)))
         ;; A repository onefetch refused to describe has been described:
         ;; what it has to say about it is why it will not.
         (described (seq-count (lambda (repository)
                                 (memq (plist-get repository :status) '(done failed)))
                               heks/onefetch--repositories)))
    (insert (propertize
             (format "onefetch · %d %s%s"
                     total
                     (if (= total 1) "repository" "repositories")
                     (if heks/onefetch-directories
                         (format " in %s"
                                 (mapconcat #'abbreviate-file-name
                                            heks/onefetch-directories ", "))
                       ""))
             'face 'bold)
            "\n")
    (insert (propertize
             (string-join
              (delq nil
                    (list (if (eq heks/onefetch-order 'recent)
                              "the last change first" "by name")
                          (cond ((process-live-p heks/onefetch--reader)
                                 "reading the repositories")
                                ((zerop total) "nothing to describe")
                                ((= described total) (format "all %d described" total))
                                (t (format "%d of %d described" described total)))
                          (and heks/onefetch--filter
                               (format "only “%s”" heks/onefetch--filter))
                          (and (/= shown total) (format "%d shown" shown))))
              " · ")
             'face 'shadow)
            "\n")
    (insert (propertize (string-join (heks/onefetch--key-hints) " · ") 'face 'shadow)
            "\n"
            ;; As wide as the widest line onefetch prints for a repository with
            ;; three languages in it, which is what the blocks are.
            (propertize (make-string 78 ?─) 'face 'shadow)
            "\n")))

(defun heks/onefetch--render-repository (repository)
  "Insert the block of REPOSITORY, heading and all.

A repository onefetch refused is its heading and the reason, and not what
onefetch used to say about it: the refusal is the newer thing."
  (let ((start (point))
        (text (plist-get repository :text))
        (status (plist-get repository :status)))
    (insert (heks/onefetch--heading repository) "\n")
    (unless (plist-get repository :folded)
      (cond
       ((eq status 'failed)
        (insert (propertize (format "  %s\n" (plist-get repository :message))
                            'face 'error)))
       (text
        (insert text)
        (unless (bolp) (insert "\n")))))
    (push (list (plist-get repository :directory) start (point)) heks/onefetch--blocks)
    ;; The whole block carries the repository it describes, so that a key
    ;; pressed anywhere in it -- or on the line under it -- knows which one.
    (put-text-property start (point) 'heks/onefetch-repository repository)
    (insert "\n")))

(defun heks/onefetch--render ()
  "Draw the screen in this buffer, and put point back where it was."
  (let ((inhibit-read-only t)
        (position (heks/onefetch--position)))
    (erase-buffer)
    (setq heks/onefetch--blocks nil)
    (heks/onefetch--render-header)
    (let ((shown (heks/onefetch--shown)))
      (cond
       (shown
        (dolist (repository shown)
          (heks/onefetch--render-repository repository)))
       ;; Nothing found yet is not nothing there: while the directories are
       ;; being read the screen is empty because the answer is coming.
       ((and (null heks/onefetch--repositories)
             (not (process-live-p heks/onefetch--reader)))
        (insert (propertize (format "  nothing under %s is a repository\n"
                                    (mapconcat #'abbreviate-file-name
                                               heks/onefetch-directories ", "))
                            'face 'shadow)))
       ((null heks/onefetch--repositories) nil)
       (t
        (insert (propertize (format "  no repository matches “%s”\n"
                                    heks/onefetch--filter)
                            'face 'shadow)))))
    (if position
        (heks/onefetch--restore position)
      (goto-char (point-min)))))

(defun heks/onefetch--position ()
  "Return where point is, as (DIRECTORY . OFFSET), or nil when it is nowhere."
  (when-let* ((repository (heks/onefetch--repository-at-point))
              (block (seq-find (lambda (block)
                                 (equal (nth 0 block) (plist-get repository :directory)))
                               heks/onefetch--blocks)))
    (cons (nth 0 block) (- (point) (nth 1 block)))))

(defun heks/onefetch--restore (position)
  "Put point back at POSITION, a (DIRECTORY . OFFSET), when it is still there.

A block that was folded while point was in it is shorter than it was, and
point ends at its heading rather than past it."
  (when position
    (when-let* ((block (seq-find (lambda (block) (equal (nth 0 block) (car position)))
                                 heks/onefetch--blocks)))
      (goto-char (min (+ (nth 1 block) (cdr position))
                      (max (nth 1 block) (1- (nth 2 block))))))))

;;;
;;; ====== At point ======
;;;

(defun heks/onefetch--repository-at-point ()
  "Return the repository whose block point is in, or nil.

Point is in a block when it is on its text; a point on the blank line under
a block is in the block above it, which is what the keys that act on \"this
repository\" read."
  (or (get-text-property (point) 'heks/onefetch-repository)
      (and (> (point) (point-min))
           (get-text-property (1- (point)) 'heks/onefetch-repository))))

(defun heks/onefetch--directory-at-point ()
  "Return the directory of the repository point is in, or say there is none."
  (if-let* ((repository (heks/onefetch--repository-at-point)))
      (plist-get repository :directory)
    (user-error "Point is not in a repository")))

(defun heks/onefetch--walk (step)
  "Move to the heading of the next repository, or of the previous one with STEP -1."
  (let* ((starts (sort (mapcar #'cadr heks/onefetch--blocks) #'<))
         (target (if (> step 0)
                     (seq-find (lambda (start) (> start (line-end-position))) starts)
                   (car (last (seq-take-while (lambda (start)
                                                (< start (line-beginning-position)))
                                              starts))))))
    (if target
        (goto-char target)
      (message "That is the %s repository" (if (> step 0) "last" "first")))))

;;;
;;; ====== The screen ======
;;;

(defvar-keymap heks/onefetch-mode-map
  :doc "The keys the onefetch screen is read with."
  :parent special-mode-map
  "n" #'heks/onefetch-next
  "p" #'heks/onefetch-previous
  "TAB" #'heks/onefetch-toggle
  "<backtab>" #'heks/onefetch-toggle-all
  "RET" #'heks/onefetch-magit
  "o" #'heks/onefetch-dired
  "b" #'heks/onefetch-browse
  "r" #'heks/onefetch-refresh-one
  "s" #'heks/onefetch-sort
  "f" #'heks/onefetch-filter
  "F" #'heks/onefetch-clear-filter
  "?" #'describe-mode)

(define-derived-mode heks/onefetch-mode special-mode "onefetch"
  "The screen of every repository, as onefetch describes it.

The blocks are in the order `heks/onefetch-order' asks for, and the text in
them is onefetch's own: its escape codes are the colours, so a block is what
the program prints, character for character.  Lines are not wrapped, because
the drawing is not wrapped either.

`g' asks about every repository again, `n' and `p' walk them, `TAB' folds
the block point is in, and `m' is the options onefetch is asked with."
  (setq-local truncate-lines t
              revert-buffer-function #'heks/onefetch--revert
              heks/onefetch--repositories nil
              heks/onefetch--queue nil
              heks/onefetch--reader nil
              heks/onefetch--running nil
              heks/onefetch--blocks nil
              heks/onefetch--filter nil)
  ;; Closing the screen stops the questions it was asking: a checkout with a
  ;; million commits takes seconds, and nobody wants that spent on a buffer
  ;; that is gone.
  (add-hook 'kill-buffer-hook #'heks/onefetch--cancel nil t))

(defun heks/onefetch--revert (&rest _)
  "Ask onefetch about every repository again, and draw the screen again."
  (heks/onefetch-refresh))

;;;
;;; ====== Reading it ======
;;;

(defun heks/onefetch-next ()
  "Move to the next repository of the screen."
  (interactive)
  (heks/onefetch--walk 1))

(defun heks/onefetch-previous ()
  "Move to the previous repository of the screen."
  (interactive)
  (heks/onefetch--walk -1))

(defun heks/onefetch-toggle ()
  "Fold, or open, the block of the repository point is in."
  (interactive)
  (let* ((repository (heks/onefetch--repository-at-point))
         (directory (plist-get repository :directory)))
    (unless directory (user-error "Point is not in a repository"))
    (heks/onefetch--update directory
                           :folded (not (plist-get (heks/onefetch--repository directory)
                                                   :folded)))
    (heks/onefetch--render)))

(defun heks/onefetch-toggle-all ()
  "Fold every block, or open every one, whichever there is more of."
  (interactive)
  (let ((fold (seq-some (lambda (repository) (not (plist-get repository :folded)))
                        (heks/onefetch--shown))))
    (dolist (repository (heks/onefetch--shown))
      (heks/onefetch--update (plist-get repository :directory) :folded fold))
    (heks/onefetch--render)))

(defun heks/onefetch-sort ()
  "Show the repositories by name, or by the last change, one after the other."
  (interactive)
  (setq heks/onefetch-order (if (eq heks/onefetch-order 'recent) 'name 'recent))
  (setq heks/onefetch--repositories
        (heks/onefetch--in-order heks/onefetch--repositories))
  (heks/onefetch--render)
  (message "The repositories, %s"
           (if (eq heks/onefetch-order 'recent) "the last change first" "by name")))

(defun heks/onefetch-filter (pattern)
  "Show only the repositories whose name matches PATTERN.

PATTERN is a regexp, and an empty one shows every repository, which is what
`F' does as well."
  (interactive (list (read-regexp "Only the repositories matching"
                                  heks/onefetch--filter)))
  (setq heks/onefetch--filter (unless (string-empty-p pattern) pattern))
  (heks/onefetch--render)
  (message "%s" (if heks/onefetch--filter
                    (format "Only the repositories matching %s" heks/onefetch--filter)
                  "Every repository")))

(defun heks/onefetch-clear-filter ()
  "Show every repository again."
  (interactive)
  (setq heks/onefetch--filter nil)
  (heks/onefetch--render))

(defun heks/onefetch-magit ()
  "Show the Magit status of the repository point is in."
  (interactive)
  (magit-status (heks/onefetch--directory-at-point)))

(defun heks/onefetch-dired ()
  "Open the directory of the repository point is in, in Dired."
  (interactive)
  (dired-other-window (heks/onefetch--directory-at-point)))

(defun heks/onefetch-browse ()
  "Open the page of the repository point is in, in the browser."
  (interactive)
  (let ((directory (heks/onefetch--directory-at-point)))
    (if-let* ((url (heks/onefetch-remote-url directory)))
        (browse-url (heks/onefetch-web-url url))
      (user-error "%s has no remote to open" (abbreviate-file-name directory)))))

;;;
;;; ====== Where a repository came from ======
;;;

(defun heks/onefetch-remote-url (directory)
  "Return the URL of DIRECTORY's `origin', or of its first remote, or nil."
  (or (heks/onefetch--git directory "remote" "get-url" "origin")
      (when-let* ((remotes (heks/onefetch--git directory "remote"))
                  (first (car (split-string remotes "\n" t))))
        (heks/onefetch--git directory "remote" "get-url" first))))

(defun heks/onefetch--ssh-hostname (alias)
  "Return the machine ssh's ALIAS stands for, or nil when it is not an alias.

`~/.ssh/config' is a list of `Host NAME' blocks, each with its own settings,
and a `HostName' in one of them is the machine that block's names are for.
The configuration on this machine reaches GitHub as `Host personal.github.com'
with a `HostName github.com' under it, because the key that is registered
there is GitHub's -- so the alias is what a remote says and the host name is
what the page is at."
  (let ((config (expand-file-name heks/onefetch-ssh-config))
        (current nil)
        (hostname nil))
    (when (file-readable-p config)
      (with-temp-buffer
        (insert-file-contents config)
        (goto-char (point-min))
        (while (and (not hostname) (not (eobp)))
          (cond ((looking-at "^[ \t]*[Hh]ost[ \t]+\\([^ \t\r\n]+\\)")
                 (setq current (unless (equal (match-string 1) "*")
                                 (match-string 1))))
                ((and (equal current alias)
                      (looking-at "^[ \t]*[Hh]ost[Nn]ame[ \t]+\\([^ \t\r\n]+\\)"))
                 (setq hostname (match-string 1))))
          (forward-line 1))))
    hostname))

(defun heks/onefetch-web-url (url)
  "Return URL, the remote a repository has, as the page a browser opens.

A remote is written three ways -- `git@github.com:owner/repo.git',
`ssh://git@codeberg.org/owner/repo.git' and
`https://gitlab.com/owner/repo.git' -- and all of them name a page whose
address is the host and the path: without the protocol the repository was
cloned with, and without the `.git' on the end.  The host is the one the ssh
configuration says an alias stands for, because an alias is a name only ssh
knows.  Something that is not a remote at all -- a path on this machine --
comes back as it came."
  (let ((trimmed (string-trim url)))
    (if (string-match
         "\\`\\(?:[[:alpha:]][[:alnum:]+.-]*://\\)?\\(?:[^@/]+@\\)?\\([^:/]+\\)[:/]\\([^[:space:]]+\\)\\'"
         trimmed)
        (let ((host (match-string 1 trimmed))
              (path (match-string 2 trimmed)))
          (format "https://%s/%s"
                  (or (heks/onefetch--ssh-hostname host) host)
                  (string-remove-suffix ".git" (string-remove-suffix "/" path))))
      trimmed)))

;;;
;;; ====== Asking again ======
;;;

(defun heks/onefetch-refresh ()
  "Ask onefetch about every repository again.

What the screen already says is kept until the new answer arrives, so that
refreshing it does not empty it: a block a reader is in the middle of is
still there, saying the old thing, while it says it again."
  (interactive)
  (heks/onefetch--cancel)
  (clrhash heks/onefetch--cache)
  (heks/onefetch--read)
  (heks/onefetch--render))

(defun heks/onefetch-refresh-one ()
  "Ask onefetch about the repository point is in, again."
  (interactive)
  (let* ((repository (heks/onefetch--repository-at-point))
         (directory (plist-get repository :directory)))
    (unless directory (user-error "Point is not in a repository"))
    (remhash (heks/onefetch--cache-key repository) heks/onefetch--cache)
    (heks/onefetch--describe (list directory))
    (heks/onefetch--render)))

;;;
;;; ====== onefetch's own options ======
;;;
;; The flags are what makes onefetch say one thing rather than another, and
;; the ones worth changing while the screen is looked at are here.  Every one
;; of them changes `heks/onefetch-arguments' and asks again, because the
;; arguments are part of what a description is: the same commit described with
;; the art left out is a different description.

(defun heks/onefetch--redescribe ()
  "Ask onefetch about every repository, with the arguments as they are now."
  (when (derived-mode-p 'heks/onefetch-mode)
    (heks/onefetch--cancel)
    (heks/onefetch--describe)
    (heks/onefetch--render)))

(defun heks/onefetch--option-values (option)
  "Return the values `heks/onefetch-arguments' gives OPTION, which takes many.

A value is everything after the option until the next one: that is how
onefetch takes `--disabled-fields a b' from a command line, and what it
would take here."
  (let ((arguments (cdr (member option heks/onefetch-arguments)))
        (values nil))
    (while (and arguments (not (string-prefix-p "--" (car arguments))))
      (push (pop arguments) values))
    (nreverse values)))

(defun heks/onefetch--set-option (option values)
  "Give OPTION the VALUES in `heks/onefetch-arguments', replacing what it had.

VALUES that are nil take the option out altogether, which is what leaves it
to onefetch's own default."
  (let ((kept nil)
        (rest heks/onefetch-arguments))
    (while rest
      (if (equal (car rest) option)
          (progn
            (pop rest)
            (while (and rest (not (string-prefix-p "--" (car rest))))
              (pop rest)))
        (push (pop rest) kept)))
    (setq heks/onefetch-arguments
          (append (nreverse kept) (when values (cons option values))))))

(defun heks/onefetch-toggle-flag (flag)
  "Turn FLAG, one of onefetch's own, on or off, and describe the screen again.

The flag is what the message names, because half of onefetch's flags are
`--no-'-something, and the readable version of one is the menu's own: it
says what leaving the thing out means rather than what the switch is
called."
  (let ((was (member flag heks/onefetch-arguments)))
    (if was
        (setq heks/onefetch-arguments (delete flag heks/onefetch-arguments))
      (setq heks/onefetch-arguments (append heks/onefetch-arguments (list flag))))
    (heks/onefetch--redescribe)
    (message "onefetch %s %s" flag (if was "off" "on"))))

(defun heks/onefetch-set-count (option prompt)
  "Set OPTION, one of onefetch's counts, from a number asked at PROMPT.

A number of zero or less takes the option out, which leaves the count to
onefetch's own default rather than asking for none of a thing."
  (let* ((current (car (heks/onefetch--option-values option)))
         (number (read-number (concat prompt ": ")
                              (and current (string-to-number current)))))
    (heks/onefetch--set-option option (and (> number 0) (list (number-to-string number))))
    (heks/onefetch--redescribe)
    (message "%s: %s" prompt (if (> number 0) number "onefetch's own"))))

(defun heks/onefetch-set-authors ()
  "How many authors onefetch shows for a repository."
  (interactive)
  (heks/onefetch-set-count "--number-of-authors" "Authors to show"))

(defun heks/onefetch-set-languages ()
  "How many languages onefetch shows for a repository."
  (interactive)
  (heks/onefetch-set-count "--number-of-languages" "Languages to show"))

(defun heks/onefetch-set-churns ()
  "How many files onefetch shows in the churn of a repository."
  (interactive)
  (heks/onefetch-set-count "--number-of-file-churns" "File churns to show"))

(defun heks/onefetch-set-fields ()
  "Choose the fields onefetch shows, from the fields it knows."
  (interactive)
  (let* ((disabled (heks/onefetch--option-values "--disabled-fields"))
         (shown (seq-difference heks/onefetch-fields disabled))
         (chosen (completing-read-multiple "The fields to show: "
                                           heks/onefetch-fields nil t
                                           (mapconcat #'identity shown ","))))
    (heks/onefetch--set-option "--disabled-fields"
                               (seq-difference heks/onefetch-fields chosen))
    (heks/onefetch--redescribe)
    (message "The fields shown: %s" (if chosen (string-join chosen ", ") "none"))))

(defmacro heks/onefetch--def-toggle (name flag description)
  "Define the command NAME, which turns FLAG, one of onefetch's, on and off.

DESCRIPTION is what the flag is about, which is what the command's own
docstring calls it -- `the art' rather than `--no-art', which is a flag that
turns a thing off and is read better the other way round."
  `(defun ,name ()
     ,(format "Turn %s on or off, and describe the repositories again." description)
     (interactive)
     (heks/onefetch-toggle-flag ,flag)))

(heks/onefetch--def-toggle heks/onefetch-toggle-art
  "--no-art" "the art")
(heks/onefetch--def-toggle heks/onefetch-toggle-palette
  "--no-color-palette" "the palette")
(heks/onefetch--def-toggle heks/onefetch-toggle-title
  "--no-title" "the title above each block")
(heks/onefetch--def-toggle heks/onefetch-toggle-bold
  "--no-bold" "bold")
(heks/onefetch--def-toggle heks/onefetch-toggle-times
  "--iso-time" "the dates as ISO 8601")
(heks/onefetch--def-toggle heks/onefetch-toggle-bots
  "--no-bots" "commits by bots, left out")
(heks/onefetch--def-toggle heks/onefetch-toggle-merges
  "--no-merges" "merge commits, left out")
(heks/onefetch--def-toggle heks/onefetch-toggle-email
  "--email" "the authors' addresses")
(heks/onefetch--def-toggle heks/onefetch-toggle-hidden
  "--include-hidden" "hidden files, counted")

(use-package transient
  :ensure nil
  :config
  ;; Onefetch's own options, in a menu, because a flag is a thing to try
  ;; rather than a setting to write down and reload the configuration for.
  (keymap-set heks/onefetch-mode-map "m" #'heks/onefetch-menu)

  (transient-define-prefix heks/onefetch-menu ()
    "onefetch: what the screen asks for, and what it shows."
    [["the screen"
      ("g" "ask about every repository again" heks/onefetch-refresh)
      ("r" "ask about this one again" heks/onefetch-refresh-one)
      ("s" "the order of the repositories" heks/onefetch-sort)
      ("f" "only the repositories whose name matches" heks/onefetch-filter)
      ("F" "every repository again" heks/onefetch-clear-filter)]
     ["what is drawn"
      ("a" "the art, on and off" heks/onefetch-toggle-art :transient t)
      ("p" "the palette, on and off" heks/onefetch-toggle-palette :transient t)
      ("t" "the title, on and off" heks/onefetch-toggle-title :transient t)
      ("b" "bold, on and off" heks/onefetch-toggle-bold :transient t)
      ("i" "the dates as ISO 8601, on and off" heks/onefetch-toggle-times :transient t)
      ("B" "commits by bots, left out" heks/onefetch-toggle-bots :transient t)
      ("M" "merge commits, left out" heks/onefetch-toggle-merges :transient t)
      ("e" "the authors' addresses, shown" heks/onefetch-toggle-email :transient t)
      ("h" "hidden files, counted" heks/onefetch-toggle-hidden :transient t)]
     ["how much of it"
      ("A" "how many authors" heks/onefetch-set-authors)
      ("L" "how many languages" heks/onefetch-set-languages)
      ("C" "how many file churns" heks/onefetch-set-churns)
      ("d" "the fields shown" heks/onefetch-set-fields)]]))

;;;###autoload
(global-set-key (kbd "C-c w o") #'heks/onefetch)

;;;###autoload
(defun heks/onefetch ()
  "Show every repository of `heks/onefetch-directories' as onefetch describes it.

Nothing is waited for: the window opens at once and the reading starts in
the background, so the directories are walked and the repositories described
while the screen is being read -- `heks/onefetch-parallelism' of them at a
time, what was described earlier in this session at once.  The keys are
under the rule at the top of the buffer, and `m' is onefetch's own options."
  (interactive)
  (let ((buffer (get-buffer-create heks/onefetch-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'heks/onefetch-mode)
        (heks/onefetch-mode))
      (heks/onefetch--read)
      (heks/onefetch--render))
    (pop-to-buffer buffer)))

(provide 'heks/onefetch)

;;; onefetch.el ends here
