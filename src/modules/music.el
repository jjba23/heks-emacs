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

;;; Code:

(use-package fretboard
  :ensure (:host github :repo "vifon/fretboard.el" :branch "master"))

(use-package emms
  :ensure t
  :bind
  (("<XF86AudioPrev>" . emms-previous)
   ("<XF86AudioNext>" . emms-next)
   ("<XF86AudioPlay>" . emms-pause)

   ;; Playback & Controls
   ("C-c e SPC"       . emms-pause)
   ("C-c e n"         . emms-next)
   ("C-c e p"         . emms-previous)
   ("C-c e s"         . emms-stop)
   ("C-c e b"         . emms-browser)
   ("C-c e e"         . emms-playlist-mode-go)
   ("C-c e i"         . emms-show)
   ("C-c e +"         . emms-volume-raise)
   ("C-c e -"         . emms-volume-lower)
   ("C-c e C"         . emms-player-mpd-connect)
   ("C-c e c" .         emms-cache-set-from-mpd-all)

   ;; Direct Media Loading (Immediate Play)
   ("C-c e f"         . emms-play-file)
   ("C-c e d"         . emms-play-directory-tree)
   ("C-c e u"         . emms-play-url)

   ;; Queueing Media (Append without overwriting current playlist)
   ("C-c e a f"       . emms-add-file)
   ("C-c e a d"       . emms-add-directory-tree)
   ("C-c e a u"       . emms-add-url)

   ;; Playlist Management & Persistence
   ("C-c e C"         . emms-playlist-clear)
   ("C-c e z"         . emms-shuffle)
   ("C-c e r"         . emms-toggle-repeat-track)
   ("C-c e R"         . emms-toggle-repeat-playlist)
   ("C-c e W"         . emms-playlist-save)
   ("C-c e L"         . emms-playlist-load)
   ("C-c e ."         . emms-playlist-mode-center-current))
  :config
  (require 'emms-setup)
  (require 'emms-player-mpd)
  (emms-all)

  ;; Connection details
  (setq emms-player-mpd-server-name heks-emacs/mpd-server-name)
  (setq emms-player-mpd-server-port heks-emacs/mpd-server-port)
  (when (bound-and-true-p heks-emacs/mpd-server-password)
    (setq emms-player-mpd-server-password heks-emacs/mpd-server-password))

  ;; Disable local file path translation for remote MPD
  ;; If this points to a local folder while MPD is on a remote server, track matching fails.
  (setq emms-player-mpd-music-directory nil)

  ;; Set MPD as the ONLY player backend (removes local mpv/vlc players)
  (setq emms-player-list '(emms-player-mpd))

  ;; Force MPD to manage info & volume
  (setq emms-info-functions '(emms-info-mpd))
  (setq emms-volume-change-function #'emms-volume-mpd-change)
  (setq emms-player-mpd-sync-playlist t)

  (add-hook 'emms-playlist-cleared-hook 'emms-player-mpd-clear)

  :custom
  (emms-browser-covers #'emms-browser-cache-thumbnail-async))


(use-package ready-player
  :ensure t
  :config
  (setq ready-player-set-global-bindings nil)
  (ready-player-mode +1))

(provide 'heks-emacs/music)

;;; music.el ends here
