;;; ai.el --- AI configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; AI in this configuration is two tools in front of one choice: GPTel
;; for a question about what is at point, and ECA for an agentic chat that reads
;; and edits the project.  Both can talk to either of two accounts -- the
;; GitHub Copilot subscription the machine at work is signed in to, or a
;; personal DeepSeek key -- and which one a session starts with is not
;; written into this checkout, because the same checkout is used on both
;; machines.  `auto' reads `HEKS_AI_PROVIDER' and, when that names
;; nothing, takes the presence of a DeepSeek key -- in the environment, or
;; in the encrypted file `heks/ai-deepseek-key-file' -- as the
;; answer.  Copilot is what is left, and it needs no key here at all --
;; GPTel and ECA keep its login themselves.
;;
;; `C-c x p' moves the session to the other account without a restart,
;; and `heks/ai-provider' or `HEKS_AI_PROVIDER' names one outright
;; on a machine whose environment cannot say so.
;;
;; ECA's server is started in the background, once, for the project the
;; reader is in -- quietly, without a window and without a message -- so
;; that the first chat opens at once rather than seconds after the key.
;; What is prepared is a project and not a directory: see "Preparing ECA
;; before it is asked for" below for why the daemon cannot prepare
;; anything at startup, and what `heks/ai-eca-prepare' turns off.

;;; Code:

(require 'cl-lib)

;;;
;;; Customization
;;;

(defcustom heks/ai-provider 'auto
  "Which AI account a session of this Emacs should use.

`auto' obeys `HEKS_AI_PROVIDER' when it names `copilot' or `deepseek',
then chooses DeepSeek when its key is where `heks/ai-deepseek-api-key'
looks for it -- `DEEPSEEK_API_KEY' or `heks/ai-deepseek-key-file' --
and GitHub Copilot otherwise.  Naming one here does not depend on either,
which is what a machine whose key lives somewhere else needs."
  :type '(choice (const :tag "From the environment" auto)
                 (const :tag "GitHub Copilot" copilot)
                 (const :tag "DeepSeek" deepseek))
  :group 'heks)

(defcustom heks/ai-copilot-model 'claude-sonnet-5.5
  "The GitHub Copilot model GPTel and ECA should use."
  :type 'symbol
  :group 'heks)

(defcustom heks/ai-deepseek-model 'deepseek-flash
  "The DeepSeek model GPTel and ECA should use.

`deepseek-flash' is DeepSeek's current general model, and the one this
configuration starts from because it is the cheaper of the two the
account offers.  `deepseek-v4-pro' is the stronger, dearer one."
  :type 'symbol
  :group 'heks)

(defcustom heks/ai-deepseek-key-file "~/.config/heks/deepseek.key.gpg"
  "A file the DeepSeek API key may be kept in.

A file whose name ends in `.gpg' or `.asc' is decrypted with GPG when a
request is made; any other file is read as it is, which is convenient but
not what this configuration recommends for a key that is meant to
outlive the machine.  Only the file's existence is looked at when `auto'
decides which account this Emacs is for, never its contents: decrypting
it at startup would ask for a passphrase before the reader asked for
anything.  `nil', or a file that is not there, means there is no key
file."
  :type '(choice (const :tag "No key file" nil) file)
  :group 'heks)

;;;
;;; Which account this session is for
;;;

(defconst heks/ai--providers '(copilot deepseek)
  "The AI accounts this configuration knows how to reach.")

(defun heks/ai--non-empty (value)
  "Return VALUE trimmed, when it is a string with something in it."
  (when (and (stringp value)
             (not (string-empty-p (string-trim value))))
    (string-trim value)))

(defun heks/ai--provider-from-environment ()
  "Return the provider `HEKS_AI_PROVIDER' names, or nil.

A name this configuration does not know is ignored rather than obeyed: a
typo should send a prompt nowhere, not to the wrong account."
  (when-let* ((named (heks/ai--non-empty (getenv "HEKS_AI_PROVIDER")))
              (provider (intern-soft named)))
    (when (memq provider heks/ai--providers)
      provider)))

(defun heks/ai--deepseek-key ()
  "Return the DeepSeek API key as the environment holds it, or nil.

Only the environment is read here, because this is what `auto' asks at
startup: an encrypted key file or auth source would turn choosing between
two accounts into a question about a passphrase.  See
`heks/ai-deepseek-api-key' for where a request looks for the key."
  (heks/ai--non-empty (getenv "DEEPSEEK_API_KEY")))

(defun heks/ai--deepseek-key-file-name ()
  "Return the expanded name of `heks/ai-deepseek-key-file', or nil."
  (when-let* ((name (heks/ai--non-empty heks/ai-deepseek-key-file)))
    (expand-file-name name)))

(defun heks/ai--deepseek-key-file-p ()
  "Return non-nil when a DeepSeek key file this Emacs can read is configured.

Only its existence and whether it can be read are checked, never its
contents: `auto' asks this at startup, and decrypting the file there would
ask for a passphrase before the reader asked for anything."
  (when-let* ((file (heks/ai--deepseek-key-file-name)))
    (file-readable-p file)))

(defun heks/ai--gpg-decrypt (file)
  "Return what GPG decrypts FILE into, or nil when it cannot.

Standard error is discarded rather than mixed into the answer, and a
missing `gpg' is an answer too -- nil -- because the caller has other
places to look and a message that names them all."
  (condition-case nil
      (with-temp-buffer
        (when (eq 0 (call-process "gpg" nil (list t nil) nil
                                  "--batch" "--quiet" "--decrypt" file))
          (heks/ai--non-empty (buffer-string))))
    (file-missing nil)))

(defun heks/ai--deepseek-key-file-key ()
  "Return the key `heks/ai-deepseek-key-file' holds, or nil.

An encrypted file is decrypted with GPG; a plain one is read as it is, so
a machine that already keeps a 0600 file can point this at it without
renaming anything.  A file that is not there, or a `gpg' that is not
installed, is nil rather than an error: the request has other places to
look, and `heks/ai-deepseek-api-key' says what they are when none
of them answers."
  (let ((file (heks/ai--deepseek-key-file-name)))
    (when (and file (file-readable-p file))
      (if (string-match-p "\\.\\(gpg\\|asc\\)\\'" file)
          (heks/ai--gpg-decrypt file)
        (condition-case nil
            (with-temp-buffer
              (insert-file-contents file)
              (heks/ai--non-empty (buffer-string)))
          (file-error nil))))))

(defun heks/ai-provider ()
  "Return the provider this session should use: `copilot' or `deepseek'."
  (pcase heks/ai-provider
    ('auto (or (heks/ai--provider-from-environment)
               (if (or (heks/ai--deepseek-key)
                       (heks/ai--deepseek-key-file-p))
                   'deepseek
                 'copilot)))
    ((or 'copilot 'deepseek) heks/ai-provider)
    (_ (user-error "`heks/ai-provider' is %S, not `auto', `copilot' or `deepseek'"
                   heks/ai-provider))))

(defun heks/ai-deepseek-api-key ()
  "Return the DeepSeek API key, from wherever this machine keeps it.

The environment comes first, then `heks/ai-deepseek-key-file', then
the auth source -- `machine api.deepseek.com login apikey password ...'
in `~/.authinfo.gpg'.  All three are read when a request is made rather
than at startup, and finding none of them is an error that names all
three: a request that left without a key would only come back as a 401."
  (or (heks/ai--deepseek-key)
      (heks/ai--deepseek-key-file-key)
      (when (fboundp 'gptel-api-key-from-auth-source)
        (condition-case nil
            (gptel-api-key-from-auth-source "api.deepseek.com")
          (user-error nil)))
      (user-error "No DeepSeek API key: set DEEPSEEK_API_KEY, write one to %s, or add a `machine api.deepseek.com' entry to ~/.authinfo.gpg"
                  (or (heks/ai--deepseek-key-file-name) "a key file"))))

(defun heks/ai-model (provider)
  "Return the model symbol PROVIDER should use."
  (pcase provider
    ('copilot heks/ai-copilot-model)
    ('deepseek heks/ai-deepseek-model)
    (_ (user-error "Unknown AI provider: %S" provider))))

(defun heks/ai-eca-model (provider)
  "Return the model id ECA knows PROVIDER by, as `provider/model'.

ECA names a model by its provider and the provider's own name for it,
which is not how this configuration names the account: `copilot' is
`github-copilot' to ECA, the name it logs in with."
  (format "%s/%s"
          (pcase provider
            ('copilot "github-copilot")
            ('deepseek "deepseek")
            (_ (user-error "Unknown AI provider: %S" provider)))
          (heks/ai-model provider)))

;;;
;;; Pointing the tools at one of them
;;;

(defvar heks/ai--gptel-backends nil
  "The GPTel backends made so far, as an alist of provider to backend.")

(defun heks/ai-gptel-backend (provider)
  "Return the GPTel backend for PROVIDER, making it the first time it is asked for.

Both are registered in `gptel--known-backends', which is what `gptel-menu'
offers, and the one not in use costs nothing: the DeepSeek backend reads
its key when a request is made, not when the backend is made, so the
personal account is never needed to start Emacs at work."
  (require 'gptel)
  ;; The two constructors live beside `gptel', not in it, and are normally
  ;; reached through the package's autoloads.  Asking for them here means a
  ;; backend can be made in a session where nothing has loaded them yet, and
  ;; the nil that says they are elsewhere leaves the autoload to answer.
  (require 'gptel-gh nil t)
  (require 'gptel-openai-extras nil t)
  (or (alist-get provider heks/ai--gptel-backends)
      (setf (alist-get provider heks/ai--gptel-backends)
            (pcase provider
              ('copilot (gptel-make-gh-copilot "Copilot"))
              ('deepseek (gptel-make-deepseek "DeepSeek"
                           :stream t
                           :key #'heks/ai-deepseek-api-key))
              (_ (user-error "Unknown AI provider: %S" provider))))))

(defun heks/ai-use-provider (&optional provider)
  "Point GPTel and ECA at PROVIDER.

Called without an argument -- which is how the configuration calls it at
startup -- this uses the provider `heks/ai-provider' resolves to.
Called interactively it asks which account to use, offering the one in
use as the answer, so moving to the other one is a key rather than an
edit and a restart.

A chat that ECA has already opened keeps the model it was started with,
because ECA chooses a model per chat: `C-c x m' changes that one, and the
next chat starts on the one chosen here."
  (interactive
   (let* ((current (heks/ai-provider))
          (chosen (completing-read
                   (format "AI provider (now %s): " current)
                   (mapcar #'symbol-name heks/ai--providers)
                   nil t nil nil (symbol-name current))))
     (list (intern chosen))))
  (let* ((provider (or provider (heks/ai-provider)))
         (model (heks/ai-model provider)))
    (setq gptel-backend (heks/ai-gptel-backend provider)
          gptel-model model
          eca-chat-custom-model (heks/ai-eca-model provider))
    (message "AI: %s (%s)" provider model)))

;; GPTel answers a prompt about what is at point.
(use-package gptel
  :ensure t
  :after (f)
  :config
  (heks/ai-use-provider))

;; ECA is the chat that reads and edits the project.
(use-package eca
  :ensure t
  :bind (("C-c x t" . eca-chat-toggle-window)
         ("C-c x n" . eca-chat-new)
         ("C-c x s" . eca-chat-select)
         ("C-c x a" . eca-chat-add-context-to-user-prompt)
         ("C-c x k" . eca-chat-stop-prompt)
         ("C-c x m" . eca-chat-select-model)
         ("C-c x p" . heks/ai-use-provider))
  :config
  (heks/ai-use-provider))

;;;
;;; Preparing ECA before it is asked for
;;;
;; A chat that has to start the server first is one that opens seconds
;; after the key was pressed, so the server is started in the background,
;; once, for the project the reader is in.  What it may not be is a start
;; that shows something: `eca' always ends by opening a chat window, and
;; not at the moment it returns -- the window is opened from the callback
;; that answers the server's `initialize' request, which is why wrapping
;; the call in `save-window-excursion' (as this file used to) closed
;; nothing at all.
;;
;; So the preparation says what it is, for as long as it lasts: a flag the
;; two advices below read.  The chat buffer is still made -- `C-c x t'
;; with no chat to toggle would show whatever buffer happened to be
;; current -- but it is given no window, and the progress ECA reports is
;; not printed, because a start nobody asked for should not talk.  The
;; first chat that is opened spends the flag, and a timer clears it in
;; case the server never answers, so a chat the reader does ask for can
;; never be the quiet one.
;;
;; There is no project to prepare at startup either: Emacs here is a
;; daemon the compositor starts, in a directory that is nobody's project,
;; and a session rooted there would claim every project under it -- which
;; is what the previous version did, since `eca-session' answers with the
;; session whose workspace folder is an ancestor, and one rooted at $HOME
;; is an ancestor of all of them.  The preparation therefore waits for the
;; first file of a project to be visited, and that file is the earliest
;; moment Emacs knows which project the reader is in.  An Emacs started
;; with `emacs .' knows already, and is prepared at its first idle moment.

(defcustom heks/ai-eca-prepare t
  "Whether to start ECA's server in the background, before a chat is asked for.
The server is prepared once per Emacs, for the project of the first file
visited in one, without a window and without a message.  The chats opened
later are the ones that show themselves, and they open at once because
the server is already there."
  :type 'boolean
  :group 'heks)

(defcustom heks/ai-eca-prepare-delay 1
  "How many seconds of idleness to wait before preparing ECA.
Long enough that starting a server does not hold up the first frame or
the first file, short enough that the first chat asked for is one the
server is already up for."
  :type 'number
  :group 'heks)

(defconst heks/ai--eca-quiet-patience 120
  "How long a background start may keep the next chat quiet, in seconds.
The flag exists for the one chat `eca' opens once its server answers.
A server that never answers -- no network, a binary that will not run --
would otherwise leave it set, and the next chat the reader asked for
would be the one that opened without a window.")

(defvar heks/ai--eca-prepared nil
  "Non-nil once ECA has been prepared, or asked to be, in this Emacs.")

(defvar heks/ai--eca-quiet nil
  "Non-nil while the background ECA start is still preparing.
`heks/ai--eca-say-nothing' and
`heks/ai--eca-open-without-window' read it; the first chat that is
opened clears it.")

(defvar heks/ai--eca-quiet-timer nil
  "The timer that gives up waiting for the prepared session, if any.")

(defun heks/ai--eca-quiet-off ()
  "Stop keeping ECA's next chat quiet."
  (setq heks/ai--eca-quiet nil)
  (when (timerp heks/ai--eca-quiet-timer)
    (cancel-timer heks/ai--eca-quiet-timer))
  (setq heks/ai--eca-quiet-timer nil))

(defun heks/ai--eca-say-nothing (orig &rest args)
  "Say nothing instead of what ORIG would say with ARGS, while preparing."
  (unless heks/ai--eca-quiet
    (apply orig args)))

(defun heks/ai--eca-open-without-window (orig session)
  "Open SESSION's chat with ORIG, but without a window while preparing it.

The chat buffer is still created and registered, which is what makes the
first `C-c x t' a chat rather than the current buffer shown in a side
window; what is skipped is `eca-chat--display-buffer', the one call that
decides where the chat goes.  This is the open the quiet flag was kept
for, so the flag is spent here: every later one is the reader's."
  (if (not heks/ai--eca-quiet)
      (funcall orig session)
    (heks/ai--eca-quiet-off)
    (cl-letf (((symbol-function 'eca-chat--display-buffer) #'ignore))
      (funcall orig session))))

(with-eval-after-load 'eca
  (advice-add 'eca-info :around #'heks/ai--eca-say-nothing)
  (advice-add 'eca-chat-open :around #'heks/ai--eca-open-without-window)
  ;; A chat that is asked for is the reader's, even when it lands in the
  ;; middle of the start nobody asked for: the same `eca-chat-open' opens
  ;; both, so the asking is what has to end the quietness.
  (advice-add 'eca-chat-new :before #'heks/ai--eca-quiet-off))

(defun heks/ai--project-root (&optional directory)
  "Return the root of the project DIRECTORY is in, or nil when it is in none.

DIRECTORY defaults to `default-directory'.  A directory on another
machine is nobody's project here, and a project without a root -- a
project backend that answers something else -- is nil as well."
  (let ((default-directory (file-name-as-directory
                            (expand-file-name (or directory default-directory)))))
    (when (and (file-directory-p default-directory)
               (not (file-remote-p default-directory))
               (fboundp 'project-current))
      (ignore-errors
        (when-let* ((project (project-current nil default-directory))
                    (root (if (fboundp 'project-root)
                              (project-root project)
                            (car (with-no-warnings (project-roots project))))))
          (file-name-as-directory (expand-file-name root)))))))

(defun heks/ai--eca-start-for-project (root)
  "Start ECA's server for the project at ROOT, without showing a chat.

A failure -- no network, no release to fetch, an ECA that is not
installed at all -- is reported once and never raised, because an Emacs
that cannot reach ECA is still an Emacs."
  (setq heks/ai--eca-quiet t
        heks/ai--eca-quiet-timer
        (run-with-timer heks/ai--eca-quiet-patience nil
                        #'heks/ai--eca-quiet-off))
  (condition-case err
      (let ((default-directory root))
        (require 'eca)
        ;; A session that is already there is one that is already prepared.
        (unless (and (fboundp 'eca-session-for-root)
                     (eca-session-for-root root))
          (eca)))
    (error (heks/ai--eca-quiet-off)
           (message "ECA was not prepared: %s" (error-message-string err)))))

(defun heks/ai-eca-prepare (&optional root)
  "Prepare ECA for ROOT -- the project at point by default -- once, quietly.
Nothing is prepared outside a project, and nothing is prepared twice:
the second project of a session starts its own server when a chat is
asked for, as it always did.  ROOT is asked for by the callers below
rather than found here, because this runs from an idle timer, where the
current buffer is whichever one happens to be current and not the one
that said which project to prepare."
  (when heks/ai-eca-prepare
    (let ((root (or root (heks/ai--project-root))))
      (when (and root (not heks/ai--eca-prepared))
        (setq heks/ai--eca-prepared t)
        (heks/ai--eca-start-for-project root)))))

(defun heks/ai--eca-prepare-when-visiting ()
  "Prepare ECA for the project of the file just visited, and watch no more."
  (if (not heks/ai-eca-prepare)
      (remove-hook 'find-file-hook #'heks/ai--eca-prepare-when-visiting)
    (when-let* ((root (heks/ai--project-root)))
      (remove-hook 'find-file-hook #'heks/ai--eca-prepare-when-visiting)
      (run-with-idle-timer heks/ai-eca-prepare-delay nil
                           #'heks/ai-eca-prepare root))))

(defun heks/ai--eca-prepare-soon ()
  "Arrange to prepare ECA for the project this Emacs is in, in the background.

Emacs started inside a project -- `emacs .' -- has one already, and is
prepared at the first idle moment.  The daemon the compositor starts has
none: its `default-directory' is nobody's project, and a session rooted
there would take every project under it for its workspace.  It watches
for the first file of a project instead, and prepares that one."
  (when heks/ai-eca-prepare
    (if-let* ((root (heks/ai--project-root)))
        (run-with-idle-timer heks/ai-eca-prepare-delay nil
                             #'heks/ai-eca-prepare root)
      (add-hook 'find-file-hook #'heks/ai--eca-prepare-when-visiting))))

;; Idle, so that starting a server does not delay the first frame.
(unless noninteractive
  (add-hook 'emacs-startup-hook #'heks/ai--eca-prepare-soon))

(provide 'heks/ai)

;;; ai.el ends here
