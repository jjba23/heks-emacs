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
;; ====== Language breakdown of a project ======
;;

(defconst heks-emacs-language-by-extension
  '(("tf" . "Terraform") ("tfvars" . "Terraform") ("hcl" . "HCL")
    ("yml" . "YAML") ("yaml" . "YAML") ("json" . "JSON")
    ("ts" . "TypeScript") ("tsx" . "TypeScript")
    ("js" . "JavaScript") ("jsx" . "JavaScript") ("mjs" . "JavaScript")
    ("py" . "Python") ("go" . "Go") ("rs" . "Rust") ("java" . "Java")
    ("kt" . "Kotlin") ("scala" . "Scala") ("c" . "C") ("h" . "C")
    ("cpp" . "C++") ("hpp" . "C++") ("cs" . "C#") ("rb" . "Ruby")
    ("el" . "Emacs Lisp") ("scm" . "Scheme") ("lisp" . "Common Lisp")
    ("clj" . "Clojure") ("cljs" . "Clojure") ("sh" . "Shell")
    ("bash" . "Shell") ("zsh" . "Shell") ("sql" . "SQL")
    ("html" . "HTML") ("css" . "CSS") ("scss" . "CSS")
    ("md" . "Markdown") ("org" . "Org") ("toml" . "TOML")
    ("nix" . "Nix") ("proto" . "Protobuf") ("lua" . "Lua")
    ("php" . "PHP") ("swift" . "Swift") ("ex" . "Elixir") ("exs" . "Elixir"))
  "Alist mapping file extensions to the language shown in the breakdown.
Files with an extension that is not listed here are not counted.")

(global-set-key (kbd "C-c w l") #'heks-emacs-project-languages)

(defun heks-emacs-git-output (root &rest args)
  "Return the trimmed output of `git ARGS' run in ROOT, or nil on failure."
  (let ((default-directory root))
    (with-temp-buffer
      (when (zerop (apply #'call-process "git" nil '(t nil) nil args))
        (string-trim (buffer-string))))))

;;;###autoload
(defun heks-emacs-project-git-stats ()
  "Show a summary of the Git history of the current project.

It covers when the project started, the latest commit, the number of
commits and the top contributors, in a small window below the current one."
  (interactive)
  (let ((root (heks-emacs-terraform-root)))
    (unless (and (executable-find "git")
                 (heks-emacs-git-output root "rev-parse" "--git-dir"))
      (user-error "%s is not in a Git repository" (abbreviate-file-name root)))
    (let* ((out (apply-partially #'heks-emacs-git-output root))
           (count (string-to-number (or (funcall out "rev-list" "--count" "HEAD") "0")))
           (first (car (last (split-string
                              (or (funcall out "log" "--max-parents=0" "--format=%as") "")
                              "\n" t))))
           (last (funcall out "log" "-1" "--format=%as %an: %s"))
           (branch (funcall out "rev-parse" "--abbrev-ref" "HEAD"))
           (authors (mapcar (lambda (l)
                              (when (string-match "\\`\\s-*\\([0-9]+\\)\\s-+\\(.*\\)\\'" l)
                                (cons (match-string 2 l)
                                      (string-to-number (match-string 1 l)))))
                            (split-string (or (funcall out "shortlog" "-sn" "HEAD") "")
                                          "\n" t)))
           (authors (delq nil authors))
           (buf (get-buffer-create "*Project git*")))
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (format "%s  (%s)\n\n" (abbreviate-file-name root) branch)
                  (format "Started       %s\n" (or first "?"))
                  (format "Latest        %s\n" (or last "?"))
                  (format "Commits       %d\n\n" count)
                  "Top 10 contributors\n")
          (dolist (a (seq-take authors 10))
            (insert (format "  %-22s %3d%%  (%d commits)\n"
                            (car a)
                            (max 1 (round (* 100.0 (cdr a)) (max count 1)))
                            (cdr a))))
          (goto-char (point-min)))
        (special-mode))
      (let ((win (split-window-below (- (min 18 (+ 9 (min 5 (length authors))))))))
        (set-window-buffer win buf)
        (select-window win)))))

(global-set-key (kbd "C-c w G") #'heks-emacs-project-git-stats)

(defun heks-emacs-language-files (root)
  "Return the files under ROOT, honouring `.gitignore' when in a git repo."
  (let ((default-directory root))
    (if (and (executable-find "git")
             (zerop (call-process "git" nil nil nil "rev-parse" "--git-dir")))
        (mapcar (lambda (f) (expand-file-name f root))
                (split-string
                 (with-output-to-string
                   (with-current-buffer standard-output
                     (call-process "git" nil t nil "ls-files" "-z"
                                   "--cached" "--others" "--exclude-standard")))
                 "\0" t))
      (directory-files-recursively
       root "" nil
       (lambda (d) (not (string-match-p "/\\(\\.git\\|node_modules\\|\\.terraform\\)\\'" d)))))))

(defun heks-emacs-language-stats (root)
  "Return an alist of (LANGUAGE . LINES) for the files under ROOT, largest first."
  (let ((counts (make-hash-table :test #'equal)) result)
    (dolist (file (heks-emacs-language-files root))
      (when-let* ((lang (cdr (assoc (downcase (or (file-name-extension file) ""))
                                    heks-emacs-language-by-extension)))
                  ((file-regular-p file))
                  ((< (file-attribute-size (file-attributes file)) 1000000)))
        (with-temp-buffer
          (insert-file-contents file)
          (puthash lang (+ (gethash lang counts 0) (count-lines (point-min) (point-max)))
                   counts))))
    (maphash (lambda (k v) (push (cons k v) result)) counts)
    (sort result (lambda (a b) (> (cdr a) (cdr b))))))

;;;###autoload
(defun heks-emacs-project-languages ()
  "Show a rough percentage of lines of code per language in the current project.

The result is displayed in a small window split below the current one."
  (interactive)
  (let* ((root (heks-emacs-terraform-root))
         (stats (heks-emacs-language-stats root))
         (total (apply #'+ (mapcar #'cdr stats)))
         (buf (get-buffer-create "*Project languages*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "%s\n\n" (abbreviate-file-name root)))
        (if (zerop total)
            (insert "No recognised source files.\n")
          (dolist (s stats)
            (insert (format "%-14s %3d%%  (%d lines)\n"
                            (car s)
                            (max 1 (round (* 100.0 (cdr s)) total))
                            (cdr s)))))
        (goto-char (point-min)))
      (special-mode))
    (let ((win (split-window-below (- (min 15 (+ 4 (length stats)))))))
      (set-window-buffer win buf)
      (select-window win))))

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

