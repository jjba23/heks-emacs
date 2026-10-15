;;; shell.el --- Shell configuration for Emacs -*- lexical-binding: t -*-

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

;; The interactive shell: Eshell, with this configuration's prompt and
;; its aliases, and Ghostel for the projects one opens a terminal in.
;;
;; Shell *scripts* are a different thing from a shell session, and what
;; checks and formats one is the tool that owns it:
;;
;;   * `shellcheck' is the checker, through Emacs's own
;;     `sh-shellcheck-flymake', which `sh-mode' and `bash-ts-mode' register:
;;     it runs shellcheck on the buffer itself, so what has been typed but
;;     not saved is checked too, and as the dialect the mode decided the
;;     script is written in.  What this module adds to that is the flag that
;;     makes a script's `source'd files count rather than be reported as
;;     not followed.
;;   * `shfmt' is the formatter, and nothing in Emacs knows about it.
;;     `C-c i f' -- the one format key, the same in every buffer -- formats a
;;     shell buffer with it, and the lines it would rewrite are reported as
;;     Flymake diagnostics, the way drift in a Scheme file is: an
;;     unformatted script says so before it is saved.
;;   * The language server (`bash-language-server', see `eglot.el') answers
;;     what those two cannot: the completion of the variables, functions and
;;     options of a script, its documentation on hover, the symbols of the
;;     file, a definition, its references and a rename.  It is not a second
;;     checker or a second formatter -- its own shellcheck and shfmt are
;;     turned off in it -- so completion is what it brings to a buffer that
;;     is already checked and already formatted.
;;
;; `shfmt' is not required.  Where it is not installed its backend stays
;; quiet and the format key falls through to whatever else the buffer has
;; rather than refusing to format a script.  Shellcheck is Emacs's to run,
;; and a machine without it simply gets the formatting half.
;;
;; Both of the modes Emacs uses for a shell script are covered.  A `.sh'
;; file opens in `bash-ts-mode' when the bash grammar is built and in
;; `sh-mode' when it is not -- and a `.zsh' or `.ksh' file always does -- so
;; the setup is hooked on each.  What neither mode did before this was start
;; Flymake at all, so the shellcheck backend that was registered for every
;; shell buffer never ran.

;;; Code:

(defun git-prompt-branch-name ()
  "Get current git branch name."
  (let ((args '("symbolic-ref" "HEAD" "--short")))
    (with-temp-buffer
      (apply #'process-file "git" nil (list t nil) nil args)
      (unless (bobp)
        (goto-char (point-min))
        (buffer-substring-no-properties (point) (line-end-position))))))

(defun eshell-here ()
  "Opens up a new shell in the directory associated with the
current buffer's file.  The eshell is renamed to match that
directory to make multiple eshell windows easier."
  (interactive)
  (let* ((parent (if (buffer-file-name)
                     (file-name-directory (buffer-file-name))
                   default-directory))
         (height (/ (window-total-height) 3))
         (name   (car (last (split-string parent "/" t)))))
    (split-window-vertically (- height))
    (other-window 1)
    (eshell "new")
    (rename-buffer (concat "*eshell: " name "*"))))

(defun eshell/x ()
  (insert "exit")
  (eshell-send-input)
  (delete-window))

(defun fish-path (path max-len)
  "Return a potentially trimmed-down version of the directory PATH, replacing
parent directories with their initial characters to try to get the character
length of PATH (sans directory slashes) down to MAX-LEN."
  (let* ((components (split-string (abbreviate-file-name path) "/"))
         (len (+ (1- (length components))
                 (cl-reduce '+ components :key 'length)))
         (str ""))
    (while (and (> len max-len)
                (cdr components))
      (setq str (concat str
                        (cond ((= 0 (length (car components))) "/")
                              ((= 1 (length (car components)))
                               (concat (car components) "/"))
                              (t
                               (if (string= "."
                                            (string (elt (car components) 0)))
                                   (concat (substring (car components) 0 2)
                                           "/")
                                 (string (elt (car components) 0) ?/)))))
            len (- len (1- (length (car components))))
            components (cdr components)))
    (concat str (cl-reduce (lambda (a b) (concat a "/" b)) components))))

(defun heks-emacs-eshell-prompt ()
  (defun with-face (str &rest face-plist)
    (propertize str 'face face-plist))
  (concat
   "\n"
   (with-face user-login-name :inherit 'font-lock-function-name-face)
   "@"
   (with-face (system-name) :inherit 'font-lock-function-name-face)
   ": "
   (with-face (if (string= (eshell/pwd) (getenv "HOME"))
                  "~" (fish-path (eshell/pwd) 36))
              :inherit 'font-lock-function-name-face)
   ": "
   (with-face
    (or (ignore-errors (git-prompt-branch-name)) "")
    :inherit 'font-lock-function-name-face)
   "\n"
   (if (= (user-uid) 0)
       "#"
     "λ")
   " "))

(setopt eshell-prompt-regexp "^[^#λ\n]*[#λ] ")
(setopt eshell-prompt-function 'heks-emacs-eshell-prompt)
(setopt eshell-highlight-prompt nil)
(setopt eshell-banner-message "Welcome to HEKS-EMACS\n")

;;(global-set-key (kbd "C-!") 'eshell-here)

(setq heks-emacs/eshell-aliases
      '((g  . magit)
        (gl . magit-log)
        (d  . dired)
        (h . eshell/history)
        (o  . find-file)
        (oo . find-file-other-window)
        (l  . (lambda () (eshell/ls '-lAh '--group-directories-first)))
        (ll  . (lambda () (eshell/ls '-lAh '--group-directories-first)))
        (eshell/clear . eshell/clear-scrollback)))

(mapc (lambda (alias)
        (defalias (car alias) (cdr alias)))
      heks-emacs/eshell-aliases)

(use-package ghostel
  :ensure t
  :bind (("C-!" . ghostel-project)
         ("C-$" . ghostel))
  :custom
  (ghostel-module-auto-install 'download)
  :config
  (add-to-list 'display-buffer-alist
               '("ghostel\\*\\'"
                 nil
                 (window-parameters (mode-line-format . none)))))

;;
;; ====== Checking shell scripts: shellcheck ======
;;
;; Emacs checks a shell script with shellcheck itself: `sh-mode' and
;; `bash-ts-mode' register `sh-shellcheck-flymake', which runs shellcheck on
;; the buffer through a pipe -- so what has been typed but not saved is
;; checked too -- as the dialect the mode decided the script is written in.
;; There is nothing to write here for that, only something to say to it,
;; and one thing to keep out of its way: the library whose other backends
;; this configuration uses registers a shellcheck of its own and switches
;; Emacs's off, so `dev.el' turns that one off instead and Emacs's runs.

(with-eval-after-load 'sh-script
  ;; The sources a script names are followed too (`-x'): without it every
  ;; `source' line is a note saying it was not followed, and the variables a
  ;; sourced file sets are then reported as unassigned.  Shellcheck is run
  ;; in the directory of the buffer, so a relative `source' finds its file.
  (setopt sh-shellcheck-arguments '("--external-sources")))

;;
;; ====== Where a shell script is ======
;;

(defun heks-emacs-shell-buffer-p ()
  "Return non-nil when the current buffer holds a shell script.

Both of the modes Emacs uses for one are meant: `bash-ts-mode' is what a
`.sh' file opens in when the bash grammar is built, and `sh-mode' is what
it opens in when it is not, and what a `.zsh' or `.ksh' file opens in."
  (derived-mode-p 'sh-mode 'bash-ts-mode))

(defun heks-emacs-shell-directory ()
  "Return the directory of the file being edited.

`shfmt' is given a copy of the buffer in a temporary directory, so this is
handed to it to run in, which is also what makes the EditorConfig settings
of the buffer's own project apply."
  (file-name-as-directory
   (or (and buffer-file-name (file-name-directory buffer-file-name))
       default-directory)))

(defun heks-emacs-shell-copy-suffix ()
  "Return the file name suffix for a copy of the buffer.

The buffer's own extension where it has one, so that `shfmt' reads the
dialect from the name as well as from the shebang the copy carries."
  (or (and buffer-file-name (file-name-extension buffer-file-name t)) ".sh"))

;;
;; ====== Formatting shell scripts: shfmt ======
;;

(defcustom heks-emacs-shfmt-program "shfmt"
  "Name of the `shfmt' executable, the formatter of shell scripts."
  :type 'string
  :group 'heks-emacs)

(defcustom heks-emacs-shfmt-flymake t
  "Whether `shfmt' reports formatting drift as a Flymake backend."
  :type 'boolean
  :group 'heks-emacs)

(defcustom heks-emacs-shfmt-arguments nil
  "Extra arguments passed to `shfmt'.

`shfmt' already reads the EditorConfig files of the project, which is
where an indentation choice belongs; this is for what those cannot say.
An indentation of two spaces is the usual one, which `-i' and `2' ask for
by name.  The arguments are passed to the tool in the order they are
written, before the file to format."
  :type '(repeat string)
  :group 'heks-emacs)

(defun heks-emacs-shfmt-available-p ()
  "Return non-nil when the `shfmt' command is installed."
  (heks-emacs-tool-available-p heks-emacs-shfmt-program))

(defun heks-emacs-shfmt-applies-p ()
  "Return non-nil when `shfmt' has something to say about this buffer."
  (and heks-emacs-shfmt-flymake
       (heks-emacs-shfmt-available-p)
       (heks-emacs-shell-buffer-p)))

(defun heks-emacs-shfmt-command (file)
  "Return the `shfmt' command that rewrites FILE in place.

The formatter is handed a copy of the buffer to rewrite, which is what
both the drift backend and `heks-emacs-tool-format-buffer' read the
result from; `shfmt' takes the dialect, and the EditorConfig settings of
the project, from the file it is given."
  (append (list (heks-emacs-tool-path heks-emacs-shfmt-program) "-w")
          heks-emacs-shfmt-arguments
          (list file)))

(defun heks-emacs-shfmt-backend (report-fn &rest _args)
  "Flymake backend reporting the lines `shfmt' would rewrite.

`shfmt' rewrites files in place, so the check runs on a copy of the
buffer: the drift is reported as the script is written rather than after
it is saved, and the buffer is never touched."
  (heks-emacs-tool-drift-backend
   "shfmt" report-fn
   (list
    :what "shfmt"
    :applies #'heks-emacs-shfmt-applies-p
    :suffix (heks-emacs-shell-copy-suffix)
    :root #'heks-emacs-shell-directory
    :command #'heks-emacs-shfmt-command)))

(defun heks-emacs-shell-format-buffer ()
  "Format the current buffer in place with `shfmt'."
  (interactive)
  (unless (heks-emacs-shfmt-available-p)
    (user-error "`%s' is not installed, so there is nothing to format with"
                heks-emacs-shfmt-program))
  (heks-emacs-tool-format-buffer
   (list :what "shfmt" :command #'heks-emacs-shfmt-command)))

(defun heks-emacs-shell-format-applies-p ()
  "Return non-nil when `shfmt' is the formatter to use in this buffer.

nil where it is not installed, so that `heks-emacs-format-buffer' asks
whoever else the buffer has -- the language server, `format-all' -- rather
than refusing to format a script no shell formatter is known for."
  (and (heks-emacs-shell-buffer-p) (heks-emacs-shfmt-available-p)))

;; `C-c i f' is the format key in every buffer, and it is a table the
;; buffer answers: in a shell one the answer is `shfmt', which is also what
;; reports the drift of the buffer.  Like the Scheme formatter, this is
;; added rather than bound, so that the key a user already knows keeps
;; working here.
(add-to-list 'heks-emacs-format-dispatch
             (cons #'heks-emacs-shell-format-applies-p
                   #'heks-emacs-shell-format-buffer))

;;
;; ====== Flymake setup ======
;;

(defun heks-emacs-shell-setup-flymake ()
  "Register the checkers of this shell buffer and start Flymake.

`shellcheck' -- through Emacs's own `sh-shellcheck-flymake', which the
mode has already registered -- checks what the script says, and `shfmt'
reports the lines it would rewrite.  `shfmt' stays quiet where it is not
installed, and the run happens where Flymake runs it: when the buffer has
been still for a moment, and when it is saved."
  (when heks-emacs-shfmt-flymake
    (add-hook 'flymake-diagnostic-functions #'heks-emacs-shfmt-backend nil t))
  (flymake-mode 1))

(add-hook 'sh-mode-hook #'heks-emacs-shell-setup-flymake)
(add-hook 'bash-ts-mode-hook #'heks-emacs-shell-setup-flymake)

;; Nothing here has to be done about the language server, which is what the
;; mode above would otherwise have to say something about: Eglot replaces
;; `flymake-diagnostic-functions' with its own backend alone while it manages
;; a buffer, and `heks-emacs-flymake-keep-backends' (see `dev.el') puts back
;; what the buffer had -- whatever language it is -- so these two checkers
;; outlive the server without this module knowing a server exists.
(provide 'heks-emacs/shell)

;;; shell.el ends here
