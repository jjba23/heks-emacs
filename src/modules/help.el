;;; help.el --- Help configuration for Emacs -*- lexical-binding: t -*-

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

;; Help configuration for Emacs

;;; Code:

(use-package helpful
  :ensure t
  ;; Documentation is a topic of its own, so that "what does this do?" is
  ;; one key in every buffer -- the IntelliJ instinct of reaching for the
  ;; documentation without leaving point.  `C-c C-d' used to do this, and
  ;; the Mermaid buffers need that key for their own commands.
  :bind (("C-h f" . helpful-callable)
         ("C-h v" . helpful-variable)
         ("C-h k" . helpful-key)
         ("C-c h h" . helpful-at-point)
         ("C-c h f" . helpful-callable)
         ("C-c h v" . helpful-variable)
         ("C-c h k" . helpful-key)
         ("C-h F" . helpful-function)
         ("C-h C" . helpful-command)))

(provide 'heks-emacs/help)

;;; help.el ends here
