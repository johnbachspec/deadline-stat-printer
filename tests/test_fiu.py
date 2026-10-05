"""Every file the game loads must stay within Deadline's Fiu VM load limit, and CI's Luau must
write bytecode the checker can read (see tools/check_fiu_compat.py)."""
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from support import LUAU_COMPILE, ROOT, needs_luau_compile

import check_fiu_compat  # noqa: E402
import build_client_autorun as client_autorun  # noqa: E402


@needs_luau_compile
class TestFiuLoadCompatibility(unittest.TestCase):
    """Deadline's Fiu VM fails to load functions spanning > 255 lines (see tools/check_fiu_compat.py)."""

    def test_game_loaded_files_are_fiu_safe(self):
        res = subprocess.run([sys.executable, str(ROOT / "tools" / "check_fiu_compat.py")],
                             cwd=str(ROOT), capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"check_fiu_compat.py failed:\n{res.stdout}\n{res.stderr}")

    def test_every_loaded_module_is_checked(self):
        checked = {p.name for p in check_fiu_compat.game_loaded_files()}
        for module in ["attachment_names.luau", "attachment_aggregator.luau", "attachment_renderer.luau",
                       "attachment_data.luau", "player_lookup.luau", "weapon_data.luau", "renderer.luau",
                       "iris_report.luau"]:
            self.assertIn(module, checked)

    def test_client_autorun_file_is_fiu_safe(self):
        # Pasted as one chunk, so it is checked on its own (it is not a .luau the scripts load).
        self.assertEqual(check_fiu_compat.check_file(LUAU_COMPILE, ROOT / "client_autorun.txt"), [])

    def test_checker_flags_long_functions(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "bad.luau"
            bad.write_text("local s = [[\n" + "x\n" * 300 + "]]\nprint(s)\n", encoding="utf-8")
            self.assertTrue(check_fiu_compat.check_file(LUAU_COMPILE, bad))
            good = Path(tmp) / "good.luau"
            good.write_text('local s = "x"\nprint(s)\n', encoding="utf-8")
            self.assertEqual(check_fiu_compat.check_file(LUAU_COMPILE, good), [])


class TestLuauPin(unittest.TestCase):
    """CI's Luau must write bytecode the Fiu checker can read (newer releases changed the format)."""

    def test_newer_bytecode_gets_a_clear_message(self):
        with self.assertRaises(ValueError) as caught:
            check_fiu_compat.read_protos(bytes([14, 3, 0]))
        self.assertIn("bytecode version 14", str(caught.exception))
        self.assertIn(check_fiu_compat.PINNED_LUAU, str(caught.exception))

    def test_ci_installs_the_luau_the_checker_expects(self):
        action = (ROOT / ".github" / "actions" / "setup-luau" / "action.yml").read_text(encoding="utf-8")
        pinned = re.search(r'default:\s*"([^"]+)"', action).group(1)
        self.assertEqual(pinned, check_fiu_compat.PINNED_LUAU,
                         "setup-luau installs a different Luau than check_fiu_compat.py names")


if __name__ == "__main__":
    unittest.main()
