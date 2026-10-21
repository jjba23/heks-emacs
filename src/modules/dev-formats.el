;;; dev-formats.el --- Data formats, JVM languages and debugging -*- lexical-binding: t -*-

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

;; Data formats, JVM languages and debugging.

;;; Code:

;; Configures Emacs for editing JSON files, providing
;; syntax highlighting and formatting.
(use-package json-mode
  :ensure (:host github :repo "json-emacs/json-mode"))

;; Provides interactive ways for working with
;; OpenAPI/Swagger specifications from Emacs.
(use-package swagg
  :ensure (:host github :repo "isamert/swagg.el"))

(use-package format-all
  :ensure t
  ;; No keys: formatting is `C-c i f' everywhere, and this is the last
  ;; resort that key falls back to when the buffer has no language server
  ;; and no language-specific formatter.  The commands are kept in the
  ;; autoloads, because the dispatcher decides at call time.
  :commands (format-all-region-or-buffer format-all-buffer format-all-mode)
  :config
  (setq-default format-all-formatters
                '(("CSS"     (prettierd))
                  ("HTML" (prettierd)))))

(use-package just-mode
  :ensure t)

(use-package justl
  :ensure t)

;;
;; ====== JVM: Java, Kotlin, Maven, Gradle and Spring ======
;;

;; Kotlin through Tree-sitter.  The `.kts' association also covers the
;; Gradle Kotlin DSL files (`build.gradle.kts', `settings.gradle.kts').
(use-package kotlin-ts-mode
  :ensure t
  :mode (("\\.kt\\'" . kotlin-ts-mode)
         ("\\.kts\\'" . kotlin-ts-mode)))

;; Groovy is the language of classic Gradle build scripts and of
;; Jenkinsfiles, both of which are plain Groovy with a declarative shape.
(use-package groovy-mode
  :ensure t
  :mode (("\\.gradle\\'" . groovy-mode)
         ("\\`Jenkinsfile\\'" . groovy-mode)
         ("\\`Jenkinsfile\\..+\\'" . groovy-mode)))

;; `pom.xml' already opens in nxml-mode (XML files carrying a declaration
;; are detected through `magic-mode-alist'), so what is left is Maven's own
;; four-space indentation, applied buffer-locally.
(defun heks-emacs-pom-xml-setup ()
  "Apply Maven conventions when visiting a `pom.xml' file.

Besides the indentation this folds elements with Hideshow, shows a
fringe indicator for each foldable element, and starts the XML language
server (`lemminx') when it is installed, which is what checks the file
against the Maven schema."
  (when (and buffer-file-name
             (string= "pom.xml" (file-name-nondirectory buffer-file-name)))
    (setq-local nxml-child-indent 4)
    (setq-local nxml-attribute-indent 4)
    (setq-local tab-width 4)
    (setq-local indent-tabs-mode nil)
    (require 'hideshow)
    (setq-local hs-show-indicators t)
    (hs-minor-mode 1)
    (when (executable-find "lemminx")
      (eglot-ensure))))

(add-to-list 'auto-mode-alist '("pom\\.xml\\'" . nxml-mode))
(add-hook 'nxml-mode-hook #'heks-emacs-pom-xml-setup)

;; Spring Boot configuration lives either in `application*.properties'
;; (already handled by `conf-javaprop-mode') or in `application*.yml',
;; which the YAML mode above takes care of.

(use-package pandoc-mode :ensure t)

;; `dape' is the client; it needs a real DAP server to drive, which for a
;; JVM project is the `java-debug' adapter that `heks-emacs-jvm-debug'
;; (see `heks-emacs.el') runs and attaches to -- see
;; `heks-emacs-java-debug-jar' for where that jar comes from.
(use-package dape
  :ensure t
  :init (setq dape-buffer-window-arrangement 'right)
  ;; `C-c j d' starts and attaches a JVM project's debugger
  ;; (`heks-emacs-jvm-debug'); `C-c b' is `dape''s own commands once
  ;; attached -- to any debuggee, JVM or otherwise, which is why it is its
  ;; own topic rather than folded into `j'.
  :bind (("C-c j d" . heks-emacs-jvm-debug)
         ("C-c b b" . dape-breakpoint-toggle)
         ("C-c b c" . dape-continue)
         ("C-c b n" . dape-next)
         ("C-c b i" . dape-step-in)
         ("C-c b o" . dape-step-out)
         ("C-c b r" . dape-repl)
         ("C-c b k" . dape-kill)))

(use-package graphql-mode
  :ensure t
  :mode ("\\.graphql\\'" "\\.graphqls\\'"))

(provide 'heks-emacs/dev-formats)

;;; dev-formats.el ends here
