# Install


### Project mode (skills scoped to the current directory)
```bash
curl -sL https://raw.githubusercontent.com/williambrach/awesome-ai-research-writing/main/install.sh | bash
```

### Personal mode (skills available in every project)
```bash
curl -sL https://raw.githubusercontent.com/williambrach/awesome-ai-research-writing/main/install.sh | bash -s -- --global
```

Both commands fetch the `SKILL.md` files into `./.claude/skills/` (project) or `~/.claude/skills/` (global). Restart Claude Code and the slash commands become available. Re-run the same command any time to update to the latest versions.

## Skills

| Command        | Description                                                                       | If you...                                                        |
| :------------- | :-------------------------------------------------------------------------------- | :--------------------------------------------------------------- |
| `/shorten`     | Compress a LaTeX paragraph by 5-15 words                                          | are a few words over the page limit on a paragraph               |
| `/polish`      | Deep academic polish for top-conference submissions                               | want NeurIPS-grade grammar and phrasing on a paragraph           |
| `/de-ai`       | Rewrite LLM-sounding text into natural academic English                           | read it back and it sounds like ChatGPT wrote it                 |
| `/logic-check` | Red-line review: fatal logic / terminology / grammar only                         | want only fatal issues flagged, no prose changes                 |
| `/finalize`    | Pipeline: logic-check → polish → de-ai on a near-final paragraph                  | have a near-final paragraph you want submission-ready in one go  |
| `/claims`      | Compress research findings into 1-3 specific claims with strength labels          | have results but no clear story yet                              |
| `/structure`   | Audit an abstract or introduction against role-by-role templates                  | are not sure your abstract or introduction covers what it should |
| `/prune`       | Paragraph-by-paragraph cut-test: keep / tighten / move-to-appendix / cut          | have to cut paragraphs but cannot decide which                   |
| `/redteam`     | Hostile pre-submission audit of claims and evidence with severity-tagged findings | worry a reviewer will find a hole you missed                     |

All skills have `disable-model-invocation: true` in their frontmatter — Claude will not spontaneously rewrite your text. You must type the slash command explicitly. This protects your drafts from unwanted edits.
