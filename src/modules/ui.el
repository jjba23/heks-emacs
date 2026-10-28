;;; ui.el --- HEKS-EMACS configuration for Emacs -*- lexical-binding: t -*-

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

;; UI configuration for Emacs

;;; Code:

(use-package pulsar
  :ensure t
  :custom
  (pulsar-pulse t)
  (pulsar-delay 0.055)
  (pulsar-iterations 10)
  (pulsar-highlight-face 'pulsar-yellow)
  :config
  (cond ((equal heks/theme 'ef-dream) (setq pulsar-face 'pulsar-magenta))
        ((memq heks/theme '(everforest-dark everforest-light)) (setq pulsar-face 'pulsar-green))
        (t (setq pulsar-face 'pulsar-green)))
  (pulsar-global-mode 1)
  (ignore-errors
    (add-hook 'consult-after-jump-hook #'pulsar-recenter-top)
    (add-hook 'consult-after-jump-hook #'pulsar-reveal-entry)))

(use-package olivetti
  :ensure t
  :bind (("C-c t o" . olivetti-mode))
  :config
  (setq olivetti-style 'fancy
        olivetti-margin-width 100
        olivetti-body-width 94)
  (olivetti-set-width 94))

(defun set-mode-line-faces ()
  (ignore-errors
    (set-face-attribute 'mode-line nil
                        :box `(:line-width 3 :color ,(face-attribute 'mode-line :background))
                        :height 0.7
                        :font heks/font-sans))
  (ignore-errors
    (set-face-attribute 'mode-line-active nil
                        :box `(:line-width 3 :color ,(face-attribute 'mode-line :background))
                        :height 0.7
                        :font heks/font-sans))
  (ignore-errors
    (set-face-attribute 'mode-line-inactive nil
                        :box `(:line-width 3 :color ,(face-attribute 'mode-line-inactive :background))
                        :height 0.7
                        :font heks/font-sans)))

(defun heks/set-face (face &rest attributes)
  "Set ATTRIBUTES on FACE, but only when FACE actually exists.

Faces that belong to a library which has not been loaded yet are simply
skipped; they are configured later through the `with-eval-after-load'
calls below."
  (when (facep face)
    (apply #'set-face-attribute face nil attributes)))

;;
;; ====== Separators between windows ======
;;
;; Emacs draws the line between two side-by-side windows with the
;; `window-divider' (or, when `window-divider-mode' is off, the
;; `vertical-border') face.  Most themes leave those faces as the
;; background color, which makes multiple buffers in a single frame
;; impossible to tell apart.  The color is derived from the active
;; theme instead of being hard-coded per palette, so separators stay
;; visible whatever theme is selected.
;;

(defun heks/window-color (attribute fallback)
  "Return the color currently used for ATTRIBUTE, or FALLBACK.

ATTRIBUTE is a `default' face attribute such as :background.  The
frame's own color is used when the face does not specify one."
  (let ((face-color (ignore-errors (face-attribute 'default attribute nil t)))
        (frame-color (ignore-errors
                       (frame-parameter nil
                                        (if (eq attribute :background)
                                            'background-color
                                          'foreground-color)))))
    (cond ((and (stringp face-color)
                (not (string-prefix-p "unspecified" face-color)))
           face-color)
          ((and (stringp frame-color)
                (not (string-prefix-p "unspecified" frame-color)))
           frame-color)
          (t fallback))))

(defun heks/color-components (color)
  "Return COLOR as a list of three 16-bit integers, or nil when unknown.

Hex colors are parsed here rather than through `color-values' because on
a text terminal that function snaps colors to the terminal's palette,
which would make the separator color unpredictable."
  (cond
   ((not (stringp color)) nil)
   ((string-match "\\`#\\([0-9a-fA-F]\\{12\\}\\)\\'" color)
    (let ((n (string-to-number (match-string 1 color) 16)))
      (list (ash n -32) (logand (ash n -16) #xffff) (logand n #xffff))))
   ((string-match "\\`#\\([0-9a-fA-F]\\{6\\}\\)\\'" color)
    (let ((n (string-to-number (match-string 1 color) 16)))
      (list (* #x101 (logand (ash n -16) #xff))
            (* #x101 (logand (ash n -8) #xff))
            (* #x101 (logand n #xff)))))
   ((string-match "\\`#\\([0-9a-fA-F]\\{3\\}\\)\\'" color)
    (let ((n (string-to-number (match-string 1 color) 16)))
      (list (* #x1111 (logand (ash n -8) #xf))
            (* #x1111 (logand (ash n -4) #xf))
            (* #x1111 (logand n #xf)))))
   (t (ignore-errors (color-values color)))))

(defun heks/blend-colors (first second weight)
  "Blend FIRST and SECOND, WEIGHT being the pull toward SECOND.

WEIGHT is clamped to the 0.0-1.0 range.  Colors are accepted in any
Emacs color format and a 16-bit hex string is returned."
  (let ((one (heks/color-components first))
        (two (heks/color-components second))
        (weight (max 0.0 (min 1.0 (float weight)))))
    (if (and one two)
        (format "#%04x%04x%04x"
                (round (+ (* (nth 0 one) (- 1.0 weight)) (* (nth 0 two) weight)))
                (round (+ (* (nth 1 one) (- 1.0 weight)) (* (nth 1 two) weight)))
                (round (+ (* (nth 2 one) (- 1.0 weight)) (* (nth 2 two) weight))))
      second)))

(defun heks/divider-color-for (themes)
  "Return the first explicit separator color listed for THEMES."
  (seq-some (lambda (theme) (alist-get theme heks/window-divider-colors))
            themes))

(defun heks/window-divider-color ()
  "Return the color used to draw the separators between windows.

Themes listed in `heks/window-divider-colors' win.  The
configured `heks/theme' is consulted first, then whichever theme
is actually enabled -- switching theme at runtime must not leave the
separators painted with a color belonging to the previous one.  Every
other theme gets a blend of its own background and foreground, so the
separator always stands out."
  (or (heks/divider-color-for
       (cons heks/theme custom-enabled-themes))
      (heks/blend-colors
       (heks/window-color :background "#000000")
       (heks/window-color :foreground "#ffffff")
       heks/window-divider-contrast)))

(defun heks/set-window-divider-faces (&rest _)
  "Give the separators between windows a clearly visible color.

Covers `window-divider' (used when `window-divider-mode' is enabled),
its first/last pixel companions and `vertical-border' (used when it is
not), so both split directions stay readable in every theme.  Themes
that paint separators invisible -- `spacious-padding' does that on
purpose -- are corrected as well, since face settings coming from an
enabled theme take precedence over `set-face-attribute'."
  (interactive)
  (ignore-errors
    (let* ((color (heks/window-divider-color))
           (spec (list (list t (list :foreground color :background color)))))
      ;; Both attributes are set: `vertical-border' is drawn with its
      ;; foreground, whereas the `window-divider' pixels use the
      ;; background, so one color has to cover both.
      (dolist (face '(window-divider
                      window-divider-first-pixel
                      window-divider-last-pixel
                      vertical-border))
        (set-face-attribute face nil :foreground color :background color)
        (when (memq 'spacious-padding custom-enabled-themes)
          (custom-theme-set-faces 'spacious-padding (list face spec)))))))

;;
;; ====== Text scale and the faces derived from it ======
;;
;; Everything below is defined at file level on purpose.  Org, Markdown
;; and the theme hooks call these functions, and they have to exist even
;; while `tekengrootte' itself is still being installed or loaded.
;;

(defvar heks/is-first-frame t
  "Non-nil until the first frame got its HEKS-EMACS UI scaling.")

(defun heks/font-height (mult)
  "Return an absolute face height for MULT times the current base size.

The base size is `heks/base-font-size' scaled by
`tekengrootte-scale'.  Because the result is absolute (tenths of a
point), faces sized with it never compound with `default' or with a
buffer face such as `variable-pitch'."
  (round (* 10 heks/base-font-size
            (if (boundp 'tekengrootte-scale) tekengrootte-scale 1.0)
            mult)))

(defun heks/set-org-faces ()
  "Size and fontify the Org faces relative to the base size.

The multipliers here are plain ratios of the base size: they are
deliberately NOT scaled by `tekengrootte-scale', so changing the global
text scale keeps the typographic hierarchy between body text, headings
and code blocks intact."
  (interactive)
  (when (facep 'org-level-1)
    (heks/set-face 'org-table :height 0.92 :font heks/font-mono)
    (heks/set-face 'org-block :font heks/font-mono :height 0.9)
    (heks/set-face 'org-block-end-line :font heks/font-mono :height 0.9)
    (heks/set-face 'org-block-begin-line :font heks/font-mono :height 0.9)
    (heks/set-face 'org-code :font heks/font-mono :height 0.85)
    (heks/set-face 'org-verbatim :font heks/font-mono :height 1.0)
    (heks/set-face 'org-document-title :font heks/font-sans :weight 'bold :height 1.5)
    (heks/set-face 'org-document-info :font heks/font-sans :height 1.05)
    (heks/set-face 'org-document-info-keyword :inherit '(font-lock-comment-face))
    (heks/set-face 'org-quote :font heks/font-serif :slant 'italic)
    (heks/set-face 'org-verse :font heks/font-serif :slant 'italic)
    (heks/set-face 'org-level-1 :font heks/font-sans :weight 'bold :height 1.35)
    (heks/set-face 'org-level-2 :font heks/font-sans :weight 'bold :height 1.22)
    (heks/set-face 'org-level-3 :font heks/font-sans :weight 'bold :height 1.12)
    (heks/set-face 'org-level-4 :font heks/font-sans :weight 'bold :height 1.06)
    (heks/set-face 'org-level-5 :font heks/font-sans :weight 'bold :height 1.0)
    (heks/set-face 'org-level-6 :font heks/font-sans :weight 'bold :height 0.98)
    (heks/set-face 'org-level-7 :font heks/font-sans :weight 'bold :height 0.96)
    (heks/set-face 'org-level-8 :font heks/font-sans :weight 'bold :height 0.94)))

(defun heks/set-markdown-faces ()
  "Size and fontify the Markdown faces relative to the base size.

Covers both the built-in `markdown-ts-mode' (Emacs 31+) and the
third-party `markdown-mode', with the same multipliers as Org so that
the two modes look consistent.  Libraries that are not loaded yet are
configured later, from the `with-eval-after-load' calls below."
  (interactive)
  ;; --- markdown-ts-mode (built-in) ---
  (when (facep 'markdown-ts-heading-1)
    (heks/set-face 'markdown-ts-heading-1 :font heks/font-sans :weight 'bold :height 1.35)
    (heks/set-face 'markdown-ts-heading-2 :font heks/font-sans :weight 'bold :height 1.22)
    (heks/set-face 'markdown-ts-heading-3 :font heks/font-sans :weight 'bold :height 1.12)
    (heks/set-face 'markdown-ts-heading-4 :font heks/font-sans :weight 'bold :height 1.06)
    (heks/set-face 'markdown-ts-heading-5 :font heks/font-sans :weight 'bold :height 1.0)
    (heks/set-face 'markdown-ts-heading-6 :font heks/font-sans :weight 'bold :height 0.98)
    (heks/set-face 'markdown-ts-setext-heading :font heks/font-sans :weight 'bold :height 1.35)
    (heks/set-face 'markdown-ts-code-block :font heks/font-mono :height 1.0)
    (heks/set-face 'markdown-ts-indented-code-block :font heks/font-mono :height 1.0)
    (heks/set-face 'markdown-ts-code-span :font heks/font-mono :height 1.0)
    (heks/set-face 'markdown-ts-block-quote :font heks/font-serif :slant 'italic))
  ;; --- markdown-mode (third-party) ---
  (when (facep 'markdown-header-face-1)
    (heks/set-face 'markdown-header-face-1 :font heks/font-sans :weight 'bold :height 1.35)
    (heks/set-face 'markdown-header-face-2 :font heks/font-sans :weight 'bold :height 1.22)
    (heks/set-face 'markdown-header-face-3 :font heks/font-sans :weight 'bold :height 1.12)
    (heks/set-face 'markdown-header-face-4 :font heks/font-sans :weight 'bold :height 1.06)
    (heks/set-face 'markdown-header-face-5 :font heks/font-sans :weight 'bold :height 1.0)
    (heks/set-face 'markdown-header-face-6 :font heks/font-sans :weight 'bold :height 0.98)
    ;; Monospace at 1.0: a smaller mono looks tiny next to the sans body.
    ;; The faces below are the ones markdown-mode shrinks or leaves in
    ;; the fixed-pitch default (tables, fences, list markers, metadata).
    (dolist (face '(markdown-pre-face markdown-code-face
                    markdown-inline-code-face markdown-table-face
                    markdown-language-keyword-face
                    markdown-language-info-face
                    markdown-markup-face markdown-list-face
                    markdown-metadata-key-face
                    markdown-metadata-value-face
                    markdown-url-face markdown-link-url-face))
      (when (facep face)
        (heks/set-face face :height 1.0)))
    (dolist (face '(markdown-pre-face markdown-code-face
                    markdown-inline-code-face markdown-table-face
                    markdown-language-keyword-face))
      (when (facep face)
        (heks/set-face face :font heks/font-mono)))
    (heks/set-face 'markdown-blockquote-face :font heks/font-serif :slant 'italic)))

;;
;; ====== ECA faces ======
;;
;; The chat ECA opens is prose that quotes code, so its faces are split by
;; what they print rather than by which file of the package defines them.
;; What names something -- the title of a chat, the label of a tool call, a
;; status, a task, a question, an action -- is read, so it takes the
;; sans-serif family; what a reader copies out of the buffer -- a command, a
;; path, a key, a tool call's arguments, the columns of a table -- stays
;; monospace, which is also the family such a chip needs to line up with the
;; code around it.  The body of a message is not in either list: it is
;; `default', and the code in it is the monospace faces configured above.
;;

(defconst heks/eca-sans-faces
  '(;; The chat and its chrome: the title, the welcome, the tabs and the
    ;; options in the header line.
    eca-chat-title-face
    eca-chat-welcome-face
    eca-chat-resume-link-face
    eca-chat-load-more-face
    eca-chat-option-value-face
    eca-chat-trust-on-face
    eca-chat-trust-off-face
    eca-chat-usage-string-face
    eca-chat-approval-modeline-face
    eca-chat-command-description-face
    eca-chat-elapsed-time-face
    eca-chat-time-face
    eca-tab-inactive-face
    eca-chat-tab-active-face
    eca-chat-tab-inactive-active-face
    ;; A message, and the labels that say what the chat is doing with it.
    eca-chat-user-messages-face
    eca-chat-rollback-face
    eca-chat-system-messages-face
    eca-chat-reason-label-face
    eca-chat-hook-label-face
    eca-chat-subagent-steps-info-face
    eca-chat-file-change-label-face
    eca-chat-diff-view-face
    eca-chat-flag-face
    eca-chat-prompt-prefix-face
    eca-chat-prompt-stop-face
    eca-chat-queued-prompt-face
    eca-chat-steer-prompt-face
    ;; A tool call: the request for approval and the three answers to it.
    eca-chat-tool-call-approval-content-face
    eca-chat-tool-call-accept-face
    eca-chat-tool-call-accept-and-remember-face
    eca-chat-tool-call-reject-face
    ;; The task area.
    eca-chat-task-prefix-face
    eca-chat-task-label-face
    eca-chat-task-label-in-progress-face
    eca-chat-task-in-progress-face
    eca-chat-task-progress-face
    eca-chat-task-done-face
    ;; A question the chat asks, and the answers it offers.
    eca-chat-question-face
    eca-chat-question-option-face
    eca-chat-question-description-face
    ;; The context bar, whose segments are read as one sentence.
    eca-chat-context-system-prompt-face
    eca-chat-context-tool-definitions-face
    eca-chat-context-conversation-face
    eca-chat-context-rules-face
    eca-chat-context-skills-face
    eca-chat-context-agents-face
    eca-chat-context-tool-calls-face
    eca-chat-context-free-face
    eca-chat-context-compaction-marker-face
    ;; The buffers that sit beside a chat: settings, providers, jobs, MCP
    ;; servers, workspaces, quota, and the inline and rewrite headers.
    eca-settings-heading
    eca-providers-authenticated-face
    eca-providers-local-face
    eca-providers-unauthenticated-face
    eca-providers-model-face
    eca-providers-auth-info-face
    eca-providers-section-face
    eca-providers-button-face
    eca-providers-button-logout-face
    eca-jobs-status-running-face
    eca-jobs-status-completed-face
    eca-jobs-status-failed-face
    eca-jobs-status-killed-face
    eca-jobs-chat-separator-face
    eca-jobs-button-output-face
    eca-jobs-button-kill-face
    eca-mcp-details-requires-auth-face
    eca-mcp-details-button-face
    eca-mcp-details-button-stop-face
    eca-mcp-details-button-logout-face
    eca-mcp-details-button-disable-face
    eca-mcp-details-button-enable-face
    eca-workspaces-tree-chat-idle-face
    eca-workspaces-tree-chat-loading-face
    eca-workspaces-tree-chat-details-face
    eca-quota-warning-face
    eca-quota-critical-face
    eca-chat-inline-in-progress-face
    eca-chat-inline-ready-face
    eca-table-action-bar-face
    eca-chat-inline-anchor-face
    eca-chat-inline-answer-face
    eca-chat-mcp-tool-call-label-face
    eca-chat-subagent-tool-call-label-face
    eca-chat-tool-call-keybinding-face
    eca-chat-option-key-face
    eca-chat-shell-command-breakdown-prefix-face
    eca-chat-context-unlinked-face
    eca-chat-context-file-face
    eca-chat-context-repo-map-face
    eca-chat-context-mcp-resource-face
    eca-chat-context-cursor-face
    eca-chat-context-cursor-unsaved-face
    eca-chat-context-buffer-face
    eca-mcp-details-tool-face
    eca-mcp-details-tool-disabled-face
    eca-doom-workspace-tab-attention-face
    eca-doom-workspace-tab-running-face
    eca-rewrite-in-progress-prefix-face
    eca-rewrite-ready-prefix-face
    eca-rewrite-model-face)
  "The ECA faces whose text is read rather than copied.

`heks/set-eca-faces' gives them `heks/font-sans', so that a
chat reads as prose and not as the code it is talking about.")

(defconst heks/eca-mono-faces
  '(;; Something a reader copies out of the buffer, and the identifiers and
    ;; the tables that only line up in a family of one width.
    eca-chat-file-path-face
    eca-chat--tool-call-table-key-face
    eca-chat--tool-call-argument-key-face
    eca-chat--tool-call-argument-value-face
    eca-chat-inline-key-face
    eca-chat-shell-command-face
    eca-chat-shell-command-remembered-face
    eca-chat-shell-command-not-remembered-face
    eca-chat-shell-command-always-asks-face
    eca-table-header-face
    eca-table-separator-face
    eca-table-pipe-face
    eca-table-row-even-face
    eca-table-action-key-face
    eca-mcp-details-command-value-face
    eca-rewrite-overlay-face
    eca-rewrite-overlay-hover-face
    eca-completion-overlay-face)
  "The ECA faces that print something a reader takes out of the buffer.

`heks/set-eca-faces' gives them `heks/font-mono', which is the
family `default' already has.  Saying it here is what keeps them monospace
should the buffer they are drawn in ever stop being so.")

(defun heks/set-eca-faces ()
  "Give each ECA face the family of what it prints.

The faces of `heks/eca-sans-faces' are the ones whose text is a
sentence, a label or a status, and take `heks/font-sans'; the ones of
`heks/eca-mono-faces' print something a reader copies, and take
`heks/font-mono'.  A face of the package this Emacs does not have yet
is skipped, so calling this before ECA is loaded costs nothing -- which is
why `heks/set-base-faces' can call it on every theme change and the
`with-eval-after-load' below repeats it once the package is there."
  (interactive)
  (dolist (face heks/eca-sans-faces)
    (heks/set-face face :font heks/font-sans))
  (dolist (face heks/eca-mono-faces)
    (heks/set-face face :font heks/font-mono)))

(defun heks/set-base-faces ()
  "Adjust the base Emacs faces to my preferences.

Only the base size (`default', `fixed-pitch') follows
`tekengrootte-scale'; every other face is a plain multiple of it, so
prose, Org, Markdown and ECA keep their proportions at any scale."
  (interactive)
  (set-face-attribute 'default nil
                      :height (heks/font-height 1.0)
                      :font heks/font-mono)

  (set-face-attribute 'fixed-pitch nil
                      :height (heks/font-height 1.0)
                      :font heks/font-mono)

  ;; Prose keeps the base size and only swaps family, which keeps the
  ;; heading multipliers below exact multiples of the body text.
  (set-face-attribute 'variable-pitch nil
                      :font heks/font-sans
                      :height heks/prose-scale)

  (set-face-attribute 'button nil :background 'unspecified
                      :weight 'bold)

  (set-mode-line-faces)

  (ignore-errors
    (set-face-attribute 'font-lock-comment-face nil
                        :italic t)
    (set-face-attribute 'font-lock-doc-face nil
                        :foreground (ef-themes-get-color-value 'yellow-faint)))

  (heks/set-org-faces)

  ;; The fold indicators are the theme's own grey blended toward its
  ;; background, so a new theme has to blend it again.
  (heks/fold-indicator-faces)

  (heks/set-markdown-faces)

  (heks/set-eca-faces)

  (ignore-errors
    (set-face-attribute 'keycast-key nil
                        :font heks/font-mono
                        :background 'unspecified
                        :box nil
                        :height 0.8)
    (set-face-attribute 'keycast-command nil
                        :font heks/font-sans
                        :height 0.8))

  ;;
  ;; ====== Theme specific tweaks ======
  ;;

  ;; ====== Catppuccin specific tweaks
  (when (string-prefix-p "catppuccin-mocha" (format "%s" heks/theme))
    (ignore-errors
      (set-face-attribute 'mode-line-active nil
                          :background (catppuccin-color 'crust))
      (set-face-attribute 'mode-line-inactive nil
                          :background (catppuccin-color 'base))))

  ;; ======= Gruvbox specific tweaks ===========

  (when (memq heks/theme '(gruvbox-light gruvbox-light-hard))
    (ignore-errors
      (set-face-attribute 'internal-border nil
                          :background "#f9f5d7")))

  (when (memq heks/theme '(gruvbox-dark gruvbox-dark-hard))
    (ignore-errors
      (set-face-attribute 'internal-border nil
                          :background "#1d2021")))

  ;; ====== Dracula specific tweaks ======
  (when (equal heks/theme 'dracula)
    (ignore-errors
      (set-face-attribute 'font-lock-variable-use-face nil
                          :bold nil)
      (set-face-attribute 'font-lock-variable-name-face nil
                          :bold nil)
      (set-face-attribute 'mode-line nil
                          :box `(:line-width 3 :color "#44475a")
                          :background "#44475a")
      (set-face-attribute 'mode-line-active nil
                          :box `(:line-width 3 :color "#44475a")
                          :background "#44475a")
      (set-face-attribute 'mode-line-inactive nil
                          :box `(:line-width 3 :color "#282a36")
                          :background "#282a36")))

  ;; ====== Everforest dark specific tweaks ======
  (ignore-errors
    (cond ((memq heks/theme '(everforest-dark everforest-hard-dark))
           (progn
             (set-face-attribute 'mode-line nil
                                 :box 'unspecified
                                 :foreground "#2b3339"
                                 :background "#96b070")
             (set-face-attribute 'mode-line-active nil
                                 :box 'unspecified
                                 :foreground "#2b3339"
                                 :background "#96b070")
             (set-face-attribute 'dired-directory nil
                                 :inherit '(font-lock-string-face))))))

  ;; ====== Everforest light specific tweaks ======
  (ignore-errors
    (cond ((memq heks/theme '(everforest-light everforest-hard-light))
           (progn
             (set-face-attribute 'mode-line nil
                                 :box 'unspecified
                                 :foreground "#2b3339"
                                 :background "#96b070")
             (set-face-attribute 'mode-line-active nil
                                 :box 'unspecified
                                 :foreground "#2b3339"
                                 :background "#96b070")
             (set-face-attribute 'dired-directory nil
                                 :inherit '(font-lock-string-face))))))

  ;; Keep the separators visible last, so no theme override wins over them.
  (heks/set-window-divider-faces))

(defun heks/refresh-faces (&rest _)
  "Re-apply the HEKS-EMACS faces and the window separator colors.

Registered on `tekengrootte-set-scale-hook' and on
`enable-theme-functions', so a new text scale or a new theme is always
reflected in the UI."
  (interactive)
  (heks/set-base-faces)
  (heks/set-window-divider-faces))

(defun new-frame-setup ()
  "Scale the UI on the first frame and re-apply the faces on every frame."
  (when heks/is-first-frame
    (message "initializing HEKS-EMACS UI scaling for first frame")
    (tekengrootte-set-scale-regular)
    (setq heks/is-first-frame nil))
  (heks/set-base-faces))

(use-package tekengrootte
  :ensure (:host codeberg :repo "jjba23/tekengrootte.el" :branch "trunk")
  :demand t
  :bind (("C-c f c" . tekengrootte-set-scale-colossal)
         ("C-c f j" . tekengrootte-set-scale-jumbo)
         ;; The ladder reads `n' nano, `t' tiny, `s' small, `r' regular,
         ;; `l' large, `L' larger, `j' jumbo, `c' colossal: the capital is
         ;; the next step up, which is what it means everywhere else in
         ;; this configuration.
         ("C-c f L" . tekengrootte-set-scale-larger)
         ("C-c f l" . tekengrootte-set-scale-large)
         ("C-c f r" . tekengrootte-set-scale-regular)
         ("C-c f s" . tekengrootte-set-scale-small)
         ("C-c f t" . tekengrootte-set-scale-tiny)
         ("C-c f n" . tekengrootte-set-scale-nano))
  :hook ((tekengrootte-set-scale . heks/refresh-faces))
  :config
  ;;
  ;; ====== Separators between windows ======
  ;;

  (setq window-divider-default-places heks/window-divider-places
        window-divider-default-right-width 2
        window-divider-default-bottom-width 1)
  (window-divider-mode 1)
  (heks/set-window-divider-faces)

  ;; Start from the "regular" scale so plain sessions and daemon sessions
  ;; (with frames created later by emacsclient) agree on the initial size.
  (setq tekengrootte-scale (alist-get 'regular tekengrootte-sizes))

  ;; Apply the faces right away: without a server frame, the
  ;; `server-after-make-frame-hook' below never runs.
  (heks/set-base-faces)

  ;; Depth 10 puts `new-frame-setup' after the other frame functions, which
  ;; matters because `spacious-padding' (see below) repaints the divider
  ;; faces with the background color on every new frame.
  (add-hook 'server-after-make-frame-hook 'new-frame-setup 10)
  (add-hook 'server-after-make-frame-hook #'my-set-custom-modeline)

  ;; Switching themes must not leave separators invisible or faces stale.
  (add-hook 'enable-theme-functions #'heks/refresh-faces))

;; Org and Markdown faces only exist once their libraries are loaded, so
;; configure them again at that point (and never mind that this may run
;; several times; the operations are idempotent).
(with-eval-after-load 'org
  (heks/set-org-faces))

(with-eval-after-load 'markdown-ts-mode
  (heks/set-markdown-faces))

(with-eval-after-load 'markdown-mode
  (heks/set-markdown-faces))

;; ECA's faces are made when the package is loaded, which is after this
;; module has run, so they are given their family once they exist.
(with-eval-after-load 'eca
  (heks/set-eca-faces))

(use-package nerd-icons
  :ensure t
  :config
  (add-to-list 'nerd-icons-regexp-icon-alist
               '("^[Jj]ustfile$" nerd-icons-faicon "nf-fa-wrench"))
  (add-to-list 'nerd-icons-regexp-icon-alist
               '("^settings-gradle\\.lockfile$" nerd-icons-faicon "nf-fa-lock"))
  (add-to-list 'nerd-icons-regexp-icon-alist
               '("^gradle\\.lockfile$" nerd-icons-faicon "nf-fa-lock"))
  (add-to-list 'nerd-icons-regexp-icon-alist
               '("^pom\\.xml$" nerd-icons-devicon "nf-dev-maven"))
  (add-to-list 'nerd-icons-regexp-icon-alist
               '("^build\\.gradle\\(\\.kts\\)?$" nerd-icons-devicon "nf-dev-gradle"))
  (add-to-list 'nerd-icons-regexp-icon-alist
               '("\\.tf\\(vars\\)?$" nerd-icons-devicon "nf-dev-terraform"))
  (add-to-list 'nerd-icons-regexp-icon-alist
               '("\\.mongo\\(sh\\)?$" nerd-icons-devicon "nf-dev-mongodb"))
  (add-to-list 'nerd-icons-regexp-icon-alist
               '("\\.sql$" nerd-icons-faicon "nf-fa-database"))
  (add-to-list 'nerd-icons-regexp-icon-alist
               '("^[Cc][Oo][Dd][Ee][Oo][Ww][Nn][Ee][Rr][Ss]$" nerd-icons-faicon "nf-fa-users")))

(use-package nerd-icons-completion
  :ensure t
  :after (nerd-icons marginalia)
  :hook ((marginalia-mode . nerd-icons-completion-marginalia-setup))
  :config (nerd-icons-completion-mode))

(use-package spacious-padding
  :ensure (:host github :repo "protesilaos/spacious-padding" :branch "main")
  :init
  (setq spacious-padding-widths
        '( :internal-border-width 18
           :header-line-width 2
           :mode-line-width 2
           :tab-width 4
           :right-divider-width 2
           :scroll-bar-width 8
           :left-fringe-width 16
           :right-fringe-width 16))
  (setq spacious-padding-subtle-mode-line nil)
  :config
  (spacious-padding-mode)
  (set-face-attribute 'internal-border nil :background 'unspecified :inherit 'default))

;; `spacious-padding' replaces the lines between windows with padding and
;; therefore deliberately paints `window-divider', `vertical-border' and
;; their companions with the background color -- which is exactly why
;; several buffers in one frame used to be indistinguishable.  HEKS-EMACS
;; wants those separators to be visible, so apply them once more *after*
;; spacious-padding had its say: now, when `window-divider-mode' is
;; toggled and on every theme change.  DEPTH 10 places these hooks after
;; the ones registered by spacious-padding.
(heks/set-window-divider-faces)
(add-hook 'enable-theme-functions #'heks/set-window-divider-faces 10)
(add-hook 'window-divider-mode-hook #'heks/set-window-divider-faces 10)
(add-hook 'after-make-frame-functions #'heks/set-window-divider-faces 10)

(use-package svg-lib
  :ensure (:host github :repo "rougier/svg-lib" :branch "master"))

(use-package kind-icon
  :ensure (:host github :repo "jdtsmith/kind-icon" :branch "main")
  :after corfu
  :config
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))



(use-package keycast
  :ensure t
  :after (tekengrootte)
  :config
  (define-minor-mode keycast-mode
    "Show current command and its key binding in the mode line."
    :global t
    (if keycast-mode
        (add-hook 'pre-command-hook 'keycast--update t)
      (remove-hook 'pre-command-hook 'keycast--update)))
  (ignore-errors (keycast-mode)))


(use-package vertico
  :ensure t
  :init
  (setq vertico-cycle t
        vertico-resize t)
  :after (compat)
  :config
  (vertico-mode))

(use-package marginalia
  :ensure t
  :after (vertico compat)
  :config (marginalia-mode))


(use-package ultra-scroll
  :ensure (:host github :repo "jdtsmith/ultra-scroll" :branch "main")
  :init
  (setq scroll-conservatively 101 ; important!
        scroll-margin 0)
  :config
  (ultra-scroll-mode 1))

(use-package embark
  :ensure (:host github :repo "oantolin/embark" :branch "master")
  :bind
  (("C-." . embark-act)         ;; pick some comfortable binding
   ("C-;" . embark-dwim)        ;; good alternative: M-.
   ("C-h B" . embark-bindings)) ;; alternative for `describe-bindings'
  :init
  ;; Optionally replace the key help with a completing-read interface
  (setq prefix-help-command #'embark-prefix-help-command)

  ;; Add Embark to the mouse context menu. Also enable `context-menu-mode'.
  (context-menu-mode 1)
  (add-hook 'context-menu-functions #'embark-context-menu 100)
  :config
  ;; Hide the mode line of the Embark live/completions buffers
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none)))))

(use-package embark-consult
  :ensure (:host github :repo "oantolin/embark" :branch "master")
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

(use-package ligature
  :ensure t
  :config
  (ligature-set-ligatures
   'prog-mode
   '("|||>" "<|||" "<==>" "<!--" "####" "~~>" "***" "||=" "||>"
     ":::" "::=" "=:=" "===" "==>" "=!=" "=>>" "=<<" "=/=" "!=="
     "!!." ">=>" ">>=" ">>>" ">>-" ">->" "->>" "-->" "---" "-<<"
     "<~~" "<~>" "<*>" "<||" "<|>" "<$>" "<==" "<=>" "<=<" "<->"
     "<--" "<-<" "<<=" "<<-" "<<<" "<+>" "</>" "###" "#_(" "..<"
     "..." "+++" "/==" "///" "_|_" "www" "&&" "^=" "~~" "~@" "~="
     "~>" "~-" "**" "*>" "*/" "||" "|}" "|]" "|=" "|>" "|-" "{|"
     "[|" "]#" "::" ":=" ":>" ":<" "$>" "==" "=>" "!=" "!!" ">:"
     ">=" ">>" ">-" "-~" "-|" "->" "--" "-<" "<~" "<*" "<|" "<:"
     "<$" "<=" "<>" "<-" "<<" "<+" "</" "#{" "#[" "#:" "#=" "#!"
     "##" "#(" "#?" "#_" "%%" ".=" ".-" ".." ".?" "+>" "++" "?:"
     "?=" "?." "??" ";;" "/*" "/=" "/>" "//" "__" "~~" "(*" "*)"
     "\\\\" "://" "www"))
  (global-ligature-mode t))

(provide 'heks/ui)

;;; ui.el ends here
