;;; mail.el --- Mail configuration for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; Mail configuration for Emacs

;;; Code:

(use-package gnus
  :ensure nil
  :bind (("C-c o m" . gnus)
         ;; Reading one group by name used to be a stray `C-c C-m C-s'
         ;; in the core module; it is a mail action, so it is here.
         ("C-c o g" . gnus-group-read-ephemeral-group))
  :config
  (setq gnus-use-cache t
        gnus-asynchronous t
        gnus-use-header-prefetch t)
  (setq gnus-sum-thread-tree-false-root " "
        gnus-sum-thread-tree-indent "  "
        gnus-sum-thread-tree-root "r "
        gnus-sum-thread-tree-single-indent "◎ "
        gnus-sum-thread-tree-vertical        "|"
        gnus-sum-thread-tree-leaf-with-other "├─► "
        gnus-sum-thread-tree-single-leaf     "╰─► "

        ;; │06-Jan│  Sender Name  │ Email Subject
        gnus-summary-line-format (concat "%0{%U%R%z%}"
                                         "%3{│%}" "%1{%d%}" "%3{│%}"
                                         "  "
                                         "%4{%-20,20f%}"
                                         "  "
                                         "%3{│%}"
                                         " "
                                         "%1{%B%}"
                                         "%s\n"))
  (setq gnus-thread-sort-functions
        '(gnus-thread-sort-by-most-recent-date
          (not gnus-thread-sort-by-number))))

(use-package smtpmail
  :ensure nil
  :config
  (setq send-mail-function 'smtpmail-send-it
        smtpmail-debug-info t
        smtpmail-debug-verb t))

(provide 'heks/mail)

;;; mail.el ends here
