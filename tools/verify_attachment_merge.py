"""Validation mirror of the ATTACHMENT_ALIASES merge logic added to
print_attachment_stats.luau (Luau cannot execute here, so this replays the
exact same aggregation in Python against a saved printer output).

Usage:
    python tools/verify_attachment_merge.py
    python tools/verify_attachment_merge.py "path/to/custom log output.txt"

Checks:
  1. total kills are conserved by the merge (no double count, no loss),
  2. the known duplicate merges listed in tests/expected_merges.csv, e.g.
     vector_9mm_bolt (511) + vector_45acp_bolt (194) -> kalis_scalar_std_bcg (705, top Vector),
  3. every canonical id whose total combines 2+ distinct log rows is listed,
  4. the embedded Luau alias table matches renames.csv verbatim,
  5. structural sanity of the Luau files (balanced braces, no tabs).
"""
import csv
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_LOG_PATH = ROOT / "tests" / "attachment logs output.txt"
CSV_PATH = ROOT / "renames.csv"
LUAU_PATH = ROOT / "print_attachment_stats.luau"
DELIMITED_PATH = ROOT / "print_attachment_stats_delimited.luau"
ATTACHMENT_DATA_PATH = ROOT / "modules" / "attachment_data.luau"
EXPECTED_MERGES_PATH = ROOT / "tests" / "expected_merges.csv"

failures = []


def load_expected_merges(path=EXPECTED_MERGES_PATH):
    """canonical id -> (total kills, top gun, top gun kills, set of contributing log ids)."""
    with open(path, encoding="utf-8") as f:
        return {r["canonical_id"]: (int(r["kills"]), r["top_gun"], int(r["top_gun_kills"]), set(r["sources"].split(";")))
                for r in csv.DictReader(f)}


ALL_EXPECTED_MERGES = load_expected_merges()


def check(cond, msg):
    print(("PASS  " if cond else "FAIL  ") + msg)
    if not cond:
        failures.append(msg)


def load_aliases():
    with open(CSV_PATH, encoding="utf-8") as f:
        rows = list(csv.reader(f))
    return {r[0].strip(): r[1].strip() for r in rows[1:]
            if len(r) == 2 and r[0].strip() and r[1].strip()}


def resolve(att_id, aliases):
    seen = set()
    current = att_id
    while current in aliases and current not in seen:
        seen.add(current)
        current = aliases[current]
    return current


def main():
    log_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_LOG_PATH
    if not log_path.is_file():
        print(f"FAIL  log fixture not found: {log_path}")
        print("      pass the printer output file as an argument, e.g.:")
        print("      python tools/verify_attachment_merge.py \"path/to/log output.txt\"")
        return 1
    aliases = load_aliases()
    check(bool(aliases), f"loaded {len(aliases)} alias pairs from {CSV_PATH.name}")

    # 4. Embedded alias table in sync with renames.csv?
    text = LUAU_PATH.read_text(encoding="utf-8")
    block = re.search(r"-- BEGIN ATTACHMENT_ALIASES(.*?)-- END ATTACHMENT_ALIASES", text, re.S)
    luau_pairs = []
    if block:
        luau_pairs = re.findall(r'\["([^"]+)"\]\s*=\s*"([^"]+)"', block.group(1))
    check(len(luau_pairs) == len(aliases),
          f"Luau alias table has {len(luau_pairs)} entries, {CSV_PATH.name} has {len(aliases)}")
    check(set(luau_pairs) == set(aliases.items()),
          f"Luau alias table identical to {CSV_PATH.name}")

    # 5. structural sanity
    check(text.count("{") == text.count("}"), "Luau braces balanced")
    check("\t" not in text, "Luau contains no tabs")
    check("-- BEGIN ATTACHMENT_ALIASES" in text and "-- END ATTACHMENT_ALIASES" in text,
          "Luau alias marker block present")

    if DELIMITED_PATH.is_file():
        dtext = DELIMITED_PATH.read_text(encoding="utf-8")
        check(dtext.count("{") == dtext.count("}"), "Delimited Luau braces balanced")
        check("\t" not in dtext, "Delimited Luau contains no tabs")

    if ATTACHMENT_DATA_PATH.is_file():
        atext = ATTACHMENT_DATA_PATH.read_text(encoding="utf-8")
        check(atext.count("{") == atext.count("}"), "modules/attachment_data.luau braces balanced")
        check("\t" not in atext, "modules/attachment_data.luau contains no tabs")

    # parse the printer's own output format
    content = log_path.read_text(encoding="utf-8")
    pat = re.compile(r'\["([^"]+)"\]=\{kills=(\d+),top_gun="([^"]+)",top_gun_kills=(\d+)\}')
    items = pat.findall(content)
    check(bool(items), f"parsed {len(items)} attachment rows from log output")
    log = {a: (int(k), t, int(tk)) for a, k, t, tk in items}

    # mirror of the Luau aggregation loop
    kills = defaultdict(int)
    weapons = defaultdict(lambda: defaultdict(int))
    sources = defaultdict(set)
    legacy_merged = 0
    for att_id, (k, top_gun, top_kills) in log.items():
        canon = resolve(att_id, aliases)
        if canon != att_id and att_id not in sources[canon]:
            legacy_merged += 1
        sources[canon].add(att_id)
        kills[canon] += k
        weapons[canon][top_gun] += k

    # 1. conservation
    check(sum(kills.values()) == sum(v[0] for v in log.values()),
          f"kills conserved: {sum(kills.values())} before+after merge "
          f"({len(log)} rows -> {len(kills)} canonical ids, {legacy_merged} legacy ids folded)")

    # top gun per merged bucket (same rule as Luau: max kills, ties -> lexicographically smallest gun)
    def top_of(canon):
        best, best_k = None, -1
        for g, gk in weapons[canon].items():
            if gk > best_k or (gk == best_k and (best is None or g < best)):
                best, best_k = g, gk
        return best, best_k

    # 2. known duplicates
    applicable_merges = {
        canon: vals for canon, vals in ALL_EXPECTED_MERGES.items()
        if any(src in aliases for src in vals[3])
    }
    for canon, (exp_k, exp_gun, exp_gk, exp_srcs) in applicable_merges.items():
        got_k = kills.get(canon)
        got_gun, got_gk = top_of(canon)
        check(got_k == exp_k, f"{canon}: {got_k} kills (expected {exp_k})")
        check(got_gun == exp_gun and got_gk == exp_gk,
              f"{canon}: top {got_gun}({got_gk}) (expected {exp_gun}({exp_gk}))")
        check(exp_srcs <= sources.get(canon, set()),
              f"{canon}: merged from {sorted(sources.get(canon, set()))}")

    # 3. every multi-source canonical id
    multi = {canon: srcs for canon, srcs in sources.items() if len(srcs) > 1}
    print(f"\ncanonical ids combining 2+ log rows: {len(multi)}")
    for canon in sorted(multi.keys()):
        srcs = sorted(multi[canon])
        k, (gun, gk) = kills[canon], top_of(canon)
        parts = ", ".join(f"{s}({log[s][0]})" for s in srcs)
        print(f"  {canon}: {k} kills, top {gun}({gk}) <- {parts}")
    check(set(multi.keys()) == set(applicable_merges.keys()),
          "multi-source set matches the expected duplicate list (no surprise merges, none missing)")

    print()
    if failures:
        print(f"FAILED ({len(failures)} checks failed)")
        return 1
    print("ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
