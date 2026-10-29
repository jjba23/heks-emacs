;;; dd.el --- DD for Emacs -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

;; DD for Emacs

;;; Code:

(defun heks/dd-burn-iso (iso-path target-device)
  "Burn ISO-PATH to TARGET-DEVICE asynchronously using dd."
  (interactive
   (let* ((iso (read-file-name "Select ISO/IMG file: "
                               nil nil t nil
                               (lambda (f)
                                 (or (file-directory-p f)
                                     (string-match-p "\\.\\(iso\\|img\\)$" f)))))
          (dev (read-file-name "Select target USB device (e.g., /dev/sdb): " "/dev/")))
     (list iso dev)))

  (let ((warning (format "WARNING: ALL DATA ON %s WILL BE DESTROYED. Write %s? "
                         target-device (file-name-nondirectory iso-path))))
    (if (yes-or-no-p warning)
        (let* ((buf-name "*dd-usb-writer*")
               (cmd (format "sudo dd if=%s of=%s bs=4M status=progress oflag=direct && sync"
                            (shell-quote-argument (expand-file-name iso-path))
                            (shell-quote-argument target-device)))
               (_ (async-shell-command cmd buf-name))
               (proc (get-buffer-process buf-name)))
          (if proc
              (let ((orig-sentinel (process-sentinel proc)))
                (set-process-sentinel
                 proc
                 (lambda (p event)
                   ;; Keep default Emacs shell sentinel behavior intact
                   (when orig-sentinel (funcall orig-sentinel p event))
                   ;; Print checkmark on clean zero exit status
                   (when (and (memq (process-status p) '(exit signal))
                              (= (process-exit-status p) 0))
                     (message "✔ ISO successfully burned to %s!" target-device)))))
            (user-error "Failed to start background process"))
          (message "Burning ISO to %s... Monitor progress in the %s buffer." target-device buf-name))
      (message "Operation aborted."))))

(provide 'heks/dd)

;;; dd.el ends here
