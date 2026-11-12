import json
import os
import pathlib
import subprocess
import tempfile
import unittest

_ROOT = pathlib.Path(__file__).resolve().parents[2]
_SCRIPT = _ROOT / "claude" / ".claude" / "hooks" / "herdr-worktree.sh"

_FAKE_HERDR = """#!/bin/sh
printf '%s\\n' "$*" >> "$HERDR_FAKE_LOG"
echo noise
"""


def git(cwd, *args):
    subprocess.run(
        ["git", "-C", str(cwd), "-c", "user.name=t", "-c", "user.email=t@t", *args],
        check=True,
        capture_output=True,
    )


class TestHerdrWorktreeHook(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        tmp = pathlib.Path(self._tmp.name).resolve()
        self.main = tmp / "repo"
        self.linked = tmp / "feature-x"
        self.plain = tmp / "plain"
        self.main.mkdir()
        self.plain.mkdir()
        git(self.main, "init", "-q", "-b", "main")
        git(self.main, "commit", "-q", "--allow-empty", "-m", "init")
        git(self.main, "worktree", "add", "-q", "-b", "feature", str(self.linked))
        (self.linked / "sub").mkdir()
        bin_dir = tmp / "bin"
        bin_dir.mkdir()
        fake = bin_dir / "herdr"
        fake.write_text(_FAKE_HERDR)
        fake.chmod(0o755)
        self.log = tmp / "herdr.log"
        self.env = {
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
            "HOME": str(tmp),
            "HERDR_ENV": "1",
            "HERDR_PANE_ID": "w1:p1",
            "HERDR_FAKE_LOG": str(self.log),
        }

    def run_hook(self, payload, env=None, cwd=None):
        return subprocess.run(
            [str(_SCRIPT)],
            input=json.dumps(payload),
            env=self.env if env is None else env,
            cwd=str(cwd or self.plain),
            capture_output=True,
            text=True,
        )

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_linked_worktree_reports_its_folder_name(self):
        r = self.run_hook({"cwd": str(self.linked)})
        self.assertEqual(r.returncode, 0)
        self.assertEqual(
            self.calls(),
            ["pane report-metadata w1:p1 --source dotfiles:worktree --token worktree=feature-x"],
        )

    def test_subdirectory_of_linked_worktree_reports_worktree_root(self):
        self.run_hook({"cwd": str(self.linked / "sub")})
        self.assertEqual(
            self.calls(),
            ["pane report-metadata w1:p1 --source dotfiles:worktree --token worktree=feature-x"],
        )

    def test_main_checkout_clears_the_token(self):
        self.run_hook({"cwd": str(self.main)})
        self.assertEqual(
            self.calls(),
            ["pane report-metadata w1:p1 --source dotfiles:worktree --clear-token worktree"],
        )

    def test_non_git_directory_clears_the_token(self):
        self.run_hook({"cwd": str(self.plain)})
        self.assertEqual(
            self.calls(),
            ["pane report-metadata w1:p1 --source dotfiles:worktree --clear-token worktree"],
        )

    def test_missing_cwd_falls_back_to_process_directory(self):
        self.run_hook({}, cwd=self.linked)
        self.assertEqual(
            self.calls(),
            ["pane report-metadata w1:p1 --source dotfiles:worktree --token worktree=feature-x"],
        )

    def test_subagent_events_are_ignored(self):
        r = self.run_hook({"cwd": str(self.linked), "agent_id": "a1"})
        self.assertEqual(r.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_outside_herdr_does_nothing(self):
        env = {k: v for k, v in self.env.items() if k not in ("HERDR_ENV", "HERDR_PANE_ID")}
        r = self.run_hook({"cwd": str(self.linked)}, env=env)
        self.assertEqual(r.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_prints_nothing(self):
        r = self.run_hook({"cwd": str(self.linked)})
        self.assertEqual(r.stdout, "")
        self.assertEqual(r.stderr, "")


if __name__ == "__main__":
    unittest.main()
