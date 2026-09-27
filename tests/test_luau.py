"""Runs the console scripts under the luau CLI and checks what they print, and
checks every file the game loads against Deadline's Fiu VM load limit."""
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from support import (LUAU_COMPILE, ROOT, dd, fixture_profile_lua, needs_luau, needs_luau_compile,
                     players_lua, run_script)

import build_attachment_names as names_builder  # noqa: E402
import check_fiu_compat  # noqa: E402

TABLE_ROW = re.compile(r"^#\d+\s+(.*?)\s*\| Kills: (\d+)\s*\| Top Gun: (.*) \((\d+)\)$")


def weapon_display_names():
    body = dd.luau_table_body(dd.WEAPON_DATA_LUAU, "WeaponData.DISPLAY_NAMES")
    return dict(re.findall(r'(\w+)\s*=\s*"([^"]*)"', body))


def expected_table_rows(rows, with_names=True):
    """What print_attachment_stats should print for fixture rows: {(name, kills, top gun, top gun kills)}."""
    merged = dd.replay_merge(rows, dict(dd.load_renames()), dd.load_weapon_aliases())
    _, _, all_names, _ = names_builder.load_all_names()
    shown = names_builder.attachment_display_names(all_names)
    groups = names_builder.load_groups(all_names) if with_names else {}
    display = weapon_display_names()

    products = {}
    for canon in merged:
        if canon in groups:
            products.setdefault(groups[canon], []).append(canon)
    entries = {canon: (shown.get(canon, canon), b["kills"], dict(b["guns"])) for canon, b in merged.items()}
    for product, members in products.items():
        if len(members) > 1:
            guns = {}
            for m in members:
                for g, k in entries[m][2].items():
                    guns[g] = max(guns.get(g, 0), k)
            kills = max(entries[m][1] for m in members)
            for m in members:
                del entries[m]
            entries["group:" + product] = (f"{product} ({len(members)} pieces)", kills, guns)
    out = set()
    for name, kills, guns in entries.values():
        gun, gun_kills = dd.top_gun(guns)
        out.add((name, kills, display.get(gun, gun), gun_kills))
    return out


def parse_table(output):
    return [(m.group(1), int(m.group(2)), m.group(3), int(m.group(4)))
            for m in map(TABLE_ROW.match, output.splitlines()) if m]


@needs_luau
class TestAttachmentPrinter(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = dd.load_fixture()
        cls.players = players_lua(fixture_profile_lua(cls.rows))
        cls.output = run_script("print_attachment_stats.luau", cls.players)
        cls.printed = parse_table(cls.output)

    def test_every_row_matches_the_python_replay(self):
        self.assertEqual(len(self.printed), len(set(self.printed)))
        self.assertEqual(set(self.printed), expected_table_rows(self.rows))

    def test_names_are_unique_and_from_game_data(self):
        names = [r[0] for r in self.printed]
        self.assertEqual(len(names), len(set(names)))
        self.assertIn("-- names: deadline-balancing", self.output)

    def test_groups_show_one_row_with_kills_counted_once(self):
        rows = {r[0]: r for r in self.printed}
        self.assertEqual(rows["AFT SC Stock (5 pieces)"][1], 6326)
        self.assertEqual(rows["AFT Stock (3 pieces)"][1], 732)
        self.assertNotIn("AFT (Connector)", rows)
        self.assertIn('Veles PT-1 "Klassika" Cheekpad', rows)  # takes a Tailhook adapter: not grouped

    def test_guns_use_the_stat_panel_names(self):
        rows = {r[0]: r for r in self.printed}
        self.assertEqual(rows["AFT Mk20 (Gas Block)"][2], "SCAR-H")
        self.assertEqual(rows["KALIS Scalar Standard (BCG)"][2], "Vector")  # old Vector kills fold into SCALAR
        guns = {r[2] for r in self.printed}
        self.assertNotIn("AFT MK-17", guns)  # balancing.csv's gun names are not used

    def test_named_player_and_shared_function(self):
        output = run_script("print_attachment_stats.luau", self.players,
                            after="shared.print_attachment_stats('Tester'); shared.print_attachment_stats('Nobody')")
        self.assertEqual(output.count("ATTACHMENTS BY KILLS"), 2)
        self.assertIn("Could not retrieve player profile stats.", output)

    def test_runs_without_the_names_module(self):
        output = run_script("print_attachment_stats.luau", self.players, missing_modules=("attachment_names",))
        self.assertIn("-- names: prettified ids", output)
        printed = parse_table(output)
        # Same numbers as without groups (groups come with the names module); names are prettified ids.
        self.assertEqual(sorted(r[1:] for r in printed),
                         sorted(r[1:] for r in expected_table_rows(self.rows, with_names=False)))
        self.assertIn("Aft Mk20 Gas Block", [r[0] for r in printed])


@needs_luau
class TestDelimitedPrinter(unittest.TestCase):
    def test_output_matches_the_python_replay(self):
        rows = dd.load_fixture()
        output = run_script("print_attachment_stats_delimited.luau", players_lua(fixture_profile_lua(rows)))
        printed = {a: (k, g, gk) for a, k, g, gk in dd.parse_fixture(output)}
        merged = dd.replay_merge(rows, dict(dd.load_renames()), dd.load_weapon_aliases())
        expected = {canon: (b["kills"],) + dd.top_gun(b["guns"]) for canon, b in merged.items()}
        self.assertEqual(printed, expected)
        self.assertIn("-- ALIASES MERGED:", output)
        self.assertNotIn("pieces", output)  # the fixture keeps every id; no groups


STAT_PROFILE = """{
  player = { total_kills = 3000, weapon_use_time = { Vector = 3600, SCALAR = 1800, M4A1 = 7200 } },
  weapon = {
    Vector = { kills = 700, deaths_with = 300, deaths_from = 20, experience = 1000, rounds_fired = 9000 },
    SCALAR = { kills = 250, deaths_with = 100, deaths_from = 5, experience = 400, rounds_fired = 3000 },
    SA58 = { kills = 400, deaths_with = 150, deaths_from = 10, experience = 800, rounds_fired = 5000 },
    SG58 = { kills = 43, deaths_with = 20, deaths_from = 1, experience = 90, rounds_fired = 600 },
    M4A1 = { kills = 1500, deaths_with = 500, deaths_from = 60, experience = 3000, rounds_fired = 20000 },
  },
}"""


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
        rows = stat_rows(run_script("print_player_stats.luau", self.players))
        self.assertEqual(rows["Vector"], [(950, "SMG")])  # Vector + SCALAR
        self.assertEqual(rows["SA58"], [(443, "308")])    # SA58 + SG58
        self.assertNotIn("SCALAR", rows)
        self.assertNotIn("SG58", rows)

    def test_lookup_by_old_or_new_id_and_filters(self):
        after = ("shared.print_player_stats('Tester', nil, 'scalar')\n"
                 "shared.print_player_stats('Tester', nil, 'SA58')\n"
                 "shared.print_player_stats('Tester', 'SMG')")
        rows = stat_rows(run_script("print_player_stats.luau", self.players, after=after))
        self.assertEqual(len(rows["Vector"]), 3)  # full report, target 'scalar', filter SMG
        self.assertEqual(len(rows["SA58"]), 2)    # full report, target 'SA58'
        self.assertEqual(len(rows["M4A1"]), 1)    # only the full report


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
                       "attachment_data.luau", "player_lookup.luau", "weapon_data.luau", "renderer.luau"]:
            self.assertIn(module, checked)

    def test_checker_flags_long_functions(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "bad.luau"
            bad.write_text("local s = [[\n" + "x\n" * 300 + "]]\nprint(s)\n", encoding="utf-8")
            self.assertTrue(check_fiu_compat.check_file(LUAU_COMPILE, bad))
            good = Path(tmp) / "good.luau"
            good.write_text('local s = "x"\nprint(s)\n', encoding="utf-8")
            self.assertEqual(check_fiu_compat.check_file(LUAU_COMPILE, good), [])


if __name__ == "__main__":
    unittest.main()
