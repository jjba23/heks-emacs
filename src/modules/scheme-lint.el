;;; scheme-lint.el --- Common bad practices in Scheme, as Flymake diagnostics -*- lexical-binding: t -*-

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

;; The Guile compiler and `guix lint' (see `modules/guile.el') are the
;; authorities on whether a Scheme file is *sound*: an unbound variable, an
;; arity mismatch, an import that does not resolve.  They are also slow --
;; they load a module tree or read the file from disk -- and they say
;; nothing about the code that works, which is most of it.
;;
;; This module is the other half: the things that work and should not be
;; written.  `(let ((x 1) (x 2)) x)' is not a compile error, and neither is
;; `(eq? "a" "b")' nor a `cond' whose `else' is not last; each of them is
;; either a bug or a habit, and each of them is visible in the text.  The
;; findings are Flymake diagnostics, so they appear in the margin beside
;; the line that has the habit.
;;
;; Two decisions shape it:
;;
;;   * it reads the buffer with a reader of its own, not with `read'.  A
;;     diagnostic has to sit on the form that is wrong, and `read' answers
;;     with a form and no positions -- the line it started on is lost the
;;     moment the form is a list.  So the text is scanned into nodes that
;;     carry the offsets they came from, and there is nothing to guess
;;     about where a problem is: it is where the node is;
;;   * it needs nothing installed.  Every rule is Elisp over those nodes:
;;     no `guile', no `guix', no process, so the check is free and runs in
;;     any Scheme buffer -- a Guix checkout, a channel, a scratch file.
;;
;; A rule is a function of the form it is looking at and the form around
;; it, and it reports what it finds through
;; `heks-emacs-scheme-lint--report'.  `heks-emacs-scheme-lint-rules' is the
;; list of them, and `test/heks-emacs-ert.el' holds each one to a form that
;; should be reported and, more importantly, to the forms around it that
;; should not be: a checker that cries wolf on `(let ((x 1)) x)' is a
;; checker that gets turned off.

;;; Code:

(require 'cl-lib)
(require 'flymake)
(require 'seq)
(require 'subr-x)

(defgroup heks-emacs-scheme-lint nil
  "The bad practices this configuration points out in Scheme."
  :group 'heks-emacs)

(defcustom heks-emacs-scheme-lint-enabled t
  "Whether the bad-practice checker runs in Scheme buffers.

It is Elisp over the buffer's own text, so it costs nothing to leave on;
this is here for a buffer where the findings are not wanted -- a generated
file, or code written in a dialect whose habits are different."
  :type 'boolean
  :group 'heks-emacs-scheme-lint)

;;
;; ====== Reading the buffer, once ======
;;
;; A node is a list: (KIND START END PAYLOAD).  KIND is `list' or `atom';
;; START and END are offsets into the text that was scanned; PAYLOAD is the
;; text of an atom, and for a list the list of its elements.
;;
;; A quote is read as the list it stands for -- `'x' becomes `(quote x)' --
;; with the symbol it is sugar for sitting at the offset of the quote: it
;; was not written there, and it is where the reader would point.

(defvar heks-emacs-scheme-lint--source nil
  "The text being read.")

(defvar heks-emacs-scheme-lint--position 0
  "How far into `heks-emacs-scheme-lint--source' the reader has got.")

(defvar heks-emacs-scheme-lint--depth 0
  "How deep in parentheses the reader is, so a broken file cannot run away.")

(defconst heks-emacs-scheme-lint-max-depth 300
  "How deep a form may nest before the reader gives up on the file.")

(define-error 'heks-emacs-scheme-lint--unterminated
  "The form is not closed")

(define-error 'heks-emacs-scheme-lint--too-deep
  "The forms nest too deeply to read")

(defconst heks-emacs-scheme-lint--delimiters
  " \t\n\r\f()[]\";'`,"
  "The characters that end an atom.")

(defun heks-emacs-scheme-lint--delimiter-p (character)
  "Return whether CHARACTER ends an atom."
  (and character (string-search (char-to-string character)
                                heks-emacs-scheme-lint--delimiters)
       t))

(defun heks-emacs-scheme-lint--char (&optional offset)
  "Return the character OFFSET past the reader, or nil at the end of the text."
  (let ((index (+ heks-emacs-scheme-lint--position (or offset 0))))
    (and (< index (length heks-emacs-scheme-lint--source))
         (aref heks-emacs-scheme-lint--source index))))

(defun heks-emacs-scheme-lint--at (string)
  "Return whether the reader is looking at STRING."
  (let ((end (+ heks-emacs-scheme-lint--position (length string))))
    (and (<= end (length heks-emacs-scheme-lint--source))
         (equal (substring heks-emacs-scheme-lint--source
                           heks-emacs-scheme-lint--position end)
                string))))

(defun heks-emacs-scheme-lint--advance (count)
  "Move the reader COUNT characters forward, and return the new position."
  (setq heks-emacs-scheme-lint--position
        (min (length heks-emacs-scheme-lint--source)
             (+ heks-emacs-scheme-lint--position count))))

(defun heks-emacs-scheme-lint--skip-line ()
  "Move the reader past the end of the line it is on."
  (let ((end (string-search "\n" heks-emacs-scheme-lint--source
                            heks-emacs-scheme-lint--position)))
    (setq heks-emacs-scheme-lint--position
          (or end (length heks-emacs-scheme-lint--source)))))

(defun heks-emacs-scheme-lint--skip-block-comment ()
  "Move the reader past a `#| ... |#' comment, which nests."
  (heks-emacs-scheme-lint--advance 2)
  (let ((level 1))
    (while (and (> level 0) (heks-emacs-scheme-lint--char))
      (cond ((heks-emacs-scheme-lint--at "|#")
             (heks-emacs-scheme-lint--advance 2)
             (setq level (1- level)))
            ((heks-emacs-scheme-lint--at "#|")
             (heks-emacs-scheme-lint--advance 2)
             (setq level (1+ level)))
            (t (heks-emacs-scheme-lint--advance 1))))))

(defun heks-emacs-scheme-lint--skip-fillers ()
  "Move the reader past whitespace, comments and `#;' datum comments."
  (let ((filler t))
    (while filler
      (setq filler nil)
      (let ((character (heks-emacs-scheme-lint--char)))
        (cond
         ((null character))
         ((heks-emacs-scheme-lint--delimiter-p character)
          (if (memq character '(?\( ?\) ?\[ ?\] ?\" ?' ?` ?,))
              nil
            (heks-emacs-scheme-lint--advance 1)
            (setq filler t)))
         ((eq character ?\;)
          (heks-emacs-scheme-lint--skip-line)
          (setq filler t))
         ((heks-emacs-scheme-lint--at "#|")
          (heks-emacs-scheme-lint--skip-block-comment)
          (setq filler t))
         ((heks-emacs-scheme-lint--at "#;")
          ;; The next datum is a comment: read it for its length, and
          ;; keep nothing.
          (heks-emacs-scheme-lint--advance 2)
          (heks-emacs-scheme-lint--read-datum)
          (setq filler t))
         ((and (zerop heks-emacs-scheme-lint--position)
               (heks-emacs-scheme-lint--at "#!"))
          ;; A script's first line, `#!/usr/bin/guile -s'.
          (heks-emacs-scheme-lint--skip-line)
          (setq filler t)))))))

(defun heks-emacs-scheme-lint--read-string (start)
  "Read the string literal that starts at START."
  (heks-emacs-scheme-lint--advance 1)
  (let ((closed nil))
    (while (not closed)
      (let ((character (heks-emacs-scheme-lint--char)))
        (cond ((null character) (setq closed t))
              ((eq character ?\\) (heks-emacs-scheme-lint--advance 2))
              ((eq character ?\") (heks-emacs-scheme-lint--advance 1)
               (setq closed t))
              (t (heks-emacs-scheme-lint--advance 1)))))
    (list 'atom start heks-emacs-scheme-lint--position
          (substring heks-emacs-scheme-lint--source start heks-emacs-scheme-lint--position))))

(defun heks-emacs-scheme-lint--read-character (start)
  "Read the character literal that starts at START, as in `#\\)'."
  (heks-emacs-scheme-lint--advance 2)
  ;; The character after `#\' is part of the literal whatever it is, even
  ;; when it is a parenthesis or a space: `#\(' and `#\space'.
  (when (heks-emacs-scheme-lint--char)
    (heks-emacs-scheme-lint--advance 1))
  (while (let ((character (heks-emacs-scheme-lint--char)))
           (and character
                (or (and (>= character ?a) (<= character ?z))
                    (and (>= character ?A) (<= character ?Z))
                    (and (>= character ?0) (<= character ?9))
                    (eq character ?-))))
    (heks-emacs-scheme-lint--advance 1))
  (list 'atom start heks-emacs-scheme-lint--position
        (substring heks-emacs-scheme-lint--source start heks-emacs-scheme-lint--position)))

(defun heks-emacs-scheme-lint--read-bar-symbol (start)
  "Read the `|symbol with spaces|' that starts at START."
  (heks-emacs-scheme-lint--advance 1)
  (let ((closed nil))
    (while (not closed)
      (let ((character (heks-emacs-scheme-lint--char)))
        (cond ((null character) (setq closed t))
              ((eq character ?|) (heks-emacs-scheme-lint--advance 1)
               (setq closed t))
              (t (heks-emacs-scheme-lint--advance 1)))))
    (list 'atom start heks-emacs-scheme-lint--position
          (substring heks-emacs-scheme-lint--source start heks-emacs-scheme-lint--position))))

(defun heks-emacs-scheme-lint--read-atom (start)
  "Read the atom that starts at START."
  (while (and (heks-emacs-scheme-lint--char)
              (not (heks-emacs-scheme-lint--delimiter-p
                    (heks-emacs-scheme-lint--char))))
    (heks-emacs-scheme-lint--advance 1))
  ;; A lone `.' is the dotted tail of a list, and is read as an atom like
  ;; any other: no rule below reads it, and the list around it keeps its
  ;; elements in the order they were written.
  (list 'atom start heks-emacs-scheme-lint--position
        (substring heks-emacs-scheme-lint--source start heks-emacs-scheme-lint--position)))

(defun heks-emacs-scheme-lint--read-list (start)
  "Read the list that opens at START."
  (heks-emacs-scheme-lint--advance 1)
  (if (> heks-emacs-scheme-lint--depth heks-emacs-scheme-lint-max-depth)
      (signal 'heks-emacs-scheme-lint--too-deep nil)
    (let ((heks-emacs-scheme-lint--depth (1+ heks-emacs-scheme-lint--depth))
          (elements nil)
          (closed nil))
      (while (not closed)
        (heks-emacs-scheme-lint--skip-fillers)
        (let ((character (heks-emacs-scheme-lint--char)))
          (cond
           ((null character) (signal 'heks-emacs-scheme-lint--unterminated nil))
           ((eq character ?\)) (heks-emacs-scheme-lint--advance 1)
            (setq closed t))
           ((eq character ?\]) (heks-emacs-scheme-lint--advance 1)
            (setq closed t))
           (t (let ((before heks-emacs-scheme-lint--position)
                    (element (heks-emacs-scheme-lint--read-datum)))
                (when element (push element elements))
                ;; A reader that consumed nothing would loop here for
                ;; ever; there is nothing left it can consume but a
                ;; character, so it takes one.
                (when (= before heks-emacs-scheme-lint--position)
                  (heks-emacs-scheme-lint--advance 1)))))))
      (list 'list start heks-emacs-scheme-lint--position (nreverse elements)))))

(defun heks-emacs-scheme-lint--read-quoted (start prefix name)
  "Read PREFIX at START as a list whose head is the symbol NAME."
  (heks-emacs-scheme-lint--advance prefix)
  (let ((element (heks-emacs-scheme-lint--read-datum)))
    (if (null element)
        (list 'atom start heks-emacs-scheme-lint--position
              (substring heks-emacs-scheme-lint--source start heks-emacs-scheme-lint--position))
      (list 'list start (nth 2 element)
            (list (list 'atom start start name) element)))))

(defun heks-emacs-scheme-lint--read-datum ()
  "Read one datum at the reader's position, or nil at the end of the text."
  (heks-emacs-scheme-lint--skip-fillers)
  (let ((start heks-emacs-scheme-lint--position)
        (character (heks-emacs-scheme-lint--char)))
    (cond
     ((null character) nil)
     ((eq character ?\() (heks-emacs-scheme-lint--read-list start))
     ((heks-emacs-scheme-lint--at "#(")
      (heks-emacs-scheme-lint--advance 1)
      (heks-emacs-scheme-lint--read-list start))
     ((eq character ?\") (heks-emacs-scheme-lint--read-string start))
     ((heks-emacs-scheme-lint--at "#\\") (heks-emacs-scheme-lint--read-character start))
     ((eq character ?|) (heks-emacs-scheme-lint--read-bar-symbol start))
     ((eq character ?') (heks-emacs-scheme-lint--read-quoted start 1 "quote"))
     ((eq character ?`) (heks-emacs-scheme-lint--read-quoted start 1 "quasiquote"))
     ((eq character ?,)
      (if (heks-emacs-scheme-lint--at ",@")
          (heks-emacs-scheme-lint--read-quoted start 2 "unquote-splicing")
        (heks-emacs-scheme-lint--read-quoted start 1 "unquote")))
     ((memq character '(?\) ?\]))
      ;; A close with nothing open: skip it, so the rest of the file is
      ;; still read and checked.
      (heks-emacs-scheme-lint--advance 1)
      nil)
     (t (heks-emacs-scheme-lint--read-atom start)))))

(defun heks-emacs-scheme-lint-parse (text)
  "Return the top-level forms of TEXT as nodes, as far as they can be read.

A file that ends in the middle of a form yields the forms that were read
before it: the checker describes what it can see, and a file that cannot
be read at all is the compiler's to complain about."
  (let* ((heks-emacs-scheme-lint--source text)
         (heks-emacs-scheme-lint--position 0)
         (heks-emacs-scheme-lint--depth 0)
         (forms nil)
         (reading t))
    (condition-case nil
        (while reading
          (let ((before heks-emacs-scheme-lint--position)
                (form (heks-emacs-scheme-lint--read-datum)))
            (when form (push form forms))
            (when (= before heks-emacs-scheme-lint--position)
              (setq reading nil))))
      ((heks-emacs-scheme-lint--unterminated heks-emacs-scheme-lint--too-deep) nil)
      (error nil))
    (nreverse forms)))

;;
;; ====== What a node is ======
;;

(defun heks-emacs-scheme-lint-list-p (node)
  "Return whether NODE is a list rather than an atom."
  (eq (car-safe node) 'list))

(defun heks-emacs-scheme-lint-elements (node)
  "Return the elements of NODE, or nil when NODE is an atom."
  (and (heks-emacs-scheme-lint-list-p node) (nth 3 node)))

(defun heks-emacs-scheme-lint-start (node)
  "Return the offset NODE starts at."
  (nth 1 node))

(defun heks-emacs-scheme-lint-end (node)
  "Return the offset NODE ends at."
  (nth 2 node))

(defun heks-emacs-scheme-lint-text (node)
  "Return the text of NODE, or nil when NODE is a list."
  (and (eq (car-safe node) 'atom) (nth 3 node)))

(defun heks-emacs-scheme-lint-head (node)
  "Return the text of the head of NODE, or nil when it has none.

The head of a list is what says what the list is: `define', `let', `if'.
A list whose head is itself a list -- `((a b) c)' -- has none."
  (heks-emacs-scheme-lint-text (car (heks-emacs-scheme-lint-elements node))))

(defun heks-emacs-scheme-lint-head-p (node name)
  "Return whether NODE is a list whose head is the symbol NAME."
  (equal (heks-emacs-scheme-lint-head node) name))

(defun heks-emacs-scheme-lint-arguments (node)
  "Return the arguments of NODE: its elements, without the head."
  (cdr (heks-emacs-scheme-lint-elements node)))

(defun heks-emacs-scheme-lint-argument (node index)
  "Return argument INDEX of NODE, counting from zero, or nil."
  (nth index (heks-emacs-scheme-lint-arguments node)))

(defun heks-emacs-scheme-lint-count (node)
  "Return how many arguments NODE has."
  (length (heks-emacs-scheme-lint-arguments node)))

(defun heks-emacs-scheme-lint-symbol-p (node)
  "Return whether NODE is an atom that reads as a symbol.

A number, a string, a character literal and a keyword are atoms that are
not names, and telling them apart is what most rules are made of."
  (let ((text (heks-emacs-scheme-lint-text node)))
    (and text
         (not (string-empty-p text))
         (not (memq (aref text 0) '(?\" ?# ??)))
         (not (string-match-p "\\`[-+]?[0-9]" text))
         (not (string-match-p "\\`[-+]\\(inf\\.0\\|nan\\.0\\)\\'" text))
         (not (string-prefix-p "." text))
         t)))

(defun heks-emacs-scheme-lint-symbol (node)
  "Return NODE's text as a symbol, or nil when it is not a name."
  (when (heks-emacs-scheme-lint-symbol-p node)
    (intern (heks-emacs-scheme-lint-text node))))

(defun heks-emacs-scheme-lint-string-p (node)
  "Return whether NODE is a string literal."
  (let ((text (heks-emacs-scheme-lint-text node)))
    (and text (string-prefix-p "\"" text))))

(defun heks-emacs-scheme-lint-character-p (node)
  "Return whether NODE is a character literal."
  (let ((text (heks-emacs-scheme-lint-text node)))
    (and text (string-prefix-p "#\\" text))))

(defun heks-emacs-scheme-lint-number-p (node)
  "Return whether NODE is a number literal."
  (let ((text (heks-emacs-scheme-lint-text node)))
    (and text
         (not (heks-emacs-scheme-lint-character-p node))
         (string-match-p "\\`\\(#[eEioxXbBdD]\\|#[0-9]*[rR]\\)?[-+]?\\([0-9]\\|\\.\\)"
                         text)
         t)))

(defun heks-emacs-scheme-lint-empty-string-p (node)
  "Return whether NODE is the empty string literal."
  (equal (heks-emacs-scheme-lint-text node) "\"\""))

(defun heks-emacs-scheme-lint-quoted-p (node)
  "Return whether NODE is a `quote' form, which is what `'x' reads as."
  (heks-emacs-scheme-lint-head-p node "quote"))

(defun heks-emacs-scheme-lint-quoted-value (node)
  "Return what NODE quotes, or nil."
  (when (heks-emacs-scheme-lint-quoted-p node)
    (heks-emacs-scheme-lint-argument node 0)))

(defun heks-emacs-scheme-lint-quasiquoted-p (node)
  "Return whether NODE is a `quasiquote' form, which is what a backquote reads as."
  (heks-emacs-scheme-lint-head-p node "quasiquote"))

(defun heks-emacs-scheme-lint-literal-value (node)
  "Return the data NODE quotes or quasiquotes, or nil.

A Guix package writes its inputs one of two ways -- a quasiquoted list of
label-and-package pairs, or `(list pkg)' -- and this is what reads the
first of them as a list of the thing rather than as a form."
  (cond ((heks-emacs-scheme-lint-quoted-p node)
         (heks-emacs-scheme-lint-argument node 0))
        ((heks-emacs-scheme-lint-quasiquoted-p node)
         (heks-emacs-scheme-lint-argument node 0))))

(defun heks-emacs-scheme-lint-same-symbol (one two)
  "Return whether ONE and TWO are the same symbol."
  (let ((first (heks-emacs-scheme-lint-symbol one))
        (second (heks-emacs-scheme-lint-symbol two)))
    (and first second (eq first second))))

;;
;; ====== The findings ======
;;

(defvar heks-emacs-scheme-lint--findings nil
  "The findings of the walk in progress, most recent first.")

(defun heks-emacs-scheme-lint--report (severity node format-string &rest arguments)
  "Record a finding of SEVERITY at NODE, described by FORMAT-STRING.

ARGUMENTS are what FORMAT-STRING is formatted with, as `format' takes
them.  A node with no position of its own -- a symbol a reader made up --
is reported at the position of the form around it."
  (push (list :severity severity
              :start (or (heks-emacs-scheme-lint-start node) 0)
              :end (or (heks-emacs-scheme-lint-end node) 0)
              :message (apply #'format format-string arguments))
        heks-emacs-scheme-lint--findings))

;;
;; ====== The rules ======
;;
;; Each rule is a function of the form it is looking at and of the form
;; around it, called once per form as the buffer is walked.  They are kept
;; apart rather than written as one `cond' so that `heks-emacs-scheme-lint-rules'
;; can be read -- and counted -- as the list of what is checked.
;;

(defconst heks-emacs-scheme-lint-body-forms
  '("when" "unless" "lambda" "λ" "let" "let*" "letrec" "letrec*"
    "let-values" "let*-values" "let-syntax" "letrec-syntax"
    "parameterize" "and" "or" "case" "guard" "begin" "cond-expand"
    "dynamic-wind" "call-with-values" "with-exception-handler"
    "call-with-output-string" "call-with-input-string")
  "The forms whose last arguments are already a body.

A `begin' in one of those says nothing: the form is a sequence already.")

(defun heks-emacs-scheme-lint--rule-begin (node parent)
  "Say that a `begin' in a body is a `begin' too many."
  (when (heks-emacs-scheme-lint-head-p node "begin")
    (let ((elements (heks-emacs-scheme-lint-elements node)))
      (cond
       ((null (cdr elements))
        (heks-emacs-scheme-lint--report
         :warning node "an empty `begin' returns nothing: say what it returns"))
       ((and parent
             (heks-emacs-scheme-lint-list-p parent)
             (member (heks-emacs-scheme-lint-head parent)
                     heks-emacs-scheme-lint-body-forms))
        (heks-emacs-scheme-lint--report
         :note node "`%s' is already a sequence: this `begin' says nothing"
         (heks-emacs-scheme-lint-head parent)))))))

(defun heks-emacs-scheme-lint--rule-cond (node _parent)
  "Say what a `cond' says that cannot work, or says badly."
  (when (heks-emacs-scheme-lint-head-p node "cond")
    (let ((clauses (heks-emacs-scheme-lint-arguments node))
          (index 0)
          (last (1- (heks-emacs-scheme-lint-count node))))
      (dolist (clause clauses)
        (let ((test (car (heks-emacs-scheme-lint-elements clause))))
          (cond
           ((equal (heks-emacs-scheme-lint-text test) "else")
            (unless (= index last)
              (heks-emacs-scheme-lint--report
               :error clause
               "nothing after `else' is ever run: it is the last test or it is the only one")))
           ((and (= index last)
                 (equal (heks-emacs-scheme-lint-text test) "#t"))
            (heks-emacs-scheme-lint--report
             :note test "`else' is how a `cond' says this"))))
        (setq index (1+ index))))))

(defun heks-emacs-scheme-lint--rule-if (node _parent)
  "Say what an `if' says in a longer way than it needs to."
  (when (heks-emacs-scheme-lint-head-p node "if")
    (let* ((arguments (heks-emacs-scheme-lint-arguments node))
           (test (nth 0 arguments))
           (then (nth 1 arguments))
           (else (nth 2 arguments)))
      (cond
       ;; (if c #t #f)
       ((and (equal (heks-emacs-scheme-lint-text then) "#t")
             (equal (heks-emacs-scheme-lint-text else) "#f"))
        (heks-emacs-scheme-lint--report
         :warning node
         "`(if c #t #f)' says `(and c t)': a test is already true or false"))
       ;; (if c #f #t)
       ((and (equal (heks-emacs-scheme-lint-text then) "#f")
             (equal (heks-emacs-scheme-lint-text else) "#t"))
        (heks-emacs-scheme-lint--report
         :warning node "`(if c #f #t)' says `(not c)'"))
       ;; (if (not c) a) has a form of its own
       ((and (heks-emacs-scheme-lint-head-p test "not")
             (null else))
        (heks-emacs-scheme-lint--report
         :note node "`unless' says this without the `not'"))
       ;; (if c (begin a b)) is a `when' that reads as an `if'
       ((and (null else)
             (heks-emacs-scheme-lint-head-p then "begin"))
        (heks-emacs-scheme-lint--report
         :note node "a one-armed `if' with a `begin': `when' says this"))))))

(defun heks-emacs-scheme-lint--rule-lambda-formals (node _parent)
  "Say that a procedure binds one name twice."
  (when (member (heks-emacs-scheme-lint-head node) '("lambda" "λ"))
    (let ((formals (heks-emacs-scheme-lint-argument node 0))
          (seen nil))
      (dolist (formal (heks-emacs-scheme-lint-elements formals))
        (let ((name (heks-emacs-scheme-lint-symbol formal)))
          (when name
            (if (member name seen)
                (heks-emacs-scheme-lint--report
                 :error formal "`%s' is bound twice by this procedure" name)
              (push name seen))))))))

(defun heks-emacs-scheme-lint--rule-definition-formals (node _parent)
  "Say that a definition binds one name twice."
  (when (member (heks-emacs-scheme-lint-head node) '("define" "define*" "define-public"))
    (let ((signature (heks-emacs-scheme-lint-argument node 0))
          (seen nil))
      (when (heks-emacs-scheme-lint-list-p signature)
        (dolist (formal (cdr (heks-emacs-scheme-lint-elements signature)))
          (let ((name (heks-emacs-scheme-lint-symbol formal)))
            (when name
              (if (member name seen)
                  (heks-emacs-scheme-lint--report
                   :error formal "`%s' is bound twice by this definition" name)
                (push name seen)))))))))

(defun heks-emacs-scheme-lint--rule-bindings (node _parent)
  "Say that a `let' binds one name twice, which is how one gets lost."
  (when (member (heks-emacs-scheme-lint-head node) '("let" "letrec" "let-values"))
    (let* ((binding (heks-emacs-scheme-lint-argument node 0))
           (seen nil))
      (dolist (entry (heks-emacs-scheme-lint-elements binding))
        (let ((name (heks-emacs-scheme-lint-symbol
                     (car (heks-emacs-scheme-lint-elements entry)))))
          (when name
            (if (member name seen)
                (heks-emacs-scheme-lint--report
                 :error entry
                 "`%s' is bound twice here: the second binding wins and the first is dead"
                 name)
              (push name seen))))))))

(defun heks-emacs-scheme-lint--rule-definition (node _parent)
  "Say what a definition does not say."
  (when (member (heks-emacs-scheme-lint-head node) '("define" "define-public" "define*"))
    (let ((name (heks-emacs-scheme-lint-argument node 0))
          (count (heks-emacs-scheme-lint-count node)))
      (cond
       ;; (define x)
       ((and (= count 1) (heks-emacs-scheme-lint-symbol-p name))
        (heks-emacs-scheme-lint--report
         :error node "`%s' is defined with no value: nothing is bound"
         (heks-emacs-scheme-lint-text name)))
       ;; (define (f x))
       ((and (= count 1) (heks-emacs-scheme-lint-list-p name))
        (heks-emacs-scheme-lint--report
         :note node "this procedure has no body, so it returns nothing"))))))

(defun heks-emacs-scheme-lint--rule-define-macro (node _parent)
  "Say that `define-macro' is the unhygienic way to write a macro."
  (when (heks-emacs-scheme-lint-head-p node "define-macro")
    (heks-emacs-scheme-lint--report
     :warning node
     "`define-macro' is unhygienic: `define-syntax' with `syntax-rules' is the hygienic one")))

(defun heks-emacs-scheme-lint--rule-nil (node _parent)
  "Say that `nil' is not Scheme."
  (when (and (heks-emacs-scheme-lint-symbol-p node)
             (equal (heks-emacs-scheme-lint-text node) "nil"))
    (heks-emacs-scheme-lint--report
     :warning node "`nil' is not Scheme: the empty list is `'()`")))

(defun heks-emacs-scheme-lint--rule-equality (node _parent)
  "Say that `eq?' is being asked about something it cannot answer for."
  (when (member (heks-emacs-scheme-lint-head node) '("eq?" "eqv?"))
    (let* ((head (heks-emacs-scheme-lint-head node))
           (arguments (heks-emacs-scheme-lint-arguments node)))
      (when (= (length arguments) 2)
        (cond
         ((seq-some #'heks-emacs-scheme-lint-string-p arguments)
          (heks-emacs-scheme-lint--report
           :warning node
           "`%s' on strings compares the objects, not the text: `string=?' is the question"
           head))
         ((and (equal head "eq?")
               (seq-some #'heks-emacs-scheme-lint-number-p arguments))
          (heks-emacs-scheme-lint--report
           :warning node
           "`eq?' on numbers is `eqv?' or `=': two numbers that print alike need not be `eq?'"))
         ((seq-some #'heks-emacs-scheme-lint-character-p arguments)
          (heks-emacs-scheme-lint--report
           :warning node
           "`%s' on characters is `char=?': characters are compared by value"
           head)))))))

(defun heks-emacs-scheme-lint--rule-numeric-equality (node _parent)
  "Say that `=' is being asked about something that is not a number."
  (when (heks-emacs-scheme-lint-head-p node "=")
    (when (seq-some #'heks-emacs-scheme-lint-string-p
                    (heks-emacs-scheme-lint-arguments node))
      (heks-emacs-scheme-lint--report
       :error node "`=' compares numbers: strings are `string=?'"))))

(defun heks-emacs-scheme-lint--rule-assoc (node _parent)
  "Say that a symbol key is `assq''s to answer."
  (when (heks-emacs-scheme-lint-head-p node "assoc")
    (let ((key (heks-emacs-scheme-lint-argument node 0)))
      (when (heks-emacs-scheme-lint-symbol
             (heks-emacs-scheme-lint-quoted-value key))
        (heks-emacs-scheme-lint--report
         :note node "`assq' is the one for a symbol key: it compares the symbols themselves")))))

(defun heks-emacs-scheme-lint--rule-redundant-call (node _parent)
  "Say that a call is the call it wraps."
  (let ((head (heks-emacs-scheme-lint-head node))
        (inner (heks-emacs-scheme-lint-head
                (heks-emacs-scheme-lint-argument node 0))))
    (cond
     ((and (equal head "reverse") (equal inner "reverse")
           (= 1 (heks-emacs-scheme-lint-count node)))
      (heks-emacs-scheme-lint--report
       :warning node "the reverse of a reverse is the list itself"))
     ((and (equal head "list->vector") (equal inner "vector->list"))
      (heks-emacs-scheme-lint--report
       :warning node "the vector itself: the round trip copies it"))
     ((and (equal head "string->symbol") (equal inner "symbol->string"))
      (heks-emacs-scheme-lint--report
       :warning node "the symbol itself: the round trip interns a new one"))
     ((and (equal head "vector->list") (equal inner "list->vector"))
      (heks-emacs-scheme-lint--report
       :warning node "the list itself: the round trip copies it")))))

(defun heks-emacs-scheme-lint--rule-set (node _parent)
  "Say that a `set!' to the name itself says nothing."
  (when (heks-emacs-scheme-lint-head-p node "set!")
    (let ((name (heks-emacs-scheme-lint-argument node 0))
          (value (heks-emacs-scheme-lint-argument node 1)))
      (when (heks-emacs-scheme-lint-same-symbol name value)
        (heks-emacs-scheme-lint--report
         :warning node "`%s' is assigned to itself"
         (heks-emacs-scheme-lint-text name))))))

(defun heks-emacs-scheme-lint--rule-empty-append (node _parent)
  "Say that an append or a concatenation has nothing to append."
  (let ((head (heks-emacs-scheme-lint-head node))
        (arguments (heks-emacs-scheme-lint-arguments node)))
    (cond
     ((and (equal head "string-append")
           (or (null arguments)
               (heks-emacs-scheme-lint-empty-string-p (car arguments))))
      (heks-emacs-scheme-lint--report
       :note node "the empty string adds nothing: `string-append' of nothing is itself"))
     ((and (equal head "append")
           (= 1 (length arguments))
           (heks-emacs-scheme-lint-quoted-p (car arguments))
           (null (heks-emacs-scheme-lint-elements
                  (heks-emacs-scheme-lint-quoted-value (car arguments)))))
      (heks-emacs-scheme-lint--report
       :note node "`(append '() x)' is `x'")))))

(defun heks-emacs-scheme-lint--rule-apply (node _parent)
  "Say that `apply' of a list made here is a call."
  (when (heks-emacs-scheme-lint-head-p node "apply")
    (let ((list (heks-emacs-scheme-lint-argument node (1- (heks-emacs-scheme-lint-count node)))))
      (when (heks-emacs-scheme-lint-head-p list "list")
        (heks-emacs-scheme-lint--report
         :note node "call it with its arguments: `apply' of a fresh list adds nothing")))))

(defun heks-emacs-scheme-lint--rule-eta (node _parent)
  "Say that a procedure that only forwards its arguments is the procedure."
  (when (member (heks-emacs-scheme-lint-head node) '("map" "for-each" "vector-map"))
    (let* ((procedure (heks-emacs-scheme-lint-argument node 0))
           (formals (and (member (heks-emacs-scheme-lint-head procedure) '("lambda" "λ"))
                         (heks-emacs-scheme-lint-argument procedure 0)))
           (body (and formals
                      (heks-emacs-scheme-lint-argument procedure 1)))
           (call-arguments (and body (heks-emacs-scheme-lint-arguments body))))
      (when (and (heks-emacs-scheme-lint-list-p formals)
                 ;; The procedure has exactly one body form, and it is a
                 ;; call of something else with exactly its own names, in
                 ;; the order they were bound.
                 (= 2 (heks-emacs-scheme-lint-count procedure))
                 body
                 (heks-emacs-scheme-lint-list-p body)
                 (heks-emacs-scheme-lint-head body)
                 (equal (length (heks-emacs-scheme-lint-elements formals))
                        (length call-arguments))
                 (cl-every #'heks-emacs-scheme-lint-same-symbol
                           (heks-emacs-scheme-lint-elements formals)
                           call-arguments))
        (heks-emacs-scheme-lint--report
         :note procedure
         "`%s' takes the procedure itself: `(%s %s ...)' says the same"
         (heks-emacs-scheme-lint-head node)
         (heks-emacs-scheme-lint-head node)
         (heks-emacs-scheme-lint-head body))))))

(defun heks-emacs-scheme-lint--rule-deep-composition (node _parent)
  "Say that a chain of five `car's and `cdr's wants a name."
  (when (heks-emacs-scheme-lint-symbol-p node)
    (let ((name (heks-emacs-scheme-lint-text node)))
      ;; Guile defines these up to four letters deep -- `cadddr' and
      ;; `cddddr' are the last of them -- and past that it is a
      ;; composition nobody reads at a glance.
      (when (string-match-p "\\`c[ad]\\{5,\\}r\\'" name)
        (heks-emacs-scheme-lint--report
         :note node
         "`%s' is a composition of %d `car's and `cdr's: name the parts, or use `match'"
         name (- (length name) 2))))))

(defun heks-emacs-scheme-lint--rule-shorter-form (node _parent)
  "Say that a form has a shorter spelling that says the same thing."
  (cond
   ((and (heks-emacs-scheme-lint-head-p node "string=?")
         (seq-some #'heks-emacs-scheme-lint-empty-string-p
                   (heks-emacs-scheme-lint-arguments node)))
    (heks-emacs-scheme-lint--report
     :note node "`string-null?' asks this question"))
   ((and (heks-emacs-scheme-lint-head-p node "with-output-to-string")
         (heks-emacs-scheme-lint-head-p (heks-emacs-scheme-lint-argument node 0) "lambda"))
    (heks-emacs-scheme-lint--report
     :note node "`call-with-output-string' says this without the thunk"))))

(defun heks-emacs-scheme-lint--walk-subtree (node function)
  "Call FUNCTION on NODE and on every form under it."
  (when (heks-emacs-scheme-lint-list-p node)
    (funcall function node)
    (dolist (element (heks-emacs-scheme-lint-elements node))
      (heks-emacs-scheme-lint--walk-subtree element function))))

(defun heks-emacs-scheme-lint--package-clause (package name)
  "Return the value of the NAME clause of PACKAGE, or nil."
  (seq-some (lambda (element)
              (when (heks-emacs-scheme-lint-head-p element name)
                (heks-emacs-scheme-lint-argument element 0)))
            (heks-emacs-scheme-lint-elements package)))

(defun heks-emacs-scheme-lint--rule-guix-tests (node _parent)
  "Say that a Guix package turns its own tests off."
  (when (heks-emacs-scheme-lint-head-p node "package")
    (let ((arguments (heks-emacs-scheme-lint--package-clause node "arguments")))
      (when arguments
        (heks-emacs-scheme-lint--walk-subtree
         arguments
         (lambda (form)
           (let ((elements (heks-emacs-scheme-lint-elements form)))
             (while (and elements (cdr elements))
               (when (and (equal (heks-emacs-scheme-lint-text (car elements)) "#:tests?")
                          (equal (heks-emacs-scheme-lint-text (nth 1 elements)) "#f"))
                 (heks-emacs-scheme-lint--report
                  :warning (car elements)
                  "the tests of this package are turned off: a failure here is one a user meets"))
               (setq elements (cdr elements))))))))))

(defun heks-emacs-scheme-lint--rule-guix-inputs (node _parent)
  "Say that a Guix package spells its inputs the way `guix style' does not."
  (when (heks-emacs-scheme-lint-head-p node "package")
    (catch 'heks-emacs-scheme-lint--old-style
      (dolist (name '("inputs" "native-inputs" "propagated-inputs" "host-inputs"))
        (let ((value (heks-emacs-scheme-lint--package-clause node name)))
          (when value
            (dolist (entry (heks-emacs-scheme-lint-elements
                            (heks-emacs-scheme-lint-literal-value value)))
              (let ((first (car (heks-emacs-scheme-lint-elements entry))))
                (when (and first (heks-emacs-scheme-lint-string-p first)
                           (<= 2 (length (heks-emacs-scheme-lint-elements entry))))
                  (heks-emacs-scheme-lint--report
                   :warning first
                   "old-style input: the label is the package's own name now, so `(list ...)' says it")
                  ;; One finding per package: twenty inputs spelled this
                  ;; way are one habit, not twenty.
                  (throw 'heks-emacs-scheme-lint--old-style t))))))))))

(defconst heks-emacs-scheme-lint-rules
  '(heks-emacs-scheme-lint--rule-begin
    heks-emacs-scheme-lint--rule-cond
    heks-emacs-scheme-lint--rule-if
    heks-emacs-scheme-lint--rule-lambda-formals
    heks-emacs-scheme-lint--rule-definition-formals
    heks-emacs-scheme-lint--rule-bindings
    heks-emacs-scheme-lint--rule-definition
    heks-emacs-scheme-lint--rule-define-macro
    heks-emacs-scheme-lint--rule-nil
    heks-emacs-scheme-lint--rule-equality
    heks-emacs-scheme-lint--rule-numeric-equality
    heks-emacs-scheme-lint--rule-assoc
    heks-emacs-scheme-lint--rule-redundant-call
    heks-emacs-scheme-lint--rule-set
    heks-emacs-scheme-lint--rule-empty-append
    heks-emacs-scheme-lint--rule-apply
    heks-emacs-scheme-lint--rule-eta
    heks-emacs-scheme-lint--rule-deep-composition
    heks-emacs-scheme-lint--rule-shorter-form
    heks-emacs-scheme-lint--rule-guix-tests
    heks-emacs-scheme-lint--rule-guix-inputs)
  "The rules, called once per form as the buffer is walked.

A rule is a function of the form it is looking at and the form around it;
what it finds is recorded with `heks-emacs-scheme-lint--report'.  They are
listed here rather than written as one function so that the list of what
is checked can be read, counted and held to a test.")

(defun heks-emacs-scheme-lint--walk (node parent)
  "Run every rule on NODE, whose form around it is PARENT, and walk into it."
  (dolist (rule heks-emacs-scheme-lint-rules)
    (condition-case error
        (funcall rule node parent)
      ;; A rule that trips over a form it did not expect must not take the
      ;; others with it: a checker that stops checking is worse than one
      ;; that misses a rule.
      (error (message "scheme-lint: %s: %s" rule (error-message-string error)))))
  (when (and (heks-emacs-scheme-lint-list-p node)
             ;; Quoted data is data: `'(nil)' is a list that holds the
             ;; symbol `nil', and no rule here has anything to say about
             ;; data a program might be reading.
             (not (heks-emacs-scheme-lint-quoted-p node)))
    (dolist (element (heks-emacs-scheme-lint-elements node))
      (heks-emacs-scheme-lint--walk element node))))

(defun heks-emacs-scheme-lint-problems (text)
  "Return the bad practices of the Scheme in TEXT, as a list of plists.

Each finding is (:severity :start :end :message), the positions being
offsets into TEXT.  This is the whole checker as a function of a string,
which is what makes it testable without a buffer, a frame or a process."
  (let ((heks-emacs-scheme-lint--findings nil))
    (dolist (form (heks-emacs-scheme-lint-parse text))
      (heks-emacs-scheme-lint--walk form nil))
    (sort (nreverse heks-emacs-scheme-lint--findings)
          (lambda (one two) (< (plist-get one :start) (plist-get two :start))))))

;;
;; ====== Saying it in a buffer ======
;;

(defun heks-emacs-scheme-lint-applies-p (&optional buffer)
  "Return whether the bad practices of BUFFER are this module's to report."
  (with-current-buffer (or buffer (current-buffer))
    (and heks-emacs-scheme-lint-enabled
         (derived-mode-p 'scheme-mode)
         t)))

(defun heks-emacs-scheme-lint-diagnostics (&optional buffer)
  "Return the bad practices of BUFFER as Flymake diagnostics.

Nothing is reported in a buffer that is not Scheme: every finding here is
about code, and code is what a Scheme buffer holds."
  (with-current-buffer (or buffer (current-buffer))
    (if (not (heks-emacs-scheme-lint-applies-p))
        nil
      (let ((text (buffer-substring-no-properties (point-min) (point-max)))
            (origin (point-min)))
        (mapcar (lambda (finding)
                  (flymake-make-diagnostic
                   (current-buffer)
                   (min (point-max) (+ origin (plist-get finding :start)))
                   (min (point-max) (+ origin (plist-get finding :end)))
                   (plist-get finding :severity)
                   (list "Scheme" nil (plist-get finding :message))))
                (heks-emacs-scheme-lint-problems text))))))

(defun heks-emacs-scheme-lint-check (report-fn &rest _arguments)
  "Report the bad practices of the Scheme in this buffer.

This is a Flymake backend, so Flymake calls it.  It answers at once --
there is no process and nothing to wait for -- and says nothing in a
buffer that is not Scheme."
  (funcall report-fn
           (when (heks-emacs-scheme-lint-applies-p)
             (heks-emacs-scheme-lint-diagnostics))))

(defun heks-emacs-scheme-lint-buffer ()
  "List what is worth changing in this Scheme buffer."
  (interactive)
  (unless (heks-emacs-scheme-lint-applies-p)
    (user-error "This buffer is not Scheme"))
  (let ((diagnostics (heks-emacs-scheme-lint-diagnostics)))
    (if (null diagnostics)
        (message "Nothing in this buffer is a habit this checks for")
      (flymake-show-buffer-diagnostics)
      (message "%d thing%s worth changing"
               (length diagnostics)
               (if (= (length diagnostics) 1) "" "s")))))

(provide 'heks-emacs/scheme-lint)

;;; scheme-lint.el ends here
