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

(dolist (module '("render" "present" "heks-emacs" "emacs-core" "dev" "openapi"
                 "shell" "guile"))
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

(ert-deftest heks-emacs-render/code-is-fontified-with-its-modes-faces ()
  "A fenced block of Elisp comes out with Emacs's own faces on it."
  (let ((html (heks-emacs-render-highlight "(defun f (x) x)" "elisp")))
    (should (string-match-p "<span class=\"hl-font-lock-keyword-face\">defun</span>" html))
    (should (string-match-p "hl-font-lock-function-name-face" html))))

(ert-deftest heks-emacs-render/fontified-code-is-still-escaped ()
  "Highlighting never lets a `<' of the snippet into the page."
  (let* ((html (heks-emacs-render-highlight "(if (< a b) \"x\")" "elisp"))
         (text (replace-regexp-in-string "</?span[^>]*>" "" html)))
    (should (string-match-p "&lt; a b" text))
    (should-not (string-match-p "[a-z] < [a-z]" text))))

(ert-deftest heks-emacs-render/a-language-without-a-mode-is-left-as-text ()
  "A language no mode reads is escaped and not guessed at."
  (should (equal (heks-emacs-render-highlight "a < b" "nosuchlanguage")
                 "a &lt; b")))

(ert-deftest heks-emacs-render/the-language-of-a-fence-finds-its-mode ()
  "The names a fence uses are the ones the mode table knows."
  (should (eq (heks-emacs-render-language-mode "bash") 'sh-mode))
  (should (eq (heks-emacs-render-language-mode "elisp") 'emacs-lisp-mode))
  (should (eq (heks-emacs-render-language-mode "shell") 'sh-mode))
  (should (eq (heks-emacs-render-language-mode "Scheme") 'scheme-mode))
  (should-not (heks-emacs-render-language-mode "nosuchlanguage")))

(ert-deftest heks-emacs-render/anchors-are-ids-a-link-can-use ()
  (should (equal (heks-emacs-render-anchor "Get /pets and the rest")
                 "get-pets-and-the-rest"))
  (should (equal (heks-emacs-render-anchor "A title: with punctuation!") "a-title-with-punctuation"))
  (should (equal (heks-emacs-render-anchor "   ") "section")))

(ert-deftest heks-emacs-render/headings-get-ids-in-the-order-they-appear ()
  (let* ((rendered (heks-emacs-render--headings "<h1>A</h1>\n<h2>B</h2>"))
         (html (car rendered))
         (entries (cdr rendered)))
    (should (string-match-p "<h1 id=\"a\">A</h1>" html))
    (should (string-match-p "<h2 id=\"b\">B</h2>" html))
    (should (equal (mapcar (lambda (entry) (list (car entry) (nth 1 entry)))
                           entries)
                   '((1 "a") (2 "b"))))))

(ert-deftest heks-emacs-render/two-headings-with-one-name-get-two-ids ()
  (let* ((rendered (heks-emacs-render--headings "<h2>Same</h2>\n<h2>Same</h2>"))
         (ids (mapcar (lambda (entry) (nth 1 entry)) (cdr rendered))))
    (should (equal ids '("same" "same-2")))
    (should-not (string-match-p "<h2 id=\"same\">Same</h2>.*<h2 id=\"same\">" (car rendered)))))

(ert-deftest heks-emacs-render/a-heading-that-has-an-id-keeps-it ()
  "The OpenAPI renderer writes ids worth mentioning, and they survive.

They are not decoration: the contents list links to them, so a heading
whose id is thrown away and replaced by a slug of its text is a heading
the list cannot reach."
  (let ((rendered (heks-emacs-render--headings "<h3 id=\"get-/pets\">GET /pets</h3>")))
    (should (string-match-p "<h3 id=\"get-/pets\">" (car rendered)))
    (should (equal (nth 1 (car (cdr rendered))) "get-/pets"))))

(ert-deftest heks-emacs-render/the-contents-list-reaches-the-operations-it-names ()
  (let ((heks-emacs-render-toc-headings 3))
    (let* ((body (mapconcat #'identity
                            '("<h1>Pet Store</h1>"
                              "<h2>pets</h2>"
                              "<h3 id=\"get-/pets\">GET /pets</h3>"
                              "<h3 id=\"post-/pets\">POST /pets</h3>")
                            "\n"))
           (document (heks-emacs-html-document "T" body)))
      (should (string-match-p "href=\"#get-/pets\"" document))
      (should (string-match-p "<h3 id=\"get-/pets\">" document)))))

(ert-deftest heks-emacs-render/contents-are-listed-when-there-are-enough ()
  (let ((heks-emacs-render-toc-headings 3))
    (let* ((two (heks-emacs-render-toc
                 (list (list 2 "a" "A") (list 2 "b" "B"))))
           (three (heks-emacs-render-toc
                   (list (list 2 "a" "A") (list 2 "b" "B") (list 2 "c" "C")))))
      (should-not two)
      (should (string-match-p "nav class=\"toc\"" three))
      (should (string-match-p "href=\"#b\"" three))
      (should (equal (heks-ert--count "<li" three) 3)))))

(ert-deftest heks-emacs-render/contents-do-not-list-the-title ()
  "A document's own heading heads it; the contents start under it."
  (let ((listed (heks-emacs-render-toc-entries
                 (list (list 1 "title" "Title") (list 2 "a" "A") (list 2 "b" "B")))))
    (should (equal (mapcar (lambda (entry) (nth 1 entry)) listed) '("a" "b")))))

(ert-deftest heks-emacs-render/contents-stop-one-level-under-the-shallowest ()
  (let ((listed (heks-emacs-render-toc-entries
                 (list (list 2 "a" "A") (list 2 "b" "B")
                       (list 3 "c" "C") (list 5 "d" "D")))))
    (should (equal (mapcar (lambda (entry) (nth 1 entry)) listed) '("a" "b" "c")))))

(ert-deftest heks-emacs-render/contents-are-in-the-document ()
  (let ((heks-emacs-render-toc-headings 3))
    (let ((document (heks-emacs-html-document
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

(ert-deftest heks-emacs-render/an-org-note-is-exported-by-org-itself ()
  "An Org buffer is rendered, and it is Org's own exporter that renders it.

A note is read as Org and not as text, so what Org knows -- a heading, a
list, a table, a link, a block of code -- arrives as the markup for it."
  (heks-ert--with-file ".org" heks-ert--org-note
    (should (eq major-mode 'org-mode))
    (should (equal (heks-emacs-render--variant-name (current-buffer)) "Org"))
    (let ((body (heks-emacs-render-body)))
      (should (stringp body))
      (should (string-match-p "One</h" body))
      (should (string-match-p "Three</h" body))
      ;; The code in the note is the note's own text on the page, escaped
      ;; rather than poured in as markup.
      (should (string-match-p "&lt;not markup&gt;" body))
      (should-not (string-match-p "<not markup>" body)))))

(ert-deftest heks-emacs-render/a-note-gets-one-contents-list-and-it-is-this-modules ()
  "Org's own contents list is asked for and dropped, not left in the body.

`org-export-with-toc' is on by default, so an export asked for it before
the settings around it were in force would carry Org's list -- and the
page would then have two, one of them linking to ids of Org's making.
The values of a `let' are evaluated before any of them is bound, which is
why these settings are bound one by one."
  (heks-ert--with-file ".org" heks-ert--org-note
    (let* ((body (heks-emacs-render-body))
           (document (heks-emacs-html-document "A note" body)))
      (should-not (string-match-p "table-of-contents" body))
      (should (equal (heks-ert--count "<nav class=\"toc\"" document) 1))
      (should (string-match-p "Contents" document))
      ;; And the one list there is lists the note's headings.
      (dolist (heading '("One" "Two" "Three"))
        (should (string-match-p heading document))))))

(ert-deftest heks-emacs-render/every-link-in-a-notes-contents-list-reaches-a-heading ()
  "Each entry of the list points at an id the page really has.

Org gives its headings ids of its own, so the list has to keep them: a
list that named unanchored slugs would be entries nobody can follow, which
is what the OpenAPI page's list was before this was checked."
  (heks-ert--with-file ".org" heks-ert--org-note
    (let* ((body (heks-emacs-render-body))
           (document (heks-emacs-html-document "A note" body))
           (position 0)
           (links 0))
      (while (string-match "href=\"#\\([^\"]+\\)\"" document position)
        (let ((target (match-string 1 document)))
          (setq position (match-end 0)
                links (1+ links))
          (should (string-match-p (regexp-quote (format "id=\"%s\"" target)) document))))
      (should (> links 0)))))

(ert-deftest heks-emacs-render/a-note-asks-for-colours-htmlize-can-give-it ()
  "Colouring a block of code is asked for when it can be done, and not otherwise.

`htmlize' is what Org colours a source block with.  Where it is here the
preview asks for its colours as inline styles, because the page carries
none of Org's stylesheet and a class name with no stylesheet behind it is
a block with no colour; where it is not, the setting is nil -- Org's plain
text -- because asking Org for colours it cannot produce is a warning on
every export."
  (should (eq (heks-emacs-render--org-output-type)
              (if (require 'htmlize nil t) 'inline-css nil))))

(defface heks-ert-coloured-face '((t :foreground "#123456" :weight bold))
  "A face for the test of the stylesheet, with a colour of its own.")

(defface heks-ert-plain-face '((t))
  "A face for the test of the stylesheet, with no colour of its own.")

(ert-deftest heks-emacs-render/the-stylesheet-colours-the-faces-that-have-colours ()
  (let* ((heks-emacs-render--faces '(heks-ert-coloured-face heks-ert-plain-face
                                                           heks-ert-coloured-face))
         (css (heks-emacs-render-highlight-css)))
    (should (string-match-p "color: #123456" css))
    (should (string-match-p "font-weight: 700" css))
    ;; One rule per face, and the same face twice is still one rule.
    (should (equal (heks-ert--count ".hl-" css) 2))
    ;; A face that says nothing about a colour inherits the text's.
    (should (string-match-p "\\.hl-heks-ert-plain-face { *}" css))))

(ert-deftest heks-emacs-render/the-palette-has-the-colours-a-page-needs ()
  (let ((palette (heks-emacs-render-palette)))
    (dolist (key '(:background :foreground :surface :border :muted :accent))
      (should (stringp (plist-get palette key))))))

;;
;; ====== Where a deck's slides are ======
;;

(ert-deftest heks-emacs-present/markdown-divides-on-a-line-of-dashes ()
  (heks-ert--with-file ".md" "# One\n\nA\n\n---\n\n# Two\n\nB\n"
    (should (equal (heks-emacs-present-format) 'markdown))
    (should (equal (length (heks-emacs-present-slides)) 2))
    (should (string-prefix-p "# One" (car (heks-emacs-present-slides))))))

(ert-deftest heks-emacs-present/markdown-without-a-break-is-one-slide ()
  (heks-ert--with-file ".md" "# Only\n\nOne section.\n"
    (should (equal (length (heks-emacs-present-slides)) 1))))

(ert-deftest heks-emacs-present/org-divides-on-its-own-headings ()
  (with-temp-buffer
    (insert "* One\nA\n\n* Two\nB\n\n* Three\nC\n")
    (org-mode)
    (should (equal (heks-emacs-present-format) 'org))
    (should (equal (length (heks-emacs-present-slides)) 3))
    (should (string-prefix-p "* One" (car (heks-emacs-present-slides))))))

(ert-deftest heks-emacs-present/org-slides-are-the-level-that-repeats ()
  "One `*' title over several `**' sections means the sections are the slides.

What comes before the first section -- the file's own `#+' lines and its
title -- is the first slide, because a talk does open with its title."
  (with-temp-buffer
    (insert "#+title: Talk\n\n* The title\n\n** One\nA\n\n** Two\nB\n")
    (org-mode)
    (should (equal (heks-emacs-present--org-level (buffer-string)) 2))
    (let ((slides (heks-emacs-present-slides)))
      (should (equal (length slides) 3))
      (should (string-prefix-p "#+title: Talk" (car slides)))
      (should (string-prefix-p "** One" (nth 1 slides)))
      (should (string-prefix-p "** Two" (nth 2 slides))))))

(ert-deftest heks-emacs-present/a-buffer-that-is-not-a-document-has-no-slides ()
  (with-temp-buffer
    (insert "just some text\n")
    (should-not (heks-emacs-present-format))
    (should-not (heks-emacs-present-slides))
    (should-error (heks-emacs-present-deck-html) :type 'user-error)))

(ert-deftest heks-emacs-present/an-empty-document-has-no-slides ()
  (heks-ert--with-file ".md" ""
    (should-error (heks-emacs-present-deck-html) :type 'user-error)))

;;
;; ====== The deck ======
;;

(ert-deftest heks-emacs-present/deck-is-one-section-per-slide ()
  (heks-ert--with-file ".md" "# One\n\nA\n\n---\n\n# Two\n\nB\n\n---\n\n# Three\n\nC\n"
    (let ((deck (heks-emacs-present-deck-html)))
      (should (equal (heks-ert--count "<section class=\"slide\"" deck) 3))
      (should (equal (heks-ert--count "</section>" deck) 3))
      (should (string-match-p "<title>" deck)))))

(ert-deftest heks-emacs-present/a-deck-of-an-org-note-is-made-too ()
  "A deck is not a Markdown thing: an Org note is exported slide by slide,
which is a different way of reading the same document."
  (with-temp-buffer
    (insert (concat "#+title: Talk\n\n* The title\n\n"
                    "** One\nA paragraph.\n\n"
                    "** Two\nB paragraph.\n"))
    (org-mode)
    (let ((deck (heks-emacs-present-deck-html)))
      (should (equal (heks-ert--count "<section class=\"slide\"" deck) 3))
      (should (string-match-p "A paragraph." deck))
      (should (string-match-p "B paragraph." deck)))))

(ert-deftest heks-emacs-present/deck-walks-its-slides-with-the-keyboard ()
  (heks-ert--with-file ".md" "# One\n\nA\n\n---\n\n# Two\n\nB\n"
    (let ((deck (heks-emacs-present-deck-html)))
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

(ert-deftest heks-emacs-present/a-deck-prints-one-slide-per-page ()
  (heks-ert--with-file ".md" "# One\n\nA\n\n---\n\n# Two\n\nB\n"
    (let ((deck (heks-emacs-present-deck-html)))
      (should (string-match-p "@page" deck))
      (should (string-match-p "break-after: page" deck))
      (should (string-match-p "page-break-after: always" deck)))))

(ert-deftest heks-emacs-present/a-deck-carries-its-own-stylesheet-and-script ()
  "Nothing a deck needs is fetched: it opens from a file:// URL."
  (heks-ert--with-file ".md" "# One\n\nA\n"
    (let ((deck (heks-emacs-present-deck-html)))
      (should (string-match-p "<style>" deck))
      (should (string-match-p "<script>" deck))
      (should-not (string-match-p "src=\"http" deck))
      (should-not (string-match-p "href=\"http" deck)))))

(ert-deftest heks-emacs-present/the-deck-of-a-file-is-written-beside-it ()
  (heks-ert--with-file ".md" "# One\n\nA\n\n---\n\n# Two\n\nB\n"
    (let* ((source (buffer-file-name))
           (target (concat (file-name-sans-extension source) ".deck.html")))
      (should (equal (heks-emacs-present-deck-export) target))
      (should (file-exists-p target))
      (with-temp-buffer
        (insert-file-contents target)
        (should (string-match-p "<section class=\"slide\"" (buffer-string)))))))

(ert-deftest heks-emacs-present/a-slide-boundary-is-inserted-in-the-documents-own-way ()
  (heks-ert--with-file ".md" "# One\n\nA\n"
    (goto-char (point-max))
    (heks-emacs-present-insert-slide)
    (should (string-match-p "^---$" (buffer-string))))
  (with-temp-buffer
    (insert (concat "#+title: Talk\n\n* The title\n\n"
                    "** One\nA\n\n** Two\nB\n"))
    (org-mode)
    (goto-char (point-max))
    (heks-emacs-present-insert-slide)
    (should (string-match-p "^\\*\\* $" (buffer-string))))
  (with-temp-buffer
    (insert "text\n")
    (should-error (heks-emacs-present-insert-slide) :type 'user-error)))

;;
;; ====== The preview ======
;;

(ert-deftest heks-emacs-preview/the-document-is-shown-in-a-buffer-that-survives ()
  "EWW renders the document into the preview buffer, and it is still there
afterwards.

`eww-render' kills the buffer it is *called from*, because it is the
callback of a retrieval and that buffer is the retrieval's own; a preview
that renders from its own destination buffer is left holding a dead one,
and the document that was rendered is gone with it."
  (heks-ert--with-file ".md" "# Title\n\nSome text.\n"
    (let ((heks-emacs-preview-buffer-name "*heks-ert preview*"))
      (unwind-protect
          (progn
            (heks-emacs-preview)
            (let ((shown (get-buffer heks-emacs-preview-buffer-name)))
              (should (buffer-live-p shown))
              (with-current-buffer shown
                (should (eq major-mode 'eww-mode)))
              (should (string-match-p "Some text\\." (heks-ert--text shown)))))
        (when (get-buffer heks-emacs-preview-buffer-name)
          (kill-buffer heks-emacs-preview-buffer-name))))))

(ert-deftest heks-emacs-preview/rendering-it-again-shows-what-the-buffer-says-now ()
  "The preview follows its buffer: the same call renders the current text."
  (heks-ert--with-file ".md" "# One\n\nfirst\n"
    (let ((source (current-buffer))
          (heks-emacs-preview-buffer-name "*heks-ert preview*"))
      (unwind-protect
          (progn
            (heks-emacs-preview)
            (with-current-buffer source
              (goto-char (point-max))
              (insert "\nsecond paragraph\n")
              (heks-emacs-render-file source)
              (should (heks-emacs-preview--reload source)))
            (should (string-match-p "second paragraph"
                                    (heks-ert--text heks-emacs-preview-buffer-name))))
        (when (get-buffer heks-emacs-preview-buffer-name)
          (kill-buffer heks-emacs-preview-buffer-name))))))

;;
;; ====== Where the notes are ======
;;

(ert-deftest heks-emacs-notes/a-directory-nobody-set-is-not-a-directory ()
  "A setting that was never given a value cannot be turned into a path.

This is what naming org-roam's notes directory after nothing used to do:
`file-truename' of nil stops the configuration where it is loaded."
  (dolist (unset '(nil "" "   "))
    (let ((heks-emacs-notes-roam-dir unset))
      (should-not (heks-emacs-notes-roam-directory)))))

(ert-deftest heks-emacs-notes/a-directory-that-is-set-is-answered-expanded ()
  (dolist (written '("~/Hacking/private-notes" "$HOME/Hacking/private-notes"))
    (let* ((heks-emacs-notes-roam-dir written)
           (directory (heks-emacs-notes-roam-directory)))
      (should (stringp directory))
      (should (string-suffix-p "private-notes" directory))
      (should (string-prefix-p (file-truename (expand-file-name "~")) directory)))))

;;
;; ====== The JVM build tools ======
;;

(ert-deftest heks-emacs-jvm/the-same-goal-has-a-name-in-each-build-tool ()
  (should (equal (heks-emacs-jvm-goal-for "test" 'maven) "test"))
  (should (equal (heks-emacs-jvm-goal-for "package" 'maven) "package"))
  (should (equal (heks-emacs-jvm-goal-for "package" 'gradle) "assemble"))
  (should (equal (heks-emacs-jvm-goal-for "verify" 'gradle) "check"))
  (should (equal (heks-emacs-jvm-goal-for "dependencies" 'maven) "dependency:tree")))

(ert-deftest heks-emacs-jvm/a-goal-nobody-defined-is-refused ()
  (should-error (heks-emacs-jvm-goal-for "nosuchgoal" 'maven) :type 'user-error))

(ert-deftest heks-emacs-jvm/what-is-offered-is-what-the-table-says ()
  (dolist (entry heks-emacs-jvm-goals)
    (should (equal (length entry) 4))
    (should (assoc (car entry) (heks-emacs-jvm--read-table) #'equal))
    ;; What is read out of the menu is a goal the table can answer for.
    (should (stringp (heks-emacs-jvm-goal-for (car entry) 'gradle)))))

(ert-deftest heks-emacs-jvm/the-project-is-the-nearest-one ()
  "A Maven project being migrated to Gradle is two projects at once."
  (let* ((root (heks-ert--temp-directory))
         (inner (expand-file-name "service/" root)))
    (unwind-protect
        (progn
          (make-directory inner t)
          (write-region "" nil (expand-file-name "pom.xml" root) nil 'silent)
          (write-region "" nil (expand-file-name "build.gradle.kts" inner) nil 'silent)
          (heks-ert--in root
            (should (eq (car (heks-emacs-jvm--project)) 'maven)))
          (heks-ert--in inner
            (should (eq (car (heks-emacs-jvm--project)) 'gradle))))
      (delete-directory root t))))

(ert-deftest heks-emacs-jvm/a-directory-that-is-no-project-says-so ()
  (let ((root (heks-ert--temp-directory)))
    (unwind-protect
        (heks-ert--in root
          (should-not (heks-emacs-jvm--project)))
      (delete-directory root t))))

(ert-deftest heks-emacs-jvm/a-wrapper-is-preferred-to-a-system-program ()
  (let* ((root (heks-ert--temp-directory))
         (wrapper (expand-file-name "mvnw" root)))
    (unwind-protect
        (progn
          (write-region "#!/bin/sh\n" nil wrapper nil 'silent)
          (set-file-modes wrapper #o755)
          (should (equal (heks-emacs--jvm-build-program root "mvnw" "mvn") wrapper))
          (set-file-modes wrapper #o644)
          ;; Not executable, so not the wrapper.
          (should (equal (heks-emacs--jvm-build-program root "mvnw" "mvn") "mvn")))
      (delete-directory root t))))

(ert-deftest heks-emacs-jvm/the-build-file-is-found-above-the-buffer ()
  (let* ((root (heks-ert--temp-directory))
         (inner (expand-file-name "a/b/" root)))
    (unwind-protect
        (progn
          (make-directory inner t)
          (write-region "" nil (expand-file-name "pom.xml" root) nil 'silent)
          (heks-ert--in inner
            (should (equal (file-name-as-directory (heks-emacs--locate-project-file "pom.xml"))
                           (file-name-as-directory root))))
          ;; Above the directory holding it there is nothing.
          (heks-ert--in "/"
            (should-not (heks-emacs--locate-project-file "heks-emacs-no-such-file"))))
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

(ert-deftest heks-emacs-format/a-language-of-its-own-answers-first ()
  "A module teaches the one key a formatter by adding a predicate."
  (let ((heks-ert-format-ran nil)
        (heks-emacs-format-dispatch
         (list (cons (lambda () t) #'heks-ert-format-something))))
    (with-temp-buffer
      (heks-emacs-format-buffer)
      (should heks-ert-format-ran))))

(ert-deftest heks-emacs-format/a-predicate-that-does-not-hold-is-passed-over ()
  "The dispatcher asks every formatter in turn, and only the one that
answers is the one that formats."
  (let ((heks-ert-format-ran nil)
        (heks-emacs-format-dispatch (list (cons (lambda () nil) #'heks-ert-format-something))))
    (with-temp-buffer
      (fundamental-mode)
      ;; What is left after the language's own formatter -- Eglot, then
      ;; `format-all' -- depends on what this machine has installed, and
      ;; saying so is the point of the refusal when it has neither.
      (if (fboundp 'format-all-region-or-buffer)
          (ignore-errors (heks-emacs-format-buffer))
        (should-error (heks-emacs-format-buffer) :type 'user-error)))
    (should-not heks-ert-format-ran)))

;;
;; ====== Terraform ======
;;

(ert-deftest heks-emacs-terraform/the-commands-say-so-when-there-is-no-terraform ()
  (skip-unless (not (executable-find terraform-command)))
  (let ((root (heks-ert--temp-directory)))
    (unwind-protect
        (heks-ert--in root
          (should-error (heks-emacs-terraform-run "plan") :type 'user-error))
      (delete-directory root t))))

(ert-deftest heks-emacs-terraform/the-configuration-is-the-directory-of-the-file ()
  (let* ((root (heks-ert--temp-directory))
         (file (expand-file-name "main.tf" root)))
    (unwind-protect
        (progn
          (write-region "" nil file nil 'silent)
          (with-current-buffer (find-file-noselect file)
            (unwind-protect
                (should (equal (file-name-as-directory (heks-emacs-terraform-root))
                               (file-name-as-directory root)))
              (set-buffer-modified-p nil)
              (kill-buffer))))
      (delete-directory root t))))

;;
;; ====== Shell scripts ======
;;

(ert-deftest heks-emacs-shell/shellcheck-is-told-to-follow-the-sources-of-a-script ()
  "Emacs runs shellcheck itself (`sh-shellcheck-flymake'); what this
configuration says to it is that the files a script sources are part of
what is checked, rather than a note on every `source' line."
  (require 'sh-script)
  (should (member "--external-sources" sh-shellcheck-arguments)))

(ert-deftest heks-emacs-shell/a-copy-keeps-the-extension-of-the-file ()
  "shfmt and shellcheck read the dialect from the name too."
  (with-temp-buffer
    (setq-local buffer-file-name "/tmp/heks-ert/one/script.bash")
    (should (equal (heks-emacs-shell-copy-suffix) ".bash")))
  (with-temp-buffer
    (should (equal (heks-emacs-shell-copy-suffix) ".sh"))))

(ert-deftest heks-emacs-shell/shfmt-arguments-come-before-the-file ()
  (let ((heks-emacs-shfmt-arguments '("-i" "2")))
    (should (equal (heks-emacs-shfmt-command "/tmp/a.sh")
                   (list (heks-emacs-tool-path heks-emacs-shfmt-program)
                         "-w" "-i" "2" "/tmp/a.sh")))))


(ert-deftest heks-emacs-shell/both-of-the-modes-of-a-script-are-shell-buffers ()
  (with-temp-buffer
    (sh-mode)
    (should (heks-emacs-shell-buffer-p)))
  ;; The other mode a `.sh' file opens in.  It is not run here -- the
  ;; Tree-sitter parser is not what is being tested -- only recognised.
  (with-temp-buffer
    (setq major-mode 'bash-ts-mode)
    (should (heks-emacs-shell-buffer-p)))
  (with-temp-buffer
    (fundamental-mode)
    (should-not (heks-emacs-shell-buffer-p))))

;;
;; ====== A language server and the checkers of a buffer ======
;;
;; Eglot replaces `flymake-diagnostic-functions' with a list of its own
;; backend alone while it manages a buffer; one function of `dev.el' puts
;; back what the buffer had.  The swap below is made with the macro Eglot's
;; own mode is written with, so what is read is Eglot's behaviour rather
;; than a list this file made up: if Eglot stops keeping the old value where
;; `heks-emacs-flymake-keep-backends' reads it, these tests fail instead of
;; quietly leaving a buffer checked by its server alone.

(ert-deftest heks-emacs-flymake/a-server-does-not-take-the-checkers-of-a-buffer ()
  "Whatever checked a buffer before a server manages it checks it still."
  (require 'eglot)
  (with-temp-buffer
    (setq-local flymake-diagnostic-functions
                '(python-flymake sh-shellcheck-flymake heks-emacs-shfmt-backend))
    (eval '(eglot--setq-saving flymake-diagnostic-functions
                               '(eglot-flymake-backend))
          t)
    (should (equal flymake-diagnostic-functions '(eglot-flymake-backend)))
    (setq-local eglot--managed-mode t)
    (heks-emacs-flymake-keep-backends)
    ;; The buffer is one Flymake is not on in, so being asked to check it --
    ;; which is the other half of what the call above does -- does nothing.
    (should (memq 'eglot-flymake-backend flymake-diagnostic-functions))
    (should (memq 'python-flymake flymake-diagnostic-functions))
    (should (memq 'sh-shellcheck-flymake flymake-diagnostic-functions))
    (should (memq 'heks-emacs-shfmt-backend flymake-diagnostic-functions))))

(ert-deftest heks-emacs-flymake/a-buffer-no-server-manages-keeps-what-it-has ()
  (require 'eglot)
  (with-temp-buffer
    (setq-local flymake-diagnostic-functions '(python-flymake))
    (heks-emacs-flymake-keep-backends)
    (should (equal flymake-diagnostic-functions '(python-flymake)))))

;;
;; ====== What a Scheme definition looks like, and where it is ======
;;

(ert-deftest heks-emacs-scheme/a-definition-is-the-head-and-not-a-mention ()
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
    (should (equal (and (heks-emacs-scheme-definition-line-p (nth 0 case) (nth 1 case)) t)
                   (nth 2 case)))))

(ert-deftest heks-emacs-scheme/the-column-is-where-the-name-is-defined ()
  "The jump lands on the name being defined, not on the name first seen."
  (should (equal (heks-emacs-scheme-definition-column "(define (greet name) name)" "greet") 9))
  (should (equal (heks-emacs-scheme-definition-column "(define-public pub-var 1)" "pub-var") 15)))

(ert-deftest heks-emacs-scheme/the-files-answer-with-the-definitions ()
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
                                    (heks-emacs-scheme-definitions-in-files "greet"))
                                   '(("utility.scm" 1))))
                    (should (equal (heks-ert--xref-locations
                                    (heks-emacs-scheme-definitions-in-files "pub-var"))
                                   '(("main.scm" 3))))
                    ;; Defined in both: the file being read comes first.
                    (should (equal (heks-ert--xref-locations
                                    (heks-emacs-scheme-definitions-in-files "twice"))
                                   '(("main.scm" 4) ("utility.scm" 3))))
                    (should-not (heks-emacs-scheme-definitions-in-files "no-such-name")))
                (set-buffer-modified-p nil)
                (kill-buffer))))
      (delete-directory root t)))))

(ert-deftest heks-emacs-scheme/the-backend-answers-for-a-scheme-buffer-alone ()
  "The backend of this module is the one a Scheme buffer is jumped with.

`xref' takes the first function of `xref-backend-functions' that answers,
so what makes `M-.' a Scheme jump is this function saying
`heks-emacs-scheme' in a Scheme buffer -- and saying nothing in a buffer
that is not one, where the backends the rest of the configuration has
should still answer."
  (with-temp-buffer
    (scheme-mode)
    (should (eq (heks-emacs-scheme-xref-backend) 'heks-emacs-scheme)))
  (with-temp-buffer
    (emacs-lisp-mode)
    (should-not (heks-emacs-scheme-xref-backend))))

(ert-deftest heks-emacs-scheme/the-repl-is-asked-before-the-files ()
  "A jump asks the REPL, then the files, then the wider search.

What the REPL says is the answer when it has one; where it has none -- or
where what it says is a module rather than a definition in a file -- the
files are asked, and where the files have nothing the search the rest of
the configuration gives a buffer is asked last (see `dev.el').  Each of
the four is stubbed, so what is checked is the order they are asked in
rather than what they answer with."
  (let ((asked '()))
    (cl-letf (((symbol-function 'heks-emacs-scheme--repl-definition)
               (lambda (_) (push 'repl asked) nil))
              ((symbol-function 'heks-emacs-scheme--repl-module)
               (lambda (_) (push 'module asked) nil))
              ((symbol-function 'heks-emacs-scheme-definitions-in-files)
               (lambda (_) (push 'files asked) nil))
              ((symbol-function 'heks-emacs-scheme--dumb-jump)
               (lambda (_) (push 'dumb-jump asked) 'the-wider-answer)))
      (should (eq (xref-backend-definitions 'heks-emacs-scheme "greet")
                  'the-wider-answer)))
    (should (equal (nreverse asked) '(repl module files dumb-jump)))))

(ert-deftest heks-emacs-scheme/the-repl-says-a-line-and-the-column-is-read ()
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
            (let* ((xref (heks-emacs-scheme--location-xref
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
                               (heks-emacs-scheme--location-xref
                                `(("file" . ,file) ("line" . 5)) "greet")))
                             5))
              (should-not (heks-emacs-scheme--location-xref
                           '(("file" . "/no/such/file.scm") ("line" . 1))
                           "greet")))))
      (delete-directory root t)))

(ert-deftest heks-emacs-scheme/a-mention-is-a-name-of-its-own ()
  "A name is mentioned where it is written as a name.

`greet' is not mentioned by `greeting' or by `greet-and-run', and it is
mentioned by `greet?' -- which a word boundary cannot say, because `1+',
`string-append' and `set-x!' are names that a word boundary falls in the
middle of."
  (should (heks-emacs-scheme-mention-line-p "(greet name)" "greet"))
  (should (heks-emacs-scheme-mention-line-p "  greet" "greet"))
  (should-not (heks-emacs-scheme-mention-line-p "(greeting)" "greet"))
  (should-not (heks-emacs-scheme-mention-line-p "(greet-and-run)" "greet"))
  (should (heks-emacs-scheme-mention-line-p "(greet? x)" "greet?"))
  (should-not (heks-emacs-scheme-mention-line-p "(greet? x)" "greet"))
  (should-not (heks-emacs-scheme-mention-line-p "(string-append a b)" "append"))
  (should (heks-emacs-scheme-mention-line-p "(set-x! v)" "set-x!"))
  (should-not (heks-emacs-scheme-mention-line-p "1+" "1"))
  (should (heks-emacs-scheme-mention-line-p "(let ((a 1+)) 1+)" "1+")))

(ert-deftest heks-emacs-scheme/the-names-the-files-define-are-what-is-asked-for ()
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
                  (should (equal (heks-emacs-scheme-defined-names)
                                 '("greet" "main" "pub-var" "twice")))
                (set-buffer-modified-p nil)
                (kill-buffer))))
      (delete-directory root t)))))

(ert-deftest heks-emacs-scheme/the-names-are-read-once-and-remembered ()
  "The search behind the prompt is not made twice in the same minute.

The names a project defines are what `M-.' completes from, so they are
asked for every time a jump is asked for, and reading them is a search of
every Scheme file of the project.  The answer is remembered by the
directory it was read from and by its age: the second question is answered
from it, a question about another directory is not, and neither is one
asked after the lifetime has passed."
  (let ((asked 0)
        (heks-emacs-scheme--defined-names-cache nil))
    (cl-letf (((symbol-function 'heks-emacs-scheme--search-files)
               (lambda (&rest _) (setq asked (1+ asked)) nil))
              ((symbol-function 'heks-emacs-scheme-load-path)
               (lambda () temporary-file-directory)))
      (should-not (heks-emacs-scheme-defined-names))
      (should-not (heks-emacs-scheme-defined-names))
      (should (equal asked 1))
      ;; Another project, read from another directory, is a new question.
      (let ((temporary-file-directory (file-name-as-directory
                                       (heks-ert--temp-directory))))
        (unwind-protect
            (progn
              (heks-emacs-scheme-defined-names)
              (should (equal asked 2)))
          (delete-directory temporary-file-directory t)))
      ;; And so is the same project once the answer has gone stale.
      (let ((heks-emacs-scheme-defined-names-lifetime -1))
        (heks-emacs-scheme-defined-names)
        (should (equal asked 3))))))

(ert-deftest heks-emacs-scheme/the-places-a-name-is-used-are-found-in-the-files ()
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
                                    (heks-emacs-scheme-mentions-in-files "greet"))
                                   '(("main.scm" 2) ("main.scm" 3) ("utility.scm" 1))))
                    (should-not (heks-emacs-scheme-mentions-in-files "no-such-name")))
                (set-buffer-modified-p nil)
                (kill-buffer))))
      (delete-directory root t)))))

(ert-deftest heks-emacs-scheme/no-repl-is-a-question-the-repl-answers-with-nil ()
  "A buffer with no REPL says so rather than starting one."
  (cl-letf (((symbol-function 'heks-emacs-scheme-repl-connected-p) (lambda () nil))
            ((symbol-function 'geiser-edit-symbol-location)
             (lambda (_) (error "The REPL was asked although there is none")))
            ((symbol-function 'geiser-eval--send/result)
             (lambda (_) (error "The REPL was asked although there is none"))))
    (should-not (heks-emacs-scheme--repl-definition "greet"))
    (should-not (heks-emacs-scheme--repl-callers "greet"))
    (should-not (heks-emacs-scheme-repl-connected-p))))

;;
;; ====== Dired ======
;;

(ert-deftest heks-emacs-dired/the-contents-of-the-marked-files-are-copied ()
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

(ert-deftest heks-emacs-keys/every-topic-letter-is-a-key-and-means-one-thing ()
  (let (seen)
    (dolist (topic heks-emacs-key-topics)
      (should (stringp (car topic)))
      (should (stringp (cdr topic)))
      (should (not (string-empty-p (cdr topic))))
      ;; A topic has to be a key sequence Emacs can read.
      (should (kbd (concat "C-c " (car topic))))
      (should-not (member (car topic) seen))
      (push (car topic) seen))))

(ert-deftest heks-emacs-keys/the-action-alphabet-has-no-duplicates ()
  (let (seen)
    (dolist (action heks-emacs-key-actions)
      (should (stringp (cdr action)))
      (should-not (member (car action) seen))
      (push (car action) seen))))

(ert-deftest heks-emacs-keys/every-key-is-described-once ()
  (let (seen)
    (dolist (entry heks-emacs-key-descriptions)
      (should (string-prefix-p "C-c " (car entry)))
      (should (stringp (cdr entry)))
      (should (not (string-empty-p (cdr entry))))
      (should-not (member (car entry) seen))
      (push (car entry) seen))))

(ert-deftest heks-emacs-keys/a-topic-letters-are-letters ()
  (dolist (topic heks-emacs-key-letters)
    (should (assoc (car topic) heks-emacs-key-topics #'equal))
    (dolist (letter (cdr topic))
      (should (string-match-p "\\`[[:alpha:]]\\'" (car letter)))
      (should (stringp (cdr letter))))))

(ert-deftest heks-emacs-keys/a-description-is-found-for-what-the-tables-hold ()
  "The lookup the reference and `which-key' both read is one function."
  (should (equal (heks-emacs-key-description "C-c i f")
                 "the buffer, formatted by whoever knows how"))
  ;; A topic's own letter, when the key has no description of its own.
  (should (equal (heks-emacs-key-description "C-c f t") "tiny"))
  ;; An action letter, under a topic that says nothing of its own about it.
  (should (equal (heks-emacs-key-description "C-c s c")
                 "the snippet at point, completed"))
  ;; A key whose last stroke is not a letter is what its topic is for.
  (should (equal (heks-emacs-key-description "C-c C-d z")
                 "diagrams: Mermaid")))

;;
;; ====== The tree-sitter grammars ======
;;

(ert-deftest heks-emacs-treesit/the-grammars-are-built-by-a-batch-emacs ()
  "The grammars are built by a child Emacs that is handed what it needs.

The child is a batch Emacs and nothing else -- no configuration to load, no
packages to install first -- so the directory, the recipes this
configuration names itself and the directories a grammar may already be in
are given to it as Lisp it is told before the script is loaded."
  (let* ((command (heks-emacs-treesit--batch-command))
         (form (read (nth 4 command))))
    (should (equal (nth 1 command) "-Q"))
    (should (equal (nth 2 command) "--batch"))
    (should (equal (nth 3 command) "--eval"))
    (should (equal (nth 5 command) "-l"))
    (should (equal (nth 6 command) heks-emacs-treesit-script))
    (should (eq (car form) 'setq))
    (should (equal (nth 1 form) 'heks-emacs-treesit-grammar-directory))
    (should (equal (nth 2 form) heks-emacs-treesit-grammar-directory))
    (should (equal (nth 3 form) 'heks-emacs-treesit-own-recipes))
    (should (equal (nth 5 form) 'treesit-extra-load-path))))

(ert-deftest heks-emacs-treesit/the-grammars-are-installed-where-told-to ()
  "The directory is the one this configuration installs and looks in."
  (should (equal (file-name-nondirectory
                  (directory-file-name heks-emacs-treesit-grammar-directory))
                 "tree-sitter"))
  (should (string-prefix-p (file-name-as-directory (expand-file-name "~/.emacs.d"))
                           (file-name-as-directory
                            heks-emacs-treesit-grammar-directory))))

(ert-deftest heks-emacs-treesit/the-script-builds-the-grammars-emacs-knows ()
  "The script asks for the grammar of every mode Emacs ships, and for ours.

It is loaded here with the installing stubbed out -- nothing in a test has a
network -- and with every grammar reported as missing, so what it would
build is what is checked: Emacs's own recipes come from its own mode files,
which is why the languages Emacs has modes for are in the answer at all."
  (let ((asked nil)
        (heks-emacs-treesit-grammar-directory "/tmp/heks-ert-grammars")
        (heks-emacs-treesit-own-recipes '((heks-ert-own "https://example.com/own"))))
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

(ert-deftest heks-emacs-treesit/a-grammar-that-is-here-is-not-built-again ()
  "What is installed is not cloned and compiled a second time."
  (let ((asked nil)
        (heks-emacs-treesit-grammar-directory "/tmp/heks-ert-grammars"))
    (cl-letf (((symbol-function 'treesit-language-available-p)
               (lambda (language &rest _) (eq language 'java)))
              ((symbol-function 'treesit-install-language-grammar)
               (lambda (language &optional _directory) (push language asked))))
      (load (expand-file-name "treesit-grammars" heks-ert--source) nil t))
    (should-not (memq 'java asked))
    (should (memq 'python asked))))

(ert-deftest heks-emacs-treesit/a-grammar-that-fails-once-is-built-on-the-second-try ()
  "A clone that timed out, or a checkout that was busy, is not a verdict.

What is reported is a grammar that would not build twice, so a language
that fails and then works is built, in the same run, and said to have
taken a second attempt rather than reported as one this machine cannot
build."
  (let ((attempts 0)
        (built nil)
        (heks-emacs-treesit-grammar-directory "/tmp/heks-ert-grammars"))
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
    (should (equal attempts heks-emacs-treesit-attempts))))

(ert-deftest heks-emacs-treesit/a-build-that-produces-nothing-is-not-a-grammar ()
  "A build that returns for a library that cannot be loaded is a failure.

Emacs warns rather than errors when the library it built cannot be found or
loaded, so counting the return of the build as success would report a
grammar as built that no mode can use -- and would leave it unbuilt for
ever, since the next run would find it missing and try again from scratch."
  (let ((asked nil)
        (heks-emacs-treesit-grammar-directory "/tmp/heks-ert-grammars"))
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
                     heks-emacs-treesit-attempts)))))

(ert-deftest heks-emacs-treesit/a-grammar-that-will-not-build-does-not-stop-the-others ()
  "One language failing is a line of output, not the end of the run."
  (let ((asked nil)
        (heks-emacs-treesit-grammar-directory "/tmp/heks-ert-grammars"))
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
                   heks-emacs-treesit-attempts))
    (should (memq 'python asked))
    (should (memq 'cpp asked))))

(ert-deftest heks-emacs-which-key/the-scheme-is-what-which-key-shows ()
  (skip-unless (and (featurep 'which-key) (fboundp 'heks-emacs-which-key-setup)))
  (let ((before (length which-key-replacement-alist)))
    (heks-emacs-which-key-setup)
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

(ert-deftest heks-emacs-which-key/a-mode-that-answers-first-says-its-own-wording ()
  "A key a mode owns is described for that mode, in the mode's own words."
  (skip-unless (and (featurep 'which-key) (fboundp 'heks-emacs-which-key-setup)))
  (heks-emacs-which-key-setup)
  ;; A mode's own table is keyed by the pattern `which-key' stores, not by
  ;; the key: the pattern is what it matches a key being typed against.
  (let* ((replacements (cdr (assq 'java-mode which-key-replacement-alist)))
         (described (cddr (seq-find (lambda (entry)
                                      (string-match-p (regexp-quote "C-c j t")
                                                      (car (car entry))))
                                    replacements))))
    (should replacements)
    (should (equal described "the test at point, through the language server"))))

(ert-deftest heks-emacs-which-key/no-sentence-of-the-scheme-is-cut ()
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
  (let ((which-key-max-description-length heks-emacs-which-key-description-length)
        (cut '()))
    (dolist (text (heks-emacs-key-description-texts))
      (let ((cell (concat which-key-prefix-prefix text)))
        (unless (equal (which-key--truncate-description cell 80) cell)
          (push text cut))))
    (should (equal cut '())))
  (should (member heks-emacs-key-root-description (heks-emacs-key-description-texts))))

;;
;; Run.
;;

(unless (getenv "HEKS_ERT_NO_RUN")
  (ert-run-tests-batch-and-exit))

;;; heks-emacs-ert.el ends here
