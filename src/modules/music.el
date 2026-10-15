;;; music.el --- Music configuration for Emacs -*- lexical-binding: t -*-

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

;;; Commentary:

;; Music configuration for Emacs
;;
;; The music is played by EMMS, over MPD: the daemon holds the files and
;; the playlist, EMMS is the interface, and the keys are the ones a player
;; has -- `n' for the next track, `p' for the previous one, `i' for what is
;; playing now.  EMMS is started from Emacs (`C-c M m') and connected to the
;; daemon once per session (`C-c M c'), which is what the M-x history of
;; this configuration said was being done by hand more than anything else
;; in it.

;;; Code:

(defcustom heks-emacs-music-directory (or (getenv "HEKS_MUSIC_DIR") "~/Music")
  "The directory the music is in, for EMMS's browser.

MPD keeps its own idea of where the music lives, in `music_directory' of
its configuration; pointing this at that directory is what lets EMMS show
the files a playlist entry came from, and tag them.  `HEKS_MUSIC_DIR' is
read first, so the directory can be set per machine without editing this
file."
  :type 'directory)

(use-package fretboard
  :ensure (:host github :repo "vifon/fretboard.el" :branch "master"))

(use-package ready-player
  :ensure t
  :config
  (setq ready-player-set-global-bindings nil)
  (ready-player-mode +1))

;; EMMS, and the keys of a player.  The letters are the ones the rest of
;; the scheme already uses for these ideas -- `n' is next, `p' is previous,
;; `o' opens something by name, `u' updates -- and the ones that are not
;; actions in the action alphabet are written down in
;; `heks-emacs-key-letters', so the reference can describe every one of
;; them without this module growing a vocabulary of its own.
(use-package emms
  :ensure t
  :bind (("C-c M m" . emms)
         ("C-c M l" . emms-playlist-mode-go)
         ("C-c M c" . emms-player-mpd-connect)
         ("C-c M r" . emms-player-mpd-play)
         ("C-c M a" . emms-pause)
         ("C-c M n" . emms-next)
         ("C-c M p" . emms-previous)
         ("C-c M i" . emms-player-mpd-show)
         ("C-c M u" . emms-cache-set-from-mpd-all)
         ("C-c M o" . emms-play-url)
         ("C-c M b" . emms-browser)
         ("C-c M C" . emms-player-mpd-clear))
  :config
  (require 'emms-setup)
  (emms-all)
  (setq emms-source-file-default-directory heks-emacs-music-directory)
  ;; `emms-all' sets up the parts; which player plays the music is the one
  ;; choice it cannot make.  MPD is the player here -- it is what the
  ;; playlist and the volume are shared with -- and a machine without the
  ;; daemon falls back to the local players, so that EMMS still plays a
  ;; file on a laptop that runs nothing in the background.
  (if (executable-find "mpd")
      (setq emms-player-list '(emms-player-mpd)
            emms-player-mpd-music-directory heks-emacs-music-directory
            emms-player-mpd-sync-playlist t)
    (emms-default-players)))

(provide 'heks-emacs/music)

;;; music.el ends here
