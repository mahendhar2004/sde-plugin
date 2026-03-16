#!/usr/bin/env bash
# ============================================================
# SDE Plugin Installer
# Symlinks all skill files to ~/.claude/skills/
# ============================================================
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_TARGET="$HOME/.claude/skills"
SDE_HOME="$HOME/.sde-plugin"

echo "╔══════════════════════════════════════════╗"
echo "║  SDE Plugin Installer v1.2               ║"
echo "║  20 Skills · 7 Agents · 5 Context Files  ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Step 1: Verify plugin directory ──────────────────────────────────────────
if [ ! -d "$PLUGIN_DIR/skills" ]; then
  echo "ERROR: skills/ directory not found in $PLUGIN_DIR"
  exit 1
fi

# ── Step 2: Create ~/.sde-plugin symlink (agents, context, references) ───────
if [ -L "$SDE_HOME" ]; then
  rm "$SDE_HOME"
fi
ln -s "$PLUGIN_DIR" "$SDE_HOME"
echo "✓ Plugin home: $SDE_HOME → $PLUGIN_DIR"
echo ""

# ── Step 3: Create ~/.sde-plugin/learnings/ (for adaptive learning) ──────────
mkdir -p "$HOME/.sde-plugin-data/learnings"
if [ ! -f "$HOME/.sde-plugin-data/learnings/user-preferences.json" ]; then
  echo '{}' > "$HOME/.sde-plugin-data/learnings/user-preferences.json"
  echo '[]' > "$HOME/.sde-plugin-data/learnings/stack-decisions.json"
  echo '[]' > "$HOME/.sde-plugin-data/learnings/recurring-issues.json"
  echo '{"projects":[],"totalProjects":0}' > "$HOME/.sde-plugin-data/learnings/project-history.json"
  echo "✓ Learnings store initialized: ~/.sde-plugin-data/learnings/"
fi

# ── Step 4: Symlink skills to ~/.claude/skills/ ───────────────────────────────
mkdir -p "$SKILLS_TARGET"
echo "Installing skills to $SKILLS_TARGET ..."
echo ""

INSTALLED=0
UPDATED=0

for skill_file in "$PLUGIN_DIR/skills"/*.md; do
  [ -f "$skill_file" ] || continue
  skill_name=$(basename "$skill_file")
  target="$SKILLS_TARGET/$skill_name"

  if [ -L "$target" ]; then
    rm "$target"
    ln -s "$skill_file" "$target"
    echo "  ↻ Updated: $skill_name"
    UPDATED=$((UPDATED + 1))
  elif [ -f "$target" ]; then
    echo "  ⚠ Skipped: $skill_name (non-symlink file exists — remove manually)"
  else
    ln -s "$skill_file" "$target"
    echo "  ✓ Installed: $skill_name"
    INSTALLED=$((INSTALLED + 1))
  fi
done

TOTAL=$((INSTALLED + UPDATED))
echo ""
echo "────────────────────────────────────────────"
printf "  Skills:     %s new, %s updated → %s active\n" "$INSTALLED" "$UPDATED" "$TOTAL"
printf "  Agents:     %s files\n" "$(ls "$PLUGIN_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')"
printf "  Context:    %s files\n" "$(ls "$PLUGIN_DIR/context"/*.md 2>/dev/null | wc -l | tr -d ' ')"
printf "  References: %s files\n" "$(ls "$PLUGIN_DIR/references"/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "────────────────────────────────────────────"
echo ""

# ── Step 5: Verify expected skills ────────────────────────────────────────────
EXPECTED_SKILLS=(
  "sde.md" "sde-config.md" "sde-idea.md" "sde-prd.md"
  "sde-architect.md" "sde-stack.md" "sde-datamodel.md" "sde-api.md"
  "sde-scaffold.md" "sde-implement.md" "sde-test.md" "sde-secure.md"
  "sde-optimize.md" "sde-devops.md" "sde-prod.md" "sde-iterate.md"
  "sde-vc.md" "sde-analyze.md" "sde-learn.md" "sde-sde5.md"
)

MISSING=0
for skill in "${EXPECTED_SKILLS[@]}"; do
  if [ ! -L "$SKILLS_TARGET/$skill" ]; then
    echo "  ⚠ Missing: $skill"
    MISSING=$((MISSING + 1))
  fi
done
[ $MISSING -gt 0 ] && echo "" && echo "WARNING: $MISSING skills missing." && echo ""

# ── Done ──────────────────────────────────────────────────────────────────────
echo "╔════════════════════════════════════════════════════╗"
echo "║  Installation Complete!                            ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║                                                    ║"
echo "║  Plugin structure:                                 ║"
echo "║    ~/.claude/skills/    ← 20 skill symlinks        ║"
echo "║    ~/.sde-plugin/       ← agents, context, refs    ║"
echo "║    ~/.sde-plugin-data/  ← learnings store          ║"
echo "║                                                    ║"
echo "║  Required Environment Variables:                   ║"
echo "║    export NOTION_TOKEN='secret_...'                ║"
echo "║    export NOTION_DATABASE_ID='...'                 ║"
echo "║    export GITHUB_TOKEN='ghp_...'                   ║"
echo "║    export SENTRY_DSN='https://...'                 ║"
echo "║    export GRAFANA_CLOUD_PUSH_URL='...'             ║"
echo "║    export GRAFANA_CLOUD_API_KEY='...'              ║"
echo "║                                                    ║"
echo "║  Add to ~/.zshrc:                                  ║"
echo "║    source ~/.zshrc  (or restart terminal)          ║"
echo "║                                                    ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  Next Steps:                                       ║"
echo "║  1. Set all environment variables above            ║"
echo "║  2. Open Claude Code in any project directory      ║"
echo "║  3. Run: /sde-config   → one-time setup            ║"
echo "║  4. Run: /sde-idea     → start a new project       ║"
echo "║  5. Follow the 13-phase lifecycle                  ║"
echo "║                                                    ║"
echo "║  For existing codebases:                           ║"
echo "║     Run: /sde-analyze                              ║"
echo "║                                                    ║"
echo "║  View your learning profile:                       ║"
echo "║     Run: /sde-learn                                ║"
echo "╚════════════════════════════════════════════════════╝"
