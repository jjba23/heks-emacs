;;; bookmarks.el --- Web bookmarks kept as an Org file -*- lexical-binding: t -*-

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

;; The bookmarks are `bookmarks.org' in the notes directory: headings are
;; the categories (and may nest), and every Org link under one is a bookmark.
;; The file stays the start page it always was -- nothing here needs a
;; format of its own -- and these commands are the quick way in and out:
;;
;;   `heks/bookmark-open'  pick a bookmark, with its category and host
;;                         beside it, and open it (or copy / insert it)
;;   `heks/bookmark-add'   file the URL at point, in the browser or in the
;;                         kill ring, under a category picked with completion

;;; Code:

(require 'subr-x)
(require 'seq)
(require 'cl-lib)

(declare-function heks/notes--root "notes" ())
(declare-function heks/notes--table "notes" (candidates category annotate &optional sort))
(declare-function heks/notes--annotation "notes" (text))
(declare-function eww-current-url "eww")

(defvar eww-data)

(defun heks/bookmarks-file ()
  "Return the file the bookmarks are kept in."
  (expand-file-name "bookmarks.org" (heks/notes--root)))

(defvar heks/bookmarks--cache nil
  "A cons of the file and its modification time, and the bookmarks read from it.")

(defun heks/bookmarks--read (file)
  "Return the bookmarks of FILE as plists of :title, :url, :category and :line."
  (let ((stack nil) (line 0) result)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (not (eobp))
        (setq line (1+ line))
        (let ((text (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
          (cond
           ((string-match "\\`\\(\\*+\\) +\\(.*?\\) *\\'" text)
            (let ((level (length (match-string 1 text))))
              (setq stack (append (seq-take stack (1- level)) (list (match-string 2 text))))))
           (t
            (let ((start 0))
              (while (string-match "\\[\\[\\(https?://[^]]+\\)\\]\\(?:\\[\\([^]]*\\)\\]\\)?\\]" text start)
                (let ((url (match-string 1 text))
                      (title (match-string 2 text)))
                  (push (list :title (if (and title (not (string-empty-p title))) title url)
                              :url url
                              :category (string-join stack " / ")
                              :line line)
                        result))
                (setq start (match-end 0)))))))
        (forward-line 1)))
    (nreverse result)))

(defun heks/bookmarks-all ()
  "Return every bookmark, reading the file again only when it changed."
  (let* ((file (heks/bookmarks-file))
         (key (and (file-exists-p file)
                   (cons file (file-attribute-modification-time (file-attributes file))))))
    (cond ((null key) nil)
          ((equal (car heks/bookmarks--cache) key) (cdr heks/bookmarks--cache))
          (t (let ((all (heks/bookmarks--read file)))
               (setq heks/bookmarks--cache (cons key all))
               all)))))

(defun heks/bookmarks--host (url)
  "Return the host of URL, without a leading www."
  (string-remove-prefix "www." (or (url-host (url-generic-parse-url url)) "")))

(defun heks/bookmarks--candidates (bookmarks)
  "Return an alist from the names shown to the BOOKMARKS they are for.
Two bookmarks with one title are told apart by their host."
  (let ((seen (make-hash-table :test 'equal)) result)
    (dolist (b bookmarks)
      (let* ((title (plist-get b :title))
             (name (if (gethash title seen)
                       (format "%s (%s)" title (heks/bookmarks--host (plist-get b :url)))
                     title)))
        (puthash title t seen)
        (push (cons name b) result)))
    (nreverse result)))

(defun heks/bookmarks--annotation (candidates)
  "Return the annotation function for the bookmark names of CANDIDATES."
  (lambda (name)
    (when-let* ((b (cdr (assoc name candidates))))
      (heks/notes--annotation
       (string-join (delq nil (list (plist-get b :category)
                                    (heks/bookmarks--host (plist-get b :url))))
                    " · ")))))

;;;###autoload
(defun heks/bookmark-open (&optional how)
  "Pick a bookmark and open it in the browser.
HOW is the prefix argument: with one, copy the URL; with two, insert it as
an Org link at point."
  (interactive "P")
  (let* ((all (or (heks/bookmarks-all) (user-error "No bookmarks in %s" (heks/bookmarks-file))))
         (candidates (heks/bookmarks--candidates all))
         (choice (completing-read "Bookmark: "
                                  (heks/notes--table (mapcar #'car candidates) 'heks-bookmark
                                                     (heks/bookmarks--annotation candidates))
                                  nil t))
         (b (cdr (assoc choice candidates)))
         (url (plist-get b :url)))
    (cond ((equal how '(4)) (kill-new url) (message "Copied %s" url))
          ((equal how '(16)) (insert (format "[[%s][%s]]" url (plist-get b :title))))
          (t (browse-url url)))))

(defun heks/bookmarks--url-here ()
  "Return a URL to offer for a new bookmark: the one at point, in the browser, or copied."
  (or (thing-at-point 'url t)
      (and (derived-mode-p 'eww-mode) (bound-and-true-p eww-data) (plist-get eww-data :url))
      (let ((kill (ignore-errors (current-kill 0 t))))
        (and kill (string-match-p "\\`https?://[^ \n]+\\'" (string-trim kill)) (string-trim kill)))))

(defun heks/bookmarks--page-title (url)
  "Return the title of the page at URL, fetched with a short timeout, or nil."
  (if (and (derived-mode-p 'eww-mode) (bound-and-true-p eww-data)
           (equal (plist-get eww-data :url) url))
      (plist-get eww-data :title)
    (ignore-errors
      (let ((buffer (url-retrieve-synchronously url t t 4)))
        (when buffer
          (unwind-protect
              (with-current-buffer buffer
                (goto-char (point-min))
                (when (re-search-forward "<title[^>]*>\\([^<]*\\)</title>" nil t)
                  (let ((title (decode-coding-string (match-string 1) 'utf-8)))
                    (string-trim (replace-regexp-in-string "[ \t\n]+" " " title)))))
            (kill-buffer buffer)))))))

(defun heks/bookmarks--categories (bookmarks)
  "Return the headings of the bookmarks file as category paths, with counts."
  (let ((counts (make-hash-table :test 'equal)))
    (with-temp-buffer
      (insert-file-contents (heks/bookmarks-file))
      (let (stack)
        (goto-char (point-min))
        (while (re-search-forward "^\\(\\*+\\) +\\(.*?\\) *$" nil t)
          (let ((level (length (match-string 1))))
            (setq stack (append (seq-take stack (1- level)) (list (match-string 2))))
            (puthash (string-join stack " / ") 0 counts)))))
    (dolist (b bookmarks)
      (when (gethash (plist-get b :category) counts)
        (cl-incf (gethash (plist-get b :category) counts))))
    counts))

(defun heks/bookmarks--find-or-make-heading (segment level)
  "Move to the heading SEGMENT of LEVEL inside the current subtree, making it if need be."
  (let ((end (save-excursion (if (> level 1) (progn (org-end-of-subtree t) (point)) (point-max))))
        (regexp (format "^%s +%s *$" (regexp-quote (make-string level ?*)) (regexp-quote segment))))
    (if (re-search-forward regexp end t)
        (beginning-of-line)
      (goto-char end)
      (unless (bolp) (insert "\n"))
      (insert (make-string level ?*) " " segment "\n")
      (forward-line -1))))

(defun heks/bookmarks--insert (url title path)
  "File URL, called TITLE, under the heading PATH (a list of names)."
  (with-current-buffer (find-file-noselect (heks/bookmarks-file))
    (save-excursion
      (org-with-wide-buffer
       (goto-char (point-min))
       (let ((level 0))
         (dolist (segment path)
           (setq level (1+ level))
           (when (> level 1) (org-narrow-to-subtree))
           (heks/bookmarks--find-or-make-heading segment level)
           (widen)))
       (org-back-to-heading t)
       (outline-next-heading)
       (skip-chars-backward " \t\n")
       (insert "\n- " (format "[[%s][%s]]" url title))))
    (save-buffer)))

;;;###autoload
(defun heks/bookmark-add (url title category)
  "File URL, called TITLE, as a bookmark under CATEGORY.
CATEGORY is a heading of the file, or `A / B' for one inside another; a
name that is not there yet makes a new category."
  (interactive
   (let* ((url (read-string "URL: " (heks/bookmarks--url-here)))
          (title (read-string "Title: " (heks/bookmarks--page-title url)))
          (all (heks/bookmarks-all))
          (counts (heks/bookmarks--categories all))
          (names (hash-table-keys counts))
          (category (completing-read
                     "Category (type a new one to create it): "
                     (heks/notes--table
                      names 'heks-bookmark-category
                      (lambda (c)
                        (heks/notes--annotation
                         (if-let* ((n (gethash c counts))) (format "%d bookmarks" n) "new category")))))))
     (list url title category)))
  (require 'org)
  (when (string-empty-p (string-trim url)) (user-error "A bookmark needs a URL"))
  (if-let* ((known (seq-find (lambda (b) (equal (plist-get b :url) url)) (heks/bookmarks-all))))
      (progn (find-file (heks/bookmarks-file))
             (goto-char (point-min))
             (forward-line (1- (plist-get known :line)))
             (message "Already bookmarked, under %s" (plist-get known :category)))
    (heks/bookmarks--insert (string-trim url)
                            (if (string-empty-p (string-trim title)) url (string-trim title))
                            (split-string category " / " t))
    (message "Bookmarked under %s" category)))

(global-set-key (kbd "C-c n b") #'heks/bookmark-open)
(global-set-key (kbd "C-c n B") #'heks/bookmark-add)

(provide 'heks/bookmarks)

;;; bookmarks.el ends here
