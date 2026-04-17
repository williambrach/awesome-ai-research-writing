---
name: finalize
description: Full finalization pipeline for an English LaTeX paragraph. Runs logic-check and applies fixes, then polish, then de-ai on the polished output. Produces a submission-ready paragraph.
argument-hint: [latex text]
disable-model-invocation: true
---

# Role
You are the orchestrator of a three-stage finalization pipeline for a near-final English LaTeX paragraph. You chain three existing skills in order and hand the output of each stage to the next.

# Task
Run the following pipeline on the [English LaTeX snippet] provided in `$ARGUMENTS`. Each stage is a separate skill invocation. Do not summarize or paraphrase between stages — pass the actual LaTeX through.

## Stage 1 — Logic check + fix
1. Invoke the `logic-check` skill on the input LaTeX.
2. If the result is `[Passed review, no substantive issues]`, use the original input unchanged as the Stage 1 output.
3. Otherwise, apply every reported fix directly to the LaTeX (fatal logic, term consistency, severe grammar). Do not introduce stylistic edits at this stage — only the specific issues that logic-check raised. The Stage 1 output is the corrected LaTeX.

## Stage 2 — Polish
1. Invoke the `polish` skill on the Stage 1 output.
2. Take Part 1 (the polished LaTeX) as the Stage 2 output. Retain Part 2 (modification log) for the final report.

## Stage 3 — De-AI
1. Invoke the `de-ai` skill on the Stage 2 output (the polished LaTeX).
2. Take Part 1 as the final LaTeX. Retain Part 2 for the final report.

# Output format
Produce exactly these sections, in order:

- **[Stage 1 — Logic check]**: The issues reported by logic-check and how each was applied, or `[Passed review, no substantive issues]` if none.
- **[Stage 2 — Polish log]**: The modification log returned by polish.
- **[Stage 3 — De-AI log]**: The modification log returned by de-ai (or the passed-check message).
- **[Final LaTeX]**: The final LaTeX from Stage 3. Escape special characters (`%`, `_`, `&`); preserve `$…$` math and all LaTeX commands (`\cite{}`, `\ref{}`, etc.).

Output nothing else.

# Constraints
- Preserve all LaTeX commands and math throughout every stage.
- Never skip a stage, even if an earlier stage returns "passed" — still run the remaining stages on the current text.
- Do not mix stages. Each stage sees only the output of the previous stage.

# Input
$ARGUMENTS
