"""Comprehensive test suite for deadline-stat-printer.

Covers:
  1. Alias integrity: renames.csv validity, 253 pairs, cycle freedom.
  2. Luau structural integrity: balanced braces, tab-free formatting, no Luau type annotations (Fiu VM).
  3. SRP modular architecture: dedicated modules for data, aggregation, formatting, and rendering.
  4. Table synchronization: print_attachment_stats.luau, print_attachment_stats_delimited.luau, and modules/attachment_data.luau.
  5. Live dynamic sync logic: safe pcall, correct upstream URL.
  6. Merge & kill conservation: exact 1,717,503 kill conservation and multi-source merge validation.
  7. Tool verification: verify_attachment_merge.py and build_attachment_aliases.py execution.

Run with:
  python tests/test_suite.py
  or:
  python -m unittest tests/test_suite.py
"""
import csv
import re
import subprocess
import sys
import unittest
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RENAMES_CSV = ROOT / "renames.csv"
PRINT_ATTACHMENT_LUAU = ROOT / "print_attachment_stats.luau"
DELIMITED_LUAU = ROOT / "print_attachment_stats_delimited.luau"
PRINT_PLAYER_LUAU = ROOT / "print_player_stats.luau"

MODULES_DIR = ROOT / "modules"
ATTACHMENT_DATA_LUAU = MODULES_DIR / "attachment_data.luau"
ATTACHMENT_AGGREGATOR_LUAU = MODULES_DIR / "attachment_aggregator.luau"
ATTACHMENT_FORMATTER_LUAU = MODULES_DIR / "attachment_formatter.luau"
ATTACHMENT_RENDERER_LUAU = MODULES_DIR / "attachment_renderer.luau"
WEAPON_DATA_LUAU = MODULES_DIR / "weapon_data.luau"
LEVEL_DATA_LUAU = MODULES_DIR / "level_data.luau"
FORMATTERS_LUAU = MODULES_DIR / "formatters.luau"
STATS_AGGREGATOR_LUAU = MODULES_DIR / "stats_aggregator.luau"
FILTERS_SORTERS_LUAU = MODULES_DIR / "filters_sorters.luau"
RENDERER_LUAU = MODULES_DIR / "renderer.luau"

LOG_FIXTURE = ROOT / "tests" / "attachment logs output.txt"


def load_csv_aliases(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        rows = list(csv.reader(f))
    return {r[0].strip(): r[1].strip() for r in rows[1:] if len(r) == 2 and r[0].strip() and r[1].strip()}


def extract_luau_table_aliases(file_path: Path) -> dict:
    text = file_path.read_text(encoding="utf-8")
    pairs = re.findall(r'^\s*\["([^"]+)"\] = "([^"]+)",\s*$', text, re.M)
    return dict(pairs)


def resolve_alias(att_id: str, aliases: dict) -> str:
    seen = set()
    current = att_id
    while current in aliases and current not in seen:
        seen.add(current)
        current = aliases[current]
    return current


class TestRenamesIntegrity(unittest.TestCase):
    def test_renames_csv_exists_and_has_full_count(self):
        self.assertTrue(RENAMES_CSV.is_file(), "renames.csv must exist as the single canonical alias file")
        aliases = load_csv_aliases(RENAMES_CSV)
        self.assertEqual(len(aliases), 253, f"renames.csv should have exactly 253 pairs, found {len(aliases)}")

    def test_no_redundant_full_file(self):
        full_csv = ROOT / "renames_full.csv"
        self.assertFalse(full_csv.is_file(), "renames_full.csv should be consolidated into renames.csv")

    def test_no_cycles_in_aliases(self):
        aliases = load_csv_aliases(RENAMES_CSV)
        for start_id in aliases:
            visited = []
            curr = start_id
            while curr in aliases:
                self.assertNotIn(curr, visited, f"Cycle detected in renames.csv: {' -> '.join(visited + [curr])}")
                visited.append(curr)
                curr = aliases[curr]

    def test_known_historical_merges_in_renames(self):
        aliases = load_csv_aliases(RENAMES_CSV)
        self.assertEqual(aliases.get("vector_9mm_bolt"), "kalis_scalar_std_bcg")
        self.assertEqual(aliases.get("vector_45acp_bolt"), "kalis_scalar_std_bcg")
        self.assertEqual(aliases.get("schmidt_super_scar_trigger"), "vallais_super_fang_trigger")
        self.assertEqual(aliases.get("schmidt_smr_mk16_mlok_urg_i_9.3inch"), "vallais_mfh_mk16_mlok_urgi_9.3inch")
        self.assertEqual(aliases.get("vallais_smr_mk16_mlok_urg_i_9.3inch"), "vallais_mfh_mk16_mlok_urgi_9.3inch")
        self.assertEqual(aliases.get("schneider_defense_qbz95_long_bow_picatinny_carry_handle"), "qingyuan_defense_qbz95_long_bow_picatinny_carry_handle")


class TestLuauStructuralIntegrity(unittest.TestCase):
    def setUp(self):
        self.luau_files = list(ROOT.glob("*.luau")) + list(MODULES_DIR.glob("*.luau"))

    def test_balanced_braces(self):
        for path in self.luau_files:
            text = path.read_text(encoding="utf-8")
            open_b = text.count("{")
            close_b = text.count("}")
            self.assertEqual(
                open_b, close_b,
                f"Unbalanced curly braces in {path.name}: {open_b} open vs {close_b} close"
            )

    def test_no_tabs(self):
        for path in self.luau_files:
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("\t", text, f"Found tab character in {path.name}")

    def test_no_fiu_incompatible_type_annotations(self):
        for path in self.luau_files:
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("::", text, f"Found Luau type cast operator '::' in {path.name}")


class TestSRPModularArchitecture(unittest.TestCase):
    def test_attachment_data_module(self):
        self.assertTrue(ATTACHMENT_DATA_LUAU.is_file(), "modules/attachment_data.luau must exist")
        content = ATTACHMENT_DATA_LUAU.read_text(encoding="utf-8")
        self.assertIn("function AttachmentData.resolve(", content)
        self.assertIn("function AttachmentData.is_legacy(", content)
        self.assertIn("function AttachmentData.all_aliases(", content)
        self.assertIn("function AttachmentData.sync_latest_renames(", content)

    def test_attachment_aggregator_module(self):
        self.assertTrue(ATTACHMENT_AGGREGATOR_LUAU.is_file(), "modules/attachment_aggregator.luau must exist")
        content = ATTACHMENT_AGGREGATOR_LUAU.read_text(encoding="utf-8")
        self.assertIn("function AttachmentAggregator.aggregate(", content)

    def test_attachment_formatter_module(self):
        self.assertTrue(ATTACHMENT_FORMATTER_LUAU.is_file(), "modules/attachment_formatter.luau must exist")
        content = ATTACHMENT_FORMATTER_LUAU.read_text(encoding="utf-8")
        self.assertIn("function AttachmentFormatter:resolve_attachment_display_name(", content)
        self.assertIn("function AttachmentFormatter:resolve_weapon_display_name(", content)

    def test_attachment_renderer_module(self):
        self.assertTrue(ATTACHMENT_RENDERER_LUAU.is_file(), "modules/attachment_renderer.luau must exist")
        content = ATTACHMENT_RENDERER_LUAU.read_text(encoding="utf-8")
        self.assertIn("function AttachmentRenderer:render_table(", content)
        self.assertIn("function AttachmentRenderer:render_delimited(", content)

    def test_weapon_modules_integrity(self):
        for p in [WEAPON_DATA_LUAU, LEVEL_DATA_LUAU, FORMATTERS_LUAU, STATS_AGGREGATOR_LUAU, FILTERS_SORTERS_LUAU, RENDERER_LUAU]:
            self.assertTrue(p.is_file(), f"{p.name} must exist")
            self.assertGreater(len(p.read_text(encoding="utf-8").splitlines()), 20, f"{p.name} must not be empty")


class TestTableSynchronization(unittest.TestCase):
    def setUp(self):
        self.aliases = load_csv_aliases(RENAMES_CSV)

    def test_print_attachment_stats_table_matches(self):
        table = extract_luau_table_aliases(PRINT_ATTACHMENT_LUAU)
        self.assertEqual(len(table), 253, f"Expected 253 aliases in {PRINT_ATTACHMENT_LUAU.name}, got {len(table)}")
        self.assertEqual(table, self.aliases, f"{PRINT_ATTACHMENT_LUAU.name} does not match renames.csv")

    def test_delimited_script_matches(self):
        self.assertTrue(DELIMITED_LUAU.is_file(), "print_attachment_stats_delimited.luau must exist")
        table = extract_luau_table_aliases(DELIMITED_LUAU)
        self.assertEqual(len(table), 253, f"Expected 253 aliases in {DELIMITED_LUAU.name}, got {len(table)}")
        self.assertEqual(table, self.aliases, f"{DELIMITED_LUAU.name} does not match renames.csv")

    def test_only_one_delimited_file_exists(self):
        hyphen_copy = ROOT / "print-attachment-stats-delimited.luau"
        self.assertFalse(hyphen_copy.is_file(), "Old hyphenated copy print-attachment-stats-delimited.luau should not exist")
        self.assertTrue(DELIMITED_LUAU.is_file(), "print_attachment_stats_delimited.luau must be the sole delimited file")

    def test_attachment_data_module_matches(self):
        table = extract_luau_table_aliases(ATTACHMENT_DATA_LUAU)
        self.assertEqual(len(table), 253, f"Expected 253 aliases in {ATTACHMENT_DATA_LUAU.name}, got {len(table)}")
        self.assertEqual(table, self.aliases, f"{ATTACHMENT_DATA_LUAU.name} does not match renames.csv")


class TestDynamicSyncMechanism(unittest.TestCase):
    def test_live_sync_present_and_protected(self):
        for p in [PRINT_ATTACHMENT_LUAU, DELIMITED_LUAU, ATTACHMENT_DATA_LUAU]:
            content = p.read_text(encoding="utf-8")
            self.assertIn("sync_latest_renames", content, f"Missing sync_latest_renames in {p.name}")
            self.assertIn("pcall", content, f"sync_latest_renames must be wrapped in pcall in {p.name}")
            self.assertIn("recoil-group/deadline-balancing", content, f"Missing upstream URL in {p.name}")


class TestLogAggregationAndKillConservation(unittest.TestCase):
    def test_kill_conservation_and_merges(self):
        self.assertTrue(LOG_FIXTURE.is_file(), "Log fixture tests/attachment logs output.txt must exist")
        content = LOG_FIXTURE.read_text(encoding="utf-8")
        pat = re.compile(r'\["([^"]+)"\]=\{kills=(\d+),top_gun="([^"]+)",top_gun_kills=(\d+)\}')
        items = pat.findall(content)
        self.assertEqual(len(items), 1103, f"Expected 1103 log rows, parsed {len(items)}")

        raw_log = {a: (int(k), gun, int(gk)) for a, k, gun, gk in items}
        raw_total_kills = sum(v[0] for v in raw_log.values())
        self.assertEqual(raw_total_kills, 1717503, f"Expected raw total kills 1,717,503, got {raw_total_kills}")

        aliases = load_csv_aliases(RENAMES_CSV)
        kills = defaultdict(int)
        weapons = defaultdict(lambda: defaultdict(int))
        sources = defaultdict(set)

        for att_id, (k, top_gun, top_kills) in raw_log.items():
            canon = resolve_alias(att_id, aliases)
            sources[canon].add(att_id)
            kills[canon] += k
            weapons[canon][top_gun] += k

        merged_total_kills = sum(kills.values())
        self.assertEqual(raw_total_kills, merged_total_kills, "Kills must be strictly conserved before and after merge")

        def top_of(canon):
            best, best_k = None, -1
            for g, gk in weapons[canon].items():
                if gk > best_k or (gk == best_k and (best is None or g < best)):
                    best, best_k = g, gk
            return best, best_k

        expected_merges = {
            "kalis_scalar_std_bcg": (705, "Vector", 705, {"vector_9mm_bolt", "vector_45acp_bolt"}),
            "vallais_super_fang_trigger": (13952, "SCARH", 13169, {"schmidt_super_scar_trigger", "vallais_super_fang_trigger"}),
            "vallais_mfh_mk16_mlok_urgi_9.3inch": (2285, "M4A1", 2285, {"schmidt_smr_mk16_mlok_urg_i_9.3inch", "vallais_smr_mk16_mlok_urg_i_9.3inch"}),
            "vallais_mfh_mk16_mlok_urgi_15inch": (159, "M4A1", 159, {"schmidt_smr_mk16_mlok_urg_i_15inch", "vallais_smr_mk16_mlok_urg_i_15inch"}),
            "qingyuan_defense_qbz95_long_bow_picatinny_carry_handle": (333, "QBZ95", 333, {"qingyuan_defense_qbz95_long_bow_picatinny_carry_handle", "schneider_defense_qbz95_long_bow_picatinny_carry_handle"}),
        }

        multi = {canon: srcs for canon, srcs in sources.items() if len(srcs) > 1}
        self.assertEqual(set(multi.keys()), set(expected_merges.keys()), "Multi-source merges set mismatch")

        for canon, (exp_k, exp_gun, exp_gk, exp_srcs) in expected_merges.items():
            self.assertEqual(kills[canon], exp_k, f"{canon} kills mismatch")
            got_gun, got_gk = top_of(canon)
            self.assertEqual(got_gun, exp_gun, f"{canon} top gun mismatch")
            self.assertEqual(got_gk, exp_gk, f"{canon} top gun kills mismatch")
            self.assertTrue(exp_srcs <= sources[canon], f"{canon} missing contributing sources")


class TestToolsExecution(unittest.TestCase):
    def test_verify_attachment_merge_script(self):
        res = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "verify_attachment_merge.py")],
            cwd=str(ROOT),
            capture_output=True,
            text=True
        )
        self.assertEqual(res.returncode, 0, f"verify_attachment_merge.py failed:\n{res.stdout}\n{res.stderr}")

    def test_build_attachment_aliases_script_check_mode(self):
        res = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "build_attachment_aliases.py"), "--check", "--offline"],
            cwd=str(ROOT),
            capture_output=True,
            text=True
        )
        self.assertEqual(res.returncode, 0, f"build_attachment_aliases.py --check failed:\n{res.stdout}\n{res.stderr}")


if __name__ == "__main__":
    unittest.main()
