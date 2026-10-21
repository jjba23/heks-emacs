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
                 "dev-langs" "dev-tools" "dev-flymake" "dev-formats" "dev-kubernetes" "dev-folding" "dev-project" "openapi" "shell" "guile" "ui" "ai"))
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
;; backend alone while it manages a buffer; one function of `dev-flymake.el' puts
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
the configuration gives a buffer is asked last (see `dev-flymake.el').  Each of
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

(ert-deftest heks-emacs-scheme/the-repls-false-is-no-answer-at-all ()
  "A `#f' from Guile is not a place, whichever question it answers.

Guile answers `#f' for a symbol it has and cannot place -- a procedure
written in C, whose module it knows and whose file it does not -- and the
`#f' of such an answer comes back through Geiser as the keyword `:f'
rather than as nothing at all.  So what is a place is what Geiser's own
jump reads as one (`geiser-edit--try-edit'): a list, and anything else is
no answer, read in the one function that reads a location
(`heks-emacs-scheme--location-p') so that every question that carries one
-- a definition, a module, the places a name is called from -- is answered
without a stop."
  (should-not (heks-emacs-scheme--location-p :f))
  (should-not (heks-emacs-scheme--location-p nil))
  (should (equal (heks-emacs-scheme--location-p '(("file" . "/tmp/x"))) '(("file" . "/tmp/x"))))
  (should-not (heks-emacs-scheme--location-xref :f "string->number"))
  (cl-letf (((symbol-function 'heks-emacs-scheme-repl-connected-p) (lambda () t))
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
    (should-not (heks-emacs-scheme--repl-definition "string->number"))
    (should-not (heks-emacs-scheme--repl-module "string->number"))
    ;; A caller whose place Guile has as `#f' is dropped, not read as one.
    (should-not (heks-emacs-scheme--repl-callers "greet"))))

(ert-deftest heks-emacs-scheme/a-head-says-which-name-it-defines ()
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
    (should (equal (heks-emacs-scheme-definition-name (nth 0 case)) (nth 1 case)))))

(ert-deftest heks-emacs-scheme/the-files-answer-with-the-definitions-that-match ()
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
                                           (heks-emacs-scheme-definitions-in-files-matching
                                            "greet"))
                                   '("greet" "greeting")))
                    (should (equal (heks-ert--xref-locations
                                    (mapcar #'cdr
                                            (heks-emacs-scheme-definitions-in-files-matching
                                             "greet")))
                                   '(("utility.scm" 1) ("utility.scm" 3))))
                    ;; A pattern of words: all of them, in any order.
                    (should (equal (mapcar #'car
                                           (heks-emacs-scheme-definitions-in-files-matching
                                            "var pub"))
                                   '("pub-var")))
                    ;; A regexp, and the head as the line of the entry.
                    (let ((items (mapcar #'cdr
                                         (heks-emacs-scheme-definitions-in-files-matching
                                          "^pub-"))))
                      (should (equal (heks-ert--xref-locations items)
                                     '(("main.scm" 3))))
                      (should (equal (xref-item-summary (car items))
                                     "(define-public pub-var 1)"))
                      (should (equal (xref-file-location-column
                                      (xref-item-location (car items)))
                                     15)))
                    ;; A name no head defines is answered with nothing.
                    (should-not (heks-emacs-scheme-definitions-in-files-matching
                                 "no-such-name")))
                (set-buffer-modified-p nil)
                (kill-buffer))))
      (delete-directory root t)))))

(ert-deftest heks-emacs-scheme/the-repl-answers-with-the-names-it-has-loaded ()
  "The names of the REPL are asked of Guile, and read in Emacs.

What is asked is Guile's own question about the names it has -- the same
one Guile's `apropos' is built on -- named through the module it lives in
rather than imported, because the module a REPL is in is `(guile-user)' or
a project's own.  What comes back is read against the pattern here, so
that a question which is wider than the answer -- the first word of a list
of words, say -- still answers with the pattern's own names."
  (let ((asked nil)
        (names '("string-append" "string-append/shared" "string-copy")))
    (cl-letf (((symbol-function 'heks-emacs-scheme-repl-connected-p) (lambda () t))
              ((symbol-function 'geiser-eval--send/result)
               (lambda (question) (setq asked question) names)))
      (should (equal (heks-emacs-scheme--repl-names "string-append")
                     '("string-append" "string-append/shared")))
      (should (equal (cadr (nth 1 asked))
                     (concat "(sort (map symbol->string ((@ (ice-9 session) "
                             "apropos-internal) \"string-append\")) string<?)")))
      ;; A list of words is asked for by its first word, and the names are
      ;; read against all of them.
      (setq names '("pub-var" "public-name" "var-pub"))
      (should (equal (heks-emacs-scheme--repl-names "pub var")
                     '("pub-var" "var-pub")))
      (should (equal (cadr (nth 1 asked))
                     (concat "(sort (map symbol->string ((@ (ice-9 session) "
                             "apropos-internal) \"pub\")) string<?)"))))))

(ert-deftest heks-emacs-scheme/apropos-is-answered-by-both-sources-once-each ()
  "`M-s .' in a Scheme buffer is answered by the files and by the REPL.

The files' answer comes first, with the place each definition is in, and
the names the REPL has that no definition answered for follow it as names;
a name both sources have is one entry, because the files know where it is
and the REPL knows only that it has it."
  (cl-letf (((symbol-function 'heks-emacs-scheme-definitions-in-files-matching)
             (lambda (_pattern)
               (list (cons "greet"
                           (xref-make "(define (greet name)"
                                      (xref-make-file-location
                                       "/tmp/heks-greet.scm" 1 9))))))
            ((symbol-function 'heks-emacs-scheme--repl-names)
             (lambda (_pattern) '("greet" "greeting" "string-append"))))
    (let ((items (xref-backend-apropos 'heks-emacs-scheme "greet")))
      (should (equal (mapcar #'xref-item-summary items)
                     '("(define (greet name)" "greeting" "string-append")))
      (should (equal (mapcar (lambda (item)
                               (xref-location-group (xref-item-location item)))
                             items)
                     '("/tmp/heks-greet.scm" "the REPL" "the REPL"))))))

(ert-deftest heks-emacs-scheme/a-name-the-repl-knows-asks-it-where-it-is-when-jumped-to ()
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
          (cl-letf (((symbol-function 'heks-emacs-scheme--repl-definition)
                     (lambda (name)
                       (push name asked)
                       (when (equal name "greet")
                         (list (xref-make "greet"
                                          (xref-make-file-location file 1 0)))))))
            (let ((location (heks-emacs-scheme--repl-name "greet")))
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
                             (heks-emacs-scheme--repl-name "no-such-name"))
                            :type 'user-error)))
      (delete-directory root t)))))

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
    (should-not (heks-emacs-scheme--repl-names "greet"))
    (should-not (heks-emacs-scheme-repl-connected-p))))

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

(ert-deftest heks-emacs-import/the-heading-a-document-names-itself-with-is-its-title ()
  "The `# ...' a document opens with names the note, and is not repeated under it."
  (let ((metadata (heks-emacs-markdown-metadata "# Heks\n\ntext\n")))
    (should (equal (plist-get metadata :title) "Heks"))
    (should (equal (string-trim (plist-get metadata :body)) "text"))))

(ert-deftest heks-emacs-import/a-title-can-be-left-as-a-heading ()
  "With the setting off, every heading stays a heading."
  (let ((heks-emacs-import-title-from-heading nil))
    (should (equal (heks-emacs-markdown-to-org "# Heks\n\ntext\n")
                   "* Heks\n\ntext\n"))))

(ert-deftest heks-emacs-import/front-matter-is-what-the-note-says-about-itself ()
  "Title, tags, aliases and the fields this does not name are all kept."
  (let ((org (heks-emacs-markdown-to-org heks-ert-import-document
                                        '(("ID" . "an-id")
                                          ("ROAM_ALIASES" . "Things, stuff")))))
    (should (string-match-p "^#\\+title: A note$" org))
    (should (string-match-p "^#\\+filetags: :emacs:org_mode:$" org))
    (should (string-match-p "^#\\+author: Josep$" org))
    ;; A field this module knows nothing about is a keyword of its own name
    ;; rather than something dropped on the floor.
    (should (string-match-p "^#\\+permalink: /notes/a$" org))
    (should (string-match-p "^ *:ID: *an-id$" org))
    (should (string-match-p "^ *:ROAM_ALIASES: *Things, stuff$" org))
    ;; The drawer comes first, then the keywords, then the body: a drawer
    ;; Org reads as the file's properties is the first thing in the file
    ;; (`org-entry-get' finds the id there, and finds nothing when the
    ;; keywords come first), and the keywords belong to the note rather
    ;; than to the first section under it.
    (should (< (string-match ":PROPERTIES:" org) (string-match "#\\+title:" org)))
    (should (< (string-match ":END:" org) (string-match "^\\* Why$" org)))))

(ert-deftest heks-emacs-import/the-hierarchy-of-a-document-is-the-hierarchy-of-a-note ()
  "The headings left under the title are shifted up to be its sections."
  (let ((org (heks-emacs-markdown-to-org "# Title\n\n## One\n\n### Two\n\n#### Three\n")))
    (should (string-match-p "^\\* One$" org))
    (should (string-match-p "^\\*\\* Two$" org))
    (should (string-match-p "^\\*\\*\\* Three$" org))))

(ert-deftest heks-emacs-import/nothing-is-shifted-when-there-is-no-title ()
  "A document that names itself nowhere keeps its own depth."
  (let ((org (heks-emacs-markdown-to-org "## One\n\ntext\n")))
    (should (string-match-p "^\\* One$" org))))

(ert-deftest heks-emacs-import/a-block-that-says-it-is-not-a-heading-is-not-shifted ()
  "A line of a code block is a line of a code block, whatever it starts with."
  (let ((org (heks-emacs-markdown-to-org
              (concat "# Title\n\n```sh\n* not a headline\n** neither\n```\n"
                      "\n## Section\n"))))
    (should (string-match-p "^\\* not a headline$" org))
    (should (string-match-p "^\\*\\* neither$" org))
    (should (string-match-p "^\\* Section$" org))))

(ert-deftest heks-emacs-import/emphasis-links-and-images-become-org-markup ()
  "What Markdown says with markers, Org says with its own."
  (let ((org (heks-emacs-markdown-to-org
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

(ert-deftest heks-emacs-import/a-link-in-a-document-becomes-the-file-it-names ()
  "A relative link is resolved against the document's own directory."
  (let ((heks-emacs-markdown-base-directory "/home/someone/docs/"))
    (should (string-match-p "\\[\\[/home/someone/docs/img/a.png\\]\\[d\\]\\]"
                            (heks-emacs-markdown-to-org "![d](img/a.png)\n")))
    (should (string-match-p "\\[\\[https://example.com/x\\]\\[a\\]\\]"
                            (heks-emacs-markdown-to-org "[a](https://example.com/x)\n")))))

(ert-deftest heks-emacs-import/a-table-becomes-a-table-org-can-align ()
  "The columns keep the alignment their delimiter row gave them, and the
header row stays a header row."
  (let ((org (heks-emacs-markdown-to-org
              "| Name | Count |\n|:-----|------:|\n| a | 1 |\n")))
    ;; The delimiter row is what tells Org where the header ends, so it is
    ;; written as well as the alignment row rather than only as one, and a
    ;; row is padded to the column it is in, so that the rule under the
    ;; header is the width of what it rules.
    (should (equal org (concat "| Name | Count |\n"
                               "| <l>  | <r>   |\n"
                               "|------+-------|\n"
                               "| a    | 1     |\n")))))

(ert-deftest heks-emacs-import/a-checked-box-is-the-box-org-reads ()
  "Markdown checks a box with `[x]' and Org reads `[X]': the box is written
as the one Org reads, so that what was done stays done."
  (let ((org (heks-emacs-markdown-to-org
              "- [ ] one\n- [x] two\n- [X] three\n- [ ]done without a space\n")))
    (should (equal org (concat "- [ ] one\n"
                               "- [X] two\n"
                               "- [X] three\n"
                               ;; Not a box Org reads either, so it is left
                               ;; as the text a document made of it.
                               "- [ ]done without a space\n")))))

(ert-deftest heks-emacs-import/a-bullet-is-never-written-as-a-headline ()
  "Markdown's `*' bullet is Org's `-', which is what a headline is not."
  (should (equal (heks-emacs-markdown-to-org "* one\n* two\n")
                 "- one\n- two\n")))

(ert-deftest heks-emacs-import/the-blank-lines-a-document-has-separate-its-blocks ()
  "In Org a blank line decides what a block ends, so the import keeps them."
  (let ((org (heks-emacs-markdown-to-org "text\n\nmore text\n")))
    (should (equal org "text\n\nmore text\n"))))

(ert-deftest heks-emacs-import/a-fragment-keeps-its-headings-where-they-are ()
  "A piece of a document is not a note: no title is made of it, no heading moves."
  (should (equal (heks-emacs-markdown-fragment-to-org "# One\n\n## Two\n\ntext\n")
                 "* One\n\n** Two\n\ntext")))

(ert-deftest heks-emacs-import/a-fragment-says-things-the-way-a-note-does ()
  "Emphasis, code, links, lists and fences are spelled as they are in a note."
  (let ((org (heks-emacs-markdown-fragment-to-org
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

(ert-deftest heks-emacs-import/the-region-is-replaced-by-what-it-says-in-org ()
  "Only the region changes, and a region that ended a line still ends one."
  (with-temp-buffer
    (insert "before\n## Two\n\n* one\n* two\nafter\n")
    (let ((beg (save-excursion (goto-char (point-min)) (forward-line 1) (point)))
          (end (save-excursion (goto-char (point-max)) (forward-line -1) (point))))
      (heks-emacs-markdown-region-to-org beg end)
      (should (equal (buffer-string)
                     "before\n** Two\n\n- one\n- two\nafter\n")))))

(ert-deftest heks-emacs-import/a-region-without-a-final-newline-gets-none ()
  "What the region did not end with it is not given."
  (with-temp-buffer
    (insert "see **this**")
    (heks-emacs-markdown-region-to-org (point-min) (point-max))
    (should (equal (buffer-string) "see *this*"))))

(ert-deftest heks-emacs-import/a-prefix-argument-copies-and-leaves-the-buffer-alone ()
  "With a prefix, the Org goes on the kill ring and the Markdown stays."
  (with-temp-buffer
    (insert "## Two\n")
    (let ((kill-ring nil))
      (heks-emacs-markdown-region-to-org (point-min) (point-max) t)
      (should (equal (buffer-string) "## Two\n"))
      (should (equal (car kill-ring) "** Two\n")))))

(ert-deftest heks-emacs-import/a-buffer-that-cannot-be-written-to-is-copied-from ()
  "A read-only buffer -- a chat, a help buffer -- is the place Markdown comes from."
  (with-temp-buffer
    (insert "## Two\n")
    (setq buffer-read-only t)
    (let ((kill-ring nil))
      (heks-emacs-markdown-region-to-org (point-min) (point-max))
      (should (equal (buffer-string) "## Two\n"))
      (should (equal (car kill-ring) "** Two\n")))))

(ert-deftest heks-emacs-import/an-identifier-is-a-uuid ()
  "A note is named the way `org-id' and `org-roam' name one."
  (let ((id (heks-emacs-import--id)))
    (should (string-match-p
             "\\`[0-9a-f]\\{8\\}-[0-9a-f]\\{4\\}-4[0-9a-f]\\{3\\}-[89ab][0-9a-f]\\{3\\}-[0-9a-f]\\{12\\}\\'"
             id))
    (should-not (equal id (heks-emacs-import--id)))))

(ert-deftest heks-emacs-import/a-file-is-imported-next-to-the-source ()
  "The Org is written beside the Markdown, and the Markdown is left alone."
  (let ((root (heks-ert--temp-directory)))
    (unwind-protect
        (let ((source (expand-file-name "README.md" root)))
          (write-region heks-ert-import-document nil source nil 'silent)
          (should (equal (heks-emacs-import-markdown-file source)
                         (expand-file-name "README.org" root)))
          (should (file-exists-p (expand-file-name "README.org" root)))
          (should (equal (with-temp-buffer (insert-file-contents source) (buffer-string))
                         heks-ert-import-document))
          ;; The same document again writes the same file, silently.
          (should (equal (heks-emacs-import-markdown-file source)
                         (expand-file-name "README.org" root))))
      (delete-directory root t))))

(ert-deftest heks-emacs-import/a-note-somebody-wrote-is-not-written-over-unasked ()
  "A file that is already there and differs is kept unless the reader says otherwise."
  (let ((root (heks-ert--temp-directory)))
    (unwind-protect
        (let ((source (expand-file-name "README.md" root))
              (target (expand-file-name "README.org" root)))
          (write-region "# Heks\n" nil source nil 'silent)
          (write-region "my own note\n" nil target nil 'silent)
          (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil)))
            (should-not (heks-emacs-import-markdown-file source)))
          (should (equal (with-temp-buffer (insert-file-contents target) (buffer-string))
                         "my own note\n"))
          (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
            (should (heks-emacs-import-markdown-file source)))
          (should (string-match-p "^#\\+title: Heks$"
                                  (with-temp-buffer (insert-file-contents target)
                                                    (buffer-string)))))
      (delete-directory root t))))

(ert-deftest heks-emacs-import/a-note-imported-into-the-notes-is-a-node ()
  "It carries an identifier and its aliases, and a second import keeps them."
  (let ((root (heks-ert--temp-directory))
        (notes (make-temp-file "heks-ert-notes-" t)))
    (unwind-protect
        (let ((source (expand-file-name "note.md" root)))
          (write-region heks-ert-import-document nil source nil 'silent)
          (cl-letf (((symbol-function 'heks-emacs-notes-roam-directory)
                     (lambda () (file-name-as-directory notes))))
            (let* ((target (heks-emacs-import-markdown-file source t))
                   (text (with-temp-buffer (insert-file-contents target) (buffer-string)))
                   (id (and (string-match ":ID: *\\([^ \t\n]+\\)" text)
                            (match-string 1 text))))
              (should (equal target (expand-file-name "note.org" notes)))
              (should (string-match-p "^ *:ROAM_ALIASES: *Things, stuff$" text))
              (should id)
              ;; Importing it again updates the note rather than making a
              ;; second node, which is what keeping the identifier does.
              (heks-emacs-import-markdown-file source t)
              (let ((again (with-temp-buffer (insert-file-contents target)
                                             (buffer-string))))
                (should (string-match ":ID: *\\([^ \t\n]+\\)" again))
                (should (equal id (match-string 1 again)))))))
      (delete-directory root t)
      (delete-directory notes t))))

(ert-deftest heks-emacs-import/the-project-import-asks-once-and-imports-the-markdown ()
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
            (heks-emacs-import-markdown-project))
          (should (file-exists-p (expand-file-name "README.org" root)))
          (should (file-exists-p (expand-file-name "guide.org" root)))
          (should (= asked 0)))
      (delete-directory root t))))

(ert-deftest heks-emacs-import/a-document-is-what-its-name-says-it-is ()
  "The names a Markdown document is written with, and the ones it is not."
  (should (heks-emacs-import-markdown-p "README.md"))
  (should (heks-emacs-import-markdown-p "guide.markdown"))
  (should (heks-emacs-import-markdown-p "NOTES.MD"))
  (should-not (heks-emacs-import-markdown-p "notes.org"))
  (should-not (heks-emacs-import-markdown-p "notes.md.org")))

(ert-deftest heks-emacs-scheme/an-evaluation-brings-up-the-repl-it-needs ()
  "Evaluating with no REPL starts the project's one; with one, it does not."
  (let ((started 0)
        (evaluated 0))
    (cl-letf (((symbol-function 'heks-emacs-scheme-repl-connected-p)
               (lambda () (>= started 1)))
              ((symbol-function 'heks-emacs-scheme-repl--start)
               (lambda () (setq started (1+ started))))
              ((symbol-function 'geiser-eval-definition)
               (lambda (_) (setq evaluated (1+ evaluated)))))
      (heks-emacs-scheme-repl-needed (lambda () (geiser-eval-definition nil)))
      (should (= started 1))
      (should (= evaluated 1))
      (heks-emacs-scheme-repl-needed (lambda () (geiser-eval-definition nil)))
      (should (= started 1))
      (should (= evaluated 2)))))

(ert-deftest heks-emacs-scheme/a-repl-that-will-not-come-up-is-said-so ()
  "A machine where the program is missing is told that rather than left waiting."
  (cl-letf (((symbol-function 'heks-emacs-scheme-repl-connected-p) (lambda () nil))
            ((symbol-function 'heks-emacs-scheme-repl--start) (lambda () nil))
            ((symbol-function 'accept-process-output) (lambda (&rest _) nil)))
    (should-error (heks-emacs-scheme-repl-needed (lambda () nil)) :type 'user-error)))

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

(ert-deftest heks-emacs-which-key/the-menu-goes-where-the-frame-has-room ()
  "The bottom window needs twice the smallest a frame's window may be.

`which-key' makes the window it shows the menu in by splitting the frame's
main window in two and keeping one half, and it asks `split-window' for
that with `split-window-no-error', whose nil answer it does not read -- so
when the split is refused, the menu is written into `which-key's buffer and
nobody sees it.  `heks-emacs-which-key-side-window-p' is the rule that
decides the place instead, and the rule is checked here against
`split-window-no-error' itself: what the predicate answers and what the
split does are the same question, so a change in Emacs's own rule is a
failing test rather than a menu that disappears again."
  (skip-unless (and (featurep 'which-key)
                    (fboundp 'heks-emacs-which-key-side-window-p)))
  (let ((configuration (current-window-configuration))
        (min-height window-min-height)
        ;; A refused split is an error `split-window-no-error' is meant to
        ;; swallow, and `ert' stops at every error it is told about.
        (debug-on-error nil))
    (unwind-protect
        (progn
          ;; One window: room for the menu, and the place is the window.
          (delete-other-windows)
          (should (heks-emacs-which-key-side-window-p))
          (should (windowp (split-window-no-error (frame-root-window) nil 'below)))
          (heks-emacs-which-key-popup-dimensions 80)
          (should-not heks-emacs-which-key-echoing)
          (delete-other-windows)
          ;; Windows which are too small to be split in two: no room, and the
          ;; menu is asked for in the echo area, with one line less than the
          ;; echo area has -- the line which-key says about the menu is not
          ;; part of the page but is shown with it.
          (dotimes (_ 2) (split-window-no-error (selected-window) nil 'below))
          (setq window-min-height 5)
          (should-not (heks-emacs-which-key-side-window-p))
          (should-not (split-window-no-error (frame-root-window) nil 'below))
          (heks-emacs-which-key-popup-dimensions 80)
          (should heks-emacs-which-key-echoing)
          (should (equal (car (heks-emacs-which-key-popup-dimensions 80))
                         (1- (car (which-key--minibuffer-max-dimensions))))))
      (setq window-min-height min-height)
      (set-window-configuration configuration))))

;;
;; ====== The family a face is given ======
;;

(ert-deftest heks-emacs-ui/an-eca-face-gets-the-family-of-what-it-prints ()
  "A chat is read, and what a reader copies out of it is not."
  (let ((given nil))
    (cl-letf (((symbol-function 'heks-emacs--set-face)
               (lambda (face &rest attributes)
                 (push (cons face attributes) given))))
      (heks-emacs-set-eca-faces))
    (should (equal (length given)
                   (+ (length heks-emacs-eca-sans-faces)
                      (length heks-emacs-eca-mono-faces))))
    (should (equal (cdr (assq 'eca-chat-title-face given))
                   (list :font heks-emacs-font-sans)))
    (should (equal (cdr (assq 'eca-chat-tool-call-accept-face given))
                   (list :font heks-emacs-font-sans)))
    (should (equal (cdr (assq 'eca-chat-file-path-face given))
                   (list :font heks-emacs-font-mono)))
    (should (equal (cdr (assq 'eca-chat-shell-command-face given))
                   (list :font heks-emacs-font-mono)))))

(ert-deftest heks-emacs-ui/no-eca-face-is-in-both-lists ()
  "A face in both lists would be given whichever family came last."
  (should-not (cl-intersection heks-emacs-eca-sans-faces
                               heks-emacs-eca-mono-faces))
  (should (cl-every #'symbolp (append heks-emacs-eca-sans-faces
                                      heks-emacs-eca-mono-faces))))

(ert-deftest heks-emacs-ui/a-face-that-is-not-there-yet-is-skipped ()
  "ECA defines its faces when it is loaded, which is after this module runs."
  (should-not (facep 'heks-emacs-no-such-face))
  (heks-emacs--set-face 'heks-emacs-no-such-face :font heks-emacs-font-sans)
  (should-not (facep 'heks-emacs-no-such-face)))

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

(ert-deftest heks-emacs-ai/the-key-in-the-environment-is-the-personal-account ()
  "Exporting the DeepSeek key is what makes an Emacs the personal one."
  (heks-ert--call-with-environment
   '(("HEKS_AI_PROVIDER" . nil) ("DEEPSEEK_API_KEY" . "sk-test"))
   (lambda ()
     (let ((heks-emacs-ai-provider 'auto))
       (should (eq (heks-emacs-ai-provider) 'deepseek))))))

(ert-deftest heks-emacs-ai/copilot-is-what-is-left-without-a-key ()
  (heks-ert--call-with-environment
   '(("HEKS_AI_PROVIDER" . nil) ("DEEPSEEK_API_KEY" . nil))
   (lambda ()
     (let ((heks-emacs-ai-provider 'auto)
           (heks-emacs-ai-deepseek-key-file nil))
       (should (eq (heks-emacs-ai-provider) 'copilot))))))

(ert-deftest heks-emacs-ai/the-environment-can-name-one-outright ()
  "A machine that must be told does not have to export a key to say so."
  (heks-ert--call-with-environment
   '(("HEKS_AI_PROVIDER" . "copilot") ("DEEPSEEK_API_KEY" . "sk-test"))
   (lambda ()
     (let ((heks-emacs-ai-provider 'auto))
       (should (eq (heks-emacs-ai-provider) 'copilot))))))

(ert-deftest heks-emacs-ai/a-name-it-does-not-know-is-not-obeyed ()
  "A typo should send a prompt nowhere, not to the wrong account."
  (heks-ert--call-with-environment
   '(("HEKS_AI_PROVIDER" . "copilot-work") ("DEEPSEEK_API_KEY" . nil))
   (lambda ()
     (let ((heks-emacs-ai-provider 'auto)
           (heks-emacs-ai-deepseek-key-file nil))
       (should (eq (heks-emacs-ai-provider) 'copilot))))))

(ert-deftest heks-emacs-ai/the-setting-does-not-need-the-environment ()
  (heks-ert--call-with-environment
   '(("HEKS_AI_PROVIDER" . nil) ("DEEPSEEK_API_KEY" . nil))
   (lambda ()
     (let ((heks-emacs-ai-provider 'deepseek))
       (should (eq (heks-emacs-ai-provider) 'deepseek))))))

(ert-deftest heks-emacs-ai/the-key-file-is-read-when-the-environment-has-none ()
  "A machine with no exported key can still keep one, and this is how it is read."
  (let ((file (make-temp-file "heks-ai-key-")))
    (unwind-protect
        (progn
          (write-region "sk-from-file\n" nil file nil 'silent)
          (heks-ert--call-with-environment
           '(("DEEPSEEK_API_KEY" . nil))
           (lambda ()
             (let ((heks-emacs-ai-deepseek-key-file file))
               (should (equal (heks-emacs-ai-deepseek-api-key) "sk-from-file"))))))
      (delete-file file))))

(ert-deftest heks-emacs-ai/the-key-file-is-what-makes-it-the-personal-machine ()
  "The file's existence is the sign at startup; it is not decrypted there."
  (let ((file (make-temp-file "heks-ai-key-")))
    (unwind-protect
        (heks-ert--call-with-environment
         '(("HEKS_AI_PROVIDER" . nil) ("DEEPSEEK_API_KEY" . nil))
         (lambda ()
           (let ((heks-emacs-ai-provider 'auto)
                 (heks-emacs-ai-deepseek-key-file file))
             (should (eq (heks-emacs-ai-provider) 'deepseek)))))
      (delete-file file))))

(ert-deftest heks-emacs-ai/an-encrypted-key-file-is-decrypted-with-gpg ()
  "A `.gpg' file is GPG's to read, and only its stdout is the key."
  (let ((file (make-temp-file "heks-ai-key-" nil ".gpg"))
        (invocation nil))
    (unwind-protect
        (let ((heks-emacs-ai-deepseek-key-file file))
          (cl-letf (((symbol-function 'call-process)
                     (lambda (program _infile destination _display &rest args)
                       (setq invocation (cons program args))
                       (with-current-buffer (if (and (consp destination)
                                                    (eq (car destination) t))
                                                (current-buffer)
                                              (error "GPG's output was not captured"))
                         (insert "sk-from-gpg\n"))
                       0)))
            (should (equal (heks-emacs-ai--deepseek-key-file-key) "sk-from-gpg"))
            (should (equal invocation
                           (list "gpg" "--batch" "--quiet" "--decrypt" file)))))
      (delete-file file))))

(ert-deftest heks-emacs-ai/eca-names-the-account-its-own-way ()
  "ECA's model id is qualified with the provider it logs in with."
  (let ((heks-emacs-ai-copilot-model 'some-copilot-model)
        (heks-emacs-ai-deepseek-model 'some-deepseek-model))
    (should (equal (heks-emacs-ai-eca-model 'copilot)
                   "github-copilot/some-copilot-model"))
    (should (equal (heks-emacs-ai-eca-model 'deepseek)
                   "deepseek/some-deepseek-model"))))

(defvar gptel-backend nil
  "The variable GPTel owns, declared so a test can bind it without GPTel.")

(defvar gptel-model nil
  "The variable GPTel owns, declared so a test can bind it without GPTel.")

(defvar eca-chat-custom-model nil
  "The variable ECA owns, declared so a test can bind it without ECA.")

(ert-deftest heks-emacs-ai/switching-points-both-tools-at-the-same-account ()
  "Choosing a provider is one choice, not one per tool."
  (let ((heks-emacs-ai-deepseek-model 'some-deepseek-model)
        (gptel-backend nil)
        (gptel-model nil)
        (eca-chat-custom-model nil))
    (cl-letf (((symbol-function 'heks-emacs-ai-gptel-backend)
               (lambda (provider) (list 'backend provider))))
      (heks-emacs-ai-use-provider 'deepseek))
    (should (equal gptel-backend '(backend deepseek)))
    (should (eq gptel-model 'some-deepseek-model))
    (should (equal eca-chat-custom-model "deepseek/some-deepseek-model"))))

;;
;; ====== Preparing ECA before it is asked for ======
;;

(ert-deftest heks-emacs-ai/a-prepared-chat-is-made-without-a-window ()
  "The chat is still created; what it is not given is a window."
  (let ((displayed nil)
        (opened nil))
    (cl-letf (((symbol-function 'eca-chat--display-buffer)
               (lambda (buffer) (push buffer displayed))))
      (let ((heks-emacs-ai--eca-quiet t))
        (heks-emacs-ai--eca-open-without-window
         (lambda (session)
           (setq opened session)
           (eca-chat--display-buffer (current-buffer)))
         'the-session))
      (should (eq opened 'the-session))
      (should-not displayed))))

(ert-deftest heks-emacs-ai/the-chat-the-reader-asks-for-shows-itself ()
  "The preparation spends the quietness, so the next chat opens normally."
  (let ((displayed nil))
    (cl-letf (((symbol-function 'eca-chat--display-buffer)
               (lambda (buffer) (push buffer displayed))))
      (let ((heks-emacs-ai--eca-quiet t))
        (heks-emacs-ai--eca-open-without-window (lambda (_session) nil) 'the-session))
      (heks-emacs-ai--eca-open-without-window
       (lambda (_session) (eca-chat--display-buffer (current-buffer)))
       'the-session)
      (should displayed))))

(ert-deftest heks-emacs-ai/a-chat-that-is-asked-for-is-not-quiet ()
  "The quietness is for the start, and asking is what ends it."
  (let ((heks-emacs-ai--eca-quiet t)
        (heks-emacs-ai--eca-quiet-timer nil))
    (heks-emacs-ai--eca-quiet-off)
    (should-not heks-emacs-ai--eca-quiet)))

(ert-deftest heks-emacs-ai/giving-up-cancels-the-timer ()
  "A timer that would clear the flag twice is one timer too many."
  (let ((timer (run-with-timer 60 nil #'ignore))
        (heks-emacs-ai--eca-quiet t))
    (let ((heks-emacs-ai--eca-quiet-timer timer))
      (heks-emacs-ai--eca-quiet-off)
      (should-not (memq timer timer-list))
      (should-not heks-emacs-ai--eca-quiet-timer))))

(ert-deftest heks-emacs-ai/nothing-is-said-while-preparing ()
  "A start nobody asked for is not a message in the echo area."
  (let ((said nil)
        (heks-emacs-ai--eca-quiet t))
    (heks-emacs-ai--eca-say-nothing (lambda (&rest args) (setq said args)) "ECA")
    (should-not said))
  (let ((said nil))
    (heks-emacs-ai--eca-say-nothing (lambda (&rest args) (setq said args)) "ECA")
    (should (equal said '("ECA")))))

(ert-deftest heks-emacs-ai/there-is-nothing-to-prepare-outside-a-project ()
  "A session rooted where there is no project would claim every project under it."
  (let ((starts 0)
        (heks-emacs-ai-eca-prepare t)
        (heks-emacs-ai--eca-prepared nil))
    (cl-letf (((symbol-function 'heks-emacs-ai--project-root)
               (lambda (&optional _directory) nil))
              ((symbol-function 'heks-emacs-ai--eca-start-for-project)
               (lambda (_root) (cl-incf starts))))
      (heks-emacs-ai-eca-prepare))
    (should (= starts 0))
    ;; Nothing was prepared, so the file that does name a project can be.
    (should-not heks-emacs-ai--eca-prepared)))

(ert-deftest heks-emacs-ai/eca-is-prepared-once ()
  "One server is prepared at startup, not one per buffer that follows."
  (let ((roots nil)
        (heks-emacs-ai-eca-prepare t)
        (heks-emacs-ai--eca-prepared nil))
    (cl-letf (((symbol-function 'heks-emacs-ai--project-root)
               (lambda (&optional _directory) "/tmp/heks-project/"))
              ((symbol-function 'heks-emacs-ai--eca-start-for-project)
               (lambda (root) (push root roots))))
      (heks-emacs-ai-eca-prepare)
      (heks-emacs-ai-eca-prepare))
    (should (equal roots '("/tmp/heks-project/")))
    (should heks-emacs-ai--eca-prepared)))

(ert-deftest heks-emacs-ai/a-start-that-is-not-asked-for-is-not-started ()
  "The setting is what decides, not a hook that was left in place."
  (let ((starts 0)
        (heks-emacs-ai-eca-prepare nil)
        (heks-emacs-ai--eca-prepared nil))
    (cl-letf (((symbol-function 'heks-emacs-ai--project-root)
               (lambda (&optional _directory) "/tmp/heks-project/"))
              ((symbol-function 'heks-emacs-ai--eca-start-for-project)
               (lambda (_root) (cl-incf starts))))
      (heks-emacs-ai-eca-prepare))
    (should (= starts 0))))

(ert-deftest heks-emacs-ai/a-start-that-fails-is-reported-and-is-not-quiet ()
  "A failure is said once, and the chat the reader asks for is theirs."
  (let ((messages nil)
        (real-require (symbol-function 'require))
        (heks-emacs-ai--eca-quiet nil))
    (cl-letf (((symbol-function 'require)
               (lambda (feature &optional filename noerror)
                 (if (eq feature 'eca) t
                   (funcall real-require feature filename noerror))))
              ((symbol-function 'eca-session-for-root) (lambda (_root) nil))
              ((symbol-function 'eca) (lambda (&optional _arg) (error "no network")))
              ((symbol-function 'run-with-timer) (lambda (&rest _) nil))
              ((symbol-function 'message)
               (lambda (format &rest args) (push (apply #'format format args) messages))))
      (heks-emacs-ai--eca-start-for-project "/tmp/heks-project/"))
    (should-not heks-emacs-ai--eca-quiet)
    (should (seq-some (lambda (one) (string-match-p "no network" one)) messages))))

(ert-deftest heks-emacs-ai/a-session-that-is-already-there-is-not-started-again ()
  "Preparing what is prepared would open a second server."
  (let ((started 0)
        (real-require (symbol-function 'require))
        (heks-emacs-ai--eca-quiet nil))
    (cl-letf (((symbol-function 'require)
               (lambda (feature &optional filename noerror)
                 (if (eq feature 'eca) t
                   (funcall real-require feature filename noerror))))
              ((symbol-function 'eca-session-for-root) (lambda (_root) 'a-session))
              ((symbol-function 'eca) (lambda (&optional _arg) (cl-incf started)))
              ((symbol-function 'run-with-timer) (lambda (&rest _) nil)))
      (heks-emacs-ai--eca-start-for-project "/tmp/heks-project/"))
    (should (= started 0))))

(ert-deftest heks-emacs-ai/the-watch-for-a-project-removes-itself ()
  "Watching for a project stops once there is one to prepare.
The project is handed to the timer: by the time the timer runs, the
buffer that said which project it is is not the current one any more."
  (let ((timers nil)
        (heks-emacs-ai-eca-prepare t)
        (heks-emacs-ai-eca-prepare-delay 1))
    (cl-letf (((symbol-function 'heks-emacs-ai--project-root)
               (lambda (&optional _directory) "/tmp/heks-project/"))
              ((symbol-function 'run-with-idle-timer)
               (lambda (seconds _repeat function &rest args)
                 (push (cons seconds (cons function args)) timers))))
      (add-hook 'find-file-hook #'heks-emacs-ai--eca-prepare-when-visiting)
      (heks-emacs-ai--eca-prepare-when-visiting))
    (should-not (memq 'heks-emacs-ai--eca-prepare-when-visiting find-file-hook))
    (should (equal timers '((1 heks-emacs-ai-eca-prepare "/tmp/heks-project/"))))))

(ert-deftest heks-emacs-ai/the-daemon-waits-for-the-first-project-file ()
  "There is no project at startup, so the first one visited is the one prepared."
  (let ((heks-emacs-ai-eca-prepare t))
    (cl-letf (((symbol-function 'heks-emacs-ai--project-root)
               (lambda (&optional _directory) nil)))
      (unwind-protect
          (progn
            (heks-emacs-ai--eca-prepare-soon)
            (should (memq 'heks-emacs-ai--eca-prepare-when-visiting find-file-hook)))
        (remove-hook 'find-file-hook #'heks-emacs-ai--eca-prepare-when-visiting)))))

(ert-deftest heks-emacs-ai/starting-inside-a-project-needs-no-file-visited ()
  "`emacs .' knows its project before anything is opened."
  (let ((timers nil)
        (heks-emacs-ai-eca-prepare t))
    (cl-letf (((symbol-function 'heks-emacs-ai--project-root)
               (lambda (&optional _directory) "/tmp/heks-project/"))
              ((symbol-function 'run-with-idle-timer)
               (lambda (seconds _repeat function &rest args)
                 (push (cons seconds (cons function args)) timers))))
      (heks-emacs-ai--eca-prepare-soon))
    (should (equal timers '((1 heks-emacs-ai-eca-prepare "/tmp/heks-project/"))))
    (should-not (memq 'heks-emacs-ai--eca-prepare-when-visiting find-file-hook))))

;;
;; ====== The fold indicators are quiet ======
;;

(ert-deftest heks-emacs-dev-folding/an-indicator-is-faded-toward-the-background ()
  "The marker colour is `shadow' moved part of the way to the background."
  (cl-letf (((symbol-function 'face-attribute)
             (lambda (face attribute &optional _frame _inherit)
               (pcase (cons face attribute)
                 ('(shadow . :foreground) "#989898")
                 ('(default . :background) "#000000")
                 (_ (error "The colour of %S %S was asked for" face attribute))))))
    (let ((heks-emacs-fold-indicator-fade 50))
      (should (equal (heks-emacs-fold-indicator-color) "#4c4c4c4c4c4c")))))

(ert-deftest heks-emacs-dev-folding/no-fade-leaves-the-markers-alone ()
  (let ((heks-emacs-fold-indicator-fade 0))
    (should-not (heks-emacs-fold-indicator-color))))

(ert-deftest heks-emacs-dev-folding/every-engine-gets-the-quiet-colour ()
  "Hideshow and Tree-sitter draw the same element and get the same face."
  (let ((given nil))
    (cl-letf (((symbol-function 'heks-emacs-fold-indicator-color)
               (lambda () "#4c4c4c4c4c4c"))
              ((symbol-function 'facep) (lambda (_face) t))
              ((symbol-function 'set-face-attribute)
               (lambda (face _frame &rest attributes)
                 (push (cons face attributes) given))))
      (heks-emacs-fold-indicator-faces))
    (should (= (length given) 5))
    (should (cl-every (lambda (one)
                        (equal (plist-get (cdr one) :foreground) "#4c4c4c4c4c4c"))
                      given))
    (should (cl-every (lambda (one) (eq (plist-get (cdr one) :inherit) 'shadow))
                      given))))

;;
;; Run.
;;

(unless (getenv "HEKS_ERT_NO_RUN")
  (ert-run-tests-batch-and-exit))

;;; heks-emacs-ert.el ends here
