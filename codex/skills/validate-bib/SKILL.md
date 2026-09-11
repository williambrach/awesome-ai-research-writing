---
name: validate-bib
description: "Verify BibTeX entries against canonical web sources, annotate verdicts, and check unused or undefined citations. Use when asked to validate, verify, audit, or check a bibliography. Prune unused entries only on request."
---

# Role
Audit a BibTeX bibliography against canonical sources. Preserve entry contents and citation keys. Add one verdict comment above each entry and report citation usage when the LaTeX sources are available.

# Input and tools
Use the bibliography supplied by the user, either as a file or pasted BibTeX. In a local project, use the requested path, defaulting to `literature.bib` in the working directory. Ask for the bibliography if it is unavailable.

Use the current environment's web search and page retrieval tools. If web access is unavailable, explain that external verification could not be performed and mark unverified entries `?`. Do not infer that a paper exists from memory or a plausible identifier. If file tools are unavailable, return annotated BibTeX in the reply. Do not claim to have modified the user's filesystem.

# Verification
For each entry, extract the citation key, entry type, title, first author, year, venue, arXiv identifier, DOI, and URL when present.

1. Open the arXiv abstract page if an arXiv identifier is present. Otherwise resolve the DOI, or open the supplied URL for software, websites, and other non-paper references.
2. Compare the title, first-author surname, and year with the actual source. An identifier that resolves is not sufficient by itself.
3. If identifiers are absent or retrieval fails, search for the exact title and first author, then open a matching canonical source such as the publisher, ACL Anthology, arXiv, or the official software repository. Account for preprint and proceedings dates when comparing years.
4. Assign one status:
   - `OK`: title, first author, and year verified; provide the canonical URL.
   - `BAD`: a demonstrated discrepancy, such as an identifier pointing to a different paper or conflicting authors. Give a specific reason.
   - `?`: insufficient evidence after search, inaccessible sources, ambiguous matches, or unavailable browsing. Search failure alone is not proof of fabrication.

Process entries sequentially by default. If parallel agents are available and authorized, divide the entries into disjoint chunks, collect one verdict per key, and wait for all results before merging. Use a fresh temporary directory per audit. Never have multiple agents edit the bibliography.

# Annotation
- Before editing a local bibliography, create a timestamped backup. For uploaded or pasted input, preserve the original and return a separate annotated version.
- Replace only previous verdict comments directly above entries (`% OK`, `% BAD`, `% ?`, or the older `% ✓` / `% X`). Preserve other comments and every entry field.
- Add `% OK <canonical URL>`, `% BAD <reason>`, or `% ? <reason>` above each entry.
- Before saving, confirm that every entry has exactly one verdict, no unknown or duplicate keys were introduced, and entry contents are unchanged. If a chunk is missing, finish it or report the incomplete audit; do not merge an incomplete set.

# Usage and optional pruning
If `.tex` sources are available, compare cited keys with bibliography keys. Report entries that are unused and citations that are undefined. Ignore commented-out citations, handle multi-key citation commands, and treat `\nocite{*}` as using all bibliography entries. State any parser limitations. Without the LaTeX sources, report usage as unavailable rather than zero.

Remove unused entries only if the user explicitly requests it. Apply an already-authorized prune request without asking again. Back up the local file before pruning, preserve all used entries, and prune the same bibliography that was audited. For uploaded input, return a separate pruned version. Do not prune without enough source context to determine usage.

# Output
- Total entries and counts of `OK`, `BAD`, and `?`.
- Each `BAD` or `?` key with its reason and available source links.
- Unused and undefined citation counts, or why the usage check was unavailable.
- The annotated bibliography or its output path, and the backup path if one was created.
- Any incomplete verification, failed tools, or parsing limitations.

# Local helper scripts
This skill includes [check-bib-usage.sh](check-bib-usage.sh), [prune-unused-bib.sh](prune-unused-bib.sh), and [merge-reports.py](merge-reports.py). They require Bash, standard Unix tools, and Python 3.9+ for the Python helpers. Resolve their paths relative to this `SKILL.md`, not the shell's `$0`.

For a conventional BibTeX file with each entry header on its own line (`@type{key,`):

1. Resolve the bibliography and LaTeX project root to absolute paths. Create a fresh temporary reports directory.
2. Write reports named `chunk_1.txt`, `chunk_2.txt`, etc. Each line must be `key|STATUS|info`, with exactly one verdict per entry. Keep `info` on one line. Check for duplicate keys before merging.
3. After backing up the bibliography and removing old verdict comments, run `python3 "<skill-dir>/merge-reports.py" "<absolute-bib-path>" "<reports-dir>"`. The helper rejects missing and unknown keys. Review the diff to confirm only verdict comments changed.
4. Run `bash "<skill-dir>/check-bib-usage.sh" "<absolute-bib-path>" "<absolute-tex-root>"` and include the report. The helper uses line-based matching. If it errors or the input uses unsupported formatting, inspect or parse the sources directly; never report a failed check as zero issues.

The prune helper searches for `.tex` files beside its own script. To use it after an explicit prune request, copy `check-bib-usage.sh` and `prune-unused-bib.sh` into the LaTeX project root without overwriting existing files, make the copies executable, and run `bash "<project-root>/prune-unused-bib.sh" --yes "<absolute-bib-path>"`. If those filenames already belong to other files, or their parser cannot handle the input, perform the same backed-up removal directly with the available file tools. Do not run the prune helper from the installed skill directory.
