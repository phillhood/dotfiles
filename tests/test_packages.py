import pathlib
import shutil
import subprocess
import unittest

_ROOT = pathlib.Path(__file__).resolve().parents[1]
_OSES = {"linux", "wsl", "darwin", "windows"}
_NOT_PACKAGES = {"assets", "docs", "tests", "tools"}


def manifest():
    rows = []
    for line in (_ROOT / "packages.conf").read_text().splitlines():
        fields = line.split()
        if fields and not fields[0].startswith("#"):
            rows.append((fields[0], fields[1:]))
    return rows


def expected(os):
    return [pkg for pkg, oses in manifest() if os in oses]


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

    def test_os_tags_valid(self):
        for pkg, oses in manifest():
            with self.subTest(pkg=pkg):
                self.assertTrue(oses, "no OS listed")
                self.assertLessEqual(set(oses), _OSES)

    def test_make_selects_manifest(self):
        for os in sorted(_OSES):
            with self.subTest(os=os):
                out = subprocess.run(
                    ["make", "-s", "packages", f"OS={os}"],
                    cwd=_ROOT, check=True, capture_output=True, text=True,
                )
                self.assertEqual(out.stderr, "")
                self.assertEqual(out.stdout.split(), expected(os))

    @unittest.skipUnless(shutil.which("pwsh"), "pwsh not installed")
    def test_install_ps1_selects_manifest(self):
        out = subprocess.run(
            ["pwsh", "-NoProfile", "-File", str(_ROOT / "install.ps1"), "-List"],
            check=True, capture_output=True, text=True,
        )
        self.assertEqual(out.stdout.split(), expected("windows"))


if __name__ == "__main__":
    unittest.main()
