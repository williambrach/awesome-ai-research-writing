---
name: finalize
description: "Full finalization pipeline for an English LaTeX paragraph. Runs logic-check and applies fixes, then polish, then de-ai on the polished output. Produces a submission-ready paragraph."
---

# Role
Finalize a near-final English LaTeX paragraph by applying three editing skills in order.

# Input
Use the text or file supplied with the user's request. Read a named file with the available file tools. If no input is available, ask for the text or file instead of inventing it.

# Workflow
Read [logic-check](../logic-check/SKILL.md), [polish](../polish/SKILL.md), and [de-ai](../de-ai/SKILL.md) relative to this skill folder. Apply their instructions directly, keeping the stages separate. No slash-command tool or subagent is required. Pass the actual LaTeX output of each stage into the next stage without summarizing it.

## Stage 1: Logic check and fix
1. Apply `logic-check` to the input LaTeX.
2. If it returns `[Passed review, no substantive issues]`, keep the original as the Stage 1 output.
3. Otherwise, apply the reported corrections to fatal logic, inconsistent terms, and severe grammar. Do not make stylistic edits at this stage. If a correction needs missing evidence or author input, report the unresolved issue without inventing a fact.

## Stage 2: Polish
1. Apply `polish` to the Stage 1 output.
2. Take Part 1, the polished LaTeX, as the Stage 2 output. Retain its modification log.

## Stage 3: De-AI
1. Apply `de-ai` to the Stage 2 output.
2. Take Part 1 as the final LaTeX. Retain its modification log.

# Output format
Produce exactly these sections, in order:

- **[Stage 1 — Logic check]**: The issues found and how each was applied, any unresolved issues, or `[Passed review, no substantive issues]`.
- **[Stage 2 — Polish log]**: The modification log from `polish`.
- **[Stage 3 — De-AI log]**: The modification log from `de-ai`, or its passed-check message.
- **[Final LaTeX]**: The final LaTeX from Stage 3.

Output nothing else.

# Constraints
- Preserve all LaTeX commands, citations, references, math, and existing escapes throughout every stage. Escape special characters in prose without double-escaping existing LaTeX.
- Never skip a stage, even if an earlier stage passes unchanged.
- Each editing stage sees only the previous stage's LaTeX output. Keep logs separately for the final report.
- Never invent claims, numbers, citations, or results.
