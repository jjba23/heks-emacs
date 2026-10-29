;;; dev-hover.el --- Mouse hover documentation for Eglot and Geiser -*- lexical-binding: t -*-

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

(defcustom heks/hover-timeout 0.8
  "Seconds to wait for a language server to answer a hover request."
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

(defvar heks/hover-mode)
(defvar heks/hover--frame nil "The child frame the popup is drawn in.")
(defconst heks/hover--buffer " *heks-hover*")

(defun heks/hover--request (pos callback)
  "Ask ElDoc's functions about POS in the current buffer, without waiting.

CALLBACK is called once, with the answers joined by blank lines (or nil
when there are none), as soon as every function has answered or
`heks/hover-timeout' seconds have passed, whichever is first.  It runs in
the buffer this was called from, if that is still live.  Nothing here
blocks: the functions in `eldoc-documentation-functions' are called with a
callback, exactly as ElDoc does, and the answers arrive whenever the
server or the REPL sends them."
  (let* ((buffer (current-buffer))
         (slots '())
         (finished nil)
         (asked nil)
         (timer nil)
         (finish
          (lambda ()
            (unless finished
              (setq finished t)
              (when (timerp timer) (cancel-timer timer))
              (let* ((docs (delq nil (mapcar #'car (reverse slots))))
                     (text (and docs
                                (string-join (mapcar #'string-trim docs)
                                             "\n\n"))))
                (when (buffer-live-p buffer)
                  (with-current-buffer buffer
                    (funcall callback (and text (not (string-empty-p text))
                                           text)))))))))
    (setq timer (run-with-timer heks/hover-timeout nil finish))
    (save-excursion
      (goto-char pos)
      (dolist (fn eldoc-documentation-functions)
        ;; A slot is (DOC . DONE): the callback fills both.
        (let* ((slot (cons nil nil))
               (result (ignore-errors
                         (funcall fn
                                  (lambda (doc &rest _)
                                    (when (stringp doc) (setcar slot doc))
                                    (setcdr slot t)
                                    ;; Last one in closes the request.
                                    (when (and asked (cl-every #'cdr slots))
                                      (funcall finish)))))))
          ;; Non-nil means "I will call the callback"; nil means there is
          ;; nothing to say here.
          (if result
              (push slot slots)
            (setcdr slot t)))))
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

(defun heks/hover--render (text)
  "Fill the popup buffer with TEXT, rendering it as Markdown if it is raw.

Eglot hands over text that is already rendered (it carries faces); what
Geiser and Elisp give is plain, and is run through `gfm-view-mode' when
that is installed so that code fences and emphasis read properly."
  (with-current-buffer (get-buffer-create heks/hover--buffer)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (kill-all-local-variables)
      (insert (string-trim text))
      (let ((rendered (text-property-not-all (point-min) (point-max) 'face nil)))
        (when (and (not rendered) (fboundp 'gfm-view-mode))
          (delay-mode-hooks (gfm-view-mode))
          (font-lock-ensure)))
      (setq-local mode-line-format nil
                  header-line-format nil
                  cursor-type nil
                  truncate-lines nil
                  word-wrap t
                  line-spacing 0.15
                  left-margin-width 0
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
    (let ((bg (face-background 'tooltip nil t))
          (fg (face-foreground 'tooltip nil t)))
      (setq heks/hover--frame
            (make-frame `((parent-frame . ,parent)
                          (minibuffer . nil)
                          (visibility . nil)
                          (undecorated . t)
                          (no-accept-focus . t)
                          (no-focus-on-map . t)
                          (skip-taskbar . t)
                          (no-other-frame . t)
                          (unsplittable . t)
                          (internal-border-width . 10)
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
      (set-face-background 'internal-border
                           (or (face-foreground 'shadow nil t) "gray50")
                           heks/hover--frame)
      (set-face-background 'child-frame-border
                           (or (face-foreground 'shadow nil t) "gray50")
                           heks/hover--frame)))
  heks/hover--frame)

(defun heks/hover--hide ()
  "Hide the popup."
  (when (and (frame-live-p heks/hover--frame)
             (frame-visible-p heks/hover--frame))
    (make-frame-invisible heks/hover--frame)))

(defun heks/hover--show (text)
  "Show TEXT in a bounded popup just below the mouse pointer."
  (let* ((parent (selected-frame))
         (pointer (cdr (mouse-pixel-position)))
         (frame (heks/hover--ensure-frame parent))
         (window (frame-root-window frame))
         (buffer (heks/hover--render text))
         (char-w (frame-char-width parent))
         (char-h (frame-char-height parent))
         (max-w (min (* heks/hover-max-width char-w)
                     (floor (* 0.5 (frame-pixel-width parent)))))
         (max-h (min (* heks/hover-max-height char-h)
                     (floor (* 0.4 (frame-pixel-height parent))))))
    (set-window-buffer window buffer)
    (set-window-dedicated-p window t)
    ;; Wrap at the maximum width, then shrink to what the text needs.
    (set-frame-size frame max-w max-h t)
    (let* ((size (window-text-pixel-size window nil nil max-w max-h t))
           (w (min max-w (+ (car size) char-w)))
           (h (min max-h (cdr size)))
           (border (* 2 (+ 10 1)))
           (fw (+ w border))
           (fh (+ h border))
           (x (if pointer (car pointer) 0))
           (y (if pointer (cdr pointer) 0))
           (left (max 0 (min x (- (frame-pixel-width parent) fw))))
           ;; Below the pointer, unless there is no room, then above it.
           (top (if (<= (+ y 24 fh) (frame-pixel-height parent))
                    (+ y 24)
                  (max 0 (- y fh 8)))))
      (set-frame-size frame w h t)
      (set-frame-position frame left top)
      (make-frame-visible frame))))


;;
;; ====== Following the mouse ======
;;

;; A repeating timer looks at where the pointer is.  When it has rested on a
;; new symbol for `heks/hover-delay' seconds, the documentation is asked
;; for -- asynchronously -- and the popup is drawn when it arrives, provided
;; the pointer is still on that symbol.  The timer runs only while some
;; buffer has `heks/hover-mode' on.

(defcustom heks/hover-delay 0.4
  "Seconds the mouse must rest on a symbol before documentation is asked for."
  :type 'number
  :group 'heks/hover)

(defvar heks/hover--poll-timer nil)
(defvar heks/hover--dwell-timer nil)
(defvar heks/hover--anchor nil
  "(WINDOW . SYMBOL-START) the pointer is on, for which a popup is wanted.")

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
    (heks/hover--show (heks/hover--truncate text))))

(defun heks/hover--ask (anchor)
  "Start the asynchronous request for ANCHOR, a (WINDOW . POS)."
  (setq heks/hover--dwell-timer nil)
  (when (and (equal anchor heks/hover--anchor) (window-live-p (car anchor)))
    (with-current-buffer (window-buffer (car anchor))
      (heks/hover--request
       (cdr anchor)
       (lambda (text) (heks/hover--deliver anchor text))))))

(defun heks/hover--poll ()
  "Notice where the pointer is; cheap, and never waits for anything."
  (if (not (cl-some (lambda (b) (buffer-local-value 'heks/hover-mode b))
                    (buffer-list)))
      (heks/hover--stop-polling)
    (let ((target (ignore-errors (heks/hover--target))))
      (unless (equal target heks/hover--anchor)
        (heks/hover--cancel-dwell)
        (heks/hover--hide)
        (setq heks/hover--anchor target)
        (when target
          (setq heks/hover--dwell-timer
                (run-with-timer heks/hover-delay nil
                                #'heks/hover--ask target)))))))

(defun heks/hover--start-polling ()
  (unless (timerp heks/hover--poll-timer)
    (setq heks/hover--poll-timer
          (run-with-timer 0.2 0.1 #'heks/hover--poll))))

(defun heks/hover--stop-polling ()
  (when (timerp heks/hover--poll-timer)
    (cancel-timer heks/hover--poll-timer))
  (setq heks/hover--poll-timer nil
        heks/hover--anchor nil)
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
