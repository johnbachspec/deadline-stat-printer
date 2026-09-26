"""Validation mirror of the ATTACHMENT_ALIASES merge logic added to
print-attachment-stats.luau (Luau cannot execute here, so this replays the
exact same aggregation in Python against a saved printer output).

Usage:
    python tools/verify_attachment_merge.py [log-output-file]

    Defaults to tests/attachment logs output.txt; the log file must use the
    printer's own output format:
        ["<att_id>"]={kills=N,top_gun="<gun>",top_gun_kills=M}, ...

Checks:
  1. total kills are conserved by the merge (no double count, no loss),
  2. the known duplicate merges: vector_9mm_bolt (511) + vector_45acp_bolt
     (194) -> kalis_scalar_std_bcg (705, top Vector),
  3. every canonical id whose total combines 2+ distinct log rows is listed,
  4. the embedded Luau table matches renames.csv verbatim,
  5. structural sanity of the Luau file (balanced braces, no tabs).
"""
import csv
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_LOG_PATH = ROOT / "tests" / "attachment logs output.txt"
CSV_PATH = ROOT / "renames.csv"
LUAU_PATH = ROOT / "print-attachment-stats.luau"

EXPECTED_MERGES = {
    # canonical id: (expected total kills, expected top gun, contributing legacy ids)
    "kalis_scalar_std_bcg": (705, "Vector", {"vector_9mm_bolt", "vector_45acp_bolt"}),
}

failures = []


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
        print("      python verify_attachment_merge.py \"path/to/log output.txt\"")
        return 1
    aliases = load_aliases()
    check(bool(aliases), f"loaded {len(aliases)} alias pairs from {CSV_PATH.name}")

    # 4. Luau table in sync with CSV?
    text = LUAU_PATH.read_text(encoding="utf-8")
    luau_pairs = re.findall(r'^\s*\["([^"]+)"\] = "([^"]+)",\s*$', text, re.M)
    check(len(luau_pairs) == len(aliases),
          f"Luau table has {len(luau_pairs)} entries, CSV has {len(aliases)}")
    check(set(luau_pairs) == set(aliases.items()),
          "Luau table entries identical to renames.csv")

    # 5. structural sanity (no Luau runtime here, so at least these)
    check(text.count("{") == text.count("}"), "Luau braces balanced")
    check("\t" not in text, "Luau contains no tabs")
    check("-- BEGIN ATTACHMENT_ALIASES" in text and "-- END ATTACHMENT_ALIASES" in text,
          "Luau alias marker block present")

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
        weapons[canon][top_gun] += k  # log rows already carry per-gun maxima merged by the printer

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

    # 2. known duplicate
    for canon, (exp_k, exp_gun, exp_srcs) in EXPECTED_MERGES.items():
        got_k = kills.get(canon)
        got_gun, got_gk = top_of(canon)
        check(got_k == exp_k, f"{canon}: {got_k} kills (expected {exp_k})")
        check(got_gun == exp_gun and got_gk == exp_k,
              f"{canon}: top {got_gun}({got_gk}) (expected {exp_gun}({exp_k}))")
        check(exp_srcs <= sources.get(canon, set()),
              f"{canon}: merged from {sorted(sources.get(canon, set()))}")

    # 3. every multi-source canonical id
    multi = {c: s for c, s in sources.items() if len(s) > 1}
    print(f"\ncanonical ids combining 2+ log rows: {len(multi)}")
    for c in sorted(multi, key=lambda c: -kills[c]):
        g, gk = top_of(c)
        detail = ", ".join(f"{s}({log[s][0]})" for s in sorted(multi[c]))
        print(f"  {c}: {kills[c]} kills, top {g}({gk}) <- {detail}")
    check(set(multi) == set(EXPECTED_MERGES),
          "multi-source set matches the expected duplicate list (no surprise merges, none missing)")

    print()
    if failures:
        print(f"{len(failures)} CHECK(S) FAILED")
        return 1
    print("ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
