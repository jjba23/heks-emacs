;;; heks-emacs-lock.el --- Check that the package set has a lock in the tree  -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Elpaca pins every package by commit, but it pins it in `~/.emacs.d/elpaca'
;; -- the installation's own state, which is nowhere in the repository.  So
;; what is reproducible here is the bootstrap, and the packages are whatever
;; Elpaca last fetched: a clone on another machine, or six months later,
;; resolves a different set.
;;
;; `elpaca-write-lock-file' writes that state as a file of recipes with a
;; `:ref' each, one package per entry, so a bump is a diff of one commit per
;; package rather than a snapshot nobody reads.  `src/elpaca-lock.eld' is
;; that file, `init.el' puts it in front of the menu functions so a recipe is
;; resolved from the lock before MELPA's, and this checks that the lock still
;; covers what the configuration uses:
;;
;;   * every package a `use-package' form asks for is in the lock;
;;   * every entry in the lock has a recipe with a `:ref', so a pinned
;;     package is actually pinned.
;;
;; The refs are not compared with the installed sources: the lock is what the
;; repository says, and a machine whose checkout is elsewhere is a machine
;; whose refs differ without anything being wrong.  What a bump looks like is
;; `git diff src/elpaca-lock.eld', and `maak lock-update' is how the file is
;; written.
;;
;;   emacs -Q --batch -l test/heks-emacs-lock.el
;;   HEKS_LOCK_WRITE=1 emacs -Q --batch -l test/heks-emacs-lock.el
;;
;; The second form writes the lock from the *installed* configuration: it
;; records the `:ref' Elpaca has on disk, so it is run on a machine whose
;; packages are where they should be, and read as a diff afterwards.

;;; Code:

(setq load-prefer-newer t)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defconst heks-lock--root
  (file-name-as-directory
   (or (getenv "HEKS_LOCK_SOURCE")
       (expand-file-name ".." (file-name-directory (file-truename load-file-name)))))
  "The checkout the lock belongs to.")

(defconst heks-lock--file "src/elpaca-lock.eld"
  "The lock file, in the tree, where `init.el' and this look for it.")

(defconst heks-lock--dir
  (file-name-as-directory
   (or (getenv "HEKS_LOCK_DIR") (expand-file-name "~/.emacs.d/")))
  "The installed configuration whose packages the lock is written from.")

(defvar heks-lock--failures 0)

(defun heks-lock--check (label value &optional expected)
  "Record that LABEL holds when VALUE equals EXPECTED, which defaults to t."
  (if (equal value (if (or (null expected) (eq expected t)) t expected))
      (message "  ok   %s" label)
    (setq heks-lock--failures (1+ heks-lock--failures))
    (message "  FAIL %s -> %S" label value)))

(defun heks-lock--read (file)
  "Return the lock FILE as the alist it was written as, or nil."
  (when (file-exists-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (ignore-errors (read (current-buffer))))))

;; The two the bootstrap reads before the lock is anywhere: `elpaca'
;; itself and the `use-package' extension that interprets these forms.
;; They cannot be in the lock -- the lock is a menu function, and the menu
;; is what those two are resolved from -- and `init.el' is where their
;; recipes are.  Everything after them is locked.
(defconst heks-lock--bootstrap '(elpaca elpaca-use-package)
  "The packages the bootstrap reads before the lock can apply.")

;; The queue is what the `use-package' forms asked for, and it is the same
;; list `elpaca-write-lock-file' writes from: reading it here is what makes
;; "a package the configuration uses" a fact rather than a grep.
(setq user-emacs-directory heks-lock--dir)
(load (expand-file-name "init.el" heks-lock--dir) nil t)

(defun heks-lock--queued ()
  "Return the identifiers of the packages the configuration queued."
  (seq-remove (lambda (id) (memq id heks-lock--bootstrap))
              (delete-dups (mapcar #'car (elpaca--queued)))))

(when (getenv "HEKS_LOCK_WRITE")
  (let ((target (expand-file-name heks-lock--file heks-lock--root)))
    (elpaca-write-lock-file target)
    (message "\n== wrote %s ==" heks-lock--file)))

(let ((lock (heks-lock--read (expand-file-name heks-lock--file heks-lock--root)))
      (queued (heks-lock--queued)))
  (message "== the packages the configuration uses, and the lock in the tree ==")
  (if (null lock)
      (progn
        (setq heks-lock--failures (1+ heks-lock--failures))
        (message "  FAIL there is no %s; write it with\n        HEKS_LOCK_WRITE=1 emacs -Q --batch -l test/heks-emacs-lock.el"
                 heks-lock--file))
    (let ((locked (mapcar #'car lock))
          (missing (seq-remove (lambda (id) (assq id lock)) queued))
          (unpinned (seq-remove (lambda (entry)
                                  (plist-get (plist-get (cdr entry) :recipe) :ref))
                                lock)))
      (heks-lock--check (format "%d packages are queued" (length queued))
                        (> (length queued) 0))
      (heks-lock--check (format "every one of them is in the lock (%d locked)"
                                (length locked))
                        (null missing))
      (dolist (id missing)
        (message "  FAIL %s is used and not locked" id))
      (heks-lock--check "every locked package is pinned to a ref"
                        (null unpinned))
      (dolist (entry unpinned)
        (message "  FAIL %s is locked without a `:ref'" (car entry)))
      (let ((extra (seq-remove (lambda (id) (memq id queued)) locked)))
        ;; A package nobody asks for is a lock entry that only costs a diff,
        ;; so it is a note rather than a failure -- the lock is rewritten by
        ;; a machine, and reading the diff is where it is decided.
        (when extra
          (message "  note %d entries are locked and no longer used: %s"
                   (length extra)
                   (string-join (mapcar #'symbol-name (seq-take extra 8)) ", "))))))
  (message "\n== %d failures ==" heks-lock--failures)
  (when (> heks-lock--failures 0)
    (kill-emacs 1)))

;;; heks-emacs-lock.el ends here
