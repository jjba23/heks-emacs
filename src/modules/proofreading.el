;;; proofreading.el --- Proof-reading configuration for Emacs -*- lexical-binding: t -*-

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

;; Proof-reading configuration for Emacs

;;; Code:

;; Jinx is a fast just-in-time spell-checker for Emacs.
(use-package jinx
  :ensure t
  :demand t
  :bind (("M-$" . jinx-correct)
         ([remap ispell-word] . #'jinx-correct)
         ("C-c t $" . jinx-mode)
         ("C-M-$" . jinx-languages))
  :init
  (setq jinx-languages "en_US nl_NL"))

;; you could enable Jinx mode automatically for certain modes like this:
;; :config
;; (dolist (hook '(text-mode-hook
;;                 prog-mode-hook
;;                 conf-mode-hook
;;                 org-mode-hook
;;                 markdown-mode-hook))
;;   (add-hook hook #'jinx-mode))

(provide 'heks/proofreading)

;;; proofreading.el ends here
