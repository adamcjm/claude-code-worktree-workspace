#!/bin/bash
set -euo pipefail

PREFIX="feature"
BASE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --prefix) PREFIX="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) NAME="$1"; shift ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "Usage: worktree-add <name> [--prefix <prefix>] [--base <branch>]" >&2
  echo "  Creates a workspace with worktrees for this repo and all nested git repos." >&2
  echo "  Also copies gitignored config files (like .env) to the new workspace." >&2
  echo "  Default branch prefix: feature" >&2
  echo "  Default base: current HEAD" >&2
  exit 1
fi

if [ -n "$PREFIX" ]; then
  BRANCH="${PREFIX}/${NAME}"
else
  BRANCH="${NAME}"
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
REPO_PARENT=$(dirname "$REPO_ROOT")
WS="$REPO_PARENT/${REPO_NAME}-${NAME}"

if [ -d "$WS" ]; then
  echo "Error: Workspace already exists: $WS" >&2
  exit 1
fi

# Check if a path should be skipped (not copied to worktree)
should_skip() {
  local path="$1"
  [[ "$path" =~ (^|/)\.DS_Store$ ]] && return 0
  [[ "$path" =~ (^|/)\.phpunit\.result\.cache$ ]] && return 0
  [[ "$path" =~ \.pyc$ ]] && return 0
  [[ "$path" =~ (^|/)(\.next|dist|build|out|\.turbo|__pycache__|\.pytest_cache|\.tox|\.vercel)(/|$) ]] && return 0
  [[ "$path" =~ (^|/)bootstrap/cache(/|$) ]] && return 0
  [[ "$path" =~ (^|/)storage/(framework|logs|downloads)(/|$) ]] && return 0
  return 1
}

# Resolve the base reference for a specific repo.
# Returns the resolved ref (local branch, origin/branch, or empty for HEAD).
resolve_base() {
  local repo=$1
  local base=$2

  [ -z "$base" ] && return 0

  if git -C "$repo" rev-parse --verify "$base" >/dev/null 2>&1; then
    echo "$base"
  elif git -C "$repo" rev-parse --verify "origin/$base" >/dev/null 2>&1; then
    echo "origin/$base"
  else
    echo "Warning: '$base' not found in $(basename "$repo"), falling back to HEAD" >&2
  fi
}
has_tracked() {
  local repo=$1
  local dir=$2
  local result
  result=$(git -C "$repo" ls-files "${dir}/" 2>/dev/null | head -1)
  if [ -n "$result" ]; then
    return 0
  else
    return 1
  fi
}

# Copy individual ignored files within a dir that has tracked content
copy_ignored_files() {
  local src_repo=$1
  local target_base=$2
  local prefix=$3

  local items
  items=$(git -c core.quotePath=false -C "$src_repo" ls-files --others --ignored --exclude-standard -- "$prefix") || return 0

  if [ -z "$items" ]; then
    return 0
  fi

  while IFS= read -r item; do
    [ -z "$item" ] && continue

    if should_skip "$item"; then
      continue
    fi

    local src_item="$src_repo/$item"
    local target_item="$target_base/$item"

    # Only handle files - directories here would mean they're fully ignored
    # (tracked dirs only have scattered ignored files, not whole ignored subdirs)
    if [ -f "$src_item" ]; then
      mkdir -p "$(dirname "$target_item")"
      cp "$src_item" "$target_item"
      echo "    Copied: $item"
    elif [ -d "$src_item" ]; then
      # Subdirectory within tracked dir that's fully ignored
      # Check if it itself has tracked content
      if has_tracked "$src_repo" "$item"; then
        copy_ignored_files "$src_repo" "$target_base" "$item"
      else
        if ! should_skip "$item"; then
          mkdir -p "$target_item"
          rsync -a "$src_item/" "$target_item/"
          echo "    Copied dir: $item/"
        fi
      fi
    fi
  done <<< "$items"
}

setup_workspace() {
  local src_repo=$1
  local target_path=$2
  local branch=$3

  local resolved_base
  resolved_base=$(resolve_base "$src_repo" "$BASE")

  echo "  Creating worktree: $target_path"
  if [ -n "$resolved_base" ]; then
    echo "    (based on $resolved_base)"
    git -C "$src_repo" worktree add "$target_path" -b "$branch" "$resolved_base" 2>&1 | sed 's/^/    /'
  else
    git -C "$src_repo" worktree add "$target_path" -b "$branch" 2>&1 | sed 's/^/    /'
  fi

  # Get unique top-level ignored items
  local ignored
  ignored=$(git -c core.quotePath=false -C "$src_repo" ls-files --others --ignored --exclude-standard | cut -d/ -f1 | sort -u) || return 0

  if [ -z "$ignored" ]; then
    return 0
  fi

  while IFS= read -r item; do
    [ -z "$item" ] && continue

    local src_item="$src_repo/$item"
    local target_item="$target_path/$item"

    # Nested git repo
    if [ -d "$src_item/.git" ] || [ -f "$src_item/.git" ]; then
      setup_workspace "$src_item" "$target_item" "$branch"
      continue
    fi

    # Directory
    if [ -d "$src_item" ]; then
      # Check if it contains any tracked files
      if has_tracked "$src_repo" "$item"; then
        # Partially tracked - only copy ignored files within
        copy_ignored_files "$src_repo" "$target_path" "$item"
      else
        # Fully ignored directory
        if should_skip "$item"; then
          continue
        fi
        echo "    Copying dir: $item/"
        mkdir -p "$target_item"
        rsync -a "$src_item/" "$target_item/"
      fi
      continue
    fi

    # File
    if should_skip "$item"; then
      continue
    fi
    mkdir -p "$(dirname "$target_item")"
    cp "$src_item" "$target_item"
    echo "    Copied: $item"

  done <<< "$ignored"
}

echo "Setting up workspace: $WS"
echo "  Branch: $BRANCH"
echo

setup_workspace "$REPO_ROOT" "$WS" "$BRANCH"

echo
echo "Workspace ready: $WS"
