;;; notes-graph.el --- A smooth graph and tree of the notes -*- lexical-binding: t -*-

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

;; Two ways to see how the notes fit together:
;;
;;   `heks/notes-graph'   (C-c n g)  an interactive map in the browser: how
;;                        notes link to each other, how topics nest, or both
;;                        at once, drawn as a force-directed graph that
;;                        settles smoothly, zooms and pans, and highlights a
;;                        note's neighbours as you move over it.  A second
;;                        tab is the same notes as a collapsible tree.
;;                        Clicking a note opens it *in this Emacs*.
;;   `heks/notes-tree'    (C-c n T)  the topics as a folding outline in an
;;                        Emacs buffer, for when a browser is not wanted.
;;   `heks/notes-graph-export'  (C-c n G)  the map as one self-contained HTML
;;                        file, to keep or to share.
;;
;; How the map is served: a small HTTP server inside Emacs, bound to
;; 127.0.0.1 only, serves `notes-graph.html' (next to this file, with no
;; library and no network use), the notes' data as JSON, and one action, "open
;; this file".  Every request must carry a random token that only the URL
;; Emacs opens knows, and a Host header naming the loopback address, so
;; another page in the same browser cannot drive it.  The data is read from
;; the notes each time the map asks, so "Reload" in the page is live.
;;
;; What counts as a link is what the rest of the notes setup writes: a
;; relative [[file:...]] link in a note, outside source and example blocks,
;; to another note.  Index pages are left out (they link to everything and
;; would turn the graph into a hairball); the structure they stand for is the
;; topic tree.

;;; Code:

(require 'subr-x)
(require 'seq)
(require 'cl-lib)
(require 'json)
(require 'url-util)

(declare-function heks/notes--root "notes" ())
(declare-function heks/notes--header "notes" (file))
(declare-function heks/notes--pretty "notes" (segment))
(declare-function heks/notes-files "notes" (&optional archive))
(declare-function org-mode "org")
(declare-function org-content "org")

(defconst heks/notes-graph--directory
  (file-name-directory (or load-file-name buffer-file-name default-directory))
  "The folder this module, and the page it serves, live in.")

(defcustom heks/notes-graph-exclude
  '("\\`\\(?:todo\\|habits\\|birthdays\\|contacts\\|bookmarks\\)\\.org\\'"
    "\\(?:\\`\\|/\\)index\\.org\\'"
    "\\`diary/")
  "Regexps, on the path inside the notes, of files that are not part of the map.
The personal files at the top, the index pages and the diary (a note a day,
nothing links to it) are not notes to look at the connections of."
  :type '(repeat regexp)
  :group 'heks)

(defcustom heks/notes-graph-browser-function nil
  "The function that opens the map's URL, or nil for the system's browser.
The map needs a browser with JavaScript, so `eww' is not a choice."
  :type '(choice (const :tag "The system browser" nil) function)
  :group 'heks)

;;; ---- The data ---------------------------------------------------------

(defun heks/notes-graph--files (archive)
  "Return the note files the map shows; with ARCHIVE, the archive's too."
  (let ((root (heks/notes--root)))
    (seq-remove
     (lambda (file)
       (let ((rel (file-relative-name file root)))
         (seq-some (lambda (rx) (string-match-p rx rel)) heks/notes-graph-exclude)))
     (append (heks/notes-files) (and archive (heks/notes-files t))))))

(defun heks/notes-graph--links (file)
  "Return the absolute names of the files FILE links to with a file: link.
Links inside source, example, export and comment blocks are not links."
  (let ((dir (file-name-directory file)) (in-block nil) (in-gen nil) links)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (not (eobp))
        (let ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
          (cond
           (in-gen
            (when (string-prefix-p "# END GENERATED RELATED" line) (setq in-gen nil)))
           ((string-prefix-p "# BEGIN GENERATED RELATED" line)
            (setq in-gen t))
           (in-block
            (when (string-match-p "\\`[ \t]*#\\+end_\\(?:src\\|example\\|export\\|comment\\|verse\\)" (downcase line))
              (setq in-block nil)))
           ((string-match-p "\\`[ \t]*#\\+begin_\\(?:src\\|example\\|export\\|comment\\|verse\\)" (downcase line))
            (setq in-block t))
           (t
            (let ((start 0))
              (while (string-match "\\[\\[file:\\([^]]+?\\)\\(?:::[^]]*\\)?\\]" line start)
                (let ((path (match-string 1 line)))
                  (unless (or (file-name-absolute-p path) (string-prefix-p "~" path))
                    (push (expand-file-name path dir) links)))
                (setq start (match-end 0)))))))
        (forward-line 1)))
    (nreverse links)))

(defun heks/notes-graph--topic-of (rel)
  "Return the topic path of the note REL: its folder, \"\" at the top."
  (directory-file-name (or (file-name-directory rel) "")))

(defun heks/notes-graph--parent (path)
  "Return the topic containing the topic PATH, or nil for the root."
  (cond ((string-empty-p path) nil)
        (t (directory-file-name (or (file-name-directory path) "")))))

;;;###autoload
(defun heks/notes-graph-data (&optional archive)
  "Return the notes as a plist of :nodes and :edges, ready for `json-serialize'.
Nodes are notes and topics; edges are `link' (note to note) and `tree'
(a topic to what is directly inside it).  With ARCHIVE, the archive too."
  (let* ((root (heks/notes--root))
         (files (heks/notes-graph--files archive))
         (known (make-hash-table :test 'equal))
         (topics (make-hash-table :test 'equal))
         (seen (make-hash-table :test 'equal))
         notes edges)
    (dolist (f files) (puthash (file-relative-name f root) f known))
    (puthash "" (list 0 0) topics)
    (dolist (f files)
      (let* ((rel (file-relative-name f root))
             (header (heks/notes--header f))
             (topic (heks/notes-graph--topic-of rel))
             (tags (split-string (or (alist-get 'tags header) "") ":" t "[ \t]+"))
             (attrs (file-attributes f))
             (age (floor (/ (float-time (time-subtract nil (file-attribute-modification-time attrs))) 86400)))
             (archived (string-prefix-p (concat heks/notes-archive-name "/") rel)))
        (push (list :id rel :rel rel
                    :title (or (alist-get 'title header) (file-name-base f))
                    :topic topic :tags (vconcat tags)
                    :size (file-attribute-size attrs) :age (max 0 age)
                    :archived (if archived t :false))
              notes)
        ;; the topic, and every topic above it, counts this note
        (let ((path topic) (first t))
          (while path
            (let ((cell (or (gethash path topics) (puthash path (list 0 0) topics))))
              (when first (cl-incf (nth 0 cell)))
              (cl-incf (nth 1 cell)))
            (setq first nil path (heks/notes-graph--parent path))))
        (push (list :s (concat "t:" topic) :t rel :k "tree") edges)
        (dolist (target (heks/notes-graph--links f))
          (let ((to (file-relative-name target root)))
            (when (and (gethash to known) (not (equal to rel)))
              (let ((key (concat rel "\0" to)))
                (unless (gethash key seen)
                  (puthash key t seen)
                  (push (list :s rel :t to :k "link") edges))))))))
    (let (topic-nodes)
      (maphash
       (lambda (path cell)
         (let ((parent (heks/notes-graph--parent path)))
           (push (list :id (concat "t:" path) :t t :path path
                       :title (cond ((string-empty-p path) "Notes")
                                    (t (heks/notes--pretty (file-name-nondirectory path))))
                       :parent (or parent :null)
                       :count (nth 0 cell) :total (nth 1 cell)
                       :archived (if (string-prefix-p heks/notes-archive-name path) t :false))
                 topic-nodes)
           (when parent (push (list :s (concat "t:" parent) :t (concat "t:" path) :k "tree") edges))))
       topics)
      (list :nodes (vconcat (nreverse topic-nodes) (nreverse notes))
            :edges (vconcat (nreverse edges))))))

(defun heks/notes-graph--json (data)
  "Return DATA as JSON that is safe to put inside a <script> element."
  (replace-regexp-in-string
   "</" "<\\\\/"
   (json-serialize data :false-object :false :null-object :null)))

(defun heks/notes-graph--page (config)
  "Return the page, its configuration set to the plist CONFIG."
  (with-temp-buffer
    (insert-file-contents (expand-file-name "notes-graph.html" heks/notes-graph--directory))
    (goto-char (point-min))
    (unless (search-forward "/*@CONFIG@*/ {}" nil t)
      (error "notes-graph.html has no place for its configuration"))
    (replace-match (heks/notes-graph--json config) t t)
    (buffer-string)))

;;; ---- The server -------------------------------------------------------

(defvar heks/notes-graph--server nil "The listening process.")
(defvar heks/notes-graph--token nil "What a request must carry to be answered.")

(defun heks/notes-graph--respond (proc status type body)
  "Answer PROC with STATUS (a line), content TYPE and BODY, then close."
  (let* ((bytes (if (multibyte-string-p body) (encode-coding-string body 'utf-8) body))
         (head (encode-coding-string
                (format "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\n\r\n"
                        status type (length bytes))
                'us-ascii)))
    (when (process-live-p proc)
      (process-send-string proc (concat head bytes))
      (run-at-time 1 nil (lambda () (when (process-live-p proc) (delete-process proc)))))))

(defun heks/notes-graph--open (kind path)
  "Open the note, or folder when KIND is \"topic\", at PATH inside the notes."
  (let* ((root (file-name-as-directory (heks/notes--root)))
         (file (expand-file-name path root)))
    (when (and (file-in-directory-p file root) (file-exists-p file))
      (run-at-time 0 nil
                   (lambda ()
                     (if (equal kind "topic") (dired file) (find-file file))
                     (when (display-graphic-p)
                       (raise-frame) (select-frame-set-input-focus (selected-frame)))))
      t)))

(defun heks/notes-graph--note-html (path)
  "Return a complete HTML page rendering the note at PATH, or nil.
Links from the note to other notes stay inside the viewer."
  (let* ((root (file-name-as-directory (heks/notes--root)))
         (file (expand-file-name path root)))
    (when (and (file-in-directory-p file root) (file-regular-p file)
               (require 'ox-html nil t))
      (let* ((dir (file-name-directory file))
             (title (or (alist-get 'title (heks/notes--header file)) (file-name-base file)))
             (body
              (with-temp-buffer
                (insert-file-contents file)
                (setq default-directory dir)
                (let ((org-inhibit-startup t)
                      (org-export-with-toc nil)
                      (org-export-with-broken-links t)
                      (org-export-use-babel nil)
                      (org-export-babel-evaluate nil)
                      (org-html-htmlize-output-type nil)
                      (org-confirm-babel-evaluate nil))
                  (delay-mode-hooks (org-mode))
                  (org-export-as 'html nil nil t))))
             (here (file-name-directory path)))
        ;; relative links to other org notes go through the viewer
        (setq body
              (replace-regexp-in-string
               "href=\"\\([^\"#:?]+\\.org\\)\\(#[^\"]*\\)?\""
               (lambda (m)
                 (let* ((rel (match-string 1 m))
                        (abs (expand-file-name rel dir)))
                   (if (file-in-directory-p abs root)
                       (format "href=\"/note?t=%s&p=%s\""
                               heks/notes-graph--token
                               (url-hexify-string (file-relative-name abs root)))
                     m)))
               body t))
        (ignore here)
        (format "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<title>%s · heks notes</title><style>%s</style>
<script>(function(){var m=matchMedia('(prefers-color-scheme: dark)'),r=document.documentElement;
function s(){try{return localStorage.getItem('heks-theme')}catch(e){return null}}
function a(){r.dataset.theme=s()||(m.matches?'dark':'light')}a();m.addEventListener('change',a);
window.heksToggle=function(){try{localStorage.setItem('heks-theme',r.dataset.theme=='dark'?'light':'dark')}catch(e){}a()}})()</script>
</head><body>
<nav><a href=\"/?t=%s\">← heks notes map</a><span class=\"sp\"></span>
<span class=\"path\">%s</span><button onclick=\"heksToggle()\" title=\"Light / dark\">◐</button></nav>
<article>%s</article>
<footer>rendered by heks-emacs · <a href=\"/open?t=%s&k=note&p=%s\" onclick=\"fetch(this.href);return false\">open in Emacs</a></footer>
</body></html>"
                (url-insert-entities-in-string title)
                heks/notes-graph--note-css
                heks/notes-graph--token
                (url-insert-entities-in-string path)
                body
                heks/notes-graph--token (url-hexify-string path))))))

(defconst heks/notes-graph--note-css
  ":root{color-scheme:light dark;--bg:#e9ecf3;--glass:rgba(255,255,255,.62);--ink:#1d1d1f;--dim:#6e6e73;--line:rgba(0,0,0,.1);--accent:#0a64d8;--code:rgba(0,0,0,.05)}
:root[data-theme=dark]{--bg:#15161c;--glass:rgba(40,42,52,.6);--ink:#f2f2f5;--dim:#98989f;--line:rgba(255,255,255,.12);--accent:#64a5ff;--code:rgba(255,255,255,.08)}
nav button{border:1px solid var(--line);background:var(--code);color:var(--ink);border-radius:8px;padding:2px 9px;cursor:pointer;font:inherit}
*{box-sizing:border-box}
body{margin:0;min-height:100vh;color:var(--ink);font:16px/1.65 -apple-system,BlinkMacSystemFont,'SF Pro Text',system-ui,sans-serif;-webkit-font-smoothing:antialiased;
background:radial-gradient(900px 600px at 10% -10%,rgba(255,150,90,.35),transparent 60%),radial-gradient(900px 700px at 100% 10%,rgba(90,140,255,.35),transparent 60%),radial-gradient(800px 600px at 50% 110%,rgba(180,100,255,.25),transparent 60%),var(--bg);background-attachment:fixed}
nav{position:sticky;top:0;z-index:2;display:flex;gap:12px;align-items:center;padding:10px 20px;background:var(--glass);backdrop-filter:blur(24px) saturate(180%);-webkit-backdrop-filter:blur(24px) saturate(180%);border-bottom:1px solid var(--line);font-size:13px}
nav .sp{flex:1}.path,footer{color:var(--dim);font-size:12px}
a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}
article{max-width:780px;margin:32px auto;padding:30px 40px;background:var(--glass);backdrop-filter:blur(28px) saturate(180%);-webkit-backdrop-filter:blur(28px) saturate(180%);border:1px solid var(--line);border-radius:18px;box-shadow:0 12px 40px rgba(0,0,0,.12)}
h1.title{font-size:2em;letter-spacing:-.02em;margin:.1em 0 .6em}
h2,h3,h4{letter-spacing:-.01em;line-height:1.25;margin:1.6em 0 .5em}
h2{border-bottom:1px solid var(--line);padding-bottom:.25em}
pre,code{font:13px/1.5 ui-monospace,'SF Mono',Menlo,monospace}
code{background:var(--code);padding:.1em .35em;border-radius:5px}
pre{background:var(--code);border:1px solid var(--line);border-radius:10px;padding:12px 14px;overflow:auto}pre code{background:none;padding:0}
blockquote{margin:1em 0;padding:.1em 1em;border-left:3px solid var(--accent);color:var(--dim)}
table{border-collapse:collapse}td,th{border:1px solid var(--line);padding:4px 10px}
img{max-width:100%;border-radius:10px}
.todo,.done{font:600 11px ui-monospace,monospace;border-radius:5px;padding:1px 6px;background:var(--code)}.done{color:#28a745}.todo{color:#e5484d}
.tag span{font-size:11px;border:1px solid var(--line);border-radius:999px;padding:0 8px;color:var(--dim);margin-left:4px}
footer{text-align:center;padding:0 0 30px}
"
  "Stylesheet of the note viewer: macOS-like, light and dark, frosted glass.")

(defun heks/notes-graph--handle (proc request)
  "Answer PROC's HTTP REQUEST (its text up to the blank line)."
  (let* ((lines (split-string request "\r\n" t))
         (first (car lines))
         (host (and (seq-find (lambda (l) (string-match-p "\\`[Hh]ost:" l)) lines)))
         (port (process-contact heks/notes-graph--server :service)))
    (if (not (and first (string-match "\\`GET \\([^ ]+\\) HTTP/1\\.[01]\\'" first)))
        (heks/notes-graph--respond proc "400 Bad Request" "text/plain" "bad request")
      (let* ((target (match-string 1 first))
             (path (car (split-string target "?")))
             (query (url-parse-query-string (or (cadr (split-string target "?")) "")))
             (arg (lambda (k) (cadr (assoc k query)))))
        (cond
         ((not (and host (member (string-trim (substring host 5))
                                 (list (format "127.0.0.1:%d" port) (format "localhost:%d" port)))))
          (heks/notes-graph--respond proc "403 Forbidden" "text/plain" "wrong host"))
         ((not (equal (funcall arg "t") heks/notes-graph--token))
          (heks/notes-graph--respond proc "403 Forbidden" "text/plain" "forbidden"))
         ((equal path "/")
          (heks/notes-graph--respond
           proc "200 OK" "text/html; charset=utf-8"
           (heks/notes-graph--page (list :serve t :token heks/notes-graph--token))))
         ((equal path "/data.json")
          (heks/notes-graph--respond
           proc "200 OK" "application/json; charset=utf-8"
           (json-serialize (heks/notes-graph-data (equal (funcall arg "archive") "1"))
                           :false-object :false :null-object :null)))
         ((equal path "/note")
          (if-let* ((p (funcall arg "p"))
                    (html (heks/notes-graph--note-html p)))
              (heks/notes-graph--respond proc "200 OK" "text/html; charset=utf-8" html)
            (heks/notes-graph--respond proc "404 Not Found" "text/plain" "no such note")))
         ((equal path "/open")
          (if (heks/notes-graph--open (funcall arg "k") (funcall arg "p"))
              (heks/notes-graph--respond proc "204 No Content" "text/plain" "")
            (heks/notes-graph--respond proc "404 Not Found" "text/plain" "no such note")))
         (t (heks/notes-graph--respond proc "404 Not Found" "text/plain" "not found")))))))

(defun heks/notes-graph--filter (proc chunk)
  "Collect CHUNK from PROC; answer once the request headers are complete."
  (let ((buf (concat (or (process-get proc :buffer) "") chunk)))
    (process-put proc :buffer buf)
    (when-let* ((end (string-search "\r\n\r\n" buf)))
      (process-put proc :buffer nil)
      (condition-case err
          (heks/notes-graph--handle proc (substring buf 0 end))
        (error (heks/notes-graph--respond proc "500 Internal Server Error" "text/plain"
                                          (format "%s" (error-message-string err))))))
    (when (> (length buf) 16384) (delete-process proc))))

(defun heks/notes-graph--ensure-server ()
  "Start the server if it is not running; return its port."
  (unless (process-live-p heks/notes-graph--server)
    (setq heks/notes-graph--token (format "%08x%08x%08x" (random #xffffffff) (random #xffffffff) (random #xffffffff))
          heks/notes-graph--server
          (make-network-process :name "heks-notes-graph" :server t :host "127.0.0.1"
                                :service t :family 'ipv4 :noquery t :coding 'binary
                                :filter #'heks/notes-graph--filter
                                :sentinel #'ignore)))
  (process-contact heks/notes-graph--server :service))

(defun heks/notes-graph--browse (url)
  "Open URL in the browser the map is meant for."
  (funcall (or heks/notes-graph-browser-function
               (and (fboundp 'browse-url-default-browser) #'browse-url-default-browser)
               #'browse-url)
           url))

;;;###autoload
(defun heks/notes-graph ()
  "Open the map of the notes in the browser: links, topics, or both, and a tree.
The archive is a checkbox in the page.  The page is served by this Emacs
and clicking a note opens it here."
  (interactive)
  (heks/notes--root)
  (let ((port (heks/notes-graph--ensure-server)))
    (heks/notes-graph--browse (format "http://127.0.0.1:%d/?t=%s" port heks/notes-graph--token))
    (message "The notes map is at 127.0.0.1:%d (served by this Emacs; M-x heks/notes-graph-stop ends it)"
             port)))

;;;###autoload
(defun heks/notes-graph-stop ()
  "Stop serving the notes map."
  (interactive)
  (when (process-live-p heks/notes-graph--server)
    (delete-process heks/notes-graph--server))
  (setq heks/notes-graph--server nil heks/notes-graph--token nil)
  (message "The notes map is no longer served"))

;;;###autoload
(defun heks/notes-graph-export (file &optional archive)
  "Write the map of the notes to FILE, one self-contained HTML page, and open it.
With a prefix argument ARCHIVE, the archive is in it.  An exported page has
no Emacs behind it, so a click on a note shows and copies its path."
  (interactive (list (read-file-name "Write the map to: " nil nil nil "notes-map.html")
                     current-prefix-arg))
  (let ((page (heks/notes-graph--page (list :serve :false :data (heks/notes-graph-data archive)))))
    (let ((coding-system-for-write 'utf-8-unix))
      (with-temp-file file (insert page)))
    (heks/notes-graph--browse (concat "file://" (expand-file-name file)))
    (message "Wrote %s" file)
    file))

;;; ---- The tree in a buffer ---------------------------------------------

(defun heks/notes-graph--org-text (title)
  "Return TITLE safe to use as the text of an Org link."
  (replace-regexp-in-string "[][]" (lambda (m) (if (equal m "[") "(" ")")) title))

;;;###autoload
(defun heks/notes-tree (&optional archive)
  "Show the topics and notes as a folding outline in a buffer.
Topics are headings with the number of notes beneath them; notes are links.
\\[org-cycle] folds, \\[org-shifttab] changes how much is shown; with a prefix
argument ARCHIVE the archive is part of it."
  (interactive "P")
  (let* ((root (file-name-as-directory (heks/notes--root)))
         (data (heks/notes-graph-data archive))
         (nodes (append (plist-get data :nodes) nil))
         (topics (seq-filter (lambda (n) (eq (plist-get n :t) t)) nodes))
         (notes (seq-remove (lambda (n) (eq (plist-get n :t) t)) nodes))
         (buffer (get-buffer-create "*Notes tree*"))
         (sort-title (lambda (a b) (string< (downcase (plist-get a :title))
                                            (downcase (plist-get b :title))))))
    (cl-labels
        ((emit (topic depth)
           (let ((path (plist-get topic :path)))
             (insert (make-string (1+ depth) ?*) " "
                     (heks/notes-graph--org-text (plist-get topic :title))
                     (format " (%d)\n" (plist-get topic :total)))
             (dolist (n (sort (seq-filter (lambda (n) (equal (plist-get n :topic) path)) notes) sort-title))
               (insert (format "- [[file:%s][%s]]\n" (expand-file-name (plist-get n :rel) root)
                               (heks/notes-graph--org-text (plist-get n :title)))))
             (dolist (child (sort (seq-filter (lambda (tp) (equal (plist-get tp :parent) path)) topics) sort-title))
               (when (and (not (equal (plist-get child :path) path)))
                 (emit child (1+ depth)))))))
      (with-current-buffer buffer
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert "#+title: Notes\n#+startup: content\n\n")
          (emit (seq-find (lambda (tp) (equal (plist-get tp :path) "")) topics) 0)
          (org-mode)
          (goto-char (point-min))
          (org-content)
          (setq buffer-read-only t))))
    (pop-to-buffer buffer)))

(global-set-key (kbd "C-c n g") #'heks/notes-graph)
(global-set-key (kbd "C-c n G") #'heks/notes-graph-export)
(global-set-key (kbd "C-c n T") #'heks/notes-tree)

(provide 'heks/notes-graph)

;;; notes-graph.el ends here
