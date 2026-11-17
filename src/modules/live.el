;;; live.el --- Org and Markdown, rendered where they are written  -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; `render.el' makes a page of a document and shows it in another buffer.
;; This is the other kind of preview, the one Obsidian made familiar: the
;; buffer is the rendered document, and the source of whatever point is on
;; is shown instead, so that reading never needs a second window and
;; editing never needs a mode switch.
;;
;; Markdown already hides its own markup (`emacs-core.el' does that, and
;; reveals it around point).  What was missing is here, for both formats:
;;
;;   * a table is drawn as one -- `│' between the cells and a box rule under
;;     the header -- and shows its pipes again the moment point is in it;
;;   * in Org, a list bullet is a dot, a checkbox is a box, and the emphasis
;;     and link markers of the line point is on are shown, the way
;;     `org-appear' does, and hidden again when point leaves it.
;;
;; Nothing here changes the text: it is overlays, `display' properties and
;; `invisible' properties, so saving the buffer writes what was typed.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defface heks/live-table '((t :inherit fixed-pitch))
  "Face of a table row, so cells line up whatever the prose font is.")

(defface heks/live-table-header '((t :inherit (heks/live-table bold)))
  "Face of the rows above a table's first rule.")

(defface heks/live-table-border '((t :inherit (heks/live-table shadow)))
  "Face of the box characters that replace a table's pipes and rules.")

(defconst heks/live-row-regexp "^[ \t]*|"
  "A line that is a row of an Org table, which always has a leading pipe.")

(defconst heks/live-rule-regexp
  (concat "\\`[ \t]*|?[ \t]*:?-+:?[ \t]*"
          "\\(?:[|+][ \t]*:?-+:?[ \t]*\\)*|?[ \t]*\\'")
  "A rule line: Org's `|---+---|', Markdown's `|:--|--:|' or `--|--'.")

(defun heks/live--rule-line-p (line)
  "Return non-nil when LINE is a table rule.
A rule needs a pipe: a bare `---' is a thematic break, not a table."
  (and (string-match-p "|" line)
       (string-match-p heks/live-rule-regexp line)
       t))

(defun heks/live--line-text ()
  "Return the text of this line."
  (buffer-substring-no-properties (line-beginning-position) (line-end-position)))

(defun heks/live--cells (line)
  "Return the trimmed cell strings of the table row LINE.
An escaped pipe is a character of its cell, not its border."
  (let* ((s (string-trim line)) (n (length s))
         (i (if (string-prefix-p "|" s) 1 0))
         (start i) (cells nil))
    (while (< i n)
      (cond ((eq (aref s i) ?\\) (setq i (+ i 2)))
            ((eq (aref s i) ?|)
             (push (substring s start i) cells)
             (setq i (1+ i) start i))
            (t (setq i (1+ i)))))
    (when (< start n) (push (substring s start) cells))
    (mapcar #'string-trim (nreverse cells))))

(defface heks/live-table-code '((t :inherit (heks/live-table font-lock-constant-face)))
  "Face of a code span inside a table cell.")

(defun heks/live--style (regexp text face)
  "Return TEXT with each REGEXP match replaced by its group 1, in FACE.
A match is left alone when it lies in a code span an earlier rule styled,
or when it is `_' inside a word, as in snake_case: code is not markup."
  (let ((start 0) (parts nil))
    (while (string-match regexp text start)
      (let ((mb (match-beginning 0)) (me (match-end 0)))
        (if (or (text-property-any mb me 'face 'heks/live-table-code text)
                (and (eq (aref text mb) ?_) (> mb 0)
                     (string-match-p "[[:alnum:]]" (string (aref text (1- mb)))))
                (and (eq (aref text (1- me)) ?_) (< me (length text))
                     (string-match-p "[[:alnum:]]" (string (aref text me)))))
            (progn (push (substring text start (1+ mb)) parts)
                   (setq start (1+ mb)))
          (push (substring text start mb) parts)
          (push (propertize (match-string 1 text) 'face face) parts)
          (setq start me))))
    (apply #'concat (nreverse (cons (substring text start) parts)))))

(defun heks/live--plain (cell)
  "Return CELL as it reads: the markup is gone and what it meant is a face.
A display string cannot hide markers the way the buffer does, so the
markers are dropped and the span keeps the look the markers asked for."
  (let ((text (replace-regexp-in-string "\\\\|" "|" cell t t))
        (org (derived-mode-p 'org-mode)))
    (dolist (rule `(("\\[\\([^]]+\\)\\]([^)]*)" . link)
                    ("\\[\\[[^]]*\\]\\[\\([^]]+\\)\\]\\]" . link)
                    ("\\[\\[\\([^]]+\\)\\]\\]" . link)
                    ("`\\([^`]+\\)`" . heks/live-table-code)
                    ,@(when org
                        '(("=\\([^= ][^=]*\\)=" . heks/live-table-code)
                          ("~\\([^~ ][^~]*\\)~" . heks/live-table-code)))
                    ("\\*\\*\\([^*]+\\)\\*\\*" . bold)
                    ("\\*\\([^* ][^*]*\\)\\*" . ,(if org 'bold 'italic))
                    ("_\\([^_]+\\)_" . italic)))
      (setq text (heks/live--style (car rule) text (cdr rule))))
    text))

(defun heks/live--aligns (line)
  "Return the alignment of each column of the rule LINE: `left', `right' or `center'."
  (mapcar (lambda (cell)
            (let ((l (string-prefix-p ":" cell)) (r (string-suffix-p ":" cell)))
              (cond ((and l r) 'center) (r 'right) (t 'left))))
          (split-string (string-trim line "[ \t|]+" "[ \t|]+") "[|+]")))

(defconst heks/live-break-regexp "[-/_.,:;]+"
  "Where a word too wide for its column may be split, after the match.
Splitting there keeps `a-very-long-name' or a path readable; a word with no
such place is cut at the column edge as a last resort.")

(defun heks/live--segments (word)
  "Return WORD cut after each run of `heks/live-break-regexp'."
  (let ((start 0) (segments nil))
    (while (string-match heks/live-break-regexp word start)
      (push (substring word start (match-end 0)) segments)
      (setq start (match-end 0)))
    (when (< start (length word)) (push (substring word start) segments))
    (nreverse segments)))

(defun heks/live--tokens (text width)
  "Return TEXT as (PIECE . GLUE) pairs to lay out in a column WIDTH wide.
GLUE is what goes before PIECE when it shares a line with the one before.
A word that fits a line on its own is one piece, so it moves down whole
rather than being split; only a word wider than WIDTH is cut into segments,
glued to each other with nothing."
  (cl-loop for word in (split-string text)
           append (if (<= (string-width word) width)
                      (list (cons word " "))
                    (cl-loop for segment in (heks/live--segments word)
                             for glue = " " then ""
                             collect (cons segment glue)))))

(defun heks/live--wrap (text width)
  "Break TEXT into lines no wider than WIDTH.
Greedy: words fill a line until the next does not fit.  A word wider than
a whole line is split after its hyphens, slashes, dots and the like, and
a piece that is still too wide is cut where the column ends."
  (let ((lines nil) (line ""))
    (pcase-dolist (`(,piece . ,glue) (heks/live--tokens text width))
      (while (> (string-width piece) width)
        (let ((head (truncate-string-to-width piece width)))
          (unless (string-empty-p line) (push line lines) (setq line ""))
          (push head lines)
          (setq piece (substring piece (length head)))))
      (cond ((string-empty-p line) (setq line piece))
            ((<= (+ (string-width line) (length glue) (string-width piece)) width)
             (setq line (concat line glue piece)))
            (t (push line lines) (setq line piece))))
    (nreverse (cons line lines))))

(defun heks/live--shrink (widths floors avail)
  "Return WIDTHS with the widest column above its floor narrowed until they fit AVAIL.
Taking from the widest first leaves short columns, a name or a number,
alone and makes the columns that carry prose pay for the space."
  (let ((w (copy-sequence widths)))
    (while (and (> (apply #'+ w) avail)
                (let ((best nil))
                  (cl-loop for i from 0 for x in w for f in floors
                           when (and (> x f) (or (null best) (> x (nth best w))))
                           do (setq best i))
                  (when best (cl-decf (nth best w)) t))))
    w))

(defun heks/live--widths (natural avail floors)
  "Return column widths from the NATURAL ones, shrunk to fit AVAIL columns.
FLOORS is each column's longest word: columns give way down to it first, so
no word is split while there is still room to avoid it.  Only if the table
is still too wide do they go on down to six columns, where words are split."
  (heks/live--shrink (heks/live--shrink natural floors avail)
                     (mapcar (lambda (f) (min f 6)) floors)
                     avail))

(defun heks/live--pad (text width align)
  "Pad TEXT to WIDTH columns according to ALIGN."
  (let ((gap (max 0 (- width (string-width text)))))
    (pcase align
      ('right (concat (make-string gap ?\s) text))
      ('center (concat (make-string (/ gap 2) ?\s) text
                       (make-string (- gap (/ gap 2)) ?\s)))
      (_ (concat text (make-string gap ?\s))))))

(defun heks/live--border (widths left mid right)
  "Return a horizontal box line over columns of WIDTHS."
  (propertize
   (concat left (mapconcat (lambda (w) (make-string (+ w 2) ?─)) widths mid) right)
   'face 'heks/live-table-border))

(defun heks/live--render (lines avail)
  "Return the box-drawn string for table LINES, fitted to AVAIL columns.
Rows above the first rule are the header; a rule line is a separator, and
when a cell wraps, the body rows are separated so each stays readable."
  (let* ((rule (seq-find #'heks/live--rule-line-p lines))
         (aligns (and rule (heks/live--aligns rule)))
         (rows (mapcar (lambda (l)
                         (if (heks/live--rule-line-p l) 'rule
                           (mapcar #'heks/live--plain (heks/live--cells l))))
                       lines))
         (data (seq-filter #'consp rows))
         (ncols (apply #'max 1 (mapcar #'length data)))
         (natural (cl-loop for c below ncols
                           collect (apply #'max 1 (mapcar (lambda (r) (string-width (or (nth c r) ""))) data))))
         (floors (cl-loop for c below ncols
                          collect (min (nth c natural) 16
                                       (apply #'max 1 (mapcar (lambda (r)
                                                                (apply #'max 0 (mapcar #'string-width
                                                                                       (split-string (or (nth c r) "")))))
                                                              data)))))
         (widths (heks/live--widths natural (- avail (* 3 ncols) 1) floors))
         (bar (propertize "│" 'face 'heks/live-table-border))
         (wrapped (cl-some (lambda (r)
                             (cl-loop for c below ncols
                                      thereis (> (string-width (or (nth c r) "")) (nth c widths))))
                           data))
         (out nil) (previous nil))
    (let ((cut (and rule (seq-position lines rule))))
      (push (heks/live--border widths "┌" "┬" "┐") out)
      (cl-loop
       for row in rows for index from 0
       do (cond
           ((eq row 'rule)
            (setq previous 'rule)
            (push (heks/live--border widths "├" "┼" "┤") out))
           (t
            (let* ((header (and cut (< index cut)))
                   (cells (cl-loop for c below ncols
                                   collect (heks/live--wrap (or (nth c row) "") (nth c widths))))
                   (height (apply #'max (mapcar #'length cells)))
                   (face (if header 'heks/live-table-header 'heks/live-table)))
              (when (and wrapped (eq previous 'row))
                (push (heks/live--border widths "├" "┼" "┤") out))
              (dotimes (k height)
                (push (concat bar
                              (mapconcat
                               (lambda (c)
                                 (let ((cell (concat " " (heks/live--pad (or (nth k (nth c cells)) "")
                                                                         (nth c widths)
                                                                         (if header 'left (or (nth c aligns) 'left)))
                                                     " ")))
                                   ;; Appended, so a span's own face wins over the row's.
                                   (add-face-text-property 0 (length cell) face t cell)
                                   cell))
                               (number-sequence 0 (1- ncols)) bar)
                              bar)
                      out))
              (setq previous 'row)))))
      (push (heks/live--border widths "└" "┴" "┘") out))
    (mapconcat #'identity (nreverse out) "\n")))

(defun heks/live--overlay (beg end &rest properties)
  "Make a live overlay from BEG to END carrying PROPERTIES."
  (let ((overlay (make-overlay beg end nil t nil)))
    (overlay-put overlay 'heks-live t)
    (overlay-put overlay 'evaporate t)
    (while properties
      (overlay-put overlay (pop properties) (pop properties)))
    overlay))

(defun heks/live--clear (beg end)
  "Delete the live overlays between BEG and END."
  (dolist (overlay (overlays-in beg end))
    (when (overlay-get overlay 'heks-live)
      (delete-overlay overlay))))

(defun heks/live--row-p ()
  "Return non-nil when this line may be a row of a table.
Org's rows start with a pipe.  Markdown's need only contain one, which is
why a Markdown table is only a table once its rule is found."
  (if (derived-mode-p 'org-mode)
      (looking-at-p heks/live-row-regexp)
    (looking-at-p "[^\n]*|")))

(defun heks/live--row-at-p (offset)
  "Return non-nil when the line OFFSET lines from this one is a table row."
  (save-excursion
    (and (zerop (forward-line offset))
         (heks/live--row-p))))

(defun heks/live--markdown-header (beg end)
  "Return where the table in the run BEG..END starts, or nil when there is none.
It starts at the line above the first rule: a pipe in a paragraph is only
a pipe."
  (save-excursion
    (goto-char beg)
    (let ((previous nil) (found nil))
      (while (and (not found) (< (point) end))
        (when (and previous (heks/live--rule-line-p (heks/live--line-text)))
          (setq found previous))
        (setq previous (point))
        (forward-line 1))
      found)))

(defun heks/live--table-bounds (pos)
  "Return (BEG . END) of the table POS is in, or nil when it is in none."
  (save-excursion
    (goto-char pos)
    (forward-line 0)
    (when (heks/live--row-p)
      (let* ((beg (save-excursion
                    (while (heks/live--row-at-p -1) (forward-line -1))
                    (point)))
             (end (save-excursion
                    (while (heks/live--row-at-p 1) (forward-line 1))
                    (line-end-position)))
             (start (if (derived-mode-p 'org-mode)
                        beg
                      (heks/live--markdown-header beg end))))
        (when (and start (<= start pos))
          (cons start end))))))

(defun heks/live--in-code-p (pos)
  "Return non-nil when POS is in a code block, where a pipe is only a pipe."
  (save-excursion
    (goto-char pos)
    (cond ((derived-mode-p 'org-mode) (org-in-src-block-p t))
          ((fboundp 'heks/markdown--block-at) (heks/markdown--block-at pos)))))

(defun heks/live--draw-table (beg end)
  "Draw the table between BEG and END as one box, fitted to the window."
  (let* ((window (get-buffer-window (current-buffer) t))
         (avail (if window (- (window-body-width window) 2) 78))
         (lines (split-string (buffer-substring-no-properties beg end) "\n")))
    (heks/live--overlay beg end 'display (heks/live--render lines avail))))

(defun heks/live-tables (beg end)
  "Draw every table that touches BEG..END, except the one point is in.
The table at point is left as source: that is the one being edited."
  (let ((pt (point)))
    (save-excursion
      (goto-char beg)
      (forward-line 0)
      (while (and (<= (point) end) (not (eobp)))
        (if-let* ((bounds (heks/live--table-bounds (point))))
            (progn
              (heks/live--clear (car bounds) (cdr bounds))
              (unless (or (<= (car bounds) pt (cdr bounds))
                          (heks/live--in-code-p (car bounds)))
                (heks/live--draw-table (car bounds) (cdr bounds)))
              (goto-char (cdr bounds))
              (forward-line 1))
          (forward-line 1))))))

(defvar-local heks/live--open nil
  "The (BEG . END) markers of the table whose source is showing, or nil.")

(defun heks/live--follow ()
  "Show the source of the table point is in, and draw the one it left."
  (let* ((bounds (heks/live--table-bounds (point)))
         (old heks/live--open))
    (unless (and bounds old
                 (= (car bounds) (car old))
                 (= (cdr bounds) (cdr old)))
      (setq heks/live--open
            (and bounds (cons (copy-marker (car bounds))
                              (copy-marker (cdr bounds) t))))
      (when old (heks/live-tables (car old) (cdr old)))
      (when bounds (heks/live-tables (car bounds) (cdr bounds))))))

;;
;; ====== Org ======
;;

(defun heks/live--glyph (group glyph)
  "Show the text of match GROUP as GLYPH; return nil, for `font-lock'."
  (put-text-property (match-beginning group) (match-end group) 'display glyph)
  nil)

(defconst heks/live-org-keywords
  '(("^[ \t]*\\([-+]\\)[ \t]" (0 (heks/live--glyph 1 "•")))
    ("^[ \t]*[-+][ \t]+\\(\\[X\\]\\)" (0 (heks/live--glyph 1 "☑")))
    ("^[ \t]*[-+][ \t]+\\(\\[ \\]\\)" (0 (heks/live--glyph 1 "☐")))
    ("^[ \t]*[-+][ \t]+\\(\\[-\\]\\)" (0 (heks/live--glyph 1 "◩"))))
  "Font-lock keywords that draw Org's bullets and checkboxes as glyphs.")

(defvar-local heks/live--element nil
  "The (BEG . END) of the Org element whose markers are showing, or nil.")

(defvar-local heks/live--restore nil
  "(KIND BEG END) of the preview point's element had before point entered it.
KIND is `latex' or `link'; BEG and END are markers.")

(defun heks/live--latex-preview (beg end)
  "Draw the LaTeX fragments between BEG and END as pictures, where Emacs can."
  (when (and (display-graphic-p) (fboundp 'org--latex-preview-region))
    (org--latex-preview-region beg end)))

(defun heks/live--link-preview (beg end)
  "Draw the previewable links between BEG and END, where Emacs can."
  (when (and (display-graphic-p) (fboundp 'org-link-preview-region))
    (org-link-preview-region t nil beg end)))

(defun heks/live--hide-preview (type range)
  "Clear the picture over the element of TYPE at RANGE, and remember it.
A picture over the source would hide the source point has come to edit."
  (let ((beg (car range)) (end (cdr range)))
    (cond
     ((memq type '(latex-fragment latex-environment))
      (when (org-clear-latex-preview beg end)
        (setq heks/live--restore (list 'latex (copy-marker beg) (copy-marker end)))))
     ((eq type 'link)
      (when (cl-some (lambda (o) (memq o org-link-preview-overlays))
                     (overlays-in beg end))
        (org-link-preview-clear beg end)
        (setq heks/live--restore (list 'link (copy-marker beg) (copy-marker end))))))))

(defun heks/live--restore-preview ()
  "Draw again the picture `heks/live--hide-preview' cleared."
  (when-let* ((restore heks/live--restore))
    (setq heks/live--restore nil)
    (pcase-let ((`(,kind ,beg ,end) restore))
      (if (eq kind 'latex)
          (heks/live--latex-preview beg end)
        (heks/live--link-preview beg end)))))

(defun heks/live--reveal-element ()
  "Show the source of the Org element at point; draw the last one again.
Emphasis and links show their markers, and a link or formula that is a
picture gives the picture up while point is in it."
  (let* ((element (ignore-errors (org-element-context)))
         (type (org-element-type element))
         (range (and (memq type '(bold italic underline strike-through code
                                       verbatim link latex-fragment latex-environment))
                     (cons (org-element-property :begin element)
                           (org-element-property :end element))))
         (old heks/live--element))
    (unless (equal range old)
      (setq heks/live--element range)
      (heks/live--restore-preview)
      (when (and old (<= (car old) (point-max)))
        (font-lock-flush (car old) (min (cdr old) (point-max)))))
    (when range
      (with-silent-modifications
        (remove-text-properties (car range) (cdr range) '(invisible nil)))
      (unless heks/live--restore
        (heks/live--hide-preview type range)))))

;;
;; ====== Fences, quotes, callouts and rules ======
;;
;; These are whole lines drawn as something else, so they are one `display'
;; property each, marked with `heks-live-deco' to tell them from the glyphs
;; above, which stay put under point.

(defconst heks/live-callouts
  '(("note" . "ⓘ") ("tip" . "✦") ("important" . "‼")
    ("warning" . "⚠") ("caution" . "⛔"))
  "The glyph that introduces each kind of callout.")

(defun heks/live--face (string)
  "Return STRING, shown in the border face."
  (propertize string 'face 'heks/live-table-border))

(defun heks/live--image-file (url)
  "Return the readable image file the Markdown destination URL names, or nil.
A destination with a scheme is not fetched: a preview that waits on a
network is not one."
  (when-let* (((stringp url))
              ((not (string-match-p "\\`[a-zA-Z][a-zA-Z0-9+.-]*:" url)))
              (file (expand-file-name (car (split-string url "#")) default-directory))
              ((file-readable-p file))
              ((image-supported-file-p file)))
    file))

(defun heks/live--image (url)
  "Return an image display spec for the Markdown destination URL, or nil."
  (when-let* (((display-graphic-p))
              (file (heks/live--image-file url))
              ((image-type-available-p (image-type-from-file-name file))))
    (create-image file nil nil :max-width 600 :max-height 400)))

(defun heks/live--decoration (line org-p &optional rule-ok)
  "Return (START END DISPLAY) for how LINE is drawn, or nil when it is plain.
START and END are offsets into LINE.  ORG-P picks Org's lines over
Markdown's, and RULE-OK says a rule may be drawn here: in Markdown a line
of dashes straight under text is a heading, not a rule."
  (let ((case-fold-search t)
        (indent (or (string-match "[^ \t]" line) 0)))
    (cl-flet ((whole (display) (list indent (length line) (heks/live--face display)))
              (head (display) (list indent (match-end 0) (heks/live--face display))))
      (cond
       ((string-empty-p line) nil)
       ((and (not org-p) (string-match "!\\[\\([^]]*\\)\\](\\([^) ]+\\)[^)]*)" line))
        ;; The picture where there is one; otherwise a label that says what
        ;; is missing, which is all a terminal or a remote image can be.
        (let* ((beg (match-beginning 0))
               (end (match-end 0))
               (alt (match-string 1 line))
               (url (match-string 2 line)))
          (list beg end
                (or (heks/live--image url)
                    (heks/live--face
                     (format "▣ %s" (if (string-empty-p alt)
                                        (file-name-nondirectory url)
                                      alt)))))))
       (org-p
        (cond ((string-match "\\`[ \t]*#\\+begin_src\\(?:[ \t]+\\([^ \t]+\\)\\)?" line)
               (whole (if-let* ((lang (match-string 1 line))) (concat "┌─ " lang) "┌─")))
              ((string-match-p "\\`[ \t]*#\\+end_src" line) (whole "└─"))
              ((string-match-p "\\`[ \t]*#\\+begin_quote" line) (whole "❝"))
              ((string-match-p "\\`[ \t]*#\\+end_quote" line) (whole "❞"))
              ((and rule-ok (string-match-p "\\`[ \t]*-\\{5,\\}[ \t]*\\'" line))
               (whole (make-string 40 ?─)))))
       ((string-match "\\`[ \t]*>[ \t]*\\[!\\([A-Za-z]+\\)\\][ \t]*" line)
        (let* ((end (match-end 0))
               (kind (heks/markdown-alert (concat "[!" (match-string 1 line) "]"))))
          (if kind
              (list indent end (heks/live--face
                                (format "%s %s" (cdr (assoc kind heks/live-callouts))
                                        (capitalize kind))))
            (and (string-match "\\`[ \t]*>[ \t]?" line) (head "▎")))))
       ((string-match "\\`[ \t]*>[ \t]?" line) (head "▎"))
       ((and rule-ok
             (string-match-p "\\`[ \t]*\\([-*_]\\)\\(?:[ \t]*\\1\\)\\{2,\\}[ \t]*\\'" line))
        (whole (make-string 40 ?─)))))))

(defun heks/live--math-specs (line)
  "Return the (START END DISPLAY) of each `$formula$' in the Markdown LINE.
The formula is shown as the text it transliterates to, which needs neither
LaTeX nor a graphical display.  A dollar sign beside a digit is a price.
shortcut: a line with a code span is skipped whole, when it matters, read
the spans."
  (when (and (fboundp 'heks/render-math-text) (not (string-match-p "`" line)))
    (let ((pos 0) (specs nil))
      (while (string-match "\\$\\([^$ \t\n]\\(?:[^$\n]*[^$ \t\n\\]\\)?\\)\\$" line pos)
        (let ((beg (match-beginning 0))
              (end (match-end 0))
              (tex (match-string 1 line)))
          (setq pos end)
          (unless (and (< end (length line)) (<= ?0 (aref line end) ?9))
            (push (list beg end (propertize (heks/render-math-text tex) 'face 'italic))
                  specs))))
      (nreverse specs))))

(defun heks/live--undecorate (beg end)
  "Take the decorations off the lines between BEG and END."
  (let ((pos beg))
    (while (< pos end)
      (let ((next (next-single-property-change pos 'heks-live-deco nil end)))
        (when (get-text-property pos 'heks-live-deco)
          (remove-text-properties pos next '(display nil heks-live-deco nil)))
        (setq pos next)))))

(defun heks/live--rule-ok-p (org-p)
  "Return non-nil when a rule may be drawn on this line."
  (or org-p
      (save-excursion
        (and (zerop (forward-line -1)) (looking-at-p "[ \t]*$")))))

(defun heks/live-decorate (beg end)
  "Draw the fences, quotes, callouts, rules and formulas of BEG..END.
The line point is on is left as source."
  (let ((org-p (derived-mode-p 'org-mode))
        (pt (point)))
    (with-silent-modifications
      (save-excursion
        (goto-char beg)
        (forward-line 0)
        (while (and (<= (point) end) (not (eobp)))
          (let* ((bol (point))
                 (eol (line-end-position))
                 (line (buffer-substring-no-properties bol eol))
                 (whole (heks/live--decoration line org-p (heks/live--rule-ok-p org-p)))
                 (specs (cond (whole (list whole))
                              (org-p nil)
                              (t (heks/live--math-specs line)))))
            (heks/live--undecorate bol eol)
            (when (and specs (not (<= bol pt eol)) (not (heks/live--in-code-p bol)))
              (dolist (spec specs)
                (add-text-properties (+ bol (nth 0 spec)) (+ bol (nth 1 spec))
                                     (list 'display (nth 2 spec) 'heks-live-deco t)))))
          (forward-line 1))))))

(defvar-local heks/live--line nil
  "Where the line whose source is showing starts, or nil.")

(defun heks/live--follow-line ()
  "Show the source of point's line, and draw the line point left."
  (let ((bol (line-beginning-position))
        (old heks/live--line))
    (unless (eql bol old)
      (setq heks/live--line bol)
      (when (and old (<= old (point-max)))
        (heks/live-decorate old old))
      (with-silent-modifications
        (heks/live--undecorate bol (line-end-position))))))

(defun heks/live--redraw-window ()
  "Draw the tables in view again: a new window width wraps them differently."
  (when-let* ((window (get-buffer-window (current-buffer))))
    (heks/live--follow)
    (heks/live-tables (window-start window) (window-end window t))))

(defun heks/live--post-command ()
  "Keep the preview in step with point."
  (heks/live--follow)
  (heks/live--follow-line)
  (when (derived-mode-p 'org-mode)
    (heks/live--reveal-element)))

;;;###autoload
(define-minor-mode heks/live-mode
  "Render this Org or Markdown buffer where it is written.
Tables are drawn as tables, quotes, callouts, fences and rules as what they
stand for, and in Org a bullet is a dot and a checkbox a box.  What point is
on shows its source."
  :lighter nil
  (if heks/live-mode
      (progn
        (jit-lock-register #'heks/live-tables)
        (jit-lock-register #'heks/live-decorate)
        (add-hook 'post-command-hook #'heks/live--post-command nil t)
        (add-hook 'window-configuration-change-hook #'heks/live--redraw-window nil t)
        ;; Draw what is in view now, rather than when the first jit-lock pass
        ;; happens to reach it.
        (run-with-idle-timer 0 nil (lambda (buffer)
                                     (when (buffer-live-p buffer)
                                       (with-current-buffer buffer
                                         (when heks/live-mode (heks/live--redraw-window)))))
                             (current-buffer))
        (if (derived-mode-p 'org-mode)
            (progn
              (font-lock-add-keywords nil heks/live-org-keywords 'append)
              (add-to-list 'font-lock-extra-managed-props 'display))
          ;; Emacs 30+: a wrapped list item or quote hangs under its text.
          (when (fboundp 'visual-wrap-prefix-mode)
            (visual-wrap-prefix-mode 1))))
    (jit-lock-unregister #'heks/live-tables)
    (jit-lock-unregister #'heks/live-decorate)
    (remove-hook 'post-command-hook #'heks/live--post-command t)
    (remove-hook 'window-configuration-change-hook #'heks/live--redraw-window t)
    (font-lock-remove-keywords nil heks/live-org-keywords)
    (heks/live--undecorate (point-min) (point-max))
    (heks/live--clear (point-min) (point-max)))
  (font-lock-flush))

(dolist (hook '(org-mode-hook markdown-ts-mode-hook markdown-mode-hook))
  (add-hook hook #'heks/live-mode))

(provide 'heks/live)

;;; live.el ends here
