;;; notes-auto.el --- Relations between notes that maintain themselves -*- lexical-binding: t -*-

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

;; Two things a note used to need a person for:
;;
;; Tags.  A note's folders are its tags: `engineering/kubernetes/x.org' is
;; tagged `engineering' and `kubernetes', next to whatever `#+filetags' it
;; has itself.  They are derived whenever they are read (see
;; `heks/notes--folder-tags'), so there is nothing to type and nothing to
;; fix when a note moves.
;;
;; Backlinks.  Every note that other notes link to ends with a generated
;; block listing them:
;;
;;     # BEGIN GENERATED RELATED
;;     * Backlinks
;;     - [[file:../other/note.org][Other note]]
;;     # END GENERATED RELATED
;;
;; Saving a note refreshes the block of every note it links to, or stopped
;; linking to, so one link written by hand shows up at both ends.  The block
;; is rewritten and never edited by hand; the notes map ignores it, so a
;; backlink is not drawn as a second link.  `heks/notes-related-update-all'
;; (C-c n R) brings every note up to date, and also works from a shell:
;;   emacs --batch -l init.el -f heks/notes-related-update-all

;;; Code:

(require 'subr-x)
(require 'seq)
(require 'cl-lib)

(declare-function heks/notes--root "notes" ())
(declare-function heks/notes--header "notes" (file))
(declare-function heks/notes--relative-link "notes" (from to))
(declare-function heks/notes-files "notes" (&optional archive))
(declare-function heks/notes-directory "heks-emacs" ())
(declare-function heks/notes-graph--links "notes-graph" (file))

(defconst heks/notes-related-begin "# BEGIN GENERATED RELATED")
(defconst heks/notes-related-end "# END GENERATED RELATED")

(defcustom heks/notes-related-exclude
  '("\\`\\(?:todo\\|habits\\|birthdays\\|contacts\\|bookmarks\\)\\.org\\'"
    "\\(?:\\`\\|/\\)index\\.org\\'")
  "Regexps, on the path inside the notes, of notes that get no backlinks block.
Notes matching them do not count as a source of backlinks either: the
index pages link to everything, which says nothing."
  :type '(repeat regexp)
  :group 'heks)

(defcustom heks/notes-related-auto t
  "When non-nil, saving a note refreshes the backlinks of the notes it links to."
  :type 'boolean
  :group 'heks)

;;; ---- The links, remembered ---------------------------------------------

(defvar heks/notes-related--cache (make-hash-table :test 'equal)
  "File -> (MODIFICATION-TIME . LINKS), so a scan reads only what changed.")

(defun heks/notes-related--links (file)
  "Return the files FILE links to, remembered until FILE changes."
  (let ((mtime (file-attribute-modification-time (file-attributes file)))
        (hit (gethash file heks/notes-related--cache)))
    (if (and hit (equal (car hit) mtime))
        (cdr hit)
      (let ((links (heks/notes-graph--links file)))
        (puthash file (cons mtime links) heks/notes-related--cache)
        links))))

(defun heks/notes-related--excluded-p (file)
  "Non-nil when FILE takes no part in backlinks."
  (let ((rel (file-relative-name file (heks/notes--root))))
    (seq-some (lambda (rx) (string-match-p rx rel)) heks/notes-related-exclude)))

(defun heks/notes-related--reverse ()
  "Return a hash table: file -> the files that link to it."
  (let ((reverse (make-hash-table :test 'equal)))
    (dolist (src (delete-dups (append (heks/notes-files) (heks/notes-files t))))
      (unless (heks/notes-related--excluded-p src)
        (dolist (target (delete-dups (copy-sequence (heks/notes-related--links src))))
          (unless (equal target src)
            (push src (gethash target reverse))))))
    reverse))

;;; ---- The block ---------------------------------------------------------

(defun heks/notes-related--title (file)
  "Return the title of the note FILE."
  (let ((title (or (alist-get 'title (heks/notes--header file)) (file-name-base file))))
    (replace-regexp-in-string "[][]" (lambda (m) (if (equal m "[") "(" ")")) title)))

(defun heks/notes-related--block (file sources)
  "Return the generated block of FILE for its SOURCES, or nil when none."
  (when sources
    (let ((items (sort (mapcar (lambda (s)
                                 (cons (heks/notes-related--title s)
                                       (heks/notes--relative-link file s)))
                               sources)
                       (lambda (a b) (string< (downcase (car a)) (downcase (car b)))))))
      (concat heks/notes-related-begin "\n* Backlinks\n"
              (mapconcat (lambda (i) (format "- [[file:%s][%s]]\n" (cdr i) (car i))) items "")
              heks/notes-related-end "\n"))))

(defconst heks/notes-related--block-regexp
  (concat "\n*" (regexp-quote heks/notes-related-begin)
          "\n\\(?:.\\|\n\\)*?" (regexp-quote heks/notes-related-end) "\n?"))

(defun heks/notes-related--rewrite (text block)
  "Return TEXT with its generated block replaced by BLOCK (nil removes it)."
  (let ((bare (if (string-match heks/notes-related--block-regexp text)
                  (concat (substring text 0 (match-beginning 0))
                          (substring text (match-end 0)))
                text)))
    (if block
        (concat (string-trim-right bare "\n+") "\n\n" block)
      (if (equal bare text) text (concat (string-trim-right bare "\n+") "\n")))))

(defun heks/notes-related-update (file reverse)
  "Bring the backlinks block of FILE up to date from REVERSE.
Return non-nil when the file was written."
  (when (and (file-regular-p file)
             (not (heks/notes-related--excluded-p file)))
    (let* ((old (with-temp-buffer
                  (let ((coding-system-for-read 'utf-8))
                    (insert-file-contents file))
                  (buffer-string)))
           (new (heks/notes-related--rewrite
                 old (heks/notes-related--block file (gethash file reverse))))
           (buf (find-buffer-visiting file)))
      (cond ((equal old new) nil)
            ((and buf (buffer-modified-p buf))
             (message "Backlinks of %s not refreshed: it has unsaved changes"
                      (file-name-nondirectory file))
             nil)
            (t (let ((coding-system-for-write 'utf-8-unix))
                 (write-region new nil file nil 'silent))
               (puthash file nil heks/notes-related--cache)
               (when buf (with-current-buffer buf (revert-buffer t t t)))
               t)))))

;;;###autoload
(defun heks/notes-related-update-all ()
  "Bring the backlinks block of every note up to date.
Also usable from a shell: emacs --batch -l init.el -f heks/notes-related-update-all"
  (interactive)
  (let ((reverse (heks/notes-related--reverse))
        (changed 0))
    (dolist (f (delete-dups (append (heks/notes-files) (heks/notes-files t))))
      (when (heks/notes-related-update f reverse) (cl-incf changed)))
    (message "Backlinks: %d notes updated" changed)
    changed))

(defun heks/notes-related--after-save ()
  "Refresh the backlinks of what this note links to, and used to link to."
  (when (and heks/notes-related-auto
             buffer-file-name
             (string-suffix-p ".org" buffer-file-name)
             (heks/notes-directory)
             (file-in-directory-p buffer-file-name (heks/notes--root))
             (not (heks/notes-related--excluded-p buffer-file-name)))
    (ignore-errors
      (let* ((file buffer-file-name)
             (before (cdr (gethash file heks/notes-related--cache)))
             (after (heks/notes-related--links file))
             (reverse (heks/notes-related--reverse)))
        (dolist (target (delete-dups (append before after)))
          (unless (equal target file)
            (heks/notes-related-update target reverse)))))))

(add-hook 'after-save-hook #'heks/notes-related--after-save)

(with-eval-after-load 'heks/notes
  (advice-add 'heks/notes-move :after
              (lambda (&rest _) (ignore-errors (heks/notes-related-update-all)))))

(global-set-key (kbd "C-c n R") #'heks/notes-related-update-all)

(provide 'heks/notes-auto)

;;; notes-auto.el ends here
