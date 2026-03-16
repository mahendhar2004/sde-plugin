#!/usr/bin/env bash
set -euo pipefail
echo "Removing SDE Plugin commands..."
rm -f ~/.claude/commands/sde*.md
echo "✓ Removed all sde commands from ~/.claude/commands/"
echo "Done. Restart Claude Code to apply."
