#!/bin/bash
set -euo pipefail

DELETE_BRANCHES=false
NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --delete-branches) DELETE_BRANCHES=true; shift ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) NAME="$1"; shift ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "Usage: worktree-remove <name> [--delete-branches]" >&2
  echo "  Removes a workspace previously created by worktree-add." >&2
  echo "  --delete-branches  Also delete the feature branch from all repos." >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
REPO_PARENT=$(dirname "$REPO_ROOT")
WS="$REPO_PARENT/${REPO_NAME}-${NAME}"

if [ ! -d "$WS" ]; then
  echo "Error: Workspace not found: $WS" >&2
  exit 1
fi

# Capture branch name from root worktree before removing anything, in case
# the user wants to delete branches afterwards.
BRANCH=$(git -C "$WS" branch --show-current 2>/dev/null || echo "")

# Collect all repo roots for branch deletion. A repo root is identified by
# having a .git file that points back to a main-repo worktrees directory.
collect_repo_roots() {
  find "$WS" -name ".git" -type f 2>/dev/null | while read -r gitfile; do
    dir=$(dirname "$gitfile")
    gitdir=$(cat "$gitfile" 2>/dev/null | sed 's/^gitdir: //')
    if [ -n "$gitdir" ]; then
      # The main repo is the parent of .git/worktrees/<name>
      main=$(echo "$gitdir" | sed 's|/\.git/worktrees/.*||')
      echo "$main"
    fi
  done | sort -u
}

echo "Removing workspace: $WS"

# Remove nested worktrees first (deepest first)
find "$WS" -name ".git" -type f 2>/dev/null | sort -r | while read -r gitfile; do
  dir=$(dirname "$gitfile")
  if [ "$dir" != "$WS" ]; then
    if git -C "$dir" rev-parse --git-dir 2>/dev/null | grep -q ".git/worktrees"; then
      echo "  Removing nested worktree: $dir"
      git -C "$dir" worktree remove "$dir" --force 2>/dev/null || true
      [ -d "$dir" ] && rm -rf "$dir" && echo "    Cleaned leftover files"
    fi
  fi
done

# Remove root worktree
echo "  Removing root worktree: $WS"
git -C "$REPO_ROOT" worktree remove "$WS" --force 2>/dev/null || true
[ -d "$WS" ] && rm -rf "$WS" && echo "  Cleaned leftover files"

# Clean up stale references in all repos
for repo in $(collect_repo_roots); do
  git -C "$repo" worktree prune 2>/dev/null || true
done

# Delete branches if requested
if [ "$DELETE_BRANCHES" = true ] && [ -n "$BRANCH" ]; then
  echo ""
  echo "  Deleting branch '$BRANCH' from all repos:"
  for repo in $(collect_repo_roots); do
    repo_name=$(basename "$repo")
    if git -C "$repo" branch --list "$BRANCH" 2>/dev/null | grep -q .; then
      git -C "$repo" branch -D "$BRANCH" 2>/dev/null && \
        echo "    $repo_name: deleted $BRANCH" || \
        echo "    $repo_name: failed to delete $BRANCH"
    else
      echo "    $repo_name: $BRANCH not found"
    fi
  done
fi

echo "Done."
