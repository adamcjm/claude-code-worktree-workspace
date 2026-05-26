#!/bin/bash
# Install worktree-workspace plugin into Claude Code
set -euo pipefail

MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/local"
PLUGIN_DIR="$MARKETPLACE_DIR/plugins/worktree-workspace"
KNOWN_MARKETPLACES="$HOME/.claude/plugins/known_marketplaces.json"
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

# Create marketplace wrapper
mkdir -p "$MARKETPLACE_DIR/.claude-plugin"
cat > "$MARKETPLACE_DIR/.claude-plugin/marketplace.json" << 'MARKETPLACE'
{
  "name": "local",
  "plugins": [
    {
      "name": "worktree-workspace",
      "description": "Create complete git worktree workspaces with nested repos and gitignored config files. No npm install needed.",
      "source": "./plugins/worktree-workspace",
      "category": "productivity",
      "homepage": "https://github.com/adamcjm/claude-code-worktree-workspace"
    }
  ]
}
MARKETPLACE

# Register marketplace
python3 -c "
import json, datetime

with open('$KNOWN_MARKETPLACES', 'r') as f:
    data = json.load(f)

if 'local' in data:
    print('  Marketplace already registered, overwriting...')
data['local'] = {
    'installLocation': '$MARKETPLACE_DIR',
    'lastUpdated': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.000Z')
}
with open('$KNOWN_MARKETPLACES', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print('  Marketplace registered (local only)')
"

echo "  Installing plugin..."
claude plugin install worktree-workspace@local 2>&1 || echo "  If the above failed, restart Claude Code and run: /plugin install worktree-workspace@local"

echo ""
echo "Done. Restart Claude Code, then use:"
echo "  /worktree-workspace:worktree-add <name>"
echo "  /worktree-workspace:worktree-list"
echo "  /worktree-workspace:worktree-remove <name>"
