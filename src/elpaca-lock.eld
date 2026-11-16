((aggressive-indent :source "elpaca-menu-lock-file" :recipe
		    (:package "aggressive-indent" :repo
			      "Malabarba/aggressive-indent-mode"
			      :fetcher github :files
			      ("*.el" "*.el.in" "dir" "*.info"
			       "*.texi" "*.texinfo" "doc/dir"
			       "doc/*.info" "doc/*.texi"
			       "doc/*.texinfo" "lisp/*.el" "docs/dir"
			       "docs/*.info" "docs/*.texi"
			       "docs/*.texinfo"
			       (:exclude ".dir-locals.el" "test.el"
					 "tests.el" "*-test.el"
					 "*-tests.el" "LICENSE"
					 "README*" "*-pkg.el"))
			      :source "MELPA" :id aggressive-indent
			      :type git :protocol https :inherit t
			      :depth treeless :ref
			      "a437a45868f94b77362c6b913c5ee8e67b273c42"))
 (aio :source "elpaca-menu-lock-file" :recipe
      (:package "aio" :fetcher github :repo "skeeto/emacs-aio" :files
		("aio.el" "README.md" "UNLICENSE") :source "MELPA" :id
		aio :host github :branch "master" :type git :protocol
		https :inherit t :depth treeless :ref
		"a20c99aafef021b77b0a00735659142d4cf49682"))
 (autothemer :source "elpaca-menu-lock-file" :recipe
	     (:package "autothemer" :fetcher github :repo
		       "ocodo/autothemer" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id autothemer :type git
		       :protocol https :inherit t :depth treeless :ref
		       "d5917521c1a0431d59431bbf1e8296affd7ddddb"))
 (avy :source "elpaca-menu-lock-file" :recipe
      (:package "avy" :repo "abo-abo/avy" :fetcher github :files
		("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		 "docs/*.texinfo"
		 (:exclude ".dir-locals.el" "test.el" "tests.el"
			   "*-test.el" "*-tests.el" "LICENSE"
			   "README*" "*-pkg.el"))
		:source "MELPA" :id avy :type git :protocol https
		:inherit t :depth treeless :ref
		"933d1f36cca0f71e4acb5fac707e9ae26c536264"))
 (ayu-theme :source "elpaca-menu-lock-file" :recipe
	    (:package "ayu-theme" :repo "vutran1710/Ayu-Theme-Emacs"
		      :fetcher github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id ayu-theme :type git
		      :protocol https :inherit t :depth treeless :ref
		      "dc325520c1202463a0f05d4ece1644109830fef4"))
 (buffer-to-pdf :source "elpaca-menu-lock-file" :recipe
		(:source "User Declaration" :package "buffer-to-pdf"
			 :id buffer-to-pdf :host github :repo
			 "protesilaos/buffer-to-pdf" :type git
			 :protocol https :inherit t :depth treeless
			 :ref
			 "f4e6fded87015aada1256736cdd26d6f952c650e"))
 (cape :source "elpaca-menu-lock-file" :recipe
       (:package "cape" :repo "minad/cape" :fetcher github :files
		 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		  "docs/*.texinfo"
		  (:exclude ".dir-locals.el" "test.el" "tests.el"
			    "*-test.el" "*-tests.el" "LICENSE"
			    "README*" "*-pkg.el"))
		 :source "MELPA" :id cape :type git :protocol https
		 :inherit t :depth treeless :ref
		 "50bc6187daf9af9df1a802fcbbd91fe4b952fc69"))
 (catppuccin-theme :source "elpaca-menu-lock-file" :recipe
		   (:package "catppuccin-theme" :fetcher github :repo
			     "catppuccin/emacs" :files
			     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			      "*.texinfo" "doc/dir" "doc/*.info"
			      "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			      "docs/dir" "docs/*.info" "docs/*.texi"
			      "docs/*.texinfo"
			      (:exclude ".dir-locals.el" "test.el"
					"tests.el" "*-test.el"
					"*-tests.el" "LICENSE"
					"README*" "*-pkg.el"))
			     :source "MELPA" :id catppuccin-theme
			     :type git :protocol https :inherit t
			     :depth treeless :ref
			     "56c3cbe1fee8b04dd7331738df1a0b9bdc6f71bd"))
 (circe :source "elpaca-menu-lock-file" :recipe
	(:package "circe" :repo "emacs-circe/circe" :fetcher github
		  :files
		  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		   "doc/*.texinfo" "lisp/*.el" "docs/dir"
		   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		   (:exclude ".dir-locals.el" "test.el" "tests.el"
			     "*-test.el" "*-tests.el" "LICENSE"
			     "README*" "*-pkg.el"))
		  :source "MELPA" :id circe :type git :protocol https
		  :inherit t :depth treeless :ref
		  "50ac3bc96a0db359a877162a1033b41ba0d01bb8"))
 (compat :source "elpaca-menu-lock-file" :recipe
	 (:package "compat" :repo "emacs-compat/compat" :tar
		   "31.1.0.0" :host github :files
		   ("*" (:exclude ".git")) :source "GNU ELPA" :id
		   compat :branch "main" :type git :protocol https
		   :inherit t :depth treeless :ref
		   "90880f81419577e1d3f68424d2a3adf31e6d663e"))
 (consult :source "elpaca-menu-lock-file" :recipe
	  (:package "consult" :repo "minad/consult" :fetcher github
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id consult :type git :protocol
		    https :inherit t :depth treeless :ref
		    "a64569f377b8bc0f62e1d2ae0f3ee48ba4a7cc1c"))
 (corfu :source "elpaca-menu-lock-file" :recipe
	(:package "corfu" :repo "minad/corfu" :files
		  (:defaults "extensions/corfu-*.el") :fetcher github
		  :source "MELPA" :id corfu :type git :protocol https
		  :inherit t :depth treeless :ref
		  "15fed49c97bf6b2436641714ae15bbd2f3e37b77"))
 (corfu-terminal :source "elpaca-menu-lock-file" :recipe
		 (:package "corfu-terminal" :repo
			   ("https://codeberg.org/akib/emacs-corfu-terminal"
			    . "corfu-terminal")
			   :tar "0.7" :host nongnu :files
			   ("*" (:exclude ".git")) :source
			   "NonGNU ELPA" :id corfu-terminal :type git
			   :protocol https :inherit t :depth treeless
			   :ref
			   "501548c3d51f926c687e8cd838c5865ec45d03cc"))
 (dagboek :source "elpaca-menu-lock-file" :recipe
	  (:source "User Declaration" :package "dagboek" :id dagboek
		   :host codeberg :repo "jjba23/dagboek.el" :branch
		   "trunk" :type git :protocol https :inherit t :depth
		   treeless :ref
		   "c9768fd550127d966a6b24191e2cb5c2f73587be"))
 (dape :source "elpaca-menu-lock-file" :recipe
       (:package "dape" :repo
		 ("https://github.com/svaante/dape" . "dape") :tar
		 "0.28.0" :host gnu :files ("*" (:exclude ".git"))
		 :source "GNU ELPA" :id dape :type git :protocol https
		 :inherit t :depth treeless :ref
		 "1d45904b40bfdbdbe0e29546a13d7859a478f710"))
 (deadgrep :source "elpaca-menu-lock-file" :recipe
	   (:package "deadgrep" :repo "Wilfred/deadgrep" :fetcher
		     github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id deadgrep :type git :protocol
		     https :inherit t :depth treeless :ref
		     "85257234fa696f412c5701b94f3aa5266a760252"))
 (diff-hl :source "elpaca-menu-lock-file" :recipe
	  (:package "diff-hl" :fetcher github :repo "dgutov/diff-hl"
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id diff-hl :type git :protocol
		    https :inherit t :depth treeless :ref
		    "8dfb5c27ea43b8c7ac1c008bb97090ad4f059285"))
 (dired-hacks-utils :source "elpaca-menu-lock-file" :recipe
		    (:package "dired-hacks-utils" :fetcher github
			      :repo "Fuco1/dired-hacks" :files
			      ("dired-hacks-utils.el") :source "MELPA"
			      :id dired-hacks-utils :type git
			      :protocol https :inherit t :depth
			      treeless :ref
			      "de9336f4b47ef901799fe95315fa080fa6d77b48"))
 (dired-open-with :source "elpaca-menu-lock-file" :recipe
		  (:package "dired-open-with" :fetcher github :repo
			    "FrostyX/dired-open-with" :files
			    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			     "*.texinfo" "doc/dir" "doc/*.info"
			     "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			     "docs/dir" "docs/*.info" "docs/*.texi"
			     "docs/*.texinfo"
			     (:exclude ".dir-locals.el" "test.el"
				       "tests.el" "*-test.el"
				       "*-tests.el" "LICENSE"
				       "README*" "*-pkg.el"))
			    :source "MELPA" :id dired-open-with :type
			    git :protocol https :inherit t :depth
			    treeless :ref
			    "5f9fddecea3d467a6d7bdb6a1863505b92a81e0d"))
 (dired-subtree :source "elpaca-menu-lock-file" :recipe
		(:package "dired-subtree" :fetcher github :repo
			  "Fuco1/dired-hacks" :files
			  ("dired-subtree.el") :source "MELPA" :id
			  dired-subtree :type git :protocol https
			  :inherit t :depth treeless :ref
			  "de9336f4b47ef901799fe95315fa080fa6d77b48"))
 (direnv :source "elpaca-menu-lock-file" :recipe
	 (:package "direnv" :fetcher github :repo
		   "wbolster/emacs-direnv" :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "MELPA" :id direnv :type git :protocol
		   https :inherit t :depth treeless :ref
		   "c1f38f71184f8aa3130898932f2de638beb5ed33"))
 (docker :source "elpaca-menu-lock-file" :recipe
	 (:package "docker" :fetcher github :repo "Silex/docker.el"
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "MELPA" :id docker :type git :protocol
		   https :inherit t :depth treeless :ref
		   "58a812d8f14b8dc3830a914740dedac50b70bc6c"))
 (doom-themes :source "elpaca-menu-lock-file" :recipe
	      (:package "doom-themes" :fetcher github :repo
			"doomemacs/themes" :files
			(:defaults "themes/*.el" "themes/*/*.el"
				   "extensions/*.el")
			:source "MELPA" :id doom-themes :type git
			:protocol https :inherit t :depth treeless
			:ref
			"a59202912ad55014e53a685eee6cd94130bdd4fd"))
 (dracula-theme :source "elpaca-menu-lock-file" :recipe
		(:package "dracula-theme" :fetcher github :repo
			  "dracula/emacs" :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "MELPA" :id dracula-theme :type git
			  :protocol https :inherit t :depth treeless
			  :ref
			  "538b8d20c667ac4b0c43ed1a5ef50760fb4ad754"))
 (dumb-jump :source "elpaca-menu-lock-file" :recipe
	    (:package "dumb-jump" :repo "jacktasia/dumb-jump" :fetcher
		      github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id dumb-jump :type git
		      :protocol https :inherit t :depth treeless :ref
		      "cf06b4ccdce6a39346c32f05139f9ee8b77ee229"))
 (eca :source "elpaca-menu-lock-file" :recipe
      (:package "eca" :fetcher github :repo
		"editor-code-assistant/eca-emacs" :files
		("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		 "docs/*.texinfo"
		 (:exclude ".dir-locals.el" "test.el" "tests.el"
			   "*-test.el" "*-tests.el" "LICENSE"
			   "README*" "*-pkg.el"))
		:source "MELPA" :id eca :type git :protocol https
		:inherit t :depth treeless :ref
		"907654083a773f141355cd2cdfe0daa3144ee150"))
 (ef-themes :source "elpaca-menu-lock-file" :recipe
	    (:package "ef-themes" :repo "protesilaos/ef-themes" :tar
		      "2.2.1" :host github :files
		      ("*"
		       (:exclude ".git" "COPYING" "doclicense.texi"
				 "contrast-ratios.org"))
		      :source "GNU ELPA" :id ef-themes :branch "main"
		      :type git :protocol https :inherit t :depth
		      treeless :ref
		      "716d365d0cf2ad3d855c6879a476857bc5fa57d2"))
 (eglot-java :source "elpaca-menu-lock-file" :recipe
	     (:package "eglot-java" :repo "yveszoundi/eglot-java"
		       :fetcher github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id eglot-java :type git
		       :protocol https :inherit t :depth treeless :ref
		       "b42b5190f3f59976d330fcec5fd27fc8e2701336"))
 (elmacro :source "elpaca-menu-lock-file" :recipe
	  (:package "elmacro" :fetcher github :repo "Silex/elmacro"
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id elmacro :host github :branch
		    "master" :type git :protocol https :inherit t
		    :depth treeless :ref
		    "c1966740ad94f2232581d622d09f8d4cfaecd016"))
 (embark :source "elpaca-menu-lock-file" :recipe
	 (:package "embark" :repo "oantolin/embark" :fetcher github
		   :files ("embark.el" "embark-org.el" "embark.texi")
		   :source "MELPA" :id embark :host github :branch
		   "master" :type git :protocol https :inherit t
		   :depth treeless :ref
		   "87e53827cf6659dcc4ac4e54be9af34aeca44f6e"))
 (embark-consult :source "elpaca-menu-lock-file" :recipe
		 (:package "embark-consult" :repo "oantolin/embark"
			   :fetcher github :files
			   ("embark-consult.el") :source "MELPA" :id
			   embark-consult :host github :branch
			   "master" :type git :protocol https :inherit
			   t :depth treeless :ref
			   "87e53827cf6659dcc4ac4e54be9af34aeca44f6e"))
 (everforest :source "elpaca-menu-lock-file" :recipe
	     (:source "User Declaration" :package "everforest" :id
		      everforest :host github :repo
		      "Theory-of-Everything/everforest-emacs" :branch
		      "master2" :type git :protocol https :inherit t
		      :depth treeless :ref
		      "ba61a881b5d57810eef76baae01c951d1e6c2ceb"))
 (expand-region :source "elpaca-menu-lock-file" :recipe
		(:package "expand-region" :repo
			  "magnars/expand-region.el" :fetcher github
			  :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "MELPA" :id expand-region :type git
			  :protocol https :inherit t :depth treeless
			  :ref
			  "351279272330cae6cecea941b0033a8dd8bcc4e8"))
 (f :source "elpaca-menu-lock-file" :recipe
    (:package "f" :fetcher github :repo "rejeep/f.el" :files
	      ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
	       "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
	       "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
	       "docs/*.texinfo"
	       (:exclude ".dir-locals.el" "test.el" "tests.el"
			 "*-test.el" "*-tests.el" "LICENSE" "README*"
			 "*-pkg.el"))
	      :source "MELPA" :id f :type git :protocol https :inherit
	      t :depth treeless :ref
	      "931b6d0667fe03e7bf1c6c282d6d8d7006143c52"))
 (fancy-compilation :source "elpaca-menu-lock-file" :recipe
		    (:package "fancy-compilation" :fetcher codeberg
			      :repo
			      "ideasman42/emacs-fancy-compilation"
			      :files
			      ("*.el" "*.el.in" "dir" "*.info"
			       "*.texi" "*.texinfo" "doc/dir"
			       "doc/*.info" "doc/*.texi"
			       "doc/*.texinfo" "lisp/*.el" "docs/dir"
			       "docs/*.info" "docs/*.texi"
			       "docs/*.texinfo"
			       (:exclude ".dir-locals.el" "test.el"
					 "tests.el" "*-test.el"
					 "*-tests.el" "LICENSE"
					 "README*" "*-pkg.el"))
			      :source "MELPA" :id fancy-compilation
			      :type git :protocol https :inherit t
			      :depth treeless :ref
			      "502d36e0fb4c4daedc16ea5d732dcbc8285d6fb1"))
 (flymake-collection :source "elpaca-menu-lock-file" :recipe
		     (:package "flymake-collection" :fetcher github
			       :repo "mohkale/flymake-collection"
			       :files
			       (:defaults "src/*.el"
					  "src/checkers/*.el")
			       :old-names (flymake-rest) :source
			       "MELPA" :id flymake-collection :type
			       git :protocol https :inherit t :depth
			       treeless :ref
			       "1c771edc125ae44d9574489f3989397027b17654"))
 (flymake-ruff :source "elpaca-menu-lock-file" :recipe
	       (:package "flymake-ruff" :fetcher github :repo
			 "erickgnavar/flymake-ruff" :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "MELPA" :id flymake-ruff :type git
			 :protocol https :inherit t :depth treeless
			 :ref
			 "ef4a6caed72bce77a27bda54ffb30e3fdb0e7d76"))
 (format-all :source "elpaca-menu-lock-file" :recipe
	     (:package "format-all" :fetcher github :repo
		       "lassik/emacs-format-all-the-code" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id format-all :type git
		       :protocol https :inherit t :depth treeless :ref
		       "0dbe9c70eaf8b92dca1a42552761eaa13c3139cf"))
 (fretboard :source "elpaca-menu-lock-file" :recipe
	    (:package "fretboard" :fetcher github :repo
		      "vifon/fretboard.el" :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id fretboard :host github
		      :branch "master" :type git :protocol https
		      :inherit t :depth treeless :ref
		      "c28f2ce0b3acb3c0df0b441a177d63877ccfb2a4"))
 (gcmh :source "elpaca-menu-lock-file" :recipe
       (:package "gcmh" :repo "koral/gcmh" :fetcher gitlab :files
		 ("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		  "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		  "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		  "docs/*.texinfo"
		  (:exclude ".dir-locals.el" "test.el" "tests.el"
			    "*-test.el" "*-tests.el" "LICENSE"
			    "README*" "*-pkg.el"))
		 :source "MELPA" :id gcmh :type git :protocol https
		 :inherit t :depth treeless :ref
		 "0089f9c3a6d4e9a310d0791cf6fa8f35642ecfd9"))
 (geiser :source "elpaca-menu-lock-file" :recipe
	 (:package "geiser" :fetcher codeberg :repo "geiser/geiser"
		   :files ("elisp/*.el" "doc/dir" "doc/geiser.texi")
		   :source "MELPA" :id geiser :type git :protocol
		   https :inherit t :depth treeless :ref
		   "0365a23e2fd090188aad02540b862db372085911"))
 (geiser-guile :source "elpaca-menu-lock-file" :recipe
	       (:package "geiser-guile" :fetcher codeberg :repo
			 "geiser/guile" :files
			 (:defaults ("src" "src/*")) :source "MELPA"
			 :id geiser-guile :type git :protocol https
			 :inherit t :depth treeless :ref
			 "fd732bfb4c7c7881ab50bf58c15c9348bd1840db"))
 (ghostel :source "elpaca-menu-lock-file" :recipe
	  (:package "ghostel" :fetcher github :repo "dakra/ghostel"
		    :files
		    (:defaults "etc" "src" "vendor" "build.zig"
			       "build.zig.zon" "symbols.map")
		    :source "MELPA" :id ghostel :type git :protocol
		    https :inherit t :depth treeless :ref
		    "c6f24788b5e114ad6569b3943702bd1609617a5e"))
 (git-link :source "elpaca-menu-lock-file" :recipe
	   (:package "git-link" :fetcher github :repo "sshaw/git-link"
		     :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id git-link :type git :protocol
		     https :inherit t :depth treeless :ref
		     "ca01d013bd575710e2cd47001ee1ef6ee41667cf"))
 (git-modes :source "elpaca-menu-lock-file" :recipe
	    (:package "git-modes" :fetcher github :repo
		      "magit/git-modes" :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id git-modes :type git
		      :protocol https :inherit t :depth treeless :ref
		      "f8a453725586c8225e47afca4c8cbc2c5585bf33"))
 (git-riddance :source "elpaca-menu-lock-file" :recipe
	       (:source "User Declaration" :package "git-riddance" :id
			git-riddance :host codeberg :repo
			"jjba23/git-riddance.el" :branch "trunk" :type
			git :protocol https :inherit t :depth treeless
			:ref
			"821dedbbccc55abd544cbf9b65c484db3341a4a8"))
 (gnuplot :source "elpaca-menu-lock-file" :recipe
	  (:package "gnuplot" :repo "emacs-gnuplot/gnuplot" :fetcher
		    github :files
		    ("gnuplot.el" "gnuplot-gui.el"
		     "gnuplot-context.el" "gnuplot-eldoc.el"
		     "gnuplot.texi")
		    :source "MELPA" :id gnuplot :type git :protocol
		    https :inherit t :depth treeless :ref
		    "3b6110a00f2bb5fcdcf5a7ea86e6ee15eec7a21d"))
 (go-mode :source "elpaca-menu-lock-file" :recipe
	  (:package "go-mode" :repo "dominikh/go-mode.el" :fetcher
		    github :files ("go-mode.el") :source "MELPA" :id
		    go-mode :host github :branch "master" :type git
		    :protocol https :inherit t :depth treeless :ref
		    "3a71d28ab47df685e54ca6046a7a3dd3e28b682c"))
 (gptel :source "elpaca-menu-lock-file" :recipe
	(:package "gptel" :repo "karthink/gptel" :fetcher github
		  :files
		  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		   "doc/*.texinfo" "lisp/*.el" "docs/dir"
		   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		   (:exclude ".dir-locals.el" "test.el" "tests.el"
			     "*-test.el" "*-tests.el" "LICENSE"
			     "README*" "*-pkg.el"))
		  :source "MELPA" :id gptel :type git :protocol https
		  :inherit t :depth treeless :ref
		  "e161ababf0cb19654ec9097f06c09c95d4561721"))
 (graphql-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "graphql-mode" :repo "davazp/graphql-mode"
			 :fetcher github :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "MELPA" :id graphql-mode :type git
			 :protocol https :inherit t :depth treeless
			 :ref
			 "64b8ba6faf85d0581c500fcd8c6042064e76c935"))
 (groovy-mode :source "elpaca-menu-lock-file" :recipe
	      (:package "groovy-mode" :fetcher github :repo
			"Groovy-Emacs-Modes/groovy-emacs-modes" :files
			("*groovy*.el") :source "MELPA" :id
			groovy-mode :type git :protocol https :inherit
			t :depth treeless :ref
			"7b8520b2e2d3ab1d62b35c426e17ac25ed0120bb"))
 (gruvbox-theme :source "elpaca-menu-lock-file" :recipe
		(:package "gruvbox-theme" :fetcher github :repo
			  "greduan/emacs-theme-gruvbox" :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "MELPA" :id gruvbox-theme :host
			  github :branch "master" :type git :protocol
			  https :inherit t :depth treeless :ref
			  "351a3ced876fe0b294398ef6bb37c8b7b8a246a7"))
 (guix :source "elpaca-menu-lock-file" :recipe
       (:package "guix" :fetcher codeberg :repo "guix/emacs-guix"
		 :files
		 ("elisp/*.el" "doc/*.texi" ("images" "images/*.svg")
		  ("scheme" "scheme/*")
		  (:exclude "scheme/Makefile.am"))
		 :source "MELPA" :id guix :type git :protocol https
		 :inherit t :depth treeless :ref
		 "97b370d70e5e74dc0bb26f1c57a4f1c89ce956f1"))
 (haskell-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "haskell-mode" :repo "haskell/haskell-mode"
			 :fetcher github :files
			 (:defaults "NEWS" "logo.svg") :source "MELPA"
			 :id haskell-mode :type git :protocol https
			 :inherit t :depth treeless :ref
			 "f957090cfb2fb8757a06750c6438561b21419f86"))
 (hcl-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "hcl-mode" :repo "hcl-emacs/hcl-mode" :fetcher
		     github :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id hcl-mode :type git :protocol
		     https :inherit t :depth treeless :ref
		     "1da895ed75d28d9f87cbf9b74f075d90ba31c0ed"))
 (helpful :source "elpaca-menu-lock-file" :recipe
	  (:package "helpful" :repo "Wilfred/helpful" :fetcher github
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id helpful :type git :protocol
		    https :inherit t :depth treeless :ref
		    "03756fa6ad4dcca5e0920622b1ee3f70abfc4e39"))
 (hl-todo :source "elpaca-menu-lock-file" :recipe
	  (:package "hl-todo" :fetcher github :repo "tarsius/hl-todo"
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id hl-todo :type git :protocol
		    https :inherit t :depth treeless :ref
		    "d25aa5a2e78f70331de2b3455d8ef85bd945356b"))
 (htmlize :source "elpaca-menu-lock-file" :recipe
	  (:package "htmlize" :fetcher github :repo
		    "emacsorphanage/htmlize" :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id htmlize :type git :protocol
		    https :inherit t :depth treeless :ref
		    "fa644880699adea3770504f913e6dddbec90c076"))
 (inheritenv :source "elpaca-menu-lock-file" :recipe
	     (:package "inheritenv" :fetcher github :repo
		       "purcell/inheritenv" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id inheritenv :type git
		       :protocol https :inherit t :depth treeless :ref
		       "b9e67cc20c069539698a9ac54d0e6cc11e616c6f"))
 (jarchive :source "elpaca-menu-lock-file" :recipe
	   (:package "jarchive" :repo
		     ("https://git.sr.ht/~dannyfreeman/jarchive"
		      . "jarchive")
		     :tar "0.12.0" :host gnu :files
		     ("*" (:exclude ".git" "LICENSE")) :source
		     "GNU ELPA" :id jarchive :type git :protocol https
		     :inherit t :depth treeless :ref
		     "b4f59c13acf783513c897a639eb4e35c20b288d9"))
 (jinx :source "elpaca-menu-lock-file" :recipe
       (:package "jinx" :repo "minad/jinx" :files
		 (:defaults "jinx-mod.c" "emacs-module.h") :fetcher
		 github :source "MELPA" :id jinx :type git :protocol
		 https :inherit t :depth treeless :ref
		 "bccb08062a3372629015bcd2c197490b7d005f37"))
 (json-mode :source "elpaca-menu-lock-file" :recipe
	    (:package "json-mode" :fetcher github :repo
		      "json-emacs/json-mode" :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id json-mode :host github :type
		      git :protocol https :inherit t :depth treeless
		      :ref "466d5b563721bbeffac3f610aefaac15a39d90a9"))
 (just-mode :source "elpaca-menu-lock-file" :recipe
	    (:package "just-mode" :repo "leon-barrett/just-mode.el"
		      :fetcher github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id just-mode :type git
		      :protocol https :inherit t :depth treeless :ref
		      "5513ab0350d2701a94deb8cafef57d3c369a5e9b"))
 (justl :source "elpaca-menu-lock-file" :recipe
	(:package "justl" :repo "psibi/justl.el" :fetcher github
		  :files
		  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		   "doc/*.texinfo" "lisp/*.el" "docs/dir"
		   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		   (:exclude ".dir-locals.el" "test.el" "tests.el"
			     "*-test.el" "*-tests.el" "LICENSE"
			     "README*" "*-pkg.el"))
		  :source "MELPA" :id justl :type git :protocol https
		  :inherit t :depth treeless :ref
		  "25ce659d99cd0ca3a1696db1a08315aa4d1e7e1c"))
 (kanagawa-theme :source "elpaca-menu-lock-file" :recipe
		 (:source "User Declaration" :package "kanagawa-theme"
			  :id kanagawa-theme :host github :repo
			  "arouene/emacs-kanagawa-theme" :branch
			  "main" :type git :protocol https :inherit t
			  :depth treeless :ref
			  "5292255526f37f7588d1668c70030fefaf8957c1"))
 (kaolin-themes :source "elpaca-menu-lock-file" :recipe
		(:package "kaolin-themes" :fetcher github :repo
			  "ogdenwebb/emacs-kaolin-themes" :old-names
			  (kaolin-theme) :files
			  (:defaults "themes/*.el") :source "MELPA"
			  :id kaolin-themes :type git :protocol https
			  :inherit t :depth treeless :ref
			  "316bb3119ebbf845504cfc932ff187cdd646f45f"))
 (keycast :source "elpaca-menu-lock-file" :recipe
	  (:package "keycast" :fetcher github :repo "tarsius/keycast"
		    :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id keycast :type git :protocol
		    https :inherit t :depth treeless :ref
		    "13d41878b64f9e8a811862b860024847c23cdd9e"))
 (kind-icon :source "elpaca-menu-lock-file" :recipe
	    (:package "kind-icon" :repo "jdtsmith/kind-icon" :tar
		      "0.2.2" :host github :files
		      ("*" (:exclude ".git")) :source "GNU ELPA" :id
		      kind-icon :branch "main" :type git :protocol
		      https :inherit t :depth treeless :ref
		      "556b0fb92aac24979b2c501431c7d48f75a5169f"))
 (kirigami :source "elpaca-menu-lock-file" :recipe
	   (:package "kirigami" :fetcher github :repo
		     "jamescherti/kirigami.el" :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id kirigami :type git :protocol
		     https :inherit t :depth treeless :ref
		     "e319bf00f845a5118fcab19e548df49ed2517d9a"))
 (kotlin-ts-mode :source "elpaca-menu-lock-file" :recipe
		 (:package "kotlin-ts-mode" :fetcher gitlab :repo
			   "bricka/emacs-kotlin-ts-mode" :files
			   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			    "*.texinfo" "doc/dir" "doc/*.info"
			    "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			    "docs/dir" "docs/*.info" "docs/*.texi"
			    "docs/*.texinfo"
			    (:exclude ".dir-locals.el" "test.el"
				      "tests.el" "*-test.el"
				      "*-tests.el" "LICENSE" "README*"
				      "*-pkg.el"))
			   :source "MELPA" :id kotlin-ts-mode :type
			   git :protocol https :inherit t :depth
			   treeless :ref
			   "292c9a05ff2243c39a48201b277840b1d25e1ea0"))
 (kubed :source "elpaca-menu-lock-file" :recipe
	(:package "kubed" :repo "eshelyaron/kubed" :tar "0.7.1" :host
		  github :files ("*" (:exclude ".git")) :source
		  "GNU ELPA" :id kubed :branch "master" :type git
		  :protocol https :inherit t :depth treeless :ref
		  "80fe51f8bb76533b04e2c26f29dbcab1aca07ea9"))
 (ligature :source "elpaca-menu-lock-file" :recipe
	   (:package "ligature" :fetcher github :repo
		     "mickeynp/ligature.el" :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id ligature :type git :protocol
		     https :inherit t :depth treeless :ref
		     "e0bc07ec41203b72386a2b878b6c8a65c28f4ced"))
 (lua-mode :source "elpaca-menu-lock-file" :recipe
	   (:package "lua-mode" :repo "immerrr/lua-mode" :fetcher
		     github :files
		     (:defaults (:exclude "init-tryout.el")) :source
		     "MELPA" :id lua-mode :type git :protocol https
		     :inherit t :depth treeless :ref
		     "2f6b8d7a6317e42c953c5119b0119ddb337e0a5f"))
 (maak.el :source "elpaca-menu-lock-file" :recipe
	  (:source "User Declaration" :package "maak.el" :id maak.el
		   :host codeberg :repo "jjba23/maak.el" :branch
		   "trunk" :type git :protocol https :inherit t :depth
		   treeless :ref
		   "459cb47e6e64230f7c2a1d8cb00f6f01b353b547"))
 (magit :source "elpaca-menu-lock-file" :recipe
	(:package "magit" :fetcher github :repo "magit/magit" :files
		  ("lisp/magit*.el" "lisp/git-*.el" "docs/magit.texi"
		   "docs/AUTHORS.md" "LICENSE" ".dir-locals.el"
		   ("githooks" "githooks/*")
		   (:exclude "lisp/magit-section.el"))
		  :source "MELPA" :id magit :type git :protocol https
		  :inherit t :depth treeless :ref
		  "da92cab409326115b7ee64cc611c99fd29b00963"))
 (magit-delta :source "elpaca-menu-lock-file" :recipe
	      (:package "magit-delta" :fetcher github :repo
			"dandavison/magit-delta" :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "MELPA" :id magit-delta :type git
			:protocol https :inherit t :depth treeless
			:ref
			"5fc7dbddcfacfe46d3fd876172ad02a9ab6ac616"))
 (marginalia :source "elpaca-menu-lock-file" :recipe
	     (:package "marginalia" :fetcher github :repo
		       "minad/marginalia" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id marginalia :type git
		       :protocol https :inherit t :depth treeless :ref
		       "381af583d2530796b9955ff2fe0cba3ad3119943"))
 (mermaid-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "mermaid-mode" :repo "abrochard/mermaid-mode"
			 :fetcher github :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "MELPA" :id mermaid-mode :type git
			 :protocol https :inherit t :depth treeless
			 :ref
			 "804dbcb1452e7496ae0c48e20362da6351227246"))
 (meson-mode :source "elpaca-menu-lock-file" :recipe
	     (:package "meson-mode" :fetcher github :repo
		       "wentasah/meson-mode" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id meson-mode :host github
		       :branch "master" :type git :protocol https
		       :inherit t :depth treeless :ref
		       "0449c649daaa9322e1c439c1540d8c290501d455"))
 (modusregel :source "elpaca-menu-lock-file" :recipe
	     (:source "User Declaration" :package "modusregel" :id
		      modusregel :host codeberg :repo
		      "jjba23/modusregel" :branch "trunk" :type git
		      :protocol https :inherit t :depth treeless :ref
		      "66d333ee8c59375d513cf027cc16c22acecb6b03"))
 (move-text :source "elpaca-menu-lock-file" :recipe
	    (:package "move-text" :fetcher github :repo
		      "emacsfodder/move-text" :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id move-text :type git
		      :protocol https :inherit t :depth treeless :ref
		      "142890cfb46d9c374113b4b49021a4202033147b"))
 (nerd-icons :source "elpaca-menu-lock-file" :recipe
	     (:package "nerd-icons" :repo
		       "rainstormstudio/nerd-icons.el" :fetcher github
		       :files (:defaults "data") :source "MELPA" :id
		       nerd-icons :type git :protocol https :inherit t
		       :depth treeless :ref
		       "87ae84981ddeb4446586ba65cb30cec6e6ccfdb0"))
 (nerd-icons-completion :source "elpaca-menu-lock-file" :recipe
			(:package "nerd-icons-completion" :repo
				  "rainstormstudio/nerd-icons-completion"
				  :fetcher github :files
				  ("*.el" "*.el.in" "dir" "*.info"
				   "*.texi" "*.texinfo" "doc/dir"
				   "doc/*.info" "doc/*.texi"
				   "doc/*.texinfo" "lisp/*.el"
				   "docs/dir" "docs/*.info"
				   "docs/*.texi" "docs/*.texinfo"
				   (:exclude ".dir-locals.el"
					     "test.el" "tests.el"
					     "*-test.el" "*-tests.el"
					     "LICENSE" "README*"
					     "*-pkg.el"))
				  :source "MELPA" :id
				  nerd-icons-completion :type git
				  :protocol https :inherit t :depth
				  treeless :ref
				  "f924dd490c8c4c1066fd97a76e0dc31e303fca30"))
 (nerd-icons-dired :source "elpaca-menu-lock-file" :recipe
		   (:package "nerd-icons-dired" :repo
			     "rainstormstudio/nerd-icons-dired"
			     :fetcher github :files
			     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			      "*.texinfo" "doc/dir" "doc/*.info"
			      "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			      "docs/dir" "docs/*.info" "docs/*.texi"
			      "docs/*.texinfo"
			      (:exclude ".dir-locals.el" "test.el"
					"tests.el" "*-test.el"
					"*-tests.el" "LICENSE"
					"README*" "*-pkg.el"))
			     :source "MELPA" :id nerd-icons-dired
			     :type git :protocol https :inherit t
			     :depth treeless :ref
			     "104acd8879528b8115589f35f1bbcbe231ad732f"))
 (nix-ts-mode :source "elpaca-menu-lock-file" :recipe
	      (:package "nix-ts-mode" :fetcher github :repo
			"nix-community/nix-ts-mode" :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "MELPA" :id nix-ts-mode :type git
			:protocol https :inherit t :depth treeless
			:ref
			"09c89886a22b8e37ac0de9210ff5b2b79c520fd7"))
 (no-littering :source "elpaca-menu-lock-file" :recipe
	       (:package "no-littering" :fetcher github :repo
			 "emacscollective/no-littering" :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "MELPA" :id no-littering :type git
			 :protocol https :inherit t :depth treeless
			 :ref
			 "10de0ce7a22d2d3ea7e54e7fe96f800c1806aa11"))
 (ob-http :source "elpaca-menu-lock-file" :recipe
	  (:package "ob-http" :repo "zweifisch/ob-http" :fetcher
		    github :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id ob-http :type git :protocol
		    https :inherit t :depth treeless :ref
		    "cd6d145da1f5f11d107f423c36f8b9a6af742dfd"))
 (ob-mermaid :source "elpaca-menu-lock-file" :recipe
	     (:package "ob-mermaid" :repo "arnm/ob-mermaid" :fetcher
		       github :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id ob-mermaid :type git
		       :protocol https :inherit t :depth treeless :ref
		       "30c2da02e3d24dbec0d004d3c6dfe7b381500b05"))
 (olivetti :source "elpaca-menu-lock-file" :recipe
	   (:package "olivetti" :fetcher github :repo "rnkn/olivetti"
		     :files
		     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		      "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		      "doc/*.texinfo" "lisp/*.el" "docs/dir"
		      "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		      (:exclude ".dir-locals.el" "test.el" "tests.el"
				"*-test.el" "*-tests.el" "LICENSE"
				"README*" "*-pkg.el"))
		     :source "MELPA" :id olivetti :type git :protocol
		     https :inherit t :depth treeless :ref
		     "d2ccae56b442d9c5b06dd2481057abbd7eb82551"))
 (orderless :source "elpaca-menu-lock-file" :recipe
	    (:package "orderless" :repo "oantolin/orderless" :fetcher
		      github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id orderless :type git
		      :protocol https :inherit t :depth treeless :ref
		      "e271a8ec938929b726331236cf56d1c44571122e"))
 (org-auto-tangle :source "elpaca-menu-lock-file" :recipe
		  (:package "org-auto-tangle" :repo
			    "yilkalargaw/org-auto-tangle" :fetcher
			    github :files
			    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			     "*.texinfo" "doc/dir" "doc/*.info"
			     "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			     "docs/dir" "docs/*.info" "docs/*.texi"
			     "docs/*.texinfo"
			     (:exclude ".dir-locals.el" "test.el"
				       "tests.el" "*-test.el"
				       "*-tests.el" "LICENSE"
				       "README*" "*-pkg.el"))
			    :source "MELPA" :id org-auto-tangle :type
			    git :protocol https :inherit t :depth
			    treeless :ref
			    "b4e7abc019179df473ecddf0af80561ddad8fc58"))
 (org-present :source "elpaca-menu-lock-file" :recipe
	      (:package "org-present" :fetcher github :repo
			"rlister/org-present" :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "MELPA" :id org-present :type git
			:protocol https :inherit t :depth treeless
			:ref
			"4ec04e1b77dea76d7c30066ccf3200d2e0b7bee9"))
 (orpheus :source "elpaca-menu-lock-file" :recipe
	  (:source "User Declaration" :package "orpheus" :id orpheus
		   :host github :repo "jjba23/orpheus.el" :branch
		   "trunk" :type git :protocol https :inherit t :depth
		   treeless :ref
		   "52ec93be919b908c6e83e8d417b6b8f31cc01c67"))
 (osm :source "elpaca-menu-lock-file" :recipe
      (:package "osm" :repo "minad/osm" :fetcher github :files
		("*.el" "*.el.in" "dir" "*.info" "*.texi" "*.texinfo"
		 "doc/dir" "doc/*.info" "doc/*.texi" "doc/*.texinfo"
		 "lisp/*.el" "docs/dir" "docs/*.info" "docs/*.texi"
		 "docs/*.texinfo"
		 (:exclude ".dir-locals.el" "test.el" "tests.el"
			   "*-test.el" "*-tests.el" "LICENSE"
			   "README*" "*-pkg.el"))
		:source "MELPA" :id osm :type git :protocol https
		:inherit t :depth treeless :ref
		"9616cbbab33a8fcd52c981e5a6ff567f43520826"))
 (package-lint :source "elpaca-menu-lock-file" :recipe
	       (:package "package-lint" :fetcher github :repo
			 "purcell/package-lint" :files
			 (:defaults "data" (:exclude "*flymake.el"))
			 :source "MELPA" :id package-lint :type git
			 :protocol https :inherit t :depth treeless
			 :ref
			 "1865be780a16098f972fef50a52b21ca6ee04df9"))
 (page-break-lines :source "elpaca-menu-lock-file" :recipe
		   (:package "page-break-lines" :fetcher github :repo
			     "purcell/page-break-lines" :files
			     ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			      "*.texinfo" "doc/dir" "doc/*.info"
			      "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			      "docs/dir" "docs/*.info" "docs/*.texi"
			      "docs/*.texinfo"
			      (:exclude ".dir-locals.el" "test.el"
					"tests.el" "*-test.el"
					"*-tests.el" "LICENSE"
					"README*" "*-pkg.el"))
			     :source "MELPA" :id page-break-lines
			     :type git :protocol https :inherit t
			     :depth treeless :ref
			     "bd5eecd6580481fc37ed41c32d3c18cb49f4af57"))
 (pandoc-mode :source "elpaca-menu-lock-file" :recipe
	      (:package "pandoc-mode" :fetcher github :repo
			"joostkremers/pandoc-mode" :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "MELPA" :id pandoc-mode :type git
			:protocol https :inherit t :depth treeless
			:ref
			"8f46da90228a9ce22de24da234ba53860257640a"))
 (prodigy :source "elpaca-menu-lock-file" :recipe
	  (:package "prodigy" :fetcher github :repo
		    "rejeep/prodigy.el" :files
		    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		     "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		     "doc/*.texinfo" "lisp/*.el" "docs/dir"
		     "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		     (:exclude ".dir-locals.el" "test.el" "tests.el"
			       "*-test.el" "*-tests.el" "LICENSE"
			       "README*" "*-pkg.el"))
		    :source "MELPA" :id prodigy :type git :protocol
		    https :inherit t :depth treeless :ref
		    "336450ba90864dec62c8c883554d34aa18132165"))
 (pulsar :source "elpaca-menu-lock-file" :recipe
	 (:package "pulsar" :repo
		   ("https://github.com/protesilaos/pulsar" . "pulsar")
		   :tar "1.4.1" :host gnu :files
		   ("*" (:exclude ".git" "COPYING" "doclicense.texi"))
		   :source "GNU ELPA" :id pulsar :type git :protocol
		   https :inherit t :depth treeless :ref
		   "83d53271a0ec2728ef36b45704d47bafd170e814"))
 (queue :source "elpaca-menu-lock-file" :recipe
	(:package "queue" :repo "emacs-straight/queue" :tar "0.2"
		  :host github :branch "master" :files
		  ("*" (:exclude ".git")) :source "GNU ELPA" :id queue
		  :type git :protocol https :inherit t :depth treeless
		  :ref "8df1334d54d4735d2f821790422a850dfaaa08ef"))
 (rainbow-mode :source "elpaca-menu-lock-file" :recipe
	       (:package "rainbow-mode" :repo
			 "emacsmirror/rainbow-mode" :tar "1.0.7" :host
			 github :branch "master" :files
			 ("*" (:exclude ".git")) :source "GNU ELPA"
			 :id rainbow-mode :type git :protocol https
			 :inherit t :depth treeless :ref
			 "9d333d3a92132c2a9057d2a39e1ebd8cc575a1bb"))
 (request :source "elpaca-menu-lock-file" :recipe
	  (:package "request" :repo "tkf/emacs-request" :fetcher
		    github :files ("request.el") :source "MELPA" :id
		    request :type git :protocol https :inherit t
		    :depth treeless :ref
		    "c22e3c23a6dd90f64be536e176ea0ed6113a5ba6"))
 (ripgrep :source "elpaca-menu-lock-file" :recipe
	  (:package "ripgrep" :repo "nlamirault/ripgrep.el" :fetcher
		    github :files ("ripgrep.el") :source "MELPA" :id
		    ripgrep :type git :protocol https :inherit t
		    :depth treeless :ref
		    "b6bd5beb0c11348f1afd9486cbb451d0d2e3c45a"))
 (rose-pine :source "elpaca-menu-lock-file" :recipe
	    (:source "User Declaration" :package "rose-pine" :id
		     rose-pine :host github :repo
		     "thongpv87/rose-pine-emacs" :branch "master"
		     :main "rose-pine-color-theme.el" :type git
		     :protocol https :inherit t :depth treeless :ref
		     "adcf6f8fe719884f7e32acb9130bdbcaccd6c4c9"))
 (rust-mode :source "elpaca-menu-lock-file" :recipe
	    (:package "rust-mode" :repo "rust-lang/rust-mode" :fetcher
		      github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id rust-mode :type git
		      :protocol https :inherit t :depth treeless :ref
		      "265e243732761b925e03ebb61930a3aeea034d0e"))
 (scala-ts-mode :source "elpaca-menu-lock-file" :recipe
		(:package "scala-ts-mode" :fetcher github :repo
			  "KaranAhlawat/scala-ts-mode" :files
			  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			   "*.texinfo" "doc/dir" "doc/*.info"
			   "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			   "docs/dir" "docs/*.info" "docs/*.texi"
			   "docs/*.texinfo"
			   (:exclude ".dir-locals.el" "test.el"
				     "tests.el" "*-test.el"
				     "*-tests.el" "LICENSE" "README*"
				     "*-pkg.el"))
			  :source "MELPA" :id scala-ts-mode :type git
			  :protocol https :inherit t :depth treeless
			  :ref
			  "a1f25865a3c2772b91f5bf95457411b45244ea1e"))
 (sesman :source "elpaca-menu-lock-file" :recipe
	 (:package "sesman" :repo "vspinu/sesman" :fetcher github
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "MELPA" :id sesman :host github :branch
		   "master" :type git :protocol https :inherit t
		   :depth treeless :ref
		   "7eb733acb33e610a53979fa7fc13393eeda3cc53"))
 (show-font :source "elpaca-menu-lock-file" :recipe
	    (:package "show-font" :repo
		      ("https://github.com/protesilaos/show-font"
		       . "show-font")
		      :tar "1.0.0" :host gnu :files
		      ("*"
		       (:exclude ".git" "COPYING" "doclicense.texi"))
		      :source "GNU ELPA" :id show-font :type git
		      :protocol https :inherit t :depth treeless :ref
		      "011f7cf929e717ee42fea885f0a24efe0158e978"))
 (sift :source "elpaca-menu-lock-file" :recipe
       (:package "sift" :repo "jjba23/sift" :fetcher github :files
		 ("emacs/sift.el") :source "MELPA" :id sift :host
		 github :branch "trunk" :type git :protocol https
		 :inherit t :depth treeless :ref
		 "66a64bbf4010a580e415c89a684f7a148bd95661"))
 (sly :source "elpaca-menu-lock-file" :recipe
      (:package "sly" :repo "joaotavora/sly" :fetcher github :files
		(:defaults "lib" "slynk" "contrib" "doc/images"
			   (:exclude "sly-autoloads.el"))
		:version-regexp "%v" :source "MELPA" :id sly :host
		github :branch "master" :type git :protocol https
		:inherit t :depth treeless :ref
		"70350623eecd1f41837c9e57cbb6d5c06678a60d"))
 (smartparens :source "elpaca-menu-lock-file" :recipe
	      (:package "smartparens" :fetcher github :repo
			"Fuco1/smartparens" :files
			("*.el" "*.el.in" "dir" "*.info" "*.texi"
			 "*.texinfo" "doc/dir" "doc/*.info"
			 "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			 "docs/dir" "docs/*.info" "docs/*.texi"
			 "docs/*.texinfo"
			 (:exclude ".dir-locals.el" "test.el"
				   "tests.el" "*-test.el" "*-tests.el"
				   "LICENSE" "README*" "*-pkg.el"))
			:source "MELPA" :id smartparens :type git
			:protocol https :inherit t :depth treeless
			:ref
			"82d2cf084a19b0c2c3812e0550721f8a61996056"))
 (spacious-padding :source "elpaca-menu-lock-file" :recipe
		   (:package "spacious-padding" :repo
			     "protesilaos/spacious-padding" :tar
			     "0.9.1" :host github :files
			     ("*"
			      (:exclude ".git" "COPYING"
					"doclicense.texi"))
			     :source "GNU ELPA" :id spacious-padding
			     :branch "main" :type git :protocol https
			     :inherit t :depth treeless :ref
			     "50519dfd38d1cceea03dfbef2c5ca5dfe922304f"))
 (speed-type :source "elpaca-menu-lock-file" :recipe
	     (:package "speed-type" :fetcher github :repo
		       "dakra/speed-type" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id speed-type :host github
		       :type git :protocol https :inherit t :depth
		       treeless :ref
		       "4c7bc4876b03af3c57b6963d59c93fb7c60a367e"))
 (sqlup-mode :source "elpaca-menu-lock-file" :recipe
	     (:package "sqlup-mode" :fetcher github :repo
		       "Trevoke/sqlup-mode.el" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id sqlup-mode :type git
		       :protocol https :inherit t :depth treeless :ref
		       "3f9df9c88d6a7f9b1ae907e401cad8d3d7d63bbf"))
 (stripspace :source "elpaca-menu-lock-file" :recipe
	     (:package "stripspace" :fetcher github :repo
		       "jamescherti/stripspace.el" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id stripspace :type git
		       :protocol https :inherit t :depth treeless :ref
		       "8a5da222ba3e53999979f8f04c016604874f75cf"))
 (sudo-edit :source "elpaca-menu-lock-file" :recipe
	    (:package "sudo-edit" :repo "nflath/sudo-edit" :fetcher
		      github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id sudo-edit :type git
		      :protocol https :inherit t :depth treeless :ref
		      "74eb1e6986461baed9a9269566ff838530b4379b"))
 (super-save :source "elpaca-menu-lock-file" :recipe
	     (:package "super-save" :fetcher github :repo
		       "bbatsov/super-save" :files
		       ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			"*.texinfo" "doc/dir" "doc/*.info"
			"doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			"docs/dir" "docs/*.info" "docs/*.texi"
			"docs/*.texinfo"
			(:exclude ".dir-locals.el" "test.el"
				  "tests.el" "*-test.el" "*-tests.el"
				  "LICENSE" "README*" "*-pkg.el"))
		       :source "MELPA" :id super-save :type git
		       :protocol https :inherit t :depth treeless :ref
		       "dae7cfe4bba83904d1567e14cbbd7ed141ab37a1"))
 (svg-lib :source "elpaca-menu-lock-file" :recipe
	  (:package "svg-lib" :repo "rougier/svg-lib" :tar "0.3" :host
		    github :files ("*" (:exclude ".git")) :source
		    "GNU ELPA" :id svg-lib :branch "master" :type git
		    :protocol https :inherit t :depth treeless :ref
		    "925ed4a0215c197ba836e7810a93905b34bea777"))
 (swagg :source "elpaca-menu-lock-file" :recipe
	(:package "swagg" :fetcher github :repo "isamert/swagg.el"
		  :files
		  ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		   "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		   "doc/*.texinfo" "lisp/*.el" "docs/dir"
		   "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		   (:exclude ".dir-locals.el" "test.el" "tests.el"
			     "*-test.el" "*-tests.el" "LICENSE"
			     "README*" "*-pkg.el"))
		  :source "MELPA" :id swagg :host github :type git
		  :protocol https :inherit t :depth treeless :ref
		  "efc457f6ab95814d806b43f1b83edfa8273f7f0c"))
 (symbol-overlay :source "elpaca-menu-lock-file" :recipe
		 (:package "symbol-overlay" :fetcher github :repo
			   "wolray/symbol-overlay" :files
			   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			    "*.texinfo" "doc/dir" "doc/*.info"
			    "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			    "docs/dir" "docs/*.info" "docs/*.texi"
			    "docs/*.texinfo"
			    (:exclude ".dir-locals.el" "test.el"
				      "tests.el" "*-test.el"
				      "*-tests.el" "LICENSE" "README*"
				      "*-pkg.el"))
			   :source "MELPA" :id symbol-overlay :type
			   git :protocol https :inherit t :depth
			   treeless :ref
			   "85d100b0cca35b70cee1b260e09af8e1fb2fcc08"))
 (tekengrootte :source "elpaca-menu-lock-file" :recipe
	       (:source "User Declaration" :package "tekengrootte" :id
			tekengrootte :host codeberg :repo
			"jjba23/tekengrootte.el" :branch "trunk" :type
			git :protocol https :inherit t :depth treeless
			:ref
			"736d4f99ff0c37d65f3d4f6796dc34e3b1c765e7"))
 (tempel :source "elpaca-menu-lock-file" :recipe
	 (:package "tempel" :repo "minad/tempel" :fetcher github
		   :files
		   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		    "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		    "doc/*.texinfo" "lisp/*.el" "docs/dir"
		    "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		    (:exclude ".dir-locals.el" "test.el" "tests.el"
			      "*-test.el" "*-tests.el" "LICENSE"
			      "README*" "*-pkg.el"))
		   :source "MELPA" :id tempel :host github :branch
		   "main" :type git :protocol https :inherit t :depth
		   treeless :ref
		   "9299c5d0f35dbb02de2565404a082224c4d11654"))
 (terraform-mode :source "elpaca-menu-lock-file" :recipe
		 (:package "terraform-mode" :repo
			   "hcl-emacs/terraform-mode" :fetcher github
			   :files
			   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			    "*.texinfo" "doc/dir" "doc/*.info"
			    "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			    "docs/dir" "docs/*.info" "docs/*.texi"
			    "docs/*.texinfo"
			    (:exclude ".dir-locals.el" "test.el"
				      "tests.el" "*-test.el"
				      "*-tests.el" "LICENSE" "README*"
				      "*-pkg.el"))
			   :source "MELPA" :id terraform-mode :type
			   git :protocol https :inherit t :depth
			   treeless :ref
			   "01635df3625c0cec2bb4613a6f920b8569d41009"))
 (toml-mode :source "elpaca-menu-lock-file" :recipe
	    (:package "toml-mode" :fetcher github :repo
		      "dryman/toml-mode.el" :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id toml-mode :type git
		      :protocol https :inherit t :depth treeless :ref
		      "f6c61817b00f9c4a3cab1bae9c309e0fc45cdd06"))
 (transient :source "elpaca-menu-lock-file" :recipe
	    (:package "transient" :fetcher github :repo
		      "magit/transient" :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id transient :type git
		      :protocol https :inherit t :depth treeless :ref
		      "d424c0d980a37413e193b8e615d1af624ef96b17"))
 (treesit-fold :source "elpaca-menu-lock-file" :recipe
	       (:package "treesit-fold" :repo
			 ("https://github.com/emacs-tree-sitter/treesit-fold"
			  . "treesit-fold")
			 :tar "0.2.1" :host nongnu :files
			 ("*" (:exclude ".git")) :source "NonGNU ELPA"
			 :id treesit-fold :type git :protocol https
			 :inherit t :depth treeless :ref
			 "cc1003b730a3167b972cc8400dffe19be7988fc7"))
 (typescript-mode :source "elpaca-menu-lock-file" :recipe
		  (:package "typescript-mode" :fetcher github :repo
			    "emacs-typescript/typescript.el" :files
			    ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			     "*.texinfo" "doc/dir" "doc/*.info"
			     "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			     "docs/dir" "docs/*.info" "docs/*.texi"
			     "docs/*.texinfo"
			     (:exclude ".dir-locals.el" "test.el"
				       "tests.el" "*-test.el"
				       "*-tests.el" "LICENSE"
				       "README*" "*-pkg.el"))
			    :source "MELPA" :id typescript-mode :type
			    git :protocol https :inherit t :depth
			    treeless :ref
			    "2535780bdb318d86761b9bd21b0347ca6a89628f"))
 (ultra-scroll :source "elpaca-menu-lock-file" :recipe
	       (:package "ultra-scroll" :fetcher github :repo
			 "jdtsmith/ultra-scroll" :files
			 ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			  "*.texinfo" "doc/dir" "doc/*.info"
			  "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			  "docs/dir" "docs/*.info" "docs/*.texi"
			  "docs/*.texinfo"
			  (:exclude ".dir-locals.el" "test.el"
				    "tests.el" "*-test.el"
				    "*-tests.el" "LICENSE" "README*"
				    "*-pkg.el"))
			 :source "MELPA" :id ultra-scroll :host github
			 :branch "main" :type git :protocol https
			 :inherit t :depth treeless :ref
			 "8aa8e7496b06fd7c3585fcae8275300a77e57730"))
 (veritas :source "elpaca-menu-lock-file" :recipe
	  (:source "User Declaration" :package "veritas" :id veritas
		   :host github :repo "jjba23/veritas.el" :branch
		   "trunk" :type git :protocol https :inherit t :depth
		   treeless :ref
		   "1e181340706a54b3d4c5a898bed92e42bf11a29c"))
 (vertico :source "elpaca-menu-lock-file" :recipe
	  (:package "vertico" :repo "minad/vertico" :files
		    (:defaults "extensions/vertico-*.el") :fetcher
		    github :source "MELPA" :id vertico :type git
		    :protocol https :inherit t :depth treeless :ref
		    "c60d80215d19b4b36c0ba49599b6815ed35f2ac1"))
 (welkomscherm :source "elpaca-menu-lock-file" :recipe
	       (:source "User Declaration" :package "welkomscherm" :id
			welkomscherm :host codeberg :repo
			"jjba23/welkomscherm.el" :branch "trunk" :type
			git :protocol https :inherit t :depth treeless
			:ref
			"3f51a88a679a4fb16f582362c59bcd2a4d6a8bf8"))
 (wgrep :source "elpaca-menu-lock-file" :recipe
	(:package "wgrep" :fetcher github :repo
		  "mhayashi1120/Emacs-wgrep" :files ("wgrep.el")
		  :source "MELPA" :id wgrep :type git :protocol https
		  :inherit t :depth treeless :ref
		  "49f09ab9b706d2312cab1199e1eeb1bcd3f27f6f"))
 (yaml-mode :source "elpaca-menu-lock-file" :recipe
	    (:package "yaml-mode" :repo "yoshiki/yaml-mode" :fetcher
		      github :files
		      ("*.el" "*.el.in" "dir" "*.info" "*.texi"
		       "*.texinfo" "doc/dir" "doc/*.info" "doc/*.texi"
		       "doc/*.texinfo" "lisp/*.el" "docs/dir"
		       "docs/*.info" "docs/*.texi" "docs/*.texinfo"
		       (:exclude ".dir-locals.el" "test.el" "tests.el"
				 "*-test.el" "*-tests.el" "LICENSE"
				 "README*" "*-pkg.el"))
		      :source "MELPA" :id yaml-mode :type git
		      :protocol https :inherit t :depth treeless :ref
		      "93dba98c050e9abfc623ec66aa499dbbb46b2fe1"))
 (yasnippet-capf :source "elpaca-menu-lock-file" :recipe
		 (:package "yasnippet-capf" :fetcher github :repo
			   "elken/yasnippet-capf" :files
			   ("*.el" "*.el.in" "dir" "*.info" "*.texi"
			    "*.texinfo" "doc/dir" "doc/*.info"
			    "doc/*.texi" "doc/*.texinfo" "lisp/*.el"
			    "docs/dir" "docs/*.info" "docs/*.texi"
			    "docs/*.texinfo"
			    (:exclude ".dir-locals.el" "test.el"
				      "tests.el" "*-test.el"
				      "*-tests.el" "LICENSE" "README*"
				      "*-pkg.el"))
			   :source "MELPA" :id yasnippet-capf :type
			   git :protocol https :inherit t :depth
			   treeless :ref
			   "f53c42a996b86fc95b96bdc2deeb58581f48c666")))
