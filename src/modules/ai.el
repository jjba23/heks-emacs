;;; ai.el --- AI configuration for Emacs -*- lexical-binding: t -*-

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

;; AI configuration for Emacs

;;; Code:

(use-package gptel
  :ensure t
  :after (f)
  :config
  (setq
   gptel-model 'gemini-pro
   gptel-backend (gptel-make-gemini "Gemini"
                   :key (lambda() (f-read-text "~/.secrets/gemini"))
                   :stream t)))

;; Provides an interactive AI coding assistant within Emacs.
(use-package eca
  :ensure t)

(provide 'heks-emacs/ai)

;;; ai.el ends here
