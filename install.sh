#!/bin/bash
# Install worktree-workspace plugin into Claude Code
set -euo pipefail

PLUGIN_DIR="$HOME/.claude/plugins/cache/local/worktree-workspace/0.1.0"
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/local"
REPO_URL="https://github.com/adamcjm/claude-code-worktree-workspace.git"

echo "Installing worktree-workspace plugin..."

# Clone / update the plugin
if [ -d "$PLUGIN_DIR/.git" ]; then
  echo "  Updating..."
  git -C "$PLUGIN_DIR" pull --ff-only
else
  echo "  Cloning..."
  mkdir -p "$(dirname "$PLUGIN_DIR")"
  git clone "$REPO_URL" "$PLUGIN_DIR"
fi

# Register directly in installed_plugins.json
python3 -c "
import json, datetime, subprocess, os

# Get git commit SHA
sha = subprocess.run(['git', '-C', '$PLUGIN_DIR', 'rev-parse', 'HEAD'],
                     capture_output=True, text=True).stdout.strip()

now = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.000Z')

with open(os.path.expanduser('~/.claude/plugins/installed_plugins.json')) as f:
    data = json.load(f)

data['plugins']['worktree-workspace@local'] = [{
    'scope': 'user',
    'installPath': '$PLUGIN_DIR',
    'version': '0.1.0',
    'installedAt': now,
    'lastUpdated': now,
    'gitCommitSha': sha
}]

with open(os.path.expanduser('~/.claude/plugins/installed_plugins.json'), 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print('  Plugin registered')
"

echo ""
echo "Done. Restart Claude Code, then use:"
echo "  /worktree-workspace:worktree-add <name>"
echo "  /worktree-workspace:worktree-list"
echo "  /worktree-workspace:worktree-remove <name>"
