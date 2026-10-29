;;; music.el --- Music configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Music configuration for Emacs: a fretboard to look at while a chord is
;; being written down, and a player that plays the file at point where the
;; file is, without a library to keep in order first.
;;
;; There is no music directory to point at and no keys of its own under
;; `C-c': what played a collection from a library, and held the playlist and
;; the daemon that owned the files, is not part of this configuration.

;;; Code:

(use-package fretboard
  :ensure (:host github :repo "vifon/fretboard.el" :branch "master"))

(use-package ready-player
  :ensure t
  :config
  (setq ready-player-set-global-bindings nil)
  (ready-player-mode +1))

(provide 'heks/music)

;;; music.el ends here
