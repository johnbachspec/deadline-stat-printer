"""explore_console.luau under the luau CLI: what it surveys, and that it only calls read-only getters."""
import unittest

from support import dd, fixture_profile_lua, lua_string, needs_luau, players_lua, run_script
import fixture_replay as fx  # noqa: E402


@needs_luau
class TestConsoleExplorer(unittest.TestCase):
    def test_surveys_globals_players_profile_and_shared(self):
        output = run_script("explore_console.luau", players_lua(fixture_profile_lua(fx.load_fixture())))
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


if __name__ == "__main__":
    unittest.main()
