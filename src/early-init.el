;;; early-init.el --- Custom Emacs configuration for heks-emacs -*- lexical-binding: t -*-

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

;;; Code:

;;; Commentary:

;; TODO

;;; Code:

;; disable Emacs' built-in package manager (in favor of Elpaca)
(setq package-enable-at-startup nil)
;; Do not allow loading from the package cache (same reason).
(setq package-quickstart nil)

;; Prevent the glimpse of un-styled Emacs by disabling these UI elements early.
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

;; Resizing the Emacs frame can be a terribly expensive part of changing the
;; font. By inhibiting this, we easily halve startup times with fonts that are
;; larger than the system default.
(setq frame-inhibit-implied-resize t)

;; hide certain UI elements of Emacs
;; which are not that interesting for power users
;;
;; if you're a beginner, consider setting all these to 1
;;
(tool-bar-mode -1)
(scroll-bar-mode -1)
(menu-bar-mode -1)

;; Defer garbage collection further back in the startup process
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; restore threshold to normal value after startup
(add-hook 'emacs-startup-hook
          (lambda() (setq gc-cons-threshold (* 50 1024 1024))))

(setq inhibit-startup-message t
      inhibit-splash-screen t
      use-file-dialog nil
      inhibit-startup-screen t)

;; tweak native compilation settings
(setq native-comp-speed 2)

;;; early-init.el ends here
