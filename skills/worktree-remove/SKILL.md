---
name: worktree-remove
description: Remove a workspace created by worktree-add, cleaning up all nested worktrees. Optionally delete branches with --delete-branches. Use when the user wants to clean up a workspace.
---

# /worktree-remove

Remove a workspace and optionally its branches:

```bash
bash ~/.claude/skills/worktree-workspace/scripts/worktree-remove.sh "<name>"
```

With branch deletion:

```bash
bash ~/.claude/skills/worktree-workspace/scripts/worktree-remove.sh "<name>" --delete-branches
```

## What it does

- Removes all nested sub-repo worktrees (inside-out)
- Removes the root worktree
- Runs `git worktree prune` across all repos
- With `--delete-branches`: also force-deletes the feature branch from every repo

Parse the user's message for `<name>` and whether `--delete-branches` was mentioned. Run the script and relay the output to the user.

## ⚠️  Do NOT set a timeout

This script recursively deletes worktree directories that may contain `node_modules/`, `vendor/`, and other large dependency folders. File size varies across projects — from megabytes to gigabytes. A timeout would leave stale worktree metadata and leftover directories. Run the command without any timeout. Let it finish however long it takes.
