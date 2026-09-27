"""Regenerate / verify the embedded ATTACHMENT_ALIASES table in
modules/attachment_data.luau, print_attachment_stats.luau, and
print_attachment_stats_delimited.luau from renames.csv.

renames.csv is deadline-balancing's rename list plus renames added by hand
here (historical ids upstream never listed). --fetch merges the upstream list
into it (upstream wins on conflicts) and never drops the hand-added rows.

Usage:
    python tools/build_attachment_aliases.py           # rewrite the tables in place
    python tools/build_attachment_aliases.py --fetch   # merge latest upstream renames.csv, then rewrite
    python tools/build_attachment_aliases.py --check   # exit 0 if tables match CSV, 1 on drift

Each Luau file must contain the marker lines:
    -- BEGIN ATTACHMENT_ALIASES ...
    -- END ATTACHMENT_ALIASES
Only the lines between the markers are replaced; all hand-written
logic in the file is left untouched.

The table is packed several entries per line so it takes about ALIAS_LINES
lines however many renames there are: Deadline's Fiu VM fails to load a
function whose code spans more than 255 source lines (see
tools/check_fiu_compat.py).
"""
import csv
import io
import math
import sys
import urllib.request
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "renames.csv"
TARGET_FILES = [
    ROOT / "modules" / "attachment_data.luau",
    ROOT / "print_attachment_stats.luau",
    ROOT / "print_attachment_stats_delimited.luau",
]
BEGIN = "-- BEGIN ATTACHMENT_ALIASES"
END = "-- END ATTACHMENT_ALIASES"
ALIAS_LINES = 24

UPSTREAM_URL = "https://raw.githubusercontent.com/recoil-group/deadline-balancing/main/renames.csv"


def parse_pairs(text, name):
    """Parse and validate rename rows; returns pairs sorted by old name."""
    rows = list(csv.reader(io.StringIO(text)))
    if not rows or [c.strip() for c in rows[0][:2]] != ["old_name", "new_name"]:
        raise SystemExit(f"unexpected header in {name}: {rows[0] if rows else None}")
    data = [r for r in rows[1:] if any(c.strip() for c in r)]
    pairs = [(r[0].strip(), r[1].strip()) for r in data
             if len(r) == 2 and r[0].strip() and r[1].strip()]
    if len(pairs) != len(data):
        raise SystemExit(f"malformed (non old,new) rows in {name}")
    if len({o for o, _ in pairs}) != len(pairs):
        dupes = sorted(k for k, c in Counter(o for o, _ in pairs).items() if c > 1)
        raise SystemExit(f"duplicate old_name entries in {name}: {dupes}")
    for o, n in pairs:
        if '"' in o or '"' in n or "\\" in o or "\\" in n:
            raise SystemExit(f"id needs Luau escaping: {o!r} -> {n!r}")
    return sorted(pairs, key=lambda p: p[0].lower())


def load_pairs(path=None):
    path = Path(path or CSV_PATH)
    return parse_pairs(path.read_text(encoding="utf-8-sig"), path.name)


def write_pairs(pairs, path=None):
    lines = ["old_name,new_name"] + [f"{o},{n}" for o, n in pairs]
    Path(path or CSV_PATH).write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def merge_pairs(local_pairs, upstream_pairs):
    """Upstream wins on conflicts; local-only rows are kept. Returns (sorted pairs, added ids, changed ids)."""
    merged, upstream = dict(local_pairs), dict(upstream_pairs)
    added = sorted(o for o in upstream if o not in merged)
    changed = sorted(o for o in upstream if o in merged and merged[o] != upstream[o])
    merged.update(upstream)
    return sorted(merged.items(), key=lambda p: p[0].lower()), added, changed


def fetch_upstream():
    """Merge the latest upstream renames.csv into the local one. Returns False if the download failed."""
    try:
        req = urllib.request.Request(UPSTREAM_URL, headers={"User-Agent": "deadline-stat-printer"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            text = resp.read().decode("utf-8-sig")
    except Exception as exc:
        print(f"Warning: could not fetch {UPSTREAM_URL} ({exc}); using the local renames.csv.")
        return False
    upstream = dict(parse_pairs(text, "upstream renames.csv"))
    merged, added, changed = merge_pairs(load_pairs(), upstream.items())
    if added or changed:
        write_pairs(merged)
    print(f"Merged {len(upstream)} upstream renames: {len(added)} new, {len(changed)} retargeted, "
          f"{len(merged) - len(upstream)} kept from local-only rows.")
    for o in added:
        print(f"  new: {o} -> {upstream[o]}")
    for o in changed:
        print(f"  retargeted: {o} -> {upstream[o]}")
    return True


def render(pairs):
    per_line = max(1, math.ceil(len(pairs) / ALIAS_LINES))
    entries = [f'["{o}"] = "{n}",' for o, n in pairs]
    rows = [" ".join(entries[i:i + per_line]) for i in range(0, len(entries), per_line)]
    return "\n".join(["local ATTACHMENT_ALIASES = {"] + ["    " + r for r in rows] + ["}"])


def split_markers(text, name):
    if BEGIN not in text:
        raise SystemExit(f"BEGIN marker not found in {name}")
    if END not in text:
        raise SystemExit(f"END marker not found in {name}")
    body_start = text.index("\n", text.index(BEGIN)) + 1
    body_end = text.index(END)
    return text[:body_start], text[body_start:body_end], text[body_end:]


def report_stats(pairs):
    merges = [(n, [o for o, m in pairs if m == n])
              for n in sorted({n for _, n in pairs})]
    merges = [(n, olds) for n, olds in merges if len(olds) > 1]
    chained = [(o, n) for o, n in pairs if any(o2 == n for o2, _ in pairs)]
    print(f"{CSV_PATH.name}: {len(pairs)} pairs, {len(merges)} merge(s), {len(chained)} chain(s)")
    for n, olds in merges:
        print(f"  merge: {n} <- {', '.join(olds)}")
    for o, n in chained:
        print(f"  chain (resolver follows it): {o} -> {n}")


def sync_table(path, pairs, check_only=False):
    text = path.read_text(encoding="utf-8")
    head, body, tail = split_markers(text, path.name)
    expected = render(pairs) + "\n"
    if body.replace("\r\n", "\n") == expected:
        print(f"ATTACHMENT_ALIASES in {path.name} is in sync with renames.csv.")
        return 0
    if check_only:
        print(f"DRIFT: ATTACHMENT_ALIASES in {path.name} does not match renames.csv. Run without --check to regenerate.")
        return 1
    path.write_text(head + expected + tail, encoding="utf-8", newline="\n")
    print(f"rewrote ATTACHMENT_ALIASES in {path.name} ({len(pairs)} entries).")
    return 0


def main(argv=None):
    if argv is None:
        argv = sys.argv
    if "--fetch" in argv:
        fetch_upstream()
    check_only = "--check" in argv
    pairs = load_pairs()
    report_stats(pairs)
    overall_rc = 0
    for target in TARGET_FILES:
        if target.is_file():
            rc = sync_table(target, pairs, check_only)
            if rc != 0:
                overall_rc = rc
    return overall_rc


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
