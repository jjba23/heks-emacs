;;; music.el --- Music configuration for Emacs -*- lexical-binding: t -*-

;;; SPDX-License-Identifier: MIT
;;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;;; Music configuration for Emacs: a fretboard to look at while a chord is
;;; being written down, and a player that is only the client of an MPD daemon
;;; running on another machine.
;;;
;;; There is no music directory to point at and no keys of its own under
;;; `C-c': the library, the playlist and the daemon that owns the files are
;;; the server's, which is why the settings below are a host and a port rather
;;; than a directory, and why the password is read from ~/.authinfo.gpg under
;;; that same host and port.

;;; Code:

(use-package fretboard
  :ensure (:host github :repo "vifon/fretboard.el" :branch "master"))

(use-package orpheus
  :ensure (:host github :repo "jjba23/orpheus.el" :branch "trunk")
  :commands (orpheus orpheus-visualizer)
  :config
  ;; (setopt orpheus-backend 'mpd
  ;;         orpheus-mpd-host "mpd-server.jointhefreeworld.org"
  ;;         orpheus-mpd-port 6600)
  (setq orpheus-backend 'ssh
    orpheus-ssh-host "wolk-jjba"
    orpheus-ssh-directory "/mnt/wolkenschlosslagerung/music")
  ;;(orpheus-mode-line-mode 1)
  )

(provide 'heks/music)

;;; music.el ends here
