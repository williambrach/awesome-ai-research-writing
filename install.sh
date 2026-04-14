#!/usr/bin/env bash
# Installer for awesome-ai-research-writing Claude Code skills.
# Source: https://github.com/williambrach/awesome-ai-research-writing
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/williambrach/awesome-ai-research-writing/main/install.sh | bash
#   curl -sL https://raw.githubusercontent.com/williambrach/awesome-ai-research-writing/main/install.sh | bash -s -- --global

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/williambrach/awesome-ai-research-writing/main"
SKILLS=(
  analyze-experiment
  de-ai
  expand
  figure-caption
  logic-check
  polish
  review-paper
  shorten
  table-caption
)

TARGET_DIR="./.claude/skills"
SCOPE_LABEL="project (./.claude/skills)"

for arg in "$@"; do
  case "$arg" in
    -g|--global)
      TARGET_DIR="$HOME/.claude/skills"
      SCOPE_LABEL="global (~/.claude/skills)"
      ;;
    -p|--project)
      TARGET_DIR="./.claude/skills"
      SCOPE_LABEL="project (./.claude/skills)"
      ;;
    -h|--help)
      cat <<EOF
Usage: install.sh [--project | --global]

  --project   Install into ./.claude/skills/ (default, current directory)
  --global    Install into ~/.claude/skills/ (available in every project)
  --help      Show this help

This installs 9 Claude Code skills: ${SKILLS[*]}
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Run 'install.sh --help' for usage." >&2
      exit 1
      ;;
  esac
done

command -v curl >/dev/null 2>&1 || {
  echo "Error: curl is required but not installed." >&2
  exit 1
}

echo "Installing ${#SKILLS[@]} skills to $SCOPE_LABEL"
echo

for skill in "${SKILLS[@]}"; do
  mkdir -p "$TARGET_DIR/$skill"
  if curl -fsSL "$REPO_RAW/.claude/skills/$skill/SKILL.md" \
       -o "$TARGET_DIR/$skill/SKILL.md"; then
    echo "  installed  /$skill"
  else
    echo "  FAILED     /$skill" >&2
    exit 1
  fi
done

echo
echo "Done. Restart Claude Code (or start it in this directory for --project)"
echo "and try: /polish, /logic-check, /figure-caption, /review-paper ..."
