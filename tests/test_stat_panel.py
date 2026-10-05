"""print_player_stats.luau under the luau CLI: the recap and the weapon table."""
import re
import unittest

from profiles import STAT_PROFILE
from support import CONSOLE_TABLES, needs_luau, players_lua, run_script


def stat_rows(output):
    """{display name: [kills, ..., type]} for each weapon table row."""
    rows = {}
    for line in output.splitlines():
        m = re.match(r"^(\S.{0,19}?)\s+([\d,]+)\s+[\d,]+\s", line)
        if m:
            rows.setdefault(m.group(1), []).append((int(m.group(2).replace(",", "")), line.split()[-1]))
    return rows


@needs_luau
class TestStatPanel(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.players = players_lua(STAT_PROFILE)

    def test_renamed_guns_merge_under_their_old_names(self):
        rows = stat_rows(run_script("print_player_stats.luau", self.players, settings=CONSOLE_TABLES))
        self.assertEqual(rows["Vector"], [(950, "SMG")])  # Vector + SCALAR
        self.assertEqual(rows["SA58"], [(443, "308")])    # SA58 + SG58
        self.assertNotIn("SCALAR", rows)
        self.assertNotIn("SG58", rows)

    def test_lookup_by_old_or_new_id_and_filters(self):
        after = ("shared.print_player_stats('Tester', nil, 'scalar')\n"
                 "shared.print_player_stats('Tester', nil, 'SA58')\n"
                 "shared.print_player_stats('Tester', 'SMG')")
        rows = stat_rows(run_script("print_player_stats.luau", self.players, settings=CONSOLE_TABLES, after=after))
        self.assertEqual(len(rows["Vector"]), 3)  # full report, target 'scalar', filter SMG
        self.assertEqual(len(rows["SA58"]), 2)    # full report, target 'SA58'
        self.assertEqual(len(rows["M4A1"]), 1)    # only the full report


@needs_luau
class TestFormatters(unittest.TestCase):
    def test_padding_counts_characters_not_bytes(self):
        # "3”" is 2 characters but 4 bytes; padding by bytes would leave the column short.
        after = """local F = require("x/modules/formatters.luau")
print("[" .. F.pad_right("3\\u{201D}", 5) .. "]", F.text_width("3\\u{201D}"), "[" .. F.center_text("\\u{201D}", 5) .. "]")"""
        output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE), after=after)
        self.assertIn("[3”   ]\t2\t[  ”]", output)


if __name__ == "__main__":
    unittest.main()
