# Local helper scripts
This skill includes [check-bib-usage.sh](check-bib-usage.sh), [prune-unused-bib.sh](prune-unused-bib.sh), and [merge-reports.py](merge-reports.py). They require Bash, standard Unix tools, and Python 3.9+ for the Python helpers. Resolve their paths relative to this `SKILL.md`, not the shell's `$0`.

For a conventional BibTeX file with each entry header on its own line (`@type{key,`):

1. Resolve the bibliography and LaTeX project root to absolute paths. Create a fresh temporary reports directory.
2. Write reports named `chunk_1.txt`, `chunk_2.txt`, etc. Each line must be `key|STATUS|info`, with exactly one verdict per entry. Keep `info` on one line. Check for duplicate keys before merging.
3. After backing up the bibliography and removing old verdict comments, run `python3 "<skill-dir>/merge-reports.py" "<absolute-bib-path>" "<reports-dir>"`. The helper rejects missing and unknown keys. Review the diff to confirm only verdict comments changed.
4. Run `bash "<skill-dir>/check-bib-usage.sh" "<absolute-bib-path>" "<absolute-tex-root>"` and include the report. The helper uses line-based matching. If it errors or the input uses unsupported formatting, inspect or parse the sources directly; never report a failed check as zero issues.

The prune helper searches for `.tex` files beside its own script. To use it after an explicit prune request, copy `check-bib-usage.sh` and `prune-unused-bib.sh` into the LaTeX project root without overwriting existing files, make the copies executable, and run `bash "<project-root>/prune-unused-bib.sh" --yes "<absolute-bib-path>"`. If those filenames already belong to other files, or their parser cannot handle the input, perform the same backed-up removal directly with the available file tools. Do not run the prune helper from the installed skill directory.
