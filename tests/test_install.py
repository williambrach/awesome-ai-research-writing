"""Exercise local and curl-piped installs without network or real home changes."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SKILLS = {
    "claims", "de-ai", "finalize", "logic-check", "polish", "prune",
    "redteam", "shorten", "structure", "validate-bib",
}
HELPERS = ("check-bib-usage.sh", "prune-unused-bib.sh", "merge-reports.py")


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="research writing test ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.project = self.root / "paper project"
        self.home = self.root / "test home"
        self.bin = self.root / "bin"
        for directory in (self.project, self.home, self.bin):
            directory.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        self.env["INSTALL_TEST_REPO"] = str(ROOT)
        self.env["INSTALL_TEST_LOG"] = str(self.root / "downloads.txt")
        # The same entry point works with fixture downloads or real local copies.
        curl = self.bin / "curl"
        curl.write_text("#!" + sys.executable + "\n" + '''
import os
from pathlib import Path
import sys

args = sys.argv[1:]
url = next(arg for arg in args if arg.startswith("https://"))
destination = Path(args[args.index("-o") + 1])
with open(os.environ["INSTALL_TEST_LOG"], "a") as log:
    log.write(url + "\\n")
failure = os.environ.get("INSTALL_TEST_FAIL")
if failure and failure in url:
    destination.write_text("partial download")
    sys.exit(22)
base = "https://raw.githubusercontent.com/williambrach/awesome-ai-research-writing/main/"
if url.startswith(base):
    source = Path(os.environ["INSTALL_TEST_REPO"]) / url[len(base):]
    if not source.is_file():
        sys.exit(22)
    destination.write_bytes(source.read_bytes())
elif url.startswith("https://raw.githubusercontent.com/vikiival/humanize-sk/main/"):
    destination.write_text("upstream humanize-sk fixture\\n")
elif url.startswith("https://raw.githubusercontent.com/petergyang/no-ai-slop/main/skills/no-ai-slop/"):
    destination.write_text("upstream no-ai-slop fixture\\n")
else:
    sys.exit(22)
''', encoding="utf-8")
        curl.chmod(0o755)

    def install(self, *args, piped=False, success=True):
        command = ["bash", "-s", "--", *args] if piped else ["bash", str(ROOT / "install.sh"), *args]
        result = subprocess.run(
            command, input=(ROOT / "install.sh").read_text() if piped else None,
            cwd=self.project, env=self.env, text=True, capture_output=True,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def assert_skills(self, directory, platform):
        self.assertEqual({p.parent.name for p in directory.glob("*/SKILL.md")}, SKILLS)
        source = ROOT / ("codex/skills" if platform == "codex" else ".claude/skills")
        for name in SKILLS:
            self.assertEqual((directory / name / "SKILL.md").read_bytes(), (source / name / "SKILL.md").read_bytes())
            if platform == "codex":
                policy = (directory / name / "agents/openai.yaml").read_text()
                expected = "true" if name == "validate-bib" else "false"
                self.assertEqual(policy, "policy:\n  allow_implicit_invocation: " + expected + "\n")
        for helper in HELPERS:
            path = directory / "validate-bib" / helper
            self.assertTrue(os.access(path, os.X_OK), helper)
            self.assertEqual(path.read_bytes(), (source / "validate-bib" / helper).read_bytes())

    def test_local_codex_project_install_and_update(self):
        self.install("--codex")
        target = self.project / ".agents/skills"
        self.assert_skills(target, "codex")
        (target / "polish/SKILL.md").write_text("older version")
        unrelated = target / "unrelated.txt"
        unrelated.write_text("keep")
        self.install("--codex")
        self.assert_skills(target, "codex")
        self.assertEqual(unrelated.read_text(), "keep")
        self.assertFalse((self.root / "downloads.txt").exists())
        self.assertFalse((self.project / ".claude").exists())

    def test_local_claude_default_remains_compatible(self):
        self.install("--no-external")
        self.assert_skills(self.project / ".claude/skills", "claude")
        self.assertFalse((self.project / ".agents").exists())

    def test_piped_codex_installs_all_resources_without_external_downloads(self):
        self.install("--codex", piped=True)
        self.assert_skills(self.project / ".agents/skills", "codex")
        downloads = (self.root / "downloads.txt").read_text().splitlines()
        self.assertEqual(len(downloads), 23)
        self.assertTrue(all("/codex/skills/" in url for url in downloads))

    def test_piped_claude_includes_upstream_resources_by_default(self):
        self.install(piped=True)
        target = self.project / ".claude/skills"
        self.assertEqual(len(list(target.glob("*/SKILL.md"))), 12)
        self.assertTrue((target / "no-ai-slop/eval.md").is_file())
        self.assertTrue((target / "humanize-sk/SKILL.md").is_file())
        for helper in HELPERS:
            self.assertTrue(os.access(target / "validate-bib" / helper, os.X_OK))

    def test_global_flags_are_order_independent(self):
        for args in (("--codex", "--global"), ("--global", "--codex"), ("--claude", "-g", "--no-external")):
            with self.subTest(args=args):
                self.install(*args)
        self.assert_skills(self.home / ".agents/skills", "codex")
        self.assert_skills(self.home / ".claude/skills", "claude")
        self.assertEqual(list(self.project.iterdir()), [])

    def test_project_flag_overrides_global(self):
        self.install("--global", "--codex", "-p")
        self.assert_skills(self.project / ".agents/skills", "codex")
        self.assertEqual(list(self.home.iterdir()), [])

    def test_chatgpt_local_and_piped_exports(self):
        for piped in (False, True):
            with self.subTest(piped=piped):
                self.install("--chatgpt", piped=piped)
                for name in ("PROJECT_INSTRUCTIONS.md", "research-writing.md"):
                    self.assertEqual((self.project / "chatgpt" / name).read_bytes(), (ROOT / "chatgpt" / name).read_bytes())
        self.assertEqual({p.name for p in self.project.iterdir()}, {"chatgpt"})

    def test_invalid_arguments_fail_without_writing(self):
        for args in (("--chatgpt", "--global"), ("--unknown",)):
            with self.subTest(args=args):
                self.install(*args, success=False)
        self.assertEqual(list(self.project.iterdir()), [])
        self.assertEqual(list(self.home.iterdir()), [])

    def test_help_has_no_side_effects(self):
        self.install("--help")
        self.assertEqual(list(self.project.iterdir()), [])
        self.assertFalse((self.root / "downloads.txt").exists())

    def test_download_failure_preserves_existing_installation(self):
        self.install("--codex")
        target = self.project / ".agents/skills"
        (target / "claims/SKILL.md").write_text("user's existing version")
        before = {p.relative_to(target): p.read_bytes() for p in target.rglob("*") if p.is_file()}
        self.env["INSTALL_TEST_FAIL"] = "/structure/SKILL.md"
        self.install("--codex", piped=True, success=False)
        after = {p.relative_to(target): p.read_bytes() for p in target.rglob("*") if p.is_file()}
        self.assertEqual(before, after)

    def test_chatgpt_download_failure_preserves_both_files(self):
        self.install("--chatgpt")
        target = self.project / "chatgpt"
        (target / "PROJECT_INSTRUCTIONS.md").write_text("custom instructions")
        self.env["INSTALL_TEST_FAIL"] = "/research-writing.md"
        self.install("--chatgpt", piped=True, success=False)
        self.assertEqual((target / "PROJECT_INSTRUCTIONS.md").read_text(), "custom instructions")

    def test_installed_bibliography_helpers_work_from_paper_project(self):
        self.install("--codex")
        helper = self.project / ".agents/skills/validate-bib"
        bib = self.project / "references.bib"
        bib.write_text('@article{used,\n  title = {A real test entry},\n  year = {2024}\n}\n\n@book{unused,\n  title = {Another entry}\n}\n')
        (self.project / "main.tex").write_text(r"We cite \cite{used,undefined}." + "\n")
        usage = subprocess.run(["bash", str(helper / "check-bib-usage.sh"), str(bib), str(self.project)], text=True, capture_output=True)
        self.assertEqual(usage.returncode, 0, usage.stderr)
        self.assertIn("--- Unused entries ---\nunused", usage.stdout)
        self.assertIn("--- Undefined citations ---\nundefined", usage.stdout)
        reports = self.root / "reports"
        reports.mkdir()
        (reports / "chunk_1.txt").write_text("used|?|Test fixture, no web verification\nunused|?|Test fixture, no web verification\n")
        merge = subprocess.run([sys.executable, str(helper / "merge-reports.py"), str(bib), str(reports)], text=True, capture_output=True)
        self.assertEqual(merge.returncode, 0, merge.stderr)
        self.assertEqual(bib.read_text().count("% ? Test fixture"), 2)
        for name in ("check-bib-usage.sh", "prune-unused-bib.sh"):
            destination = self.project / name
            destination.write_bytes((helper / name).read_bytes())
            destination.chmod(0o755)
        prune = subprocess.run(["bash", str(self.project / "prune-unused-bib.sh"), "--yes", str(bib)], text=True, capture_output=True)
        self.assertEqual(prune.returncode, 0, prune.stderr)
        self.assertIn("@article{used,", bib.read_text())
        self.assertNotIn("@book{unused,", bib.read_text())
        self.assertEqual(len(list(self.project.glob("references.bib.bak.*"))), 1)


class PackageTests(unittest.TestCase):
    def test_generated_packages_are_current(self):
        result = subprocess.run([sys.executable, str(ROOT / "scripts/build_openai.py"), "--check"], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_native_skills_have_valid_identity_and_no_claude_placeholders(self):
        paths = list((ROOT / "codex/skills").glob("*/SKILL.md"))
        self.assertEqual({path.parent.name for path in paths}, SKILLS)
        for path in paths:
            content = path.read_text()
            frontmatter = content.split("---\n", 2)[1]
            metadata = dict(line.split(": ", 1) for line in frontmatter.strip().splitlines())
            self.assertEqual(metadata["name"], path.parent.name)
            self.assertTrue(json.loads(metadata["description"]))
            self.assertNotIn("$ARGUMENTS", content)
            self.assertNotIn(".claude/", content)
            self.assertNotIn("WebFetch", content)
            self.assertNotIn("subagent_type", content)

    def test_chatgpt_bundle_contains_all_workflows_without_local_dependencies(self):
        content = (ROOT / "chatgpt/research-writing.md").read_text()
        names = {line.removeprefix("## Skill: ") for line in content.splitlines() if line.startswith("## Skill: ")}
        self.assertEqual(names, SKILLS)
        self.assertNotIn("$ARGUMENTS", content)
        self.assertNotIn(".claude/", content)
        self.assertNotIn("../logic-check/SKILL.md", content)
        self.assertNotIn("merge-reports.py", content)


if __name__ == "__main__":
    unittest.main()
