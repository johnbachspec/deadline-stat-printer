"""Comprehensive Test Suite for Deadline Stat Printer
Runs unit tests, validation checks, and regression tests across:
  - Fiu VM compatibility (no Luau type annotations `::`, no tabs `\t`, balanced braces)
  - SRP modular architecture (modules/ integrity and responsibility boundaries)
  - Attachment renames & synchronization (renames.csv, balancing.csv, and embedded tables)
  - Live dynamic GitHub syncing protection (HttpService pcall guards)
  - Log aggregation and mathematical kill conservation (1,717,503 kills fixture)
  - Execution of tool scripts (verify_attachment_merge.py, build_attachment_aliases.py, build_attachment_names.py)

Usage:
  python tests/test_suite.py
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
BALANCING_CSV = ROOT / "balancing.csv"
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


def load_csv_aliases(path):
    with open(path, encoding="utf-8") as f:
        r = csv.reader(f)
        rows = list(r)
    aliases = {}
    for row in rows[1:]:
        if len(row) >= 2 and row[0].strip() and row[1].strip():
            aliases[row[0].strip()] = row[1].strip()
    return aliases


def extract_luau_table_aliases(path):
    text = path.read_text(encoding="utf-8")
    m = re.search(r"-- BEGIN ATTACHMENT_ALIASES.*?local ALIASES_CSV = \[\[(.*?)\]\].*?-- END ATTACHMENT_ALIASES", text, re.DOTALL)
    if not m:
        raise ValueError(f"Could not find ATTACHMENT_ALIASES block in {path}")
    table = {}
    for line in m.group(1).splitlines():
        pair_match = re.match(r"([^,]+),([^,]+)$", line.strip())
        if pair_match:
            table[pair_match.group(1)] = pair_match.group(2)
    return table


def resolve_alias(att_id, aliases):
    seen = set()
    curr = att_id
    while curr in aliases and curr not in seen:
        seen.add(curr)
        curr = aliases[curr]
    return curr


class TestRenamesIntegrity(unittest.TestCase):
    def test_renames_csv_exists_and_has_full_count(self):
        self.assertTrue(RENAMES_CSV.is_file(), "renames.csv must exist in repo root")
        aliases = load_csv_aliases(RENAMES_CSV)
        self.assertEqual(len(aliases), 253, f"Expected 253 aliases in renames.csv, found {len(aliases)}")

    def test_no_redundant_full_file(self):
        full_csv = ROOT / "renames_full.csv"
        self.assertFalse(full_csv.is_file(), "renames_full.csv should be removed in favor of single renames.csv")

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
        self.assertIn("function AttachmentFormatter:sync_balancing_names(", content)

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


class TestBeautifiedNamesAndBalancing(unittest.TestCase):
    def test_balancing_csv_exists_and_loaded(self):
        self.assertTrue(BALANCING_CSV.is_file(), "balancing.csv must exist in repo root")
        with open(BALANCING_CSV, encoding="utf-8", errors="replace") as f:
            r = csv.reader(f)
            names = {row[2].strip(): row[3].strip() for row in r if len(row) > 3 and row[2].strip()}
        self.assertGreaterEqual(len(names), 2400, "balancing.csv should have >= 2400 attachment names")

    def test_attachment_formatter_sync_and_beautified_names(self):
        content = ATTACHMENT_FORMATTER_LUAU.read_text(encoding="utf-8")
        self.assertIn("function AttachmentFormatter:sync_balancing_names(", content)
        self.assertIn("recoil-studio/deadline-balancing", content)
        self.assertIn("recoil-group/deadline-balancing", content)
        self.assertIn("AttachmentFormatter.BEAUTIFIED_NAMES = {}", content)
        self.assertIn("runtime loaded; intentionally no embedded table", content)

    def test_sample_beautified_names(self):
        content = ATTACHMENT_FORMATTER_LUAU.read_text(encoding="utf-8")
        self.assertIn("function AttachmentFormatter:sync_balancing_names(", content)
        self.assertNotIn('["kalis_scalar_std_bcg"] = "KALIS Scalar Standard",', content)


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

    def test_build_attachment_names_script_check_mode(self):
        res = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "build_attachment_names.py"), "--check"],
            cwd=str(ROOT),
            capture_output=True,
            text=True
        )
        self.assertEqual(res.returncode, 0, f"build_attachment_names.py --check failed:\n{res.stdout}\n{res.stderr}")


if __name__ == "__main__":
    unittest.main()
