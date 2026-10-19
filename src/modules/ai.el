;;; ai.el --- AI configuration for Emacs -*- lexical-binding: t -*-

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

;; AI in this configuration is two tools in front of one choice: GPTel
;; for a question about what is at point, and ECA for an agentic chat that reads
;; and edits the project.  Both can talk to either of two accounts -- the
;; GitHub Copilot subscription the machine at work is signed in to, or a
;; personal DeepSeek key -- and which one a session starts with is not
;; written into this checkout, because the same checkout is used on both
;; machines.  `auto' reads `HEKS_AI_PROVIDER' and, when that names
;; nothing, takes the presence of `DEEPSEEK_API_KEY' as the answer: the
;; variable ECA already reads for its own DeepSeek provider is the one
;; that says which account this Emacs is for.  Copilot is what is left,
;; and it needs no key here at all -- GPTel and ECA keep its login
;; themselves.
;;
;; `C-c x p' moves the session to the other account without a restart,
;; and `heks-emacs-ai-provider' or `HEKS_AI_PROVIDER' names one outright
;; on a machine whose environment cannot say so.

;;; Code:

;;;
;;; Customization
;;;

(defcustom heks-emacs-ai-provider 'auto
  "Which AI account a session of this Emacs should use.

`auto' obeys `HEKS_AI_PROVIDER' when it names `copilot' or `deepseek',
then chooses DeepSeek when `DEEPSEEK_API_KEY' is exported and GitHub
Copilot otherwise.  Naming one here does not depend on the environment at
all, which is what a machine that keeps its key somewhere other than the
environment needs."
  :type '(choice (const :tag "From the environment" auto)
                 (const :tag "GitHub Copilot" copilot)
                 (const :tag "DeepSeek" deepseek))
  :group 'heks-emacs)

(defcustom heks-emacs-ai-copilot-model 'claude-sonnet-5.5
  "The GitHub Copilot model GPTel and ECA should use."
  :type 'symbol
  :group 'heks-emacs)

(defcustom heks-emacs-ai-deepseek-model 'deepseek-flash
  "The DeepSeek model GPTel and ECA should use.

`deepseek-flash' is DeepSeek's current general model, and the one this
configuration starts from because it is the cheaper of the two the
account offers.  `deepseek-v4-pro' is the stronger, dearer one."
  :type 'symbol
  :group 'heks-emacs)

;;;
;;; Which account this session is for
;;;

(defconst heks-emacs-ai--providers '(copilot deepseek)
  "The AI accounts this configuration knows how to reach.")

(defun heks-emacs-ai--non-empty (value)
  "Return VALUE trimmed, when it is a string with something in it."
  (when (and (stringp value)
             (not (string-empty-p (string-trim value))))
    (string-trim value)))

(defun heks-emacs-ai--provider-from-environment ()
  "Return the provider `HEKS_AI_PROVIDER' names, or nil.

A name this configuration does not know is ignored rather than obeyed: a
typo should send a prompt nowhere, not to the wrong account."
  (when-let* ((named (heks-emacs-ai--non-empty (getenv "HEKS_AI_PROVIDER")))
              (provider (intern-soft named)))
    (when (memq provider heks-emacs-ai--providers)
      provider)))

(defun heks-emacs-ai--deepseek-key ()
  "Return the DeepSeek API key as the environment holds it, or nil.

Only the environment is read here, because this is what `auto' asks at
startup: an encrypted auth source would turn choosing between two
accounts into a question about a passphrase.  The key a request needs may
also come from the auth source -- see `heks-emacs-ai-deepseek-api-key'."
  (heks-emacs-ai--non-empty (getenv "DEEPSEEK_API_KEY")))

(defun heks-emacs-ai-provider ()
  "Return the provider this session should use: `copilot' or `deepseek'."
  (pcase heks-emacs-ai-provider
    ('auto (or (heks-emacs-ai--provider-from-environment)
               (if (heks-emacs-ai--deepseek-key) 'deepseek 'copilot)))
    ((or 'copilot 'deepseek) heks-emacs-ai-provider)
    (_ (user-error "`heks-emacs-ai-provider' is %S, not `auto', `copilot' or `deepseek'"
                   heks-emacs-ai-provider))))

(defun heks-emacs-ai-deepseek-api-key ()
  "Return the DeepSeek API key, from the environment or the auth source.

The environment is what `auto' looks at, but a machine that keeps the key
in `~/.authinfo' -- `machine api.deepseek.com login apikey password ...'
-- is served from there, when a request is made rather than at startup."
  (or (heks-emacs-ai--deepseek-key)
      (gptel-api-key-from-auth-source "api.deepseek.com")))

(defun heks-emacs-ai-model (provider)
  "Return the model symbol PROVIDER should use."
  (pcase provider
    ('copilot heks-emacs-ai-copilot-model)
    ('deepseek heks-emacs-ai-deepseek-model)
    (_ (user-error "Unknown AI provider: %S" provider))))

(defun heks-emacs-ai-eca-model (provider)
  "Return the model id ECA knows PROVIDER by, as `provider/model'.

ECA names a model by its provider and the provider's own name for it,
which is not how this configuration names the account: `copilot' is
`github-copilot' to ECA, the name it logs in with."
  (format "%s/%s"
          (pcase provider
            ('copilot "github-copilot")
            ('deepseek "deepseek")
            (_ (user-error "Unknown AI provider: %S" provider)))
          (heks-emacs-ai-model provider)))

;;;
;;; Pointing the tools at one of them
;;;

(defvar heks-emacs-ai--gptel-backends nil
  "The GPTel backends made so far, as an alist of provider to backend.")

(defun heks-emacs-ai-gptel-backend (provider)
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
  (or (alist-get provider heks-emacs-ai--gptel-backends)
      (setf (alist-get provider heks-emacs-ai--gptel-backends)
            (pcase provider
              ('copilot (gptel-make-gh-copilot "Copilot"))
              ('deepseek (gptel-make-deepseek "DeepSeek"
                           :stream t
                           :key #'heks-emacs-ai-deepseek-api-key))
              (_ (user-error "Unknown AI provider: %S" provider))))))

(defun heks-emacs-ai-use-provider (&optional provider)
  "Point GPTel and ECA at PROVIDER.

Called without an argument -- which is how the configuration calls it at
startup -- this uses the provider `heks-emacs-ai-provider' resolves to.
Called interactively it asks which account to use, offering the one in
use as the answer, so moving to the other one is a key rather than an
edit and a restart.

A chat that ECA has already opened keeps the model it was started with,
because ECA chooses a model per chat: `C-c x m' changes that one, and the
next chat starts on the one chosen here."
  (interactive
   (let* ((current (heks-emacs-ai-provider))
          (chosen (completing-read
                   (format "AI provider (now %s): " current)
                   (mapcar #'symbol-name heks-emacs-ai--providers)
                   nil t nil nil (symbol-name current))))
     (list (intern chosen))))
  (let* ((provider (or provider (heks-emacs-ai-provider)))
         (model (heks-emacs-ai-model provider)))
    (setq gptel-backend (heks-emacs-ai-gptel-backend provider)
          gptel-model model
          eca-chat-custom-model (heks-emacs-ai-eca-model provider))
    (message "AI: %s (%s)" provider model)))

;; GPTel answers a prompt about what is at point.
(use-package gptel
  :ensure t
  :after (f)
  :config
  (heks-emacs-ai-use-provider))

;; ECA is the chat that reads and edits the project.
(use-package eca
  :ensure t
  :bind (("C-c x t" . eca-chat-toggle-window)
         ("C-c x n" . eca-chat-new)
         ("C-c x s" . eca-chat-select)
         ("C-c x a" . eca-chat-add-context-to-user-prompt)
         ("C-c x k" . eca-chat-stop-prompt)
         ("C-c x m" . eca-chat-select-model)
         ("C-c x p" . heks-emacs-ai-use-provider))
  :config
  (heks-emacs-ai-use-provider))

(provide 'heks-emacs/ai)

;;; ai.el ends here
