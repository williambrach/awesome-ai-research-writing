#!/usr/bin/env python3
"""Merge agent verdict reports into a .bib file as comment lines.

Usage: merge-reports.py <bib_file> <reports_dir>

Reads every chunk_*.txt in <reports_dir> (one pipe-delimited verdict per line:
KEY|STATUS|INFO) and inserts a `% STATUS INFO` line above each @entry in the
.bib file. STATUS is one of: OK, BAD, ?.

Refuses to merge if any bib entry is missing a verdict, or if any verdict key
is not in the bib (these indicate a chunk range/output mismatch).
"""

import glob
import os
import re
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2

    bib_path, reports_dir = sys.argv[1], sys.argv[2]

    verdicts: dict[str, tuple[str, str]] = {}
    report_files = sorted(glob.glob(os.path.join(reports_dir, "chunk_*.txt")))
    if not report_files:
        print(f"Error: no chunk_*.txt reports in {reports_dir}", file=sys.stderr)
        return 1

    for rp in report_files:
        with open(rp, encoding="utf-8") as f:
            for raw in f:
                line = raw.rstrip("\n")
                if not line:
                    continue
                parts = line.split("|", 2)
                if len(parts) != 3:
                    print(f"Warning: malformed line in {rp}: {line!r}", file=sys.stderr)
                    continue
                key, status, info = (p.strip() for p in parts)
                if status not in {"OK", "BAD", "?"}:
                    print(f"Warning: unknown status {status!r} for key {key} in {rp}", file=sys.stderr)
                    continue
                verdicts[key] = (status, info)

    with open(bib_path, encoding="utf-8") as f:
        src_lines = f.read().split("\n")

    entry_re = re.compile(r"^@[a-zA-Z]+\{([^,\s]+)\s*,\s*$")
    bib_keys = [
        m.group(1)
        for line in src_lines
        if (m := entry_re.match(line))
    ]

    missing_in_reports = [k for k in bib_keys if k not in verdicts]
    extra_in_reports   = [k for k in verdicts if k not in bib_keys]

    if missing_in_reports or extra_in_reports:
        print("Error: report set does not match bib. Aborting merge.", file=sys.stderr)
        if missing_in_reports:
            print(f"  Bib entries with no verdict ({len(missing_in_reports)}):", file=sys.stderr)
            for k in missing_in_reports[:20]:
                print(f"    - {k}", file=sys.stderr)
        if extra_in_reports:
            print(f"  Verdicts with no matching bib entry ({len(extra_in_reports)}):", file=sys.stderr)
            for k in extra_in_reports[:20]:
                print(f"    - {k}", file=sys.stderr)
        return 1

    out_lines: list[str] = []
    counts = {"OK": 0, "BAD": 0, "?": 0}
    for line in src_lines:
        m = entry_re.match(line)
        if m:
            key = m.group(1)
            status, info = verdicts[key]
            out_lines.append(f"% {status} {info}")
            counts[status] += 1
        out_lines.append(line)

    with open(bib_path, "w", encoding="utf-8") as f:
        f.write("\n".join(out_lines))

    total = sum(counts.values())
    print(f"Merged {total} verdicts into {bib_path}: {counts['OK']} OK, {counts['BAD']} BAD, {counts['?']} ?")
    return 0


if __name__ == "__main__":
    sys.exit(main())
