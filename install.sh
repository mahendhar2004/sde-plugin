#!/usr/bin/env bash
# ============================================================
# SDE Plugin Installer
# Symlinks all skill files to ~/.claude/skills/
# ============================================================
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_TARGET="$HOME/.claude/skills"

echo "╔══════════════════════════════════════════╗"
echo "║  SDE Plugin Installer                    ║"
echo "║  Solo Dev Engineering Team — 18 Skills   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Verify skills directory exists
if [ ! -d "$PLUGIN_DIR/skills" ]; then
  echo "ERROR: skills/ directory not found in $PLUGIN_DIR"
  exit 1
fi

# Create ~/.claude/skills directory if it doesn't exist
if [ ! -d "$SKILLS_TARGET" ]; then
  echo "Creating $SKILLS_TARGET ..."
  mkdir -p "$SKILLS_TARGET"
fi

echo "Installing skills to $SKILLS_TARGET ..."
echo ""

# Counter for installed skills
INSTALLED=0
UPDATED=0

# Symlink all skill files
for skill_file in "$PLUGIN_DIR/skills"/*.md; do
  if [ ! -f "$skill_file" ]; then
    continue
  fi

  skill_name=$(basename "$skill_file")
  target="$SKILLS_TARGET/$skill_name"

  if [ -L "$target" ]; then
    # Update existing symlink
    rm "$target"
    ln -s "$skill_file" "$target"
    echo "  ↻ Updated: $skill_name"
    UPDATED=$((UPDATED + 1))
  elif [ -f "$target" ]; then
    # File exists but is not a symlink (someone put a file there)
    echo "  ⚠ Skipped: $skill_name (file exists, not a symlink — remove manually to install)"
  else
    # Create new symlink
    ln -s "$skill_file" "$target"
    echo "  ✓ Installed: $skill_name"
    INSTALLED=$((INSTALLED + 1))
  fi
done

TOTAL=$((INSTALLED + UPDATED))
echo ""
echo "────────────────────────────────────────────"
echo "  $INSTALLED new, $UPDATED updated → $TOTAL total skills active"
echo "────────────────────────────────────────────"
echo ""

# Verify all skills were installed
EXPECTED_SKILLS=(
  "sde.md"
  "sde-config.md"
  "sde-idea.md"
  "sde-prd.md"
  "sde-architect.md"
  "sde-stack.md"
  "sde-datamodel.md"
  "sde-api.md"
  "sde-scaffold.md"
  "sde-implement.md"
  "sde-test.md"
  "sde-secure.md"
  "sde-optimize.md"
  "sde-devops.md"
  "sde-prod.md"
  "sde-iterate.md"
  "sde-vc.md"
  "sde-analyze.md"
)

MISSING=0
for skill in "${EXPECTED_SKILLS[@]}"; do
  if [ ! -L "$SKILLS_TARGET/$skill" ]; then
    echo "  ⚠ Missing: $skill"
    MISSING=$((MISSING + 1))
  fi
done

if [ $MISSING -gt 0 ]; then
  echo ""
  echo "WARNING: $MISSING skills could not be installed."
  echo "Run this script again or install manually."
  echo ""
fi

echo "╔══════════════════════════════════════════╗"
echo "║  Installation Complete!                  ║"
echo "╠══════════════════════════════════════════╣"
echo "║                                          ║"
echo "║  Required Environment Variables:         ║"
echo "║    export NOTION_TOKEN='secret_...'      ║"
echo "║    export NOTION_DATABASE_ID='...'       ║"
echo "║    export GITHUB_TOKEN='ghp_...'         ║"
echo "║    export SENTRY_DSN='https://...'       ║"
echo "║    export GRAFANA_CLOUD_PUSH_URL='...'   ║"
echo "║    export GRAFANA_CLOUD_API_KEY='...'    ║"
echo "║                                          ║"
echo "║  Add these to ~/.bashrc or ~/.zshrc      ║"
echo "║                                          ║"
echo "╠══════════════════════════════════════════╣"
echo "║                                          ║"
echo "║  Next Steps:                             ║"
echo "║  1. Set the environment variables above  ║"
echo "║  2. Open Claude Code in any project dir  ║"
echo "║  3. Run: /sde-config  (one-time setup)   ║"
echo "║  4. Run: /sde-idea    (start a project)  ║"
echo "║  5. Follow the 13-phase workflow         ║"
echo "║                                          ║"
echo "║  For existing projects:                  ║"
echo "║     Run: /sde-analyze                    ║"
echo "║                                          ║"
echo "╚══════════════════════════════════════════╝"
