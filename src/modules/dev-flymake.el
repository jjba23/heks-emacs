;;; dev-flymake.el --- Flymake checkers and their interaction with Eglot -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>


;;; Commentary:

;; Flymake checkers and their interaction with Eglot.

;;; Code:

;; Sets up a collection of Flymake backends for various languages,
;; enabling on-the-fly syntax checking and linting.
(use-package flymake-collection
  :ensure t
  ;; Deferred loading has to be forced here: the package is only reachable
  ;; through the `:hook' entries below, and adding
  ;; `flymake-collection-hook-setup' to `after-init-hook' -- as the package
  ;; suggests -- does not work with Elpaca, which installs the library while
  ;; `after-init-hook' is already running, so that entry is never reached and
  ;; no backend would ever be registered.  Loading it up front and calling the
  ;; setup from `:config' registers every backend the library configures.
  :demand t
  :config
  (flymake-collection-hook-setup)
  ;; Shell scripts are checked by shellcheck through Emacs's own
  ;; `sh-shellcheck-flymake', which `sh-mode' and `bash-ts-mode' register
  ;; themselves (see `shell.el' for what is said to it).  The package
  ;; defaults disable that one in favour of its own shellcheck backend; both
  ;; are turned around here, so that the library's checker is off and
  ;; Emacs's -- which reads shellcheck's JSON output -- is the one that
  ;; runs.  Two of them would report every problem in the buffer twice.
  (let ((shell (assoc '(sh-mode bash-ts-mode) flymake-collection-hook-config)))
    (when shell
      (setcdr shell '((flymake-collection-shellcheck :disabled t)))))
  :hook (;; The backends are registered globally above; Flymake itself still has
         ;; to be started per buffer.  SQL uses the `sql-lint' backend from the
         ;; package defaults, and shell scripts are set up by `shell.el',
         ;; which starts Flymake with its own checkers.
         (emacs-lisp-mode . flymake-mode)
         (sql-mode . flymake-mode)))

;;
;; ====== The checkers a buffer already has ======
;;

;; Eglot manages Flymake opinionatedly.  When it starts managing a buffer it
;; saves the value of `flymake-diagnostic-functions' and replaces it with a
;; list of its own backend alone -- "completely replacing its value", says
;; its manual -- and it puts the saved value back when it stops managing the
;; buffer.  For as long as a server is there, then, the buffer is checked by
;; the server and by nothing else.  The checkers of this configuration are
;; not the server's to take away: `sh-shellcheck-flymake' is registered by
;; Emacs's own shell modes, the linters of the library above by the modes it
;; covers, and the shfmt drift, the OpenAPI check and the rest by modules
;; here.  None of those can say so where the server would hear it, because
;; each of them is registered on its major mode and knows nothing about
;; servers.
;;
;; So the list is put back together in one place, for every language and
;; every buffer: what Eglot saved is exactly what the buffer had, and every
;; backend of it that is not Eglot's own goes back beside it.  A module says
;; what checks its buffers where it belongs, and connecting a server can
;; neither lose a checker nor make a problem be reported twice.

(defun heks/flymake-keep-backends ()
  "Put a buffer's own Flymake backends back when Eglot manages it.

Eglot replaces `flymake-diagnostic-functions' with a list of its own
backend alone for as long as it manages a buffer, which is what this
function reads the saved value of.  `eglot--saved-bindings' is where
Eglot keeps it -- the place it takes the list from when it stops
managing the buffer -- and every backend of it that is not
`eglot-flymake-backend' is added to the buffer again.  Flymake is then
asked to check the buffer, because the list Eglot left it with is one it
has never reported on.

Nothing here knows a language: a checker registered on its major mode,
by Emacs or by a module of this configuration, survives a server without
that module saying anything about it."
  (when (eglot-managed-p)
    (let ((own (alist-get 'flymake-diagnostic-functions eglot--saved-bindings)))
      (when own
        (dolist (backend own)
          (unless (eq backend 'eglot-flymake-backend)
            (add-hook 'flymake-diagnostic-functions backend nil t)))
        (flymake-start)))))

(add-hook 'eglot-managed-mode-hook #'heks/flymake-keep-backends)

;; What `python-flymake' -- Emacs's own backend for Python, which
;; `python-base-mode' registers for every Python buffer -- runs where it
;; does: flake8, installed for this user rather than system-wide.  Nothing
;; here puts that backend in a buffer, because the library's own
;; configuration for Python turns it off in favour of its `pycodestyle'
;; backend, as it used to turn the shellcheck of `shell.el' off; this is
;; what Emacs's backend would run rather than what checks a Python buffer
;; here today.  It is kept because it is what one would change to make that
;; backend (and so flake8) the checker of a Python buffer.
(setq python-flymake-command '("~/.local/bin/flake8" "-"))

(provide 'heks/dev-flymake)

;;; dev-flymake.el ends here
