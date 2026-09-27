"""Runs the console scripts under the luau CLI and checks what they print, and
checks every file the game loads against Deadline's Fiu VM load limit."""
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from support import (LUAU_COMPILE, ROOT, dd, fixture_profile_lua, lua_string, needs_luau, needs_luau_compile,
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


@needs_luau
class TestConsoleExplorer(unittest.TestCase):
    def test_surveys_globals_players_profile_and_shared(self):
        output = run_script("explore_console.luau", players_lua(fixture_profile_lua(dd.load_fixture())))
        for section in ["===== GLOBALS", "===== PLAYERS", "===== PROFILE (Tester)", "===== SHARED", "===== END"]:
            self.assertIn(section, output)
        self.assertIn("players: 2 names", output)
        self.assertIn("get_profile_stats = function", output)
        # Big maps are summarized, not dumped: one line for 29 weapons, keys across entries, one entry's shape.
        self.assertIn("profile.weapon = table of 29, e.g. AK12", output)
        self.assertIn("profile.weapon entries have: attachment_stats x29", output)
        self.assertLess(len(output.splitlines()), 150)

    def test_live_section_calls_only_the_listed_getters(self):
        actions = ["ban_from_server", "deal_damage", "equip_weapon", "explode", "fire_client", "give_money",
                   "kick", "kill", "refill_ammo", "respawn", "set_health", "set_position", "set_speed",
                   "set_team", "set_weapon", "spawn"]
        action_fns = ", ".join(f'{a} = function() print("ACTION CALLED: {a}") end' for a in actions)
        setup = '{"attachments":' + '["ak12_gen1_lower_receiver"],' * 30 + '"x":1}'  # long, like a setup JSON
        players = (
            "(function() local p\n"
            "p = { name = 'Tester', id = 1, player_id = 2, " + action_fns + ",\n"
            "  is_bot = function() return false end,\n"
            "  get_profile_stats = function() return { player = { total_kills = 1 } } end,\n"
            "  is_alive = function() return true end, get_health = function() return 87 end,\n"
            "  get_team = function() return 'defender' end,\n"
            "  get_leaderboard_stats = function() return { kills = 3, hit_shots = 40, total_shots = 100 } end,\n"
            "  get_weapon_data_from_character = function(slot)\n"
            "    if slot ~= 'primary' then error('invalid weapon index') end\n"
            f"    return {{ ammo = 30, client_data = {{ name = 'AK12', setup = {lua_string(setup)}, laser_enabled = false }} }} end,\n"
            "  get_weapon_from_loadout = function(i, slot)\n"
            "    if i == 0 and slot == 'primary' then return { weapon = 'AK12', data = '[]' } end\n"
            "    return \"couldn't find setup\" end }\n"
            "return { get_all = function() return { p } end, get_alive = function() return { p } end,\n"
            "  reset_ragdolls = function() print('ACTION CALLED: reset_ragdolls') end } end)()")
        api_actions = {"map": ["set_map", "set_preset", "set_time", "run_vote"], "gamemode": ["set_gamemode", "force_set_gamemode"],
                       "chat": ["send_announcement", "send_ingame_notification"], "spawning": ["explosion", "bot"]}
        prelude = "\n".join(
            f"local {table} = {{ " + ", ".join(f'{a} = function() print("ACTION CALLED: {table}.{a}") end' for a in acts)
            + (", get_maps = function() return { 'shipment', 'district' } end" if table == "map" else "")
            + (", available_gamemodes = { 'koth', 'tdm' }" if table == "gamemode" else "") + " }"
            for table, acts in api_actions.items())
        prelude += ("\nlocal config = { weapon_names = { 'AK12', 'M4A1' } }"
                    "\nlocal sharedvars = { sv_spawning_enabled = true }")
        output = run_script("explore_console.luau", players, prelude=prelude)
        self.assertNotIn("ACTION CALLED", output)
        self.assertIn("kill = function", output)       # listed, not run
        self.assertIn("  set_map = function", output)  # API table functions listed, not run
        for line in ["is_alive() = boolean true", "get_health() = number 87", 'get_team() = string "defender"',
                     "get_leaderboard_stats().hit_shots = number 40",
                     'get_weapon_data_from_character("primary").client_data.name = string "AK12"',
                     'get_weapon_data_from_character("primary").client_data.setup = string "{\\"attachments\\"',
                     'get_weapon_data_from_character("secondary") failed',
                     'get_weapon_from_loadout(0, "primary").weapon = string "AK12"',
                     'get_weapon_from_loadout(1, "primary") = string "couldn\'t find setup"',
                     "#players.get_alive() = number 1",
                     'config.weapon_names.1 = string "AK12"', "sharedvars.sv_spawning_enabled = boolean true",
                     'map.get_maps().1 = string "shipment"', 'gamemode.available_gamemodes.2 = string "tdm"']:
            self.assertIn(line, output)
        # Weapon setups are shown up to 400 characters, other strings up to 40.
        setup_line = next(l for l in output.splitlines() if "client_data.setup" in l)
        self.assertIn(f"({len(setup)} chars)", setup_line)
        self.assertGreater(len(setup_line), 400)

    def test_records_are_listed_and_collections_summarized(self):
        # Shaped like a real profile: a 13-field player record must list every field,
        # while lists and per-item collections are summarized.
        owned = ", ".join(f'"GUN{i}"' for i in range(37))
        fields = ", ".join(f"field_{i} = {i}" for i in range(11))
        attachments = ", ".join(f'["att_{i}"] = {{ kills = {i}, experience = {i * 100} }}' for i in range(20))
        camo = ", ".join(f'["part_{i}"] = {{ Blue = true, ["Orange "] = true }}' for i in range(15))
        owned_atts = ", ".join(f'"att_{i}"' for i in range(30))
        profile = (f"{{ player = {{ {fields}, owned_weapons = {{ {owned} }}, weapon_use_time = {{ AK12 = 5 }} }},\n"
                   f"  weapon = {{ AK12 = {{ kills = 1, attachment_stats = {{ {attachments} }},\n"
                   f"    owned_attachments = {{ {owned_atts} }}, owned_camo = {{ {camo} }} }} }} }}")
        output = run_script("explore_console.luau", players_lua(profile))
        for i in range(11):
            self.assertIn(f"profile.player.field_{i} = number {i}", output)
        self.assertIn("profile.player.weapon_use_time.AK12 = number 5", output)
        self.assertIn("profile.player.owned_weapons = table of 37", output)
        self.assertNotIn("profile.player = table of", output)
        self.assertIn("profile.weapon.AK12.attachment_stats entries have: experience x20, kills x20", output)
        self.assertIn("profile.weapon.AK12.owned_attachments = table of 30", output)
        self.assertIn('profile.weapon.AK12.owned_camo entries have: Blue x15, Orange  x15', output)


CAP_PRELUDE = """
local __threads, __chat_handlers = {}, {}
local task = {
  spawn = function(f) local co = coroutine.create(f); table.insert(__threads, co); assert(coroutine.resume(co)); return co end,
  wait = function() coroutine.yield() end,
}
local function __tick()  -- runs one more check in every waiting loop
  for _, co in ipairs(__threads) do if coroutine.status(co) == "suspended" then assert(coroutine.resume(co)) end end
end
local function __say(content)
  for _, h in pairs(__chat_handlers) do if h then h("Bob", "all", content) end end
end
local chat = {
  send_announcement = function(t) print("ANNOUNCE: " .. t) end,
  send_ingame_notification = function(t) print("NOTIFY: " .. t) end,
  player_chatted = { Connect = function(self, fn)
    local i = #__chat_handlers + 1; __chat_handlers[i] = fn
    return { Disconnect = function() __chat_handlers[i] = false end } end },
}
local __caps = { Alice = 0, Bob = 0 }
local function __player(name, id)
  return { name = name, player_id = id, is_bot = function() return false end,
    get_leaderboard_stats = function() return { objective_captures = __caps[name], kills = 0 } end }
end
players = { get_all = function() return { __player("Alice", 1), __player("Bob", 2) } end }
"""


@needs_luau
class TestCapAnnouncer(unittest.TestCase):
    def test_announces_captures_and_answers_the_chat_command(self):
        after = """
print("-- step: Alice caps")
__caps.Alice = 1; __tick()
print("-- step: both cap")
__caps.Alice = 2; __caps.Bob = 1; __tick()
print("-- step: chat")
__say("  !CAPS "); __say("hello")
shared.caps()
print("-- step: new match")
__caps.Alice = 0; __caps.Bob = 0; __tick()
__caps.Bob = 1; __tick()
print("-- step: stopped")
shared.stop_cap_announcer(); __caps.Bob = 5; __tick(); __say("!caps")
"""
        output = run_script("cap_announcer.luau", "nil", prelude=CAP_PRELUDE, after=after)
        steps = dict(part.split("\n", 1) for part in output.split("-- step: ")[1:])
        self.assertNotIn("ANNOUNCE", output.split("-- step: ")[0])  # the first check only records counts
        self.assertIn("ANNOUNCE: Alice captured a point (1 this match)", steps["Alice caps"])
        self.assertIn("ANNOUNCE: Alice and Bob captured a point", steps["both cap"])
        self.assertEqual(steps["chat"].count("ANNOUNCE: Captures this match: Alice 2, Bob 1"), 1)
        self.assertIn("[caps] Captures this match: Alice 2, Bob 1", steps["chat"])  # shared.caps() in the console
        self.assertEqual(steps["new match"].count("ANNOUNCE"), 1)  # the reset to 0 is not a capture
        self.assertIn("ANNOUNCE: Bob captured a point (1 this match)", steps["new match"])
        self.assertNotIn("ANNOUNCE", steps["stopped"])

    def test_running_it_again_replaces_the_running_copy(self):
        script = (ROOT / "cap_announcer.luau").read_text(encoding="utf-8")
        after = f";(function()\n{script}\nend)()\n__caps.Alice = 1; __tick(); __say('!caps')"
        output = run_script("cap_announcer.luau", "nil", prelude=CAP_PRELUDE, after=after)
        self.assertEqual(output.count("ANNOUNCE: Alice captured a point (1 this match)"), 1)
        self.assertEqual(output.count("ANNOUNCE: Captures this match: Alice 1"), 1)


# A mock of the client's Iris and both consoles' networking. Iris records what a
# frame draws: widgets in __drawn, table cells in __grids[table id][row][column],
# placed the way the real Table widget places them (2.4+ or older, __NEW_TABLES__).
# fire_client on the human "Tester" delivers straight to the viewer; fire_server
# delivers to the server's on_client_event handlers as that player.
IRIS_MOCKS = r"""
local __new_tables = __NEW_TABLES__
local __widgets, __stack, __next_id, __frame_fn, __clicks = {}, {}, nil, nil, {}
local __drawn, __grids, __sent, __auto_ids = {}, {}, 0, {}
local function __state(v) return { value = v, set = function(self, x) self.value = x end } end
local function __esc(s) return (tostring(s):gsub("\t", "<TAB>"):gsub("\n", "<NL>")) end
local function __make(kind, container)
  return function(args)
    local id = __next_id or (kind .. "#" .. #__drawn); __next_id = nil
    if id == kind .. "#" .. #__drawn then table.insert(__auto_ids, id .. " " .. __esc(args and args[1])) end
    local w = __widgets[id]
    if not w then
      w = { kind = kind, state = { isOpened = __state(true), isUncollapsed = __state(kind == "Window"),
        text = __state(""), size = __state(nil), position = __state(nil) } }
      __widgets[id] = w
    end
    w.id = id
    w.clicked = function() return __clicks[id] == true end
    local text, parent = args and args[1], __stack[#__stack]
    if text == "boom" then error("boom") end
    if kind == "Text" and parent and parent.kind == "Table" then
      if not __new_tables then parent.row = math.ceil(parent.index / parent.n); parent.col = (parent.index - 1) % parent.n + 1 end
      __grids[parent.id] = __grids[parent.id] or {}
      local g = __grids[parent.id]; g[parent.row] = g[parent.row] or {}; g[parent.row][parent.col] = text
    else
      table.insert(__drawn, kind .. " " .. __esc(text))
    end
    if kind == "Table" then w.n, w.index, w.row, w.col = args[1], 0, 1, 1 end
    if container then table.insert(__stack, w) end
    return w
  end
end
local iris = {
  Window = __make("Window", true), CollapsingHeader = __make("CollapsingHeader", true),
  SameLine = __make("SameLine", true), Table = __make("Table", true),
  Text = __make("Text"), SmallButton = __make("SmallButton"), InputText = __make("InputText"),
  SetNextWidgetID = function(id) __next_id = id end,
  End = function() assert(#__stack > 0, "End without an open widget"); table.remove(__stack) end,
  NextColumn = function()
    local t = __stack[#__stack]; assert(t and t.kind == "Table", "NextColumn outside a table")
    if not __new_tables then t.index = t.index + 1
    elseif t.col == t.n then t.col = 1; t.row = t.row + 1 else t.col = t.col + 1 end
  end,
  Connect = function(self, fn) __frame_fn = fn end,
}
if __new_tables then
  iris.NextHeaderColumn = function() end
  iris.SetHeaderColumnIndex = function(i) local t = __stack[#__stack]; t.row = 0; t.col = i end
end
local function __frame()
  __drawn, __grids = {}, {}
  __frame_fn()
  assert(#__stack == 0, "a frame left " .. #__stack .. " widgets open")
  -- Under Fiu, Iris's automatic ids are draw order, so any widget without an explicit id can
  -- take over another one's state (or kind) when a report changes.
  assert(#__auto_ids == 0, "drawn without an explicit id: " .. table.concat(__auto_ids, "; "))
  __clicks = {}
end
local function __click(id) assert(__widgets[id], "no widget " .. id); __clicks[id] = true end
local function __dump()
  for _, line in ipairs(__drawn) do print("DRAWN\t" .. line) end
  local ids = {}
  for id in pairs(__grids) do table.insert(ids, id) end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local rows = {}
    for r in pairs(__grids[id]) do table.insert(rows, r) end
    table.sort(rows)
    for _, r in ipairs(rows) do
      local cells, last = {}, 0
      for c in pairs(__grids[id][r]) do last = math.max(last, c) end
      for c = 1, last do cells[c] = __esc(__grids[id][r][c] or "<nil>") end
      print("ROW\t" .. id .. "\t" .. table.concat(cells, "\t"))
    end
  end
end
local __client_handlers, __server_handlers = {}, {}
local on_server_event = { Connect = function(self, fn) table.insert(__client_handlers, fn) end }
local on_client_event = { Connect = function(self, fn) table.insert(__server_handlers, fn) end }
function __deliver(message) __sent = __sent + 1; for _, h in ipairs(__client_handlers) do h(message) end end
local __me = type(players) == "table" and players.get and players.get("Tester")
if __me then __me.fire_client = __deliver end
local function fire_server(message) for _, h in ipairs(__server_handlers) do h(__me, message) end end
"""


def viewer_prelude(new_tables=True, extra=""):
    """Mocks, then `extra`, then iris_viewer.luau started the way the client console runs it."""
    viewer = (ROOT / "iris_viewer.luau").read_text(encoding="utf-8")
    mocks = IRIS_MOCKS.replace("__NEW_TABLES__", "true" if new_tables else "false")
    return f"{mocks}\n{extra}\n;(function()\n{viewer}\nend)()\n"


def drawn(output):
    return [line.split("\t", 1)[1] for line in output.splitlines() if line.startswith("DRAWN\t")]


def grids(output):
    """{table id: [row cells]} from __dump(), rows in order, header bold tags removed."""
    tables = {}
    for line in output.splitlines():
        if line.startswith("ROW\t"):
            _, table_id, *cells = line.split("\t")
            tables.setdefault(table_id, []).append([re.sub(r"</?b>", "", c) for c in cells])
    return tables


def only_table(output, columns):
    found = [rows for rows in grids(output).values() if len(rows[0]) == columns]
    assert len(found) == 1, f"expected one {columns}-column table, found {len(found)}"
    return found[0]


@needs_luau
class TestIrisViewer(unittest.TestCase):
    def test_stat_panel_opens_in_the_viewer_with_both_table_apis(self):
        for new_tables in (True, False):
            with self.subTest(new_tables=new_tables):
                output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE),
                                    prelude=viewer_prelude(new_tables), after="__frame(); __dump()")
                self.assertIn("DETAILED WEAPON STATS", output)  # still printed to the console
                self.assertIn("Window Stats: Tester", drawn(output))
                weapons = only_table(output, 13)
                self.assertEqual(weapons[0][:3], ["weapon", "kills", "deaths w/"])
                vector = next(row for row in weapons if row[0] == "Vector")
                self.assertEqual((vector[1], vector[-1]), ("950", "SMG"))
                recap = only_table(output, 6)
                self.assertEqual(recap[1][:2], ["Kills:", "3,000"])

    def test_refresh_asks_the_server_for_a_new_copy(self):
        after = """__frame()
local before = __sent
__click("dsp:stats:Tester:refresh"); __frame()
__click("dsp:attachments:Tester:refresh"); __frame()
print("REFRESHED " .. (__sent - before))
__click("dsp:stats:Tester:refresh"); __frame()  -- within half a second: ignored
print("AGAIN " .. (__sent - before))"""
        output = run_script("print_player_stats.luau", players_lua(STAT_PROFILE), prelude=viewer_prelude(),
                            after=";(function()\n" + (ROOT / "print_attachment_stats.luau").read_text(encoding="utf-8")
                            + "\nend)()\n" + after)
        self.assertIn("REFRESHED 2", output)  # each report fits in one message
        self.assertIn("AGAIN 2", output)

    def test_long_reports_arrive_in_parts_and_page_and_filter(self):
        after = r"""
local R = require("x/modules/iris_report.luau")
local report = R.new("attachments:Big", "Big", nil)
report:section("All", true)
report:columns({ "Name", "Note" })
for i = 1, 120 do report:row({ "row " .. i, string.rep("é", 40) .. "\ttab\\slash\nline" }) end
local messages = report:messages()
for _, m in ipairs(messages) do assert(utf8.len(m), "a part split a UTF-8 character") end
print("PARTS " .. #messages)
for _, m in ipairs(messages) do __deliver(m) end
__frame(); print("-- page 1"); __dump()
__click("dsp:attachments:Big:2:2:next"); __frame(); __frame(); print("-- page 2"); __dump()
__widgets["dsp:attachments:Big:2:2:filter"].state.text.value = "ROW 5"; __frame(); print("-- filtered"); __dump()
__widgets["dsp:attachments:Big:2:2:filter"].state.text.value = ""
__click("dsp:attachments:Big:2:2:all"); __frame(); __frame(); print("-- all"); __dump()
"""
        output = run_script("iris_viewer.luau", "nil", prelude=IRIS_MOCKS.replace("__NEW_TABLES__", "true"), after=after)
        self.assertGreater(int(re.search(r"PARTS (\d+)", output).group(1)), 1)
        pages = dict(part.split("\n", 1) for part in output.split("-- ")[1:])
        page1 = only_table(pages["page 1"], 2)
        self.assertEqual([r[0] for r in page1], ["Name"] + [f"row {i}" for i in range(1, 51)])
        self.assertEqual(page1[1][1], "é" * 40 + "<TAB>tab\\slash<NL>line")
        self.assertIn("Text rows 51-100 of 120", drawn(pages["page 2"]))
        self.assertEqual([r[0] for r in only_table(pages["page 2"], 2)][1:], [f"row {i}" for i in range(51, 101)])
        filtered = [r[0] for r in only_table(pages["filtered"], 2)][1:]
        self.assertEqual(filtered, ["row 5"] + [f"row {i}" for i in range(50, 60)])
        self.assertEqual(len(only_table(pages["all"], 2)), 1 + 120)  # Show all: every row on one page
        self.assertIn("Text all 120 rows", drawn(pages["all"]))
        self.assertIn("SmallButton Pages", drawn(pages["all"]))
        self.assertNotIn("SmallButton Next >", drawn(pages["all"]))

    def test_only_for_limits_the_viewer_to_named_players(self):
        viewer = (ROOT / "iris_viewer.luau").read_text(encoding="utf-8")
        self.assertIn("local ONLY_FOR = {}", viewer)
        mocks = IRIS_MOCKS.replace("__NEW_TABLES__", "true") + '\nlocal local_player = "Tester"\n'
        for names, runs in (('{ "Someone" }', False), ('{ "Someone", "Tester" }', True)):
            with self.subTest(names=names):
                source = viewer.replace("local ONLY_FOR = {}", f"local ONLY_FOR = {names}")
                with tempfile.TemporaryDirectory() as tmp:
                    script = Path(tmp) / "viewer.luau"
                    script.write_text(source, encoding="utf-8")
                    output = run_script(script, "nil", prelude=mocks)
                self.assertEqual("[viewer] ready" in output, runs)

    def test_a_failing_window_is_closed_and_reported_once(self):
        after = r"""
local R = require("x/modules/iris_report.luau")
local bad = R.new("bad", "Bad", nil); bad:section("S", true); bad:columns({ "A" }); bad:row({ "boom" })
for _, m in ipairs(bad:messages()) do __deliver(m) end
local good = R.new("good", "Good", nil); good:text("fine")
for _, m in ipairs(good:messages()) do __deliver(m) end
__frame(); __frame(); __dump()"""
        output = run_script("iris_viewer.luau", "nil", prelude=IRIS_MOCKS.replace("__NEW_TABLES__", "true"), after=after)
        self.assertEqual(output.count("[viewer] "), 2)  # the ready line and one error
        self.assertIn("Text fine", drawn(output))       # later windows still draw
        self.assertTrue(any(line.startswith("Text Error: ") for line in drawn(output)))

    def test_captures_window_follows_the_announcer(self):
        cap_players = CAP_PRELUDE.replace("is_bot = function() return false end,",
                                          "is_bot = function() return false end, fire_client = __deliver,")
        after = """
__caps.Alice = 1; __tick(); __frame(); print("-- captured"); __dump()
__widgets["dsp:caps"].state.isOpened.value = false
__caps.Bob = 1; __tick(); __frame(); print("-- closed " .. tostring(__widgets["dsp:caps"].state.isOpened.value))"""
        output = run_script("cap_announcer.luau", "nil", prelude=viewer_prelude(extra=cap_players), after=after)
        captured = output.split("-- captured")[1].split("-- closed")[0]
        self.assertEqual(only_table(captured, 2), [["Player", "Captures"], ["Alice", "1"]])
        self.assertTrue(any(line.endswith("Alice captured a point (1 this match)") for line in drawn(captured)))
        self.assertIn("-- closed false", output)  # live updates do not reopen a closed window


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
