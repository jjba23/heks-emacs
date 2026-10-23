;;; git.el --- Git configuration for Emacs -*- lexical-binding: t -*-

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

;; Git configuration for Emacs

;;; Code:

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
