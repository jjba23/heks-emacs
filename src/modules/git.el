(use-package magit :ensure t :after (transient compat))

(use-package git-riddance
  :ensure (:host codeberg :repo "jjba23/git-riddance.el" :branch "trunk"))
