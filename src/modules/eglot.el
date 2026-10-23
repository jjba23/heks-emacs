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

;; Global toggle of Eglot
(setopt eglot-enabled-p t)

(defun heks/eglot-enable ()
  (interactive)
  (setopt eglot-enabled-p t))
(defun heks/eglot-disable ()
  (interactive)
  (setopt eglot-enabled-p nil)
  (eglot-shutdown-all))
(defun heks/eglot-ensure ()
  (if eglot-enabled-p (eglot-ensure) nil))

(defun heks/eglot-format-before-save ()
  "Format with Eglot, only where a live server manages this buffer."
  (when (and (fboundp 'eglot-managed-p) (eglot-managed-p)
             (ignore-errors (eglot-current-server)))
    (eglot-format-buffer)))

(use-package eglot
  :ensure nil
  :hook ((scala-ts-mode . heks/eglot-ensure)
         ;; Both of the modes Emacs opens a shell script in: `bash-ts-mode'
         ;; is what a `.sh' file gets when the bash grammar is built, and
         ;; `sh-mode' is what it falls back to (and what a `.ksh' or `.zsh'
         ;; file always gets).  The server completes and explains the
         ;; script; it does not check it -- see the `:bashIde' section of
         ;; `eglot-workspace-configuration' below -- because `shellcheck'
         ;; is run for every shell buffer by `sh-shellcheck-flymake'.
         ((sh-mode bash-ts-mode) . heks/eglot-ensure)
         (haskell-mode . heks/eglot-ensure)
         (markdown-mode . heks/eglot-ensure)
         (markdown-ts-mode . heks/eglot-ensure)
         (nix-ts-mode . heks/eglot-ensure)
         (go-mode . heks/eglot-ensure)
         (python-mode . heks/eglot-ensure)
         (rust-mode . heks/eglot-ensure)
         (html-mode . heks/eglot-ensure)
         (c-mode . heks/eglot-ensure)
         (c-ts-mode . heks/eglot-ensure)
         (css-mode . heks/eglot-ensure)
         (css-ts-mode . heks/eglot-ensure)
         (html-ts-mode . heks/eglot-ensure)
         (js-mode . heks/eglot-ensure)
         (js-ts-mode . heks/eglot-ensure)
         (kotlin-ts-mode . heks/eglot-ensure)
         (yaml-mode . heks/eglot-ensure)
         (yaml-ts-mode . heks/eglot-ensure)
         (before-save . heks/eglot-format-before-save))
  ;; `g' goes to the implementation and `k' shuts the server down, so that
  ;; both are the letters they are everywhere else; `x' used to reconnect
  ;; it, which is not what `x' means (running a script), and is now the
  ;; `R' that restarts the REPL one topic down.
  :bind (("C-c i g" . eglot-find-implementation)
         ("C-c i e" . eglot)
         ("C-c i k" . eglot-shutdown-all)
         ("C-c i 1" . heks/eglot-enable)
         ("C-c i 0" . heks/eglot-disable)
         ("C-c i r" . eglot-rename)
         ("C-c i R" . eglot-reconnect)
         ("C-c i a" . eglot-code-actions)
         ("C-c i m" . eglot-menu)
         ("C-c i E" . eglot-events-buffer)
         ("C-c i s" . heks/yaml-insert-schema-modeline)
         ;; No `C-c i f' here: formatting is `heks/format-buffer',
         ;; which asks Eglot when a server manages the buffer and the
         ;; language's own formatter when it does not.
         ("C-c i h" . eglot-inlay-hints-mode))
  :init
  (setq eglot-autoshutdown t
        eglot-confirm-server-edits nil
        ;; Suppress mode-line progress animations
        eglot-report-progress nil
        eglot-extend-to-xref t
        eglot-sync-connect 0
        eglot-connect-timeout 60
        eglot-autoreconnect t)
  :config
  ;; Disable event logging completely (Emacs >= 30)
  (setq eglot-events-buffer-config '(:size 0 :format short))
  ;; For Emacs <= 29
  ;; (setq eglot-events-buffer-size 0)

  ;; Disabling the JSON-RPC event hook also avoids serializing JSON payloads:
  ;;The tradeoff is that disabling the JSON-RPC event hook (jsonrpc-event-hook) removes useful debugging information.
  (setq jsonrpc-event-hook nil)

  ;; Disable automatic code action indicators to reduce background polling
  (setq eglot-code-action-indications nil)
  (setq eglot-server-programs (assq-delete-all 'scala-mode eglot-server-programs))
  (setq eglot-server-programs (assq-delete-all 'scala-ts-mode eglot-server-programs))

  (setq eglot-server-programs (assoc-delete-all 'scala-ts-mode eglot-server-programs))

  (add-to-list 'eglot-server-programs `(scala-ts-mode . ("metals"
                                                         "-Xmx4G"
                                                         "-XX:+UseZGC"
                                                         "-Dmetals.http=true"
                                                         :initializationOptions (:isHttpEnabled t))))

  (add-to-list 'eglot-server-programs '(nix-ts-mode . ("nil")))

  ;; --- Kotlin ---
  ;; JetBrains' Kotlin LSP ships as `bin/intellij-server' in its release
  ;; archive; the community `kotlin-language-server' is the fallback for
  ;; setups that do not have it.  Resolving this at connect time means the
  ;; right server is used whichever one is installed.
  (defun heks/eglot-kotlin-server (&rest _)
    "Return the command of the best available Kotlin language server.

Eglot calls the function stored in `eglot-server-programs' with the
INTERACTIVE flag and any further contact arguments (see the docstring of
`eglot-server-programs'), not with no arguments at all; the `&rest _'
here is what absorbs them, since this particular resolution does not
depend on either of them."
    (cond ((executable-find "intellij-server") '("intellij-server" "--stdio"))
          ((executable-find "kotlin-lsp") '("kotlin-lsp" "--stdio"))
          ((executable-find "kotlin-language-server") '("kotlin-language-server"))
          (t '("intellij-server" "--stdio"))))

  (setq eglot-server-programs (assoc-delete-all 'kotlin-ts-mode eglot-server-programs))
  (setq eglot-server-programs (assoc-delete-all 'kotlin-mode eglot-server-programs))
  (add-to-list 'eglot-server-programs
               (cons '(kotlin-mode kotlin-ts-mode) #'heks/eglot-kotlin-server))

  (add-to-list 'eglot-server-programs '(markdown-mode . ("marksman")))

  ;; --- Terraform / HCL ---
  ;; `terraform-ls' provides completion, validation and hover for the
  ;; Terraform and HCL major modes.
  (add-to-list 'eglot-server-programs '(terraform-mode . ("terraform-ls" "serve")))

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

                  ;; --- YAML: which schema a file is checked against ---
                  ;; The language server reads `yaml.schemas' as an object
                  ;; from a schema to the files it applies to, keyed by the
                  ;; schema's own URL; `kubernetes' is the one name the
                  ;; server resolves itself, and it is what makes a
                  ;; manifest complete inside its `kind'.  A key here has
                  ;; to be a symbol -- Emacs's JSON writer refuses a string
                  ;; -- which is why no URL below contains a fragment.
                  ;;
                  ;; Two things are deliberately absent.  A Helm chart's
                  ;; `values.yaml' has no schema anybody can write, because
                  ;; its keys are the chart's own; it is checked against
                  ;; the `values.schema.json' the chart ships, named in the
                  ;; file itself.  And `schemaStore' already knows the
                  ;; files that have a schema by name, Woodpecker pipelines
                  ;; among them, so only what it cannot know is spelled out
                  ;; here.  Both gaps are what `C-c i s' fills in for one
                  ;; file at a time.
                  :yaml ( :format (:enable t)
                          :validate t
                          :hover t
                          :completion t
                          :schemas (
                                    https://codeberg.org/jjba23/pop-test/raw/branch/trunk/resources/json-schema/pop-test.json ["golden-test.yaml" "golden-test.yml" "pop-test.yaml" "pop-test.yml"]
                                    https://json.schemastore.org/yamllint.json [".yamllint" ".yamllint.yml" ".yamllint.yaml"]
                                    kubernetes ["**/k8s/**/*.yaml" "**/manifests/**/*.yaml" "!**/k8s/**/values.yaml" "!**/k8s/**/kustomization.yaml"]
                                    https://spec.openapis.org/oas/3.2/schema/2026-08-30 ["openapi.yaml" "openapi.yml" "**/openapi.yaml" "**/openapi.yml" "**/*-openapi.yaml" "**/*-openapi.yml"]
                                    https://json.schemastore.org/github-workflow.json ["**/.github/workflows/*.yml" "**/.github/workflows/*.yaml"]
                                    https://raw.githubusercontent.com/compose-spec/compose-spec/main/schema/compose-spec.json ["compose.yaml" "compose.yml" "docker-compose.yaml" "docker-compose.yml" "**/compose.yaml" "**/docker-compose.yml"]
                                    https://gitlab.com/gitlab-org/gitlab/-/raw/master/app/assets/javascripts/editor/schema/ci.json ["**/.gitlab-ci.yml" "**/.gitlab-ci.yaml"]
                                    https://json.schemastore.org/woodpecker.json ["**/.woodpecker/*.yml" "**/.woodpecker/*.yaml"])
                          :schemaStore (:enable :json-false))
                  :nil (:formatting (:command ["nixfmt"]))

                  ;; --- Shell: what the server is for ---
                  ;; bash-language-server is kept for what it knows about a
                  ;; script that is not a diagnostic: completion of the
                  ;; variables, functions and options it parses, hover, the
                  ;; symbols of a file, going to a definition, its
                  ;; references and a rename.  Its own two tools are turned
                  ;; off in it, because the branch that runs them is not the
                  ;; only one: it lints with shellcheck, and Emacs's own
                  ;; `sh-shellcheck-flymake' already checks every shell
                  ;; buffer (see `shell.el'); it formats with shfmt, and
                  ;; this configuration already formats one -- with the
                  ;; arguments it was given, from the drift it reports to
                  ;; `C-c i f'.  An empty `shellcheckPath' and an empty
                  ;; `shfmt.path' are the server's own way of saying "do not
                  ;; lint" and "do not format", and leaving either on would
                  ;; report every problem on a line twice, or quietly
                  ;; reformat a script on save in a style the formatter that
                  ;; is configured here would then report as drift.
                  :bashIde (:shellcheckPath ""
                            :shfmt (:path ""))

                  ;; --- XML: which schema a file is checked against ---
                  ;; lemminx reads `xml.fileAssociations' as a list of
                  ;; (pattern, systemId) pairs.  A pom that names its own
                  ;; schema in `xsi:schemaLocation' keeps that one; these are
                  ;; for the ones that do not, so every `pom.xml' gets
                  ;; completion, hover and validation from the Maven XSD.
                  :xml (:fileAssociations
                        [(:pattern "**/pom.xml"
                          :systemId "https://maven.apache.org/xsd/maven-4.0.0.xsd")
                         (:pattern "**/settings.xml"
                          :systemId "https://maven.apache.org/xsd/settings-1.2.0.xsd")
                         (:pattern "**/toolchains.xml"
                          :systemId "https://maven.apache.org/xsd/toolchains-1.1.0.xsd")]
                        :validation (:enabled t :noGrammar "hint")
                        :downloadExternalResources (:enabled t))))

  ;; `lemminx' (brew install lemminx) is the XML language server; nxml can
  ;; read a RELAX NG schema but not an XSD, which is what Maven publishes.
  (add-to-list 'eglot-server-programs '((nxml-mode xml-mode) . ("lemminx")))

  ;; --- YAML: the schema a file names for itself ---
  ;; What `yaml.schemas' above cannot cover is named by the file itself,
  ;; in a comment the language server reads:
  ;;
  ;;   # yaml-language-server: $schema=./values.schema.json
  ;;
  ;; `C-c i s' writes that line, and works out which schema to write: the
  ;; chart's own `values.schema.json' when the file sits beside one, and
  ;; otherwise the published schema of the OpenAPI version the file
  ;; declares, so that a 3.0 or 3.1 specification is not checked as a 3.2
  ;; one.  (3.2 is what `yaml.schemas' associates by name, because it is
  ;; the most modern version; a file can only be checked against one
  ;; schema at a time, so older files need this modeline.)
  (defconst heks/yaml-version-schemas
    '(("3.0" . "https://spec.openapis.org/oas/3.0/schema/2024-10-18")
      ("3.1" . "https://spec.openapis.org/oas/3.1/schema/2026-08-03")
      ("3.2" . "https://spec.openapis.org/oas/3.2/schema/2026-08-30"))
    "The published schema of each OpenAPI version, by its `openapi' field.

The date in a URL is how the OpenAPI Initiative identifies a schema
revision, and the ones here are the current revisions of each version;
`https://spec.openapis.org/oas/' is where they are listed.")

  (defun heks/yaml--declared-version ()
    "Return the OpenAPI version this buffer declares, like \"3.1\", or nil."
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward
             "^[ \t]*openapi:[ \t]*[\"']?\\([0-9]+\\.[0-9]+\\)" 4000 t)
        (match-string 1))))

  (defun heks/yaml-schema-for-file ()
    "Return the schema this YAML file should name for itself, or nil.

A `values.yaml' is validated by the `values.schema.json' that sits beside
it, which is Helm's own convention and the only schema a chart's values
can have.  An OpenAPI specification is validated by the schema of the
version it declares."
    (let ((directory (and buffer-file-name (file-name-directory buffer-file-name))))
      (or (when (and directory
                     (file-exists-p (expand-file-name "values.schema.json" directory)))
            "./values.schema.json")
          (cdr (assoc (heks/yaml--declared-version)
                      heks/yaml-version-schemas)))))

  (defun heks/yaml-insert-schema-modeline (schema)
    "Insert the comment that tells the YAML language server which SCHEMA to use.

Interactively SCHEMA is worked out from the file itself, with a prompt
only when the file says nothing: a chart's `values.schema.json' beside a
`values.yaml', or the published schema of a specification's version.  The
line goes at the top of the file, and replaces one that is already
there."
    (interactive (list (or (heks/yaml-schema-for-file)
                           (read-string "Schema URL or path: "))))
    (unless (derived-mode-p 'yaml-mode 'yaml-ts-mode)
      (user-error "This is a %s buffer, and the line is for a YAML one" major-mode))
    (let ((line (format "# yaml-language-server: $schema=%s" schema)))
      (save-excursion
        (goto-char (point-min))
        (if (re-search-forward "^# yaml-language-server: \\$schema=" nil t)
            (progn (beginning-of-line) (kill-line) (insert line))
          (insert line "\n")))
      (message "The language server will check this file against %s" schema)))

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


  (defun my/eglot-disable-metals-semantic-refresh (orig-fn server)
    (let* ((caps (funcall orig-fn server))
           (workspace (plist-get caps :workspace))
           (tokens (plist-get workspace :semanticTokens)))
      (when tokens
        (plist-put tokens :refreshSupport :json-false))
      caps))

  (advice-add 'eglot-client-capabilities :around #'my/eglot-disable-metals-semantic-refresh)

  ;; No language is named here for the Flymake backends a server would take
  ;; with it, which is what used to be written for Python alone.  Eglot
  ;; replaces `flymake-diagnostic-functions' with a list of its own backend
  ;; alone while it manages a buffer, and what the buffer had is put back for
  ;; every language at once by `heks/flymake-keep-backends' (see
  ;; `dev-flymake.el') -- Python's flake8 among them, registered by `python-base-mode'
  ;; itself, and the command it runs set in that module with it.  A server is
  ;; then language intelligence and never the reason a buffer stops being
  ;; checked.
  )

(use-package eglot-java
  :ensure t
  :after (eglot)
  :hook ((java-mode . eglot-java-mode)
         (java-ts-mode . eglot-java-mode))
  :config
  ;; `eglot-java' can be activated from its autoloads before the library
  ;; itself is loaded, in which case `eglot-java-mode-map' does not exist
  ;; yet; wait for the real load before touching its internals.
  (with-eval-after-load 'eglot-java
    ;; Bindings local to Java buffers using eglot-java; the global
    ;; `C-c j m/g/s' build commands (see `heks/maven-run' and
    ;; friends) keep working in every other buffer.
    (keymap-set eglot-java-mode-map "C-c j n" #'eglot-java-file-new)
    (keymap-set eglot-java-mode-map "C-c j r" #'eglot-java-run-main)
    (keymap-set eglot-java-mode-map "C-c j t" #'eglot-java-run-test)
    (keymap-set eglot-java-mode-map "C-c j N" #'eglot-java-project-new)
    (keymap-set eglot-java-mode-map "C-c j b" #'eglot-java-project-build-task)
    (keymap-set eglot-java-mode-map "C-c j B" #'eglot-java-project-build-refresh)

    ;; Ask Eclipse JDT LS to re-import Maven/Gradle projects automatically
    ;; when their build files change.  The function is called with the
    ;; server and the JDT LS version, hence the ignored arguments.
    (defun heks/eglot-java-init-opts (&rest _)
      "JDT LS initialization options for HEKS-EMACS."
      '(:settings (:java (:configuration (:updateBuildConfiguration "automatic")))))
    (setq eglot-java-user-init-opts-fn #'heks/eglot-java-init-opts)))

(use-package jarchive
  :ensure t
  :config
  (jarchive-mode))

(provide 'heks/eglot)

;;; eglot.el ends here
