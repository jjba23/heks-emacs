;;; notes.el --- Notes: one Org file per note, in topic folders -*- lexical-binding: t -*-

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

;; Notes are plain files: <notes>/<topic>/<slug>.org, where a topic is a
;; folder (and may be nested: "work/infra").  Each note opens with #+title:
;; and #+date: (and #+filetags: when it has tags), and links to other notes
;; are plain relative `file:' links, so a note reads the same in any tool.
;;
;; There is no database and no identifier to keep: titles are read from the
;; files themselves, backlinks and search are grep, and moving a note
;; rewrites the links that pointed at it.  The notes directory is nothing
;; but files, and syncs with git, Syncthing or anything else.
;;
;; The notes directory is `heks/notes-dir' (see heks-emacs.el).

;;; Code:

(require 'subr-x)
(require 'seq)
(require 'cl-lib)

(declare-function heks/notes-directory "heks-emacs" ())
(declare-function eww-current-url "eww")
(declare-function org-link-make-string "ol")
(declare-function consult-ripgrep "consult")
(declare-function lgrep "grep")

(defun heks/notes--root ()
  "Return the notes directory, or signal what to set when there is none."
  (let ((root (or (heks/notes-directory)
                  (user-error
                   "Set `heks/notes-dir' to say where the notes are"))))
    (make-directory root t)
    (file-name-as-directory root)))

(defconst heks/notes-archive-name ".archive"
  "The folder old, employer-specific notes live in.
It starts with a dot, so it stays out of `heks/notes-files', the
agenda and ripgrep until one asks for it with `heks/notes-find-archived'.")

(defun heks/notes-files (&optional archive)
  "Return every note file, as absolute names.
With ARCHIVE, return the files of the archive instead."
  (let ((root (heks/notes--root)))
    (if archive
        (let ((dir (expand-file-name heks/notes-archive-name root)))
          (and (file-directory-p dir)
               (directory-files-recursively dir "\\.org\\'")))
      (seq-remove (lambda (file) (string-match-p "/\\." (file-relative-name file root)))
                  (directory-files-recursively root "\\.org\\'")))))

(defun heks/notes-topics ()
  "Return the topic folders that exist, relative to the notes directory."
  (let ((root (heks/notes--root)))
    (sort (mapcar (lambda (dir)
                    (directory-file-name (file-relative-name dir root)))
                  (seq-remove
                   (lambda (dir) (string-match-p "/\\." (file-relative-name dir root)))
                   (seq-filter #'file-directory-p
                               (directory-files-recursively root "" t))))
          #'string<)))

(defun heks/notes--slug (title)
  "Return TITLE as a file name stem: lowercase words joined by dashes."
  (let ((slug (replace-regexp-in-string
               "-+" "-"
               (replace-regexp-in-string
                "[^[:alnum:]]" "-" (downcase (string-trim title))))))
    (setq slug (string-trim slug "-+" "-+"))
    (if (string-empty-p slug) "untitled" slug)))

(defun heks/notes--header (file)
  "Return an alist of ID, TITLE and TAGS read from the head of FILE."
  (with-temp-buffer
    (insert-file-contents file nil 0 2048)
    (let (id title tags)
      (goto-char (point-min))
      (when (re-search-forward "^:ID:[ \t]+\\([^ \t\n]+\\)" nil t)
        (setq id (match-string 1)))
      (goto-char (point-min))
      (when (re-search-forward "^#\\+title:[ \t]*\\(.*\\)$" nil t)
        (setq title (string-trim (match-string 1))))
      (goto-char (point-min))
      (when (re-search-forward "^#\\+filetags:[ \t]*\\(.*\\)$" nil t)
        (setq tags (string-trim (match-string 1))))
      `((id . ,id) (title . ,title) (tags . ,tags)))))

(defun heks/notes--age (time)
  "Return TIME as a short age: today, 3d, 5w, 2y."
  (let ((days (floor (/ (float-time (time-subtract nil time)) 86400))))
    (cond ((< days 1) "today")
          ((< days 14) (format "%dd" days))
          ((< days 90) (format "%dw" (/ days 7)))
          ((< days 730) (format "%dmo" (/ days 30)))
          (t (format "%dy" (/ days 365))))))

(defun heks/notes--annotation (text)
  "Return TEXT as a completion annotation, aligned the way Marginalia aligns."
  (concat (propertize " " 'display '(space :align-to 48))
          (propertize text 'face 'completions-annotations)))

(defun heks/notes--table (candidates category annotate &optional sort)
  "Return a completion table of CANDIDATES (strings), in CATEGORY.
ANNOTATE maps a candidate to its annotation; SORT, when given, orders them."
  (lambda (string pred action)
    (if (eq action 'metadata)
        `(metadata (category . ,category)
                   (annotation-function . ,annotate)
                   (display-sort-function . ,(or sort #'identity))
                   (cycle-sort-function . ,(or sort #'identity)))
      (complete-with-action action candidates string pred))))

(defun heks/notes--topic-description (topic)
  "Return the first line of prose of TOPIC's index note, or nil."
  (let ((index (expand-file-name "index.org" (expand-file-name topic (heks/notes--root)))))
    (when (file-readable-p index)
      (with-temp-buffer
        (insert-file-contents index nil 0 1500)
        (goto-char (point-min))
        (catch 'found
          (while (not (eobp))
            (let ((line (buffer-substring (line-beginning-position) (line-end-position))))
              (unless (string-match-p "\\`\\(:\\|#\\|\\*\\|-\\|[ \t]*\\'\\)" line)
                (throw 'found (truncate-string-to-width line 60 nil nil "…"))))
            (forward-line 1)))))))

(defun heks/notes--topic-info ()
  "Return a hash table: topic -> (NOTES SUBTOPICS NEWEST-TIME)."
  (let ((info (make-hash-table :test 'equal))
        (root (heks/notes--root)))
    (dolist (topic (heks/notes-topics))
      (puthash topic (list 0 0 nil) info))
    (dolist (file (heks/notes-files))
      (let* ((topic (directory-file-name
                     (or (file-name-directory (file-relative-name file root)) "")))
             (cell (gethash topic info))
             (time (file-attribute-modification-time (file-attributes file))))
        (when cell
          (cl-incf (nth 0 cell))
          (when (or (null (nth 2 cell)) (time-less-p (nth 2 cell) time))
            (setf (nth 2 cell) time)))))
    (maphash (lambda (topic _cell)
               (let ((parent (directory-file-name (or (file-name-directory topic) ""))))
                 (when-let* ((p (gethash parent info)))
                   (cl-incf (nth 1 p)))))
             info)
    info))

(defun heks/notes--topic-annotation (info)
  "Return the annotation function for topics, over the table INFO."
  (lambda (topic)
    (let ((cell (gethash topic info)))
      (heks/notes--annotation
       (if (not cell) "new topic"
         (concat (format "%3d notes" (nth 0 cell))
                 (if (> (nth 1 cell) 0) (format " · %d sub" (nth 1 cell)) "")
                 (if (nth 2 cell) (format " · %s" (heks/notes--age (nth 2 cell))) "")
                 (when-let* ((d (heks/notes--topic-description topic)))
                   (concat " — " d))))))))

(defun heks/notes--topic-name (input)
  "Return INPUT as a topic path: each segment lowercase words with dashes."
  (let ((segments (seq-remove #'string-empty-p
                              (split-string (string-trim input) "/" t))))
    (when (member ".." segments)
      (user-error "A topic is a folder inside the notes, not a path out of them"))
    (mapconcat #'heks/notes--slug segments "/")))

(defun heks/notes--read-topic ()
  "Ask where a note goes: an existing topic, or a new one typed in.
Candidates show how many notes a topic holds, when it last changed and
what its index says it is for; the busiest recent ones come first."
  (let* ((info (heks/notes--topic-info))
         (topics (hash-table-keys info))
         (sort (lambda (candidates)
                 (sort (copy-sequence candidates)
                       (lambda (a b)
                         (let ((ta (nth 2 (gethash a info)))
                               (tb (nth 2 (gethash b info))))
                           (cond ((and ta tb) (time-less-p tb ta))
                                 (ta t)
                                 (t nil)))))))
         (input (completing-read
                 "Put the note in (type a new topic to create it): "
                 (heks/notes--table
                  topics 'heks/note-topic
                  (heks/notes--topic-annotation info) sort)))
         (topic (heks/notes--topic-name input)))
    (when (string-empty-p topic)
      (user-error "A note needs a topic"))
    (unless (gethash topic info)
      (unless (y-or-n-p (format "Create the new topic `%s'? " topic))
        (user-error "Cancelled")))
    topic))

(defun heks/notes--candidates (&optional archive)
  "Return an alist from completion strings to note files.
With ARCHIVE, the notes of the archive.  The text of a candidate is the
title alone, or the title and topic when two notes share a title."
  (let* ((root (heks/notes--root))
         (base (if archive
                   (expand-file-name heks/notes-archive-name root)
                 root))
         (seen (make-hash-table :test 'equal))
         result)
    (dolist (file (heks/notes-files archive))
      (let* ((header (heks/notes--header file))
             (title (or (alist-get 'title header) (file-name-base file)))
             (topic (directory-file-name
                     (or (file-name-directory (file-relative-name file base)) "")))
             (name (if (gethash title seen) (format "%s (%s)" title topic) title)))
        (puthash title t seen)
        (push (cons (propertize name 'heks/note-file file) file) result)))
    (nreverse result)))

(defun heks/notes--note-annotation (candidate)
  "Return the annotation for note CANDIDATE: topic, tags and age."
  (when-let* ((file (get-text-property 0 'heks/note-file candidate)))
    (let* ((root (heks/notes--root))
           (topic (directory-file-name
                   (or (file-name-directory (file-relative-name file root)) "")))
           (tags (alist-get 'tags (heks/notes--header file)))
           (time (file-attribute-modification-time (file-attributes file))))
      (heks/notes--annotation
       (string-join
        (delq nil (list (unless (string-empty-p topic) topic)
                        (unless (string-empty-p (or tags "")) tags)
                        (heks/notes--age time)))
        " · ")))))

(defun heks/notes--note-table (candidates)
  "Return a completion table of the notes CANDIDATES."
  (heks/notes--table (mapcar #'car candidates) 'heks/note
                           #'heks/notes--note-annotation))

(defun heks/notes--read-note (prompt &optional archive require-match)
  "Ask for a note with PROMPT and return its file, or the text typed.
ARCHIVE asks among the archive; REQUIRE-MATCH insists on an existing note."
  (let* ((candidates (heks/notes--candidates archive))
         (choice (completing-read prompt (heks/notes--note-table candidates)
                                  nil require-match)))
    (or (cdr (assoc choice candidates)) choice)))

(defun heks/notes--unique-file (directory slug)
  "Return a file in DIRECTORY named after SLUG that does not exist yet."
  (let ((file (expand-file-name (concat slug ".org") directory))
        (n 1))
    (while (file-exists-p file)
      (setq n (1+ n)
            file (expand-file-name (format "%s-%d.org" slug n) directory)))
    file))

(defvar heks/notes-after-create-hook nil
  "Hook run in the buffer of a note just created.")

(defun heks/notes--snippet ()
  "Return what to capture from this buffer: the region, or nil."
  (when (use-region-p)
    (buffer-substring-no-properties (region-beginning) (region-end))))

(defun heks/notes--source ()
  "Return an Org link, or text, saying where the current buffer came from."
  (cond (buffer-file-name
         (format "[[file:%s][%s]]" (abbreviate-file-name buffer-file-name)
                 (file-name-nondirectory buffer-file-name)))
        ((and (derived-mode-p 'eww-mode) (bound-and-true-p eww-data))
         (let ((url (plist-get eww-data :url)))
           (format "[[%s][%s]]" url (or (plist-get eww-data :title) url))))
        (t (buffer-name))))

(defun heks/notes--format-snippet (snippet)
  "Return SNIPPET as Org: a source block in code buffers, a quote elsewhere."
  (if (derived-mode-p 'prog-mode)
      (format "#+begin_src %s\n%s\n#+end_src\n"
              (string-remove-suffix "-mode" (symbol-name major-mode))
              (string-trim-right snippet))
    (format "#+begin_quote\n%s\n#+end_quote\n" (string-trim-right snippet))))

;;;###autoload
(defun heks/notes-new (topic title &optional tags body visit)
  "Create a note called TITLE in folder TOPIC, with TAGS and BODY.
The note is opened when VISIT, and its file is returned either way."
  (interactive
   (list (heks/notes--read-topic)
         (read-string "Title: ")
         (read-string "Tags (space separated, optional): ")
         nil t))
  (when (string-empty-p (string-trim title))
    (user-error "A note needs a title"))
  (let* ((directory (expand-file-name topic (heks/notes--root)))
         (file (heks/notes--unique-file
                directory (heks/notes--slug title)))
         (tags (split-string (or tags "") "[ ,:]+" t)))
    (make-directory directory t)
    (with-temp-file file
      (insert "#+title: " (string-trim title) "\n"
              "#+date: " (format-time-string "[%Y-%m-%d %a]") "\n"
              (if tags (format "#+filetags: :%s:\n" (string-join tags ":")) "")
              "\n" (or body "")))
    (heks/notes-index-update-up directory)
    (when visit
      (find-file file)
      (goto-char (point-max))
      (run-hooks 'heks/notes-after-create-hook))
    file))

;;;###autoload
(defun heks/notes-capture (&optional clipboard)
  "Capture a note from anywhere, asking where it goes.

The text is the active region, or with a prefix argument CLIPBOARD the
latest kill; it is stored with a link back to where it came from, and
Emacs stays where it was.  With no text, the new note is opened for
writing instead."
  (interactive "P")
  (let* ((snippet (or (heks/notes--snippet)
                      (and clipboard (current-kill 0 t))))
         (source (heks/notes--source))
         (default (and snippet
                       (car (split-string (string-trim snippet) "\n" t))))
         (topic (heks/notes--read-topic))
         (title (read-string
                 (if default "Title: " "Title: ")
                 (and default (truncate-string-to-width default 60))))
         (tags (read-string "Tags (space separated, optional): "))
         (body (and snippet
                    (concat (heks/notes--format-snippet snippet)
                            "\nSource: " source "\n")))
         (file (heks/notes-new topic title tags body (not snippet))))
    (when snippet
      (deactivate-mark)
      (message "Captured in %s" (file-relative-name file (heks/notes--root))))
    file))

;;;###autoload
(defun heks/notes-extend (&optional clipboard)
  "Add text to the end of an existing note, chosen by title.
The text is the active region, or with CLIPBOARD the latest kill, or what
is typed; it is filed under a heading with today's date."
  (interactive "P")
  (let* ((snippet (or (heks/notes--snippet)
                      (and clipboard (current-kill 0 t))
                      (read-string "Add: ")))
         (source (heks/notes--source))
         (file (heks/notes--read-note "Add to note: " nil t))
         (body (concat "\n* " (format-time-string "[%Y-%m-%d %a]") "\n"
                       (if (heks/notes--snippet)
                           (heks/notes--format-snippet snippet)
                         (string-trim-right snippet))
                       (if buffer-file-name (concat "\n\nSource: " source) "")
                       "\n")))
    (with-current-buffer (find-file-noselect file)
      (save-excursion
        (goto-char (point-max))
        (unless (bolp) (insert "\n"))
        (insert body))
      (save-buffer))
    (deactivate-mark)
    (message "Added to %s" (file-name-nondirectory file))))

;;;###autoload
(defun heks/notes-find ()
  "Open a note, found by title."
  (interactive)
  (find-file (heks/notes--read-note "Note: " nil t)))

;;;###autoload
(defun heks/notes-find-archived ()
  "Open a note from the archive, the old employers' knowledge."
  (interactive)
  (find-file (heks/notes--read-note "Archived note: " t t)))

(defun heks/notes--note-or-new (prompt visit)
  "Ask for a note with PROMPT; a title that names none creates one.
The new note is opened when VISIT.  Return the file."
  (let ((answer (heks/notes--read-note prompt)))
    (if (file-exists-p answer)
        answer
      (heks/notes-new (heks/notes--read-topic) answer nil nil visit))))

;;;###autoload
(defun heks/notes-find-or-create ()
  "Open the note called by a title, or create it when no note is."
  (interactive)
  (find-file (heks/notes--note-or-new "Note (new title to create): " nil)))

;;;###autoload
(defun heks/notes--relative-link (from to)
  "Return the file name TO as a link target relative to the file FROM."
  (let ((rel (file-relative-name to (file-name-directory (expand-file-name from)))))
    (if (string-prefix-p "." rel) rel (concat "./" rel))))

(defun heks/notes-insert ()
  "Insert a link to a note, creating the note when it does not exist."
  (interactive)
  (let* ((file (heks/notes--note-or-new "Link to note (new title to create): " nil))
         (header (heks/notes--header file))
         (target (if buffer-file-name
                     (heks/notes--relative-link buffer-file-name file)
                   file)))
    (insert (format "[[file:%s][%s]]" target
                    (or (alist-get 'title header) (file-name-base file))))))

;;;###autoload
(defun heks/notes-backlinks ()
  "List the notes that link to the note of this buffer."
  (interactive)
  (let ((file (or buffer-file-name (user-error "This buffer is not a note"))))
    (require 'grep)
    (lgrep (format "file:[^]]*[./]%s\\.org" (regexp-quote (file-name-base file)))
           "*.org" (heks/notes--root))))

;;;###autoload
(defun heks/notes-search ()
  "Search the text of every note."
  (interactive)
  (if (fboundp 'consult-ripgrep)
      (consult-ripgrep (heks/notes--root))
    (require 'grep)
    (lgrep (read-string "Search notes: ") "*.org" (heks/notes--root))))

;;;###autoload
(defun heks/notes--relink-text (text old-base new-base from to)
  "Return TEXT with its relative file links repaired.
TEXT lived in the folder OLD-BASE and now lives in NEW-BASE; a link that
pointed at the file FROM now points at the file TO.  When the folder did
not change, only the links to FROM are touched."
  (replace-regexp-in-string
   "\\[\\[file:\\([^]:]+\\)\\(::[^]]*\\)?\\]"
   (lambda (match)
     (let* ((path (match-string 1 match))
            (suffix (or (match-string 2 match) "")))
       (if (or (file-name-absolute-p path) (string-prefix-p "~" path))
           match
         (let* ((target (expand-file-name path old-base))
                (hit (string= target (expand-file-name from))))
           (if (and (not hit)
                    (string= (file-name-as-directory (expand-file-name old-base))
                             (file-name-as-directory (expand-file-name new-base))))
               match
             (let ((rel (file-relative-name (if hit to target) new-base)))
               (format "[[file:%s%s]" (if (string-prefix-p "." rel) rel (concat "./" rel))
                       suffix)))))))
   text t t))

(defun heks/notes--relink-file (file old-base new-base from to)
  "Repair the links of FILE (see `heks/notes--relink-text').  Return non-nil if changed."
  (let* ((buf (find-buffer-visiting file))
         (old (with-temp-buffer (insert-file-contents file) (buffer-string)))
         (new (heks/notes--relink-text old old-base new-base from to)))
    (unless (equal old new)
      (if (and buf (buffer-modified-p buf))
          (progn (message "Not repairing links in %s: it has unsaved changes" file) nil)
        (write-region new nil file nil 'silent)
        (when buf (with-current-buffer buf (revert-buffer t t t)))
        t))))

;;;###autoload
(defun heks/notes-move (topic)
  "Move the note of this buffer to folder TOPIC.

Links are relative, so the links that pointed at the note are rewritten to
point at its new place, and the links inside it are made relative to it."
  (interactive (list (heks/notes--read-topic)))
  (let* ((file (or buffer-file-name (user-error "This buffer is not a note")))
         (directory (expand-file-name topic (heks/notes--root)))
         (target (heks/notes--unique-file directory (file-name-base file)))
         (old-base (file-name-directory file))
         (repaired 0))
    (when (buffer-modified-p) (save-buffer))
    (make-directory directory t)
    (rename-file file target)
    (set-visited-file-name target nil t)
    (set-buffer-modified-p nil)
    ;; its own links first, then everyone else's
    (when (heks/notes--relink-file target old-base (file-name-directory target) file target)
      (revert-buffer t t t)
      (cl-incf repaired))
    (dolist (f (append (heks/notes-files) (heks/notes-files t)))
      (unless (file-equal-p f target)
        (when (heks/notes--relink-file f (file-name-directory f) (file-name-directory f) file target)
          (cl-incf repaired))))
    (heks/notes-index-update-up old-base)
    (heks/notes-index-update-up directory)
    (message "Moved to %s; %d notes had links repaired"
             (file-relative-name target (heks/notes--root)) repaired)))

;;;###autoload
(defun heks/notes-topic ()
  "Open a topic folder in Dired."
  (interactive)
  (let ((topic (completing-read "Topic: " (heks/notes-topics) nil t)))
    (dired (expand-file-name topic (heks/notes--root)))))

;;; ---- Index pages ----------------------------------------------------
;;
;; Every topic folder has an `index.org' that lists what is in it.  It is
;; generated: the part between the BEGIN and END markers is rebuilt from the
;; folder, and whatever is written above it (the description) is kept.  An
;; index without the markers, or the old generated comment, is somebody's
;; own page and is never touched.

(defconst heks/notes-index-begin "# BEGIN GENERATED INDEX")
(defconst heks/notes-index-end "# END GENERATED INDEX")

(defcustom heks/notes-index-acronyms
  '(("ah" . "AH") ("ctms" . "CTMS") ("boms" . "BOMS") ("boap" . "BOAP")
    ("ikea" . "IKEA") ("vko" . "VKO") ("p4" . "P4") ("ai" . "AI")
    ("sbt" . "sbt") ("devops" . "DevOps") ("nix" . "Nix") ("guix" . "Guix")
    ("sss" . "SSS") ("adr" . "ADR") ("http" . "HTTP") ("apis" . "APIs"))
  "Folder words that are not written as plain capitalised words in an index title."
  :type '(alist :key-type string :value-type string)
  :group 'heks)

(defun heks/notes--pretty (segment)
  "Return folder SEGMENT as a title: `http-apis' becomes `HTTP APIs'."
  (mapconcat (lambda (w)
               (or (cdr (assoc w heks/notes-index-acronyms))
                   (if (member w '("and" "of" "for" "the" "to" "in" "a" "on")) w
                     (capitalize w))))
             (split-string (string-remove-prefix "." segment) "-" t) " "))

(defun heks/notes--index-dirs-p (dir)
  "Non-nil when DIR is a folder that gets an index: the notes, or the archive."
  (let* ((root (heks/notes--root))
         (rel (file-relative-name (directory-file-name dir) root)))
    (and (not (string-prefix-p ".." rel))
         (not (string-match-p "\\(\\`\\|/\\)\\.\\(?:git\\|metals\\)\\(/\\|\\'\\)" rel))
         (not (string-match-p "\\`diary\\(/\\|\\'\\)" rel))
         (or (string= rel ".")
             (not (string-match-p "\\(\\`\\|/\\)\\." (replace-regexp-in-string
                                                      "\\`\\.archive\\(/\\|\\'\\)" "" rel)))))))

(defun heks/notes--dir-notes (dir)
  "Return the note files directly in DIR, except its index."
  (seq-remove (lambda (f) (string= (file-name-nondirectory f) "index.org"))
              (directory-files dir t "\\.org\\'")))

(defun heks/notes--dir-subdirs (dir)
  "Return the folders directly in DIR that can hold notes."
  (seq-filter (lambda (d)
                (and (file-directory-p d)
                     (not (member (file-name-nondirectory d) '("." ".." ".git" ".metals" "diary")))
                     (heks/notes--index-dirs-p d)
                     ;; the archive is not a child of the notes' root index
                     (not (string= (file-name-nondirectory d) heks/notes-archive-name))))
              (directory-files dir t "\\`[^.].*\\|\\`\\.archive\\'")))

(defun heks/notes--has-notes-p (dir)
  "Non-nil when DIR, or a folder under it, holds a note."
  (and (file-directory-p dir)
       (directory-files-recursively
        dir "\\.org\\'" nil
        (lambda (d) (not (string-match-p "/\\.\\(git\\|metals\\)\\'" d))))
       t))

(defun heks/notes--index-text (dir)
  "Return the generated body for the index of DIR, or nil when it has none."
  (let* ((root (heks/notes--root))
         (is-root (file-equal-p dir root))
         (subs (delq nil
                     (mapcar
                      (lambda (d)
                        (when (heks/notes--has-notes-p d)
                          (unless (file-exists-p (expand-file-name "index.org" d))
                            (heks/notes-index-update d))
                          (when (file-exists-p (expand-file-name "index.org" d))
                            (list (heks/notes--pretty (file-name-nondirectory d))
                                  (format "./%s/index.org" (file-name-nondirectory d))))))
                      (heks/notes--dir-subdirs dir))))
         (notes (unless is-root
                  (mapcar (lambda (f)
                            (list (or (alist-get 'title (heks/notes--header f))
                                      (file-name-base f))
                                  (format "./%s" (file-name-nondirectory f))))
                          (heks/notes--dir-notes dir))))
         (by-title (lambda (a b) (string< (downcase (car a)) (downcase (car b)))))
         (item (lambda (s) (format "- [[file:%s][%s]]\n" (cadr s) (car s)))))
    (when (or subs notes is-root)
      (concat
       (when subs (concat "* Topics\n" (mapconcat item (sort subs by-title) "")))
       (when notes (concat "* Notes\n" (mapconcat item (sort notes by-title) "")))))))

(defun heks/notes--index-generated-p (text)
  "Non-nil when TEXT, an index page, is one this module generates."
  (string-match-p (concat "^\\(?:" (regexp-quote heks/notes-index-begin)
                          "\\|# This index is generated\\)")
                  text))

(defun heks/notes--index-head (dir text)
  "Return the parts of the index TEXT of DIR to keep: (HEAD DESCRIPTION TAIL)."
  (let* ((root (heks/notes--root))
         (rel (file-relative-name (directory-file-name dir) root))
         (title (if (string= rel ".") "Notes"
                  (mapconcat #'heks/notes--pretty (split-string rel "/" t) " / "))))
    (if (and text (string-match "\\`\\(\\(?::PROPERTIES:\n\\(?:.*\n\\)*?:END:\n\\)?\\(?:#\\+.*\n\\)+\\)" text))
        (let* ((head (match-string 1 text))
               (rest (substring text (match-end 1)))
               (cut (or (string-match (concat "^\\*\\|" (regexp-quote heks/notes-index-begin)
                                              "\\|# This index") rest)
                        (length rest)))
               (desc (string-trim (substring rest 0 cut))))
          (list head desc
                (cond ((string-match (concat (regexp-quote heks/notes-index-end) "\n") rest)
                       (substring rest (match-end 0)))
                      ((string-match "^\\* Not indexed here\n" rest)
                       (car (split-string (substring rest (match-beginning 0))
                                          "\n# This index" t)))
                      (t ""))))
      (list (concat "#+title: " title "\n"
                    "#+date: " (format-time-string "[%Y-%m-%d %a]") "\n")
            "" ""))))

;;;###autoload
(defun heks/notes-index-update (dir)
  "Regenerate the index page of the notes folder DIR.
Return non-nil when the page was written."
  (let* ((dir (file-name-as-directory (expand-file-name dir)))
         (file (expand-file-name "index.org" dir))
         (old (and (file-exists-p file)
                   (with-temp-buffer (insert-file-contents file) (buffer-string)))))
    (when (and (heks/notes--index-dirs-p dir)
               (or (null old) (heks/notes--index-generated-p old)))
      (when-let* ((body (heks/notes--index-text dir)))
        (pcase-let* ((`(,head ,desc ,tail) (heks/notes--index-head dir old))
                     (new (concat head "\n"
                                  (if (string-empty-p desc) "" (concat desc "\n\n"))
                                  heks/notes-index-begin "\n" body heks/notes-index-end "\n"
                                  (if (string-empty-p (string-trim tail)) "" (concat "\n" (string-trim tail) "\n")))))
          (unless (equal new old)
            (make-directory dir t)
            (write-region new nil file nil 'silent)
            (when-let* ((buf (find-buffer-visiting file)))
              (unless (buffer-modified-p buf)
                (with-current-buffer buf (revert-buffer t t t))))
            t))))))

(defun heks/notes-index-update-up (dir)
  "Regenerate the index of DIR and of every folder above it, up to the root."
  (let ((root (file-name-as-directory (heks/notes--root)))
        (dir (file-name-as-directory (expand-file-name dir))))
    (while (and (string-prefix-p root dir) (heks/notes--index-dirs-p dir))
      (heks/notes-index-update dir)
      (setq dir (file-name-as-directory
                 (file-name-directory (directory-file-name dir)))))))

;;;###autoload
(defun heks/notes-regenerate-indexes ()
  "Regenerate every index page, children first.
Also usable from a shell: emacs --batch -l init.el -f heks/notes-regenerate-indexes"
  (interactive)
  (let* ((root (heks/notes--root))
         (dirs (cons root
                     (seq-filter #'heks/notes--index-dirs-p
                                 (seq-filter #'file-directory-p
                                             (directory-files-recursively
                                              root "" t
                                              (lambda (d) (not (string-match-p "/\\.\\(git\\|metals\\)\\'\\|/diary\\'" d))))))))
         (dirs (seq-remove (lambda (d) (string-match-p "/diary\\(/\\|\\'\\)" d)) dirs))
         (changed 0))
    (dolist (d (sort dirs (lambda (a b) (> (length a) (length b)))))
      (when (heks/notes-index-update d) (cl-incf changed)))
    ;; the archive has its own root page
    (let ((archive (expand-file-name heks/notes-archive-name root)))
      (when (file-directory-p archive)
        (when (heks/notes-index-update archive) (cl-incf changed))))
    (message "Indexes: %d written" changed)))

(defun heks/notes--index-after-save ()
  "Keep the index pages current when a note is saved."
  (when (and buffer-file-name
             (string-suffix-p ".org" buffer-file-name)
             (not (string= (file-name-nondirectory buffer-file-name) "index.org"))
             (heks/notes-directory)
             (file-in-directory-p buffer-file-name (heks/notes--root)))
    (ignore-errors
      (heks/notes-index-update-up (file-name-directory buffer-file-name)))))

(add-hook 'after-save-hook #'heks/notes--index-after-save)

;;; ---- Agenda files ---------------------------------------------------

(defcustom heks/notes-agenda-exclude
  '("\\`bookmarks\\.org\\'" "\\`contacts\\.org\\'" "/index\\.org\\'")
  "Regexps, on the path inside the notes, of notes that are not agenda files.
Notes bigger than `heks/notes-agenda-max-size' are left out too."
  :type '(repeat regexp)
  :group 'heks)

(defcustom heks/notes-agenda-max-size 100000
  "Bytes above which a note is too big to be scanned for the agenda."
  :type 'integer
  :group 'heks)

(defun heks/notes-agenda-files ()
  "Return the notes the agenda reads."
  (let ((root (heks/notes--root)))
    (seq-remove
     (lambda (f)
       (or (> (file-attribute-size (file-attributes f)) heks/notes-agenda-max-size)
           (seq-some (lambda (rx) (string-match-p rx (file-relative-name f root)))
                     heks/notes-agenda-exclude)))
     (heks/notes-files))))

(defun heks/notes--sync-agenda-files (&rest _)
  "Make the notes the agenda reads its files."
  (when (heks/notes-directory)
    (setq org-agenda-files (heks/notes-agenda-files))))

(with-eval-after-load 'org
  (heks/notes--sync-agenda-files)
  (advice-add 'org-agenda :before #'heks/notes--sync-agenda-files))

(global-set-key (kbd "C-c n c") #'heks/notes-capture)
(global-set-key (kbd "C-c n n") #'heks/notes-new)
(global-set-key (kbd "C-c n e") #'heks/notes-extend)
(global-set-key (kbd "C-c n f") #'heks/notes-find)
(global-set-key (kbd "C-c n F") #'heks/notes-find-or-create)
(global-set-key (kbd "C-c n a") #'heks/notes-find-archived)
(global-set-key (kbd "C-c n i") #'heks/notes-insert)
(global-set-key (kbd "C-c n l") #'heks/notes-backlinks)
(global-set-key (kbd "C-c n s") #'heks/notes-search)
(global-set-key (kbd "C-c n r") #'heks/notes-move)
(global-set-key (kbd "C-c n t") #'heks/notes-topic)
(global-set-key (kbd "C-c n I") #'heks/notes-regenerate-indexes)

(provide 'heks/notes)

;;; notes.el ends here
