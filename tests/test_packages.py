import itertools
import pathlib
import shutil
import subprocess
import unittest

_ROOT = pathlib.Path(__file__).resolve().parents[1]
_OSES = ["darwin", "linux", "windows", "wsl"]
_PROFILES = ["personal", "work"]
_STOW_IGNORE = {".stow-local-ignore", ".gitignore", "README.md", "LICENSE", "COPYING"}


def layers():
    rows = {}
    for line in (_ROOT / "layers.conf").read_text().splitlines():
        fields = line.split()
        if fields and not fields[0].startswith("#"):
            rows[fields[0]] = fields[1:]
    return rows


def packages(layer):
    root = _ROOT / layer
    return [f"{layer}/{p.name}" for p in sorted(root.iterdir()) if p.is_dir()] if root.is_dir() else []


def expected(os, profile):
    platform = [p for layer in layers()[os] for p in packages(f"platform/{layer}")]
    names = {p.rsplit("/", 1)[1] for p in platform}
    every_name = {
        p.rsplit("/", 1)[1]
        for layer in (_ROOT / "platform").iterdir()
        for p in packages(f"platform/{layer.name}")
    }
    personal = [
        p for p in packages(f"profile/{profile}")
        if p.rsplit("/", 1)[1] in names or p.rsplit("/", 1)[1] not in every_name
    ]
    return platform + personal


class LayersTest(unittest.TestCase):
    def test_layers_conf_matches_folders(self):
        self.assertEqual(sorted(layers()), _OSES)
        used = {layer for row in layers().values() for layer in row}
        folders = {p.name for p in (_ROOT / "platform").iterdir() if p.is_dir()}
        self.assertEqual(used, folders)
        self.assertEqual({p.name for p in (_ROOT / "profile").iterdir() if p.is_dir()}, set(_PROFILES))

    def test_no_loose_files_in_layers(self):
        for group in ("platform", "profile"):
            for layer in (_ROOT / group).iterdir():
                with self.subTest(layer=f"{group}/{layer.name}"):
                    self.assertEqual([f.name for f in layer.iterdir() if not f.is_dir()], [])

    def test_profile_packages_follow_their_platform_package(self):
        self.assertIn("profile/personal/zsh", expected("linux", "personal"))
        self.assertNotIn("profile/personal/zsh", expected("windows", "personal"))
        self.assertIn("profile/personal/pwsh", expected("windows", "personal"))
        self.assertNotIn("profile/personal/pwsh", expected("darwin", "personal"))
        for os in _OSES:
            self.assertIn("profile/personal/ssh", expected(os, "personal"))

    def test_selected_packages_never_share_a_file(self):
        for os, profile in itertools.product(_OSES, _PROFILES):
            with self.subTest(os=os, profile=profile):
                owners = {}
                for pkg in expected(os, profile):
                    root = _ROOT / pkg
                    for f in root.rglob("*"):
                        if f.is_file() and f.name not in _STOW_IGNORE:
                            rel = f.relative_to(root)
                            self.assertNotIn(rel, owners, f"{pkg} and {owners.get(rel)}")
                            owners[rel] = pkg

    def test_make_selects_layers(self):
        for os, profile in itertools.product(_OSES, _PROFILES):
            with self.subTest(os=os, profile=profile):
                out = subprocess.run(
                    ["make", "-s", "packages", f"OS={os}", f"PROFILE={profile}"],
                    cwd=_ROOT, check=True, capture_output=True, text=True,
                )
                self.assertEqual(out.stderr, "")
                self.assertEqual(out.stdout.split(), expected(os, profile))

    def test_make_rejects_unknown_profile_and_os(self):
        for arg in ("PROFILE=nope", "OS=nope"):
            with self.subTest(arg=arg):
                out = subprocess.run(
                    ["make", "-s", "packages", arg], cwd=_ROOT, capture_output=True, text=True
                )
                self.assertNotEqual(out.returncode, 0)

    @unittest.skipUnless(shutil.which("pwsh"), "pwsh not installed")
    def test_install_ps1_selects_layers(self):
        for profile in _PROFILES:
            with self.subTest(profile=profile):
                out = subprocess.run(
                    ["pwsh", "-NoProfile", "-File", str(_ROOT / "install.ps1"),
                     "-List", "-Profile", profile],
                    check=True, capture_output=True, text=True,
                )
                self.assertEqual(out.stdout.split(), expected("windows", profile))


if __name__ == "__main__":
    unittest.main()
