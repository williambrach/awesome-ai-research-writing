#!/usr/bin/env bash
# Report which BibTeX entries are unused and which \cite keys are undefined.
# Usage: ./check-bib-usage.sh [bib-file] [tex-dir]
# Defaults: literature.bib   .

set -euo pipefail

BIB="${1:-literature.bib}"
TEX_DIR="${2:-.}"

[[ -f "$BIB" ]]      || { echo "Error: bib file not found: $BIB" >&2; exit 1; }
[[ -d "$TEX_DIR" ]]  || { echo "Error: tex dir not found: $TEX_DIR" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

grep -oE '^@[a-zA-Z]+\{[^,[:space:]]+' "$BIB" \
  | sed 's/^@[a-zA-Z]*{//' \
  | sort -u > "$TMP/bib_keys.txt"

find "$TEX_DIR" -type f -name '*.tex' -print0 > "$TMP/tex_files.nul"
TEX_COUNT=$(tr -dc '\0' < "$TMP/tex_files.nul" | wc -c | tr -d ' ')

if [[ $TEX_COUNT -eq 0 ]]; then
  echo "Error: no .tex files found under $TEX_DIR" >&2
  exit 1
fi

if xargs -0 grep -lE '\\nocite\*?\{[[:space:]]*\*[[:space:]]*\}' < "$TMP/tex_files.nul" >/dev/null 2>&1; then
  NOCITE_STAR=1
else
  NOCITE_STAR=0
fi

xargs -0 cat < "$TMP/tex_files.nul" \
  | sed 's/\\%/__PCT__/g; s/%.*$//; s/__PCT__/\\%/g' \
  | grep -oE '\\[a-zA-Z]*cite[a-zA-Z]*\*?(\[[^]]*\])*\{[^}]+\}' \
  | sed -E 's/.*\{([^}]*)\}$/\1/' \
  | tr ',' '\n' \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
  | grep -v '^$' \
  | grep -v '^\*$' \
  | sort -u > "$TMP/cited_keys.txt"

TOTAL_BIB=$(wc -l < "$TMP/bib_keys.txt" | tr -d ' ')
TOTAL_CITED=$(wc -l < "$TMP/cited_keys.txt" | tr -d ' ')

if [[ $NOCITE_STAR -eq 1 ]]; then
  : > "$TMP/unused.txt"
else
  comm -23 "$TMP/bib_keys.txt" "$TMP/cited_keys.txt" > "$TMP/unused.txt"
fi
comm -13 "$TMP/bib_keys.txt" "$TMP/cited_keys.txt" > "$TMP/undefined.txt"

UNUSED_COUNT=$(wc -l < "$TMP/unused.txt" | tr -d ' ')
UNDEFINED_COUNT=$(wc -l < "$TMP/undefined.txt" | tr -d ' ')

echo "=== Bibliography usage report ==="
echo "Bib file:                       $BIB ($TOTAL_BIB entries)"
echo "Tex source:                     $TEX_DIR ($TEX_COUNT .tex files)"
echo "Distinct cited keys:            $TOTAL_CITED"
[[ $NOCITE_STAR -eq 1 ]] && echo "Note:                           \\nocite{*} present — every bib entry counts as cited."
echo "Unused (in bib, never cited):   $UNUSED_COUNT"
echo "Undefined (cited, not in bib):  $UNDEFINED_COUNT"
echo

if [[ $UNUSED_COUNT -gt 0 ]]; then
  echo "--- Unused entries ---"
  cat "$TMP/unused.txt"
  echo
fi

if [[ $UNDEFINED_COUNT -gt 0 ]]; then
  echo "--- Undefined citations ---"
  cat "$TMP/undefined.txt"
  echo
fi

if command -v checkcites &>/dev/null && ls *.aux >/dev/null 2>&1; then
  echo "Tip: 'checkcites' is installed; for a build-aware cross-check run:"
  echo "  checkcites"
fi
