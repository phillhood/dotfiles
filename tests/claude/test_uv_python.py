import json
import pathlib
import subprocess
import unittest

_ROOT = pathlib.Path(__file__).resolve().parents[2]
_SCRIPT = _ROOT / "platform" / "shared" / "claude" / ".claude" / "hooks" / "uv-python.sh"


class TestUvPythonHook(unittest.TestCase):
    def run_hook(self, command):
        payload = {"tool_name": "Bash", "tool_input": {"command": command}}
        return subprocess.run(
            [str(_SCRIPT)], input=json.dumps(payload), capture_output=True, text=True
        )

    def assertAllowed(self, command):
        r = self.run_hook(command)
        self.assertEqual(r.returncode, 0, f"{command!r} blocked: {r.stderr}")

    def assertBlocked(self, command):
        r = self.run_hook(command)
        self.assertEqual(r.returncode, 2, f"{command!r} allowed")
        self.assertTrue(r.stderr.strip())

    def test_bare_python_and_pip_are_blocked(self):
        for command in [
            "python x.py",
            "python3 -c 1",
            "pip install x",
            "cd a && python x.py",
            "ls | xargs python",
        ]:
            with self.subTest(command=command):
                self.assertBlocked(command)

    def test_uv_and_mentions_are_allowed(self):
        for command in [
            "uv run python x.py",
            "uv pip install x",
            "rg python notes.md",
            "Get-Content python.txt",
        ]:
            with self.subTest(command=command):
                self.assertAllowed(command)

    def test_powershell_forms_are_blocked(self):
        for command in [
            "& python x.py",
            "python.exe x.py",
            "pip.exe install x",
            "Set-Location a; python x.py",
        ]:
            with self.subTest(command=command):
                self.assertBlocked(command)


if __name__ == "__main__":
    unittest.main()
