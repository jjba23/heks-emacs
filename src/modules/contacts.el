;;; contacts.el --- Contacts and birthdays kept as an Org file -*- lexical-binding: t -*-

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

;; Contacts are the level-one headings of `contacts.org' in the notes
;; directory, with their details as properties:
;;
;;   * Manon
;;   :PROPERTIES:
;;   :EMAIL:    someone@example.org
;;   :PHONE:    +31 6 12345678
;;   :BIRTHDAY: 1992-11-23
;;   :END:
;;
;; Nothing else is needed to keep them: `heks/contact-find' picks one with the
;; details beside it, `heks/contact-new' adds one, an address is completed in
;; a message from the names here, and every :BIRTHDAY: is in the agenda
;; through the one line of `birthdays.org', `%%(heks/contacts-birthdays)',
;; which asks this file who has a birthday on each day the agenda shows.
;; A birthday is YYYY-MM-DD, or MM-DD when the year is not known.

;;; Code:

(require 'subr-x)
(require 'seq)
(require 'cl-lib)
(require 'calendar)

(declare-function heks/notes--root "notes" ())
(declare-function heks/notes--table "notes" (candidates category annotate &optional sort))
(declare-function heks/notes--annotation "notes" (text))
(declare-function org-mode "org")
(declare-function org-map-entries "org")
(declare-function org-current-level "org")
(declare-function org-get-heading "org")
(declare-function org-entry-get "org")
(declare-function org-show-entry "org-fold")
(declare-function message-in-body-p "message")

(defvar date)

(defun heks/contacts-file ()
  "Return the file the contacts are kept in."
  (expand-file-name "contacts.org" (heks/notes--root)))

(defvar heks/contacts--cache nil
  "A cons of the modification time of the contacts file and what it said.")

(defun heks/contacts--property (name)
  "Return property NAME of the entry at point, or nil when it is empty."
  (let ((value (org-entry-get nil name)))
    (and value (not (string-empty-p (string-trim value))) (string-trim value))))

(defun heks/contacts--read (file)
  "Return the contacts of FILE as a list of plists."
  (with-temp-buffer
    (insert-file-contents file)
    (delay-mode-hooks (org-mode))
    (let (contacts)
      (org-map-entries
       (lambda ()
         (when (= (org-current-level) 1)
           (push (list :name (org-get-heading t t t t)
                       :email (heks/contacts--property "EMAIL")
                       :phone (heks/contacts--property "PHONE")
                       :birthday (heks/contacts--property "BIRTHDAY")
                       :nickname (heks/contacts--property "NICKNAME")
                       :position (point))
                 contacts))))
      (nreverse contacts))))

(defun heks/contacts-all ()
  "Return every contact, reading the file again only when it changed."
  (let* ((file (heks/contacts-file))
         (time (and (file-exists-p file)
                    (file-attribute-modification-time (file-attributes file)))))
    (cond ((null time) nil)
          ((and heks/contacts--cache (equal (car heks/contacts--cache) (cons file time)))
           (cdr heks/contacts--cache))
          (t (let ((contacts (heks/contacts--read file)))
               (setq heks/contacts--cache (cons (cons file time) contacts))
               contacts)))))

(defun heks/contacts-parse-birthday (text)
  "Return TEXT, a birthday, as (YEAR MONTH DAY), with a nil YEAR when unknown.
Return nil when TEXT is not a birthday."
  (when (and text
             (string-match "\\`\\(?:\\([0-9]\\{4\\}\\)-\\|--\\)?\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)\\'"
                           (string-trim text)))
    (let ((year (match-string 1 (string-trim text)))
          (month (string-to-number (match-string 2 (string-trim text))))
          (day (string-to-number (match-string 3 (string-trim text)))))
      (when (and (<= 1 month 12) (<= 1 day 31))
        (list (and year (string-to-number year)) month day)))))

;;;###autoload
(defun heks/contacts-birthdays (&optional _mark)
  "Diary sexp: the birthdays of the contacts that fall on the agenda's `date'.
Written as %%(heks/contacts-birthdays) in an Org file the agenda reads."
  (let ((month (calendar-extract-month date))
        (day (calendar-extract-day date))
        (year (calendar-extract-year date))
        names)
    (dolist (contact (heks/contacts-all))
      (pcase (heks/contacts-parse-birthday (plist-get contact :birthday))
        (`(,born ,m ,d)
         (when (or (and (= m month) (= d day))
                   ;; the 29th of February is kept on the 28th in other years
                   (and (= m 2) (= d 29) (= month 2) (= day 28)
                        (not (calendar-leap-year-p year))))
           (push (format "🎂 %s%s" (plist-get contact :name)
                         (if born (format " (%d)" (- year born)) ""))
                 names)))))
    (and names (mapconcat #'identity (nreverse names) ", "))))

(defun heks/contacts--annotation (contacts)
  "Return the annotation function for the contact names of CONTACTS."
  (lambda (name)
    (let ((contact (seq-find (lambda (c) (equal (plist-get c :name) name)) contacts)))
      (when contact
        (heks/notes--annotation
         (string-join
          (delq nil (list (plist-get contact :email)
                          (plist-get contact :phone)
                          (when-let* ((b (heks/contacts-parse-birthday (plist-get contact :birthday))))
                            (format "🎂 %s" (plist-get contact :birthday)))))
          " · "))))))

(defun heks/contacts--read-name (prompt)
  "Ask for a contact with PROMPT; return the contact's plist."
  (let* ((contacts (or (heks/contacts-all) (user-error "No contacts in %s" (heks/contacts-file))))
         (names (mapcar (lambda (c) (plist-get c :name)) contacts))
         (choice (completing-read prompt
                                  (heks/notes--table names 'heks-contact
                                                     (heks/contacts--annotation contacts))
                                  nil t)))
    (seq-find (lambda (c) (equal (plist-get c :name) choice)) contacts)))

;;;###autoload
(defun heks/contact-find (&optional insert)
  "Find a contact, with their email, phone and birthday beside the name.
Visit the entry; with a prefix argument INSERT, insert `Name <email>' at
point instead, which is what a message wants."
  (interactive "P")
  (let ((contact (heks/contacts--read-name "Contact: ")))
    (if insert
        (insert (if (plist-get contact :email)
                    (format "%s <%s>" (plist-get contact :name) (plist-get contact :email))
                  (plist-get contact :name)))
      (find-file (heks/contacts-file))
      (goto-char (plist-get contact :position))
      (org-show-entry)
      (recenter 2))))

;;;###autoload
(defun heks/contact-new (name &optional email phone birthday)
  "Add the contact NAME, with EMAIL, PHONE and BIRTHDAY, to the contacts file."
  (interactive
   (let* ((name (read-string "Name: "))
          (email (read-string "Email (optional): "))
          (phone (read-string "Phone (optional): "))
          (birthday (read-string "Birthday YYYY-MM-DD or MM-DD (optional): ")))
     (list name email phone birthday)))
  (when (string-empty-p (string-trim name))
    (user-error "A contact needs a name"))
  (when (and birthday (not (string-empty-p birthday))
             (not (heks/contacts-parse-birthday birthday)))
    (user-error "A birthday is YYYY-MM-DD or MM-DD, not `%s'" birthday))
  (when (and (seq-find (lambda (c) (string-equal-ignore-case (plist-get c :name) name))
                       (heks/contacts-all))
             (not (y-or-n-p (format "There is already a %s; add another? " name))))
    (user-error "Cancelled"))
  (let ((details (seq-filter (lambda (p) (and (cdr p) (not (string-empty-p (string-trim (cdr p))))))
                             `(("EMAIL" . ,email) ("PHONE" . ,phone) ("BIRTHDAY" . ,birthday)))))
    (with-current-buffer (find-file-noselect (heks/contacts-file))
      (save-excursion
        (goto-char (point-max))
        (unless (or (bobp) (bolp)) (insert "\n"))
        (insert "* " (string-trim name) "\n")
        (when details
          (insert ":PROPERTIES:\n"
                  (mapconcat (lambda (p) (format ":%s: %s\n" (car p) (string-trim (cdr p)))) details "")
                  ":END:\n")))
      (save-buffer))
    (message "Added %s" name)))

(defun heks/contacts-capf ()
  "Complete a contact's name, in the headers of a message, as `Name <email>'."
  (when (and (or (not (fboundp 'message-in-body-p)) (not (message-in-body-p)))
             (heks/contacts-all))
    (let ((bounds (bounds-of-thing-at-point 'symbol)))
      (list (if bounds (car bounds) (point))
            (if bounds (cdr bounds) (point))
            (mapcar (lambda (c) (format "%s <%s>" (plist-get c :name) (plist-get c :email)))
                    (seq-filter (lambda (c) (plist-get c :email)) (heks/contacts-all)))
            :exclusive 'no))))

(add-hook 'message-mode-hook
          (lambda () (add-hook 'completion-at-point-functions #'heks/contacts-capf nil t)))

(global-set-key (kbd "C-c n k") #'heks/contact-find)
(global-set-key (kbd "C-c n K") #'heks/contact-new)

(provide 'heks/contacts)

;;; contacts.el ends here
