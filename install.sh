#!/bin/bash
# Install worktree-workspace plugin into Claude Code
# Claude Code v2.1.157+ auto-discovers plugins in ~/.claude/skills/
set -euo pipefail

SKILLS_DIR="${HOME}/.claude/skills"
PLUGIN_DIR="${SKILLS_DIR}/worktree-workspace"
REPO_URL="https://github.com/adamcjm/claude-code-worktree-workspace.git"

echo "Installing worktree-workspace plugin..."

if [ -d "$PLUGIN_DIR/.git" ]; then
    echo "  Updating existing installation..."
    git -C "$PLUGIN_DIR" pull --ff-only
else
    echo "  Cloning..."
    mkdir -p "$SKILLS_DIR"
    git clone "$REPO_URL" "$PLUGIN_DIR"
fi

echo ""
echo "Done. Restart Claude Code, then use:"
echo "  /worktree-workspace:worktree-add <name>"
echo "  /worktree-workspace:worktree-list"
echo "  /worktree-workspace:worktree-remove <name>"
