;;; demo.el --- Scripted tour of heks-emacs for recording the README GIF -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Plays a timed tour inside a running heks-emacs so that a screen recorder
;; sees the same thing every time.  Start the recorder, then run
;;
;;   M-x load-file RET docs/demo/demo.el RET
;;   M-x heks/demo-play RET
;;
;; The tour opens a few files, walks through every `tekengrootte' scale
;; (nano .. jumbo, ending back at regular), and parks the pointer on a symbol
;; so the hover popup shows.  Edit `heks/demo--steps' to change the story.
;;
;; Recording on macOS (needs Screen Recording permission for the terminal):
;;
;;   screencapture -v -V 40 /tmp/heks.mov
;;   ffmpeg -i /tmp/heks.mov -vf "fps=15,scale=1100:-1:flags=lanczos" docs/images/heks-emacs.gif
;;
;; `gifsicle -O3' afterwards keeps the file small.

;;; Code:

(require 'cl-lib)

(defconst heks/demo--scales
  '(tekengrootte-set-scale-nano
    tekengrootte-set-scale-tiny
    tekengrootte-set-scale-small
    tekengrootte-set-scale-regular
    tekengrootte-set-scale-large
    tekengrootte-set-scale-larger
    tekengrootte-set-scale-colossal
    tekengrootte-set-scale-jumbo
    tekengrootte-set-scale-regular)
  "The `tekengrootte' commands the tour calls, in order.")

(defun heks/demo--call (command)
  "Call COMMAND if it is defined, and say which one in the echo area."
  (when (fboundp command)
    (message "%s" command)
    (funcall command)))

(defun heks/demo--steps ()
  "Return the tour as a list of (SECONDS-AFTER-START . THUNK)."
  (let* ((root (file-name-directory (or load-file-name buffer-file-name
                                        default-directory)))
         (repo (expand-file-name "../.." root))
         (open (lambda (file)
                 (lambda () (find-file (expand-file-name file repo)))))
         (scale-steps
          (cl-loop for command in heks/demo--scales
                   for at from 8 by 2
                   collect (cons at (let ((c command))
                                      (lambda () (heks/demo--call c)))))))
    (append
     (list (cons 0 (funcall open "README.org"))
           (cons 3 (funcall open "src/modules/dev-hover.el"))
           (cons 6 (lambda () (goto-char (point-min))
                     (re-search-forward "heks/hover--request" nil t))))
     scale-steps
     (list (cons 28 (funcall open "src/modules/ui.el"))
           (cons 33 (lambda () (message "heks-emacs")))))))

;;;###autoload
(defun heks/demo-play ()
  "Play the scripted tour; see the Commentary of this file."
  (interactive)
  (dolist (step (heks/demo--steps))
    (run-at-time (car step) nil (cdr step))))

(provide 'heks-demo)

;;; demo.el ends here
