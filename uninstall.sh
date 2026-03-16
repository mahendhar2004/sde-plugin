#!/usr/bin/env bash
# ============================================================
# SDE Plugin Uninstaller
# Removes all symlinked skill files from ~/.claude/skills/
# ============================================================
set -euo pipefail

SKILLS_TARGET="$HOME/.claude/skills"

echo "╔══════════════════════════════════════════╗"
echo "║  SDE Plugin Uninstaller                  ║"
echo "╚══════════════════════════════════════════╝"
echo ""

if [ ! -d "$SKILLS_TARGET" ]; then
  echo "No skills directory found at $SKILLS_TARGET"
  echo "Nothing to uninstall."
  exit 0
fi

SDE_SKILLS=(
  "sde"
  "sde-config"
  "sde-idea"
  "sde-prd"
  "sde-architect"
  "sde-stack"
  "sde-datamodel"
  "sde-api"
  "sde-scaffold"
  "sde-implement"
  "sde-test"
  "sde-secure"
  "sde-optimize"
  "sde-devops"
  "sde-prod"
  "sde-iterate"
  "sde-vc"
  "sde-analyze"
)

REMOVED=0
MISSING=0

echo "Removing SDE skills from $SKILLS_TARGET ..."
echo ""

for skill in "${SDE_SKILLS[@]}"; do
  target="$SKILLS_TARGET/$skill.md"

  if [ -L "$target" ]; then
    rm "$target"
    echo "  ✓ Removed: $skill.md"
    REMOVED=$((REMOVED + 1))
  elif [ -f "$target" ]; then
    echo "  ⚠ Skipped: $skill.md (not a symlink — remove manually if needed)"
    MISSING=$((MISSING + 1))
  else
    echo "  - Not found: $skill.md (already removed)"
    MISSING=$((MISSING + 1))
  fi
done

echo ""
echo "────────────────────────────────────────────"
echo "  $REMOVED skills removed"
if [ $MISSING -gt 0 ]; then
  echo "  $MISSING skills not found (already uninstalled or manual files)"
fi
echo "────────────────────────────────────────────"
echo ""
echo "SDE Plugin uninstalled."
echo ""
echo "Note: Your project .sde/ directories are untouched."
echo "Note: The plugin files in this directory are also untouched."
echo "      To reinstall: bash install.sh"
