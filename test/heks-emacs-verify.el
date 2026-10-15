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
(heks-verify--check "the bridge module is loaded" (featurep 'heks-emacs/heks-emacs))
(when (boundp 'heks-emacs-modules)
  (dolist (module heks-emacs-modules)
    (let ((file (expand-file-name (format "modules/%s.el" module) heks-verify--dir)))
      (heks-verify--check (format "modules/%s.el is installed" module)
                          (file-exists-p file))
      ;; The feature a module provides is read out of the module rather than
      ;; guessed from its name, so a rename cannot make this check pass by
      ;; accident: `emacs-core' provides `heks-emacs/emacs-self'.
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
;; configured wrongly whatever the setting says a moment later, and org-roam
;; -- whose notes directory is nobody's default -- is where that showed: it
;; was named after a nil, which stopped the configuration where it loaded.
(let ((notes (heks-emacs-notes-roam-directory)))
  (if notes
      (heks-verify--check
       "org-roam is pointed at the notes directory"
       (and (boundp 'org-roam-directory)
            (stringp org-roam-directory)
            (equal (file-name-as-directory (file-truename org-roam-directory))
                   (file-name-as-directory notes))))
    (heks-verify--check
     "org-roam is not pointed at a directory built out of nothing"
     (or (not (boundp 'org-roam-directory))
         (stringp org-roam-directory)))))

(heks-verify--section "reading what a tool says")
(heks-verify--check
 "a warning is parsed into its parts"
 (heks-emacs-parse-diagnostics "src/a.scm:12:3: warning: unused variable `y'\n")
 '(("src/a.scm" 12 3 :warning "unused variable `y'")))
(heks-verify--check
 "severities come from the message"
 (mapcar (lambda (line) (nth 3 (car (heks-emacs-parse-diagnostics line))))
         '("a.scm:1:1: error: no\n" "a.scm:1:1: note: hm\n" "a.scm:1:1: bare\n"))
 '(:error :note :warning))
(heks-verify--check
 "a hyperlinked, coloured diagnostic is still read"
 (heks-emacs-parse-diagnostics
  "\e]8;;file:///tmp/a.scm\a/tmp/a.scm\e]8;;\a:7:2: \e[31merror\e[0m: boom\n")
 '(("/tmp/a.scm" 7 2 :error "boom")))
(heks-verify--check
 "a backtrace is not mistaken for a diagnostic"
 (heks-emacs-parse-diagnostics
  "Backtrace:\nIn ice-9/boot-9.scm:\n  1705:22 0 (raise-exception _)\nno code for module\n")
 nil)
(heks-verify--check
 "the reason for a hard failure is found below the backtrace"
 (heks-emacs-tool-error-line
  "Backtrace:\nIn srfi/srfi-1.scm:\n  750:9 19 (for-each _)\nno code for module (nope)\n")
 "no code for module (nope)")
(heks-verify--check "changed lines are found"
                    (heks-emacs-tool-changed-lines "a\nb\nc\n" "a\nB\nc\n")
                    '(2))
(heks-verify--check "neighbouring lines become one range"
                    (heks-emacs-tool-number-ranges '(1 2 3 7))
                    '((1 . 3) (7 . 7)))

;; The shape of a diagnostic is the part of the Emacs API that changed under
;; this configuration's feet: Emacs builds the string the user reads out of
;; an origin, a code and a message, and a diagnostic whose message has been
;; put in the wrong slot reads with an empty headline in front of it.
(heks-verify--section "a diagnostic reads the way it should")
(with-temp-buffer
  (insert "(define one 1)\n(define two 2)\n")
  (let ((diags (heks-emacs-tool-diagnostic-list
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
;;; Guile
;;;

(heks-verify--section "the Guile module is wired up")
(dolist (name '(heks-emacs-scheme-repl
                heks-emacs-scheme-eval-definition
                heks-emacs-scheme-debugger
                heks-emacs-scheme-find-definition
                heks-emacs-scheme-callers
                heks-emacs-scheme-test
                heks-emacs-scheme-format-buffer
                heks-emacs-guix-style-apply-rule
                heks-emacs-guile-compile-backend
                heks-emacs-guix-lint-backend
                heks-emacs-guix-style-backend))
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
                        (commandp (lookup-key heks-emacs-scheme-mode-map (kbd key))))))

;; What the keys above are worth is that they are the ones that answer when
;; the key is pressed in a buffer, whichever mode the buffer is in.
(heks-verify--with-scheme-buffer "(define (f x)\n  x)\n"
  (heks-verify--check "the fold key is the global one in a Scheme buffer"
                      (key-binding (kbd "C-c v c")) 'heks-emacs-fold-close)
  (heks-verify--check "the format key is the global one in a Scheme buffer"
                      (key-binding (kbd "C-c i f")) 'heks-emacs-format-buffer))

(dolist (key '("C-c ! n" "C-c ! N" "C-c ! b" "C-c ! a" "C-c ! m"
               "C-c a v" "C-c a l" "C-c a r" "C-c a b"
               "C-c c d" "C-c d p" "C-c d m"
               "C-c e d" "C-c e a"
               "C-c h h" "C-c h f" "C-c h v" "C-c h k"
               "C-c i f" "C-c j m" "C-c j M" "C-c j g" "C-c j G"
               "C-c j s" "C-c j R" "C-c l d" "C-c l e" "C-c m r"
               "C-c n v" "C-c o m" "C-c o g"
               "C-c r p" "C-c r b" "C-c r e" "C-c r m" "C-c r r"
               "C-c t a" "C-c t w" "C-c t c" "C-c u u"
               "C-c v o" "C-c v O" "C-c v c" "C-c v C" "C-c v r" "C-c v t" "C-c v d"
               "C-c w r" "C-c w f" "C-c w t" "C-c w d" "C-c w g"
               "C-c # s" "C-c # u" "C-c # f" "C-c # j"
               "C-c f n" "C-c f t" "C-c f s" "C-c f r" "C-c f l" "C-c f L"
               "C-c f j" "C-c f c"))
  (heks-verify--check (format "%s is bound" key)
                      (commandp (key-binding (kbd key)))))
(heks-verify--check "C-c p is the completion prefix"
                    (keymapp (key-binding (kbd "C-c p"))))


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
                      (and (memq 'heks-emacs-guile-compile-backend
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
(cl-letf (((symbol-function 'heks-emacs-tool-available-p)
           (lambda (program) (not (equal program heks-emacs-guix-program)))))
  (heks-verify--check "Guix is seen as missing" (heks-emacs-guix-available-p) nil)
  (heks-verify--check "Guile is still there" (heks-emacs-guile-available-p))
  (heks-verify--with-scheme-buffer
      "(define-module (verify package))\n(define-public hello (package))\n"
    ;; The file *looks* like a Guix package, but nothing here can lint one,
    ;; so the compiler has to be the checker instead of nothing at all.
    (heks-verify--check "a Guix-looking file is checked by the Guile compiler"
                        (heks-emacs-guile-compile-applies-p))
    (heks-verify--check "the Guix checkers bow out"
                        (and (not (memq 'heks-emacs-guix-lint-backend
                                        flymake-diagnostic-functions))
                             (not (memq 'heks-emacs-guix-style-backend
                                        flymake-diagnostic-functions))
                             t))
    (heks-verify--check "a Guix REPL is not offered" (heks-emacs-scheme-guile-binary) nil)))

;;;
;;; The interface
;;;

(heks-verify--section "the type scale and the separators")
(heks-verify--check "the base type size is a size" (numberp heks-emacs-base-font-size))
(heks-verify--check "a face height is an absolute number"
                    (integerp (heks-emacs-font-height 1.0)))
(heks-verify--check "face sizes hold their ratio to the base size"
                    (<= (abs (- (heks-emacs-font-height 2.0)
                                (* 2 (heks-emacs-font-height 1.0))))
                        1))
(heks-verify--check "a larger multiple is a larger size"
                    (> (heks-emacs-font-height 1.5) (heks-emacs-font-height 1.0)))
(let ((color (heks-emacs-window-divider-color)))
  (heks-verify--check "the separators between windows have a color"
                      (and (stringp color) (string-prefix-p "#" color)))
  (heks-emacs-set-window-divider-faces)
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
                                          (eq (cdr entry) 'heks-emacs-scheme-format-buffer)))
                                   (bound-and-true-p heks-emacs-format-dispatch))
                         t))
(heks-verify--with-scheme-buffer "(define-module (verify one))\n"
  (heks-verify--check "a Scheme buffer is claimed by the Scheme formatter"
                      (and (seq-find (lambda (entry) (funcall (car entry)))
                                     heks-emacs-format-dispatch)
                           t))
(heks-verify--check "the format command exists" (commandp 'heks-emacs-format-buffer)))

(heks-verify--section "one fold key, whichever the mode")
(heks-verify--with-scheme-buffer heks-verify--scheme-source
  ;; Hideshow is what folds these buffers, and kirigami is the interface
  ;; that knows it: the keys the user has do not mention either.
  (goto-char (point-min))
  (search-forward "(two x)")
  (heks-emacs-fold-toggle)
  (heks-verify--check "the fold key folds the definition at point"
                      (length (heks-verify--hs-overlays)) 1)
  (heks-emacs-fold-open-all)
  (heks-verify--check "the reveal key brings everything back"
                      (heks-verify--hs-overlays) nil)
  (heks-emacs-fold-close-all)
  ;; The source has three top-level forms: the `define-module' and the two
  ;; definitions, which is what hiding every block has to cover.
  (heks-verify--check "folding everything hides every form"
                      (length (heks-verify--hs-overlays)) 3)
  (heks-emacs-fold-toggle)
  (heks-verify--check "and toggling still works with folds closed"
                      (>= (length (heks-verify--hs-overlays)) 1) t)
  (heks-emacs-fold-open-all))

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
  (heks-verify--check "it is recognised as Markdown" (heks-emacs-render-markdown-p))
  (let ((body (heks-emacs-render-body)))
    (heks-verify--check "the heading becomes a heading"
                        (and (string-match-p "<h1>Title</h1>" body) t))
    (heks-verify--check "the emphasis is rendered"
                        (and (string-match-p "<em>emphasis</em>" body) t))
    (heks-verify--check "the code block is kept"
                        (and (string-match-p "language-elisp" body) t)))
  (let ((document (heks-emacs-render-document)))
    (heks-verify--check "it is wrapped in a document"
                        (and (string-prefix-p "<!DOCTYPE html>" document) t))
    (heks-verify--check "the document names its renderer"
                        (and (string-match-p "class=\"headline\">Markdown" document) t))
    (heks-verify--check "the stylesheet is themed, not linked"
                        (and (string-match-p "<style>" document) t)))
  ;; The preview writes a document and shows it, which is the part a user
  ;; actually presses a key for.  It is run for real here: EWW renders
  ;; in batch as well as it does in a frame.
  (let ((file (heks-emacs-render-file)))
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
  (let ((preview (get-buffer heks-emacs-preview-buffer-name)))
    (when preview (kill-buffer preview)))
  (heks-emacs-preview)
  (let ((shown (get-buffer heks-emacs-preview-buffer-name)))
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
  (heks-verify--check "it is recognised as a specification" (heks-emacs-openapi-spec-p))
  (heks-verify--check "it reads" (and (hash-table-p (heks-emacs-openapi-parse)) t))
  (heks-verify--check "it has one operation"
                      (length (heks-emacs-openapi-operations (heks-emacs-openapi-parse))) 1)
  (heks-verify--check "and no problems" (heks-emacs-openapi-diagnostics) nil)
  (let ((page (heks-emacs-openapi-html)))
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
                      (and (string-match-p "<!DOCTYPE html>" (heks-emacs-render-document)) t))
  (heks-verify--check "the server to call comes from the specification"
                      (heks-emacs-openapi-server-url) "https://api.example.com/v1")
  (heks-verify--check "the menu lists the operation under its tag"
                      (and (assoc "widgets" (heks-emacs-openapi-imenu)) t)))

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
  (heks-verify--check "it is recognised as a specification" (heks-emacs-openapi-spec-p))
  (heks-verify--check "it reads" (let ((spec (heks-emacs-openapi-parse)))
                             (and (hash-table-p spec) t)))
  (heks-verify--check "a response code is read as the text it is written as"
                      (let* ((spec (heks-emacs-openapi-parse))
                             (operation (car (heks-emacs-openapi-operations spec))))
                        (and (heks-emacs-openapi-get
                              (heks-emacs-openapi-get (plist-get operation :operation)
                                                      "responses")
                              "999")
                             t)))
  (heks-verify--check "and the checker names it as a code"
                      (let (said)
                        (dolist (diagnostic (heks-emacs-openapi-diagnostics))
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
                (heks-emacs-openapi-html)))))
  (let ((json (funcall page "render-petstore.json"))
        (yaml (funcall page "render-petstore.yaml")))
    (heks-verify--check "a YAML fixture is a specification"
                        (with-temp-buffer
                          (insert-file-contents
                           (expand-file-name "render-petstore.yaml" heks-verify--fixtures))
                          (setq-local buffer-file-name
                                      (expand-file-name "render-petstore.yaml"
                                                        heks-verify--fixtures))
                          (heks-emacs-openapi-spec-p)))
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
  (let* ((diagnostics (heks-emacs-openapi-diagnostics))
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
;;; The verdict
;;;

(message "\n== %d passed, %d failed ==" heks-verify--passed heks-verify--failed)
(when (> heks-verify--failed 0)
  (kill-emacs 1))

;;; heks-emacs-verify.el ends here
