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
;;   * the whole key tree, grouped by the scheme's topic letter, with the
;;     meaning of every key read out of the scheme's own tables;
;;   * every two-letter key that means more than one thing;
;;   * every key that is a command in one map and a prefix in another,
;;     where the prefix silently wins;
;;   * every command whose name is claimed by this configuration but
;;     cannot be called, which is what a typo in a binding looks like;
;;   * every letter that neither the action alphabet nor the topic's own
;;     letters describe, which is what an undocumented key looks like;
;;   * every key whose topic has no sentence of its own about it, and
;;     every sentence about a key that is bound nowhere.
;;
;; Run it on this checkout:
;;
;;   emacs -Q --batch -l test/heks-emacs-keys.el
;;   HEKS_KEYS_WRITE=1 emacs -Q --batch -l test/heks-emacs-keys.el
;;
;; The second form writes `docs/keybindings.org', the reference a person
;; reads: every topic, every key under it, and what both letters of it
;; mean.  The file is checked like any other: it is compared with what
;; the configuration says now, so it cannot quietly stop being true.  The
;; tables it is written from are read from the source rather than from
;; the loaded configuration, because they are the thing being written.
;;
;; It exits non-zero when it finds a conflict that is not on the list of
;; deliberate ones below, or a key the scheme does not describe, so
;; `maak keys' fails with it.

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

(defvar heks-keys--tables nil
  "The scheme's own tables, as read from the source: (NAME . VALUE).")

(defconst heks-keys--table-names
  '(heks-emacs-key-topics heks-emacs-key-actions heks-emacs-key-letters
    heks-emacs-key-descriptions)
  "The tables the scheme is written in.")

(defconst heks-keys--reference-file "docs/keybindings.org"
  "The reference this audit writes and checks.")

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
(defun heks-keys--read-tables (form)
  "Remember the scheme table FORM defines, if it defines one.

The tables are read here, from the source, rather than off the loaded
configuration: they are what every key is going to be judged against, and
a configuration that failed to load must not turn that judgement into
something else."
  (when (and (consp form)
             (eq (car form) 'defconst)
             (memq (nth 1 form) heks-keys--table-names))
    (let ((value (nth 2 form)))
      (when (and (consp value) (eq (car value) 'quote) (consp (cdr value)))
        (setq heks-keys--tables
              (cons (cons (nth 1 form) (car (cdr value))) heks-keys--tables))))))

(defun heks-keys--table (name)
  "Return the scheme table called NAME, or nil when it was not read."
  (or (cdr (assq name heks-keys--tables))
      (and (boundp name) (symbol-value name))))

(defun heks-keys--read-source ()
  "Fill `heks-keys--entries' from the configuration's source.

A file that cannot be read, or a form the walker chokes on, is reported
and skipped: a binding that was never seen must not be mistaken for a
binding that is not there."
  (setq heks-keys--entries nil
        heks-keys--tables nil)
  (dolist (file (heks-keys--files))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (condition-case err
          (while t
            (let ((form (read (current-buffer))))
              (heks-keys--read-tables form)
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
;; is a decision, with the reason it was made.  The audit refuses an
;; unlisted conflict so that a new one cannot slip in unnoticed, and it
;; refuses a listed one that no longer means two things, so that this
;; stays a record of decisions rather than of history.
(defconst heks-keys--deliberate
  '(;; In a Java buffer the JDT language server builds and tests the
    ;; program itself, which is more accurate than asking Maven to do it
    ;; from a buffer that is not that project's build file.  Everywhere
    ;; else the two keys are the project's own build tool: the same idea,
    ;; answered by whoever knows the project better.
    ("C-c j b" . "Java buffers build through eglot-java")
    ("C-c j t" . "Java buffers run a test through eglot-java"))
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

(defun heks-keys--letter-of (key)
  "Return the action letter of KEY, when KEY has one.

The last stroke of a two-letter key is its action: `C-c' then the topic,
then what the key does.  A stroke that is not a single letter -- the `SPC'
of the dashboard, a digit -- is not an action letter."
  (let* ((two-letter (heks-keys--two-letter key))
         (letter (and two-letter (car (last (split-string two-letter " "))))))
    (and letter
         (= (length letter) 1)
         (string-match-p "[a-zA-Z]" letter)
         letter)))

(defun heks-keys--letter-meaning (topic letter)
  "Return what LETTER means under TOPIC, or nil when neither table says.

The topic's own letters come first: a topic that names things is the one
that knows what its letters name."
  (or (cdr (assoc letter
                  (cdr (assoc topic (heks-keys--table 'heks-emacs-key-letters) #'equal))
                  #'equal))
      (cdr (assoc letter (heks-keys--table 'heks-emacs-key-actions) #'equal))))

(defun heks-keys--placement (entry)
  "Return where ENTRY's key lives, as the report and the reference show it.

A key written in a mode's own map only works there, which is worth
seeing: it is the difference between a key every buffer has and one that
only a Scheme buffer has.  A map that is not a variable this configuration
can name -- the one a `let' in a package's own setup made -- is called
one."
  (let ((map (nth 1 entry)))
    (cond ((eq map 'global-map) (nth 3 entry))
          ((and (symbolp map) (boundp map) (keymapp (symbol-value map)))
           (format "%s (%s)" (nth 3 entry) map))
          (t (format "%s (a mode's own map)" (nth 3 entry))))))

(defun heks-keys--meaning-of (topic key)
  "Return what KEY does under TOPIC, for the report and the reference.

The key's own description comes first, then what its topic means by its
letter, then what the letter means everywhere, and finally what the topic
is for -- which is what a key whose last stroke is not a letter at all,
the dashboard's `C-c SPC SPC', is left with."
  (or (cdr (assoc key (heks-keys--table 'heks-emacs-key-descriptions) #'equal))
      (let ((letter (heks-keys--letter-of key)))
        (or (and letter (heks-keys--letter-meaning topic letter))
            (cdr (assoc topic (or (heks-keys--table 'heks-emacs-key-topics)
                                  heks-keys--fallback-topics)
                        #'equal))))))

(defun heks-keys--report ()
  "Print the key tree and the problems found in it."
  (let* ((entries (reverse heks-keys--entries))
         (topics (or (heks-keys--table 'heks-emacs-key-topics)
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
          (message "    %-16s %-42s %-34s %s"
                   (car entry)
                   (format "%s" (nth 2 entry))
                   (or (heks-keys--meaning-of topic (car entry)) "")
                   (heks-keys--placement entry)))))

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
        (message "  none"))
      ;; A decision recorded for a conflict that is no longer there is a
      ;; note that has stopped being true, which is how a list of
      ;; exceptions rots into a list nobody reads.
      (dolist (entry heks-keys--deliberate)
        (let ((entries (gethash (car entry) by-key)))
          (unless (and entries
                       (> (length (delete-dups (mapcar (lambda (e) (nth 2 e)) entries))) 1))
            (setq heks-keys--failures (1+ heks-keys--failures))
            (message "  FAIL %-12s is on the list of deliberate conflicts, and means one thing now"
                     (car entry))))))

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

  ;; A letter that neither the action alphabet nor the topic's own letters
  ;; describe is a key nobody can be told about, which is the state this
  ;; whole scheme exists to avoid -- `i' had come to mean an implementation
  ;; under one topic and an interrupt under another -- so it fails here.
  (message "\n== letters the scheme does not describe ==")
  (let ((found 0)
        (letters (heks-keys--table 'heks-emacs-key-letters)))
    (if (not (and letters (heks-keys--table 'heks-emacs-key-actions)))
        (message "  none (the scheme's tables were not read, so this was not checked)")
      (dolist (entry (reverse heks-keys--entries))
        (let* ((key (car entry))
               (topic (heks-keys--top key))
               (letter (heks-keys--letter-of key)))
          (when (and letter (not (heks-keys--letter-meaning topic letter)))
            (setq found (1+ found)
                  heks-keys--failures (1+ heks-keys--failures))
            (message "  FAIL %-12s `%s' means nothing under topic `%s' (%s)"
                     key letter topic (nth 3 entry)))))
      (when (zerop found)
        (message "  none"))))

  ;; A key with no description of its own can only be described by its
  ;; letters, which is what the reference read like before there was a
  ;; table for this: "a menu, or turn the mode on and off" under a key
  ;; that did not turn a mode on.  Every key under `C-c' is written down
  ;; in its topic's own words, and this is what holds the reference to
  ;; that rather than to the reader's patience.
  (message "\n== keys with no description of their own ==")
  (let ((found 0)
        (descriptions (heks-keys--table 'heks-emacs-key-descriptions)))
    (if (not descriptions)
        (message "  none (the scheme's tables were not read, so this was not checked)")
      (dolist (entry (reverse heks-keys--entries))
        (let ((key (car entry)))
          (when (and (heks-keys--top key)
                     (not (assoc key descriptions #'equal)))
            (setq found (1+ found)
                  heks-keys--failures (1+ heks-keys--failures))
            (message "  FAIL %-12s %s is left with its letter's meaning (%s)"
                     key (nth 2 entry) (nth 3 entry)))))
      (when (zerop found)
        (message "  none"))))

  ;; And the other way around: a description of a key nobody binds is a
  ;; sentence about a key that does not exist, which is worse than none,
  ;; because it reads like an answer.
  (message "\n== descriptions of keys that are not bound ==")
  (let ((found 0)
        (descriptions (heks-keys--table 'heks-emacs-key-descriptions)))
    (if (not descriptions)
        (message "  none (the scheme's tables were not read, so this was not checked)")
      (dolist (description descriptions)
        (unless (assoc (car description) (reverse heks-keys--entries))
          (setq found (1+ found)
                heks-keys--failures (1+ heks-keys--failures))
          (message "  FAIL %-12s is described as \"%s\" and bound nowhere"
                   (car description) (cdr description))))
      (when (zerop found)
        (message "  none"))))

  ;; A letter the tables describe and no key uses is documentation that
  ;; has stopped being true.  The reference is written from the keys
  ;; rather than from the tables, so this is a note and not a failure.
  (message "\n== letters the scheme describes and no key uses ==")
  (let ((unused nil))
    (dolist (topic-entry (heks-keys--table 'heks-emacs-key-letters))
      (dolist (letter-entry (cdr topic-entry))
        (unless (seq-find (lambda (entry)
                            (and (equal (heks-keys--top (car entry)) (car topic-entry))
                                 (equal (heks-keys--letter-of (car entry))
                                        (car letter-entry))))
                          (reverse heks-keys--entries))
          (push (format "%s %s" (car topic-entry) (car letter-entry)) unused))))
    (if unused
        (message "  note %s" (string-join (nreverse unused) ", "))
      (message "  none"))))

;;
;; The reference.
;;

(defun heks-keys--diff (actual expected &optional limit)
  "Describe how ACTUAL differs from EXPECTED, line by line.

LIMIT, four by default, is how many differing lines are shown: the point
is a diff one can read, not a full one."
  (let* ((limit (or limit 4))
         (actual-lines (split-string (string-remove-suffix "\n" actual) "\n"))
         (expected-lines (split-string (string-remove-suffix "\n" expected) "\n"))
         (rows (max (length actual-lines) (length expected-lines)))
         (shown 0)
         (found 0))
    (dotimes (index rows)
      (let ((mine (nth index actual-lines))
            (theirs (nth index expected-lines)))
        (unless (equal mine theirs)
          (setq found (1+ found))
          (when (< shown limit)
            (setq shown (1+ shown))
            (message "       %-4s file:  %s" (1+ index)
                     (if mine mine "<nothing: the file ends here>"))
            (message "       %-4s now:   %s" (1+ index)
                     (if theirs theirs "<nothing: the document ends here>"))))))
    (format "%d line%s differ, of %d"
            found (if (= found 1) "" "s") rows)))

(defun heks-keys--reference ()
  "Return `docs/keybindings.org' as the text it should hold.

It is written from the same three tables the audit judges the
configuration by, and from the bindings it read, so it says what the keys
are rather than what they were when somebody last edited it."
  (let ((entries (reverse heks-keys--entries))
        (topics (or (heks-keys--table 'heks-emacs-key-topics)
                    heks-keys--fallback-topics))
        (actions (sort (copy-sequence (heks-keys--table 'heks-emacs-key-actions))
                       (lambda (a b) (string< (car a) (car b)))))
        (letters (heks-keys--table 'heks-emacs-key-letters))
        (by-topic (make-hash-table :test #'equal))
        (out nil))
    (dolist (entry entries)
      (let ((topic (heks-keys--top (car entry))))
        (when topic
          (push entry (gethash topic by-topic)))))
    (cl-labels ((say (&rest rows) (dolist (row rows) (push row out)))
                (description (topic)
                             (or (cdr (assoc topic topics #'equal)) "UNDOCUMENTED"))
                (keys-of (topic)
                         (sort (reverse (gethash topic by-topic))
                               (lambda (a b) (string< (car a) (car b))))))
      (say "#+title: The keybindings 🗝️"
           "#+author: Josep Bigorra"
           "#+options: toc:2"
           ""
           "Everything this configuration adds lives under ~C-c~: a letter for the"
           "topic, then a letter for the action.  This file is written from the"
           "configuration itself, so it says what the keys are rather than what they"
           "were; editing it by hand changes nothing.  Edit the scheme in"
           "~emacs-core.el~ and run =maak keys-update= -- =maak keys= fails while this"
           "file and the configuration disagree."
           ""
           "Every key here says what it does in the topic it is in, in that topic's"
           "own words: `C-c i f' is not \"format\" but \"the buffer, formatted by"
           "whoever knows how\", because the same letter under another topic is a"
           "different formatter.  The alphabet below is what the letters mean; the"
           "keys, further down, are what each one actually does.  =maak keys= fails"
           "when a key has no description of its own, so a new key cannot arrive"
           "described only by a letter."
           ""
           "* The alphabet"
           ""
           "** The action letters, the same under every topic"
           ""
           "| Letter | Meaning |"
           "|--------+---------|")
      (dolist (row actions)
        (say (format "| ~%s~ | %s |" (car row) (cdr row))))
      (say ""
           "** The topic letters"
           ""
           "| Letter | What it is for |"
           "|--------+----------------|")
      (dolist (topic (sort (hash-table-keys by-topic) #'string<))
        (say (format "| ~%s~ | %s |" topic (description topic))))
      (say ""
           "** The letters a topic gives its own meaning"
           ""
           "A few topics key something that is not an action -- a font size, the"
           "configuration being written, the journal entry for today -- and their"
           "letters are the first letter of what they name.  A topic can also say"
           "here that it means something of its own by an action letter: under"
           "~C-c w~ it is ~i~ that initialises the Terraform state, where ~i~ inserts"
           "in every other topic."
           ""
           "| Topic | Letter | What it means here |"
           "|-------+--------+--------------------|")
      (dolist (topic-entry (sort (copy-sequence letters)
                                 (lambda (a b) (string< (car a) (car b)))))
        (dolist (letter-entry (cdr topic-entry))
          (say (format "| ~%s~ | ~%s~ | %s |"
                       (car topic-entry) (car letter-entry) (cdr letter-entry)))))
      (say ""
           "* The keys, by topic")
      (dolist (topic (sort (hash-table-keys by-topic) #'string<))
        (say ""
             (format "** ~C-c %s~ %s" topic (description topic))
             ""
             "| Key | Command | What it does | In |"
             "|-----+---------+--------------+----|")
        (dolist (entry (keys-of topic))
          (say (format "| ~%s~ | ~%s~ | %s | %s |"
                       (car entry)
                       (nth 2 entry)
                       (or (heks-keys--meaning-of topic (car entry)) "")
                       (heks-keys--placement entry))))))
    (concat (string-join (nreverse out) "\n") "\n")))

(defun heks-keys--check-reference ()
  "Write `docs/keybindings.org', or fail when it is not what it should say."
  (let ((file (expand-file-name heks-keys--reference-file heks-keys--root))
        (text (heks-keys--reference)))
    (if (getenv "HEKS_KEYS_WRITE")
        (progn
          (make-directory (file-name-directory file) t)
          (with-temp-file file (insert text))
          (message "\n== wrote %s, %d lines ==" heks-keys--reference-file
                   (length (split-string text "\n"))))
      (message "\n== the reference, %s ==" heks-keys--reference-file)
      (let ((current (if (file-exists-p file)
                         (with-temp-buffer
                           (insert-file-contents file)
                           (buffer-string))
                       "")))
        (if (equal current text)
            (message "  ok   it says what the configuration says")
          (setq heks-keys--failures (1+ heks-keys--failures))
          (message "  FAIL it does not; write it with\n        HEKS_KEYS_WRITE=1 emacs -Q --batch -l test/heks-emacs-keys.el")
          (message "       %s" (heks-keys--diff current text)))))))

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
    (heks-keys--check-reference)
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
