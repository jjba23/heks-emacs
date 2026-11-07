;;; music.el --- Music configuration for Emacs -*- lexical-binding: t -*-

;;; SPDX-License-Identifier: MIT
;;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;;; Music configuration for Emacs: a fretboard to look at while a chord is
;;; being written down, and a player that plays the file at point where the
;;; file is, without a library to keep in order first.
;;;
;;; There is no music directory to point at and no keys of its own under
;;; `C-c': what played a collection from a library, and held the playlist and
;;; the daemon that owned the files, is not part of this configuration.

;;; Code:

(use-package fretboard
  :ensure (:host github :repo "vifon/fretboard.el" :branch "master"))

(use-package orpheus
  :ensure (:host github :repo "jjba23/orpheus.el" :branch "trunk")
  :commands (orpheus orpheus-visualizer)
  :config
  (setopt orpheus-backend 'mpd
          orpheus-mpd-host "mpd-server.jointhefreeworld.org"
          orpheus-mpd-port 6600)
  (orpheus-mode-line-mode 1))

(provide 'heks/music)

;;; music.el ends here
