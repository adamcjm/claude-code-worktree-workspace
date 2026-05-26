#!/bin/bash
# Install worktree-workspace plugin into Claude Code
set -euo pipefail

MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/local"
KNOWN_MARKETPLACES="$HOME/.claude/plugins/known_marketplaces.json"
REPO_URL="https://github.com/adamcjm/claude-code-worktree-workspace.git"

echo "Installing worktree-workspace plugin..."

# Clone / update the marketplace
if [ -d "$MARKETPLACE_DIR/.git" ]; then
  echo "  Updating..."
  git -C "$MARKETPLACE_DIR" pull --ff-only
else
  echo "  Cloning..."
  git clone "$REPO_URL" "$MARKETPLACE_DIR"
fi

# Register marketplace
python3 -c "
import json, datetime

# known_marketplaces.json
with open('$KNOWN_MARKETPLACES', 'r') as f:
    data = json.load(f)

data['local'] = {
    'source': {'source': 'github', 'repo': 'adamcjm/claude-code-worktree-workspace'},
    'installLocation': '$MARKETPLACE_DIR',
    'lastUpdated': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.000Z')
}
with open('$KNOWN_MARKETPLACES', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

# settings.json (required for in-app /plugin command)
settings_path = '$HOME/.claude/settings.json'
with open(settings_path, 'r') as f:
    settings = json.load(f)
settings.setdefault('extraKnownMarketplaces', {})['local'] = {
    'source': {'source': 'github', 'repo': 'adamcjm/claude-code-worktree-workspace'}
}
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print('  Marketplace registered (known_marketplaces + settings)')
"

# Install the plugin
echo "  Installing plugin..."
claude plugin marketplace update local 2>/dev/null || true
claude plugin install worktree-workspace@local 2>&1 || echo "  If the above failed, restart Claude Code and run: /plugin install worktree-workspace@local"

echo ""
echo "Done. Restart Claude Code, then use:"
echo "  /worktree-workspace:worktree-add <name>"
echo "  /worktree-workspace:worktree-list"
echo "  /worktree-workspace:worktree-remove <name>"
