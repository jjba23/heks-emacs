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
;; The tour walks through the things this configuration is for: the
;; dashboard, an Org file folded to its headlines, the key scheme explained
;; by which-key while C-c is being typed, Emacs Lisp and Markdown, an
;; OpenAPI specification rendered next to its source, a shell script served
;; by bash-language-server (hover documentation, Flymake findings), Dired
;; with its icons, five palettes, and every `tekengrootte' scale from nano
;; to jumbo and back to the working size.  It reads only files from this
;; repository -- never the notes, mail or other personal files a real
;; installation has -- and it changes nothing on disk.
;;
;; Run it in a separate Emacs (a second GUI instance, or one started with
;; its own `--init-directory') if the tour should not take over the Emacs
;; you are using: it does delete other windows while it plays, and puts the
;; layout back when it is over.
;;
;; The tour makes the frame opaque while it plays (`alpha-background'
;; 100) and puts the old value back at the end: HEKS-EMACS paints its
;; frame at 86%, so a recorder would film this configuration's colours
;; blended with the desktop behind it -- and the fringe, which Emacs
;; paints opaque, as a pale band beside every line.
;;
;; Recording on GNU/Linux under Wayland, with wf-recorder recording the
;; Emacs window (see `heks/demo-frame-width' for the size the tour is cut
;; for):
;;
;;   wf-recorder -g "0,0 1274x768" -f /tmp/heks-tour.mkv
;;   # ... play the tour, then stop the recorder with C-c ...
;;   ffmpeg -ss 2.9 -t 54.3 -i /tmp/heks-tour.mkv -vf \
;;     "fps=10,scale=1000:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
;;     docs/images/heks-emacs.gif
;;   gifsicle -O3 --lossy=70 docs/images/heks-emacs.gif -o docs/images/heks-emacs.gif
;;
;; On macOS, `screencapture -v -V 50 /tmp/heks.mov' records the screen and
;; the same ffmpeg line turns it into the GIF.
;;
;; Edit `heks/demo--steps' to change the story.  Keep the pointer still
;; while recording: which-key and the echo area are part of the picture.

;;; Code:

(require 'cl-lib)

(declare-function dired-hide-details-mode "dired" (&optional arg))
(declare-function eglot "eglot" (&rest args))
(declare-function eglot-current-server "eglot" (&optional server))
(declare-function flymake-show-buffer-diagnostics "flymake" (&optional arg))
(declare-function heks/hover-open "heks/dev-hover" ())
(declare-function heks/openapi-mode "heks/openapi" (&optional arg))
(declare-function heks/openapi-view "heks/openapi" ())
(declare-function heks/preview "heks/render" (&optional buffer))
(declare-function heks/refresh-faces "heks/ui" (&rest _))
(declare-function heks/set-base-faces "heks/ui" ())
(declare-function heks/set-markdown-faces "heks/ui" ())
(declare-function heks/set-org-faces "heks/ui" ())
(declare-function heks/set-window-divider-faces "heks/ui" ())
(declare-function org-fold-hide-sublevels "orgfold" (levels))
(declare-function org-fold-show-all "orgfold" (&optional types))
(declare-function welkomscherm "welkomscherm" ())

(defconst heks/demo-root
  (expand-file-name
   "../.." (file-name-directory (or load-file-name buffer-file-name
                                     default-directory)))
  "Root of the heks-emacs checkout the tour shows.")

(defconst heks/demo-frame-width 1274
  "Pixel width the tour is composed for; see the Commentary.")

(defconst heks/demo--themes
  '(ef-autumn gruvbox-dark-hard dracula modus-vivendi-tinted ef-cyprus)
  "Palettes the tour visits, in the order it visits them.")

(defconst heks/demo--scale-commands
  '(tekengrootte-set-scale-nano
    tekengrootte-set-scale-tiny
    tekengrootte-set-scale-small
    tekengrootte-set-scale-regular
    tekengrootte-set-scale-large
    tekengrootte-set-scale-larger
    tekengrootte-set-scale-colossal
    tekengrootte-set-scale-jumbo
    tekengrootte-set-scale-small)
  "Every `tekengrootte' command, smallest to largest and back to small.

The last one is the size the tour works in: it is the size the frame was
composed for, and where the tour leaves the text after showing the ladder.")

(defvar heks/demo--timers nil
  "Timers `heks/demo-play' has scheduled, so that `heks/demo-stop' can cancel.")

(defvar heks/demo--saved-windows nil
  "The window layout from before the tour, put back when it ends.")

(defvar heks/demo--saved-theme nil
  "The themes enabled before the tour, put back when it ends.")

(defvar heks/demo--saved-scale nil
  "The `tekengrootte-scale' from before the tour, put back when it ends.")

(defvar heks/demo--saved-alpha nil
  "The frame's `alpha-background' from before the tour, put back when it ends.")

;;;
;;; Small helpers the steps are written with
;;;

(defun heks/demo--file (relative)
  "Return the absolute name of RELATIVE inside the checkout."
  (expand-file-name relative heks/demo-root))

(defun heks/demo--call (command)
  "Call COMMAND when it exists, and say so when it does not.

A tour of a configuration has to survive a module that was not loaded or a
machine without one of its tools: a step says what is missing and the tour
goes on.  Nothing is said when the command runs, so that the echo area keeps
the words the command itself has for the viewer."
  (if (fboundp command)
      (funcall command)
    (message "demo: %s is not available here" command)))

(defun heks/demo--only-window ()
  "Leave the frame with one window, the largest one.
which-key and the previews can leave side windows behind, and a side window
is where a file must not end up: select the largest window, delete the rest,
and then any side window that refused to go with them."
  (select-window (get-largest-window))
  (delete-other-windows)
  (dolist (window (window-list))
    (unless (eq window (selected-window))
      (ignore-errors (delete-window window)))))

(defun heks/demo--open (relative &optional search)
  "Show RELATIVE, the file at point-min or at the first SEARCH match.
The whole frame is given to the file."
  (let ((buffer (find-file-noselect (heks/demo--file relative))))
    (heks/demo--only-window)
    (switch-to-buffer buffer)
    (heks/demo--forget-keys)
    (goto-char (point-min))
    (when (and search (re-search-forward search nil t))
      (goto-char (match-beginning 0))
      (recenter 6))
    ;; Whatever the previous scene left in the echo area is no longer true.
    (message nil)
    buffer))

(defun heks/demo--beside (relative render &optional prepare)
  "Show RELATIVE on the left and RENDER's output on the right.
PREPARE, when given, is called in the source buffer first -- it is how the
OpenAPI step turns the YAML into a spec before asking for its rendering."
  (heks/demo--open relative)
  (when prepare (funcall prepare))
  (let ((source-buffer (current-buffer))
        (window (split-window-right)))
    (with-selected-window window
      (heks/demo--call render))
    ;; `pop-to-buffer' inside RENDER may pick either window; the document is
    ;; always the one on the left.
    (let ((rendered (get-buffer-window
                     (or (and (boundp 'heks/preview-buffer-name)
                              heks/preview-buffer-name)
                         "*heks-emacs preview*")))
          (source (get-buffer-window source-buffer)))
      (when (and rendered source
                 (< (window-pixel-left rendered) (window-pixel-left source)))
        (window-swap-states rendered source)))
    (balance-windows)))

(defun heks/demo--scale (name)
  "Apply the `tekengrootte' scale NAME and re-apply the faces."
  (let ((command (intern (format "tekengrootte-set-scale-%s" name))))
    (when (fboundp command)
      (funcall command)
      ;; `tekengrootte-set-scale' runs `tekengrootte-set-scale-hook', which
      ;; this configuration uses to re-apply its faces; calling it here too
      ;; keeps the step honest when the hook is missing.
      (when (fboundp 'heks/refresh-faces)
        (heks/refresh-faces)))))

(defun heks/demo--theme (theme)
  "Make THEME the only palette, and re-apply the faces that depend on it."
  (condition-case err
      (progn
        (mapc #'disable-theme custom-enabled-themes)
        (load-theme theme t)
        (when (fboundp 'heks/set-base-faces) (heks/set-base-faces))
        (when (fboundp 'heks/set-window-divider-faces)
          (heks/set-window-divider-faces))
        (when (fboundp 'heks/set-org-faces) (heks/set-org-faces))
        (when (fboundp 'heks/set-markdown-faces) (heks/set-markdown-faces))
        (when (fboundp 'heks/refresh-faces) (heks/refresh-faces))
        (message "%s" theme))
    (error (message "demo: cannot load %s (%s)" theme (error-message-string err)))))

(defun heks/demo--forget-keys ()
  "Blank the keycast display, which otherwise keeps the last key sequence."
  (when (boundp 'keycast--this-command-keys)
    (setq keycast--this-command-keys nil
          keycast--this-command-desc nil)
    (force-mode-line-update t)))

(defun heks/demo--which-key ()
  "Ask Emacs for the C-c prefix, so that which-key explains it.
The key is put in `unread-command-events' rather than pressed: the command
loop reads it exactly as it reads a typed prefix, and `heks/demo--cancel'
sends the C-g that leaves the prefix."
  (heks/demo--forget-keys)
  (setq unread-command-events (list ?\C-c)))

(defun heks/demo--cancel ()
  "Leave the prefix `heks/demo--which-key' started.
The C-g is read by the command loop after this step is over, and keycast
records it then; the display is blanked a moment later, while the next scene
is opening."
  (setq unread-command-events (list ?\C-g))
  (run-with-timer
   0.4 nil
   (lambda ()
     (heks/demo--forget-keys)
     ;; C-g leaves "C-c is undefined" in the echo area; say what C-c means
     ;; instead.
     (message "%s" (if (boundp 'heks/key-root-description)
                        heks/key-root-description
                      "heks-emacs"))))
  ;; The C-g is read a little after this step, and keycast records it then;
  ;; blank the display once more after it has been seen.
  (run-with-timer 1.4 nil #'heks/demo--forget-keys))

(defun heks/demo--shell ()
  "Show the shell sample served by bash-language-server.
`eglot-ensure' waits for the next command before connecting, and a tour is
all timers: starting the server the way M-x eglot does keeps it immediate."
  (heks/demo--open "docs/demo/samples/tour.sh" "printf")
  (unless (ignore-errors (eglot-current-server))
    (when (fboundp 'eglot) (call-interactively #'eglot))))

(defun heks/demo--hover ()
  "Ask for the documentation of the symbol at point, in a window."
  (heks/demo--open "docs/demo/samples/tour.sh" "printf")
  (heks/demo--call 'heks/hover-open))

(defun heks/demo--diagnostics ()
  "Show the Flymake findings of the shell sample, on their own."
  (heks/demo--open "docs/demo/samples/tour.sh")
  (when-let* ((doc (get-buffer "*heks-hover-doc*"))
              (window (get-buffer-window doc)))
    (quit-window nil window))
  (delete-other-windows)
  (heks/demo--call 'flymake-show-buffer-diagnostics))

(defun heks/demo--dired ()
  "Show the modules as files, with their icons."
  (delete-other-windows)
  (dired (heks/demo--file "src/modules"))
  (dired-hide-details-mode 1))

(defun heks/demo--start ()
  "Open the dashboard the configuration starts with, at working size."
  ;; Anything still queued from before the tour -- a C-g that was never read,
  ;; say -- belongs to the session before it, not to the film.
  (setq unread-command-events nil)
  (delete-other-windows)
  (heks/demo--forget-keys)
  (heks/demo--scale "small")
  (heks/demo--call 'welkomscherm))

(defun heks/demo--finish ()
  "Say the name, on the README, at the end of the tour."
  (heks/demo--open "README.org" "\\* See it move")
  (with-current-buffer (window-buffer (selected-window))
    (when (fboundp 'org-fold-show-all) (org-fold-show-all))
    (recenter 0))
  (message "heks-emacs"))

;;;
;;; The tour
;;;

(defun heks/demo--steps ()
  "Return the tour as a list of (SECONDS-AFTER-START . THUNK).

The seconds accumulate as the list is built, so a step is written as the
pause before it: `(cue 2.4 ...)' means \"2.4 seconds after the one before\".
That keeps the story readable and the rhythm in one column."
  (let ((at 0.0)
        (steps nil))
    (cl-flet ((cue (seconds thunk)
                   (setq at (+ at seconds))
                   (push (cons at thunk) steps)))
      (cue 0.2 #'heks/demo--start)

      ;; The README, then its headlines alone: what Org folding is for.
      (cue 2.4 (lambda () (heks/demo--open "README.org")))
      (cue 2.0 (lambda ()
                 (with-current-buffer (window-buffer (selected-window))
                   (org-content 2)
                   (recenter 0)
                   (message nil))))

      ;; C-c, explained while it is being typed, then let go of.  The C-g
      ;; gets a step of its own: it is read by the command loop between two
      ;; timers, and never while a file is being opened.
      (cue 1.8 #'heks/demo--which-key)
      (cue 1.6 #'heks/demo--cancel)

      ;; Emacs Lisp: one of the modules, at the function that renders a
      ;; document.
      (cue 1.0 (lambda ()
                 (heks/demo--open "src/modules/render.el"
                                  "defun heks/render-document")))

      ;; Markdown beside its rendering.
      (cue 2.8 (lambda ()
                 (heks/demo--beside "test/fixtures/render-note.md"
                                    'heks/preview)))

      ;; An OpenAPI specification read as a specification, next to the YAML.
      (cue 3.2 (lambda ()
                 (heks/demo--beside "test/fixtures/render-petstore.yaml"
                                    'heks/openapi-view
                                    (lambda () (heks/demo--call 'heks/openapi-mode)))))

      ;; The same API as JSON: a different file, a different tree.
      (cue 2.8 (lambda ()
                 (heks/demo--open "test/fixtures/render-petstore.json")))

      ;; Shell: the language server, then its hover documentation and its
      ;; Flymake findings.
      (cue 1.8 #'heks/demo--shell)
      (cue 3.0 #'heks/demo--hover)
      (cue 3.0 #'heks/demo--diagnostics)

      ;; Files, as files.
      (cue 2.2 #'heks/demo--dired)

      ;; Five palettes over the same Elisp, so the difference is the theme.
      (cue 2.2 (lambda () (heks/demo--open "src/modules/ui.el")))
      (dolist (theme heks/demo--themes)
        (cue 1.7 (let ((theme theme))
                   (lambda () (heks/demo--theme theme)))))

      ;; Every text size the configuration binds, ending at the working one.
      (dolist (command heks/demo--scale-commands)
        (cue 1.15 (let ((command command))
                    (lambda () (heks/demo--call command)))))

      ;; And the name, on the README.
      (cue 2.2 #'heks/demo--finish))
    (nreverse steps)))

;;;
;;; Playing it
;;;

(defun heks/demo--restore ()
  "Put back the layout, the palettes and the text size from before the tour."
  (when (window-configuration-p heks/demo--saved-windows)
    (set-window-configuration heks/demo--saved-windows))
  (when (and heks/demo--saved-scale (boundp 'tekengrootte-scale))
    (setq tekengrootte-scale heks/demo--saved-scale)
    (when (fboundp 'heks/refresh-faces) (heks/refresh-faces)))
  (when heks/demo--saved-theme
    (mapc #'disable-theme custom-enabled-themes)
    (dolist (theme heks/demo--saved-theme)
      (ignore-errors (load-theme theme t))))
  (set-frame-parameter nil 'alpha-background heks/demo--saved-alpha))

;;;###autoload
(defun heks/demo-stop ()
  "Cancel a tour `heks/demo-play' has scheduled, and put the frame back."
  (interactive)
  (mapc #'cancel-timer heks/demo--timers)
  (setq heks/demo--timers nil)
  (heks/demo--restore))

;;;###autoload
(defun heks/demo-play ()
  "Play the scripted tour; see the Commentary of this file.
The tour uses one window; the layout from before, the palettes and the text
size are restored when it ends."
  (interactive)
  (heks/demo-stop)
  (setq heks/demo--saved-windows (current-window-configuration)
        heks/demo--saved-theme custom-enabled-themes
        heks/demo--saved-scale (and (boundp 'tekengrootte-scale)
                                    tekengrootte-scale)
        heks/demo--saved-alpha (frame-parameter nil 'alpha-background)
        heks/demo--timers nil)
  ;; Film the configuration's own colours, not those colours blended with
  ;; whatever is behind the frame.
  (set-frame-parameter nil 'alpha-background 100)
  (let ((steps (heks/demo--steps)))
    (dolist (step steps)
      (push (run-at-time (car step) nil
                         (lambda (thunk)
                           (condition-case err (funcall thunk)
                             (error (message "demo step failed: %S" err))))
                         (cdr step))
            heks/demo--timers))
    ;; Leave the last frame on screen for a while, then hand the Emacs back.
    ;; A recording is stopped inside that pause, not after the restore.
    (push (run-at-time (+ (car (car (last steps))) 8.0) nil #'heks/demo--restore)
          heks/demo--timers)))

(provide 'heks-demo)

;;; demo.el ends here
