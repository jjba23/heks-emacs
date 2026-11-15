;;; dev-tools.el --- Editing helpers and developer tooling -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>


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
  (defun heks/yaml-fold-range (node offset)
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
                   (block_sequence_item . heks/yaml-fold-range)
                   (block_mapping_pair . heks/yaml-fold-range))))
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
;; compiler and `guix lint' for checking, sift (see `modules/sift.el') for
;; the habits of a file, the drift and the formatting, and the folding keys
;; shared with the other languages.  Guix is optional there: without it the
;; module is a plain Guile setup.

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

;;
;; ====== The doctor: the programs this configuration expects ======
;;
;; A language server, a formatter and a search are programs outside Emacs,
;; and a module that needs one stays silent when it is absent -- which is
;; the right behaviour at load time and the wrong one when somebody asks
;; why a key does nothing.  This is the same knowledge said once, as a
;; report: which program, which module wants it, what that module does
;; without it, and the version the program answers with.

(defvar heks/doctor-programs
  '(("rg" "search and consult" . "the project and note search falls back to `grep'")
    ("fd" "dired and search" . "directories are listed by find(1) instead")
    ("aspell" "proofreading" . "spell checking is off")
    ("git" "git, the project and onefetch" . "there is no history, no diff and no repository screen")
    ("gh" "github-repo" . "the repository settings cannot be captured, applied or verified")
    ("guile" "guile" . "there is no Geiser REPL and no Guix")
    ("guild" "guile" . "the Scheme compiler backend cannot check a file")
    ("sift" "sift" . "the Scheme formatter, lint and drift tools are off")
    ("eca" "ai" . "the ECA chat does not start; GPTel still answers")
    ("onefetch" "onefetch" . "the repository screens have nothing to draw")
    ("terraform" "dev-project" . "the Terraform commands say what is missing")
    ("mongosh" "databases" . "the MongoDB shell is not offered")
    ("docker" "containers" . "the Docker menu is not offered")
    ("shfmt" "shell" . "shell scripts are not formatted")
    ("shellcheck" "shell" . "shell scripts are not checked")
    ("ruff" "dev-formats" . "Python files are not formatted or checked by ruff")
    ("java" "JVM" . "Maven and Gradle projects cannot be built or debugged")
    ("node" "dev-langs" . "the JavaScript language server cannot run")
    ("pandoc" "dev-formats" . "documents are not converted between formats"))
  "The external programs this configuration expects, and why.

Each entry is (PROGRAM MODULE . WHAT-THE-MODULE-DOES-WITHOUT-IT).  The
table is the whole knowledge: a program that arrives is found on
`exec-path', a program that is absent is a line in the report rather than
an error at startup, and the module beside it says what is lost.")

(defun heks/doctor-version (program)
  "Return the version line PROGRAM answers with, or nil.

Not every program has a `--version' that exits successfully, and a
program that does not is still installed; the report says so rather than
turning a missing version into a missing program."
  (when (executable-find program)
    (with-temp-buffer
      (let ((status (ignore-errors
                      (call-process program nil t nil "--version"))))
        (when (and status (zerop status))
          (let ((line (car (split-string (string-trim (buffer-string)) "\n" t))))
            (and line (not (string-empty-p line)) line)))))))

(defun heks/doctor ()
  "Report the external programs this configuration expects.

The report says where each one is, the version it answers with, and what
the module that wants it does without it -- the answer to a key that
quietly does nothing, said once for every program rather than once per
module.  Return the buffer it made."
  (interactive)
  (let ((buffer (get-buffer-create "*heks doctor*"))
        (missing 0))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer))
      (insert (format "heks-emacs %s on Emacs %s\n\n" heks/version emacs-version)
              "The programs the modules here expect, the version each answers with,\n"
              "and what its module does without it.  A missing program is not an\n"
              "error: the module says so and the rest of the configuration works.\n\n"
              (format "%-14s %-46s %s\n" "Program" "Status" "Without it")
              (format "%-14s %-46s %s\n" "-------" "------" "----------"))
      (dolist (entry heks/doctor-programs)
        (let* ((program (car entry))
               (module (cadr entry))
               ;; The fallback is the tail of the pair, so that a row reads
               ;; as `(program module . what-is-lost)'.
               (fallback (cddr entry))
               (path (executable-find program))
               (version (and path (heks/doctor-version program)))
               (status (if path
                           (format "%s%s" path
                                   (if version (format " (%s)" version) ""))
                         "missing")))
          (unless path (setq missing (1+ missing)))
          (insert (format "%-14s %-46s %s\n" program status
                          (format "%s: %s" module fallback)))))
      (insert (format "\n%d of %d programs are missing.\n"
                      missing (length heks/doctor-programs)))
      (special-mode)
      (goto-char (point-min)))
    (display-buffer buffer)
    buffer))

(global-set-key (kbd "C-c ! d") #'heks/doctor)

;; What a file says it still has to do: `TODO', `FIXME', `XXX', `NOTE',
;; `HACK' and the rest are coloured wherever they are written, and walked
;; one at a time under the text tools, where the other things one does to
;; the text of a buffer live.
(use-package hl-todo
  :ensure t
  :hook ((prog-mode . hl-todo-mode)
         (org-mode . hl-todo-mode)
         (markdown-mode . hl-todo-mode)
         (markdown-ts-mode . hl-todo-mode))
  :bind (("C-c t n" . hl-todo-next)
         ("C-c t p" . hl-todo-previous))
  :config
  (setq hl-todo-highlight-punctuation ":"
        hl-todo-keyword-faces
        '(("TODO" . warning)
          ("FIXME" . error)
          ("BUG" . error)
          ("HACK" . warning)
          ("NOTE" . info)
          ("XXX" . warning)
          ("REVIEW" . info)
          ("DEPRECATED" . shadow))))

;; The occurrences of the symbol at point: lit up in the buffer, walked one
;; at a time, and renamed together.  It is the question a reader of code
;; asks most -- "where else is this?" -- answered without leaving the
;; buffer and without a search that has to be typed.
(use-package symbol-overlay
  :ensure t
  :bind (("C-c z o" . symbol-overlay-put)
         ("C-c z n" . symbol-overlay-jump-next)
         ("C-c z p" . symbol-overlay-jump-prev)
         ("C-c z r" . symbol-overlay-rename)
         ("C-c z k" . symbol-overlay-remove-all))
  :config
  ;; The package puts its own menu on `M-i' when it is loaded.  The keys
  ;; are under `C-c z' here, and a global key that shadowed `M-i' would be
  ;; the one thing in this configuration that is not where it says it is.
  (when (eq (key-binding (kbd "M-i")) 'symbol-overlay-map)
    (global-unset-key (kbd "M-i"))))

(provide 'heks/dev-tools)

;;; dev-tools.el ends here
