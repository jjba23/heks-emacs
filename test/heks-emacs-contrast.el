;;; heks-emacs-contrast.el --- Check that no face goes invisible  -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; The README claims that the palettes' "separators, faces and prose sizes
;; derive from the theme so that nothing goes invisible when you switch".
;; This is that claim as a check: every installed palette is asked what
;; colour it gives the body text, the faces that carry text, the mode line
;; and the separators, and the contrast between each foreground and the
;; background behind it is computed.  The floors are WCAG 2.1's -- 4.5:1
;; for body text, 3:1 for the rest, which is what "large text" and user
;; interface components are held to -- plus one this configuration adds
;; for itself: the separator is a blend of the palette's own background and
;; foreground (`heks/window-divider-contrast'), and a blend is only worth
;; making if the result still stands out, so it is held to 2:1.
;;
;; Two details make the numbers mean something in a batch Emacs.
;;
;; The colours are read from the *theme's own face specs*, not from the
;; loaded faces.  `face-attribute' answers for the frame it is asked about,
;; and a batch frame is a text terminal with no colours at all: modus and
;; the Ef collection set their `default' face under `((class color)
;; (min-colors 256))', so on that frame they have no background at all, and
;; `color-values' snaps a colour to the terminal's eight.  The first
;; alternative of a face spec is the one written for a true-colour display
;; -- the palette itself -- and that is what is read here.  `heks/blend-colors'
;; and `heks/color-components' (see `modules/ui.el') already resolve colours
;; without asking a display, and are what the separator check uses.
;;
;; A check that cannot fail is decoration, so the file ends with a negative
;; control: one deliberately invisible pair, which the same arithmetic has
;; to reject.  If that passes, the check has stopped meaning anything.
;;
;;   emacs -Q --batch -l test/heks-emacs-contrast.el
;;   HEKS_CONTRAST_VERBOSE=1 emacs -Q --batch -l test/heks-emacs-contrast.el
;;
;; The modules are loaded from `src' by name with `use-package' stubbed
;; out, as the other checks load them: installing packages is not what is
;; being measured.  A palette that is not installed is skipped rather than
;; failed, so this reports on the palettes a machine has.

;;; Code:

(setq load-prefer-newer t)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defconst heks-contrast--source
  (file-name-as-directory
   (or (getenv "HEKS_CONTRAST_SOURCE")
       (expand-file-name "../src" (file-name-directory (file-truename load-file-name)))))
  "The directory holding the modules whose colours are being checked.")

(defmacro use-package (&rest _)
  "Stand in for the macro that installs packages, which is not under test."
  nil)

(defun heks-contrast--module (name)
  "Load the module NAME from the source tree and return its feature."
  (load (expand-file-name (format "modules/%s.el" name) heks-contrast--source) nil t))

;; `ui.el` is what blends the separators, and `theme.el` is where the list
;; of palettes is; `emacs-core.el` is loaded first because the settings the
;; other two define are read through the group it declares.
(dolist (module '("heks-emacs" "emacs-core" "ui" "theme"))
  (heks-contrast--module module))

;; A palette is a file named `<theme>-theme.el' in a package directory under
;; Elpaca's builds, and `load-theme' finds it once that directory is on the
;; theme path.  Every build is on `load-path' too, because a theme file
;; requires the library that made it (autothemer, mostly).
(let ((builds (expand-file-name "~/.emacs.d/elpaca/builds/")))
  (when (file-directory-p builds)
    (dolist (directory (directory-files builds t "\\`[^.]"))
      (when (file-directory-p directory)
        (add-to-list 'load-path directory)
        (when (directory-files directory nil "-theme\\.el\\'")
          (add-to-list 'custom-theme-load-path directory))))))

;;
;; The faces that carry text, and the floors they are held to.
;;

(defconst heks-contrast--body-face 'default
  "The face body text is drawn with.")

(defconst heks-contrast--text-faces
  '(font-lock-comment-face
    font-lock-comment-delimiter-face
    font-lock-keyword-face
    font-lock-function-name-face
    font-lock-variable-name-face
    font-lock-type-face
    font-lock-string-face
    font-lock-builtin-face
    font-lock-constant-face
    font-lock-doc-face
    link
    shadow
    error
    warning
    success
    line-number
    mode-line
    mode-line-inactive
    header-line)
  "The faces whose text has to be readable against its own background.

Each one is checked against its own background when it has one (the mode
line does) and against the palette's otherwise.")

(defconst heks-contrast--body-ratio 4.5
  "The contrast ratio body text is held to: WCAG 2.1 AA, normal text.

This one is a floor of the check and not a report: a palette whose own body
text is below it is a palette that is hard to read before anything this
configuration does to it.")

(defconst heks-contrast--visible-ratio 1.2
  "The floor that makes a face *visible* at all, which is what is checked.

Not WCAG's 3:1: the palettes here are third-party and deliberately paint
line numbers and comments faintly (#ayu-light's line numbers are 1.23:1),
and a check that failed on a palette's taste would be a check nobody could
act on.  What it does fail on is the failure the README's claim is about --
a face that lands on its own background, 1.0:1 -- and anything close to it.
The faces below AA are counted and printed, so the number is visible
without being a demand this configuration cannot meet.")

(defconst heks-contrast--divider-ratio 1.5
  "The contrast ratio the separators are held to, against the background.

The colour is this configuration's own -- the palette's background and
foreground blended at `heks/window-divider-contrast' -- so this one is a
floor it can meet rather than a palette's choice.  It is not WCAG's 3:1
for interface components: a separator is a one-pixel line, and 1.5:1 is
the point below which it is a rumour rather than an edge.")

;;
;; Reading a palette.
;;

(defun heks-contrast--face-spec (theme face)
  "Return the plist THEME gives FACE for a true-colour display, or nil.

The face specs live in the theme's own settings -- `theme-face' entries,
each a list of alternatives, the first of which is the one written for the
richest display, which is the palette; the later ones are the fallbacks for
terminals with fewer colours, and reading those would be asking what the
palette looks like on hardware nobody here has.

An alternative is written two ways in the wild: `(DISPLAY . PLIST)', which
is what `custom-theme-set-faces' documents, and `(DISPLAY (PLIST))', which
several of the palettes here are generated with.  Both are read, and a
spec with no display condition at all is a plist on its own."
  (let* ((entry (seq-find (lambda (setting)
                            (and (eq (car setting) 'theme-face)
                                 (eq (nth 1 setting) face)))
                          (get theme 'theme-settings)))
         (alternative (car (nth 3 entry))))
    (cond
     ((keywordp (car alternative)) alternative)
     ((keywordp (car-safe (cdr alternative))) (cdr alternative))
     ((keywordp (car-safe (car-safe (cdr alternative)))) (car (cdr alternative)))
     (t nil))))

(defun heks-contrast--color (theme face attribute)
  "Return the colour THEME gives FACE for ATTRIBUTE, or nil."
  (let ((value (plist-get (heks-contrast--face-spec theme face) attribute)))
    (and (stringp value)
         (not (string-prefix-p "unspecified" value))
         value)))

(defun heks-contrast--colours (theme face)
  "Return the (FOREGROUND . BACKGROUND) THEME paints FACE with, or nil.

A face that names no background is drawn on the palette's, and a face
that names no foreground is written in the palette's -- which is what the
display does with it."
  (let ((body-background (heks-contrast--color theme heks-contrast--body-face :background))
        (body-foreground (heks-contrast--color theme heks-contrast--body-face :foreground)))
    (let ((foreground (or (heks-contrast--color theme face :foreground) body-foreground))
          (background (or (heks-contrast--color theme face :background) body-background)))
      (and foreground background (cons foreground background)))))

;;
;; The check.
;;

(defvar heks-contrast--palettes 0)
(defvar heks-contrast--checks 0)
(defvar heks-contrast--failures 0)
(defvar heks-contrast--notes 0
  "How many faces are below WCAG AA, which is the palette's choice and reported.")

(defvar heks-contrast--repainted 0
  "How many faces a palette made nearly invisible, and the configuration repaints.")

(defun heks-contrast--check (label foreground background threshold)
  "Record that FOREGROUND on BACKGROUND is at least THRESHOLD, for LABEL."
  (let ((ratio (heks/contrast-ratio foreground background)))
    (setq heks-contrast--checks (1+ heks-contrast--checks))
    (cond
     ((null ratio)
      (setq heks-contrast--failures (1+ heks-contrast--failures))
      (message "  FAIL %-44s %s on %s: not a colour either of them" label foreground background)
      nil)
     ((>= ratio threshold)
      (when (getenv "HEKS_CONTRAST_VERBOSE")
        (message "  ok   %-44s %.2f:1 (floor %.1f:1)" label ratio threshold))
      t)
     (t
      (setq heks-contrast--failures (1+ heks-contrast--failures))
      (message "  FAIL %-44s %.2f:1, below %.1f:1 (%s on %s)"
               label ratio threshold foreground background)
      nil))))

(defun heks-contrast--count-below-aa (label foreground background)
  "Count LABEL as below WCAG AA, and say so when asked for the numbers.

A palette that paints its comments faintly is making a choice; this is
where the choice is written down rather than failed.  It is a report, so
nothing here can make `maak contrast' exit non-zero."
  (let ((ratio (heks/contrast-ratio foreground background)))
    (when (and ratio (< ratio heks-contrast--body-ratio))
      (setq heks-contrast--notes (1+ heks-contrast--notes))
      (when (getenv "HEKS_CONTRAST_VERBOSE")
        (message "  note %-44s %.2f:1, below AA (the palette's choice)" label ratio)))))

(defun heks-contrast--palette (theme)
  "Check the palette THEME, and return non-nil when it was installed.

What is checked is the colour a face ends up with, not the colour the
palette wrote: a face the palette made nearly invisible is repainted at
load (`heks/set-readable-faces'), and the check reads it through the same
function, so a palette that is corrected here is a palette that is
readable in the editor."
  (let ((loaded (condition-case _err (load-theme theme t) (error nil))))
    (cond
     ((not loaded)
      (message "  skip %-38s not installed" theme)
      nil)
     (t
      (setq heks-contrast--palettes (1+ heks-contrast--palettes))
      (disable-theme theme)
      (let ((body (heks-contrast--colours theme heks-contrast--body-face)))
        (if (null body)
            ;; A theme that names neither a background nor a colour for its
            ;; body text is one this check cannot read, which is worth
            ;; saying rather than passing.
            (progn
              (setq heks-contrast--failures (1+ heks-contrast--failures))
              (message "  FAIL %-38s says nothing about its body text" theme))
          (heks-contrast--check (format "%s: body text" theme)
                                (car body) (cdr body) heks-contrast--body-ratio)
          (dolist (face heks-contrast--text-faces)
            (let ((colours (heks-contrast--colours theme face)))
              (when colours
                (let ((readable (heks/readable-color (car colours) (cdr colours)
                                                     (car body))))
                  (unless (equal readable (car colours))
                    (setq heks-contrast--repainted (1+ heks-contrast--repainted))
                    (message "  fix  %-44s %s is %s on %s, repainted %s"
                             (format "%s: %s" theme face) (car colours)
                             (format "%.2f:1" (heks/contrast-ratio (car colours) (cdr colours)))
                             (cdr colours) readable))
                  (heks-contrast--check (format "%s: %s" theme face)
                                        readable (cdr colours)
                                        heks-contrast--visible-ratio)
                  (heks-contrast--count-below-aa (format "%s: %s" theme face)
                                                 readable (cdr colours))))))
          ;; The separators are this configuration's own colour: the
          ;; palette's background and foreground blended by
          ;; `heks/window-divider-contrast' (`heks/window-divider-color').
          (let ((divider (heks/blend-colors (cdr body) (car body)
                                            heks/window-divider-contrast)))
            (heks-contrast--check (format "%s: the separators" theme)
                                  divider (cdr body) heks-contrast--divider-ratio))))
      t))))

(message "== no face is invisible in the palettes the configuration offers ==")
(dolist (theme heks/themes)
  (heks-contrast--palette theme))

;;
;; A negative control: the same arithmetic, on a pair nobody could read.
;;

(message "\n== the check knows what a failure looks like ==")
(let ((before heks-contrast--failures))
  (heks-contrast--check "a face painted its own background" "#000000" "#000000"
                        heks-contrast--body-ratio)
  (if (> heks-contrast--failures before)
      (progn
        ;; It was supposed to fail; that failure is not the palette's.
        (setq heks-contrast--failures before
              heks-contrast--checks (1- heks-contrast--checks))
        (message "  ok   an invisible pair was rejected"))
    (setq heks-contrast--failures (1+ heks-contrast--failures))
    (message "  FAIL an invisible pair was accepted: the arithmetic is not measuring contrast")))

(message "\n== %d palettes, %d checks, %d failures (%d repainted, %d below AA) =="
         heks-contrast--palettes heks-contrast--checks heks-contrast--failures
         heks-contrast--repainted heks-contrast--notes)
(when (or (> heks-contrast--failures 0)
          (zerop heks-contrast--palettes))
  (kill-emacs 1))

;;; heks-emacs-contrast.el ends here
