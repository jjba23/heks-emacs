;;; dev-folding.el --- Code navigation and folding -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>


;;; Commentary:

;; Code navigation and folding.

;;; Code:

;; `xref' is what the dispatcher below extends and `cl-defmethod' is how a
;; backend is written, so both are required here rather than reached through
;; an autoload: a method defined before its generic function exists is a
;; generic function `xref' then defines again.
(require 'cl-lib)
(require 'seq)
(require 'xref)

;; The one function of Eglot this file asks, and only to find out whether a
;; buffer is a server's; the rest of Eglot is asked through `xref', whose
;; generic functions are what a backend is.
(declare-function eglot-managed-p "eglot" (&optional buffer))

(use-package dumb-jump
  :ensure t
  :custom
  (dumb-jump-prefer-searcher 'rg)
  (xref-show-definitions-function #'consult-xref)
  :config
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate))

;;
;; ====== A definition, whichever way it is found ======
;;
;; `xref' asks one backend: it runs the functions of
;; `xref-backend-functions' until one answers with the backend of the
;; buffer, and whatever that backend says is the answer -- including
;; nothing.  A language server is the best answer to `M-.' when it has one,
;; and it has none for a name it cannot resolve: a definition in a file it
;; has not indexed, a macro of the language, a name whose module it does not
;; know.  In a buffer a server manages, the server is therefore asked first
;; and, where it has nothing, the backends that were there before it answer:
;; its answer is the first rather than the only one.
;;
;; Nothing changes in a buffer no server manages -- `heks/xref-install' is
;; what puts the entry in the hook, and it is on Eglot's own hook -- so `M-.'
;; in a Scheme file with no server is `heks/scheme' and the files as before,
;; and a language whose server this configuration registers elsewhere (the
;; three Lisps, whose server is sift's, see `modules/sift.el') is one of the
;; buffers it applies to rather than an exception.  Nor does it replace a
;; backend: the ones the buffer already had are the ones asked after the
;; server, in the order the hook names them.

(defun heks/xref-backend ()
  "Return the chaining backend when a language server manages this buffer.

`xref' takes the first function of `xref-backend-functions' that answers
for a buffer, and this one answers for a buffer a server is in: the
server's answer first, and the answers of the other backends of the
buffer where it has none (see `heks/xref--first').  Every other buffer
is left to the backends it had."
  (when (and (fboundp 'eglot-managed-p) (eglot-managed-p))
    'heks/xref))

(defun heks/xref--backend-functions ()
  "Return the functions of `xref-backend-functions' as `xref' runs them.

A buffer-local value holds the functions the buffer itself added, with the
symbol t where the global value belongs -- that is what `add-hook' puts
there when it is given a LOCAL argument, and what
`run-hook-with-args-until-success' expands into the global functions.
Both halves are backends here: the server's own entry is in the buffer's
value and the rest of the configuration's are in the global one."
  (let ((global (ensure-list (default-value 'xref-backend-functions))))
    (seq-mapcat (lambda (function)
                  (if (eq function t) global (list function)))
                (ensure-list xref-backend-functions))))

(defun heks/xref--backends ()
  "Return the backends of this buffer, without the one asking.

Each function of the hook is asked for the backend it serves, which is
what `xref' does with them; one that serves nothing here -- saying nil,
or signalling because the buffer is not its -- contributes nothing.  The
server's backend comes first, since the buffer's own entry is ahead of
the global ones."
  (let ((served (mapcar (lambda (function)
                          (when (and (functionp function)
                                     (not (eq function #'heks/xref-backend)))
                            (ignore-errors (funcall function))))
                        (heks/xref--backend-functions))))
    (seq-uniq (delq nil served))))

(defun heks/xref--first (method backends &rest arguments)
  "Return the first non-nil answer to METHOD asked of BACKENDS.

METHOD is one of the `xref-backend-*' generic functions, ARGUMENTS what
it is given after the backend, and a backend that signals is one that has
nothing to say here: Eglot's own methods signal where the server does not
support the request, which is a fallback rather than an error."
  (seq-some (lambda (backend)
              (ignore-errors (apply method backend arguments)))
            backends))

(defun heks/xref--server-backend ()
  "Return the backend of the language server, or nil where Eglot is absent."
  (when (fboundp 'eglot-xref-backend) (eglot-xref-backend)))

(defun heks/xref--identifier-at-point ()
  "Return the name at point, as the buffer's own backends read it.

The server's own reading is the last one asked for.  In a buffer Eglot
manages it is usually a stand-in rather than a name -- Eglot sets
`xref-prompt-for-identifier' to nil there, so it has no reason to work
out which name is meant, and asks the server about the place point is at
instead -- and a stand-in is not a name to hand to the backends that
follow, which search for one."
  (let* ((backends (heks/xref--backends))
         (server (heks/xref--server-backend))
         (others (if server (delq server (copy-sequence backends)) backends)))
    (or (heks/xref--first #'xref-backend-identifier-at-point others)
        (heks/xref--first #'xref-backend-identifier-at-point backends))))

(cl-defmethod xref-backend-identifier-at-point ((_backend (eql heks/xref)))
  "Return the name at point, read the way the buffer's tools read it."
  (heks/xref--identifier-at-point))

(cl-defmethod xref-backend-identifier-completion-table
    ((_backend (eql heks/xref)))
  "Return the names a jump can be asked for: the server's, or the others'.

The server's table is the workspace's symbols, which is the widest list of
names on offer; a backend that has no table of its own says nil and the
next one is asked."
  (heks/xref--first #'xref-backend-identifier-completion-table
                    (heks/xref--backends)))

(cl-defmethod xref-backend-definitions ((_backend (eql heks/xref)) identifier)
  "Return the definitions of IDENTIFIER: the server's, or the others'."
  (heks/xref--first #'xref-backend-definitions
                    (heks/xref--backends) identifier))

(cl-defmethod xref-backend-references ((_backend (eql heks/xref)) identifier)
  "Return the places IDENTIFIER is used: the server's, or the others'."
  (heks/xref--first #'xref-backend-references
                    (heks/xref--backends) identifier))

(cl-defmethod xref-backend-apropos ((_backend (eql heks/xref)) pattern)
  "Return what matches PATTERN: the server's names, or the others'.

`xref-find-apropos' is answered by one backend, so the server's names are
what is offered where it has any, and the files are what is read where it
has none."
  (heks/xref--first #'xref-backend-apropos
                    (heks/xref--backends) pattern))

(defun heks/xref-install ()
  "Put the chaining backend in front of the server's own, or take it out.

Both entries are buffer-local, so the order is decided here rather than
by the global hook: the depth puts this one ahead of the entry
`eglot--managed-mode' added at the default depth, and the server's own
entry is what the chaining backend asks first.  A buffer the server has
stopped managing gets the entry taken out, which leaves its own backends
as they were."
  (if (and (fboundp 'eglot-managed-p) (eglot-managed-p))
      (add-hook 'xref-backend-functions #'heks/xref-backend -90 t)
    (remove-hook 'xref-backend-functions #'heks/xref-backend t)))

(add-hook 'eglot-managed-mode-hook #'heks/xref-install)

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
          markdown-ts-mode
          ) . treesit-fold-mode)

  :config
  ;; treesit-fold ships no Markdown rules.  A `section' node is a heading
  ;; and everything under it, nested sections included, so folding it from
  ;; the end of the heading line is Org's per-heading fold.
  (defun heks/markdown-fold-range (node offset)
    "Fold range of the Markdown section NODE, below its heading line."
    (let ((beg (save-excursion
                 (goto-char (treesit-node-start node))
                 (line-end-position)))
          (end (max (treesit-node-start node)
                    (1- (treesit-node-end node)))))
      (when (> end beg)
        (treesit-fold--cons-add (cons beg end) offset))))
  ;; `treesit-fold' asks for "the" root node, and in a Markdown buffer the
  ;; first parser is the embedded HTML one, which has no sections.
  (defun heks/markdown-primary-root (original &optional language)
    "Call ORIGINAL; in Markdown buffers with no LANGUAGE use the primary parser."
    (if (and (null language)
             (derived-mode-p 'markdown-ts-mode)
             (treesit-parser-p treesit-primary-parser))
        (treesit-parser-root-node treesit-primary-parser)
      (funcall original language)))
  (advice-add 'treesit-buffer-root-node :around
              #'heks/markdown-primary-root)
  (with-eval-after-load 'treesit-fold
    (setf (alist-get 'markdown-ts-mode treesit-fold-range-alist)
          '((section . heks/markdown-fold-range))))
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

(defcustom heks/fold-indicator-fade 50
  "How far the fold indicators are faded toward the background, in percent.
0 leaves them as bright as `shadow', which is what they inherited before
this existed, and 100 makes them the colour of the background.  What is
worth the setting is the guide of a Tree-sitter block, drawn on every one
of its lines: at 50 the markers are still findable and the guides are a
hint rather than a rule drawn through the code.  It was 55 until the
guide stopped being a dotted line (see below): a guide drawn solid reads
lighter than one drawn in dashes, so it is given back five points of the
colour that drawing it properly took away."
  :type 'integer
  :group 'heks)

(defun heks/fold-indicator-color ()
  "Return the colour the fold indicators are drawn in, or nil for `shadow'.

It is the theme's `shadow' foreground blended
`heks/fold-indicator-fade' of the way toward the theme's background,
which is the one colour in the theme that is meant to be quiet.  A theme
that names no `shadow', and the frameless Emacs of a daemon before its
first frame, leave nil: the markers are then `shadow', as they were."
  (when (and (> heks/fold-indicator-fade 0)
             (fboundp 'heks/blend-colors))
    (let ((shadow (ignore-errors (face-attribute 'shadow :foreground nil t)))
          (background (ignore-errors (face-attribute 'default :background nil t))))
      (when (and (stringp shadow) (stringp background)
                 (not (string-prefix-p "unspecified" shadow))
                 (not (string-prefix-p "unspecified" background)))
        (heks/blend-colors shadow background
                                  (/ (float heks/fold-indicator-fade)
                                     100))))))

(defun heks/fold-indicator-redraw ()
  "Draw the Tree-sitter fold indicators again, with this theme's bitmaps."
  (when (fboundp 'treesit-fold-indicators--render-buffer)
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        (when (bound-and-true-p treesit-fold-indicators-mode)
          (ignore-errors (treesit-fold-indicators--render-buffer)))))))

;; Subtle indicators: the faded `shadow' colour, no bold, for every engine.
(defun heks/fold-indicator-faces ()
  "Make the fold indicator faces of all engines quiet.

A face of a library that is not loaded yet is skipped, so this may run
before `treesit-fold' does; `heks/set-base-faces' calls it again on
every theme and scale change, and `with-eval-after-load' below once the
libraries are there."
  (let ((color (heks/fold-indicator-color)))
    (dolist (face '(hs-indicator-hide hs-indicator-show
                    treesit-fold-indicators-face
                    treesit-fold-fringe-face
                    treesit-fold-indicators-fringe-face))
      (when (facep face)
        (set-face-attribute face nil :inherit 'shadow :weight 'normal
                            :foreground (or color 'unspecified)
                            :background 'unspecified
                            :box nil))))
  ;; The markers are cut to the height of a line, and a new text scale
  ;; makes a new one: they are drawn again as well as recoloured.
  (heks/fold-indicator-redraw))

;;
;; ====== Where the guides are unbroken ======
;;
;; `treesit-fold-indicators' draws a block's guide with a bitmap 23 rows
;; tall, centred in the line it is drawn beside.  A line of this
;; configuration is 29 pixels -- the font's 23 and the six of
;; `line-spacing' -- so every row of a guide was a 23 pixel dash with
;; three pixels of nothing above it and three below, and a block read as a
;; dotted line rather than as a bracket.  The bitmaps below are what the
;; package is given instead, through the string it builds for each line of
;; a block: the guide is a single row, which `define-fringe-bitmap'
;; repeats for as long as the line it is drawn beside, so no spacing can
;; put a gap in it, and the marker and the end of a block are cut to the
;; height of a line, so the guide runs into them rather than stopping
;; short of them.
;;
;; Drawing them in the left margin instead is what would put them in text,
;; and the `pointer' property of text is what turns the mouse into a hand
;; over a link.  It buys none: Emacs answers every position in a margin
;; with the nontext cursor before it looks at the string there -- see
;; `note_mouse_highlight' in `xdisp.c' -- so a hand over a fold indicator
;; is a change to Emacs itself and not to this file.  The indicators stay
;; in the fringe, and what was wrong with them there is what this fixes.

(defconst heks/fold-indicator-line-row #b00011000
  "One row of a block's guide: two pixels, in the columns it always had.")

(defconst heks/fold-indicator-box-open
  [#b1111111 #b1000001 #b1000001 #b1011101 #b1000001 #b1000001 #b1111111]
  "The marker of a block that is open: a box with a minus in it.")

(defconst heks/fold-indicator-box-closed
  [#b1111111 #b1000001 #b1001001 #b1011101 #b1001001 #b1000001 #b1111111]
  "The marker of a block that is folded away: a box with a plus in it.")

(defconst heks/fold-indicator-elbow #b00011111
  "The guide of a block turning right, toward the text it brackets.")

(defun heks/fold-indicator-define-guide ()
  "Define the bitmap that draws the guide of a block.
The guide is a single row, which the periodic `top' alignment repeats for
as long as the line it is drawn beside: no line spacing can put a gap in
it."
  (define-fringe-bitmap 'heks/fold-indicator-guide
    (vector heks/fold-indicator-line-row) nil nil '(top t)))

(heks/fold-indicator-define-guide)

(defun heks/fold-indicator-line-spacing ()
  "Return the pixels `line-spacing' adds below a line of this buffer."
  (let ((spacing (if (boundp 'line-spacing) line-spacing 0))
        (height (window-font-height)))
    (cond ((integerp spacing) spacing)
          ((floatp spacing) (round (* spacing height)))
          ((and (consp spacing)
                (integerp (car spacing))
                (integerp (cdr spacing)))
           (+ (car spacing) (cdr spacing)))
          (t 0))))

(defun heks/fold-indicator-line-height (&optional window)
  "Return the height in pixels of a line of WINDOW, its spacing included."
  (+ (window-font-height window) (heks/fold-indicator-line-spacing)))

(defun heks/fold-indicator-fringe-rows (kind height)
  "Return the HEIGHT rows of the fringe bitmap that draws KIND.
KIND is `open' for the line a block starts on while it is open,
`closed' for that line while it is folded away, or `end' for the line
it ends on.  The box of a marker is centred, and the guide of an open
block runs from the box to the bottom of the bitmap, where the guide of
the line below picks it up."
  (let ((rows (make-vector height 0)))
    (if (eq kind 'end)
        (let ((middle (/ height 2)))
          (dotimes (index height)
            (aset rows index (cond ((< index middle)
                                    heks/fold-indicator-line-row)
                                   ((< index (+ middle 2))
                                    heks/fold-indicator-elbow)
                                   (t 0)))))
      (let* ((box (if (eq kind 'closed)
                      heks/fold-indicator-box-closed
                    heks/fold-indicator-box-open))
             (box-height (length box))
             (box-top (max 0 (/ (- height box-height) 2))))
        (dotimes (index box-height)
          (when (< (+ box-top index) height)
            (aset rows (+ box-top index) (aref box index))))
        (when (eq kind 'open)
          (let ((index (min height (+ box-top box-height))))
            (while (< index height)
              (aset rows index heks/fold-indicator-line-row)
              (setq index (1+ index)))))))
    rows))

(defun heks/fold-indicator-fringe-bitmap (kind &optional window)
  "Return the fringe bitmap that draws KIND beside a line of WINDOW.
`guide' is the repeating bitmap above; `open', `closed' and `end' are cut
to the height of a line and defined once per height, since a marker that
stops short of the line below it is the dotting this is here to undo."
  (if (eq kind 'guide)
      'heks/fold-indicator-guide
    (let* ((height (max 9 (heks/fold-indicator-line-height window)))
           (name (intern (format "heks/fold-indicator-%s-%d"
                                 kind height))))
      (unless (get name 'fringe)
        (define-fringe-bitmap name
          (heks/fold-indicator-fringe-rows kind height)
          nil nil 'top))
      name)))

(defun heks/fold-indicator-fringe ()
  "Return the fringe the fold indicators are drawn in."
  (if (bound-and-true-p treesit-fold-indicators-fringe)
      treesit-fold-indicators-fringe
    'left-fringe))

(defun heks/fold-indicator-tree-sitter (folded overlay bitmap)
  "Return the string that draws one line of a Tree-sitter fold.
Replaces `treesit-fold-indicators--get-string', whose answer is what the
package puts in front of the line: FOLDED is the state of the block,
OVERLAY the indicator, and BITMAP the drawing the package chose, which
says whether the line is the one the block starts on, one of its middle
lines or the one it ends on."
  (let ((kind (pcase bitmap
                ('treesit-fold-indicators-fr-plus 'closed)
                ('treesit-fold-indicators-fr-minus-tail 'open)
                ('treesit-fold-indicators-fr-center 'guide)
                ('treesit-fold-indicators-fr-end-left 'end)
                ('treesit-fold-indicators-fr-end-right 'end))))
    ;; A folded block shows the line it starts on and nothing else, which
    ;; is what the package's own bitmaps did.
    (when (and kind (or (not folded) (eq kind 'closed)))
      (let ((window (or (overlay-get overlay 'window) (selected-window)))
            (face (or (and (functionp
                            (bound-and-true-p
                             treesit-fold-indicators-face-function))
                           (funcall treesit-fold-indicators-face-function
                                    (overlay-start overlay)))
                      'treesit-fold-fringe-face)))
        (propertize "." 'display
                    (list (heks/fold-indicator-fringe)
                          (heks/fold-indicator-fringe-bitmap kind window)
                          face))))))

(with-eval-after-load 'hideshow (heks/fold-indicator-faces))
(with-eval-after-load 'treesit-fold-indicators
  ;; The guide of a block is drawn by this function, one line at a time:
  ;; it is what decides which bitmap goes in front of which line, so the
  ;; guide is one row repeated instead of the package's 23 row dashes.
  (advice-add 'treesit-fold-indicators--get-string
              :override #'heks/fold-indicator-tree-sitter)
  (heks/fold-indicator-faces))

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
    ;; XML and YAML are set up per buffer by `heks/hs-xml-setup' and
    ;; `heks/hs-yaml-setup' (hooks below).
    nil)
  (defun heks/hs-indent-forward (_arg)
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
  (defun heks/hs-xml-setup ()
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
  (defun heks/hs-yaml-setup ()
    "Fold YAML mappings and sequences by indentation with Hideshow."
    (setq-local hs-block-start-regexp "^[ \t]*[^ \t\n#][^\n]*:[ \t]*\\(?:#.*\\)?$"
                hs-block-start-mdata-select 0
                hs-block-end-regexp nil
                hs-c-start-regexp "#"
                hs-forward-sexp-function #'heks/hs-indent-forward))
  (add-hook 'nxml-mode-hook #'heks/hs-xml-setup)
  (add-hook 'yaml-mode-hook #'heks/hs-yaml-setup)
  (defun heks/fold-indicators-setup ()
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
  (add-hook 'after-change-major-mode-hook #'heks/fold-indicators-setup)
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

(provide 'heks/dev-folding)

;;; dev-folding.el ends here
