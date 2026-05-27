---
name: validate-bib
description: Validates a LaTeX BibTeX file by web-searching every entry to confirm it refers to a real paper with correct title/author/year. Annotates each entry in the .bib with a `% OK <url>`, `% BAD <reason>`, or `% ? <reason>` comment line. Dispatches parallel sub-agents over chunks of the bibliography for speed. Then runs a usage report (unused vs undefined citations) and, on request, prunes unused entries. Use when the user asks to "validate", "verify", "audit", or "check" a `.bib` / bibliography / references / citations, or asks whether papers in a bib file are real / hallucinated. Argument: optional path to the .bib file (defaults to `literature.bib` in cwd).
argument-hint: [path/to/file.bib]
---

# Role
You orchestrate a multi-agent audit of a LaTeX BibTeX file. The output is the original .bib file with a one-line `%`-comment verdict above every entry, plus a usage report and an optional prune step. **You do not modify the entries themselves.**

# Inputs
- `$ARGUMENTS` — path to the .bib file. If empty, default to `literature.bib` in cwd.
- The skill folder contains three helper scripts you copy into the project root on first run: `check-bib-usage.sh`, `prune-unused-bib.sh`, `merge-reports.py`.

# Workflow

## Step 1: Locate the bib file and copy helper scripts

```bash
BIB="${ARGUMENTS:-literature.bib}"
test -f "$BIB" || { echo "Error: $BIB not found"; exit 1; }

SKILL_DIR="$(dirname "$0")"   # the skill folder; resolve via `realpath` if needed
for f in check-bib-usage.sh prune-unused-bib.sh merge-reports.py; do
  if [[ ! -f "./$f" ]]; then
    cp "$SKILL_DIR/$f" "./$f"
    chmod +x "./$f" 2>/dev/null || true
  fi
done
```

(In practice, find the skill folder by checking common locations: `.claude/skills/validate-bib/` in the project, then `~/.claude/skills/validate-bib/`. If the skill is invoked, those scripts are accessible to you.)

## Step 2: Strip any prior annotation markers

The skill always re-validates from scratch. Make a timestamped backup, then remove existing marker lines (both old `✓/X/?` style and new `OK/BAD/?` style) so agents see clean entries.

```bash
STAMP=$(date +%Y%m%d-%H%M%S)
cp "$BIB" "${BIB}.bak.${STAMP}"

# Remove any line matching:  % OK <...>  /  % BAD <...>  /  % ? <...>  /  % ✓ <...>  /  % X <...>
# that sits directly above an @entry line. (Use Python to be safe.)
python3 - "$BIB" <<'PY'
import re, sys
p = sys.argv[1]
with open(p, encoding="utf-8") as f:
    lines = f.read().split("\n")
out, i = [], 0
marker = re.compile(r'^%\s*(OK|BAD|\?|✓|X)\b')
entry  = re.compile(r'^@[a-zA-Z]+\{')
while i < len(lines):
    if marker.match(lines[i]) and i + 1 < len(lines) and entry.match(lines[i+1]):
        i += 1
        continue
    out.append(lines[i]); i += 1
with open(p, "w", encoding="utf-8") as f:
    f.write("\n".join(out))
PY
```

## Step 3: Compute chunks for parallel verification

Aim for ~30 entries per agent, capped at 10 agents.

```bash
ENTRIES=$(grep -n '^@' "$BIB")
N=$(echo "$ENTRIES" | wc -l | tr -d ' ')
CHUNKS=$(( (N + 29) / 30 ))
[[ $CHUNKS -gt 10 ]] && CHUNKS=10
[[ $CHUNKS -lt 1  ]] && CHUNKS=1
PER=$(( (N + CHUNKS - 1) / CHUNKS ))
TOTAL_LINES=$(wc -l < "$BIB" | tr -d ' ')
```

For each chunk index `c` in `1..CHUNKS`, the entries in that chunk start at the `((c-1)*PER + 1)`-th `@`-line and end one line before the `(c*PER + 1)`-th `@`-line (or end of file for the last chunk). Use awk/sed to compute the start/end byte line numbers in `$BIB`.

```bash
mkdir -p /tmp/bib_validate
> /tmp/bib_validate/ranges.txt
echo "$ENTRIES" | awk -F: -v per="$PER" -v total="$TOTAL_LINES" '
  { idx = NR }
  idx % per == 1 { start = $1 }
  (idx % per == 0) || (idx == NR_total) {
    end = $1 - 1   # placeholder; set properly below
    print start "-" end
  }
' # — simpler: compute in Python or shell loop
```

(Use a short Python helper if the awk version gets fiddly — Python is fine for control flow.)

## Step 4: Dispatch parallel verification agents

For each chunk `c` with line range `[start, end]`, spawn one Agent (`subagent_type: general-purpose`, `run_in_background: true`) with the prompt template below. Substitute the chunk-specific values: `{C}`, `{START}`, `{END}`, `{LIMIT}` (= end - start + 1), `{N_IN_CHUNK}`, `{BIB_PATH}`.

Send all agents in a single message (parallel dispatch). When notifications arrive, mark the corresponding task complete and wait for the rest. Do not poll — you'll be notified.

### Agent prompt template

```
You are validating BibTeX entries in a LaTeX bibliography. Some entries may be LLM-hallucinated (fabricated arXiv IDs, fake DOIs, mangled author lists, wrong years). Be skeptical: matching by title alone is not enough — verify author + year too.

File: {BIB_PATH}
Line range: {START} to {END} ({N_IN_CHUNK} entries)
Output report: /tmp/bib_validate/chunk_{C}.txt

DO NOT modify the file. Read with offset={START}, limit={LIMIT}.

For EACH entry, do this verification:

1. Extract: cite key, type (@article/@inproceedings/@misc/@book/etc.), title, FIRST author, year, venue, eprint/arxiv id, DOI, URL.

2. Verify in priority order — pick the FIRST applicable:
   a. eprint=NNNN.NNNNN or arXiv id → WebFetch https://arxiv.org/abs/<id>; confirm title + first-author surname + year match the bib.
   b. doi= → WebFetch https://doi.org/<doi>; confirm.
   c. @misc with url= (GitHub, RFC, website, software) → WebFetch the URL; confirm it exists and matches the description.
   d. None of the above → WebSearch `"<title>" <first-author>` and check arxiv/aclanthology/dblp/openalex/IEEE/ACM/Springer/publisher. Verify author + year.

3. Decide status (strict rubric):
   - OK   = Verified. Title, first-author surname, year all match. Provide canonical URL.
   - BAD  = Major discrepancy or not found. Specifically: arxiv/DOI points to a different paper; first author wrong; year off by ≥1 year (unless explainable as preprint→conference); title fundamentally different; fully dead URL with no other identifier; paper not found anywhere.
   - ?    = Genuinely ambiguous after honest search (paywalled, obscure book without ISBN, multiple papers with same title).

OUTPUT FORMAT — write to /tmp/bib_validate/chunk_{C}.txt. ONE pipe-delimited line per entry, in file order:

  <citekey>|<OK|BAD|?>|<URL on success, or short reason (<100 chars) on failure>

Examples:
  xie2024osworld|OK|https://arxiv.org/abs/2404.07972
  fakepaper2024|BAD|arXiv 2304.99999 → unrelated physics paper; first author has no work matching title
  ambiguous2020|?|Title matches a 2018 paper not 2020; could be different work

The file must contain exactly {N_IN_CHUNK} lines. Plain text — no header, no commentary.

Reply with: counts OK / BAD / ?, and any patterns or fetch failures (under 150 words).
```

## Step 5: Merge reports into the bib

Once all agents have completed and `/tmp/bib_validate/chunk_*.txt` files are in place:

```bash
python3 ./merge-reports.py "$BIB" /tmp/bib_validate
```

The script verifies every key in the .bib has a verdict, then inserts a `% OK <url>` / `% BAD <reason>` / `% ? <reason>` comment line above each `@type{key,`.

## Step 6: Run the usage report

```bash
./check-bib-usage.sh "$BIB" .
```

Print the full output to the user. Highlight in your reply: total entries, distinct cited keys, unused count, undefined count.

## Step 7: Offer to prune unused entries (only if the user asks)

If the user explicitly asks to prune, remove, or clean up unused entries, run:

```bash
./prune-unused-bib.sh --yes
```

Otherwise, mention that the prune step is available and stop.

# Verdict vocabulary

| Marker | Meaning |
|--------|---------|
| `OK`   | Verified against canonical source. URL given. |
| `BAD`  | Doesn't exist as cited (wrong arXiv/DOI, fabricated, mangled metadata, dead URL). |
| `?`    | Couldn't verify but couldn't disprove (paywall, ambiguous, obscure). |

# What to report back to the user

When done with Steps 1-6, summarize in this shape:

> **Bibliography validation complete.**
> - N entries: X OK, Y BAD, Z ?
> - Top BAD findings: <key1>, <key2>, ... (with one-line reason each)
> - Usage: A unused entries, B undefined citations
> - Backup at `<BIB>.bak.<timestamp>`
> - To prune unused entries, ask me to run `prune-unused-bib.sh`.

# Safety

- Never modify entry contents — only add `%` comment lines above them.
- Always make a `.bak.<timestamp>` before the strip step.
- The prune step is opt-in and itself makes a fresh backup.
- If any agent fails or a report is missing/short, surface that to the user before merging — never merge a partial report set.
