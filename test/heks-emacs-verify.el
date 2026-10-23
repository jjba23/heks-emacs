;;; heks-emacs-verify.el --- Check the installed configuration  -*- lexical-binding: t -*-

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

;; The configuration is a program with invariants, and until this file
;; existed nothing checked them: a module could stop loading, a keymap entry
;; could be dropped, a fold could stop covering a whole definition and a
;; checker could stop surviving the decorated output of a tool, and the only
;; symptom would be that something quietly stopped working weeks later.
;;
;; Run it over an installed configuration:
;;
;;   emacs -Q --batch -l test/heks-emacs-verify.el
;;   HEKS_VERIFY_DIR=/tmp/some-config emacs -Q --batch -l test/heks-emacs-verify.el
;;
;; It loads the configuration exactly as Emacs does at startup and then
;; asserts the things that are easy to break and hard to notice.  It exits
;; non-zero when any of them fails, so `maak verify' fails with it.

;;; Code:

(setq load-prefer-newer t)
(require 'cl-lib)
(require 'seq)

(defvar heks-verify--dir
  (file-name-as-directory
   (expand-file-name (or (getenv "HEKS_VERIFY_DIR") "~/.emacs.d/")))
  "The installed configuration to check.")

(defvar heks-verify--passed 0)
(defvar heks-verify--failed 0)

(defun heks-verify--section (title)
  "Announce the checks that follow as belonging to TITLE."
  (message "\n== %s ==" title))

(defun heks-verify--check (label value &rest expected-given)
  "Record that LABEL holds when VALUE equals the first of EXPECTED-GIVEN.

Without an explicit expectation the check is that VALUE is non-nil."
  (let ((expected (if expected-given (car expected-given) t)))
    (if (equal value expected)
        (progn (setq heks-verify--passed (1+ heks-verify--passed))
               (message "  ok   %s" label))
      (setq heks-verify--failed (1+ heks-verify--failed))
      (message "  FAIL %s -> %S (expected %S)" label value expected))))

(defmacro heks-verify--with-scheme-buffer (text &rest body)
  "Run BODY in a temporary `scheme-mode' buffer holding TEXT.

The buffer is given a file name and put through the configuration's own
major mode hook, so what BODY sees is what a real `.scm' buffer gets."
  (declare (indent 1))
  `(with-temp-buffer
     (insert ,text)
     (setq-local buffer-file-name
                 (expand-file-name "heks-verify.scm" temporary-file-directory))
     (scheme-mode)
     (goto-char (point-min))
     ,@body))

(defun heks-verify--hs-overlays ()
  "Return the Hideshow overlays of the current buffer."
  (seq-filter (lambda (overlay) (overlay-get overlay 'hs))
              (overlays-in (point-min) (point-max))))

(defun heks-verify--load-packages ()
  "Install and load what the configuration queued with Elpaca.

`init.el' queues every package and then has Elpaca work through the queue
from `after-init-hook', which a batch Emacs never runs.  Without this the
configuration is only half loaded: the `use-package' bodies of packages
have not run yet, so the keys, hooks and commands they add are not there,
and a check on them would report the startup process instead of the
configuration."
  (when (fboundp 'elpaca-wait)
    (let ((start (float-time)))
      (heks-verify--check "the queued packages are loaded"
                          (condition-case err
                              (progn (elpaca-wait) t)
                            (error (message "  package error: %s"
                                            (error-message-string err))
                                   nil)))
      (message "  (%.1fs spent loading packages)" (- (float-time) start)))))

(defun heks-verify--load-config ()
  "Load the installed configuration the way Emacs does at startup."
  (setq user-emacs-directory heks-verify--dir)
  (let ((init (expand-file-name "init.el" heks-verify--dir)))
    (heks-verify--check "init.el exists" (file-exists-p init))
    (heks-verify--check "the configuration loads"
                        (condition-case err
                            (progn (load init nil t) t)
                          (error (message "  load error: %s" (error-message-string err))
                                 nil)))
    (heks-verify--load-packages)))

;;;
;;; The checks
;;;

(heks-verify--section "the configuration")
(heks-verify--load-config)

(heks-verify--section "every module is loaded")
(heks-verify--check "the bridge module is loaded" (featurep 'heks/heks-emacs))
(when (boundp 'heks/modules)
  (dolist (module heks/modules)
    (let ((file (expand-file-name (format "modules/%s.el" module) heks-verify--dir)))
      (heks-verify--check (format "modules/%s.el is installed" module)
                          (file-exists-p file))
      ;; The feature a module provides is read out of the module rather than
      ;; guessed from its name, so a rename cannot make this check pass by
      ;; accident: `emacs-core' provides `heks/emacs-self'.
      (let ((feature (with-temp-buffer
                       (when (file-exists-p file)
                         (insert-file-contents file)
                         (goto-char (point-min))
                         (when (re-search-forward "^(provide '\\([^)]+\\)" nil t)
                           (intern (match-string 1)))))))
        (heks-verify--check (format "%s is loaded" feature)
                            (and feature (featurep feature)))))))

(heks-verify--section "the settings reach the modules that read them")

;; The customization variables are defined by `heks-emacs.el', given their
;; values by the bridge installed next to this configuration, and read by
;; every module after that.  A module that read one while it was still nil is
;; configured wrongly whatever the setting says a moment later, and the notes
;; -- whose notes directory is nobody's default -- is where that showed: it
;; was named after a nil, which stopped the configuration where it loaded.
(let ((notes (heks/notes-directory)))
  (if notes
      (heks-verify--check
       "the notes commands are loaded"
       (fboundp 'heks/notes-new))
    (heks-verify--check
     "no notes directory is built out of nothing"
     (null (heks/notes-directory)))))

(heks-verify--section "the tree-sitter grammars are built before they are needed")

;; A grammar Emacs fetches while a file is being opened is a wait on the
;; first file of every language; a language no recipe is known for is a
;; question instead.  Both are answered before anything is opened, by a
;; batch Emacs that builds every grammar this Emacs can be asked for -- so
;; what is checked here is that it is set up to: the directory it installs
;; into is the one this configuration looks in first, a grammar Emacs
;; fetches for itself is fetched without asking, the script is where the
;; child is told to load it, and the child is what runs at startup.
(heks-verify--check
 "the grammars go into this configuration's own directory, looked in first"
 (progn
   ;; treesit is loaded lazily, and both what this configuration adds to the
   ;; search path and what a package adds to it arrive when it is: loading it
   ;; here is the state a session is in the moment it is needed.
   (require 'treesit)
   (equal (car treesit-extra-load-path) heks/treesit-grammar-directory)))
(heks-verify--check
 "a grammar Emacs fetches for itself is fetched without asking"
 (eq treesit-auto-install-grammar 'always))
(heks-verify--check
 "the script that builds them is next to the installed configuration"
 (and (file-exists-p heks/treesit-script)
      (string-suffix-p "treesit-grammars.el" heks/treesit-script)))
(heks-verify--check
 "what the child is handed reads as Lisp"
 (eq (car (read (nth 4 (heks/treesit--batch-command)))) 'setq))
(heks-verify--check
 "and building them is what this configuration does at startup"
 (and (memq 'heks/treesit-install-grammars-in-background emacs-startup-hook)
      heks/treesit-install-grammars))

(heks-verify--section "reading what a tool says")
(heks-verify--check
 "a warning is parsed into its parts"
 (heks/parse-diagnostics "src/a.scm:12:3: warning: unused variable `y'\n")
 '(("src/a.scm" 12 3 :warning "unused variable `y'")))
(heks-verify--check
 "severities come from the message"
 (mapcar (lambda (line) (nth 3 (car (heks/parse-diagnostics line))))
         '("a.scm:1:1: error: no\n" "a.scm:1:1: note: hm\n" "a.scm:1:1: bare\n"))
 '(:error :note :warning))
(heks-verify--check
 "a hyperlinked, coloured diagnostic is still read"
 (heks/parse-diagnostics
  "\e]8;;file:///tmp/a.scm\a/tmp/a.scm\e]8;;\a:7:2: \e[31merror\e[0m: boom\n")
 '(("/tmp/a.scm" 7 2 :error "boom")))
(heks-verify--check
 "a backtrace is not mistaken for a diagnostic"
 (heks/parse-diagnostics
  "Backtrace:\nIn ice-9/boot-9.scm:\n  1705:22 0 (raise-exception _)\nno code for module\n")
 nil)
(heks-verify--check
 "the reason for a hard failure is found below the backtrace"
 (heks/tool-error-line
  "Backtrace:\nIn srfi/srfi-1.scm:\n  750:9 19 (for-each _)\nno code for module (nope)\n")
 "no code for module (nope)")
(heks-verify--check "changed lines are found"
                    (heks/tool-changed-lines "a\nb\nc\n" "a\nB\nc\n")
                    '(2))
(heks-verify--check "neighbouring lines become one range"
                    (heks/tool-number-ranges '(1 2 3 7))
                    '((1 . 3) (7 . 7)))

;; The shape of a diagnostic is the part of the Emacs API that changed under
;; this configuration's feet: Emacs builds the string the user reads out of
;; an origin, a code and a message, and a diagnostic whose message has been
;; put in the wrong slot reads with an empty headline in front of it.
(heks-verify--section "a diagnostic reads the way it should")
(with-temp-buffer
  (insert "(define one 1)\n(define two 2)\n")
  (let ((diags (heks/tool-diagnostic-list
                "/tmp/heks-verify.scm:2:1: warning: stand-in says no\n"
                "/tmp/heks-verify.scm" "/tmp" "stand-in")))
    (heks-verify--check "a diagnostic is produced" (length diags) 1)
    (heks-verify--check "it names the tool that reported it"
                        (flymake-diagnostic-text (car diags)) "stand-in : stand-in says no")
    (heks-verify--check "its message is the message"
                        (flymake-diagnostic-text (car diags) '(message))
                        "stand-in says no")
    (heks-verify--check "it sits on the line that was reported"
                        (line-number-at-pos (flymake-diagnostic-beg (car diags))) 2)
    (heks-verify--check "it is a warning"
                        (flymake-diagnostic-type (car diags)) :warning)))

;;;
;;; The compilation buffer
;;;

;; What a tool writes is coloured, and what colours it is `fancy-compilation',
;; which does its work by advising `compilation-filter' and `compilation-start'
;; rather than by a mode a buffer turns on.  That is why the mode has to be on
;; before the first compilation rather than when it is first wanted: a
;; compilation buffer shows the escapes a tool wrote until something reads
;; them, and by the time one notices, the output is already in the buffer.
;; The colours are looked for where `ansi-color' puts them, which is an
;; overlay rather than a text property (see `ansi-color-apply-face-function').
(heks-verify--section "a compilation buffer colours what a tool colours")
(heks-verify--check "the mode that colours it is on"
                    (and fancy-compilation-mode t))
(heks-verify--check "and it was on before any compilation started"
                    (and (advice-member-p 'fancy-compilation--compilation-filter
                                          'compilation-filter)
                         t))
(heks-verify--check "a tool is told it is talking to a terminal"
                    (and (advice-member-p 'fancy-compilation--compile 'compile) t))
(let* ((default-directory (file-name-as-directory (make-temp-file "heks-verify-compile-" t)))
       ;; What a tool colours, written the way a tool writes it.
       (buffer (compile
                (concat "printf 'plain \\033[32mgreen\\033[0m and "
                        "\\033[1;31mred\\033[0m\\n'")))
       (buffer (if (consp buffer) (car buffer) buffer)))
  (unwind-protect
      (with-current-buffer buffer
        (let ((tries 0))
          (while (and (< tries 200) (get-buffer-process buffer))
            (accept-process-output nil 0.1)
            (setq tries (1+ tries))))
        (accept-process-output nil 0.2)
        (let ((text (buffer-substring-no-properties (point-min) (point-max))))
          (heks-verify--check "the output arrived, with the escapes read"
                              (and (string-match-p "plain green and red" text) t))
          (heks-verify--check "and no escape character is left in the buffer"
                              (and (not (string-match-p "\033" text)) t)))
        (heks-verify--check
         "a coloured word is coloured, and stays so as more output arrives"
         (and (goto-char (point-min))
              (search-forward "green" nil t)
              (seq-some (lambda (overlay)
                          (let ((face (overlay-get overlay 'face)))
                            (and (consp face)
                                 (memq (car face) '(ansi-color-green :foreground
                                                    ansi-color-bright-green))
                                 t)))
                        (overlays-at (match-beginning 0))))))
    (kill-buffer buffer)))

;;;
;;; Guile
;;;

(heks-verify--section "the Guile module is wired up")
(dolist (name '(heks/scheme-repl
                heks/scheme-eval-definition
                heks/scheme-debugger
                heks/scheme-xref-backend
                heks/scheme-definitions-in-files
                heks/scheme-mentions-in-files
                heks/scheme-defined-names
                heks/scheme-callers
                heks/scheme-test
                heks/scheme-format-buffer
                heks/guix-style-apply-rule
                heks/guile-compile-backend
                heks/guix-lint-backend
                heks/guix-style-backend))
  (heks-verify--check (format "%s is defined" name) (fboundp name)))

(heks-verify--section "the keys the key scheme promises")

;; `emacs-core.el' describes the scheme: one letter for the topic, one for
;; the action, the same meaning everywhere.  These are the keys each part
;; of the configuration has to keep, so that a rename is caught here
;; instead of by the fingers that had learned it.
;;
;; `key-binding' rather than `lookup-key' is the one to ask: `C-c' is not a
;; keymap in the global map but the symbol `mode-specific-command-prefix',
;; which `lookup-key' stops at and reports as a prefix, while `key-binding'
;; resolves it, and the current buffer's own maps with it, the way pressing
;; the key does.
;; The map holds the keys that are Scheme's own.  Folding and formatting are
;; bound once, globally, and are checked in the buffer further down, where a
;; map that had also answered the global key shows up as the wrong command.
(with-temp-buffer
  (insert "(define (f x) x)")
  (dolist (key '("C-c g r" "C-c g R" "C-c g s" "C-c g e" "C-c g E" "C-c g b"
                 "C-c g k" "C-c g x" "C-c g d" "C-c g g" "C-c g h" "C-c g c"
                 "C-c g C" "C-c g m" "C-c g t" "C-c g L" "C-c g f" "C-c g S"
                 "C-c g p" "C-c s p" "C-c s a" "C-c s h"))
    (heks-verify--check (format "a Scheme buffer has %s" key)
                        (commandp (lookup-key heks/scheme-mode-map (kbd key))))))

;; What the keys above are worth is that they are the ones that answer when
;; the key is pressed in a buffer, whichever mode the buffer is in.
(heks-verify--with-scheme-buffer "(define (f x)\n  x)\n"
  (heks-verify--check "the fold key is the global one in a Scheme buffer"
                      (key-binding (kbd "C-c v c")) 'heks/fold-close)
  (heks-verify--check "the format key is the global one in a Scheme buffer"
                      (key-binding (kbd "C-c i f")) 'heks/format-buffer))

(dolist (key '("C-c ! n" "C-c ! N" "C-c ! b" "C-c ! a" "C-c ! m"
               "C-c a v" "C-c a l" "C-c a r" "C-c a b"
               "C-c c d" "C-c d p" "C-c d m"
               "C-c e d" "C-c e a"
               "C-c h h" "C-c h f" "C-c h v" "C-c h k"
               "C-c i f" "C-c j m" "C-c j M" "C-c j g" "C-c j G"
               "C-c j s" "C-c j R" "C-c l d" "C-c l e" "C-c m r"
               "C-c n v" "C-c o m" "C-c o g"
               "C-c r p" "C-c r b" "C-c r e" "C-c r m" "C-c r r" "C-c r s"
               "C-c t a" "C-c t w" "C-c t c" "C-c t n" "C-c t p"
               "C-c v o" "C-c v O" "C-c v c" "C-c v C" "C-c v r" "C-c v t" "C-c v d"
               "C-c v D"
               "C-c w r" "C-c w f" "C-c w t" "C-c w d" "C-c w g"
               "C-c z e" "C-c z s" "C-c z o" "C-c z n" "C-c z p" "C-c z r"
               "C-c z k" "C-c z j" "C-c z J"
               "C-c # s" "C-c # u" "C-c # f" "C-c # j" "C-c # e"
               "C-c f n" "C-c f t" "C-c f s" "C-c f r" "C-c f l" "C-c f L"
               "C-c f j" "C-c f c"))
  (heks-verify--check (format "%s is bound" key)
                      (commandp (key-binding (kbd key)))))
(heks-verify--check "C-c p is the completion prefix"
                    (keymapp (key-binding (kbd "C-c p"))))
;; `C-c u' is kubed's own menu rather than a command of this configuration,
;; and which keys it holds is the package's business: an older kubed had a
;; `u' inside it and this one does not, so what is checked is the menu.
(heks-verify--check "C-c u is kubed's prefix"
                    (keymapp (key-binding (kbd "C-c u"))))


;;; A definition spread over several lines, which is what a real one looks
;;; like: Hideshow does not offer to hide a form that fits on one line, since
;;; there would be nothing left to see.
(defconst heks-verify--scheme-source
  (concat "(define-module (verify demo)\n"
          "  #:use-module (ice-9 match))\n"
          "\n"
          "(define (one x)\n"
          "  \"Return twice X.\"\n"
          "  (* 2 x))\n"
          "\n"
          "(define (two x)\n"
          "  (+ x\n"
          "     (one x)))\n"))

(heks-verify--section "a Scheme buffer is set up for work")
(heks-verify--with-scheme-buffer heks-verify--scheme-source
  (heks-verify--check "Hideshow is on" hs-minor-mode)
  (heks-verify--check "a top-level form is what gets folded"
                      hs-block-start-regexp "^(")
  (heks-verify--check "the compiler checks the buffer"
                      (and (memq 'heks/guile-compile-backend
                                 flymake-diagnostic-functions)
                           t))
  (heks-verify--check "the bad-practice checker runs beside it"
                      (and (memq 'heks/scheme-lint-check
                                 flymake-diagnostic-functions)
                           t))
  (heks-verify--check "Flymake is on" flymake-mode)

  (heks-verify--section "folding covers a whole definition")
  ;; Point goes into the *middle* of the definition, which is where it is
  ;; when one wants to collapse what one is looking at.
  (goto-char (point-max))
  (search-backward "(one x)")
  (hs-toggle-hiding)
  (let ((overlays (heks-verify--hs-overlays)))
    (heks-verify--check "one definition is hidden" (length overlays) 1)
    (heks-verify--check "it starts on the definition's own line"
                        (line-number-at-pos (overlay-start (car overlays))) 8)
    (heks-verify--check "and covers it to the last line"
                        (line-number-at-pos (overlay-end (car overlays))) 10))
  (hs-show-all)
  (heks-verify--check "nothing stays hidden" (heks-verify--hs-overlays) nil)
  (hs-hide-all)
  (heks-verify--check "collapsing the file hides every top-level form"
                      (length (heks-verify--hs-overlays)) 3)
  (hs-show-all)
  (heks-verify--check "and brings them all back" (heks-verify--hs-overlays) nil))

;;;
;;; Without Guix
;;;

;; The point of this configuration on a machine that has no Guix -- a Mac,
;; say -- is that it is still a complete Guile setup.  Guix's absence is
;; simulated rather than required, so the check runs everywhere.
(heks-verify--section "without Guix, Guile is still checked")
(cl-letf (((symbol-function 'heks/tool-available-p)
           (lambda (program) (not (equal program heks/guix-program)))))
  (heks-verify--check "Guix is seen as missing" (heks/guix-available-p) nil)
  (heks-verify--check "Guile is still there" (heks/guile-available-p))
  (heks-verify--with-scheme-buffer
      "(define-module (verify package))\n(define-public hello (package))\n"
    ;; The file *looks* like a Guix package, but nothing here can lint one,
    ;; so the compiler has to be the checker instead of nothing at all.
    (heks-verify--check "a Guix-looking file is checked by the Guile compiler"
                        (heks/guile-compile-applies-p))
    (heks-verify--check "the Guix checkers bow out"
                        (and (not (memq 'heks/guix-lint-backend
                                        flymake-diagnostic-functions))
                             (not (memq 'heks/guix-style-backend
                                        flymake-diagnostic-functions))
                             t))
    (heks-verify--check "a Guix REPL is not offered" (heks/scheme-guile-binary) nil)))

;;;
;;; Finding a definition
;;;

;; A project of its own: a definition in one file, a call of it in the
;; other, and no REPL anywhere.  This is the case that used to be the error
;; that said to try M-x geiser.
(defconst heks-verify--scheme-definition-dir
  (file-name-as-directory
   (expand-file-name "heks-verify-scheme" temporary-file-directory)))

(heks-verify--section "a definition is found with no REPL to ask")
(let* ((root heks-verify--scheme-definition-dir)
       (utility (expand-file-name "utility.scm" root))
       (main (expand-file-name "main.scm" root)))
  (unwind-protect
      (progn
        (make-directory root t)
        (write-region (concat "(define (greet name)\n"
                              "  name)\n"
                              "(define-public pub-var 1)\n")
                      nil utility nil 'silent)
        (write-region (concat "(define (main)\n"
                              "  (greet name))\n"
                              "(define-public pub-var 2)\n")
                      nil main nil 'silent)
        (let ((buffer (find-file-noselect main)))
          (unwind-protect
              (with-current-buffer buffer
                (setq-local default-directory root)
                (heks-verify--check "the file is a Scheme buffer"
                                    (and (derived-mode-p 'scheme-mode) t))
                (heks-verify--check
                 "the definition is found in the other file"
                 (mapcar (lambda (item)
                           (file-name-nondirectory
                            (xref-file-location-file (xref-item-location item))))
                         (heks/scheme-definitions-in-files "greet"))
                 '("utility.scm"))
                (heks-verify--check
                 "defined in both files, and the one being read comes first"
                 (mapcar (lambda (item)
                           (let ((location (xref-item-location item)))
                             (list (file-name-nondirectory
                                    (xref-file-location-file location))
                                   (xref-file-location-line location))))
                         (heks/scheme-definitions-in-files "pub-var"))
                 '(("main.scm" 3) ("utility.scm" 3)))
                ;; The command is Emacs's own -- `xref-find-definitions',
                ;; which is what `M-.' is everywhere -- and what answers it
                ;; in this buffer is the backend the configuration installs.
                ;; The prompt and the display are caught, because a batch
                ;; Emacs has no minibuffer and the configuration shows a
                ;; list of definitions in `consult-xref'.
                (heks-verify--check "`M-.' is `xref-find-definitions' here"
                                    (key-binding (kbd "M-.")) 'xref-find-definitions)
                (heks-verify--check "and `C-c g g' is that same command"
                                    (key-binding (kbd "C-c g g")) 'xref-find-definitions)
                (heks-verify--check "the backend a Scheme buffer is jumped with"
                                    (xref-find-backend) 'heks/scheme)
                (goto-char (point-min))
                (search-forward "(greet name)")
                (goto-char (match-beginning 0))
                (forward-char 1)
                (let* ((found nil)
                       (prompted nil)
                       (references nil))
                  (cl-letf (((symbol-function 'completing-read)
                             (lambda (prompt collection &rest _)
                               (setq prompted (list prompt
                                                    (and (listp collection)
                                                         (all-completions "" collection))))
                               "")))
                    (let ((xref-show-definitions-function
                           (lambda (fetcher _alist)
                             (setq found (funcall fetcher))
                             (when found (xref-pop-to-location (car found) nil)))))
                      (call-interactively #'xref-find-definitions))
                    (let ((xref-show-xrefs-function
                           (lambda (fetcher _alist)
                             (setq references (funcall fetcher)))))
                      (call-interactively #'xref-find-references)))
                  (heks-verify--check "one definition is offered" (length found) 1)
                  (heks-verify--check "the jump lands in the file that defines it"
                                      (file-name-nondirectory (buffer-file-name))
                                      "utility.scm")
                  (heks-verify--check "and on the line of the definition"
                                      (line-number-at-pos) 1)
                  (heks-verify--check "and on the name itself"
                                      (thing-at-point 'symbol) "greet")
                  (heks-verify--check "the names a jump can be asked for"
                                      (nth 1 prompted) '("greet" "main" "pub-var"))
                  ;; `M-?' is `xref-find-references', and with no REPL the
                  ;; files say where a name is written -- the file being read
                  ;; first, which after the jump is the one that defines it.
                  (heks-verify--check
                   "the definition and the call are the places greet is used"
                   (mapcar (lambda (item)
                             (let ((location (xref-item-location item)))
                               (list (file-name-nondirectory
                                      (xref-file-location-file location))
                                     (xref-file-location-line location))))
                           references)
                   '(("utility.scm" 1) ("main.scm" 2)))
                  ;; `M-s .' is the other question this backend answers: not
                  ;; where one name is, but which names match a pattern.
                  ;; With no REPL the heads of the definitions of the project
                  ;; answer it, and the head is what an entry shows.
                  (let ((matches nil))
                    (cl-letf (((symbol-function 'read-string)
                               (lambda (&rest _) "pub")))
                      (let ((xref-show-xrefs-function
                             (lambda (fetcher _action)
                               (setq matches (funcall fetcher)))))
                        (call-interactively #'xref-find-apropos)))
                    (heks-verify--check
                     "a pattern is answered with the definitions that match it"
                     (mapcar (lambda (item)
                               (let ((location (xref-item-location item)))
                                 (list (file-name-nondirectory
                                        (xref-file-location-file location))
                                       (xref-file-location-line location))))
                             matches)
                     '(("utility.scm" 3) ("main.scm" 3)))
                    (heks-verify--check
                     "and the head of the definition is the line of the entry"
                     (xref-item-summary (car matches))
                     "(define-public pub-var 1)"))
                  (heks-verify--check "no REPL was started to answer"
                                      (heks/scheme-repl-connected-p) nil)))
            (set-buffer-modified-p nil)
            (kill-buffer buffer))))
    (ignore-errors (delete-directory root t))))

;;;
;;; Shell: the checker and the formatter
;;;

(heks-verify--section "the shell tools are wired up")
(dolist (name '(heks/shfmt-backend
                heks/shfmt-command
                heks/shell-format-buffer))
  (heks-verify--check (format "%s is defined" name) (fboundp name)))
(heks-verify--check "sh-mode runs the shell setup"
                    (and (memq #'heks/shell-setup-flymake sh-mode-hook) t))
(heks-verify--check "and so does bash-ts-mode, the mode a `.sh' file opens in"
                    (and (memq #'heks/shell-setup-flymake bash-ts-mode-hook) t))

;; A real shell buffer is what the checks below run in, made the way a file
;; makes one, so that the mode hook of the configuration runs on it.
(defmacro heks-verify--with-shell-buffer (text &rest body)
  "Run BODY in a temporary shell buffer holding TEXT.

The buffer is given a `.sh' file name and put through a real shell major
mode, so what BODY sees is what a `.sh' file gets."
  (declare (indent 1))
  `(with-temp-buffer
     (insert ,text)
     (setq-local buffer-file-name
                 (expand-file-name "heks-verify.sh" temporary-file-directory))
     (sh-mode)
     (goto-char (point-min))
     ,@body))

(heks-verify--with-shell-buffer "#!/bin/bash\necho \"$x\"\n"
  (heks-verify--check "Flymake is on in a shell buffer" flymake-mode)
  ;; Shellcheck is Emacs's own backend, registered by the mode itself, and
  ;; what this configuration adds to it is the flag that makes a script's
  ;; `source'd files count.
  (heks-verify--check "Emacs's shellcheck backend is registered"
                      (and (memq 'sh-shellcheck-flymake flymake-diagnostic-functions) t))
  (heks-verify--check "and told to follow the sources a script names"
                      (and (member "--external-sources" sh-shellcheck-arguments) t))
  (heks-verify--check "shfmt reports the drift of the buffer"
                      (and (memq 'heks/shfmt-backend
                                 flymake-diagnostic-functions)
                           t))
  ;; The library registers a shellcheck backend of its own; Emacs's is the
  ;; one authority, so the library's must not be there as well.
  (heks-verify--check "and the library's shellcheck is not there"
                      (not (memq 'flymake-collection-shellcheck
                                 flymake-diagnostic-functions))))

;; Flymake's backends are asynchronous, so a check that wants to look at
;; what one reports has to wait for it rather than read what is there.
(defun heks-verify--run-backend (backend)
  "Run the Flymake BACKEND in this buffer and return (ANSWERED . DIAGNOSTICS)."
  (let (reported done)
    (funcall backend (lambda (diagnostics) (setq reported diagnostics done t)))
    (let ((tries 0))
      (while (and (not done) (< tries 60))
        (accept-process-output nil 0.25)
        (setq tries (1+ tries))))
    (cons done reported)))

(defun heks-verify--backend-messages (answer)
  "Return the messages of the diagnostics an ANSWER from a backend holds."
  (mapcar (lambda (diagnostic)
            (format "%s" (flymake-diagnostic-text diagnostic '(message))))
          (cdr answer)))

(defun heks-verify--diagnostic-line (diagnostic)
  "Return the line DIAGNOSTIC is on.

A backend may give a position as the `(LINE . COLUMN)' pair Emacs's own
shellcheck backend does rather than as a buffer position, and the line is
the first of the two either way."
  (let ((beg (flymake-diagnostic-beg diagnostic)))
    (if (consp beg) (car beg) (line-number-at-pos beg))))

;; The checker itself, run the way Flymake runs it: Emacs's own backend,
;; with the flags this configuration gives it, has to report the unquoted
;; variable on the line it is on.  Where shellcheck is not installed there
;; is nothing to report, so what is checked is that the flag is set and the
;; backend is registered for when it is.
(heks-verify--section "shellcheck really checks a script")
(heks-verify--with-shell-buffer "#!/bin/bash\necho $foo\n"
  (if (executable-find sh-shellcheck-program)
      (let* ((answer (heks-verify--run-backend #'sh-shellcheck-flymake))
             (diagnostics (cdr answer)))
        (heks-verify--check "shellcheck answers" (car answer))
        (heks-verify--check
         "and reports the unquoted variable as a diagnostic on its own line"
         (and (seq-find (lambda (diagnostic)
                          (and (= 2 (heks-verify--diagnostic-line diagnostic))
                               (string-match-p "SC2086"
                                               (format "%s" (flymake-diagnostic-text
                                                             diagnostic '(message))))))
                        diagnostics)
              t)))
    (heks-verify--check "shellcheck is not installed, so there is nothing to report"
                        (executable-find sh-shellcheck-program) nil)))

;; And what the flag it was given is worth: the variables a *sourced* file
;; sets are known, so a script that sources its own library is not covered
;; in warnings about them being unassigned.
(heks-verify--section "the sources a script names are followed")
(if (executable-find sh-shellcheck-program)
    (let* ((dir (file-name-as-directory (make-temp-file "heks-verify-source" t)))
           (file (expand-file-name "script.sh" dir)))
      (unwind-protect
          (progn
            (write-region "a=1\n" nil (expand-file-name "lib.sh" dir) nil 'silent)
            (write-region "#!/bin/bash\nsource ./lib.sh\necho \"$a\"\n" nil file nil 'silent)
            (with-current-buffer (find-file-noselect file)
              (unwind-protect
                  (let* ((answer (heks-verify--run-backend #'sh-shellcheck-flymake))
                         (messages (heks-verify--backend-messages answer)))
                    (heks-verify--check "shellcheck answers" (car answer))
                    (heks-verify--check
                     "a variable set by a sourced file is not called unassigned"
                     (not (seq-find (lambda (message)
                                      (string-match-p "SC2154" message))
                                    messages))))
                (set-buffer-modified-p nil)
                (kill-buffer))))
        (delete-directory dir t)))
  (heks-verify--check "shellcheck is not installed, so nothing is followed" t))

(heks-verify--section "shfmt really formats a script")
(if (heks/shfmt-available-p)
    (let ((file (make-temp-file "heks-verify-shfmt" nil ".sh")))
      (unwind-protect
          (progn
            ;; A block whose body is not indented, which is what `shfmt'
            ;; has an opinion about: the body comes back indented.
            (write-region "#!/bin/bash\nif [ \"$x\" = 1 ]; then\necho hi\nfi\n"
                          nil file nil 'silent)
            (let ((command (heks/shfmt-command file)))
              (apply #'call-process (car command) nil nil nil (cdr command)))
            (heks-verify--check
             "the file is rewritten the way shfmt writes shell"
             (with-temp-buffer
               (insert-file-contents file)
               (and (string-match-p "^[ \t]+echo hi$" (buffer-string)) t))))
        (delete-file file)))
  (heks-verify--check "shfmt is not installed, so its backend bows out"
                      (heks/shfmt-applies-p) nil))

;; And the one format key reaches it, which is the part a user presses.
(heks-verify--section "the format key reaches shfmt in a shell buffer")
(if (heks/shfmt-available-p)
    (heks-verify--with-shell-buffer "echo hi\n"
      (heks-verify--check "a shell buffer is claimed by the shell formatter"
                          (eq (cdr (seq-find (lambda (entry) (funcall (car entry)))
                                             heks/format-dispatch))
                              'heks/shell-format-buffer)))
  (heks-verify--check "without shfmt the key falls through to another formatter"
                      (heks/shell-format-applies-p) nil))

;;;
;;; The shell language server
;;;

;; The server is kept for what it knows that is not a diagnostic --
;; completion, hover, the symbols of a file, a definition and its
;; references, a rename -- and its own shellcheck and shfmt are turned off
;; in it, because the checking and the formatting of a shell script are
;; already done for every one of them (Emacs's `sh-shellcheck-flymake' and
;; the shfmt of `shell.el').
(heks-verify--section "a shell script gets a language server, not a second toolchain")
;; Eglot is part of Emacs, and loading it here is what makes the checks
;; below read the configuration it is given rather than a symbol on a hook.
(require 'eglot)
(heks-verify--check "sh-mode asks for a language server"
                    (and (memq 'heks/eglot-ensure sh-mode-hook) t))
(heks-verify--check "and so does bash-ts-mode, the mode a `.sh' file opens in"
                    (and (memq 'heks/eglot-ensure bash-ts-mode-hook) t))
(heks-verify--check "Emacs knows which server to start for one"
                    (equal (cdr (seq-find
                                 (lambda (entry)
                                   (let ((modes (if (listp (car entry))
                                                    (car entry)
                                                  (list (car entry)))))
                                     (memq 'bash-ts-mode modes)))
                                 eglot-server-programs))
                           '("bash-language-server" "start")))
(let ((shell (plist-get (default-value 'eglot-workspace-configuration) :bashIde)))
  (heks-verify--check "the server is told not to run shellcheck"
                      (plist-get shell :shellcheckPath) "")
  (heks-verify--check "and not to format either, which shfmt does here"
                      (plist-get (plist-get shell :shfmt) :path) ""))

;; And the other half of that, which is what would leave a buffer checked by
;; nothing: Eglot makes its own backend the only Flymake one for as long as
;; it manages a buffer -- it saves `flymake-diagnostic-functions' and
;; replaces it -- so what the buffer already had is put back by one function,
;; for every language, in `dev-flymake.el'.  The swap below is the one Eglot makes,
;; made with the macro its own mode is written with, so what is being read is
;; Eglot's behaviour and not a list this file made up.
(heks-verify--section "a language server does not take the checkers away")
(heks-verify--check "one function answers for every language at once"
                    (and (memq 'heks/flymake-keep-backends
                               eglot-managed-mode-hook)
                         t))
(heks-verify--with-shell-buffer "#!/bin/bash\necho $foo\n"
  (setq-local eglot--managed-mode t)
  (eval '(eglot--setq-saving flymake-diagnostic-functions
                             '(eglot-flymake-backend))
        t)
  (heks-verify--check "a managed shell buffer is checked by the server alone"
                      flymake-diagnostic-functions '(eglot-flymake-backend))
  (let ((asked nil))
    (cl-letf (((symbol-function 'flymake-start)
               (lambda (&rest _) (setq asked t))))
      (heks/flymake-keep-backends))
    (heks-verify--check "Flymake is asked to check it again" asked))
  (heks-verify--check "the server's own backend stays where it is"
                      (and (memq 'eglot-flymake-backend flymake-diagnostic-functions) t))
  (heks-verify--check "and shellcheck is put back beside it"
                      (and (memq 'sh-shellcheck-flymake flymake-diagnostic-functions) t))
  (heks-verify--check "and so is the drift shfmt reports"
                      (and (memq 'heks/shfmt-backend flymake-diagnostic-functions) t)))

;; Nor is it a shell function.  A Python buffer is checked by whatever
;; registers its checkers -- `python-base-mode', the library's configuration
;; above -- and the whole of that set comes back, with no line of the
;; configuration about Python's server or Python's checkers.
(require 'python)
;; The configuration's own `python-mode-hook' entries are not what is being
;; read here, and one of them would start a server.
(let ((python-mode-hook nil))
  (with-temp-buffer
    (python-mode)
    (let ((before flymake-diagnostic-functions))
      (heks-verify--check "a Python buffer is checked before any server is"
                          (and before t))
      (setq-local eglot--managed-mode t)
      (eval '(eglot--setq-saving flymake-diagnostic-functions
                                 '(eglot-flymake-backend))
            t)
      (cl-letf (((symbol-function 'flymake-start) (lambda (&rest _) nil)))
        (heks/flymake-keep-backends))
      (heks-verify--check "and every one of its checkers survives a server"
                          (seq-difference before flymake-diagnostic-functions) nil)
      (heks-verify--check "with only the server's own backend added"
                          (- (length flymake-diagnostic-functions) (length before))
                          1))))

;;;
;;; The interface
;;;

(heks-verify--section "the type scale and the separators")
(heks-verify--check "the base type size is a size" (numberp heks/base-font-size))
(heks-verify--check "a face height is an absolute number"
                    (integerp (heks/font-height 1.0)))
(heks-verify--check "face sizes hold their ratio to the base size"
                    (<= (abs (- (heks/font-height 2.0)
                                (* 2 (heks/font-height 1.0))))
                        1))
(heks-verify--check "a larger multiple is a larger size"
                    (> (heks/font-height 1.5) (heks/font-height 1.0)))
(let ((color (heks/window-divider-color)))
  (heks-verify--check "the separators between windows have a color"
                      (and (stringp color) (string-prefix-p "#" color)))
  (heks/set-window-divider-faces)
  (dolist (face '(window-divider window-divider-first-pixel
                  window-divider-last-pixel vertical-border))
    (heks-verify--check (format "%s is drawn with it" face)
                        (equal (downcase (format "%s" (face-attribute face :background nil t)))
                               (downcase color)))))

;;;
;;; Formatting and folding, which every language shares
;;;

(heks-verify--section "one format key, whichever the language")
;; The dispatcher is a table a language module adds itself to, so what is
;; worth checking is that Scheme is in it and that the buffer decides, not
;; the global state.
(heks-verify--check "Scheme is in the format dispatch table"
                    (and (seq-find (lambda (entry)
                                     (and (functionp (cdr entry))
                                          (eq (cdr entry) 'heks/scheme-format-buffer)))
                                   (bound-and-true-p heks/format-dispatch))
                         t))
(heks-verify--with-scheme-buffer "(define-module (verify one))\n"
  (heks-verify--check "a Scheme buffer is claimed by the Scheme formatter"
                      (and (seq-find (lambda (entry) (funcall (car entry)))
                                     heks/format-dispatch)
                           t))
(heks-verify--check "the format command exists" (commandp 'heks/format-buffer)))

(heks-verify--section "one fold key, whichever the mode")
(heks-verify--with-scheme-buffer heks-verify--scheme-source
  ;; Hideshow is what folds these buffers, and kirigami is the interface
  ;; that knows it: the keys the user has do not mention either.
  (goto-char (point-min))
  (search-forward "(two x)")
  (heks/fold-toggle)
  (heks-verify--check "the fold key folds the definition at point"
                      (length (heks-verify--hs-overlays)) 1)
  (heks/fold-open-all)
  (heks-verify--check "the reveal key brings everything back"
                      (heks-verify--hs-overlays) nil)
  (heks/fold-close-all)
  ;; The source has three top-level forms: the `define-module' and the two
  ;; definitions, which is what hiding every block has to cover.
  (heks-verify--check "folding everything hides every form"
                      (length (heks-verify--hs-overlays)) 3)
  (heks/fold-toggle)
  (heks-verify--check "and toggling still works with folds closed"
                      (>= (length (heks-verify--hs-overlays)) 1) t)
  (heks/fold-open-all))

;;;
;;; Rendering what one reads
;;;

(heks-verify--section "a Markdown file renders")
(with-temp-buffer
  (insert "# Title\n\n"
          "Some *emphasis* and a [link](https://example.com).\n\n"
          "- one\n- two\n\n"
          "```elisp\n(+ 1 2)\n```\n")
  (setq-local buffer-file-name (expand-file-name "HEKS-VERIFY.md" temporary-file-directory))
  (markdown-ts-mode)
  (heks-verify--check "it is recognised as Markdown" (heks/render-markdown-p))
  (let ((body (heks/render-body)))
    (heks-verify--check "the heading becomes a heading"
                        (and (string-match-p "<h1>Title</h1>" body) t))
    (heks-verify--check "the emphasis is rendered"
                        (and (string-match-p "<em>emphasis</em>" body) t))
    (heks-verify--check "the code block is kept"
                        (and (string-match-p "language-elisp" body) t)))
  (let ((document (heks/render-document)))
    (heks-verify--check "it is wrapped in a document"
                        (and (string-prefix-p "<!DOCTYPE html>" document) t))
    (heks-verify--check "the document names its renderer"
                        (and (string-match-p "class=\"headline\">Markdown" document) t))
    (heks-verify--check "the stylesheet is themed, not linked"
                        (and (string-match-p "<style>" document) t)))
  ;; The preview writes a document and shows it, which is the part a user
  ;; actually presses a key for.  It is run for real here: EWW renders
  ;; in batch as well as it does in a frame.
  (let ((file (heks/render-file)))
    (heks-verify--check "the preview file is written" (file-exists-p file))
    ;; What is written is a whole document, and a document's headings are
    ;; given ids, because that is what a link to one of them points at.
    (heks-verify--check "and holds the rendered document"
                        (with-temp-buffer
                          (insert-file-contents file)
                          (and (string-match-p "<h1 id=\"title\">Title</h1>" (buffer-string)) t))))
  ;; And the preview shows it, which is the part a key is pressed for.  It is
  ;; asked to show the document in the preview buffer and then that buffer is
  ;; looked at: EWW kills the buffer it renders *from*, so a preview that
  ;; renders from its own destination is left holding a dead one.
  (let ((preview (get-buffer heks/preview-buffer-name)))
    (when preview (kill-buffer preview)))
  (heks/preview)
  (let ((shown (get-buffer heks/preview-buffer-name)))
    (heks-verify--check "and the preview holds it, in a buffer that survives"
                        (and (buffer-live-p shown)
                             (with-current-buffer shown
                               (and (eq major-mode 'eww-mode)
                                    (string-match-p "Title" (buffer-string)) t))))))

(heks-verify--section "an OpenAPI specification is read, checked and shown")

(defconst heks-verify--openapi-good
  (concat "{\n"
          "  \"openapi\": \"3.1.0\",\n"
          "  \"info\": {\"title\": \"Widgets\", \"version\": \"1.0.0\"},\n"
          "  \"servers\": [{\"url\": \"https://api.example.com/v1\"}],\n"
          "  \"paths\": {\n"
          "    \"/widgets/{id}\": {\n"
          "      \"get\": {\n"
          "        \"operationId\": \"getWidget\",\n"
          "        \"tags\": [\"widgets\"],\n"
          "        \"parameters\": [{\"name\": \"id\", \"in\": \"path\", \"required\": true,\n"
          "                          \"schema\": {\"type\": \"string\"}}],\n"
          "        \"responses\": {\"200\": {\"description\": \"the widget\"}}\n"
          "      }\n"
          "    }\n"
          "  },\n"
          "  \"components\": {\"schemas\": {\"Widget\": {\"type\": \"object\",\n"
          "                                           \"description\": \"a widget\"}}}\n"
          "}\n")
  "A specification with nothing wrong with it.")

(defmacro heks-verify--with-spec-buffer (text name &rest body)
  "Run BODY in a temporary buffer holding TEXT, as the file NAME."
  (declare (indent 2))
  `(let ((buffer (generate-new-buffer ,name)))
     (unwind-protect
         (with-current-buffer buffer
           (insert ,text)
           (js-json-mode)
           (setq-local buffer-file-name (expand-file-name ,name temporary-file-directory))
           (goto-char (point-min))
           ,@body)
       (kill-buffer buffer))))

(heks-verify--with-spec-buffer heks-verify--openapi-good "openapi.json"
  (heks-verify--check "it is recognised as a specification" (heks/openapi-spec-p))
  (heks-verify--check "it reads" (and (hash-table-p (heks/openapi-parse)) t))
  (heks-verify--check "it has one operation"
                      (length (heks/openapi-operations (heks/openapi-parse))) 1)
  (heks-verify--check "and no problems" (heks/openapi-diagnostics) nil)
  (let ((page (heks/openapi-html)))
    (heks-verify--check "the page is titled after the API"
                        (and (string-match-p "<h1>Widgets" page) t))
    (heks-verify--check "the method is shown" (and (string-match-p "GET" page) t))
    (heks-verify--check "the operations are grouped by tag"
                        (and (string-match-p "<h2>widgets</h2>" page) t))
    (heks-verify--check "the parameters are in a table"
                        (and (string-match-p "<th>In</th>" page) t))
    (heks-verify--check "the responses are in a table"
                        (and (string-match-p "<code>200</code>" page) t))
    (heks-verify--check "the schemas are listed"
                        (and (string-match-p "<h2>Schemas</h2>" page) t)))
  (heks-verify--check "and it makes a document of its own"
                      (and (string-match-p "<!DOCTYPE html>" (heks/render-document)) t))
  (heks-verify--check "the server to call comes from the specification"
                      (heks/openapi-server-url) "https://api.example.com/v1")
  (heks-verify--check "the menu lists the operation under its tag"
                      (and (assoc "widgets" (heks/openapi-imenu)) t)))

(heks-verify--section "and a specification written in YAML reads like one in JSON")

;; A YAML document is read by a package rather than by Emacs, and it hands
;; back what a scalar looks like instead of what a specification means: a
;; bare key arrives as a symbol, a response written `200' arrives as the
;; number 200, and `false' arrives as a symbol, which is a true value.
;; Every one of those used to be a way for a specification to render as an
;; empty page or to stop the rendering with an error, so they are checked
;; here on a real file -- the two spellings of one specification that the
;; golden renderings are also taken from.
(defconst heks-verify--test-dir
  (file-name-as-directory (file-name-directory (or load-file-name buffer-file-name)))
  "The directory this file lives in, where the fixtures and pages are.")

(defconst heks-verify--fixtures (expand-file-name "fixtures/" heks-verify--test-dir)
  "The documents the renderings are taken from.")

(defconst heks-verify--golden (expand-file-name "golden/" heks-verify--test-dir)
  "The renderings those documents are compared with.")

(defconst heks-verify--openapi-yaml
  "openapi: 3.0.3
info:
  title: Broken
  version: 1.0.0
paths:
  /things:
    get:
      operationId: getThing
      responses:
        999:
          description: not a code
")

(defmacro heks-verify--with-yaml-buffer (text name &rest body)
  "Run BODY in a temporary buffer holding TEXT, as the YAML file NAME."
  (declare (indent 2))
  `(let ((buffer (generate-new-buffer ,name)))
     (unwind-protect
         (with-current-buffer buffer
           (insert ,text)
           (setq-local buffer-file-name (expand-file-name ,name temporary-file-directory))
           (goto-char (point-min))
           ,@body)
       (kill-buffer buffer))))

(heks-verify--with-yaml-buffer heks-verify--openapi-yaml "openapi.yaml"
  (heks-verify--check "it is recognised as a specification" (heks/openapi-spec-p))
  (heks-verify--check "it reads" (let ((spec (heks/openapi-parse)))
                             (and (hash-table-p spec) t)))
  (heks-verify--check "a response code is read as the text it is written as"
                      (let* ((spec (heks/openapi-parse))
                             (operation (car (heks/openapi-operations spec))))
                        (and (heks/openapi-get
                              (heks/openapi-get (plist-get operation :operation)
                                                      "responses")
                              "999")
                             t)))
  (heks-verify--check "and the checker names it as a code"
                      (let (said)
                        (dolist (diagnostic (heks/openapi-diagnostics))
                          (when (string-match-p
                                 "is not a response code"
                                 (format "%s" (flymake-diagnostic-text diagnostic '(message))))
                            (setq said t)))
                        said)))

;; The two files are one specification, so they have to come out as one
;; page: that is the check that would have caught a document read with
;; symbol keys, where every lookup misses and the page comes out empty.
(let ((page (lambda (name)
              (with-temp-buffer
                (insert-file-contents (expand-file-name name heks-verify--fixtures))
                (setq-local buffer-file-name (expand-file-name name heks-verify--fixtures))
                (heks/openapi-html)))))
  (let ((json (funcall page "render-petstore.json"))
        (yaml (funcall page "render-petstore.yaml")))
    (heks-verify--check "a YAML fixture is a specification"
                        (with-temp-buffer
                          (insert-file-contents
                           (expand-file-name "render-petstore.yaml" heks-verify--fixtures))
                          (setq-local buffer-file-name
                                      (expand-file-name "render-petstore.yaml"
                                                        heks-verify--fixtures))
                          (heks/openapi-spec-p)))
    (heks-verify--check "the same specification in two languages is the same page"
                        (equal json yaml) t)
    (heks-verify--check "and the page is the one kept beside it"
                        (with-temp-buffer
                          (insert-file-contents
                           (expand-file-name "render-petstore.html"
                                             heks-verify--golden))
                          (equal yaml (buffer-string)))
                        t)))

(heks-verify--section "and what it says about a specification that is wrong")

;; One document, every rule at once: a path that is not a path, a key under a
;; path that is not an operation, the same identifier on two operations, a
;; path variable nobody declares, a response code that is not one, a body
;; with no shape, and a `$ref' that points at nothing.  The response `999'
;; is two problems rather than one -- the code is not a code, and the
;; response says nothing about itself -- which is why eight are expected.
(defconst heks-verify--openapi-bad
  (concat "{\n"
          "  \"openapi\": \"3.1.0\",\n"
          "  \"info\": {\"title\": \"Widgets\", \"version\": \"1.0.0\"},\n"
          "  \"paths\": {\n"
          "    \"widgets\": {\n"
          "      \"pust\": {\"responses\": {\"200\": {\"description\": \"typo\"}}},\n"
          "      \"post\": {\n"
          "        \"operationId\": \"getWidget\",\n"
          "        \"requestBody\": {\"content\": {\"application/json\":\n"
          "                         {\"schema\": {\"description\": \"no type\"}}}},\n"
          "        \"responses\": {\"999\": {}}\n"
          "      }\n"
          "    },\n"
          "    \"/widgets/{id}\": {\n"
          "      \"get\": {\"operationId\": \"getWidget\",\n"
          "                \"responses\": {\"200\": {\"description\": \"ok\"}},\n"
          "                \"parameters\": [{\"$ref\": \"#/components/parameters/Nope\"}]}\n"
          "    }\n"
          "  }\n"
          "}\n")
  "A specification that gets several things wrong.")

(heks-verify--with-spec-buffer heks-verify--openapi-bad "broken-openapi.json"
  (let* ((diagnostics (heks/openapi-diagnostics))
         (messages (mapcar (lambda (diagnostic)
                             (format "%s" (flymake-diagnostic-text
                                           diagnostic '(message))))
                           diagnostics)))
    (heks-verify--check "every problem is reported" (length messages) 8)
    (heks-verify--check
     "a path that is not a path"
     (and (seq-find (lambda (message)
                      (string-match-p "has to start with '/" message)) messages)
          t))
    (heks-verify--check
     "something under a path that is not an operation"
     (and (seq-find (lambda (message)
                      (string-match-p "is not an operation" message)) messages)
          t))
    (heks-verify--check
     "an identifier used twice"
     (and (seq-find (lambda (message)
                      (string-match-p "already the identifier" message)) messages)
          t))
    (heks-verify--check
     "a path variable nobody declares"
     (and (seq-find (lambda (message)
                      (string-match-p "never declared as a parameter" message)) messages)
          t))
    (heks-verify--check
     "a response code that is not one"
     (and (seq-find (lambda (message)
                      (string-match-p "is not a response code" message)) messages)
          t))
    (heks-verify--check
     "a body with no shape"
     (and (seq-find (lambda (message)
                      (string-match-p "untyped" message)) messages)
          t))
    (heks-verify--check "they are Flymake diagnostics"
                        (and (seq-every-p (lambda (diagnostic)
                                            (and (flymake-diagnostic-buffer diagnostic)
                                                 (flymake-diagnostic-beg diagnostic)))
                                          diagnostics)
                             t))))

;;;
;;; What which-key shows
;;;

(heks-verify--section "which-key shows a whole sentence, and how many keys")

(heks-verify--check "which-key is loaded" (and (featurep 'which-key) t))
(heks-verify--check "the menu is shown by this configuration, which chooses where"
                    which-key-popup-type 'custom)
(heks-verify--check "which is asked how much of the frame it may take"
                    which-key-custom-popup-max-dimensions-function
                    'heks/which-key-popup-dimensions)
(heks-verify--check "and shows it"
                    which-key-custom-show-popup-function
                    'heks/which-key-show-popup)
(heks-verify--check "and hides it"
                    which-key-custom-hide-popup-function
                    'heks/which-key-hide-popup)
(heks-verify--check "the window it asks for opens at the bottom"
                    which-key-side-window-location 'bottom)
(heks-verify--check "it may take two fifths of the frame"
                    which-key-side-window-max-height 0.4)
(heks-verify--check "the mode line counts the prefix's keys"
                    which-key-show-remaining-keys t)
(heks-verify--check "the windows that were there come back"
                    which-key-preserve-window-configuration t)
(heks-verify--check "and the length it may cut to is the longest sentence"
                    which-key-max-description-length
                    heks/which-key-description-length)

;; Cutting is which-key's own function, given the same length, and the `+'
;; which-key puts in front of a key that opens a keymap is part of what it
;; cuts -- which is why every description is tried with one.
(let ((cut '()))
  (dolist (text (heks/key-description-texts))
    (let ((cell (concat which-key-prefix-prefix text)))
      (unless (equal (which-key--truncate-description cell 80) cell)
        (push text cut))))
  (heks-verify--check "no description the scheme has arrives cut" cut nil))

;; And the real display, of the real `C-c': the idle timer's own function is
;; called with the prefix key the timer would have read.
(when (fboundp 'which-key--update)
  (let ((which-key-this-command-keys-function (lambda () (kbd "C-c")))
        (this-command nil)
        (echoed nil))
    (cl-letf (((symbol-function 'message)
               (lambda (format-string &rest arguments)
                 (setq echoed (apply #'format format-string arguments))
                 nil)))
      (which-key--update))
    (let ((window (and (buffer-live-p which-key--buffer)
                       (get-buffer-window which-key--buffer)))
          (shown (or (and (buffer-live-p which-key--buffer)
                          (with-current-buffer which-key--buffer
                            (buffer-string)))
                     echoed)))
      (heks-verify--check "the keys are shown in a window" (and window t))
      (heks-verify--check "on the bottom side of the frame"
                          (window-parameter window 'window-side) 'bottom)
      (heks-verify--check
       "the mode line says how many of the prefix's keys are in it"
       (and (string-match-p "[0-9]+/[0-9]+ keys"
                            (format "%s" (cdr (assq 'which-key-mode minor-mode-alist))))
            t))
      (heks-verify--check
       "and nothing it shows is a sentence with its end cut off"
       (seq-find (lambda (line)
                   (string-match-p (regexp-quote which-key-ellipsis) line))
                 (split-string (or shown "") "\n"))
       nil))
    (which-key--hide-popup)))

;;
;; Where the menu goes is decided from the window tree, so it is checked
;; against the tree: with room the height is the window which-key asks for,
;; and without it the menu is the echo area's (one line less, for the line
;; which-key says about it), asking for no window at all.
;;

(heks-verify--section "where the menu goes when the frame has no room for the window")

(let ((configuration (current-window-configuration))
      (min-height window-min-height))
  (unwind-protect
      (progn
        (delete-other-windows)
        (heks-verify--check "one window of a frame this size can be split in two"
                            (and (heks/which-key-side-window-p) t))
        (heks-verify--check "so the menu is the bottom window"
                            (car (heks/which-key-popup-dimensions (window-width)))
                            (car (which-key--side-window-max-dimensions)))
        (dotimes (_ 2) (ignore-errors (split-window-below)))
        (setq window-min-height 5)
        (heks-verify--check "windows too small to be split in two leave no room"
                            (heks/which-key-side-window-p) nil)
        (heks-verify--check "so the menu is the echo area's"
                            (car (heks/which-key-popup-dimensions (window-width)))
                            (1- (car (which-key--minibuffer-max-dimensions))))
        (heks-verify--check "one line less than the echo area has, for which-key's line"
                            heks/which-key-echoing t))
    (setq window-min-height min-height)
    (set-window-configuration configuration)))

;; And the display itself in that case: no window, the keys in the echo area,
;; and the line which-key says about them above the keys rather than after
;; them, because the echo area loses the end of a long message.
(when (fboundp 'which-key--update)
  (let ((configuration (current-window-configuration))
        (min-height window-min-height)
        (which-key-this-command-keys-function (lambda () (kbd "C-c")))
        (this-command nil)
        (echoed nil)
        (debug-on-error nil))
    (unwind-protect
        (progn
          (delete-other-windows)
          (dotimes (_ 2) (ignore-errors (split-window-below)))
          (setq window-min-height 5)
          ;; `which-key--echo' is the one door the menu has to the echo area
          ;; (it calls `message'), so the last text it is given is the menu.
          (cl-letf (((symbol-function 'which-key--echo)
                     (lambda (text) (setq echoed text))))
            (which-key--update))
          (heks-verify--check "the menu is in no window"
                              (and (buffer-live-p which-key--buffer)
                                   (get-buffer-window which-key--buffer))
                              nil)
          (heks-verify--check "it is in the echo area"
                              (and heks/which-key-echoing t))
          (heks-verify--check "with the line which-key says about it"
                              (and (string-match-p "(1 of [0-9]+)" (format "%s" echoed)) t))
          (heks-verify--check "and with keys of the scheme under it"
                              (and (string-match-p "diagnostics" (format "%s" echoed)) t))
          (heks-verify--check "and with nothing cut off"
                              (seq-find (lambda (line)
                                          (string-match-p (regexp-quote which-key-ellipsis)
                                                          line))
                                        (split-string (or echoed "") "\n"))
                              nil))
      (setq window-min-height min-height)
      (set-window-configuration configuration)
      (which-key--hide-popup))))

;;;
;;; Importing a Markdown document
;;;
;;; Making an Org note of a Markdown document is a string in and a string
;;; out, and `test/heks-emacs-ert.el' holds it to that.  What an installed
;;; configuration can be asked, and a string cannot, is whether what it
;;; writes is *Org*: the note is handed to Org's own parser, and what Org
;;; makes of it is what is checked.  A conversion that wrote a table Org
;;; reads as a paragraph, or a heading at a level that is not a level,
;;; would pass every check on the text and be a note nobody can use.

(heks-verify--section "a Markdown document becomes the Org note Org reads")

(let* ((fixture (expand-file-name "import-note.md" heks-verify--fixtures))
       (text (with-temp-buffer (insert-file-contents fixture) (buffer-string)))
       (org (heks/markdown-to-org text '(("ID" . "a-heks-verify-id")))))
  (with-temp-buffer
    (insert org)
    (org-mode)
    (let* ((tree (org-element-parse-buffer))
           (headlines (org-element-map tree 'headline
                        (lambda (h) (org-element-property :level h))))
           (keys (org-element-map tree 'keyword
                   (lambda (k) (cons (upcase (org-element-property :key k))
                                     (org-element-property :value k)))))
           (languages (org-element-map tree 'src-block
                        (lambda (b) (org-element-property :language b))))
           (checks (org-element-map tree 'item
                     (lambda (i) (org-element-property :checkbox i))))
           (labels (org-element-map tree 'footnote-definition
                     (lambda (f) (org-element-property :label f))))
           (rows (org-element-map tree 'table-row
                   (lambda (r) (org-element-property :type r))))
           (types (org-element-map tree 'export-block
                    (lambda (b) (downcase (or (org-element-property :type b) ""))))))
      (heks-verify--check "the title is a title, not a heading"
                          (cdr (assoc "TITLE" keys))
                          "A note about importing notes")
      (heks-verify--check "the tags become the file's tags"
                          (mapcar #'downcase org-file-tags)
                          '("emacs" "org_mode"))
      (heks-verify--check "a field of the front matter Org does not know is a keyword"
                          (cdr (assoc "PERMALINK" keys))
                          "/notes/importing")
      (heks-verify--check "the sections are first-level headlines"
                          headlines '(1))
      (heks-verify--check "the code fence is a source block of that language"
                          languages '("scheme"))
      (heks-verify--check "and a fence with no language is an example block"
                          (and (org-element-map tree 'example-block #'identity) t))
      (heks-verify--check "the task list items are the checkboxes Org knows"
                          (delq nil checks) '(off on))
      (heks-verify--check "the footnote reference found its definition"
                          labels '("why"))
      ;; A header row, the alignment row the delimiter row becomes (which
      ;; is a row Org keeps out of the export), the rule that closes the
      ;; header, and then the rows the document had.
      (heks-verify--check "the Markdown table is a header, an alignment row, a rule and two rows"
                          rows '(standard standard rule standard standard))
      (heks-verify--check "the quote block is a quote block"
                          (and (org-element-map tree 'quote-block #'identity) t))
      (heks-verify--check "the raw block is passed through as HTML"
                          types '("html"))
      (heks-verify--check "the two spaces at the end of a line are one line break"
                          (length (org-element-map tree 'line-break #'identity))
                          1)
      (heks-verify--check "the identifier is a property Org reads back"
                          (org-entry-get (point-min) "ID")
                          "a-heks-verify-id"))))

(heks-verify--section "an import writes the file it says it does")

(let ((root (make-temp-file "heks-verify-import-" t)))
  (unwind-protect
      (let ((source (expand-file-name "README.md" root))
            ;; Nothing here is a note of the reader's own: only a file of
            ;; the notes directory is registered, and there is none here.
            (heks/notes-dir nil))
        (write-region "# Heks\n\nA **project** with a `maak` task.\n" nil source nil 'silent)
        (heks-verify--check "the Org is written beside the Markdown"
                            (heks/import-markdown-file source)
                            (expand-file-name "README.org" root))
        (heks-verify--check "and the Markdown is left exactly as it was"
                            (with-temp-buffer (insert-file-contents source)
                                              (buffer-string))
                            "# Heks\n\nA **project** with a `maak` task.\n")
        (heks-verify--check "the note says what the document said"
                            (with-temp-buffer
                              (insert-file-contents (expand-file-name "README.org" root))
                              (buffer-string))
                            "#+title: Heks\n\nA *project* with a =maak= task.\n")
        (let ((notes (expand-file-name "notes/" root)))
          (make-directory notes t)
          (cl-letf (((symbol-function 'heks/notes-directory)
                     (lambda () notes)))
            (let* ((note (heks/import-markdown-file source t))
                   (text (with-temp-buffer (insert-file-contents note) (buffer-string))))
              (heks-verify--check "a note is written into the notes directory"
                                  note (expand-file-name "README.org" notes))
              (heks-verify--check "carries an identifier"
                                  (and (string-match-p "^ *:ID: *[^ \t\n]+$" text) t))))))
    (delete-directory root t)))

;;;
;;; The verdict
;;;

(message "\n== %d passed, %d failed ==" heks-verify--passed heks-verify--failed)
(when (> heks-verify--failed 0)
  (kill-emacs 1))

;;; heks-emacs-verify.el ends here
