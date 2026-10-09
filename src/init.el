;;; init.el --- Custom Emacs configuration for heks-emacs -*- lexical-binding: t -*-

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

;;; Code:

;; ====== Package manager ======

;; Install the Elpaca package manager
(defvar elpaca-installer-version 0.12)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-sources-directory (expand-file-name "sources/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1 :inherit ignore
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca-activate)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-sources-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil)) (load "./elpaca-autoloads"))))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

;; Enable integration of use-package with Elpaca
(elpaca elpaca-use-package (elpaca-use-package-mode))

;; ====== Configuration ======

;; Add user Emacs Lisp modules
(defconst user-init-dir
  (cond ((boundp 'user-emacs-directory)
         user-emacs-directory)
        ((boundp 'user-init-directory)
         user-init-directory)
        (t "~/.emacs.d/")))

(defun load-user-file (file)
  "Load FILE in current user's configuration directory, often ~/.emacs.d."
  (interactive "f")
  (if (file-exists-p (expand-file-name file user-init-dir))
      (load-file (expand-file-name file user-init-dir))
    (message (format "file doesn't exist: %s" (expand-file-name file user-init-dir)))))

(defconst heks/is-gnu-linux-p (equal system-type 'gnu/linux)
  "Any GNU/Linux machine.")

(defconst heks/is-darwin-p (equal system-type 'darwin)
  "Any Darwin (macOS) machine.")

;; ====== Tweak GC =========

(use-package gcmh
  :ensure t
  :config
  (gcmh-mode 1))

(use-package no-littering
  :ensure t
  :config
  (with-eval-after-load 'recentf
    (add-to-list 'recentf-exclude no-littering-var-directory)
    (add-to-list 'recentf-exclude no-littering-etc-directory))
  )

;; ====== Load user modules ======

(load-user-file "modules/heks-emacs.el")

;; Load more user modules
(defvar heks-emacs-modules '())
(setq heks-emacs-modules '(
                           ai
                           common-lisp
                           completion
                           consult
                           dashboard
                           dev
                           dd
                           dired
                           editor
                           eglot
                           emacs-core
                           irc
                           git
                           go
                           help
                           libs
                           macros
                           mail
                           maps
                           misc
                           music
                           org
                           plot
                           proofreading
                           search
                           shell
                           snippets
                           theme
                           ui))
(mapc (lambda(f) (load-user-file (format "modules/%s.el" f))) heks-emacs-modules)

;; load heks-linux bridge if available (GNU/Linux system)
(ignore-errors
  (when heks/is-gnu-linux-p
    (load-user-file "heks-linux-bridge.el")))

;; load cask-and-cons bridge if available (macOS system)
(ignore-errors
  (when heks/is-darwin-p
    (load-user-file "cask-and-cons-bridge.el")))

;;; init.el ends here
