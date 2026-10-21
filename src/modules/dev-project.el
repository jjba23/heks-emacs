;;; dev-project.el --- Project tooling, infrastructure and SQL -*- lexical-binding: t -*-

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

;; Project tooling, infrastructure and SQL.

;;; Code:

(use-package stripspace
  :ensure t
  :hook ((prog-mode . stripspace-local-mode)
         (text-mode . stripspace-local-mode)
         (conf-mode . stripspace-local-mode))

  :custom
  ;; The `stripspace-only-if-initially-clean' option:
  ;; - nil to always delete trailing whitespace.
  ;; - Non-nil to only delete whitespace when the buffer is clean initially.
  ;; (The initial cleanliness check is performed when `stripspace-local-mode'
  ;; is enabled.)
  (stripspace-only-if-initially-clean nil)

  ;; Enabling `stripspace-restore-column' preserves the cursor's column position
  ;; even after stripping spaces. This is useful in scenarios where you add
  ;; extra spaces and then save the file. Although the spaces are removed in the
  ;; saved file, the cursor remains in the same position, ensuring a consistent
  ;; editing experience without affecting cursor placement.
  (stripspace-restore-column t))

(use-package editorconfig
  :ensure nil
  :config
  (editorconfig-mode 1))

(use-package maak.el
  :ensure (:host codeberg :repo "jjba23/maak.el" :branch "trunk")
  :demand t
  :bind ("C-c m r" . maak-run-task))

(use-package meson-mode
  :ensure (:host github :repo "wentasah/meson-mode" :branch "master"))

;;
;; ====== Terraform and HCL ======
;;

;; Generic HCL: `.hcl' files (including `.terraform.lock.hcl') and Nomad jobs.
(use-package hcl-mode
  :ensure t
  :mode ("\\.hcl\\'" "\\.nomad\\'"))

(use-package terraform-mode
  :ensure t
  :mode (("\\.tf\\'" . terraform-mode)
         ("\\.tfvars\\'" . terraform-mode))
  :hook ((terraform-mode . heks-emacs-terraform-setup))
  :custom
  (terraform-indent-level 2)
  ;; The workflow, in the order it is run: `init' once, then `validate' and
  ;; `plan' as often as one likes, and `apply' when the plan is the one that
  ;; was wanted.  They live under the workspace topic because a Terraform
  ;; run is a project task, and they take the letters they take everywhere
  ;; else: `v' validates, `p' previews, `a' applies.
  :bind (("C-c w i" . heks-emacs-terraform-init)
         ("C-c w v" . heks-emacs-terraform-validate)
         ("C-c w p" . heks-emacs-terraform-plan)
         ("C-c w a" . heks-emacs-terraform-apply)
         ("C-c w D" . heks-emacs-terraform-destroy))
  :config
  ;; `terraform fmt' on save and `terraform-ls' over Eglot, both guarded on
  ;; the executable being available so that visiting a .tf file never
  ;; fails on a machine without the Terraform toolchain.
  (defun heks-emacs-terraform-setup ()
    "Enable Terraform formatter and language server when available."
    (when (executable-find terraform-command)
      (terraform-format-on-save-mode 1))
    (when (executable-find "terraform-ls")
      (heks/eglot-ensure))))

(defun heks-emacs-terraform-root ()
  "Return the directory the Terraform configuration lives in.

That is the project root when the file being edited is in one, and the
file's own directory otherwise, so that the commands work in a project
Emacs does not recognise as well."
  (or (when-let* ((project (project-current)))
        (project-root project))
      (and buffer-file-name (file-name-directory buffer-file-name))
      default-directory))

(defun heks-emacs-terraform-run (subcommand)
  "Run `terraform SUBCOMMAND' in the configuration being edited.

Run through `compile', so its output is a compilation buffer like every
other build: `g' reruns it, `M-n' and `M-p' walk the errors."
  (let ((root (heks-emacs-terraform-root)))
    (unless (executable-find terraform-command)
      (user-error "%s is not installed, so there is nothing to run" terraform-command))
    (let ((default-directory root))
      (compile (concat (shell-quote-argument terraform-command) " " subcommand)))))

(defun heks-emacs-terraform-init ()
  "Initialise the providers and the state of this configuration."
  (interactive)
  (heks-emacs-terraform-run "init"))

(defun heks-emacs-terraform-validate ()
  "Check that the configuration is internally consistent."
  (interactive)
  (heks-emacs-terraform-run "validate"))

(defun heks-emacs-terraform-plan ()
  "Show what applying the configuration would change."
  (interactive)
  (heks-emacs-terraform-run "plan"))

(defun heks-emacs-terraform-apply ()
  "Apply the configuration, which is what changes the infrastructure."
  (interactive)
  (heks-emacs-terraform-run "apply"))

(defun heks-emacs-terraform-destroy ()
  "Destroy the infrastructure this configuration created.

Terraform asks for the name of the workspace to confirm this itself; the
prompt here is the second one, in the vocabulary of the person asking."
  (interactive)
  (unless (yes-or-no-p (format "Destroy the infrastructure in %s? " (heks-emacs-terraform-root)))
    (user-error "Nothing was destroyed"))
  (heks-emacs-terraform-run "destroy"))

;;
;; ====== Databases: SQL, PostgreSQL and MongoDB ======
;;

;; SQL editing: PostgreSQL is the default dialect, keywords are upper-cased
;; as they are typed, and Flymake lints the buffer with `sql-lint' when that
;; tool is installed (see the flymake-collection setup above).
(use-package sql
  :ensure nil
  :mode (("\\.sql\\'" . sql-mode))
  ;; Leave `sql-postgres-login-params' at its default: it already offers the
  ;; database names of the server for completion.  `sql.el' reads the
  ;; `sql-server', `sql-port', `sql-user' and `sql-database' variables when
  ;; it connects, which `heks-emacs-sql-postgres' fills in from the
  ;; environment.
  :custom
  (sql-product 'postgres))

(use-package sqlup-mode
  :ensure t
  :hook (sql-mode . sqlup-mode))

;; `mongosh' scripts are JavaScript; `C-c d m' (see `heks-emacs-mongosh')
;; opens an interactive shell in a real terminal buffer.
(add-to-list 'auto-mode-alist '("\\.mongo\\(sh\\)?\\'" . js-mode))

(provide 'heks-emacs/dev-project)

;;; dev-project.el ends here
