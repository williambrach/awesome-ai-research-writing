# Awesome AI Research Writing

Academic writing workflows for **Claude Code, Codex, and ChatGPT**. Turn research notes into claims, audit a draft, polish LaTeX, and verify a bibliography.

## Install

### Claude Code

Project mode (skills scoped to the current directory):

```bash
curl -fsSL https://raw.githubusercontent.com/williambrach/awesome-ai-research-writing/main/install.sh | bash
```

Personal mode (skills available in every project):

```bash
curl -fsSL https://raw.githubusercontent.com/williambrach/awesome-ai-research-writing/main/install.sh | bash -s -- --global
```

These install into `./.claude/skills/` or `~/.claude/skills/`. Restart Claude Code and invoke a skill with `/polish`, `/claims`, etc. The default remains Claude Code; `--claude` selects it explicitly.

### Codex

Project mode:

```bash
curl -fsSL https://raw.githubusercontent.com/williambrach/awesome-ai-research-writing/main/install.sh | bash -s -- --codex
```

Personal mode:

```bash
curl -fsSL https://raw.githubusercontent.com/williambrach/awesome-ai-research-writing/main/install.sh | bash -s -- --codex --global
```

These install the ten first-party skills from [`codex/skills/`](codex/skills/) into `./.agents/skills/` or `~/.agents/skills/`, including invocation policies and bibliography helper scripts. Open Codex in your project, then use:

```text
$polish Improve this paragraph: ...
$finalize Make this LaTeX paragraph submission-ready: ...
$validate-bib references.bib
```

Codex discovers skills in these locations and supports `$skill-name` invocation. Restart it if new skills do not appear. See the [official OpenAI skills documentation](https://learn.chatgpt.com/docs/build-skills).

### ChatGPT

The ChatGPT edition is an uploadable prompt bundle containing the same ten first-party workflows. It works from pasted text or uploaded files.

1. Download [`chatgpt/research-writing.md`](chatgpt/research-writing.md).
2. Create a ChatGPT Project and upload that file as a project source.
3. Paste the contents of [`chatgpt/PROJECT_INSTRUCTIONS.md`](chatgpt/PROJECT_INSTRUCTIONS.md) into the project's instructions.
4. Start a chat in that project and supply your text or files with a request such as:

```text
Use polish on this LaTeX paragraph: ...
Use claims on these research notes: ...
Use finalize on the attached paragraph.
Use validate-bib on the attached references.bib and main.tex.
```

Project files and instructions provide shared context to chats in that project. Upload the paper sources you want it to use; a ChatGPT Project does not give access to your local paper folder. See [OpenAI's Projects documentation](https://learn.chatgpt.com/docs/projects).

For a one-off chat, attach the bundle and your input, then ask ChatGPT to apply a named skill from the bundle. These names are plain-text selectors, so this route does not require installed slash commands. `finalize` includes all three component workflows in the same bundle. Bibliography verification requires available web tools; entries that could not be verified are marked `?`. Usage checks also need the `.tex` sources.

To download both ChatGPT files from a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/williambrach/awesome-ai-research-writing/main/install.sh | bash -s -- --chatgpt
```

This writes to `./chatgpt/` for you to upload. `--global` does not apply to this export.

### Install from a clone or update

From a clone, run the installer directly to use the checked-out files:

```bash
./install.sh --codex
./install.sh --claude --no-external
./install.sh --chatgpt
```

For another paper project, run `/path/to/awesome-ai-research-writing/install.sh --codex` from that project's directory. Global installs use the home directory regardless of the working directory. On Windows, run the shell installer in WSL or copy the skill folders manually to the appropriate location.

Re-run the same install command to update. Curl-piped installs fetch the published `main` branch; local installs use your checkout. The installer stages all downloads before updating installed files. It also installs all three bibliography helpers; their execution needs Bash, standard Unix utilities, and Python 3.9+.

## Skills

Use `/name` in Claude Code, `$name` in Codex, or `Use name on ...` with the ChatGPT bundle.

| Skill | Description | If you... |
| :---- | :---------- | :-------- |
| `shorten` | Compress a LaTeX paragraph by 5–15 words | are a few words over the page limit |
| `polish` | Deep academic polish for top-conference submissions | want stronger grammar and phrasing |
| `de-ai` | Rewrite mechanical LLM-sounding text into natural academic English | read it back and it sounds generated |
| `logic-check` | Review fatal logic, terminology, and grammar issues | want substantive issues flagged without prose changes |
| `finalize` | Pipeline: logic-check → polish → de-ai | want a near-final paragraph ready for submission |
| `claims` | Compress findings into 1–3 specific claims with strength labels | have results but no clear story yet |
| `structure` | Audit an abstract or introduction against structural templates | are unsure whether the draft covers each required role |
| `prune` | Paragraph-level cut test: keep / tighten / move-to-appendix / cut | need to cut paragraphs but cannot decide which |
| `redteam` | Audit claims and evidence with severity-tagged findings | want to find weaknesses before reviewers do |
| `validate-bib` | Verify bibliography entries, annotate verdicts, and report citation usage | need to check references or identify unused/undefined citations |

The nine editing skills require explicit invocation. Claude uses `disable-model-invocation: true`; the Codex edition preserves that behavior with `policy.allow_implicit_invocation: false` in each skill's `agents/openai.yaml`. `validate-bib` retains its existing automatic matching for bibliography-check requests. The ChatGPT project instructions apply only the workflow you request.

## External skills (Claude Code)

The Claude installer also fetches these upstream skills by default. Pass `--no-external` to skip them. They are not included in the Codex edition or ChatGPT bundle; their instructions and compatibility are maintained upstream.

| Command | Description | Source |
| :------ | :---------- | :----- |
| `/humanize-sk` | Rewrite AI-generated Slovak text to sound natural | [vikiival/humanize-sk](https://github.com/vikiival/humanize-sk) |
| `/no-ai-slop` | General-purpose editing for posts, emails, and blogs | [petergyang/no-ai-slop](https://github.com/petergyang/no-ai-slop) |

## Maintaining the editions

The first-party `.claude/skills/*/SKILL.md` files are the source for shared editing instructions. The OpenAI-specific `finalize` and bibliography workflows live in [`scripts/openai/`](scripts/openai/). They use the current environment's tools and support working without local file access.

After editing a source skill or an OpenAI template, regenerate and check the committed packages:

```bash
python3 scripts/build_openai.py
python3 scripts/build_openai.py --check
python3 -m unittest discover -s tests -v
```

Commit the generated `codex/skills/` and `chatgpt/research-writing.md` files with their sources. Generation uses only Python's standard library; users do not need Python to install the writing skills or export the ChatGPT bundle.
