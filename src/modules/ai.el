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
   gptel-backend (gptel-make-gh-copilot "Copilot")
   gptel-model 'claude-sonnet-5.5))

;; Provides an interactive AI coding assistant within Emacs.
(use-package eca
  :ensure t
  :custom
  (eca-chat-default-model "github-copilot/claude-sonnet-5.5")
  :bind (("C-c x t" . eca-chat-toggle-window)
         ("C-c x n" . eca-chat-new)
         ("C-c x s" . eca-chat-select)
         ("C-c x a" . eca-chat-add-context-to-user-prompt)
         ("C-c x k" . eca-chat-stop-prompt)
         ("C-c x m" . eca-chat-select-model)))

(provide 'heks-emacs/ai)

;;; ai.el ends here
