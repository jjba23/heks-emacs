;;; batch-indent.el --- Custom Emacs configuration for heks-emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; TODO

;;; Code:

(defun indent-file (&optional save)
  "Format the whole buffer."
  ;; (setq indent-tabs-mode nil)
  (indent-region (point-min) (point-max) nil)
  (untabify (point-min) (point-max))
  (delete-trailing-whitespace)
  (when save
    (save-buffer))
  ;; (princ (buffer-string))
  )

(defun indent-and-save ()
  "Indent the file named on the command line and save it (batch entry point)."
  (indent-file t))

;;; batch-indent.el ends here
