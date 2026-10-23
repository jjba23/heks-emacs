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
