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

(defun heks/live--rule-string (line)
  "Return the box-drawing rule that LINE, a table rule, is shown as.
It is as wide as LINE, so the cells under it keep their columns."
  (let* ((text (string-trim line))
         (last (1- (length text))))
    (propertize
     (concat (seq-map-indexed
              (lambda (char index)
                (cond ((and (= index 0) (eq char ?|)) ?├)
                      ((not (memq char '(?| ?+))) ?─)
                      ((and (= index last) (eq char ?|)) ?┤)
                      (t ?┼)))
              text))
     'face 'heks/live-table-border)))

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
  "Draw the table between BEG and END: pipes as `│', rules as box rules."
  (save-excursion
    (goto-char beg)
    (let ((first-rule (cl-loop while (< (point) end)
                               when (heks/live--rule-line-p (heks/live--line-text))
                               return (point)
                               do (forward-line 1))))
      (goto-char beg)
      (while (< (point) end)
        (let* ((bol (line-beginning-position))
               (eol (line-end-position))
               (start (progn (skip-chars-forward " \t") (point)))
               (text (buffer-substring start eol)))
          (if (heks/live--rule-line-p text)
              (heks/live--overlay start eol 'display (heks/live--rule-string text))
            (heks/live--overlay
             start eol 'face (if (and first-rule (< bol first-rule))
                                 'heks/live-table-header
                               'heks/live-table))
            (goto-char start)
            ;; An escaped pipe is a character of the cell, not its border.
            (while (search-forward "|" eol t)
              (unless (eq (char-before (1- (point))) ?\\)
                (heks/live--overlay
                 (1- (point)) (point)
                 'display (propertize "│" 'face 'heks/live-table-border)))))
          (forward-line 1))))))

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
    (font-lock-remove-keywords nil heks/live-org-keywords)
    (heks/live--undecorate (point-min) (point-max))
    (heks/live--clear (point-min) (point-max)))
  (font-lock-flush))

(dolist (hook '(org-mode-hook markdown-ts-mode-hook markdown-mode-hook))
  (add-hook hook #'heks/live-mode))

(provide 'heks/live)

;;; live.el ends here
