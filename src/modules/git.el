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

(use-package git-riddance
  :ensure (:host codeberg :repo "jjba23/git-riddance.el" :branch "trunk"))

(use-package git-modes
  :ensure t)

(use-package git-link
  :ensure t)

(provide 'heks/git)

;;; git.el ends here
