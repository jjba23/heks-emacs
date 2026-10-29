;;; misc.el --- Misc configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Misc configuration for Emacs

;;; Code:

(use-package prodigy
  :ensure t)

(use-package dagboek
  :ensure (:host codeberg :repo "jjba23/dagboek.el" :branch "trunk")
  :bind (("C-c ; v" . dagboek-today-entry)
         ("C-c ; g" . dagboek-yesterday-entry))
  :custom
  (dagboek-entry-location "~/hacking/private-notes/diary"))

(use-package speed-type
  :ensure (:host github :repo "dakra/speed-type"))

(use-package guix :ensure t :demand t)

(use-package buffer-to-pdf
  :ensure (:host github :repo "protesilaos/buffer-to-pdf")
  :config
  (setq buffer-to-pdf-directory (expand-file-name "~/")))

(use-package show-font
  :ensure t)


(provide 'heks/misc)

;;; misc.el ends here
