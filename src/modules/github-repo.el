;;; github-repo.el --- Making a GitHub repository match a spec -*- lexical-binding: t -*-

;;; SPDX-License-Identifier: MIT
;;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;;; A repository's GitHub configuration -- its merge settings, its features,
;;; its security features, the permissions of its Actions and the ruleset that
;;; guards its default branch -- is a thing one wants to write down once and
;;; give to the next repository.  This module is that: `heks/github-repo-capture'
;;; reads a repository and returns its settings as Emacs Lisp, `-apply' makes a
;;; repository match them, and `-verify' says whether it still does.
;;;
;;; It is the Emacs Lisp of a shell script that lived in my heks-linux checkout
;;; (scripts/github-repo.sh, with the settings beside it in a JSON file).  What
;;; the port bought is the thing the script could not have: the settings are a
;;; Lisp value in this configuration rather than a JSON file with `jq' between
;;; it and the API, so the tool is written in one language, a setting is read
;;; where it is written, and nothing has to be installed beside `gh'.
;;;
;;; The spec below was captured from `heks/github-repo-reference' and is what
;;; every repository of mine is given: squash and rebase merges only, linear
;;; history, signed commits, a pull request that needs one approving review and
;;; a code-owner one, secret scanning and push protection on, private
;;; vulnerability reporting on, Dependabot on, and a read-only token for
;;; Actions.
;;;
;;; `gh' is the program; this is the interface to it.  It has to be installed
;;; and authenticated (`gh auth login'), and nothing here touches the token.
;;;
;;; The three commands are `M-x' commands rather than keys.  They are run once
;;; per repository, they ask questions the key tree cannot ask (which
;;; repository, whether to push), and a key for a command used once a month is
;;; a key the scheme has to describe and nobody remembers.
;;;
;;; Three notes on the spec.
;;;
;;; * a JSON object is an alist whose keys are the API's own field names, so
;;; `has_issues' is a symbol with an underscore in it.  That is not the
;;; Lisp style; it is the API's, kept so that a captured spec and the
;;; payload sent back are the same thing, and so that the error GitHub
;;; answers with names a field one can find in the spec;
;;; * a JSON `false' is the symbol `json-false' (`:json-false', which
;;; `json-encode' writes as `false'); a JSON `null' is nil, which
;;; `json-encode' writes as `null', and which is also how a setting the
;;; spec does not name is read -- GitHub treats an absent setting and a
;;; null one alike, so nothing is lost.  A setting that is `false' is not
;;; a setting that is absent, and that difference is the whole of what
;;; `has_wiki' means; an empty array is `[]', a vector, because nil is
;;; not an empty array either;
;;; * `-apply' writes one field per request, in dependency order, because
;;; GitHub rejects some fields on their own terms: `allow_forking' is
;;; org-only for a private repository, the squash/merge message pair has to
;;; be sent together, merge messages need merge commits enabled, and the
;;; default branch can only be set once it exists.

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'seq)
(require 'subr-x)

(defgroup heks/github-repo nil
  "Making a GitHub repository match a spec."
  :group 'tools
  :prefix "heks/github-repo-")

(defcustom heks/github-repo-executable "gh"
  "The GitHub CLI this module drives."
  :type 'string
  :group 'heks/github-repo)

(defcustom heks/github-repo-protocol nil
  "Which protocol the git remote is made with: `ssh', `https', or nil.
Nil means what `gh config get git_protocol' answers, and `https' when it
answers nothing."
  :type '(choice (const :tag "As gh is configured" nil)
                 (const :tag "ssh" ssh)
                 (const :tag "https" https))
  :group 'heks/github-repo)

(defcustom heks/github-repo-ssh-host nil
  "The ssh host alias used for git@github URLs, or nil to look one up.
GitHub is often reached through an alias in ~/.ssh/config -- this machine
uses `Host personal.github.com' with a key of its own -- and the remote has
to name the alias for ssh to use that key."
  :type '(choice (const :tag "Find it in ~/.ssh/config" nil) string)
  :group 'heks/github-repo)

(defcustom heks/github-repo-log-buffer "*heks/github-repo*"
  "The buffer the log, and the report of a difference, are shown in."
  :type 'string
  :group 'heks/github-repo)

(defcustom heks/github-repo-spec-buffer "*heks/github-repo spec*"
  "The buffer a captured spec is shown in, ready to be copied or loaded."
  :type 'string
  :group 'heks/github-repo)

(defcustom heks/github-repo-specs nil
  "Specs for particular repositories, by owner or by OWNER/REPO.
An entry is (KEY . SPEC): KEY is an owner such as \"jjba23\" or a
repository such as \"jjba23/sift\".  The most specific entry wins, and
`heks/github-repo-spec' is the answer when neither is there, so the house
style and its exceptions sit beside each other:

  (setq heks/github-repo-specs
        '((\"jjba23\" . ((repo (has_wiki . t))))
          (\"jjba23/sift\" . ((repo (has_wiki . :json-false))))))

An entry is a whole spec and not a patch over the default: a value that
the entry does not mention is a value that `apply' does not set.
`heks/github-repo-capture' is how one is written."
  :type '(repeat (cons string sexp))
  :group 'heks/github-repo)

(defcustom heks/github-repo-include-forks nil
  "Whether the batch commands consider forks.
A fork is somebody else's project with your name on the remote, and its
settings are not yours to standardise, so the batch commands leave forks
out unless this says otherwise.  Archived repositories are always left
out: a repository nobody touches is not one to reconfigure."
  :type 'boolean
  :group 'heks/github-repo)

(defvar heks/github-repo-dry-run nil
  "Whether the next command says what it would do instead of doing it.
`heks/github-repo-apply' binds it from its prefix argument, and every
mutating call reads it.")

(defconst heks/github-repo-reference "jjba23/symbanta"
  "The repository `heks/github-repo-spec' was captured from.")

(defconst heks/github-repo-optional-rules
  '(copilot_code_review code_quality code_scanning)
  "Ruleset rules that only newer or paid repositories have.
They are dropped, one per attempt, when the repository refuses them, so
that one spec can be applied to a repository on the free plan.")

(defconst heks/github-repo-repo-fields
  '(has_issues has_projects has_wiki has_discussions web_commit_signoff_required
               is_template allow_forking allow_squash_merge allow_merge_commit
               allow_rebase_merge delete_branch_on_merge allow_auto_merge
               allow_update_branch squash_merge_commit_title
               squash_merge_commit_message merge_commit_title merge_commit_message)
  "The repository settings a spec holds, after branch, visibility and description.")

(defconst heks/github-repo-ruleset-noise
  '(id node_id source source_type _links created_at updated_at
       current_user_can_bypass)
  "The parts of a live ruleset that say where it is and not what it does.
They are what `capture' takes out, so that the ruleset it writes can be
posted to another repository.")

(defconst heks/github-repo-spec
  '((template . "jjba23/symbanta")
    (captured_at . "2026-11-02T18:04:56Z")
    (repo
     (default_branch . "trunk")
     (visibility . "public")
     (has_issues . t)
     (has_projects . :json-false)
     (has_wiki . :json-false)
     (has_discussions . t)
     (web_commit_signoff_required . :json-false)
     (is_template . :json-false)
     (allow_forking . t)
     (allow_squash_merge . t)
     (allow_merge_commit . :json-false)
     (allow_rebase_merge . t)
     (delete_branch_on_merge . t)
     (allow_auto_merge . t)
     (allow_update_branch . t)
     (squash_merge_commit_title . "PR_TITLE")
     (squash_merge_commit_message . "PR_BODY")
     (merge_commit_title . "MERGE_MESSAGE")
     (merge_commit_message . "PR_TITLE")
     (security_and_analysis
      (secret_scanning (status . "enabled"))
      (secret_scanning_push_protection (status . "enabled"))
      (dependabot_security_updates (status . "enabled"))
      (secret_scanning_non_provider_patterns (status . "disabled"))
      (secret_scanning_validity_checks (status . "disabled"))))
    (private_vulnerability_reporting . t)
    (actions_permissions
     (enabled . t)
     (allowed_actions . "all")
     (sha_pinning_required . :json-false))
    (workflow_permissions
     (default_workflow_permissions . "read")
     (can_approve_pull_request_reviews . :json-false))
    (rulesets
     ((name . "branch-ruleset")
      (target . "branch")
      (enforcement . "active")
      (conditions
       (ref_name
        (exclude . [])
        (include . ("~DEFAULT_BRANCH"))))
      (rules
       ((type . "deletion"))
       ((type . "non_fast_forward"))
       ((type . "required_linear_history"))
       ((type . "required_signatures"))
       ((type . "pull_request")
        (parameters
         (required_approving_review_count . 1)
         (dismiss_stale_reviews_on_push . :json-false)
         (required_reviewers . [])
         (require_code_owner_review . t)
         (require_last_push_approval . :json-false)
         (required_review_thread_resolution . t)
         (require_extra_approval_for_unattributed_changes . t)
         (allowed_merge_methods . ("squash" "rebase"))))
       ((type . "copilot_code_review")
        (parameters
         (review_on_push . :json-false)
         (review_draft_pull_requests . :json-false)))
       ((type . "code_scanning")
        (parameters
         (code_scanning_tools
          ((tool . "CodeQL")
           (security_alerts_threshold . "high_or_higher")
           (alerts_threshold . "errors")))))
       ((type . "code_quality")
        (parameters
         (severity . "errors"))))
      (bypass_actors
       ((actor_id . 5)
        (actor_type . "RepositoryRole")
        (bypass_mode . "always"))))))
  "The GitHub settings every repository of mine is given.
It is plain Lisp data: a JSON object is an alist, a JSON array a list or
a vector (a vector for an array that is empty, which nil cannot say), a
JSON false is `json-false' and a JSON null is nil.  `capture' writes
this shape, `apply' sends it, and `verify' compares against it; edit it as
any other value and the next `apply' is what makes a repository match.")

;;;
;;; ====== Which spec a repository gets ======
;;;

(defun heks/github-repo-specification (slug)
  "Return the spec SLUG is given.
`heks/github-repo-specs' is asked first -- the repository before its
owner -- and `heks/github-repo-spec' is the answer when it has nothing."
  (or (cdr (assoc slug heks/github-repo-specs))
      (cdr (assoc (car (split-string slug "/")) heks/github-repo-specs))
      heks/github-repo-spec))

;;;
;;; ====== Talking to gh ======
;;;

(defun heks/github-repo--log (format &rest args)
  "Append a line made from FORMAT and ARGS to the log buffer."
  (with-current-buffer (get-buffer-create heks/github-repo-log-buffer)
    (let ((inhibit-read-only t))
      (goto-char (point-max))
      (insert (apply #'format format args) "\n")))
  nil)

(defun heks/github-repo--clear-log ()
  "Empty the log buffer."
  (with-current-buffer (get-buffer-create heks/github-repo-log-buffer)
    (let ((inhibit-read-only t))
      (erase-buffer))))

(defun heks/github-repo--step (format &rest args)
  "Start a new step of the log with a line made from FORMAT and ARGS."
  (heks/github-repo--log "")
  (heks/github-repo--log "== %s" (apply #'format format args)))

(defun heks/github-repo--warn (format &rest args)
  "Say a warning in the log and in the echo area."
  (let ((text (apply #'format format args)))
    (heks/github-repo--log "warning: %s" text)
    (message "heks/github-repo: %s" text)))

(defun heks/github-repo--show-log ()
  "Show the log buffer, keeping what is in it."
  (let ((buffer (get-buffer-create heks/github-repo-log-buffer)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (special-mode))
      (goto-char (point-min)))
    (pop-to-buffer buffer)))

(defun heks/github-repo--run (args &optional input)
  "Run the gh executable with ARGS, feeding it INPUT on standard input.
Return (STATUS STDOUT STDERR), the three as they came, so that a caller can
say what a refusal said rather than only that it refused."
  (let ((stdout (generate-new-buffer " *heks/gh output*"))
        (stderr (make-temp-file "heks-gh-stderr"))
        (status nil))
    (unwind-protect
      (progn
        (setq status
          (if input
            (with-temp-buffer
              (insert input)
              (apply #'call-process-region (point-min) (point-max)
                     heks/github-repo-executable
                     nil (list stdout stderr) nil args))
            (apply #'call-process heks/github-repo-executable nil
                   (list stdout stderr) nil args)))
        (list status
              (with-current-buffer stdout (buffer-string))
              (with-temp-buffer
                (insert-file-contents stderr)
                (buffer-string))))
      (kill-buffer stdout)
      (delete-file stderr))))

(defun heks/github-repo--gh (args &optional input)
  "Run gh with ARGS and return its standard output.
Signal an error carrying both streams when it fails, because gh writes the
reason a call was refused to standard error and the JSON of an API error to
standard output."
  (pcase-let ((`(,status ,out ,err) (heks/github-repo--run args input)))
    (unless (eq status 0)
      (user-error "gh %s failed: %s" (string-join args " ")
                  (string-trim (concat err out))))
    out))

(defun heks/github-repo--from-json (value)
  "Return the JSON VALUE as a spec value: an array is a list, an empty one [].
An empty array has to stay a vector: nil is not an empty array in the API's
eyes, and encoding it back would send nothing where a list is required."
  (cond
    ((vectorp value)
     (if (zerop (length value))
       []
       (mapcar #'heks/github-repo--from-json (append value nil))))
    ((and (consp value) (consp (car value)) (symbolp (caar value)))
     (mapcar (lambda (cell)
               (cons (car cell) (heks/github-repo--from-json (cdr cell))))
             value))
    ((consp value)
     (mapcar #'heks/github-repo--from-json value))
    (t value)))

(defun heks/github-repo--query (path)
  "Return the JSON at PATH as a Lisp value, or nil when it cannot be read.
Read-only, and forgiving: a repository's private vulnerability reporting or
Actions permissions are not there on every plan, and a missing one is not
the end of a capture."
  (ignore-errors
    (heks/github-repo--from-json
     (json-parse-string (heks/github-repo--gh (list "api" path))
                        :object-type 'alist
                        :array-type 'array
                        :null-object nil
                        :false-object json-false))))

(defun heks/github-repo--request (method path &optional payload)
  "Make the API request METHOD PATH with PAYLOAD, without signalling.
Return (OK . OUTPUT), OUTPUT carrying what GitHub answered either way."
  (pcase-let ((`(,status ,out ,err)
               (heks/github-repo--run
                (append (list "api" "-X" method path)
                        (when payload (list "--input" "-")))
                payload)))
    (cons (eq status 0) (string-trim (concat out err)))))

(defun heks/github-repo--api (method path &optional payload)
  "Make the mutating request METHOD PATH with PAYLOAD, unless dry-running.
Return what GitHub answered; signal when it refused."
  (if heks/github-repo-dry-run
    (progn
      (heks/github-repo--log "dry-run: gh api -X %s %s%s" method path
                             (if payload (format " <<< %s" payload) ""))
      "")
    (pcase-let ((`(,ok . ,output) (heks/github-repo--request method path payload)))
      (unless ok
        (user-error "%s %s failed: %s" method path output))
      output)))

(defun heks/github-repo--api-try (method path &optional payload)
  "Like `heks/github-repo--api', but a refusal is only a warning.
Used for the features that depend on the plan or the visibility of the
repository -- secret scanning on a private repository, Copilot, code
quality -- so that one the repository cannot have does not stop the rest
from being applied."
  (condition-case err
    (progn
      (heks/github-repo--api method path payload)
      t)
    (error
      (heks/github-repo--warn "%s %s not applied: %s%s" method path
                              (error-message-string err)
                              (if payload (format " [sent: %s]" payload) ""))
      nil)))

(defun heks/github-repo--exists-p (slug)
  "Return whether the repository SLUG exists."
  (and (heks/github-repo--query (format "repos/%s" slug)) t))

(defun heks/github-repo--require ()
  "Make sure gh is here and signed in before anything is asked of it."
  (unless (executable-find heks/github-repo-executable)
    (user-error "%s is not installed, so there is nothing to ask GitHub"
                heks/github-repo-executable))
  (unless (eq 0 (car (heks/github-repo--run '("auth" "status"))))
    (user-error "gh is not authenticated; run 'gh auth login' first")))

(defun heks/github-repo--login ()
  "Return the login of the signed-in GitHub user, or nil."
  (when-let* ((output (ignore-errors (heks/github-repo--gh '("api" "user" "--jq" ".login")))))
             (string-trim output)))

(defun heks/github-repo--slug (slug)
  "Return SLUG as OWNER/REPO, taking the owner from the signed-in user."
  (if (string-match-p "/" slug)
    slug
    (let ((login (heks/github-repo--login)))
      (unless login
        (user-error "gh is not authenticated, so the owner of '%s' is unknown" slug))
      (format "%s/%s" login slug))))

(defun heks/github-repo--read-slug (&optional prompt)
  "Read OWNER/REPO, defaulting to the repository the buffer belongs to.
A project whose origin is a GitHub remote offers it, so the answer to the
prompt is usually RET; a directory that is not one falls back to this user
and the directory's name."
  (let* ((login (heks/github-repo--login))
         (name (file-name-nondirectory (directory-file-name default-directory)))
         (default (or (heks/github-repo--project-slug)
                      (if login (format "%s/%s" login name) name))))
    (read-string (format "%s [%s]: " (or prompt "Repository (OWNER/REPO)") default)
                 nil nil default)))

(defun heks/github-repo--string (value)
  "Return VALUE when it is a non-empty string, nil for a null or a boolean."
  (and (stringp value) (not (string-empty-p value)) value))

(defun heks/github-repo--get (alist key)
  "Return the value of KEY in ALIST, missing or not."
  (cdr (assq key alist)))

(defun heks/github-repo--pick (alist keys)
  "Return the entries of ALIST named by KEYS, in that order, `:null' when absent."
  (mapcar (lambda (key)
            (cons key (alist-get key alist)))
          keys))

(defun heks/github-repo--without-nulls (alist)
  "Return ALIST without the entries that hold nothing, the unset settings."
  (seq-filter #'cdr alist))

;;;
;;; ====== Capture ======
;;;

(defun heks/github-repo--security (repo)
  "Return the security features of REPO, each by the status it has."
  (mapcar (lambda (entry)
            (cons (car entry) (heks/github-repo--pick (cdr entry) '(status))))
          (alist-get 'security_and_analysis repo)))

(defun heks/github-repo--clean-ruleset (ruleset)
  "Return RULESET without the parts that say where it is rather than what it does."
  (seq-reduce (lambda (ruleset key) (assq-delete-all key ruleset))
              heks/github-repo-ruleset-noise
              (copy-tree ruleset)))

(defun heks/github-repo--capture-rulesets (slug)
  "Return the rulesets of SLUG, without their identifiers, sorted by name."
  (let ((listed (or (heks/github-repo--query (format "repos/%s/rulesets" slug)) '())))
    (sort (mapcar (lambda (summary)
                    (heks/github-repo--clean-ruleset
                     (or (heks/github-repo--query
                          (format "repos/%s/rulesets/%s" slug (alist-get 'id summary)))
                         summary)))
                  listed)
          (lambda (one two)
            (string< (or (heks/github-repo--string (alist-get 'name one)) "")
                     (or (heks/github-repo--string (alist-get 'name two)) ""))))))

(defun heks/github-repo-capture-spec (slug)
  "Return the live settings of SLUG, in the shape of `heks/github-repo-spec'.

Everything that belongs to this repository in particular (its name, its
description) is dropped or defaulted, so that what comes back can be given
to another one."
  (let* ((slug (heks/github-repo--slug slug))
         (repo (heks/github-repo--query (format "repos/%s" slug)))
         (pvr (heks/github-repo--query (format "repos/%s/private-vulnerability-reporting" slug)))
         (actions (heks/github-repo--query (format "repos/%s/actions/permissions" slug)))
         (workflow (heks/github-repo--query (format "repos/%s/actions/permissions/workflow" slug))))
    (unless repo
      (user-error "could not read the repository %s" slug))
    (list
     (cons 'template slug)
     (cons 'captured_at (format-time-string "%Y-%m-%dT%H:%M:%SZ" nil t))
     (cons 'repo
           (append
            (list (cons 'default_branch (alist-get 'default_branch repo))
                  (cons 'visibility (alist-get 'visibility repo))
                  (cons 'description nil))
            (mapcar (lambda (field) (cons field (alist-get field repo)))
                    heks/github-repo-repo-fields)
            (list (cons 'security_and_analysis
                        (heks/github-repo--security repo)))))
     (cons 'private_vulnerability_reporting
           (if (eq (alist-get 'enabled pvr) t) t json-false))
     (cons 'actions_permissions
           (heks/github-repo--pick actions '(enabled allowed_actions sha_pinning_required)))
     (cons 'workflow_permissions
           (heks/github-repo--pick workflow
                                   '(default_workflow_permissions
                                     can_approve_pull_request_reviews)))
     (cons 'rulesets (heks/github-repo--capture-rulesets slug)))))

(defun heks/github-repo--pp (object)
  "Return OBJECT as pretty-printed Lisp, quotes kept as quotes."
  (let ((print-quoted t)
        (print-length nil)
        (print-level nil))
    (concat (pp-to-string object) "\n")))

(defun heks/github-repo-capture (slug &optional filename)
  "Show the live settings of SLUG as a `heks/github-repo-spec' form.
With a prefix argument, or FILENAME, write that form to FILENAME instead:
loading the file is what gives the next `heks/github-repo-apply' the
settings of the repository it was captured from."
  (interactive
    (list (heks/github-repo--read-slug)
          (when current-prefix-arg
            (read-file-name "Write the spec to: " nil nil nil "github-repo-settings.el"))))
  (heks/github-repo--require)
  (let* ((slug (heks/github-repo--slug slug))
         (form (heks/github-repo--pp
                (list 'defconst 'heks/github-repo-spec
                      (list 'quote (heks/github-repo-capture-spec slug))))))
    (if filename
      (progn
        (with-temp-file filename (insert form))
        (message "wrote %s" (abbreviate-file-name (expand-file-name filename))))
      (let ((buffer (get-buffer-create heks/github-repo-spec-buffer)))
        (with-current-buffer buffer
          (let ((inhibit-read-only t))
            (erase-buffer))
          (emacs-lisp-mode)
          (insert (format ";; captured from %s on %s\n"
                          slug (format-time-string "%Y-%m-%d %H:%M" nil t)))
          (insert form)
          (goto-char (point-min)))
        (pop-to-buffer buffer)
        (message "The spec captured from %s" slug)))
    form))

;;;
;;; ====== Payloads GitHub will take ======
;;;

(defun heks/github-repo-reduce-ruleset (ruleset)
  "Return RULESET with one unsupported thing dropped, or nil when none is left.

GitHub answers a ruleset it cannot take with an error that names nothing.
What it cannot take is a rule newer than the repository -- Copilot code
review, code quality, code scanning -- or, on an older repository, the
parameter that asks for an extra approval when a commit has no attributed
author.  One is dropped per attempt and the request is made again, so a
repository that takes all of them gets all of them."
  (let* ((rules (alist-get 'rules ruleset))
         (pull (seq-find (lambda (rule)
                           (equal (alist-get 'type rule) "pull_request"))
                         rules))
         (extra (and pull
                     (assq 'require_extra_approval_for_unattributed_changes
                           (alist-get 'parameters pull)))))
    (cond
      (extra
        (heks/github-repo--warn
         "dropping unsupported pull_request parameter: require_extra_approval_for_unattributed_changes")
        (let ((copy (copy-tree ruleset)))
          (dolist (rule (alist-get 'rules copy))
            (when (equal (alist-get 'type rule) "pull_request")
              (setf (alist-get 'parameters rule)
                    (assq-delete-all 'require_extra_approval_for_unattributed_changes
                                     (alist-get 'parameters rule)))))
          copy))
      (t
        (let ((optional (seq-find (lambda (rule)
                                    (memq (intern (alist-get 'type rule))
                                          heks/github-repo-optional-rules))
                                  rules)))
          (when optional
            (heks/github-repo--warn "dropping unsupported rule: %s"
                                    (alist-get 'type optional))
            (let ((copy (copy-tree ruleset)))
              (setf (alist-get 'rules copy)
                    (seq-remove (lambda (rule)
                                  (equal (alist-get 'type rule)
                                         (alist-get 'type optional)))
                                (alist-get 'rules copy)))
              copy)))))))

(defun heks/github-repo-apply-ruleset (slug ruleset)
  "Make the ruleset RULESET of the repository SLUG exist as it is described.
A ruleset of that name is updated and anything else is created, so running
this twice changes nothing the second time."
  (let ((name (alist-get 'name ruleset))
        (path (format "repos/%s/rulesets" slug))
        (id nil))
    (heks/github-repo--step "ruleset: %s" name)
    (when (heks/github-repo--exists-p slug)
      (setq id (alist-get 'id
                          (seq-find (lambda (ruleset)
                                      (equal (alist-get 'name ruleset) name))
                                    (heks/github-repo--query path)))))
    (cond
      (heks/github-repo-dry-run
        (heks/github-repo--log "dry-run: gh api -X %s %s <<< %s"
                               (if id "PUT" "POST")
                               (if id (format "%s/%s" path id) path)
                               (json-encode ruleset)))
      (t
        (let ((attempt ruleset)
              (done nil))
          (while (not done)
            (let* ((url (if id (format "%s/%s" path id) path))
                   (result (heks/github-repo--request (if id "PUT" "POST") url
                                                      (json-encode attempt))))
              (cond
                ((car result)
                 (if id
                   (heks/github-repo--log "updated ruleset %s (id %s)" name id)
                   (let ((created (ignore-errors
                                    (json-parse-string (cdr result)
                                                       :object-type 'alist
                                                       :null-object nil
                                                       :false-object json-false))))
                     (heks/github-repo--log "created ruleset %s (id %s)"
                                            name (alist-get 'id created))))
                 (setq done t))
                ((string-match-p "Upgrade to GitHub Pro" (cdr result))
                 ;; Rulesets are not available on a free private repository,
                 ;; and no amount of trimming the payload will change that.
                 (heks/github-repo--warn
                  "rulesets need a public repository or a paid plan; skipping '%s'" name)
                 (setq done t))
                (t
                  (let ((reduced (heks/github-repo-reduce-ruleset attempt)))
                    (unless reduced
                      (user-error "could not apply ruleset '%s': %s" name (cdr result)))
                    (setq attempt reduced)))))))))))

;;;
;;; ====== git: the remote and the first push ======
;;;

(defun heks/github-repo--git-status (directory args)
  "Return (STATUS . OUTPUT) of git ARGS run in DIRECTORY."
  (with-temp-buffer
    (let ((default-directory (file-name-as-directory (expand-file-name directory))))
      (cons (apply #'call-process "git" nil t nil args)
            (buffer-string)))))

(defun heks/github-repo--git (directory &rest args)
  "Return the trimmed output of git ARGS in DIRECTORY, or nil when it fails."
  ;; `--git-status' answers with a cons, so the pattern is dotted: a
  ;; two-element list pattern would bind OUTPUT to nil, and `string-trim'
  ;; would refuse it.
  (pcase-let ((`(,status . ,output) (heks/github-repo--git-status directory args)))
    (when (eq status 0) (string-trim output))))

(defun heks/github-repo--git-run (directory &rest args)
  "Run the mutating git command ARGS in DIRECTORY, unless dry-running."
  (if heks/github-repo-dry-run
    (progn
      (heks/github-repo--log "dry-run: git -C %s %s"
                             directory (string-join args " "))
      "")
    (pcase-let* ((`(,status . ,output) (heks/github-repo--git-status directory args))
                 (trimmed (string-trim output)))
      (heks/github-repo--log "git %s%s" (string-join args " ")
                             (if (string-empty-p trimmed) "" (format "\n%s" trimmed)))
      (unless (eq status 0)
        (user-error "git %s failed: %s" (string-join args " ") trimmed))
      trimmed)))

(defun heks/github-repo--ssh-host ()
  "Return the ssh host that git@ URLs should name.

An alias from ~/.ssh/config whose HostName is github.com, when there is
one, so that the key configured for it is the key ssh offers; otherwise
github.com."
  (let ((config (expand-file-name "~/.ssh/config"))
        (host nil)
        (current nil))
    (when (file-readable-p config)
      (with-temp-buffer
        (insert-file-contents config)
        (goto-char (point-min))
        (while (and (not host) (not (eobp)))
          (cond ((looking-at "^[ \t]*[Hh]ost[ \t]+\\([^ \t\r\n]+\\)")
                 (setq current (unless (equal (match-string 1) "*")
                                 (match-string 1))))
                ((looking-at "^[ \t]*[Hh]ost[Nn]ame[ \t]+github\\.com[ \t]*$")
                 (setq host current)))
          (forward-line 1))))
    (or host "github.com")))

(defun heks/github-repo--github-url (slug)
  "Return the git URL of SLUG, by the protocol this configuration uses."
  (let ((protocol (or heks/github-repo-protocol
                      (heks/github-repo--string
                       (ignore-errors
                         (string-trim
                          (heks/github-repo--gh '("config" "get" "git_protocol"
                                                  "--host" "github.com")))))
                      "https")))
    (if (equal protocol "ssh")
      (format "git@%s:%s.git" (or heks/github-repo-ssh-host
                                  (heks/github-repo--ssh-host))
              slug)
      (format "https://github.com/%s.git" slug))))

(defun heks/github-repo--systemd-agent ()
  "Return the agent socket the systemd user session reports, or nil."
  (when (executable-find "systemctl")
    (with-temp-buffer
      (when (eq 0 (call-process "systemctl" nil t nil "--user" "show-environment"))
        (when (string-match "^SSH_AUTH_SOCK=\\(.+\\)$" (buffer-string))
          (match-string 1 (buffer-string)))))))

(defun heks/github-repo--agent ()
  "Return the socket of an ssh agent that answers, or nil.

The inherited SSH_AUTH_SOCK cannot be trusted on its own: a shell, an
editor or a terminal that outlives the agent that was running when it
started keeps pointing at a path that no longer exists, and ssh then never
asks a real agent -- which reads as \"the key is not registered\".  So the
inherited socket only counts while it answers (`ssh-add -l'), and the
session's own answer, and the usual runtime paths, are tried after it."
  (let* ((runtime (or (getenv "XDG_RUNTIME_DIR")
                      (format "/run/user/%d" (user-uid))))
         (candidates (delq nil (list (getenv "SSH_AUTH_SOCK")
                                     (heks/github-repo--systemd-agent)
                                     (expand-file-name "gcr/ssh" runtime)
                                     (expand-file-name "ssh-agent/socket" runtime)
                                     (expand-file-name "ssh-agent.socket" runtime)))))
    (seq-find (lambda (socket)
                (and (file-exists-p socket)
                     (let* ((process-environment
                             (cons (format "SSH_AUTH_SOCK=%s" socket)
                                   process-environment)))
                       ;; 0 = identities listed, 1 = a live agent with
                       ;; none, 2 = cannot connect.
                       (memq (process-file "ssh-add" nil nil nil "-l") '(0 1)))))
              candidates)))

(defun heks/github-repo--ssh-identity ()
  "Return the key ssh would offer for the GitHub host, or nil."
  (when (executable-find "ssh")
    (with-temp-buffer
      (when (eq 0 (call-process "ssh" nil t nil "-G" (heks/github-repo--ssh-host)))
        (when (string-match "^identityfile \\(.+?\\)$" (buffer-string))
          (match-string 1 (buffer-string)))))))

(defun heks/github-repo--ssh-reaches-github-p ()
  "Return whether ssh to the GitHub host authenticates."
  (when (executable-find "ssh")
    (with-temp-buffer
      (call-process "ssh" nil t nil
                    "-o" "BatchMode=yes" "-o" "StrictHostKeyChecking=accept-new"
                    "-o" "ConnectTimeout=5" "-T"
                    (format "git@%s" (heks/github-repo--ssh-host)))
      (string-match-p "successfully authenticated" (buffer-string)))))

(defun heks/github-repo--prepare-ssh ()
  "Make the push use an agent that answers, and stop when GitHub cannot be reached."
  (let ((agent (heks/github-repo--agent)))
    (cond
      ((and agent (not (equal agent (getenv "SSH_AUTH_SOCK"))))
       (when (getenv "SSH_AUTH_SOCK")
         (heks/github-repo--log "ignoring a dead SSH_AUTH_SOCK (%s)"
                                (getenv "SSH_AUTH_SOCK")))
       (heks/github-repo--log "using the agent at %s" agent)
       (setenv "SSH_AUTH_SOCK" agent))
      ((and (getenv "SSH_AUTH_SOCK")
            (not (file-exists-p (getenv "SSH_AUTH_SOCK"))))
       (heks/github-repo--warn "SSH_AUTH_SOCK points at %s, which is not a socket"
                               (getenv "SSH_AUTH_SOCK"))))
    (unless (heks/github-repo--ssh-reaches-github-p)
      (let ((host (heks/github-repo--ssh-host))
            (key (heks/github-repo--ssh-identity)))
        (if heks/github-repo-dry-run
          (heks/github-repo--warn "ssh to %s does not authenticate; a real run would stop here" host)
          (user-error "ssh to %s does not authenticate; add %s to https://github.com/settings/keys, or set heks/github-repo-protocol to 'https"
                      host (or key "your key")))))))

(defun heks/github-repo--use-gh-credentials (directory)
  "Let DIRECTORY take the GitHub token from gh as its credential, locally."
  (heks/github-repo--git-run directory "config" "--local"
                             "credential.https://github.com.helper"
                             "!gh auth git-credential"))

(defun heks/github-repo--ensure-remote (directory name slug)
  "Make the remote NAME of DIRECTORY point at SLUG, keeping the others.
A remote that points at Codeberg is renamed to `codeberg' rather than
removed, because the repository it names is still there for a while."
  (let ((url (heks/github-repo--github-url slug))
        (current (heks/github-repo--git directory "remote" "get-url" name)))
    (if (string-match-p "\\`https://" url)
      (heks/github-repo--use-gh-credentials directory)
      (heks/github-repo--prepare-ssh))
    (cond
      ((null current)
       (heks/github-repo--log "adding remote %s -> %s" name url)
       (heks/github-repo--git-run directory "remote" "add" name url))
      ((string-match-p (format "github\\.com[:/]%s\\.git\\'" (regexp-quote slug))
                       current)
       (if (equal current url)
         (heks/github-repo--log "remote %s -> %s" name current)
         (heks/github-repo--log "updating remote %s: %s -> %s" name current url)
         (heks/github-repo--git-run directory "remote" "set-url" name url)))
      ((and (string-match-p "codeberg\\.org" current)
            (null (heks/github-repo--git directory "remote" "get-url" "codeberg")))
       (heks/github-repo--log "renaming remote %s -> codeberg (%s)" name current)
       (heks/github-repo--git-run directory "remote" "rename" name "codeberg")
       (heks/github-repo--git-run directory "remote" "add" name url))
      (t
        (user-error "remote %s points at %s, not %s; rename or remove it first"
                    name current url)))))

(defun heks/github-repo--project-root ()
  "Return the root of the current project, or the current directory."
  (or (when-let* ((project (project-current)))
                 (project-root project))
      default-directory))

(defun heks/github-repo--slug-from-url (url)
  "Return OWNER/REPO named by the GitHub remote URL URL, or nil.
It reads the two last segments of what ssh and https both write --
`git@host:owner/repo.git' and `https://github.com/owner/repo.git' -- and
says nothing about a URL that is not GitHub's, since a Codeberg remote is
not a repository this tool can configure."
  (when (and url (string-match-p "github\\.com" url))
    (when (string-match "\\([[:alnum:]_.-]+\\)/\\([[:alnum:]_.-]+\\)\\'" url)
      (format "%s/%s"
              (match-string 1 url)
              (string-remove-suffix ".git"
                                    (string-remove-suffix "/" (match-string 2 url)))))))

(defun heks/github-repo--project-slug ()
  "Return OWNER/REPO of the current project's origin, when it is on GitHub."
  (when (fboundp 'project-current)
    (heks/github-repo--slug-from-url
     (heks/github-repo--git (heks/github-repo--project-root)
                            "remote" "get-url" "origin"))))

;;;
;;; ====== Apply ======
;;;

(defun heks/github-repo--apply-settings (slug spec)
  "Apply the repository settings of SPEC to SLUG, one field per request."
  (let* ((repo (alist-get 'repo spec))
         (path (format "repos/%s" slug))
         (description (heks/github-repo--string (alist-get 'description repo)))
         (visibility (heks/github-repo--string (alist-get 'visibility repo)))
         (owner (car (split-string slug "/")))
         (owner-type (or (alist-get 'type (heks/github-repo--query
                                           (format "users/%s" owner)))
                         "User")))
    (heks/github-repo--step "repository settings")
    (when description
      (heks/github-repo--api-try "PATCH" path
                                 (json-encode (list (cons 'description description))))
      (heks/github-repo--log "description: %s" description))
    (when visibility
      (heks/github-repo--api-try "PATCH" path
                                 (json-encode (list (cons 'visibility visibility))))
      (heks/github-repo--log "visibility: %s" visibility))
    (dolist (key '(has_issues has_projects has_wiki has_discussions
                              web_commit_signoff_required is_template allow_forking
                              allow_auto_merge allow_update_branch delete_branch_on_merge))
      (let ((value (alist-get key repo)))
        (cond
          ((null value) nil)
          ((and (eq key 'allow_forking) (not (equal owner-type "Organization")))
           ;; GitHub only lets an organisation change this on a private
           ;; repository; a user repository is GitHub's own answer.
           (heks/github-repo--log
            "allow_forking: managed by GitHub for user-owned repositories, skipping"))
          (t
            (heks/github-repo--api-try "PATCH" path
                                       (json-encode (list (cons key value))))))))
    (dolist (key '(allow_merge_commit allow_squash_merge allow_rebase_merge))
      (let ((value (alist-get key repo)))
        (unless (null value)
          (heks/github-repo--api-try "PATCH" path
                                     (json-encode (list (cons key value)))))))
    (let ((title (heks/github-repo--string (alist-get 'squash_merge_commit_title repo)))
          (message (heks/github-repo--string (alist-get 'squash_merge_commit_message repo))))
      (when (and title message)
        ;; The pair is sent together: GitHub refuses one without the other.
        (heks/github-repo--api-try
         "PATCH" path
         (json-encode (list (cons 'squash_merge_commit_title title)
                            (cons 'squash_merge_commit_message message))))))
    (when (eq (alist-get 'allow_merge_commit repo) t)
      (let ((title (heks/github-repo--string (alist-get 'merge_commit_title repo)))
            (message (heks/github-repo--string (alist-get 'merge_commit_message repo))))
        (when (and title message)
          ;; A merge message only means something while merge commits exist.
          (heks/github-repo--api-try
           "PATCH" path
           (json-encode (list (cons 'merge_commit_title title)
                              (cons 'merge_commit_message message)))))))
    (let ((branch (heks/github-repo--string (alist-get 'default_branch repo))))
      (when branch
        (cond
          ((heks/github-repo--query (format "repos/%s/branches/%s" slug branch))
           (heks/github-repo--api "PATCH" path
                                  (json-encode (list (cons 'default_branch branch))))
           (heks/github-repo--log "default branch: %s" branch))
          (heks/github-repo-dry-run
            (heks/github-repo--log "dry-run: gh api -X PATCH %s <<< %s"
                                   path (json-encode (list (cons 'default_branch branch)))))
          (t
            ;; Setting a default branch that is not there yet is a request
            ;; GitHub answers with an error; pushing it and running again is
            ;; what the script said, and it is still the answer.
            (heks/github-repo--warn
             "default branch '%s' does not exist yet; push it and run apply again"
             branch)))))))

(defun heks/github-repo--apply-security (slug spec)
  "Apply the security features of SPEC to SLUG, one feature per request."
  (let* ((repo (alist-get 'repo spec))
         (features (alist-get 'security_and_analysis repo))
         (path (format "repos/%s" slug)))
    (heks/github-repo--step "security")
    (dolist (feature '(secret_scanning secret_scanning_push_protection
                                       secret_scanning_non_provider_patterns
                                       secret_scanning_validity_checks))
      (let ((status (heks/github-repo--string
                     (alist-get 'status (alist-get feature features)))))
        (when status
          ;; One call per feature, so a paid-only one cannot block the rest.
          (heks/github-repo--api-try
           "PATCH" path
           (json-encode
            (list (cons 'security_and_analysis
                        (list (cons feature (list (cons 'status status))))))))
          (heks/github-repo--log "%s: %s" feature status))))
    (let ((dependabot (heks/github-repo--string
                       (alist-get 'status
                                  (alist-get 'dependabot_security_updates features)))))
      (cond
        ((equal dependabot "enabled")
         (heks/github-repo--api-try "PUT" (format "repos/%s/automated-security-fixes" slug) "{}")
         (heks/github-repo--log "dependabot security updates: enabled"))
        ((equal dependabot "disabled")
         (heks/github-repo--api-try "DELETE" (format "repos/%s/automated-security-fixes" slug))
         (heks/github-repo--log "dependabot security updates: disabled"))))
    (if (eq (alist-get 'private_vulnerability_reporting spec) t)
      (progn
        (heks/github-repo--api-try "PUT" (format "repos/%s/private-vulnerability-reporting" slug) "{}")
        (heks/github-repo--log "private vulnerability reporting: enabled"))
      (heks/github-repo--api-try "DELETE" (format "repos/%s/private-vulnerability-reporting" slug))
      (heks/github-repo--log "private vulnerability reporting: disabled"))))

(defun heks/github-repo--apply-actions (slug spec)
  "Apply the Actions permissions of SPEC to SLUG."
  (heks/github-repo--step "actions")
  (let ((actions (heks/github-repo--without-nulls (alist-get 'actions_permissions spec)))
        (workflow (heks/github-repo--without-nulls (alist-get 'workflow_permissions spec))))
    (when actions
      (heks/github-repo--api-try "PUT" (format "repos/%s/actions/permissions" slug)
                                 (json-encode actions))
      (heks/github-repo--log "repository actions permissions applied"))
    (when workflow
      (heks/github-repo--api-try "PUT" (format "repos/%s/actions/permissions/workflow" slug)
                                 (json-encode workflow))
      (heks/github-repo--log "default workflow permissions applied"))))

(defun heks/github-repo-apply (slug &optional description visibility source push spec)
  "Make the repository SLUG match SPEC, or the spec SLUG is given.

The spec is `heks/github-repo-specification' for SLUG unless SPEC is
passed, so one house style and its exceptions live in configuration
rather than in the call.  The repository is created when it does not
exist, DESCRIPTION and VISIBILITY are set when given (VISIBILITY nil
means the spec's), and SOURCE -- a git checkout -- is given the GitHub
remote, with PUSH pushing its default branch and tags once the remote is
there.  Every write is skipped by a prefix argument, and a settings write
that GitHub refuses is a warning rather than the end of the run, because
the features a repository may have depend on its plan and its visibility.

Called from Lisp -- by `heks/github-repo-apply-all', say -- it writes to
the log buffer and lets the caller decide when to show it."
  (interactive
    (let* ((slug (heks/github-repo--read-slug))
           (project (heks/github-repo--project-root))
           (attach (and project
                        (y-or-n-p (format "Attach %s as a remote? "
                                          (abbreviate-file-name project))))))
      (list slug
            (let ((answer (read-string "Description (empty leaves it as it is): ")))
              (unless (string-empty-p answer) answer))
            (let ((answer (completing-read "Visibility: "
                                           '("public" "private" "internal")
                                           nil t nil nil nil)))
              (unless (string-empty-p answer) answer))
            (and attach project)
            (and attach (yes-or-no-p "Push its default branch and tags? ")))))
  (let ((heks/github-repo-dry-run (and current-prefix-arg t)))
    (condition-case err
      (progn
        (heks/github-repo--require)
        (setq slug (heks/github-repo--slug slug))
        (when (called-interactively-p 'interactive)
          (heks/github-repo--clear-log))
        (let* ((spec (or spec (heks/github-repo-specification slug)))
               (repo (alist-get 'repo spec))
               (wanted (heks/github-repo--string (alist-get 'default_branch repo))))
          (when heks/github-repo-dry-run
            (heks/github-repo--log "dry-run: no changes will be made"))
          ;; 1. the repository itself
          (heks/github-repo--step "repository %s" slug)
          (if (heks/github-repo--exists-p slug)
            (heks/github-repo--log "already exists")
            (let* ((visibility (or visibility
                                   (heks/github-repo--string
                                    (alist-get 'visibility repo))
                                   "public"))
                   (args (append (list "repo" "create" slug
                                       (concat "--" visibility))
                                 (when description (list "--description" description)))))
              (if heks/github-repo-dry-run
                (heks/github-repo--log "dry-run: gh %s" (string-join args " "))
                (heks/github-repo--gh args))
              (heks/github-repo--log "created (%s)" visibility)))
          ;; 2. the remote and the first push, so that the default branch
          ;;    exists before anything is set on it
          (when source
            (heks/github-repo--step "git remote in %s"
                                    (abbreviate-file-name
                                     (expand-file-name source)))
            (unless (heks/github-repo--git source "rev-parse" "--git-dir")
              (user-error "%s is not a git checkout" source))
            (heks/github-repo--ensure-remote source "origin" slug)
            (when push
              (let* ((branch (heks/github-repo--git source "symbolic-ref" "--quiet"
                                                    "--short" "HEAD"))
                     (default (or wanted branch)))
                (unless branch
                  (user-error "cannot push from a detached HEAD"))
                (unless (equal branch default)
                  (user-error "checked out on '%s' but the spec protects '%s'; check '%s' out first"
                              branch default default))
                (heks/github-repo--step "pushing %s" branch)
                (heks/github-repo--git-run source "push" "-u" "origin" branch)
                (heks/github-repo--git-run source "push" "origin" "--tags"))))
          ;; 3. settings, security, Actions, rulesets
          (heks/github-repo--apply-settings slug spec)
          (heks/github-repo--apply-security slug spec)
          (heks/github-repo--apply-actions slug spec)
          (dolist (ruleset (alist-get 'rulesets spec))
            (heks/github-repo-apply-ruleset slug ruleset))
          (heks/github-repo--step "done")
          (heks/github-repo--log "https://github.com/%s" slug)
          (when (called-interactively-p 'interactive)
            (heks/github-repo--show-log))))
      (error
        (heks/github-repo--log "error: %s" (error-message-string err))
        (when (called-interactively-p 'interactive)
          (heks/github-repo--show-log))
        (signal (car err) (cdr err))))))

;;;
;;; ====== Verify ======
;;;

(defun heks/github-repo--sort-keys (object)
  "Return OBJECT with the keys of every object in one fixed order."
  (cond
    ((and (consp object) (consp (car object)) (symbolp (caar object)))
     (mapcar (lambda (cell)
               (cons (car cell) (heks/github-repo--sort-keys (cdr cell))))
             (sort (copy-sequence object)
                   (lambda (one two)
                     (string< (symbol-name (car one))
                              (symbol-name (car two)))))))
    ((vectorp object) (mapcar #'heks/github-repo--sort-keys (append object nil)))
    ((consp object) (mapcar #'heks/github-repo--sort-keys object))
    (t object)))

(defun heks/github-repo-normalize (spec)
  "Return SPEC in the canonical form `heks/github-repo-verify' compares.

What is dropped is what belongs to the capture rather than to the
repository: the template it was taken from and when.  What is ordered is
what GitHub does not order -- the keys of every object, the rulesets by
name, the rules of each by type -- so that a difference found is a
difference in settings and not in the order they came back in."
  (let* ((spec (copy-tree spec))
         (spec (assq-delete-all 'template spec))
         (spec (assq-delete-all 'captured_at spec))
         (repo (alist-get 'repo spec))
         (rulesets (alist-get 'rulesets spec)))
    ;; The description belongs to the repository and not to the scheme of
    ;; settings, so it is neither compared nor kept.
    (when repo
      (setf (alist-get 'repo spec) (assq-delete-all 'description repo)))
    (dolist (ruleset rulesets)
      (setf (alist-get 'rules ruleset)
            (sort (copy-sequence (alist-get 'rules ruleset))
                  (lambda (one two)
                    (string< (or (alist-get 'type one) "")
                             (or (alist-get 'type two) ""))))))
    (setf (alist-get 'rulesets spec)
          (sort rulesets
                (lambda (one two)
                  (string< (or (alist-get 'name one) "")
                           (or (alist-get 'name two) "")))))
    (heks/github-repo--sort-keys spec)))

(defun heks/github-repo--diff (one two)
  "Return a unified diff between the printed forms of ONE and TWO."
  (let ((file-one (make-temp-file "heks-github-repo" nil ".el"))
        (file-two (make-temp-file "heks-github-repo" nil ".el")))
    (unwind-protect
      (progn
        (with-temp-file file-one (insert (heks/github-repo--pp one)))
        (with-temp-file file-two (insert (heks/github-repo--pp two)))
        (if (executable-find "diff")
          (with-temp-buffer
            (call-process "diff" nil t nil "-u"
                          "--label" "spec" "--label" "live"
                          file-one file-two)
            (buffer-string))
          ;; Without diff the two forms are still comparable, one under
          ;; the other; a difference found is worth showing somehow.
          (format "spec:\n%s\nlive:\n%s"
                  (heks/github-repo--pp one) (heks/github-repo--pp two))))
      (delete-file file-one)
      (delete-file file-two))))

(defun heks/github-repo-verify (slug &optional spec)
  "Report whether SLUG still matches SPEC, or the spec SLUG is given.
The live repository is captured, normalized and compared with the spec;
any difference is shown as a diff, and the return value says whether there
was one."
  (interactive (list (heks/github-repo--read-slug)))
  (heks/github-repo--require)
  (let* ((slug (heks/github-repo--slug slug))
         (spec (or spec (heks/github-repo-specification slug)))
         (want (heks/github-repo-normalize spec))
         (have (heks/github-repo-normalize (heks/github-repo-capture-spec slug)))
         (same (equal want have)))
    (cond
      (same
        (message "%s matches heks/github-repo-spec" slug)
        t)
      (t
        (let ((buffer (get-buffer-create heks/github-repo-log-buffer)))
          (with-current-buffer buffer
            (let ((inhibit-read-only t))
              (erase-buffer)
              (insert (format "%s differs from heks/github-repo-spec:\n\n" slug))
              (insert (heks/github-repo--diff want have)))
            (special-mode)
            (goto-char (point-min)))
          (pop-to-buffer buffer))
        nil))))

;;;
;;; ====== All of them at once ======
;;;

(defun heks/github-repo-repositories (&optional owner)
  "Return the repositories OWNER has, as OWNER/REPO strings, sorted.
OWNER is the signed-in user when it is not given.  Forks are left out
unless `heks/github-repo-include-forks' says otherwise, and archived
repositories are always left out."
  (let* ((owner (or owner (heks/github-repo--login)
                    (user-error "gh is not authenticated, so the repositories are unknown")))
         (repos (heks/github-repo--from-json
                 (json-parse-string
                  (heks/github-repo--gh (list "repo" "list" owner "--limit" "1000"
                                              "--json" "nameWithOwner,isFork,isArchived"))
                  :object-type 'alist
                  :array-type 'array
                  :null-object nil
                  :false-object json-false))))
    (sort (delq nil
                (mapcar (lambda (repo)
                          (when (and (not (eq (alist-get 'isArchived repo) t))
                                     (or heks/github-repo-include-forks
                                         (not (eq (alist-get 'isFork repo) t))))
                            (alist-get 'nameWithOwner repo)))
                        repos))
          #'string<)))

(defun heks/github-repo--read-repositories (&optional prompt)
  "Read one or more OWNER/REPO, completed from the user's repositories.
An empty answer is every repository `heks/github-repo-repositories'
considers, which is what makes the batch commands one command."
  (let ((all (heks/github-repo-repositories)))
    (or (completing-read-multiple
         (format "%s (one or more, empty for all %d): "
                 (or prompt "Repositories") (length all))
         all)
        all)))

(defun heks/github-repo-verify-all (repos)
  "Compare REPOS with the spec each one is given, and report them together.
One line says whether each still matches; the difference of every one that
does not is printed under its name, so that drift is read in one place
rather than one repository at a time.  Return non-nil when all of them
match."
  (interactive (list (heks/github-repo--read-repositories)))
  (heks/github-repo--require)
  (let ((differing 0)
        (buffer (get-buffer-create heks/github-repo-log-buffer)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "%d repositories against their spec\n\n" (length repos)))
        (dolist (slug repos)
          (let* ((spec (heks/github-repo-specification slug))
                 (want (heks/github-repo-normalize spec))
                 (have (heks/github-repo-normalize
                        (heks/github-repo-capture-spec slug))))
            (if (equal want have)
              (insert (propertize (format "  ok       %s\n" slug)
                                  'face 'success))
              (setq differing (1+ differing))
              (insert (propertize (format "  differs  %s\n" slug)
                                  'face 'warning))
              (dolist (line (split-string (heks/github-repo--diff want have) "\n"))
                (unless (string-empty-p line)
                  (insert (format "             %s\n" line)))))))
        (goto-char (point-min)))
      (special-mode))
    (pop-to-buffer buffer)
    (message "%d of %d repositories differ from the spec"
             differing (length repos))
    (zerop differing)))

(defun heks/github-repo-apply-all (repos &optional dry-run)
  "Make every repository in REPOS match the spec it is given.
A DRY-RUN writes nothing and says what would be done.  Each repository is
applied on its own, so a refusal on one is a line in the log rather than
the end of the ones after it; the return value says whether every one was
applied."
  (interactive
    (progn
      (heks/github-repo--require)
      (let ((repos (heks/github-repo--read-repositories)))
        (when (and (> (length repos) 1)
                   (not (yes-or-no-p
                         (format "Apply the spec to %d repositories? "
                                 (length repos)))))
          (user-error "Nothing was applied"))
        (list repos current-prefix-arg))))
  (let ((heks/github-repo-dry-run (and dry-run t))
        (applied 0)
        (failed nil))
    (heks/github-repo--require)
    (heks/github-repo--clear-log)
    (dolist (slug repos)
      (condition-case err
        (progn
          (heks/github-repo-apply slug)
          (setq applied (1+ applied)))
        (error
          (push slug failed)
          (heks/github-repo--log "error applying %s: %s" slug
                                 (error-message-string err)))))
    (heks/github-repo--step "summary")
    (heks/github-repo--log "%d of %d applied%s"
                           applied (length repos)
                           (if failed
                             (format "; failed: %s" (string-join (nreverse failed) ", "))
                             ""))
    (heks/github-repo--show-log)
    (null failed)))

(provide 'heks/github-repo)

;;; github-repo.el ends here
