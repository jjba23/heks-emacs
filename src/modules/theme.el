;;; theme.el --- Themes and look/feel for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Themes and look/feel for Emacs UI/UX/DX

;;; Code:

(use-package ef-themes
  :ensure (:host github :repo "protesilaos/ef-themes" :branch "main")
  :if (and heks/theme
           (string-match-p "\\`\\(ef-\\|modus-\\)" (symbol-name heks/theme)))
  :config
  (setq modus-themes-mixed-fonts t
        modus-themes-italic-constructs t)
  (modus-themes-include-derivatives-mode 1)

  ;; Handle theme-specific overrides dynamically
  (pcase heks/theme
    ;; The light operandi palettes paint a comment `red-faint', and a comment
    ;; that shouts belongs to neither the prose nor the code around it; it is
    ;; given the theme's own grey, the `fg-dim' the untinted palette uses.
    ('modus-operandi
     (setq modus-operandi-palette-overrides '((comment fg-dim))))
    ('modus-operandi-tinted
     (setq modus-operandi-tinted-palette-overrides '((comment fg-dim))))
    ('modus-vivendi-tinted
     (setq modus-vivendi-tinted-palette-overrides '((comment "#928f8a"))))
    ('ef-bio
     (setq ef-bio-palette-overrides '((variable fg-main) (string green-faint))))
    ('ef-cyprus
     (setq ef-cyprus-palette-overrides '((variable fg-main) (bg-main bg-dim) (string green-faint))))
    ('ef-melissa-light
     (setq ef-melissa-light-palette-overrides '((variable fg-main) (string green-warmer))))
    ('ef-autumn
     (setq ef-autumn-palette-overrides '((variable fg-main) (bg-main bg-dim)))))

  (load-theme heks/theme t)

  ;; A directory is `accent-0' in the Modus palettes, and in the light ones
  ;; that is a red.  Dired draws a folder in `dired-directory' and, through
  ;; `nerd-icons-dired', in `nerd-icons-dired-dir-face', so both are given a
  ;; pink instead; reading the palette rather than writing a hex keeps them
  ;; with the theme if `magenta-warmer' is ever overridden.
  (when (memq heks/theme '(modus-operandi modus-operandi-tinted))
    (let ((folder (modus-themes-get-color-value 'magenta-warmer)))
      (custom-theme-set-faces
       heks/theme
       `(dired-directory ((t :foreground ,folder)))
       `(nerd-icons-dired-dir-face ((t :foreground ,folder)))))))

(use-package everforest
  :ensure (:host github :repo "Theory-of-Everything/everforest-emacs" :branch "master2")
  :no-require t
  :if (memq heks/theme '(everforest-dark everforest-light))
  :config
  (load-theme (if (eq heks/theme 'everforest-dark)
                  'everforest-hard-dark
                'everforest-hard-light)
              t))

(use-package gruvbox-theme
  :ensure (:host github :repo "greduan/emacs-theme-gruvbox" :branch "master")
  :if (memq heks/theme '(gruvbox-dark gruvbox-light))
  :config
  (load-theme (if (eq heks/theme 'gruvbox-dark)
                  'gruvbox-dark-hard
                'gruvbox-light-hard)
              t))

(use-package dracula-theme
  :ensure t
  :if (eq heks/theme 'dracula)
  :config
  (load-theme heks/theme t)
  (setq dracula-enlarge-headings t
        dracula-height-title-1 1.25
        dracula-height-title-2 1.15
        dracula-height-title-3 1.05
        dracula-height-doc-title 1.4
        dracula-alternate-mode-line-and-minibuffer nil))

(use-package catppuccin-theme
  :ensure t
  :if (memq heks/theme '(catppuccin-latte catppuccin-mocha))
  :config
  (setq catppuccin-italic-comments t)
  (setopt catppuccin-flavor (if (eq heks/theme 'catppuccin-latte) 'latte 'mocha))
  (load-theme 'catppuccin t))

(use-package autothemer :ensure t)

(use-package rose-pine
  :ensure (:host github :repo "thongpv87/rose-pine-emacs" :branch "master" :main "rose-pine-color-theme.el")
  :after (autothemer)
  :no-require t
  :if (memq heks/theme '(rose-pine-moon rose-pine-dawn))
  :config
  (load-theme heks/theme t))

(use-package kaolin-themes
  :ensure t
  :if (eq heks/theme 'kaolin-dark)
  :config
  (setq kaolin-themes-bold t
        kaolin-themes-italic t
        kaolin-themes-underline t
        kaolin-themes-modeline-border nil
        kaolin-themes-underline-wave nil
        kaolin-themes-distinct-metakeys nil
        kaolin-themes-italic-comments t
        kaolin-themes-hl-line-colored t
        kaolin-themes-distinct-fringe t
        kaolin-themes-git-gutter-solid t)
  (load-theme 'kaolin-dark t))

(use-package ayu-theme
  :ensure t
  :if (memq heks/theme '(ayu-dark ayu-light ayu-mirage ayu-grey))
  :config
  (if (eq heks/theme 'ayu-mirage)
      (load-theme 'ayu-grey t)
    (load-theme heks/theme t))
  (set-face-attribute 'font-lock-string-face nil
                      :italic nil)
  (set-face-attribute 'font-lock-doc-face nil
                      :inherit 'font-lock-comment-face
                      :italic t)
  (set-face-attribute 'dired-directory nil
                      :inherit 'font-lock-keyword-face)
  (if (eq heks/theme 'ayu-dark)
      (custom-theme-set-faces
       'ayu-dark
       '(cursor ((t (:background "#ffb07c"))))
       '(default ((t (:foreground "#d4d1cc" :background "#0f1419" ))))
       '(font-lock-comment-face ((t (:foreground "#8B92A0" :slant italic))))
       '(font-lock-comment-delimiter-face ((t (:inherit font-lock-comment-face))))
       '(font-lock-keyword-face ((t (:foreground "#ff9e64"))))
       '(font-lock-type-face ((t (:foreground "#e0af68"))))
       '(font-lock-function-name-face ((t (:foreground "#7aa2f7"))))
       '(font-lock-string-face ((t (:foreground "#A9B665"))))
       '(hl-line ((t (:background "#1d252a"))))
       '(mode-line ((t (:box (:line-width 1 :color "#3E4451")
                             :foreground "#ECEFF4"
                             :background "#282C34"))))
       '(mode-line-inactive ((t (:box (:line-width 1 :color "#181A1F")
                                      :foreground "#4B5263"
                                      :background "#0F1115")))))))

(use-package doom-themes
  :ensure t
  :if (memq heks/theme '(doom-tomorrow-night doom-one nord tokyo-night solarized-light solarized-dark doom-one-light doom-molokai))
  :custom
  (doom-themes-enable-bold t)
  (doom-themes-enable-italic t)
  :config
  ;; Dynamic mapping for mismatched theme names
  (let ((theme (pcase heks/theme
                 ('nord 'doom-nord)
                 ('tokyo-night 'doom-tokyo-night)
                 ('solarized-light 'doom-solarized-light)
                 ('solarized-dark 'doom-solarized-dark)
                 (_ heks/theme))))
    (load-theme theme t))

  (doom-themes-visual-bell-config)
  (doom-themes-neotree-config)
  (doom-themes-treemacs-config)
  (doom-themes-org-config))

(use-package kanagawa-theme
  :ensure (:host github :repo "arouene/emacs-kanagawa-theme" :branch "main")
  :if (memq heks/theme '(kanagawa))
  :config
  (load-theme 'kanagawa t))

;;
;; ====== Every palette, on one page ======
;;
;; Choosing a palette was a sequence: load a theme, look at the buffer,
;; load the next.  The renderer already turns a document into a page from
;; the colours of the current theme, so the comparison is the same
;; renderer run once per theme: one page, one frame per palette, and no
;; network anywhere in it.
;;
;; The sample is written in Markdown because the renderer reads it, and it
;; has one of each thing a palette can get wrong -- prose, bold, a link,
;; inline code, a list, a quote, a table and a fenced block.

(defconst heks/themes
  '(ef-autumn ef-bio ef-dream ef-day ef-kassio ef-melissa-light ef-cyprus
    modus-vivendi modus-operandi
    doom-solarized-light doom-solarized-dark kaolin-dark
    catppuccin
    dracula doom-tokyo-night
    everforest-hard-dark everforest-hard-light
    gruvbox-dark-hard gruvbox-light-hard
    kanagawa doom-nord rose-pine-moon rose-pine-dawn
    doom-one doom-one-light doom-tomorrow-night doom-molokai
    ayu-dark ayu-grey ayu-light)
  "The palettes this configuration offers, by the name Emacs loads.

This is the list the gallery renders and the names `load-theme' answers
to; `docs/themes.org' lists the same palettes under the names a person
sets `heks/theme' to, which are sometimes the package's own (the `nord'
of the documentation is `doom-nord' here, its palette).  A theme that is
not installed is skipped by the gallery rather than failing it, so this
list may name a palette a machine has not got.")

(defconst heks/theme-gallery-sample
  (concat "# A page in this palette\n\n"
          "A paragraph with **bold**, *italic*, `inline code` and a "
          "[link](https://example.org).\n\n"
          "- the first item\n"
          "- the second item\n\n"
          "> A quotation, which the palette should make quiet.\n\n"
          "| Column | Value |\n"
          "|--------+-------|\n"
          "| one | the first |\n"
          "| two | the second |\n\n"
          "```elisp\n"
          "(defun greet (name)\n"
          "  (message \"hello, %s\" name))\n"
          "```\n")
  "The one document the theme gallery renders in every palette.")

(defcustom heks/theme-gallery-file nil
  "Where `heks/theme-gallery' writes its page, or nil for the checkout.
Nil means `reports/themes.html' under this configuration's own directory,
which is what `maak themes' writes and what the command opens."
  :type '(choice (const :tag "the checkout's reports directory" nil)
                 (file :tag "a file of its own"))
  :group 'heks)

(defun heks/theme-gallery-target (&optional file)
  "Return the file the gallery is written to, FILE when it is given."
  (or file heks/theme-gallery-file
      (expand-file-name "reports/themes.html"
                        (or (and (boundp 'heks/clone-dir) heks/clone-dir)
                            default-directory))))

(defun heks/theme-gallery-html (entries &optional title)
  "Return one HTML page that shows each of ENTRIES in its own frame.

ENTRIES is a list of (NAME . DOCUMENT), where a document is the whole
page the renderer produces for the palette NAME.  Each one goes into an
`iframe' whose `srcdoc' is the document itself: a rendered page carries a
stylesheet for `body', so two of them cannot share one document without
one repainting the other.  Nothing is fetched, so the page opens from a
`file:' URL."
  (format "<!DOCTYPE html>
<html lang=\"en\">
<head>
<meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<title>%s</title>
<style>
:root { color-scheme: light dark; }
body { margin: 0; padding: 2rem; font-family: system-ui, sans-serif;
       background: #f4f4f4; color: #222; }
@media (prefers-color-scheme: dark) {
  body { background: #17181a; color: #e8e8e8; }
  iframe { border-color: #ffffff22 !important; }
}
header { max-width: 70rem; margin: 0 auto 2rem; }
h1 { margin: 0 0 0.4rem; font-size: 1.6rem; }
p { margin: 0; opacity: 0.75; }
nav { display: flex; flex-wrap: wrap; gap: 0.4rem; margin-top: 1rem; }
nav a { color: inherit; text-decoration: none; border: 1px solid currentColor;
        border-radius: 999px; padding: 0.15rem 0.6rem; font-size: 0.85rem;
        opacity: 0.8; }
section { max-width: 70rem; margin: 0 auto 2rem; }
h2 { font-size: 1rem; margin: 0 0 0.4rem; font-weight: 600; }
iframe { display: block; width: 100%%; height: 24rem; border: 1px solid #00000022;
         border-radius: 8px; background: white; }
</style>
</head>
<body>
<header>
<h1>%s</h1>
<p>One page, rendered by the same renderer as <code>C-c r p</code>, in every palette
this Emacs can load.  Press <code>C-c r g</code> again to render it again.</p>
<nav>%s</nav>
</header>
%s
</body>
</html>
"
          (heks/render--escape (or title "heks-emacs: every palette"))
          (heks/render--escape (or title "heks-emacs: every palette"))
          (mapconcat (lambda (entry)
                       (format "<a href=\"#%s\">%s</a>"
                               (heks/render--escape (car entry) t)
                               (heks/render--escape (car entry))))
                     entries "\n")
          (mapconcat (lambda (entry)
                       (format "<section id=\"%s\">\n<h2>%s</h2>\n\
<iframe title=\"%s\" loading=\"lazy\" srcdoc=\"%s\"></iframe>\n</section>"
                               (heks/render--escape (car entry) t)
                               (heks/render--escape (car entry))
                               (heks/render--escape (car entry) t)
                               (heks/render--escape (cdr entry) t)))
                     entries "\n")))

(defun heks/theme-gallery (&optional file)
  "Render `heks/theme-gallery-sample' in every available theme, as one page.

Each theme is loaded, rendered and disabled in turn, so the palette a
document carries is that theme's own; the themes that were enabled when
the gallery was asked for are enabled again at the end.  A theme that
will not load is left out of the page rather than failing the run, and
the file is written where `heks/theme-gallery-target' says.  Return it."
  (interactive)
  (require 'custom)
  (require 'heks/render nil t)
  (let* ((original (copy-sequence custom-enabled-themes))
         (entries
          (delq nil
                (mapcar
                 (lambda (theme)
                   (condition-case nil
                       (progn
                         (load-theme theme t)
                         (prog1 (cons (symbol-name theme)
                                      (heks/html-document
                                       (format "heks-emacs in %s" theme)
                                       (heks/render--markdown
                                        heks/theme-gallery-sample)))
                           (disable-theme theme)))
                     (error nil)))
                 (sort heks/themes
                       (lambda (a b) (string< (symbol-name a) (symbol-name b)))))))
         (target (heks/theme-gallery-target file)))
    (make-directory (file-name-directory target) t)
    (with-temp-file target
      (insert (heks/theme-gallery-html entries)))
    (mapc #'enable-theme original)
    (message "Rendered %d palettes into %s" (length entries) target)
    target))

(keymap-set global-map "C-c r g" #'heks/theme-gallery)

(provide 'heks/theme)

;;; theme.el ends here
