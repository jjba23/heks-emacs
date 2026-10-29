;;; search.el --- Search configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

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


(provide 'heks/search)

;;; search.el ends here
