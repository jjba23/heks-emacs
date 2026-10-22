;;; org.el --- Org configuration for Emacs -*- lexical-binding: t -*-

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

;; Org configuration for Emacs

;;; Code:

(use-package org
  :ensure nil
  :hook ((org-mode . heks-emacs-org-mode))
  :bind (:map org-mode-map
              ;; Org binds `C-c #' to statistics cookies, which is where
              ;; the global `C-c #' system keys used to disappear: in an
              ;; Org buffer, three of them did nothing.  The command moves
              ;; one key over, to `C-c C-#', and the prefix is free again.
              ("C-c #" . nil)
              ("C-c C-#" . org-update-statistics-cookies))
  ;; Toggling how links read is a view action on a note, so it lives
  ;; under the notes topic with roam; the agenda is the other half of a
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
  (org-startup-with-inline-images t)
  (org-table-convert-region-max-lines 9999)
  :config
  (defun heks-emacs-org-mode ()
    (variable-pitch-mode 1)
    (org-indent-mode)
    (auto-fill-mode 0)
    (org-restart-font-lock)
    (font-lock-add-keywords
     nil
     '(("^-\\{5,\\}"  0 '(:inherit font-lock-comment-face))))
    ;; Only the prose faces are re-applied here: calling the full
    ;; `heks-emacs-set-base-faces' would reset the global text scale
    ;; (C-= / C--) every time an Org buffer is opened.
    (ignore-errors (heks-emacs-set-org-faces))
    (heks-emacs-org-fold-indicators-mode 1)))

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

(define-fringe-bitmap 'heks-emacs-fold-open
  [#b00000000 #b01111110 #b00111100 #b00011000 #b00000000] nil nil 'center)
(define-fringe-bitmap 'heks-emacs-fold-closed
  [#b01100000 #b01111000 #b01111110 #b01111000 #b01100000] nil nil 'center)

(defvar heks-emacs-org-fold-indicator-map
  (let ((map (make-sparse-keymap)))
    (define-key map [left-fringe mouse-1] #'heks-emacs-org-fold-indicator-click)
    (define-key map [right-fringe mouse-1] #'heks-emacs-org-fold-indicator-click)
    map)
  "The keymap of a fold indicator: a click toggles the heading.")

;; A click in the fringe is looked up in the buffer's keymaps, not in the
;; `keymap' property of the string that draws the marker, so the binding
;; has to be in Org's own map as well.
(with-eval-after-load 'org
  (define-key org-mode-map [left-fringe mouse-1]
              #'heks-emacs-org-fold-indicator-click))

(defvar-local heks-emacs-org-fold-indicator-timer nil
  "The idle timer that will redraw this buffer's fold indicators.")

(defun heks-emacs-org-fold-indicator-click (event)
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

(defun heks-emacs-org-fold-indicators-refresh (buffer)
  "Redraw the fold indicators of Org BUFFER."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq heks-emacs-org-fold-indicator-timer nil)
      (remove-overlays (point-min) (point-max) 'heks-emacs-fold-indicator t)
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (while (re-search-forward org-outline-regexp-bol nil t)
            (let* ((bol (line-beginning-position))
                   (eol (line-end-position))
                   (folded (org-fold-folded-p eol))
                   (has-body (save-excursion
                               (goto-char bol)
                               (org-end-of-subtree t t)
                               (> (point) (1+ eol)))))
              (when (or folded has-body)
                ;; Not empty, and not `evaporate': an empty overlay with
                ;; that property is deleted the moment it is made, which
                ;; left the buffer with no indicators at all.
                (let ((overlay (make-overlay bol (1+ bol) nil t))
                      (bitmap (if folded
                                  'heks-emacs-fold-closed
                                'heks-emacs-fold-open)))
                  (overlay-put overlay 'heks-emacs-fold-indicator t)
                  (overlay-put
                   overlay 'before-string
                   (propertize " " 'display `(left-fringe ,bitmap shadow)
                               'keymap heks-emacs-org-fold-indicator-map)))))
            (forward-line 1)))))))

(defun heks-emacs-org-fold-indicators-schedule ()
  "Redraw the fold indicators once Emacs is idle."
  (unless heks-emacs-org-fold-indicator-timer
    (setq heks-emacs-org-fold-indicator-timer
          (run-with-idle-timer 0.2 nil
                               #'heks-emacs-org-fold-indicators-refresh
                               (current-buffer)))))

(define-minor-mode heks-emacs-org-fold-indicators-mode
  "Show a fringe marker on each Org heading that can be folded."
  :lighter nil
  (if heks-emacs-org-fold-indicators-mode
      (progn
        (add-hook 'post-command-hook
                  #'heks-emacs-org-fold-indicators-schedule nil t)
        (heks-emacs-org-fold-indicators-schedule))
    (remove-hook 'post-command-hook
                 #'heks-emacs-org-fold-indicators-schedule t)
    (when (timerp heks-emacs-org-fold-indicator-timer)
      (cancel-timer heks-emacs-org-fold-indicator-timer))
    (setq heks-emacs-org-fold-indicator-timer nil)
    (remove-overlays (point-min) (point-max) 'heks-emacs-fold-indicator t)))

(use-package org-roam-ui
  :ensure t
  :after (org-roam)
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

;; `org-present' is not declared here: it is declared -- and therefore
;; queued for installation, hooked and bound -- by `present.el', which is
;; the module that presents things.  A package queued twice is a package
;; elpaca answers with a warning rather than a queued item, and that answer
;; used to stop the configuration while it loaded.

(use-package org-auto-tangle
  :ensure t
  :after (org)
  :hook ((org-mode . org-auto-tangle-mode)))

(use-package org-roam
  :ensure t
  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n g" . org-roam-graph)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n c" . org-roam-capture)
         ("C-c n d" . org-roam-dailies-goto-today)
         ("C-c n j" . org-roam-dailies-capture-today))
  :init
  ;; Where the notes are is this user's own business -- no default can know
  ;; it -- so it is read from `heks-emacs-notes-roam-dir', which the bridge
  ;; next to the installed configuration sets.  A module is loaded after the
  ;; settings it reads, so by the time this runs the directory is either a
  ;; directory or nobody has said where the notes go; in that second case
  ;; org-roam is loaded but not started, and the variable to set is named
  ;; rather than a path quietly built out of a nil.
  (let ((directory (heks-emacs-notes-roam-directory)))
    (if directory
        (setq org-roam-directory directory
              org-roam-v2-ack t
              org-roam-node-display-template
              (concat "${title:*} " (propertize "${tags:10}" 'face 'org-tag)))
      (message "heks-emacs: org-roam starts when `heks-emacs-notes-roam-dir' names a directory")))
  :config
  (when org-roam-directory
    (org-roam-db-autosync-mode)
    (org-roam-setup)))

(use-package ob-http :ensure t)

(use-package ob-mermaid :ensure t)

;; (use-package org-remoteimg
;;   :ensure (:host github :repo "jjba23/org-remoteimg")
;;   :config
;;   (setq org-display-remote-inline-images 'cache)
;;   (defvaralias 'org-link-preview-overlays 'org-inline-image-overlays))

(provide 'heks-emacs/org)

;;; org.el ends here
