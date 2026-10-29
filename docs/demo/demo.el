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
;; so the hover popup shows (the pointer is moved onto the symbol, since the
;; popup follows the pointer, not point).  Edit `heks/demo--steps' to change
;; the story.  Keep the pointer still while recording.
;;
;; Recording on macOS (needs Screen Recording permission for the terminal):
;;
;;   screencapture -v -V 42 /tmp/heks.mov
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

(defun heks/demo--park-pointer ()
  "Move the pointer onto the symbol at point, so that the hover popup shows.
The popup follows the mouse pointer rather than point, which is why merely
moving point to a symbol shows nothing."
  (redisplay t)
  (let* ((window (selected-window))
         (posn (posn-at-point (point) window))
         (xy (and posn (posn-x-y posn))))
    (when xy
      (set-mouse-pixel-position
       (window-frame window)
       (+ (car xy) (car (window-inside-pixel-edges window)) 8)
       (+ (cdr xy) (cadr (window-inside-pixel-edges window))
          (floor (frame-char-height (window-frame window)) 2))))))

(defun heks/demo--steps ()
  "Return the tour as a list of (SECONDS-AFTER-START . THUNK)."
  (let* ((root (file-name-directory (or load-file-name buffer-file-name
                                        default-directory)))
         (repo (expand-file-name "../.." root))
         (open (lambda (file)
                 (lambda ()
                   (switch-to-buffer
                    (find-file-noselect (expand-file-name file repo))))))
         (scale-steps
          (cl-loop for command in heks/demo--scales
                   for at from 14 by 2
                   collect (cons at (let ((c command))
                                      (lambda () (heks/demo--call c)))))))
    (append
     (list (cons 0 (funcall open "README.org"))
           (cons 3 (funcall open "src/modules/dev-hover.el"))
           (cons 6 (lambda () (goto-char (point-min))
                     (when (re-search-forward "heks/hover--request" nil t)
                       (goto-char (match-beginning 0))
                       (recenter 8))))
           ;; Give the pointer a moment to settle, then let the popup show
           ;; (`heks/hover-delay' plus the answer) before anything else moves.
           (cons 8 #'heks/demo--park-pointer)
           (cons 13 (lambda () (set-mouse-pixel-position (selected-frame) 5 5))))
     scale-steps
     (list (cons 33 (funcall open "src/modules/ui.el"))
           (cons 38 (lambda () (message "heks-emacs")))))))

(defvar heks/demo--saved-windows nil
  "The window layout from before the tour, put back when it ends.")

;;;###autoload
(defun heks/demo-play ()
  "Play the scripted tour; see the Commentary of this file.
The tour uses one window; the layout from before is restored at the end."
  (interactive)
  (setq heks/demo--saved-windows (current-window-configuration))
  (delete-other-windows)
  (dolist (step (heks/demo--steps))
    (run-at-time (car step) nil
                 (lambda (thunk)
                   (condition-case err (funcall thunk)
                     (error (message "demo step failed: %S" err))))
                 (cdr step)))
  (run-at-time 41 nil
               (lambda ()
                 (when (window-configuration-p heks/demo--saved-windows)
                   (set-window-configuration heks/demo--saved-windows)))))

(provide 'heks-demo)

;;; demo.el ends here
