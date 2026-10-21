;;; dev-tools.el --- Editing helpers and developer tooling -*- lexical-binding: t -*-

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

;; Editing helpers and developer tooling.

;;; Code:

;; Enables smart handling of parentheses and other delimiters in programming modes,
;; assisting with balanced expressions.
(use-package smartparens
  :ensure t
  :hook ((prog-mode . smartparens-mode))
  :config
  ;; The stock YAML rules signal an error on a plain sequence item such as
  ;; `- plain', which breaks folding for the whole buffer.  These fold any
  ;; mapping pair or sequence item that spans several lines, from the end of
  ;; its first line.
  (defun heks-emacs-yaml-fold-range (node offset)
    "Fold range of NODE from the end of its first line, if it spans lines."
    (let ((beg (save-excursion
                 (goto-char (treesit-node-start node))
                 (line-end-position)))
          (end (treesit-node-end node)))
      (when (> end beg)
        (treesit-fold--cons-add (cons beg end) offset))))
  (with-eval-after-load 'treesit-fold
    (let ((rules `((comment
                    . (lambda (node offset)
                        (treesit-fold-range-line-comment node offset "#")))
                   (block_sequence_item . heks-emacs-yaml-fold-range)
                   (block_mapping_pair . heks-emacs-yaml-fold-range))))
      (dolist (mode '(yaml-ts-mode yaml-mode))
        (setf (alist-get mode treesit-fold-range-alist) rules))))
  (require 'smartparens-config))

;; Integrates direnv with Emacs, allowing automatic loading and unloading
;; of environment variables based on directory.  The environment a project
;; needs is its own topic, `C-c e', which Docker and the databases used to
;; share with it.
(use-package direnv
  :ensure t
  :bind (("C-c e d" . direnv-mode)
         ("C-c e a" . direnv-allow)))

;; Provides aggressive indentation for Lisp-like languages,
;; automatically formatting code as you type.
(use-package aggressive-indent
  :ensure t
  :hook ((emacs-lisp-mode . aggressive-indent-mode)
         ;; in Scheme I usually just use Guix format
         ;; which auto-formats my files nicely
         ;;
         ;;otherwise feel free to turn this on
         ;; (scheme-mode . aggressive-indent-mode)
         (lisp-mode . aggressive-indent-mode)))

;; Configures Emacs for editing Dockerfile and .dockerignore files using tree-sitter.
(use-package dockerfile-ts-mode
  :ensure nil
  :mode (("\\Dockerfile\\'" . dockerfile-ts-mode)
         ("\\.dockerignore\\'" . dockerfile-ts-mode))
  :config
  (setq dockerfile-mode-command "podman"))

;; Provides an interface for interacting with Docker from within Emacs,
;; allowing management of containers and images.  Containers are their own
;; topic: `C-c c d' starts Docker and `C-c d p' is a database.
(use-package docker
  :ensure t
  :bind (("C-c c d" . docker)))

;; Scheme, Guile and Guix development live in `modules/guile.el': Geiser for
;; the REPL, the completion, the debugger and the call hierarchy; the Guile
;; compiler and `guix lint' for checking, `guix style' for formatting, and
;; the folding keys shared with the other languages.  Guix is optional
;; there: without it the module is a plain Guile setup.

;; Provdes a REPL session management tool for Emacs and more.
(use-package sesman
  :ensure (:host github :repo "vspinu/sesman" :branch "master")
  :demand t)

;; Enhances the compilation buffer with what a terminal gives for free: the
;; ANSI escapes a tool writes become colours instead of `[0m' noise in the
;; middle of a line, the output scrolls as it arrives, and the faces of the
;; buffer come from the theme rather than the package's own palette
;; (`fancy-compilation-override-colors' off).
;;
;; It is loaded up front rather than on the first call of
;; `fancy-compilation-mode', which is what `:commands' asked for and why
;; none of this was happening: what the package does, it does by advising
;; `compile' and `compilation-filter' and by a hook of its own, so a mode
;; that is only loaded when it is called has to be called before the first
;; compilation -- a thing nobody remembers to do, since the escape codes
;; only appear once it is too late.  It is the same trap as the one
;; `flymake-collection' below describes, and answered the same way: load it
;; now, and turn it on in `:config'.
(use-package fancy-compilation
  :ensure t
  :demand t
  :config
  (setq fancy-compilation-override-colors nil)
  (fancy-compilation-mode))

;; Provides visual diff highlighting in the margin,
;; showing changes relative to version control.
(use-package diff-hl
  :ensure t
  :config
  ;; Enabling the mode runs `git diff' in every open buffer, including the
  ;; init file being loaded right now, whose directory can be a symlink into
  ;; another repository; a git failure there must not abort the setup.
  (with-demoted-errors "diff-hl: %S"
    (global-diff-hl-mode))
  (setopt diff-hl-margin-symbols-alist
          '((insert . "+") (delete . "-") (change . "~")
            (unknown . "?") (ignored . "i")))
  (with-demoted-errors "diff-hl: %S"
    (diff-hl-margin-mode))
  (ignore-errors
    (add-hook 'magit-post-refresh-hook 'diff-hl-magit-post-refresh)
    (add-hook 'dired-mode-hook
              (lambda () (diff-hl-dired-mode))))
  (ignore-errors
    (set-face-attribute 'diff-hl-change nil
                        :background 'unspecified)
    (set-face-attribute 'diff-hl-insert nil
                        :background 'unspecified)
    (set-face-attribute 'diff-hl-delete nil
                        :background 'unspecified)))

;; Provides a library for making HTTP requests from Emacs Lisp.
(use-package request
  :ensure t)

(provide 'heks-emacs/dev-tools)

;;; dev-tools.el ends here
