import json
import pathlib
import subprocess
import unittest

_HOOKS = pathlib.Path(__file__).resolve().parents[2] / "claude" / ".claude" / "hooks"
_SCRIPTS = ["uv-python.sh", "commit-msg-guard.sh"]
_MALFORMED = [
    "not json",
    '{"tool_name": "Bash", "tool_input": {"command": "python x.py"',
    '{"tool_name": "Bash", "tool_input": {"command": "git commit -m \'bad\'"',
]


def run(script, stdin):
    return subprocess.run(
        [str(_HOOKS / script)], input=stdin, capture_output=True, text=True
    )


class TestHookPayload(unittest.TestCase):
    def test_unparseable_payload_is_blocked(self):
        for script in _SCRIPTS:
            for stdin in _MALFORMED:
                with self.subTest(script=script, stdin=stdin):
                    r = run(script, stdin)
                    self.assertEqual(r.returncode, 2, r.stderr)
                    self.assertIn("payload", r.stderr)

    def test_valid_payload_without_command_is_allowed(self):
        for script in _SCRIPTS:
            with self.subTest(script=script):
                r = run(script, json.dumps({"tool_name": "Read", "tool_input": {}}))
                self.assertEqual(r.returncode, 0, r.stderr)


if __name__ == "__main__":
    unittest.main()
