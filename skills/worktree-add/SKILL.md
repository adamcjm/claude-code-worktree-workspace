---
name: worktree-add
description: Create a complete git worktree workspace with nested repos and gitignored config files. Use when the user wants to create an isolated workspace for parallel feature development.
---

# /worktree-add

Create a complete workspace by running the worktree-add script:

```bash
bash ~/.claude/skills/worktree-workspace/scripts/worktree-add.sh "<name>" --prefix "<prefix>" --base "<base>"
```

## Arguments

- `name` (required) — workspace identifier, appended to repo dir name
- `--prefix` (optional) — branch prefix, default `feature`. Branch = `<prefix>/<name>`
- `--base` (optional) — base branch/commit. Defaults to each repo's current HEAD. When specified (e.g. `--base main`), all repos branch from that ref, resolving locally then `origin/<ref>`, falling back to HEAD with a warning.

## Behavior

- Creates a worktree for the current repo and ALL nested sub-repos (gitignored directories containing `.git`)
- All repos get the same branch name
- Copies gitignored config files (`.env`, `.idea/`, etc.)
- Copies dependency directories (`node_modules/`, `vendor/`, `.venv/`)
- Skips build artifacts and caches only (`.next/`, `dist/`, `build/`, `__pycache__/`, `.DS_Store`, etc.)

Parse the user's message for `<name>` and optional `--prefix`/`--base` flags. Run the script and relay the output to the user.
