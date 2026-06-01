# worktree-workspace

A Claude Code plugin that creates **immediately runnable** git worktree workspaces.

> [中文文档](README.zh-CN.md)

---

## Why this plugin?

`git worktree add` only checks out **git-tracked files**. Everything below is left behind:

| Missing content | Consequence |
|----------------|-------------|
| `.env` / `.env.development` config files | Project won't start |
| `.idea/` / `.vscode/` IDE settings | Dev environment lost |
| Sub-repos gitignored by the parent | Related projects missing |
| Sub-repo config files (their own `.env`) | Sub-projects also broken |

**Result**: after every `git worktree add`, you manually copy config files, re-clone sub-repos, and troubleshoot just to get the project running.

## What this plugin does

**One command to create a complete workspace.** The result is immediately runnable — no `npm install`, no copying config files, no manual setup. Beyond checking out tracked files, it automatically:

- ✅ **Recursively handles nested git repos** — sub-repos ignored by the parent get their own worktrees, all on the same feature branch
- ✅ **Intelligently copies config files** — `.env`, `.idea/`, `.claude/` and other gitignored configs are copied to the workspace
- ✅ **Copies dependency directories** — `node_modules`, `vendor`, `.venv` are copied to the workspace. No `npm install` needed — the project is immediately runnable.
- ✅ **Distinguishes directory types** — if a directory has tracked files, only copies ignored files within it; if fully ignored, copies the whole thing
- ✅ **Unicode filename support** — correctly handles filenames with Chinese and other non-ASCII characters
- ✅ **One-command cleanup** — `/worktree-workspace:worktree-remove` recursively removes all nested worktrees

### Comparison

| | `git worktree add` | `worktree-workspace` |
|---|---|---|
| Git-tracked files | ✅ | ✅ |
| Ignored config files (`.env` etc.) | ❌ | ✅ Auto-copied |
| Nested sub-repos & their worktrees | ❌ | ✅ Recursively created |
| Sub-repo config files | ❌ | ✅ Copied too |
| IDE config dirs (`.idea/` etc.) | ❌ | ✅ Auto-copied |
| `node_modules` / `vendor` | ❌ | ✅ Copied — project runs immediately |
| Cleanup all nested worktrees | ❌ Manual | ✅ One command |

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/adamcjm/claude-code-worktree-workspace/main/install.sh | bash
```

This clones the plugin to `~/.claude/skills/worktree-workspace` — Claude Code v2.1.157+ auto-discovers plugins from this directory. Restart Claude Code when done.

## Commands

All commands are run **inside Claude Code**. Each command is a skill under the `worktree-workspace` plugin namespace.

### `/worktree-workspace:worktree-add` — Create a workspace

```
/worktree-workspace:worktree-add <name> [--prefix <branch-prefix>] [--base <base-branch>]
```

| Argument | Default | Description |
|----------|---------|-------------|
| `name` | *(required)* | Workspace identifier. The directory is created as `<repo>-<name>` alongside the original repo |
| `--prefix` | `feature` | Branch name prefix. Branch = `<prefix>/<name>`. Use `--prefix fix` for `fix/<name>`, or `--prefix ""` for no prefix |
| `--base` | current HEAD | The branch/commit to branch from. Each repo resolves this independently |

**Branch naming**: every repo in the workspace (root + all nested sub-repos) uses the **same branch name**. If you run `/worktree-workspace:worktree-add order-export`, all repos get branch `feature/order-export`.

**`--base` behavior**: without `--base`, each repo branches from its **own current HEAD** — meaning different repos may start from different branches:

```
Root repo on main       → feature/order-export based on main
API repo on master      → feature/order-export based on master
Web repo on dev         → feature/order-export based on dev
```

With `--base main`: all repos branch from `main` (or `origin/main` if `main` doesn't exist locally). If the base doesn't exist in a given repo, it falls back to HEAD with a warning.

**What it does** step by step:

1. Creates a git worktree for the current repo at `<repo-parent>/<repo-name>-<name>`
2. Lists all gitignored files/directories
3. For each ignored item:
   - Nested git repos → recursively creates a worktree (same branch name)
   - Fully-ignored directories (e.g. `.idea/`) → rsync to worktree
   - Partially-tracked directories (e.g. `app/` with isolated `.DS_Store`) → only copy the ignored files
   - Gitignored dependency dirs (`node_modules/`, `vendor/`, `.venv/`) → rsync to worktree
   - Ignored files (e.g. `.env`) → copy to worktree
   - Build artifacts and caches (`.next/`, `dist/`, `build/`, `__pycache__/`, `.DS_Store`, etc.) → skip

Examples:

```
# Start a new feature (each repo branches from its own HEAD)
/worktree-workspace:worktree-add order-export

# Bug fix from main, all repos branch from main
/worktree-workspace:worktree-add login-error --prefix fix --base main

# Bare branch name, no prefix
/worktree-workspace:worktree-add experiment --prefix ""
```

Output:

```
Setting up workspace: ~/projects/myapp-order-export
  Branch: feature/order-export

  Creating worktree: .../myapp-order-export
  Creating worktree: .../myapp-order-export/api
  Creating worktree: .../myapp-order-export/web
    Copied: .env
    Copied: .env.development
    Copying dir: .idea/

Workspace ready: ~/projects/myapp-order-export
```

### `/worktree-workspace:worktree-list` — List workspaces

```
/worktree-workspace:worktree-list
```

Shows all workspaces for the current repo, with branch names and nested repos.

Output:

```
Workspaces for myapp:

  order-export                   feature/order-export
    └─ api                       feature/order-export
    └─ web                       feature/order-export
  login-error                    fix/login-error
    └─ api                       fix/login-error
    └─ web                       fix/login-error
```

### `/worktree-workspace:worktree-remove` — Remove a workspace

```
/worktree-workspace:worktree-remove <name> [--delete-branches]
```

| Argument | Description |
|----------|-------------|
| `name` | The workspace name used when creating |
| `--delete-branches` | Also delete the feature branch from every repo |

**What it does** step by step:

1. Locates the workspace directory at `<repo-parent>/<repo-name>-<name>`
2. Removes nested sub-repo worktrees from deepest to shallowest
3. Removes the root worktree
4. **Completely deletes the workspace directory** — including any non-git files (dependencies, configs, etc.)
5. Runs `git worktree prune` on every repo to clean up stale references
6. If `--delete-branches` is specified: force-deletes the branch from every repo

**Branches are NOT deleted by default.** After `worktree-remove`, the branches still exist. Use `--delete-branches` to remove them, or delete manually with `git branch -D feature/<name>` in each repo.

Examples:

```
# Remove workspace but keep branches
/worktree-workspace:worktree-remove order-export

# Remove workspace and delete all branches
/worktree-workspace:worktree-remove order-export --delete-branches
```

### `/worktree-workspace:worktree-help` — Usage help

```
/worktree-workspace:worktree-help
```

Displays all commands with their options and examples.

### Full workflow

Commands prefixed with `/` are typed **in Claude Code**. Terminal commands are marked with `$`.

```
# 1. Create isolated workspace
/worktree-workspace:worktree-add order-export

# 2. Open workspace in terminal
$ cd ../myapp-order-export

# 3. Start another Claude Code session in the original repo
#    for parallel development
/worktree-workspace:worktree-add stock-report

# 4. Check active workspaces
/worktree-workspace:worktree-list

# 5. Remove workspace (keep branches)
/worktree-workspace:worktree-remove order-export

# 6. Or remove everything including branches
/worktree-workspace:worktree-remove order-export --delete-branches
```

## Use cases

- **Monorepo / multi-repo projects** — multiple independent git repos under one root directory, all need feature branches
- **Config files outside git** — `.env` and other sensitive configs can't be committed but must be present to run
- **Parallel feature development** — each feature gets its own isolated workspace; switch directories to switch context

## How it works

1. `git worktree add` for the root repo
2. `git ls-files --others --ignored --exclude-standard` to find ignored items
3. For each ignored item:
   - Directory containing `.git` → recurse (nested repo)
   - Directory (fully ignored) → rsync to worktree (includes `node_modules`, `vendor`, `.venv`)
   - Directory (partially tracked) → only copy ignored files within
   - File → copy to worktree
   - Matches skip patterns → skip (build artifacts, caches)
4. `worktree-remove` tears it all down in reverse order

## License

MIT
