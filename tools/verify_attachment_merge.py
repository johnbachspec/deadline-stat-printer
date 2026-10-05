"""Replays the attachment merge (renames.csv + weapon renames) over a saved
output of print_attachment_stats.luau's "fixture" view and checks the result.

Usage:
    python tools/verify_attachment_merge.py                    # check tests/fixtures/attachment_stats_output.txt
    python tools/verify_attachment_merge.py "path/to/log.txt"  # check another saved output
    python tools/verify_attachment_merge.py --write-expected   # rewrite tests/fixtures/expected_merges.csv

Checks:
  1. fixture integrity (no duplicates, valid kill counts, non-empty gun names),
  2. total kills are conserved by the merge (no double count, no loss),
  3. every current id built from 2+ logged ids is listed in expected_merges.csv with
     the same kills, top gun and contributing ids (no surprise merges, none missing).

After adding renames that fold ids in the fixture together, review the printed
merges and run with --write-expected.
"""
import sys
from pathlib import Path

import deadline_data as dd
import fixture_replay as fx


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    log_path = Path(args[0]) if args else dd.FIXTURE_OUTPUT
    if not log_path.is_file():
        print(f"FAIL  saved output not found: {log_path}")
        return 1
    rows = fx.load_fixture(log_path)
    failures = [f"fixture error: {err}" for err in fx.validate_fixture_rows(rows)]
    merged = fx.replay_merge(rows, dict(dd.load_renames()), dd.load_weapon_aliases())
    merges = fx.merges_from_replay(merged)

    print(f"{len(rows)} logged rows -> {len(merged)} current ids, {len(merges)} built from 2+ logged ids:")
    for canon in sorted(merges):
        kills, gun, gun_kills, sources = merges[canon]
        print(f"  {canon}: {kills} kills, top {gun} ({gun_kills}) <- {', '.join(sorted(sources))}")

    if "--write-expected" in argv:
        if failures:
            print("\nFAIL  cannot write expected merges from an invalid fixture:")
            for f in failures:
                print(f"      {f}")
            return 1
        fx.write_expected_merges(merges)
        print(f"\nwrote {dd.EXPECTED_MERGES_CSV.relative_to(dd.ROOT)}")
        return 0

    before, after = sum(r[1] for r in rows), sum(b["kills"] for b in merged.values())
    if before != after:
        failures.append(f"kills not conserved: {before} logged, {after} after merging")
    expected = fx.load_expected_merges()
    for canon in sorted(set(expected) | set(merges)):
        if expected.get(canon) != merges.get(canon):
            failures.append(f"{canon}: expected {expected.get(canon)}, got {merges.get(canon)}")

    print()
    for f in failures:
        print(f"FAIL  {f}")
    print(f"FAILED ({len(failures)})" if failures else f"ALL CHECKS PASSED ({before} kills conserved)")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(dd.run_cli(main, sys.argv))
