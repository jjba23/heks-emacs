;;; search.el --- Search configuration for Emacs -*- lexical-binding: t -*-

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

;; Search configuration for Emacs

;;; Code:

(use-package ripgrep
  :ensure t)

(use-package deadgrep
  :ensure t
  ;; A project-wide search is a workspace action, so it lives with the
  ;; other `C-c w' keys instead of under a `C-c z' that meant nothing.
  :bind (("C-c w g" . deadgrep)))

;; A search is a list of lines to change, not a list of lines to look at:
;; this hands the grep buffer back as an editable one, and writing it out
;; makes the change in the files it names.  It needs no key of its own --
;; it is `C-c C-p' in every grep and `deadgrep' buffer, which is where the
;; hand already is.
(use-package wgrep
  :ensure t
  :config
  (setq wgrep-auto-save-buffer t
        wgrep-change-readonly-file t))

;; A place on the screen, jumped to by a letter: the one motion that needs
;; no name for what it is jumping to.  It is under the same topic as the
;; region that grows and the symbol that lights up, because all three are
;; about what is at point rather than about a file or a project.
(use-package avy
  :ensure t
  :bind (("C-c z j" . avy-goto-char-timer)
         ("C-c z J" . avy-goto-line))
  :config
  (setq avy-timeout-seconds 0.35
        avy-all-windows t
        avy-background t))


(provide 'heks-emacs/search)

;;; search.el ends here
