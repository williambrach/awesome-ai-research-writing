#!/usr/bin/env bash
# Installer for awesome-ai-research-writing Claude Code, Codex, and ChatGPT editions.
# Source: https://github.com/williambrach/awesome-ai-research-writing
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/williambrach/awesome-ai-research-writing/main/install.sh | bash
#   curl -sL https://raw.githubusercontent.com/williambrach/awesome-ai-research-writing/main/install.sh | bash -s -- --global
#   ./install.sh --codex
#   ./install.sh --chatgpt

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
  "asd-ste100|https://raw.githubusercontent.com/danyuchn/asd-ste100-skill/master|SKILL.md LICENSE README.md references/writing-rules.md examples/before-after.md examples/linter-edge-cases.md scripts/ste-lint.py"
)
CLAUDE_EXTERNAL_SKILLS=(
  "humanize-sk|https://raw.githubusercontent.com/vikiival/humanize-sk/main|SKILL.md"
  "no-ai-slop|https://raw.githubusercontent.com/petergyang/no-ai-slop/main/skills/no-ai-slop|SKILL.md eval.md"
)

PLATFORM="claude"
SCOPE="project"
INSTALL_EXTERNAL=1

for arg in "$@"; do
  case "$arg" in
    -g|--global)
      SCOPE="global"
      ;;
    -p|--project)
      SCOPE="project"
      ;;
    --claude|--codex|--chatgpt)
      PLATFORM="${arg#--}"
      ;;
    --no-external)
      INSTALL_EXTERNAL=0
      ;;
    -h|--help)
      cat <<EOF
Usage: install.sh [--claude | --codex | --chatgpt] [--project | --global] [--no-external]

  --claude       Install Claude Code skills (default)
  --codex        Install Codex skills
  --chatgpt      Download the ChatGPT prompt bundle to ./chatgpt/ for upload
  --project      Install into ./.claude/skills/ or ./.agents/skills/ (default)
  --global       Install into ~/.claude/skills/ or ~/.agents/skills/
  --no-external  Skip upstream skills (including asd-ste100 on both platforms)
  --help         Show this help

First-party skills: ${SKILLS[*]}
External skills: asd-ste100 for Claude and Codex; humanize-sk and no-ai-slop for Claude.
The ChatGPT bundle contains only the ${#SKILLS[@]} first-party skills and has no --global mode.
Run from a clone to install local files; curl-piped installs fetch from GitHub.
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

case "$PLATFORM" in
  claude)
    EXTERNAL_SKILLS+=("${CLAUDE_EXTERNAL_SKILLS[@]}")
    SOURCE_DIR=".claude/skills"
    TARGET_DIR="./.claude/skills"
    [ "$SCOPE" != "global" ] || TARGET_DIR="$HOME/.claude/skills"
    ;;
  codex)
    SOURCE_DIR="codex/skills"
    TARGET_DIR="./.agents/skills"
    [ "$SCOPE" != "global" ] || TARGET_DIR="$HOME/.agents/skills"
    ;;
  chatgpt)
    if [ "$SCOPE" = "global" ]; then
      echo "Error: --chatgpt exports upload files; --global does not apply." >&2
      exit 1
    fi
    TARGET_DIR="./chatgpt"
    INSTALL_EXTERNAL=0
    ;;
esac

# A checked-out installer uses files beside itself, even when invoked elsewhere.
# When piped into bash there is no local source tree, so fetch the published files.
REPO_DIR=""
INSTALLER_PATH="${BASH_SOURCE[0]:-}"
if [ -n "$INSTALLER_PATH" ] && [ -f "$INSTALLER_PATH" ]; then
  REPO_DIR="$(cd "$(dirname "$INSTALLER_PATH")" && pwd)"
  if [ ! -f "$REPO_DIR/.claude/skills/polish/SKILL.md" ]; then
    REPO_DIR=""
  fi
fi

if [ -z "$REPO_DIR" ] || [ "$INSTALL_EXTERNAL" -eq 1 ]; then
  command -v curl >/dev/null 2>&1 || {
    echo "Error: curl is required but not installed." >&2
    exit 1
  }
fi

# Stage all downloads before updating installed files. A failed fetch leaves the
# current installation intact, including the skill whose download failed.
STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

stage_repo_file() {
  local source="$1"
  local destination="$STAGING_DIR/$2"
  mkdir -p "$(dirname "$destination")"
  if [ -n "$REPO_DIR" ]; then
    cp "$REPO_DIR/$source" "$destination"
  else
    curl -fsSL "$REPO_RAW/$source" -o "$destination"
  fi
}

if [ "$PLATFORM" = "chatgpt" ]; then
  stage_repo_file "chatgpt/PROJECT_INSTRUCTIONS.md" "PROJECT_INSTRUCTIONS.md"
  stage_repo_file "chatgpt/research-writing.md" "research-writing.md"
  mkdir -p "$TARGET_DIR"
  cp -R "$STAGING_DIR/." "$TARGET_DIR/"
  echo "Exported ${#SKILLS[@]} ChatGPT workflows to $TARGET_DIR/"
  echo "Upload research-writing.md to a ChatGPT Project and paste"
  echo "PROJECT_INSTRUCTIONS.md into its project instructions. Then try:"
  echo "Use polish on this paragraph: ..."
  exit 0
fi

TOTAL=${#SKILLS[@]}
if [ "$INSTALL_EXTERNAL" -eq 1 ]; then
  TOTAL=$(( TOTAL + ${#EXTERNAL_SKILLS[@]} ))
fi
echo "Installing $TOTAL $PLATFORM skills to $TARGET_DIR ($SCOPE)"
echo

for skill in "${SKILLS[@]}"; do
  stage_repo_file "$SOURCE_DIR/$skill/SKILL.md" "$skill/SKILL.md"
  if [ "$PLATFORM" = "codex" ]; then
    stage_repo_file "$SOURCE_DIR/$skill/agents/openai.yaml" "$skill/agents/openai.yaml"
  fi
  if [ "$skill" = "validate-bib" ]; then
    for file in check-bib-usage.sh prune-unused-bib.sh merge-reports.py; do
      stage_repo_file "$SOURCE_DIR/$skill/$file" "$skill/$file"
      chmod +x "$STAGING_DIR/$skill/$file"
    done
  fi
done

if [ "$INSTALL_EXTERNAL" -eq 1 ]; then
  for entry in "${EXTERNAL_SKILLS[@]}"; do
    skill="${entry%%|*}"
    rest="${entry#*|}"
    base_url="${rest%%|*}"
    files="${rest#*|}"
    for file in $files; do
      mkdir -p "$(dirname "$STAGING_DIR/$skill/$file")"
      if ! curl -fsSL "$base_url/$file" -o "$STAGING_DIR/$skill/$file"; then
        echo "  FAILED     /$skill ($file)" >&2
        exit 1
      fi
      case "$file" in
        scripts/*.py|scripts/*.sh) chmod +x "$STAGING_DIR/$skill/$file" ;;
      esac
    done
  done
fi

mkdir -p "$TARGET_DIR"
cp -R "$STAGING_DIR/." "$TARGET_DIR/"
echo
if [ "$PLATFORM" = "codex" ]; then
  echo 'Done. Open Codex in your project and try: $polish, $logic-check, $shorten, $de-ai ...'
  echo "If the skills do not appear, restart Codex."
else
  echo "Done. Restart Claude Code (or start it in this directory for --project)"
  echo "and try: /polish, /logic-check, /shorten, /de-ai ..."
fi
