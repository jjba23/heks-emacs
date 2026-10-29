#!/usr/bin/env bash
# A small script the tour opens to show the shell setup: tree-sitter,
# Flymake running shellcheck, and bash-language-server answering through
# Eglot.  It is not meant to be run; it is meant to be looked at.

set -u

readonly greeting="hello from heks-emacs"

say() {
	local who="$1"
	printf '%s, %s\n' "$greeting" "$who"
}

summarise() {
	local total=0
	for n in "$@"; do
		total=$((total + n))
	done
	printf '%s files\n' "$total"
}

files=$(ls ./*.el)

# Left unquoted on purpose: shellcheck has something to say about it, and
# the tour shows the finding sitting on the line Flymake puts it on.
for file in $files; do
	say $file
done

summarise 3 5 8
