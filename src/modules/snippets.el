;;; snippets.el --- Snippets configuration for Emacs -*- lexical-binding: t -*-

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

;; Snippets configuration for Emacs

;;; Code:

(use-package tempel
  "Tempel is a tiny template package for Emacs, which uses the syntax of the Emacs Tempo library."
  :ensure (:host github :repo "minad/tempel" :branch "main")
  :bind (("C-c s c" . tempel-complete)
         ("C-c s i" . tempel-insert)
         ("C-c s x" . tempel-expand))
  :init
  (setopt tempel-path '("~/.emacs.d/snippets/*.eld")))

;;; snippets.el ends here
