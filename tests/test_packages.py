import itertools
import pathlib
import shutil
import subprocess
import unittest

_ROOT = pathlib.Path(__file__).resolve().parents[1]
_OSES = {"linux", "wsl", "darwin", "windows"}
_PROFILES = {"personal", "work"}
_NOT_PACKAGES = {"assets", "docs", "tests", "tools"}
_STOW_IGNORE = {".stow-local-ignore", ".gitignore", "README.md", "LICENSE", "COPYING"}


def manifest():
    rows = []
    for line in (_ROOT / "packages.conf").read_text().splitlines():
        fields = line.split()
        if fields and not fields[0].startswith("#"):
            rows.append((fields[0], set(fields[1:])))
    return rows


def expected(os, profile):
    return [
        pkg
        for pkg, tags in manifest()
        if os in tags and (not tags & _PROFILES or profile in tags)
    ]


class ManifestTest(unittest.TestCase):
    def test_every_package_dir_listed_once(self):
        names = [pkg for pkg, _ in manifest()]
        dirs = sorted(
            p.name
            for p in _ROOT.iterdir()
            if p.is_dir() and not p.name.startswith(".") and p.name not in _NOT_PACKAGES
        )
        self.assertEqual(len(names), len(set(names)), "duplicate entries")
        self.assertEqual(sorted(names), dirs)

    def test_tags_valid(self):
        for pkg, tags in manifest():
            with self.subTest(pkg=pkg):
                self.assertTrue(tags & _OSES, "no OS listed")
                self.assertLessEqual(tags, _OSES | _PROFILES)

    def test_selected_packages_never_share_a_file(self):
        for os, profile in itertools.product(sorted(_OSES), sorted(_PROFILES)):
            with self.subTest(os=os, profile=profile):
                owners = {}
                for pkg in expected(os, profile):
                    root = _ROOT / pkg
                    for f in root.rglob("*"):
                        if f.is_file() and f.name not in _STOW_IGNORE:
                            rel = f.relative_to(root)
                            self.assertNotIn(rel, owners, f"{pkg} and {owners.get(rel)}")
                            owners[rel] = pkg

    def test_make_selects_manifest(self):
        for os, profile in itertools.product(sorted(_OSES), sorted(_PROFILES)):
            with self.subTest(os=os, profile=profile):
                out = subprocess.run(
                    ["make", "-s", "packages", f"OS={os}", f"PROFILE={profile}"],
                    cwd=_ROOT, check=True, capture_output=True, text=True,
                )
                self.assertEqual(out.stderr, "")
                self.assertEqual(out.stdout.split(), expected(os, profile))

    def test_make_rejects_unknown_profile(self):
        out = subprocess.run(
            ["make", "-s", "packages", "PROFILE=nope"],
            cwd=_ROOT, capture_output=True, text=True,
        )
        self.assertNotEqual(out.returncode, 0)

    @unittest.skipUnless(shutil.which("pwsh"), "pwsh not installed")
    def test_install_ps1_selects_manifest(self):
        for profile in sorted(_PROFILES):
            with self.subTest(profile=profile):
                out = subprocess.run(
                    ["pwsh", "-NoProfile", "-File", str(_ROOT / "install.ps1"),
                     "-List", "-Profile", profile],
                    check=True, capture_output=True, text=True,
                )
                self.assertEqual(out.stdout.split(), expected("windows", profile))


if __name__ == "__main__":
    unittest.main()
