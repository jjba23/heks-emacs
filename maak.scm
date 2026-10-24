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

(define (default)
  "Default maak task."
  (list-tasks))

;; Emacs configuration installation directory.  The path is resolved here
;; rather than left to a shell, so `cp' writes into the home directory and not
;; into a directory named `~'.
(define emacs-config-install-dir
  (~ "~a/.emacs.d/" (home-dir)))

(define (remake-emacs-config-dir)
  "Remake the Emacs configuration directory."
  (remkdir-p emacs-config-install-dir))

(define (install-emacs-config)
  "Install the Emacs configuration."
  (cp "src/init.el" emacs-config-install-dir)
  (cp "src/early-init.el" emacs-config-install-dir)
  (cp "src/batch-indent.el" emacs-config-install-dir)
  ;; The script the configuration runs in a batch Emacs to build the
  ;; tree-sitter grammars, next to the configuration it belongs to.
  (cp "src/treesit-grammars.el" emacs-config-install-dir)
  (cp "src/modules" emacs-config-install-dir)
  (cp "src/snippets" emacs-config-install-dir))

(define (full-install-emacs-config)
  "Fully install the Emacs configuration."
  (remake-emacs-config-dir)
  (install-emacs-config))

(define (lint)
  "Check that every Elisp file of the configuration parses.

Fast and without installing anything: it reads each file form by form and
compares the module list in `init.el' with the modules that are there.  A
parenthesis that closed a macro too early, or a module that was renamed
without its entry in the list, is caught here."
  (run (list "emacs" "-Q" "--batch" "-l" "test/heks-emacs-lint.el")))

(define (verify)
  "Install the configuration and check it in a batch Emacs.

This is the slow one: it loads the whole configuration the way Emacs does
at startup and asserts its invariants (that every module is loaded, that a
fold covers a whole definition, that a checker survives a tool's decorated
output, that nothing breaks without Guix, that a Markdown file renders and
an OpenAPI file is read and checked).  It installs first, because what
gets checked is the copy Emacs actually runs."
  (install-emacs-config)
  (run (list "emacs" "-Q" "--batch" "-l" "test/heks-emacs-verify.el")))

(define (keys)
  "Check that no key means two things.

Reads the configuration's source for every binding -- including the ones
that only take effect when a package loads, which a runtime dump of the
keymaps cannot see -- prints the whole key tree under its topic letters,
and fails on a key that does two jobs, on a topic nobody documented and
on a binding whose command does not exist."
  (install-emacs-config)
  (run (list "emacs" "-Q" "--batch" "-l" "test/heks-emacs-keys.el")))

(define (keys-update)
  "Write the keybindings reference from the configuration.

`docs/keybindings.org' is written from the same tables the audit checks
the keys against and from the bindings it reads, so it cannot say
something the configuration does not; this is how it is made.  Read the
diff before committing it."
  (install-emacs-config)
  (run (list "emacs" "-Q" "--batch" "-l" "test/heks-emacs-keys.el")
       #:env '("HEKS_KEYS_WRITE=1")))

(define (render)
  "Check the Markdown renderer on its own.

Fast, and without loading any of the configuration: the renderer is a
pure function from a string to HTML, so it is checked as one."
  (run (list "emacs" "-Q" "--batch" "-l" "test/heks-emacs-render.el")))

(define (test)
  "Run the configuration's own test suite.

The other checks read this configuration and judge what it says; this one
loads the modules and calls the code, which is the only way to find out
that a function does what its docstring says.  It needs nothing installed:
the modules are loaded from `src' by name, with `use-package' stubbed out."
  (run (list "emacs" "-Q" "--batch" "-l" "test/heks-emacs-ert.el")))

(define (golden)
  "Check that the renderers still produce the pages they produced last time.

The documents in `test/fixtures/' are rendered and compared, line by line,
with the pages kept in `test/golden/', so that a change in what a preview
shows arrives as a diff rather than as a page one has to read and judge."
  (run (list "emacs" "-Q" "--batch" "-l" "test/heks-emacs-golden.el")))

(define (golden-update)
  "Write the pages the renderers produce now over the golden ones.

Run this when the change is the one that was wanted, then read the diff it
leaves in `test/golden/' before committing it."
  (run (list "emacs" "-Q" "--batch" "-l" "test/heks-emacs-golden.el")
       #:env '("HEKS_GOLDEN_UPDATE=1")))

(define (stats)
  "Print the configuration's line and decision counts.

A report rather than a check: how many lines the modules, the other
configuration files, the tests and the snippets have, how many of those
lines are blank or comments, and how many decision points the top-level
definitions of the modules contain.  This is what refreshes the numbers
in the README."
  (run (list "emacs" "-Q" "--batch" "-l" "test/heks-emacs-stats.el")))

(define (check)
  "Everything: parse the source, then check the installed configuration."
  (lint)
  (keys)
  (render)
  (test)
  (golden)
  (verify))
