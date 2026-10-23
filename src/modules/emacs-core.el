;;; emacs-core.el --- Configuring Emacs core -*- lexical-binding: t -*-

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

;;; Commentary:

;; Configuring Emacs core
;; This file establishes the baseline behavior for Emacs

;;; Code:

;;
;; ====== The key scheme ======
;;
;; Everything this configuration adds lives under `C-c': one letter for
;; the topic, then a letter for the action.  Two rules keep a map of a
;; few hundred keys learnable, and they are written down here because a
;; binding nobody can describe is a binding nobody uses:
;;
;;   * a topic letter means one thing, everywhere (`d' is databases and
;;     only databases; direnv and Docker used to live there too) -- and a
;;     topic may be a modified stroke, such as `C-#', when a mode's own
;;     key would otherwise sit in the topic's way;
;;   * an action letter means the same thing under every topic: `f'
;;     formats, `t' tests, `d' debugs, `b' builds, `r' runs or opens a
;;     REPL, `e' evaluates, `g' goes to a definition, `h' explains, `c'
;;     lists callers, `i' inserts, `k' kills, `l' lints, `n' creates,
;;     `v' views, `a' applies.
;;
;; So `C-c g f' formats a Scheme file with Guix, `C-c i f' formats
;; whatever buffer is current, and `C-c j t' runs the tests of a JVM
;; project.
;;
;; Some topics key something that is not one of those verbs at all, and
;; the letter is then the first letter of what it names: the font sizes
;; (`C-c f t' is tiny, `C-c f c' colossal), what the system topic
;; reconfigures (`C-c # j' is his own configuration, `C-c # s' the
;; system), what the notes topic opens (`C-c n f' finds a note, `C-c n c'
;; the journal entry for today).  Those letters are written down per
;; topic in `heks/key-letters' rather than being pushed into the
;; action alphabet until it means everything and nothing -- which is what
;; `i' had come to mean, with a key for the implementation and a key for
;; an interrupt under it.
;;
;; The tables below are the scheme: what each topic is for
;; (`heks/key-topics'), what each action letter means everywhere
;; (`heks/key-actions'), what a topic means by a letter of its own
;; (`heks/key-letters'), and what each individual key does in its
;; own words (`heks/key-descriptions').
;;
;; The last table exists because a letter can only say so much: `C-c i f'
;; and `C-c j f' both format, but `C-c i f' is "the buffer, formatted by
;; whoever knows how" and a key that said only "format" would leave the
;; reader to guess which of the two formatters answers.  Every key under
;; `C-c' has an entry, which is what the reference prints and what
;; `which-key' shows while the key is being typed.
;;
;; `test/heks-emacs-keys.el' reads all four, prints the whole key tree
;; with the meaning of every key, writes `docs/keybindings.org' -- the
;; reference to read -- and refuses a binding whose topic is not
;; described here, that disagrees with another binding of the same key,
;; whose command does not exist, whose letters are in no table, or that
;; has no description of its own.

(defconst heks/key-topics
  '(("!"     . "diagnostics: Flymake")
    ("#"     . "system: this machine and the Guix system")
    ("C-#"   . "Org statistics cookies, kept off `C-c #'")
    (";"     . "diary")
    ("C-d"   . "diagrams: Mermaid")
    ("SPC"   . "dashboard")
    ("a"     . "API and HTTP: OpenAPI specs and requests")
    ("b"     . "breakpoints and the debugger: dape")
    ("c"     . "containers: Docker")
    ("d"     . "databases: PostgreSQL and MongoDB")
    ("e"     . "environment: direnv")
    ("f"     . "fonts and text size")
    ("g"     . "Guile and Guix")
    ("h"     . "help and documentation")
    ("i"     . "IDE: language server, formatting, diagnostics")
    ("j"     . "JVM: Maven, Gradle, Spring, Java and Kotlin")
    ("l"     . "Emacs itself: evaluating and debugging Elisp")
    ("m"     . "make-style tasks: maak")
    ("n"     . "notes: Org notes")
    ("o"     . "mail: Gnus")
    ("p"     . "completion at point: cape")
    ("r"     . "render, preview and present")
    ("s"     . "snippets and recorded macros")
    ("t"     . "text tools")
    ("u"     . "Kubernetes: kubed, by its own mnemonic letters")
    ("U"     . "Kubernetes: kubed, from a menu")
    ("v"     . "view: folding and comparisons")
    ("w"     . "workspace and project: running it, and Terraform")
    ("x"     . "eca: the AI coding assistant")
    ("z"     . "the thing at point: the region grown, the symbol lit up, a place jumped to")
    ("C-f"   . "JSON log view: filtering, kept off `C-c f' (font sizes)")
    ("C-g"   . "JSON log view: filtering by raw text, kept off `C-c g' (Guile and Guix)")
    ("C-c"   . "JSON log view: clearing the filter")
    ("C-t"   . "JSON log view: the menu of its own commands"))
  "What each `C-c' topic letter is for.

A capital letter is a topic of its own and not a variant of the small
one: `C-c C-d' is the diagrams where `C-c d' is the databases.

Read by `test/heks-emacs-keys.el', which fails when a key uses a topic
that is not described here.")

(defconst heks/key-actions
  '(("a" . "apply an action, or add something")
    ("b" . "build")
    ("c" . "show the callers of this definition")
    ("d" . "debug, or the difference between two things")
    ("e" . "evaluate")
    ("f" . "format")
    ("g" . "go to: a definition, an implementation, a location")
    ("h" . "explain: the documentation of what is at point")
    ("i" . "insert")
    ("k" . "kill: stop a process or a server")
    ("l" . "lint, or list the problems")
    ("m" . "a menu, or turn the mode on and off")
    ("n" . "new, or next")
    ("o" . "open")
    ("p" . "preview, or previous")
    ("r" . "run, or open a REPL")
    ("s" . "send to a REPL, or switch")
    ("t" . "test")
    ("u" . "update")
    ("v" . "view, or validate")
    ("w" . "write, or work on")
    ("x" . "execute a script"))
  "What each action letter means under every topic.

An action letter is one meaning in every topic that uses it.  A topic
that keys something other than an action says so in
`heks/key-letters', and the two together are what every key under
`C-c' is held to; an uppercase letter is the further one of a pair (`C-c
g E' evaluates more than `C-c g e', `C-c v C' closes everything where
`C-c v c' closes one fold).")

(defconst heks/key-letters
  '(("!" ("n" . "the next diagnostic")
         ("N" . "the previous diagnostic")
         ("b" . "the diagnostics of this buffer")
         ("a" . "all the diagnostics of the project"))
    ("#" ("j" . "his own configuration")
         ("s" . "the system")
         ("e" . "this file, edited as root")
         ("f" . "everything: his configuration and the system"))
    (";" ("v" . "the entry for today")
         ("g" . "the entry for yesterday"))
    ("C-d" ("c" . "the diagram at point")
           ("r" . "the diagram in the region")
           ("b" . "the diagrams in this buffer")
           ("f" . "the diagrams in this file"))
    ("a" ("b" . "the request written as a block to paste"))
    ("b" ("b" . "a breakpoint at point, toggled")
         ("c" . "the program, continued to the next breakpoint")
         ("i" . "into the call at point, stepped")
         ("o" . "out of the current function, stepped"))
    ("c" ("d" . "Docker"))
    ("d" ("p" . "PostgreSQL")
         ("m" . "the MongoDB shell"))
    ("e" ("a" . "allow this `.envrc'")
         ("d" . "direnv, in every buffer"))
    ("f" ("c" . "colossal")
         ("j" . "jumbo")
         ("l" . "large")
         ("L" . "larger")
         ("n" . "nano")
         ("r" . "regular")
         ("s" . "small")
         ("t" . "tiny"))
    ("g" ("b" . "the whole buffer, sent to the REPL")
         ("L" . "lint it with `guix lint'")
         ("S" . "apply one of `guix style''s rules")
         ("p" . "the package at the mark")
         ("R" . "restart it")
         ("E" . "the region, or the whole buffer")
         ("C" . "the callees of this definition"))
    ("h" ("f" . "the function at point, as `C-h f'")
         ("v" . "the variable at point, as `C-h v'")
         ("k" . "the key at point, as `C-h k'")
         ("F" . "the face at point"))
    ("i" ("e" . "Eglot itself, and what it is doing")
         ("E" . "the server's log of messages")
         ("r" . "rename the symbol at point")
         ("R" . "restart the language server")
         ("s" . "the schema line this file names")
         ("h" . "the server's inlay hints, on and off"))
    ("j" ("m" . "Maven")
         ("M" . "the Maven menu")
         ("g" . "Gradle")
         ("G" . "the Gradle menu")
         ("s" . "Spring Boot")
         ("N" . "a new project")
         ("B" . "the project, built again")
         ("D" . "the dependencies of this project")
         ("T" . "the tree of this project's dependencies")
         ("R" . "the project's classpath, reloaded"))
    ("l" ("l" . "a library, opened by name")
         ("L" . "a library, loaded from disk")
         ("p" . "the parentheses of this buffer"))
    ("n" ("a" . "an archived note, opened")
         ("b" . "a bookmark, opened")
         ("B" . "a bookmark, filed under a category")
         ("c" . "a note, captured from anywhere")
         ("d" . "today: the agenda, its habits and the inbox")
         ("e" . "text added to an existing note")
         ("f" . "a note, found")
         ("g" . "the notes as a graph and a tree, in the browser")
         ("G" . "the map of the notes, exported as one HTML page")
         ("F" . "a note, found or created")
         ("h" . "the habits, with their graphs")
         ("i" . "a link to a note, inserted")
         ("I" . "the index pages, regenerated")
         ("k" . "a contact, found")
         ("K" . "a contact, added")
         ("l" . "the notes that link here")
         ("n" . "a new note, opened for writing")
         ("r" . "this note, moved to another topic")
         ("s" . "the text of every note, searched")
         ("t" . "a topic folder, opened")
         ("T" . "the topics as a folding outline")
         ("u" . "the birthdays coming up")
         ("x" . "a todo, captured into the inbox")
         ("X" . "a habit, captured")
         ("A" . "the agenda: every note's dates and TODOs, in one list")
         ;; `m' is the Markdown a note is made from rather than a menu:
         ;; an import is not a mode to turn on and off.
         ("m" . "a Markdown file, imported as an Org note")
         ("M" . "a region of Markdown, converted to Org"))
    ("o" ("m" . "Gnus itself")
         ("g" . "a group, read once"))
    ("r" ("b" . "the browser")
         ("d" . "the deck, in the browser")
         ("D" . "the deck, written next to the file")
         ("e" . "keep it as a file")
         ("m" . "follow the buffer, re-rendering on save")
         ("n" . "a slide boundary, inserted")
         ("P" . "the buffer, presented")
         ("r" . "render it again"))
    ("s" ("a" . "an alist accessor out of a string one")
         ("c" . "the snippet at point, completed")
         ("h" . "a hygguile class set out of a list of classes")
         ("p" . "a parameter out of a value")
         ("x" . "the named snippet, expanded"))
    ("t" ("a" . "the lines, sorted")
         ("c" . "the fill column indicator")
         ("o" . "Olivetti, writing in the middle of the window")
         ("r" . "colour names, shown as colours")
         ("w" . "the whitespace at the end of the lines")
         ("y" . "the marked files' contents, copied"))
    ("v" ("c" . "this fold")
         ("C" . "every fold")
         ("o" . "this fold, opened")
         ("O" . "this fold and everything under it")
         ("r" . "every fold, revealed")
         ("d" . "the difference between two buffers")
         ("D" . "the code this project writes more than once")
         ("t" . "the fold at point, toggled"))
    ("w" ("c" . "a repository, cloned")
         ("d" . "the development server")
         ("D" . "the infrastructure, destroyed")
         ("g" . "a search of the project")
         ("i" . "the providers and state, initialised")
         ("s" . "a random order for the standup"))
    ("x" ("t" . "the chat window, shown or hidden")
         ("m" . "the model, chosen")
         ("p" . "the provider, chosen"))
    ("z" ("e" . "the region, grown to the next thing around it")
         ("s" . "the region, shrunk back to what it was")
         ("o" . "the symbol at point, lit up at every occurrence")
         ("n" . "the next occurrence of it")
         ("p" . "the previous occurrence of it")
         ("r" . "every occurrence of it, renamed at once")
         ("k" . "the lighting, taken off")
         ("j" . "a place on the screen, jumped to by its letter")
         ("J" . "a line, jumped to by its letter")))
  "What the letters of a topic mean, topic by topic.

These are the topics whose keys do not perform one of the actions in
`heks/key-actions': the letter is the first letter of what the key
names.  A topic can also say here that it means something of its own by
an action letter -- `C-c w i' initialises Terraform where `i' inserts
everywhere else -- and the four tables together are what every key under
`C-c' is held to: an entry in `heks/key-descriptions' first, then
this table, then the action alphabet.  Both tables are read by
`test/heks-emacs-keys.el', which fails on a key that has no description
of its own and prints, for every key, what this scheme calls it.")

(defconst heks/key-descriptions
  '(("C-c ! N" . "the previous diagnostic")
    ("C-c ! a" . "all the diagnostics of the project")
    ("C-c ! b" . "the diagnostics of this buffer")
    ("C-c ! m" . "the background checking, on and off")
    ("C-c ! n" . "the next diagnostic")
    ("C-c # f" . "everything: his configuration and the system")
    ("C-c # e" . "this file, edited as root")
    ("C-c # j" . "his own configuration")
    ("C-c # s" . "the system")
    ("C-c # u" . "the packages of the system, updated")
    ("C-c ; g" . "the entry for yesterday")
    ("C-c ; v" . "the entry for today")
    ("C-c C-#" . "the statistics cookies of this outline")
    ("C-c C-d b" . "the diagrams in this buffer")
    ("C-c C-d c" . "the diagram at point")
    ("C-c C-d f" . "the diagrams in this file")
    ("C-c C-d h" . "the Mermaid documentation")
    ("C-c C-d o" . "the rendered diagram in the browser")
    ("C-c C-d r" . "the diagram in the region")
    ("C-c SPC SPC" . "the dashboard")
    ("C-c a b" . "the request written as a block to paste")
    ("C-c a l" . "the spec's problems, listed")
    ("C-c a m" . "the spec, read as a spec")
    ("C-c a r" . "the operation, sent as a live request")
    ("C-c a v" . "the spec, rendered to read")
    ("C-c b b" . "a breakpoint at point, toggled")
    ("C-c b c" . "the program, continued to the next breakpoint")
    ("C-c b i" . "into the call at point, stepped")
    ("C-c b k" . "the debug session, killed")
    ("C-c b n" . "the next line, stepped over")
    ("C-c b o" . "out of the current function, stepped")
    ("C-c b r" . "a REPL into the debuggee")
    ("C-c c d" . "the Docker transient")
    ("C-c d m" . "the MongoDB shell")
    ("C-c d p" . "a PostgreSQL prompt")
    ("C-c e a" . "allow this `.envrc'")
    ("C-c e d" . "direnv, in every buffer")
    ("C-c f L" . "larger")
    ("C-c f c" . "colossal")
    ("C-c f j" . "jumbo")
    ("C-c f l" . "large")
    ("C-c f n" . "nano")
    ("C-c f r" . "regular")
    ("C-c f s" . "small")
    ("C-c f t" . "tiny")
    ("C-c g C" . "the callees of this definition")
    ("C-c g E" . "the region, or the whole buffer")
    ("C-c g L" . "lint it with `guix lint'")
    ("C-c g R" . "the REPL, restarted")
    ("C-c g S" . "apply one of `guix style''s rules")
    ("C-c g b" . "the whole buffer, sent to the REPL")
    ("C-c g c" . "the callers of this definition")
    ("C-c g d" . "the Guile debugger")
    ("C-c g e" . "the definition at point")
    ("C-c g f" . "the buffer, formatted with Guix style")
    ("C-c g g" . "the definition of the symbol at point")
    ("C-c g h" . "the documentation of the symbol at point")
    ("C-c g k" . "the running Guile, interrupted")
    ("C-c g m" . "the generic methods of this symbol")
    ("C-c g o" . "a REPL that is already running")
    ("C-c g p" . "the package at the mark")
    ("C-c g r" . "a Geiser REPL for this project")
    ("C-c g s" . "the REPL, in another module")
    ("C-c g t" . "the tests of this file")
    ("C-c g x" . "this file, run as a script")
    ("C-c h F" . "the face at point")
    ("C-c h f" . "the function at point, as `C-h f'")
    ("C-c h h" . "the documentation of what is at point")
    ("C-c h k" . "the key at point, as `C-h k'")
    ("C-c h v" . "the variable at point, as `C-h v'")
    ("C-c i 0" . "the language server, off in this Emacs")
    ("C-c i 1" . "the language server, on in this Emacs")
    ("C-c i E" . "the server's log of messages")
    ("C-c i R" . "the language server, reconnected")
    ("C-c i a" . "the actions the server offers here")
    ("C-c i e" . "the server, and what it is doing")
    ("C-c i f" . "the buffer, formatted by whoever knows how")
    ("C-c i g" . "the implementation of the symbol at point")
    ("C-c i h" . "the server's hints, inside the source")
    ("C-c i k" . "every language server, stopped")
    ("C-c i m" . "the Eglot menu")
    ("C-c i r" . "the symbol at point, renamed everywhere")
    ("C-c i s" . "the schema line, written into this file")
    ("C-c j B" . "the project, built again")
    ("C-c j G" . "a Gradle task, chosen by what it does")
    ("C-c j M" . "a Maven goal, chosen by what it does")
    ("C-c j N" . "a Java project, created")
    ("C-c j R" . "the project, re-read by its tooling")
    ("C-c j T" . "the dependency tree of this Maven project")
    ("C-c j b" . "a build task of this project")
    ("C-c j c" . "the build output, deleted")
    ("C-c j D" . "the dependencies of this project")
    ("C-c j d" . "debugged, suspended until `dape' attaches")
    ("C-c j g" . "a Gradle task of this project")
    ("C-c j m" . "a Maven goal of this project")
    ("C-c j n" . "a Java file, created")
    ("C-c j p" . "the artefact of this project, built")
    ("C-c j r" . "the main class, run")
    ("C-c j s" . "the Spring Boot application")
    ("C-c j t" . "the tests, run this project's way")
    ("C-c j v" . "every check this project defines")
    ("C-c l L" . "a library, loaded from disk")
    ("C-c l d" . "the debugger, on and off for every error")
    ("C-c l e" . "this buffer, evaluated")
    ("C-c l l" . "a library, opened by name")
    ("C-c l p" . "the parentheses of this buffer, checked")
    ("C-c m r" . "a maak task of this project")
    ("C-c n F" . "a note by title, created when none has it")
    ("C-c n G" . "the map of the notes, exported as one self-contained HTML page")
    ("C-c n T" . "the topics and notes as a folding outline in a buffer")
    ("C-c n I" . "every index page, regenerated from the notes")
    ("C-c n K" . "a contact, added to the contacts file")
    ("C-c n B" . "a bookmark, filed under a category picked with completion")
    ("C-c n X" . "a habit, captured: a todo that repeats")
    ("C-c n a" . "an archived note, from a former employer")
    ("C-c n b" . "a bookmark, picked and opened (prefix: copied; twice: inserted as a link)")
    ("C-c n c" . "capture a note from anywhere: the region (or, with a prefix, the latest kill) filed under a topic you pick, with a link back")
    ("C-c n d" . "today: the day's agenda with habits and birthdays, what is in progress, the inbox")
    ("C-c n e" . "text added to the end of an existing note")
    ("C-c n f" . "a note, found by title")
    ("C-c n g" . "the notes as a smooth graph (links, topics, or both) and a tree, in the browser; clicking a note opens it here")
    ("C-c n h" . "the habits, with their consistency graphs")
    ("C-c n i" . "a link to another note, inserted")
    ("C-c n k" . "a contact, found by name (prefix: inserted as Name <email>)")
    ("C-c n l" . "the notes that link to this one")
    ("C-c n n" . "a new note, opened for writing, in a topic you pick")
    ("C-c n r" . "this note, moved to another topic, its links repaired")
    ("C-c n s" . "the text of every note, searched")
    ("C-c n t" . "a topic folder, opened")
    ("C-c n u" . "the birthdays of the next 60 days")
    ("C-c n x" . "a todo, captured into the inbox from anywhere, linked to where it came from")
    ("C-c n M" . "the region of Markdown, converted to Org")
    ("C-c n m" . "the Markdown file of this buffer, imported as an Org note")
    ("C-c n v" . "links, shown as their text")
    ("C-c n A" . "the agenda: every note's dates and TODOs, in one list")
    ("C-c o g" . "a group, read once")
    ("C-c o m" . "Gnus itself")
    ("C-c p" . "completion at point, and its letters")
    ("C-c r D" . "the deck, kept as a file")
    ("C-c r P" . "this buffer, presented")
    ("C-c r b" . "this document, in the browser")
    ("C-c r d" . "the deck, in the browser")
    ("C-c r e" . "this document, kept as an HTML file")
    ("C-c r m" . "follow the buffer, re-rendering on save")
    ("C-c r n" . "a slide boundary, inserted")
    ("C-c r p" . "this buffer, rendered in Emacs")
    ("C-c r r" . "the preview, rendered again")
    ("C-c r s" . "the preview, moved to the section point is in")
    ("C-c s a" . "an alist accessor out of a string one")
    ("C-c s c" . "the snippet at point, completed")
    ("C-c s h" . "a hygguile class set from classes")
    ("C-c s i" . "a snippet, inserted by name")
    ("C-c s p" . "a parameter out of a value")
    ("C-c s x" . "the snippet name at point, expanded")
    ("C-c t $" . "spell checking, on and off")
    ("C-c t a" . "the lines, sorted")
    ("C-c t c" . "the fill column indicator")
    ("C-c t o" . "writing in the middle of the window")
    ("C-c t r" . "colour names, shown as colours")
    ("C-c t w" . "the whitespace at the end of the lines")
    ("C-c t y" . "the marked files' contents, copied")
    ("C-c t i" . "a UUID, generated")
    ("C-c t n" . "the next TODO or FIXME in this buffer")
    ("C-c t p" . "the previous one")
    ("C-c u" . "kubed's own commands, by mnemonic letter")
    ("C-c U" . "kubed's commands, from a menu")
    ("C-c C-f" . "the log lines in this buffer, filtered by a JSON field")
    ("C-c C-g" . "the log lines in this buffer, filtered by a regexp on their raw text")
    ("C-c C-c" . "the filter on this buffer's log lines, cleared")
    ("C-c C-t" . "the log view commands in this buffer, from a menu")
    ("C-c v C" . "every fold")
    ("C-c v O" . "this fold and everything under it")
    ("C-c v c" . "this fold")
    ("C-c v d" . "two buffers, compared")
    ("C-c v D" . "the code this project writes more than once")
    ("C-c v o" . "this fold, opened")
    ("C-c v r" . "every fold, revealed")
    ("C-c v t" . "the fold at point, toggled")
    ("C-c w D" . "the infrastructure, destroyed")
    ("C-c w G" . "the Git history of the project, summarised")
    ("C-c w a" . "the plan, applied")
    ("C-c w c" . "a repository, cloned")
    ("C-c w d" . "the development server")
    ("C-c w f" . "the project, formatted")
    ("C-c w g" . "a search of the project")
    ("C-c w i" . "the providers and state, initialised")
    ("C-c w l" . "the languages of the project, measured")
    ("C-c w p" . "the change, previewed")
    ("C-c w r" . "a REPL process for this project")
    ("C-c w s" . "a random order for the standup")
    ("C-c w t" . "the project's tests")
    ("C-c w v" . "the Terraform configuration, validated")
    ("C-c x a" . "the context, added to the prompt")
    ("C-c x k" . "the running prompt, stopped")
    ("C-c x m" . "the model, chosen")
    ("C-c x n" . "a new chat")
    ("C-c x p" . "the provider, chosen")
    ("C-c x s" . "a chat, switched to by name")
    ("C-c x t" . "the chat window, shown or hidden")
    ("C-c z e" . "the region, grown to the next thing around it")
    ("C-c z s" . "the region, shrunk back to what it was")
    ("C-c z o" . "the symbol at point, lit up at every occurrence")
    ("C-c z n" . "the next occurrence of it")
    ("C-c z p" . "the previous occurrence of it")
    ("C-c z r" . "every occurrence of it, renamed at once")
    ("C-c z k" . "the lighting, taken off")
    ("C-c z j" . "a place on the screen, jumped to by its letter")
    ("C-c z J" . "a line, jumped to by its letter"))
  "What each key under `C-c' does, in the words of its own topic.

A key here is described by this entry and by nothing else, so the
reference says what the key does rather than trusting the reader to
combine a topic with a letter: `C-c i f' formats, `C-c j f' is a
formatter this configuration does not have, and only a sentence can tell
them apart.  The letter tables above remain the scheme's dictionary --
they are what makes the letters learnable -- and they are the fallback
for a key an entry here has not been written for yet.

Every key under `C-c' has an entry; `test/heks-emacs-keys.el' fails on a
binding that does not, so a key added without one cannot quietly fall
back to its letter's meaning.")

(defconst heks/key-major-mode-descriptions
  '((java-mode ("C-c j b" . "a JDT build task for this project")
               ("C-c j n" . "a Java file, through the language server")
               ("C-c j r" . "the main class, through the language server")
               ("C-c j t" . "the test at point, through the language server"))
    (java-ts-mode ("C-c j b" . "a JDT build task for this project")
                  ("C-c j n" . "a Java file, through the language server")
                  ("C-c j r" . "the main class, through the language server")
                  ("C-c j t" . "the test at point, through the language server")))
  "Keys that mean something else inside one major mode.

Four keys are deliberately two things at once: in a Java buffer the
language server can run and test the program itself, which is more
accurate than asking Maven to do it.  `heks/key-descriptions' says
what such a key does everywhere; this table says what it does in the
buffer where the mode's own map answers first, and `which-key' shows the
right one while the key is being typed.")

(defun heks/key-description (key)
  "Return what KEY does, in the words of the scheme.

This is the one place the four tables are read in order, so that the
reference, `which-key' and a person all get the same answer: the key's
own description, then what its topic means by its letter, then what the
letter means everywhere."
  (let* ((topic (and (string-match "\\`C-c \\([^ ]+\\)" key) (match-string 1 key)))
         (letter (and (string-match "\\`C-c [^ ]+ \\([a-zA-Z]\\)\\'" key)
                      (match-string 1 key))))
    (or (cdr (assoc key heks/key-descriptions #'equal))
        (and topic letter
             (cdr (assoc letter
                         (cdr (assoc topic heks/key-letters #'equal)) #'equal)))
        (and letter (cdr (assoc letter heks/key-actions #'equal)))
        (and topic (cdr (assoc topic heks/key-topics #'equal))))))

(defconst heks/key-root-description
  "this configuration: a letter for the topic, then one for the action"
  "What `C-c' itself says, above the topics of the scheme.

Every other description is a row of a table -- what a key does in its own
words, or what a letter means under a topic -- and this is the one the
scheme has for the root of it, written next to the tables rather than
inside `heks/which-key-setup' so that the length which-key is told
(see `heks/which-key-description-length') measures it too: it is the
longest sentence of them all, and it was the one that arrived cut.")

(defun heks/key-description-texts ()
  "Return every description the scheme has, in one list.

The four tables are read the way `heks/key-description' reads them:
what a topic is for, what an action letter means under a topic that keys
something of its own, what an action letter means everywhere, and what each
key does in its own words -- and `heks/key-root-description', which
is what the tables hang under rather than a row of one."
  (let ((texts (list heks/key-root-description)))
    (dolist (table (list heks/key-topics heks/key-actions
                         heks/key-descriptions))
      (dolist (entry table) (push (cdr entry) texts)))
    (dolist (table (list heks/key-letters heks/key-major-mode-descriptions))
      (dolist (entry table)
        (dolist (inner (cdr entry)) (push (cdr inner) texts))))
    (nreverse texts)))

(defconst heks/which-key-description-length
  (1+ (apply #'max (mapcar #'length (heks/key-description-texts))))
  "The length `which-key' is told the scheme's descriptions have.

`which-key' cuts a description longer than it is allowed to be, with
`which-key-ellipsis' where the end of it was, and what this scheme gives a
key is a sentence -- `the buffer, formatted by whoever knows how'; `go to:
a definition, an implementation, a location'.  A sentence with its end
removed is not a sentence, and which-key cuts the cell it shows rather
than the description in it: a key that is a prefix is shown with the `+'
of `which-key-prefix-prefix' in front of it, so that character is counted
here too.  The length of the longest sentence is what is measured rather
than a round number, and the longest of them all is the one the scheme has
for `C-c' itself -- see `heks/key-root-description', the row that
was missing from this count when the round number was written.

The setting is the one in the `which-key' setup below, and
`test/heks-emacs-verify.el' checks it there, in an Emacs that has loaded
this configuration; `test/heks-emacs-ert.el' checks the rule instead, with
`which-key's own truncation: no description the scheme has is touched at
this length.")

(defun heks/which-key-setup ()
  "Teach `which-key' what the key scheme means.

Every prefix in the scheme gets the name of its topic, and every key gets
what it does, so that a key that is being typed is explained while it is
being typed rather than only in a document.  The replacements are key
strings, which is how `which-key' describes a binding it is about to
show; a key that is not there is never displayed, so nothing needs to be
declared first.

The four keys that mean something else inside a Java buffer are declared
for those modes instead, with `which-key's own mode-scoped table."
  (which-key-add-key-based-replacements "C-c" heks/key-root-description)
  (dolist (topic heks/key-topics)
    (which-key-add-key-based-replacements (concat "C-c " (car topic)) (cdr topic)))
  (dolist (entry heks/key-descriptions)
    (which-key-add-key-based-replacements (car entry) (cdr entry)))
  (dolist (mode-entry heks/key-major-mode-descriptions)
    (dolist (entry (cdr mode-entry))
      (which-key-add-major-mode-key-based-replacements
       (car mode-entry) (car entry) (cdr entry)))))

;;
;; ====== Where the menu can be shown ======
;;
;; `which-key' makes the window it asks for by splitting the frame's main
;; window in two and keeping the lower half, with `split-window-no-error' --
;; whose nil answer it does not read.  `split-window' refuses to split a
;; window that is not twice the size of the smallest it is allowed to be, so
;; the bottom of the frame is unavailable when its windows are already that
;; small, and the refusal is silent: the keys are written into
;; `which-key's own buffer, which nobody is looking at, and all that is left
;; on screen is the line the echo area has about the menu -- its title, the
;; page it is on and `C-h' -- with no keys under it.

(defvar heks/which-key-echoing nil
  "Non-nil while the menu is in the echo area rather than in a window.")

(defun heks/which-key-side-window-p ()
  "Non-nil when Emacs will make the menu the bottom window it asks for.

`split-window' refuses when the window it is asked to split is smaller
than twice the smallest it is allowed to be (`window-min-size', which is
`window-min-height' -- four lines -- for every window in the frame's main
window).  So the window is unavailable when the frame's windows are
already that small: three windows of a twenty-four line frame, two of a
sixteen line one, one of a frame shorter than nine lines.  The menu's own
height is not the reason and cannot be: the split makes the new window
half the frame's main window, so a smaller menu would not need a smaller
split."
  (let ((root (frame-root-window)))
    (and (window-valid-p root)
         (>= (window-size root nil t)
             (* 2 (window-min-size root nil nil t))))))

(defun heks/which-key-popup-dimensions (_width)
  "How much of the frame the menu may take, and where it will go.

`which-key' asks for this before it makes its pages, so the place is
chosen here -- once -- and the pages are made to fit it: the window when
the frame can give the menu one, the echo area when it cannot (see
`heks/which-key-side-window-p').  There the line which-key says
about the menu is part of the menu (see
`heks/which-key-show-popup'), so the keys are given one line less
than the echo area has."
  (setq heks/which-key-echoing (not (heks/which-key-side-window-p)))
  (if heks/which-key-echoing
      (let ((dims (which-key--minibuffer-max-dimensions)))
        (cons (max 1 (1- (car dims))) (cdr dims)))
    (which-key--side-window-max-dimensions)))

(defun heks/which-key-show-popup (dimensions)
  "Show the menu in the window which-key asked for, or in the echo area.

`which-key--show-buffer-side-window' answers nil, without a word, when
Emacs will not make the window -- and it is `which-key' that asks, so the
answer has to be read here.  A menu nobody can see is worse than a small
menu: when there is no window, the keys and the line which-key says about
them go to the echo area."
  (unless (and (not heks/which-key-echoing)
               (condition-case nil
                   (which-key--show-buffer-side-window dimensions)
                 (error nil)))
    (which-key--echo (heks/which-key-echoed-menu))))

(defun heks/which-key-echoed-menu ()
  "Return the menu as one message, with the line which-key says about it.

That line -- the prefix, the page of how many, and `C-h' -- is composed
by `which-key--process-page', from the pages object it is given; asking it
for the line rather than writing one here is what keeps the two the same.
It is put first because the echo area keeps the first lines of a message
and loses the last ones.

The line reaches this function by being echoed -- that is how
`which-key--process-page' hands it over -- and `message' answers with what
it showed, so a `message' which answers something else leaves the keys
alone rather than putting a `nil' in front of them."
  (let* ((echoed (which-key--process-page which-key--pages-obj))
         (page (car echoed))
         (status (when (cdr echoed) (funcall (cdr echoed)))))
    (if (stringp status) (concat status "\n" page) page)))

(defun heks/which-key-hide-popup ()
  "Hide the menu, from wherever it was shown."
  (which-key--hide-buffer-side-window)
  (when heks/which-key-echoing
    (message nil)))

(defun heks/which-key-popup-visible-p (original)
  "Say that the menu is on screen when it is in the echo area.

`which-key' looks for its buffer in a window to know whether its menu is
showing, which the echo area is not: without this, `C-h' in the echo area
would ask for the menu again instead of opening the dispatch menu it opens
in the window."
  (or (funcall original) heks/which-key-echoing))

;; Configure Flymake (built-in linter).
;;
;; All of diagnostics is one topic: `n' and `N' walk them, `b' and `a'
;; list them for this buffer and for the whole project, and `m' turns the
;; background checking on and off.  (`p' used to list the project's
;; diagnostics, one letter away from a "previous error" key that did not
;; exist, while `C-c i p' formatted the buffer -- three letters that had
;; nothing to do with each other.)
(use-package flymake
  :ensure nil
  :bind (("C-c ! n" . flymake-goto-next-error)
         ("C-c ! N" . flymake-goto-prev-error)
         ("C-c ! b" . flymake-show-buffer-diagnostics)
         ("C-c ! a" . flymake-show-project-diagnostics)
         ("C-c ! m" . flymake-mode)))

;; Discoverability: Show available keybindings after a short delay
(use-package which-key
  :ensure nil
  :config
  (setq which-key-sort-order 'which-key-key-order-alpha
        ;; Long enough for every sentence the scheme has, so that none of
        ;; them is shown with its end replaced by `..' -- see
        ;; `heks/which-key-description-length', which is what the
        ;; longest of them measures.
        which-key-max-description-length heks/which-key-description-length)
  ;; Fast enough to be useful, slow enough not to flash
  (setq-default which-key-idle-delay 0.4)
  ;; `C-h' after a prefix asks for the menu at once, for when the 0.4s
  ;; of waiting is one breath too long.
  (setq which-key-show-early-on-C-h t
        which-key-idle-secondary-delay 0.05)
  ;; The window at the bottom rather than the echo area, which is the one
  ;; choice here that which-key's own documentation asks for: of
  ;; `which-key-setup-minibuffer' it says "do not use this setup if you use
  ;; the paging commands", and this scheme needs them.  The echo area can
  ;; never grow past `max-mini-window-height', a quarter of the frame -- six
  ;; lines of a 25 line one -- and `C-c' alone has 29 keys, so a page of
  ;; them arrived six at a time, five pages of a menu that is one menu.  A
  ;; window is as tall as the page it shows (up to two fifths of the frame
  ;; here), which is three pages of the same keys in that small frame and
  ;; one in a larger one; it leaves the echo area to eldoc and to messages;
  ;; and it has a mode line, which is where `which-key-show-remaining-keys'
  ;; says how many of the prefix's keys are in it -- "WK: 10/29 keys" --
  ;; instead of leaving a reader to wonder whether that was all of them.
  ;; The buffers that were visible get their window configuration back when
  ;; it goes.
  ;;
  ;; That is the window when the frame can give the menu one.  When it
  ;; cannot -- a small frame, or one already filled with windows -- the
  ;; echo area is better than the nothing which-key leaves behind, and the
  ;; two functions below choose between the two places each time the menu
  ;; is about to be shown.
  (which-key-setup-side-window-bottom)
  ;; which-key sizes its window in lines, and ignores the global
  ;; `line-spacing'; with spacing the window is too short in pixels and the
  ;; last rows are clipped.  Its own buffer gets none.
  (add-hook 'which-key-init-buffer-hook
            (lambda () (setq-local line-spacing 0)))
  (setq which-key-side-window-max-height 0.4
        ;; Fit the window to the buffer in pixels, not to a count of
        ;; default-font lines: the menu's lines are taller than that, and
        ;; the lower rows were being cut off.
        which-key-allow-imprecise-window-fit nil
        which-key-show-remaining-keys t
        which-key-preserve-window-configuration t)
  ;; Which of the two places the menu goes in is decided per popup, in
  ;; `heks/which-key-popup-dimensions', and shown in
  ;; `heks/which-key-show-popup': `which-key' has no fallback of its
  ;; own, so this configuration shows the menu itself (the `custom' popup
  ;; is which-key's own way of being told that).
  (setq which-key-popup-type 'custom
        which-key-custom-popup-max-dimensions-function
        #'heks/which-key-popup-dimensions
        which-key-custom-show-popup-function #'heks/which-key-show-popup
        which-key-custom-hide-popup-function #'heks/which-key-hide-popup)
  (advice-add 'which-key--popup-showing-p :around
              #'heks/which-key-popup-visible-p)
  ;; Every topic and every key, in the words the scheme gives them.
  (heks/which-key-setup)
  (which-key-mode))

;; (use-package nyan-mode
;;   :ensure t
;;   :demand t
;;   :config
;;   (setq nyan-bar-length 12))

;; Custom modeline package
(use-package modusregel
  :ensure (:host codeberg :repo "jjba23/modusregel" :branch "trunk")
  :demand t)

(defun add-prettify-mappings ()
  "Append custom symbols to the buffer-local prettify-symbols-alist."
  (setq prettify-symbols-alist
        (append '(
                  ;; --- Functional Programming & Lambdas ---
                  ("lambda" . ?λ)
                  ;; ("fn"    . ?Λ)
                  ;; ("fun"   . ?Λ)
                  ("defun"    . ?Λ)
                  ("define*"    . ?Λ)
                  ("func"    . ?Λ)
                  ;; ("function" . ?Λ)
                  ("compose" . ?∘)
                  ("define-syntax" . ?μ)
                  ("define-syntax-rule" . ?μ)
                  ("define-macro" . ?μ)
                  ("define-module" . ?⬡)
                  ("define-record-type" . ?✦)
                  ("define-record-with-kw" . ?✦)
                  ("use-package" . ?ρ)
                  ("defmacro" . ?μ)

                  ;; --- Types & Optionals ---
                  ;; ("None"    . ?Ø)
                  ;; ("Nil"     . ?Ø)
                  ;; ("nil"     . ?Ø)
                  ;; ("null"    . ?Ø)

                  ;; --- Logic & Boolean ---
                  ;; ("true"   . ?✓)
                  ;; ("#t"     . ?✓)
                  ;; ("True"   . ?✓)
                  ;; ("false"  . ?✗)
                  ;; ("#f"     . ?✗)
                  ;; ("False"  . ?✗)

                  ;; --- Mathematical & Set Theory ---
                  ;; ("in"     . ?∈)
                  ;; ("not in" . ?∉)
                  ("sum"    . ?∑)
                  ;; ("product" . ?∏)
                  ("sqrt"   . ?√)
                  ("pi"     . ?π)
                  ("Infinity" . ?∞)
                  ("infinity" . ?∞)
                  ("inf" . ?∞)
                  ("Omega"   . ?Ω)
                  ("omega"   . ?Ω)
                  ("Theta"   . ?Θ)
                  ("theta"   . ?Θ)
                  ("phi"     . ?φ)
                  ("Phi"     . ?φ)
                  ("forall"  . ?∀)
                  ("mu"      . ?μ)
                  ("sigma"   . ?σ)
                  ("Sigma"   . ?Σ)
                  ("alpha"   . ?α)
                  ("Alpha"   . ?α)
                  ("beta"    . ?β)
                  ("Beta"    . ?β)
                  ("gamma"   . ?γ)
                  ("Gamma"   . ?γ)
                  ("pi"      . ?π)
                  ("Pi"      . ?π)
                  ("tau"     . ?τ)
                  ("Tau"     . ?τ)

                  ;; --- Comparison Operators ---
                  ("<="     . ?≤)
                  (">="     . ?≥)

                  ;; --- Control Flow & Arrows ---
                  ("->"     . ?→)
                  ("-->"    . ?⟶)
                  ("<-"     . ?←)
                  ("<--"    . ?⟵)

                  ;; ---- Org
                  ("#+begin_src"       . ?≫)
                  ("#+BEGIN_SRC"       . ?≫)
                  ("#+end_src"         . ?≪)
                  ("#+END_SRC"         . ?≪)
                  ("#+results:"        . ?▷)
                  ("#+RESULTS:"        . ?▷)
                  ("#+begin_quote"     . ?“)
                  ("#+BEGIN_QUOTE"     . ?“)
                  ("#+end_quote"       . ?”)
                  ("#+END_QUOTE"       . ?”)
                  ("#+begin_example" . ?¶)
                  ("#+BEGIN_EXAMPLE" . ?¶)
                  ("#+end_example" . ?¶)
                  ("#+END_EXAMPLE" . ?¶)
                  ("#+title:"   . ?§)
                  ("#+TITLE:"   . ?§)
                  ("#+author:"  . ?᚛)
                  ("#+AUTHOR:"  . ?᚛)
                  ("#+email:"  . ?✉)
                  ("#+EMAIL:"  . ?✉)
                  ("#+date:"    . ?⧖)
                  ("#+DATE:"    . ?⧖)
                  ("#+options:" . ?⌘)
                  ("#+OPTIONS:" . ?⌘)
                  ("#+name:"       . ?⛦)
                  ("#+NAME:"       . ?⛦)

                  ;; --- Lisp ---
                  ("unquote" . ?↴)
                  ("cons"      . ?∷)

                  ;; --- Miscellaneous / Clean Syntax ---
                  ;; ("import" . ?📥)
                  ;; ("export" . ?📤)
                  )
                prettify-symbols-alist)))

(defun heks-activate-prettify ()
  "Populate mappings and safely initialize prettify-symbols-mode."
  (add-prettify-mappings)
  (prettify-symbols-mode +1))

;; Core Emacs Configuration
;; This block is grouped by logical domains for easier reading.
(use-package emacs
  :ensure nil
  :after (modusregel)

  ;; --- Global Keybindings ---
  ;; Note: Custom heks-emacs-* functions must be defined elsewhere.
  ;; The topic table above says what each group is for; these are the
  ;; global keys, and the language modules add theirs under the same
  ;; topics (`C-c g' for Guile, `C-c r' for previewing a Markdown file,
  ;; `C-c a' for an OpenAPI spec) so that one letter keeps one meaning.
  :bind (("C-x C-b" . ibuffer) ; Use the superior interactive buffer menu
         ;; View: folding and comparisons.  The fold keys dispatch, so they
         ;; work in every buffer whichever folding engine it uses.
         ("C-c v o" . heks/fold-open)
         ("C-c v O" . heks/fold-open-recursive)
         ("C-c v c" . heks/fold-close)
         ("C-c v C" . heks/fold-close-all)
         ("C-c v r" . heks/fold-open-all)
         ("C-c v t" . heks/fold-toggle)
         ("C-c v d" . highlight-compare-buffers)
         ;; A comparison of a project with itself: what it writes twice.
         ("C-c v D" . heks/duplicates-report)
         ;; Emacs itself: the libraries it is made of, and the parentheses
         ;; that hold a file together.
         ("C-c l d" . toggle-debug-on-error)
         ("C-c l e" . eval-buffer)
         ("C-c l l" . find-library)
         ("C-c l L" . load-library)
         ("C-c l p" . check-parens)
         ;; Help: the four things one asks about whatever is at point.  `F'
         ;; is the face, where `f' is the function.
         ("C-c h F" . describe-face)
         ("C-c # j" . heks/joe-reconfigure)
         ("C-c # s" . heks/sys-reconfigure)
         ("C-c # u" . heks/sys-update)
         ("C-c # f" . heks/full-reconfigure)
         ("C-c w r" . heks/project-start-repl-process)
         ("C-c w f" . heks/project-fmt)
         ("C-=" . text-scale-increase)
         ("C--" . text-scale-decrease)
         ("C-c w t" . heks/project-start-test)
         ("C-c w d" . heks/project-start-dev)
         ("C-c w s" . heks/print-random-standup-order)
         ;; A repository is cloned into a directory before anything else
         ;; happens in it, so cloning lives with the project.
         ("C-c w c" . magit-clone)
         ;; Text tools, in every buffer.
         ("C-c t a" . sort-lines)
         ("C-c t w" . delete-trailing-whitespace)
         ("C-c t c" . display-fill-column-indicator-mode)
         ("C-c t r" . rainbow-mode)
         ;; These two used to live under `C-c u', back when `u' meant
         ;; "utilities"; `dev-kubernetes.el' now binds the whole of `C-c u' straight
         ;; to `kubed-prefix-map', so `u' means kubed and these moved here
         ;; instead, as the generic action letters they already were:
         ;; `i' inserts, same as everywhere else.
         ("C-c t i" . heks/uuidgen)
         ("C-c t y" . heks/dired-copy-marked-files-content)
         ;; Formatting: one key, and the language decides who formats.
         ("C-c i f" . heks/format-buffer)
         ;; JVM build tooling (Maven, Gradle, Spring Boot).  The capital
         ;; letters open the menus, which name the goals by what they do.
         ("C-c j m" . heks/maven-run)
         ("C-c j M" . heks/maven-menu)
         ("C-c j T" . heks/maven-dependency-tree)
         ("C-c j g" . heks/gradle-run)
         ("C-c j G" . heks/gradle-menu)
         ("C-c j s" . heks/spring-boot-run)
         ("C-c j R" . heks/jvm-refresh-project)
         ;; The goals a project is actually built with, one key each,
         ;; whatever the build tool is: `heks/jvm-run' knows that
         ;; Maven calls it `package' and Gradle `assemble'.
         ("C-c j t" . heks/jvm-test)
         ("C-c j b" . heks/jvm-build)
         ("C-c j p" . heks/jvm-package)
         ("C-c j v" . heks/jvm-verify)
         ("C-c j c" . heks/jvm-clean)
         ("C-c j D" . heks/jvm-dependencies)
         ;; Databases (PostgreSQL, MongoDB)
         ("C-c d p" . heks/sql-postgres)
         ("C-c d m" . heks/mongosh))

  :hook ((text-mode . visual-line-mode)
         (prog-mode . heks-activate-prettify)
         (org-mode . heks-activate-prettify)
         (markdown-ts-mode . heks-activate-prettify)
         ((emacs-lisp-mode
           conf-mode
           markdown-ts-mode
           org-mode
           scheme-mode
           diff-mode) . outline-minor-mode))
  :custom
  ;; Support opening new minibuffers from inside existing minibuffers.
  (enable-recursive-minibuffers t)
  (minibuffer-prompt-properties
   '(read-only t cursor-intangible t face minibuffer-prompt))
  :config
  ;; --- UI & Visual Tweaks ---
  (setq-default line-spacing 6
                pgtk-wait-for-event-timeout 0 ; Fixes input lag on Wayland/PGTK builds
                electric-indent-inhibit t)

  (setopt treesit-font-lock-level 4           ; Maximum syntax highlighting for tree-sitter
          ring-bell-function #'ignore         ; Disable the annoying visual/audio bell
          frame-resize-pixelwise t            ; Allow smooth, gapless window tiling
          use-dialog-box nil                  ; Force prompts to stay in the minibuffer
          fill-column 78)                     ; Standard column width for indicators/wrapping

  (setopt treesit-auto-install-grammar 'always) ; EMACS-31
  (setopt treesit-enabled-modes t)              ; EMACS-31

  ;; default to utf-8 for all the things
  (set-charset-priority 'unicode)
  (setq locale-coding-system 'utf-8
        coding-system-for-read 'utf-8
        coding-system-for-write 'utf-8)
  (set-terminal-coding-system 'utf-8)
  (set-keyboard-coding-system 'utf-8)
  (set-selection-coding-system 'utf-8)
  (prefer-coding-system 'utf-8)
  (setq default-process-coding-system '(utf-8-unix . utf-8-unix))

  (setq-default cursor-type 'bar)             ; Modern pipe cursor instead of standard block
  (global-hl-line-mode +1)                    ; Highlight current line

  ;; --- Editing & Behavior ---
  (setopt backward-delete-char-untabify-method 'hungry ; Deleting whitespace eats all of it at once
          compilation-always-kill t           ; Auto-kill old compilation processes without prompting
          tab-always-indent 'complete         ; Make TAB fallback to completion if already indented
          text-mode-ispell-word-completion nil
          vc-follow-symlinks t                ; Don't ask to follow symlinks to version-controlled files
          delete-by-moving-to-trash t         ; Use system trash instead of permanent deletion
          tab-width 2
          sentence-end-double-space t
          compile-command "maak --list")

  (defun heks/project-compilation-buffer-name (mode)
    "Create a compilation buffer name based on the current project."
    (let* ((project (project-current))
           ;; Extract the folder name if in a project, otherwise use "global"
           (project-name (if project
                             (file-name-nondirectory (directory-file-name (project-root project)))
                           "global")))
      ;; Returns e.g., "*compilation-my-project*"
      (format "*%s-%s*" (downcase mode) project-name)))

  ;; Tell Emacs to use your custom function
  (setq compilation-buffer-name-function #'heks/project-compilation-buffer-name)

  (setq-default indent-tabs-mode nil)         ; Always use spaces instead of tabs


  (defalias 'yes-or-no-p 'y-or-n-p)           ; Type 'y' instead of 'yes' for prompts

  ;; --- Minibuffer & Completion ---
  (setopt read-extended-command-predicate #'command-completion-default-include-p ; Hide irrelevant commands
          completion-cycle-threshold 3        ; Cycle through options if there are 3 or fewer
          completion-eager-update t               ;; EMACS-31
          completion-eager-display 'auto          ;; EMACS-31
          minibuffer-visible-completions 'up-down ;; EMACS-31
          read-file-name-completion-ignore-case t
          read-buffer-completion-ignore-case t
          completion-ignore-case t
          eldoc-help-at-pt t)

  ;; --- State Preservation ---
  (savehist-mode 1)                           ; Remember minibuffer history across sessions
  (save-place-mode 1)                         ; Remember cursor position in previously opened files
  (global-auto-revert-mode 1)                 ; Auto-update buffers if the file changes on disk
  (delete-selection-mode +1)                  ; Typing replaces highlighted text (modern behavior)

  ;; Remember recently opened files
  (recentf-mode 1)
  (setopt recentf-max-menu-items 100
          recentf-max-saved-items 100)

  ;; startup
  (setopt inhibit-startup-screen t
          initial-scratch-message nil)

  (winner-mode t)

  (show-paren-mode t)

  (column-number-mode 1)

  ;; less noise when compiling elisp
  (setq byte-compile-warnings '(not free-vars unresolved noruntime lexical make-local))
  (setq native-comp-async-report-warnings-errors nil)
  (setq load-prefer-newer t)

  ;; --- Integrations & Paths ---

  (setopt safe-local-variable-directories
          ;; Whitelist specific Guix directory to prevent constant local-variable security
          (list (string-replace "$HOME" (getenv "HOME") "$HOME/fork/guix/")))

  ;; --- Window Management ---
  ;; Enable Shift+Arrow keys for easy directional window switching
  (when (fboundp 'windmove-default-keybindings)
    (windmove-default-keybindings))

  ;; Frame transparency (requires a compositor like Wayland or Picom)
  (ignore-errors
    (set-frame-parameter nil 'alpha-background 86)
    (add-to-list 'default-frame-alist '(alpha-background . 86)))

  ;; --- File Management (Dired) ---
  (when heks/is-darwin-p
    (setopt insert-directory-program (executable-find "gls")))

  (setopt dired-listing-switches "-lAh --group-directories-first" ; Human readable, dirs at the top
          dired-kill-when-opening-new-dired-buffer t)             ; Keep buffer list clean

  (add-to-list 'set-message-functions 'inhibit-message)
  (add-to-list 'inhibit-message-regexps "replicasets\\.apps is forbidden")

  (add-hook 'dired-mode-hook
            (lambda ()
              (dired-hide-details-mode 1)     ; Hide ownership/permissions by default for cleaner look
              (auto-revert-mode)))            ; Auto-refresh dired when files change

  (add-to-list 'auto-mode-alist '("\\.hbs\\'" . html-mode))

  ;; --- Buffer Placement Rules ---
  ;; Tame window popups. Anatomy of a display-buffer-alist entry:
  ;; (BUFFER-MATCHER LIST-OF-DISPLAY-FUNCTIONS &optional PARAMETERS)
  ;; matchers can be an Emacs buffer name regex string or a mode matcher: (derived-mode . typescript-mode)
  (setq display-buffer-alist '(("\\*Occur\\*"
                                (display-buffer-reuse-mode-window
                                 display-buffer-below-selected)
                                (window-height . fit-window-to-buffer)
                                (dedicated . t))
                               ((derived-mode . completion-list-mode)
                                (display-buffer-use-some-window))))

  ;; --- Disable Bidirectional Text Scanning  ---
  ;; If you don’t edit right-to-left languages (like me), Emacs is doing a bunch of work on every redisplay cycle for nothing.
  ;; These settings tell Emacs to assume left-to-right text everywhere and skip the bidirectional parenthesis algorithm:

  (setq-default bidi-display-reordering 'left-to-right
                bidi-paragraph-direction 'left-to-right)

  (setq bidi-inhibit-bpa t)

  ;; --- Skip Fontification During Input ---
  ;; Emacs normally fontifies (syntax-highlights) text even while you’re actively typing.
  ;; This can cause micro-stutters, especially in tree-sitter modes or large buffers.
  ;; One setting fixes it:

  (setq redisplay-skip-fontification-on-input t)

  ;; --- Increase Process Output Buffer for LSP ---
  ;; The default read-process-output-max is 64KB, which is still quite conservative.
  ;; Modern LSP servers like rust-analyzer or clangd routinely send multi-megabyte responses.
  ;; Bumping this reduces the number of read calls Emacs has to make.
  ;; If you use eglot (or lsp-mode), this is basically free performance.

  (setq read-process-output-max (* 6 1024 1024)) ; 6MB

  ;; --- Don’t Render Cursors in Non-Focused Windows ---
  ;; If you have several windows visible, Emacs draws a cursor in each of them – even the ones you’re not working in.
  ;; It also highlights selections in non-focused windows. Two settings to stop that:

  (setq-default cursor-in-non-selected-windows nil)
  (setq highlight-nonselected-windows nil)

  ;; --- Save the Clipboard Before Killing ---
  ;; Here’s a scenario: you copy a URL from your browser, switch to Emacs, kill a line with C-k, and then try to yank the URL you copied earlier with C-y.
  ;; Gone. The kill replaced it on the clipboard.
  ;; This setting makes Emacs save the existing clipboard content into the kill ring before overwriting it:
  ;; Now C-y gets the kill, and M-y gets you back to the URL. Such a small thing, but it eliminates a genuinely annoying problem.

  (setq save-interprogram-paste-before-kill t)

  ;; --- No Duplicates in the Kill Ring ---
  ;; Kill the same line three times and you get three identical entries in the kill ring, wasting slots.
  ;; This deduplicates them:

  (setq kill-do-not-save-duplicates t)

  ;; --- Speedbar ---
  (setopt speedbar-window-default-width 25) ;; EMACS-31
  (setopt speedbar-window-max-width 25)     ;; EMACS-31

  ;; --- VC ---
  (setopt vc-auto-revert-mode t                    ; EMACS-31
          vc-allow-rewriting-published-history t   ; EMACS-31
          vc-dir-auto-hide-up-to-date t)     ; EMACS-31

  ;; -- General niceties ----
  (setopt delete-pair-push-mark t)                    ; EMACS-31: pushes a mark after
                                        ; delete-pair so C-x C-x selects what was inside
  (setopt ibuffer-human-readable-size t)              ; EMACS-31: KB/MB instead of raw byte counts
  (setopt kill-region-dwim 'emacs-word)               ; EMACS-31: C-w with no region kills a word
  (setopt native-comp-async-on-battery-power nil)     ; EMACS-31: stop native-comp jobs on battery
  (setopt view-lossage-auto-refresh t)                ; EMACS-31: live-updating C-h l, great for teaching/debugging
  (setopt display-fill-column-indicator-warning nil)  ; EMACS-31
  (setopt dired-hide-details-hide-absolute-location t); EMACS-31: hide the absolute dir path in dired-hide-details-mode
  (setopt world-clock-sort-order "%FT%T")             ; EMACS-31: sort the world clock sanely
  (setopt zone-all-frames t)                          ; EMACS-31
  (setopt zone-all-windows-in-frame t)                ; EMACS-31
  (setopt uniquify-after-kill-buffer-flag t)          ; EMACS-31: renamed from the -p variant


  ;; --- Persist the Kill Ring Across Sessions ---
  ;; Most configs that use savehist-mode only persist search rings. But savehist can save any variable – including the kill ring.
  ;; Add it and you get clipboard history that survives restarts:

  (setq savehist-additional-variables
        '(search-ring regexp-search-ring kill-ring))

  ;; One thing to watch out for: the kill ring can accumulate text properties (fonts, overlays, etc.) that bloat the savehist file.
  ;; With this you strip them before saving:
  (add-hook 'savehist-save-hook
            (lambda ()
              (setq kill-ring
                    (mapcar #'substring-no-properties
                            (cl-remove-if-not #'stringp kill-ring)))))

  ;; --- Prevent ffap from Pinging Hostnames ---
  ;; Ever had Emacs freeze for a few seconds when you ran find-file-at-point (or a command that uses it internally)?
  ;; If the text under point looks like a hostname – say, something.com in a comment
  ;; ffap tries to ping it to check if it’s reachable. On a slow or firewalled network, that’s a multi-second hang.

  (setq ffap-machine-p-known 'reject)

  ;; --- Faster Mark Popping ---
  ;; The mark ring is one of Emacs’s most underused navigation features.
  ;; Every time you jump somewhere – isearch, M-<, M->, goto-line, imenu, and many more
  ;; Emacs pushes your old position onto the mark ring. C-u C-SPC pops it, jumping you back.
  ;; The annoyance: you need C-u C-SPC every single time.
  ;; With this setting, after the first C-u C-SPC you can keep pressing just C-SPC to continue popping:

  (setq set-mark-command-repeat-pop t)

  ;; --- Trust some directories ---
  (add-to-list 'trusted-content "~/.emacs.d/")
  (add-to-list 'trusted-content "~/Hacking/")
  (add-to-list 'trusted-content "~/Work/")

  ;; --- Auto-Select Help Windows ---
  ;; When you press C-h f or C-h v, Emacs opens the help buffer but leaves your cursor in the original window.
  ;; You almost always want to read the help right away, so you end up pressing C-x o every single time. This fixes it:

  (setq help-window-select t)

  ;; --- Proportional Window Resizing ---
  ;; When you split a window with C-x 2 or C-x 3, Emacs halves the current window.
  ;; If you already have a multi-window layout, this can produce one awkwardly tiny window while others stay large.
  ;; With this setting, all windows in the frame resize proportionally:

  (setq window-combination-resize t)


  ;; --- Custom Modeline Construction ---
  (defun my-set-custom-modeline ()
    "Customize mode-line format using modusregel."
    (setq mode-line-format (list
                            modusregel-leading-str
                            modusregel-remote-expr
                            modusregel-buffer-name-expr
                            modusregel-buffer-modified-str
                            modusregel-buffer-read-only-str
                            modusregel-spacer-str

                            ;; Uncomment if nyan-mode is enabled above
                            ;; modusregel-nyan-expr

                            modusregel-spacer-str
                            modusregel-line-number-str
                            modusregel-column-number-str
                            modusregel-spacer-str
                            modusregel-buffer-position-expr
                            modusregel-spacer-str
                            modusregel-vc-expr
                            modusregel-major-mode-expr
                            modusregel-eglot-expr
                            modusregel-spacer-str
                            modusregel-flymake-expr
                            (ignore-errors keycast-mode-line))))

  (add-hook 'after-change-major-mode-hook #'my-set-custom-modeline)

  )


;;
;; ====== Tree-sitter grammars ======
;;

;; A tree-sitter mode is only as good as the grammar library built for the
;; language it parses, and Emacs fetches a missing one while a file is being
;; opened: with `treesit-auto-install-grammar' at `always' it does that
;; without asking, but the session then waits for `git' and a C compiler on
;; the first file of every language, and a language no recipe is known for is
;; a question instead.  So every grammar this Emacs can be asked for is built
;; once, by `treesit-grammars.el' in a batch Emacs of its own, in the
;; background -- after which the file-opening path has nothing left to fetch.
;; `M-x heks/treesit-install-grammars' runs the same script in front of
;; you, for when one wants to wait and watch it.

(defcustom heks/treesit-grammar-directory
  (expand-file-name "tree-sitter" user-emacs-directory)
  "The directory tree-sitter grammar libraries are installed into.

It is the first entry of `treesit-extra-load-path', which makes it the
directory Emacs looks in first and -- a missing grammar being fetched into
the first entry that can be written to -- the one a grammar Emacs fetches
for itself is written to."
  :type 'directory)

(defcustom heks/treesit-install-grammars t
  "Whether the missing grammars are built at startup, in the background.

The script builds only what has no library here, so a machine whose
grammars are all installed spends a second in that batch Emacs and no more.
Turn it off where there is no network, or where compiling a grammar is not
wanted: nothing is lost but the wait, because Emacs still fetches a grammar
it needs while a file is opened -- it just does it then, in front of the
person who opened the file."
  :type 'boolean)

(defconst heks/treesit-own-recipes
  '((kotlin "https://github.com/fwcd/tree-sitter-kotlin")
    (scala "https://github.com/tree-sitter/tree-sitter-scala")
    (nix "https://github.com/nix-community/tree-sitter-nix"))
  "The recipes of the grammars Emacs itself ships no tree-sitter mode for.

The recipes of the languages Emacs does have modes for are the ones its own
mode files add to `treesit-language-source-alist' as they load, so there is
no list of those to keep here: a grammar whose recipe comes from Emacs is a
grammar whose recipe is right, and stays right as Emacs changes.")

(defconst heks/treesit-grammars-buffer-name
  "*heks-emacs tree-sitter grammars*"
  "Where the batch Emacs that builds grammars writes what it says.")

(defconst heks/treesit-script
  (expand-file-name "treesit-grammars.el" user-emacs-directory)
  "The script a batch Emacs runs to build the grammars.

It sits next to the installed configuration, the way `batch-indent.el'
does, because what it is loaded by is an Emacs with no configuration of its
own.")

(defun heks/treesit--batch-command ()
  "Return the command line of the batch Emacs that builds the grammars.

The script is handed the directory to install into, the recipes this
configuration names itself and the directories a grammar may already be
built in, as Lisp it is told before it is loaded: what it needs is given to
it rather than looked for, which is what keeps the child a batch Emacs and
nothing else -- no Elpaca, no modules, no packages to install first."
  (list (car command-line-args) "-Q" "--batch"
        "--eval" (format "(setq heks/treesit-grammar-directory %S \
heks/treesit-own-recipes '%S \
treesit-extra-load-path '%S)"
                         heks/treesit-grammar-directory
                         heks/treesit-own-recipes
                         (bound-and-true-p treesit-extra-load-path))
        "-l" heks/treesit-script))

(defun heks/treesit--grammars-built (process event)
  "Report what became of PROCESS, the batch Emacs that builds grammars."
  (when (memq (process-status process) '(exit signal))
    (message "heks-emacs: %s (see %s)"
             (string-trim event) heks/treesit-grammars-buffer-name)))

(defun heks/treesit-install-grammars ()
  "Build every tree-sitter grammar that has no library here, and wait.

This is the work the background build does at startup, in front of you:
cloning and compiling a grammar takes a few seconds, and there are as many
of them as this Emacs has languages."
  (interactive)
  (let ((command (heks/treesit--batch-command))
        (buffer (get-buffer-create heks/treesit-grammars-buffer-name)))
    (message "heks-emacs: building tree-sitter grammars (see %s)"
             heks/treesit-grammars-buffer-name)
    (apply #'call-process (car command) nil buffer t (cdr command))
    (message "heks-emacs: tree-sitter grammars built (see %s)"
             heks/treesit-grammars-buffer-name)))

(defun heks/treesit-install-grammars-in-background (&rest _)
  "Build the missing tree-sitter grammars in a batch Emacs of its own.

Nothing here waits for the work: the child is named after what it is doing,
keeps what it says in `heks/treesit-grammars-buffer-name', and its end
is reported in the echo area.  This is what runs at startup, after the rest
of the configuration, because it is the one thing here that finishes long
after the configuration does."
  (when heks/treesit-install-grammars
    (make-process
     :name "heks-emacs tree-sitter grammars"
     :buffer (get-buffer-create heks/treesit-grammars-buffer-name)
     :command (heks/treesit--batch-command)
     :sentinel #'heks/treesit--grammars-built)))

(add-hook 'emacs-startup-hook #'heks/treesit-install-grammars-in-background)

(defun heks/treesit--own-directory-first (&rest _)
  "Put this configuration's grammar directory first, whoever added another.

A grammar Emacs fetches for itself is written to the first entry of
`treesit-extra-load-path' that can be written to, and `no-littering' pushes
a grammar directory of its own onto that list when treesit loads.  Which of
the two comes first is settled here -- after a library load, which is after
the handlers that do the pushing -- rather than left to the order in which
two configurations happened to be loaded."
  (when (boundp 'treesit-extra-load-path)
    (let ((wanted (cons heks/treesit-grammar-directory
                        (remove heks/treesit-grammar-directory
                                treesit-extra-load-path))))
      (unless (equal treesit-extra-load-path wanted)
        (setq treesit-extra-load-path wanted)))))

(add-hook 'after-load-functions #'heks/treesit--own-directory-first)

(with-eval-after-load 'treesit
  ;; The recipes of the languages Emacs has no tree-sitter mode for go into
  ;; the alist here, so that fetching one of those by hand -- or by whatever
  ;; reads the alist next -- knows where to get it.
  (heks/treesit--own-directory-first)
  (dolist (recipe heks/treesit-own-recipes)
    (setf (alist-get (car recipe) treesit-language-source-alist nil nil #'eq)
          (cdr recipe))))


(use-package project
  :ensure nil
  :init
  ;; Treat directories with .envrc (direnv) as project roots.
  ;; Essential for Nix/Guix/direnv workflows so project.el knows where the project starts.
  (setq project-vc-extra-root-markers '(".envrc")))

(defconst heks/markdown-marker-regexp
  (rx (or (seq (group "`") (+ (not (any "`\n"))) (group "`"))
          (seq (group (or "***" "**" "__" "~~"))
               (+? (not (any "\n"))) (group (backref 3)))
          (seq (group-n 5 (any "*_")) (not (any "*_ \n"))
               (*? (not (any "\n"))) (not (any "*_ \n")) (backref 5))))
  "Inline Markdown markup whose delimiters are hidden, as in Org.")

(defun heks/markdown-hide-markers (beg end)
  "Hide the delimiters of inline Markdown markup between BEG and END.
The delimiters show again while point is inside the markup."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward heks/markdown-marker-regexp end t)
      (let* ((mb (match-beginning 0)) (me (match-end 0))
             (open (cond ((match-beginning 1) 1)
                         ((match-beginning 3) (length (match-string 3)))
                         (t 1))))
        (put-text-property mb (+ mb open) 'invisible 'heks-md)
        (put-text-property (- me open) me 'invisible 'heks-md)))))

(require 'org-faces)

(defface heks/markdown-code-block
  '((t :inherit org-block :extend t))
  "Face for the lines of a fenced code block, like `org-block'.")

(defface heks/markdown-code-fence
  '((t :inherit (org-block-begin-line) :extend t))
  "Face for the fence lines of a fenced code block.")

(defun heks/markdown-prettify-blocks (beg end)
  "Give the fenced code blocks overlapping BEG..END an Org-like look.
The fence lines become a rule, labelled with the language, and the body
gets a background."
  (save-excursion
    (goto-char beg)
    (when (re-search-backward "^[ \t]*```" nil t)
      (setq beg (line-beginning-position)))
    (goto-char beg)
    (while (re-search-forward
            "^\\([ \t]*\\)```[ \t]*\\([^ \t\n`{}]*\\).*\n\\(\\(?:.*\n\\)*?\\)[ \t]*```[ \t]*$"
            nil t)
      (let ((open-end (save-excursion (goto-char (match-beginning 3))
                                      (1- (point))))
            (body-beg (match-beginning 3))
            (body-end (match-end 3))
            (close-beg (save-excursion (goto-char (match-end 0))
                                       (line-beginning-position)))
            (close-end (match-end 0))
            (open-beg (match-beginning 0))
            (lang (match-string 2)))
        (add-text-properties
         open-beg open-end
         `(display ,(concat (propertize (if (string-empty-p lang) "───" (concat "─── " lang))
                                        'face 'heks/markdown-code-fence))
           font-lock-multiline t))
        (font-lock-append-text-property
         body-beg body-end 'face 'heks/markdown-code-block)
        (add-text-properties
         close-beg close-end
         `(display ,(propertize "───" 'face 'heks/markdown-code-fence)
           font-lock-multiline t))
        (when (> (point) end) (goto-char (point-max)))))))

(defun heks/markdown-prettify ()
  "Make a Markdown buffer look like an Org one: hide inline markup."
  (add-to-invisibility-spec 'heks-md)
  (jit-lock-register #'heks/markdown-hide-markers)
  (jit-lock-register #'heks/markdown-prettify-blocks)
  ;; Reveal markup under point like `org-appear'.
  (add-hook 'post-command-hook #'heks/markdown-reveal nil t))

(defvar-local heks/markdown--revealed nil)

(defun heks/markdown-reveal ()
  "Show the delimiters of the markup around point, hide the rest."
  (let ((inhibit-modification-hooks t)
        (inhibit-read-only t))
    (when heks/markdown--revealed
      (remove-from-invisibility-spec 'heks-md)
      (add-to-invisibility-spec 'heks-md)
      (setq heks/markdown--revealed nil))
    (when (and (get-text-property (point) 'invisible)
               (eq (get-text-property (point) 'invisible) 'heks-md))
      (remove-from-invisibility-spec 'heks-md)
      (setq heks/markdown--revealed t))))

(use-package markdown-ts-mode
  :ensure nil
  :hook ((markdown-ts-mode . heks/markdown-ts-mode))
  :config
  (defun heks/markdown-ts-mode ()
    (heks/markdown-prettify)
    (variable-pitch-mode 1)
    (auto-fill-mode 0)
    (visual-line-mode 1)
    ;; Only the prose faces, so opening a Markdown buffer never resets
    ;; the global text scale (see `heks/org-mode').
    (ignore-errors (heks/set-markdown-faces))))

(provide 'heks/emacs-self)

;;; emacs-core.el ends here
