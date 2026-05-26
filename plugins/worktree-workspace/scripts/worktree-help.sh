#!/bin/bash
# Display usage information for worktree-workspace plugin
set -euo pipefail

cat << 'EOF'

  worktree-workspace — Complete git worktree workspaces

  Commands (run in Claude Code):

  /worktree-workspace:worktree-add <name> [--prefix <prefix>] [--base <branch>]

      Create a workspace. Every repo (root + nested sub-repos) gets its
      own worktree, all on the same branch. Gitignored config files like
      .env are copied over automatically.

      Options:
        name          Workspace name (required)
        --prefix      Branch prefix, default "feature". Branch = <prefix>/<name>
        --base        Base branch/commit, default: each repo's current HEAD.
                      Use --base main to start all repos from main.

      Examples:
        /worktree-workspace:worktree-add order-export
        /worktree-workspace:worktree-add login-fix --prefix fix --base main


  /worktree-workspace:worktree-list

      List all workspaces for the current repo, with branch names.


  /worktree-workspace:worktree-remove <name> [--delete-branches]

      Remove a workspace. By default branches are kept.

      Options:
        name               Workspace name (required)
        --delete-branches  Also delete the branch from every repo.

      Examples:
        /worktree-workspace:worktree-remove order-export
        /worktree-workspace:worktree-remove order-export --delete-branches


  /worktree-workspace:worktree-help

      Show this help.

EOF
