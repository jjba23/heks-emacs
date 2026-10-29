;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>


emacs-lisp-mode

(atload & ";;;###autoload")
(pt "(point)")
(vr "(defvar " p "\n  \"" p "\")")
(lcl "(defvar-local " p "\n  \"" p "\")")
(cnst "(defconst " p "\n  \"" p "\")")
(cstom "(defcustom " p "\n  \"" p "\"" n> ":type '" p ")")
(fce "(defface " p " '((t :inherit " p "))\n  \"" p "\")")
(grp "(defgroup " p " nil\n  \"" p "\"" n> ":group '" p n> ":prefix \"" p "-\")")
(mcr "(defmacro " p " (" p ")\n  \"" p "\"" n> r> ")")
(als "(defalias '" p " '" p ")")
(fn "(defun " p " (" p ")\n  \"" p "\"" n> r> ")")
(iflet "(if-let (" p ")" n> r> ")")
(whnlt "(when-let (" p ")" n> r> ")")
(iflt* "(if-let* (" p ")" n> r> ")")
(whnlt* "(when-let* (" p ")" n> r> ")")
(andlt* "(and-let* (" p ")" n> r> ")")
(cnd "(cond" n "(" q "))" >)
(pcase "(pcase " (p "scrutinee") n "(" q "))" >)
(lt "(let (" p ")" n> r> ")")
(lt* "(let* (" p ")" n> r> ")")
(rc "(letrec (" p ")" n> r> ")")
(dtimes "(dotimes (" p ")" n> r> ")")
(dlist "(dolist (" p ")" n> r> ")")
(lp "(cl-loop for " p " in " p " do" n> r> ")")
(cmmnd "(defun " p " (" p ")\n  \"" p "\"" n> "(interactive" p ")" n> r> ")")
(advce "(defun " (p "adv" name) " (&rest app)" n> p n> "(apply app))" n>
        "(advice-add #'" (p "fun") " " (p ":around") " #'" (s name) ")")
(prvide "(provide '" (file-name-base (or (buffer-file-name) (buffer-name))) ")" n
         ";;; " (file-name-nondirectory (or (buffer-file-name) (buffer-name))) " ends here" n)
(lg "(message \"LOG %s " (s sexp) ": %S"
     "\" (format-time-string \"%X\") " sexp ")")
(package-header ";;; " (p (file-name-base (or (buffer-file-name) (buffer-name))) file) ".el --- " (p "summary" summary) " -*- lexical-binding: t -*-" n n

                ";; Author: " (p (user-full-name)) n
                ";; Version: " (p "version") n
                ";; Package-Requires: " (p "dependencies") n
                ";; Homepage: " (p "homepage") n
                ";; Keywords: " (p "keywords") n n

                ";; This file is not part of GNU Emacs" n n

                ";; SPDX-License-Identifier: MIT" n
                ";; Copyright © " (p (user-full-name)) n

                n n

                ";;; Commentary:" n n

                ";; " (p "commentary") n n

                ";;; Code:" n n

                (p "(message \"Hello, World\")") n n

                "(provide '" (s file) ")" n
                ";;; " (s file) ".el ends here")
