;;; heks-emacs-render.el --- Check the Markdown renderer  -*- lexical-binding: t -*-

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

;; The renderer is the one part of this configuration that turns text a
;; person wrote into something else a person reads, so what it produces is
;; worth pinning down.  These are unit tests of a pure function: no frame,
;; no network, no theme, and no configuration -- loading `render.el' is
;; enough.  The keybinding `use-package' at the end of that module is
;; stubbed out, because a keymap is not what is being checked here.
;;
;;   emacs -Q --batch -l test/heks-emacs-render.el
;;
;; It exits non-zero when any rendering is wrong, so `maak render' fails
;; with it.

;;; Code:

(setq load-prefer-newer t)
(require 'cl-lib)
(require 'subr-x)

(defvar heks-render--passed 0)
(defvar heks-render--failed 0)

(defmacro use-package (&rest _)
  "Stand in for the keybinding macro, which this test does not exercise."
  nil)

(defun heks-render--check (label value &rest expected)
  "Record that LABEL holds when VALUE equals the first of EXPECTED."
  (let ((expected (if expected (car expected) t)))
    (if (equal value expected)
        (progn (setq heks-render--passed (1+ heks-render--passed))
               (message "  ok   %s" label))
      (setq heks-render--failed (1+ heks-render--failed))
      (message "  FAIL %s -> %S (expected %S)" label value expected))))

(defun heks-render--matches (label html pattern)
  "Record that HTML matches PATTERN."
  (heks-render--check label (and (string-match-p pattern html) t) t))

(defconst heks-render--dir
  (file-name-as-directory
   (file-name-directory (directory-file-name (file-name-directory load-file-name))))
  "The checkout holding the configuration's source.")

(add-to-list 'load-path (expand-file-name "src/modules" heks-render--dir))
;; `markdown.el' is the reading of a document; `render.el' is what is made
;; of it, and is loaded second for that reason.
(load "markdown" nil t)
(load "render" nil t)

(message "== the Markdown renderer ==")

(let ((html (heks-emacs-markdown-to-html
             (concat "# Title\n"
                     "\n"
                     "Some *emphasis*, some **strong**, some `code`, a [link](docs/a.md)\n"
                     "and ![diagram](images/d.png).\n"
                     "\n"
                     "- first\n"
                     "- second\n"
                     "  - nested\n"
                     "- [ ] todo\n"
                     "- [x] done\n"
                     "\n"
                     "1. one\n"
                     "2. two\n"
                     "\n"
                     "> quoted *text*\n"
                     "\n"
                     "```elisp\n"
                     "(setq x \"<not markup>\")\n"
                     "```\n"
                     "\n"
                     "| Name | Count | Note |\n"
                     "|:-----|------:|:----:|\n"
                     "| a | 1 | left |\n"
                     "| b | 22 | right |\n"
                     "\n"
                     "---\n"
                     "\n"
                     "A hard break  \nafter two spaces.\n"
                     "\n"
                     "<details>a raw block</details>\n"))))
  (heks-render--matches "a heading becomes a heading" html "<h1>Title</h1>")
  (heks-render--matches "emphasis" html "<em>emphasis</em>")
  (heks-render--matches "strong" html "<strong>strong</strong>")
  (heks-render--matches "a code span" html "<code>code</code>")
  (heks-render--matches "a link" html "<a href=\"docs/a.md\">link</a>")
  (heks-render--matches "an image" html "<img src=\"images/d.png\"")
  (heks-render--matches "a list" html "<ul>\n<li>first</li>")
  (heks-render--matches "a nested list, inside its item"
                        html "<li>second</li>\n<ul>\n<li>nested</li>\n</ul>")
  (heks-render--matches "an unchecked task" html "☐ todo")
  (heks-render--matches "a checked task" html "☑ done")
  (heks-render--matches "an ordered list" html "<ol>\n<li>one</li>")
  ;; A list has to be closed when the next block is not a list, and at
  ;; the end of a document: an unclosed one puts the heading that follows
  ;; it inside the list, where no browser puts it.
  (heks-render--matches "the ordered list is closed before the blockquote"
                        html "<li>two</li>\n</ol>")
  (heks-render--check "a list at the end of a document is closed"
                      (heks-emacs-markdown-to-html "- one\n- two\n")
                      "<ul>\n<li>one</li>\n<li>two</li>\n</ul>\n")
  (heks-render--matches "a blockquote" html "<blockquote><p>quoted <em>text</em></p></blockquote>")
  (heks-render--matches "a fence keeps its language" html "class=\"language-elisp\"")
  (heks-render--matches "code is escaped, not interpreted" html "&lt;not markup&gt;")
  (heks-render--matches "the first column aligns left"
                        html "<th style=\"text-align:left\">Name</th>")
  (heks-render--matches "the third column is centred, whatever the cell says"
                        html "text-align:center\">left</td>")
  (heks-render--matches "the second column aligns right"
                        html "<td style=\"text-align:right\">22</td>")
  (heks-render--matches "a thematic break" html "<hr>")
  (heks-render--matches "two trailing spaces break the line" html "break<br>after")
  (heks-render--matches "a raw block passes through" html "<details>a raw block</details>")
  ;; A paragraph with a rule under it is a heading, not a one-column table.
  (let ((setext (heks-emacs-markdown-to-html "Title\n=====\n\nText\n---\n")))
    (heks-render--matches "a setext heading" setext "<h1>Title</h1>")
    (heks-render--matches "a rule under a paragraph is still a heading"
                          setext "<h2>Text</h2>")))

(message "\n== escaping and links ==")
(heks-render--check "escaping" (heks-emacs-render--escape "<a & b>") "&lt;a &amp; b&gt;")
(heks-render--check "escaping a quote" (heks-emacs-render--escape "a\"b" t) "a&quot;b")
;; A relative link in a document resolves against the document's own
;; directory, not against the preview, which lives in a temporary one.
(let ((heks-emacs-markdown-base-directory "/home/someone/docs/"))
  (heks-render--matches "a relative image resolves against the document"
                        (heks-emacs-markdown-to-html "![d](img/a.png)")
                        "src=\"file:///home/someone/docs/img/a.png\"")
  (heks-render--matches "an absolute URL is left alone"
                        (heks-emacs-markdown-to-html "[a](https://example.com/x)")
                        "href=\"https://example.com/x\""))

(message "\n== the document around it ==")
(let ((document (heks-emacs-html-document "Title" "<p>body</p>" "Markdown")))
  (heks-render--matches "it is a document" document "<!DOCTYPE html>")
  (heks-render--matches "it carries a stylesheet" document "<style>")
  (heks-render--matches "the title is in the head" document "<title>Title</title>")
  (heks-render--matches "the renderer names itself" document "class=\"headline\">Markdown")
  (heks-render--check "the stylesheet fills every placeholder"
                      (and (string-match-p "%s" (heks-emacs-render-stylesheet)) nil)
                      nil))

(message "\n== %d passed, %d failed ==" heks-render--passed heks-render--failed)
(when (> heks-render--failed 0)
  (kill-emacs 1))

;;; heks-emacs-render.el ends here
