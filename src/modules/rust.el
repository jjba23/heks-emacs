;;; rust.el --- Rust: Cargo, its tools, and a debugged Rust program -*- lexical-binding: t -*-

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>


;;; Commentary:

;; Rust: Cargo, its tools, and a debugged Rust program.
;;
;; The JVM has a topic of its own (`C-c j') because a JVM project is built
;; by a tool that is not the language's compiler, and Rust is the same
;; shape: `cargo' is what builds, tests, lints, formats, runs and documents
;; a crate, and every one of those is a key here rather than a command
;; remembered.  The letters are the scheme's own: `b' builds, `t' tests,
;; `v' validates (that is `cargo check', the faster half of a build), `l'
;; lints with clippy, `f' formats, `r' runs, `a' adds a dependency, `u'
;; updates them, `T' is the dependency tree, `D' the documentation, `c'
;; cleans and `d' debugs -- `c' being clean here exactly as it is under
;; `C-c j', which is what makes the two build-tool topics one habit.
;;
;; Everything runs through `compile', so a Rust build is the same
;; compilation buffer as a C or a Maven one: `C-c ! n' walks the errors,
;; `g' runs it again, and Emacs' own `rust' rule in
;; `compilation-error-regexp-alist' turns `error[E0308]' and the `-->'
;; line under it into a link to the file and line.  Nextest's and rus'
;; panics are read by the `rust-panic' rule beside it.
;;
;; The debugger is dape, like the other natives: `C-c R d' builds the crate
;; with `cargo build' (dape waits for the build before it starts), picks
;; the binary the crate's own manifest says it produces, and attaches
;; `lldb-dap' when the machine has it, a gdb that speaks the Debug Adapter
;; Protocol otherwise.  Stepping is then `C-c b n', `C-c b i', `C-c b o'
;; and `C-c b c' like every other debuggee -- see `modules/dev-formats.el'.

;;; Code:

(require 'seq)
(require 'subr-x)
(require 'json)

(defconst heks/rust-manifest "Cargo.toml"
  "The file that makes a directory a crate.

A crate is what has one of these at its root, which is the only
definition worth using: `cargo' itself looks no higher than the nearest
one, and a workspace's manifest at the top of a checkout is a different
crate from the member the buffer is in.")

;;;
;;; Finding the crate
;;;

(defun heks/rust-root (&optional directory)
  "Return the directory of the crate DIRECTORY is in, or nil.

The nearest manifest is the answer, because that is the crate the file
belongs to -- walking up from a workspace member finds the member rather
than the workspace, which is what `cargo' does too."
  (heks/parent-with heks/rust-manifest directory))

(defun heks/rust--cargo (arguments &optional environment)
  "Run `cargo ARGUMENTS' in this buffer's crate, and say what it said.

The run is `heks/run-task', so ARGUMENTS is a list of strings quoted one
by one, ENVIRONMENT is a literal assignment in front of the command
(`RUST_BACKTRACE=1'), and the output goes to a compilation buffer, which
is where every other build in this configuration goes and where the
errors are links."
  (heks/run-task "cargo" arguments environment heks/rust-manifest))

(defun heks/rust-build ()
  "Build this buffer's crate."
  (interactive)
  (heks/rust--cargo '("build")))

(defun heks/rust-build-release ()
  "Build this buffer's crate, optimised.

The other half of the pair `b' and `B' are everywhere in the scheme: what
`b' builds is what the debugger wants, and what `B' builds is what ships."
  (interactive)
  (heks/rust--cargo '("build" "--release")))

(defun heks/rust-check ()
  "Type-check this crate without producing a binary.

It is the faster half of a build and the one to run on every save caught
by hand: the borrow checker's complaints are the same ones `cargo build'
would make, without the code generation."
  (interactive)
  (heks/rust--cargo '("check")))

(defun heks/rust-clippy ()
  "Lint this crate with clippy, tests and examples included.

`--all-targets' is what clippy's own documentation asks for when the
question is the whole crate: without it the tests and the examples are
not linted, and they are code too."
  (interactive)
  (heks/rust--cargo '("clippy" "--all-targets")))

(defun heks/rust-fmt ()
  "Format this crate with `cargo fmt'."
  (interactive)
  (heks/rust--cargo '("fmt")))

(defun heks/rust-test (&optional nocapture)
  "Run the tests of this crate.

With a prefix argument the tests are told to keep printing
(`-- --nocapture'), which is what shows the output of a failing test
while it fails rather than after it finished."
  (interactive "P")
  (heks/rust--cargo (if nocapture
                        '("test" "--" "--nocapture")
                      '("test"))))

(defun heks/rust-run (&optional arguments)
  "Run this crate's program, with ARGUMENTS after a prefix argument.

`RUST_BACKTRACE=1' is set for the run: a panic then prints the frames it
came through instead of the note that says to set it and try again, which
is the first thing one does after seeing a panic anyway."
  (interactive
   (list (when current-prefix-arg
           (split-string (read-string "Arguments: ") " " t))))
  (heks/rust--cargo (append '("run" "--") arguments) "RUST_BACKTRACE=1"))

(defun heks/rust-clean ()
  "Delete this crate's build output."
  (interactive)
  (heks/rust--cargo '("clean")))

(defun heks/rust-add (crate)
  "Add CRATE as a dependency, the way `cargo add' does it."
  (interactive (list (read-string "Crate: ")))
  (when (string-empty-p crate)
    (user-error "No crate named"))
  (heks/rust--cargo (list "add" crate)))

(defun heks/rust-update ()
  "Update the dependencies of this crate, within `Cargo.toml'."
  (interactive)
  (heks/rust--cargo '("update")))

(defun heks/rust-tree ()
  "Show the dependency tree of this crate."
  (interactive)
  (heks/rust--cargo '("tree")))

(defun heks/rust-doc ()
  "Build this crate's documentation and open it in the browser.

`--no-deps' documents this crate alone, which is what one opened the key
for; a crate whose dependencies have no documentation of their own fails
`cargo doc' without it."
  (interactive)
  (heks/rust--cargo '("doc" "--no-deps" "--open")))

;;;
;;; Debugging the program the crate produces
;;;

(defcustom heks/rust-debug-program nil
  "The program `heks/rust-debug' starts, or nil to take cargo's answer.

Cargo knows which targets are binaries and where it puts them, and this
asks it (see `heks/rust-metadata') -- so nil is the right answer for
almost every crate.  A prefix argument to `heks/rust-debug' asks for a
file instead, and this is the setting for a program whose launch the
debugger has to be told about every time."
  :type '(choice (const :tag "ask cargo" nil)
                 (file :tag "a program"))
  :group 'heks)

(defcustom heks/rust-debug-args nil
  "The arguments `heks/rust-debug' gives the program, in order."
  :type '(repeat string)
  :group 'heks)

(defcustom heks/rust-debug-adapter 'auto
  "Which debugger `heks/rust-debug' drives a Rust program with.

`auto' is the order they are worth trying on a Rust program:
`lldb-dap', which Rust's own tooling documents and which reads Rust's
types without help; then the older `lldb-vscode'; then a `gdb' that speaks
the Debug Adapter Protocol.  Naming one makes the key use that one, or
fall back to GUD with `rust-gdb' when it is not on this machine -- which is
what a machine with several installed wants when its answer is not the
first one."
  :type '(choice (const :tag "the first one installed" auto)
                 (const :tag "lldb, over the Debug Adapter Protocol" lldb-dap)
                 (const :tag "lldb-vscode, the older name" lldb-vscode)
                 (const :tag "gdb, over the Debug Adapter Protocol" gdb)
                 (const :tag "GUD with rust-gdb" gud))
  :group 'heks)

(defun heks/rust-metadata (&optional root)
  "Return `cargo metadata' for ROOT as the alist it prints, or nil.

`--no-deps' is what keeps this cheap: the crates.io registry is not read
and no dependency is resolved, so the answer is this workspace's own
packages and the directory their build goes in.  A machine without cargo
answers nil, and the caller says so rather than guessing a path."
  (let ((default-directory (file-name-as-directory
                            (or root (heks/rust-root) default-directory))))
    (when (executable-find "cargo")
      (with-temp-buffer
        (when (zerop (call-process "cargo" nil t nil "--quiet" "--no-deps"
                                   "--format-version" "1" "metadata"))
          (ignore-errors
            (json-parse-buffer :object-type 'alist :array-type 'list
                               :null-object nil :false-object nil)))))))

(defun heks/rust--package (metadata root)
  "Return the package of METADATA that ROOT's manifest belongs to."
  (let ((manifest (expand-file-name heks/rust-manifest root))
        (packages (alist-get 'packages metadata)))
    (or (seq-find (lambda (package)
                    (equal (expand-file-name (alist-get 'manifest_path package))
                           manifest))
                  packages)
        (let ((default (car (alist-get 'workspace_default_members metadata))))
          (and default
               (seq-find (lambda (package)
                           (equal (alist-get 'id package) default))
                         packages)))
        (car packages))))

(defun heks/rust--bin (package &optional buffer-file)
  "Return the binary target of PACKAGE that BUFFER-FILE is in, or the first.

A crate can hold several binaries.  The one whose source the buffer is in
is the one being worked on; failing that, the one named after the crate,
which is what a crate called `app' with `src/main.rs' has; failing that,
the first, because a debugger with the wrong binary is better than a key
that asks a question nobody expected."
  (let ((bins (seq-filter (lambda (target)
                            (member "bin" (alist-get 'kind target)))
                          (alist-get 'targets package))))
    (or (seq-find (lambda (target)
                    (and buffer-file
                         (equal (expand-file-name (alist-get 'src_path target))
                                (expand-file-name buffer-file))))
                  bins)
        (seq-find (lambda (target)
                    (equal (alist-get 'name target) (alist-get 'name package)))
                  bins)
        (car bins))))

(defun heks/rust-program-from (metadata root &optional buffer-file)
  "Return the program METADATA says ROOT's build produced, or nil.

The answer is `target_directory'/debug/`name', which is where cargo puts
a debug binary: `target_directory' is the workspace's (`target/' beside
the top manifest, unless it was moved), and the name is the binary
target's, which is the crate's only when the target was not renamed."
  (let ((package (heks/rust--package metadata root)))
    (when package
      (let ((bin (heks/rust--bin package buffer-file))
            (target (alist-get 'target_directory metadata)))
        (and bin target
             (expand-file-name (concat "debug/" (alist-get 'name bin))
                               target))))))

(defun heks/rust-program (&optional root)
  "Return the program this buffer's crate builds, or nil."
  (let ((root (or root (heks/rust-root))))
    (or heks/rust-debug-program
        (when root
          (when-let* ((metadata (heks/rust-metadata root)))
            (heks/rust-program-from metadata root buffer-file-name))))))

(defun heks/rust-adapter ()
  "Return the name of the dape configuration that can drive a Rust program.

`heks/rust-debug-adapter' decides: `auto' takes `lldb-dap', then the older
`lldb-vscode', then `gdb' if the gdb on this machine speaks the Debug
Adapter Protocol (14.1 and later).  A named adapter is used when its
program is here, and nothing here answers nil, which is GUD with
`rust-gdb' -- gdb with Rust's pretty printers loaded."
  (let ((chosen heks/rust-debug-adapter))
    (cond ((eq chosen 'gud) nil)
          ((not (eq chosen 'auto))
           (and (executable-find (symbol-name chosen))
                (if (eq chosen 'gdb)
                    (and (fboundp 'heks/c-debug--dap-capable-p)
                         (heks/c-debug--dap-capable-p))
                  t)
                chosen))
          ((executable-find "lldb-dap") 'lldb-dap)
          ((executable-find "lldb-vscode") 'lldb-vscode)
          ((and (fboundp 'heks/c-debug--dap-capable-p)
                (heks/c-debug--dap-capable-p))
           'gdb)
          (t nil))))

(defun heks/rust-debug (&optional program)
  "Debug the Rust program of this crate.

The crate is rebuilt first -- `cargo build', run by dape and waited for --
because a session on a binary from before the edit is the classic way to
chase a bug that is no longer there.  Which program to start is the
manifest's answer (see `heks/rust-program'), and a prefix argument asks
for a file instead.

The session is a dape one, so the keys are the ones every other debuggee
answers to: `C-c b b' breaks, `C-c b c' continues, `C-c b n' steps over,
`C-c b i' into and `C-c b o' out of, `C-c b r' is the debugger's prompt
and `C-c b k' ends the session."
  (interactive
   (list (when current-prefix-arg
           (read-file-name "Program: " (or (heks/rust-root) default-directory)
                           nil t (heks/rust-program)))))
  (require 'dape)
  (let* ((root (or (heks/rust-root)
                   (user-error "No %s above %s" heks/rust-manifest
                               default-directory)))
         (program (expand-file-name
                   (or program
                       (heks/rust-program root)
                       (read-file-name "Program: " root nil t))))
         (adapter (heks/rust-adapter)))
    (if (null adapter)
        (heks/debug--gud program heks/rust-debug-args root nil
                         (if (executable-find "rust-gdb") "rust-gdb" "gdb"))
      (let ((config (copy-tree (alist-get adapter dape-configs))))
        (unless config
          (user-error "This dape has no `%s' configuration; update dape" adapter))
        (setq config (plist-put config :program program))
        (setq config (plist-put config :args (vconcat heks/rust-debug-args)))
        (setq config (plist-put config :cwd root))
        (setq config (plist-put config 'compile "cargo build"))
        (let ((default-directory (file-name-as-directory root)))
          (dape config))))))

;;;
;;; The keys
;;;

;; Cargo is the crate's tool wherever the buffer is, so the keys are global
;; rather than bound to a Rust buffer's map: a `Cargo.toml', a `.rs' file, a
;; README that says what to run -- the crate is found from any of them
;; (`heks/rust-root' walks up to the manifest), and the key says why when
;; there is none.

(keymap-set global-map "C-c R b" #'heks/rust-build)
(keymap-set global-map "C-c R B" #'heks/rust-build-release)
(keymap-set global-map "C-c R t" #'heks/rust-test)
(keymap-set global-map "C-c R v" #'heks/rust-check)
(keymap-set global-map "C-c R l" #'heks/rust-clippy)
(keymap-set global-map "C-c R f" #'heks/rust-fmt)
(keymap-set global-map "C-c R r" #'heks/rust-run)
(keymap-set global-map "C-c R c" #'heks/rust-clean)
(keymap-set global-map "C-c R a" #'heks/rust-add)
(keymap-set global-map "C-c R u" #'heks/rust-update)
(keymap-set global-map "C-c R T" #'heks/rust-tree)
(keymap-set global-map "C-c R D" #'heks/rust-doc)
(keymap-set global-map "C-c R d" #'heks/rust-debug)

(provide 'heks/rust)

;;; rust.el ends here
