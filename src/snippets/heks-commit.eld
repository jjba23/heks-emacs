;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

text-mode :when (bound-and-true-p git-commit-mode)

(feature-commit "# Introduce a new feature." n "#" n
         "feat: " p n n p n)

(bug-commit "# Fix a bug." n "#" n
     "bug: " p n n p n)

(docs-commit "# Update documentation." n "#" n
      "docs: " p n n p n)

(style-commit "# Style changes to code or appearance." n "#" n
       "style: " p n n p n )

(refactor-commit "# Refactor and improve code and algorithms." n "#" n
                 "refactor: " p n n p n )

(performance-commit "# Improve performance" n "#" n
                    "performance: " p n n p n)

(test-commit "# Test or work on exiting tests." n "#" n
             "test: " p n n p n)

(chore-commit "# Tweak the project, and other general maintenance." n "#" n
             "chore: " p n n p n)

(fix-commit "# Fix the project, the build, and other general maintenance." n "#" n
             "fix: " p n n p n)

(revert-commit "# Revert changes from a previous commit or decision." n "#" n
             "revert: " p n n p n)

(add-dependency-commit "# Introduce a new dependency." n "#" n
             "add-dependency: " p n n p n)

(remove-dependency-commit "# Remove a dependency." n "#" n
             "remove-dependency: " p n n p n)

(update-commit "# Update the project or a dependency." n "#" n
             "update: " p n n p n)

(delete-commit "# Delete code or files." n "#" n
             "delete: " p n n p n)

(wip-commit "# " n "# Work in progress, still in development (use carefully)" n
             "work-in-progress: " p n n p n )

(package-commit "# Change the build system, dependencies or packaging" n "#" n
             "package: " p n n p n)

(ci-cd-commit "# Change the CI/CD system or pipeline" n "#" n
             "ci: " p n n p n)
