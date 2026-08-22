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
  claims
  de-ai
  finalize
  logic-check
  polish
  prune
  redteam
  shorten
  structure
  validate-bib
)

# External skills pulled from their upstream repos (not vendored here).
# Format: "<skill-name>|<raw base url>|<space-separated files>"
EXTERNAL_SKILLS=(
  "humanize-sk|https://raw.githubusercontent.com/vikiival/humanize-sk/main|SKILL.md"
  "no-ai-slop|https://raw.githubusercontent.com/petergyang/no-ai-slop/main/skills/no-ai-slop|SKILL.md eval.md"
)

TARGET_DIR="./.claude/skills"
SCOPE_LABEL="project (./.claude/skills)"
INSTALL_EXTERNAL=1

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
    --no-external)
      INSTALL_EXTERNAL=0
      ;;
    -h|--help)
      cat <<EOF
Usage: install.sh [--project | --global] [--no-external]

  --project      Install into ./.claude/skills/ (default, current directory)
  --global       Install into ~/.claude/skills/ (available in every project)
  --no-external  Skip external skills (installed by default): ${EXTERNAL_SKILLS[*]%%|*}
  --help         Show this help

This installs $(( ${#SKILLS[@]} + ${#EXTERNAL_SKILLS[@]} )) Claude Code skills: ${SKILLS[*]} ${EXTERNAL_SKILLS[*]%%|*}
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

TOTAL=${#SKILLS[@]}
if [ "$INSTALL_EXTERNAL" -eq 1 ]; then
  TOTAL=$(( TOTAL + ${#EXTERNAL_SKILLS[@]} ))
fi
echo "Installing $TOTAL skills to $SCOPE_LABEL"
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

if [ "$INSTALL_EXTERNAL" -eq 1 ]; then
for entry in "${EXTERNAL_SKILLS[@]}"; do
  skill="${entry%%|*}"
  rest="${entry#*|}"
  base_url="${rest%%|*}"
  files="${rest#*|}"
  mkdir -p "$TARGET_DIR/$skill"
  for file in $files; do
    if ! curl -fsSL "$base_url/$file" -o "$TARGET_DIR/$skill/$file"; then
      echo "  FAILED     /$skill ($file)" >&2
      exit 1
    fi
  done
  echo "  installed  /$skill (external)"
done
fi

echo
echo "Done. Restart Claude Code (or start it in this directory for --project)"
echo "and try: /polish, /logic-check, /shorten, /de-ai ..."
