#!/bin/bash
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
REPO_PARENT=$(dirname "$REPO_ROOT")
PREFIX="${REPO_NAME}-"

echo "Workspaces for ${REPO_NAME}:"
echo

found=0

for ws in "$REPO_PARENT"/"$PREFIX"*; do
  [ -d "$ws" ] || continue
  [ -f "$ws/.git" ] || continue

  ws_name="${ws##*/${PREFIX}}"
  ws_name="${ws_name#$PREFIX}"
  branch=$(git -C "$ws" branch --show-current 2>/dev/null || echo "detached")

  printf "  %-30s %s\n" "$ws_name" "$branch"

  # List nested repos
  find "$ws" -name ".git" -type f 2>/dev/null | while read -r gf; do
    nd=$(dirname "$gf")
    [ "$nd" = "$ws" ] && continue
    nb=$(git -C "$nd" branch --show-current 2>/dev/null || echo "detached")
    rel="${nd#$ws/}"
    printf "    %-28s %s\n" "└─ $rel" "$nb"
  done

  found=$((found + 1))
  echo
done

if [ "$found" -eq 0 ]; then
  echo "  (none)"
fi
