;;; treesit-grammars.el --- Build the tree-sitter grammars  -*- lexical-binding: t -*-

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

;; A tree-sitter mode is only as good as the grammar library built for the
;; language it parses, and Emacs fetches a missing one while a file is being
;; opened -- which is a wait on the first file of every language, and, for a
;; language no recipe is known for, a question.  This script is the other
;; way round: it builds every grammar this Emacs can be asked for, once, so
;; that nothing is fetched on the file-opening path at all.
;;
;; Cloning a repository and compiling a grammar is work that fails for
;; reasons that have nothing to do with the grammar -- a clone that timed
;; out, a checkout that was busy, a network that looked away -- so a grammar
;; is tried twice before it is given up on, and what is reported here is a
;; grammar that would not build two times rather than once.
;;
;; `emacs-core.el' starts it in a batch Emacs of its own, in the background,
;; with three variables set for it before it is loaded: the directory to
;; install into, the recipes this configuration names itself, and the
;; directories a grammar may already be built in.  What it needs is handed
;; to it rather than looked for, which is what makes the child a batch Emacs
;; and nothing else: no Elpaca, no modules, no packages.
;;
;;   emacs -Q --batch -l ~/.emacs.d/treesit-grammars.el
;;
;; is how it is run by hand, with the defaults: the grammar directory of the
;; configuration, and no recipes of its own to add.

;;; Code:

(require 'seq)
(require 'subr-x)
(require 'treesit)

(defvar heks-emacs-treesit-grammar-directory
  (expand-file-name "tree-sitter" user-emacs-directory)
  "The directory the grammars are installed into.")

(defvar heks-emacs-treesit-own-recipes nil
  "The recipes of the grammars Emacs itself ships no mode for.")

(defvar heks-emacs-treesit-attempts 2
  "How many times a grammar is built before it is given up on.

Building one is a clone and a compilation, and either step can fail for a
reason that is not about the grammar at all, so a second attempt is worth
far more than the line it costs.")

(defun heks-emacs-treesit--mode-libraries ()
  "Return the libraries that define this Emacs's tree-sitter modes.

A mode is not the library it lives in -- `python-ts-mode' is in `python',
`csharp-ts-mode' is in `csharp-mode' -- so the library is the one the mode
was defined in, and the two are not the same name."
  (delq nil (mapcar (lambda (pair) (symbol-file (cdr pair) 'defun))
                    (bound-and-true-p treesit-major-mode-remap-alist))))

(defun heks-emacs-treesit-recipes ()
  "Return the recipes of every grammar this Emacs can be asked for.

The recipes of the languages Emacs has modes for are not a list to keep
anywhere: each of its mode files adds the recipe of the language its mode
parses to `treesit-language-source-alist' as it is loaded, so the list is
Emacs's own and stays right as Emacs changes.  What this configuration adds
to it is the languages Emacs ships no mode for."
  (dolist (library (heks-emacs-treesit--mode-libraries))
    (load library nil t))
  (append heks-emacs-treesit-own-recipes
          (seq-remove (lambda (recipe)
                        (assq (car recipe) heks-emacs-treesit-own-recipes))
                      treesit-language-source-alist)))

(defun heks-emacs-treesit-build (language)
  "Build LANGUAGE's grammar, answering whether it can be loaded here now.

A build that returns is not a grammar that arrived: Emacs reports a library
it cannot locate or load as a warning rather than as an error, so what this
answers is what `treesit-language-available-p' says afterwards.  A language
that fails, or that is built but does not arrive, is tried
`heks-emacs-treesit-attempts' times before it is given up on, and only the
last failure is reported as the verdict: what the earlier line says is that
an attempt did not work, which is a different thing."
  (let ((attempt 0)
        (built nil)
        (why nil))
    (while (and (not built) (< attempt heks-emacs-treesit-attempts))
      (setq attempt (1+ attempt)
            why nil)
      (condition-case err
          (treesit-install-language-grammar
           language heks-emacs-treesit-grammar-directory)
        (error (setq why (error-message-string err))))
      (cond
       ((and (null why) (treesit-language-available-p language))
        (setq built t)
        (when (> attempt 1)
          (message "the %s grammar was built on attempt %d" language attempt)))
       ((< attempt heks-emacs-treesit-attempts)
        (message "the %s grammar did not build on attempt %d (%s); trying once more"
                 language attempt (or why "no library could be loaded")))
       (t
        (message "the %s grammar could not be built: %s"
                 language (or why "it was built, but no library can be loaded")))))
    built))

(defun heks-emacs-treesit-install-grammars ()
  "Build every grammar whose recipe is known and whose library is not here.

Each one is given its attempts before it is reported, and a grammar that is
given up on is a line saying which rather than the end of the ones after
it: one language's repository having moved, or its compiler having gone
missing, is no reason for the others to stay unbuilt."
  (let ((built 0)
        (missing nil))
    (dolist (recipe (heks-emacs-treesit-recipes))
      (unless (treesit-language-available-p (car recipe))
        (if (heks-emacs-treesit-build (car recipe))
            (setq built (1+ built))
          (push (car recipe) missing))))
    (message "heks-emacs: %d tree-sitter grammar%s built%s"
             built
             (if (= built 1) "" "s")
             (if missing
                 (format ", not built: %s"
                         (mapconcat #'symbol-name (nreverse missing) ", "))
               ""))))

(heks-emacs-treesit-install-grammars)

(provide 'heks-emacs/treesit-grammars)

;;; treesit-grammars.el ends here
