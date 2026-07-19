;;; eglot.el --- Eglot configuration for Emacs -*- lexical-binding: t -*-

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

;; Eglot configuration for Emacs

;;; Code:

(use-package eglot
  :ensure nil
  :hook ((scala-ts-mode . eglot-ensure)
         (sh-mode . eglot-ensure)
         (haskell-mode . eglot-ensure)
         (markdown-mode . eglot-ensure)
         (markdown-ts-mode . eglot-ensure)
         (nix-ts-mode . eglot-ensure)
         (go-mode . eglot-ensure)
         (python-mode . eglot-ensure)
         (rust-mode . eglot-ensure)
         (html-mode . eglot-ensure)
         (css-mode . eglot-ensure)
         (css-ts-mode . eglot-ensure)
         (html-ts-mode . eglot-ensure)
         (js-mode . eglot-ensure)
         (js-ts-mode . eglot-ensure)
         (kotlin-ts-mode . eglot-ensure)
         (yaml-mode . eglot-ensure)
         (yaml-ts-mode . eglot-ensure)
         (before-save . eglot-format-buffer))
  :bind (("C-c i i" . eglot-find-implementation)
         ("C-c i e" . eglot)
         ("C-c i k" . eglot-shutdown-all)
         ("C-c i r" . eglot-rename)
         ("C-c i x" . eglot-reconnect)
         ("C-c i a" . eglot-code-actions)
         ("C-c i m" . eglot-menu)
         ("C-c i f" . eglot-format-buffer)
         ("C-c i h" . eglot-inlay-hints-mode))
  :init
  (setq eglot-autoshutdown t
        eglot-confirm-server-edits nil
        eglot-report-progress t
        eglot-extend-to-xref t
        eglot-sync-connect 1
        eglot-connect-timeout 60
        eglot-autoreconnect t)
  :config
  (setopt eglot-code-action-indications nil)                   ;; EMACS-31
  (setq eglot-server-programs (assq-delete-all 'scala-mode eglot-server-programs))
  (setq eglot-server-programs (assq-delete-all 'scala-ts-mode eglot-server-programs))

  (setq eglot-server-programs (assoc-delete-all 'scala-ts-mode eglot-server-programs))

  (add-to-list 'eglot-server-programs `(scala-ts-mode . ("metals"
                                                         "-Xmx4G"
                                                         "-XX:+UseZGC"
                                                         "-Dmetals.http=true"
                                                         :initializationOptions (:isHttpEnabled t))))

  (add-to-list 'eglot-server-programs '(nix-ts-mode . ("nil")))

  (setq eglot-server-programs (assoc-delete-all 'kotlin-ts-mode eglot-server-programs))
  (add-to-list 'eglot-server-programs '(kotlin-ts-mode . ("intellij-server" "--stdio")))

  (add-to-list 'eglot-server-programs '(markdown-mode . ("marksman")))

  (setq-default eglot-workspace-configuration
                '(
                  :metals ( :autoImportBuild "all"
                            :isHttpEnabled t
                            :superMethodLensesEnabled t
                            :showInferredType t
                            :enableSemanticHighlighting t
                            :inlayHints ( :inferredTypes (:enable t )
                                          :implicitArguments (:enable nil)
                                          :implicitConversions (:enable nil )
                                          :typeParameters (:enable t )
                                          :hintsInPatternMatch (:enable nil ))
                            :bloopJvmProperties ["-Xmx4G"])
                  :haskell (:formattingProvider "ormolu")
                  :typescript (:format (:baseIndentSize 0
                                                        :convertTabsToSpaces t
                                                        :indentSize 2
                                                        :semicolons "remove"
                                                        :tabSize 2))
                  :javascript (:format (:baseIndentSize 0
                                                        :convertTabsToSpaces t
                                                        :indentSize 2
                                                        :semicolons "remove"
                                                        :tabSize 2))
                  :rust-analyzer (:check (:command "clippy")
                                         :cargo (:sysroot "discover"
                                                          :features "all"
                                                          :buildScripts (:enable t))
                                         :diagnostics (:disabled ["macro-error"])
                                         :procMacro (:enable t))

                  :yaml ( :format (:enable t)
                          :validate t
                          :hover t
                          :completion t
                          :schemas (
                                    https://codeberg.org/jjba23/pop-test/raw/branch/trunk/resources/json-schema/pop-test.json ["golden-test.yaml" "golden-test.yml" "pop-test.yaml" "pop-test.yml"]
                                    https://raw.githubusercontent.com/Vandebron/gh-mpyl/refs/heads/main/src/mpyl/schema/project.schema.yml ["project.yml"]
                                    https://json.schemastore.org/yamllint.json ["/*.yml"])
                          :schemaStore (:enable t))
                  :nil (:formatting (:command ["nixfmt"]))))

  (add-hook 'eglot-managed-mode-hook
            (lambda ()
              ;; Show flymake diagnostics first.
              (setq eldoc-documentation-functions
                    (cons #'flymake-eldoc-function
                       (remove #'flymake-eldoc-function eldoc-documentation-functions)))
              ;; Show all eldoc feedback.
              (setq eldoc-documentation-strategy #'eldoc-documentation-compose)))

  (defun heks/eglot-uri-to-path-kotlin (orig-fn uri &rest args)
    (if (and (stringp uri) (string-prefix-p "jar:///" uri))
        (apply orig-fn (replace-regexp-in-string "^jar:///" "jar:file:///" uri) args)
      (apply orig-fn uri args)))

  (defun heks/eglot-path-to-uri-kotlin (orig-fn path &rest args)
    (if (and (stringp path) (string-prefix-p "jar:file:///" path))
        (replace-regexp-in-string "^jar:file:///" "jar:///" path)
      (apply orig-fn path args)))

  (if (fboundp 'eglot-uri-to-path)
      (progn
        (advice-add 'eglot-uri-to-path :around #'heks/eglot-uri-to-path-kotlin)
        (advice-add 'eglot-path-to-uri :around #'heks/eglot-path-to-uri-kotlin))
    (progn
      (advice-add 'eglot--uri-to-path :around #'heks/eglot-uri-to-path-kotlin)
      (advice-add 'eglot--path-to-uri :around #'heks/eglot-path-to-uri-kotlin)))


  (defun my-jsonrpc-request-kotlin-fix (orig-fn connection method params &rest args)
    "Fix kotlin-lsp empty newText bug by removing textEdit to trigger Eglot fallback."
    (let ((result (apply orig-fn connection method params args)))
      (when (and (eq method :textDocument/completion)
                 (derived-mode-p 'kotlin-mode 'kotlin-ts-mode)
                 result)
        (let ((items (if (vectorp result) result (plist-get result :items))))
          (seq-do (lambda (item)
                    (let ((text-edit (plist-get item :textEdit)))
                      ;; If the server sent an empty newText, strip textEdit completely
                      ;; so Eglot falls back to replacing the actual prefix.
                      (when (and text-edit (equal (plist-get text-edit :newText) ""))
                        (plist-put item :textEdit nil))))
                  items)))
      result))

  (defun my-jsonrpc-async-request-kotlin-fix (orig-fn connection method params &rest args)
    "Fix kotlin-lsp empty newText bug in asynchronous Eglot requests."
    (if (and (eq method :textDocument/completion)
             (derived-mode-p 'kotlin-mode 'kotlin-ts-mode))
        (let* ((orig-success (plist-get args :success-fn))
               (new-success (lambda (result)
                              (let ((items (if (vectorp result) result (plist-get result :items))))
                                (seq-do (lambda (item)
                                          (let ((text-edit (plist-get item :textEdit)))
                                            (when (and text-edit (equal (plist-get text-edit :newText) ""))
                                              (plist-put item :textEdit nil))))
                                        items))
                              (funcall orig-success result)))
               (new-args (plist-put (copy-sequence args) :success-fn new-success)))
          (apply orig-fn connection method params new-args))
      (apply orig-fn connection method params args)))

  (advice-add 'jsonrpc-request :around #'my-jsonrpc-request-kotlin-fix)
  (advice-add 'jsonrpc-async-request :around #'my-jsonrpc-async-request-kotlin-fix)

  (setq python-flymake-command '("~/.local/bin/flake8" "-") )
  (add-hook 'eglot-managed-mode-hook
            (lambda ()
              (when (or (derived-mode-p 'python-mode)
                        (derived-mode-p 'python-ts-mode))
                (add-hook 'flymake-diagnostic-functions
                          'python-flymake nil t)
                (flymake-start)))))

(use-package eglot-java
  :ensure t
  :after (eglot)
  :hook ((java-mode . eglot-java-mode)
         (java-ts-mode . eglot-java-mode)))

(use-package jarchive
  :ensure t
  :config
  (jarchive-mode))

(provide 'heks-emacs/eglot)

;;; eglot.el ends here
