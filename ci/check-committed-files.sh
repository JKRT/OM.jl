#!/usr/bin/env bash
# Files that must not be committed, in the checked-out commit:
#   1. files .gitignore ignores (committed before the rule, or with `git add -f`);
#   2. binary files other than images (object files, executables, libraries, .mat results);
#   3. files over 5 MB.
# Build output, such as an omc run's generated C, objects, executable, makefile and
# JSON/XML files, is caught by 1 and 2.
# Run from the repository root: bash ci/check-committed-files.sh
set -euo pipefail

MAX_BYTES=$((5 * 1024 * 1024))
EMPTY_TREE=$(git hash-object -t tree /dev/null)
failed=0

check() {  # title, paths (one per line)
  [ -z "$2" ] && return 0
  echo "::error::$1"
  printf '%s\n' "$2" | sed 's/^/  /'
  failed=1
}

check "Files that .gitignore ignores are committed (git rm --cached them):" \
  "$(git ls-files -ci --exclude-standard)"
check "Binary files other than images are committed:" \
  "$(git diff --numstat "$EMPTY_TREE" HEAD |
     awk -F'\t' '$1 == "-" && $3 !~ /\.(png|jpe?g|gif|ico|svg|pdf)$/ {print $3}')"
check "Files over 5 MB are committed:" \
  "$(git ls-tree -r -l HEAD |
     awk -F'\t' -v max="$MAX_BYTES" '{split($1, a, " "); if (a[2] == "blob" && a[4] > max) print $2}')"

[ "$failed" -eq 0 ] && echo "No files that must not be committed."
exit "$failed"
