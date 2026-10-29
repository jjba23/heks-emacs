;;; org.el --- Org configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Org configuration for Emacs

;;; Code:

(use-package org
  :ensure nil
  :hook ((org-mode . heks/org-mode))
  :bind (:map org-mode-map
              ;; Org binds `C-c #' to statistics cookies, which is where
              ;; the global `C-c #' system keys used to disappear: in an
              ;; Org buffer, three of them did nothing.  The command moves
              ;; one key over, to `C-c C-#', and the prefix is free again.
              ("C-c #" . nil)
              ("C-c C-#" . org-update-statistics-cookies))
  ;; Toggling how links read is a view action on a note, so it lives
  ;; under the notes topic; the agenda is the other half of a
  ;; system of notes -- the dates and the TODOs of every one of them in a
  ;; single list -- and it is `A' rather than `a' because a note is what
  ;; `C-c n' opens and the agenda is what it opens all of them in.
  :bind (("C-c n v" . org-toggle-link-display)
         ("C-c n A" . org-agenda))
  :custom
  (org-todo-keywords '((sequence "TODO" "WIP" "REVIEWING" "|" "DONE")))
  (org-log-done 'time)
  (org-hide-emphasis-markers t)
  (org-hide-leading-stars t)
  (org-pretty-entities t)
  (org-link-descriptive t)
  (org-src-fontify-natively t)
  (org-src-tab-acts-natively t)
  (org-edit-src-content-indentation 0)
  (org-startup-with-inline-images nil)
  (org-table-convert-region-max-lines 9999)
  ;; Open everything: a note is read, not consulted, and starting folded
  ;; left S-TAB to be pressed through before the file could be read.  It is
  ;; also the cheaper state to start in: `showeverything' is the one value
  ;; that skips the visibility passes -- contents, drawers, blocks, archived
  ;; subtrees -- that walk every heading when the buffer opens.
  (org-startup-folded 'showeverything)
  ;; Don't re-parse the whole file for every cycle/visibility change.
  (org-fold-core-style 'text-properties)
  (org-element-use-cache t)
  :config
  (defun heks/org-mode ()
    (variable-pitch-mode 1)
    (org-indent-mode)
    (auto-fill-mode 0)
    ;; No `org-restart-font-lock' here: it refontified the whole buffer a
    ;; second time on open.  JIT-lock fontifies what is on screen only.
    (font-lock-add-keywords
     nil
     '(("^-\\{5,\\}"  0 '(:inherit font-lock-comment-face))))
    ;; Only the prose faces are re-applied here: calling the full
    ;; `heks/set-base-faces' would reset the global text scale
    ;; (C-= / C--) every time an Org buffer is opened.
    (ignore-errors (heks/set-org-faces))
    (heks/org-fold-indicators-mode 1)))

;; Fold indicators for Org, with nothing but Emacs and Org themselves.
;;
;; Org folds with its own invisible text, so neither `treesit-fold' nor
;; Hideshow nor Outline's buttons can draw a marker for it.  This puts one
;; in the left fringe of every heading that has something under it: a
;; triangle pointing down for an open heading and one pointing right for a
;; folded one, and a click on it toggles the heading like `TAB' does.
;; Folding itself is unchanged -- `TAB', `S-TAB' and kirigami's `C-c v' keys
;; work as before -- and whatever folds a heading, the marker follows: it is
;; redrawn once Emacs is idle after a command, rather than from the hooks of
;; one folding command.

(define-fringe-bitmap 'heks/fold-open
  [#b00000000 #b01111110 #b00111100 #b00011000 #b00000000] nil nil 'center)
(define-fringe-bitmap 'heks/fold-closed
  [#b01100000 #b01111000 #b01111110 #b01111000 #b01100000] nil nil 'center)

(defvar heks/org-fold-indicator-map
  (let ((map (make-sparse-keymap)))
    (define-key map [left-fringe mouse-1] #'heks/org-fold-indicator-click)
    (define-key map [right-fringe mouse-1] #'heks/org-fold-indicator-click)
    map)
  "The keymap of a fold indicator: a click toggles the heading.")

;; A click in the fringe is looked up in the buffer's keymaps, not in the
;; `keymap' property of the string that draws the marker, so the binding
;; has to be in Org's own map as well.
(with-eval-after-load 'org
  (define-key org-mode-map [left-fringe mouse-1]
              #'heks/org-fold-indicator-click))

(defvar-local heks/org-fold-indicator-timer nil
  "The idle timer that will redraw this buffer's fold indicators.")

(defvar-local heks/org-fold-indicator-chars-tick nil
  "`buffer-chars-modified-tick' when the indicators were last rebuilt.

Folding changes text properties, not characters, so it leaves this tick
alone; typing changes it.")

(defvar-local heks/org-fold-indicator-complete-p nil
  "Non-nil once this buffer's indicators have been drawn at least once.")

(defvar-local heks/org-fold-indicator-dirty nil
  "The markers around the text changed since the indicators were drawn.

A cons of two markers, or nil when no change is waiting for a redraw.
Markers rather than positions, because more than one edit can arrive
between two redraws and each one moves the region the others left.")

(defun heks/org-fold-indicator-click (event)
  "Toggle the fold of the heading whose indicator EVENT clicked."
  (interactive "e")
  (let* ((posn (event-start event))
         (window (posn-window posn))
         (pos (posn-point posn)))
    (when (and (windowp window) (number-or-marker-p pos))
      (select-window window)
      (goto-char pos)
      (when (org-at-heading-p)
        (org-cycle)))))

(defun heks/org-fold-indicators--draw (overlay folded)
  "Make OVERLAY show a fold marker for FOLDED, if it does not already.

The marker itself is remembered on the overlay, so that a redraw of a
heading whose state has not changed costs one comparison and no string."
  (let ((state (if folded 'heks/fold-closed 'heks/fold-open)))
    (unless (eq (overlay-get overlay 'heks/fold-folded) state)
      (overlay-put overlay 'heks/fold-folded state)
      (overlay-put
       overlay 'before-string
       (propertize " " 'display `(left-fringe ,state shadow)
                   'keymap heks/org-fold-indicator-map)))))

(defun heks/org-fold-indicators--heading ()
  "Give the heading at point its fold indicator, if it needs one."
  (let* ((bol (line-beginning-position))
         (eol (line-end-position))
         (has-body (save-excursion
                     (goto-char eol)
                     (and (< eol (point-max))
                          (progn
                            (forward-line 1)
                            (and (not (eobp))
                                 (or (not (looking-at org-outline-regexp-bol))
                                     (> (org-current-level)
                                        (save-excursion
                                          (goto-char bol)
                                          (org-current-level))))))))))
    ;; A heading with nothing under it cannot be folded, so it gets no
    ;; marker -- whether or not its line is visible at the moment.
    (when has-body
      ;; Not empty, and not `evaporate': an empty overlay with that
      ;; property is deleted the moment it is made, which left the buffer
      ;; with no indicators at all.
      (let ((overlay (make-overlay bol (1+ bol) nil t)))
        (overlay-put overlay 'heks/fold-indicator t)
        (heks/org-fold-indicators--draw
         overlay (org-fold-folded-p eol))))))

(defun heks/org-fold-indicators-rebuild (buffer)
  "Rebuild the fold indicators of Org BUFFER from scratch."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (heks/org-fold-indicators--take-dirty)
      (remove-overlays (point-min) (point-max) 'heks/fold-indicator t)
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (while (re-search-forward org-outline-regexp-bol nil t)
            (heks/org-fold-indicators--heading)
            (forward-line 1)))))))

(defun heks/org-fold-indicators--note-change (beg end &rest _)
  "Remember that BEG..END changed, for the next redraw of the buffer."
  (let ((dirty heks/org-fold-indicator-dirty))
    (if dirty
        (progn
          (set-marker (car dirty)
                      (min (marker-position (car dirty)) beg))
          (set-marker (cdr dirty)
                      (max (marker-position (cdr dirty)) end)))
      (setq heks/org-fold-indicator-dirty
            (cons (copy-marker beg nil)
                  (copy-marker end t))))))

(defun heks/org-fold-indicators--take-dirty ()
  "Return the region changed since the last redraw, and forget it."
  (let ((dirty heks/org-fold-indicator-dirty))
    (when dirty
      (let ((beg (marker-position (car dirty)))
            (end (marker-position (cdr dirty))))
        (set-marker (car dirty) nil)
        (set-marker (cdr dirty) nil)
        (setq heks/org-fold-indicator-dirty nil)
        (when (and beg end)
          (cons beg end))))))

(defun heks/org-fold-indicators--region-start (pos)
  "Return where to start rebuilding for a change at POS.

The heading at or above POS may have gained or lost the first line of
its body; the heading before that one may have lost the child that made
it foldable, so it is included too."
  (save-excursion
    (goto-char (min (point-max) (max (point-min) pos)))
    (beginning-of-line)
    (unless (org-at-heading-p)
      (ignore-errors (org-back-to-heading t)))
    (beginning-of-line)
    (when (re-search-backward org-outline-regexp-bol nil t)
      (beginning-of-line))
    (point)))

(defun heks/org-fold-indicators--region-end (pos)
  "Return where to stop rebuilding for a change at POS.

The line after POS is included: whether a heading has a body is decided
by the first line under it, which is the line a change can have made or
taken away."
  (save-excursion
    (goto-char (min (point-max) (max (point-min) pos)))
    (forward-line 1)
    (line-end-position)))

(defun heks/org-fold-indicators-rebuild-region (beg end)
  "Rebuild the fold indicators that BEG..END can have changed.

Only the headings the change can have touched are visited: the ones in
the region, and the heading before it, whose body may be what was
written or deleted.  The rest of the buffer keeps the markers it has,
which is what makes typing in a large file cost what the line costs
rather than what the file costs."
  (save-excursion
    (let ((from (heks/org-fold-indicators--region-start beg))
          (to (heks/org-fold-indicators--region-end end)))
      (when (< from to)
        (remove-overlays from to 'heks/fold-indicator t)
        (goto-char from)
        (while (and (< (point) to)
                    (re-search-forward org-outline-regexp-bol to t))
          (heks/org-fold-indicators--heading)
          (forward-line 1))))))

(defun heks/org-fold-indicators-refresh (buffer)
  "Redraw the fold indicators of Org BUFFER, doing only what changed.

A redraw is scheduled after every command, but a command usually changes
nothing about the headings: it moves, it scrolls, it edits a line.  Re-
searching the whole buffer and remaking every overlay each time is work
done on every pause, and on a large file it is the difference between a
pause that is not noticed and one that is.  So the text is what decides:

  * it did not change, and neither did the headings, so the indicators
    that are on screen are redrawn and the ones that are not can wait
    until they are;
  * it changed, and the change is remembered, so only the headings that
    change can have made, moved or unmade are rebuilt;
  * it changed, and no change was remembered -- an edit made where the
    change hooks did not see it -- so the buffer is rebuilt.

Folding changes text properties, not characters, so folding alone takes
the first path -- which is why the fold state of a heading is read back
from Org each time rather than remembered from the last rebuild."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq heks/org-fold-indicator-timer nil)
      (let ((chars (buffer-chars-modified-tick)))
        (cond
         ((not heks/org-fold-indicator-complete-p)
          (heks/org-fold-indicators-rebuild buffer))
         ((eq chars heks/org-fold-indicator-chars-tick)
          (heks/org-fold-indicators-redraw))
         (t
          (let ((dirty (heks/org-fold-indicators--take-dirty)))
            (if dirty
                (progn
                  (heks/org-fold-indicators-rebuild-region
                   (car dirty) (cdr dirty))
                  ;; A visibility change may also be waiting -- a fold and
                  ;; a keystroke can arrive before one idle timer -- and
                  ;; the rebuild only went where the text did.
                  (heks/org-fold-indicators-redraw))
              (heks/org-fold-indicators-rebuild buffer)))))
        (setq heks/org-fold-indicator-chars-tick chars
              heks/org-fold-indicator-complete-p t)))))

(defun heks/org-fold-indicators-redraw ()
  "Redraw the indicators of the headings that are on screen.

A heading that is not shown has no marker to correct: when it is scrolled
into view the redraw that follows the command draws it.  A buffer with no
window -- which is what a batch Emacs has -- is redrawn whole, so that
what the timer leaves behind does not depend on there being a frame."
  (let ((windows (get-buffer-window-list (current-buffer) nil t)))
    (if windows
        (dolist (window windows)
          (let ((end (window-end window)))
            (when end
              (heks/org-fold-indicators--redraw-region (window-start window) end))))
      (heks/org-fold-indicators--redraw-region (point-min) (point-max)))))

(defun heks/org-fold-indicators--redraw-region (beg end)
  "Redraw the indicators between BEG and END."
  (dolist (overlay (overlays-in beg end))
    (when (overlay-get overlay 'heks/fold-indicator)
      (heks/org-fold-indicators--draw
       overlay
       (save-excursion
         (goto-char (overlay-start overlay))
         (org-fold-folded-p (line-end-position)))))))

(defun heks/org-fold-indicators-schedule ()
  "Redraw the fold indicators once Emacs is idle."
  (unless heks/org-fold-indicator-timer
    (setq heks/org-fold-indicator-timer
          (run-with-idle-timer 0.2 nil
                               #'heks/org-fold-indicators-refresh
                               (current-buffer)))))

(define-minor-mode heks/org-fold-indicators-mode
  "Show a fringe marker on each Org heading that can be folded."
  :lighter nil
  (if heks/org-fold-indicators-mode
      (progn
        (add-hook 'post-command-hook
                  #'heks/org-fold-indicators-schedule nil t)
        (add-hook 'after-change-functions
                  #'heks/org-fold-indicators--note-change nil t)
        (heks/org-fold-indicators-schedule))
    (remove-hook 'post-command-hook
                 #'heks/org-fold-indicators-schedule t)
    (remove-hook 'after-change-functions
                 #'heks/org-fold-indicators--note-change t)
    (heks/org-fold-indicators--take-dirty)
    (when (timerp heks/org-fold-indicator-timer)
      (cancel-timer heks/org-fold-indicator-timer))
    (setq heks/org-fold-indicator-timer nil
          heks/org-fold-indicator-complete-p nil)
    (remove-overlays (point-min) (point-max) 'heks/fold-indicator t)))

;; `org-present' is not declared here: it is declared -- and therefore
;; queued for installation, hooked and bound -- by `present.el', which is
;; the module that presents things.  A package queued twice is a package
;; elpaca answers with a warning rather than a queued item, and that answer
;; used to stop the configuration while it loaded.

(use-package org-auto-tangle
  :ensure t
  :after (org)
  :hook ((org-mode . org-auto-tangle-mode)))

;; Notes themselves live in `notes.el'.

(use-package ob-http :ensure t)

(use-package ob-mermaid :ensure t)

;; (use-package org-remoteimg
;;   :ensure (:host github :repo "jjba23/org-remoteimg")
;;   :config
;;   (setq org-display-remote-inline-images 'cache)
;;   (defvaralias 'org-link-preview-overlays 'org-inline-image-overlays))

(provide 'heks/org)

;;; org.el ends here
