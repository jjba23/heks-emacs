;;; dev-kubernetes.el --- Kubernetes and JSON log viewing -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>


;;; Commentary:

;; Kubernetes and JSON log viewing.

;;; Code:

(use-package kubed
  :ensure (:host github :repo "eshelyaron/kubed" :branch "master")
  ;; `kubed-prefix-map' is the package's own bundle of direct commands
  ;; (`p' pods, `d' deployments, `j' jobs, `L' logs, `k' the transient
  ;; dispatcher below, and so on -- see `kubed-prefix-map' for the full
  ;; list); `C-c U' opens `kubed-transient' straight away, the discoverable
  ;; menu version of the same commands, for when the mnemonic under
  ;; `C-c u' is not remembered.  Kept off `C-c k'/`C-c K': that is one typo
  ;; away from `C-c k' buffer-killing commands elsewhere, and a stray `D'
  ;; (delete) or `R' (run) landing in the wrong cluster is not a mistake
  ;; worth being one key-chord away from.
  :bind (("C-c u" . kubed-prefix-map)
         ("C-c U" . kubed-transient)))

;;
;; ====== JSON-lines log viewing (pretty-print + field filtering) ======
;;

;; Pretty-prints and filters streaming logs in-place, in whatever buffer is
;; receiving them.  It handles mixed log shapes line by line: a line that
;; parses as a JSON object (Spring Boot style structured logs, among
;; others) is reformatted and can be filtered by field value; any other
;; line -- a plain-text log, a stack trace continuation line, a banner --
;; is left exactly as printed and can still be filtered by a regexp on its
;; raw text.  So it is just as usable on an app that never emits JSON as
;; on one that does, and on buffers mixing both (e.g. a JVM banner
;; followed by JSON log lines).
;;
;; It is a plain minor mode rather than its own process/viewer, so it
;; attaches to any buffer that keeps appending log lines: a `tail -f'
;; process, a `compilation-mode' buffer, or `kubed's own log buffers (see
;; `kubed-logs-setup-hook' below) -- `kubed' manages the `kubectl logs'
;; process itself, this mode only reformats and hides lines in its output.
(defvar-local json-log-view--filter nil
  "Predicate (lambda (PLIST) => bool) selecting visible lines.
PLIST has `:json' (the parsed JSON object, or nil if the line did not
parse as one) and `:text' (the line's original raw text).  Nil means
every line is visible.")

(defvar-local json-log-view--processed-pos nil
  "Marker up to which buffer text has already been pretty-printed.")

(define-minor-mode json-log-view-mode
  "Pretty-print and filter streaming logs in this buffer.

Lines that parse as a JSON object are reformatted in place into a
fixed-width \"timestamp level logger message\" rendering, coloured by
level, and can be hidden (not deleted) by field value with
`json-log-view-filter'.  Lines that are not JSON are left untouched, so
this mode is safe to enable on apps that log plain text, and they can
still be hidden by raw-text regexp with `json-log-view-grep-filter'.
Works incrementally, so it keeps up with a buffer that a process keeps
appending to.

\\{json-log-view-mode-map}"
  :lighter " JSONLog"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c C-f") #'json-log-view-filter)
            (define-key map (kbd "C-c C-g") #'json-log-view-grep-filter)
            (define-key map (kbd "C-c C-c") #'json-log-view-clear-filter)
            (define-key map (kbd "C-c C-t") #'json-log-view-transient)
            map)
  (if json-log-view-mode
      (progn
        (setq json-log-view--processed-pos (copy-marker (point-min)))
        (json-log-view--process-region (point-min) (point-max))
        (add-hook 'after-change-functions #'json-log-view--after-change nil t))
    (remove-hook 'after-change-functions #'json-log-view--after-change t)
    (json-log-view--show-all)))

(defun json-log-view--after-change (&rest _)
  "Reformat any newly appended complete lines."
  (json-log-view--process-region json-log-view--processed-pos (point-max)))

(defun json-log-view--process-region (start end)
  "Reformat every complete log line between START and END."
  (save-excursion
    (goto-char start)
    (let ((inhibit-modification-hooks t))
      (while (re-search-forward "\n" end t)
        (json-log-view--process-line (line-beginning-position 0) (1- (point)))
        (set-marker json-log-view--processed-pos (point))))))

(defun json-log-view--process-line (start end)
  "Reformat the log line between START and END, JSON or not.

A line that parses as a JSON object is replaced by its pretty rendering;
any other line (plain text, stack trace, banner, malformed JSON) is left
exactly as it was.  Either way the line gets an overlay carrying its data
so it can be filtered uniformly."
  (let* ((text (buffer-substring-no-properties start end))
         (obj (and (string-prefix-p "{" (string-trim text))
                   (ignore-errors (json-parse-string text :object-type 'alist))))
         (line (list :json obj :text text))
         (visible (or (null json-log-view--filter)
                      (funcall json-log-view--filter line))))
    (when obj
      (delete-region start end)
      (goto-char start)
      (insert (json-log-view--format obj))
      (setq end (point)))
    (let ((ov (make-overlay start end)))
      (overlay-put ov 'json-log-view-line line)
      (unless visible
        (overlay-put ov 'invisible t)))))

(defun json-log-view--format (obj)
  "Render parsed JSON OBJ as a single colourised log line."
  (let ((level (alist-get 'level obj)))
    (propertize
     (format "%-23s %-5s %-30s %s"
             (or (alist-get 'timestamp obj) (alist-get '@timestamp obj) "")
             (or level "")
             (or (alist-get 'logger_name obj) (alist-get 'logger obj) "")
             (or (alist-get 'message obj) ""))
     'face (pcase level
             ("ERROR" 'error)
             ("WARN" 'warning)
             (_ 'default)))))

(defun json-log-view-filter (field value)
  "Show only log lines whose JSON FIELD equals VALUE.

FIELD and VALUE are read as strings; FIELD is looked up as a JSON key in
each line that parsed as JSON (e.g. \"level\", \"logger_name\").  Lines
that are not JSON never match a field filter and are hidden by it; use
`json-log-view-grep-filter' instead on logs that are not JSON."
  (interactive "sField: \nsValue: ")
  (setq json-log-view--filter
        (lambda (line)
          (when-let* ((obj (plist-get line :json)))
            (equal (format "%s" (alist-get (intern field) obj)) value))))
  (json-log-view--reapply-filter))

(defun json-log-view-grep-filter (regexp)
  "Show only log lines whose raw text matches REGEXP.

Unlike `json-log-view-filter', this works the same whether a line is
JSON or plain text, since it matches against the line as it was
originally printed -- the right tool for apps that do not log JSON."
  (interactive "sFilter regexp: ")
  (setq json-log-view--filter
        (lambda (line) (string-match-p regexp (plist-get line :text))))
  (json-log-view--reapply-filter))

(defun json-log-view-clear-filter ()
  "Remove any active filter, showing every log line again."
  (interactive)
  (setq json-log-view--filter nil)
  (json-log-view--reapply-filter))

(defun json-log-view--reapply-filter ()
  "Recompute visibility of every already-processed line."
  (dolist (ov (overlays-in (point-min) (point-max)))
    (when-let* ((line (overlay-get ov 'json-log-view-line)))
      (overlay-put ov 'invisible
                   (and json-log-view--filter
                        (not (funcall json-log-view--filter line)))))))

(defun json-log-view--show-all ()
  "Make every line in the buffer visible again."
  (dolist (ov (overlays-in (point-min) (point-max)))
    (overlay-put ov 'invisible nil)))

;; `kubed-logs' runs `kubed-logs-setup-hook' in its freshly created log
;; buffer, before starting the `kubectl logs' process -- the log buffer is
;; otherwise plain `fundamental-mode', so this hook is the only place to
;; attach behaviour to it without advising `kubed-logs' itself.
(with-eval-after-load 'kubed
  (add-hook 'kubed-logs-setup-hook #'json-log-view-mode))

;; A small transient gathering the filter commands above, in the same
;; style as `kubed-transient' and its "friends" (`kubed-transient-logs'
;; and so on).  It is meant to be called from inside a buffer that has
;; `json-log-view-mode' on -- i.e. a `kubed' log buffer, or any other log
;; buffer the mode was turned on in by hand -- which is also what its
;; `C-c C-t' binding in `json-log-view-mode-map' is for.
;; Defined once transient has been activated by Elpaca; requiring it
;; here at load time would pull in the built-in version too early.
(eval-when-compile (require 'transient))
(with-eval-after-load 'transient
  (transient-define-prefix json-log-view-transient ()
    "Filter and reset the log view in the current buffer."
    ["Log view"
     ("f" "Filter by JSON field" json-log-view-filter)
     ("g" "Filter by regexp" json-log-view-grep-filter)
     ("c" "Clear filter" json-log-view-clear-filter)]))

;; Folded into `kubed-transient' itself, right next to "Logs", so that
;; once you are looking at a log buffer that command opened, filtering it
;; is one more key away through the same menu rather than a separate one
;; to remember.
(with-eval-after-load 'kubed-transient
  (transient-append-suffix 'kubed-transient "l"
    '("f" "Filter log buffer" json-log-view-transient)))

(provide 'heks/dev-kubernetes)

;;; dev-kubernetes.el ends here
