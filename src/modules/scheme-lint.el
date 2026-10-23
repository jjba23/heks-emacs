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
;; `heks/scheme-lint--report'.  `heks/scheme-lint-rules' is the
;; list of them, and `test/heks-emacs-ert.el' holds each one to a form that
;; should be reported and, more importantly, to the forms around it that
;; should not be: a checker that cries wolf on `(let ((x 1)) x)' is a
;; checker that gets turned off.

;;; Code:

(require 'cl-lib)
(require 'flymake)
(require 'seq)
(require 'subr-x)

(defgroup heks/scheme-lint nil
  "The bad practices this configuration points out in Scheme."
  :group 'heks)

(defcustom heks/scheme-lint-enabled t
  "Whether the bad-practice checker runs in Scheme buffers.

It is Elisp over the buffer's own text, so it costs nothing to leave on;
this is here for a buffer where the findings are not wanted -- a generated
file, or code written in a dialect whose habits are different."
  :type 'boolean
  :group 'heks/scheme-lint)

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

(defvar heks/scheme-lint--source nil
  "The text being read.")

(defvar heks/scheme-lint--position 0
  "How far into `heks/scheme-lint--source' the reader has got.")

(defvar heks/scheme-lint--depth 0
  "How deep in parentheses the reader is, so a broken file cannot run away.")

(defconst heks/scheme-lint-max-depth 300
  "How deep a form may nest before the reader gives up on the file.")

(define-error 'heks/scheme-lint--unterminated
  "The form is not closed")

(define-error 'heks/scheme-lint--too-deep
  "The forms nest too deeply to read")

(defconst heks/scheme-lint--delimiters
  " \t\n\r\f()[]\";'`,"
  "The characters that end an atom.")

(defun heks/scheme-lint--delimiter-p (character)
  "Return whether CHARACTER ends an atom."
  (and character (string-search (char-to-string character)
                                heks/scheme-lint--delimiters)
       t))

(defun heks/scheme-lint--char (&optional offset)
  "Return the character OFFSET past the reader, or nil at the end of the text."
  (let ((index (+ heks/scheme-lint--position (or offset 0))))
    (and (< index (length heks/scheme-lint--source))
         (aref heks/scheme-lint--source index))))

(defun heks/scheme-lint--at (string)
  "Return whether the reader is looking at STRING."
  (let ((end (+ heks/scheme-lint--position (length string))))
    (and (<= end (length heks/scheme-lint--source))
         (equal (substring heks/scheme-lint--source
                           heks/scheme-lint--position end)
                string))))

(defun heks/scheme-lint--advance (count)
  "Move the reader COUNT characters forward, and return the new position."
  (setq heks/scheme-lint--position
        (min (length heks/scheme-lint--source)
             (+ heks/scheme-lint--position count))))

(defun heks/scheme-lint--skip-line ()
  "Move the reader past the end of the line it is on."
  (let ((end (string-search "\n" heks/scheme-lint--source
                            heks/scheme-lint--position)))
    (setq heks/scheme-lint--position
          (or end (length heks/scheme-lint--source)))))

(defun heks/scheme-lint--skip-block-comment ()
  "Move the reader past a `#| ... |#' comment, which nests."
  (heks/scheme-lint--advance 2)
  (let ((level 1))
    (while (and (> level 0) (heks/scheme-lint--char))
      (cond ((heks/scheme-lint--at "|#")
             (heks/scheme-lint--advance 2)
             (setq level (1- level)))
            ((heks/scheme-lint--at "#|")
             (heks/scheme-lint--advance 2)
             (setq level (1+ level)))
            (t (heks/scheme-lint--advance 1))))))

(defun heks/scheme-lint--skip-fillers ()
  "Move the reader past whitespace, comments and `#;' datum comments."
  (let ((filler t))
    (while filler
      (setq filler nil)
      (let ((character (heks/scheme-lint--char)))
        (cond
         ((null character))
         ((heks/scheme-lint--delimiter-p character)
          (if (memq character '(?\( ?\) ?\[ ?\] ?\" ?' ?` ?,))
              nil
            (heks/scheme-lint--advance 1)
            (setq filler t)))
         ((eq character ?\;)
          (heks/scheme-lint--skip-line)
          (setq filler t))
         ((heks/scheme-lint--at "#|")
          (heks/scheme-lint--skip-block-comment)
          (setq filler t))
         ((heks/scheme-lint--at "#;")
          ;; The next datum is a comment: read it for its length, and
          ;; keep nothing.
          (heks/scheme-lint--advance 2)
          (heks/scheme-lint--read-datum)
          (setq filler t))
         ((and (zerop heks/scheme-lint--position)
               (heks/scheme-lint--at "#!"))
          ;; A script's first line, `#!/usr/bin/guile -s'.
          (heks/scheme-lint--skip-line)
          (setq filler t)))))))

(defun heks/scheme-lint--read-string (start)
  "Read the string literal that starts at START."
  (heks/scheme-lint--advance 1)
  (let ((closed nil))
    (while (not closed)
      (let ((character (heks/scheme-lint--char)))
        (cond ((null character) (setq closed t))
              ((eq character ?\\) (heks/scheme-lint--advance 2))
              ((eq character ?\") (heks/scheme-lint--advance 1)
               (setq closed t))
              (t (heks/scheme-lint--advance 1)))))
    (list 'atom start heks/scheme-lint--position
          (substring heks/scheme-lint--source start heks/scheme-lint--position))))

(defun heks/scheme-lint--read-character (start)
  "Read the character literal that starts at START, as in `#\\)'."
  (heks/scheme-lint--advance 2)
  ;; The character after `#\' is part of the literal whatever it is, even
  ;; when it is a parenthesis or a space: `#\(' and `#\space'.
  (when (heks/scheme-lint--char)
    (heks/scheme-lint--advance 1))
  (while (let ((character (heks/scheme-lint--char)))
           (and character
                (or (and (>= character ?a) (<= character ?z))
                    (and (>= character ?A) (<= character ?Z))
                    (and (>= character ?0) (<= character ?9))
                    (eq character ?-))))
    (heks/scheme-lint--advance 1))
  (list 'atom start heks/scheme-lint--position
        (substring heks/scheme-lint--source start heks/scheme-lint--position)))

(defun heks/scheme-lint--read-bar-symbol (start)
  "Read the `|symbol with spaces|' that starts at START."
  (heks/scheme-lint--advance 1)
  (let ((closed nil))
    (while (not closed)
      (let ((character (heks/scheme-lint--char)))
        (cond ((null character) (setq closed t))
              ((eq character ?|) (heks/scheme-lint--advance 1)
               (setq closed t))
              (t (heks/scheme-lint--advance 1)))))
    (list 'atom start heks/scheme-lint--position
          (substring heks/scheme-lint--source start heks/scheme-lint--position))))

(defun heks/scheme-lint--read-atom (start)
  "Read the atom that starts at START."
  (while (and (heks/scheme-lint--char)
              (not (heks/scheme-lint--delimiter-p
                    (heks/scheme-lint--char))))
    (heks/scheme-lint--advance 1))
  ;; A lone `.' is the dotted tail of a list, and is read as an atom like
  ;; any other: no rule below reads it, and the list around it keeps its
  ;; elements in the order they were written.
  (list 'atom start heks/scheme-lint--position
        (substring heks/scheme-lint--source start heks/scheme-lint--position)))

(defun heks/scheme-lint--read-list (start)
  "Read the list that opens at START."
  (heks/scheme-lint--advance 1)
  (if (> heks/scheme-lint--depth heks/scheme-lint-max-depth)
      (signal 'heks/scheme-lint--too-deep nil)
    (let ((heks/scheme-lint--depth (1+ heks/scheme-lint--depth))
          (elements nil)
          (closed nil))
      (while (not closed)
        (heks/scheme-lint--skip-fillers)
        (let ((character (heks/scheme-lint--char)))
          (cond
           ((null character) (signal 'heks/scheme-lint--unterminated nil))
           ((eq character ?\)) (heks/scheme-lint--advance 1)
            (setq closed t))
           ((eq character ?\]) (heks/scheme-lint--advance 1)
            (setq closed t))
           (t (let ((before heks/scheme-lint--position)
                    (element (heks/scheme-lint--read-datum)))
                (when element (push element elements))
                ;; A reader that consumed nothing would loop here for
                ;; ever; there is nothing left it can consume but a
                ;; character, so it takes one.
                (when (= before heks/scheme-lint--position)
                  (heks/scheme-lint--advance 1)))))))
      (list 'list start heks/scheme-lint--position (nreverse elements)))))

(defun heks/scheme-lint--read-quoted (start prefix name)
  "Read PREFIX at START as a list whose head is the symbol NAME."
  (heks/scheme-lint--advance prefix)
  (let ((element (heks/scheme-lint--read-datum)))
    (if (null element)
        (list 'atom start heks/scheme-lint--position
              (substring heks/scheme-lint--source start heks/scheme-lint--position))
      (list 'list start (nth 2 element)
            (list (list 'atom start start name) element)))))

(defun heks/scheme-lint--read-datum ()
  "Read one datum at the reader's position, or nil at the end of the text."
  (heks/scheme-lint--skip-fillers)
  (let ((start heks/scheme-lint--position)
        (character (heks/scheme-lint--char)))
    (cond
     ((null character) nil)
     ((eq character ?\() (heks/scheme-lint--read-list start))
     ((heks/scheme-lint--at "#(")
      (heks/scheme-lint--advance 1)
      (heks/scheme-lint--read-list start))
     ((eq character ?\") (heks/scheme-lint--read-string start))
     ((heks/scheme-lint--at "#\\") (heks/scheme-lint--read-character start))
     ((eq character ?|) (heks/scheme-lint--read-bar-symbol start))
     ((eq character ?') (heks/scheme-lint--read-quoted start 1 "quote"))
     ((eq character ?`) (heks/scheme-lint--read-quoted start 1 "quasiquote"))
     ((eq character ?,)
      (if (heks/scheme-lint--at ",@")
          (heks/scheme-lint--read-quoted start 2 "unquote-splicing")
        (heks/scheme-lint--read-quoted start 1 "unquote")))
     ((memq character '(?\) ?\]))
      ;; A close with nothing open: skip it, so the rest of the file is
      ;; still read and checked.
      (heks/scheme-lint--advance 1)
      nil)
     (t (heks/scheme-lint--read-atom start)))))

(defun heks/scheme-lint-parse (text)
  "Return the top-level forms of TEXT as nodes, as far as they can be read.

A file that ends in the middle of a form yields the forms that were read
before it: the checker describes what it can see, and a file that cannot
be read at all is the compiler's to complain about."
  (let* ((heks/scheme-lint--source text)
         (heks/scheme-lint--position 0)
         (heks/scheme-lint--depth 0)
         (forms nil)
         (reading t))
    (condition-case nil
        (while reading
          (let ((before heks/scheme-lint--position)
                (form (heks/scheme-lint--read-datum)))
            (when form (push form forms))
            (when (= before heks/scheme-lint--position)
              (setq reading nil))))
      ((heks/scheme-lint--unterminated heks/scheme-lint--too-deep) nil)
      (error nil))
    (nreverse forms)))

;;
;; ====== What a node is ======
;;

(defun heks/scheme-lint-list-p (node)
  "Return whether NODE is a list rather than an atom."
  (eq (car-safe node) 'list))

(defun heks/scheme-lint-elements (node)
  "Return the elements of NODE, or nil when NODE is an atom."
  (and (heks/scheme-lint-list-p node) (nth 3 node)))

(defun heks/scheme-lint-start (node)
  "Return the offset NODE starts at."
  (nth 1 node))

(defun heks/scheme-lint-end (node)
  "Return the offset NODE ends at."
  (nth 2 node))

(defun heks/scheme-lint-text (node)
  "Return the text of NODE, or nil when NODE is a list."
  (and (eq (car-safe node) 'atom) (nth 3 node)))

(defun heks/scheme-lint-head (node)
  "Return the text of the head of NODE, or nil when it has none.

The head of a list is what says what the list is: `define', `let', `if'.
A list whose head is itself a list -- `((a b) c)' -- has none."
  (heks/scheme-lint-text (car (heks/scheme-lint-elements node))))

(defun heks/scheme-lint-head-p (node name)
  "Return whether NODE is a list whose head is the symbol NAME."
  (equal (heks/scheme-lint-head node) name))

(defun heks/scheme-lint-arguments (node)
  "Return the arguments of NODE: its elements, without the head."
  (cdr (heks/scheme-lint-elements node)))

(defun heks/scheme-lint-argument (node index)
  "Return argument INDEX of NODE, counting from zero, or nil."
  (nth index (heks/scheme-lint-arguments node)))

(defun heks/scheme-lint-count (node)
  "Return how many arguments NODE has."
  (length (heks/scheme-lint-arguments node)))

(defun heks/scheme-lint-symbol-p (node)
  "Return whether NODE is an atom that reads as a symbol.

A number, a string, a character literal and a keyword are atoms that are
not names, and telling them apart is what most rules are made of."
  (let ((text (heks/scheme-lint-text node)))
    (and text
         (not (string-empty-p text))
         (not (memq (aref text 0) '(?\" ?# ??)))
         (not (string-match-p "\\`[-+]?[0-9]" text))
         (not (string-match-p "\\`[-+]\\(inf\\.0\\|nan\\.0\\)\\'" text))
         (not (string-prefix-p "." text))
         t)))

(defun heks/scheme-lint-symbol (node)
  "Return NODE's text as a symbol, or nil when it is not a name."
  (when (heks/scheme-lint-symbol-p node)
    (intern (heks/scheme-lint-text node))))

(defun heks/scheme-lint-string-p (node)
  "Return whether NODE is a string literal."
  (let ((text (heks/scheme-lint-text node)))
    (and text (string-prefix-p "\"" text))))

(defun heks/scheme-lint-character-p (node)
  "Return whether NODE is a character literal."
  (let ((text (heks/scheme-lint-text node)))
    (and text (string-prefix-p "#\\" text))))

(defun heks/scheme-lint-number-p (node)
  "Return whether NODE is a number literal."
  (let ((text (heks/scheme-lint-text node)))
    (and text
         (not (heks/scheme-lint-character-p node))
         (string-match-p "\\`\\(#[eEioxXbBdD]\\|#[0-9]*[rR]\\)?[-+]?\\([0-9]\\|\\.\\)"
                         text)
         t)))

(defun heks/scheme-lint-empty-string-p (node)
  "Return whether NODE is the empty string literal."
  (equal (heks/scheme-lint-text node) "\"\""))

(defun heks/scheme-lint-quoted-p (node)
  "Return whether NODE is a `quote' form, which is what `'x' reads as."
  (heks/scheme-lint-head-p node "quote"))

(defun heks/scheme-lint-quoted-value (node)
  "Return what NODE quotes, or nil."
  (when (heks/scheme-lint-quoted-p node)
    (heks/scheme-lint-argument node 0)))

(defun heks/scheme-lint-quasiquoted-p (node)
  "Return whether NODE is a `quasiquote' form, which is what a backquote reads as."
  (heks/scheme-lint-head-p node "quasiquote"))

(defun heks/scheme-lint-literal-value (node)
  "Return the data NODE quotes or quasiquotes, or nil.

A Guix package writes its inputs one of two ways -- a quasiquoted list of
label-and-package pairs, or `(list pkg)' -- and this is what reads the
first of them as a list of the thing rather than as a form."
  (cond ((heks/scheme-lint-quoted-p node)
         (heks/scheme-lint-argument node 0))
        ((heks/scheme-lint-quasiquoted-p node)
         (heks/scheme-lint-argument node 0))))

(defun heks/scheme-lint-same-symbol (one two)
  "Return whether ONE and TWO are the same symbol."
  (let ((first (heks/scheme-lint-symbol one))
        (second (heks/scheme-lint-symbol two)))
    (and first second (eq first second))))

;;
;; ====== The findings ======
;;

(defvar heks/scheme-lint--findings nil
  "The findings of the walk in progress, most recent first.")

(defun heks/scheme-lint--report (severity node format-string &rest arguments)
  "Record a finding of SEVERITY at NODE, described by FORMAT-STRING.

ARGUMENTS are what FORMAT-STRING is formatted with, as `format' takes
them.  A node with no position of its own -- a symbol a reader made up --
is reported at the position of the form around it."
  (push (list :severity severity
              :start (or (heks/scheme-lint-start node) 0)
              :end (or (heks/scheme-lint-end node) 0)
              :message (apply #'format format-string arguments))
        heks/scheme-lint--findings))

;;
;; ====== The rules ======
;;
;; Each rule is a function of the form it is looking at and of the form
;; around it, called once per form as the buffer is walked.  They are kept
;; apart rather than written as one `cond' so that `heks/scheme-lint-rules'
;; can be read -- and counted -- as the list of what is checked.
;;

(defconst heks/scheme-lint-body-forms
  '("when" "unless" "lambda" "λ" "let" "let*" "letrec" "letrec*"
    "let-values" "let*-values" "let-syntax" "letrec-syntax"
    "parameterize" "and" "or" "case" "guard" "begin" "cond-expand"
    "dynamic-wind" "call-with-values" "with-exception-handler"
    "call-with-output-string" "call-with-input-string")
  "The forms whose last arguments are already a body.

A `begin' in one of those says nothing: the form is a sequence already.")

(defun heks/scheme-lint--rule-begin (node parent)
  "Say that a `begin' in a body is a `begin' too many."
  (when (heks/scheme-lint-head-p node "begin")
    (let ((elements (heks/scheme-lint-elements node)))
      (cond
       ((null (cdr elements))
        (heks/scheme-lint--report
         :warning node "an empty `begin' returns nothing: say what it returns"))
       ((and parent
             (heks/scheme-lint-list-p parent)
             (member (heks/scheme-lint-head parent)
                     heks/scheme-lint-body-forms))
        (heks/scheme-lint--report
         :note node "`%s' is already a sequence: this `begin' says nothing"
         (heks/scheme-lint-head parent)))))))

(defun heks/scheme-lint--rule-cond (node _parent)
  "Say what a `cond' says that cannot work, or says badly."
  (when (heks/scheme-lint-head-p node "cond")
    (let ((clauses (heks/scheme-lint-arguments node))
          (index 0)
          (last (1- (heks/scheme-lint-count node))))
      (dolist (clause clauses)
        (let ((test (car (heks/scheme-lint-elements clause))))
          (cond
           ((equal (heks/scheme-lint-text test) "else")
            (unless (= index last)
              (heks/scheme-lint--report
               :error clause
               "nothing after `else' is ever run: it is the last test or it is the only one")))
           ((and (= index last)
                 (equal (heks/scheme-lint-text test) "#t"))
            (heks/scheme-lint--report
             :note test "`else' is how a `cond' says this"))))
        (setq index (1+ index))))))

(defun heks/scheme-lint--rule-if (node _parent)
  "Say what an `if' says in a longer way than it needs to."
  (when (heks/scheme-lint-head-p node "if")
    (let* ((arguments (heks/scheme-lint-arguments node))
           (test (nth 0 arguments))
           (then (nth 1 arguments))
           (else (nth 2 arguments)))
      (cond
       ;; (if c #t #f)
       ((and (equal (heks/scheme-lint-text then) "#t")
             (equal (heks/scheme-lint-text else) "#f"))
        (heks/scheme-lint--report
         :warning node
         "`(if c #t #f)' says `(and c t)': a test is already true or false"))
       ;; (if c #f #t)
       ((and (equal (heks/scheme-lint-text then) "#f")
             (equal (heks/scheme-lint-text else) "#t"))
        (heks/scheme-lint--report
         :warning node "`(if c #f #t)' says `(not c)'"))
       ;; (if (not c) a) has a form of its own
       ((and (heks/scheme-lint-head-p test "not")
             (null else))
        (heks/scheme-lint--report
         :note node "`unless' says this without the `not'"))
       ;; (if c (begin a b)) is a `when' that reads as an `if'
       ((and (null else)
             (heks/scheme-lint-head-p then "begin"))
        (heks/scheme-lint--report
         :note node "a one-armed `if' with a `begin': `when' says this"))))))

(defun heks/scheme-lint--rule-lambda-formals (node _parent)
  "Say that a procedure binds one name twice."
  (when (member (heks/scheme-lint-head node) '("lambda" "λ"))
    (let ((formals (heks/scheme-lint-argument node 0))
          (seen nil))
      (dolist (formal (heks/scheme-lint-elements formals))
        (let ((name (heks/scheme-lint-symbol formal)))
          (when name
            (if (member name seen)
                (heks/scheme-lint--report
                 :error formal "`%s' is bound twice by this procedure" name)
              (push name seen))))))))

(defun heks/scheme-lint--rule-definition-formals (node _parent)
  "Say that a definition binds one name twice."
  (when (member (heks/scheme-lint-head node) '("define" "define*" "define-public"))
    (let ((signature (heks/scheme-lint-argument node 0))
          (seen nil))
      (when (heks/scheme-lint-list-p signature)
        (dolist (formal (cdr (heks/scheme-lint-elements signature)))
          (let ((name (heks/scheme-lint-symbol formal)))
            (when name
              (if (member name seen)
                  (heks/scheme-lint--report
                   :error formal "`%s' is bound twice by this definition" name)
                (push name seen)))))))))

(defun heks/scheme-lint--rule-bindings (node _parent)
  "Say that a `let' binds one name twice, which is how one gets lost."
  (when (member (heks/scheme-lint-head node) '("let" "letrec" "let-values"))
    (let* ((binding (heks/scheme-lint-argument node 0))
           (seen nil))
      (dolist (entry (heks/scheme-lint-elements binding))
        (let ((name (heks/scheme-lint-symbol
                     (car (heks/scheme-lint-elements entry)))))
          (when name
            (if (member name seen)
                (heks/scheme-lint--report
                 :error entry
                 "`%s' is bound twice here: the second binding wins and the first is dead"
                 name)
              (push name seen))))))))

(defun heks/scheme-lint--rule-definition (node _parent)
  "Say what a definition does not say."
  (when (member (heks/scheme-lint-head node) '("define" "define-public" "define*"))
    (let ((name (heks/scheme-lint-argument node 0))
          (count (heks/scheme-lint-count node)))
      (cond
       ;; (define x)
       ((and (= count 1) (heks/scheme-lint-symbol-p name))
        (heks/scheme-lint--report
         :error node "`%s' is defined with no value: nothing is bound"
         (heks/scheme-lint-text name)))
       ;; (define (f x))
       ((and (= count 1) (heks/scheme-lint-list-p name))
        (heks/scheme-lint--report
         :note node "this procedure has no body, so it returns nothing"))))))

(defun heks/scheme-lint--rule-define-macro (node _parent)
  "Say that `define-macro' is the unhygienic way to write a macro."
  (when (heks/scheme-lint-head-p node "define-macro")
    (heks/scheme-lint--report
     :warning node
     "`define-macro' is unhygienic: `define-syntax' with `syntax-rules' is the hygienic one")))

(defun heks/scheme-lint--rule-nil (node _parent)
  "Say that `nil' is not Scheme."
  (when (and (heks/scheme-lint-symbol-p node)
             (equal (heks/scheme-lint-text node) "nil"))
    (heks/scheme-lint--report
     :warning node "`nil' is not Scheme: the empty list is `'()`")))

(defun heks/scheme-lint--rule-equality (node _parent)
  "Say that `eq?' is being asked about something it cannot answer for."
  (when (member (heks/scheme-lint-head node) '("eq?" "eqv?"))
    (let* ((head (heks/scheme-lint-head node))
           (arguments (heks/scheme-lint-arguments node)))
      (when (= (length arguments) 2)
        (cond
         ((seq-some #'heks/scheme-lint-string-p arguments)
          (heks/scheme-lint--report
           :warning node
           "`%s' on strings compares the objects, not the text: `string=?' is the question"
           head))
         ((and (equal head "eq?")
               (seq-some #'heks/scheme-lint-number-p arguments))
          (heks/scheme-lint--report
           :warning node
           "`eq?' on numbers is `eqv?' or `=': two numbers that print alike need not be `eq?'"))
         ((seq-some #'heks/scheme-lint-character-p arguments)
          (heks/scheme-lint--report
           :warning node
           "`%s' on characters is `char=?': characters are compared by value"
           head)))))))

(defun heks/scheme-lint--rule-numeric-equality (node _parent)
  "Say that `=' is being asked about something that is not a number."
  (when (heks/scheme-lint-head-p node "=")
    (when (seq-some #'heks/scheme-lint-string-p
                    (heks/scheme-lint-arguments node))
      (heks/scheme-lint--report
       :error node "`=' compares numbers: strings are `string=?'"))))

(defun heks/scheme-lint--rule-assoc (node _parent)
  "Say that a symbol key is `assq''s to answer."
  (when (heks/scheme-lint-head-p node "assoc")
    (let ((key (heks/scheme-lint-argument node 0)))
      (when (heks/scheme-lint-symbol
             (heks/scheme-lint-quoted-value key))
        (heks/scheme-lint--report
         :note node "`assq' is the one for a symbol key: it compares the symbols themselves")))))

(defun heks/scheme-lint--rule-redundant-call (node _parent)
  "Say that a call is the call it wraps."
  (let ((head (heks/scheme-lint-head node))
        (inner (heks/scheme-lint-head
                (heks/scheme-lint-argument node 0))))
    (cond
     ((and (equal head "reverse") (equal inner "reverse")
           (= 1 (heks/scheme-lint-count node)))
      (heks/scheme-lint--report
       :warning node "the reverse of a reverse is the list itself"))
     ((and (equal head "list->vector") (equal inner "vector->list"))
      (heks/scheme-lint--report
       :warning node "the vector itself: the round trip copies it"))
     ((and (equal head "string->symbol") (equal inner "symbol->string"))
      (heks/scheme-lint--report
       :warning node "the symbol itself: the round trip interns a new one"))
     ((and (equal head "vector->list") (equal inner "list->vector"))
      (heks/scheme-lint--report
       :warning node "the list itself: the round trip copies it")))))

(defun heks/scheme-lint--rule-set (node _parent)
  "Say that a `set!' to the name itself says nothing."
  (when (heks/scheme-lint-head-p node "set!")
    (let ((name (heks/scheme-lint-argument node 0))
          (value (heks/scheme-lint-argument node 1)))
      (when (heks/scheme-lint-same-symbol name value)
        (heks/scheme-lint--report
         :warning node "`%s' is assigned to itself"
         (heks/scheme-lint-text name))))))

(defun heks/scheme-lint--rule-empty-append (node _parent)
  "Say that an append or a concatenation has nothing to append."
  (let ((head (heks/scheme-lint-head node))
        (arguments (heks/scheme-lint-arguments node)))
    (cond
     ((and (equal head "string-append")
           (or (null arguments)
               (heks/scheme-lint-empty-string-p (car arguments))))
      (heks/scheme-lint--report
       :note node "the empty string adds nothing: `string-append' of nothing is itself"))
     ((and (equal head "append")
           (= 1 (length arguments))
           (heks/scheme-lint-quoted-p (car arguments))
           (null (heks/scheme-lint-elements
                  (heks/scheme-lint-quoted-value (car arguments)))))
      (heks/scheme-lint--report
       :note node "`(append '() x)' is `x'")))))

(defun heks/scheme-lint--rule-apply (node _parent)
  "Say that `apply' of a list made here is a call."
  (when (heks/scheme-lint-head-p node "apply")
    (let ((list (heks/scheme-lint-argument node (1- (heks/scheme-lint-count node)))))
      (when (heks/scheme-lint-head-p list "list")
        (heks/scheme-lint--report
         :note node "call it with its arguments: `apply' of a fresh list adds nothing")))))

(defun heks/scheme-lint--rule-eta (node _parent)
  "Say that a procedure that only forwards its arguments is the procedure."
  (when (member (heks/scheme-lint-head node) '("map" "for-each" "vector-map"))
    (let* ((procedure (heks/scheme-lint-argument node 0))
           (formals (and (member (heks/scheme-lint-head procedure) '("lambda" "λ"))
                         (heks/scheme-lint-argument procedure 0)))
           (body (and formals
                      (heks/scheme-lint-argument procedure 1)))
           (call-arguments (and body (heks/scheme-lint-arguments body))))
      (when (and (heks/scheme-lint-list-p formals)
                 ;; The procedure has exactly one body form, and it is a
                 ;; call of something else with exactly its own names, in
                 ;; the order they were bound.
                 (= 2 (heks/scheme-lint-count procedure))
                 body
                 (heks/scheme-lint-list-p body)
                 (heks/scheme-lint-head body)
                 (equal (length (heks/scheme-lint-elements formals))
                        (length call-arguments))
                 (cl-every #'heks/scheme-lint-same-symbol
                           (heks/scheme-lint-elements formals)
                           call-arguments))
        (heks/scheme-lint--report
         :note procedure
         "`%s' takes the procedure itself: `(%s %s ...)' says the same"
         (heks/scheme-lint-head node)
         (heks/scheme-lint-head node)
         (heks/scheme-lint-head body))))))

(defun heks/scheme-lint--rule-deep-composition (node _parent)
  "Say that a chain of five `car's and `cdr's wants a name."
  (when (heks/scheme-lint-symbol-p node)
    (let ((name (heks/scheme-lint-text node)))
      ;; Guile defines these up to four letters deep -- `cadddr' and
      ;; `cddddr' are the last of them -- and past that it is a
      ;; composition nobody reads at a glance.
      (when (string-match-p "\\`c[ad]\\{5,\\}r\\'" name)
        (heks/scheme-lint--report
         :note node
         "`%s' is a composition of %d `car's and `cdr's: name the parts, or use `match'"
         name (- (length name) 2))))))

(defun heks/scheme-lint--rule-shorter-form (node _parent)
  "Say that a form has a shorter spelling that says the same thing."
  (cond
   ((and (heks/scheme-lint-head-p node "string=?")
         (seq-some #'heks/scheme-lint-empty-string-p
                   (heks/scheme-lint-arguments node)))
    (heks/scheme-lint--report
     :note node "`string-null?' asks this question"))
   ((and (heks/scheme-lint-head-p node "with-output-to-string")
         (heks/scheme-lint-head-p (heks/scheme-lint-argument node 0) "lambda"))
    (heks/scheme-lint--report
     :note node "`call-with-output-string' says this without the thunk"))))

(defun heks/scheme-lint--walk-subtree (node function)
  "Call FUNCTION on NODE and on every form under it."
  (when (heks/scheme-lint-list-p node)
    (funcall function node)
    (dolist (element (heks/scheme-lint-elements node))
      (heks/scheme-lint--walk-subtree element function))))

(defun heks/scheme-lint--package-clause (package name)
  "Return the value of the NAME clause of PACKAGE, or nil."
  (seq-some (lambda (element)
              (when (heks/scheme-lint-head-p element name)
                (heks/scheme-lint-argument element 0)))
            (heks/scheme-lint-elements package)))

(defun heks/scheme-lint--rule-guix-tests (node _parent)
  "Say that a Guix package turns its own tests off."
  (when (heks/scheme-lint-head-p node "package")
    (let ((arguments (heks/scheme-lint--package-clause node "arguments")))
      (when arguments
        (heks/scheme-lint--walk-subtree
         arguments
         (lambda (form)
           (let ((elements (heks/scheme-lint-elements form)))
             (while (and elements (cdr elements))
               (when (and (equal (heks/scheme-lint-text (car elements)) "#:tests?")
                          (equal (heks/scheme-lint-text (nth 1 elements)) "#f"))
                 (heks/scheme-lint--report
                  :warning (car elements)
                  "the tests of this package are turned off: a failure here is one a user meets"))
               (setq elements (cdr elements))))))))))

(defun heks/scheme-lint--rule-guix-inputs (node _parent)
  "Say that a Guix package spells its inputs the way `guix style' does not."
  (when (heks/scheme-lint-head-p node "package")
    (catch 'heks/scheme-lint--old-style
      (dolist (name '("inputs" "native-inputs" "propagated-inputs" "host-inputs"))
        (let ((value (heks/scheme-lint--package-clause node name)))
          (when value
            (dolist (entry (heks/scheme-lint-elements
                            (heks/scheme-lint-literal-value value)))
              (let ((first (car (heks/scheme-lint-elements entry))))
                (when (and first (heks/scheme-lint-string-p first)
                           (<= 2 (length (heks/scheme-lint-elements entry))))
                  (heks/scheme-lint--report
                   :warning first
                   "old-style input: the label is the package's own name now, so `(list ...)' says it")
                  ;; One finding per package: twenty inputs spelled this
                  ;; way are one habit, not twenty.
                  (throw 'heks/scheme-lint--old-style t))))))))))

(defconst heks/scheme-lint-rules
  '(heks/scheme-lint--rule-begin
    heks/scheme-lint--rule-cond
    heks/scheme-lint--rule-if
    heks/scheme-lint--rule-lambda-formals
    heks/scheme-lint--rule-definition-formals
    heks/scheme-lint--rule-bindings
    heks/scheme-lint--rule-definition
    heks/scheme-lint--rule-define-macro
    heks/scheme-lint--rule-nil
    heks/scheme-lint--rule-equality
    heks/scheme-lint--rule-numeric-equality
    heks/scheme-lint--rule-assoc
    heks/scheme-lint--rule-redundant-call
    heks/scheme-lint--rule-set
    heks/scheme-lint--rule-empty-append
    heks/scheme-lint--rule-apply
    heks/scheme-lint--rule-eta
    heks/scheme-lint--rule-deep-composition
    heks/scheme-lint--rule-shorter-form
    heks/scheme-lint--rule-guix-tests
    heks/scheme-lint--rule-guix-inputs)
  "The rules, called once per form as the buffer is walked.

A rule is a function of the form it is looking at and the form around it;
what it finds is recorded with `heks/scheme-lint--report'.  They are
listed here rather than written as one function so that the list of what
is checked can be read, counted and held to a test.")

(defun heks/scheme-lint--walk (node parent)
  "Run every rule on NODE, whose form around it is PARENT, and walk into it."
  (dolist (rule heks/scheme-lint-rules)
    (condition-case error
        (funcall rule node parent)
      ;; A rule that trips over a form it did not expect must not take the
      ;; others with it: a checker that stops checking is worse than one
      ;; that misses a rule.
      (error (message "scheme-lint: %s: %s" rule (error-message-string error)))))
  (when (and (heks/scheme-lint-list-p node)
             ;; Quoted data is data: `'(nil)' is a list that holds the
             ;; symbol `nil', and no rule here has anything to say about
             ;; data a program might be reading.
             (not (heks/scheme-lint-quoted-p node)))
    (dolist (element (heks/scheme-lint-elements node))
      (heks/scheme-lint--walk element node))))

(defun heks/scheme-lint-problems (text)
  "Return the bad practices of the Scheme in TEXT, as a list of plists.

Each finding is (:severity :start :end :message), the positions being
offsets into TEXT.  This is the whole checker as a function of a string,
which is what makes it testable without a buffer, a frame or a process."
  (let ((heks/scheme-lint--findings nil))
    (dolist (form (heks/scheme-lint-parse text))
      (heks/scheme-lint--walk form nil))
    (sort (nreverse heks/scheme-lint--findings)
          (lambda (one two) (< (plist-get one :start) (plist-get two :start))))))

;;
;; ====== Saying it in a buffer ======
;;

(defun heks/scheme-lint-applies-p (&optional buffer)
  "Return whether the bad practices of BUFFER are this module's to report."
  (with-current-buffer (or buffer (current-buffer))
    (and heks/scheme-lint-enabled
         (derived-mode-p 'scheme-mode)
         t)))

(defun heks/scheme-lint-diagnostics (&optional buffer)
  "Return the bad practices of BUFFER as Flymake diagnostics.

Nothing is reported in a buffer that is not Scheme: every finding here is
about code, and code is what a Scheme buffer holds."
  (with-current-buffer (or buffer (current-buffer))
    (if (not (heks/scheme-lint-applies-p))
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
                (heks/scheme-lint-problems text))))))

(defun heks/scheme-lint-check (report-fn &rest _arguments)
  "Report the bad practices of the Scheme in this buffer.

This is a Flymake backend, so Flymake calls it.  It answers at once --
there is no process and nothing to wait for -- and says nothing in a
buffer that is not Scheme."
  (funcall report-fn
           (when (heks/scheme-lint-applies-p)
             (heks/scheme-lint-diagnostics))))

(defun heks/scheme-lint-buffer ()
  "List what is worth changing in this Scheme buffer."
  (interactive)
  (unless (heks/scheme-lint-applies-p)
    (user-error "This buffer is not Scheme"))
  (let ((diagnostics (heks/scheme-lint-diagnostics)))
    (if (null diagnostics)
        (message "Nothing in this buffer is a habit this checks for")
      (flymake-show-buffer-diagnostics)
      (message "%d thing%s worth changing"
               (length diagnostics)
               (if (= (length diagnostics) 1) "" "s")))))

(provide 'heks/scheme-lint)

;;; scheme-lint.el ends here
