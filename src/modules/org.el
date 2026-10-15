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
  ;; under the notes topic with roam.
  :bind (("C-c n v" . org-toggle-link-display))
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
    (ignore-errors (heks-emacs-set-org-faces))))

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
