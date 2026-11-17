import os
import pathlib
import subprocess
import tempfile
import unittest

_ROOT = pathlib.Path(__file__).resolve().parents[1]
_PERSONAL = "phill@phillhood.ca"
_AETHON = "phood@aethonaerial.com"

_EXPECTED = {
    "personal": {
        "": (_PERSONAL, "id_phill"),
        "shychedelic": ("shy@shychedelic.com", "id_shy"),
        "aethon": (_AETHON, "id_rsa_aethon"),
        "phillhood": (_PERSONAL, "id_phill"),
    },
    "work": {
        "": (_AETHON, "id_rsa_aethon"),
        "shychedelic": (_AETHON, "id_rsa_aethon"),
        "aethon": (_AETHON, "id_rsa_aethon"),
        "phillhood": (_PERSONAL, None),
    },
}


def link_package(home, package):
    root = _ROOT / package
    for src in root.rglob("*"):
        if src.is_file():
            dst = home / src.relative_to(root)
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.symlink_to(src)


class GitIdentityTest(unittest.TestCase):
    def make_home(self, profile):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        home = pathlib.Path(tmp.name)
        for package in ("platform/shared/git", f"profile/{profile}/git"):
            link_package(home, package)
        bin_dir = home / "bin"
        bin_dir.mkdir()
        log = home / "ssh.log"
        for name in ("ssh", "windows-ssh"):
            fake = bin_dir / name
            fake.write_text(f'#!/bin/sh\necho "{name} $*" >> "{log}"\nexit 1\n')
            fake.chmod(0o755)
        return home, bin_dir, log

    def probe(self, home, bin_dir, log, owner, extra_env=None):
        repo = home / "Dev" / owner / "repo" if owner else home / "Dev" / "repo"
        repo.mkdir(parents=True, exist_ok=True)
        env = {
            "HOME": str(home),
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
            "GIT_CONFIG_NOSYSTEM": "1",
            "XDG_CONFIG_HOME": str(home / ".config"),
            **(extra_env or {}),
        }
        subprocess.run(["git", "init", "-q", str(repo)], env=env, check=True)
        email = subprocess.run(
            ["git", "-C", str(repo), "config", "user.email"],
            env=env, capture_output=True, text=True,
        ).stdout.strip()
        log.unlink(missing_ok=True)
        subprocess.run(
            ["git", "-C", str(repo), "ls-remote", "ssh://example.invalid/repo.git"],
            env=env, capture_output=True,
        )
        return email, log.read_text().splitlines()

    def test_identity_and_key_per_directory(self):
        for profile, cases in _EXPECTED.items():
            home, bin_dir, log = self.make_home(profile)
            for owner, (email, key) in cases.items():
                with self.subTest(profile=profile, owner=owner or "default"):
                    got_email, calls = self.probe(home, bin_dir, log, owner)
                    self.assertEqual(got_email, email)
                    self.assertEqual(len(calls), 1, calls)
                    self.assertTrue(calls[0].startswith("ssh "), calls)
                    if key:
                        self.assertIn(f"-i {home}/.ssh/{key} ", calls[0])
                    else:
                        self.assertNotIn("-i ", calls[0])

    def test_dotfiles_ssh_overrides_program_and_keeps_key(self):
        for profile, cases in _EXPECTED.items():
            home, bin_dir, log = self.make_home(profile)
            win = str(bin_dir / "windows-ssh")
            for owner, (_, key) in cases.items():
                with self.subTest(profile=profile, owner=owner or "default"):
                    _, calls = self.probe(home, bin_dir, log, owner, {"DOTFILES_SSH": win})
                    self.assertEqual(len(calls), 1, calls)
                    self.assertTrue(calls[0].startswith("windows-ssh "), calls)
                    if key:
                        self.assertIn(f"-i {home}/.ssh/{key} ", calls[0])


if __name__ == "__main__":
    unittest.main()
