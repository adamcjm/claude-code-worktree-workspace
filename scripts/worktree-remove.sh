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

# Safely clean up a workspace directory with path assertions.
# Only removes directories that are under REPO_PARENT and within the WS tree.
safe_cleanup_workspace_dir() {
  local dir="$1"

  # Safety check 1: must be under the repo parent directory
  if [[ "$dir" != "$REPO_PARENT/"* ]]; then
    echo "    ⚠ Refusing to clean: $dir is outside repo parent ($REPO_PARENT)" >&2
    return 1
  fi

  # Safety check 2: must be under the workspace root directory
  if [[ "$dir" != "$WS/"* ]] && [ "$dir" != "$WS" ]; then
    echo "    ⚠ Refusing to clean: $dir is outside workspace ($WS)" >&2
    return 1
  fi

  # Safety check 3: must be a directory
  if [ ! -d "$dir" ]; then
    return 1
  fi

  # First pass: remove all empty directories (safest)
  find "$dir" -type d -empty -delete 2>/dev/null || true

  # Second pass: if content remains, it's non-empty dirs/files — safe to rm
  if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
    echo "    Cleaning leftover: $(find "$dir" -not -path '*/.git/*' -type f 2>/dev/null | head -3)"
    rm -rf "$dir"
    [ ! -d "$dir" ] && echo "    Cleaned" || echo "    ⚠ Partial cleanup, some files may remain" >&2
  else
    # Only empty directories remain (or already gone)
    rmdir "$dir" 2>/dev/null || true
  fi
}

echo "Removing workspace: $WS"

# Snapshot repo roots BEFORE removing anything — the .git files live inside WS
REPO_ROOTS=$(collect_repo_roots)

# Remove nested worktrees first (deepest first)
find "$WS" -name ".git" -type f 2>/dev/null | sort -r | while read -r gitfile; do
  dir=$(dirname "$gitfile")
  if [ "$dir" != "$WS" ]; then
    if git -C "$dir" rev-parse --git-dir 2>/dev/null | grep -q ".git/worktrees"; then
      echo "  Removing nested worktree: $dir"
      git -C "$dir" worktree remove "$dir" --force 2>/dev/null || true
      safe_cleanup_workspace_dir "$dir" || true
    fi
  fi
done

# Remove root worktree
echo "  Removing root worktree: $WS"
git -C "$REPO_ROOT" worktree remove "$WS" --force 2>/dev/null || true
safe_cleanup_workspace_dir "$WS" || true

# Clean up stale references in all repos
for repo in $REPO_ROOTS; do
  git -C "$repo" worktree prune 2>/dev/null || true
done

# Delete branches if requested
if [ "$DELETE_BRANCHES" = true ] && [ -n "$BRANCH" ]; then
  echo ""
  echo "  Deleting branch '$BRANCH' from all repos:"
  for repo in $REPO_ROOTS; do
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
