import os
import pathlib
import subprocess
import tempfile
import unittest

_ROOT = pathlib.Path(__file__).resolve().parents[1]
_IDENTITIES = {"": "id_phill", "shychedelic": "id_shy", "aethon": "id_rsa_aethon"}


class GitSshCommandTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.home = pathlib.Path(tmp.name)
        for name in (".gitconfig", ".gitconfig-shy", ".gitconfig-aethon"):
            (self.home / name).symlink_to(_ROOT / "git" / name)
        self.log = self.home / "ssh.log"
        self.bin = self.home / "bin"
        self.bin.mkdir()
        for name in ("ssh", "windows-ssh"):
            fake = self.bin / name
            fake.write_text(f'#!/bin/sh\necho "{name} $*" >> "{self.log}"\nexit 1\n')
            fake.chmod(0o755)

    def ssh_calls(self, owner, extra_env):
        repo = self.home / "Dev" / owner / "repo" if owner else self.home / "Dev" / "repo"
        repo.mkdir(parents=True)
        env = {
            "HOME": str(self.home),
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "GIT_CONFIG_NOSYSTEM": "1",
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            **extra_env,
        }
        subprocess.run(["git", "init", "-q", str(repo)], env=env, check=True)
        self.log.unlink(missing_ok=True)
        subprocess.run(
            ["git", "-C", str(repo), "ls-remote", "ssh://example.invalid/repo.git"],
            env=env, capture_output=True,
        )
        return self.log.read_text().splitlines()

    def test_plain_ssh_when_unset(self):
        for owner, key in _IDENTITIES.items():
            with self.subTest(owner=owner or "default"):
                calls = self.ssh_calls(owner, {})
                self.assertEqual(len(calls), 1, calls)
                self.assertTrue(calls[0].startswith("ssh "), calls)
                self.assertIn(f"-i {self.home}/.ssh/{key} ", calls[0])

    def test_dotfiles_ssh_overrides_program_and_keeps_key(self):
        win = self.bin / "windows-ssh"
        for owner, key in _IDENTITIES.items():
            with self.subTest(owner=owner or "default"):
                calls = self.ssh_calls(owner, {"DOTFILES_SSH": str(win)})
                self.assertEqual(len(calls), 1, calls)
                self.assertTrue(calls[0].startswith("windows-ssh "), calls)
                self.assertIn(f"-i {self.home}/.ssh/{key} ", calls[0])


if __name__ == "__main__":
    unittest.main()
