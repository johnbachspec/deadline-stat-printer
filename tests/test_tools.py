"""Unit tests for the helpers in tools/."""
import tempfile
import unittest
from pathlib import Path

from support import dd
import fixture_replay as fx  # noqa: E402
import luau_source as luau  # noqa: E402

import build_attachment_aliases as aliases_builder  # noqa: E402
import build_attachment_names as names_builder  # noqa: E402


class TestRenameHelpers(unittest.TestCase):
    def test_upstream_merge_keeps_local_only_rows(self):
        local = [("a_old", "a_new"), ("hand_added", "kept"), ("retarget", "stale")]
        upstream = [("a_old", "a_new"), ("retarget", "fresh"), ("brand_new", "x")]
        merged, added, changed = aliases_builder.merge_pairs(local, upstream)
        self.assertEqual(dict(merged), {"a_old": "a_new", "hand_added": "kept", "retarget": "fresh", "brand_new": "x"})
        self.assertEqual((added, changed), (["brand_new"], ["retarget"]))

    def test_parse_renames_rejects_bad_files(self):
        for text in ["old,new\na,b\n", "old_name,new_name\na,b\na,c\n", "old_name,new_name\na\n", 'old_name,new_name\na",b\n']:
            with self.assertRaises(dd.DataError):
                dd.parse_renames(text)

    def test_resolve_follows_chains_and_survives_cycles(self):
        self.assertEqual(dd.resolve("a", {"a": "b", "b": "c"}), "c")
        self.assertIn(dd.resolve("a", {"a": "b", "b": "a"}), {"a", "b"})
        self.assertEqual(dd.resolve("x", {"a": "b"}), "x")

    def test_final_renames_collapses_chains_and_rejects_loops(self):
        self.assertEqual(dd.final_renames([("a", "b"), ("b", "c"), ("x", "y")]), {"a": "c", "b": "c", "x": "y"})
        for pairs in ([("a", "b"), ("b", "a")], [("a", "a")]):
            with self.assertRaisesRegex(ValueError, "loops"):
                dd.final_renames(pairs)

    def test_rename_tool_reads_the_shared_rename_list(self):
        import rename  # noqa: E402  (tools/rename.py)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "renames.csv"
            path.write_text("old_name,new_name\na,b\nb,c\n", encoding="utf-8")
            self.assertEqual(rename.read_renames(path), {"a": "c", "b": "c"})
            path.write_text("old_name,new_name\na,b\na,c\n", encoding="utf-8")
            with self.assertRaises(dd.DataError):  # the same duplicate check the Luau alias builder uses
                rename.read_renames(path)


class TestReplay(unittest.TestCase):
    def test_merges_attachments_and_guns(self):
        rows = [("old_bolt", 5, "Vector", 5), ("new_bolt", 3, "SCALAR", 3), ("other", 2, "M4A1", 2)]
        merged = fx.replay_merge(rows, {"old_bolt": "new_bolt"}, {"Vector": "SCALAR"})
        self.assertEqual(merged["new_bolt"]["kills"], 8)
        self.assertEqual(dict(merged["new_bolt"]["guns"]), {"SCALAR": 8})
        self.assertEqual(fx.merges_from_replay(merged), {"new_bolt": (8, "SCALAR", 8, {"old_bolt", "new_bolt"})})

    def test_top_gun_ties_go_to_the_first_gun_alphabetically(self):
        self.assertEqual(fx.top_gun({"M4A1": 5, "AK_762": 5, "UMP": 1}), ("AK_762", 5))

    def test_parse_fixture(self):
        text = ' ["a_b"]={kills=12,top_gun="SCARH",top_gun_kills=10}, ["c"]={kills=1,top_gun="M4A1",top_gun_kills=1}'
        self.assertEqual(fx.parse_fixture(text), [("a_b", 12, "SCARH", 10), ("c", 1, "M4A1", 1)])

    def test_expected_merges_round_trip(self):
        merges = {"x": (3, "SCARH", 2, {"a", "b"})}
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "merges.csv"
            fx.write_expected_merges(merges, path)
            self.assertEqual(fx.load_expected_merges(path), merges)


class TestLuauGeneration(unittest.TestCase):
    def test_luau_string_escaping(self):
        s = luau.luau_string
        self.assertEqual(s('SLx 1.1"'), '"SLx 1.1\\""')
        self.assertEqual(s("a\\b"), '"a\\\\b"')
        self.assertEqual(s("{x}"), '"\\123x\\125"')
        self.assertEqual(s("\n1"), '"\\0101"')  # 3-digit escape, so the following digit is not absorbed
        self.assertEqual(s("ü"), '"\\195\\188"')

    def test_pack_respects_the_line_budget(self):
        entries = [f"e{i}," for i in range(1000)]
        rows = luau.pack(entries, 32)
        self.assertLessEqual(len(rows), 32)
        self.assertEqual(" ".join(r.strip() for r in rows).split(), entries)

    def test_part_labels(self):
        labels = names_builder.part_labels(["aft_stock_cheek_piece", "aft_stock_connector"], "AFT")
        self.assertEqual(labels, {"aft_stock_cheek_piece": "Cheek Piece", "aft_stock_connector": "Connector"})
        labels = names_builder.part_labels(["x_castlenut", "x_castlenut_hk"], "X Castle Nut")
        self.assertEqual(labels, {"x_castlenut": "Standard", "x_castlenut_hk": "HK"})

    def test_label_words(self):
        w = names_builder.label_word
        self.assertEqual([w(t) for t in ["bcg", "gen2", "20r", "ak74", "30mm", "5.45x39", "gasblock"]],
                         ["BCG", "Gen2", "20R", "AK74", "30mm", "5.45x39", "Gas Block"])


class TestGroupValidation(unittest.TestCase):
    def test_rejects_bad_rows(self):
        _, _, names, _ = names_builder.load_all_names()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "groups.csv"
            for body, problem in [("fn_scar_sc_stock_buttpad,X\nfn_scar_sc_stock_cheekpad,X\n", "renamed"),
                                  ("aft_stock_connector,Solo\n", "only one piece"),
                                  ("not_a_real_id,X\naft_stock_connector,X\n", "not a known"),
                                  ("SCARH,X\naft_stock_connector,X\n", "not a known"),
                                  ("aft_stock_connector,X\naft_stock_connector,X\n", "twice")]:
                path.write_text("id,group\n" + body, encoding="utf-8")
                with self.assertRaises(dd.DataError) as ctx:
                    names_builder.load_groups(names, path)
                self.assertIn(problem, str(ctx.exception))


class TestFixtureValidation(unittest.TestCase):
    def test_valid_rows_pass(self):
        rows = [("att_a", 10, "M4A1", 8), ("att_b", 5, "SCARH", 5)]
        self.assertEqual(fx.validate_fixture_rows(rows), [])

    def test_empty_rows_fail(self):
        self.assertIn("0 rows", fx.validate_fixture_rows([])[0])

    def test_duplicate_attachment_ids_fail(self):
        rows = [("att_a", 10, "M4A1", 8), ("att_a", 5, "SCARH", 5)]
        errors = fx.validate_fixture_rows(rows)
        self.assertTrue(any("duplicate" in e for e in errors))

    def test_invalid_counts_and_missing_gun_fail(self):
        cases = [
            ([("att_a", 10, "M4A1", 12)], "exceeds"),
            ([("att_b", -1, "M4A1", 0)], "negative kills"),
            ([("att_c", 5, "M4A1", -1)], "negative top_gun_kills"),
            ([("att_d", 5, "", 2)], "missing top_gun"),
        ]
        for rows, expected in cases:
            with self.subTest(expected=expected):
                errors = fx.validate_fixture_rows(rows)
                self.assertTrue(any(expected in e for e in errors), f"expected {expected} in {errors}")


if __name__ == "__main__":
    unittest.main()
