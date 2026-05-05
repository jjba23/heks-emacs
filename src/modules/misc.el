;;; misc.el --- Misc configuration for Emacs -*- lexical-binding: t -*-

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

(provide 'heks-emacs/misc)

;;; misc.el ends here
