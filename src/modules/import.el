;;; import.el --- Import a Markdown document as an Org one  -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; A repository's README, a changelog, the documentation of a service: the
;; files one *reads* are Markdown, because that is what the tools around a
;; project read.  What one *works in* is Org, where a note can be linked
;; from another note, scheduled, exported as a slide deck and searched as a
;; set.  This module is the one-way door between them.
;;
;; One-way is the design rather than the limitation: the Markdown is read
;; and left exactly as it was, and the Org is written beside it (or into
;; the notes, with a prefix argument).  A document kept in two formats and
;; edited in both is a document with two truths, and there is no way to
;; write down which one is right.
;;
;; What it covers is the Markdown `modules/markdown.el' reads, which is the
;; Markdown the preview reads, turned into the Org that says the same
;; thing: headings as an outline, emphasis as emphasis, a table as an Org
;; table, a code fence as a source block, a blockquote as a quote, a link
;; and an image as the Org link both of them are.  What the front matter
;; says about the document -- its title, its tags, its aliases, its date --
;; becomes what Org says about the note, and the heading a document names
;; itself with becomes the title rather than a section repeated under it.
;;
;; Two things it deliberately does not do.  It does not keep the Org and
;; the Markdown in step afterwards (see above), and it does not go looking
;; for anything: a link to a file next to the document is written as the
;; full name of that file, so that a note written somewhere else still
;; opens what it points at, and an image is a link like any other rather
;; than something copied into place behind the reader's back.
;;
;; The keys are under the notes topic, because a note is what it makes:
;;
;;   `C-c n m'   the Markdown file of this buffer, imported as an Org file
;;               next to it; with a prefix argument it is written into
;;               `heks/notes-directory' as a note
;;               instead, with the identifier, the title, the tags and the
;;               aliases it needs to be a node rather than a file.
;;               Nothing here is loaded from Org: the reading and the
;;               writing of a document are strings in and strings out, so
;;               the conversion works in an Emacs that has no Org at all
;;               -- which is what the tests that check it are.
;;               `heks/import-into-notes' swaps which of the two the
;;               prefix asks for.
;;
;;   `C-c n M'   the region, Markdown converted to Org in place; with a
;;               prefix argument (or in a buffer that cannot be written
;;               to) the Org goes on the kill ring instead.  It is a piece
;;               rather than a note, so a heading keeps its level and no
;;               title or property drawer is made of it.
;;
;;   `M-x heks/import-markdown-file' imports a file named at the
;;   prompt, and `M-x heks/import-markdown-project' imports every
;;   Markdown file the current project has -- its own file list, so what a
;;   repository carries and not what was built in it -- one Org file each,
;;   with one question before it writes over anything that is already
;;   there.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

;; The reading of a Markdown document, and what the preview makes of one:
;; this module makes Org of the same reading, so a file previewed and a
;; file imported cannot disagree about the same lines.
(declare-function heks/markdown-resolve-path "markdown" (url))
(declare-function heks/markdown-split-code-spans "markdown" (text))
(declare-function heks/markdown-indent-of "markdown" (line))
(declare-function heks/markdown-cells "markdown" (line))
(declare-function heks/markdown-link-definitions "markdown" (lines))
(declare-function heks/markdown-normalize-label "markdown" (label))
(declare-function heks/markdown-alert "markdown" (line))
(declare-function heks/markdown-alert-remainder "markdown" (line))
(declare-function heks/markdown-table-p "markdown" (line next))
(declare-function heks/render-markdown-p "render" (&optional buffer))
;; The notes directory is this user's own, and `modules/heks-emacs.el' is
;; where it is known -- as a directory, or as nothing at all.
(declare-function heks/notes-directory "heks-emacs" ())

;;;
;;; Customization
;;;

(defcustom heks/import-into-notes nil
  "Whether an import with no prefix argument becomes an Org notes note.

The default is the other way round, and the one that leaves the note next
to the source it was made from: the import then says where it came from,
and the file it is about is where the rest of that project's files are.
A prefix argument asks for the other of the two places rather than for the
notes in particular, so setting this to t makes plain `C-c n m' the note
and `C-u C-c n m' the file next to the Markdown -- which is what a user
who imports in order to write wants."
  :type 'boolean
  :group 'heks)

(defcustom heks/import-title-from-heading t
  "Whether the first heading of a document names the note.

A Markdown file usually says what it is in a heading at the top (`# My
project') rather than in front matter, and Org says the same thing in a
`#+title:' keyword.  With this on, that heading becomes the title and is
not repeated as a section under it; with it off, every heading stays a
heading, and a document with no front matter has the name of its file as
its title -- which is what the notes do with a note that has none."
  :type 'boolean
  :group 'heks)

;;;
;;; What a document says about itself
;;;

(defconst heks/import--named-fields
  '("title" "tags" "categories" "aliases" "alias" "date" "author"
    "authors" "description" "summary" "excerpt")
  "The front matter fields this module reads as its own.

What is left of the front matter is not dropped: a field only this
document's tooling knows about is written to the note as an Org keyword of
its own name, which is what Org keeps them for.")

(defun heks/import--unquote (value)
  "Return VALUE, a front matter value, without the quotes it may wear."
  (let ((trimmed (string-trim value)))
    (if (and (>= (length trimmed) 2)
             (memq (aref trimmed 0) '(?\" ?'))
             (eq (aref trimmed 0) (aref trimmed (1- (length trimmed)))))
        (substring trimmed 1 -1)
      trimmed)))

(defun heks/import--front-matter-fields (lines)
  "Read LINES, the lines of a front matter block, as an alist of KEY and value.

A key whose value is written under it rather than after it -- YAML's
`tags:' and then `  - a', `  - b' -- keeps its items as one comma
separated value, which is how a list is written elsewhere in the block."
  (let ((fields nil)
        (items nil))
    (cl-labels ((close ()
                  (when (and fields items)
                    (setcdr (car fields)
                            (mapconcat #'identity (nreverse items) ", "))
                    (setq items nil))))
      (dolist (line lines)
        (cond
         ((string-match "\\`[ \t]*-[ \t]+\\(.*\\)\\'" line)
          (push (heks/import--unquote (match-string 1 line)) items))
         ((string-match "\\`\\([^:# \t]+\\):[ \t]*\\(.*\\)\\'" line)
          (close)
          (push (cons (downcase (match-string 1 line))
                      (heks/import--unquote (match-string 2 line)))
                fields))
         (t nil)))
      (close))
    (nreverse fields)))

(defun heks/import--front-matter (text)
  "Return (FIELDS . BODY) for TEXT, a document that may open with front matter.

Front matter is the block a static site generator reads: three dashes (or
three plus signs) on the first line of the document, the `key: value'
lines of it, and the line that closes it.  A document that opens with
neither is itself again, with no fields."  (if (not (string-match "\\`\\(---\\|\\+\\+\\+\\)[ \t]*\n" text))
      (cons nil text)
    (let* ((fence (match-string 1 text))
           (from (match-end 0))
           (closing (format "\n%s[ \t]*\\(\n\\|\\'\\)" (regexp-quote fence)))
           (to (when (string-match closing text from) (match-beginning 0)))
           (after (when to (match-end 0))))
      (if (not to)
          (cons nil text)
        (cons (heks/import--front-matter-fields
               (split-string (substring text from to) "\n"))
              ;; The line that closed the block goes with the block, and
              ;; so does the newline that ended it: the body is what is
              ;; under the front matter.
              (substring text after))))))

(defun heks/import--field (fields names)
  "Return the value FIELDS gives the first of NAMES that it has."
  (let ((found nil))
    (while (and names (not found))
      (setq found (cdr (assoc (car names) fields)))
      (setq names (cdr names)))
    found))

(defun heks/import--items (value)
  "Return VALUE, a front matter value, as the list of items it holds.

`[a, b]', `a, b' and a lone `a' all read as lists: the brackets a YAML
flow sequence wears are taken off, and what is left is split at the
commas."
  (when (and (stringp value) (not (string-blank-p value)))
    (let ((text (string-trim value)))
      (when (and (string-prefix-p "[" text) (string-suffix-p "]" text))
        (setq text (substring text 1 -1)))
      (delq nil (mapcar (lambda (item)
                          (let ((item (heks/import--unquote item)))
                            (unless (string-blank-p item) item)))
                        (split-string text ","))))))

(defun heks/import--elsewhere (fields)
  "Return the FIELDS this module does not name itself, as (KEY . VALUE) pairs."
  (cl-remove-if (lambda (field)
                  (member (car field) heks/import--named-fields))
                fields))

(defun heks/import--plain (text)
  "Return TEXT, a heading, with its inline markup taken off it.

The title of an Org document is a string rather than a paragraph, so
`# The **why** of it' is titled `The why of it'."
  (let ((plain text))
    (setq plain (replace-regexp-in-string
                 "!\\[\\([^]]*\\)\\](\\([^)]*\\))" "\\1" plain t))
    (setq plain (replace-regexp-in-string
                 "\\[\\([^]]*\\)\\](\\([^)]*\\))" "\\1" plain t))
    (setq plain (replace-regexp-in-string "`\\([^`]*\\)`" "\\1" plain t))
    (setq plain (replace-regexp-in-string "\\*\\*\\([^*]+\\)\\*\\*" "\\1" plain t))
    (setq plain (replace-regexp-in-string "__\\([^_]+\\)__" "\\1" plain t))
    (setq plain (replace-regexp-in-string "\\*\\([^*]+\\)\\*" "\\1" plain t))
    (setq plain (replace-regexp-in-string
                 "\\(\\`\\|[^_a-zA-Z]\\)_\\([^_]+\\)_" "\\1\\2" plain t))
    (setq plain (replace-regexp-in-string "~~\\([^~]+\\)~~" "\\1" plain t))
    (string-trim plain)))

(defun heks/import--first-heading (text)
  "Return (TITLE BEGIN END) for the heading TEXT opens with, or nil.

Only the heading a document opens with counts: that one names the document
rather than a section of it, and a `# ...' further down is a section like
any other."
  (when (string-match
         "\\`\\(?:[ \t]*\n\\)*#[ \t]+\\(.*?\\)[ \t]*#*[ \t]*\\(\n\\|\\'\\)" text)
    (let ((title (heks/import--plain (match-string 1 text))))
      (unless (string-blank-p title)
        (list title (match-beginning 0) (match-end 0))))))

(defun heks/markdown-metadata (text)
  "Return a plist describing the Markdown document in TEXT.

What it reads is what the file says about itself rather than what is in
it: `:title' from the front matter or from the document's own first
heading, `:tags' and `:aliases' as lists, `:date', `:author' and
`:description', `:keywords' as an alist of the front matter fields this
module does not name itself, and `:body' -- the document without its front
matter and without the heading the title was taken from."
  (let* ((parts (heks/import--front-matter text))
         (fields (car parts))
         (body (cdr parts))
         (title (heks/import--field fields '("title")))
         (heading (heks/import--first-heading body)))
    ;; A document that says what it is in a heading says it in the heading
    ;; *and* in the front matter when both are there.  A title that is the
    ;; heading's own text is the same title said twice, so the heading goes
    ;; either way; and when the front matter says nothing, the heading is
    ;; the only thing that names the document.
    (when (and heading
               heks/import-title-from-heading
               (or (null title) (equal title (car heading))))
      (setq title (car heading)
            body (concat (substring body 0 (nth 1 heading))
                         (substring body (nth 2 heading)))))
    (list :title title
          :tags (heks/import--items
                 (heks/import--field fields '("tags" "categories")))
          :aliases (heks/import--items
                    (heks/import--field fields '("aliases" "alias")))
          :date (heks/import--field fields '("date"))
          :author (heks/import--field fields '("author" "authors"))
          :description (heks/import--field
                        fields '("description" "summary" "excerpt"))
          :keywords (heks/import--elsewhere fields)
          :body body)))

;;;
;;; Saying it in Org
;;;

(defconst heks/import--bold-marker "\u0001"
  "The character a strong emphasis is held as until the emphasis pass is done.

Org writes bold with the same character it writes a headline with, and the
pass that turns a single pair of asterisks into emphasis would read the
result of the bold pass as one of its own pairs.  A character no document
carries stands in for the pair until both passes have run.")

(defun heks/import--code (text)
  "Return TEXT, a code span, as the Org code span with no ambiguity in it.

Org writes a code span with `=' or with `~', and neither may hold the
character it is written with: a span that holds an `=' is written with the
tildes, and one that holds both has no Org spelling at all -- it is
written with the `=', which is the one that reads as code."
  (cond ((not (string-match-p "=" text)) (format "=%s=" text))
        ((not (string-match-p "~" text)) (format "~%s~" text))
        (t (format "=%s=" text))))

(defvar heks/import--links nil
  "The link definitions of the document being imported.

A Markdown document can write a link as `[text][label]' and give the
address once, in a `[label]: url' line anywhere in the file.  That line is
a definition and not a paragraph, and the reference is a link: both are
read from `markdown.el', so that the note an import writes and the page a
preview shows point at the same place.")

(defun heks/import-definition (label)
  "Return the link definition LABEL names, as (URL . TITLE), or nil."
  (cdr (assoc (heks/markdown-normalize-label label)
              heks/import--links)))

(defun heks/import--url (url)
  "Return URL, a link in a document, as the Org link it is written as.

A link to a file next to the document becomes the full name of that file,
because what the note is written next to is not what the document was
written next to: the note may be written into a notes directory of its
own, and a relative link would then point at nothing."
  (or (heks/markdown-resolve-path url) url))

(defun heks/import--link (url text)
  "Return URL as an Org link, labelled with TEXT.

Org shows the target itself for a link with no text of its own, so a
Markdown `[https://example.com](https://example.com)' is one link rather
than a link whose label repeats it.

The match data is put back as it was found: this runs inside the
replacement function of a `replace-regexp-in-string', which reads the
match data again once that function has returned."
  (save-match-data
    (let ((target (heks/import--url url)))
      (if (or (string-blank-p text) (equal (string-trim text) target))
          (format "[[%s]]" target)
        (format "[[%s][%s]]" target (heks/import--inline text))))))

(defun heks/import--image (url alt)
  "Return URL, an image, as the Org link an image is, labelled with ALT."
  (save-match-data
    (let ((target (heks/import--url url)))
      (if (string-blank-p alt)
          (format "[[%s]]" target)
        (format "[[%s][%s]]" target (heks/import--plain alt))))))

(defun heks/import--inline-markup (text)
  "Turn the emphasis, links and images of TEXT into Org markup.

TEXT is not escaped on the way: Org has no characters to escape, and what
it does have is the emphasis markers this writes -- which is why a bold
pair is held as `heks/import--bold-marker' until the pass that reads
a single pair of asterisks is behind it."
  (let ((result text))
    ;; A reference-style link and image are ones this document defines
    ;; somewhere else in it, and they become the links they name.
    (setq result
          (replace-regexp-in-string
           "!\\[\\([^]]*\\)\\]\\[\\([^]]*\\)\\]"
           (lambda (match)
             (let* ((alt (match-string 1 match))
                    (label (match-string 2 match))
                    (definition (heks/import-definition
                                 (if (string-empty-p label) alt label))))
               (if definition
                   (heks/import--image (car definition) alt)
                 match)))
           result t t))
    (setq result
          (replace-regexp-in-string
           "\\[\\([^]]*\\)\\]\\[\\([^]]*\\)\\]"
           (lambda (match)
             (let* ((text (match-string 1 match))
                    (label (match-string 2 match))
                    (definition (heks/import-definition
                                 (if (string-empty-p label) text label))))
               (if definition
                   (heks/import--link (car definition) text)
                 match)))
           result t t))
    ;; Images before links: an image is a link with a bang in front of it.
    (setq result
          (replace-regexp-in-string
           "!\\[\\([^]]*\\)\\](\\([^) \t]+\\)\\(?:[ \t]+\"[^\"]*\"\\)?)"
           (lambda (match)
             (heks/import--image (match-string 2 match)
                                       (match-string 1 match)))
           result t t))
    (setq result
          (replace-regexp-in-string
           "\\[\\([^]]*\\)\\](\\([^) \t]+\\)\\(?:[ \t]+\"[^\"]*\"\\)?)"
           (lambda (match)
             (heks/import--link (match-string 2 match)
                                      (match-string 1 match)))
           result t t))
    ;; An autolink: a link written as its own address, with no text of
    ;; its own, which is what Org writes as the address in brackets.
    (setq result (replace-regexp-in-string
                  "<\\(https?://[^ <]+\\)>" "[[\\1]]" result t))
    ;; A footnote reference, before the emphasis passes: `[^1]' is not a
    ;; link, and the brackets are what Org writes a footnote with.
    (setq result (replace-regexp-in-string
                  "\\[\\^\\([^]]+\\)\\]" "[fn:\\1]" result t))
    (setq result
          (replace-regexp-in-string
           "\\*\\*\\([^*]+\\)\\*\\*"
           (concat heks/import--bold-marker "\\1"
                   heks/import--bold-marker)
           result t))
    (setq result
          (replace-regexp-in-string
           "__\\([^_]+\\)__"
           (concat heks/import--bold-marker "\\1"
                   heks/import--bold-marker)
           result t))
    (setq result (replace-regexp-in-string "\\*\\([^*\n]+\\)\\*"
                                           "/\\1/" result t))
    (setq result (replace-regexp-in-string
                  "\\(\\`\\|[^_a-zA-Z]\\)_\\([^_\n]+\\)_" "\\1/\\2/" result t))
    (setq result (replace-regexp-in-string "~~\\([^~]+\\)~~" "+\\1+" result t))
    (replace-regexp-in-string (regexp-quote heks/import--bold-marker)
                              "*" result t)))

(defun heks/import--inline (text)
  "Return TEXT, with its inline Markdown turned into Org markup.

Code spans first, as in the preview: inside one, an asterisk is an
asterisk, and no pass of this may look at what is in there."
  (mapconcat (lambda (piece)
               (if (car piece)
                   (heks/import--code (cdr piece))
                 (heks/import--inline-markup (cdr piece))))
             (heks/markdown-split-code-spans text)
             ""))

(defun heks/import--line (line)
  "Return LINE, the inline Markdown in it turned into Org.

A line that ends in two spaces ends in a hard break in Markdown, which is
`\\\\' in Org: the spaces go with the break rather than staying behind as
whitespace at the end of a line."
  (if (string-suffix-p "  " line)
      (concat (heks/import--inline (string-trim-right line)) "\\\\")
    (heks/import--inline line)))

(defun heks/import--paragraph (lines)
  "Return LINES, the lines of one paragraph, as the Org for one paragraph.

Every line stays the line it was: a line broken by the writer is a line
broken in the note, which Org reads back as the one paragraph it is, and
rewrapping somebody's prose is not what an import is for."
  (mapconcat #'heks/import--line lines "\n"))

(defun heks/import--widths (rows)
  "Return the width of every column of ROWS, a list of rows of cells."
  (let ((widths nil))
    (dotimes (index (apply #'max 1 (mapcar #'length rows)))
      (push (apply #'max 1
                   (mapcar (lambda (row) (string-width (or (nth index row) "")))
                           rows))
            widths))
    (nreverse widths)))

(defun heks/import--row (cells widths)
  "Return CELLS, one row of a table, as an Org table row of WIDTHS.

A cell is padded to its column rather than written as it came: the widths
are what the rule under the header row is drawn with, and a row narrower
than the rule above it is a table a person reads as a mistake, whatever
Org makes of it when it aligns the buffer."
  (concat "| "
          (mapconcat #'identity
                     (cl-loop for cell in cells
                              for index from 0
                              for width = (or (nth index widths) 0)
                              for text = (string-trim-right cell)
                              collect (concat text
                                              (make-string
                                               (max 0 (- width (string-width text)))
                                               ?\s)))
                     " | ")
          " |"))

(defun heks/import--rule (widths)
  "Return WIDTHS as the Org rule that closes a table's header row."
  (concat "|"
          (mapconcat (lambda (width) (make-string (+ width 2) ?-))
                     widths "+")
          "|"))

(defun heks/import--checkbox (text)
  "Return TEXT, a list item's text, with its box spelled as Org reads it.

Markdown checks a box with `[x]' and Org reads `[X]': a lowercase one is
not a box to Org, so a checked note imported as it was written would read
back as an item whose text happens to start with a box.  A box a document
writes some other way -- `[-]', a thing half done -- is left as it is, and
so is text that only looks like a box because the space after it is
missing."
  (let ((box (and (> (length text) 3) (substring text 0 3))))
    (if (and (member box '("[ ]" "[x]" "[X]" "[-]"))
             (memq (aref text 3) '(?\s ?\t)))
        (concat (if (member box '("[x]" "[X]")) "[X]" box)
                (substring text 3))
      text)))

(defun heks/import--table (lines index)
  "Return the Org for the Markdown table that starts at INDEX in LINES.

Return a cons of the table and the index just past it.  The alignment of a
column comes from its position in the delimiter row rather than from what
is in the cells, exactly as in the preview, and Org is told about it the
way Org is told: a row of `<l>', `<c>' and `<r>' cookies, which is a row
Org aligns by and does not export.  Markdown's delimiter row is also what
separates a table's header from its body, so the rule that does that in Org
is written too: without it the first row would read as a row rather than as
the header it was."
  (let ((header (heks/markdown-cells (nth index lines)))
        (aligns (mapcar (lambda (cell)
                          (cond ((and (string-prefix-p ":" cell)
                                      (string-suffix-p ":" cell)) "<c>")
                                ((string-suffix-p ":" cell) "<r>")
                                (t "<l>")))
                        (heks/markdown-cells (nth (1+ index) lines))))
        (rows nil)
        (i (+ index 2))
        (n (length lines)))
    (while (and (< i n)
                (string-match-p "|" (nth i lines))
                (not (string-match-p "\\`[ \t]*\\'" (nth i lines))))
      (push (heks/markdown-cells (nth i lines)) rows)
      (setq i (1+ i)))
    (let* ((cells (cons header (nreverse rows)))
           (converted (mapcar (lambda (row)
                                (mapcar #'heks/import--inline row))
                              cells))
           (widths (heks/import--widths
                    (cons aligns (append converted (list aligns))))))
      (cons (mapconcat #'identity
                       (append (list (heks/import--row
                                      (car converted) widths)
                                     (heks/import--row aligns widths)
                                     (heks/import--rule widths))
                               (mapcar (lambda (row)
                                         (heks/import--row row widths))
                                       (cdr converted)))
                       "\n")
            i))))

(defun heks/import--shift (org)
  "Return ORG with its headings shifted up, so that none starts deeper than one.

A note whose title went into `#+title:' has no first-level headline for
its sections to hang under, and a document that opens with `## Install'
would otherwise be a note of subsections and of no sections.  So the
shallowest heading of what is left becomes the first level, and every
heading moves with it.

A line inside a block is not a heading, whatever it starts with: a shell
snippet with `* ' in it is a shell snippet."
  (let* ((lines (split-string org "\n"))
         (block nil)
         (levels nil))
    (dolist (line lines)
      (cond ((string-match-p "\\`#\\+\\(?:begin\\|end\\)_" line)
             (setq block (not block)))
            ((and (not block) (string-match "\\`\\(\\*+\\) " line))
             (push (length (match-string 1 line)) levels))))
    (let ((shift (if levels (1- (apply #'min levels)) 0)))
      (if (< shift 1)
          org
        (setq block nil)
        (string-join
         (mapcar (lambda (line)
                   (cond ((string-match-p "\\`#\\+\\(?:begin\\|end\\)_" line)
                          (setq block (not block))
                          line)
                         ((and (not block) (string-match "\\`\\*\\{2,\\} " line))
                          (replace-regexp-in-string
                           "\\`\\*+" (lambda (stars)
                                       (make-string
                                        (max 1 (- (length stars) shift)) ?*))
                           line t t))
                         (t line)))
                 lines)
         "\n")))))

(defun heks/import--blocks (text)
  "Return the Org blocks the Markdown in TEXT makes.

The branches are the preview's branches in the preview's order -- a
fenced block, a table, a quote, a heading, a rule, a list item, a raw
block, a paragraph -- and the questions they ask are `markdown.el''s, so
that what is a table here is a table there.

The blank lines are kept, because in HTML they decide nothing and in Org
they decide what a block ends: a list that follows a paragraph with no
blank line between them is a lazy line of that paragraph, and an import
that lost the question would change the answer."
  (let* ((split (split-string (string-trim text) "\n"))
         ;; The link definitions are taken out of the document once, at
         ;; the top: they are not blocks, and a note that kept them would
         ;; keep the addresses as paragraphs of their own.
         (parsed (if heks/import--links
                     (cons split nil)
                   (heks/markdown-link-definitions split)))
         (heks/import--links (or (cdr parsed) heks/import--links))
         (lines (car parsed))
         (n (length lines))
         (i 0)
         (out nil)
         (paragraph nil)
         (blank nil))
    (cl-labels ((emit (org)
                  ;; The empty line the document had before this block,
                  ;; if it had one and there is a block to separate it
                  ;; from.  A leading or trailing blank line is nobody's.
                  (when (and blank out) (push "" out))
                  (setq blank nil)
                  (push org out))
                (close-paragraph ()
                  (when paragraph
                    (emit (heks/import--paragraph (nreverse paragraph)))
                    (setq paragraph nil))))
      (while (< i n)
        (let* ((line (nth i lines))
               (trimmed (string-trim line))
               (consumed 1))
          (cond
           ;; A blank line ends the paragraph, and is remembered so that
           ;; what follows it is a block of its own.
           ((string-empty-p trimmed)
            (close-paragraph)
            (setq blank t))

           ;; A fenced block: what it says it is, it is.
           ((string-match "\\`\\(```+\\)\\(.*\\)\\'" trimmed)
            (close-paragraph)
            (let* ((fence (match-string 1 trimmed))
                   (info (string-trim (match-string 2 trimmed)))
                   (body nil)
                   (closed nil)
                   (j (1+ i))
                   (pattern (format "\\`%s" (regexp-quote fence))))
              (while (and (< j n) (not closed))
                (if (string-match-p pattern (string-trim (nth j lines)))
                    (setq closed t)
                  (push (nth j lines) body))
                (setq j (1+ j)))
              (setq consumed (- j i))
              (emit (concat (if (string-empty-p info)
                                "#+begin_example"
                              (format "#+begin_src %s" info))
                            "\n"
                            (mapconcat #'identity (nreverse body) "\n")
                            (if (string-empty-p info)
                                "\n#+end_example"
                              "\n#+end_src")))))

           ;; A table, before the list branch: a row of cells also starts
           ;; with a dash-and-space when it is `| - |'.
           ((heks/markdown-table-p line (nth (1+ i) lines))
            (close-paragraph)
            (let ((table (heks/import--table lines i)))
              (emit (car table))
              (setq consumed (- (cdr table) i))))

           ;; A quote: the quoted lines are a document of their own.  A
           ;; quote that opens with GitHub's callout marker -- `[!NOTE]'
           ;; -- is that sentence rather than the marker: the note says
           ;; what the callout says, and not what kind of callout it was.
           ((string-match "\\`> ?\\(.*\\)\\'" trimmed)
            (close-paragraph)
            (let ((quoted nil)
                  (j i))
              (while (and (< j n)
                          (string-match "\\`> ?\\(.*\\)\\'"
                                        (string-trim (nth j lines))))
                (push (match-string 1 (string-trim (nth j lines))) quoted)
                (setq j (1+ j)))
              (setq consumed (- j i))
              (setq quoted (nreverse quoted))
              (when (heks/markdown-alert (car quoted))
                (let ((rest (cdr quoted))
                      (remainder (heks/markdown-alert-remainder (car quoted))))
                  (setq quoted (if remainder (cons remainder rest) rest))))
              (emit (concat "#+begin_quote\n"
                            (string-trim
                             (heks/import--blocks
                              (mapconcat #'identity quoted "\n")))
                            "\n#+end_quote"))))

           ;; A heading: the depth it says it is, for now; the shift takes
           ;; off the level a title would have been (see
           ;; `heks/import--shift').
           ((string-match "\\`\\(#\\{1,6\\}\\)[ \t]+\\(.*?\\)[ \t]*#*\\'"
                          trimmed)
            (close-paragraph)
            (emit (concat (make-string (length (match-string 1 trimmed)) ?*)
                          " "
                          (heks/import--inline (match-string 2 trimmed)))))

           ;; A setext heading is a paragraph with a line under it, and it
           ;; is a level deeper for every dash it is underlined with.
           ((and paragraph (string-match "\\`=\\{2,\\}[ \t]*\\'" trimmed))
            (let ((text (heks/import--inline
                         (mapconcat #'identity (nreverse paragraph) " "))))
              (setq paragraph nil)
              (emit (concat "* " text))))
           ((and paragraph (string-match "\\`-\\{2,\\}[ \t]*\\'" trimmed))
            (let ((text (heks/import--inline
                         (mapconcat #'identity (nreverse paragraph) " "))))
              (setq paragraph nil)
              (emit (concat "** " text))))

           ((string-match "\\`\\([-*_]\\)\\([ \t]*\\1\\)\\{2,\\}[ \t]*\\'"
                          trimmed)
            (close-paragraph)
            (emit "-----"))

           ;; A footnote: Org writes the definition as the reference.
           ((string-match "\\`\\[\\^\\([^]]+\\)\\]:[ \t]+\\(.*\\)\\'" trimmed)
            (close-paragraph)
            (let ((body (list (match-string 2 trimmed)))
                  (j (1+ i)))
              (while (and (< j n)
                          (not (string-empty-p (nth j lines)))
                          (string-match-p "\\`[ \t]" (nth j lines)))
                (push (string-trim (nth j lines)) body)
                (setq j (1+ j)))
              (setq consumed (- j i))
              (emit (format "[fn:%s] %s" (match-string 1 trimmed)
                            (heks/import--inline
                             (mapconcat #'identity (nreverse body) " "))))))

           ;; A list item: the marker it has, and the depth it has it at.
           ;; A bullet becomes Org's `-', since a line that starts with an
           ;; asterisk is a headline in Org and a bullet in Markdown, and
           ;; no import may turn the second into the first.
           ((string-match "\\`\\([-*+]\\|[0-9]+[.)]\\)[ \t]+\\(.*\\)\\'"
                          trimmed)
            (let* ((indent (heks/markdown-indent-of line))
                   (marker (if (string-match-p "\\`[0-9]" (match-string 1 trimmed))
                               (replace-regexp-in-string ")\\'" "." (match-string 1 trimmed))
                             "-")))
              (close-paragraph)
              (emit (concat (make-string indent ?\s)
                            marker
                            " "
                            (heks/import--inline
                             (heks/import--checkbox
                              (match-string 2 trimmed)))))))

           ;; A raw HTML block is passed through as what it is, because a
           ;; badge or a `<details>' is HTML no Org spelling improves on.
           ((and (string-prefix-p "<" trimmed)
                 (string-match-p "\\`</?[a-zA-Z][^>]*>" trimmed))
            (close-paragraph)
            (let ((body nil)
                  (j i))
              (while (and (< j n)
                          (not (string-empty-p (string-trim (nth j lines)))))
                (push (nth j lines) body)
                (setq j (1+ j)))
              (setq consumed (- j i))
              (emit (concat "#+begin_export html\n"
                            (mapconcat #'identity (nreverse body) "\n")
                            "\n#+end_export"))))

           (t
            (push line paragraph)))
          (setq i (+ i consumed))))
      (close-paragraph))
    (string-join (nreverse out) "\n")))

(defun heks/import--filetags (items)
  "Return ITEMS, a list of tags, as the `:a:b:' Org writes tags with.

A tag may not hold a space, so the spaces of a tag that has one become
underscores: what a tag is called is not something an import changes."
  (format ":%s:" (mapconcat (lambda (tag)
                              (replace-regexp-in-string "[ \t]+" "_"
                                                        (string-trim tag)))
                            items ":")))

(defun heks/import--keywords (metadata)
  "Return the Org keywords the METADATA of a Markdown document asks for.

What the front matter says becomes what Org says about the note, and a
field this module does not read as its own is written as a keyword of that
name rather than dropped: Org keeps keywords nobody has heard of, and a
tool that wrote the field can find it again."
  (let ((lines nil))
    (cl-flet ((keyword (name value)
                (when (and (stringp value) (not (string-blank-p value)))
                  (push (format "#+%s: %s" name (string-trim value)) lines))))
      (keyword "title" (plist-get metadata :title))
      (keyword "author" (plist-get metadata :author))
      (keyword "date" (plist-get metadata :date))
      (keyword "description" (plist-get metadata :description))
      (when (plist-get metadata :tags)
        (push (format "#+filetags: %s"
                      (heks/import--filetags (plist-get metadata :tags)))
              lines))
      (dolist (field (plist-get metadata :keywords))
        (keyword (car field) (cdr field))))
    (mapconcat #'identity (nreverse lines) "\n")))

(defun heks/import--drawer (properties)
  "Return PROPERTIES, an alist of name to value, as an Org property drawer."
  (when properties
    (concat ":PROPERTIES:\n"
            (mapconcat (lambda (property)
                         (format "%-10s %s"
                                 (concat ":" (car property) ":")
                                 (cdr property)))
                       properties "\n")
            "\n:END:")))

(defun heks/markdown-to-org (text &optional properties)
  "Return the Org document that TEXT, a Markdown document, becomes.

PROPERTIES, when given, is an alist of name to value written as the file's
property drawer, which is where Org keeps what it knows about the whole
note rather than about a place in it -- Org keeps a note's
identifier and its aliases there.

The drawer comes before the keywords rather than after them, which is
where Org reads one: a drawer is a property drawer when it is the first
thing in the file (or the first thing after a headline), and one written
further down is a drawer of text that `org-entry-get' will not find."
  (let* ((metadata (heks/markdown-metadata text))
         (blocks (list (heks/import--drawer properties)
                       (heks/import--keywords metadata)
                       (heks/import--shift
                        (heks/import--blocks (plist-get metadata :body))))))
    (concat (string-trim-right             ;; A document with no front matter has no keywords and one
             ;; with no properties has no drawer, and neither leaves a
             ;; blank line behind it.
             (mapconcat #'identity
                        (cl-remove-if (lambda (block)
                                        (or (null block) (string-empty-p block)))
                                      blocks)
                        "\n\n"))
            "\n")))

(defun heks/markdown-fragment-to-org (text)
  "Return the Org that TEXT, a piece of a Markdown document, becomes.

Unlike `heks/markdown-to-org' this is not a note: there is no front
matter to read, no title to take out of a heading and no property drawer,
and the headings keep the level they have -- a `## Install' is a `**
Install' whatever else the piece holds, because a piece does not know
what it is a part of and the buffer it is going back into does.  What it
shares with the note is every rule about how a line is said in Org.

The result has no newline at the end; the caller knows whether the text
it replaces had one."
  (string-trim-right (heks/import--blocks text)))

(defun heks/markdown-region-to-org (beg end &optional copy)
  "Convert the Markdown between BEG and END to Org, in place.

The region is replaced by what it says in Org (see
`heks/markdown-fragment-to-org').  With a prefix argument COPY, or
in a buffer that cannot be written to -- a chat, a help buffer -- the Org
is put on the kill ring instead and the buffer is left as it is, which is
the way to take Markdown from somewhere one cannot edit into a note.

A relative link is written as the file it names, resolved against the
directory of the buffer's file (or `default-directory' when it has none),
the way an imported document's is."
  (interactive "r\nP")
  (let* ((text (buffer-substring-no-properties beg end))
         (heks/markdown-base-directory
          (file-name-as-directory
           (if buffer-file-name
               (file-name-directory buffer-file-name)
             default-directory)))
         (org (concat (heks/markdown-fragment-to-org text)
                      ;; A region that ended a line ends a line after it
                      ;; is converted, so that what follows it does not
                      ;; move up.
                      (if (string-suffix-p "\n" text) "\n" ""))))
    (cond
     ((or copy buffer-read-only)
      (kill-new org)
      (message "Org copied to the kill ring"))
     (t
      (save-excursion
        (goto-char beg)
        (delete-region beg end)
        (insert org))
      (deactivate-mark)))
    org))

;;;
;;; Writing it where it belongs
;;;

(defun heks/import-markdown-p (file)
  "Return whether FILE, a file name, is a Markdown document."
  (and (stringp file)
       (string-match-p "\\.\\(md\\|markdown\\|mkd\\|mdx\\)\\'" (downcase file))
       t))

(defun heks/import--contents (file)
  "Return the text of FILE."
  (with-temp-buffer
    (set-buffer-multibyte t)
    (insert-file-contents file)
    (buffer-substring-no-properties (point-min) (point-max))))

(defun heks/import--target (source notes)
  "Return the Org file SOURCE, a Markdown file, is imported to.

With NOTES it is a file of that name in the notes directory -- which is
this user's own business, and named rather than guessed when it is not
set -- and without it, a file of that name next to the Markdown."
  (if notes
      (let ((directory (heks/notes-directory)))
        (unless directory
          (user-error
           "Set `heks/notes-dir' to import into the notes, or import next to the file"))
        (expand-file-name
         (concat (file-name-nondirectory (file-name-sans-extension source))
                 ".org")
         directory))
    (concat (file-name-sans-extension source) ".org")))

(defun heks/import--existing-id (file)
  "Return the `org-id' identifier FILE already carries, or nil."
  (when (file-exists-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (when (re-search-forward "^:ID:[ \t]+\\([^ \t\n]+\\)" nil t)
        (match-string 1)))))

(defun heks/import--id ()
  "Return an identifier for a note, as the UUID `org-id' writes.

Made here rather than asked of `org-id' because an import may be the
first thing a fresh Emacs is asked to do, and an identifier does not need
Org loaded to be one: the hash of a time, a process and a number, with
the version and variant bits set the way RFC 4122 says, which is the
shape `org-id' writes and reads."
  (let ((hex (substring (secure-hash 'sha256
                                     (format "%s-%s-%s"
                                             (float-time) (emacs-pid)
                                             (random most-positive-fixnum)))
                        0 32)))
    (format "%s-%s-4%s-%x%s-%s"
            (substring hex 0 8)
            (substring hex 8 12)
            (substring hex 13 16)
            ;; The variant bits are the top two of the nibble (RFC 4122,
            ;; section 4.4), so the nibble becomes one of 8, 9, a and b.
            (logior #x8 (logand #x3 (string-to-number (substring hex 16 17) 16)))
            (substring hex 17 20)
            (substring hex 20 32))))

(defun heks/import--properties (metadata target notes)
  "Return the properties a note imported into TARGET should carry.

A note is named by an identifier rather than by its file, so a
note written into the notes directory gets one -- the one it already has,
when it already has one, because importing a document again is meant to
update the note rather than to make a second one -- and the aliases the
front matter gives it, which is where Org looks for them."
  (when notes
    (let ((id (or (heks/import--existing-id target) (heks/import--id)))
          (aliases (plist-get metadata :aliases)))
      (append (list (cons "ID" id))
              (when aliases
                (list (cons "ALIASES" (mapconcat #'identity aliases ", "))))))))

(defun heks/import--notes-p (argument)
  "Return whether an import with prefix ARGUMENT goes into the notes.

A prefix asks for the other of the two places rather than for the notes in
particular, so that the setting and one command agree about which of them
is the usual one (see `heks/import-into-notes')."
  (if heks/import-into-notes (not argument) (and argument t)))

(defun heks/import--write (target org &optional force)
  "Write ORG to TARGET, unless TARGET holds another file and that is not wanted.

Return TARGET when it was written and nil when what is there was kept.  A
file that already says what the import would write is written again,
silently; a file that says something else is written over only when FORCE
says so or the reader says yes, because an import that quietly replaced a
note somebody wrote is a worse import than one that asked."
  (cond
   ((and (file-exists-p target)
         (not (equal (heks/import--contents target) org))
         (not force)
         (not (yes-or-no-p (format "%s is already there and differs; write over it? "
                                   target))))
    nil)
   ((eq force 'keep)
    (if (equal (heks/import--contents target) org) target nil))
   (t
    (make-directory (file-name-directory target) t)
    (write-region org nil target nil 'silent)
    target)))

(defun heks/import--index (file)
  "Make FILE, which an import has just written, findable by its identifier.

A note is linked to by its `org-id' identifier, and `org-id' learns where an
identifier lives from a scan; telling it about FILE now is what makes a link
to the note work the moment it is written rather than after the next scan.
A note written outside the notes directory is no business of the notes, and
is left alone."
  (let ((directory (heks/notes-directory)))
    (when (and directory (file-in-directory-p file directory)
               (require 'org-id nil t)
               (fboundp 'org-id-update-id-locations))
      (ignore-errors (org-id-update-id-locations (list file)))
      t)))

(defun heks/import-markdown-file (file &optional notes force)
  "Import FILE, a Markdown document, as an Org file, and return its name.

The Markdown is read and left exactly as it was (see the commentary); the
Org is written next to it, or into the notes directory as a
note when NOTES is non-nil.  FORCE answers the question the writing would
otherwise ask: t writes over what is there, `keep' keeps it, and nil asks
whenever there is something that differs (see `heks/import--write')."
  (interactive (list (heks/import--read-file) current-prefix-arg))
  (let* ((source (expand-file-name file))
         (notes (heks/import--notes-p notes))
         (text (heks/import--contents source))
         (target (heks/import--target source notes))
         (metadata (heks/markdown-metadata text))
         ;; The document's own directory, so that a relative link in it is
         ;; written as the file it names rather than as a path that means
         ;; something only from where the document used to be.
         (heks/markdown-base-directory (file-name-directory source))
         (org (heks/markdown-to-org
               text (heks/import--properties metadata target notes))))
    (when (heks/import--write target org force)
      (heks/import--index target)
      target)))

(defun heks/import--read-file ()
  "Return the Markdown file to import: the one asked for."
  (let ((here (and buffer-file-name
                   (or (heks/render-markdown-p (current-buffer))
                       (heks/import-markdown-p buffer-file-name))
                   buffer-file-name)))
    (expand-file-name (read-file-name "Import a Markdown file as Org: "
                                      nil here t))))

(defun heks/import-markdown (&optional notes)
  "Import the Markdown file of this buffer as an Org file, and visit it.

The Org file is written next to the Markdown, which is left as it was;
with a prefix argument it is written into `heks/notes-directory'
instead, as a note that carries the identifier, the title, the
tags and the aliases it needs (`heks/import-into-notes' swaps which
of the two the prefix asks for).  A buffer that visits no Markdown file
asks for one."
  (interactive "P")
  (let* ((file (if (and buffer-file-name
                        (or (heks/render-markdown-p (current-buffer))
                            (heks/import-markdown-p buffer-file-name)))
                   buffer-file-name
                 (heks/import--read-file)))
         (target (heks/import-markdown-file file notes)))
    (if target
        (progn
          (find-file target)
          (message "Imported %s as %s"
                   (file-name-nondirectory file)
                   (file-name-nondirectory target)))
      (message "Kept %s as it is" (heks/import--target
                                   (expand-file-name file)
                                   (heks/import--notes-p notes))))))

(defun heks/import--marked-files ()
  "Return the Markdown files of the current project."
  (let ((project (or (project-current)
                     (user-error "No project here; open a file that belongs to one"))))
    (seq-filter #'heks/import-markdown-p (project-files project))))

(defun heks/import-markdown-project (&optional notes)
  "Import every Markdown file the current project has, as Org files.

What counts as the project's files is the project's own answer to that
question, so what a repository carries is imported and what was built in
it is not.  Each file is imported the way `heks/import-markdown-file'
imports one -- next to the Markdown, or into the notes with a prefix
argument -- and the number of files written, kept and mentioned is
reported.  One question is asked before a batch, rather than one per file."
  (interactive "P")
  (let* ((notes (heks/import--notes-p notes))
         (files (heks/import--marked-files))
         (targets (mapcar (lambda (file) (heks/import--target file notes))
                          files))
         (force (when (seq-some #'file-exists-p targets)
                  (if (yes-or-no-p
                       (format "%d Org files are already there; write over them? "
                               (length (seq-filter #'file-exists-p targets))))
                      t 'keep)))
         (written 0)
         (kept 0))
    (if (null files)
        (message "No Markdown file in this project")
      (dolist (file files)
        (if (heks/import-markdown-file file notes force)
            (setq written (1+ written))
          (setq kept (1+ kept))))
      (message "Imported %d of %d Markdown files as Org%s"
               written (length files)
               (if (> kept 0) (format " (%d kept as they were)" kept) "")))))

(use-package emacs
  :ensure nil
  :bind (("C-c n m" . heks/import-markdown)
         ("C-c n M" . heks/markdown-region-to-org)))

(provide 'heks/import)

;;; import.el ends here
