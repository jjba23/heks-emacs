;;; dashboard.el --- Dashboard for Emacs -*- lexical-binding: t -*-

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

;; Dashboard for Emacs

;;; Code:

(setq joe-welkomscherm/bookmarks-list
      `((("heks-emacs" . ,(string-replace "$HOME" "~" heks-emacs-clone-dir))
         ("niri" . ,(format "%s/src/heks-emacs/niri.scm" (string-replace "$HOME" "~" heks-emacs-clone-dir))))
        (("notes" . "~/Hacking/private-notes/")
         ("pop-test" . "~/Hacking/pop-test/")
         ("iter-vitae" . "~/Hacking/iter-vitae/")
         ("jointhefreeworld" . "~/Hacking/jointhefreeworld/"))
        (("wolk-jjba" . "~/Hacking/wolk-jjba/")
         ("wikimusic" . "~/Hacking/wikimusic/")
         ("lucidplan" . "~/Hacking/lucidplan/")
         ("byggsteg" . "~/Hacking/byggsteg/"))
        (("ggg" . "~/Hacking/ggg")
         ("pingwing" . "~/Hacking/pingwing")
         ("kracht" . "~/Hacking/kracht")
         ("hygguile" . "~/Hacking/hygguile"))
        (("orgwebalchemy" . "~/Hacking/orgwebalchemy")
         ("oculuslambda" . "~/Hacking/oculuslambda"))
        ))

(setq joe-welkomscherm/work-list
      '((("VDB" . "~/Work/Vandebron/")
         ("mobile" . "~/Work/mobile")
         ("onboarding" . "~/Work/onboarding/"))
        ))

(setq joe-welkomscherm/actions-list
      '((("*scratch*" . (lambda(btn) (switch-to-buffer "*scratch*")))
         ("*Messages*" . (lambda(btn) (switch-to-buffer "*Messages*")))
         ("re-render me" . (lambda(btn) (welkomscherm))))
        ;; (("system-rebuild  (sr)" . (lambda(btn) (heks-emacs-sys-reconfigure)))
        ;;  ("joe-rebuild (jr)" . (lambda(btn) (heks-emacs-joe-reconfigure))))
        ))

(use-package welkomscherm
  :ensure (:host codeberg :repo "jjba23/welkomscherm.el" :branch "trunk")
  :demand t
  :bind (("C-c SPC SPC" . welkomscherm)
         )
  :init
  (setopt welkomscherm/bookmarks-list joe-welkomscherm/bookmarks-list)
  (setopt welkomscherm/work-list joe-welkomscherm/work-list)
  (setopt welkomscherm/actions-list joe-welkomscherm/actions-list)
  :config
  (setopt initial-buffer-choice
          (lambda ()
            (or
             (ignore-errors
               (welkomscherm)
               (get-buffer welkomscherm/buffer-name))
             (get-buffer-create "*scratch*")))))

(provide 'heks-emacs/dashboard)

;;; dashboard.el ends here
