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

(with-eval-after-load 'smerge-mode
  ;; Word-level highlight of what differs inside a conflict, like delta does
  ;; for diffs.  `C-c ^ E' runs ediff on the conflict at point.
  (setq smerge-refine-ignore-whitespace nil))

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
