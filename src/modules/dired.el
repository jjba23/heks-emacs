;;; dired.el --- Dired configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Dired configuration for Emacs

;;; Code:

(use-package dired-hacks-utils :ensure t)

(use-package dired-subtree
  :ensure t
  :hook ((dired-subtree-after-insert . nerd-icons-dired--refresh))
  :config
  ;; `dired-subtree' only defines faces for depths 1-6
  ;; (`dired-subtree-depth-1-face' .. `-6-face', each its own independent
  ;; `defface', with no shared parent face to inherit from); past depth 6
  ;; it keeps asking for `dired-subtree-depth-7-face',
  ;; `dired-subtree-depth-10-face' and so on by the same naming scheme,
  ;; which were never defined -- "Invalid face reference" follows from any
  ;; subtree nested deeper than six levels.  There is no bound on how deep
  ;; a listing can go, so the fix defines the missing faces up to whatever
  ;; depth is reached rather than hardcoding how many, cycling back through
  ;; the six the package already ships so a depth-7 subtree looks like a
  ;; depth-1 one, depth-8 like depth-2, and so on.
  (dotimes (i 30)
    (let* ((depth (1+ i))
           (face (intern (format "dired-subtree-depth-%d-face" depth))))
      (unless (facep face)
        (let ((base (intern (format "dired-subtree-depth-%d-face"
                                     (1+ (mod (1- depth) 6))))))
          (eval `(defface ,face '((t :inherit ,base)) "") t)))
      (set-face-attribute face nil :background 'unspecified)))
  :bind (:map dired-mode-map (("<mouse-1>" . dired-subtree-toggle)
                              ("<TAB>" . dired-subtree-toggle)
                              ("C-<tab>" . dired-subtree-toggle)
                              ("C-<TAB>" . dired-subtree-toggle))))

(use-package dired-open-with :ensure t)

(use-package nerd-icons-dired
  :ensure t
  :hook ((dired-mode . nerd-icons-dired-mode)))

(provide 'heks/dired)

;;; dired.el ends here
