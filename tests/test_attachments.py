"""print_attachment_stats.luau under the luau CLI: names, merges, groups, views and the fixture view."""
import re
import unittest

from iris_support import drawn, grids, viewer_prelude
from profiles import ATTACHMENT_PROFILE
from support import CONSOLE_TABLES, dd, fixture_profile_lua, needs_luau, players_lua, run_script
import fixture_replay as fx  # noqa: E402
import luau_source as luau  # noqa: E402

import build_attachment_names as names_builder  # noqa: E402


TABLE_ROW = re.compile(r"^#\d+\s+(.*?)\s*\| Kills: (\d+)\s*\| Top Gun: (.*?) \((\d+)\)(?: \| Also: .*)?$")


def weapon_display_names():
    body = luau.luau_table_body(dd.WEAPON_DATA_LUAU, "WeaponData.DISPLAY_NAMES")
    return dict(re.findall(r'(\w+)\s*=\s*"([^"]*)"', body))


def expected_table_rows(rows, with_names=True):
    """What print_attachment_stats should print for fixture rows: {(name, kills, top gun, top gun kills)}."""
    merged = fx.replay_merge(rows, dict(dd.load_renames()), dd.load_weapon_aliases())
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
        gun, gun_kills = fx.top_gun(guns)
        out.add((name, kills, display.get(gun, gun), gun_kills))
    return out


def parse_table(output):
    return [(m.group(1), int(m.group(2)), m.group(3), int(m.group(4)))
            for m in map(TABLE_ROW.match, output.splitlines()) if m]


ALL_ROWS = "print('-- ALL ROWS --'); shared.print_attachment_stats(nil, { rows = 0 })"


def all_rows(output):
    """The part of the output printed by ALL_ROWS (every row, not just the first CONSOLE_ROWS)."""
    return output.split("-- ALL ROWS --", 1)[1]


@needs_luau
class TestAttachmentPrinter(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = fx.load_fixture()
        cls.players = players_lua(fixture_profile_lua(cls.rows))
        cls.first_run = run_script("print_attachment_stats.luau", cls.players, settings=CONSOLE_TABLES, after=ALL_ROWS)
        cls.output = all_rows(cls.first_run)
        cls.printed = parse_table(cls.output)

    def test_console_prints_the_first_rows_only(self):
        first = self.first_run.split("-- ALL ROWS --", 1)[0]
        self.assertEqual(len(parse_table(first)), 50)  # CONSOLE_ROWS
        hidden = len(self.printed) - 50
        self.assertIn(f"... {hidden} more not printed here: the Iris window has every row", first)
        self.assertNotIn("more not printed here", self.output)
        self.assertEqual(parse_table(first), self.printed[:50])  # the same top rows

    def test_every_row_matches_the_python_replay(self):
        self.assertEqual(len(self.printed), len(set(self.printed)))
        self.assertEqual(set(self.printed), expected_table_rows(self.rows))

    def test_names_are_unique_and_from_game_data(self):
        names = [r[0] for r in self.printed]
        self.assertEqual(len(names), len(set(names)))
        self.assertIn("-- Names: deadline-balancing", self.output)

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
        output = run_script("print_attachment_stats.luau", self.players, settings=CONSOLE_TABLES,
                            after="shared.print_attachment_stats('Tester'); shared.print_attachment_stats('Nobody')")
        self.assertEqual(output.count("ATTACHMENTS BY KILLS"), 2)
        self.assertIn('Player "Nobody" not found, or has no profile stats.', output)

    def test_runs_without_the_names_module(self):
        output = all_rows(run_script("print_attachment_stats.luau", self.players, settings=CONSOLE_TABLES, after=ALL_ROWS,
                                     missing_modules=("attachment_names",)))
        self.assertIn("-- Names: prettified ids", output)
        printed = parse_table(output)
        # Same numbers as without groups (groups come with the names module); names are prettified ids.
        self.assertEqual(sorted(r[1:] for r in printed),
                         sorted(r[1:] for r in expected_table_rows(self.rows, with_names=False)))
        self.assertIn("Aft Mk20 Gas Block", [r[0] for r in printed])


@needs_luau
class TestAttachmentViews(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.players = players_lua(ATTACHMENT_PROFILE)

    def test_rows_list_the_next_guns(self):
        output = run_script("print_attachment_stats.luau", self.players, settings=CONSOLE_TABLES)
        self.assertIn("10mm Thread Protector | Kills: 20     | Top Gun: AKM (10) | Also: M4A1 (7), Vector (2), +1 more",
                      output)
        self.assertIn("CQR 15mm              | Kills: 7      | Top Gun: AKM (7)", output)  # AKMN folds into AKM
        self.assertEqual([r[1] for r in parse_table(output)], [20, 7])

    def test_one_gun_only(self):
        output = run_script("print_attachment_stats.luau", self.players, settings=CONSOLE_TABLES,
                            after="shared.print_attachment_stats('Tester', { gun = 'akmn' })")
        part = output.split("ATTACHMENTS BY KILLS ON AKM")[1]
        self.assertIn("#1   10mm Thread Protector | Kills: 10", part)
        self.assertIn("#2   CQR 15mm              | Kills: 7", part)
        self.assertNotIn("Top Gun", part)

    def test_search_and_unknown_gun(self):
        output = run_script("print_attachment_stats.luau", self.players, settings=CONSOLE_TABLES,
                            after="shared.print_attachment_stats('Tester', { search = 'CQR' })\n"
                                  "shared.print_attachment_stats('Tester', { gun = 'Nope' })")
        part = output.split('1 ATTACHMENTS BY KILLS MATCHING "CQR"')[1].split("[iris]")[0]
        self.assertEqual([r[0] for r in parse_table(part)], ["CQR 15mm"])
        self.assertIn('No attachment kills on Nope. "Nope" is not a gun this script knows', output)

    def test_grouped_by_gun(self):
        output = run_script("print_attachment_stats.luau", self.players, settings=CONSOLE_TABLES,
                            after="shared.print_attachment_stats('Tester', { view = 'guns' })\n"
                                  "shared.print_attachment_stats('Tester', { view = 'nope' })")
        part = output.split("ATTACHMENT KILLS BY GUN: 4 GUNS")[1]
        guns = re.findall(r"^---- (.*): (\d+) attachments? ----$", part, re.M)
        self.assertEqual(guns, [("AKM", "2"), ("M4A1", "1"), ("Vector", "1"), ("MP5", "1")])
        self.assertIn("#2   CQR 15mm              | Kills: 7      | All guns: 7", part)
        self.assertIn('Unknown view "nope"', output)

    def test_iris_windows_for_each_view_and_refresh(self):
        after = """
shared.print_attachment_stats("Tester", { view = "guns", gun = "M4A1" })
__frame(); __dump()
local before = __sent
__click("dsp:attachments:Tester:by gun M4A1:refresh"); __frame()
print("REFRESHED " .. (__sent - before))"""
        output = run_script("print_attachment_stats.luau", self.players, prelude=viewer_prelude(), after=after)
        frame = drawn(output)
        self.assertIn("Window Attachments: Tester", frame)
        self.assertIn("Window Attachments: Tester (by gun M4A1)", frame)
        tables = grids(output)
        main = next(rows for rows in tables.values() if rows[0][:3] == ["#", "Attachment", "Kills"] and len(rows[0]) == 7)
        self.assertEqual(main[1], ["1", "10mm Thread Protector", "20", "AKM", "10", "M4A1 (7), Vector (2), +1 more", "4"])
        self.assertEqual(main[2][5], "-")  # an empty cell shows "-", so its column stays in line
        by_gun = next(rows for rows in tables.values() if rows[0] == ["#", "Attachment", "Kills"])
        self.assertEqual(by_gun[1:], [["1", "10mm Thread Protector", "7"]])  # one gun: no "All guns" total
        self.assertIn("REFRESHED 1", output)


@needs_luau
class TestFixtureView(unittest.TestCase):
    def test_output_matches_the_python_replay(self):
        rows = fx.load_fixture()
        output = run_script("print_attachment_stats.luau", players_lua(fixture_profile_lua(rows)),
                            after="print('-- FIXTURE --'); shared.print_attachment_stats(nil, { view = 'fixture' })")
        output = output.split("-- FIXTURE --", 1)[1]
        printed = {a: (k, g, gk) for a, k, g, gk in fx.parse_fixture(output)}
        merged = fx.replay_merge(rows, dict(dd.load_renames()), dd.load_weapon_aliases())
        expected = {canon: (b["kills"],) + fx.top_gun(b["guns"]) for canon, b in merged.items()}
        self.assertEqual(printed, expected)
        self.assertIn("-- ALIASES MERGED:", output)
        self.assertNotIn("pieces", output)  # the fixture keeps every id; no groups
        self.assertNotIn("[iris]", output)  # console only


@needs_luau
class TestDefaultOutput(unittest.TestCase):
    def test_console_gets_one_status_line_and_iris_the_table(self):
        output = run_script("print_attachment_stats.luau", players_lua(ATTACHMENT_PROFILE),
                            prelude=viewer_prelude(), after="__frame(); __dump()")
        console = [line for line in output.splitlines() if not line.startswith(("DRAWN\t", "ROW\t", "[viewer]"))]
        self.assertEqual(console, ["[iris] sent Tester's attachments to 1 of 1 players"])
        self.assertIn("Window Attachments: Tester", drawn(output))
