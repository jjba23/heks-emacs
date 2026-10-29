;;; heks-emacs-ert.el --- Unit tests for this configuration's own code  -*- lexical-binding: t -*-

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

;; The other checks in `test/' read this configuration and judge what it
;; says: that it parses, that no key means two things, that the pages the
;; renderers produce are the pages they produced last time, and that the
;; installed configuration loads.  This one is the test suite: it loads the
;; modules and calls the code, which is the only way to find out that a
;; function does what its docstring says rather than what it looks like it
;; does.
;;
;;   emacs -Q --batch -l test/heks-emacs-ert.el
;;   emacs -Q --batch -l test/heks-emacs-ert.el -f ert-run-tests-batch-and-exit
;;
;; or `maak test', which is the same thing.  It exits non-zero when any
;; test fails, so a broken module fails the build rather than the user.
;;
;; Two things about how it loads:
;;
;;   * the modules are loaded by file name with `use-package' stubbed out.
;;     A module's `use-package' forms are how this configuration gets its
;;     packages, and installing packages is not what is being tested; what
;;     is being tested is the code above them.  Stubbing it also keeps the
;;     modules off `load-path', where a file called `org.el' would answer
;;     for the Org that Emacs came with;
;;   * a test that needs something this machine does not have -- a YAML
;;     reader, the `terraform' program -- says so and is skipped rather
;;     than failing.  `maak verify' is where the configuration is checked
;;     as a whole, against everything it expects to be there.

;;; Code:

(setq load-prefer-newer t)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'ert)

(defconst heks-ert--source
  (file-name-as-directory
   (or (getenv "HEKS_ERT_SOURCE")
       (expand-file-name "../src" (file-name-directory (file-truename load-file-name)))))
  "The directory holding the modules being tested.")

(defmacro use-package (&rest _)
  "Stand in for the macro that installs packages, which is not under test."
  nil)

(defun heks-ert--module (name)
  "Load the module NAME from the source tree and return its feature."
  (load (expand-file-name (format "modules/%s.el" name) heks-ert--source) nil t))

(dolist (module '("markdown" "render" "import" "present" "heks-emacs" "emacs-core"
                 "notes" "notes-graph" "notes-auto" "contacts" "bookmarks" "agenda" "dev-langs" "dev-tools" "dev-flymake" "dev-formats" "dev-kubernetes" "dev-folding" "dev-project" "dev-hover" "openapi" "scheme-lint" "duplicates" "shell" "guile" "ui" "ai"))
  (heks-ert--module module))

;; `htmlize' is what Org colours the code in a note with, and the
;; configuration installs it: where it has been installed it is looked for,
;; so that the test of how a note asks for colours is not always a test of
;; what happens without them.
(let ((build (expand-file-name "htmlize" (expand-file-name "~/.emacs.d/elpaca/builds/"))))
  (when (file-directory-p build)
    (add-to-list 'load-path build)))

;; `which-key' is part of Emacs 30 and later; on anything older the two
;; tests that read its replacement list are skipped.
(require 'which-key nil t)

;;
;; Helpers.
;;

(defun heks-ert--count (needle haystack)
  "Return how many times NEEDLE appears in HAYSTACK."
  (let ((found 0)
        (position 0))
    (while (string-match (regexp-quote needle) haystack position)
      (setq found (1+ found)
            position (match-end 0)))
    found))

(defmacro heks-ert--with-file (name content &rest body)
  "Run BODY in a buffer visiting a temporary file called NAME holding CONTENT.
NAME is the extension: `\".md\"' makes the buffer a Markdown one, which is
what the renderer goes by.  The file is removed afterwards, and so is a
file written next to it."
  (declare (indent 2))
  `(let ((file (make-temp-file "heks-ert-" nil ,name)))
     (unwind-protect
         (progn
           (write-region ,content nil file nil 'silent)
           (with-current-buffer (find-file-noselect file)
             (unwind-protect (progn ,@body)
               (set-buffer-modified-p nil)
               (kill-buffer))))
       (let ((beside (file-name-sans-extension file)))
         (ignore-errors (delete-file (concat beside ".html")))
         (ignore-errors (delete-file (concat beside ".deck.html"))))
       (delete-file file))))

(defmacro heks-ert--in (directory &rest body)
  "Run BODY with DIRECTORY as `default-directory'."
  (declare (indent 1))
  `(let ((default-directory ,directory))
     (let (project-current)
       ,@body)))

(defun heks-ert--temp-directory ()
  "Return a new empty temporary directory."
  (make-temp-file "heks-ert-project-" t))

(defun heks-ert--xref-locations (items)
  "Return the FILE:LINE of the xref ITEMS as a list of (NAME LINE) pairs."
  (mapcar (lambda (item)
            (let ((location (xref-item-location item)))
              (list (file-name-nondirectory (xref-file-location-file location))
                    (xref-file-location-line location))))
          items))

(defun heks-ert--text (buffer)
  "Return BUFFER's text as one line, with the line breaks taken out.

A preview is filled by `shr' into whatever the window is wide, and in
batch that is a guess; what the document *says* is what is checked here,
so the check is not also a check on where the text was wrapped."
  (with-current-buffer buffer
    (string-trim
     (replace-regexp-in-string "[ \t\n]+" " "
                               (buffer-substring-no-properties (point-min) (point-max))))))

;;
;; ====== The renderer ======
;;

(ert-deftest heks/render/code-is-fontified-with-its-modes-faces ()
  "A fenced block of Elisp comes out with Emacs's own faces on it."
  (let ((html (heks/render-highlight "(defun f (x) x)" "elisp")))
    (should (string-match-p "<span class=\"hl-font-lock-keyword-face\">defun</span>" html))
    (should (string-match-p "hl-font-lock-function-name-face" html))))

(ert-deftest heks/render/fontified-code-is-still-escaped ()
  "Highlighting never lets a `<' of the snippet into the page."
  (let* ((html (heks/render-highlight "(if (< a b) \"x\")" "elisp"))
         (text (replace-regexp-in-string "</?span[^>]*>" "" html)))
    (should (string-match-p "&lt; a b" text))
    (should-not (string-match-p "[a-z] < [a-z]" text))))

(ert-deftest heks/render/a-language-without-a-mode-is-left-as-text ()
  "A language no mode reads is escaped and not guessed at."
  (should (equal (heks/render-highlight "a < b" "nosuchlanguage")
                 "a &lt; b")))

(ert-deftest heks/render/the-language-of-a-fence-finds-its-mode ()
  "The names a fence uses are the ones the mode table knows."
  (should (eq (heks/render-language-mode "bash") 'sh-mode))
  (should (eq (heks/render-language-mode "elisp") 'emacs-lisp-mode))
  (should (eq (heks/render-language-mode "shell") 'sh-mode))
  (should (eq (heks/render-language-mode "Scheme") 'scheme-mode))
  (should-not (heks/render-language-mode "nosuchlanguage")))

(ert-deftest heks/render/anchors-are-ids-a-link-can-use ()
  (should (equal (heks/render-anchor "Get /pets and the rest")
                 "get-pets-and-the-rest"))
  (should (equal (heks/render-anchor "A title: with punctuation!") "a-title-with-punctuation"))
  (should (equal (heks/render-anchor "   ") "section")))

(ert-deftest heks/render/headings-get-ids-in-the-order-they-appear ()
  (let* ((rendered (heks/render--headings "<h1>A</h1>\n<h2>B</h2>"))
         (html (car rendered))
         (entries (cdr rendered)))
    (should (string-match-p "<h1 id=\"a\">A</h1>" html))
    (should (string-match-p "<h2 id=\"b\">B</h2>" html))
    (should (equal (mapcar (lambda (entry) (list (car entry) (nth 1 entry)))
                           entries)
                   '((1 "a") (2 "b"))))))

(ert-deftest heks/render/two-headings-with-one-name-get-two-ids ()
  (let* ((rendered (heks/render--headings "<h2>Same</h2>\n<h2>Same</h2>"))
         (ids (mapcar (lambda (entry) (nth 1 entry)) (cdr rendered))))
    (should (equal ids '("same" "same-2")))
    (should-not (string-match-p "<h2 id=\"same\">Same</h2>.*<h2 id=\"same\">" (car rendered)))))

(ert-deftest heks/render/a-heading-that-has-an-id-keeps-it ()
  "The OpenAPI renderer writes ids worth mentioning, and they survive.

They are not decoration: the contents list links to them, so a heading
whose id is thrown away and replaced by a slug of its text is a heading
the list cannot reach."
  (let ((rendered (heks/render--headings "<h3 id=\"get-/pets\">GET /pets</h3>")))
    (should (string-match-p "<h3 id=\"get-/pets\">" (car rendered)))
    (should (equal (nth 1 (car (cdr rendered))) "get-/pets"))))

(ert-deftest heks/render/the-contents-list-reaches-the-operations-it-names ()
  (let ((heks/render-toc-headings 3))
    (let* ((body (mapconcat #'identity
                            '("<h1>Pet Store</h1>"
                              "<h2>pets</h2>"
                              "<h3 id=\"get-/pets\">GET /pets</h3>"
                              "<h3 id=\"post-/pets\">POST /pets</h3>")
                            "\n"))
           (document (heks/html-document "T" body)))
      (should (string-match-p "href=\"#get-/pets\"" document))
      (should (string-match-p "<h3 id=\"get-/pets\">" document)))))

(ert-deftest heks/render/contents-are-listed-when-there-are-enough ()
  (let ((heks/render-toc-headings 3))
    (let* ((two (heks/render-toc
                 (list (list 2 "a" "A") (list 2 "b" "B"))))
           (three (heks/render-toc
                   (list (list 2 "a" "A") (list 2 "b" "B") (list 2 "c" "C")))))
      (should-not two)
      (should (string-match-p "nav class=\"toc\"" three))
      (should (string-match-p "href=\"#b\"" three))
      (should (equal (heks-ert--count "<li" three) 3)))))

(ert-deftest heks/render/contents-do-not-list-the-title ()
  "A document's own heading heads it; the contents start under it."
  (let ((listed (heks/render-toc-entries
                 (list (list 1 "title" "Title") (list 2 "a" "A") (list 2 "b" "B")))))
    (should (equal (mapcar (lambda (entry) (nth 1 entry)) listed) '("a" "b")))))

(ert-deftest heks/render/contents-stop-one-level-under-the-shallowest ()
  (let ((listed (heks/render-toc-entries
                 (list (list 2 "a" "A") (list 2 "b" "B")
                       (list 3 "c" "C") (list 5 "d" "D")))))
    (should (equal (mapcar (lambda (entry) (nth 1 entry)) listed) '("a" "b" "c")))))

(ert-deftest heks/render/contents-are-in-the-document ()
  (let ((heks/render-toc-headings 3))
    (let ((document (heks/html-document
                     "T" "<h1>T</h1>\n<h2>A</h2>\n<h2>B</h2>\n<h3>C</h3>")))
      (should (string-match-p "<nav class=\"toc\"" document))
      (should (string-match-p "<h2 id=\"a\">" document))
      ;; The stylesheet is written after the body, because it colours the
      ;; faces the body turned out to use.
      (should (string-match-p "@media print" document)))))

;;
;; ====== A note, rendered by Org ======
;;

(defconst heks-ert--org-note
  "* One\n\nfirst\n\n* Two\n\nsecond\n\n* Three\n\n#+begin_src elisp\n(setq x \"<not markup>\")\n#+end_src\n"
  "A note with enough headings to want a contents list, and a code block.")

(ert-deftest heks/render/an-org-note-is-exported-by-org-itself ()
  "An Org buffer is rendered, and it is Org's own exporter that renders it.

A note is read as Org and not as text, so what Org knows -- a heading, a
list, a table, a link, a block of code -- arrives as the markup for it."
  (heks-ert--with-file ".org" heks-ert--org-note
    (should (eq major-mode 'org-mode))
    (should (equal (heks/render--variant-name (current-buffer)) "Org"))
    (let ((body (heks/render-body)))
      (should (stringp body))
      (should (string-match-p "One</h" body))
      (should (string-match-p "Three</h" body))
      ;; The code in the note is the note's own text on the page, escaped
      ;; rather than poured in as markup.
      (should (string-match-p "&lt;not markup&gt;" body))
      (should-not (string-match-p "<not markup>" body)))))

(ert-deftest heks/render/a-note-gets-one-contents-list-and-it-is-this-modules ()
  "Org's own contents list is asked for and dropped, not left in the body.

`org-export-with-toc' is on by default, so an export asked for it before
the settings around it were in force would carry Org's list -- and the
page would then have two, one of them linking to ids of Org's making.
The values of a `let' are evaluated before any of them is bound, which is
why these settings are bound one by one."
  (heks-ert--with-file ".org" heks-ert--org-note
    (let* ((body (heks/render-body))
           (document (heks/html-document "A note" body)))
      (should-not (string-match-p "table-of-contents" body))
      (should (equal (heks-ert--count "<nav class=\"toc\"" document) 1))
      (should (string-match-p "Contents" document))
      ;; And the one list there is lists the note's headings.
      (dolist (heading '("One" "Two" "Three"))
        (should (string-match-p heading document))))))

(ert-deftest heks/render/every-link-in-a-notes-contents-list-reaches-a-heading ()
  "Each entry of the list points at an id the page really has.

Org gives its headings ids of its own, so the list has to keep them: a
list that named unanchored slugs would be entries nobody can follow, which
is what the OpenAPI page's list was before this was checked."
  (heks-ert--with-file ".org" heks-ert--org-note
    (let* ((body (heks/render-body))
           (document (heks/html-document "A note" body))
           (position 0)
           (links 0))
      (while (string-match "href=\"#\\([^\"]+\\)\"" document position)
        (let ((target (match-string 1 document)))
          (setq position (match-end 0)
                links (1+ links))
          (should (string-match-p (regexp-quote (format "id=\"%s\"" target)) document))))
      (should (> links 0)))))

(ert-deftest heks/render/a-note-asks-for-colours-htmlize-can-give-it ()
  "Colouring a block of code is asked for when it can be done, and not otherwise.

`htmlize' is what Org colours a source block with.  Where it is here the
preview asks for its colours as inline styles, because the page carries
none of Org's stylesheet and a class name with no stylesheet behind it is
a block with no colour; where it is not, the setting is nil -- Org's plain
text -- because asking Org for colours it cannot produce is a warning on
every export."
  (should (eq (heks/render--org-output-type)
              (if (require 'htmlize nil t) 'inline-css nil))))

(defface heks-ert-coloured-face '((t :foreground "#123456" :weight bold))
  "A face for the test of the stylesheet, with a colour of its own.")

(defface heks-ert-plain-face '((t))
  "A face for the test of the stylesheet, with no colour of its own.")

(ert-deftest heks/render/the-stylesheet-colours-the-faces-that-have-colours ()
  (let* ((heks/render--faces '(heks-ert-coloured-face heks-ert-plain-face
                                                           heks-ert-coloured-face))
         (css (heks/render-highlight-css)))
    (should (string-match-p "color: #123456" css))
    (should (string-match-p "font-weight: 700" css))
    ;; One rule per face, and the same face twice is still one rule.
    (should (equal (heks-ert--count ".hl-" css) 2))
    ;; A face that says nothing about a colour inherits the text's.
    (should (string-match-p "\\.hl-heks-ert-plain-face { *}" css))))

(ert-deftest heks/render/the-palette-has-the-colours-a-page-needs ()
  (let ((palette (heks/render-palette)))
    (dolist (key '(:background :foreground :surface :border :muted :accent))
      (should (stringp (plist-get palette key))))))

;;
;; ====== Where a deck's slides are ======
;;

(ert-deftest heks/present/markdown-divides-on-a-line-of-dashes ()
  (heks-ert--with-file ".md" "# One\n\nA\n\n---\n\n# Two\n\nB\n"
    (should (equal (heks/present-format) 'markdown))
    (should (equal (length (heks/present-slides)) 2))
    (should (string-prefix-p "# One" (car (heks/present-slides))))))

(ert-deftest heks/present/markdown-without-a-break-is-one-slide ()
  (heks-ert--with-file ".md" "# Only\n\nOne section.\n"
    (should (equal (length (heks/present-slides)) 1))))

(ert-deftest heks/present/org-divides-on-its-own-headings ()
  (with-temp-buffer
    (insert "* One\nA\n\n* Two\nB\n\n* Three\nC\n")
    (org-mode)
    (should (equal (heks/present-format) 'org))
    (should (equal (length (heks/present-slides)) 3))
    (should (string-prefix-p "* One" (car (heks/present-slides))))))

(ert-deftest heks/present/org-slides-are-the-level-that-repeats ()
  "One `*' title over several `**' sections means the sections are the slides.

What comes before the first section -- the file's own `#+' lines and its
title -- is the first slide, because a talk does open with its title."
  (with-temp-buffer
    (insert "#+title: Talk\n\n* The title\n\n** One\nA\n\n** Two\nB\n")
    (org-mode)
    (should (equal (heks/present--org-level (buffer-string)) 2))
    (let ((slides (heks/present-slides)))
      (should (equal (length slides) 3))
      (should (string-prefix-p "#+title: Talk" (car slides)))
      (should (string-prefix-p "** One" (nth 1 slides)))
      (should (string-prefix-p "** Two" (nth 2 slides))))))

(ert-deftest heks/present/a-buffer-that-is-not-a-document-has-no-slides ()
  (with-temp-buffer
    (insert "just some text\n")
    (should-not (heks/present-format))
    (should-not (heks/present-slides))
    (should-error (heks/present-deck-html) :type 'user-error)))

(ert-deftest heks/present/an-empty-document-has-no-slides ()
  (heks-ert--with-file ".md" ""
    (should-error (heks/present-deck-html) :type 'user-error)))

;;
;; ====== The deck ======
;;

(ert-deftest heks/present/deck-is-one-section-per-slide ()
  (heks-ert--with-file ".md" "# One\n\nA\n\n---\n\n# Two\n\nB\n\n---\n\n# Three\n\nC\n"
    (let ((deck (heks/present-deck-html)))
      (should (equal (heks-ert--count "<section class=\"slide\"" deck) 3))
      (should (equal (heks-ert--count "</section>" deck) 3))
      (should (string-match-p "<title>" deck)))))

(ert-deftest heks/present/a-deck-of-an-org-note-is-made-too ()
  "A deck is not a Markdown thing: an Org note is exported slide by slide,
which is a different way of reading the same document."
  (with-temp-buffer
    (insert (concat "#+title: Talk\n\n* The title\n\n"
                    "** One\nA paragraph.\n\n"
                    "** Two\nB paragraph.\n"))
    (org-mode)
    (let ((deck (heks/present-deck-html)))
      (should (equal (heks-ert--count "<section class=\"slide\"" deck) 3))
      (should (string-match-p "A paragraph." deck))
      (should (string-match-p "B paragraph." deck)))))

(ert-deftest heks/present/deck-walks-its-slides-with-the-keyboard ()
  (heks-ert--with-file ".md" "# One\n\nA\n\n---\n\n# Two\n\nB\n"
    (let ((deck (heks/present-deck-html)))
      (should (string-match-p "ArrowRight" deck))
      (should (string-match-p "ArrowLeft" deck))
      (should (string-match-p "addEventListener('keydown'" deck))
      ;; The number of slides is on the page, and it is announced.
      (should (string-match-p "1 / 2" deck))
      (should (string-match-p "aria-live=\"polite\"" deck))
      ;; Both buttons can be clicked, and both say what they do.
      (should (string-match-p "id=\"next\"" deck))
      (should (string-match-p "id=\"prev\"" deck))
      (should (string-match-p "aria-label=\"Next slide\"" deck)))))

(ert-deftest heks/present/a-deck-prints-one-slide-per-page ()
  (heks-ert--with-file ".md" "# One\n\nA\n\n---\n\n# Two\n\nB\n"
    (let ((deck (heks/present-deck-html)))
      (should (string-match-p "@page" deck))
      (should (string-match-p "break-after: page" deck))
      (should (string-match-p "page-break-after: always" deck)))))

(ert-deftest heks/present/a-deck-carries-its-own-stylesheet-and-script ()
  "Nothing a deck needs is fetched: it opens from a file:// URL."
  (heks-ert--with-file ".md" "# One\n\nA\n"
    (let ((deck (heks/present-deck-html)))
      (should (string-match-p "<style>" deck))
      (should (string-match-p "<script>" deck))
      (should-not (string-match-p "src=\"http" deck))
      (should-not (string-match-p "href=\"http" deck)))))

(ert-deftest heks/present/the-deck-of-a-file-is-written-beside-it ()
  (heks-ert--with-file ".md" "# One\n\nA\n\n---\n\n# Two\n\nB\n"
    (let* ((source (buffer-file-name))
           (target (concat (file-name-sans-extension source) ".deck.html")))
      (should (equal (heks/present-deck-export) target))
      (should (file-exists-p target))
      (with-temp-buffer
        (insert-file-contents target)
        (should (string-match-p "<section class=\"slide\"" (buffer-string)))))))

(ert-deftest heks/present/a-slide-boundary-is-inserted-in-the-documents-own-way ()
  (heks-ert--with-file ".md" "# One\n\nA\n"
    (goto-char (point-max))
    (heks/present-insert-slide)
    (should (string-match-p "^---$" (buffer-string))))
  (with-temp-buffer
    (insert (concat "#+title: Talk\n\n* The title\n\n"
                    "** One\nA\n\n** Two\nB\n"))
    (org-mode)
    (goto-char (point-max))
    (heks/present-insert-slide)
    (should (string-match-p "^\\*\\* $" (buffer-string))))
  (with-temp-buffer
    (insert "text\n")
    (should-error (heks/present-insert-slide) :type 'user-error)))

;;
;; ====== The preview ======
;;

(ert-deftest heks/preview/the-document-is-shown-in-a-buffer-that-survives ()
  "EWW renders the document into the preview buffer, and it is still there
afterwards.

`eww-render' kills the buffer it is *called from*, because it is the
callback of a retrieval and that buffer is the retrieval's own; a preview
that renders from its own destination buffer is left holding a dead one,
and the document that was rendered is gone with it."
  (heks-ert--with-file ".md" "# Title\n\nSome text.\n"
    (let ((heks/preview-buffer-name "*heks-ert preview*"))
      (unwind-protect
          (progn
            (heks/preview)
            (let ((shown (get-buffer heks/preview-buffer-name)))
              (should (buffer-live-p shown))
              (with-current-buffer shown
                (should (eq major-mode 'eww-mode)))
              (should (string-match-p "Some text\\." (heks-ert--text shown)))))
        (when (get-buffer heks/preview-buffer-name)
          (kill-buffer heks/preview-buffer-name))))))

(ert-deftest heks/preview/rendering-it-again-shows-what-the-buffer-says-now ()
  "The preview follows its buffer: the same call renders the current text."
  (heks-ert--with-file ".md" "# One\n\nfirst\n"
    (let ((source (current-buffer))
          (heks/preview-buffer-name "*heks-ert preview*"))
      (unwind-protect
          (progn
            (heks/preview)
            (with-current-buffer source
              (goto-char (point-max))
              (insert "\nsecond paragraph\n")
              (heks/render-file source)
              (should (heks/preview--reload source)))
            (should (string-match-p "second paragraph"
                                    (heks-ert--text heks/preview-buffer-name))))
        (when (get-buffer heks/preview-buffer-name)
          (kill-buffer heks/preview-buffer-name))))))

;;
;; ====== Where the notes are ======
;;

(ert-deftest heks/notes/a-directory-nobody-set-is-not-a-directory ()
  "A setting that was never given a value cannot be turned into a path.

This is what naming the notes directory after nothing used to do:
`file-truename' of nil stops the configuration where it is loaded."
  (dolist (unset '(nil "" "   "))
    (let ((heks/notes-dir unset))
      (should-not (heks/notes-directory)))))

(ert-deftest heks/notes/a-directory-that-is-set-is-answered-expanded ()
  (dolist (written '("~/Hacking/private-notes" "$HOME/Hacking/private-notes"))
    (let* ((heks/notes-dir written)
           (directory (heks/notes-directory)))
      (should (stringp directory))
      (should (string-suffix-p "private-notes" directory))
      (should (string-prefix-p (file-truename (expand-file-name "~")) directory)))))

;;
;; ====== Reading the notes without reading them twice ======
;;

(defmacro heks-ert--with-notes (directory &rest body)
  "Run BODY over DIRECTORY as the notes directory, with nothing remembered.
The caches are what a prompt is made of, so a test of a prompt starts from
a cache that says nothing rather than from whatever the last test left."
  (declare (indent 1))
  `(cl-letf (((symbol-function 'heks/notes-directory)
              (lambda () (file-name-as-directory ,directory))))
     (heks/notes--forget-cache)
     (unwind-protect (progn ,@body)
       (heks/notes--forget-cache))))

(defun heks-ert--write-note (file title)
  "Write FILE as a note titled TITLE, and return it."
  (make-directory (file-name-directory file) t)
  (write-region (format "#+title: %s\n#+date: [2026-01-01 Thu]\n#+filetags: :one:\n\nBody.\n"
                        title)
                nil file nil 'silent)
  file)

(ert-deftest heks/notes/a-title-changed-on-disk-is-read-again ()
  "A note edited by another program is what the next prompt offers.

The title of a note is remembered, and remembered with the modification
time and the size it was read at: a file that says something else now is
read again, whoever wrote it."
  (let ((root (heks-ert--temp-directory)))
    (unwind-protect
        (heks-ert--with-notes root
          (let ((note (expand-file-name "work/note.org" root)))
            (heks-ert--write-note note "The old title")
            (should (equal (mapcar #'car (heks/notes--candidates))
                           '("The old title")))
            ;; Written again by something that is not this configuration, with
            ;; a title of a different length: nothing depends on how finely the
            ;; filesystem dates a file.
            (heks-ert--write-note note "A title someone else gave it")
            (should (equal (mapcar #'car (heks/notes--candidates))
                           '("A title someone else gave it")))
            (should (equal (alist-get 'title (heks/notes--header note))
                           "A title someone else gave it"))))
      (delete-directory root t))))

(ert-deftest heks/notes/the-archive-is-in-no-prompt ()
  "The dot-folder is not a topic, is not a candidate, and is not scanned."
  (let ((root (heks-ert--temp-directory)))
    (unwind-protect
        (heks-ert--with-notes root
          (heks-ert--write-note (expand-file-name "work/note.org" root) "A working note")
          (heks-ert--write-note (expand-file-name ".archive/old/note.org" root)
                                "A note from a former employer")
          (should (equal (mapcar #'cdr (heks/notes--candidates))
                         (list (expand-file-name "work/note.org" root))))
          (should (equal (heks/notes-topics) '("work")))
          ;; It is still there, for the key that asks for it.
          (should (equal (heks/notes-files t)
                         (list (expand-file-name ".archive/old/note.org" root)))))
      (delete-directory root t))))

(ert-deftest heks/notes/a-note-that-was-created-here-is-offered-at-once ()
  "Creating a note throws the scan away; nothing waits for the cache to expire."
  (let ((root (heks-ert--temp-directory)))
    (unwind-protect
        (heks-ert--with-notes root
          (let ((heks/notes-cache-seconds 3600))
            (heks-ert--write-note (expand-file-name "work/one.org" root) "One")
            (should (= 1 (length (heks/notes--candidates))))
            (heks-ert--write-note (expand-file-name "work/two.org" root) "Two")
            ;; The scan is reused while nothing says otherwise: that is what
            ;; makes the second prompt of a session cost nothing.
            (should (= 1 (length (heks/notes--candidates))))
            ;; And this is what creating a note does -- `heks/notes-new',
            ;; `heks/notes-move' and the save hook all do it.
            (heks/notes--forget-cache)
            (should (= 2 (length (heks/notes--candidates))))))
      (delete-directory root t))))

(ert-deftest heks/notes/what-is-remembered-is-remembered-for-one-directory ()
  "Pointing `heks/notes-dir' elsewhere serves nothing from where it was."
  (let ((one (heks-ert--temp-directory))
        (two (heks-ert--temp-directory)))
    (unwind-protect
        (progn
          (heks-ert--write-note (expand-file-name "work/one.org" one) "The note in one")
          (heks-ert--write-note (expand-file-name "work/two.org" two) "The note in two")
          (heks/notes--forget-cache)
          (cl-letf (((symbol-function 'heks/notes-directory)
                     (lambda () (file-name-as-directory one))))
            (should (equal (mapcar #'car (heks/notes--candidates))
                           '("The note in one"))))
          ;; No forgetting in between: the directory itself is what decides.
          (cl-letf (((symbol-function 'heks/notes-directory)
                     (lambda () (file-name-as-directory two))))
            (should (equal (mapcar #'car (heks/notes--candidates))
                           '("The note in two")))))
      (heks/notes--forget-cache)
      (delete-directory one t)
      (delete-directory two t))))

(ert-deftest heks/notes/an-annotation-says-what-the-note-is ()
  "The columns beside a title are the topic, the tags and the age of the note."
  (let ((root (heks-ert--temp-directory)))
    (unwind-protect
        (heks-ert--with-notes root
          (heks-ert--write-note (expand-file-name "work/infra/note.org" root) "A note")
          (let ((annotation (heks/notes--note-annotation
                             (caar (heks/notes--candidates)))))
            (should (equal (car annotation) "work/infra"))
            ;; Its own tags and the folders it lives in, derived, never written.
            (should (equal (cadr annotation) "one:work:infra"))
            (should (stringp (nth 2 annotation))))
          ;; The annotation a row asks for is the same whether it is given the
          ;; table made for the prompt or the candidate alone.
          (let* ((candidates (heks/notes--candidates))
                 (info (heks/notes--note-info (mapcar #'cdr candidates))))
            (should (equal (heks/notes--note-annotation (caar candidates) info)
                           (heks/notes--note-annotation (caar candidates))))))
      (delete-directory root t))))

;;
;; ====== A hover popup that does not wait ======
;;

(defun heks-ert--asked-with (functions pos settle)
  "Ask POS with FUNCTIONS and return each answer with the delay before it.
The result is a list of (SECONDS . TEXT), in the order the popup would have
shown them; SETTLE is how long to listen for answers before giving up."
  (let ((answers nil)
        (start (float-time)))
    (let ((eldoc-documentation-functions functions))
      (heks/hover--request pos
                           (lambda (text)
                             (push (cons (- (float-time) start) text) answers)))
      ;; The answers arrive through timers, which `sit-for' runs.
      (let ((deadline (+ (float-time) settle)))
        (while (< (float-time) deadline) (sit-for 0.02))))
    (nreverse answers)))

(ert-deftest heks/hover/the-fast-answer-is-not-held-behind-the-slow-one ()
  "A source that answers at once is shown at once, not at the timeout.

Waiting for every source before showing anything is what made a popup
appear a second after the pointer stopped moving, for a server that had
already answered."
  (with-temp-buffer
    (insert "(foo bar)")
    (emacs-lisp-mode)
    (let* ((answers (heks-ert--asked-with
                     (list (lambda (cb) (funcall cb "the fast one") t)
                           (lambda (cb)
                             (run-with-timer 0.4 nil
                                             (lambda () (funcall cb "the slow one")))
                             t))
                     (point-min) 0.9))
           (first (car answers))
           (last (car (last answers))))
      (should (equal (cdr first) "the fast one"))
      ;; It arrived at once, not when the request timed out.
      (should (< (car first) 0.2))
      ;; And when the slow one does answer, the popup says so too.
      (should (string-match-p "the slow one" (cdr last)))
      (should (string-match-p "the fast one" (cdr last))))))

(ert-deftest heks/hover/a-source-with-nothing-to-say-calls-back-nobody ()
  (with-temp-buffer
    (insert "(foo)")
    (emacs-lisp-mode)
    (should-not (heks-ert--asked-with (list (lambda (_cb) nil)) (point-min) 0.7))))

;;; ---- An idle pointer is not looked at again ------------------------

(ert-deftest heks/hover/a-pointer-that-has-not-moved-is-not-asked-about-again ()
  "Three polls of an unmoved pointer look the symbol up once, not three times."
  (let ((buffer (generate-new-buffer " *heks-hover-poll*"))
        (asked 0)
        (heks/hover--sight nil)
        (heks/hover--anchor nil))
    (unwind-protect
        (progn
          (with-current-buffer buffer (setq heks/hover-mode t))
          (cl-letf (((symbol-function 'heks/hover--target)
                     (lambda () (cl-incf asked) nil)))
            (heks/hover--poll)
            (let ((after-first asked))
              (heks/hover--poll)
              (heks/hover--poll)
              (should (= after-first asked))
              (should (= asked 1)))))
      (with-current-buffer buffer (setq heks/hover-mode nil))
      (heks/hover--poll)
      (should-not (timerp heks/hover--poll-timer))
      (kill-buffer buffer))))

;;
;; ====== The JVM build tools ======
;;

(ert-deftest heks/jvm/the-same-goal-has-a-name-in-each-build-tool ()
  (should (equal (heks/jvm-goal-for "test" 'maven) "test"))
  (should (equal (heks/jvm-goal-for "package" 'maven) "package"))
  (should (equal (heks/jvm-goal-for "package" 'gradle) "assemble"))
  (should (equal (heks/jvm-goal-for "verify" 'gradle) "check"))
  (should (equal (heks/jvm-goal-for "dependencies" 'maven) "dependency:tree")))

(ert-deftest heks/jvm/a-goal-nobody-defined-is-refused ()
  (should-error (heks/jvm-goal-for "nosuchgoal" 'maven) :type 'user-error))

(ert-deftest heks/jvm/what-is-offered-is-what-the-table-says ()
  (dolist (entry heks/jvm-goals)
    (should (equal (length entry) 4))
    (should (assoc (car entry) (heks/jvm--read-table) #'equal))
    ;; What is read out of the menu is a goal the table can answer for.
    (should (stringp (heks/jvm-goal-for (car entry) 'gradle)))))

(ert-deftest heks/jvm/the-project-is-the-nearest-one ()
  "A Maven project being migrated to Gradle is two projects at once."
  (let* ((root (heks-ert--temp-directory))
         (inner (expand-file-name "service/" root)))
    (unwind-protect
        (progn
          (make-directory inner t)
          (write-region "" nil (expand-file-name "pom.xml" root) nil 'silent)
          (write-region "" nil (expand-file-name "build.gradle.kts" inner) nil 'silent)
          (heks-ert--in root
            (should (eq (car (heks/jvm--project)) 'maven)))
          (heks-ert--in inner
            (should (eq (car (heks/jvm--project)) 'gradle))))
      (delete-directory root t))))

(ert-deftest heks/jvm/a-directory-that-is-no-project-says-so ()
  (let ((root (heks-ert--temp-directory)))
    (unwind-protect
        (heks-ert--in root
          (should-not (heks/jvm--project)))
      (delete-directory root t))))

(ert-deftest heks/jvm/a-wrapper-is-preferred-to-a-system-program ()
  (let* ((root (heks-ert--temp-directory))
         (wrapper (expand-file-name "mvnw" root)))
    (unwind-protect
        (progn
          (write-region "#!/bin/sh\n" nil wrapper nil 'silent)
          (set-file-modes wrapper #o755)
          (should (equal (heks/jvm-build-program root "mvnw" "mvn") wrapper))
          (set-file-modes wrapper #o644)
          ;; Not executable, so not the wrapper.
          (should (equal (heks/jvm-build-program root "mvnw" "mvn") "mvn")))
      (delete-directory root t))))

(ert-deftest heks/jvm/the-build-file-is-found-above-the-buffer ()
  (let* ((root (heks-ert--temp-directory))
         (inner (expand-file-name "a/b/" root)))
    (unwind-protect
        (progn
          (make-directory inner t)
          (write-region "" nil (expand-file-name "pom.xml" root) nil 'silent)
          (heks-ert--in inner
            (should (equal (file-name-as-directory (heks/locate-project-file "pom.xml"))
                           (file-name-as-directory root))))
          ;; Above the directory holding it there is nothing.
          (heks-ert--in "/"
            (should-not (heks/locate-project-file "heks/no-such-file"))))
      (delete-directory root t))))

;;
;; ====== Formatting, wherever the buffer is ======
;;

(defvar heks-ert-format-ran nil
  "Whether the stand-in formatter below has run.

A variable of the configuration's own rather than one a test closes over,
because the command is called the way a key calls it -- by name, from
`call-interactively' -- and a shared variable is what survives that.")

(defun heks-ert-format-something ()
  "A stand-in formatter: what a language module would install for a language."
  (interactive)
  (setq heks-ert-format-ran t))

(ert-deftest heks/format/a-language-of-its-own-answers-first ()
  "A module teaches the one key a formatter by adding a predicate."
  (let ((heks-ert-format-ran nil)
        (heks/format-dispatch
         (list (cons (lambda () t) #'heks-ert-format-something))))
    (with-temp-buffer
      (heks/format-buffer)
      (should heks-ert-format-ran))))

(ert-deftest heks/format/a-predicate-that-does-not-hold-is-passed-over ()
  "The dispatcher asks every formatter in turn, and only the one that
answers is the one that formats."
  (let ((heks-ert-format-ran nil)
        (heks/format-dispatch (list (cons (lambda () nil) #'heks-ert-format-something))))
    (with-temp-buffer
      (fundamental-mode)
      ;; What is left after the language's own formatter -- Eglot, then
      ;; `format-all' -- depends on what this machine has installed, and
      ;; saying so is the point of the refusal when it has neither.
      (if (fboundp 'format-all-region-or-buffer)
          (ignore-errors (heks/format-buffer))
        (should-error (heks/format-buffer) :type 'user-error)))
    (should-not heks-ert-format-ran)))

;;
;; ====== Terraform ======
;;

(ert-deftest heks/terraform/the-commands-say-so-when-there-is-no-terraform ()
  (skip-unless (not (executable-find terraform-command)))
  (let ((root (heks-ert--temp-directory)))
    (unwind-protect
        (heks-ert--in root
          (should-error (heks/terraform-run "plan") :type 'user-error))
      (delete-directory root t))))

(ert-deftest heks/terraform/the-configuration-is-the-directory-of-the-file ()
  (let* ((root (heks-ert--temp-directory))
         (file (expand-file-name "main.tf" root)))
    (unwind-protect
        (progn
          (write-region "" nil file nil 'silent)
          (with-current-buffer (find-file-noselect file)
            (unwind-protect
                (should (equal (file-name-as-directory (heks/terraform-root))
                               (file-name-as-directory root)))
              (set-buffer-modified-p nil)
              (kill-buffer))))
      (delete-directory root t))))

;;
;; ====== Shell scripts ======
;;

(ert-deftest heks/shell/shellcheck-is-told-to-follow-the-sources-of-a-script ()
  "Emacs runs shellcheck itself (`sh-shellcheck-flymake'); what this
configuration says to it is that the files a script sources are part of
what is checked, rather than a note on every `source' line."
  (require 'sh-script)
  (should (member "--external-sources" sh-shellcheck-arguments)))

(ert-deftest heks/shell/a-copy-keeps-the-extension-of-the-file ()
  "shfmt and shellcheck read the dialect from the name too."
  (with-temp-buffer
    (setq-local buffer-file-name "/tmp/heks-ert/one/script.bash")
    (should (equal (heks/shell-copy-suffix) ".bash")))
  (with-temp-buffer
    (should (equal (heks/shell-copy-suffix) ".sh"))))

(ert-deftest heks/shell/shfmt-arguments-come-before-the-file ()
  (let ((heks/shfmt-arguments '("-i" "2")))
    (should (equal (heks/shfmt-command "/tmp/a.sh")
                   (list (heks/tool-path heks/shfmt-program)
                         "-w" "-i" "2" "/tmp/a.sh")))))


(ert-deftest heks/shell/both-of-the-modes-of-a-script-are-shell-buffers ()
  (with-temp-buffer
    (sh-mode)
    (should (heks/shell-buffer-p)))
  ;; The other mode a `.sh' file opens in.  It is not run here -- the
  ;; Tree-sitter parser is not what is being tested -- only recognised.
  (with-temp-buffer
    (setq major-mode 'bash-ts-mode)
    (should (heks/shell-buffer-p)))
  (with-temp-buffer
    (fundamental-mode)
    (should-not (heks/shell-buffer-p))))

;;
;; ====== A language server and the checkers of a buffer ======
;;
;; Eglot replaces `flymake-diagnostic-functions' with a list of its own
;; backend alone while it manages a buffer; one function of `dev-flymake.el' puts
;; back what the buffer had.  The swap below is made with the macro Eglot's
;; own mode is written with, so what is read is Eglot's behaviour rather
;; than a list this file made up: if Eglot stops keeping the old value where
;; `heks/flymake-keep-backends' reads it, these tests fail instead of
;; quietly leaving a buffer checked by its server alone.

(ert-deftest heks/flymake/a-server-does-not-take-the-checkers-of-a-buffer ()
  "Whatever checked a buffer before a server manages it checks it still."
  (require 'eglot)
  (with-temp-buffer
    (setq-local flymake-diagnostic-functions
                '(python-flymake sh-shellcheck-flymake heks/shfmt-backend))
    (eval '(eglot--setq-saving flymake-diagnostic-functions
                               '(eglot-flymake-backend))
          t)
    (should (equal flymake-diagnostic-functions '(eglot-flymake-backend)))
    (setq-local eglot--managed-mode t)
    (heks/flymake-keep-backends)
    ;; The buffer is one Flymake is not on in, so being asked to check it --
    ;; which is the other half of what the call above does -- does nothing.
    (should (memq 'eglot-flymake-backend flymake-diagnostic-functions))
    (should (memq 'python-flymake flymake-diagnostic-functions))
    (should (memq 'sh-shellcheck-flymake flymake-diagnostic-functions))
    (should (memq 'heks/shfmt-backend flymake-diagnostic-functions))))

(ert-deftest heks/flymake/a-buffer-no-server-manages-keeps-what-it-has ()
  (require 'eglot)
  (with-temp-buffer
    (setq-local flymake-diagnostic-functions '(python-flymake))
    (heks/flymake-keep-backends)
    (should (equal flymake-diagnostic-functions '(python-flymake)))))

;;
;; ====== What a Scheme definition looks like, and where it is ======
;;

(ert-deftest heks/scheme/a-definition-is-the-head-and-not-a-mention ()
  "A name is defined by the head of a `define', not by being mentioned.

The search itself cannot tell a definition from a use -- it looks for a
name and a `define' on one line -- so what is checked here is what reads
the hits back, which is what keeps a call of `greet' from being offered as
its definition."
  (dolist (case '(("(define (greet name) name)" "greet" t)
                  ("(define-public (pub-fn x) x)" "pub-fn" t)
                  ("(define pub-var 1)" "pub-var" t)
                  ("(define* (f x) x)" "f" t)
                  ("(define-syntax-rule (when-let* ((x y)) x)" "when-let*" t)
                  ("(define-record-type <ping> (fields (name ping-name)))" "<ping>" t)
                  ("(define (publish! x) x)" "publish!" t)
                  ("(define (empty? x) x)" "empty?" t)
                  ("  (define-public (scm->string x) x)" "scm->string" t)
                  ("(define-module (verify demo))" "demo" nil)
                  ("(greet world)" "greet" nil)
                  ("(define pub-var-2 1)" "pub-var" nil)
                  ("(define (greet name) (string-append name))" "string-append" nil)))
    (should (equal (and (heks/scheme-definition-line-p (nth 0 case) (nth 1 case)) t)
                   (nth 2 case)))))

(ert-deftest heks/scheme/the-column-is-where-the-name-is-defined ()
  "The jump lands on the name being defined, not on the name first seen."
  (should (equal (heks/scheme-definition-column "(define (greet name) name)" "greet") 9))
  (should (equal (heks/scheme-definition-column "(define-public pub-var 1)" "pub-var") 15)))

(ert-deftest heks/scheme/the-files-answer-with-the-definitions ()
  "A definition is found in another file, and a use is not a definition.

The files are what answer when no REPL can: the buffer is reading a file
that both calls the name and defines it, the definition that is meant is
in another file of the project, and a file that is not Scheme defining the
name is not searched at all."
  (skip-unless (or (executable-find "rg") (executable-find "grep")))
  ;; A project of its own, so that what is found is what was written here
  ;; and not whatever else the directory happens to hold.
  (let* ((root (file-name-as-directory (heks-ert--temp-directory)))
         (main (expand-file-name "main.scm" root))
         (utility (expand-file-name "utility.scm" root))
         (notes (expand-file-name "notes.txt" root)))
    (unwind-protect
        (progn
          (write-region (concat "(define (main)\n"
                                "  (greet name))\n"
                                "(define-public pub-var 1)\n"
                                "(define (twice x) (+ x x))\n")
                        nil main nil 'silent)
          (write-region (concat "(define (greet name)\n"
                                "  name)\n"
                                "(define (twice x) (* 2 x))\n")
                        nil utility nil 'silent)
          ;; Not Scheme, so not searched, though it defines the name too.
          (write-region "(define (greet name) name)\n" nil notes nil 'silent)
          (heks-ert--in root
            (with-current-buffer (find-file-noselect main)
              (unwind-protect
                  (progn
                    (should (equal (heks-ert--xref-locations
                                    (heks/scheme-definitions-in-files "greet"))
                                   '(("utility.scm" 1))))
                    (should (equal (heks-ert--xref-locations
                                    (heks/scheme-definitions-in-files "pub-var"))
                                   '(("main.scm" 3))))
                    ;; Defined in both: the file being read comes first.
                    (should (equal (heks-ert--xref-locations
                                    (heks/scheme-definitions-in-files "twice"))
                                   '(("main.scm" 4) ("utility.scm" 3))))
                    (should-not (heks/scheme-definitions-in-files "no-such-name")))
                (set-buffer-modified-p nil)
                (kill-buffer))))
      (delete-directory root t)))))

(ert-deftest heks/scheme/the-backend-answers-for-a-scheme-buffer-alone ()
  "The backend of this module is the one a Scheme buffer is jumped with.

`xref' takes the first function of `xref-backend-functions' that answers,
so what makes `M-.' a Scheme jump is this function saying
`heks/scheme' in a Scheme buffer -- and saying nothing in a buffer
that is not one, where the backends the rest of the configuration has
should still answer."
  (with-temp-buffer
    (scheme-mode)
    (should (eq (heks/scheme-xref-backend) 'heks/scheme)))
  (with-temp-buffer
    (emacs-lisp-mode)
    (should-not (heks/scheme-xref-backend))))

(ert-deftest heks/scheme/the-repl-is-asked-before-the-files ()
  "A jump asks the REPL, then the files, then the wider search.

What the REPL says is the answer when it has one; where it has none -- or
where what it says is a module rather than a definition in a file -- the
files are asked, and where the files have nothing the search the rest of
the configuration gives a buffer is asked last (see `dev-flymake.el').  Each of
the four is stubbed, so what is checked is the order they are asked in
rather than what they answer with."
  (let ((asked '()))
    (cl-letf (((symbol-function 'heks/scheme--repl-definition)
               (lambda (_) (push 'repl asked) nil))
              ((symbol-function 'heks/scheme--repl-module)
               (lambda (_) (push 'module asked) nil))
              ((symbol-function 'heks/scheme-definitions-in-files)
               (lambda (_) (push 'files asked) nil))
              ((symbol-function 'heks/scheme--dumb-jump)
               (lambda (_) (push 'dumb-jump asked) 'the-wider-answer)))
      (should (eq (xref-backend-definitions 'heks/scheme "greet")
                  'the-wider-answer)))
    (should (equal (nreverse asked) '(repl module files dumb-jump)))))

(ert-deftest heks/scheme/the-repl-says-a-line-and-the-column-is-read ()
  "What the REPL says is turned into a jump onto the name itself.

Guile's location of a procedure is a file and a line and no column at
all, and a line is where Geiser's own jump goes; here the head that
defines the name is looked for in the file the REPL named, and the point
lands on the name rather than on the parenthesis in front of it.  A file
that is not on this machine is not an answer to jump to."
  (let* ((root (file-name-as-directory (heks-ert--temp-directory)))
         (file (expand-file-name "utility.scm" root)))
    (unwind-protect
        (progn
          (write-region (concat ";; The name is defined twice, on purpose,\n"
                                "(define (greet name)\n"
                                "  name)\n"
                                "(define (other) (greet \"x\"))\n"
                                "(define (greet name)\n"
                                "  name)\n")
                        nil file nil 'silent)
          (cl-letf (((symbol-function 'geiser-edit--location-file)
                     (lambda (location) (cdr (assoc "file" location))))
                    ((symbol-function 'geiser-edit--location-line)
                     (lambda (location) (cdr (assoc "line" location))))
                    ((symbol-function 'geiser-edit--location-name)
                     (lambda (_) nil))
                    ;; Geiser's own two patterns, as they are: the head of a
                    ;; `define' of the name, and the head of the two forms
                    ;; whose names arrive as a list.
                    ((symbol-function 'geiser-edit--def-re)
                     (lambda (name)
                       (concat "[(]define[^[:space:]()]*[[:space:]]+[(]?"
                               (regexp-quote name))))
                    ((symbol-function 'geiser-edit--def-re*)
                     (lambda (name)
                       (concat "[(]define-syntaxes[[:space:]]+[(]"
                               (regexp-quote name)))))
            (let* ((xref (heks/scheme--location-xref
                          `(("file" . ,file) ("line" . 2)) "greet"))
                   (place (xref-item-location xref)))
              (should (equal (file-name-nondirectory (xref-file-location-file place))
                             "utility.scm"))
              (should (equal (xref-file-location-line place) 2))
              (should (equal (xref-file-location-column place) 9))
              (should (equal (xref-item-summary xref) "(define (greet name)")))
              ;; The line the REPL named is looked at first, so the second
              ;; definition is the one that arrives when it named that one.
              (should (equal (xref-file-location-line
                              (xref-item-location
                               (heks/scheme--location-xref
                                `(("file" . ,file) ("line" . 5)) "greet")))
                             5))
              (should-not (heks/scheme--location-xref
                           '(("file" . "/no/such/file.scm") ("line" . 1))
                           "greet")))))
      (delete-directory root t)))

(ert-deftest heks/scheme/a-mention-is-a-name-of-its-own ()
  "A name is mentioned where it is written as a name.

`greet' is not mentioned by `greeting' or by `greet-and-run', and it is
mentioned by `greet?' -- which a word boundary cannot say, because `1+',
`string-append' and `set-x!' are names that a word boundary falls in the
middle of."
  (should (heks/scheme-mention-line-p "(greet name)" "greet"))
  (should (heks/scheme-mention-line-p "  greet" "greet"))
  (should-not (heks/scheme-mention-line-p "(greeting)" "greet"))
  (should-not (heks/scheme-mention-line-p "(greet-and-run)" "greet"))
  (should (heks/scheme-mention-line-p "(greet? x)" "greet?"))
  (should-not (heks/scheme-mention-line-p "(greet? x)" "greet"))
  (should-not (heks/scheme-mention-line-p "(string-append a b)" "append"))
  (should (heks/scheme-mention-line-p "(set-x! v)" "set-x!"))
  (should-not (heks/scheme-mention-line-p "1+" "1"))
  (should (heks/scheme-mention-line-p "(let ((a 1+)) 1+)" "1+")))

(ert-deftest heks/scheme/the-names-the-files-define-are-what-is-asked-for ()
  "What `M-.' can be asked for is what the project's files define.

A `define' of any kind is one name, a name defined twice in two files is
one name, and a file that is not Scheme contributes nothing -- the same
files the definitions are searched in, asked the one question that has no
name in it to search for."
  (skip-unless (or (executable-find "rg") (executable-find "grep")))
  (let* ((root (file-name-as-directory (heks-ert--temp-directory)))
         (main (expand-file-name "main.scm" root))
         (utility (expand-file-name "utility.scm" root))
         (notes (expand-file-name "notes.txt" root)))
    (unwind-protect
        (progn
          (write-region (concat "(define (main) (greet name))\n"
                                "(define-public pub-var 1)\n")
                        nil main nil 'silent)
          (write-region (concat "(define (greet name) name)\n"
                                "(define-syntax-rule (twice x) (* 2 x))\n")
                        nil utility nil 'silent)
          (write-region "(define (greet name) name)\n" nil notes nil 'silent)
          (heks-ert--in root
            (with-current-buffer (find-file-noselect main)
              (unwind-protect
                  (should (equal (heks/scheme-defined-names)
                                 '("greet" "main" "pub-var" "twice")))
                (set-buffer-modified-p nil)
                (kill-buffer))))
      (delete-directory root t)))))

(ert-deftest heks/scheme/the-names-are-read-once-and-remembered ()
  "The search behind the prompt is not made twice in the same minute.

The names a project defines are what `M-.' completes from, so they are
asked for every time a jump is asked for, and reading them is a search of
every Scheme file of the project.  The answer is remembered by the
directory it was read from and by its age: the second question is answered
from it, a question about another directory is not, and neither is one
asked after the lifetime has passed."
  (let ((asked 0)
        (heks/scheme--defined-names-cache nil))
    (cl-letf (((symbol-function 'heks/scheme--search-files)
               (lambda (&rest _) (setq asked (1+ asked)) nil))
              ((symbol-function 'heks/scheme-load-path)
               (lambda () temporary-file-directory)))
      (should-not (heks/scheme-defined-names))
      (should-not (heks/scheme-defined-names))
      (should (equal asked 1))
      ;; Another project, read from another directory, is a new question.
      (let ((temporary-file-directory (file-name-as-directory
                                       (heks-ert--temp-directory))))
        (unwind-protect
            (progn
              (heks/scheme-defined-names)
              (should (equal asked 2)))
          (delete-directory temporary-file-directory t)))
      ;; And so is the same project once the answer has gone stale.
      (let ((heks/scheme-defined-names-lifetime -1))
        (heks/scheme-defined-names)
        (should (equal asked 3))))))

(ert-deftest heks/scheme/the-repls-false-is-no-answer-at-all ()
  "A `#f' from Guile is not a place, whichever question it answers.

Guile answers `#f' for a symbol it has and cannot place -- a procedure
written in C, whose module it knows and whose file it does not -- and the
`#f' of such an answer comes back through Geiser as the keyword `:f'
rather than as nothing at all.  So what is a place is what Geiser's own
jump reads as one (`geiser-edit--try-edit'): a list, and anything else is
no answer, read in the one function that reads a location
(`heks/scheme--location-p') so that every question that carries one
-- a definition, a module, the places a name is called from -- is answered
without a stop."
  (should-not (heks/scheme--location-p :f))
  (should-not (heks/scheme--location-p nil))
  (should (equal (heks/scheme--location-p '(("file" . "/tmp/x"))) '(("file" . "/tmp/x"))))
  (should-not (heks/scheme--location-xref :f "string->number"))
  (cl-letf (((symbol-function 'heks/scheme-repl-connected-p) (lambda () t))
            ((symbol-function 'geiser-edit-symbol-location) (lambda (_) :f))
            ((symbol-function 'geiser-completion--module-at-point)
             (lambda () '(ice-9 popen)))
            ((symbol-function 'geiser-edit-module-location) (lambda (_) :f))
            ;; Nothing may reach the accessors with a `:f', and a stop here
            ;; is how that would arrive.
            ((symbol-function 'geiser-edit--location-file)
             (lambda (_) (error "A `:f' was read as a location")))
            ((symbol-function 'geiser-eval--send/result)
             (lambda (_)
               '( (("location" . :f)
                   ("signature" . ("greet")))))))
    (should-not (heks/scheme--repl-definition "string->number"))
    (should-not (heks/scheme--repl-module "string->number"))
    ;; A caller whose place Guile has as `#f' is dropped, not read as one.
    (should-not (heks/scheme--repl-callers "greet"))))

(ert-deftest heks/scheme/a-head-says-which-name-it-defines ()
  "A line says which name it defines, or that it defines none.

The name is read out of the head of the definition, and a `define' that
begins the line is the only head that counts: one mentioned inside another
form, or commented out, defines nothing this project can jump to."
  (dolist (case '(("(define (greet name) name)" "greet")
                  ("(define-public pub-var 1)" "pub-var")
                  ("  (define* (f x) x)" "f")
                  ("(define-syntax-rule (twice x) (* 2 x))" "twice")
                  ("(define-record-type <ping> (fields (name ping-name)))" "<ping>")
                  ("(define-values (a b) (values 1 2))" "a")
                  ("(greet world)" nil)
                  ("  (greet world)" nil)
                  ("(list (define (greet name) name))" nil)
                  (";; (define (greet name) name)" nil)
                  ("" nil)))
    (should (equal (heks/scheme-definition-name (nth 0 case)) (nth 1 case)))))

(ert-deftest heks/scheme/the-files-answer-with-the-definitions-that-match ()
  "A pattern is answered with the definitions whose name matches it.

One search of the files answers a pattern of any kind, and what makes an
answer is the name the head of the definition defines rather than the line
the search found: a `define' of a name the pattern does not match is not
one.  The entry shows the head itself -- the name, the arguments, the body
-- because that is what one is looking at a list of matches for, and the
name is kept beside it, since the names of the REPL are read against
these."
  (skip-unless (or (executable-find "rg") (executable-find "grep")))
  (let* ((root (file-name-as-directory (heks-ert--temp-directory)))
         (main (expand-file-name "main.scm" root))
         (utility (expand-file-name "utility.scm" root)))
    (unwind-protect
        (progn
          (write-region (concat "(define (main)\n"
                                "  (greet name))\n"
                                "(define-public pub-var 1)\n")
                        nil main nil 'silent)
          (write-region (concat "(define (greet name)\n"
                                "  name)\n"
                                "(define-syntax-rule (greeting name) name)\n")
                        nil utility nil 'silent)
          (heks-ert--in root
            (with-current-buffer (find-file-noselect main)
              (unwind-protect
                  (progn
                    ;; A name, and the names that contain it: a fragment of
                    ;; one is a pattern like any other.
                    (should (equal (mapcar #'car
                                           (heks/scheme-definitions-in-files-matching
                                            "greet"))
                                   '("greet" "greeting")))
                    (should (equal (heks-ert--xref-locations
                                    (mapcar #'cdr
                                            (heks/scheme-definitions-in-files-matching
                                             "greet")))
                                   '(("utility.scm" 1) ("utility.scm" 3))))
                    ;; A pattern of words: all of them, in any order.
                    (should (equal (mapcar #'car
                                           (heks/scheme-definitions-in-files-matching
                                            "var pub"))
                                   '("pub-var")))
                    ;; A regexp, and the head as the line of the entry.
                    (let ((items (mapcar #'cdr
                                         (heks/scheme-definitions-in-files-matching
                                          "^pub-"))))
                      (should (equal (heks-ert--xref-locations items)
                                     '(("main.scm" 3))))
                      (should (equal (xref-item-summary (car items))
                                     "(define-public pub-var 1)"))
                      (should (equal (xref-file-location-column
                                      (xref-item-location (car items)))
                                     15)))
                    ;; A name no head defines is answered with nothing.
                    (should-not (heks/scheme-definitions-in-files-matching
                                 "no-such-name")))
                (set-buffer-modified-p nil)
                (kill-buffer))))
      (delete-directory root t)))))

(ert-deftest heks/scheme/the-repl-answers-with-the-names-it-has-loaded ()
  "The names of the REPL are asked of Guile, and read in Emacs.

What is asked is Guile's own question about the names it has -- the same
one Guile's `apropos' is built on -- named through the module it lives in
rather than imported, because the module a REPL is in is `(guile-user)' or
a project's own.  What comes back is read against the pattern here, so
that a question which is wider than the answer -- the first word of a list
of words, say -- still answers with the pattern's own names."
  (let ((asked nil)
        (names '("string-append" "string-append/shared" "string-copy")))
    (cl-letf (((symbol-function 'heks/scheme-repl-connected-p) (lambda () t))
              ((symbol-function 'geiser-eval--send/result)
               (lambda (question) (setq asked question) names)))
      (should (equal (heks/scheme--repl-names "string-append")
                     '("string-append" "string-append/shared")))
      (should (equal (cadr (nth 1 asked))
                     (concat "(sort (map symbol->string ((@ (ice-9 session) "
                             "apropos-internal) \"string-append\")) string<?)")))
      ;; A list of words is asked for by its first word, and the names are
      ;; read against all of them.
      (setq names '("pub-var" "public-name" "var-pub"))
      (should (equal (heks/scheme--repl-names "pub var")
                     '("pub-var" "var-pub")))
      (should (equal (cadr (nth 1 asked))
                     (concat "(sort (map symbol->string ((@ (ice-9 session) "
                             "apropos-internal) \"pub\")) string<?)"))))))

(ert-deftest heks/scheme/apropos-is-answered-by-both-sources-once-each ()
  "`M-s .' in a Scheme buffer is answered by the files and by the REPL.

The files' answer comes first, with the place each definition is in, and
the names the REPL has that no definition answered for follow it as names;
a name both sources have is one entry, because the files know where it is
and the REPL knows only that it has it."
  (cl-letf (((symbol-function 'heks/scheme-definitions-in-files-matching)
             (lambda (_pattern)
               (list (cons "greet"
                           (xref-make "(define (greet name)"
                                      (xref-make-file-location
                                       "/tmp/heks-greet.scm" 1 9))))))
            ((symbol-function 'heks/scheme--repl-names)
             (lambda (_pattern) '("greet" "greeting" "string-append"))))
    (let ((items (xref-backend-apropos 'heks/scheme "greet")))
      (should (equal (mapcar #'xref-item-summary items)
                     '("(define (greet name)" "greeting" "string-append")))
      (should (equal (mapcar (lambda (item)
                               (xref-location-group (xref-item-location item)))
                             items)
                     '("/tmp/heks-greet.scm" "the REPL" "the REPL"))))))

(ert-deftest heks/scheme/a-name-the-repl-knows-asks-it-where-it-is-when-jumped-to ()
  "What the REPL knows of one of its names is asked when the name is jumped to.

The names a program has loaded are many and their files are files the
project does not hold, so a name of the REPL's arrives as the name alone
and the question of where it is is asked of the one that is chosen -- the
same question `M-.' asks.  A name the REPL has no place for is a jump that
says so rather than one that lands wherever the name was searched for."
  (let* ((root (file-name-as-directory (heks-ert--temp-directory)))
         (file (expand-file-name "greet.scm" root))
         (asked '()))
    (unwind-protect
        (progn
          (write-region "(define (greet name)\n  name)\n" nil file nil 'silent)
          (cl-letf (((symbol-function 'heks/scheme--repl-definition)
                     (lambda (name)
                       (push name asked)
                       (when (equal name "greet")
                         (list (xref-make "greet"
                                          (xref-make-file-location file 1 0)))))))
            (let ((location (heks/scheme--repl-name "greet")))
              ;; The name is all there is until it is jumped to.
              (should-not asked)
              (let ((marker (xref-location-marker location)))
                (should (equal asked '("greet")))
                (should (equal (buffer-file-name (marker-buffer marker)) file))
                (with-current-buffer (marker-buffer marker)
                  (should (equal (line-number-at-pos marker) 1))
                  (set-buffer-modified-p nil)
                  (kill-buffer)))
              (should-error (xref-location-marker
                             (heks/scheme--repl-name "no-such-name"))
                            :type 'user-error)))
      (delete-directory root t)))))

(ert-deftest heks/scheme/the-places-a-name-is-used-are-found-in-the-files ()
  "`M-?' is answered by the files where the REPL has no callers.

Every file that mentions the name is offered -- the call, the definition
and the other call -- with the file being read first, and a name nothing
mentions has no places."
  (skip-unless (or (executable-find "rg") (executable-find "grep")))
  (let* ((root (file-name-as-directory (heks-ert--temp-directory)))
         (main (expand-file-name "main.scm" root))
         (utility (expand-file-name "utility.scm" root)))
    (unwind-protect
        (progn
          (write-region (concat "(define (main)\n"
                                "  (greet name))\n"
                                "(define (greeting) (greet\"hi\"))\n")
                        nil main nil 'silent)
          (write-region (concat "(define (greet name)\n"
                                "  name)\n")
                        nil utility nil 'silent)
          (heks-ert--in root
            (with-current-buffer (find-file-noselect main)
              (unwind-protect
                  (progn
                    (should (equal (heks-ert--xref-locations
                                    (heks/scheme-mentions-in-files "greet"))
                                   '(("main.scm" 2) ("main.scm" 3) ("utility.scm" 1))))
                    (should-not (heks/scheme-mentions-in-files "no-such-name")))
                (set-buffer-modified-p nil)
                (kill-buffer))))
      (delete-directory root t)))))

(ert-deftest heks/scheme/no-repl-is-a-question-the-repl-answers-with-nil ()
  "A buffer with no REPL says so rather than starting one."
  (cl-letf (((symbol-function 'heks/scheme-repl-connected-p) (lambda () nil))
            ((symbol-function 'geiser-edit-symbol-location)
             (lambda (_) (error "The REPL was asked although there is none")))
            ((symbol-function 'geiser-eval--send/result)
             (lambda (_) (error "The REPL was asked although there is none"))))
    (should-not (heks/scheme--repl-definition "greet"))
    (should-not (heks/scheme--repl-callers "greet"))
    (should-not (heks/scheme--repl-names "greet"))
    (should-not (heks/scheme-repl-connected-p))))

;;
;; ====== Importing a Markdown document ======
;;

(defconst heks-ert-import-document
  (concat "---\n"
          "title: A note\n"
          "tags:\n"
          "  - emacs\n"
          "  - org mode\n"
          "aliases: [Things, stuff]\n"
          "author: Josep\n"
          "permalink: /notes/a\n"
          "---\n"
          "\n"
          "# A note\n"
          "\n"
          "Some *emphasis*, some **strong**, some `code` and a [link](docs/a.md).\n"
          "\n"
          "## Why\n"
          "\n"
          "- first\n"
          "  - nested\n"
          "\n"
          "```scheme\n"
          "(display \"* not a headline\")\n"
          "```\n"
          "\n"
          "| Name | Count |\n"
          "|:-----|------:|\n"
          "| a | 1 |\n"
          "\n"
          "A foot[^1].\n"
          "\n"
          "[^1]: The note.\n")
  "A document with the parts of Markdown an import has to have an answer for.")

(ert-deftest heks/import/the-heading-a-document-names-itself-with-is-its-title ()
  "The `# ...' a document opens with names the note, and is not repeated under it."
  (let ((metadata (heks/markdown-metadata "# Heks\n\ntext\n")))
    (should (equal (plist-get metadata :title) "Heks"))
    (should (equal (string-trim (plist-get metadata :body)) "text"))))

(ert-deftest heks/import/a-title-can-be-left-as-a-heading ()
  "With the setting off, every heading stays a heading."
  (let ((heks/import-title-from-heading nil))
    (should (equal (heks/markdown-to-org "# Heks\n\ntext\n")
                   "* Heks\n\ntext\n"))))

(ert-deftest heks/import/front-matter-is-what-the-note-says-about-itself ()
  "Title, tags, aliases and the fields this does not name are all kept."
  (let ((org (heks/markdown-to-org heks-ert-import-document
                                        '(("ID" . "an-id")
                                          ("ALIASES" . "Things, stuff")))))
    (should (string-match-p "^#\\+title: A note$" org))
    (should (string-match-p "^#\\+filetags: :emacs:org_mode:$" org))
    (should (string-match-p "^#\\+author: Josep$" org))
    ;; A field this module knows nothing about is a keyword of its own name
    ;; rather than something dropped on the floor.
    (should (string-match-p "^#\\+permalink: /notes/a$" org))
    (should (string-match-p "^ *:ID: *an-id$" org))
    (should (string-match-p "^ *:ALIASES: *Things, stuff$" org))
    ;; The drawer comes first, then the keywords, then the body: a drawer
    ;; Org reads as the file's properties is the first thing in the file
    ;; (`org-entry-get' finds the id there, and finds nothing when the
    ;; keywords come first), and the keywords belong to the note rather
    ;; than to the first section under it.
    (should (< (string-match ":PROPERTIES:" org) (string-match "#\\+title:" org)))
    (should (< (string-match ":END:" org) (string-match "^\\* Why$" org)))))

(ert-deftest heks/import/the-hierarchy-of-a-document-is-the-hierarchy-of-a-note ()
  "The headings left under the title are shifted up to be its sections."
  (let ((org (heks/markdown-to-org "# Title\n\n## One\n\n### Two\n\n#### Three\n")))
    (should (string-match-p "^\\* One$" org))
    (should (string-match-p "^\\*\\* Two$" org))
    (should (string-match-p "^\\*\\*\\* Three$" org))))

(ert-deftest heks/import/nothing-is-shifted-when-there-is-no-title ()
  "A document that names itself nowhere keeps its own depth."
  (let ((org (heks/markdown-to-org "## One\n\ntext\n")))
    (should (string-match-p "^\\* One$" org))))

(ert-deftest heks/import/a-block-that-says-it-is-not-a-heading-is-not-shifted ()
  "A line of a code block is a line of a code block, whatever it starts with."
  (let ((org (heks/markdown-to-org
              (concat "# Title\n\n```sh\n* not a headline\n** neither\n```\n"
                      "\n## Section\n"))))
    (should (string-match-p "^\\* not a headline$" org))
    (should (string-match-p "^\\*\\* neither$" org))
    (should (string-match-p "^\\* Section$" org))))

(ert-deftest heks/import/emphasis-links-and-images-become-org-markup ()
  "What Markdown says with markers, Org says with its own."
  (let ((org (heks/markdown-to-org
              (concat "*emphasis*, **strong**, `code`, ~~gone~~, a [link](a.md)\n"
                      "an ![image](b.png), <https://example.com/x> and a foot[^2].\n"
                      "\n[^2]: a note\n"))))
    (should (string-match-p
             "^/emphasis/, \\*strong\\*, =code=, \\+gone\\+, a \\[\\[a.md\\]\\[link\\]\\]$"
             org))
    (should (string-match-p
             "^an \\[\\[b.png\\]\\[image\\]\\], \\[\\[https://example.com/x\\]\\] and a foot\\[fn:2\\]\\.$"
             org))
    (should (string-match-p "^\\[fn:2\\] a note$" org))))

(ert-deftest heks/import/a-link-in-a-document-becomes-the-file-it-names ()
  "A relative link is resolved against the document's own directory."
  (let ((heks/markdown-base-directory "/home/someone/docs/"))
    (should (string-match-p "\\[\\[/home/someone/docs/img/a.png\\]\\[d\\]\\]"
                            (heks/markdown-to-org "![d](img/a.png)\n")))
    (should (string-match-p "\\[\\[https://example.com/x\\]\\[a\\]\\]"
                            (heks/markdown-to-org "[a](https://example.com/x)\n")))))

(ert-deftest heks/import/a-table-becomes-a-table-org-can-align ()
  "The columns keep the alignment their delimiter row gave them, and the
header row stays a header row."
  (let ((org (heks/markdown-to-org
              "| Name | Count |\n|:-----|------:|\n| a | 1 |\n")))
    ;; The delimiter row is what tells Org where the header ends, so it is
    ;; written as well as the alignment row rather than only as one, and a
    ;; row is padded to the column it is in, so that the rule under the
    ;; header is the width of what it rules.
    (should (equal org (concat "| Name | Count |\n"
                               "| <l>  | <r>   |\n"
                               "|------+-------|\n"
                               "| a    | 1     |\n")))))

(ert-deftest heks/import/a-checked-box-is-the-box-org-reads ()
  "Markdown checks a box with `[x]' and Org reads `[X]': the box is written
as the one Org reads, so that what was done stays done."
  (let ((org (heks/markdown-to-org
              "- [ ] one\n- [x] two\n- [X] three\n- [ ]done without a space\n")))
    (should (equal org (concat "- [ ] one\n"
                               "- [X] two\n"
                               "- [X] three\n"
                               ;; Not a box Org reads either, so it is left
                               ;; as the text a document made of it.
                               "- [ ]done without a space\n")))))

(ert-deftest heks/import/a-bullet-is-never-written-as-a-headline ()
  "Markdown's `*' bullet is Org's `-', which is what a headline is not."
  (should (equal (heks/markdown-to-org "* one\n* two\n")
                 "- one\n- two\n")))

(ert-deftest heks/import/the-blank-lines-a-document-has-separate-its-blocks ()
  "In Org a blank line decides what a block ends, so the import keeps them."
  (let ((org (heks/markdown-to-org "text\n\nmore text\n")))
    (should (equal org "text\n\nmore text\n"))))

(ert-deftest heks/import/a-fragment-keeps-its-headings-where-they-are ()
  "A piece of a document is not a note: no title is made of it, no heading moves."
  (should (equal (heks/markdown-fragment-to-org "# One\n\n## Two\n\ntext\n")
                 "* One\n\n** Two\n\ntext")))

(ert-deftest heks/import/a-fragment-says-things-the-way-a-note-does ()
  "Emphasis, code, links, lists and fences are spelled as they are in a note."
  (let ((org (heks/markdown-fragment-to-org
              (concat "Some **bold** and `code` and [a](https://example.com/x).\n"
                      "\n"
                      "* one\n"
                      "* two\n"
                      "\n"
                      "```elisp\n(+ 1 2)\n```\n"))))
    (should (string-match-p "\\*bold\\*" org))
    (should (string-match-p "~code~\\|=code=" org))
    (should (string-match-p "\\[\\[https://example.com/x\\]\\[a\\]\\]" org))
    (should (string-match-p "^- one\n- two$" org))
    (should (string-match-p "#\\+begin_src elisp" org))
    (should-not (string-match-p "^#\\+title" org))
    (should-not (string-match-p ":PROPERTIES:" org))))

(ert-deftest heks/import/the-region-is-replaced-by-what-it-says-in-org ()
  "Only the region changes, and a region that ended a line still ends one."
  (with-temp-buffer
    (insert "before\n## Two\n\n* one\n* two\nafter\n")
    (let ((beg (save-excursion (goto-char (point-min)) (forward-line 1) (point)))
          (end (save-excursion (goto-char (point-max)) (forward-line -1) (point))))
      (heks/markdown-region-to-org beg end)
      (should (equal (buffer-string)
                     "before\n** Two\n\n- one\n- two\nafter\n")))))

(ert-deftest heks/import/a-region-without-a-final-newline-gets-none ()
  "What the region did not end with it is not given."
  (with-temp-buffer
    (insert "see **this**")
    (heks/markdown-region-to-org (point-min) (point-max))
    (should (equal (buffer-string) "see *this*"))))

(ert-deftest heks/import/a-prefix-argument-copies-and-leaves-the-buffer-alone ()
  "With a prefix, the Org goes on the kill ring and the Markdown stays."
  (with-temp-buffer
    (insert "## Two\n")
    (let ((kill-ring nil))
      (heks/markdown-region-to-org (point-min) (point-max) t)
      (should (equal (buffer-string) "## Two\n"))
      (should (equal (car kill-ring) "** Two\n")))))

(ert-deftest heks/import/a-buffer-that-cannot-be-written-to-is-copied-from ()
  "A read-only buffer -- a chat, a help buffer -- is the place Markdown comes from."
  (with-temp-buffer
    (insert "## Two\n")
    (setq buffer-read-only t)
    (let ((kill-ring nil))
      (heks/markdown-region-to-org (point-min) (point-max))
      (should (equal (buffer-string) "## Two\n"))
      (should (equal (car kill-ring) "** Two\n")))))

(ert-deftest heks/import/an-identifier-is-a-uuid ()
  "A note is named the way `org-id' names one."
  (let ((id (heks/import--id)))
    (should (string-match-p
             "\\`[0-9a-f]\\{8\\}-[0-9a-f]\\{4\\}-4[0-9a-f]\\{3\\}-[89ab][0-9a-f]\\{3\\}-[0-9a-f]\\{12\\}\\'"
             id))
    (should-not (equal id (heks/import--id)))))

(ert-deftest heks/import/a-file-is-imported-next-to-the-source ()
  "The Org is written beside the Markdown, and the Markdown is left alone."
  (let ((root (heks-ert--temp-directory)))
    (unwind-protect
        (let ((source (expand-file-name "README.md" root)))
          (write-region heks-ert-import-document nil source nil 'silent)
          (should (equal (heks/import-markdown-file source)
                         (expand-file-name "README.org" root)))
          (should (file-exists-p (expand-file-name "README.org" root)))
          (should (equal (with-temp-buffer (insert-file-contents source) (buffer-string))
                         heks-ert-import-document))
          ;; The same document again writes the same file, silently.
          (should (equal (heks/import-markdown-file source)
                         (expand-file-name "README.org" root))))
      (delete-directory root t))))

(ert-deftest heks/import/a-note-somebody-wrote-is-not-written-over-unasked ()
  "A file that is already there and differs is kept unless the reader says otherwise."
  (let ((root (heks-ert--temp-directory)))
    (unwind-protect
        (let ((source (expand-file-name "README.md" root))
              (target (expand-file-name "README.org" root)))
          (write-region "# Heks\n" nil source nil 'silent)
          (write-region "my own note\n" nil target nil 'silent)
          (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil)))
            (should-not (heks/import-markdown-file source)))
          (should (equal (with-temp-buffer (insert-file-contents target) (buffer-string))
                         "my own note\n"))
          (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
            (should (heks/import-markdown-file source)))
          (should (string-match-p "^#\\+title: Heks$"
                                  (with-temp-buffer (insert-file-contents target)
                                                    (buffer-string)))))
      (delete-directory root t))))

(ert-deftest heks/import/a-note-imported-into-the-notes-is-a-node ()
  "It carries an identifier and its aliases, and a second import keeps them."
  (let ((root (heks-ert--temp-directory))
        (notes (make-temp-file "heks-ert-notes-" t)))
    (unwind-protect
        (let ((source (expand-file-name "note.md" root)))
          (write-region heks-ert-import-document nil source nil 'silent)
          (cl-letf (((symbol-function 'heks/notes-directory)
                     (lambda () (file-name-as-directory notes))))
            (let* ((target (heks/import-markdown-file source t))
                   (text (with-temp-buffer (insert-file-contents target) (buffer-string)))
                   (id (and (string-match ":ID: *\\([^ \t\n]+\\)" text)
                            (match-string 1 text))))
              (should (equal target (expand-file-name "note.org" notes)))
              (should (string-match-p "^ *:ALIASES: *Things, stuff$" text))
              (should id)
              ;; Importing it again updates the note rather than making a
              ;; second node, which is what keeping the identifier does.
              (heks/import-markdown-file source t)
              (let ((again (with-temp-buffer (insert-file-contents target)
                                             (buffer-string))))
                (should (string-match ":ID: *\\([^ \t\n]+\\)" again))
                (should (equal id (match-string 1 again)))))))
      (delete-directory root t)
      (delete-directory notes t))))

(ert-deftest heks/import/the-project-import-asks-once-and-imports-the-markdown ()
  "Every Markdown file the project has is imported, and nothing else is."
  (let ((root (heks-ert--temp-directory))
        (asked 0))
    (unwind-protect
        (let ((one (expand-file-name "README.md" root))
              (two (expand-file-name "guide.markdown" root))
              (other (expand-file-name "notes.org" root)))
          (write-region "# One\n" nil one nil 'silent)
          (write-region "# Two\n" nil two nil 'silent)
          (write-region "* not markdown\n" nil other nil 'silent)
          (cl-letf (((symbol-function 'project-current) (lambda (&optional _) 'a-project))
                    ((symbol-function 'project-files) (lambda (&optional _) (list one two other)))
                    ((symbol-function 'yes-or-no-p) (lambda (&rest _) (setq asked (1+ asked)) t)))
            (heks/import-markdown-project))
          (should (file-exists-p (expand-file-name "README.org" root)))
          (should (file-exists-p (expand-file-name "guide.org" root)))
          (should (= asked 0)))
      (delete-directory root t))))

(ert-deftest heks/import/a-document-is-what-its-name-says-it-is ()
  "The names a Markdown document is written with, and the ones it is not."
  (should (heks/import-markdown-p "README.md"))
  (should (heks/import-markdown-p "guide.markdown"))
  (should (heks/import-markdown-p "NOTES.MD"))
  (should-not (heks/import-markdown-p "notes.org"))
  (should-not (heks/import-markdown-p "notes.md.org")))

(ert-deftest heks/scheme/an-evaluation-brings-up-the-repl-it-needs ()
  "Evaluating with no REPL starts the project's one; with one, it does not."
  (let ((started 0)
        (evaluated 0))
    (cl-letf (((symbol-function 'heks/scheme-repl-connected-p)
               (lambda () (>= started 1)))
              ((symbol-function 'heks/scheme-repl--start)
               (lambda () (setq started (1+ started))))
              ((symbol-function 'geiser-eval-definition)
               (lambda (_) (setq evaluated (1+ evaluated)))))
      (heks/scheme-repl-needed (lambda () (geiser-eval-definition nil)))
      (should (= started 1))
      (should (= evaluated 1))
      (heks/scheme-repl-needed (lambda () (geiser-eval-definition nil)))
      (should (= started 1))
      (should (= evaluated 2)))))

(ert-deftest heks/scheme/a-repl-that-will-not-come-up-is-said-so ()
  "A machine where the program is missing is told that rather than left waiting."
  (cl-letf (((symbol-function 'heks/scheme-repl-connected-p) (lambda () nil))
            ((symbol-function 'heks/scheme-repl--start) (lambda () nil))
            ((symbol-function 'accept-process-output) (lambda (&rest _) nil)))
    (should-error (heks/scheme-repl-needed (lambda () nil)) :type 'user-error)))

;;
;; ====== Dired ======
;;

(ert-deftest heks/dired/the-contents-of-the-marked-files-are-copied ()
  (let ((root (heks-ert--temp-directory)))
    (unwind-protect
        (progn
          (write-region "first\n" nil (expand-file-name "a.txt" root) nil 'silent)
          (write-region "second\n" nil (expand-file-name "b.txt" root) nil 'silent)
          (dired root)
          (dired-mark-files-regexp "\\.txt\\'")
          (heks/dired-copy-marked-files-content)
          (let ((copied (current-kill 0)))
            (should (string-match-p "=== FILE: a.txt ===" copied))
            (should (string-match-p "first" copied))
            (should (string-match-p "=== FILE: b.txt ===" copied))
            (should (string-match-p "second" copied)))
          (kill-buffer (current-buffer)))
      (delete-directory root t))))

;;
;; ====== The key scheme's own tables ======
;;
;; The audit in `test/heks-emacs-keys.el' reads these tables out of the
;; source and judges the configuration with them; what is checked here is
;; the shape they are read as, which a report of no problems would not
;; notice being wrong.

(ert-deftest heks/keys/every-topic-letter-is-a-key-and-means-one-thing ()
  (let (seen)
    (dolist (topic heks/key-topics)
      (should (stringp (car topic)))
      (should (stringp (cdr topic)))
      (should (not (string-empty-p (cdr topic))))
      ;; A topic has to be a key sequence Emacs can read.
      (should (kbd (concat "C-c " (car topic))))
      (should-not (member (car topic) seen))
      (push (car topic) seen))))

(ert-deftest heks/keys/the-action-alphabet-has-no-duplicates ()
  (let (seen)
    (dolist (action heks/key-actions)
      (should (stringp (cdr action)))
      (should-not (member (car action) seen))
      (push (car action) seen))))

(ert-deftest heks/keys/every-key-is-described-once ()
  (let (seen)
    (dolist (entry heks/key-descriptions)
      (should (string-prefix-p "C-c " (car entry)))
      (should (stringp (cdr entry)))
      (should (not (string-empty-p (cdr entry))))
      (should-not (member (car entry) seen))
      (push (car entry) seen))))

(ert-deftest heks/keys/a-topic-letters-are-letters ()
  (dolist (topic heks/key-letters)
    (should (assoc (car topic) heks/key-topics #'equal))
    (dolist (letter (cdr topic))
      (should (string-match-p "\\`[[:alpha:]]\\'" (car letter)))
      (should (stringp (cdr letter))))))

(ert-deftest heks/keys/a-description-is-found-for-what-the-tables-hold ()
  "The lookup the reference and `which-key' both read is one function."
  (should (equal (heks/key-description "C-c i f")
                 "the buffer, formatted by whoever knows how"))
  ;; A topic's own letter, when the key has no description of its own.
  (should (equal (heks/key-description "C-c f t") "tiny"))
  ;; An action letter, under a topic that says nothing of its own about it.
  (should (equal (heks/key-description "C-c s c")
                 "the snippet at point, completed"))
  ;; A key whose last stroke is not a letter is what its topic is for.
  (should (equal (heks/key-description "C-c C-d z")
                 "diagrams: Mermaid")))

;;
;; ====== The tree-sitter grammars ======
;;

(ert-deftest heks/treesit/the-grammars-are-built-by-a-batch-emacs ()
  "The grammars are built by a child Emacs that is handed what it needs.

The child is a batch Emacs and nothing else -- no configuration to load, no
packages to install first -- so the directory, the recipes this
configuration names itself and the directories a grammar may already be in
are given to it as Lisp it is told before the script is loaded."
  (let* ((command (heks/treesit--batch-command))
         (form (read (nth 4 command))))
    (should (equal (nth 1 command) "-Q"))
    (should (equal (nth 2 command) "--batch"))
    (should (equal (nth 3 command) "--eval"))
    (should (equal (nth 5 command) "-l"))
    (should (equal (nth 6 command) heks/treesit-script))
    (should (eq (car form) 'setq))
    (should (equal (nth 1 form) 'heks/treesit-grammar-directory))
    (should (equal (nth 2 form) heks/treesit-grammar-directory))
    (should (equal (nth 3 form) 'heks/treesit-own-recipes))
    (should (equal (nth 5 form) 'treesit-extra-load-path))))

(ert-deftest heks/treesit/the-grammars-are-installed-where-told-to ()
  "The directory is the one this configuration installs and looks in."
  (should (equal (file-name-nondirectory
                  (directory-file-name heks/treesit-grammar-directory))
                 "tree-sitter"))
  (should (string-prefix-p (file-name-as-directory (expand-file-name "~/.emacs.d"))
                           (file-name-as-directory
                            heks/treesit-grammar-directory))))

(ert-deftest heks/treesit/the-script-builds-the-grammars-emacs-knows ()
  "The script asks for the grammar of every mode Emacs ships, and for ours.

It is loaded here with the installing stubbed out -- nothing in a test has a
network -- and with every grammar reported as missing, so what it would
build is what is checked: Emacs's own recipes come from its own mode files,
which is why the languages Emacs has modes for are in the answer at all."
  (let ((asked nil)
        (heks/treesit-grammar-directory "/tmp/heks-ert-grammars")
        (heks/treesit-own-recipes '((heks-ert-own "https://example.com/own"))))
    (cl-letf (((symbol-function 'treesit-language-available-p)
               (lambda (&rest _) nil))
              ((symbol-function 'treesit-install-language-grammar)
               (lambda (language &optional directory)
                 (push (cons language directory) asked))))
      (load (expand-file-name "treesit-grammars" heks-ert--source) nil t))
    (dolist (language '(java python typescript tsx c-sharp go heks-ert-own))
      (should (assq language asked)))
    ;; Every language of every tree-sitter mode this Emacs ships, and the
    ;; three languages it ships no mode for, are asked for together.
    (should (> (length asked) 25))
    (dolist (entry asked)
      (should (equal (cdr entry) "/tmp/heks-ert-grammars")))))

(ert-deftest heks/treesit/a-grammar-that-is-here-is-not-built-again ()
  "What is installed is not cloned and compiled a second time."
  (let ((asked nil)
        (heks/treesit-grammar-directory "/tmp/heks-ert-grammars"))
    (cl-letf (((symbol-function 'treesit-language-available-p)
               (lambda (language &rest _) (eq language 'java)))
              ((symbol-function 'treesit-install-language-grammar)
               (lambda (language &optional _directory) (push language asked))))
      (load (expand-file-name "treesit-grammars" heks-ert--source) nil t))
    (should-not (memq 'java asked))
    (should (memq 'python asked))))

(ert-deftest heks/treesit/a-grammar-that-fails-once-is-built-on-the-second-try ()
  "A clone that timed out, or a checkout that was busy, is not a verdict.

What is reported is a grammar that would not build twice, so a language
that fails and then works is built, in the same run, and said to have
taken a second attempt rather than reported as one this machine cannot
build."
  (let ((attempts 0)
        (built nil)
        (heks/treesit-grammar-directory "/tmp/heks-ert-grammars"))
    (cl-letf (((symbol-function 'treesit-language-available-p)
               (lambda (&rest _) built))
              ((symbol-function 'treesit-install-language-grammar)
               ;; The first attempt fails the way a network does, and the
               ;; one after it builds.
               (lambda (&rest _)
                 (setq attempts (1+ attempts))
                 (if (= attempts 1)
                     (error "the clone timed out")
                   (setq built t)))))
      (load (expand-file-name "treesit-grammars" heks-ert--source) nil t))
    ;; The grammar that failed was tried again, and the one that arrived
    ;; was not built a third time: the rest of the languages were already
    ;; here, because the retry made the library loadable.
    (should (equal attempts heks/treesit-attempts))))

(ert-deftest heks/treesit/a-build-that-produces-nothing-is-not-a-grammar ()
  "A build that returns for a library that cannot be loaded is a failure.

Emacs warns rather than errors when the library it built cannot be found or
loaded, so counting the return of the build as success would report a
grammar as built that no mode can use -- and would leave it unbuilt for
ever, since the next run would find it missing and try again from scratch."
  (let ((asked nil)
        (heks/treesit-grammar-directory "/tmp/heks-ert-grammars"))
    (cl-letf (((symbol-function 'treesit-language-available-p)
               (lambda (&rest _) nil))
              ((symbol-function 'treesit-install-language-grammar)
               (lambda (language &optional _directory) (push language asked))))
      (load (expand-file-name "treesit-grammars" heks-ert--source) nil t))
    ;; Every language was missing and none arrived, so each was tried twice
    ;; -- and no language more than that, whatever it said about itself.
    (should (> (length asked) 25))
    (dolist (language (delete-dups (copy-sequence asked)))
      (should (equal (seq-count (lambda (one) (eq one language)) asked)
                     heks/treesit-attempts)))))

(ert-deftest heks/treesit/a-grammar-that-will-not-build-does-not-stop-the-others ()
  "One language failing is a line of output, not the end of the run."
  (let ((asked nil)
        (heks/treesit-grammar-directory "/tmp/heks-ert-grammars"))
    (cl-letf (((symbol-function 'treesit-language-available-p)
               (lambda (&rest _) nil))
              ((symbol-function 'treesit-install-language-grammar)
               (lambda (language &optional _directory)
                 (push language asked)
                 (when (eq language 'java) (error "no compiler here")))))
      (load (expand-file-name "treesit-grammars" heks-ert--source) nil t))
    ;; java was given both of its attempts before anything was said about
    ;; it, and the languages after it were built all the same.
    (should (equal (seq-count (lambda (language) (eq language 'java)) asked)
                   heks/treesit-attempts))
    (should (memq 'python asked))
    (should (memq 'cpp asked))))

(ert-deftest heks/which-key/the-scheme-is-what-which-key-shows ()
  (skip-unless (and (featurep 'which-key) (fboundp 'heks/which-key-setup)))
  (let ((before (length which-key-replacement-alist)))
    (heks/which-key-setup)
    (cl-flet ((shown (key)
                     (let ((entry (seq-find (lambda (candidate)
                                              (equal (car (car candidate))
                                                     (concat "\\`" (regexp-quote key) "\\'")))
                                            which-key-replacement-alist)))
                       (cdr (cdr entry)))))
      ;; A topic prefix is named by the topic.
      (should (equal (shown "C-c i") "IDE: language server, formatting, diagnostics"))
      ;; A key is named by what it does there.
      (should (equal (shown "C-c i f") "the buffer, formatted by whoever knows how"))
      (should (equal (shown "C-c w i") "the providers and state, initialised"))
      ;; And `C-c' itself says what the letters under it are.
      (should (string-match-p "topic" (shown "C-c"))))
    (should (> (length which-key-replacement-alist) before))))

(ert-deftest heks/which-key/a-mode-that-answers-first-says-its-own-wording ()
  "A key a mode owns is described for that mode, in the mode's own words."
  (skip-unless (and (featurep 'which-key) (fboundp 'heks/which-key-setup)))
  (heks/which-key-setup)
  ;; A mode's own table is keyed by the pattern `which-key' stores, not by
  ;; the key: the pattern is what it matches a key being typed against.
  (let* ((replacements (cdr (assq 'java-mode which-key-replacement-alist)))
         (described (cddr (seq-find (lambda (entry)
                                      (string-match-p (regexp-quote "C-c j t")
                                                      (car (car entry))))
                                    replacements))))
    (should replacements)
    (should (equal described "the test at point, through the language server"))))

(ert-deftest heks/which-key/no-sentence-of-the-scheme-is-cut ()
  "The length which-key is told fits every description the scheme gives a key.

`which-key' cuts a description longer than that with `which-key-ellipsis',
and a sentence with its end cut off is not a sentence: at the length this
replaced, `+go to: a definition, an implementation, a location' was shown
as `+go to: a definition, an implementation, a ..'.  Every description is
tried with the `+' of `which-key-prefix-prefix' in front of it, because
that is the character which-key puts in front of a key that opens a keymap
and counts when it cuts.  The cutting is `which-key's own, so the setting
is held to which-key's behaviour rather than to a copy of it, and the
description of `C-c' itself is checked to be among the ones measured -- it
was not when the length was a round number, and it is the longest of them."
  (skip-unless (and (featurep 'which-key) (fboundp 'which-key--truncate-description)))
  (let ((which-key-max-description-length heks/which-key-description-length)
        (cut '()))
    (dolist (text (heks/key-description-texts))
      (let ((cell (concat which-key-prefix-prefix text)))
        (unless (equal (which-key--truncate-description cell 80) cell)
          (push text cut))))
    (should (equal cut '())))
  (should (member heks/key-root-description (heks/key-description-texts))))

(ert-deftest heks/which-key/the-menu-goes-where-the-frame-has-room ()
  "The bottom window needs twice the smallest a frame's window may be.

`which-key' makes the window it shows the menu in by splitting the frame's
main window in two and keeping one half, and it asks `split-window' for
that with `split-window-no-error', whose nil answer it does not read -- so
when the split is refused, the menu is written into `which-key's buffer and
nobody sees it.  `heks/which-key-side-window-p' is the rule that
decides the place instead, and the rule is checked here against
`split-window-no-error' itself: what the predicate answers and what the
split does are the same question, so a change in Emacs's own rule is a
failing test rather than a menu that disappears again."
  (skip-unless (and (featurep 'which-key)
                    (fboundp 'heks/which-key-side-window-p)))
  (let ((configuration (current-window-configuration))
        (min-height window-min-height)
        ;; A refused split is an error `split-window-no-error' is meant to
        ;; swallow, and `ert' stops at every error it is told about.
        (debug-on-error nil))
    (unwind-protect
        (progn
          ;; One window: room for the menu, and the place is the window.
          (delete-other-windows)
          (should (heks/which-key-side-window-p))
          (should (windowp (split-window-no-error (frame-root-window) nil 'below)))
          (heks/which-key-popup-dimensions 80)
          (should-not heks/which-key-echoing)
          (delete-other-windows)
          ;; Windows which are too small to be split in two: no room, and the
          ;; menu is asked for in the echo area, with one line less than the
          ;; echo area has -- the line which-key says about the menu is not
          ;; part of the page but is shown with it.
          (dotimes (_ 2) (split-window-no-error (selected-window) nil 'below))
          (setq window-min-height 5)
          (should-not (heks/which-key-side-window-p))
          (should-not (split-window-no-error (frame-root-window) nil 'below))
          (heks/which-key-popup-dimensions 80)
          (should heks/which-key-echoing)
          (should (equal (car (heks/which-key-popup-dimensions 80))
                         (1- (car (which-key--minibuffer-max-dimensions))))))
      (setq window-min-height min-height)
      (set-window-configuration configuration))))

;;
;; ====== The family a face is given ======
;;

(ert-deftest heks/ui/an-eca-face-gets-the-family-of-what-it-prints ()
  "A chat is read, and what a reader copies out of it is not."
  (let ((given nil))
    (cl-letf (((symbol-function 'heks/set-face)
               (lambda (face &rest attributes)
                 (push (cons face attributes) given))))
      (heks/set-eca-faces))
    (should (equal (length given)
                   (+ (length heks/eca-sans-faces)
                      (length heks/eca-mono-faces))))
    (should (equal (cdr (assq 'eca-chat-title-face given))
                   (list :font heks/font-sans)))
    (should (equal (cdr (assq 'eca-chat-tool-call-accept-face given))
                   (list :font heks/font-sans)))
    (should (equal (cdr (assq 'eca-chat-file-path-face given))
                   (list :font heks/font-mono)))
    (should (equal (cdr (assq 'eca-chat-shell-command-face given))
                   (list :font heks/font-mono)))))

(ert-deftest heks/ui/no-eca-face-is-in-both-lists ()
  "A face in both lists would be given whichever family came last."
  (should-not (cl-intersection heks/eca-sans-faces
                               heks/eca-mono-faces))
  (should (cl-every #'symbolp (append heks/eca-sans-faces
                                      heks/eca-mono-faces))))

(ert-deftest heks/ui/a-face-that-is-not-there-yet-is-skipped ()
  "ECA defines its faces when it is loaded, which is after this module runs."
  (should-not (facep 'heks/no-such-face))
  (heks/set-face 'heks/no-such-face :font heks/font-sans)
  (should-not (facep 'heks/no-such-face)))

;;
;; ====== Which AI account this session is for ======
;;

(defun heks-ert--call-with-environment (variables function)
  "Call FUNCTION with the environment VARIABLES set, an alist of name to value.

A value of nil unsets the variable, and every one of them is put back the
way it was afterwards: a test that sets a key cannot leak it into the ones
that follow, and the suite does not depend on what the shell it runs in
exports."
  (let ((saved (mapcar (lambda (pair) (cons (car pair) (getenv (car pair))))
                       variables)))
    (unwind-protect
        (progn
          (dolist (pair variables) (setenv (car pair) (cdr pair)))
          (funcall function))
      (dolist (pair saved) (setenv (car pair) (cdr pair))))))

(ert-deftest heks/ai/the-key-in-the-environment-is-the-personal-account ()
  "Exporting the DeepSeek key is what makes an Emacs the personal one."
  (heks-ert--call-with-environment
   '(("HEKS_AI_PROVIDER" . nil) ("DEEPSEEK_API_KEY" . "sk-test"))
   (lambda ()
     (let ((heks/ai-provider 'auto))
       (should (eq (heks/ai-provider) 'deepseek))))))

(ert-deftest heks/ai/copilot-is-what-is-left-without-a-key ()
  (heks-ert--call-with-environment
   '(("HEKS_AI_PROVIDER" . nil) ("DEEPSEEK_API_KEY" . nil))
   (lambda ()
     (let ((heks/ai-provider 'auto)
           (heks/ai-deepseek-key-file nil))
       (should (eq (heks/ai-provider) 'copilot))))))

(ert-deftest heks/ai/the-environment-can-name-one-outright ()
  "A machine that must be told does not have to export a key to say so."
  (heks-ert--call-with-environment
   '(("HEKS_AI_PROVIDER" . "copilot") ("DEEPSEEK_API_KEY" . "sk-test"))
   (lambda ()
     (let ((heks/ai-provider 'auto))
       (should (eq (heks/ai-provider) 'copilot))))))

(ert-deftest heks/ai/a-name-it-does-not-know-is-not-obeyed ()
  "A typo should send a prompt nowhere, not to the wrong account."
  (heks-ert--call-with-environment
   '(("HEKS_AI_PROVIDER" . "copilot-work") ("DEEPSEEK_API_KEY" . nil))
   (lambda ()
     (let ((heks/ai-provider 'auto)
           (heks/ai-deepseek-key-file nil))
       (should (eq (heks/ai-provider) 'copilot))))))

(ert-deftest heks/ai/the-setting-does-not-need-the-environment ()
  (heks-ert--call-with-environment
   '(("HEKS_AI_PROVIDER" . nil) ("DEEPSEEK_API_KEY" . nil))
   (lambda ()
     (let ((heks/ai-provider 'deepseek))
       (should (eq (heks/ai-provider) 'deepseek))))))

(ert-deftest heks/ai/the-key-file-is-read-when-the-environment-has-none ()
  "A machine with no exported key can still keep one, and this is how it is read."
  (let ((file (make-temp-file "heks-ai-key-")))
    (unwind-protect
        (progn
          (write-region "sk-from-file\n" nil file nil 'silent)
          (heks-ert--call-with-environment
           '(("DEEPSEEK_API_KEY" . nil))
           (lambda ()
             (let ((heks/ai-deepseek-key-file file))
               (should (equal (heks/ai-deepseek-api-key) "sk-from-file"))))))
      (delete-file file))))

(ert-deftest heks/ai/the-key-file-is-what-makes-it-the-personal-machine ()
  "The file's existence is the sign at startup; it is not decrypted there."
  (let ((file (make-temp-file "heks-ai-key-")))
    (unwind-protect
        (heks-ert--call-with-environment
         '(("HEKS_AI_PROVIDER" . nil) ("DEEPSEEK_API_KEY" . nil))
         (lambda ()
           (let ((heks/ai-provider 'auto)
                 (heks/ai-deepseek-key-file file))
             (should (eq (heks/ai-provider) 'deepseek)))))
      (delete-file file))))

(ert-deftest heks/ai/an-encrypted-key-file-is-decrypted-with-gpg ()
  "A `.gpg' file is GPG's to read, and only its stdout is the key."
  (let ((file (make-temp-file "heks-ai-key-" nil ".gpg"))
        (invocation nil))
    (unwind-protect
        (let ((heks/ai-deepseek-key-file file))
          (cl-letf (((symbol-function 'call-process)
                     (lambda (program _infile destination _display &rest args)
                       (setq invocation (cons program args))
                       (with-current-buffer (if (and (consp destination)
                                                    (eq (car destination) t))
                                                (current-buffer)
                                              (error "GPG's output was not captured"))
                         (insert "sk-from-gpg\n"))
                       0)))
            (should (equal (heks/ai--deepseek-key-file-key) "sk-from-gpg"))
            (should (equal invocation
                           (list "gpg" "--batch" "--quiet" "--decrypt" file)))))
      (delete-file file))))

(ert-deftest heks/ai/eca-names-the-account-its-own-way ()
  "ECA's model id is qualified with the provider it logs in with."
  (let ((heks/ai-copilot-model 'some-copilot-model)
        (heks/ai-deepseek-model 'some-deepseek-model))
    (should (equal (heks/ai-eca-model 'copilot)
                   "github-copilot/some-copilot-model"))
    (should (equal (heks/ai-eca-model 'deepseek)
                   "deepseek/some-deepseek-model"))))

(defvar gptel-backend nil
  "The variable GPTel owns, declared so a test can bind it without GPTel.")

(defvar gptel-model nil
  "The variable GPTel owns, declared so a test can bind it without GPTel.")

(defvar eca-chat-custom-model nil
  "The variable ECA owns, declared so a test can bind it without ECA.")

(ert-deftest heks/ai/switching-points-both-tools-at-the-same-account ()
  "Choosing a provider is one choice, not one per tool."
  (let ((heks/ai-deepseek-model 'some-deepseek-model)
        (gptel-backend nil)
        (gptel-model nil)
        (eca-chat-custom-model nil))
    (cl-letf (((symbol-function 'heks/ai-gptel-backend)
               (lambda (provider) (list 'backend provider))))
      (heks/ai-use-provider 'deepseek))
    (should (equal gptel-backend '(backend deepseek)))
    (should (eq gptel-model 'some-deepseek-model))
    (should (equal eca-chat-custom-model "deepseek/some-deepseek-model"))))

;;
;; ====== Preparing ECA before it is asked for ======
;;

(ert-deftest heks/ai/a-prepared-chat-is-made-without-a-window ()
  "The chat is still created; what it is not given is a window."
  (let ((displayed nil)
        (opened nil))
    (cl-letf (((symbol-function 'eca-chat--display-buffer)
               (lambda (buffer) (push buffer displayed))))
      (let ((heks/ai--eca-quiet t))
        (heks/ai--eca-open-without-window
         (lambda (session)
           (setq opened session)
           (eca-chat--display-buffer (current-buffer)))
         'the-session))
      (should (eq opened 'the-session))
      (should-not displayed))))

(ert-deftest heks/ai/the-chat-the-reader-asks-for-shows-itself ()
  "The preparation spends the quietness, so the next chat opens normally."
  (let ((displayed nil))
    (cl-letf (((symbol-function 'eca-chat--display-buffer)
               (lambda (buffer) (push buffer displayed))))
      (let ((heks/ai--eca-quiet t))
        (heks/ai--eca-open-without-window (lambda (_session) nil) 'the-session))
      (heks/ai--eca-open-without-window
       (lambda (_session) (eca-chat--display-buffer (current-buffer)))
       'the-session)
      (should displayed))))

(ert-deftest heks/ai/a-chat-that-is-asked-for-is-not-quiet ()
  "The quietness is for the start, and asking is what ends it."
  (let ((heks/ai--eca-quiet t)
        (heks/ai--eca-quiet-timer nil))
    (heks/ai--eca-quiet-off)
    (should-not heks/ai--eca-quiet)))

(ert-deftest heks/ai/giving-up-cancels-the-timer ()
  "A timer that would clear the flag twice is one timer too many."
  (let ((timer (run-with-timer 60 nil #'ignore))
        (heks/ai--eca-quiet t))
    (let ((heks/ai--eca-quiet-timer timer))
      (heks/ai--eca-quiet-off)
      (should-not (memq timer timer-list))
      (should-not heks/ai--eca-quiet-timer))))

(ert-deftest heks/ai/nothing-is-said-while-preparing ()
  "A start nobody asked for is not a message in the echo area."
  (let ((said nil)
        (heks/ai--eca-quiet t))
    (heks/ai--eca-say-nothing (lambda (&rest args) (setq said args)) "ECA")
    (should-not said))
  (let ((said nil))
    (heks/ai--eca-say-nothing (lambda (&rest args) (setq said args)) "ECA")
    (should (equal said '("ECA")))))

(ert-deftest heks/ai/there-is-nothing-to-prepare-outside-a-project ()
  "A session rooted where there is no project would claim every project under it."
  (let ((starts 0)
        (heks/ai-eca-prepare t)
        (heks/ai--eca-prepared nil))
    (cl-letf (((symbol-function 'heks/ai--project-root)
               (lambda (&optional _directory) nil))
              ((symbol-function 'heks/ai--eca-start-for-project)
               (lambda (_root) (cl-incf starts))))
      (heks/ai-eca-prepare))
    (should (= starts 0))
    ;; Nothing was prepared, so the file that does name a project can be.
    (should-not heks/ai--eca-prepared)))

(ert-deftest heks/ai/eca-is-prepared-once ()
  "One server is prepared at startup, not one per buffer that follows."
  (let ((roots nil)
        (heks/ai-eca-prepare t)
        (heks/ai--eca-prepared nil))
    (cl-letf (((symbol-function 'heks/ai--project-root)
               (lambda (&optional _directory) "/tmp/heks-project/"))
              ((symbol-function 'heks/ai--eca-start-for-project)
               (lambda (root) (push root roots))))
      (heks/ai-eca-prepare)
      (heks/ai-eca-prepare))
    (should (equal roots '("/tmp/heks-project/")))
    (should heks/ai--eca-prepared)))

(ert-deftest heks/ai/a-start-that-is-not-asked-for-is-not-started ()
  "The setting is what decides, not a hook that was left in place."
  (let ((starts 0)
        (heks/ai-eca-prepare nil)
        (heks/ai--eca-prepared nil))
    (cl-letf (((symbol-function 'heks/ai--project-root)
               (lambda (&optional _directory) "/tmp/heks-project/"))
              ((symbol-function 'heks/ai--eca-start-for-project)
               (lambda (_root) (cl-incf starts))))
      (heks/ai-eca-prepare))
    (should (= starts 0))))

(ert-deftest heks/ai/a-start-that-fails-is-reported-and-is-not-quiet ()
  "A failure is said once, and the chat the reader asks for is theirs."
  (let ((messages nil)
        (real-require (symbol-function 'require))
        (heks/ai--eca-quiet nil))
    (cl-letf (((symbol-function 'require)
               (lambda (feature &optional filename noerror)
                 (if (eq feature 'eca) t
                   (funcall real-require feature filename noerror))))
              ((symbol-function 'eca-session-for-root) (lambda (_root) nil))
              ((symbol-function 'eca) (lambda (&optional _arg) (error "no network")))
              ((symbol-function 'run-with-timer) (lambda (&rest _) nil))
              ((symbol-function 'message)
               (lambda (format &rest args) (push (apply #'format format args) messages))))
      (heks/ai--eca-start-for-project "/tmp/heks-project/"))
    (should-not heks/ai--eca-quiet)
    (should (seq-some (lambda (one) (string-match-p "no network" one)) messages))))

(ert-deftest heks/ai/a-session-that-is-already-there-is-not-started-again ()
  "Preparing what is prepared would open a second server."
  (let ((started 0)
        (real-require (symbol-function 'require))
        (heks/ai--eca-quiet nil))
    (cl-letf (((symbol-function 'require)
               (lambda (feature &optional filename noerror)
                 (if (eq feature 'eca) t
                   (funcall real-require feature filename noerror))))
              ((symbol-function 'eca-session-for-root) (lambda (_root) 'a-session))
              ((symbol-function 'eca) (lambda (&optional _arg) (cl-incf started)))
              ((symbol-function 'run-with-timer) (lambda (&rest _) nil)))
      (heks/ai--eca-start-for-project "/tmp/heks-project/"))
    (should (= started 0))))

(ert-deftest heks/ai/the-watch-for-a-project-removes-itself ()
  "Watching for a project stops once there is one to prepare.
The project is handed to the timer: by the time the timer runs, the
buffer that said which project it is is not the current one any more."
  (let ((timers nil)
        (heks/ai-eca-prepare t)
        (heks/ai-eca-prepare-delay 1))
    (cl-letf (((symbol-function 'heks/ai--project-root)
               (lambda (&optional _directory) "/tmp/heks-project/"))
              ((symbol-function 'run-with-idle-timer)
               (lambda (seconds _repeat function &rest args)
                 (push (cons seconds (cons function args)) timers))))
      (add-hook 'find-file-hook #'heks/ai--eca-prepare-when-visiting)
      (heks/ai--eca-prepare-when-visiting))
    (should-not (memq 'heks/ai--eca-prepare-when-visiting find-file-hook))
    (should (equal timers '((1 heks/ai-eca-prepare "/tmp/heks-project/"))))))

(ert-deftest heks/ai/the-daemon-waits-for-the-first-project-file ()
  "There is no project at startup, so the first one visited is the one prepared."
  (let ((heks/ai-eca-prepare t))
    (cl-letf (((symbol-function 'heks/ai--project-root)
               (lambda (&optional _directory) nil)))
      (unwind-protect
          (progn
            (heks/ai--eca-prepare-soon)
            (should (memq 'heks/ai--eca-prepare-when-visiting find-file-hook)))
        (remove-hook 'find-file-hook #'heks/ai--eca-prepare-when-visiting)))))

(ert-deftest heks/ai/starting-inside-a-project-needs-no-file-visited ()
  "`emacs .' knows its project before anything is opened."
  (let ((timers nil)
        (heks/ai-eca-prepare t))
    (cl-letf (((symbol-function 'heks/ai--project-root)
               (lambda (&optional _directory) "/tmp/heks-project/"))
              ((symbol-function 'run-with-idle-timer)
               (lambda (seconds _repeat function &rest args)
                 (push (cons seconds (cons function args)) timers))))
      (heks/ai--eca-prepare-soon))
    (should (equal timers '((1 heks/ai-eca-prepare "/tmp/heks-project/"))))
    (should-not (memq 'heks/ai--eca-prepare-when-visiting find-file-hook))))

;;
;; ====== The fold indicators are quiet ======
;;

(ert-deftest heks/dev-folding/an-indicator-is-faded-toward-the-background ()
  "The marker colour is `shadow' moved part of the way to the background."
  (cl-letf (((symbol-function 'face-attribute)
             (lambda (face attribute &optional _frame _inherit)
               (pcase (cons face attribute)
                 ('(shadow . :foreground) "#989898")
                 ('(default . :background) "#000000")
                 (_ (error "The colour of %S %S was asked for" face attribute))))))
    (let ((heks/fold-indicator-fade 50))
      (should (equal (heks/fold-indicator-color) "#4c4c4c4c4c4c")))))

(ert-deftest heks/dev-folding/no-fade-leaves-the-markers-alone ()
  (let ((heks/fold-indicator-fade 0))
    (should-not (heks/fold-indicator-color))))

(ert-deftest heks/dev-folding/every-engine-gets-the-quiet-colour ()
  "Hideshow and Tree-sitter draw the same element and get the same face."
  (let ((given nil))
    (cl-letf (((symbol-function 'heks/fold-indicator-color)
               (lambda () "#4c4c4c4c4c4c"))
              ((symbol-function 'facep) (lambda (_face) t))
              ((symbol-function 'set-face-attribute)
               (lambda (face _frame &rest attributes)
                 (push (cons face attributes) given))))
      (heks/fold-indicator-faces))
    (should (= (length given) 5))
    (should (cl-every (lambda (one)
                        (equal (plist-get (cdr one) :foreground) "#4c4c4c4c4c4c"))
                      given))
    (should (cl-every (lambda (one) (eq (plist-get (cdr one) :inherit) 'shadow))
                      given))))

;;
;; ====== The guides of a fold are unbroken ======
;;

(ert-deftest heks/dev-folding/the-guide-is-given-back-five-points ()
  "The indicators are five points less faded now that the guide is solid."
  (should (= heks/fold-indicator-fade 50)))

(ert-deftest heks/dev-folding/a-line-is-as-tall-as-its-font-and-spacing ()
  "A line here is the font's 23 pixels and the six `line-spacing' adds."
  (with-temp-buffer
    (setq-local line-spacing 6)
    (cl-letf (((symbol-function 'window-font-height)
               (lambda (&optional _window) 23)))
      (should (= (heks/fold-indicator-line-height) 29)))))

(ert-deftest heks/dev-folding/the-marker-of-an-open-block-ends-in-its-guide ()
  "The guide of an open block runs from its marker to the line below it."
  (let ((rows (heks/fold-indicator-fringe-rows 'open 29)))
    (should (= (length rows) 29))
    ;; Nothing above the box: this is the line the block starts on.
    (should (equal (seq-take rows 11) (make-vector 11 0)))
    ;; The box is centred in the line...
    (should (equal (append (seq-subseq rows 11 18) nil)
                   (append heks/fold-indicator-box-open nil)))
    ;; ...and the guide runs from it to the last row, where the guide of
    ;; the next line picks it up.
    (should (equal (seq-drop rows 18)
                   (make-vector 11 heks/fold-indicator-line-row)))))

(ert-deftest heks/dev-folding/a-folded-block-shows-only-its-marker ()
  "A folded block has no guide to draw, so its line is just the marker."
  (let ((rows (heks/fold-indicator-fringe-rows 'closed 29)))
    (should (equal (append (seq-subseq rows 11 18) nil)
                   (append heks/fold-indicator-box-closed nil)))
    (should (equal (seq-subseq rows 0 11) (make-vector 11 0)))
    (should (equal (seq-subseq rows 18 29) (make-vector 11 0)))))

(ert-deftest heks/dev-folding/the-guide-of-a-block-ends-where-the-block-does ()
  "The last line of a block turns the guide toward the text and stops."
  (let ((rows (heks/fold-indicator-fringe-rows 'end 29)))
    (should (= (aref rows 0) heks/fold-indicator-line-row))
    (should (= (aref rows 13) heks/fold-indicator-line-row))
    (should (= (aref rows 14) heks/fold-indicator-elbow))
    (should (= (aref rows 15) heks/fold-indicator-elbow))
    (should (seq-every-p #'zerop (seq-drop rows 16)))))

(ert-deftest heks/dev-folding/a-marker-is-cut-to-the-height-of-a-line ()
  "A marker is a bitmap of the height of a line, made once per height."
  (with-temp-buffer
    (setq-local line-spacing 6)
    (cl-letf (((symbol-function 'window-font-height)
               (lambda (&optional _window) 23)))
      (should (eq (heks/fold-indicator-fringe-bitmap 'open)
                  'heks/fold-indicator-open-29))
      (should (eq (heks/fold-indicator-fringe-bitmap 'open)
                  'heks/fold-indicator-open-29)))))

(ert-deftest heks/dev-folding/the-guide-is-one-row-repeated ()
  "A guide is a single row, which `define-fringe-bitmap' repeats, so no
line height can leave a gap in it."
  (should (eq (heks/fold-indicator-fringe-bitmap 'guide)
              'heks/fold-indicator-guide))
  (should (integerp (get 'heks/fold-indicator-guide 'fringe))))

(ert-deftest heks/dev-folding/every-line-of-a-block-is-drawn-by-its-own-bitmap ()
  "The head of a block, its middle and its end are drawn differently."
  (with-temp-buffer
    (insert "x")
    (let ((overlay (make-overlay 1 2))
          (drawn nil))
      (cl-letf (((symbol-function 'heks/fold-indicator-fringe-bitmap)
                 (lambda (kind &optional _window) (push kind drawn) kind))
                ((symbol-function 'heks/fold-indicator-fringe)
                 (lambda () 'left-fringe)))
        (dolist (case '((treesit-fold-indicators-fr-plus . closed)
                        (treesit-fold-indicators-fr-minus-tail . open)
                        (treesit-fold-indicators-fr-center . guide)
                        (treesit-fold-indicators-fr-end-left . end)))
          (let* ((string (heks/fold-indicator-tree-sitter
                          nil overlay (car case)))
                 (display (get-text-property 0 'display string)))
            (should (eq (car drawn) (cdr case)))
            (should (equal (nth 0 display) 'left-fringe))
            (should (eq (nth 1 display) (cdr case)))
            (should (eq (nth 2 display) 'treesit-fold-fringe-face))))
        ;; A folded block shows the line it starts on and nothing else.
        (should-not (heks/fold-indicator-tree-sitter
                     t overlay 'treesit-fold-indicators-fr-center))
        (should (heks/fold-indicator-tree-sitter
                 t overlay 'treesit-fold-indicators-fr-plus))
        ;; A drawing that is not the package's own is left alone.
        (should-not (heks/fold-indicator-tree-sitter
                     nil overlay 'some-other-drawing))))))

;;
;; ====== The things a document has, and a preview needs ======
;;

(ert-deftest heks/render/a-reference-link-is-the-link-it-names ()
  (let ((html (heks/markdown-to-html
               "A [link][docs] and another [one][].\n\n[docs]: https://example.com/d \"Docs\"\n[one]: https://example.com/one\n")))
    (should (string-match-p "<a href=\"https://example.com/d\">link</a>" html))
    (should (string-match-p "<a href=\"https://example.com/one\">one</a>" html))
    ;; The definition is not a paragraph of its own.
    (should-not (string-match-p "<p>\\[docs\\]" html))))

(ert-deftest heks/render/a-label-this-document-does-not-define-is-left-alone ()
  (let ((html (heks/markdown-to-html "A [link][nowhere].\n")))
    (should (string-match-p "\\[link\\]\\[nowhere\\]" html))))

(ert-deftest heks/render/a-footnote-is-answered-at-the-end ()
  (let ((html (heks/markdown-to-html
               "Text[^a] and more[^b].\n\n[^a]: The first note.\n[^b]: The second note.\n")))
    (should (string-match-p "<sup class=\"footnote-ref\"><a id=\"fnref-1\" href=\"#fn-1\">1</a></sup>" html))
    (should (string-match-p "<sup class=\"footnote-ref\"><a id=\"fnref-2\" href=\"#fn-2\">2</a></sup>" html))
    (should (string-match-p "<li id=\"fn-1\">The first note\\." html))
    (should (string-match-p "<li id=\"fn-2\">The second note\\." html))))

(ert-deftest heks/render/footnotes-are-numbered-in-the-order-they-are-read ()
  "The order of the notes is the order of the reading, not of the file."
  (let ((html (heks/markdown-to-html
               "Text[^second] and more[^first].\n\n[^first]: Written first.\n[^second]: Read first.\n")))
    (should (string-match-p "<li id=\"fn-1\">Read first\\." html))
    (should (string-match-p "<li id=\"fn-2\">Written first\\." html))))

(ert-deftest heks/render/a-callout-is-a-quote-that-says-what-it-is ()
  (let ((html (heks/markdown-to-html
               "> [!WARNING]\n> Mind the gap.\n")))
    (should (string-match-p "<div class=\"callout callout-warning\">" html))
    (should (string-match-p "class=\"callout-title\">Warning" html))
    (should (string-match-p "<p>Mind the gap\\.</p>" html)))
  ;; A quote that says nothing about itself is still a quote.
  (let ((html (heks/markdown-to-html "> Just a quote.\n")))
    (should (string-match-p "<blockquote>" html))
    (should-not (string-match-p "callout" html))))

(ert-deftest heks/render/a-formula-is-readable-without-a-network ()
  (should (equal (heks/render-math-text "E = mc^2") "E = mc²"))
  (should (equal (heks/render-math-text "\\alpha \\leq \\beta") "α ≤ β"))
  (should (equal (heks/render-math-text "x_0 + y_{12}") "x₀ + y₁₂"))
  (should (equal (heks/render-math-text "\\frac{a}{b}") "a/b"))
  (let ((html (heks/markdown-to-html "So $E = mc^2$ holds, and $$x_1$$ too.")))
    (should (string-match-p "<span class=\"math\">E = mc²</span>" html))
    (should (string-match-p "class=\"math math-display\">x₁</span>" html))))

(ert-deftest heks/render/an-emoji-is-written-as-its-shortcode ()
  (let ((html (heks/markdown-to-html "Ship it :rocket: and :no_such_emoji: too.")))
    (should (string-match-p "Ship it 🚀" html))
    ;; A name this does not know is left as it was written.
    (should (string-match-p ":no_such_emoji:" html))))

(ert-deftest heks/render/escaped-markup-is-text-and-not-markup ()
  (let ((html (heks/markdown-to-html "An \\*asterisk\\* and a \\_underscore\\_.")))
    (should (string-match-p "An \\*asterisk\\*" html))
    (should-not (string-match-p "<em>" html))))

(ert-deftest heks/render/a-highlighted-phrase-is-marked ()
  (should (string-match-p "<mark>this</mark>"
                          (heks/markdown-to-html "A ==this== phrase."))))

(ert-deftest heks/render/a-fence-says-what-language-it-is ()
  "A code block is labelled the way a documentation site labels one."
  (let ((html (heks/markdown-to-html "```elisp\n(setq x 1)\n```\n")))
    (should (string-match-p "<figure class=\"code-block\">" html))
    (should (string-match-p "<figcaption class=\"code-language\">elisp</figcaption>" html))
    (should (string-match-p "class=\"language-elisp\"" html)))
  ;; A fence with no language has no label to give.
  (let ((html (heks/markdown-to-html "```\nplain\n```\n")))
    (should-not (string-match-p "figcaption" html))))

(ert-deftest heks/render/the-section-point-is-in-is-the-one-a-preview-follows ()
  (with-temp-buffer
    (insert "# One\n\ntext\n\n## Two\n\nmore text\n")
    (setq buffer-file-name (expand-file-name "heks-ert-sync.md" temporary-file-directory))
    ;; The file name is what makes the buffer Markdown here, so the test
    ;; does not need the mode that a real visit would give it.
    (goto-char (point-max))
    (should (equal (heks/preview--section-heading) "Two"))
    (goto-char (point-min))
    (forward-line 2)
    (should (equal (heks/preview--section-heading) "One")))
  ;; An Org note says it with asterisks, and says the same thing.
  (with-temp-buffer
    (insert "* One\n\ntext\n\n** Two\n\nmore\n")
    (org-mode)
    (goto-char (point-max))
    (should (equal (heks/preview--section-heading) "Two"))))

(ert-deftest heks/render/a-buffer-with-no-heading-has-no-section-to-follow ()
  (with-temp-buffer
    (insert "just a paragraph\n")
    (setq buffer-file-name (expand-file-name "heks-ert-sync.md" temporary-file-directory))
    (goto-char (point-max))
    (should-not (heks/preview--section-heading))))

;;
;; ====== The rules a Scheme buffer is held to ======
;;
;; `heks/scheme-lint-problems' is the whole checker as a function of
;; a string, which is what makes these tests what they are: a form in, and
;; the findings out.  Two kinds of test matter here, and the second more
;; than the first: that a habit is reported, and that the code around it --
;; the quote, the comment, the shebang line -- is not.
;;

(defun heks-ert--scheme-lint (text)
  "Return the findings of the Scheme in TEXT, as (SEVERITY . MESSAGE) pairs."
  (mapcar (lambda (finding)
            (cons (plist-get finding :severity) (plist-get finding :message)))
          (heks/scheme-lint-problems text)))

(ert-deftest heks/scheme-lint/a-clean-form-is-left-alone ()
  (should-not (heks-ert--scheme-lint
               "(define (twice f x) (f (f x)))\n\n(let* ((a 1) (b 2)) (+ a b))\n"))
  (should-not (heks-ert--scheme-lint
               "(cond ((null? xs) '()) (else (car xs)))")))

(ert-deftest heks/scheme-lint/a-name-bound-twice-is-an-error ()
  (let ((found (heks-ert--scheme-lint "(let ((x 1) (x 2)) x)")))
    (should (equal (length found) 1))
    (should (eq (caar found) :error))
    (should (string-match-p "bound twice" (cdar found)))))

(ert-deftest heks/scheme-lint/a-procedure-that-binds-a-name-twice-is-an-error ()
  (should (eq (caar (heks-ert--scheme-lint "(lambda (x x) x)")) :error))
  (should (eq (caar (heks-ert--scheme-lint "(define (f a a) a)")) :error)))

(ert-deftest heks/scheme-lint/a-clause-after-else-can-never-run ()
  (should (eq (caar (heks-ert--scheme-lint "(cond (a 1) (else 2) (b 3))")) :error)))

(ert-deftest heks/scheme-lint/eq-on-a-string-is-not-a-string-comparison ()
  (let ((found (heks-ert--scheme-lint "(eq? \"a\" \"b\")")))
    (should (eq (caar found) :warning))
    (should (string-match-p "string=?" (cdar found))))
  ;; The same question asked the right way says nothing.
  (should-not (heks-ert--scheme-lint "(string=? a b)")))

(ert-deftest heks/scheme-lint/quoted-data-is-data ()
  "A `nil' a program reads is not a `nil' a program wrote."
  (should-not (heks-ert--scheme-lint "(assq 'nil alist)"))
  (should (heks-ert--scheme-lint "(car (list nil))")))

(ert-deftest heks/scheme-lint/a-finding-sits-on-the-form-that-has-the-habit ()
  (let* ((text "(define (f) (if c #t #f))")
         (finding (car (heks/scheme-lint-problems text))))
    (should (equal (substring text (plist-get finding :start) (plist-get finding :end))
                   "(if c #t #f)"))))

(ert-deftest heks/scheme-lint/what-is-not-code-does-not-move-the-reader ()
  "Comments, a shebang line and a datum comment are read past, not read."
  (should-not (heks-ert--scheme-lint "#| (let ((x 1) (x 2))) |#\n"))
  (should-not (heks-ert--scheme-lint "#!/usr/bin/guile -s\n(define (f) 1)\n"))
  (should-not (heks-ert--scheme-lint "(define (f) #;(let ((x 1) (x 2))) 1)"))
  ;; A nested block comment ends where it ends, not at the first `|#'.
  (should-not (heks-ert--scheme-lint "#| a #| b |# (let ((x 1) (x 2))) |#\n"))
  ;; And the form after a string holding a comment opener is still read.
  (should (heks-ert--scheme-lint "(define (f) \"#|\" (let ((x 1) (x 2)) x))")))

(ert-deftest heks/scheme-lint/a-file-that-stops-in-the-middle-still-checks-what-it-has ()
  (let ((found (heks-ert--scheme-lint "(let ((x 1) (x 2)) x)\n(define (f) 1")))
    (should (= 1 (length found)))))

(ert-deftest heks/scheme-lint/a-guix-package-says-what-it-turns-off ()
  (let ((found (heks-ert--scheme-lint
                "(package (name foo) (arguments '(#:tests? #f)))")))
    (should (= 1 (length found)))
    (should (string-match-p "tests" (cdar found))))
  ;; A package that runs its tests says nothing.
  (should-not (heks-ert--scheme-lint
               "(package (name foo) (arguments (list #:tests? #t)))")))

(ert-deftest heks/scheme-lint/a-guix-package-with-old-style-inputs-is-one-finding ()
  (let ((found (heks-ert--scheme-lint
                "(package (name foo) (inputs `((\"a\" ,a) (\"b\" ,b))))")))
    (should (= 1 (length found)))
    (should (string-match-p "old-style" (cdar found))))
  ;; The inputs spelled the way `guix style' writes them are quiet.
  (should-not (heks-ert--scheme-lint
               "(package (name foo) (inputs (list a b)))")))

(ert-deftest heks/scheme-lint/every-rule-is-a-function-and-there-are-many ()
  (should (> (length heks/scheme-lint-rules) 15))
  (dolist (rule heks/scheme-lint-rules)
    (should (functionp rule))))

(ert-deftest heks/scheme-lint/a-buffer-gets-diagnostics-on-the-lines-they-belong-to ()
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "heks-ert-lint.scm" temporary-file-directory))
    (insert ";; a comment\n\n(let ((x 1) (x 2)) x)\n")
    (scheme-mode)
    (let ((diagnostics (heks/scheme-lint-diagnostics)))
      (should (= 1 (length diagnostics)))
      ;; The diagnostic sits on the form that has the habit -- the second
      ;; binding, not the line it happens to be on -- because that is what
      ;; the reader is being told to look at.
      (should (equal (line-number-at-pos (flymake-diagnostic-beg (car diagnostics))) 3))
      (should (equal (buffer-substring-no-properties
                      (flymake-diagnostic-beg (car diagnostics))
                      (flymake-diagnostic-end (car diagnostics)))
                     "(x 2)"))
      (should (equal (flymake-diagnostic-type (car diagnostics)) :error))
      ;; What the user reads is a sentence with a tool in front of it,
      ;; not a message with a gap where the tool should be.
      (should (string-prefix-p "Scheme" (flymake-diagnostic-text (car diagnostics)))))))

(ert-deftest heks/scheme-lint/nothing-is-said-in-a-buffer-that-is-not-scheme ()
  (with-temp-buffer
    (insert "(let ((x 1) (x 2)) x)")
    (emacs-lisp-mode)
    (should-not (heks/scheme-lint-diagnostics))))

;;
;; ====== The page an OpenAPI specification becomes ======
;;

(defconst heks-ert--spec
  (concat
   "{\"openapi\": \"3.0.3\","
   "\"info\": {\"title\": \"Pets\", \"version\": \"1.0.0\"},"
   "\"tags\": [{\"name\": \"pets\", \"description\": \"Everything the store keeps.\","
   " \"externalDocs\": {\"url\": \"https://example.com/guide\", \"description\": \"The guide\"}}],"
   "\"externalDocs\": {\"url\": \"https://example.com/api\", \"description\": \"The API docs\"},"
   "\"paths\": {\"/pets\": {\"get\": {\"tags\": [\"pets\"], \"summary\": \"List them\","
   " \"responses\": {\"200\": {\"description\": \"The pets\", \"content\":"
   " {\"application/json\": {\"schema\": {\"$ref\": \"#/components/schemas/Pet\"},"
   " \"example\": [{\"name\": \"Rex\", \"id\": 42}]}}}}}}},"
   "\"components\": {"
   "\"securitySchemes\": {\"key\": {\"type\": \"apiKey\", \"name\": \"X-Key\","
   " \"in\": \"header\", \"description\": \"The caller's key.\"}},"
   "\"schemas\": {\"Pet\": {\"type\": \"object\", \"description\": \"A pet.\","
   " \"required\": [\"name\"],"
   " \"properties\": {\"id\": {\"type\": \"integer\", \"format\": \"int64\", \"example\": 42},"
   " \"name\": {\"type\": \"string\", \"description\": \"Its name.\"},"
   " \"status\": {\"type\": \"string\", \"enum\": [\"available\", \"sold\"],"
   " \"default\": \"available\"},"
   " \"kind\": {\"oneOf\": [{\"type\": \"string\"}, {\"type\": \"integer\"}]}}}}}}")
  "A specification written to be small and to have everything once.")

(defmacro heks-ert--with-spec (&rest body)
  "Run BODY in a buffer visiting `heks-ert--spec' as JSON."
  (declare (indent 0))
  `(with-temp-buffer
     (setq buffer-file-name (expand-file-name "heks-ert-spec.json" temporary-file-directory))
     (insert heks-ert--spec)
     ,@body))

(ert-deftest heks/openapi/a-schema-says-what-a-value-of-it-looks-like ()
  (heks-ert--with-spec
    (let* ((spec (heks/openapi-parse))
           (schemas (heks/openapi-get (heks/openapi-get spec "components") "schemas"))
           (pet (gethash "Pet" schemas))
           (property (lambda (name)
                       (heks/openapi--schema-html
                        spec (gethash name (heks/openapi-get pet "properties")))))
      (should (string-match-p "<code>integer</code> (int64) (example: <code>42</code>)"
                              (funcall property "id")))
      (should (string-match-p "one of <code>available</code>, <code>sold</code>"
                              (funcall property "status")))
      (should (string-match-p "(default: <code>available</code>)"
                              (funcall property "status")))
      (should (string-match-p "<code>one of</code> <code>string</code>, <code>integer</code>"
                              (funcall property "kind"))))))

(ert-deftest heks/openapi/an-object-is-a-table-of-what-it-holds ()
  (heks-ert--with-spec
    (let* ((spec (heks/openapi-parse))
           (pet (gethash "Pet" (heks/openapi-get
                                (heks/openapi-get spec "components") "schemas")))
           (html (heks/openapi--properties-html spec pet)))
      (should (string-match-p "<th>Property</th><th>Type</th><th>Required</th>" html))
      (should (string-match-p "<td><code>name</code></td>.*<td>yes</td>.*<td>Its name\\.</td>" html))
      (should (string-match-p "<td><code>id</code></td>.*<td></td>" html)))))

(ert-deftest heks/openapi/an-example-is-the-json-it-is ()
  (should (equal (heks/openapi--json '(:false))
                 "false"))
  (heks-ert--with-spec
    (let* ((spec (heks/openapi-parse))
           (pet (gethash "Pet" (heks/openapi-get
                                (heks/openapi-get spec "components") "schemas"))))
      (should (equal (heks/openapi--json pet)
                     (concat "{\n  \"properties\": {\n    \"id\": {\n"
                             "      \"example\": 42,\n      \"format\": \"int64\",\n"
                             "      \"type\": \"integer\"\n    },\n"
                             "    \"kind\": {\n      \"oneOf\": [\n        {\n"
                             "          \"type\": \"string\"\n        },\n        {\n"
                             "          \"type\": \"integer\"\n        }\n      ]\n    },\n"
                             "    \"name\": {\n      \"description\": \"Its name.\",\n"
                             "      \"type\": \"string\"\n    },\n"
                             "    \"status\": {\n      \"default\": \"available\",\n"
                             "      \"enum\": [\n        \"available\",\n        \"sold\"\n      ],\n"
                             "      \"type\": \"string\"\n    }\n  },\n"
                             "  \"required\": [\n    \"name\"\n  ],\n"
                             "  \"type\": \"object\"\n}"))))))

(ert-deftest heks/openapi/the-page-says-what-there-is-before-what-there-is ()
  (heks-ert--with-spec
    (let ((html (heks/openapi-html)))
      ;; How much there is, where to read more, and who may call.
      (should (string-match-p "<p class=\"headline\">1 operation · 1 tag" html))
      (should (string-match-p "href=\"https://example.com/api\"" html))
      (should (string-match-p "<h2>Authentication</h2>" html))
      (should (string-match-p "<code>apiKey</code>" html))
      ;; What the tag is for, and the guide it comes with.
      (should (string-match-p "<p class=\"tag-description\">Everything the store keeps\\.</p>" html))
      (should (string-match-p "href=\"https://example.com/guide\"" html))
      ;; The operation, and the example of what it answers.
      (should (string-match-p "<h3 id=\"get-/pets\">" html))
      (should (string-match-p "class=\"example\"" html))
      (should (string-match-p "\"name\": \"Rex\"" html))
      ;; And the schemas, as the tables they are.
      (should (string-match-p "<h2>Schemas</h2>" html))
      (should (string-match-p "table class=\"properties\"" html)))))

(ert-deftest heks/openapi/a-specification-that-cannot-be-read-says-nothing-it-does-not-know ()
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "heks-ert-spec.json" temporary-file-directory))
    (insert "{\"openapi\": ")
    (let ((html (heks/openapi-html)))
      (should (string-match-p "<pre class=\"plain\">" html))
      (should-not (string-match-p "<h1>" html))))))

;;
;; ====== What a project writes twice ======
;;
;; The scan is a function of a directory, so these tests are a directory
;; of small files in and the clusters out.  What matters is not the exact
;; numbers -- those are in the report, where a person reads them -- but
;; that a block written twice is one cluster and not four, that a block
;; written once is not a cluster, and that the report says where.
;;

(defconst heks-ert--shared-block
  "(define (helper x y)
  (let* ((sum (+ x y))
         (product (* x y))
         (difference (- x y)))
    (when (> sum 100)
      (error \"too big: %s\" sum))
    (list sum product difference
          (string-append (number->string sum)
                         \"/\"
                         (number->string product)))))
"
  "A block of Scheme this configuration's tests copy into two files.")

(defmacro heks-ert--with-project (files &rest body)
  "Run BODY in a temporary project holding FILES, an alist of name and text."
  (declare (indent 1))
  `(let ((directory (heks-ert--temp-directory)))
     (unwind-protect
         (progn
           (dolist (entry ',files)
             (let ((file (expand-file-name (car entry) directory)))
               (make-directory (file-name-directory file) t)
               (with-temp-file file (insert (cdr entry)))))
           (let ((default-directory directory))
             (let (project-current)
               ,@body)))
       (delete-directory directory t))))

(ert-deftest heks/duplicates/a-block-in-two-files-is-one-cluster ()
  (heks-ert--with-project (("a.scm" . ";;; a\n(define-module (a))\n\n")
                           ("b.scm" . ";;; b\n(define-module (b))\n\n"))
    ;; The same block, written twice, and nothing else.
    (with-temp-file (expand-file-name "a.scm" default-directory)
      (insert ";;; a\n(define-module (a))\n\n" heks-ert--shared-block))
    (with-temp-file (expand-file-name "b.scm" default-directory)
      (insert ";;; b\n(define-module (b))\n\n" heks-ert--shared-block))
    (let ((runs (heks/duplicates-scan default-directory)))
      (should (= 1 (length runs)))
      (let ((run (car runs)))
        (should (= 10 (plist-get run :length)))
        (should (= 2 (length (plist-get run :occurrences))))
        (should (= 10 (heks/duplicates-wasted-lines run)))
        (should (equal (sort (mapcar (lambda (occurrence)
                                       (file-name-nondirectory (nth 0 occurrence)))
                                     (plist-get run :occurrences))
                             #'string<)
                       '("a.scm" "b.scm")))
        ;; The occurrence starts where the block does: line 4 of each file,
        ;; after the comment, the module and the blank line.
        (should (equal (sort (mapcar (lambda (occurrence)
                                       (list (file-name-nondirectory (nth 0 occurrence))
                                             (nth 1 occurrence) (nth 2 occurrence)))
                                     (plist-get run :occurrences))
                             (lambda (one two) (string< (car one) (car two))))
                       '(("a.scm" 4 13) ("b.scm" 4 13))))))))

(ert-deftest heks/duplicates/a-block-written-once-is-not-a-cluster ()
  (heks-ert--with-project (("a.scm" . ";;; a\n")
                           ("b.scm" . ";;; b\n"))
    (with-temp-file (expand-file-name "a.scm" default-directory)
      (insert ";;; a\n(define-module (a))\n\n" heks-ert--shared-block))
    (with-temp-file (expand-file-name "b.scm" default-directory)
      (insert ";;; b\n(define (b-only) 1)\n"))
    (should-not (heks/duplicates-scan default-directory))))

(ert-deftest heks/duplicates/a-short-block-is-an-idiom-and-not-reported ()
  (heks-ert--with-project (("a.el" . "(require 'cl-lib)\n")
                           ("b.el" . "(require 'cl-lib)\n"))
    (should-not (heks/duplicates-scan default-directory))))

(ert-deftest heks/duplicates/a-block-copied-inside-one-file-is-hidden-until-asked-for ()
  (let ((heks/duplicates-across-files-only t))
    (heks-ert--with-project (("a.scm" . ""))
      (with-temp-file (expand-file-name "a.scm" default-directory)
        (insert heks-ert--shared-block "\n" heks-ert--shared-block))
      (should-not (heks/duplicates-scan default-directory))
      (let ((heks/duplicates-across-files-only nil))
        (should (= 1 (length (heks/duplicates-scan default-directory))))))))

(ert-deftest heks/duplicates/indentation-is-not-a-difference ()
  "The same code indented differently is the same code."
  (heks-ert--with-project (("a.scm" . "")
                           ("b.scm" . ""))
    (with-temp-file (expand-file-name "a.scm" default-directory)
      (insert "(define (helper x y)\n  (let* ((sum (+ x y))\n         (product (* x y))\n         (difference (- x y)))\n    (when (> sum 100)\n      (error \"too big\"))\n    (list sum product difference)))\n"))
    (with-temp-file (expand-file-name "b.scm" default-directory)
      (insert "(define (helper x y)\n      (let* ((sum (+ x y))\n   (product (* x y))\n               (difference (- x y)))\n  (when (> sum 100)\n      (error \"too big\"))\n      (list sum product difference)))\n"))
    (should (= 1 (length (heks/duplicates-scan default-directory))))))

(ert-deftest heks/duplicates/a-comment-is-not-code-and-is-not-compared ()
  "Two copies of a block are one cluster, whatever is said about them."
  (heks-ert--with-project (("a.scm" . "")
                           ("b.scm" . ""))
    (with-temp-file (expand-file-name "a.scm" default-directory)
      (insert ";; the helper, written once\n    ;; and explained\n"
              heks-ert--shared-block))
    (with-temp-file (expand-file-name "b.scm" default-directory)
      (insert ";;; a different explanation\n;;; of the same thing\n"
              heks-ert--shared-block))
    (let ((runs (heks/duplicates-scan default-directory)))
      (should (= 1 (length runs)))
      ;; The comment lines are not part of what is compared, so the
      ;; cluster is the code and starts where the code starts.
      (should-not (string-match-p "written once" (plist-get (car runs) :text))))))

(ert-deftest heks/duplicates/the-report-says-where-and-how-much ()
  (let ((run (list :text "(a)\n(b)\n(c)" :length 3
                   :occurrences '(("/p/a.el" 10 12) ("/p/b.el" 40 42)))))
    (with-temp-buffer
      (heks/duplicates-render (list run) "duplicated code · /p")
      (let ((text (buffer-string)))
        (should (string-match-p "1 cluster" text))
        (should (string-match-p "3 lines in 2 places" text))
        (should (string-match-p "3 lines wasted" text))
        (should (string-match-p "a\\.el:10-12" text))
        (should (string-match-p "b\\.el:40-42" text))
        ;; The excerpt is there, so a reader can tell at a glance whether
        ;; the block is worth opening.
        (should (string-match-p "(b)" text))
        ;; And every place is a button, which is what makes the report
        ;; something to act on rather than something to read.
        (goto-char (point-min))
        (should (next-button (point-min)))))))

(ert-deftest heks/duplicates/an-empty-report-says-so ()
  (with-temp-buffer
    (heks/duplicates-render nil "duplicated code · /p")
    (should (string-match-p "Nothing is written twice" (buffer-string)))))

(ert-deftest heks/duplicates/the-report-has-a-mode-and-keys ()
  (with-temp-buffer
    (heks/duplicates-report-mode)
    (should (derived-mode-p 'special-mode))
    (should (keymapp heks/duplicates-report-mode-map))
    (should (eq (key-binding (kbd "n")) 'heks/duplicates-next))
    (should (key-binding (kbd "s")))
    (should (key-binding (kbd "q")))))

(ert-deftest heks/duplicates/the-report-walks-its-clusters ()
  (let ((one (list :text "(a)\n(b)" :length 2
                   :occurrences '(("/p/a.el" 1 2) ("/p/b.el" 1 2))))
        (two (list :text "(c)\n(d)" :length 2
                   :occurrences '(("/p/c.el" 5 6) ("/p/d.el" 5 6)))))
    (with-temp-buffer
      (heks/duplicates-report-mode)
      (let ((inhibit-read-only t))
        (heks/duplicates-render (list one two) "duplicated code · /p"))
      (goto-char (point-min))
      (should (equal (heks/duplicates--clusters) '(1 2)))
      (heks/duplicates-next)
      (should (equal (get-text-property (point) 'heks/duplicates-cluster) 1))
      (heks/duplicates-next)
      (should (equal (get-text-property (point) 'heks/duplicates-cluster) 2))
      ;; The last cluster is the last one: walking past it says so rather
      ;; than moving nowhere, and walking back arrives at the first.
      (heks/duplicates-next)
      (should (equal (get-text-property (point) 'heks/duplicates-cluster) 2))
      (heks/duplicates-next t)
      (should (equal (get-text-property (point) 'heks/duplicates-cluster) 1)))))

(ert-deftest heks/duplicates/the-scan-reads-what-is-code ()
  "A file that is not written to be read is not read."
  (heks-ert--with-project (("a.scm" . "") ("image.png" . "not really a png"))
    (should (equal (mapcar #'file-name-nondirectory
                           (heks/duplicates--candidate-files default-directory))
                   '("a.scm")))))

;;
;; Run.
;;

;;
;; ====== The notes: indexes, links, contacts, bookmarks ======
;;

(defvar date)

(defmacro heks-ert--with-notes (&rest body)
  "Run BODY with `root' a fresh, empty notes directory."
  `(let* ((root (file-name-as-directory (file-truename (heks-ert--temp-directory))))
          (heks/notes-dir root)
          (heks/contacts--cache nil)
          (heks/bookmarks--cache nil))
     (unwind-protect (progn ,@body)
       (delete-directory root t))))

(defun heks-ert--write (file text)
  "Write TEXT to FILE, making its folder."
  (make-directory (file-name-directory file) t)
  (write-region text nil file nil 'silent))

(defun heks-ert--read (file)
  "Return the text of FILE."
  (with-temp-buffer (insert-file-contents file) (buffer-string)))

(ert-deftest heks/notes/an-index-lists-what-is-in-its-folder ()
  (heks-ert--with-notes
    (heks-ert--write (expand-file-name "eng/haskell/monads.org" root) "#+title: Monads\n\ntext\n")
    (heks-ert--write (expand-file-name "eng/overview.org" root) "#+title: Overview\n")
    (heks/notes-regenerate-indexes)
    (let ((eng (heks-ert--read (expand-file-name "eng/index.org" root)))
          (haskell (heks-ert--read (expand-file-name "eng/haskell/index.org" root))))
      (should (string-match-p "^- \\[\\[file:\\./haskell/index\\.org\\]\\[Haskell\\]\\]$" eng))
      (should (string-match-p "^- \\[\\[file:\\./overview\\.org\\]\\[Overview\\]\\]$" eng))
      (should (string-match-p "^- \\[\\[file:\\./monads\\.org\\]\\[Monads\\]\\]$" haskell))
      (should (string-match-p "^#\\+title: Eng$" eng)))))

(ert-deftest heks/notes/regenerating-an-index-changes-nothing-and-keeps-its-description ()
  (heks-ert--with-notes
    (heks-ert--write (expand-file-name "a/one.org" root) "#+title: One\n")
    (heks/notes-regenerate-indexes)
    (let* ((file (expand-file-name "a/index.org" root))
           (text (heks-ert--read file)))
      (heks-ert--write file (replace-regexp-in-string "\n\n# BEGIN" "\n\nWhat a is for.\n\n# BEGIN" text))
      (should-not (heks/notes-index-update (expand-file-name "a" root)))
      (should (string-match-p "What a is for\\." (heks-ert--read file))))))

(ert-deftest heks/notes/an-index-written-by-hand-is-left-alone ()
  (heks-ert--with-notes
    (heks-ert--write (expand-file-name "a/one.org" root) "#+title: One\n")
    (heks-ert--write (expand-file-name "a/index.org" root) "#+title: Mine\n\nMy own page.\n")
    (heks/notes-regenerate-indexes)
    (should (equal (heks-ert--read (expand-file-name "a/index.org" root))
                   "#+title: Mine\n\nMy own page.\n"))))

(ert-deftest heks/notes/moving-a-note-repairs-the-links-to-it-and-in-it ()
  (heks-ert--with-notes
    (let* ((from (expand-file-name "a/x.org" root))
           (to (expand-file-name "b/c/x.org" root)))
      (should (equal (heks/notes--relink-text "[[file:./x.org][X]] [[file:../a/y.org][Y]]"
                                              (expand-file-name "a/" root) (expand-file-name "a/" root)
                                              from to)
                     "[[file:../b/c/x.org][X]] [[file:../a/y.org][Y]]"))
      ;; the moved note's own links are made relative to where it now is
      (should (equal (heks/notes--relink-text "[[file:./y.org][Y]] [[https://example.org][E]]"
                                              (expand-file-name "a/" root) (expand-file-name "b/c/" root)
                                              from to)
                     "[[file:../../a/y.org][Y]] [[https://example.org][E]]")))))

(ert-deftest heks/contacts/a-birthday-is-read-with-or-without-its-year ()
  (should (equal (heks/contacts-parse-birthday "1992-11-23") '(1992 11 23)))
  (should (equal (heks/contacts-parse-birthday "11-23") '(nil 11 23)))
  (should (equal (heks/contacts-parse-birthday "--02-29") '(nil 2 29)))
  (should-not (heks/contacts-parse-birthday "soon"))
  (should-not (heks/contacts-parse-birthday "1992-13-01")))

(ert-deftest heks/contacts/the-agenda-is-told-whose-birthday-it-is ()
  (heks-ert--with-notes
    (heks-ert--write (expand-file-name "contacts.org" root)
                     "* Manon\n:PROPERTIES:\n:BIRTHDAY: 1992-11-23\n:END:\n* Joe\n:PROPERTIES:\n:BIRTHDAY: 03-04\n:END:\n* Nobody\n")
    (let ((date '(11 23 2026)))
      (should (equal (heks/contacts-birthdays) "🎂 Manon (34)")))
    (let ((date '(3 4 2026)))
      (should (equal (heks/contacts-birthdays) "🎂 Joe")))
    (let ((date '(5 5 2026)))
      (should-not (heks/contacts-birthdays)))))

(ert-deftest heks/contacts/a-contact-is-added-with-only-the-details-given ()
  (heks-ert--with-notes
    (heks-ert--write (expand-file-name "contacts.org" root) "#+title: Contacts\n")
    (heks/contact-new "Ada" "ada@example.org" "" "12-10")
    (let ((contact (car (heks/contacts-all))))
      (should (equal (plist-get contact :name) "Ada"))
      (should (equal (plist-get contact :email) "ada@example.org"))
      (should-not (plist-get contact :phone))
      (should (equal (plist-get contact :birthday) "12-10")))
    (should-error (heks/contact-new "Bad" "" "" "tomorrow") :type 'user-error)))

(ert-deftest heks/bookmarks/the-links-under-a-heading-are-its-bookmarks ()
  (heks-ert--with-notes
    (heks-ert--write (expand-file-name "bookmarks.org" root)
                     "* Dev\n- [[https://gnu.org/][GNU]]\n** Haskell\n- [[https://haskell.org/][Haskell]]\n")
    (let ((all (heks/bookmarks-all)))
      (should (equal (mapcar (lambda (b) (plist-get b :category)) all) '("Dev" "Dev / Haskell")))
      (should (equal (plist-get (cadr all) :url) "https://haskell.org/")))))

(ert-deftest heks/bookmarks/a-bookmark-is-filed-under-its-category-and-only-once ()
  (heks-ert--with-notes
    (heks-ert--write (expand-file-name "bookmarks.org" root)
                     "* Dev\n- [[https://gnu.org/][GNU]]\n\n* Fun\n")
    (heks/bookmark-add "https://example.org/a" "A" "Dev")
    (heks/bookmark-add "https://example.org/b" "B" "Music / Guitar")
    (let ((text (heks-ert--read (expand-file-name "bookmarks.org" root))))
      (should (string-match-p "\\* Dev\n- \\[\\[https://gnu.org/\\]\\[GNU\\]\\]\n- \\[\\[https://example.org/a\\]\\[A\\]\\]\n" text))
      (should (string-match-p "\\* Music\n\\*\\* Guitar\n- \\[\\[https://example.org/b\\]\\[B\\]\\]" text)))
    (heks/bookmark-add "https://example.org/a" "A again" "Dev")
    (should (= 1 (seq-count (lambda (b) (equal (plist-get b :url) "https://example.org/a"))
                            (heks/bookmarks-all))))
    (kill-matching-buffers "bookmarks.org" t t)))

(ert-deftest heks/graph/notes-and-topics-are-nodes-and-links-and-folders-are-edges ()
  (heks-ert--with-notes
    (heks-ert--write (expand-file-name "eng/a.org" root)
                     "#+title: A\n\nSee [[file:./b.org][B]] and [[file:../food/c.org][C]].\n#+begin_src org\n[[file:./hidden.org][not a link]]\n#+end_src\n")
    (heks-ert--write (expand-file-name "eng/b.org" root) "#+title: B\n")
    (heks-ert--write (expand-file-name "food/c.org" root) "#+title: C\n")
    (heks-ert--write (expand-file-name "eng/hidden.org" root) "#+title: Hidden\n")
    (heks-ert--write (expand-file-name "todo.org" root) "#+title: Todo\n[[file:eng/a.org][A]]\n")
    (heks-ert--write (expand-file-name "eng/index.org" root) "#+title: Eng\n")
    (let* ((data (heks/notes-graph-data))
           (nodes (append (plist-get data :nodes) nil))
           (edges (append (plist-get data :edges) nil))
           (ids (mapcar (lambda (n) (plist-get n :id)) nodes))
           (pairs (lambda (kind) (sort (mapcar (lambda (e) (cons (plist-get e :s) (plist-get e :t)))
                                               (seq-filter (lambda (e) (equal (plist-get e :k) kind)) edges))
                                       (lambda (a b) (string< (format "%S" a) (format "%S" b)))))))
      (should (member "eng/a.org" ids))
      (should (member "t:eng" ids))
      (should (member "t:" ids))
      ;; the personal file and the index page are not notes of the map
      (should-not (member "todo.org" ids))
      (should-not (member "eng/index.org" ids))
      ;; a link in a source block is not a link
      (should (equal (funcall pairs "link")
                     '(("eng/a.org" . "eng/b.org") ("eng/a.org" . "food/c.org"))))
      (should (member '("t:eng" . "eng/a.org") (funcall pairs "tree")))
      (should (member '("t:" . "t:eng") (funcall pairs "tree")))
      (should (= 3 (plist-get (seq-find (lambda (n) (equal (plist-get n :id) "t:eng")) nodes) :total))))))

(ert-deftest heks/graph/the-page-carries-its-data-and-cannot-close-its-script ()
  (heks-ert--with-notes
    (heks-ert--write (expand-file-name "t/x.org" root) "#+title: </script><b>x\n")
    (let ((page (heks/notes-graph--page (list :serve :false :data (heks/notes-graph-data)))))
      (should (string-match-p "\"serve\":false" page))
      (should (string-match-p "<\\\\/script><b>x" page))
      (should-not (string-match-p "/\\*@CONFIG@\\*/ {}" page)))))

;;
;; ====== Markdown prettifying ======
;;

(defmacro heks-ert--with-markdown (text &rest body)
  "Run BODY in a text buffer holding TEXT, with the Markdown hiding applied."
  (declare (indent 1))
  `(with-temp-buffer
     (insert ,text)
     (heks/markdown-hide-markers (point-min) (point-max))
     (heks/markdown-prettify-blocks (point-min) (point-max))
     ,@body))

(defun heks-ert--has-face (pos face)
  "Return non-nil when FACE is among the faces at POS."
  (let ((f (get-text-property pos 'face)))
    (if (listp f) (memq face f) (eq face f))))

(defun heks-ert--hidden (string)
  "Return the text of the buffer without what is invisible, given STRING is in it."
  (let ((out ""))
    (dotimes (i (- (point-max) (point-min)))
      (let ((pos (+ (point-min) i)))
        (unless (get-text-property pos 'invisible)
          (setq out (concat out (string (char-after pos)))))))
    (ignore string)
    out))

(ert-deftest heks/markdown/inline-delimiters-are-hidden ()
  (heks-ert--with-markdown "a `code` **bold** *it* ~~gone~~ z\n"
    (should (equal (heks-ert--hidden nil) "a code bold it gone z\n"))))

(ert-deftest heks/markdown/code-blocks-keep-their-characters ()
  "Nothing inside a fenced block, nor its fences, is hidden."
  (let ((text "x\n```bash\nls *.md `a` **b** _c_ snake_case_name\n```\ny *z*\n"))
    (heks-ert--with-markdown text
      (should (equal (heks-ert--hidden nil)
                     "x\n```bash\nls *.md `a` **b** _c_ snake_case_name\n```\ny z\n")))))

(ert-deftest heks/markdown/intraword-underscores-are-not-emphasis ()
  (heks-ert--with-markdown "use snake_case_name and _this_\n"
    (should (equal (heks-ert--hidden nil) "use snake_case_name and this\n"))))

(ert-deftest heks/markdown/an-unclosed-fence-hides-nothing-after-it ()
  (let ((text "```\n*a* `b`\n"))
    (heks-ert--with-markdown text
      (should (equal (heks-ert--hidden nil) text)))))

(ert-deftest heks/markdown/blocks-get-a-label-and-a-body-face ()
  (heks-ert--with-markdown "```elisp\n(+ 1 2)\n```\n"
    (should (string-match-p "elisp" (get-text-property 1 'display)))
    (should (heks-ert--has-face 10 'heks/markdown-code-block))
    (should (get-text-property (- (point-max) 4) 'display))))

(ert-deftest heks/markdown/two-blocks-are-paired-correctly ()
  "A refontify starting between two blocks must not pair a closing fence with the next opening one."
  (let ((text "```a\nx\n```\nprose\n```b\ny\n```\n"))
    (with-temp-buffer
      (insert text)
      (heks/markdown-prettify-blocks (point-min) (point-max))
      ;; Refontify only the prose between them.
      (heks/markdown-prettify-blocks 12 18)
      (should (string-match-p "a" (get-text-property 1 'display)))
      (should-not (get-text-property 12 'display))
      (should-not (heks-ert--has-face 19 'heks/markdown-code-fence))
      (goto-char (point-min))
      (search-forward "y")
      (should (heks-ert--has-face (1- (point)) 'heks/markdown-code-block)))))

(ert-deftest heks/markdown/removing-a-fence-removes-its-look ()
  (with-temp-buffer
    (insert "```\nx\n```\n")
    (heks/markdown-prettify-blocks (point-min) (point-max))
    (should (get-text-property 1 'display))
    (goto-char (point-min))
    (delete-char 3)
    (heks/markdown-prettify-blocks (point-min) (point-max))
    (should-not (get-text-property 1 'display))))

(ert-deftest heks/markdown/rehiding-is-idempotent-and-refreshes ()
  (with-temp-buffer
    (insert "*a*\n")
    (heks/markdown-hide-markers (point-min) (point-max))
    (heks/markdown-hide-markers (point-min) (point-max))
    (should (equal (heks-ert--hidden nil) "a\n"))
    (goto-char 3) (delete-char 1)
    (heks/markdown-hide-markers (point-min) (point-max))
    (should (equal (heks-ert--hidden nil) "*a\n"))))

(ert-deftest heks/markdown/markup-shows-while-point-is-in-it ()
  (with-temp-buffer
    (insert "a *b* c\n*d*\n")
    (heks/markdown-hide-markers (point-min) (point-max))
    (goto-char 4)
    (heks/markdown-reveal)
    (should (equal (heks-ert--hidden nil) "a *b* c\nd\n"))
    (goto-char 10)
    (heks/markdown-reveal)
    (should (equal (heks-ert--hidden nil) "a b c\n*d*\n"))))

(ert-deftest heks/markdown/huge-buffers-are-left-alone ()
  (let ((heks/markdown-max-size 5))
    (heks-ert--with-markdown "*abc* *def*\n"
      (should (equal (heks-ert--hidden nil) "*abc* *def*\n")))))

(ert-deftest heks/markdown/the-readme-style-document-has-balanced-hiding ()
  "Sanity: across a realistic document, hiding never removes a code character."
  (let ((text (concat "# T\n\n| a | b |\n|---|---|\n| `x` | y |\n\n"
                      "```bash\nmvn test -Dtest=A#b\n# *not* hidden\n```\n\n"
                      "- **Port:** 8087\n")))
    (heks-ert--with-markdown text
      (let ((shown (heks-ert--hidden nil)))
        (should (string-match-p "mvn test -Dtest=A#b\n# \\*not\\* hidden" shown))
        (should (string-match-p "- Port: 8087" shown))))))
(ert-deftest heks/markdown/tilde-fences-are-fences ()
  (let ((text "~~~sh\n*a* `b` _c_\n~~~\n*d*\n"))
    (heks-ert--with-markdown text
      (should (equal (heks-ert--hidden nil) "~~~sh\n*a* `b` _c_\n~~~\nd\n"))
      (should (string-match-p "sh" (get-text-property 1 'display))))))

(ert-deftest heks/markdown/a-longer-fence-holds-a-shorter-one ()
  "Four backticks are closed by four or more, not by three."
  (let ((text "````md\n```\n*a*\n```\n````\n*b*\n"))
    (heks-ert--with-markdown text
      (should (equal (heks-ert--hidden nil) "````md\n```\n*a*\n```\n````\nb\n"))
      (should (= 1 (length (heks/markdown--blocks)))))))

(ert-deftest heks/markdown/a-tilde-fence-is-not-closed-by-backticks ()
  (let ((text "~~~\n```\n*a*\n~~~\n*b*\n"))
    (heks-ert--with-markdown text
      (should (equal (heks-ert--hidden nil) "~~~\n```\n*a*\n~~~\nb\n")))))

(ert-deftest heks/markdown/a-backtick-line-with-backticks-after-is-inline-code ()
  (heks-ert--with-markdown "```a`` and *b*\n"
    (should (null (heks/markdown--blocks)))))

(ert-deftest heks/markdown/an-indented-fence-works ()
  (heks-ert--with-markdown "- item\n  ```go\n  *a*\n  ```\n"
    (should (equal (heks-ert--hidden nil) "- item\n  ```go\n  *a*\n  ```\n"))))


(unless (getenv "HEKS_ERT_NO_RUN")
  (ert-run-tests-batch-and-exit))

;;; heks-emacs-ert.el ends here
