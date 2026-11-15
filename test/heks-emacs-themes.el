;;; heks-emacs-themes.el --- Render the sample in every palette  -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; `heks/theme-gallery' renders one document in every palette the
;; configuration offers and writes the result as one HTML page.  This is
;; the batch entry point for it -- `maak themes' -- so the comparison is a
;; report a task makes rather than a key pressed in a running Emacs.
;;
;; The palettes are packages, and this batch Emacs has none of them on its
;; load path by default: the build directories Elpaca keeps are added
;; before the gallery reads `heks/themes', so a theme that is installed is
;; found and a theme that is not is skipped.
;;
;;   emacs -Q --batch -l test/heks-emacs-themes.el
;;   HEKS_THEMES_OUTPUT=/tmp/themes.html emacs -Q --batch -l test/heks-emacs-themes.el
;;
;; The modules are loaded from `src' by name with `use-package' stubbed
;; out, as the other checks load them: installing packages is not what is
;; being rendered.

;;; Code:

(setq load-prefer-newer t)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defconst heks-themes--source
  (file-name-as-directory
   (or (getenv "HEKS_THEMES_SOURCE")
       (expand-file-name "../src" (file-name-directory (file-truename load-file-name)))))
  "The directory holding the modules whose renderer writes the page.")

(defmacro use-package (&rest _)
  "Stand in for the macro that installs packages, which is not under test."
  nil)

(defun heks-themes--module (name)
  "Load the module NAME from the source tree and return its feature."
  (load (expand-file-name (format "modules/%s.el" name) heks-themes--source) nil t))

(dolist (module '("markdown" "heks-emacs" "render" "theme"))
  (heks-themes--module module))

;; Every installed palette is a file named `<theme>-theme.el' in a package
;; directory under Elpaca's builds.  A directory that holds one is a theme
;; package, and adding it to `custom-theme-load-path' is what lets
;; `load-theme' find the palette by name.  Every build directory is on
;; `load-path' as well, because a theme file requires the library it was
;; written in -- autothemer is what most of the Rosé Pine, Gruvbox and
;; Kaolin palettes are made with -- and that library is a build of its own.
(let ((builds (expand-file-name "~/.emacs.d/elpaca/builds/")))
  (when (file-directory-p builds)
    (dolist (directory (directory-files builds t "\\`[^.]"))
      (when (file-directory-p directory)
        (add-to-list 'load-path directory)
        (when (directory-files directory nil "-theme\\.el\\'")
          (add-to-list 'custom-theme-load-path directory))))))

(let ((output (or (getenv "HEKS_THEMES_OUTPUT")
                  (expand-file-name "reports/themes.html" default-directory))))
  (heks/theme-gallery output))

;;; heks-emacs-themes.el ends here
