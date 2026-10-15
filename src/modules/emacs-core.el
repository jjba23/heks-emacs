;;; emacs-core.el --- Configuring Emacs core -*- lexical-binding: t -*-

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

;; Configuring Emacs core
;; This file establishes the baseline behavior for Emacs

;;; Code:

;;
;; ====== The key scheme ======
;;
;; Everything this configuration adds lives under `C-c': one letter for
;; the topic, then a letter for the action.  Two rules keep a map of a
;; few hundred keys learnable, and they are written down here because a
;; binding nobody can describe is a binding nobody uses:
;;
;;   * a topic letter means one thing, everywhere (`d' is databases and
;;     only databases; direnv and Docker used to live there too) -- and a
;;     topic may be a modified stroke, such as `C-#', when a mode's own
;;     key would otherwise sit in the topic's way;
;;   * an action letter means the same thing under every topic: `f'
;;     formats, `t' tests, `d' debugs, `b' builds, `r' runs or opens a
;;     REPL, `e' evaluates, `g' goes to a definition, `h' explains, `c'
;;     lists callers, `i' inserts, `k' kills, `l' lints, `n' creates,
;;     `v' views, `a' applies.
;;
;; So `C-c g f' formats a Scheme file with Guix, `C-c i f' formats
;; whatever buffer is current, and `C-c j t' runs the tests of a JVM
;; project.
;;
;; Some topics key something that is not one of those verbs at all, and
;; the letter is then the first letter of what it names: the font sizes
;; (`C-c f t' is tiny, `C-c f c' colossal), what the system topic
;; reconfigures (`C-c # j' is his own configuration, `C-c # s' the
;; system), what the notes topic opens (`C-c n f' finds a node, `C-c n j'
;; the journal entry for today).  Those letters are written down per
;; topic in `heks-emacs-key-letters' rather than being pushed into the
;; action alphabet until it means everything and nothing -- which is what
;; `i' had come to mean, with a key for the implementation and a key for
;; an interrupt under it.
;;
;; `test/heks-emacs-keys.el' reads these three tables, prints the whole
;; key tree with the meaning of every key, writes `docs/keybindings.org'
;; -- the reference to read -- and refuses a binding whose topic is not
;; described here, that disagrees with another binding of the same key,
;; whose command does not exist, or whose letters are in no table.

(defconst heks-emacs-key-topics
  '(("!"     . "diagnostics: Flymake")
    ("#"     . "system: this machine and the Guix system")
    ("C-#"   . "Org statistics cookies, kept off `C-c #'")
    (";"     . "diary")
    ("SPC"   . "dashboard")
    ("C-d"   . "diagrams: Mermaid")
    ("a"     . "API and HTTP: OpenAPI specs and requests")
    ("c"     . "containers: Docker")
    ("d"     . "databases: PostgreSQL and MongoDB")
    ("e"     . "environment: direnv")
    ("f"     . "fonts and text size")
    ("g"     . "Guile and Guix")
    ("h"     . "help and documentation")
    ("i"     . "IDE: language server, formatting, diagnostics")
    ("j"     . "JVM: Maven, Gradle, Spring, Java and Kotlin")
    ("l"     . "Emacs itself: evaluating and debugging Elisp")
    ("m"     . "make-style tasks: maak")
    ("n"     . "notes: Org and roam")
    ("o"     . "mail: Gnus")
    ("p"     . "completion at point: cape")
    ("r"     . "render and preview")
    ("s"     . "snippets and recorded macros")
    ("t"     . "text tools")
    ("u"     . "utilities")
    ("v"     . "view: folding and comparisons")
    ("w"     . "workspace and project"))
  "What each `C-c' topic letter is for.

Read by `test/heks-emacs-keys.el', which fails when a key uses a topic
that is not described here.")

(defconst heks-emacs-key-actions
  '(("a" . "apply an action, or add something")
    ("b" . "build")
    ("c" . "show the callers of this definition")
    ("d" . "debug, or the difference between two things")
    ("e" . "evaluate")
    ("f" . "format")
    ("g" . "go to: a definition, an implementation, a location")
    ("h" . "explain: the documentation of what is at point")
    ("i" . "insert")
    ("k" . "kill: stop a process or a server")
    ("l" . "lint, or list the problems")
    ("m" . "a menu, or turn the mode on and off")
    ("n" . "new, or next")
    ("o" . "open")
    ("p" . "preview, or previous")
    ("r" . "run, or open a REPL")
    ("s" . "send to a REPL, or switch")
    ("t" . "test")
    ("u" . "update")
    ("v" . "view, or validate")
    ("w" . "write, or work on")
    ("x" . "execute a script"))
  "What each action letter means under every topic.

An action letter is one meaning in every topic that uses it.  A topic
that keys something other than an action says so in
`heks-emacs-key-letters', and the two together are what every key under
`C-c' is held to; an uppercase letter is the further one of a pair (`C-c
g E' evaluates more than `C-c g e', `C-c v C' closes everything where
`C-c v c' closes one fold).")

(defconst heks-emacs-key-letters
  '(("!" ("n" . "the next diagnostic")
         ("N" . "the previous diagnostic")
         ("b" . "the diagnostics of this buffer")
         ("a" . "all the diagnostics of the project"))
    ("#" ("j" . "his own configuration")
         ("s" . "the system")
         ("f" . "everything: his configuration and the system"))
    (";" ("v" . "the entry for today")
         ("g" . "the entry for yesterday"))
    ("C-d" ("c" . "the diagram at point")
           ("r" . "the diagram in the region")
           ("b" . "the diagrams in this buffer")
           ("f" . "the diagrams in this file"))
    ("a" ("b" . "the request written as a block to paste"))
    ("c" ("d" . "Docker"))
    ("d" ("p" . "PostgreSQL")
         ("m" . "the MongoDB shell"))
    ("e" ("a" . "allow this `.envrc'")
         ("d" . "direnv, in every buffer"))
    ("f" ("c" . "colossal")
         ("j" . "jumbo")
         ("l" . "large")
         ("L" . "larger")
         ("n" . "nano")
         ("r" . "regular")
         ("s" . "small")
         ("t" . "tiny"))
    ("g" ("b" . "the whole buffer, sent to the REPL")
         ("L" . "lint it with `guix lint'")
         ("S" . "apply one of `guix style''s rules")
         ("p" . "the package at the mark")
         ("R" . "restart it")
         ("E" . "the region, or the whole buffer")
         ("C" . "the callees of this definition"))
    ("h" ("f" . "the function at point, as `C-h f'")
         ("v" . "the variable at point, as `C-h v'")
         ("k" . "the key at point, as `C-h k'"))
    ("i" ("e" . "Eglot itself, and what it is doing")
         ("r" . "rename the symbol at point")
         ("R" . "restart the language server")
         ("h" . "the server's inlay hints, on and off"))
    ("j" ("m" . "Maven")
         ("M" . "the Maven menu")
         ("g" . "Gradle")
         ("G" . "the Gradle menu")
         ("s" . "Spring Boot")
         ("N" . "a new project")
         ("B" . "the project, built again")
         ("R" . "the project's classpath, reloaded"))
    ("n" ("c" . "capture a note")
         ("f" . "find a node")
         ("g" . "the graph of the notes")
         ("j" . "the journal entry for today")
         ("l" . "the buffer that lists the links"))
    ("o" ("m" . "Gnus itself")
         ("g" . "a group, read once"))
    ("r" ("b" . "the browser")
         ("e" . "keep it as a file")
         ("m" . "follow the buffer, re-rendering on save")
         ("r" . "render it again"))
    ("s" ("a" . "an alist accessor out of a string one")
         ("c" . "the snippet at point, completed")
         ("h" . "a hygguile class set out of a list of classes")
         ("p" . "a parameter out of a value")
         ("x" . "the named snippet, expanded"))
    ("t" ("a" . "the lines, sorted")
         ("c" . "the fill column indicator")
         ("o" . "Olivetti, writing in the middle of the window")
         ("w" . "the whitespace at the end of the lines"))
    ("u" ("u" . "a UUID"))
    ("v" ("c" . "this fold")
         ("C" . "every fold")
         ("o" . "this fold, opened")
         ("O" . "this fold and everything under it")
         ("r" . "every fold, revealed")
         ("t" . "the fold at point, toggled"))
    ("w" ("d" . "the development server")
         ("g" . "a search of the project")
         ("s" . "a random order for the standup")))
  "What the letters of a topic that names things mean, topic by topic.

These are the topics whose keys do not perform one of the actions in
`heks-emacs-key-actions': the letter is the first letter of what the key
names.  Both tables are read by `test/heks-emacs-keys.el', which fails on
a letter that is in neither of them, so a key always has a description
to show in `docs/keybindings.org'.")

;; Configure Flymake (built-in linter).
;;
;; All of diagnostics is one topic: `n' and `N' walk them, `b' and `a'
;; list them for this buffer and for the whole project, and `m' turns the
;; background checking on and off.  (`p' used to list the project's
;; diagnostics, one letter away from a "previous error" key that did not
;; exist, while `C-c i p' formatted the buffer -- three letters that had
;; nothing to do with each other.)
(use-package flymake
  :ensure nil
  :bind (("C-c ! n" . flymake-goto-next-error)
         ("C-c ! N" . flymake-goto-prev-error)
         ("C-c ! b" . flymake-show-buffer-diagnostics)
         ("C-c ! a" . flymake-show-project-diagnostics)
         ("C-c ! m" . flymake-mode)))

;; Discoverability: Show available keybindings after a short delay
(use-package which-key
  :ensure nil
  :config
  (setq which-key-sort-order 'which-key-key-order-alpha
        which-key-max-description-length 35)
  ;; Fast enough to be useful, slow enough not to flash
  (setq-default which-key-idle-delay 0.4)
  (which-key-setup-minibuffer)
  (which-key-mode))

;; (use-package nyan-mode
;;   :ensure t
;;   :demand t
;;   :config
;;   (setq nyan-bar-length 12))

;; Custom modeline package
(use-package modusregel
  :ensure (:host codeberg :repo "jjba23/modusregel" :branch "trunk")
  :demand t)

(defun add-prettify-mappings ()
  "Append custom symbols to the buffer-local prettify-symbols-alist."
  (setq prettify-symbols-alist
        (append '(
                  ;; --- Functional Programming & Lambdas ---
                  ("lambda" . ?λ)
                  ("fn"    . ?Λ)
                  ("fun"   . ?Λ)
                  ("defun"    . ?Λ)
                  ("define*"    . ?Λ)
                  ("func"    . ?Λ)
                  ("function" . ?Λ)
                  ("compose" . ?∘)
                  ("define-syntax" . ?μ)
                  ("define-syntax-rule" . ?μ)
                  ("define-macro" . ?μ)
                  ("define-module" . ?⬡)
                  ("define-record-type" . ?✦)
                  ("define-record-with-kw" . ?✦)
                  ("use-package" . ?ρ)
                  ("defmacro" . ?μ)

                  ;; --- Types & Optionals ---
                  ;; ("None"    . ?Ø)
                  ;; ("Nil"     . ?Ø)
                  ;; ("nil"     . ?Ø)
                  ;; ("null"    . ?Ø)

                  ;; --- Logic & Boolean ---
                  ;; ("true"   . ?✓)
                  ;; ("#t"     . ?✓)
                  ;; ("True"   . ?✓)
                  ;; ("false"  . ?✗)
                  ;; ("#f"     . ?✗)
                  ;; ("False"  . ?✗)

                  ;; --- Mathematical & Set Theory ---
                  ;; ("in"     . ?∈)
                  ;; ("not in" . ?∉)
                  ("sum"    . ?∑)
                  ("product" . ?∏)
                  ("sqrt"   . ?√)
                  ("pi"     . ?π)
                  ("Infinity" . ?∞)
                  ("infinity" . ?∞)
                  ("inf" . ?∞)
                  ("Omega"   . ?Ω)
                  ("omega"   . ?Ω)
                  ("Theta"   . ?Θ)
                  ("theta"   . ?Θ)
                  ("phi"     . ?φ)
                  ("Phi"     . ?φ)
                  ("forall"  . ?∀)
                  ("mu"      . ?μ)
                  ("sigma"   . ?σ)
                  ("Sigma"   . ?Σ)
                  ("alpha"   . ?α)
                  ("Alpha"   . ?α)
                  ("beta"    . ?β)
                  ("Beta"    . ?β)
                  ("gamma"   . ?γ)
                  ("Gamma"   . ?γ)
                  ("pi"      . ?π)
                  ("Pi"      . ?π)
                  ("tau"     . ?τ)
                  ("Tau"     . ?τ)

                  ;; --- Comparison Operators ---
                  ("<="     . ?≤)
                  (">="     . ?≥)

                  ;; --- Control Flow & Arrows ---
                  ("->"     . ?→)
                  ("-->"    . ?⟶)
                  ("<-"     . ?←)
                  ("<--"    . ?⟵)

                  ;; ---- Org
                  ("#+begin_src"       . ?≫)
                  ("#+BEGIN_SRC"       . ?≫)
                  ("#+end_src"         . ?≪)
                  ("#+END_SRC"         . ?≪)
                  ("#+results:"        . ?▷)
                  ("#+RESULTS:"        . ?▷)
                  ("#+begin_quote"     . ?“)
                  ("#+BEGIN_QUOTE"     . ?“)
                  ("#+end_quote"       . ?”)
                  ("#+END_QUOTE"       . ?”)
                  ("#+begin_example" . ?¶)
                  ("#+BEGIN_EXAMPLE" . ?¶)
                  ("#+end_example" . ?¶)
                  ("#+END_EXAMPLE" . ?¶)
                  ("#+title:"   . ?§)
                  ("#+TITLE:"   . ?§)
                  ("#+author:"  . ?᚛)
                  ("#+AUTHOR:"  . ?᚛)
                  ("#+email:"  . ?✉)
                  ("#+EMAIL:"  . ?✉)
                  ("#+date:"    . ?⧖)
                  ("#+DATE:"    . ?⧖)
                  ("#+options:" . ?⌘)
                  ("#+OPTIONS:" . ?⌘)
                  ("#+name:"       . ?⛦)
                  ("#+NAME:"       . ?⛦)

                  ;; --- Lisp ---
                  ("unquote" . ?↴)
                  ("cons"      . ?∷)

                  ;; --- Miscellaneous / Clean Syntax ---
                  ;; ("import" . ?📥)
                  ;; ("export" . ?📤)
                  )
                prettify-symbols-alist)))

(defun heks-activate-prettify ()
  "Populate mappings and safely initialize prettify-symbols-mode."
  (add-prettify-mappings)
  (prettify-symbols-mode +1))

;; Core Emacs Configuration
;; This block is grouped by logical domains for easier reading.
(use-package emacs
  :ensure nil
  :after (modusregel)

  ;; --- Global Keybindings ---
  ;; Note: Custom heks-emacs-* functions must be defined elsewhere.
  ;; The topic table above says what each group is for; these are the
  ;; global keys, and the language modules add theirs under the same
  ;; topics (`C-c g' for Guile, `C-c r' for previewing a Markdown file,
  ;; `C-c a' for an OpenAPI spec) so that one letter keeps one meaning.
  :bind (("C-x C-b" . ibuffer) ; Use the superior interactive buffer menu
         ;; View: folding and comparisons.  The fold keys dispatch, so they
         ;; work in every buffer whichever folding engine it uses.
         ("C-c v o" . heks-emacs-fold-open)
         ("C-c v O" . heks-emacs-fold-open-recursive)
         ("C-c v c" . heks-emacs-fold-close)
         ("C-c v C" . heks-emacs-fold-close-all)
         ("C-c v r" . heks-emacs-fold-open-all)
         ("C-c v t" . heks-emacs-fold-toggle)
         ("C-c v d" . highlight-compare-buffers)
         ("C-c l d" . toggle-debug-on-error)
         ("C-c l e" . eval-buffer)
         ("C-c u u" . heks-emacs-uuidgen)
         ("C-c # j" . heks-emacs-joe-reconfigure)
         ("C-c # s" . heks-emacs-sys-reconfigure)
         ("C-c # u" . heks-emacs-sys-update)
         ("C-c # f" . heks-emacs-full-reconfigure)
         ("C-c w r" . heks-emacs-project-start-repl-process)
         ("C-c w f" . heks-emacs-project-fmt)
         ("C-=" . text-scale-increase)
         ("C--" . text-scale-decrease)
         ("C-c w t" . heks-emacs-project-start-test)
         ("C-c w d" . heks-emacs-project-start-dev)
         ("C-c w s" . heks-emacs-print-random-standup-order)
         ;; Text tools, in every buffer.
         ("C-c t a" . sort-lines)
         ("C-c t w" . delete-trailing-whitespace)
         ("C-c t c" . display-fill-column-indicator-mode)
         ;; Formatting: one key, and the language decides who formats.
         ("C-c i f" . heks-emacs-format-buffer)
         ;; JVM build tooling (Maven, Gradle, Spring Boot).  The capital
         ;; letters open the menus, which name the goals by what they do.
         ("C-c j m" . heks-emacs-maven-run)
         ("C-c j M" . heks-emacs-maven-menu)
         ("C-c j g" . heks-emacs-gradle-run)
         ("C-c j G" . heks-emacs-gradle-menu)
         ("C-c j s" . heks-emacs-spring-boot-run)
         ("C-c j R" . heks-emacs-jvm-refresh-project)
         ;; Databases (PostgreSQL, MongoDB)
         ("C-c d p" . heks-emacs-sql-postgres)
         ("C-c d m" . heks-emacs-mongosh))

  :hook ((text-mode . visual-line-mode)
         (prog-mode . heks-activate-prettify)
         (org-mode . heks-activate-prettify)
         (markdown-ts-mode . heks-activate-prettify)
         ((emacs-lisp-mode
           conf-mode
           markdown-ts-mode
           org-mode
           scheme-mode
           diff-mode) . outline-minor-mode))
  :custom
  ;; Support opening new minibuffers from inside existing minibuffers.
  (enable-recursive-minibuffers t)
  (minibuffer-prompt-properties
   '(read-only t cursor-intangible t face minibuffer-prompt))
  :config
  ;; --- UI & Visual Tweaks ---
  (setq-default line-spacing 6
                pgtk-wait-for-event-timeout 0 ; Fixes input lag on Wayland/PGTK builds
                electric-indent-inhibit t)

  (setopt treesit-font-lock-level 4           ; Maximum syntax highlighting for tree-sitter
          ring-bell-function #'ignore         ; Disable the annoying visual/audio bell
          frame-resize-pixelwise t            ; Allow smooth, gapless window tiling
          use-dialog-box nil                  ; Force prompts to stay in the minibuffer
          fill-column 78)                     ; Standard column width for indicators/wrapping

  (setopt treesit-auto-install-grammar 'always) ; EMACS-31
  (setopt treesit-enabled-modes t)              ; EMACS-31

  ;; default to utf-8 for all the things
  (set-charset-priority 'unicode)
  (setq locale-coding-system 'utf-8
        coding-system-for-read 'utf-8
        coding-system-for-write 'utf-8)
  (set-terminal-coding-system 'utf-8)
  (set-keyboard-coding-system 'utf-8)
  (set-selection-coding-system 'utf-8)
  (prefer-coding-system 'utf-8)
  (setq default-process-coding-system '(utf-8-unix . utf-8-unix))

  ;; these might require a manual `M-x treesit-install-language-grammar'
  (add-to-list 'treesit-language-source-alist
               '(kotlin . ("https://github.com/fwcd/tree-sitter-kotlin")))
  (add-to-list 'treesit-language-source-alist
               '(scala . ("https://github.com/tree-sitter/tree-sitter-scala")))
  (add-to-list 'treesit-language-source-alist
               '(nix . ("https://github.com/nix-community/tree-sitter-nix")))

  (setq-default cursor-type 'bar)             ; Modern pipe cursor instead of standard block
  (global-hl-line-mode +1)                    ; Highlight current line

  ;; --- Editing & Behavior ---
  (setopt backward-delete-char-untabify-method 'hungry ; Deleting whitespace eats all of it at once
          compilation-always-kill t           ; Auto-kill old compilation processes without prompting
          tab-always-indent 'complete         ; Make TAB fallback to completion if already indented
          text-mode-ispell-word-completion nil
          vc-follow-symlinks t                ; Don't ask to follow symlinks to version-controlled files
          delete-by-moving-to-trash t         ; Use system trash instead of permanent deletion
          tab-width 2
          sentence-end-double-space t
          compile-command "maak --list")

  (defun heks-emacs/project-compilation-buffer-name (mode)
    "Create a compilation buffer name based on the current project."
    (let* ((project (project-current))
           ;; Extract the folder name if in a project, otherwise use "global"
           (project-name (if project
                             (file-name-nondirectory (directory-file-name (project-root project)))
                           "global")))
      ;; Returns e.g., "*compilation-my-project*"
      (format "*%s-%s*" (downcase mode) project-name)))

  ;; Tell Emacs to use your custom function
  (setq compilation-buffer-name-function #'heks-emacs/project-compilation-buffer-name)

  (setq-default indent-tabs-mode nil)         ; Always use spaces instead of tabs


  (defalias 'yes-or-no-p 'y-or-n-p)           ; Type 'y' instead of 'yes' for prompts

  ;; --- Minibuffer & Completion ---
  (setopt read-extended-command-predicate #'command-completion-default-include-p ; Hide irrelevant commands
          completion-cycle-threshold 3        ; Cycle through options if there are 3 or fewer
          completion-eager-update t               ;; EMACS-31
          completion-eager-display 'auto          ;; EMACS-31
          minibuffer-visible-completions 'up-down ;; EMACS-31
          read-file-name-completion-ignore-case t
          read-buffer-completion-ignore-case t
          completion-ignore-case t
          eldoc-help-at-pt t)

  ;; --- State Preservation ---
  (savehist-mode 1)                           ; Remember minibuffer history across sessions
  (save-place-mode 1)                         ; Remember cursor position in previously opened files
  (global-auto-revert-mode 1)                 ; Auto-update buffers if the file changes on disk
  (delete-selection-mode +1)                  ; Typing replaces highlighted text (modern behavior)

  ;; Remember recently opened files
  (recentf-mode 1)
  (setopt recentf-max-menu-items 100
          recentf-max-saved-items 100)

  ;; startup
  (setopt inhibit-startup-screen t
          initial-scratch-message nil)

  (winner-mode t)

  (show-paren-mode t)

  (column-number-mode 1)

  ;; less noise when compiling elisp
  (setq byte-compile-warnings '(not free-vars unresolved noruntime lexical make-local))
  (setq native-comp-async-report-warnings-errors nil)
  (setq load-prefer-newer t)

  ;; --- Integrations & Paths ---

  (setopt safe-local-variable-directories
          ;; Whitelist specific Guix directory to prevent constant local-variable security
          (list (string-replace "$HOME" (getenv "HOME") "$HOME/fork/guix/")))

  ;; Load TreeSitter AST syntax lexer and highlighting
  ;; used to be needed pre-Emacs 31
  ;; (setopt treesit-extra-load-path (list "~/.emacs.d/tree-sitter-grammars"))

  ;; --- Window Management ---
  ;; Enable Shift+Arrow keys for easy directional window switching
  (when (fboundp 'windmove-default-keybindings)
    (windmove-default-keybindings))

  ;; Frame transparency (requires a compositor like Wayland or Picom)
  (ignore-errors
    (set-frame-parameter nil 'alpha-background 86)
    (add-to-list 'default-frame-alist '(alpha-background . 86)))

  ;; --- File Management (Dired) ---
  (when heks/is-darwin-p
    (setopt insert-directory-program (executable-find "gls")))

  (setopt dired-listing-switches "-lAh --group-directories-first" ; Human readable, dirs at the top
          dired-kill-when-opening-new-dired-buffer t)             ; Keep buffer list clean

  (add-to-list 'set-message-functions 'inhibit-message)
  (add-to-list 'inhibit-message-regexps "replicasets\\.apps is forbidden")

  (add-hook 'dired-mode-hook
            (lambda ()
              (dired-hide-details-mode 1)     ; Hide ownership/permissions by default for cleaner look
              (auto-revert-mode)))            ; Auto-refresh dired when files change

  (add-to-list 'auto-mode-alist '("\\.hbs\\'" . html-mode))

  ;; --- Buffer Placement Rules ---
  ;; Tame window popups. Anatomy of a display-buffer-alist entry:
  ;; (BUFFER-MATCHER LIST-OF-DISPLAY-FUNCTIONS &optional PARAMETERS)
  ;; matchers can be an Emacs buffer name regex string or a mode matcher: (derived-mode . typescript-mode)
  (setq display-buffer-alist '(("\\*Occur\\*"
                                (display-buffer-reuse-mode-window
                                 display-buffer-below-selected)
                                (window-height . fit-window-to-buffer)
                                (dedicated . t))
                               ((derived-mode . completion-list-mode)
                                (display-buffer-use-some-window))))

  ;; --- Disable Bidirectional Text Scanning  ---
  ;; If you don’t edit right-to-left languages (like me), Emacs is doing a bunch of work on every redisplay cycle for nothing.
  ;; These settings tell Emacs to assume left-to-right text everywhere and skip the bidirectional parenthesis algorithm:

  (setq-default bidi-display-reordering 'left-to-right
                bidi-paragraph-direction 'left-to-right)

  (setq bidi-inhibit-bpa t)

  ;; --- Skip Fontification During Input ---
  ;; Emacs normally fontifies (syntax-highlights) text even while you’re actively typing.
  ;; This can cause micro-stutters, especially in tree-sitter modes or large buffers.
  ;; One setting fixes it:

  (setq redisplay-skip-fontification-on-input t)

  ;; --- Increase Process Output Buffer for LSP ---
  ;; The default read-process-output-max is 64KB, which is still quite conservative.
  ;; Modern LSP servers like rust-analyzer or clangd routinely send multi-megabyte responses.
  ;; Bumping this reduces the number of read calls Emacs has to make.
  ;; If you use eglot (or lsp-mode), this is basically free performance.

  (setq read-process-output-max (* 6 1024 1024)) ; 6MB

  ;; --- Don’t Render Cursors in Non-Focused Windows ---
  ;; If you have several windows visible, Emacs draws a cursor in each of them – even the ones you’re not working in.
  ;; It also highlights selections in non-focused windows. Two settings to stop that:

  (setq-default cursor-in-non-selected-windows nil)
  (setq highlight-nonselected-windows nil)

  ;; --- Save the Clipboard Before Killing ---
  ;; Here’s a scenario: you copy a URL from your browser, switch to Emacs, kill a line with C-k, and then try to yank the URL you copied earlier with C-y.
  ;; Gone. The kill replaced it on the clipboard.
  ;; This setting makes Emacs save the existing clipboard content into the kill ring before overwriting it:
  ;; Now C-y gets the kill, and M-y gets you back to the URL. Such a small thing, but it eliminates a genuinely annoying problem.

  (setq save-interprogram-paste-before-kill t)

  ;; --- No Duplicates in the Kill Ring ---
  ;; Kill the same line three times and you get three identical entries in the kill ring, wasting slots.
  ;; This deduplicates them:

  (setq kill-do-not-save-duplicates t)

  ;; --- Speedbar ---
  (setopt speedbar-window-default-width 25) ;; EMACS-31
  (setopt speedbar-window-max-width 25)     ;; EMACS-31

  ;; --- VC ---
  (setopt vc-auto-revert-mode t                    ; EMACS-31
          vc-allow-rewriting-published-history t   ; EMACS-31
          vc-dir-auto-hide-up-to-date t)     ; EMACS-31

  ;; -- General niceties ----
  (setopt delete-pair-push-mark t)                    ; EMACS-31: pushes a mark after
                                        ; delete-pair so C-x C-x selects what was inside
  (setopt ibuffer-human-readable-size t)              ; EMACS-31: KB/MB instead of raw byte counts
  (setopt kill-region-dwim 'emacs-word)               ; EMACS-31: C-w with no region kills a word
  (setopt native-comp-async-on-battery-power nil)     ; EMACS-31: stop native-comp jobs on battery
  (setopt view-lossage-auto-refresh t)                ; EMACS-31: live-updating C-h l, great for teaching/debugging
  (setopt display-fill-column-indicator-warning nil)  ; EMACS-31
  (setopt dired-hide-details-hide-absolute-location t); EMACS-31: hide the absolute dir path in dired-hide-details-mode
  (setopt world-clock-sort-order "%FT%T")             ; EMACS-31: sort the world clock sanely
  (setopt zone-all-frames t)                          ; EMACS-31
  (setopt zone-all-windows-in-frame t)                ; EMACS-31
  (setopt uniquify-after-kill-buffer-flag t)          ; EMACS-31: renamed from the -p variant


  ;; --- Persist the Kill Ring Across Sessions ---
  ;; Most configs that use savehist-mode only persist search rings. But savehist can save any variable – including the kill ring.
  ;; Add it and you get clipboard history that survives restarts:

  (setq savehist-additional-variables
        '(search-ring regexp-search-ring kill-ring))

  ;; One thing to watch out for: the kill ring can accumulate text properties (fonts, overlays, etc.) that bloat the savehist file.
  ;; With this you strip them before saving:
  (add-hook 'savehist-save-hook
            (lambda ()
              (setq kill-ring
                    (mapcar #'substring-no-properties
                            (cl-remove-if-not #'stringp kill-ring)))))

  ;; --- Prevent ffap from Pinging Hostnames ---
  ;; Ever had Emacs freeze for a few seconds when you ran find-file-at-point (or a command that uses it internally)?
  ;; If the text under point looks like a hostname – say, something.com in a comment
  ;; ffap tries to ping it to check if it’s reachable. On a slow or firewalled network, that’s a multi-second hang.

  (setq ffap-machine-p-known 'reject)

  ;; --- Faster Mark Popping ---
  ;; The mark ring is one of Emacs’s most underused navigation features.
  ;; Every time you jump somewhere – isearch, M-<, M->, goto-line, imenu, and many more
  ;; Emacs pushes your old position onto the mark ring. C-u C-SPC pops it, jumping you back.
  ;; The annoyance: you need C-u C-SPC every single time.
  ;; With this setting, after the first C-u C-SPC you can keep pressing just C-SPC to continue popping:

  (setq set-mark-command-repeat-pop t)

  ;; --- Trust some directories ---
  (add-to-list 'trusted-content "~/.emacs.d/")
  (add-to-list 'trusted-content "~/Hacking/")
  (add-to-list 'trusted-content "~/Work/")

  ;; --- Auto-Select Help Windows ---
  ;; When you press C-h f or C-h v, Emacs opens the help buffer but leaves your cursor in the original window.
  ;; You almost always want to read the help right away, so you end up pressing C-x o every single time. This fixes it:

  (setq help-window-select t)

  ;; --- Proportional Window Resizing ---
  ;; When you split a window with C-x 2 or C-x 3, Emacs halves the current window.
  ;; If you already have a multi-window layout, this can produce one awkwardly tiny window while others stay large.
  ;; With this setting, all windows in the frame resize proportionally:

  (setq window-combination-resize t)


  ;; --- Custom Modeline Construction ---
  (defun my-set-custom-modeline ()
    "Customize mode-line format using modusregel."
    (setq mode-line-format (list
                            modusregel-leading-str
                            modusregel-remote-expr
                            modusregel-buffer-name-expr
                            modusregel-buffer-modified-str
                            modusregel-buffer-read-only-str
                            modusregel-spacer-str

                            ;; Uncomment if nyan-mode is enabled above
                            ;; modusregel-nyan-expr

                            modusregel-spacer-str
                            modusregel-line-number-str
                            modusregel-column-number-str
                            modusregel-spacer-str
                            modusregel-buffer-position-expr
                            modusregel-spacer-str
                            modusregel-vc-expr
                            modusregel-major-mode-expr
                            modusregel-eglot-expr
                            modusregel-spacer-str
                            modusregel-flymake-expr
                            (ignore-errors keycast-mode-line))))

  (add-hook 'after-change-major-mode-hook #'my-set-custom-modeline)

  )


(use-package project
  :ensure nil
  :init
  ;; Treat directories with .envrc (direnv) as project roots.
  ;; Essential for Nix/Guix/direnv workflows so project.el knows where the project starts.
  (setq project-vc-extra-root-markers '(".envrc")))

(use-package markdown-ts-mode
  :ensure nil
  :hook ((markdown-ts-mode . heks-emacs-markdown-ts-mode))
  :config
  (defun heks-emacs-markdown-ts-mode ()
    (variable-pitch-mode 1)
    (auto-fill-mode 0)
    (visual-line-mode 1)
    ;; Only the prose faces, so opening a Markdown buffer never resets
    ;; the global text scale (see `heks-emacs-org-mode').
    (ignore-errors (heks-emacs-set-markdown-faces))))

(provide 'heks-emacs/emacs-self)

;;; emacs-core.el ends here
