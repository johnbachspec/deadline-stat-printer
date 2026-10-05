"""Static analysis of every Luau file with luau-analyze: undefined variables, typos in
names, values that may be nil where they can't be, unreachable code and the other
Luau lints. The console's own globals (players, shared, iris, ...) are declared in
.luaurc, so anything else unknown is a real mistake."""
import json
import re
import subprocess
import unittest

from support import ROOT
import luau_cli  # noqa: E402

ANALYZE = luau_cli.find_luau_tool("luau-analyze")


def luau_files():
    """Everything the game runs: the root scripts and the modules."""
    return sorted(ROOT.glob("*.luau")) + sorted((ROOT / "modules").glob("*.luau"))


@unittest.skipUnless(ANALYZE, "luau-analyze not found (set LUAU_BIN or add it to luau_bin/)")
class TestLuauAnalyze(unittest.TestCase):
    def test_no_warnings(self):
        files = [str(p.relative_to(ROOT)) for p in luau_files()]
        result = subprocess.run([ANALYZE, *files], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
        findings = (result.stdout + result.stderr).strip()
        self.assertEqual(findings, "", f"luau-analyze found problems:\n{findings}")
        self.assertEqual(result.returncode, 0)

    def test_luaurc_declares_only_console_globals_the_scripts_use(self):
        # A name declared but used nowhere is probably a typo or a leftover.
        declared = json.loads((ROOT / ".luaurc").read_text(encoding="utf-8"))["globals"]
        source = "\n".join(p.read_text(encoding="utf-8") for p in luau_files())
        unused = [name for name in declared if not re.search(rf"\b{name}\b", source)]
        self.assertEqual(unused, [])


if __name__ == "__main__":
    unittest.main()
