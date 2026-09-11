#!/usr/bin/env bash
# Remove unused entries (and their preceding %-marker line, if any) from a .bib file.
# Usage:
#   ./prune-unused-bib.sh                    # dry run on literature.bib
#   ./prune-unused-bib.sh path/to/file.bib   # dry run on a specific bib
#   ./prune-unused-bib.sh --yes              # actually prune literature.bib
#   ./prune-unused-bib.sh --yes path/to.bib  # actually prune a specific bib

set -euo pipefail

cd "$(dirname "$0")"

BIB="literature.bib"
DRY_RUN=1
for arg in "$@"; do
  case "$arg" in
    --yes|-y) DRY_RUN=0 ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) BIB="$arg" ;;
  esac
done

[[ -f "$BIB" ]]                || { echo "Error: $BIB not found" >&2; exit 1; }
[[ -x ./check-bib-usage.sh ]]  || { echo "Error: ./check-bib-usage.sh not found or not executable" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

./check-bib-usage.sh "$BIB" \
  | awk '/^--- Unused entries ---/{flag=1;next} /^---/{flag=0} /^$/{flag=0} /^Tip:/{flag=0} flag' \
  > "$TMP/unused.txt"

COUNT=$(wc -l < "$TMP/unused.txt" | tr -d ' ')

if [[ $COUNT -eq 0 ]]; then
  echo "No unused entries — nothing to prune."
  exit 0
fi

echo "Found $COUNT unused entries in $BIB."
if [[ $DRY_RUN -eq 1 ]]; then
  echo "(dry run — pass --yes to actually prune)"
  echo
  cat "$TMP/unused.txt"
  exit 0
fi

STAMP=$(date +%Y%m%d-%H%M%S)
cp "$BIB" "${BIB}.bak.${STAMP}"
echo "Backup: ${BIB}.bak.${STAMP}"

python3 - "$BIB" "$TMP/unused.txt" <<'PYEOF'
import re, sys

bib_path, keys_path = sys.argv[1], sys.argv[2]

with open(keys_path) as f:
    unused = {line.strip() for line in f if line.strip()}

with open(bib_path) as f:
    lines = f.read().split('\n')

out, i, removed = [], 0, 0
entry_re  = re.compile(r'^@[a-zA-Z]+\{([^,\s]+)\s*,')
marker_re = re.compile(r'^%\s*(OK|BAD|\?|✓|X)\s')

while i < len(lines):
    m = entry_re.match(lines[i])
    if m and m.group(1) in unused:
        depth, end = 0, i
        for j in range(i, len(lines)):
            depth += lines[j].count('{') - lines[j].count('}')
            if depth == 0 and j > i:
                end = j
                break
        else:
            end = len(lines) - 1

        while out and marker_re.match(out[-1]):
            out.pop()
        while out and out[-1] == '':
            out.pop()

        i = end + 1
        while i < len(lines) and lines[i] == '':
            i += 1
        if out:
            out.append('')
        removed += 1
        continue
    out.append(lines[i])
    i += 1

with open(bib_path, 'w') as f:
    f.write('\n'.join(out))

print(f"Removed {removed} entries.")
PYEOF

echo
echo "=== Post-prune usage report ==="
./check-bib-usage.sh "$BIB" | sed -n '1,6p'
