;;; agenda.el --- Todos, habits and the day's agenda over the notes -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Four files at the top of the notes directory make up the personal
;; agenda, and the agenda reads them together with the TODOs written inside
;; any note:
;;
;;   todo.org       the inbox: `C-c n x' captures a todo from anywhere into it
;;   habits.org     TODOs with an `.+1w'-style repeater and `:STYLE: habit',
;;                  drawn as consistency graphs by `org-habit'
;;   birthdays.org  one `%%(heks/contacts-birthdays)' line (see contacts.el)
;;   contacts.org   where the birthdays come from
;;
;; `C-c n d' is today: the agenda for the day with its habits and
;; birthdays, what is in progress, and the inbox.

;;; Code:

(require 'subr-x)

(declare-function heks/notes--root "notes" ())
(declare-function org-agenda "org-agenda")
(declare-function org-capture "org-capture")

(defconst heks/agenda-inbox-heading "Inbox"
  "Heading under which capture templates file new todo entries.")

(defun heks/agenda--file (name)
  "Return the file NAME at the top of the notes directory."
  (expand-file-name name (heks/notes--root)))

(defun heks/agenda--ensure-file (name header)
  "Make the file NAME, with the keyword line HEADER, when it is not there."
  (let ((file (heks/agenda--file name)))
    (unless (file-exists-p file)
      (write-region header nil file nil 'silent))
    file))

(defun heks/agenda--setup ()
  "Set up capture, the habit graphs, refiling and the day's agenda commands."
  (when (heks/notes-directory)
    (require 'org-habit)
    (let ((todo (heks/agenda--file "todo.org"))
          (habits (heks/agenda--file "habits.org"))
          (birthdays (heks/agenda--file "birthdays.org")))
      (setq org-habit-graph-column 62
            org-habit-preceding-days 21
            org-habit-following-days 3
            org-habit-show-habits-only-for-today nil
            org-agenda-skip-scheduled-if-done t
            org-agenda-skip-deadline-if-done t
            org-agenda-window-setup 'current-window
            org-refile-targets `((nil :maxlevel . 2)
                                 ((,todo ,habits) :maxlevel . 2))
            org-refile-use-outline-path 'file
            org-outline-path-complete-in-steps nil
            org-capture-templates
            `(("t" "Todo" entry (file+headline ,todo ,heks/agenda-inbox-heading)
               "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n%i%a\n"
               :empty-lines 0)
              ("h" "Habit" entry (file+headline ,habits "Habits")
               "* TODO %?\nSCHEDULED: <%<%Y-%m-%d %a> %^{Repeat|.+1d|.+2d|.+1w|.+2w|.+1m}>\n:PROPERTIES:\n:STYLE: habit\n:END:\n"
               :empty-lines 0))
            org-agenda-custom-commands
            `(("d" "Today"
               ((agenda "" ((org-agenda-span 1) (org-deadline-warning-days 7)))
                (todo "WIP|REVIEWING" ((org-agenda-overriding-header "In progress")))
                (todo "TODO" ((org-agenda-files (list ,todo))
                              (org-agenda-overriding-header "Inbox")))))
              ("h" "Habits" agenda ""
               ((org-agenda-span 7)
                (org-agenda-files (list ,habits))
                (org-agenda-overriding-header "Habits")))
              ("b" "Birthdays, the next 60 days" agenda ""
               ((org-agenda-span 60)
                (org-agenda-start-day "today")
                (org-agenda-files (list ,birthdays))
                (org-agenda-overriding-header "Birthdays")))
              ("t" "Every todo" alltodo ""
               ((org-agenda-sorting-strategy '(category-keep)))))))))

(with-eval-after-load 'org-agenda
  (heks/agenda--setup))
(with-eval-after-load 'org-capture
  (heks/agenda--setup))

;;;###autoload
(defun heks/agenda-today ()
  "Open today: the day's agenda with its habits and birthdays, then what is in progress and the inbox."
  (interactive)
  (heks/agenda--setup)
  (org-agenda nil "d"))

;;;###autoload
(defun heks/agenda-habits ()
  "Open the habits, with their consistency graphs."
  (interactive)
  (heks/agenda--setup)
  (org-agenda nil "h"))

;;;###autoload
(defun heks/agenda-birthdays ()
  "Open the birthdays of the next 60 days."
  (interactive)
  (heks/agenda--setup)
  (org-agenda nil "b"))

;;;###autoload
(defun heks/todo-capture ()
  "Capture a todo from anywhere into the inbox, linked to where it came from."
  (interactive)
  (heks/agenda--ensure-file "todo.org" (format "#+title: Todo\n\n* %s\n" heks/agenda-inbox-heading))
  (heks/agenda--setup)
  (org-capture nil "t"))

;;;###autoload
(defun heks/habit-capture ()
  "Capture a new habit: a todo that repeats, drawn as a graph in the agenda."
  (interactive)
  (heks/agenda--ensure-file "habits.org" "#+title: Habits\n\n* Habits\n")
  (heks/agenda--setup)
  (org-capture nil "h"))

(global-set-key (kbd "C-c n d") #'heks/agenda-today)
(global-set-key (kbd "C-c n h") #'heks/agenda-habits)
(global-set-key (kbd "C-c n u") #'heks/agenda-birthdays)
(global-set-key (kbd "C-c n x") #'heks/todo-capture)
(global-set-key (kbd "C-c n X") #'heks/habit-capture)

(provide 'heks/agenda)

;;; agenda.el ends here
