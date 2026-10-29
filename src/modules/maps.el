;;; maps.el --- Maps configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Maps configuration for Emacs

;;; Code:

(use-package osm
  :ensure t
  ;;:bind ("C-c m" . osm-prefix-map)
  :custom
  (osm-server 'default)
  (osm-copyright t))

(provide 'heks/maps)

;;; maps.el ends here
