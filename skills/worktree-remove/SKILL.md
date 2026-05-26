---
name: worktree-remove
description: Remove a workspace created by worktree-add, cleaning up all nested worktrees. Optionally delete branches with --delete-branches. Use when the user wants to clean up a workspace.
---

# /worktree-remove

Remove a workspace and optionally its branches:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-remove.sh" "<name>"
```

With branch deletion:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-remove.sh" "<name>" --delete-branches
```

## What it does

- Removes all nested sub-repo worktrees (inside-out)
- Removes the root worktree
- Runs `git worktree prune` across all repos
- With `--delete-branches`: also force-deletes the feature branch from every repo

Parse the user's message for `<name>` and whether `--delete-branches` was mentioned. Run the script and relay the output to the user.
