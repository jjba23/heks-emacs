;;; heks-emacs

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

(define-module (maak)
  #:declarative? #t
  #:use-module (maak maak))

(define emacs-config-install-dir
  (~ "\"~a\"" "$HOME/.emacs.d/"))

(define (remake-emacs-config-dir)
  (remkdir-p emacs-config-install-dir))

(define (install-emacs-config)
  (cp "src/init.el" emacs-config-install-dir)
  (cp "src/early-init.el" emacs-config-install-dir)
  (cp "src/batch-indent.el" emacs-config-install-dir)
  (cp "src/modules" emacs-config-install-dir)
  (cp "src/snippets" emacs-config-install-dir))

(define tree-sitter-grammars-url
  "https://github.com/casouri/tree-sitter-module/releases/download/v2.5/libs-linux-x64.zip")

(define (install-tree-sitter-grammars)
  ($ '("rm -rfv ~/.emacs.d/tree-sitter-grammars"))
  ($ (list (~ "wget ~a" tree-sitter-grammars-url)))
  ($ '("unzip libs-linux-x64"))
  ($ '("mv dist ~/.emacs.d/tree-sitter-grammars"))
  ($ '("rm -rfv libs-linux-x64.zip")))

(define (full-install-emacs-config)
  (remake-emacs-config-dir)
  (install-emacs-config)
  (install-tree-sitter-grammars))
