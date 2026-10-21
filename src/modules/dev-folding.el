;;; dev-folding.el --- Code navigation and folding -*- lexical-binding: t -*-

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

;; Code navigation and folding.

;;; Code:

(use-package dumb-jump
  :ensure t
  :custom
  (dumb-jump-prefer-searcher 'rg)
  (xref-show-definitions-function #'consult-xref)
  :config
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate))

(use-package treesit-fold
  :ensure t
  :commands (treesit-fold-close
             treesit-fold-close-all
             treesit-fold-open
             treesit-fold-toggle
             treesit-fold-open-all
             treesit-fold-mode
             global-treesit-fold-mode
             treesit-fold-open-recursively
             treesit-fold-line-comment-mode)

  :custom
  (treesit-fold-line-count-show t)
  (treesit-fold-line-count-format " ▼")

  :hook ((
          bash-ts-mode
          c++-ts-mode
          c-ts-mode
          cmake-ts-mode
          css-ts-mode
          dockerfile-ts-mode
          elixir-ts-mode
          go-mod-ts-mode
          go-ts-mode
          heex-ts-mode
          html-ts-mode
          java-ts-mode
          js-ts-mode
          json-ts-mode
          kotlin-ts-mode
          lua-ts-mode
          nix-ts-mode
          php-ts-mode
          python-ts-mode
          ruby-ts-mode
          rust-ts-mode
          scala-ts-mode
          toml-ts-mode
          tsx-ts-mode
          tsx-ts-mode
          typescript-ts-mode
          yaml-ts-mode
          ) . treesit-fold-mode)

  :config
  ;; Fringe indicators for every foldable node in the Tree-sitter modes.
  (add-hook 'treesit-fold-mode-hook #'treesit-fold-indicators-mode)
  (set-face-attribute 'treesit-fold-replacement-face nil
                      :inherit 'shadow
                      :foreground 'unspecified
                      :box nil
                      :weight 'normal))

;;
;; ====== How quiet the fold indicators are ======
;;
;; Every engine draws its markers in a face that inherits `shadow', which
;; most themes make as bright as a comment.  That is too bright for what
;; Tree-sitter folding draws: a block's guide is not one marker on the line
;; the block starts on but a marker on every line of it, so the grey of
;; `shadow' becomes a rule running down the fringe beside the code.  The
;; colour is the theme's own `shadow' moved part of the way toward the
;; theme's background, so no theme needs an entry here and a light one is
;; faded the other way.

(defcustom heks-emacs-fold-indicator-fade 55
  "How far the fold indicators are faded toward the background, in percent.
0 leaves them as bright as `shadow', which is what they inherited before
this existed, and 100 makes them the colour of the background.  What is
worth the setting is the guide of a Tree-sitter block, drawn on every one
of its lines: at 55 the markers are still findable and the guides are a
hint rather than a rule drawn through the code."
  :type 'integer
  :group 'heks-emacs)

(defun heks-emacs-fold-indicator-color ()
  "Return the colour the fold indicators are drawn in, or nil for `shadow'.

It is the theme's `shadow' foreground blended
`heks-emacs-fold-indicator-fade' of the way toward the theme's background,
which is the one colour in the theme that is meant to be quiet.  A theme
that names no `shadow', and the frameless Emacs of a daemon before its
first frame, leave nil: the markers are then `shadow', as they were."
  (when (and (> heks-emacs-fold-indicator-fade 0)
             (fboundp 'heks-emacs--blend-colors))
    (let ((shadow (ignore-errors (face-attribute 'shadow :foreground nil t)))
          (background (ignore-errors (face-attribute 'default :background nil t))))
      (when (and (stringp shadow) (stringp background)
                 (not (string-prefix-p "unspecified" shadow))
                 (not (string-prefix-p "unspecified" background)))
        (heks-emacs--blend-colors shadow background
                                  (/ (float heks-emacs-fold-indicator-fade)
                                     100))))))

;; Subtle indicators: the faded `shadow' colour, no bold, for every engine.
(defun heks-emacs-fold-indicator-faces ()
  "Make the fold indicator faces of all engines quiet.

A face of a library that is not loaded yet is skipped, so this may run
before `treesit-fold' does; `heks-emacs-set-base-faces' calls it again on
every theme and scale change, and `with-eval-after-load' below once the
libraries are there."
  (let ((color (heks-emacs-fold-indicator-color)))
    (dolist (face '(hs-indicator-hide hs-indicator-show
                    treesit-fold-indicators-face
                    treesit-fold-fringe-face
                    treesit-fold-indicators-fringe-face))
      (when (facep face)
        (set-face-attribute face nil :inherit 'shadow :weight 'normal
                            :foreground (or color 'unspecified)
                            :background 'unspecified
                            :box nil)))))

(with-eval-after-load 'hideshow (heks-emacs-fold-indicator-faces))
(with-eval-after-load 'treesit-fold-indicators
  (heks-emacs-fold-indicator-faces))

(use-package kirigami
  :ensure t
  ;; No keys either: `C-c v c/o/r/t' dispatch to whichever folding engine
  ;; the buffer has, and kirigami is the fallback for the modes that have
  ;; neither Tree-sitter folds nor Hideshow.
  :commands (kirigami-open-fold
             kirigami-open-fold-rec
             kirigami-open-folds
             kirigami-close-fold
             kirigami-close-folds
             kirigami-toggle-fold
             kirigami-mode)
  :init
  ;; --- Fold indicators in the fringe, whichever engine folds the buffer ---
  ;; kirigami only dispatches; it draws nothing.  The indicators come from
  ;; the engine itself: `treesit-fold-indicators-mode' in every Tree-sitter
  ;; buffer (see above), and Hideshow's own (`hs-show-indicators') in every
  ;; other programming, configuration and XML buffer.  The two are never on
  ;; together, so a buffer has one marker per foldable block, and kirigami's
  ;; `C-c v' keys fold it either way.
  (setq hs-show-indicators t
        hs-indicator-type 'fringe
        ;; Outline buttons are switched on per buffer below, only where
        ;; Hideshow does not already draw an indicator.
        outline-minor-mode-use-buttons nil)
  (with-eval-after-load 'hideshow
    ;; XML and YAML are set up per buffer by `heks-emacs-hs-xml-setup' and
    ;; `heks-emacs-hs-yaml-setup' (hooks below).
    nil)
  (defun heks-emacs-hs-indent-forward (_arg)
    "Move to the end of the indented block that starts on this line.
For Hideshow in indentation-structured buffers such as YAML."
    (let ((indent (current-indentation)))
      (end-of-line)
      (let ((end (point)))
        (forward-line 1)
        (while (and (not (eobp))
                    (or (looking-at-p "[ \t]*\\(?:#.*\\)?$")
                        (> (current-indentation) indent)))
          (unless (looking-at-p "[ \t]*$")
            (setq end (line-end-position)))
          (forward-line 1))
        (goto-char end))))
  (defun heks-emacs-hs-xml-setup ()
    "Fold XML elements, from start tag to end tag, with Hideshow.
Skips `<?xml ?>', `<!-- -->', `<!DOCTYPE>' and empty `<tag/>' elements."
    (setq-local hs-block-start-regexp "<[A-Za-z_][^>]*[^/>]>\\|<[A-Za-z_]>"
                hs-block-start-mdata-select 0
                hs-block-end-regexp "</[^>]+>"
                hs-c-start-regexp "<!--"
                hs-forward-sexp-function
                (lambda (_arg)
                  (let ((end (condition-case nil
                                 (nxml-scan-element-forward (point))
                               (error nil))))
                    (if end
                        (goto-char end)
                      (signal 'scan-error (list "No end tag" (point) (point))))))))
  (defun heks-emacs-hs-yaml-setup ()
    "Fold YAML mappings and sequences by indentation with Hideshow."
    (setq-local hs-block-start-regexp "^[ \t]*[^ \t\n#][^\n]*:[ \t]*\\(?:#.*\\)?$"
                hs-block-start-mdata-select 0
                hs-block-end-regexp nil
                hs-c-start-regexp "#"
                hs-forward-sexp-function #'heks-emacs-hs-indent-forward))
  (add-hook 'nxml-mode-hook #'heks-emacs-hs-xml-setup)
  (add-hook 'yaml-mode-hook #'heks-emacs-hs-yaml-setup)
  (defun heks-emacs-fold-indicators-setup ()
    "Give the buffer exactly one set of fold indicators.

Runs after every mode hook (see `after-change-major-mode-hook'), by which
time `treesit-fold-mode' is either on or will not be.  Tree-sitter buffers
get only its indicators; the other programming, configuration and XML
buffers get Hideshow's.  Where outline buttons would duplicate Hideshow's
indicators, the buttons are turned off.  Org and Markdown are left alone."
    (unless (minibufferp)
      (cond
       ((or (bound-and-true-p treesit-fold-mode)
            ;; Tree-sitter buffers the :hook above did not reach (a mode
            ;; switched on through a remap, say) get the mode here.
            (and (string-suffix-p "-ts-mode" (symbol-name major-mode))
                 (treesit-parser-list)
                 (progn (treesit-fold-mode 1)
                        (bound-and-true-p treesit-fold-mode))))
        (when (bound-and-true-p hs-minor-mode)
          (hs-minor-mode -1))
        (unless (bound-and-true-p treesit-fold-indicators-mode)
          (treesit-fold-indicators-mode 1)))
       ((derived-mode-p 'prog-mode 'conf-mode 'nxml-mode 'toml-mode
                        'yaml-mode)
        (when (bound-and-true-p outline-minor-mode)
          ;; Outline buttons next to Hideshow's indicators would double up.
          (outline-minor-mode -1)
          (setq-local outline-minor-mode-use-buttons nil)
          (outline-minor-mode 1))
        (unless (bound-and-true-p hs-minor-mode)
          (hs-minor-mode 1)))
       ((and (bound-and-true-p outline-minor-mode)
             (not (derived-mode-p 'org-mode)))
        ;; Outline-only buffers (Markdown, Diff) get clickable buttons.
        (outline-minor-mode -1)
        (setq-local outline-minor-mode-use-buttons t)
        (outline-minor-mode 1)))))
  (add-hook 'after-change-major-mode-hook #'heks-emacs-fold-indicators-setup)
  :config
  ;; kirigami answers with the first engine in its list whose mode is on,
  ;; and `outline-minor-mode' is on in almost every buffer here.  In the
  ;; buffers where `hs-minor-mode' was turned on deliberately -- a Scheme
  ;; buffer, which folds its definitions with it -- that deliberate choice
  ;; has to win, or `C-c v c' folds headings that a Scheme file does not
  ;; have.  The list is reordered rather than rewritten, so an engine
  ;; kirigami adds later is still used wherever Hideshow is off.
  (with-eval-after-load 'kirigami
    (setq kirigami-fold-list
          (append (seq-filter (lambda (entry) (memq 'hs-minor-mode (car entry)))
                              kirigami-fold-list)
                  (seq-remove (lambda (entry) (memq 'hs-minor-mode (car entry)))
                              kirigami-fold-list)))))

(provide 'heks-emacs/dev-folding)

;;; dev-folding.el ends here
