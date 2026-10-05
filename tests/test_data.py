"""Checks the data files and the Luau generated from them."""
import re
import unittest

from support import dd
import fixture_replay as fx  # noqa: E402
import luau_source as luau  # noqa: E402

import build_attachment_aliases as aliases_builder  # noqa: E402
import build_attachment_names as names_builder  # noqa: E402
import check_fiu_compat  # noqa: E402


class TestRenames(unittest.TestCase):
    def setUp(self):
        self.aliases = dict(dd.load_renames())

    def test_full_list_kept(self):
        # 214 upstream rows + hand-added historical renames; syncs may only add rows.
        self.assertGreaterEqual(len(self.aliases), 309)

    def test_no_cycles(self):
        for start in self.aliases:
            chain, current = [], start
            while current in self.aliases:
                self.assertNotIn(current, chain, f"cycle: {' -> '.join(chain + [current])}")
                chain.append(current)
                current = self.aliases[current]

    def test_known_renames(self):
        a = self.aliases
        self.assertEqual(a["vector_9mm_bolt"], "kalis_scalar_std_bcg")
        self.assertEqual(a["vector_45acp_bolt"], "kalis_scalar_std_bcg")
        self.assertEqual(a["schmidt_super_scar_trigger"], "vallais_super_fang_trigger")
        self.assertEqual(a["fn_scar_h_bolt_carrier"], "aft_mk_17_bolt_carrier")  # SCAR-H parts -> MK-17
        self.assertEqual(a["fn_scar_l_bolt_carrier"], "aft_mk_16_bolt_carrier")  # SCAR-L parts -> MK-16
        self.assertNotIn("dd_enhanced_mvg", a)  # the current id; it used to be renamed away by mistake

    def test_targets_are_current_ids(self):
        _, _, names = names_builder.load_names()
        # Hand-added targets the balancing sheet has no row for (the game has them, the sheet does not).
        unlisted = {"kosch_default_mag_release", "paramount_arms_slx_1.53inch_straight_spacer_alt",
                    "paramount_arms_slx_1x_microprism_acss_g2_scope_alt", "whitner_defense_um3_mount"}
        missing = {n for n in self.aliases.values() if n not in names} - unlisted
        self.assertEqual(missing, set())

    def test_alias_table_in_sync(self):
        self.assertEqual(aliases_builder.main(["", "--check"]), 0)


class TestNames(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        _, _, cls.names, _ = names_builder.load_all_names()
        cls.shown = names_builder.attachment_display_names(cls.names)

    def test_module_in_sync(self):
        self.assertEqual(names_builder.main(["", "--check"]), 0)

    def test_every_fixture_attachment_has_an_in_game_name(self):
        # A missing id prints as a prettified id ("Fn SCAR Mk20 Gas Block"): add a rename to
        # data/renames.csv if the part still exists under a new id, else a row to extra_display_names.csv.
        aliases = dict(dd.load_renames())
        unnamed = sorted({dd.resolve(r[0], aliases) for r in fx.load_fixture()} - set(self.shown))
        self.assertEqual(unnamed, [])

    def test_extra_names_never_override_balancing(self):
        _, _, balancing = names_builder.load_names()
        for name, pretty in balancing.items():
            self.assertEqual(self.names[name], pretty)

    def test_attachment_names_are_unique(self):
        self.assertEqual(len(self.shown), len(set(self.shown.values())))

    def test_shared_names_get_part_labels(self):
        s = self.shown
        self.assertEqual(s["aft_stock_cheek_piece"], "AFT (Cheek Piece)")
        self.assertEqual(s["aft_stock_connector"], "AFT (Connector)")
        self.assertEqual(s["kazarov_ak74_fire_selector"], "Kazarov AK-74 (Fire Selector)")  # model not repeated
        self.assertEqual(s["kf_416_a5_barrel_nut"], "KF416A5 (Barrel Nut)")
        self.assertEqual(s["hart_m4a1_castlenut"], "Hart M4A1 Castle Nut (Standard)")  # base part of its variants
        self.assertEqual(s["ak308_7.62x51_muzzle_brake"], "Kazarov Group AK-308 (7.62x51 Muzzle Brake)")  # vs the gun
        self.assertEqual(s["dd_enhanced_mvg"], "AD Enhanced MVG")  # unique names untouched

    def test_module_has_attachments_only(self):
        module = dd.ATTACHMENT_NAMES_LUAU.read_text(encoding="utf-8")
        self.assertIn('["kalis_scalar_std_bcg"] = "KALIS Scalar Standard (BCG)",', module)
        self.assertIn('["sig_sauer_bravo4_4x30"] = "Sic St\\195\\188rmer GAIUS4 4X30",', module)
        self.assertNotIn('["SCARH"]', module)  # guns are named by weapon_data, like the stat panel
        self.assertTrue(module.isascii())

    def test_groups(self):
        groups = names_builder.load_groups(self.names)  # raises on unknown, renamed or duplicate ids
        self.assertEqual({k for k, v in groups.items() if v == "AFT SC Stock"},
                         {"aft_sc_stock_adapter", "aft_sc_stock_adjustment_lever", "aft_sc_stock_adjustment_rail",
                          "aft_sc_stock_buttpad", "aft_sc_stock_cheekpad"})
        self.assertEqual(groups["insight_technology_an_paq_4a_ir_laser"],
                         groups["insight_technology_an_paq_4a_carry_handle_mount"])
        # Products with swappable add-ons stay separate: the PT-1 takes a Tailhook adapter,
        # the Obsidian9 swaps pistons.
        self.assertFalse(any(k.startswith("veles_pt_1") for k in groups))
        self.assertNotIn("resiliant_suppressors_obsidian_9_3lug_piston", groups)


class TestWeapons(unittest.TestCase):
    def setUp(self):
        self.aliases = dd.load_weapon_aliases()
        self.types = dict(re.findall(r'(\w+)\s*=\s*"([^"]*)"', luau.luau_table_body(dd.WEAPON_DATA_LUAU, "WeaponData.TYPES")))
        self.display = dict(re.findall(r'(\w+)\s*=\s*"([^"]*)"',
                                       luau.luau_table_body(dd.WEAPON_DATA_LUAU, "WeaponData.DISPLAY_NAMES")))

    def test_legacy_ids_are_not_typed(self):
        # A legacy id listed in TYPES would win the name lookup over its alias and match no row.
        self.assertEqual(set(self.aliases) & set(self.types), set())

    def test_renamed_guns_keep_their_old_names(self):
        self.assertEqual((self.aliases["Vector"], self.types["SCALAR"], self.display["SCALAR"]), ("SCALAR", "SMG", "Vector"))
        self.assertEqual((self.aliases["SA58"], self.types["SG58"], self.display["SG58"]), ("SG58", "308", "SA58"))

    def test_every_gun_in_balancing_has_a_type(self):
        # An untyped gun is "Unknown" and hidden from the stat panel by default (as SCALAR and SG58 were).
        not_guns = {"ExplosiveRadio", "TestFlash", "TestSmoke"}
        _, _, names = names_builder.load_names()
        guns = {k for k in names if names_builder.is_weapon(k)}
        self.assertEqual(sorted(guns - set(self.types) - set(self.aliases) - not_guns), [])


class TestExpectedMerges(unittest.TestCase):
    def test_replay_conserves_kills_and_matches_expected_merges(self):
        rows = fx.load_fixture()
        merged = fx.replay_merge(rows, dict(dd.load_renames()), dd.load_weapon_aliases())
        self.assertEqual(sum(r[1] for r in rows), sum(b["kills"] for b in merged.values()))
        self.assertEqual(fx.merges_from_replay(merged), fx.load_expected_merges(),
                         "review with tools/verify_attachment_merge.py, then run it with --write-expected")

    def test_hand_checked_anchors(self):
        # Fixed values, so a regenerated expected_merges.csv cannot silently drift.
        expected = fx.load_expected_merges()
        self.assertEqual(len(fx.load_fixture()), 1103)
        self.assertEqual(sum(r[1] for r in fx.load_fixture()), 1717503)
        self.assertEqual(expected["kalis_scalar_std_bcg"], (705, "SCALAR", 705, {"vector_9mm_bolt", "vector_45acp_bolt"}))
        self.assertEqual(expected["vallais_super_fang_trigger"],
                         (13952, "SCARH", 13169, {"schmidt_super_scar_trigger", "vallais_super_fang_trigger"}))
        self.assertEqual(expected["aft_mk_17_bolt_carrier"],
                         (8082 + 31861, "SCARH", 8082 + 31861, {"aft_mk_17_bolt_carrier", "fn_scar_h_bolt_carrier"}))


class TestLuauSourceRules(unittest.TestCase):
    def test_game_loaded_files(self):
        # Kept from earlier console fixes: no Luau type casts, and no tabs in pasted code.
        for path in check_fiu_compat.game_loaded_files():
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("::", text, path.name)
            self.assertNotIn("\t", text, path.name)


if __name__ == "__main__":
    unittest.main()
