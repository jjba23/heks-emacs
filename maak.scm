;;; heks-emacs

;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (maak)
  #:declarative? #t
  #:use-module (maak maak)
  #:use-module ((ice-9 rdelim) #:select (read-line)))

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

;; ====== Agent skills ======

;; AGENTS.md is generated, never edited by hand.  The section has two halves:
;; the data below, which is this project's, and the task itself, which is not.
;; Another repository copies the whole section and replaces the data - the
;; header, the pinned skills (repository, commit, path, licence) and the
;; practices - and `maak agents' writes its own AGENTS.md.  Regeneration is
;; deterministic: the same pins and the same text produce the same file, byte
;; for byte, and it needs nothing but curl.  The skill URLs assume GitHub, so a
;; skill hosted elsewhere needs a URL of its own.

(define ponytail-commit
  "96608e078b2d5ea607c5c3b8b5a54d1c1fba6846")

(define tdd-commit
  "22f0b463e7a5e579904dd6211a520321035526f7")

;; Name, repository, commit, the path the repository keeps the skill at and the
;; licence.  A skill arrives whole: trimming it means scanning for headings, and
;; such a scan cannot tell a heading from a `##' line inside a code fence.
(define agent-skills
  (list (list "ponytail"
              "DietrichGebert/ponytail"
              ponytail-commit
              "skills/ponytail/SKILL.md"
              "MIT")
        (list "test-driven-development"
              "obra/superpowers"
              tdd-commit
              "skills/test-driven-development/SKILL.md"
              "MIT")))

(define agent-skills-dir
  "reports/agent-skills")

(define agents-header
  "# AGENTS.md

Generated by `maak agents` from the pinned skills and the practices in
`maak.scm`; edit that task, never this file.  The pins and the text are the whole
input, so regenerating gives the same document.  The repository's own rules win
over general advice, and the narrowest rule here wins over the broadest.
")

;; Practices this project keeps.  They are short on purpose: a rule a reader
;; checks in a second is a rule that gets followed.  The pinned skills are the
;; long form of the same habits.
(define agent-practices
  (list
   "## Documentation

- Every user-visible change reaches the documentation: the page that owns the
  feature, the manual page for a flag or an environment variable, and the
  release notes under the unreleased heading.
- Keep the table of contents in step with the headings.  A section with no entry
  is a section nobody finds.
- The guide is Org: one `*` heading per page, `**` for sections, `#+TITLE` and
  `#+EMAIL` at the top, a `CUSTOM_ID` on anything linked from elsewhere, and
  `file:` links between pages.
- Explain why and when, never what: the code already says what.  A docstring's
  first line works as a summary on its own.
- Spell an identifier the way the code spells it - the exact name, not a
  description of it.
- An example must run as written, copied from a real invocation.
- No promises about the future and no changelog in the guide; history lives in
  the release notes.
"
   "## Security

- No secrets in the tree.  Tokens, keys and passwords arrive through the
  environment, and no recipe, workflow or example embeds one.
- Validate at the edge: anything from a file, a report, a path or a subprocess
  is untrusted until it has been checked.
- Never build a shell string out of data.  Tasks pass argument lists, and Guile
  calls `(system \"program\" \"arg\")` or `open-pipe*`, never a command
  assembled with `string-append`.
- Do not `eval` or `read` input you did not write; parse with `(json)` or a
  reader built for the format.
- Escape what leaves the process: a name that came from input is escaped when
  it is written to XML, HTML or a data file.
- Fail closed.  A file that cannot be read is an error, not an empty result.
- Input never chooses the path of a written file; writes stay inside the
  directory reserved for them.
- A dependency is a security decision: it must be needed, MIT compatible and
  pinned.
- Report a vulnerability privately, not in a public issue.
"
   "## Performance

- Measure first.  A before and after belongs in the benchmark, and a speedup
  claimed without a number is not a speedup.
- Prefer not doing the work: cache it, skip it, batch it, or delete the call,
  before making the call faster.
- Then the algorithm, then the data structure (hash table, vector), then the
  micro-optimisation.  In that order, for that reason.
- Guile specifics: keep module resolution and long `assoc` chains out of loops,
  use `#:declarative?` modules and compiled `.go` files at startup, and reach
  for `statprof` instead of guessing where the time goes.
- A shortcut that buys speed costs clarity; it gets a measurement and a
  `shortcut:` comment saying what it costs and when to revisit it.
- Coverage instrumentation is slow by design: iterate without it, and measure
  before finishing.
"
   "## Architecture decisions

- A decision that is expensive to reverse gets a short record: the context, the
  decision, the consequences, and the alternatives that lost.  A small decision
  belongs in the commit body instead.
- Two paragraphs beat a design document; record the choice while it is still a
  choice, not after it has become a fact.
- An accepted record is not rewritten.  Supersede it with a new one and link the
  two directions.
- The record lives next to its subject: the documentation for anything a user
  would notice, the release notes for the release-level result.
- Changes to the public API, a file format, the pipeline or the licence get this
  treatment at a minimum in the commit body.
"
   "## Semantic versioning

- The project follows SemVer 2.0.0 for its public API: the exported functions,
  the CLI flags and environment variables, and the shape of its file formats.
- A breaking change bumps MAJOR, a new feature MINOR, a fix PATCH.  A new export
  is MINOR; removing or changing one is MAJOR.
- One version string, named everywhere it appears: the source, the build
  recipes, the manual page and the packaging.
- A release is a dated release-notes section, an annotated `vX.Y.Z` tag on the
  release commit, and a packaging checksum updated afterwards from the published
  archive.
"
   "## Conventional commits

- `type(scope): summary`, imperative, lower case, no full stop, about seventy
  characters.
- Types in use: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`, `ci`,
  `chore`.  A `!` after the type or a `BREAKING CHANGE:` footer marks a MAJOR
  change, and says what breaks.
- The subject says what changed.  The body says why, and what was rejected.
- One logical change per commit: a refactor and a fix travel apart, so either
  can be reverted alone.
- Run the full validation task before committing, and never commit a red suite
  without saying so in the message.
- Reference the issue in the footer - `Closes #12` - not in the subject.
"
   "## Functional programming and immutability

- Pure functions in the core, effects at the edges.  Whatever touches the file
  system or the clock sits at the edge; the core does not.
- Prefer `let` and new values to `set!`.  Build results with `map`, `filter`,
  `fold` and named `let`, not with index loops that push into a list.
- A record is a value: construct a new one instead of mutating a shared one, and
  pass configuration as arguments or parameters rather than as globals.
- Handle an exception at the boundary: catch it there, turn it into a result
  record, and let the caller decide what it means.
- A function that both computes and prints is two functions.
- Temporary effects - a changed directory, a bound environment variable - go
  through `dynamic-wind`.
- Prefer the expression style: `if` and `cond` that return a value, not a branch
  that assigns one.
"
   "## Do not reinvent the wheel

- Guile's standard library first: `(ice-9 ...)` for the runtime, `(srfi srfi-1)`
  for lists, `(srfi srfi-9)` for records, `(srfi srfi-13)` for strings, `(json)`
  for JSON.  The project already depends on all of them.
- Then this codebase: read the existing modules before writing a helper, and use
  the one that is nearly right instead of adding a second one.
- A new dependency needs a reason the standard library cannot meet, a licence
  the project can carry, and a paragraph in the commit body.
- Prefer deleting a special case to writing code that handles it.
- The best diff removes lines and keeps the behaviour; the second best is a
  small diff that is obvious a year later.
"))

(define (slurp path)
  "Return the whole of @var{path} as a string."
  (call-with-input-file path
    (lambda (port)
      (let loop ((lines '())
                 (line (read-line port)))
        (if (eof-object? line)
            (string-concatenate-reverse lines)
            (loop (cons (string-append line "\n") lines)
                  (read-line port)))))))

(define (fetch-skill name repository commit path)
  "Download one skill pinned at @var{commit}, into the reports tree.

  Returns the skill's text."
  (let ((target (~ "~a/~a.md" agent-skills-dir name))
        (url (~ "https://raw.githubusercontent.com/~a/~a/~a"
                repository commit path)))
    (run (list "curl" "--fail" "--silent" "--show-error" "--location"
               "--output" target url)
         #:verbose? #t)
    (slurp target)))

(define (agents)
  "Regenerate AGENTS.md from the pinned skills and the practices."
  (run (list "mkdir" "-p" agent-skills-dir))
  ;; Every download happens before the file is opened, so a fetch that fails
  ;; leaves the previous AGENTS.md in place rather than a half-written one.
  (let ((skills (map (lambda (skill)
                       (append skill
                               (list (fetch-skill (list-ref skill 0)
                                                  (list-ref skill 1)
                                                  (list-ref skill 2)
                                                  (list-ref skill 3)))))
                     agent-skills)))
    (call-with-output-file "AGENTS.md"
      (lambda (port)
        (display agents-header port)
        (for-each (lambda (skill)
                    (format port
                            "~%## ~a~%~%`~a` at `~a`, `~a`, ~a licensed.~%~%"
                            (list-ref skill 0)
                            (list-ref skill 1)
                            (list-ref skill 2)
                            (list-ref skill 3)
                            (list-ref skill 4))
                    (display (list-ref skill 5) port))
                  skills)
        (for-each (lambda (practice)
                    (newline port)
                    (display practice port))
                  agent-practices)))))
