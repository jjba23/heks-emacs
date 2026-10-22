;;; duplicates.el --- Finding the same code in more than one place -*- lexical-binding: t -*-

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

;; Duplication is the one problem a compiler cannot see and a linter cannot
;; name: every copy of a block is correct on its own line, and the bug is
;; the count.  It is also invisible by construction -- the second copy is
;; in another file, and nobody reads two files at once.
;;
;; So this module reads them at once.  The whole of it is a few steps, each
;; of which is a function of the one before:
;;
;;   * every file of a project is read into lines, and each line is
;;     normalized -- trailing space, indentation and runs of spaces taken
;;     out -- so that code that was indented differently still matches;
;;   * blank lines and comment-only lines are dropped, because a clone is
;;     the code, not the prose around it;
;;   * every window of `heks-emacs-duplicates-min-lines' consecutive lines
;;     is indexed by its own text.  A window that appears twice is a place
;;     where two copies start;
;;   * each of those is *extended* forward as far as the two copies agree,
;;     which is what turns "these five lines match" into "these sixty lines
;;     are the same sixty lines", and the extensions are collected by the
;;     text of the whole run, so that a clone found from three of its
;;     windows is one clone and not three;
;;   * what is left is filtered -- a run shorter than the minimum, a run
;;     with one place, a run inside a longer run that has the same places
;;     -- and sorted by how much it costs: the lines it repeats.
;;
;; The report is the point of it.  A list of findings a person has to read
;; is a list a person does not read, so the buffer says what it found in
;; the order of what is worth fixing, gives every place as a button that
;; opens the file at the line and lights the region up, and offers the
;; three things one wants next: the next cluster, the previous one, and
;; the same scan without the files-only rule.
;;
;; What it finds is *text* that repeats, spelled the same way: a copy with
;; its variables renamed is a copy this does not find, and neither is one
;; that was reformatted between lines.  That is the honest limit of a
;; comparison that needs no parser, no index and no network -- and it is
;; the kind that catches what actually happens, which is a block pasted
;; into a second file and then maintained twice.

;;; Code:

(require 'button)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defgroup heks-emacs-duplicates nil
  "Finding the same code in more than one place."
  :group 'tools)

(defcustom heks-emacs-duplicates-min-lines 6
  "How many lines two places have to share to be worth reporting.

Six lines is roughly a function body or a `let' with its clauses: less
than that is a shared idiom -- `(require 'cl-lib)', an `unless' -- and a
report full of idioms is a report nobody reads to the end."
  :type 'integer
  :group 'heks-emacs-duplicates)

(defcustom heks-emacs-duplicates-across-files-only t
  "Whether only duplications between two different files are reported.

A block copied inside one file is a function waiting to be written; the
same block in two files is the one nobody notices, because the two files
are never read together.  This reports the second and leaves the first to
a reader who is already looking at it; `s' in the report shows both."
  :type 'boolean
  :group 'heks-emacs-duplicates)

(defcustom heks-emacs-duplicates-file-regexp
  "\\.\\(?:el\\|eld\\|scm\\|sld\\|sls\\|md\\|org\\|txt\\|rst\\|ya?ml\\|json\\|toml\\|ini\\|cfg\\|sh\\|bash\\|zsh\\|py\\|rb\\|rs\\|go\\|c\\|h\\|cc\\|cpp\\|hpp\\|java\\|kt\\|kts\\|groovy\\|ts\\|tsx\\|js\\|jsx\\|css\\|scss\\|html\\|sql\\|tf\\|nix\\|hs\\|lisp\\|clj\\)\\'"
  "The files that are read, by the name a code file has.

A project also holds images, fonts, lock files and a `.git' directory; the
scan reads what is written to be read, and leaves the rest alone."
  :type 'regexp
  :group 'heks-emacs-duplicates)

(defcustom heks-emacs-duplicates-max-file-size (* 512 1024)
  "How large a file may be, in bytes, before the scan skips it.

A generated file is thousands of lines that look like every other
generated file, and reporting them as a clone of each other says nothing
about the code anybody wrote."
  :type 'integer
  :group 'heks-emacs-duplicates)

(defcustom heks-emacs-duplicates-max-files 3000
  "How many files one scan reads, at most.

The scan is quadratic in the number of *repeated* windows and linear in the
number of lines, so a large project is a large but ordinary wait; this is
the point past which the report would be unusable anyway."
  :type 'integer
  :group 'heks-emacs-duplicates)

(defcustom heks-emacs-duplicates-buffer-name "*heks-emacs duplicates*"
  "The buffer the report is shown in."
  :type 'string
  :group 'heks-emacs-duplicates)

(defconst heks-emacs-duplicates-comment-regexp
  "\\`\\(?:;;\\|;\\|#|\\||#\\|//\\|/\\*\\|\\*\\|<!--\\|-->\\)"
  "The lines that are a comment rather than code.

A clone is code; the comment above it is the copy's explanation and is
written again in different words, so it is left out of the comparison.  A
line that is nothing but a brace or a `end' is the same idea: it is
structure, and the structure is what the code around it already says.")

(defconst heks-emacs-duplicates-structure-regexp
  "\\`[][(){}[:space:];,]*\\'\\|\\`\\(?:end\\|fi\\|done\\|else\\|begin\\|then\\)\\'"
  "The lines that say nothing on their own, and match everywhere.")

;;
;; ====== Reading the files ======
;;

(defun heks-emacs-duplicates--normalize (line)
  "Return LINE with its indentation and its runs of spaces taken out."
  (string-trim (replace-regexp-in-string "[ \t]+" " " line)))

(defun heks-emacs-duplicates--worth-comparing-p (text)
  "Return whether TEXT, a normalized line, is code worth comparing."
  (and (not (string-empty-p text))
       (not (string-match-p heks-emacs-duplicates-comment-regexp text))
       (not (string-match-p heks-emacs-duplicates-structure-regexp text))))

(defun heks-emacs-duplicates-file-lines (file)
  "Return the comparable lines of FILE as a list of (NUMBER . TEXT).

NUMBER is the line's number in the file, which is what the report shows
and what the button that opens it jumps to; TEXT is the normalized line
the comparison is made of.  The file is read whole, and read as text: the
point is to compare what is written, not to understand it."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((number 1)
          (lines nil))
      (while (not (eobp))
        (let ((text (heks-emacs-duplicates--normalize
                     (buffer-substring-no-properties (line-beginning-position)
                                                     (line-end-position)))))
          (when (heks-emacs-duplicates--worth-comparing-p text)
            (push (cons number text) lines)))
        (forward-line 1)
        (setq number (1+ number)))
      (nreverse lines))))

(defun heks-emacs-duplicates--candidate-files (directory)
  "Return the files of DIRECTORY the scan should read.

What a project says its files are is `project.el''s answer, which already
leaves out what is ignored; a directory that is not a project falls back
to every file under it.  The size and the name of each one are then what
decides."
  (let* ((directory (file-name-as-directory (expand-file-name directory)))
         (project (ignore-errors (project-current nil directory)))
         (files (or (and project (ignore-errors (project-files project)))
                    (directory-files-recursively directory "" t))))
    (seq-take (seq-filter
               (lambda (file)
                 (and (file-regular-p file)
                      (string-match-p heks-emacs-duplicates-file-regexp file)
                      (let ((size (file-attribute-size (file-attributes file))))
                        (and (numberp size)
                             (<= size heks-emacs-duplicates-max-file-size)))))
               files)
              heks-emacs-duplicates-max-files)))

;;
;; ====== Finding the same lines twice ======
;;
;; A run is (TEXT LENGTH OCCURRENCES): the lines that were found more than
;; once, how many of them there are, and where.  An occurrence is
;; (FILE FIRST-LINE LAST-LINE), with the line numbers the file itself has.

(defun heks-emacs-duplicates--windows (file lines)
  "Return the windows of FILES's LINES that the index is built from.

Each window is (TEXT . INDEX), INDEX being the position of the window's
first line in LINES."
  (let ((width heks-emacs-duplicates-min-lines)
        (count (length lines))
        (windows nil)
        (index 0))
    (while (<= (+ index width) count)
      (push (cons (mapconcat (lambda (line) (cdr line))
                             (seq-subseq lines index (+ index width)) "\n")
                  index)
            windows)
      (setq index (1+ index)))
    windows))

(defun heks-emacs-duplicates--extend (one two files)
  "Return how many lines the runs at ONE and TWO agree on.

ONE and TWO are (FILE . INDEX) pairs and FILES maps a file to its lines,
as a vector; neither reads past the end of its file, and a window that was
indexed has at least the width of one line left, so the answer is never
zero."
  (let* ((one-lines (gethash (car one) files))
         (two-lines (gethash (car two) files))
         (index (cdr one))
         (other (cdr two))
         (length 0))
    (while (and (< index (length one-lines))
                (< other (length two-lines))
                (equal (cdr (aref one-lines index)) (cdr (aref two-lines other))))
      (setq index (1+ index)
            other (1+ other)
            length (1+ length)))
    length))

(defun heks-emacs-duplicates--occurrence (place files length)
  "Return PLACE, a (FILE . INDEX) pair, as the occurrence of LENGTH lines."
  (let* ((lines (gethash (car place) files))
         (first (aref lines (cdr place)))
         (last (aref lines (1- (+ (cdr place) length)))))
    (list (car place) (car first) (car last))))

(defun heks-emacs-duplicates--collect (files)
  "Return every run of lines FILES has more than once.

FILES is a hash table from a file name to its comparable lines.  The
windows are indexed first, and only the windows that appear twice are
extended: a line that is written once costs a table entry, and the work
is spent where there is a question to answer."
  (let ((index (make-hash-table :test #'equal))
        (runs (make-hash-table :test #'equal)))
    (maphash
     (lambda (file lines)
       (dolist (window (heks-emacs-duplicates--windows file lines))
         (push (cons file (cdr window)) (gethash (car window) index))))
     files)
    (maphash
     (lambda (text places)
       (when (cdr places)
         (let ((places (nreverse places)))
           (while (cdr places)
             (let ((one (car places)))
               (dolist (two (cdr places))
                 (let ((length (heks-emacs-duplicates--extend one two files)))
                   (when (>= length heks-emacs-duplicates-min-lines)
                     (let* ((one-lines (gethash (car one) files))
                            (run-text (mapconcat (lambda (line) (cdr line))
                                                 (seq-subseq one-lines (cdr one)
                                                             (+ (cdr one) length))
                                                 "\n"))
                            (entry (gethash run-text runs)))
                       (unless entry
                         (setq entry (list :text run-text :length length
                                           :occurrences nil))
                         (puthash run-text entry runs))
                       ;; The same run is found once per window it holds,
                       ;; and the occurrence is the same each time: the
                       ;; set is what keeps the report honest.
                       (dolist (place (list one two))
                         (let ((occurrence
                                (heks-emacs-duplicates--occurrence place files length)))
                           (unless (member occurrence (plist-get entry :occurrences))
                             (setq entry (plist-put entry :occurrences
                                                    (cons occurrence
                                                          (plist-get entry :occurrences))))
                             (puthash run-text entry runs))))))))
               (setq places (cdr places)))))))
     index)
    (let ((collected nil))
      (maphash (lambda (_text entry) (push entry collected)) runs)
      collected)))

(defun heks-emacs-duplicates--contains-p (outer line)
  "Return whether LINE, an occurrence, is inside the run OUTER holds."
  (seq-some (lambda (occurrence)
              (and (equal (nth 0 occurrence) (nth 0 line))
                   (<= (nth 1 occurrence) (nth 1 line))
                   (<= (nth 2 line) (nth 2 occurrence))))
            (plist-get outer :occurrences)))

(defun heks-emacs-duplicates--filter (runs)
  "Return RUNS worth reporting: long enough, twice, and not a piece of another.

A run that sits inside a longer run in exactly the same places is the same
finding said twice, and it is said the second time in a lower voice: it is
shorter, so it sorts below the run it belongs to, and a reader would have
to work out that the two are one."
  (let ((kept nil))
    (dolist (run (sort runs (lambda (one two)
                              (> (plist-get one :length) (plist-get two :length)))))
      (let ((occurrences (plist-get run :occurrences)))
        (when (and (>= (length occurrences) 2)
                   (or (not heks-emacs-duplicates-across-files-only)
                       (< 1 (length (delete-dups (mapcar #'car occurrences)))))
                   (not (seq-some (lambda (other)
                                    (and (> (plist-get other :length)
                                            (plist-get run :length))
                                         (cl-every (lambda (occurrence)
                                                     (heks-emacs-duplicates--contains-p
                                                      other occurrence))
                                                   occurrences)))
                                  kept)))
          (push run kept))))
    (nreverse kept)))

(defun heks-emacs-duplicates-wasted-lines (run)
  "Return how many lines RUN repeats for nothing.

A block in three places could be written once: the cost of not writing it
once is every copy but one."
  (* (plist-get run :length) (1- (length (plist-get run :occurrences)))))

(defun heks-emacs-duplicates--scan-files (names)
  "Return the duplications of the files NAMES, worst first."
  (let ((files (make-hash-table :test #'equal)))
    (dolist (file names)
      (let ((lines (ignore-errors (heks-emacs-duplicates-file-lines file))))
        (when (and lines (cdr lines))
          (puthash (expand-file-name file) (vconcat lines) files))))
    (sort (heks-emacs-duplicates--filter (heks-emacs-duplicates--collect files))
          (lambda (one two)
            (> (heks-emacs-duplicates-wasted-lines one)
               (heks-emacs-duplicates-wasted-lines two))))))

(defun heks-emacs-duplicates-scan (directory)
  "Return the duplications of the files of DIRECTORY, worst first.

Each one is a plist: :text (the lines, as the comparison sees them),
:length (how many lines), :occurrences (a list of (FILE FIRST-LINE
LAST-LINE)), and what `heks-emacs-duplicates-wasted-lines' makes of them."
  (heks-emacs-duplicates--scan-files (heks-emacs-duplicates--candidate-files directory)))

;;
;; ====== Saying it, so that it is read ======
;;

(defun heks-emacs-duplicates--flash (file first last)
  "Show the clone at FILE from FIRST to LAST and put point at its start."
  (let ((buffer (find-file-other-window file)))
    (with-current-buffer buffer
      (goto-char (point-min))
      (forward-line (1- (max 1 first)))
      (let* ((start (point))
             (end (save-excursion
                    (forward-line (max 0 (- last first)))
                    (min (point-max) (line-end-position))))
             (overlay (make-overlay start end buffer)))
        (overlay-put overlay 'face 'highlight)
        (ignore-errors (recenter))
        ;; The light goes out on its own: a region left highlighted is a
        ;; region the next edit is made inside by accident.
        (run-at-time 2 nil
                     (lambda (overlay)
                       (when (and (overlayp overlay)
                                  (buffer-live-p (overlay-buffer overlay)))
                         (delete-overlay overlay)))
                     overlay))
      buffer)))

(defun heks-emacs-duplicates--button (file first last)
  "Insert a button for the clone at FILE from FIRST to LAST."
  (let ((label (format "%s:%d-%d" (abbreviate-file-name file) first last)))
    (insert-text-button label
                        :follow (lambda (_button)
                                  (heks-emacs-duplicates--flash file first last))
                        :help-echo "Open this place, with the clone lit up"
                        :face 'link)
    (insert "\n")))

(defun heks-emacs-duplicates--preview (text)
  "Insert the first lines of TEXT as the excerpt of a cluster."
  (let ((lines (seq-take (split-string text "\n") 4)))
    (dolist (line lines)
      (insert (propertize (format "     │ %s\n" line) 'face 'shadow)))))

(defun heks-emacs-duplicates-render (report title)
  "Insert REPORT, a list of clusters, into the current buffer.

TITLE says what was scanned and is put above them.  The report is ordered
by what it costs, because a list of everything is not a list of anything:
the first cluster is the one worth the time, and the numbers beside each
one are the two things that decide it -- how many lines, and how many of
them are written more than once."
  (let* ((count (length report))
         (lines (apply #'+ 0 (mapcar (lambda (run) (plist-get run :length)) report)))
         (wasted (apply #'+ 0 (mapcar #'heks-emacs-duplicates-wasted-lines report))))
    (insert (propertize (format "%s\n" title) 'face 'bold))
    (insert (make-string (min 72 (max 40 (length title))) ?─) "\n")
    (if (zerop count)
        (insert (propertize "\nNothing is written twice, as far as this can tell.\n"
                            'face 'shadow))
      (insert (format "%d cluster%s · %d lines · %d of them written twice\n\n"
                      count (if (= count 1) "" "s") lines wasted)))
    (let ((number 0))
      (dolist (run report)
        (setq number (1+ number))
        (insert (propertize
                 (format "%d  %d lines in %d places · %d lines wasted\n"
                         number
                         (plist-get run :length)
                         (length (plist-get run :occurrences))
                         (heks-emacs-duplicates-wasted-lines run))
                 'face 'bold
                 'heks-emacs-duplicates-cluster number))
        (dolist (occurrence (sort (copy-sequence (plist-get run :occurrences))
                                  (lambda (one two)
                                    (if (equal (nth 0 one) (nth 0 two))
                                        (< (nth 1 one) (nth 1 two))
                                      (string< (nth 0 one) (nth 0 two))))))
          (insert "   ")
          (heks-emacs-duplicates--button (nth 0 occurrence)
                                        (nth 1 occurrence)
                                        (nth 2 occurrence)))
        (heks-emacs-duplicates--preview (plist-get run :text))
        (insert "\n")))))

(defvar-local heks-emacs-duplicates--directory nil
  "The directory the report in this buffer was made from.")

(defun heks-emacs-duplicates--revert (&rest _)
  "Make the report in this buffer again, from the directory it names."
  (when heks-emacs-duplicates--directory
    (heks-emacs-duplicates-report heks-emacs-duplicates--directory t)))

(defun heks-emacs-duplicates-next (&optional previous)
  "Move to the next cluster of the report, or to the PREVIOUS one."
  (interactive)
  (let* ((numbers (heks-emacs-duplicates--clusters))
         (here (or (get-text-property (point) 'heks-emacs-duplicates-cluster) 0))
         (below (seq-filter (lambda (number) (if previous (< number here) (> number here)))
                            numbers))
         (target (if previous (car (last below)) (car below))))
    (if target
        (progn
          (goto-char (point-min))
          (while (and (not (eobp))
                      (not (equal (get-text-property
                                   (point) 'heks-emacs-duplicates-cluster)
                                  target)))
            (forward-line 1))
          (beginning-of-line))
      (message "That is the %s cluster" (if previous "first" "last")))))

(defun heks-emacs-duplicates--clusters ()
  "Return the cluster numbers of the report in this buffer."
  (let ((numbers nil)
        (limit (point-max))
        (position (point-min)))
    (while (< position limit)
      (let ((next (next-single-property-change
                   position 'heks-emacs-duplicates-cluster nil limit)))
        (if (or (null next) (<= next position))
            (setq position (1+ position))
          (let ((number (get-text-property next 'heks-emacs-duplicates-cluster)))
            (when number (push number numbers))
            (setq position next)))))
    (delete-dups (nreverse numbers))))

(defun heks-emacs-duplicates-toggle-files ()
  "Show, or stop showing, the clones inside one file."
  (interactive)
  (setq heks-emacs-duplicates-across-files-only
        (not heks-emacs-duplicates-across-files-only))
  (message "Duplication within one file is %s"
           (if heks-emacs-duplicates-across-files-only "hidden" "shown"))
  (heks-emacs-duplicates--revert))

(defvar heks-emacs-duplicates-report-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "n") #'heks-emacs-duplicates-next)
    (define-key map (kbd "p") (lambda () (interactive)
                                (heks-emacs-duplicates-next t)))
    (define-key map (kbd "s") #'heks-emacs-duplicates-toggle-files)
    (define-key map (kbd "g") #'revert-buffer)
    map)
  "The keys of the duplication report: the next cluster, and the next look.")

(define-derived-mode heks-emacs-duplicates-report-mode special-mode "Duplicates"
  "The report of what a project writes twice.

The clusters are in the order of what they cost, every place is a button
that opens it with the clone lit up, and `n' and `p' walk the clusters."
  (setq-local truncate-lines nil
              revert-buffer-function #'heks-emacs-duplicates--revert))

(defun heks-emacs-duplicates-report (&optional directory keep-window)
  "Find what DIRECTORY writes more than once, and show it.

The scan reads the files the project says it has, compares their lines, and
reports the blocks that appear in more than one place -- the worst first,
with every place a button that opens it.  KEEP-WINDOW is for the report
being made again in the buffer it is already shown in."
  (interactive (list (read-directory-name "Find duplication under: "
                                          (or (ignore-errors
                                                (project-root (project-current)))
                                              default-directory)
                                          nil t)))
  (let* ((directory (file-name-as-directory (expand-file-name directory)))
         (files (heks-emacs-duplicates--candidate-files directory))
         (report (heks-emacs-duplicates--scan-files files))
         (buffer (get-buffer-create heks-emacs-duplicates-buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (heks-emacs-duplicates-report-mode)
        (setq heks-emacs-duplicates--directory directory)
        (heks-emacs-duplicates-render
         report
         (format "duplicated code · %s · %d files read"
                 (abbreviate-file-name directory) (length files)))
        (goto-char (point-min))))
    (if keep-window
        (with-current-buffer buffer (goto-char (point-min)))
      (pop-to-buffer buffer))
    (message "%d cluster%s of code written more than once"
             (length report) (if (= (length report) 1) "" "s"))
    buffer))

(provide 'heks-emacs/duplicates)

;;; duplicates.el ends here
