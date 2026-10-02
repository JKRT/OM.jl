#!/usr/bin/env bash
# Clone OM.jl sibling packages at the branch that matches the change under test.
#
#   checkout-siblings.sh <dest dir> <package...>
#
# Each package (Absyn, DAE, ..., or OM for OM.jl itself) is cloned into
# <dest dir>/<Package>.jl. The ref is the first branch that exists of
#   pull request: <PR head branch> in the PR author's fork (fork PRs only),
#                 <PR head branch>, <line>, master
#   push:         <line>, master
# where <line> is LINE if set, else the PR base branch or the pushed branch.
# So coordinated changes across repositories (same branch name) are tested
# together, and otherwise the siblings come from the line the change targets
# (for example 1.13) instead of master. A head branch that is itself a line
# (master, main, 1.13, ...) or equals the base branch is not a coordinated
# change: forks carry stale copies of those, so it is skipped.
#
# Environment (set by the action from the GitHub context; all optional):
#   EVENT_NAME, HEAD_REF, BASE_REF, REF_NAME
#   HEAD_REPO, BASE_REPO  owner/name of the PR head and base repositories
#   LINE                  force the line (e.g. 1.13) instead of BASE_REF/REF_NAME
#   OM_REPOSITORY         repository of OM.jl (default JKRT/OM.jl)
#   SIBLINGS_OWNER        owner of the sibling repositories (default OpenModelica)
#   GIT_BASE_URL          default https://github.com; a local directory tree
#                         <base>/<owner>/<repo> also works, for dry runs
set -euo pipefail

dest=$1; shift
EVENT_NAME=${EVENT_NAME:-push}
OM_REPOSITORY=${OM_REPOSITORY:-JKRT/OM.jl}
SIBLINGS_OWNER=${SIBLINGS_OWNER:-OpenModelica}
GIT_BASE_URL=${GIT_BASE_URL:-https://github.com}
# Never ask for credentials: a fork that lacks a repository must just be skipped.
export GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never
mkdir -p "$dest"

repo_of() {  # repo_of <package> -> owner/name
  if [ "$1" = OM ]; then echo "$OM_REPOSITORY"; else echo "$SIBLINGS_OWNER/$1.jl"; fi
}
url_of() { echo "$GIT_BASE_URL/$1"; }
is_line() {  # a long-lived branch, not a feature branch
  case "$1" in master|main) return 0 ;; esac
  [[ "$1" =~ ^[0-9]+\.[0-9]+$ ]]
}
# has_branch <owner/name> <branch> <attempts>: 0 if it exists, 1 if not, 2 if
# the repository could not be queried (missing, or a network error).
has_branch() {
  local rc=0 try
  for try in $(seq "$3"); do
    rc=0
    git -c credential.helper= ls-remote --exit-code --heads "$(url_of "$1")" "refs/heads/$2" \
      > /dev/null 2>&1 || rc=$?
    case $rc in 0) return 0 ;; 2) return 1 ;; esac
    [ "$try" -lt "$3" ] && sleep $((try * 5))
  done
  return 2
}

pr=""; fork=""; line=""
if [ "$EVENT_NAME" = pull_request ] || [ "$EVENT_NAME" = pull_request_target ]; then
  pr=1
  line=${LINE:-${BASE_REF:-}}
  [ -n "${HEAD_REPO:-}" ] && [ "$HEAD_REPO" != "${BASE_REPO:-}" ] && fork=${HEAD_REPO%%/*}
else
  line=${LINE:-${REF_NAME:-}}
fi
head=""
if [ -n "$pr" ] && [ -n "${HEAD_REF:-}" ] && ! is_line "$HEAD_REF" && [ "$HEAD_REF" != "${BASE_REF:-}" ]; then
  head=$HEAD_REF
fi

summary=""
for pkg in "$@"; do
  repo=$(repo_of "$pkg")
  name=${repo#*/}
  # "<owner/name> <branch> <fork|upstream>"
  candidates=()
  if [ -n "$head" ]; then
    [ -n "$fork" ] && [ "$fork" != "${repo%%/*}" ] && candidates+=("$fork/$name $head fork")
    candidates+=("$repo $head upstream")
  fi
  [ -n "$line" ] && candidates+=("$repo $line upstream")
  candidates+=("$repo master upstream")

  from=""; ref=""
  for c in "${candidates[@]}"; do
    read -r crepo cref kind <<< "$c"
    # Forks: one attempt (most forks lack most siblings); upstream: retry.
    rc=0; has_branch "$crepo" "$cref" "$([ "$kind" = fork ] && echo 1 || echo 3)" || rc=$?
    if [ $rc = 0 ]; then from=$crepo; ref=$cref; break; fi
    # A missing fork repository is normal; an unreachable upstream is an error,
    # not a reason to fall back to another branch.
    if [ $rc = 2 ] && [ "$kind" = upstream ]; then
      echo "::error::cannot query $crepo (branch $cref)"; exit 1
    fi
  done
  [ -n "$from" ] || { echo "::error::no branch found for $pkg in $repo"; exit 1; }
  target="$dest/$pkg.jl"
  if [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
    echo "::error::$target exists and is not empty"; exit 1
  fi
  git clone --quiet --depth 1 --branch "$ref" "$(url_of "$from")" "$target"
  sha=$(git -C "$target" rev-parse --short HEAD)
  echo "$pkg.jl: $from@$ref ($sha)"
  summary+="| $pkg.jl | $from | $ref | $sha |"$'\n'
done

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  { echo "| Package | Repository | Branch | Commit |"; echo "|---|---|---|---|"; printf "%s" "$summary"; } >> "$GITHUB_STEP_SUMMARY"
fi
