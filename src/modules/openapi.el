;;; openapi.el --- OpenAPI specifications: check, render and call  -*- lexical-binding: t -*-

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

;; An OpenAPI file is a document that is read twice: once by the machine
;; that serves it and once by the person writing it.  This module is about
;; the second reading.
;;
;;   * it recognises a specification, so that opening one is enough --
;;     there is no minor mode to remember to turn on (`C-c a' exists for
;;     the actions, not for the mode);
;;   * it checks the things a reader notices and a generator does not:
;;     an operation with no responses, an identifier used twice, a path
;;     parameter that the operation never declares, a `$ref' that points
;;     at nothing.  The problems are Flymake diagnostics, so they appear in
;;     the margin as the file is edited;
;;   * it renders the specification the way Swagger UI does -- operations
;;     grouped by tag, with the method, the parameters, the body and the
;;     responses -- in the preview buffer, and can hand the document to the
;;     browser instead;
;;   * it turns the specification into a request.  `swagg' does the work of
;;     building the URL and the body; what was missing was the connection
;;     between the file being edited and the definition `swagg' asks for.
;;
;; The rendering and the document it lives in come from `modules/render.el'.
;;
;; One thing is worth knowing before reading the code below: the two
;; parsers do not agree on what a scalar is.  JSON has strings wherever a
;; specification means text, while YAML reads what the scalar looks like --
;; a bare key comes back as a symbol, `200' as a number, `true' as the
;; symbol `t' -- and it does that even for a quoted `"200"'.  A key is
;; always text in a specification, so every mapping is read once through
;; `heks-emacs-openapi--key-text' when the document is parsed, and every
;; value that is shown or searched for goes through
;; `heks-emacs-openapi-text'.  Without that, a YAML specification reads as
;; an empty document (every lookup of `paths' misses) and its response
;; codes crash the page instead of appearing in it.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'json)
(require 'flymake)

(defgroup heks-emacs-openapi nil
  "Checking and reading OpenAPI specifications."
  :group 'tools)

(defconst heks-emacs-openapi-methods
  '("get" "put" "post" "delete" "options" "head" "patch" "trace")
  "The HTTP methods an operation can be written under.")

(defconst heks-emacs-openapi-path-item-keys
  '("$ref" "summary" "description" "servers" "parameters")
  "The keys of a path item that are not operations.")

(defconst heks-emacs-openapi-file-regexp
  "\\(?:\\`openapi\\|\\`swagger\\|[-_.]openapi\\|[-_.]swagger\\)"
  "Regexp matching the file names a specification is usually given.")

;;
;; ====== Recognising and reading one ======
;;

;; These predicates answer yes or no: `string-match-p' answers with a
;; position and `memq' with the rest of a list, and a predicate whose
;; answer depends on where a pattern matched is one no caller can trust.

(defun heks-emacs-openapi-json-p (&optional buffer)
  "Return whether BUFFER, defaulting to the current one, holds JSON."
  (with-current-buffer (or buffer (current-buffer))
    (and (or (memq major-mode '(json-mode js-json-mode json-ts-mode))
             (and buffer-file-name (string-match-p "\\.json\\'" buffer-file-name)))
         t)))

(defun heks-emacs-openapi-data-mode-p (&optional buffer)
  "Return whether BUFFER holds one of the two languages a spec is written in."
  (with-current-buffer (or buffer (current-buffer))
    (and (or (heks-emacs-openapi-json-p)
             (memq major-mode '(yaml-mode yaml-ts-mode conf-mode))
             (and buffer-file-name (string-match-p "\\.ya?ml\\'" buffer-file-name)))
         t)))

(defun heks-emacs-openapi-version-key-p (&optional buffer)
  "Return whether BUFFER opens with a specification version key.

That key -- `openapi:' or `swagger:' -- is what makes a YAML file a
specification and a JSON file a configuration."
  (with-current-buffer (or buffer (current-buffer))
    (and (save-excursion
           (goto-char (point-min))
           (re-search-forward "[\"']?\\(?:openapi\\|swagger\\)[\"']?[ \t]*:"
                              (min (point-max) 4000) t))
         t)))

(defun heks-emacs-openapi-spec-p (&optional buffer)
  "Return whether BUFFER, defaulting to the current one, is a specification."
  (with-current-buffer (or buffer (current-buffer))
    (and (heks-emacs-openapi-data-mode-p)
         (or (and buffer-file-name
                  (string-match-p heks-emacs-openapi-file-regexp
                                  (file-name-nondirectory buffer-file-name)))
             (heks-emacs-openapi-version-key-p))
         t)))

(defun heks-emacs-openapi-get (mapping key &optional default)
  "Return the value of KEY in MAPPING, or DEFAULT.

Both parsers are in play here: `json-parse-buffer' gives hash tables keyed
by string, and an alist is accepted too, so that a structure that came
from somewhere else can be read with the same functions."
  (cond ((hash-table-p mapping)
         (gethash key mapping default))
        ((consp mapping)
         (or (cdr (assoc key mapping))
             (let ((symbol (intern key)))
               (or (cdr (assq symbol mapping))
                   (cdr (assq (intern (concat ":" key)) mapping))
                   default))))
        (t default)))

(defun heks-emacs-openapi-seq (value)
  "Return VALUE as a list, whether it is a list or a vector or neither."
  (cond ((null value) nil)
        ((listp value) value)
        ((vectorp value) (append value nil))
        (t nil)))

(defun heks-emacs-openapi-text (value)
  "Return VALUE as the text a document says, or nil when it says nothing.

A scalar is whatever the parser made of it: a string in JSON, but a
symbol, a number or nil in YAML, where `200' is a number and `true' is a
symbol.  A specification means text by all of them -- a response code is
`200' whether or not the document quoted it -- so everything that is
displayed, compared against a pattern or searched for in the buffer is
read through here first."
  (cond ((null value) nil)
        ((stringp value) value)
        ((eq value t) "true")
        ((numberp value) (number-to-string value))
        ((symbolp value)
         (if (eq value :false) "false"
           (string-remove-prefix ":" (symbol-name value))))
        (t nil)))

(defun heks-emacs-openapi-yes-p (value)
  "Return whether VALUE is a document's yes rather than its no.

Both parsers are asked for the symbol `:false' where a document says
`false', because `nil' is what a document says nothing with; the symbol is
a true value in Elisp, so a `required: false' read on its own would answer
yes to every question asked about it."
  (and value (not (eq value :false)) (not (eq value 'false)) t))

(defun heks-emacs-openapi--key-text (key)
  "Return KEY as the text a mapping writes it with."
  (or (heks-emacs-openapi-text key) ""))

(defun heks-emacs-openapi--string-keys (value)
  "Return VALUE with every mapping key turned into the text it is written as.

This is what makes a YAML document and a JSON one the same thing to every
function below: `paths' is `paths' rather than the symbol `paths', and a
response is keyed by "200" rather than by the number 200."
  (cond
   ((hash-table-p value)
    (let ((table (make-hash-table :test #'equal)))
      (maphash (lambda (key item)
                 (puthash (heks-emacs-openapi--key-text key)
                          (heks-emacs-openapi--string-keys item)
                          table))
               value)
      table))
   ((consp value) (mapcar #'heks-emacs-openapi--string-keys value))
   (t value)))

(defun heks-emacs-openapi--sorted-keys (mapping)
  "Return the keys of MAPPING, sorted, so that reading it is reproducible.

A mapping has no order of its own, and the one a hash table iterates in
is not the document's, so anything that is shown -- or compared with a
file, as the golden renderings are -- is read in a defined order."
  (sort (if (hash-table-p mapping) (hash-table-keys mapping) nil) #'string<))

(defun heks-emacs-openapi-parse (&optional buffer)
  "Return BUFFER's specification as a table, or nil when it cannot be read.

The table is keyed by string, and holds lists where the document writes
sequences, whichever of the two languages it is written in."
  (with-current-buffer (or buffer (current-buffer))
    (condition-case err
        (heks-emacs-openapi--string-keys
         (if (heks-emacs-openapi-json-p)
             (save-excursion
               (goto-char (point-min))
               (json-parse-buffer :object-type 'hash-table
                                  :array-type 'list
                                  :null-object nil
                                  :false-object :false))
           (require 'yaml)
           ;; `object-key-type' is a string rather than the default symbol
           ;; for two reasons: a key is text, and a symbol would be
           ;; interned -- a specification would fill the obarray with the
           ;; names of its paths.
           (yaml-parse-string (buffer-string)
                              :object-type 'hash-table
                              :object-key-type 'string
                              :sequence-type 'list
                              :null-object nil
                              :false-object :false)))
      (error
       (message "This is not readable as %s: %s"
                (if (heks-emacs-openapi-json-p) "JSON" "YAML")
                (error-message-string err))
       nil))))

(defun heks-emacs-openapi--ref-get (spec reference)
  "Return what the JSON REFERENCE (`#/components/schemas/Name') points at."
  (when (and (stringp reference) (string-prefix-p "#/" reference))
    (let ((parts (mapcar (lambda (part)
                           (replace-regexp-in-string
                            "~1" "/" (replace-regexp-in-string "~0" "~" part)))
                         (split-string (substring reference 2) "/")))
          (value spec)
          (found t))
      (while (and found parts)
        (let ((key (pop parts)))
          (if (hash-table-p value)
              (if (gethash key value) (setq value (gethash key value)) (setq found nil))
            (setq value (heks-emacs-openapi-get value key :missing))
            (when (eq value :missing) (setq found nil)))))
      (when found value))))

(defun heks-emacs-openapi--resolve (spec object)
  "Return OBJECT, following it through a leading `$ref' when it has one."
  (let ((seen 0))
    (while (and (heks-emacs-openapi-get object "$ref") (< seen 10))
      (setq object (heks-emacs-openapi--ref-get spec (heks-emacs-openapi-get object "$ref")))
      (setq seen (1+ seen)))
    object))

;;
;; ====== The operations ======
;;;

(defun heks-emacs-openapi-operations (spec)
  "Return the operations of SPEC.

Each one is a plist: :path, :method, :operation, :item (the path item it
was written under) and :tags."
  (let ((operations nil))
    (maphash
     (lambda (path item)
       (let ((item (heks-emacs-openapi--resolve spec item)))
         (when (hash-table-p item)
           (maphash
            (lambda (key value)
              (when (member key heks-emacs-openapi-methods)
                (push (list :path path :method key :operation value :item item
                            :tags (heks-emacs-openapi-seq
                                   (heks-emacs-openapi-get value "tags")))
                      operations)))
            item))))
     (or (heks-emacs-openapi-get spec "paths") (make-hash-table :test #'equal)))
    ;; A mapping has no order, so the document's own is imposed here: by
    ;; path, and by the order the methods are written above.  The page and
    ;; the menu are then the same on every run, which is what lets their
    ;; rendering be compared with a file.
    (sort (nreverse operations)
          (lambda (a b)
            (let ((path-a (plist-get a :path))
                  (path-b (plist-get b :path)))
              (if (equal path-a path-b)
                  (< (seq-position heks-emacs-openapi-methods (plist-get a :method))
                     (seq-position heks-emacs-openapi-methods (plist-get b :method)))
                (string< path-a path-b)))))))

(defun heks-emacs-openapi--template-parameters (path)
  "Return the names of the variables written in the PATH template."
  (let ((path (or (heks-emacs-openapi-text path) ""))
        (names nil) (start 0))
    (while (string-match "{\\([^}/]+\\)}" path start)
      (push (match-string 1 path) names)
      (setq start (match-end 0)))
    (nreverse names)))

(defun heks-emacs-openapi--declared-parameters (spec operation item)
  "Return the parameters declared for OPERATION and its ITEM, resolved."
  (let ((from-item (heks-emacs-openapi-seq (heks-emacs-openapi-get item "parameters")))
        (from-operation (heks-emacs-openapi-seq (heks-emacs-openapi-get operation "parameters"))))
    (mapcar (lambda (parameter) (heks-emacs-openapi--resolve spec parameter))
            (append from-item from-operation))))

;;;
;;; What is wrong with it
;;;

;; A problem is (SEVERITY NEEDLE MESSAGE): what Flymake paints, the text to
;; look for in the buffer so that the diagnostic sits on the line that has
;; the problem, and what to say about it.
;;
;; The list being checked is kept in a variable rather than threaded through
;; every call: this is a walk over a document, and a checker that has to
;; return its findings through five levels of `mapcar' is a checker nobody
;; will add a rule to.

(defvar heks-emacs-openapi--problems nil
  "The problems found by the current run of `heks-emacs-openapi-problems'.")

(defvar heks-emacs-openapi--refs nil
  "Every `$ref' in the document being checked.")

(defvar heks-emacs-openapi--identifiers nil
  "The `operationId's seen so far, so that a repeated one is caught.")

(defun heks-emacs-openapi--problem (severity needle message)
  "Record a problem: what a reader should see, and where."
  (push (list severity needle message) heks-emacs-openapi--problems))

(defun heks-emacs-openapi--collect-refs (value)
  "Record every `$ref' in VALUE, so that a dangling one is found.

A `$ref' that is not a reference at all is recorded as a problem of its
own: it is what an editor leaves behind when a schema is deleted, and
nothing else would report it."
  (cond
   ((hash-table-p value)
    (dolist (key (heks-emacs-openapi--sorted-keys value))
      (let ((item (gethash key value)))
        (if (equal key "$ref")
            (if (stringp item)
                (push item heks-emacs-openapi--refs)
              (heks-emacs-openapi--problem
               :error nil "`$ref' has to name a reference such as `#/components/schemas/Name'"))
          (heks-emacs-openapi--collect-refs item)))))
   ((consp value)
    (mapc #'heks-emacs-openapi--collect-refs value))))

(defun heks-emacs-openapi--check-content (spec content operation)
  "Report bodies of OPERATION in SPEC that do not say what shape they have.

A schema with no type, no `$ref' and no properties is the most common way
a specification stops being useful: a generator can only guess, and so can
a reader."
  (dolist (media-type (heks-emacs-openapi--sorted-keys content))
    (let ((schema (heks-emacs-openapi--resolve
                   spec (heks-emacs-openapi-get (gethash media-type content) "schema"))))
      (when (and (hash-table-p schema)
                 (not (heks-emacs-openapi-get schema "type"))
                 (not (heks-emacs-openapi-get schema "$ref"))
                 (not (heks-emacs-openapi-get schema "properties")))
        (heks-emacs-openapi--problem
         :warning (heks-emacs-openapi-text (heks-emacs-openapi-get operation "operationId"))
         (format "the schema of %s is untyped, so a generator can only guess"
                 media-type))))))

(defun heks-emacs-openapi--check-responses (method path responses)
  "Report the problems of the RESPONSES of METHOD on PATH."
  (if (not (hash-table-p responses))
      (heks-emacs-openapi--problem
       :error nil (format "%s %s has no responses" method path))
    (maphash
     (lambda (code response)
       (setq code (or (heks-emacs-openapi-text code) ""))
       (unless (or (string-match-p "\\`[1-5][0-9][0-9]\\'" code)
                   (string-match-p "\\`[1-5]XX\\'" code)
                   (equal code "default"))
         (heks-emacs-openapi--problem :warning code
                                      (format "`%s' is not a response code" code)))
       (when (and (hash-table-p response)
                  (not (heks-emacs-openapi-get response "description")))
         (heks-emacs-openapi--problem
          :warning code
          (format "the %s response of %s %s has no description"
                  code method path))))
     responses)))

(defun heks-emacs-openapi--check-parameters (spec path item operation)
  "Report the parameters of OPERATION that do not agree with PATH.

A variable written in the path and never declared is a request the server
will reject; one declared and not written in the path is a parameter no
request can ever give a value to."
  (let* ((declared (heks-emacs-openapi--declared-parameters spec operation item))
         (names (delq nil (mapcar (lambda (parameter)
                                    (heks-emacs-openapi-text
                                     (heks-emacs-openapi-get parameter "name")))
                                  declared)))
         (template (heks-emacs-openapi--template-parameters path)))
    (dolist (variable template)
      (unless (member variable names)
        (heks-emacs-openapi--problem
         :error path
         (format "`%s' in the path is never declared as a parameter" variable))))
    (dolist (parameter declared)
      (when (and (equal "path" (heks-emacs-openapi-text
                                (heks-emacs-openapi-get parameter "in")))
                 (not (member (heks-emacs-openapi-text
                               (heks-emacs-openapi-get parameter "name"))
                              template)))
        (heks-emacs-openapi--problem
         :warning (heks-emacs-openapi-text (heks-emacs-openapi-get parameter "name"))
         (format "`%s' is declared as a path parameter but is not in `%s'"
                 (heks-emacs-openapi-text (heks-emacs-openapi-get parameter "name"))
                 path))))))

(defun heks-emacs-openapi--check-operation (spec path method item operation)
  "Report the problems of one OPERATION of PATH in SPEC."
  (let ((identifier (heks-emacs-openapi-text
                     (heks-emacs-openapi-get operation "operationId"))))
    (when identifier
      (if (gethash identifier heks-emacs-openapi--identifiers)
          (heks-emacs-openapi--problem
           :error identifier
           (format "`%s' is already the identifier of another operation" identifier))
        (puthash identifier t heks-emacs-openapi--identifiers))))
  (heks-emacs-openapi--check-parameters spec path item operation)
  (heks-emacs-openapi--check-responses method path
                                       (heks-emacs-openapi-get operation "responses"))
  (let ((body (heks-emacs-openapi--resolve
               spec (heks-emacs-openapi-get operation "requestBody"))))
    (when (hash-table-p body)
      (heks-emacs-openapi--check-content spec
                                         (heks-emacs-openapi-get body "content")
                                         operation))))

(defun heks-emacs-openapi--check-paths (spec)
  "Report the problems of the paths of SPEC."
  (let ((paths (heks-emacs-openapi-get spec "paths")))
    (cond ((null paths)
           (heks-emacs-openapi--problem
            :warning nil "there are no `paths', so this describes no endpoints"))
          ((not (hash-table-p paths))
           (heks-emacs-openapi--problem
            :error "paths" "`paths' has to be a mapping of paths")))
    (when (hash-table-p paths)
      (maphash
       (lambda (path item)
         (unless (string-prefix-p "/" path)
           (heks-emacs-openapi--problem
            :error path (format "`%s' is not a path: it has to start with '/'" path)))
         (let ((item (heks-emacs-openapi--resolve spec item)))
           (when (hash-table-p item)
             (maphash
              (lambda (key value)
                (cond
                 ((member key heks-emacs-openapi-methods)
                  ;; A `parameters' array belongs to the whole path item, so
                  ;; it is checked once per operation rather than here.
                  (heks-emacs-openapi--check-operation
                   spec path (upcase key) item value))
                 ((not (member key heks-emacs-openapi-path-item-keys))
                  (heks-emacs-openapi--problem
                   :warning key
                   (format "`%s' under `%s' is not an operation; the methods are %s"
                           key path (string-join heks-emacs-openapi-methods "/"))))))
              item))))
       paths))))

(defun heks-emacs-openapi-problems (spec)
  "Return the problems of SPEC as a list of (SEVERITY NEEDLE MESSAGE)."
  (let ((heks-emacs-openapi--problems nil)
        (heks-emacs-openapi--refs nil)
        (heks-emacs-openapi--identifiers (make-hash-table :test #'equal)))
    (unless (or (heks-emacs-openapi-get spec "openapi")
                (heks-emacs-openapi-get spec "swagger"))
      (heks-emacs-openapi--problem
       :error nil "no `openapi' version, so this is not a specification"))
    (let ((info (heks-emacs-openapi-get spec "info")))
      (if (not (hash-table-p info))
          (heks-emacs-openapi--problem
           :error "info" "`info' is required and describes the API")
        (dolist (key '("title" "version"))
          (unless (heks-emacs-openapi-get info key)
            (heks-emacs-openapi--problem
             :error key (format "`info.%s' is required" key))))))
    (heks-emacs-openapi--check-paths spec)
    (heks-emacs-openapi--collect-refs spec)
    (dolist (reference heks-emacs-openapi--refs)
      (unless (heks-emacs-openapi--ref-get spec reference)
        (heks-emacs-openapi--problem
         :error reference
         (format "`%s' points at nothing in this document" reference))))
    (dolist (server (heks-emacs-openapi-seq (heks-emacs-openapi-get spec "servers")))
      (unless (and (hash-table-p server) (heks-emacs-openapi-get server "url"))
        (heks-emacs-openapi--problem :warning "servers" "a server needs a `url'")))
    (nreverse heks-emacs-openapi--problems)))

(defun heks-emacs-openapi--position (needle)
  "Return the buffer position of NEEDLE, or the start of the buffer."
  (save-excursion
    (goto-char (point-min))
    (if (and (stringp needle) (search-forward needle (point-max) t))
        (match-beginning 0)
      (point-min))))

(defun heks-emacs-openapi--diagnostic (severity position message)
  "Return a diagnostic on the line holding POSITION.

The text is the (origin code message) list Emacs builds what the user
reads out of: a diagnostic with no origin renders with a gap in front of
it, so the checker always names itself."
  (flymake-make-diagnostic (current-buffer) position
                           (save-excursion (goto-char position) (line-end-position))
                           severity (list "OpenAPI" nil message)))

(defun heks-emacs-openapi-diagnostics (&optional buffer)
  "Return the specification problems in BUFFER as Flymake diagnostics.

A document that cannot be read at all -- a YAML file with a stray tab,
most often -- is itself the problem, and it is reported as one rather
than as a checker that found nothing."
  (with-current-buffer (or buffer (current-buffer))
    (let ((spec (heks-emacs-openapi-parse)))
      (if (not spec)
          (list (heks-emacs-openapi--diagnostic
                 :error (point-min)
                 (if (heks-emacs-openapi-json-p)
                     "This is not valid JSON, so it cannot be checked"
                   "This is not valid YAML, so it cannot be checked")))
        (mapcar (lambda (problem)
                  (heks-emacs-openapi--diagnostic
                   (nth 0 problem)
                   (heks-emacs-openapi--position (nth 1 problem))
                   (nth 2 problem)))
                (heks-emacs-openapi-problems spec))))))

(defun heks-emacs-openapi-flymake (report-fn &rest _)
  "Report the problems of the specification in the current buffer.

This is a Flymake backend, so Flymake calls it; a buffer that is not a
specification reports nothing rather than complaining."
  (funcall report-fn
           (when (heks-emacs-openapi-spec-p)
             (heks-emacs-openapi-diagnostics))))

(defun heks-emacs-openapi-check ()
  "Check the specification in this buffer and show what is wrong."
  (interactive)
  (unless (heks-emacs-openapi-spec-p)
    (user-error "This buffer is not an OpenAPI specification"))
  (let ((diagnostics (heks-emacs-openapi-diagnostics)))
    (if (null diagnostics)
        (message "The specification has no problems this checks for")
      (flymake-show-buffer-diagnostics)
      (message "%d problem%s" (length diagnostics)
               (if (= (length diagnostics) 1) "" "s")))))

;;
;; ====== Folding the operations into the menu ======
;;;

(defun heks-emacs-openapi-imenu ()
  "Return the operations of this buffer for `imenu'."
  (when-let* ((spec (heks-emacs-openapi-parse))
              (operations (heks-emacs-openapi-operations spec)))
    (let ((by-tag nil))
      (dolist (operation operations)
        (let* ((tags (or (plist-get operation :tags) '("untagged")))
               (name (format "%-6s %s" (upcase (plist-get operation :method))
                             (plist-get operation :path))))
          (dolist (tag tags)
            (let ((entry (assoc tag by-tag)))
              (unless entry
                (setq entry (cons tag nil))
                (push entry by-tag))
              (setcdr entry (append (cdr entry)
                                    (list (cons name (heks-emacs-openapi--position
                                                      (plist-get operation :path))))))))))
      (nreverse by-tag))))

;;
;; ====== Reading it: the Swagger page ======
;;;

(defconst heks-emacs-openapi-method-colors
  '(("get" . "#1f8b4c") ("post" . "#1f6feb") ("put" . "#b7791f")
    ("patch" . "#8957e5") ("delete" . "#c4342a") ("head" . "#57606a")
    ("options" . "#57606a") ("trace" . "#57606a"))
  "What each method is painted with in the rendered page.")

(defun heks-emacs-openapi--html-text (value)
  "Return VALUE as text escaped for the page, or the empty string.

Everything the page says about a specification comes through here, so
that a scalar YAML made of a number, a symbol or nothing at all is shown
as the text the document means rather than stopping the rendering."
  (heks-emacs-render--escape (or (heks-emacs-openapi-text value) "")))

(defun heks-emacs-openapi--badge (text color)
  "Return a filled label saying TEXT in COLOR."
  (format "<span style=\"background:%s;color:#fff;font-weight:700;font-size:0.78em;\
padding:0.2em 0.55em;border-radius:5px;letter-spacing:0.04em\">%s</span>"
          color (heks-emacs-openapi--html-text text)))

(defun heks-emacs-openapi--media-entries (spec content)
  "Return the media types of the CONTENT of a body, paired with their schema.

A body is written one way most of the time, but a document that offers
JSON and one other serialisation has to show both, in a defined order."
  (mapcar (lambda (media-type)
            (cons media-type
                  (heks-emacs-openapi--schema-html
                   spec (heks-emacs-openapi-get (gethash media-type content) "schema"))))
          (heks-emacs-openapi--sorted-keys content)))

(defun heks-emacs-openapi--schema-html (spec schema &optional depth)
  "Return a short description of SCHEMA, resolved through SPEC.

DEPTH stops a schema that describes itself from describing itself
forever."
  (let ((depth (or depth 0)))
    (if (> depth 4)
        "<code>…</code>"
      (let* ((reference (and (hash-table-p schema) (heks-emacs-openapi-get schema "$ref")))
             (resolved (if reference
                           (heks-emacs-openapi--resolve spec schema)
                         schema))
             (type (and (hash-table-p resolved) (heks-emacs-openapi-get resolved "type")))
             (schema-format (and (hash-table-p resolved)
                                 (heks-emacs-openapi-get resolved "format")))
             (items (and (hash-table-p resolved) (heks-emacs-openapi-get resolved "items")))
             (properties (and (hash-table-p resolved)
                              (heks-emacs-openapi-get resolved "properties"))))
        (cond
         (reference
          (format "<code>%s</code>" (heks-emacs-openapi--html-text
                                     (car (last (split-string (heks-emacs-openapi--key-text
                                                               reference)
                                                              "/"))))))
         ((equal type "array")
          (format "<code>array</code> of %s" (heks-emacs-openapi--schema-html
                                              spec items (1+ depth))))
         (properties
          (format "<code>object</code> with %s"
                  (string-join
                   (mapcar (lambda (name)
                             (format "<code>%s</code>" (heks-emacs-openapi--html-text name)))
                           (heks-emacs-openapi--sorted-keys properties))
                   ", ")))
         (type (format "<code>%s</code>%s" (heks-emacs-openapi--html-text type)
                       (if schema-format
                           (format " (%s)" (heks-emacs-openapi--html-text schema-format))
                         "")))
         (t "<code>any</code>"))))))

(defun heks-emacs-openapi--parameters-html (spec parameters)
  "Return a table of the PARAMETERS of an operation of SPEC."
  (let ((parameters (delq nil parameters)))
    (if (null parameters)
        ""
      (concat
       "<table><thead><tr><th>Name</th><th>In</th><th>Type</th><th>Required</th><th></th></tr></thead><tbody>"
       (apply #'concat
              (mapcar
               (lambda (parameter)
                 (format "<tr><td><code>%s</code></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>"
                         (heks-emacs-openapi--html-text
                          (or (heks-emacs-openapi-get parameter "name") "?"))
                         (heks-emacs-openapi--html-text
                          (heks-emacs-openapi-get parameter "in"))
                         (heks-emacs-openapi--schema-html
                          spec (heks-emacs-openapi-get parameter "schema"))
                         (if (heks-emacs-openapi-yes-p
                              (heks-emacs-openapi-get parameter "required"))
                             "yes" "")
                         (heks-emacs-openapi--html-text
                          (heks-emacs-openapi-get parameter "description"))))
               parameters))
       "</tbody></table>"))))

(defun heks-emacs-openapi--responses-html (spec responses)
  "Return a table of the RESPONSES of an operation of SPEC."
  (if (not (hash-table-p responses))
      ""
    (concat
     "<table><thead><tr><th>Code</th><th>What it returns</th><th></th></tr></thead><tbody>"
     (apply #'concat
            (mapcar
             (lambda (code)
               (let* ((response (heks-emacs-openapi--resolve spec (gethash code responses)))
                      (content (and (hash-table-p response)
                                    (heks-emacs-openapi-get response "content"))))
                 (format "<tr><td><code>%s</code></td><td>%s</td><td>%s</td></tr>"
                         (heks-emacs-openapi--html-text code)
                         (heks-emacs-openapi--html-text
                          (and (hash-table-p response)
                               (heks-emacs-openapi-get response "description")))
                         (string-join
                          (mapcar (lambda (entry)
                                    (format "%s → %s"
                                            (heks-emacs-openapi--html-text (car entry))
                                            (cdr entry)))
                                  (heks-emacs-openapi--media-entries spec content))
                          "<br>"))))
             (heks-emacs-openapi--sorted-keys responses)))
     "</tbody></table>")))

(defun heks-emacs-openapi--body-html (spec body)
  "Return the request body of an operation of SPEC."
  (let ((body (heks-emacs-openapi--resolve spec body)))
    (if (not (hash-table-p body))
        ""
      (let ((content (heks-emacs-openapi-get body "content"))
            (description (heks-emacs-openapi-get body "description")))
        (concat
         (when description
           (format "<p>%s</p>" (heks-emacs-openapi--html-text description)))
         (when (hash-table-p content)
           (concat "<p class=\"headline\">Request body</p><ul>"
                   (string-join
                    (mapcar (lambda (entry)
                              (format "<li><code>%s</code> — %s</li>"
                                      (heks-emacs-openapi--html-text (car entry))
                                      (cdr entry)))
                            (heks-emacs-openapi--media-entries spec content))
                    "")
                   "</ul>")))))))

(defun heks-emacs-openapi--operation-html (spec operation)
  "Return the rendered OPERATION of SPEC."
  (let* ((method (heks-emacs-openapi--key-text (plist-get operation :method)))
         (path (heks-emacs-openapi--key-text (plist-get operation :path)))
         (operation-value (plist-get operation :operation))
         (item (plist-get operation :item))
         (summary (heks-emacs-openapi-text
                   (heks-emacs-openapi-get operation-value "summary")))
         (description (heks-emacs-openapi-text
                       (heks-emacs-openapi-get operation-value "description")))
         (identifier (heks-emacs-openapi-text
                      (heks-emacs-openapi-get operation-value "operationId")))
         (parameters (heks-emacs-openapi--declared-parameters spec operation-value item))
         (deprecated (heks-emacs-openapi-yes-p
                      (heks-emacs-openapi-get operation-value "deprecated"))))
    (concat
     (format "<h3 id=\"%s\">%s <code>%s</code>%s</h3>\n"
             (heks-emacs-render--escape (format "%s-%s" method path) t)
             (heks-emacs-openapi--badge (upcase method)
                                        (or (cdr (assoc method heks-emacs-openapi-method-colors))
                                            "#57606a"))
             (heks-emacs-render--escape path)
             (if deprecated " <em>(deprecated)</em>" ""))
     (when summary (format "<p><strong>%s</strong></p>\n" (heks-emacs-render--escape summary)))
     (when description (format "<p>%s</p>\n" (heks-emacs-render--escape description)))
     (when identifier
       (format "<p class=\"headline\">operationId: %s</p>\n" (heks-emacs-render--escape identifier)))
     (when parameters
       (concat "<p class=\"headline\">Parameters</p>" (heks-emacs-openapi--parameters-html spec parameters)))
     (heks-emacs-openapi--body-html spec (heks-emacs-openapi-get operation-value "requestBody"))
     (concat "<p class=\"headline\">Responses</p>"
             (heks-emacs-openapi--responses-html spec (heks-emacs-openapi-get operation-value "responses"))))))

(defun heks-emacs-openapi--schemas-html (spec)
  "Return the schemas SPEC defines, as a section."
  (let ((components (heks-emacs-openapi-get spec "components")))
    (if (not (hash-table-p components))
        ""
      (let ((schemas (heks-emacs-openapi-get components "schemas")))
        (if (not (hash-table-p schemas))
            ""
          (concat
           "<h2>Schemas</h2>\n"
           (apply #'concat
                  (mapcar
                   (lambda (name)
                     (let ((schema (heks-emacs-openapi--resolve spec (gethash name schemas))))
                       (concat
                        (format "<h3><code>%s</code></h3>\n" (heks-emacs-openapi--html-text name))
                        (when (and (hash-table-p schema)
                                   (heks-emacs-openapi-get schema "description"))
                          (format "<p>%s</p>\n"
                                  (heks-emacs-openapi--html-text
                                   (heks-emacs-openapi-get schema "description"))))
                        (format "<p>%s</p>\n"
                                (heks-emacs-openapi--schema-html spec schema)))))
                   (heks-emacs-openapi--sorted-keys schemas)))))))))

(defun heks-emacs-openapi-html (&optional buffer)
  "Return the specification in BUFFER rendered as a page of HTML.

The shape is the one Swagger UI has made familiar -- operations grouped
by tag, each with its method, its parameters, its body and its responses
-- because that is the shape a reader already knows how to read."
  (with-current-buffer (or buffer (current-buffer))
    (let* ((spec (heks-emacs-openapi-parse))
           (info (and spec (heks-emacs-openapi-get spec "info")))
           (title (or (and (hash-table-p info)
                           (heks-emacs-openapi-text (heks-emacs-openapi-get info "title")))
                      (heks-emacs-render-title)))
           (version (and (hash-table-p info) (heks-emacs-openapi-get info "version")))
           (description (and (hash-table-p info) (heks-emacs-openapi-get info "description")))
           (operations (and spec (heks-emacs-openapi-operations spec)))
           (tags nil))
      (cond
       ((not spec)
        (format "<pre class=\"plain\">%s</pre>"
                (heks-emacs-render--escape (buffer-string))))
       (t
        ;; Operations come out grouped by their first tag, which is what
        ;; the specification's `tags' list is for.
        (dolist (operation operations)
          (let ((tag (or (car (plist-get operation :tags)) "untagged")))
            (let ((entry (assoc tag tags)))
              (unless entry
                (setq entry (cons tag nil))
                (push entry tags))
              (setcdr entry (append (cdr entry) (list operation))))))
        (concat
         (format "<h1>%s %s</h1>\n" (heks-emacs-openapi--html-text title)
                 (if version
                     (heks-emacs-openapi--badge (format "v%s" version) "#57606a")
                   ""))
         (when description
           (format "<p>%s</p>\n" (heks-emacs-openapi--html-text description)))
         (let ((servers (heks-emacs-openapi-seq (heks-emacs-openapi-get spec "servers"))))
           (if servers
               (concat "<p class=\"headline\">Servers</p><ul>"
                       (string-join
                        (mapcar (lambda (server)
                                  (let ((text (heks-emacs-openapi-text
                                               (heks-emacs-openapi-get server "description"))))
                                    (format "<li><code>%s</code>%s</li>"
                                            (heks-emacs-openapi--html-text
                                             (heks-emacs-openapi-get server "url"))
                                            (if text
                                                (format " — %s"
                                                        (heks-emacs-openapi--html-text text))
                                              ""))))
                                servers)
                        "")
                       "</ul>")
             ""))
         (apply #'concat
                (mapcar (lambda (entry)
                          (concat (format "<h2>%s</h2>\n" (heks-emacs-openapi--html-text (car entry)))
                                  (apply #'concat
                                         (mapcar (lambda (operation)
                                                   (heks-emacs-openapi--operation-html spec operation))
                                                 (cdr entry)))))
                        (nreverse tags)))
         (heks-emacs-openapi--schemas-html spec)))))))

(defun heks-emacs-openapi-view ()
  "Render this specification the way Swagger UI would and show it."
  (interactive)
  (unless (heks-emacs-openapi-spec-p)
    (user-error "This buffer is not an OpenAPI specification"))
  (heks-emacs-preview))

;;
;; ====== Calling it ======
;;;

(defun heks-emacs-openapi-server-url (&optional buffer)
  "Return the first server URL of BUFFER's specification."
  (with-current-buffer (or buffer (current-buffer))
    (when-let* ((spec (heks-emacs-openapi-parse)))
      (or (let ((servers (heks-emacs-openapi-seq (heks-emacs-openapi-get spec "servers"))))
            (and servers (heks-emacs-openapi-text
                          (heks-emacs-openapi-get (car servers) "url"))))
          ;; OpenAPI 2.0 says the same thing in three keys.
          (let ((host (heks-emacs-openapi-text (heks-emacs-openapi-get spec "host")))
                (base (or (heks-emacs-openapi-text
                           (heks-emacs-openapi-get spec "basePath"))
                          "/"))
                (schemes (heks-emacs-openapi-seq (heks-emacs-openapi-get spec "schemes"))))
            (when host
              (format "%s://%s%s"
                      (or (heks-emacs-openapi-text (car schemes)) "https") host base)))))))

(defun heks-emacs-openapi-definition (&optional buffer)
  "Return the `swagg' definition for BUFFER's specification.

`swagg' wants a name, a base URL and the file it should read the
definition from; the one thing it cannot know is which file is being
edited, which is what this adds."
  (with-current-buffer (or buffer (current-buffer))
    (unless buffer-file-name
      (user-error "Save the specification first: a definition names a file"))
    (let ((base (heks-emacs-openapi-server-url)))
      (unless base
        (user-error "This specification declares no server to call"))
      (list :name (file-name-nondirectory buffer-file-name)
            :base (replace-regexp-in-string "/+\\'" "" (heks-emacs-openapi-text base))
            (if (heks-emacs-openapi-json-p) :json :yaml)
            (buffer-file-name)))))

(defun heks-emacs-openapi-request ()
  "Call one of the operations of this specification, from the file itself.

The path parameters are asked for, the URL is built from the operation
and the answer is shown in its own buffer."
  (interactive)
  (require 'swagg)
  (swagg-request (heks-emacs-openapi-definition)))

(defun heks-emacs-openapi-rest-block ()
  "Write one of the operations of this specification as a request block.

The block goes to the `swagg' buffer, where a rest client can send it,
which is what one wants for a request with a body or one worth keeping."
  (interactive)
  (require 'swagg)
  (swagg-request-with-rest-block (heks-emacs-openapi-definition)))

;;
;; ====== Turning it on where it belongs ======
;;;

(defun heks-emacs-openapi-imenu-setup ()
  "Make `imenu' list the operations of this buffer."
  (setq-local imenu-create-index-function #'heks-emacs-openapi-imenu))

(defun heks-emacs-openapi-check-setup ()
  "Check this buffer's specification with every Flymake run."
  (add-hook 'flymake-diagnostic-functions #'heks-emacs-openapi-flymake nil t)
  (flymake-mode 1))

(define-minor-mode heks-emacs-openapi-mode
  "Check and navigate the OpenAPI specification in this buffer.

It is turned on by the hooks below whenever a buffer turns out to hold a
specification, so there is nothing to remember to enable.  What it adds is
a Flymake backend -- the problems of the document appear in the margin --
and an `imenu' that lists the operations by tag."
  :lighter " OpenAPI"
  (if heks-emacs-openapi-mode
      (progn (heks-emacs-openapi-check-setup)
             (heks-emacs-openapi-imenu-setup))
    (remove-hook 'flymake-diagnostic-functions #'heks-emacs-openapi-flymake t)))

(defun heks-emacs-openapi--maybe-enable ()
  "Turn `heks-emacs-openapi-mode' on when the buffer is a specification."
  (when (heks-emacs-openapi-spec-p)
    (heks-emacs-openapi-mode 1)))

;; JSON and YAML are where a specification lives; the check above decides
;; whether this particular file is one.
(dolist (hook '(json-mode-hook js-json-mode-hook json-ts-mode-hook
                yaml-mode-hook yaml-ts-mode-hook))
  (add-hook hook #'heks-emacs-openapi--maybe-enable))

(use-package emacs
  :ensure nil
  :bind (("C-c a v" . heks-emacs-openapi-view)
         ("C-c a l" . heks-emacs-openapi-check)
         ("C-c a r" . heks-emacs-openapi-request)
         ("C-c a b" . heks-emacs-openapi-rest-block)))

(provide 'heks-emacs/openapi)

;;; openapi.el ends here
