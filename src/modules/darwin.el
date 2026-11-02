;;; darwin.el --- macOS-only settings -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Things that are only true on macOS.  `init.el' loads this module on Darwin
;; and nowhere else, and before the modules in `heks/modules', so whatever it
;; sets up is in place when they look for a program.
;;
;;   * The PATH.  An Emacs started from the Dock or Spotlight does not inherit
;;     the login shell's PATH, so tools installed outside the system's default
;;     directories (sift, guile, ...) are invisible to `executable-find'.  The
;;     user's own shell is asked once, at startup.

;;; Code:

(defun heks/darwin-import-shell-path ()
  "Make `exec-path' and the PATH variable agree with the login shell's PATH."
  (let* ((shell (or (getenv "SHELL") "/bin/zsh"))
         ;; Markers guard against noise printed by interactive rc files.
         (out (with-temp-buffer
                (call-process shell nil t nil "-l" "-i" "-c"
                              "printf '__HEKS_PATH__%s__HEKS_PATH__' \"$PATH\"")
                (buffer-string))))
    (when (string-match "__HEKS_PATH__\\(.*?\\)__HEKS_PATH__" out)
      (let ((path (match-string 1 out)))
        (setenv "PATH" path)
        (setq exec-path (delete-dups
                         (append (split-string path path-separator t)
                                 exec-path)))))))

(ignore-errors (heks/darwin-import-shell-path))

(provide 'heks/darwin)

;;; darwin.el ends here
