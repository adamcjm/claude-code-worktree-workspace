# Contributing to worktree-workspace

Thanks for your interest in contributing. This is a small utility, so the process is lightweight.

## Getting started

1. Fork the repo and clone it locally.
2. The plugin lives entirely in shell scripts — no build step, no dependencies beyond git and rsync.
3. Scripts are in `scripts/`. Skills (the Claude Code entry points) are in `skills/`.

## Testing

Since this plugin manipulates git worktrees, there's no automated test suite yet. To test manually:

1. Create a test directory with a git repo containing nested sub-repos and gitignored config files.
2. Run the script directly: `bash scripts/worktree-add.sh test-feature`
3. Verify the workspace was created correctly at `<repo>-test-feature/`.
4. Verify nested repos have their own worktrees with the same branch.
5. Verify gitignored config files (`.env`, etc.) and dependency dirs (`node_modules`, etc.) were copied.
6. Run `bash scripts/worktree-remove.sh test-feature` and verify everything was cleaned up.

## Code style

- Shell scripts use `#!/bin/bash` with `set -euo pipefail`.
- Use `git -C` instead of `cd` for repo-relative operations.
- Print user-facing output to stdout, errors to stderr.
- Keep scripts self-contained — no external dependencies beyond git and rsync.

## Pull request process

1. Open an issue describing what you want to change before writing code (unless it's a trivial fix).
2. Keep PRs focused — one change per PR.
3. Describe what you tested and how.
4. PRs are reviewed on a best-effort basis.

## Questions?

Open an issue on GitHub.
