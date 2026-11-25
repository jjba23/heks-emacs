;;; dev-docstring.el --- Javadoc, KDoc and Scheme docstrings, rendered where they are written -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; A docstring is written in one syntax and read in another.  A Javadoc or
;; KDoc comment is HTML and at-tags around prose; a Scheme docstring is a
;; string literal whose prose is often Texinfo.  Read as source, both are
;; harder than the documentation they carry.
;;
;; This module renders them in the buffer they are written in, the way
;; `live.el' renders a table: an overlay with a `display' string replaces
;; the comment or the string while point is elsewhere, and the source comes
;; back the moment point enters it, so editing never sees the rendering and
;; saving never writes it.  What is shown is the documentation as a reader
;; wants it -- prose in the sans-serif family, signatures and code in the
;; monospace one with the language's own colours, headings and links in the
;; palette's colours -- and the syntax around it is read rather than shown:
;; a Javadoc/KDoc comment loses its `/**', ` * ' gutter and `*/', its HTML
;; and `{@code x}'/`@link Target label}' tags are read as prose and code, and
;; its `@param'/`@return'/`@throws' blocks become the sections an IDE puts
;; around them; a Scheme docstring loses its quotes and its Texinfo
;; `@deffn'/`@itemize'/`@example'/`@code' commands become signatures, lists,
;; code blocks and inline markup.
;;
;; The rendering is a pure function of the docstring's text, cached by that
;; text, so a comment that has not changed is laid out once however often
;; jit-lock asks about it.  Only the docstrings in the region being
;; fontified are looked at, a docstring larger than
;; `heks/docstring-max-size' is left as source, and a rendering that fails
;; leaves the source alone rather than half a document.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defgroup heks/docstring nil
  "Javadoc, KDoc and Scheme docstrings rendered in place."
  :group 'heks)

(defcustom heks/docstring-max-size 20000
  "Largest docstring, in characters, that is rendered.
A larger one is left as source: a documentation comment is not a place
where a layout pass should be allowed to take a noticeable amount of time."
  :type 'natnum
  :group 'heks/docstring)

(defcustom heks/docstring-cache-size 128
  "How many rendered docstrings are kept.
The cache is by text, so the entries are whole rendered documents; a
project that changes its comments often would otherwise keep every version
of every comment read this session."
  :type 'natnum
  :group 'heks/docstring)

(defconst heks/docstring-signature-width 80
  "Width at which a long signature in a rendered docstring is broken.")

;;
;; ====== The faces a rendered docstring reads with ======
;;
;; Each face inherits one the palette already paints -- the prose family,
;; the monospace one, a heading's colour, a link -- so a rendered docstring
;; changes with the theme like the text around it, and nothing here is a
;; colour of its own.

(defface heks/docstring-prose '((t :inherit variable-pitch))
  "Face of the prose of a rendered docstring.")

(defface heks/docstring-code '((t :inherit fixed-pitch))
  "Face of the code and signatures of a rendered docstring.")

(defface heks/docstring-heading
  '((t :inherit (variable-pitch font-lock-function-name-face) :weight bold))
  "Face of a heading in a rendered docstring.")

(defface heks/docstring-strong '((t :inherit (variable-pitch bold)))
  "Face of strong text in a rendered docstring.")

(defface heks/docstring-emphasis '((t :inherit (variable-pitch italic)))
  "Face of emphasised text in a rendered docstring.")

(defface heks/docstring-link '((t :inherit (variable-pitch link)))
  "Face of a link in a rendered docstring.")

;;
;; ====== HTML entities ======
;;

(defconst heks/docstring--entities
  '(("&nbsp;" . " ") ("&lt;" . "<") ("&gt;" . ">") ("&quot;" . "\"")
    ("&apos;" . "'") ("&hellip;" . "…") ("&ndash;" . "–")
    ("&mdash;" . "—") ("&lsquo;" . "‘") ("&rsquo;" . "’")
    ("&ldquo;" . "“") ("&rdquo;" . "”") ("&times;" . "×")
    ("&middot;" . "·") ("&copy;" . "©") ("&reg;" . "®")
    ("&amp;" . "&"))
  "The HTML entities Javadoc writes that have a plain character.

`&amp;' is last on purpose: unescaping it first would turn `&amp;lt;' into
`&lt;' and then into a `<', which is not what the documentation said.")

(defun heks/docstring--unescape-entities (text)
  "Return TEXT with the HTML entities documentation uses turned into characters."
  (let* ((text (replace-regexp-in-string
                "&#x\\([0-9a-fA-F]+\\);\\|&#\\([0-9]+\\);"
                (lambda (match)
                  (let ((code (if (match-string 1 match)
                                  (string-to-number (match-string 1 match) 16)
                                (string-to-number (match-string 2 match)))))
                    (if (and (> code 0) (< code #x110000))
                        (char-to-string code)
                      match)))
                text t)))
    (dolist (entity heks/docstring--entities)
      (setq text (string-replace (car entity) (cdr entity) text)))
    text))

;;
;; ====== Texinfo becomes Markdown ======
;;

(defconst heks/docstring--texinfo-re
  (concat "\\(?:\\`\\|[^{]\\)@\\(?:code\\|var\\|samp\\|example\\|lisp\\|smallexample"
          "\\|smalllisp\\|verbatim\\|deffnx?\\|defun\\|defmac\\|defspec\\|defvar"
          "\\|defopt\\|defvr\\|deftp\\|deftype[a-z]*\\|emph\\|dfn\\|cite\\|strong"
          "\\|b\\|file\\|command\\|option\\|env\\|kbd\\|key\\|xref\\|ref\\|pxref"
          "\\|uref\\|url\\|dots\\|result\\|print\\|error\\|expansion\\|point"
          "\\|table\\|itemize\\|enumerate\\|itemx?\\)\\b")
  "Texinfo commands that mark a docstring as Texinfo.

The character before the at-sign must not be `{': `{@code x}' is Javadoc's
inline tag, not Texinfo's `@code{x}'.")

(defconst heks/docstring--javadoc-re
  (concat "\\(?:{@\\(?:code\\|link\\|linkplain\\|literal\\|value\\|inheritDoc"
          "\\|docRoot\\|snippet\\)"
          "\\|</?\\(?:p\\|br\\|code\\|pre\\|b\\|i\\|em\\|strong\\|ul\\|ol"
          "\\|li\\|a\\|h[1-6]\\)\\b"
          "\\|^[ \t]*@\\(?:param\\|return\\|returns\\|throws\\|exception\\|see"
          "\\|since\\|author\\|version\\|deprecated\\|sample\\|receiver"
          "\\|property\\|constructor\\)\\b\\)")
  "Javadoc and KDoc syntax that is not Markdown.")

(defun heks/docstring--texinfo-p (text)
  "Return non-nil when TEXT is a Texinfo docstring."
  (let ((case-fold-search nil))
    (and (string-match-p heks/docstring--texinfo-re text) t)))

(defun heks/docstring--javadoc-p (text)
  "Return non-nil when TEXT is written as Javadoc or KDoc.

The test is case-sensitive on purpose: `<B>' in a Java signature is a type
parameter, and reading it as the HTML bold tag would eat it."
  (and (not (heks/docstring--texinfo-p text))
       (string-match-p heks/docstring--javadoc-re text)
       t))

(defconst heks/docstring--texinfo-definitions
  '("deffn" "deffnx" "defun" "defmac" "defspec" "defvar" "defopt" "defvr"
    "deftp" "deftypefn" "deftypefun" "deftypevr" "deftypemethod"
    "deftypevar" "deftypeop")
  "The Texinfo commands that begin a definition line.")

(defun heks/docstring--texinfo-definition-arguments (string)
  "Split STRING, the arguments of a Texinfo definition, into its parts.

Return (QUALIFIERS NAME ARGS): QUALIFIERS are the leading brace groups --
the category of a `@deffn', the type of a `@deftypefun' -- NAME is the
first token that is not one, and ARGS is what is left of the line."
  (let ((qualifiers '())
        (rest (string-trim string)))
    (while (string-match "\\`{\\([^}]*\\)}[ \t]*" rest)
      (push (match-string 1 rest) qualifiers)
      (setq rest (substring rest (match-end 0))))
    (when (string-match "\\`\\(\\S-+\\)[ \t]*\\(.*\\)\\'" rest)
      (list (nreverse qualifiers) (match-string 1 rest) (match-string 2 rest)))))

(defun heks/docstring--texinfo-inline (text)
  "Turn the inline Texinfo commands of TEXT into Markdown."
  ;; shortcut: one level of braces, which is how a docstring writes these
  ;; commands; a nested argument would need a real Texinfo reader.
  (let ((case-fold-search nil))
    (dolist (pair '(("code" . "`") ("samp" . "`") ("command" . "`")
                    ("file" . "`") ("option" . "`") ("env" . "`")
                    ("kbd" . "`") ("key" . "`") ("var" . "*")
                    ("emph" . "*") ("dfn" . "*") ("cite" . "*") ("i" . "*")
                    ("strong" . "**") ("b" . "**")))
      (setq text (replace-regexp-in-string
                  (format "@%s{\\([^{}]*\\)}" (car pair))
                  (concat (cdr pair) "\\1" (cdr pair))
                  text t)))
    (setq text (replace-regexp-in-string
                "@\\(?:p?x?ref\\){\\([^},]*\\)[^}]*}" "`\\1`" text t))
    (setq text (replace-regexp-in-string
                "@uref{\\([^},]*\\)[ \t]*,[ \t]*\\([^}]*\\)}"
                "[\\2](\\1)" text t))
    (setq text (replace-regexp-in-string
                "@url{\\([^}]*\\)}" "<\\1>" text t))
    (dolist (pair '(("@dots{}" . "…") ("@result{}" . "⇒")
                    ("@print{}" . "⊣") ("@error{}" . "error→")
                    ("@expansion{}" . "↦") ("@point{}" . "∗")
                    ("@equiv{}" . "≡") ("@minus{}" . "−")
                    ("@leq{}" . "≤") ("@geq{}" . "≥")
                    ("@nbsp{}" . " ") ("@tie{}" . " ")))
      (setq text (string-replace (car pair) (cdr pair) text)))
    (replace-regexp-in-string "@\\([{}@]\\)" "\\1" text t)))

(defun heks/docstring--texinfo-definition (line)
  "Return LINE, a Texinfo `@def...' line, as a Markdown signature."
  (if (string-match (format "\\`[ \t]*@\\(%s\\)\\(?:[ \t]+\\(.*\\)\\)?[ \t]*\\'"
                            (regexp-opt heks/docstring--texinfo-definitions))
                    line)
      (let* ((parts (heks/docstring--texinfo-definition-arguments
                     (or (match-string 2 line) "")))
             (qualifiers (nth 0 parts))
             (name (or (nth 1 parts) ""))
             (args (or (nth 2 parts) "")))
        (string-trim
         (concat (and qualifiers
                      (concat "*" (mapconcat #'identity qualifiers " ") "* "))
                 (format "**`%s`**" (heks/docstring--texinfo-inline name))
                 (and (not (string-empty-p args))
                      (concat " " (heks/docstring--texinfo-inline args))))))
    line))

(defun heks/docstring--texinfo-to-markdown (text)
  "Turn the Texinfo in TEXT into Markdown, which `gfm-view-mode' can show.

A definition becomes a signature, `@itemize' and `@table' become lists,
`@example' becomes a fenced block of Scheme, and the inline commands
become the emphasis and code they mark.  A command this does not know is
left as it is written, which is kinder than deleting what it guessed
wrong."
  (let ((in-code nil) (list-kind nil) (number 0) (out '()))
    (dolist (line (split-string (substring-no-properties text) "\n"))
      (cond
       ((string-match "\\`[ \t]*@\\(example\\|lisp\\|smallexample\\|smalllisp\\|verbatim\\)[ \t]*\\'" line)
        (setq in-code t)
        (push "```scheme" out))
       ((and in-code
             (string-match "\\`[ \t]*@end \\(?:example\\|lisp\\|smallexample\\|smalllisp\\|verbatim\\)[ \t]*\\'" line))
        (setq in-code nil)
        (push "```" out))
       (in-code (push line out))
       ((string-match "\\`[ \t]*@\\(itemize\\|enumerate\\|table\\)\\(?:[ \t]+\\(.*\\)\\)?[ \t]*\\'" line)
        (setq list-kind (pcase (match-string 1 line)
                          ("enumerate" 'number)
                          ("table" (if (and (match-string 2 line)
                                            (string-match-p "@code" (match-string 2 line)))
                                       'code 'bullet))
                          (_ 'bullet))
              number 0))
       ((string-match "\\`[ \t]*@end \\(?:itemize\\|enumerate\\|table\\)[ \t]*\\'" line)
        (setq list-kind nil))
       ((string-match "\\`[ \t]*@itemx?[ \t]+\\(.*\\)\\'" line)
        (let ((item (heks/docstring--texinfo-inline (string-trim (match-string 1 line)))))
          (push (pcase list-kind
                  ('number (cl-incf number) (format "%d. %s" number item))
                  ('code (format "- `%s`" item))
                  (_ (format "- %s" item)))
                out)))
       ((string-match "\\`[ \t]*@def[a-z]+\\(?:[ \t].*\\)?\\'" line)
        (push (heks/docstring--texinfo-definition line) out))
       ((string-match "\\`[ \t]*@end [a-z]+[ \t]*\\'" line) nil)
       ((string-match "\\`[ \t]*@\\(?:noindent\\|page\\|group\\|sp\\|comment\\|c\\)\\b.*\\'" line) nil)
       (t (push (heks/docstring--texinfo-inline line) out))))
    (string-trim (string-join (nreverse out) "\n"))))

;;
;; ====== Javadoc and KDoc become Markdown ======
;;

(defconst heks/docstring--javadoc-section-titles
  '((param . "Parameters")
    (throws . "Throws")
    (return . "Returns")
    (see . "See also")
    (since . "Since")
    (author . "Author")
    (version . "Version")
    (deprecated . "Deprecated")
    (sample . "Sample")
    (receiver . "Receiver")
    (property . "Properties")
    (constructor . "Constructor")
    (suppress . "Suppress warnings")
    (serial . "Serial")
    (apinote . "API Note")
    (implspec . "Implementation Requirements")
    (implnote . "Implementation Note"))
  "The section a Javadoc or KDoc block tag becomes, by tag keyword.")

(defun heks/docstring--javadoc-pre (text)
  "Turn the `<pre>' blocks of TEXT into fenced code blocks, as an IDE shows them.

The tags are read in lower case: Javadoc writes them that way, and a
case-insensitive `<B>' would be a type parameter and not a bold tag."
  (setq text (replace-regexp-in-string
              "<pre[^>]*>[ \t\n]*{@\\(?:code\\|literal\\)[ \t\n]*"
              "\n```\n" text t))
  (setq text (replace-regexp-in-string
              "[ \t\n]*}[ \t\n]*</pre>" "\n```\n" text t))
  (setq text (replace-regexp-in-string "<pre[^>]*>" "\n```\n" text t))
  (replace-regexp-in-string "</pre>" "\n```\n" text t))

(defun heks/docstring--html-tags (line)
  "Return LINE with the HTML Javadoc writes turned into Markdown.

The tags are read in lower case, as Javadoc writes them: matching `<B>'
here would turn a Java type parameter into bold and eat the name."
  ;; shortcut: the HTML a docstring actually uses, one line at a time; a
  ;; full document would need an HTML parser, and this is not one.
  (let ((case-fold-search nil))
    ;; A link keeps its label, and its target when it has one.
    (setq line (replace-regexp-in-string
                "<a[^>]*href=\"\\([^\"]+\\)\"[^>]*>\\([^<]*\\)</a>"
                "[\\2](\\1)" line t))
    (setq line (replace-regexp-in-string
                "<a[^>]*>\\([^<]*\\)</a>" "\\1" line t))
    (setq line (replace-regexp-in-string
                "<h\\([1-6]\\)[^>]*>\\(.*?\\)</h\\1>" "\\2" line t))
    (dolist (pair '(("<p[^>]*>" . "\n\n") ("</p>" . "\n\n")
                    ("<br[^>]*>" . "\n")
                    ("<li[^>]*>" . "- ")
                    ("<[ou]l[^>]*>" . "\n") ("</[ou]l>" . "\n")
                    ("<blockquote[^>]*>" . "\n") ("</blockquote>" . "\n")
                    ("<code[^>]*>" . "`") ("</code>" . "`")
                    ("<tt[^>]*>" . "`") ("</tt>" . "`")
                    ("<kbd[^>]*>" . "`") ("</kbd>" . "`")
                    ("<var[^>]*>" . "`") ("</var>" . "`")
                    ("<b[^>]*>" . "**") ("</b>" . "**")
                    ("<strong[^>]*>" . "**") ("</strong>" . "**")
                    ("<i[^>]*>" . "*") ("</i>" . "*")
                    ("<em[^>]*>" . "*") ("</em>" . "*")
                    ("<cite[^>]*>" . "*") ("</cite>" . "*")
                    ("<hr[^>]*>" . "\n---\n")
                    ("<img[^>]*>" . "")))
      (setq line (replace-regexp-in-string (car pair) (cdr pair) line t)))
    ;; Anything left whose name is HTML goes; `<T>', a generic written
    ;; literally, is not HTML and stays.
    (replace-regexp-in-string
     (concat "<\\/?\\(?:a\\|abbr\\|acronym\\|address\\|article\\|aside\\|b\\|big"
             "\\|blockquote\\|br\\|caption\\|center\\|cite\\|code\\|col\\|dd"
             "\\|del\\|details\\|dfn\\|div\\|dl\\|dt\\|em\\|figcaption\\|figure"
             "\\|font\\|footer\\|h[1-6]\\|head\\|header\\|hr\\|html\\|i\\|iframe"
             "\\|img\\|ins\\|kbd\\|li\\|main\\|mark\\|nav\\|ol\\|p\\|pre\\|q\\|s"
             "\\|samp\\|section\\|small\\|span\\|strike\\|strong\\|sub\\|summary"
             "\\|sup\\|table\\|tbody\\|td\\|tfoot\\|th\\|thead\\|tr\\|tt\\|u\\|ul"
             "\\|var\\|wbr\\)\\(?:\\s-+[^>]*\\)?>")
     "" line t t)))

(defun heks/docstring--javadoc-inline (line)
  "Turn the inline Javadoc and KDoc tags of LINE into Markdown."
  (let ((case-fold-search nil))
    ;; `{@code x}' is code and `{@literal x}' is what it says.
    (setq line (replace-regexp-in-string
                "{@\\(?:code\\|snippet\\)[ \t]+\\([^}]*\\)}" "`\\1`" line t))
    (setq line (replace-regexp-in-string
                "{@literal[ \t]+\\([^}]*\\)}" "\\1" line t))
    ;; `{@link Target label}' keeps the label, `{@link Target}' the target.
    (setq line (replace-regexp-in-string
                "{@\\(?:link\\|linkplain\\)[ \t]+\\([^}]*\\)}"
                (lambda (match)
                  ;; `save-match-data': the inner `string-match' must not
                  ;; move the match data `replace-regexp-in-string' is using.
                  (save-match-data
                    (let ((body (string-trim (match-string 1 match))))
                      (if (string-match "\\`\\(\\S-+\\)\\s-+\\(.+\\)\\'" body)
                          (format "`%s`" (string-trim (match-string 2 body)))
                        (format "`%s`" body)))))
                line t))
    ;; A tag that is only a note to the documentation tool goes.
    (setq line (replace-regexp-in-string
                "{@\\(?:value\\|docRoot\\|inheritDoc\\|index\\|systemProperty\\)[^}]*}"
                "" line t))
    ;; KDoc: `[Label][Target]' and `[Target]' name code.
    (setq line (replace-regexp-in-string
                "\\[\\([^]]+\\)\\]\\[\\([^]]+\\)\\]" "`\\1`" line t))
    (replace-regexp-in-string
     "\\[\\([A-Za-z_][A-Za-z0-9_.$#<>]*\\)\\]\\(.\\)?"
     (lambda (match)
       (let ((after (match-string 2 match)))
         (if (and after (memq (aref after 0) '(?\( ?: ?\[)))
             (match-string 0 match)
           (concat (format "`%s`" (match-string 1 match)) (or after "")))))
     line t)))

(defun heks/docstring--javadoc-tag (line)
  "Return (KEYWORD . REST) when LINE begins a Javadoc block tag, or nil."
  (when (string-match "\\`[ \t]*@\\([a-zA-Z]+\\)\\(?:[ \t]+\\(.*\\)\\)?[ \t]*\\'" line)
    (cons (intern (downcase (match-string 1 line)))
          (string-trim (or (match-string 2 line) "")))))

(defun heks/docstring--javadoc-markup (text)
  "Turn the HTML and inline tags of TEXT into Markdown, fence by fence."
  (let ((in-code nil) (out '()))
    (dolist (line (split-string text "\n"))
      (cond
       ((string-match-p "\\`[ \t]*```" line)
        (setq in-code (not in-code))
        (push line out))
       (in-code (push line out))
       (t (push (heks/docstring--javadoc-inline (heks/docstring--html-tags line)) out))))
    (string-join (nreverse out) "\n")))

(defun heks/docstring--javadoc-sections (text)
  "Turn the block tags of TEXT into the sections an IDE shows."
  (let ((in-code nil) (section nil) (current nil) (out '()))
    (cl-labels
        ((join (description)
           (let ((trimmed (string-trim (or description ""))))
             (if (string-empty-p trimmed) "" (concat " — " trimmed))))
         (emit (keyword name description)
           (let ((title (or (alist-get keyword heks/docstring--javadoc-section-titles)
                            (capitalize (symbol-name keyword)))))
             (unless (equal title section)
               (setq section title)
               (push (format "\n### %s\n" title) out))
             (push (if name
                       (format "- `%s`%s" name (join description))
                     (string-trim (or description "")))
                   out)))
         (flush ()
           (when current
             (apply #'emit current)
             (setq current nil))))
      (dolist (line (split-string text "\n"))
        (cond
         ((string-match-p "\\`[ \t]*```" line)
          (flush)
          (setq in-code (not in-code) section nil)
          (push line out))
         (in-code (push line out))
         (t
          (let ((tag (heks/docstring--javadoc-tag line)))
            (cond
             ((and tag (memq (car tag) '(param property receiver)))
              (flush)
              (let ((rest (cdr tag)))
                (setq current
                      (if (string-match "\\`\\(<[^>]+>\\|[^ \t]+\\)[ \t]*\\(.*\\)\\'" rest)
                          (list (car tag) (match-string 1 rest) (match-string 2 rest))
                        (list (car tag) nil rest)))))
             ((and tag (memq (car tag) '(throws exception)))
              (flush)
              (let ((rest (cdr tag)))
                (setq current
                      (if (string-match "\\`\\([^ \t]+\\)[ \t]*\\(.*\\)\\'" rest)
                          (list 'throws (match-string 1 rest) (match-string 2 rest))
                        (list 'throws nil rest)))))
             ((and tag (alist-get (car tag) heks/docstring--javadoc-section-titles))
              (flush)
              (setq section nil)
              (emit (if (eq (car tag) 'returns) 'return (car tag)) nil (cdr tag)))
             ((and current (not tag) (not (string-empty-p (string-trim line))))
              ;; A description that wrapped onto the next line belongs to
              ;; the tag above it, not to the prose.
              (setcar (cddr current)
                      (string-trim (concat (nth 2 current) " " (string-trim line)))))
             (t
              (flush)
              (setq section nil)
              (push line out)))))))
      (flush))
    (string-join (delq nil (nreverse out)) "\n")))

(defun heks/docstring--javadoc-to-markdown (text)
  "Turn the Javadoc or KDoc in TEXT into the Markdown the renderer reads."
  (let* ((markdown (heks/docstring--javadoc-sections
                    (heks/docstring--javadoc-markup (heks/docstring--javadoc-pre text))))
         ;; A converted `<pre>' arrives with a blank line on each side of
         ;; its fence; an IDE shows the code right under the signature.
         (after-open (replace-regexp-in-string
                      "\\(```[^\n]*\\)\n\n+" "\\1\n" markdown))
         (before-close (replace-regexp-in-string
                        "\n\n+\\(```\\)" "\n\\1" after-open)))
    (string-trim before-close)))

(defun heks/docstring--normalize (text)
  "Return TEXT as the Markdown a rendered docstring reads.

Texinfo is read as Texinfo, Javadoc and KDoc as the HTML and block tags
they are written with, and anything else passes through.  The entities a
server escaped are turned back into characters last, after the markup
around them has been read, so that `&lt;T&gt;' is a type and not a tag."
  (let* ((text (substring-no-properties text))
         (texinfo (heks/docstring--texinfo-p text))
         (javadoc (heks/docstring--javadoc-p text))
         (markdown (cond (texinfo (heks/docstring--texinfo-to-markdown text))
                         (javadoc (heks/docstring--javadoc-to-markdown text))
                         (t text))))
    (heks/docstring--unescape-entities
     (if (or texinfo javadoc (string-match-p "^[ \t]*```" text))
         (heks/docstring--break-code markdown)
       markdown))))

(defun heks/docstring--break-signature (line)
  "Break LINE, a long signature, after its top-level parameter commas."
  (if (or (<= (length line) heks/docstring-signature-width)
          (not (string-match-p "(" line)))
      line
    (let ((depth 0) (out '()) (start 0) (i 0) (n (length line)) (opened nil))
      (while (< i n)
        (let ((c (aref line i)))
          (cond
           ((memq c '(?\( ?\[ ?\{))
            (when (and (= depth 0) (not opened) (eq c ?\())
              (setq opened t)
              (push (substring line start (1+ i)) out)
              (setq start (1+ i)))
            (cl-incf depth))
           ((and (eq c ?<) (> depth 0)) (cl-incf depth))
           ((and (eq c ?>) (> depth 1) (not (eq (and (> i 0) (aref line (1- i))) ?-)))
            (cl-decf depth))
           ((memq c '(?\) ?\] ?\}))
            (cl-decf depth)
            (when (and (= depth 0) (eq opened t) (eq c ?\)))
              (push (substring line start i) out)
              (setq start i opened 'done)))
           ((and (eq c ?,) (= depth 1) (eq opened t))
            (push (substring line start (1+ i)) out)
            (setq start (1+ i)))))
        (cl-incf i))
      (push (substring line start) out)
      (let ((parts (nreverse out)))
        (if (< (length parts) 3)
            line
          (concat (car parts) "\n"
                  (mapconcat (lambda (p) (concat "    " (string-trim p)))
                             (butlast (cdr parts)) "\n")
                  "\n" (car (last parts))))))))

(defun heks/docstring--break-code (text)
  "Break the long signature lines of the fenced code blocks in TEXT."
  (let ((in nil))
    (mapconcat
     (lambda (line)
       (cond ((string-match-p "\\`[ \t]*```" line) (setq in (not in)) line)
             (in (heks/docstring--break-signature line))
             (t line)))
     (split-string text "\n") "\n")))

;;
;; ====== Extracting the documentation from the source ======
;;

(defun heks/docstring--language ()
  "Return the docstring syntax of this buffer: `jvm', `scheme', or nil."
  (cond ((derived-mode-p 'java-mode 'java-ts-mode 'kotlin-mode 'kotlin-ts-mode)
         'jvm)
        ((derived-mode-p 'scheme-mode 'scheme-ts-mode)
         'scheme)))

(defun heks/docstring--starts-line-p (position)
  "Return non-nil when POSITION is the first non-blank thing on its line."
  (save-excursion
    (goto-char position)
    (skip-chars-backward " \t")
    (= (point) (line-beginning-position))))

(defun heks/docstring--ends-line-p (position)
  "Return non-nil when only whitespace follows POSITION on its line."
  (save-excursion
    (goto-char position)
    (skip-chars-forward " \t")
    (eolp)))

(defun heks/docstring--jvm-text (beg end)
  "Return the documentation of the JVM comment BEG..END, without its gutter."
  (let* ((raw (string-trim (buffer-substring-no-properties beg end)))
         (body (if (string= raw "/**/")
                   ""
                 (string-remove-suffix "*/" (string-remove-prefix "/**" raw)))))
    (string-trim
     (string-join
      (mapcar (lambda (line)
                (if (string-match "\\`[ \t]*\\*[ \t]?" line)
                    (substring line (match-end 0))
                  line))
              (split-string body "\n"))
      "\n"))))

(defun heks/docstring--scheme-text (beg end)
  "Return the documentation of the Scheme string BEG..END, without its quotes."
  (replace-regexp-in-string
   "\\\\\\(.\\)"
   (lambda (match)
     (pcase (match-string 1 match)
       ("n" "\n") ("t" "\t") ("\"" "\"") ("\\" "\\")
       (_ (match-string 0 match))))
   (buffer-substring-no-properties (1+ beg) (1- end))
   t))

;;
;; ====== Finding the docstrings in a region ======
;;

(defun heks/docstring--jvm-ranges (beg end)
  "Return the JVM doc comments overlapping BEG..END as (BEG . END) pairs."
  (let ((start (save-excursion
                 (let ((state (syntax-ppss beg)))
                   (if (nth 4 state) (nth 8 state) beg))))
        ranges)
    (save-excursion
      (goto-char start)
      (while (re-search-forward "/\\*\\*" end t)
        (let ((open (match-beginning 0)))
          (when (save-excursion
                  (let ((state (syntax-ppss (+ open 2))))
                    (and (nth 4 state) (= (nth 8 state) open))))
            (let ((close (save-excursion
                           (goto-char open)
                           (search-forward "*/" nil t))))
              (when close
                (push (cons open close) ranges)
                (goto-char close)))))))
    (nreverse ranges)))

(defconst heks/docstring--scheme-definition-heads
  '(define define* define-public define-syntax define-syntax-rule lambda)
  "The Scheme forms whose body begins with a docstring.")

(defun heks/docstring--scheme-head (list-start)
  "Return the symbol after the open paren at LIST-START, or nil."
  (save-excursion
    (goto-char (1+ list-start))
    (forward-comment (point-max))
    (skip-chars-forward " \t\n")
    (when (looking-at "[^][() \t\n;\"']+")
      (intern (match-string-no-properties 0)))))

(defun heks/docstring--scheme-docstring-p (start)
  "Return non-nil when the string at START is a Scheme docstring.

A docstring is the first expression of a body: it follows the argument
list of a `define', a `lambda' or a `define-syntax', with only whitespace
and comments between them.  A string that is a value -- `(define x
\"value\")', the argument of a call -- is not one."
  (let* ((state (save-excursion (syntax-ppss start)))
         (list-start (car (last (nth 9 state))))
         (head (and list-start (heks/docstring--scheme-head list-start))))
    (and (memq head heks/docstring--scheme-definition-heads)
         (condition-case nil
             (save-excursion
               (goto-char (1+ list-start))
               (forward-comment (point-max))
               (skip-chars-forward " \t\n")
               (forward-sexp 1)          ; the head symbol
               (forward-comment (point-max))
               (skip-chars-forward " \t\n")
               ;; The argument list: a list, or for `lambda' also a symbol.
               (cond ((eq (char-after) ?\()
                      (forward-sexp 1))
                     ((eq head 'lambda)
                      (forward-sexp 1))
                     (t (signal 'scan-error nil)))
               (forward-comment (point-max))
               (skip-chars-forward " \t\n")
               (= (point) start))
           (error nil)))))

(defun heks/docstring--scheme-ranges (beg end)
  "Return the Scheme docstrings overlapping BEG..END as (BEG . END) pairs."
  (let ((state (save-excursion (syntax-ppss beg)))
        ranges)
    (when (or (nth 3 state)
              (save-excursion (goto-char beg) (search-forward "\"" end t)))
      (save-excursion
        (goto-char (if (nth 3 state) (nth 8 state) beg))
        (while (< (point) end)
          (let ((state (syntax-ppss)))
            (cond
             ((nth 3 state)
              (let* ((start (nth 8 state))
                     (stop (condition-case nil (scan-sexps start 1) (error nil))))
                (when (and stop (heks/docstring--scheme-docstring-p start))
                  (push (cons start stop) ranges))
                (goto-char (or stop end))))
             ((nth 4 state)
              (let ((start (nth 8 state)))
                (goto-char start)
                (forward-comment 1)
                ;; A comment the syntax table reports but `forward-comment'
                ;; does not move over would otherwise be visited forever.
                (when (<= (point) start) (forward-char 1))))
             (t (forward-char 1)))))))
    (nreverse ranges)))

;;
;; ====== Rendering one docstring ======
;;

(defconst heks/docstring--code-faces
  '(markdown-code-face markdown-inline-code-face markdown-pre-face
    markdown-table-face markdown-language-keyword-face
    markdown-language-info-face)
  "The Markdown faces whose text is code.")

(defconst heks/docstring--heading-faces
  '(markdown-header-face markdown-header-face-1 markdown-header-face-2
    markdown-header-face-3 markdown-header-face-4 markdown-header-face-5
    markdown-header-face-6 markdown-ts-heading-1 markdown-ts-heading-2
    markdown-ts-heading-3 markdown-ts-heading-4 markdown-ts-heading-5
    markdown-ts-heading-6 markdown-ts-setext-heading)
  "The Markdown faces whose text is a heading.")

(defun heks/docstring--face-for (face)
  "Return the face a Markdown run with FACE should be displayed in."
  (let ((faces (if (listp face) face (list face))))
    (cond
     ((cl-some (lambda (candidate) (memq candidate heks/docstring--heading-faces))
               faces)
      'heks/docstring-heading)
     ((cl-some (lambda (candidate) (memq candidate heks/docstring--code-faces))
               faces)
      (cons 'heks/docstring-code
            (cl-remove-if (lambda (candidate)
                            (memq candidate heks/docstring--code-faces))
                          faces)))
     ((memq 'markdown-bold-face faces) 'heks/docstring-strong)
     ((memq 'markdown-italic-face faces) 'heks/docstring-emphasis)
     ((memq 'markdown-blockquote-face faces) 'heks/docstring-emphasis)
     ((memq 'markdown-link-face faces) 'heks/docstring-link)
     ((null face) 'heks/docstring-prose)
     (t face))))

(defun heks/docstring--restyle ()
  "Give the Markdown runs of the current buffer the docstring faces."
  (let ((inhibit-read-only t)
        (position (point-min))
        (limit (point-max)))
    (while (< position limit)
      (let ((next (next-single-property-change position 'face nil limit)))
        (put-text-property position next 'face
                           (heks/docstring--face-for
                            (get-text-property position 'face)))
        (setq position next)))))

(defun heks/docstring--only-faces (string)
  "Return STRING with its text and faces, and none of the bookkeeping.

A `display' string found on a run replaces the run, which is how a
Markdown list gets the bullet the Markdown mode draws."
  (let ((pieces '()) (position 0) (size (length string)))
    (while (< position size)
      (let* ((next (or (next-property-change position string size) size))
             (text (substring string position next))
             (display (get-text-property position 'display string))
             (face (get-text-property position 'face string))
             (piece (if (and display (stringp display))
                        display
                      (substring-no-properties text))))
        (when face
          (put-text-property 0 (length piece) 'face face piece))
        (push piece pieces)
        (setq position next)))
    (apply #'concat (nreverse pieces))))

(defun heks/docstring--render-string (text)
  "Return TEXT rendered as a propertized string, or nil when unable to."
  (require 'markdown-mode nil t)
  (when (fboundp 'gfm-view-mode)
    (with-temp-buffer
      (insert (heks/docstring--normalize text))
      (delay-mode-hooks (gfm-view-mode))
      (font-lock-ensure)
      (heks/docstring--restyle)
      (let ((visible (filter-buffer-substring (point-min) (point-max))))
        (unless (string-empty-p visible)
          (heks/docstring--only-faces visible))))))

(defvar heks/docstring--cache (make-hash-table :test #'equal)
  "Rendered docstrings, by the text they were rendered from.")

(defun heks/docstring--display (text)
  "Return the display string for TEXT, rendering and caching it once."
  (or (gethash text heks/docstring--cache)
      (let ((rendered (ignore-errors (heks/docstring--render-string text))))
        (when rendered
          (when (>= (hash-table-count heks/docstring--cache)
                    heks/docstring-cache-size)
            (clrhash heks/docstring--cache))
          (puthash text rendered heks/docstring--cache))
        rendered)))

;;
;; ====== Drawing and clearing the overlays ======
;;

(defun heks/docstring--clear (beg end)
  "Remove the rendered docstring overlays between BEG and END."
  (dolist (overlay (overlays-in beg end))
    (when (overlay-get overlay 'heks-docstring)
      (delete-overlay overlay))))

(defun heks/docstring--indent (string indent)
  "Prefix each line of STRING but the first with INDENT spaces."
  (if (zerop indent)
      string
    (string-replace "\n" (concat "\n" (make-string indent ?\s)) string)))

(defun heks/docstring--draw (beg end)
  "Draw the docstring BEG..END in place, unless point is inside it."
  (unless (or (<= beg (point) end)
              (> (- end beg) heks/docstring-max-size)
              (not (heks/docstring--starts-line-p beg))
              (not (heks/docstring--ends-line-p end)))
    (heks/docstring--clear beg end)
    (let ((text (pcase (heks/docstring--language)
                  ('jvm (heks/docstring--jvm-text beg end))
                  ('scheme (heks/docstring--scheme-text beg end)))))
      (when (and text (not (string-empty-p (string-trim text))))
        (let ((display (heks/docstring--display text)))
          (when (and display (not (string-empty-p display)))
            (let ((overlay (make-overlay beg end nil t nil))
                  (indent (save-excursion (goto-char beg) (current-column))))
              (overlay-put overlay 'heks-docstring t)
              (overlay-put overlay 'evaporate t)
              (overlay-put overlay 'display
                           (heks/docstring--indent display indent)))))))))

(defun heks/docstring--fontify (beg end)
  "Draw the docstrings that overlap BEG..END."
  (let ((language (heks/docstring--language)))
    (when language
      (with-silent-modifications
        (dolist (range (if (eq language 'jvm)
                           (heks/docstring--jvm-ranges beg end)
                         (heks/docstring--scheme-ranges beg end)))
          (heks/docstring--draw (car range) (cdr range)))))))

;;
;; ====== Following point ======
;;

(defvar-local heks/docstring--open nil
  "The (BEG . END) markers of the docstring whose source is showing, or nil.")

(defun heks/docstring--overlay-at-point ()
  "Return the rendered docstring overlay at point, or nil."
  (cl-find-if (lambda (overlay) (overlay-get overlay 'heks-docstring))
              (overlays-at (point))))

(defun heks/docstring--range-at-point ()
  "Return the (BEG . END) of the docstring point is in, or nil."
  (or (and heks/docstring--open
           (<= (car heks/docstring--open) (point))
           (<= (point) (cdr heks/docstring--open))
           heks/docstring--open)
      (when-let* ((overlay (heks/docstring--overlay-at-point)))
        (cons (overlay-start overlay) (overlay-end overlay)))))

(defun heks/docstring--follow ()
  "Show the source of the docstring point is in, and draw the one it left."
  (let ((range (heks/docstring--range-at-point)))
    (unless (and range heks/docstring--open
                 (= (car range) (car heks/docstring--open))
                 (= (cdr range) (cdr heks/docstring--open)))
      (when heks/docstring--open
        (heks/docstring--draw (car heks/docstring--open)
                              (cdr heks/docstring--open)))
      (when range
        (heks/docstring--clear (car range) (cdr range)))
      (setq heks/docstring--open
            (and range (cons (copy-marker (car range))
                             (copy-marker (cdr range) t)))))))

;;
;; ====== The mode ======
;;

;;;###autoload
(define-minor-mode heks/docstring-mode
  "Render the docstrings of this buffer where they are written.

A Javadoc or KDoc comment is shown as the documentation it is: prose in
the sans-serif family, code and signatures in the monospace one, headings
and links in the palette's colours, with the comment's own delimiters and
gutter out of the way.  A Scheme docstring is read the same way, with its
Texinfo commands turned into the markup they stand for.  What point is on
shows its source, so editing never sees the rendering."
  :lighter nil
  (if heks/docstring-mode
      (progn
        (jit-lock-register #'heks/docstring--fontify)
        (add-hook 'post-command-hook #'heks/docstring--follow nil t)
        (font-lock-flush))
    (jit-lock-unregister #'heks/docstring--fontify)
    (remove-hook 'post-command-hook #'heks/docstring--follow t)
    (heks/docstring--clear (point-min) (point-max))
    (setq heks/docstring--open nil)))

(defun heks/docstring--enable ()
  "Turn on `heks/docstring-mode' in this buffer."
  (heks/docstring-mode 1))

(dolist (hook '(java-mode-hook java-ts-mode-hook kotlin-mode-hook
                kotlin-ts-mode-hook scheme-mode-hook scheme-ts-mode-hook))
  (add-hook hook #'heks/docstring--enable))

(provide 'heks/dev-docstring)

;;; dev-docstring.el ends here
