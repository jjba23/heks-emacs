;;; render.el --- Render a buffer into something to read  -*- lexical-binding: t -*-

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

;; A file that is written to be read -- a README, a changelog, an API
;; specification -- reads better with its Markdown turned into headings and
;; tables than it does as text with `#' in front of the titles.  This module
;; is the one place that knows how to do that: it renders a buffer to HTML
;; and shows it in an Emacs buffer (EWW, which follows links and renders the
;; stylesheet inline), or in the real browser, or as a file next to the
;; source.
;;
;; Two rules shape it:
;;
;;   * the renderer is a pure function from a string to HTML, so it can be
;;     tested without a frame or a network, and needs no external tool: no
;;     pandoc, no node, no network at any point;
;;   * a preview follows its buffer.  `heks-emacs-preview-follow-mode'
;;     re-renders on save, which is what makes it worth leaving open next to
;;     the file being edited.
;;
;; Markdown is rendered here; OpenAPI is rendered by `modules/openapi.el',
;; which asks this module for the document it wraps its rendering in; Org is
;; exported by Org's own exporter, which is asked for the body of the note and
;; nothing around it, so a note has the shape a Markdown file has: this
;; module's document, this module's stylesheet and this module's contents
;; list; plain HTML is used as it is.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
;; `browse-url' turns a file name into the URL the preview and the browser
;; both want; EWW is loaded when a preview is actually shown, because it
;; drags in the URL library and the DOM parser with it.
(require 'browse-url)

(defgroup heks-emacs-preview nil
  "Rendering and previewing the buffer being edited."
  :group 'tools)

(defcustom heks-emacs-preview-buffer-name "*heks-emacs preview*"
  "The buffer a preview is shown in."
  :type 'string)

(defcustom heks-emacs-preview-follow-on-save t
  "Whether a preview re-renders itself when its source is saved."
  :type 'boolean)

(defcustom heks-emacs-render-toc-headings 3
  "How many headings a document needs before it gets a table of contents.

A note with two sections is read from the top; a README with eight is
navigated, and the first thing a reader wants is the list of them."
  :type 'integer)

;;
;; ====== Turning text into HTML ======
;;

(defun heks-emacs-render--escape (text &optional attribute)
  "Return TEXT with the characters that mean something in HTML escaped.

When ATTRIBUTE is non-nil the quote is escaped too, for text that goes
inside an attribute value."
  (let ((escaped (replace-regexp-in-string "&" "&amp;" text t t)))
    (setq escaped (replace-regexp-in-string "<" "&lt;" escaped t t))
    (setq escaped (replace-regexp-in-string ">" "&gt;" escaped t t))
    (when attribute
      (setq escaped (replace-regexp-in-string "\"" "&quot;" escaped t t)))
    escaped))

(defvar heks-emacs-render--base-directory nil
  "The directory a document's relative links are resolved against.

Bound while rendering, so that `![a diagram](images/a.png)' in a file finds
the image that sits next to it rather than one next to the preview, which
lives in a temporary directory.")

(defun heks-emacs-render--resolve (url)
  "Return URL, made absolute against `heks-emacs-render--base-directory'."
  (cond ((or (string-empty-p url)
             (string-match-p "\\`\\([a-zA-Z][a-zA-Z0-9+.-]*:\\|#\\|/\\)" url))
         url)
        (heks-emacs-render--base-directory
         (browse-url-file-url
          (expand-file-name url heks-emacs-render--base-directory)))
        (t url)))

(defun heks-emacs-render--split-code-spans (text)
  "Split TEXT at its `code spans', returning (IS-CODE . TEXT) pieces.

Code is found first because inside a code span an asterisk is an asterisk:
`a *b*' is code, not emphasis."
  (let ((start 0) (pieces nil) (length (length text)))
    (while (string-match "`\\([^`]+\\)`" text start)
      (when (> (match-beginning 0) start)
        (push (cons nil (substring text start (match-beginning 0))) pieces))
      (push (cons t (match-string 1 text)) pieces)
      (setq start (match-end 0)))
    (when (< start length)
      (push (cons nil (substring text start)) pieces))
    (nreverse pieces)))

(defun heks-emacs-render--inline-markup (text)
  "Turn the emphasis, links and images of TEXT into HTML.

TEXT is plain text, not yet escaped: escaping happens here so that the
markup is found in what the author wrote."
  (let ((result (heks-emacs-render--escape text)))
    ;; Autolinks first: `&lt;https://...&gt;' is what an escaped one looks
    ;; like by the time the patterns below run.
    (setq result (replace-regexp-in-string
                  "&lt;\\(https?://[^ <]+\\)&gt;"
                  "<a href=\"\\1\">\\1</a>" result t))
    ;; Images before links: an image is a link with a bang in front of it.
    (setq result
          (replace-regexp-in-string
           "!\\[\\([^]]*\\)\\](\\([^) \t]+\\)\\(?:[ \t]+\"[^\"]*\"\\)?)"
           ;; The replacement function is called with the match and
           ;; nothing else, and the helpers below run regexps of their own,
           ;; so the groups are read out first.
           (lambda (match)
             (let ((alt (match-string 1 match))
                   (src (match-string 2 match)))
               (format "<img src=\"%s\" alt=\"%s\">"
                       (heks-emacs-render--resolve src)
                       (heks-emacs-render--escape alt t))))
           result t t))
    (setq result
          (replace-regexp-in-string
           "\\[\\([^]]*\\)\\](\\([^) \t]+\\)\\(?:[ \t]+\"[^\"]*\"\\)?)"
           (lambda (match)
             (let ((text (match-string 1 match))
                   (href (match-string 2 match)))
               (format "<a href=\"%s\">%s</a>"
                       (heks-emacs-render--resolve href) text)))
           result t t))
    ;; Strong before emphasis, so that `**x**' is not read as two
    ;; one-asterisk pairs with nothing between them.
    (setq result (replace-regexp-in-string "\\*\\*\\([^*]+\\)\\*\\*"
                                           "<strong>\\1</strong>" result t))
    (setq result (replace-regexp-in-string "__\\([^_]+\\)__"
                                           "<strong>\\1</strong>" result t))
    (setq result (replace-regexp-in-string "\\*\\([^*\n]+\\)\\*"
                                           "<em>\\1</em>" result t))
    (setq result (replace-regexp-in-string "\\(\\`\\|[^_a-zA-Z]\\)_\\([^_\n]+\\)_"
                                           "\\1<em>\\2</em>" result t))
    ;; Strikethrough and hard line breaks, the last two things a README
    ;; actually uses.
    (setq result (replace-regexp-in-string "~~\\([^~]+\\)~~"
                                           "<del>\\1</del>" result t))
    result))

(defun heks-emacs-render--inline (text)
  "Return TEXT, with its inline Markdown turned into HTML."
  (mapconcat (lambda (piece)
               (if (car piece)
                   (format "<code>%s</code>"
                           (heks-emacs-render--escape (cdr piece)))
                 (heks-emacs-render--inline-markup (cdr piece))))
             (heks-emacs-render--split-code-spans text)
             ""))

;;
;; ====== Colouring the code ======
;;
;; A README with a code block in it reads better when the code is coloured
;; the way it is coloured in the buffer, and there is no reason to reach for
;; a highlighter written outside Emacs: the mode that fontifies the code in
;; a buffer fontifies it in a temporary one, and what it produces is a face
;; on a stretch of text.  This turns those faces into class names -- one
;; class per face, and a rule per class in the stylesheet -- so that the
;; page is the colours of the theme that is current *now* rather than the
;; theme that was current when the file was written.

(defvar heks-emacs-render--faces nil
  "The faces the rendering in progress has used.

Collected while the body is rendered, then written into the stylesheet
that wraps it, because a document knows which faces it used only after
its body has been turned into HTML.")

(defconst heks-emacs-render-language-modes
  '(("bash" . sh-mode) ("sh" . sh-mode) ("shell" . sh-mode)
    ("console" . sh-mode) ("zsh" . sh-mode)
    ("elisp" . emacs-lisp-mode) ("el" . emacs-lisp-mode)
    ("lisp" . emacs-lisp-mode) ("scheme" . scheme-mode)
    ("guile" . scheme-mode) ("guix" . scheme-mode)
    ("js" . js-mode) ("javascript" . js-mode) ("json" . js-mode)
    ("ts" . typescript-ts-mode) ("typescript" . typescript-ts-mode)
    ("yml" . yaml-mode) ("yaml" . yaml-mode)
    ("golang" . go-mode) ("rs" . rust-mode) ("tf" . terraform-mode)
    ("tfvars" . terraform-mode) ("hcl" . hcl-mode)
    ("psql" . sql-mode) ("postgres" . sql-mode))
  "The language names a code fence uses, and the mode that reads them.

A fence says `bash' where the mode is `sh-mode' and `elisp' where it is
`emacs-lisp-mode'; the names that are not simply the mode's are here.")

(defun heks-emacs-render-language-mode (language)
  "Return the major mode that reads LANGUAGE, or nil when none does.

LANGUAGE is what a code fence says.  The name is tried as written, as
`NAME-mode' and as `NAME-ts-mode', after this module's own table of the
names that are not the mode's."
  (let ((name (downcase (string-trim language))))
    (when (and name (not (string-empty-p name)))
      (or (cdr (assoc name heks-emacs-render-language-modes #'equal))
          (seq-find (lambda (candidate) (and candidate (fboundp candidate)))
                    (list (intern-soft (concat name "-mode"))
                          (intern-soft (concat name "-ts-mode"))))))))

(defun heks-emacs-render--face-of (value)
  "Return the face that VALUE, a `face' text property, stands for.

The property is often a list -- `(font-lock-keyword-face)' or an
anonymous `(:inherit bold)' -- and the last symbol in it is the face
that matters, because it is the one that was added last."
  (let ((candidates (cond ((symbolp value) (list value))
                          ((consp value) value))))
    (car (last (seq-filter #'symbolp candidates)))))

(defun heks-emacs-render--fontify (code mode)
  "Return CODE as HTML spans, fontified in a temporary buffer with MODE.

Mode hooks do not run -- a preview is not the place to start a language
server -- and nil is returned when the mode did not fontify anything at
all, which is what a mode for a language this Emacs cannot read looks
like.  The faces used are remembered, so that the stylesheet written
after the body can colour them."
  (with-temp-buffer
    (insert code)
    (let ((delay-mode-hooks t)
          (inhibit-message t)
          (create-lockfiles nil))
      (funcall mode)
      (setq font-lock-mode t)
      (ignore-errors (font-lock-ensure))
      (when font-lock-mode
        (let ((position (point-min))
              (pieces nil))
          (while (< position (point-max))
            (let* ((next (next-single-property-change position 'face nil (point-max)))
                   (face (heks-emacs-render--face-of (get-text-property position 'face)))
                   (text (buffer-substring-no-properties position next)))
              (when face
                (push face heks-emacs-render--faces))
              (push (if face
                        (format "<span class=\"hl-%s\">%s</span>" face
                                (heks-emacs-render--escape text))
                      (heks-emacs-render--escape text))
                    pieces)
              (setq position next)))
          (apply #'concat (nreverse pieces)))))))

(defun heks-emacs-render-highlight (code language)
  "Return CODE as HTML, coloured the way LANGUAGE's mode colours it.

A language no mode answers for is escaped and left alone; the code is
escaped either way, because a snippet is where a `<' is a `<'.  Each face
gets a class -- `hl-font-lock-keyword-face' -- which the stylesheet
turns into the face's colours, and the faces used are remembered so that
the stylesheet can be written after the body is finished."
  (let ((mode (heks-emacs-render-language-mode language)))
    (or (and mode (ignore-errors (heks-emacs-render--fontify code mode)))
        (heks-emacs-render--escape code))))

(defun heks-emacs-render--face-attribute (face attribute fallback)
  "Return FACE's ATTRIBUTE as a value, or FALLBACK when it has none.

A face that says nothing about an attribute inherits it from what is
around it, which is what the class then does too: no rule is written for
a colour the face does not have, so a theme that leaves the font-lock
faces to the default face's colour keeps them that way.

The value is returned as the face states it, because an attribute is not
always a colour: a weight is the symbol `bold', an underline may be a
plist, and the caller has to recognise them to write a rule at all."
  (let ((value (ignore-errors (face-attribute face attribute nil t))))
    (cond ((eq value 'unspecified) fallback)
          ((and (stringp value) (string-empty-p value)) fallback)
          ((null value) fallback)
          (t value))))

(defun heks-emacs-render-highlight-css ()
  "Return the rules that colour the faces the last rendering used.

One rule per face, so that the class names in the body are what is
coloured and the colours come from the theme being used now: bold stays
bold, a keyword is the colour of a keyword, and a document written in a
light theme is still readable in a dark one."
  (mapconcat
   (lambda (face)
     (let ((foreground (heks-emacs-render--face-attribute face :foreground nil))
           (background (heks-emacs-render--face-attribute face :background nil))
           (weight (heks-emacs-render--face-attribute face :weight nil))
           (slant (heks-emacs-render--face-attribute face :slant nil))
           (underline (heks-emacs-render--face-attribute face :underline nil)))
       (format ".hl-%s { %s%s%s%s%s }" face
               (if foreground (format "color: %s; " foreground) "")
               (if background (format "background: %s; " background) "")
               (cond ((eq weight 'bold) "font-weight: 700; ")
                     ((eq weight 'light) "font-weight: 300; ")
                     (t ""))
               (cond ((memq slant '(italic oblique)) "font-style: italic; ")
                     (t ""))
               (if underline "text-decoration: underline; " ""))))
   (delete-dups (reverse heks-emacs-render--faces))
   "\n"))

(defun heks-emacs-render--indent-of (line)
  "Return the width of the indentation of LINE, counting a tab as four."
  (let ((width 0)
        (index 0))
    (while (and (< index (length line))
                (memq (aref line index) '(?\s ?\t)))
      (setq width (+ width (if (eq (aref line index) ?\t) 4 1)))
      (setq index (1+ index)))
    width))

(defun heks-emacs-render--cells (line)
  "Return the cells of a table row LINE."
  (let ((trimmed (string-trim line)))
    (setq trimmed (string-remove-prefix "|" trimmed))
    (setq trimmed (string-remove-suffix "|" trimmed))
    (mapcar #'string-trim (split-string trimmed "|"))))

(defun heks-emacs-render--table? (line next)
  "Return whether LINE starts a table, given the NEXT line.

A table is a row of cells followed by a delimiter row: `| a | b |' then
`|---|:--:|'."
  (and line next
       (string-match-p "|" line)
       ;; A pipe in the delimiter row too: a paragraph with a rule
       ;; under it (`text' then `---') is a setext heading, not a
       ;; one-column table.
       (string-match-p "|" next)
       (string-match-p "\\`[ \t]*|?[ \t]*:?-\\{2,\\}" next)))

(defun heks-emacs-render--table (lines index)
  "Render the table that starts at INDEX in LINES.

Return a cons of the HTML and the index just past the table."
  (let ((header (heks-emacs-render--cells (nth index lines)))
        (aligns (mapcar (lambda (cell)
                          (cond ((and (string-prefix-p ":" cell)
                                      (string-suffix-p ":" cell)) "center")
                                ((string-suffix-p ":" cell) "right")
                                (t "left")))
                        (heks-emacs-render--cells (nth (1+ index) lines))))
        (rows nil)
        (i (+ index 2))
        (n (length lines)))
    (while (and (< i n)
                (string-match-p "|" (nth i lines))
                (not (string-match-p "\\`[ \t]*\\'" (nth i lines))))
      (push (heks-emacs-render--cells (nth i lines)) rows)
      (setq i (1+ i)))
    ;; The alignment of a column comes from its position in the delimiter
    ;; row, not from the cell's text: a row of `| a | a |' has two columns
    ;; that look alike and align differently.
    (cons
     (concat
      "<table>\n<thead><tr>"
      (cl-loop for cell in header
               for index from 0
               collect (format "<th style=\"text-align:%s\">%s</th>"
                               (or (nth index aligns) "left")
                               (heks-emacs-render--inline cell))
               into cells
               finally return (apply #'concat cells))
      "</tr></thead>\n"
      (if rows
          (concat "<tbody>"
                  (mapconcat
                   (lambda (row)
                     (concat "<tr>"
                             (cl-loop for cell in row
                                      for index from 0
                                      collect (format "<td style=\"text-align:%s\">%s</td>"
                                                      (or (nth index aligns) "left")
                                                      (heks-emacs-render--inline cell))
                                      into cells
                                      finally return (apply #'concat cells))
                             "</tr>"))
                   (nreverse rows) "")
                  "</tbody>")
        "")
      "</table>")
     i)))

(defun heks-emacs-markdown-to-html (text)
  "Return the Markdown in TEXT rendered as a fragment of HTML.

The subset covered is the one documents are written in: headings, fenced
code, tables, lists (including task lists), blockquotes, thematic breaks,
paragraphs, and the inline markup -- emphasis, code spans, links and
images.  A block of raw HTML is passed through, so a README can embed a
badge.  Indented code blocks are not recognised: the lists here are more
likely than the code."
  (let* ((lines (split-string (string-trim-right text) "\n"))
         (n (length lines))
         (i 0)
         (out nil)
         (paragraph nil)
         (lists nil))            ; stack of (INDENT . ORDERED-P)
    ;; `cl-labels', not `cl-flet': the helpers call each other (`closing a
    ;; paragraph' pushes through `emit'), and only `cl-labels' makes every
    ;; one of them visible to the others.
    (cl-labels ((emit (html) (push html out))
              (close-paragraph ()
                (when paragraph
                  ;; The NUL a hard break left behind becomes its tag only
                  ;; now, after escaping has run over the text.
                  ;; The space that joined the two lines belongs to the
                  ;; joining, not to the text, so it goes with the newline
                  ;; it is replacing.
                  (emit (replace-regexp-in-string
                         "\u0000 *" "<br>"
                         (format "<p>%s</p>"
                                 (heks-emacs-render--inline
                                  (mapconcat #'identity (nreverse paragraph) " ")))
                         t t))
                  (setq paragraph nil)))
              ;; UP-TO is the indentation a list has to be nested deeper
              ;; than to be closed.  A block that is not a list closes them
              ;; all, and says so with -1, because a list at column zero is
              ;; deeper than -1 like any other: passing 0 there left the
              ;; last list of a section unclosed, and the heading that
              ;; followed it inside it.
              (close-lists (up-to)
                (while (and lists (> (caar lists) up-to))
                  (emit (if (cdar lists) "</ol>" "</ul>"))
                  (pop lists))))
      (while (< i n)
        (let* ((line (nth i lines))
               (trimmed (string-trim line))
               (consumed 1))
          (cond
           ;; A blank line ends the paragraph; lists stay open across it,
           ;; because that is how Markdown reads a loose list.
           ((string-empty-p trimmed)
            (close-paragraph))

           ;; Fenced code, with the language it names kept as a class.
           ((string-match "\\`\\(```+\\)\\(.*\\)\\'" trimmed)
            (close-paragraph)
            (close-lists -1)
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
              (emit (format "<pre class=\"code\"><code%s>%s</code></pre>"
                            (if (string-empty-p info)
                                ""
                              (format " class=\"language-%s\""
                                      (heks-emacs-render--escape info t)))
                            (heks-emacs-render-highlight
                             (mapconcat #'identity (nreverse body) "\n")
                             info)))))

           ;; A table, before the list branch: a row of cells also starts
           ;; with a dash-and-space when it is `| - |'.
           ((heks-emacs-render--table? line (nth (1+ i) lines))
            (close-paragraph)
            (close-lists -1)
            (let ((rendered (heks-emacs-render--table lines i)))
              (emit (car rendered))
              (setq consumed (- (cdr rendered) i))))

           ;; A blockquote: the quoted lines render as their own document.
           ((string-match "\\`> ?\\(.*\\)\\'" trimmed)
            (close-paragraph)
            (close-lists -1)
            (let ((quoted nil)
                  (j i))
              (while (and (< j n)
                          (string-match "\\`> ?\\(.*\\)\\'" (string-trim (nth j lines))))
                (push (match-string 1 (string-trim (nth j lines))) quoted)
                (setq j (1+ j)))
              (setq consumed (- j i))
              (emit (format "<blockquote>%s</blockquote>"
                            (string-trim
                             (heks-emacs-markdown-to-html
                              (mapconcat #'identity (nreverse quoted) "\n")))))))

           ((string-match "\\`\\(#\\{1,6\\}\\)[ \t]+\\(.*?\\)[ \t]*#*\\'" trimmed)
            (close-paragraph)
            (close-lists -1)
            (let ((level (length (match-string 1 trimmed))))
              (emit (format "<h%d>%s</h%d>" level
                            (heks-emacs-render--inline (match-string 2 trimmed))
                            level))))

           ;; A setext heading is a paragraph with a line under it.
           ((and paragraph (string-match "\\`=\\{2,\\}[ \t]*\\'" trimmed))
            (let ((text (mapconcat #'identity (nreverse paragraph) " ")))
              (setq paragraph nil)
              (emit (format "<h1>%s</h1>" (heks-emacs-render--inline text)))))
           ((and paragraph (string-match "\\`-\\{2,\\}[ \t]*\\'" trimmed))
            (let ((text (mapconcat #'identity (nreverse paragraph) " ")))
              (setq paragraph nil)
              (emit (format "<h2>%s</h2>" (heks-emacs-render--inline text)))))

           ((string-match "\\`\\([-*_]\\)\\([ \t]*\\1\\)\\{2,\\}[ \t]*\\'" trimmed)
            (close-paragraph)
            (close-lists -1)
            (emit "<hr>"))

           ;; A list item, nested by its indentation.
           ((string-match "\\`\\([-*+]\\|[0-9]+[.)]\\)[ \t]+\\(.*\\)\\'" trimmed)
            (let* ((indent (heks-emacs-render--indent-of line))
                   (ordered (string-match-p "\\`[0-9]" (match-string 1 trimmed)))
                   (item (match-string 2 trimmed)))
              (close-paragraph)
              ;; Close the deeper lists first, then open the one this item
              ;; belongs to: an item indented less than the previous one
              ;; ends that list and may start a shallower one.
              (close-lists indent)
              ;; A numbered list that follows bullet points at the same
              ;; indentation is a new list, not more items of the old one.
              (when (and lists (= indent (caar lists)) (not (eq (cdar lists) ordered)))
                (emit (if (cdar lists) "</ol>" "</ul>"))
                (pop lists))
              (when (or (null lists) (> indent (caar lists)))
                (push (cons indent ordered) lists)
                (emit (if ordered "<ol>" "<ul>")))
              ;; Task lists are the one extension every README uses.
              (when (string-match "\\`\\[\\([ xX]?\\)\\][ \t]+\\(.*\\)\\'" item)
                (setq item (format "%s %s"
                                   (if (string-blank-p (match-string 1 item)) "☐" "☑")
                                   (match-string 2 item))))
              (emit (format "<li>%s</li>" (heks-emacs-render--inline item)))))

           ;; Raw HTML blocks pass through, so a badge or a `<details>' in
           ;; a README survives being previewed.
           ((and (string-prefix-p "<" trimmed)
                 (string-match-p "\\`</?[a-zA-Z][^>]*>" trimmed))
            (close-paragraph)
            (close-lists -1)
            (emit line))

           (t
            ;; A line that ends in two spaces is a hard break, which is
            ;; what a README uses to keep an address or a list of flags
            ;; one line each.  The NUL is a marker no document contains;
            ;; it is turned into a tag once the paragraph is joined and
            ;; escaped.
            (push (if (string-suffix-p "  " line)
                      (concat (string-trim-right line) "\u0000")
                    line)
                  paragraph)))
          (setq i (+ i consumed))))
      (close-paragraph)
      (close-lists -1))
    (concat (string-join (nreverse out) "\n") "\n")))

;;
;; ====== The document the fragment goes in ======
;;

(defun heks-emacs-render--color (attribute fallback)
  "Return the colour of the default face's ATTRIBUTE, or FALLBACK."
  (let ((value (ignore-errors (face-attribute 'default attribute nil t))))
    (if (and (stringp value) (not (string-empty-p value))
             (not (string= value "unspecified")))
        value
      fallback)))

(defun heks-emacs-render--mix (one two weight)
  "Return ONE blended towards TWO by WEIGHT, as a colour string."
  (let* ((first (color-values one))
         (second (color-values two)))
    (if (or (null first) (null second))
        one
      (apply #'format "#%02x%02x%02x"
             (cl-mapcar (lambda (a b)
                          (round (/ (+ (* a (- 1 weight)) (* b weight)) 257.0)))
                        first second)))))

(defun heks-emacs-render-palette ()
  "Return the colours of the current theme, as a plist.

Six colours are enough for everything this configuration writes, and they
are worked out here so that a document and a presentation look like each
other: `:background' and `:foreground' are the theme's own, `:surface' is
a panel a step away from the background, `:border' the line between two
of them, `:muted' text that is there but not the point, and `:accent' the
colour of a link."
  (let* ((background (heks-emacs-render--color :background "#ffffff"))
         (foreground (heks-emacs-render--color :foreground "#000000")))
    (list :background background
          :foreground foreground
          :surface (heks-emacs-render--mix background foreground 0.06)
          :border (heks-emacs-render--mix background foreground 0.20)
          :muted (heks-emacs-render--mix foreground background 0.45)
          :accent (heks-emacs-render--color :link "#2a6fd6"))))

(defun heks-emacs-render-stylesheet ()
  "Return the stylesheet a rendered document carries.

It is built from the colours of the current theme, so a preview looks
like the rest of Emacs, and embedded in the document rather than linked,
so that neither the preview nor an exported file needs the network."
  (let* ((palette (heks-emacs-render-palette))
         (background (plist-get palette :background))
         (foreground (plist-get palette :foreground))
         (surface (plist-get palette :surface))
         (border (plist-get palette :border))
         (muted (plist-get palette :muted))
         (accent (plist-get palette :accent)))
    (concat
     (format "
:root { color-scheme: light dark; }
body { max-width: 60em; margin: 0 auto; padding: 2em 1.5em 6em;
       font-family: system-ui, sans-serif; font-size: 16px; line-height: 1.6;
       background: %s; color: %s; }
h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.6em 0 0.6em; font-weight: 600; }
h1 { font-size: 1.9em; border-bottom: 3px solid %s; padding-bottom: 0.2em; }
h2 { font-size: 1.5em; border-bottom: 1px solid %s; padding-bottom: 0.2em; }
h3 { font-size: 1.25em; } h4 { font-size: 1.1em; } h5, h6 { font-size: 1em; color: %s; }
p, ul, ol, blockquote, table, pre { margin: 0.9em 0; }
a { color: %s; text-decoration: none; } a:hover { text-decoration: underline; }
code, pre, kbd { font-family: ui-monospace, monospace; font-size: 0.92em; }
code { background: %s; padding: 0.1em 0.35em; border-radius: 4px; }
pre.code { background: %s; border: 1px solid %s; border-radius: 6px;
           padding: 0.9em 1.1em; overflow-x: auto; }
pre.code code { background: none; padding: 0; }
pre.plain { white-space: pre-wrap; }
blockquote { border-left: 4px solid %s; margin-left: 0; padding: 0.1em 0 0.1em 1em;
             color: %s; }
table { border-collapse: collapse; width: 100%%; }
th, td { border: 1px solid %s; padding: 0.45em 0.7em; text-align: left; }
th { background: %s; font-weight: 600; }
hr { border: none; border-top: 1px solid %s; margin: 2em 0; }
img { max-width: 100%%; }
.headline { color: %s; font-size: 0.85em; font-weight: 500;
            text-transform: uppercase; letter-spacing: 0.08em; }
.badge { display: inline-block; font-size: 0.8em; font-weight: 700;
         padding: 0.15em 0.5em; border-radius: 4px;
         background: %s; color: %s; }

"
            ;; body
            background foreground
            ;; the two rules under the headings
            border border
            ;; muted text (h5 and h6, blockquote, the headline)
            muted
            ;; links
            accent
            ;; code, inline and fenced
            surface surface border
            ;; blockquote framing and text
            border muted
            ;; tables
            border surface
            ;; the rule between sections
            border
            ;; the headline above the title
            muted
            ;; the badge chip: a filled label
            foreground background)
     ;; The colours of the code, one rule per face the rendering used.
     (heks-emacs-render-highlight-css)
     (format "
nav.toc { background: %s; border: 1px solid %s; border-radius: 6px;
          padding: 0.6em 1em; margin: 1.2em 0; break-inside: avoid; }
nav.toc .headline { margin: 0 0 0.4em; }
nav.toc ul { list-style: none; margin: 0; padding: 0; columns: 2; }
nav.toc li { margin: 0.15em 0; break-inside: avoid; }
nav.toc li.toc-depth-3 { margin-left: 1.2em; }
nav.toc li.toc-depth-4 { margin-left: 2.4em; }

@media print {
  @page { margin: 1.5cm; }
  body { max-width: none; padding: 0; }
  pre.code { overflow: visible; white-space: pre-wrap; }
  h1, h2, h3, h4, h5, h6 { break-after: avoid; }
  table, tr, pre, blockquote, img { break-inside: avoid; }
  a { color: inherit; text-decoration: underline; }
}
"
             surface border))))

;;
;; ====== Headings, anchors and the contents list ======
;;

(defun heks-emacs-render--heading-text (html)
  "Return the text of a heading's HTML, with its markup taken off."
  (let ((text (replace-regexp-in-string "<[^>]+>" "" html)))
    (setq text (replace-regexp-in-string "&[a-zA-Z]+;\|&#[0-9]+;" " " text))
    (string-trim (replace-regexp-in-string "[ \t]+" " " text))))

(defun heks-emacs-render-anchor (text)
  "Return an HTML id for TEXT, which is what a link points at.

An id may not contain a space, so the spaces become dashes and the
characters HTML would rather not see inside one are dropped."
  (let ((slug (downcase text)))
    (setq slug (replace-regexp-in-string "[^a-z0-9 _-]+" "" slug))
    (setq slug (replace-regexp-in-string "[ _]+" "-" slug))
    (setq slug (string-trim slug "-"))
    (if (string-empty-p slug) "section" slug)))

(defun heks-emacs-render--unique-anchor (text taken)
  "Return an id for TEXT that TAKEN, a hash table, does not hold yet."
  (let ((base (heks-emacs-render-anchor text))
        (id nil)
        (count 2))
    (setq id base)
    (while (gethash id taken)
      (setq id (format "%s-%d" base count)
            count (1+ count)))
    (puthash id t taken)
    id))

(defun heks-emacs-render--headings (html)
  "Give every heading in HTML an id, and return (HTML . ENTRIES).

An id is what makes a heading linkable and what a contents list points
at, and it is made here rather than by every renderer: a Markdown
heading and an OpenAPI operation end up in the same kind of page.  A
heading that already has an id keeps it, and that id is the one the
contents list points at: the OpenAPI renderer names its operations after
the method and the path, and a slug made from their text would be a link
to nowhere."
  (let ((taken (make-hash-table :test #'equal))
        (entries nil)
        (out nil)
        (position 0)
        (at 0))
    (while (string-match "<h\\([1-6]\\)\\([^>]*\\)>\\(.*?\\)</h\\1>" html position)
      (let* (;; The outer match is read out before the id below is looked
             ;; for in the attributes, because that search is a match of its
             ;; own and would otherwise leave the outer one behind.
             (beg (match-beginning 0))
             (end (match-end 0))
             (whole (match-string 0 html))
             (level (string-to-number (match-string 1 html)))
             (attributes (match-string 2 html))
             (inner (match-string 3 html))
             (text (heks-emacs-render--heading-text inner))
             (written (and (string-match "\\bid=\"\\([^\" ]+\\)\"" attributes)
                           (match-string 1 attributes)))
             (id (if written
                     (progn (puthash written t taken) written)
                   (heks-emacs-render--unique-anchor text taken))))
        (push (substring html at beg) out)
        (push (if written
                  whole
                (format "<h%d id=\"%s\"%s>%s</h%d>" level id attributes inner level))
              out)
        (push (list level id text) entries)
        (setq at end
              position end)))
    (push (substring html at) out)
    (cons (apply #'concat (nreverse out)) (nreverse entries))))

(defun heks-emacs-render-toc-entries (entries)
  "Return the headings a contents list should show, from ENTRIES.

The title of a document is not a section of it: an h1 that stands alone
above deeper headings heads the page, and the contents start under it.
Only one level below the shallowest heading is listed, because a
contents list longer than what it lists is worse than none.

ENTRIES is what `heks-emacs-render--headings' collected, as
\(LEVEL ID TEXT) in the order the headings appear."
  (let* ((rest (if (and (cdr entries) (= 1 (car (car entries))))
                   (cdr entries)
                 entries))
         (shallowest (and rest (apply #'min (mapcar #'car rest))))
         (limit (and shallowest (min 4 (1+ shallowest)))))
    (seq-filter (lambda (entry) (<= (car entry) limit)) rest)))

(defun heks-emacs-render-toc (entries)
  "Return a list of contents for ENTRIES, or nil when they are too few."
  (let ((listed (heks-emacs-render-toc-entries entries)))
    (when (and listed (>= (length listed) heks-emacs-render-toc-headings))
      (concat "<nav class=\"toc\" aria-label=\"Contents\">\n"
              "<p class=\"headline\">Contents</p>\n<ul>\n"
              (mapconcat (lambda (entry)
                           (format "<li class=\"toc-depth-%d\"><a href=\"#%s\">%s</a></li>"
                                   (car entry) (nth 1 entry)
                                   (heks-emacs-render--escape (nth 2 entry))))
                         listed "\n")
              "\n</ul>\n</nav>\n"))))

(defun heks-emacs-html-document (title body &optional headline)
  "Return a complete HTML document.

TITLE becomes the title of the document and HEADLINE, when given, the
small line printed above it.  The headings of BODY are given ids, so that
a link to one of them works, and a list of contents is put between the
headline and the body when the body has enough sections to want one."
  (let* ((anchored (heks-emacs-render--headings body))
         (contents (heks-emacs-render-toc (cdr anchored))))
    (format "<!DOCTYPE html>
<html lang=\"en\">
<head>
<meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<title>%s</title>
<style>%s</style>
</head>
<body>
%s
%s%s
</body>
</html>
"
            (heks-emacs-render--escape title)
            ;; The stylesheet is built after the body has been rendered,
            ;; because it colours the faces the body turned out to use.
            (heks-emacs-render-stylesheet)
            (if headline (format "<p class=\"headline\">%s</p>\n"
                                 (heks-emacs-render--escape headline))
              "")
            (or contents "")
            (car anchored))))

;;
;; ====== Which renderer a buffer gets ======
;;

;; The predicates below answer yes or no rather than a position or a
;; sublist, so that `(if (heks-emacs-render-markdown-p) ...)' and a check
;; that expects `t' both read the same.

(defun heks-emacs-render-markdown-p (&optional buffer)
  "Return whether BUFFER, defaulting to the current one, holds Markdown."
  (with-current-buffer (or buffer (current-buffer))
    (and (or (memq major-mode '(markdown-mode markdown-ts-mode gfm-mode))
             (and buffer-file-name
                  (string-match-p "\\.\\(md\\|markdown\\|mkd\\)\\'"
                                  buffer-file-name)))
         t)))

(defun heks-emacs-render-html-p (&optional buffer)
  "Return whether BUFFER, defaulting to the current one, holds HTML."
  (with-current-buffer (or buffer (current-buffer))
    (and (or (memq major-mode '(html-mode html-ts-mode mhtml-mode sgml-mode web-mode))
             (and buffer-file-name
                  (string-match-p "\\.\\(html?\\|xhtml\\)\\'" buffer-file-name)))
         t)))

(defun heks-emacs-render--org-output-type ()
  "Return what `org-html-htmlize-output-type' should be for a preview.

Colouring the code in a note is `htmlize's work and Org says as much: it
hands the block to `htmlize', and with `htmlize' absent -- a batch Emacs
reading this module on its own, with the packages elpaca installs nowhere
near it -- it writes the block as plain text and warns about it, on every
export.  So where `htmlize' is here the colours are asked for as inline
styles, because a preview carries none of Org's own stylesheet and a class
name with no stylesheet behind it is a snippet with no colour; where it is
not, the setting is nil, which is Org's plain text asked for rather than
warned about."
  (if (require 'htmlize nil t) 'inline-css nil))

(defun heks-emacs-render--org-body (buffer)
  "Return the body of BUFFER's Org export, or nil when Org cannot export.

Org is asked for the body only, so that its own stylesheet and its own
header do not end up inside this module's document, and a note ends up with
the same shape as a Markdown file: the contents list is this module's own --
a document is given one when it has enough headings to want one -- so Org's
is asked for rather than left in as a second one, and the code in a note is
coloured by Org itself, with the colours of the theme in force written into
the page, because a preview carries no stylesheet of Org's and a class name
without one is a snippet with no colour."
  (with-current-buffer buffer
    (when (require 'ox-html nil t)
      ;; `let*' rather than `let': the export is asked for in the last
      ;; binding, and `let' evaluates every value before it binds any of
      ;; them, so the settings above it would not be in force yet and Org
      ;; would write its own contents list into the body.
      (let* ((org-html-html-helper-timestamp nil)
             (org-html-postamble nil)
             (org-export-with-toc nil)
             (org-html-htmlize-output-type (heks-emacs-render--org-output-type))
             (html (ignore-errors (org-html-export-as-html nil nil nil t nil))))
        (cond ((bufferp html)
               (with-current-buffer html
                 (string-trim (buffer-string))))
              ((stringp html) (string-trim html))
              (t nil))))))

(defun heks-emacs-render-body (&optional buffer)
  "Return the HTML body for BUFFER, asking the renderer that fits it.

This is the single place that decides how a buffer is previewed, which is
what makes `C-c r p' work in a Markdown file, an OpenAPI specification, an
Org note and a plain text file alike."
  (with-current-buffer (or buffer (current-buffer))
    (let ((heks-emacs-render--base-directory
           (and buffer-file-name (file-name-directory buffer-file-name)))
          ;; Whatever this rendering uses will be in its stylesheet, so
          ;; what the last one used is forgotten here rather than blurred
          ;; into it.
          (heks-emacs-render--faces nil))
      (cond
       ((heks-emacs-render-markdown-p)
        (heks-emacs-markdown-to-html (buffer-string)))
       ((and (fboundp 'heks-emacs-openapi-spec-p) (heks-emacs-openapi-spec-p))
        (heks-emacs-openapi-html))
       ((and (eq major-mode 'org-mode) (heks-emacs-render--org-body (current-buffer))))
       ((heks-emacs-render-html-p) (buffer-string))
       (t (format "<pre class=\"plain\">%s</pre>"
                  (heks-emacs-render--escape (buffer-string))))))))

(defun heks-emacs-render-title (&optional buffer)
  "Return what to call BUFFER's preview."
  (with-current-buffer (or buffer (current-buffer))
    (or (and buffer-file-name (file-name-nondirectory buffer-file-name))
        (buffer-name))))

(defun heks-emacs-render-document (&optional buffer)
  "Return BUFFER's content as a complete HTML document."
  (let ((target (or buffer (current-buffer))))
    (heks-emacs-html-document (heks-emacs-render-title target)
                              (heks-emacs-render-body target)
                              (heks-emacs-render--variant-name target))))

(defun heks-emacs-render--variant-name (buffer)
  "Return the name of the renderer BUFFER is being shown with."
  (with-current-buffer buffer
    (cond ((heks-emacs-render-markdown-p) "Markdown")
          ((and (fboundp 'heks-emacs-openapi-spec-p) (heks-emacs-openapi-spec-p))
           "OpenAPI")
          ((eq major-mode 'org-mode) "Org")
          ((heks-emacs-render-html-p) "HTML")
          (t "Text"))))

;;
;; ====== Showing it ======
;;;

(defvar heks-emacs-preview--files nil
  "Alist of source buffer name to the file its preview was written to.")

(defun heks-emacs-render-file (&optional buffer)
  "Write BUFFER's rendering to a file and return its name.

The file is written once per buffer and rewritten after that, so that EWW
keeps its history for a document that is being edited."
  (let* ((source (or buffer (current-buffer)))
         (key (buffer-name source))
         (known (assoc key heks-emacs-preview--files))
         (file (or (cdr known)
                   (make-temp-file "heks-emacs-preview-" nil ".html"))))
    (unless known
      (push (cons key file) heks-emacs-preview--files))
    (write-region (heks-emacs-render-document source) nil file nil 'silent)
    file))

(defun heks-emacs-preview--data-buffer (file)
  "Return a buffer holding FILE as the answer EWW reads a document from.

`eww-render' takes the document out of the buffer it is called in and
kills that buffer when it is done, which is what it is for: it is the
callback of a retrieval, and the buffer is the retrieval's own.  A file
that is already here was never retrieved, so the answer it would have
arrived as is made -- the content type, then the document -- and EWW is
asked to render that."
  (with-current-buffer (generate-new-buffer " *heks-emacs preview data*")
    (set-buffer-multibyte nil)
    (insert "Content-type: text/html\n\n")
    (insert-file-contents file)
    (goto-char (point-min))
    (current-buffer)))

(defun heks-emacs-preview--render (file target)
  "Show FILE's HTML in TARGET, which becomes an EWW buffer again.

TARGET is prepared the way EWW prepares its own buffer, so what it ends up
holding is what `eww-open-file' would have shown -- links, faces, the whole
of the stylesheet -- in a buffer this module can find again and render
into a second time."
  (require 'eww)
  (with-current-buffer target
    (eww-setup-buffer))
  (with-current-buffer (heks-emacs-preview--data-buffer file)
    (eww-render nil (browse-url-file-url file) nil target))
  target)

(defun heks-emacs-preview (&optional buffer)
  "Render BUFFER and show it in the Emacs buffer made for previews.

EWW renders it, which means links work and the stylesheet that came with
the document is applied, without leaving Emacs."
  (interactive)
  (let* ((source (or buffer (current-buffer)))
         (file (heks-emacs-render-file source))
         (target (get-buffer-create heks-emacs-preview-buffer-name)))
    (heks-emacs-preview--render file target)
    (pop-to-buffer target)
    (message "%s preview: %s" (heks-emacs-render--variant-name source) file)))

(defun heks-emacs-preview-browser (&optional buffer)
  "Render BUFFER and open it in the browser configured for Emacs.

This is the faithful path: the browser applies the whole stylesheet,
which is what one wants before sharing a document or checking a table's
alignment."
  (interactive)
  (let ((file (heks-emacs-render-file (or buffer (current-buffer)))))
    (browse-url (browse-url-file-url file))
    (message "Preview opened in the browser: %s" file)))

(defun heks-emacs-preview-export (&optional buffer)
  "Render BUFFER next to its file, as a `.html' file to keep."
  (interactive)
  (let* ((source (or buffer (current-buffer)))
         (file (or buffer-file-name (user-error "This buffer is not visiting a file")))
         (target (concat (file-name-sans-extension file) ".html")))
    (write-region (heks-emacs-render-document source) nil target)
    (message "Wrote %s" target)
    target))

;;
;; ====== A preview that follows its buffer ======
;;;

(defun heks-emacs-preview--reload (buffer)
  "Show BUFFER's current rendering in the preview buffer again."
  (let ((file (cdr (assoc (buffer-name buffer) heks-emacs-preview--files)))
        (target (get-buffer heks-emacs-preview-buffer-name)))
    (when (and file target)
      (heks-emacs-preview--render file target)
      t)))

(defun heks-emacs-preview-follow--refresh (&optional buffer)
  "Re-render the preview of BUFFER, which has just been saved.

Only buffers that asked for it reach here: the mode installs this as a
buffer-local `after-save-hook', and a preview is only worth refreshing
while it is on screen."
  (let ((source (or buffer (current-buffer))))
    (when (and heks-emacs-preview-follow-on-save
               (get-buffer-window heks-emacs-preview-buffer-name))
      (require 'eww)
      (heks-emacs-render-file source)
      (heks-emacs-preview--reload source))))

(defun heks-emacs-preview-refresh ()
  "Re-render the preview of this buffer if one is showing."
  (interactive)
  (heks-emacs-render-file (current-buffer))
  (if (heks-emacs-preview--reload (current-buffer))
      (message "Preview refreshed")
    (heks-emacs-preview)))

(define-minor-mode heks-emacs-preview-follow-mode
  "Re-render this buffer's preview whenever the buffer is saved.

Off by default: a preview refreshed on every save is the point of leaving
it open, but it costs a render per save, so it is asked for."
  :lighter " Preview"
  (if heks-emacs-preview-follow-mode
      (add-hook 'after-save-hook #'heks-emacs-preview-follow--refresh nil t)
    (remove-hook 'after-save-hook #'heks-emacs-preview-follow--refresh t)))

(defun heks-emacs-preview-toggle-follow ()
  "Turn the preview's re-rendering on save on or off for this buffer."
  (interactive)
  (heks-emacs-preview-follow-mode 'toggle)
  (when heks-emacs-preview-follow-mode
    (heks-emacs-preview)))

;; Colouring the code in a note is `htmlize's work, and Org says as much:
;; it is what Org hands a source block to, and without it a block is text.
;; Declared here because this module is what asks Org for the colours.
(use-package htmlize
  :ensure t)

(use-package emacs
  :ensure nil
  :bind (("C-c r p" . heks-emacs-preview)
         ("C-c r b" . heks-emacs-preview-browser)
         ("C-c r e" . heks-emacs-preview-export)
         ("C-c r m" . heks-emacs-preview-toggle-follow)
         ("C-c r r" . heks-emacs-preview-refresh)))

(provide 'heks-emacs/render)

;;; render.el ends here
