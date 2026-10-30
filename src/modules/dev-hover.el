;;; dev-hover.el --- Mouse hover documentation for Eglot and Geiser -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Rest the mouse on a symbol and a tooltip explains it, as in any IDE.
;;
;; Nothing here talks to a language server or to a REPL.  Eglot (hover,
;; signature help, diagnostics) and Geiser (autodoc) already register their
;; answers with ElDoc, which shows them for the symbol at point in the echo
;; area.  What this module adds is only the mouse: it asks the same ElDoc
;; functions about the position under the pointer, and hands the answer to
;; a popup.  A repeating timer notices where the pointer rests; the question
;; is asked and answered asynchronously (`heks/hover--request'), so neither
;; the mouse nor typing ever waits on a server or a REPL.  The popup is a
;; bounded child frame (at most `heks/hover-max-width'
;; by `heks/hover-max-height', and never more than half / 40% of the frame)
;; with padding, a border, wrapped lines and Markdown rendered through
;; `gfm-view-mode' when the text is raw.  Hover needs a graphical frame; in a
;; terminal use `C-c i D' for the same text in a buffer.
;;
;; It is on for a buffer exactly while `eglot--managed-mode' or
;; `geiser-mode' is, and in Emacs Lisp buffers, where ElDoc's own
;; `elisp-eldoc-*' functions supply function signatures, variable
;; docstrings and the like.  `heks/hover-mode' can be switched off with
;; `C-c i H' when a tooltip is in the way.

;;; Code:

(require 'eldoc)
(require 'cl-lib)

(defgroup heks/hover nil
  "Mouse hover documentation."
  :group 'tools)

(defcustom heks/hover-timeout 0.6
  "Seconds after which the answers that have arrived are shown regardless.
The first answer is shown as soon as it arrives, so this is not how long a
popup takes to appear: it is how long the request waits for the quieter
sources before it is closed, and a source that answers later still updates the
popup while it is on screen."
  :type 'number
  :group 'heks/hover)

(defcustom heks/hover-max-lines 40
  "Most lines of documentation kept; the rest is cut with an ellipsis."
  :type 'integer
  :group 'heks/hover)

(defcustom heks/hover-max-width 80
  "Widest hover popup, in characters (also capped at half the frame)."
  :type 'integer
  :group 'heks/hover)

(defcustom heks/hover-max-height 16
  "Tallest hover popup, in lines (also capped at 40% of the frame)."
  :type 'integer
  :group 'heks/hover)

(defcustom heks/hover-backend 'auto
  "How the popup is drawn.
`child-frame' draws a bounded, padded child frame; it needs a window system
that really embeds child frames (X11, Windows).  Under tiling or dynamic window
managers (OmniWM on macOS, Niri on GNU/Linux via Wayland/pgtk) a child frame is
a separate toplevel that the WM may tile, focus or animate, so it flickers or
steals space.  `tooltip' uses Emacs's native tooltip, which every WM leaves
alone.  `auto' picks `child-frame' only on plain X11 and `tooltip' elsewhere."
  :type '(choice (const auto) (const child-frame) (const tooltip))
  :group 'heks/hover)

(defun heks/hover--backend ()
  "Return the backend to use for the selected frame."
  (cond ((not (eq heks/hover-backend 'auto)) heks/hover-backend)
        ((and (eq window-system 'x) (not (featurep 'pgtk))
              (not (getenv "WAYLAND_DISPLAY")))
         'child-frame)
        (t 'tooltip)))

(defvar heks/hover-mode)
(defvar heks/hover--frame nil "The child frame the popup is drawn in.")
(defconst heks/hover--buffer " *heks-hover*")
(defvar heks/hover--shown nil
  "Cons of (TEXT . (WIDTH . HEIGHT)): the popup as it was last measured.
Rendering a document and then measuring it is the expensive half of showing a
popup, and hovering along a line asks for the same text again and again.")

(defun heks/hover--request (pos callback)
  "Ask ElDoc's functions about POS in the current buffer, without waiting.

CALLBACK is called with the answers joined by blank lines (or nil when there
are none) as soon as the first one arrives, and again as the others come in, so
that a source which answers at once is not held behind one that thinks about
it.  `heks/hover-timeout' closes the request, and whatever has arrived by then
is what it says.  It runs in the buffer this was called from, if that is still
live.  Nothing here blocks: the functions in `eldoc-documentation-functions'
are called with a callback, exactly as ElDoc does, and the answers arrive
whenever the server or the REPL sends them."
  (let* ((buffer (current-buffer))
         (slots '())
         (finished nil)
         (asked nil)
         (timer nil)
         ;; Whatever has been said so far, handed over now rather than at the
         ;; end: the popup that waits for the last server to answer waits for
         ;; the slowest one every time.
         (settle
          (lambda ()
            (let* ((docs (delq nil (mapcar #'car (reverse slots))))
                   (text (and docs
                              (string-join (mapcar #'string-trim docs)
                                           "\n\n"))))
              (when (and text (not (string-empty-p text)) (buffer-live-p buffer))
                (with-current-buffer buffer (funcall callback text))))))
         (finish
          (lambda ()
            (unless finished
              (setq finished t)
              (when (timerp timer) (cancel-timer timer))
              (funcall settle)))))
    (setq timer (run-with-timer heks/hover-timeout nil finish))
    (save-excursion
      (goto-char pos)
      (dolist (fn eldoc-documentation-functions)
        ;; The slot is on the list before the function is called: a function is
        ;; allowed to answer in the same breath it was asked, and an answer
        ;; that arrives before its slot exists is an answer lost.
        (let ((slot (cons nil nil)))
          (push slot slots)
          (let ((result (ignore-errors
                          (funcall fn
                                   (lambda (doc &rest _)
                                     (when (stringp doc) (setcar slot doc))
                                     (setcdr slot t)
                                     (funcall settle)
                                     ;; Last one in closes the request.
                                     (when (and asked (cl-every #'cdr slots))
                                       (funcall finish)))))))
            ;; Non-nil means "I will call the callback"; nil means there is
            ;; nothing to say here.
            (unless result
              (setcdr slot t))))))
    (setq asked t)
    (when (cl-every #'cdr slots)
      (funcall finish))))

(defun heks/hover--truncate (text)
  "Cut TEXT to `heks/hover-max-lines' lines."
  (let ((lines (split-string text "\n")))
    (if (<= (length lines) heks/hover-max-lines)
        text
      (concat (string-join (seq-take lines heks/hover-max-lines) "\n")
              "\n… (C-c i D for the full text)"))))

;;
;; ====== The popup ======
;;

(defconst heks/hover--texinfo-re
  "@\\(?:code\\|var\\|samp\\|example\\|lisp\\|deffnx?\\|defun\\|defvr\\|emph\\|strong\\|file\\|command\\|option\\|xref\\|ref\\|pxref\\|dots\\|table\\|itemize\\|item\\)\\b"
  "Texinfo commands that mark a docstring as Texinfo (Guile, Guix, Geiser).")

(defun heks/hover--texinfo-to-markdown (text)
  "Turn the Texinfo in TEXT into Markdown, which `gfm-view-mode' can show."
  (with-temp-buffer
    (insert (substring-no-properties text))
    (let ((case-fold-search nil))
      (dolist (rule
               '(("^@\\(?:example\\|lisp\\|smallexample\\|smalllisp\\)[ \t]*$" . "```scheme")
                 ("^@end \\(?:example\\|lisp\\|smallexample\\|smalllisp\\)[ \t]*$" . "```")
                 ("^@end [a-z]+[ \t]*$" . "")
                 ("^@\\(?:itemize\\|enumerate\\|table\\)\\b.*$" . "")
                 ("^@itemx?[ \t]+" . "- ")
                 ("^@def[a-z]*x?[ \t]+\\(?:{[^}]*}\\|[^ \t\n]+\\)[ \t]+\\(\\S-+\\)\\(.*\\)$"
                  . "**\\1**\\2")
                 ("@\\(?:code\\|samp\\|command\\|file\\|option\\|env\\|kbd\\){\\([^{}]*\\)}" . "`\\1`")
                 ("@\\(?:var\\|emph\\|dfn\\|cite\\){\\([^{}]*\\)}" . "*\\1*")
                 ("@strong{\\([^{}]*\\)}" . "**\\1**")
                 ("@\\(?:p?x?ref\\|uref\\|url\\){\\([^{},]*\\)[^{}]*}" . "`\\1`")
                 ("@dots{}" . "…")
                 ("@result{}" . "⇒")
                 ("@print{}" . "⊣")
                 ("@error{}" . "error→")
                 ("@\\([{}@]\\)" . "\\1")))
        (goto-char (point-min))
        (while (re-search-forward (car rule) nil t)
          (replace-match (cdr rule)))))
    (buffer-string)))

(defun heks/hover--break-signature (line)
  "Break LINE, a long signature, after its top-level parameter commas."
  (if (or (<= (length line) heks/hover-max-width)
          (not (string-match-p "(" line)))
      line
    (let ((depth 0) (out '()) (start 0) (i 0) (n (length line)) (opened nil))
      (while (< i n)
        (let ((c (aref line i)))
          (cond
           ((memq c '(?\( ?\[ ?\{))
            (when (and (= depth 0) (not opened) (eq c ?\())
              (setq opened t)
              (push (substring line start (1+ i)) out)
              (setq start (1+ i)))
            (cl-incf depth))
           ((and (eq c ?<) (> depth 0)) (cl-incf depth))
           ((and (eq c ?>) (> depth 1) (not (eq (and (> i 0) (aref line (1- i))) ?-)))
            (cl-decf depth))
           ((memq c '(?\) ?\] ?\}))
            (cl-decf depth)
            (when (and (= depth 0) (eq opened t) (eq c ?\)))
              (push (substring line start i) out)
              (setq start i opened 'done)))
           ((and (eq c ?,) (= depth 1) (eq opened t))
            (push (substring line start (1+ i)) out)
            (setq start (1+ i)))))
        (cl-incf i))
      (push (substring line start) out)
      (let ((parts (nreverse out)))
        (if (< (length parts) 3)
            line
          (concat (car parts) "\n"
                  (mapconcat (lambda (p) (concat "    " (string-trim p)))
                             (butlast (cdr parts)) "\n")
                  "\n" (car (last parts))))))))

(defun heks/hover--break-code (text)
  "Break the long signature lines of the fenced code blocks in TEXT."
  (let ((in nil))
    (mapconcat
     (lambda (line)
       (cond ((string-match-p "\\`[ \t]*```" line) (setq in (not in)) line)
             (in (heks/hover--break-signature line))
             (t line)))
     (split-string text "\n") "\n")))

(defun heks/hover--render (text)
  "Fill the popup buffer with TEXT, rendering it as Markdown if it is raw.

Eglot hands over text that is already rendered (it carries faces); what
Geiser and Elisp give is plain, and is run through `gfm-view-mode' when
that is installed so that code fences and emphasis read properly.  A
Texinfo docstring is first converted to Markdown, whatever faces it has.
Text Eglot has already run through Markdown (it carries `markdown-*'
properties and invisible fences, tied to a buffer that is gone) is
stripped and rendered afresh."
  (with-current-buffer (get-buffer-create heks/hover--buffer)
    (let* ((inhibit-read-only t)
           (texinfo (let ((case-fold-search nil))
                      (string-match-p heks/hover--texinfo-re text)))
           (fenced (string-match-p "^[ \t]*```" text))
           (text (cond (texinfo (heks/hover--texinfo-to-markdown text))
                       (fenced (substring-no-properties text))
                       (t text)))
           (text (if (or texinfo fenced) (heks/hover--break-code text) text))
           (texinfo (or texinfo fenced)))
      (erase-buffer)
      (kill-all-local-variables)
      (insert (string-trim text))
      (let ((rendered (and (not texinfo)
                           (text-property-not-all (point-min) (point-max) 'face nil))))
        (when (and (not rendered) (fboundp 'gfm-view-mode))
          (delay-mode-hooks (gfm-view-mode))
          (font-lock-ensure)))
      (setq-local mode-line-format nil
                  header-line-format nil
                  cursor-type nil
                  truncate-lines nil
                  word-wrap t
                  line-spacing 0.1
                  left-margin-width 1
                  right-margin-width 1
                  show-trailing-whitespace nil)
      (visual-line-mode 1)
      (face-remap-add-relative 'default :inherit 'tooltip)
      (goto-char (point-min)))
    (current-buffer)))

(defun heks/hover--ensure-frame (parent)
  "Return the popup frame, a child of PARENT, creating it when needed."
  (unless (and (frame-live-p heks/hover--frame)
               (eq (frame-parent heks/hover--frame) parent))
    (when (frame-live-p heks/hover--frame)
      (delete-frame heks/hover--frame))
    ;; A popup measured in another frame -- another font, another theme, another
    ;; size -- says nothing about this one.
    (setq heks/hover--shown nil)
    (let ((bg (face-background 'tooltip nil t))
          (fg (face-foreground 'tooltip nil t)))
      (setq heks/hover--frame
            (make-frame `((parent-frame . ,parent)
                          (minibuffer . nil)
                          (visibility . nil)
                          (undecorated . t)
                          (override-redirect . t)
                          (no-accept-focus . t)
                          (no-special-glyphs . t)
                          (z-group . above)
                          (no-focus-on-map . t)
                          (skip-taskbar . t)
                          (no-other-frame . t)
                          (unsplittable . t)
                          (internal-border-width . 6)
                          (child-frame-border-width . 1)
                          (left-fringe . 0) (right-fringe . 0)
                          (menu-bar-lines . 0) (tool-bar-lines . 0)
                          (tab-bar-lines . 0)
                          (vertical-scroll-bars . nil)
                          (horizontal-scroll-bars . nil)
                          (cursor-type . nil)
                          (width . 40) (height . 4)
                          ,@(and bg `((background-color . ,bg)))
                          ,@(and fg `((foreground-color . ,fg))))))
      (let ((edge (or (face-foreground 'shadow nil t) "gray50")))
        (dolist (face '(internal-border child-frame-border))
          (set-face-background face edge heks/hover--frame)))))
  heks/hover--frame)

(defun heks/hover--hide ()
  "Hide the popup."
  ;; A tooltip is a graphic: on a terminal, and in an Emacs built without a
  ;; window system (where `tooltip-hide' calls the `x-hide-tip' that is not
  ;; there), there is none to hide.
  (when (and (eq (heks/hover--backend) 'tooltip)
             (display-graphic-p))
    (tooltip-hide))
  (when (and (frame-live-p heks/hover--frame)
             (frame-visible-p heks/hover--frame))
    (make-frame-invisible heks/hover--frame)))

(defun heks/hover--measure (frame window text max-w max-h)
  "Return the (WIDTH . HEIGHT) in pixels that TEXT needs in WINDOW of FRAME.
The frame is widened to MAX-W first, because a line wraps at the width its
window has: measuring before that would measure one very long line."
  (set-window-buffer window (heks/hover--render text))
  (set-window-dedicated-p window t)
  (set-frame-size frame max-w max-h t)
  (let ((size (window-text-pixel-size window nil nil max-w max-h t)))
    (cons (min max-w (+ (car size) 2))
          (min max-h (cdr size)))))

(defun heks/hover--clean (text)
  "Drop what no popup can use from TEXT: `command:' links and HTML entities.
A server's `[`Name`](command:...)' link is a long URL that does nothing
here, so only its label stays."
  (let ((s (replace-regexp-in-string
            "\\[\\([^]\n]*\\)\\]([a-z]+:[^)\n]*)" "\\1" text)))
    (dolist (e '(("&ndash;" . "–") ("&mdash;" . "—") ("&amp;" . "&")
                 ("&lt;" . "<") ("&gt;" . ">") ("&nbsp;" . " ")
                 ("&quot;" . "\"")))
      (setq s (string-replace (car e) (cdr e) s)))
    s))

(defun heks/hover--plain (text)
  "Return TEXT as readable plain text, wrapped, for the native tooltip.
Fences, rules, emphasis and code ticks go; long prose lines are wrapped at
`heks/hover-max-width' and long signatures are broken at their parameters."
  (let ((in nil) (out '()))
    (dolist (line (split-string (substring-no-properties text) "\n"))
      (cond
       ((string-match-p "\\`[ \t]*```" line) (setq in (not in)))
       (in (push (heks/hover--break-signature line) out))
       ((string-match-p "\\`[ \t]*\\(?:---+\\|\\*\\*\\*+\\)[ \t]*\\'" line)
        (push "" out))
       (t
        (let ((l (replace-regexp-in-string
                  "\\*\\*\\([^*\n]+\\)\\*\\*" "\\1"
                  (replace-regexp-in-string "`\\([^`\n]+\\)`" "\\1" line))))
          (push (if (> (length l) heks/hover-max-width)
                    (with-temp-buffer
                      (insert l)
                      (let ((fill-column heks/hover-max-width))
                        (fill-region (point-min) (point-max)))
                      (buffer-string))
                  l)
                out)))))
    (string-trim
     (replace-regexp-in-string "\n\\{3,\\}" "\n\n"
                               (string-join (nreverse out) "\n")))))

(defun heks/hover--show (text)
  "Show TEXT in a popup just below the mouse pointer, per the backend."
  (if (eq (heks/hover--backend) 'tooltip)
      (let ((tooltip-hide-delay 30))
        (tooltip-show (heks/hover--plain text)))
    (heks/hover--show-frame text)))

(defun heks/hover--show-frame (text)
  "Show TEXT in a bounded child frame just below the mouse pointer."
  (let* ((parent (selected-frame))
         (pointer (cdr (mouse-pixel-position)))
         (frame (heks/hover--ensure-frame parent))
         (window (frame-root-window frame))
         (char-w (frame-char-width parent))
         (char-h (frame-char-height parent))
         (max-w (min (* heks/hover-max-width char-w)
                     (floor (* 0.5 (frame-pixel-width parent)))))
         (max-h (min (* heks/hover-max-height char-h)
                     (floor (* 0.4 (frame-pixel-height parent)))))
         ;; The same words in the same frame do not have to be laid out again.
         (known (and (equal text (car-safe heks/hover--shown))
                     (cdr heks/hover--shown)))
         (size (or known (heks/hover--measure frame window text max-w max-h)))
         (border (* 2 (+ 6 1)))
         (fw (+ (car size) border))
         (fh (+ (cdr size) border))
         (x (if pointer (car pointer) 0))
         (y (if pointer (cdr pointer) 0))
         (left (max 0 (min x (- (frame-pixel-width parent) fw))))
         ;; Below the pointer, unless there is no room, then above it.
         (top (if (<= (+ y 24 fh) (frame-pixel-height parent))
                  (+ y 24)
                (max 0 (- y fh 8)))))
    (unless known
      (setq heks/hover--shown (cons text size)))
    (set-frame-size frame (car size) (cdr size) t)
    (set-frame-position frame left top)
    (make-frame-visible frame)))


;;
;; ====== Following the mouse ======
;;

;; A repeating timer looks at where the pointer is.  When it has rested on a
;; new symbol for `heks/hover-delay' seconds, the documentation is asked
;; for -- asynchronously -- and the popup is drawn when it arrives, provided
;; the pointer is still on that symbol.  The timer runs only while some
;; buffer has `heks/hover-mode' on.

(defcustom heks/hover-delay 0.3
  "Seconds the mouse must rest on a symbol before documentation is asked for.
Short enough that the popup feels like it follows the pointer rather than
trailing it, long enough that crossing a line of names asks for nothing."
  :type 'number
  :group 'heks/hover)

(defvar heks/hover--poll-timer nil)
(defvar heks/hover--dwell-timer nil)
(defvar heks/hover--anchor nil
  "(WINDOW . SYMBOL-START) the pointer is on, for which a popup is wanted.")
(defvar heks/hover--sight nil
  "What the last poll saw: the pointer, the window and where it starts.
While this is unchanged, nothing is asked of `posn-at-x-y', of the symbol at
point or of a server: a pointer that has not moved is over the same symbol
unless the window beneath it scrolled.")

(defun heks/hover--target ()
  "Return (WINDOW . POS) for the hoverable symbol under the pointer, or nil."
  (pcase (mouse-pixel-position)
    (`(,frame ,x . ,y)
     (when (and (framep frame) x y (display-graphic-p frame)
                (not (eq frame heks/hover--frame)))
       (let* ((posn (posn-at-x-y x y frame))
              (window (and posn (posn-window posn)))
              (pos (and posn (null (posn-area posn)) (posn-point posn))))
         (when (and (windowp window) (window-live-p window) (integerp pos)
                    (not (window-minibuffer-p window))
                    (buffer-local-value 'heks/hover-mode (window-buffer window)))
           (with-current-buffer (window-buffer window)
             (let ((char (char-after pos)))
               (when (and char (memq (char-syntax char) '(?w ?_)))
                 (let ((bounds (save-excursion
                                 (goto-char pos)
                                 (bounds-of-thing-at-point 'symbol))))
                   (and bounds (cons window (car bounds)))))))))))))

(defun heks/hover--cancel-dwell ()
  (when (timerp heks/hover--dwell-timer)
    (cancel-timer heks/hover--dwell-timer))
  (setq heks/hover--dwell-timer nil))

(defun heks/hover--deliver (anchor text)
  "Show TEXT if the pointer is still on ANCHOR."
  (when (and text (equal anchor heks/hover--anchor)
             (equal anchor (heks/hover--target)))
    (heks/hover--show (heks/hover--truncate (heks/hover--clean text)))))

(defun heks/hover--ask (anchor)
  "Start the asynchronous request for ANCHOR, a (WINDOW . POS)."
  (setq heks/hover--dwell-timer nil)
  (when (and (equal anchor heks/hover--anchor) (window-live-p (car anchor)))
    (with-current-buffer (window-buffer (car anchor))
      (heks/hover--request
       (cdr anchor)
       (lambda (text) (heks/hover--deliver anchor text))))))

(defun heks/hover--wanted ()
  "Return non-nil while some buffer has `heks/hover-mode' on.
The timer polls for all of them at once, so it is asked this on every tick
and lets go of the poll when the last buffer that wanted a popup is done
with it."
  (cl-some (lambda (buffer) (buffer-local-value 'heks/hover-mode buffer))
           (buffer-list)))

(defun heks/hover--poll ()
  "Notice where the pointer is; cheap, and never waits for anything."
  (if (not (heks/hover--wanted))
      (heks/hover--stop-polling)
    ;; Unfocused frame (workspace switch, another WM-managed window): no popup.
    (cond
     ;; Pointer is on the popup itself (to read or scroll it): leave it alone.
     ((and (frame-live-p heks/hover--frame)
           (frame-visible-p heks/hover--frame)
           (eq (car (mouse-pixel-position)) heks/hover--frame))
      nil)
     ((not (or (frame-focus-state) (frame-focus-state heks/hover--frame)))
        (progn (when heks/hover--anchor
                 (heks/hover--cancel-dwell)
                 (heks/hover--hide)
                 (setq heks/hover--anchor nil heks/hover--sight nil))))
     (t
    (let ((sight (list (mouse-pixel-position)
                       (selected-window)
                       (window-buffer)
                       (window-start)
                       ;; The window the popup belongs to may not be the
                       ;; selected one: it is its own scroll that would move the
                       ;; text out from under a pointer that has not moved.
                       (and (window-live-p (car-safe heks/hover--anchor))
                            (window-start (car heks/hover--anchor))))))
      ;; A pointer that has not moved is over the same symbol, unless the
      ;; window under it moved: most ticks of this timer do nothing at all,
      ;; which is what makes hovering not cost anything while it is idle.
      (unless (equal sight heks/hover--sight)
        (setq heks/hover--sight sight)
        (let ((target (ignore-errors (heks/hover--target))))
          (unless (equal target heks/hover--anchor)
            (heks/hover--cancel-dwell)
            (heks/hover--hide)
            (setq heks/hover--anchor target)
            (when target
              (setq heks/hover--dwell-timer
                    (run-with-timer heks/hover-delay nil
                                    #'heks/hover--ask target)))))))))))

(defun heks/hover--start-polling ()
  (unless (timerp heks/hover--poll-timer)
    (setq heks/hover--poll-timer
          (run-with-timer 0.2 0.1 #'heks/hover--poll))))

(defun heks/hover--stop-polling ()
  (when (timerp heks/hover--poll-timer)
    (cancel-timer heks/hover--poll-timer))
  (setq heks/hover--poll-timer nil
        heks/hover--anchor nil
        heks/hover--sight nil)
  (heks/hover--cancel-dwell)
  (heks/hover--hide))

;;
;; ====== Scrolling and the full text ======
;;

(defun heks/hover--scroll (lines)
  "Scroll the visible popup by LINES (negative is up)."
  (if (and (frame-live-p heks/hover--frame)
           (frame-visible-p heks/hover--frame))
      (with-selected-window (frame-root-window heks/hover--frame)
        (condition-case nil
            (scroll-up lines)
          (end-of-buffer (goto-char (point-min)))
          (beginning-of-buffer nil)))
    (user-error "No hover popup is showing")))

(defun heks/hover-scroll-down ()
  "Scroll the hover popup towards its end, a few lines at a time."
  (interactive)
  (heks/hover--scroll 5))

(defun heks/hover-scroll-up ()
  "Scroll the hover popup back towards its start."
  (interactive)
  (heks/hover--scroll -5))

(defun heks/hover-open ()
  "Show the complete documentation for the symbol at point in a buffer.

Unlike the popup this is not clipped or cut, and it is a normal window:
scroll it, search it, `q' closes it."
  (interactive)
  (heks/hover--hide)
  (message "Asking for documentation…")
  (heks/hover--request
   (point)
   (lambda (doc)
     (if (not doc)
         (message "Nothing to say about the symbol at point")
       (with-current-buffer (get-buffer-create "*heks-hover-doc*")
         (let ((inhibit-read-only t))
           (erase-buffer)
           (insert doc)
           (when (and (not (text-property-not-all (point-min) (point-max)
                                                  'face nil))
                      (fboundp 'gfm-view-mode))
             (delay-mode-hooks (gfm-view-mode))
             (font-lock-ensure))
           (special-mode)
           (visual-line-mode 1)
           (goto-char (point-min)))
         (display-buffer (current-buffer)))))))

(global-set-key (kbd "C-c i D") #'heks/hover-open)
(global-set-key (kbd "C-c i n") #'heks/hover-scroll-down)
(global-set-key (kbd "C-c i p") #'heks/hover-scroll-up)

;;;###autoload
(define-minor-mode heks/hover-mode
  "Show ElDoc documentation in a popup when the mouse rests on a symbol."
  :lighter nil
  (if heks/hover-mode
      (heks/hover--start-polling)
    (setq heks/hover--anchor nil)
    (heks/hover--hide)))

(defun heks/hover--maybe-enable ()
  "Turn on hover in this buffer when Eglot or Geiser is serving it."
  (when (or (bound-and-true-p eglot--managed-mode)
            (bound-and-true-p geiser-mode))
    (heks/hover-mode 1)))

(defun heks/hover--maybe-disable ()
  "Turn hover off again once neither Eglot nor Geiser serves the buffer."
  (unless (or (bound-and-true-p eglot--managed-mode)
              (bound-and-true-p geiser-mode))
    (heks/hover-mode -1)))

(add-hook 'eglot-managed-mode-hook
          (lambda ()
            (if (bound-and-true-p eglot--managed-mode)
                (heks/hover--maybe-enable)
              (heks/hover--maybe-disable))))
(add-hook 'geiser-mode-hook
          (lambda ()
            (if (bound-and-true-p geiser-mode)
                (heks/hover--maybe-enable)
              (heks/hover--maybe-disable))))

(add-hook 'emacs-lisp-mode-hook #'heks/hover-mode)
(add-hook 'lisp-interaction-mode-hook #'heks/hover-mode)

(global-set-key (kbd "C-c i H") #'heks/hover-mode)

(provide 'heks/dev-hover)

;;; dev-hover.el ends here
