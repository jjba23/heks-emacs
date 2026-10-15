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

(dolist (module '("render" "present" "heks-emacs" "emacs-core" "dev" "openapi"))
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

;;
;; Run.
;;

(unless (getenv "HEKS_ERT_NO_RUN")
  (ert-run-tests-batch-and-exit))

;;; heks-emacs-ert.el ends here
