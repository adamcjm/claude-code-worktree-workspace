---
name: worktree-list
description: List all workspaces created by worktree-add for the current repo, showing branch names and nested repos. Use when the user wants to see active workspaces and their branches.
---

# /worktree-list

List all workspaces:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/worktree-list.sh"
```

Shows workspace name, branch, and each nested repo's branch. Run the script and relay the output to the user.
