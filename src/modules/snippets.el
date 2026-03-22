(use-package tempel
  :ensure (:host github :repo "minad/tempel" :branch "main")
  :bind (("C-c s c" . tempel-complete)
         ("C-c s i" . tempel-insert)
         ("C-c s x" . tempel-expand))
  :init
  (setopt tempel-path '("~/.emacs.d/snippets/*.eld")))
