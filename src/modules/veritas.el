;;; veritas.el --- Veritas, the Guile test runner, in the scheme -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Veritas is the testing framework of this configuration's Scheme work, and
;; `veritas.el' is its editor side: it teaches Emacs the vocabulary of a
;; suite -- `suite', `test', `benchmark', `scenario' and their BDD, table and
;; snapshot companions -- and it runs the Veritas CLI from the project, the
;; current file, or the test, suite, tag or benchmark at point.  A run is
;; reported from the runner's JSON event stream, so every test and assertion
;; is a link to its own definition and a failure is collected at the top with
;; what it expected and what it got.
;;
;; The package is the whole of that, and this module is only what the
;; configuration says to it.  The first half is the map: the package binds its
;; menu to `C-c v', which is this configuration's view topic, so that binding
;; is taken out of `veritas-mode-map' and the menu is given `C-c g T' -- the
;; further test key under Guile, beside `C-c g t', which runs the project's
;; own tests.  Binding the package's prefix directly would shadow `C-c v c'
;; and the rest of the view topic in exactly the buffers a Veritas project
;; opens, which is the kind of conflict the key audit exists to catch.
;;
;; The second half is nothing: `veritas-auto-enable' is already what we want.
;; The package adds `veritas-mode-maybe' to `scheme-mode-hook', and the mode
;; turns itself on in a Scheme buffer that belongs to a detected Veritas
;; project.  A `.scm' file outside one is left alone, which is right: a test
;; suite is a project's, and the menu would have no project to run.

;;; Code:

(declare-function veritas-dispatch "veritas" ())
(defvar heks/scheme-mode-map)
(defvar veritas-mode-map)

(defun heks/veritas--mnemonic-keys ()
  "Give Veritas's commands this configuration's keys instead of the package's.

The package binds its command menu to `C-c v', and `C-c v' is the view topic
here: in a Veritas buffer the package's map would answer first and folding,
narrowing and the rest of the topic would stop working.  That binding is taken
out, and the menu is given `C-c g T' -- the further test key of the Guile
topic -- in the Scheme map, where every Scheme buffer answers it.  The letters
under the menu are the package's own, reached through `veritas-dispatch' so
that the configuration does not spell out the runner's flags a second time."
  (define-key veritas-mode-map (kbd "C-c v") nil)
  ;; The key belongs to the Scheme map, which every Scheme buffer has: a
  ;; Veritas project's buffer gets the mode, but the menu stays reachable in
  ;; one that is not a project yet, where the runner can say what it needs.
  (define-key heks/scheme-mode-map (kbd "C-c g T") #'veritas-dispatch))

;; The map exists once the package has loaded, so this runs then rather than
;; at the moment this file is read.
(with-eval-after-load 'veritas (heks/veritas--mnemonic-keys))

(use-package veritas
  :ensure (:host github :repo "jjba23/veritas.el" :branch "trunk")
  :demand t)

(provide 'heks/veritas)

;;; veritas.el ends here
