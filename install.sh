#!/usr/bin/env bash
# ============================================================
# SDE Plugin Installer
# Installs 28 slash commands via ~/.claude/commands/ symlinks
# (Claude Code user-level commands — no plugin namespace needed)
# ============================================================
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_DIR="$HOME/.claude/commands"

echo "╔══════════════════════════════════════════╗"
echo "║  SDE Plugin Installer v2.1               ║"
echo "║  28 Commands · ~/.claude/commands/        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Step 1: Verify plugin directory ──────────────────────────────────────────
if [ ! -d "$PLUGIN_DIR/commands" ]; then
  echo "ERROR: commands/ directory not found in $PLUGIN_DIR"
  exit 1
fi

# ── Step 2: Create ~/.claude/commands/ and symlink all sde commands ──────────
mkdir -p "$COMMANDS_DIR"

LINKED=0
for cmd_file in "$PLUGIN_DIR/commands"/sde*.md; do
  cmd_name="$(basename "$cmd_file")"
  target="$COMMANDS_DIR/$cmd_name"
  if [ -L "$target" ]; then
    rm "$target"
  fi
  ln -sf "$cmd_file" "$target"
  LINKED=$((LINKED + 1))
done

echo "✓ Symlinked $LINKED commands → $COMMANDS_DIR/"
echo ""

# ── Step 3: Initialize learnings store ────────────────────────────────────────
mkdir -p "$HOME/.sde-plugin-data/learnings"
if [ ! -f "$HOME/.sde-plugin-data/learnings/user-preferences.json" ]; then
  echo '{}' > "$HOME/.sde-plugin-data/learnings/user-preferences.json"
  echo '[]' > "$HOME/.sde-plugin-data/learnings/stack-decisions.json"
  echo '[]' > "$HOME/.sde-plugin-data/learnings/recurring-issues.json"
  echo '{"projects":[],"totalProjects":0}' > "$HOME/.sde-plugin-data/learnings/project-history.json"
  echo "✓ Learnings store initialized: ~/.sde-plugin-data/learnings/"
fi

# ── Step 4: Clean up old skills symlinks if they exist ───────────────────────
if ls "$HOME/.claude/skills/sde"*.md 2>/dev/null | grep -q .; then
  rm -f "$HOME/.claude/skills/sde"*.md
  echo "✓ Removed old skills/ symlinks"
fi

# ── Step 5: Verify ────────────────────────────────────────────────────────────
echo ""
COMMAND_COUNT=$(ls "$COMMANDS_DIR"/sde*.md 2>/dev/null | wc -l | tr -d ' ')
echo "────────────────────────────────────────────"
printf "  Commands:   %s symlinks in ~/.claude/commands/\n" "$COMMAND_COUNT"
printf "  Agents:     %s files\n" "$(ls "$PLUGIN_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')"
printf "  Context:    %s files\n" "$(ls "$PLUGIN_DIR/context"/*.md 2>/dev/null | wc -l | tr -d ' ')"
printf "  References: %s files\n" "$(ls "$PLUGIN_DIR/references"/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "────────────────────────────────────────────"
echo ""

# ── Done ──────────────────────────────────────────────────────────────────────
echo "╔════════════════════════════════════════════════════╗"
echo "║  Installation Complete!                            ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║                                                    ║"
echo "║  Commands installed to: ~/.claude/commands/        ║"
echo "║  Plugin source:  ~/Documents/sde-plugin/           ║"
echo "║  Learnings:      ~/.sde-plugin-data/               ║"
echo "║                                                    ║"
echo "║  Required Environment Variables:                   ║"
echo "║    export NOTION_TOKEN='secret_...'                ║"
echo "║    export NOTION_DATABASE_ID='...'                 ║"
echo "║    export GITHUB_TOKEN='ghp_...'                   ║"
echo "║    export SENTRY_DSN='https://...'                 ║"
echo "║    export GRAFANA_CLOUD_PUSH_URL='...'             ║"
echo "║    export GRAFANA_CLOUD_API_KEY='...'              ║"
echo "║                                                    ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  Next Steps:                                       ║"
echo "║  1. Restart Claude Code to load commands           ║"
echo "║  2. Set all environment variables above            ║"
echo "║  3. Run: /sde-config   → one-time setup            ║"
echo "║  4. Run: /sde-idea     → start a new project       ║"
echo "║                                                    ║"
echo "║  For existing codebases:                           ║"
echo "║     Run: /sde-analyze                              ║"
echo "╚════════════════════════════════════════════════════╝"
