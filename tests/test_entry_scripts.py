"""The entry scripts can't share code (each has to load its modules before anything is
downloaded), so they carry copies of REPO_BASE and load_module. These must stay identical."""
import re
import unittest

from support import ROOT

LOADER = re.compile(r"^local function load_module\(module_name\)\n.*?^end\n", re.M | re.S)
REPO_BASE = re.compile(r'^local REPO_BASE = "([^"]+)"', re.M)


def entry_scripts():
    """Root scripts that download modules (not the client-side viewer and theme)."""
    return [p for p in sorted(ROOT.glob("*.luau")) if "load_module(" in p.read_text(encoding="utf-8")]


class TestEntryScripts(unittest.TestCase):
    def test_every_script_has_the_same_loader(self):
        scripts = entry_scripts()
        self.assertGreaterEqual(len(scripts), 3)
        loaders = {p.name: LOADER.search(p.read_text(encoding="utf-8")) for p in scripts}
        missing = [name for name, m in loaders.items() if not m]
        self.assertEqual(missing, [], "scripts without a top-level load_module")
        self.assertEqual(len({m.group(0) for m in loaders.values()}), 1,
                         "load_module differs between " + ", ".join(loaders))

    def test_every_script_downloads_from_the_same_repo(self):
        bases = {p.name: REPO_BASE.search(p.read_text(encoding="utf-8")).group(1) for p in entry_scripts()}
        self.assertEqual(len(set(bases.values())), 1, f"REPO_BASE differs: {bases}")
        base = next(iter(bases.values()))
        self.assertRegex(base, r"^https://raw\.githubusercontent\.com/[^/]+/deadline-stat-printer/main/modules/$")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn(base.removesuffix("modules/"), readme)  # the require(...) lines players copy


if __name__ == "__main__":
    unittest.main()
