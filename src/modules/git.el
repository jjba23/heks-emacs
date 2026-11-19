;;; git.el --- Git configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Git configuration for Emacs

;;; Code:

;; `magit-popup' is Magit's pre-Transient menu library.  Nothing here needs
;; it, and a stale copy left in an Elpaca tree clashes with current Magit
;; and Transient.  Remove it, wherever this config runs, and forget it.
(defun heks/git-purge-magit-popup ()
  "Delete stale `magit-popup' build and source dirs, and unload the feature."
  (when (featurep 'elpaca)
    (dolist (dir (list (and (boundp 'elpaca-builds-directory) elpaca-builds-directory)
                       (and (boundp 'elpaca-repos-directory) elpaca-repos-directory)))
      (let ((target (and dir (expand-file-name "magit-popup" dir))))
        (when (and target (file-directory-p target))
          (ignore-errors (delete-directory target t))
          (message "heks-emacs: removed stale %s" target)))))
  (setq load-path (seq-remove (lambda (p) (string-match-p "/magit-popup/?\\'" p))
                              load-path))
  (when (featurep 'magit-popup)
    (ignore-errors (unload-feature 'magit-popup t))))

(heks/git-purge-magit-popup)

(use-package magit
  :ensure t
  :after (transient compat)
  :custom
  ;; Show word-level changes in the selected hunk.
  (magit-diff-refine-hunk t)
  ;; Open the status buffer in the current window.
  (magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1)
  ;; Don't ask before saving buffers in the repo.
  (magit-save-repository-buffers 'dontask)
  :config
  ;; Sign off every commit by default; `-s' in the commit menu still toggles it.
  (setf (alist-get 'magit-commit transient-values) '("--signoff")))

;; `delta' draws the diff, and the mode has nothing to show without the
;; program, so it is only turned on where it is installed.
(use-package magit-delta
  :ensure t
  :defer t)

(when (executable-find "delta")
  (add-hook 'magit-mode-hook #'magit-delta-mode))

;; Conflicts, IntelliJ style: ours | merged result | theirs in one frame, with
;; the common ancestor available.  `magit-ediff-resolve-all' (`e' on a
;; conflicted file in the status buffer) opens that three-way view, and
;; `smerge-mode' turns on by itself in any buffer that holds conflict markers.
(use-package ediff
  :ensure nil
  :custom
  ;; A control panel in the same frame, not a floating one.
  (ediff-window-setup-function #'ediff-setup-windows-plain)
  ;; Panes side by side, as in a merge dialog.
  (ediff-split-window-function #'split-window-horizontally)
  ;; Highlight the changed words inside a difference, not only the lines.
  (ediff-auto-refine 'on))

(defun heks/git-smerge-maybe ()
  "Enable `smerge-mode' when the buffer has conflict markers."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward "^<<<<<<< " nil t)
      (smerge-mode 1))))

(add-hook 'find-file-hook #'heks/git-smerge-maybe)

(require 'smerge-mode)
;; Not `(require 'transient)' at load: that loads Emacs' own copy before Elpaca
;; activates its build ("transient loaded before Elpaca activation").  The menu
;; is defined when transient loads, and `smerge-mode-hook' loads it on demand.
(when (bound-and-true-p byte-compile-current-file)
  (require 'transient nil t))
(add-hook 'smerge-mode-hook (lambda () (require 'transient nil t)))

(with-eval-after-load 'transient
 (transient-define-prefix heks/smerge-menu ()
  "Resolve the conflict at point; navigation keeps the menu open."
  [:description
   (lambda () (format "Conflict %s" (if (bound-and-true-p smerge-mode) "" "(smerge off)")))
   ["Keep"
    ("u" "ours (upper)" smerge-keep-upper :transient t)
    ("l" "theirs (lower)" smerge-keep-lower :transient t)
    ("b" "base" smerge-keep-base :transient t)
    ("a" "both" smerge-keep-all :transient t)
    ("RET" "side under point" smerge-keep-current :transient t)]
   ["Go"
    ("n" "next" smerge-next :transient t)
    ("p" "previous" smerge-prev :transient t)
    ("r" "refine words" smerge-refine :transient t)]
   ["Compare"
    ("E" "ediff three-way" smerge-ediff)
    ("=" "ours vs theirs" smerge-diff-upper-lower)
    ("d" "base vs ours" smerge-diff-base-upper)
    ("D" "base vs theirs" smerge-diff-base-lower)]
   ["Whole file"
    ("U" "all ours" heks/smerge-all-ours :transient t)
    ("L" "all theirs" heks/smerge-all-theirs :transient t)
    ("F" "finish: save and stage" heks/smerge-finish)]]))

;; VSCode-style CodeLens above each conflict and an IntelliJ-style counter in
;; the header line, both clickable.

(defun heks/smerge-count ()
  "Number of conflicts still in the buffer."
  (save-excursion
    (goto-char (point-min))
    (let ((n 0))
      (while (re-search-forward "^<<<<<<< " nil t) (setq n (1+ n)))
      n)))

(defun heks/smerge--all (fn)
  "Resolve every conflict in the buffer with FN."
  (save-excursion
    (goto-char (point-min))
    (while (smerge-find-conflict) (funcall fn))))

(defun heks/smerge-all-ours () "Keep ours everywhere." (interactive) (heks/smerge--all #'smerge-keep-upper))
(defun heks/smerge-all-theirs () "Keep theirs everywhere." (interactive) (heks/smerge--all #'smerge-keep-lower))

(defun heks/smerge-finish ()
  "Save the buffer, leave `smerge-mode' and stage the file when Magit is here."
  (interactive)
  (unless (zerop (heks/smerge-count))
    (user-error "%d conflict(s) remain" (heks/smerge-count)))
  (save-buffer)
  (smerge-mode -1)
  (when (and (fboundp 'magit-stage-file) buffer-file-name)
    (magit-stage-file buffer-file-name))
  (message "Merge of %s complete" (file-name-nondirectory (or buffer-file-name ""))))

(defun heks/smerge--button (label help action)
  "A clickable LABEL showing HELP that runs ACTION on mouse-1 or RET."
  (let ((map (make-sparse-keymap)))
    (define-key map [mouse-1] action)
    (define-key map (kbd "RET") action)
    (propertize label 'face 'link 'mouse-face 'highlight
                'help-echo help 'keymap map)))

(defun heks/smerge--at (marker fn)
  "Command that moves to MARKER, then calls FN."
  (lambda () (interactive) (goto-char marker) (funcall fn)))

(defun heks/smerge-lens-refresh ()
  "Redraw the clickable action line above every conflict."
  (remove-overlays (point-min) (point-max) 'heks-lens t)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "^<<<<<<< " nil t)
      (let* ((m (copy-marker (line-beginning-position)))
             (ov (make-overlay m (line-end-position)))
             (sep (propertize " | " 'face 'shadow)))
        (overlay-put ov 'heks-lens t)
        (overlay-put
         ov 'before-string
         (concat
          (heks/smerge--button "Accept Ours" "Keep the upper (HEAD) side" (heks/smerge--at m #'smerge-keep-upper))
          sep
          (heks/smerge--button "Accept Theirs" "Keep the lower (incoming) side" (heks/smerge--at m #'smerge-keep-lower))
          sep
          (heks/smerge--button "Accept Both" "Keep both sides" (heks/smerge--at m #'smerge-keep-all))
          sep
          (heks/smerge--button "Compare" "Three-way ediff" (heks/smerge--at m #'smerge-ediff))
          sep
          (heks/smerge--button "More…" "Conflict menu" (heks/smerge--at m #'heks/smerge-menu))
          "\n"))))))

(defun heks/smerge-header ()
  "Header line: remaining conflicts with navigation and finish buttons."
  (let ((n (heks/smerge-count)))
    (concat
     (propertize (if (zerop n) " ✔ All conflicts resolved " (format " ⚠ %d conflict%s left " n (if (= n 1) "" "s")))
                 'face (if (zerop n) 'success 'warning))
     (heks/smerge--button "[Prev]" "Previous conflict" #'smerge-prev) " "
     (heks/smerge--button "[Next]" "Next conflict" #'smerge-next) " "
     (heks/smerge--button "[Menu]" "Conflict menu" #'heks/smerge-menu) " "
     (and (zerop n) (heks/smerge--button "[Finish]" "Save and stage" #'heks/smerge-finish)))))

(defvar-local heks/smerge--tick nil)

(defun heks/smerge-post-command ()
  "Refresh lenses when the text changed."
  (unless (eq heks/smerge--tick (buffer-chars-modified-tick))
    (setq heks/smerge--tick (buffer-chars-modified-tick))
    (heks/smerge-lens-refresh)
    (force-mode-line-update)))

(defun heks/smerge-decorate ()
  "Turn the lenses and header line on or off with `smerge-mode'."
  (cond
   (smerge-mode
    (setq-local header-line-format '(:eval (heks/smerge-header)))
    (add-hook 'post-command-hook #'heks/smerge-post-command nil t)
    (heks/smerge-lens-refresh))
   (t
    (kill-local-variable 'header-line-format)
    (remove-hook 'post-command-hook #'heks/smerge-post-command t)
    (remove-overlays (point-min) (point-max) 'heks-lens t))))

(add-hook 'smerge-mode-hook #'heks/smerge-decorate)

(defun heks/smerge-menu-at-mouse (event)
  "Move point to the click at EVENT and open `heks/smerge-menu'."
  (interactive "e")
  (mouse-set-point event)
  (heks/smerge-menu))

(with-eval-after-load 'smerge-mode
  (setq smerge-refine-ignore-whitespace nil)
  ;; Colour by meaning, from the theme's diff faces: ours green, theirs red,
  ;; the ancestor neutral, the marker lines dim so the code stands out.
  (set-face-attribute 'smerge-upper nil :inherit 'diff-added :extend t)
  (set-face-attribute 'smerge-lower nil :inherit 'diff-removed :extend t)
  (set-face-attribute 'smerge-base nil :inherit 'diff-changed :extend t)
  (set-face-attribute 'smerge-markers nil :inherit 'shadow :weight 'bold :extend t)
  ;; `C-c ^ ?' or a right click opens the menu; `C-c ^ E' runs ediff.
  (define-key smerge-basic-map (kbd "?") #'heks/smerge-menu)
  (define-key smerge-mode-map [mouse-3] #'heks/smerge-menu-at-mouse))

;; Ediff: stronger current-difference colours and word refinement.
(with-eval-after-load 'ediff-init
  (set-face-attribute 'ediff-current-diff-A nil :inherit 'diff-removed :extend t)
  (set-face-attribute 'ediff-current-diff-B nil :inherit 'diff-added :extend t)
  (set-face-attribute 'ediff-current-diff-C nil :inherit 'diff-changed :extend t)
  (set-face-attribute 'ediff-fine-diff-A nil :inherit 'diff-refine-removed)
  (set-face-attribute 'ediff-fine-diff-B nil :inherit 'diff-refine-added)
  (set-face-attribute 'ediff-fine-diff-C nil :inherit 'diff-refine-changed))

;; Keep the common ancestor in the file, so the three-way view and `smerge'
;; can show what both sides changed from.  Applies to this Emacs's git calls.
(with-eval-after-load 'magit
  (setq magit-git-global-arguments
        (append magit-git-global-arguments '("-c" "merge.conflictStyle=diff3"))))

(use-package git-riddance
  :ensure (:host codeberg :repo "jjba23/git-riddance.el" :branch "trunk"))

(use-package git-modes
  :ensure t)

(use-package git-link
  :ensure t)

(provide 'heks/git)

;;; git.el ends here
