;;; heks-emacs-keys.el --- Audit the configuration's keybindings  -*- lexical-binding: t -*-

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

;; A keymap is a program with one invariant that is easy to break and
;; invisible when broken: one key, one meaning.  Emacs happily accepts a
;; second definition of the same key, and the only symptom is that the key
;; that used to do X now does Y -- or does nothing at all, because some
;; mode's map answered first.
;;
;; This file reads the configuration's source form by form -- including
;; the `:bind' entries that only take effect when a package finally loads,
;; which a runtime dump of the keymaps cannot see -- and reports:
;;
;;   * the whole key tree, grouped by the scheme's topic letter;
;;   * every two-letter key that means more than one thing;
;;   * every key that is a command in one map and a prefix in another,
;;     where the prefix silently wins;
;;   * every command whose name is claimed by this configuration but
;;     cannot be called, which is what a typo in a binding looks like.
;;
;; Run it on this checkout:
;;
;;   emacs -Q --batch -l test/heks-emacs-keys.el
;;
;; It exits non-zero when it finds a conflict that is not on the list of
;; deliberate ones below, so `maak keys' fails with it.

;;; Code:

(setq load-prefer-newer t)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defconst heks-keys--root
  (file-name-as-directory
   (or (getenv "HEKS_KEYS_SOURCE")
       (expand-file-name "." (file-name-directory (directory-file-name
                                                   (file-name-directory load-file-name))))))
  "The checkout holding the configuration's source.")

(defvar heks-keys--entries nil
  "One entry per binding found in the source, as (KEY MAP COMMAND FILE FORM).")

;;
;; Reading the source.
;;

(defun heks-keys--files ()
  "Return the Elisp files of the configuration."
  (append (directory-files (expand-file-name "src" heks-keys--root) t "\\`[^.#].*\\.el\\'")
          (directory-files (expand-file-name "src/modules" heks-keys--root) t "\\`[^.#].*\\.el\\'")))

(defun heks-keys--key-string (object)
  "Return OBJECT as a key description when it looks like one."
  (cond ((and (stringp object) (string-prefix-p "C-" object)) object)
        ((and (consp object) (memq (car object) '(kbd key-description)))
         (let ((target (cdr object)))
           (cond ((stringp target) target)
                 ((and (consp target) (stringp (car target))) (car target)))))
        (t nil)))

(defun heks-keys--command (object)
  "Return OBJECT as a command symbol when it looks like one."
  (cond ((symbolp object) object)
        ((and (consp object) (memq (car object) '(function quote)))
         (let ((target (cdr object)))
           (cond ((symbolp target) target)
                 ((and (consp target) (symbolp (car target))) (car target)))))
        (t nil)))

(defun heks-keys--record (key map command file form)
  "Remember that in MAP, KEY calls COMMAND, as written in FILE by FORM."
  (when (and key command)
    (push (list key (or map 'global-map) command file form) heks-keys--entries)))

(defun heks-keys--from-bind (bind map file form)
  "Collect the bindings in a `:bind' value BIND, for MAP."
  (cond
   ;; (:map some-map "key" . cmd  or  (:map some-map ("key" . cmd))
   ((and (consp bind) (eq (car bind) :map))
    (let ((target (cadr bind)))
      (dolist (item (cddr bind))
        (heks-keys--from-bind item target file form))))
   ;; ("key" . command)
   ((and (consp bind) (heks-keys--key-string (car bind)))
    (heks-keys--record (heks-keys--key-string (car bind)) map
                       (heks-keys--command (cdr bind)) file form))
   ;; (("key" . command) ("key" . command))
   ((consp bind)
    (let ((tail bind))
      (while (consp tail)
        (heks-keys--from-bind (car tail) map file form)
        (setq tail (cdr tail)))))))

(defun heks-keys--walk (form file)
  "Collect every binding written anywhere in FORM, which came from FILE."
  (when (consp form)
    (let ((head (car form)))
      (cond
       ;; (keymap-set map "key" #'command)
       ((eq head 'keymap-set)
        (heks-keys--record (heks-keys--key-string (nth 2 form))
                           (and (symbolp (nth 1 form)) (nth 1 form))
                           (heks-keys--command (nth 3 form)) file form))
       ;; (define-key map (kbd "key") #'command)
       ((memq head '(define-key global-set-key local-set-key))
        (let ((key (if (eq head 'global-set-key) (nth 1 form) (nth 2 form)))
              (map (unless (eq head 'global-set-key) (nth 1 form)))
              (command (if (eq head 'global-set-key) (nth 2 form) (nth 3 form))))
          (heks-keys--record (heks-keys--key-string key)
                             (and (symbolp map) map)
                             (heks-keys--command command) file form)))
       ;; (define-key-after ...) and friends are not used here.
       ((eq head 'use-package)
        (let ((rest (cdr form)))
          (while rest
            (when (memq (car rest) '(:bind :bind*))
              (heks-keys--from-bind (cadr rest) nil file form))
            (setq rest (cdr rest)))))
       ;; (bind-key "key" #'command map) from bind-key.el
       ((eq head 'bind-key)
        (heks-keys--record (heks-keys--key-string (nth 1 form))
                           (and (symbolp (nth 3 form)) (nth 3 form))
                           (heks-keys--command (nth 2 form)) file form)))
      ;; Anything can hide a binding: a `with-eval-after-load', a `:config'
      ;; block, a `cl-letf'.  Walk the whole form, and stop at a dotted
      ;; tail: `:hook (python-mode . python-black-on-save-mode)' is a pair,
      ;; not a list, and walking it as one is an error.
      (let ((tail form))
        (while (consp tail)
          (heks-keys--walk (car tail) file)
          (setq tail (cdr tail)))))))

(defun heks-keys--read-source ()
  "Fill `heks-keys--entries' from the configuration's source.

A file that cannot be read, or a form the walker chokes on, is reported
and skipped: a binding that was never seen must not be mistaken for a
binding that is not there."
  (setq heks-keys--entries nil)
  (dolist (file (heks-keys--files))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (condition-case err
          (while t
            (let ((form (read (current-buffer))))
              (condition-case walk-error
                  (heks-keys--walk form (file-name-nondirectory file))
                (error
                 (message "  FAIL %s: form at line %d was not walked: %s"
                          (file-name-nondirectory file)
                          (line-number-at-pos) (error-message-string walk-error))
                 (setq heks-keys--failures (1+ heks-keys--failures))))))
        (end-of-file nil)
        (error
         (message "  FAIL %s: could not be read past line %d: %s"
                  (file-name-nondirectory file)
                  (line-number-at-pos) (error-message-string err))
         (setq heks-keys--failures (1+ heks-keys--failures)))))))

;;
;; The scheme.
;;

(defconst heks-keys--fallback-topics
  '(("a" . "API and HTTP")
    ("c" . "containers")
    ("d" . "databases")
    ("e" . "environment")
    ("f" . "fonts and text size")
    ("g" . "Guile and Guix")
    ("h" . "help")
    ("i" . "IDE: the language server, formatting, diagnostics")
    ("j" . "JVM: Maven, Gradle, Spring")
    ("l" . "Emacs itself")
    ("m" . "make-style tasks")
    ("n" . "notes: Org and roam")
    ("o" . "mail")
    ("p" . "completion at point")
    ("r" . "render and preview")
    ("s" . "snippets and macros")
    ("t" . "text tools")
    ("u" . "utilities")
    ("v" . "view: folding and comparisons")
    ("w" . "workspace and project"))
  "The documented topic letters, used when the configuration cannot be loaded.")

;; A key that means two things is not always a mistake.  Every entry here
;; is a decision, with the reason it was made; the audit refuses an
;; unlisted conflict so that a new one cannot slip in unnoticed.
(defconst heks-keys--deliberate
  '(;; In a Java buffer the JDT language server can run and test the
    ;; program itself, which is more accurate than asking Maven to do it
    ;; in a buffer that is not that project's build file.
    ("C-c j r" . "Java buffers run the main class through eglot-java")
    ("C-c j t" . "Java buffers run a test through eglot-java")
    ("C-c j b" . "Java buffers build through eglot-java")
    ("C-c j n" . "Java buffers create a file through eglot-java"))
  "Two-letter keys that deliberately mean different things in different maps.")

;;
;; Checks.
;;

(defvar heks-keys--failures 0)
(defvar heks-keys--warnings 0)

(defun heks-keys--top (key)
  "Return the topic letter of KEY, as a string like \"C-c g\"."
  (when (string-match "\\`C-c \\([^ ]+\\)" key)
    (match-string 1 key)))

(defun heks-keys--two-letter (key)
  "Return the \"C-c X Y\" part of KEY, when KEY has one."
  (when (string-match "\\`\\(C-c [^ ]+ [^ ]+\\)" key)
    (match-string 1 key)))

(defun heks-keys--report ()
  "Print the key tree and the problems found in it."
  (let* ((entries (reverse heks-keys--entries))
         (topics (if (boundp 'heks-emacs-key-topics)
                     heks-emacs-key-topics
                   heks-keys--fallback-topics))
         (by-topic (make-hash-table :test #'equal)))
    (dolist (entry entries)
      (let ((topic (heks-keys--top (car entry))))
        (when topic
          (push entry (gethash topic by-topic)))))
    (message "\n== the key tree ==")
    (dolist (topic (sort (hash-table-keys by-topic) #'string<))
      (let ((description (alist-get topic topics nil nil #'equal)))
        (message "\n  C-c %s  %s" topic (or description "UNDOCUMENTED"))
        (unless description
          (setq heks-keys--failures (1+ heks-keys--failures))
          (message "        ^ no documented meaning for this topic letter"))
        (dolist (entry (sort (reverse (gethash topic by-topic))
                             (lambda (a b) (string< (car a) (car b)))))
          ;; A binding written inside a mode's own map only applies there,
          ;; and that is worth seeing in the report.
          (message "    %-16s %-42s %s"
                   (car entry)
                   (format "%s" (nth 2 entry))
                   (if (eq (nth 1 entry) 'global-map)
                       (nth 3 entry)
                     (format "%s (%s)" (nth 3 entry) (nth 1 entry)))))))

    ;; One key, two meanings.
    (message "\n== keys with more than one meaning ==")
    (let ((by-key (make-hash-table :test #'equal))
          (conflicts 0))
      (dolist (entry (reverse heks-keys--entries))
        (let ((key (heks-keys--two-letter (car entry))))
          (when key (push entry (gethash key by-key)))))
      (dolist (key (sort (hash-table-keys by-key) #'string<))
        (let* ((entries (gethash key by-key))
               (commands (delete-dups (mapcar (lambda (e) (nth 2 e)) entries)))
               (deliberate (assoc key heks-keys--deliberate)))
          (when (> (length commands) 1)
            (setq conflicts (1+ conflicts))
            (if deliberate
                (progn
                  (setq heks-keys--warnings (1+ heks-keys--warnings))
                  (message "  ok   %-12s %s" key (cdr deliberate)))
              (setq heks-keys--failures (1+ heks-keys--failures))
              (message "  FAIL %-12s %s" key (string-join (mapcar #'symbol-name commands) " != "))))))
      (when (zerop conflicts)
        (message "  none")))

    ;; One key, both a command and a prefix: the prefix wins, silently.
    (message "\n== keys that are both a command and a prefix ==")
    (let ((commands (make-hash-table :test #'equal))
          (found 0))
      (dolist (entry (reverse heks-keys--entries))
        (puthash (car entry) (nth 2 entry) commands))
      (dolist (key (sort (hash-table-keys commands) #'string<))
        (let ((as-prefix (seq-filter (lambda (other)
                                       (and (not (equal other key))
                                            (string-prefix-p (concat key " ") other)))
                                     (hash-table-keys commands))))
          (when as-prefix
            (setq found (1+ found))
            (message "  FAIL %-12s does %s, but %s is a prefix underneath it"
                     key (gethash key commands) (car as-prefix))
            (setq heks-keys--failures (1+ heks-keys--failures)))))
      (when (zerop found)
        (message "  none"))))

  ;; A binding whose command does not exist is a typo that which-key
  ;; cannot show and that only fails when the key is pressed.
  (message "\n== bindings this configuration cannot call ==")
  (let ((found 0))
    (dolist (entry (reverse heks-keys--entries))
      (let ((command (nth 2 entry)))
        (when (and (string-prefix-p "heks" (symbol-name command))
                   (not (fboundp command)))
          (setq found (1+ found))
          (message "  FAIL %-16s %s is not defined (%s)"
                   (car entry) command (nth 3 entry))
          (setq heks-keys--failures (1+ heks-keys--failures)))))
    (when (zerop found)
      (message "  none")))

  ;; An action letter that the scheme does not describe is not a mistake by
  ;; itself -- it is a letter the scheme should probably say something
  ;; about -- so it is reported and not counted against the build.
  (message "\n== action letters the scheme does not describe ==")
  (let ((actions (if (boundp 'heks-emacs-key-actions)
                     heks-emacs-key-actions
                   nil))
        (unknown nil))
    (dolist (entry (reverse heks-keys--entries))
      (let* ((two-letter (heks-keys--two-letter (car entry)))
             (action (and two-letter (car (last (split-string two-letter " "))))))
        (when (and action (= (length action) 1)
                   (string-match-p "[a-zA-Z]" action)
                   (not (alist-get (downcase action) actions nil nil #'equal))
                   (not (member action unknown)))
          (push action unknown)
          (message "  note the action letter `%s' is not in `heks-emacs-key-actions'" action))))
    (when (null unknown)
      (message "  none"))))

;;
;; Run.
;;

(defun heks-keys-run ()
  "Audit the configuration and return the number of conflicts found."
  (let* ((dir (file-name-as-directory
               (expand-file-name (or (getenv "HEKS_VERIFY_DIR") "~/.emacs.d/"))))
         (init (expand-file-name "init.el" dir)))
    (setq heks-keys--failures 0
          heks-keys--warnings 0
          default-directory heks-keys--root)
    (heks-keys--read-source)
    (message "== read %d bindings from %d files =="
             (length heks-keys--entries) (length (heks-keys--files)))
    ;; The installed configuration is loaded so that the commands it binds
    ;; can be checked; failing to load it is reported, never fatal here.
    (setq user-emacs-directory dir)
    (condition-case err
        (load init nil t)
      (error (message "  the configuration did not load: %s" (error-message-string err))))
    (heks-keys--report)
    (message "\n== %d failures, %d deliberate %s =="
             heks-keys--failures heks-keys--warnings
             (if (= heks-keys--warnings 1) "conflict" "conflicts"))
    heks-keys--failures))

;; `HEKS_KEYS_NO_RUN' lets another check load this file for its functions,
;; and a dump of every binding read is one variable away when the report
;; looks wrong.
(unless (getenv "HEKS_KEYS_NO_RUN")
  (when (getenv "HEKS_KEYS_DEBUG")
    (heks-keys--read-source)
    (dolist (entry (reverse heks-keys--entries))
      (message "  %-18s %-42s %s" (car entry) (nth 2 entry) (nth 3 entry))))
  (when (> (heks-keys-run) 0)
    (kill-emacs 1)))

;;; heks-emacs-keys.el ends here
