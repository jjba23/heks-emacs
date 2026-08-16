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

;; Use Smudge to connect to Spotify
;;
;; (use-package smudge
;;   :ensure t
;;   :after (f)
;;   :custom
;;   (smudge-oauth2-client-secret (f-read-text "~/secrets/smudge-oauth2-client-secret"))
;;   (smudge-oauth2-client-id (f-read-text "~/secrets/smudge-oauth2-client-id"))
;;   (smudge-player-use-transient-map t)
;;   :config
;;   (define-key smudge-mode-map (kbd "C-c .") 'smudge-command-map))

(use-package emms
  :ensure t
  :init
  (require 'emms-setup)
  (require 'emms-player-mpd)
  ;; Load standard EMMS features
  (emms-all)

  ;; MPD Connection Details
  (setq emms-player-mpd-server-name "localhost")
  (setq emms-player-mpd-server-port "6600")
  ;; (setq emms-player-mpd-server-password "your-password") ; Uncomment if MPD requires auth

  ;; Absolute path to your MPD music directory
  (setq emms-player-mpd-music-directory heks-emacs-ews-music-directory)

  ;; Set MPD as the primary player
  (setq emms-player-list '(emms-player-mpd))

  ;; Use MPD for fetching track metadata
  (add-to-list 'emms-info-functions #'emms-info-mpd)

  ;; Use MPD to control playback volume
  (setq emms-volume-change-function #'emms-volume-mpd-change)

  ;; Auto-sync EMMS playlist with MPD status
  (setq emms-player-mpd-sync-playlist t)

  ;; Enable EMMS cache to read metadata from MPD
  (setq emms-info-functions '(emms-info-mpd))

  ;; Dump MPD database into EMMS cache automatically when starting emms-browser
  ;; (setq emms-cache-set-function #'emms-cache-set-from-mpd-all)

  :custom
  (emms-source-file-default-directory heks-emacs-ews-music-directory)
  (emms-browser-covers #'emms-browser-cache-thumbnail-async)
  :bind
  (("<f5>"   . emms-browser)
   ("M-<f5>" . emms)
   ("<XF86AudioPrev>" . emms-previous)
   ("<XF86AudioNext>" . emms-next)
   ("<XF86AudioPlay>" . emms-pause)))

(use-package listen
  :ensure (:host github :repo "alphapapa/listen.el"))

(use-package ready-player
  :ensure t
  :config
  (setq ready-player-set-global-bindings nil)
  (ready-player-mode +1))

(provide 'heks-emacs/music)

;;; music.el ends here
