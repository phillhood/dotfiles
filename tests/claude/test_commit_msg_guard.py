import json
import pathlib
import subprocess
import tempfile
import unittest

_ROOT = pathlib.Path(__file__).resolve().parents[2]
_SCRIPT = _ROOT / "claude" / ".claude" / "hooks" / "commit-msg-guard.sh"

_ABSENT = object()


def git(cwd, *args):
    subprocess.run(
        ["git", "-C", str(cwd), "-c", "user.name=t", "-c", "user.email=t@t", *args],
        check=True,
        capture_output=True,
    )


def heredoc(first_line, quoted):
    delim = "'EOF'" if quoted else "EOF"
    return (
        f'git commit -m "$(cat <<{delim}\n'
        f"{first_line}\n"
        "\n"
        "Body line.\n"
        "EOF\n"
        ')"'
    )


class TestCommitMsgGuard(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = pathlib.Path(self._tmp.name).resolve()

    def run_hook(self, command, cwd=_ABSENT):
        payload = {"tool_name": "Bash", "tool_input": {"command": command}}
        if cwd is not _ABSENT:
            payload["cwd"] = str(cwd)
        return subprocess.run(
            [str(_SCRIPT)],
            input=json.dumps(payload),
            cwd=str(self.tmp),
            capture_output=True,
            text=True,
        )

    def assertAllowed(self, command, cwd=_ABSENT):
        r = self.run_hook(command, cwd)
        self.assertEqual(r.returncode, 0, f"{command!r} blocked: {r.stderr}")
        return r

    def assertBlocked(self, command, cwd=_ABSENT):
        r = self.run_hook(command, cwd)
        self.assertEqual(r.returncode, 2, f"{command!r} allowed")
        self.assertTrue(r.stderr.strip())
        return r

    def commit(self, subject):
        return f'git commit -m "{subject}"'

    def test_command_without_commit_is_allowed(self):
        self.assertAllowed("ls -la && echo hi")

    def test_conventional_subject_is_allowed(self):
        self.assertAllowed('git commit -m "fix: handle empty input"')

    def test_unprefixed_subject_is_blocked_and_names_types(self):
        r = self.assertBlocked('git commit -m "bump forgejo to 17.0.1"')
        self.assertIn("feat", r.stderr)
        self.assertIn("fix", r.stderr)
        self.assertNotRegex(r.stderr, r"[\w.-]+/[\w.-]+\.(sh|md|json)")

    def test_scope_and_breaking_marker_are_allowed(self):
        self.assertAllowed('git commit -m "feat(api)!: drop v1"')
        self.assertAllowed('git commit -m "docs(read.me/x-1): tidy"')

    def test_malformed_prefixes_are_blocked(self):
        for subject in [
            "Fix: thing",
            "FIX: thing",
            "fix: Thing",
            "wip: thing",
            "fix:thing",
            "fix:  thing",
            "fix: ",
            "fix(API): thing",
        ]:
            with self.subTest(subject=subject):
                self.assertBlocked(self.commit(subject))

    def test_attribution_is_blocked_even_with_valid_prefix(self):
        self.assertBlocked(
            'git commit -m "fix: a" -m "Co-Authored-By: Claude <noreply@anthropic.com>"'
        )
        self.assertBlocked(
            'git commit -m "fix: a" -m "Generated with [Claude Code](https://claude.com)"'
        )

    def test_heredoc_message(self):
        for quoted in (True, False):
            with self.subTest(quoted=quoted):
                self.assertAllowed(heredoc("fix: handle heredoc", quoted))
                self.assertBlocked(heredoc("handle heredoc", quoted))

    def test_commit_without_inline_message_is_allowed(self):
        for command in [
            "git commit",
            "git commit --amend --no-edit",
            "git commit -F msg.txt",
            "git commit -C HEAD",
            "git commit --fixup HEAD",
        ]:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_exempt_subjects_are_allowed(self):
        for command in [
            "git commit -m \"Merge branch 'x' into main\"",
            "git commit -m 'Revert \"fix: y\"'",
            'git commit -m "fixup! fix: y"',
            'git commit -m "squash! fix: y"',
            'git commit -m "amend! fix: y"',
            'git commit -m "CORE-155 concern data-layer foundation"',
        ]:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_result_does_not_depend_on_cwd(self):
        unprefixed = self.tmp / "unprefixed"
        unprefixed.mkdir()
        git(unprefixed, "init", "-q", "-b", "main")
        git(unprefixed, "commit", "-q", "--allow-empty", "-m", "add things")
        empty = self.tmp / "empty"
        empty.mkdir()
        git(empty, "init", "-q", "-b", "main")
        plain = self.tmp / "plain"
        plain.mkdir()
        for cwd in [unprefixed, empty, plain, _ABSENT]:
            with self.subTest(cwd=cwd if cwd is not _ABSENT else "absent"):
                self.assertAllowed('git commit -m "fix: handle empty input"', cwd)
                self.assertBlocked('git commit -m "bump forgejo to 17.0.1"', cwd)

    def test_commit_inside_compound_commands(self):
        self.assertAllowed('git -C /tmp/x commit -q -m "fix: a"')
        self.assertBlocked('cd x && git add -A && git commit -m "add things" && git push')
        self.assertAllowed(
            'git add -A && git commit -q -m "chore: bump x" && git log --oneline -1'
        )

    def test_global_config_option_before_commit(self):
        self.assertAllowed('git -c user.name=x commit -m "fix: a"')
        self.assertBlocked('git -c user.name=x commit -m "a thing"')

    def test_message_flag_forms(self):
        for command in [
            'git commit -am "fix: a"',
            'git commit -qm "fix: a"',
            'git commit --message="fix: a"',
            'git commit --message "fix: a"',
            "git commit -m 'fix: a'",
            'git commit -m "docs: a" -m "Body Text"',
        ]:
            with self.subTest(command=command):
                self.assertAllowed(command)
        self.assertBlocked('git commit -am "a thing"')
        self.assertBlocked('git commit -m "a thing" -m "fix: body"')

    def test_non_commit_git_commands_are_allowed(self):
        self.assertAllowed("git show HEAD")
        self.assertAllowed("git status")

    def test_every_commit_in_a_command_is_checked(self):
        for sep in [" && ", "; ", "\n"]:
            with self.subTest(sep=sep):
                self.assertBlocked(f'git commit -m "fix: a"{sep}git commit -m "bad subject"')
                self.assertBlocked(
                    f'git commit --amend --no-edit{sep}git commit -m "bad subject"'
                )
                self.assertAllowed(f'git commit -m "fix: a"{sep}git commit -m "docs: b"')
        self.assertBlocked(heredoc("fix: a", True) + ' && git commit -m "bad subject"')
        self.assertAllowed(heredoc("fix: a", True) + ' && git commit -m "docs: b"')

    def test_quoted_global_option_values(self):
        self.assertBlocked('git -C "/tmp/a b" commit -m "bad subject"')
        self.assertAllowed('git -C "/tmp/a b" commit -m "fix: a"')
        self.assertBlocked('git -c user.name="Test User" commit -m "bad subject"')
        self.assertAllowed('git -c user.name="Test User" commit -m "fix: a"')

    def test_global_options_are_parsed_not_skipped(self):
        self.assertBlocked('git -C /tmp/x commit -q -m "add things"')
        self.assertBlocked('git -c k=v commit -m "add things"')
        self.assertAllowed('git -c k=v commit -m "fix: a"')

    def test_double_dash_ends_option_scanning(self):
        self.assertAllowed("git commit -- -myfile")
        self.assertAllowed('git commit -a -- -myfile && echo "done"')

    def test_commit_mentioned_in_quoted_text_is_allowed(self):
        for command in [
            'echo "git commit -m nothing"',
            'rg -n "git commit -m" notes.md',
            "printf '%s\\n' 'git commit -m \"x\"'",
            'echo "then run git commit -m nothing"',
            "rg -n 'use git commit -m' notes.md",
        ]:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_git_after_assignments_and_wrappers_is_checked(self):
        self.assertBlocked('GIT_AUTHOR_NAME=x git commit -m "bad subject"')
        self.assertBlocked('sudo git commit -m "bad subject"')
        self.assertBlocked('if true; then git commit -m "bad subject"; fi')
        self.assertBlocked('(cd x && git commit -m "bad subject")')
        self.assertAllowed('GIT_AUTHOR_NAME=x git commit -m "fix: a"')
        self.assertBlocked(
            'GIT_AUTHOR_NAME=x git commit -m "fix: a" -m "Co-Authored-By: Claude <noreply@anthropic.com>"'
        )

    def test_unevaluable_message_is_allowed(self):
        for command in [
            'git commit -m "$MSG"',
            "git commit -m \"$(printf '%s' \"$subject\")\"",
            "git commit -m $MSG",
            'git commit -m "`cat msg.txt`"',
        ]:
            with self.subTest(command=command):
                self.assertAllowed(command)
        self.assertBlocked("git commit -m '$MSG'")


if __name__ == "__main__":
    unittest.main()
