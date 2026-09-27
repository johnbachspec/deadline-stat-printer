"""Regenerate / verify the embedded ATTACHMENT_ALIASES table in
modules/attachment_data.luau, print_attachment_stats.luau, and
print_attachment_stats_delimited.luau from deadline-balancing renames.csv
(tracked in this repo as renames.csv).

Usage:
    python tools/build_attachment_aliases.py           # rewrite the tables in place
    python tools/build_attachment_aliases.py --fetch   # download latest renames.csv then rewrite
    python tools/build_attachment_aliases.py --check   # exit 0 if tables match CSV, 1 on drift

The Luau file must contain the marker lines:
    -- BEGIN ATTACHMENT_ALIASES ...
    -- END ATTACHMENT_ALIASES
Only the lines between the markers are replaced; all hand-written
logic in the file is left untouched.
"""
import csv
import sys
import urllib.request
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "renames.csv"
LUAU_PATH = ROOT / "print_attachment_stats.luau"
TARGET_FILES = [
    ROOT / "modules" / "attachment_data.luau",
    ROOT / "print_attachment_stats.luau",
    ROOT / "print_attachment_stats_delimited.luau",
]
BEGIN = "-- BEGIN ATTACHMENT_ALIASES"
END = "-- END ATTACHMENT_ALIASES"

UPSTREAM_URLS = [
    "https://raw.githubusercontent.com/recoil-studio/deadline-balancing/main/renames.csv",
    "https://raw.githubusercontent.com/recoil-group/deadline-balancing/main/renames.csv",
]


def fetch_upstream():
    """Download the latest renames.csv from upstream repository."""
    for url in UPSTREAM_URLS:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = resp.read()
                if len(data) > 500:
                    CSV_PATH.write_bytes(data)
                    print(f"Fetched latest renames.csv from {url} ({len(data)} bytes)")
                    return True
        except Exception:
            continue
    print("Warning: Failed to fetch upstream renames.csv, using existing local copy.")
    return False


def load_pairs(path=None):
    """Read and validate the rename list; returns pairs sorted by old name."""
    if path is None:
        path = CSV_PATH
    with open(path, encoding="utf-8") as f:
        rows = list(csv.reader(f))
    name = Path(path).name
    if not rows or rows[0][:2] != ["old_name", "new_name"]:
        raise SystemExit(f"unexpected header in {name}: {rows[0] if rows else None}")
    data = rows[1:]
    pairs = [(r[0].strip(), r[1].strip()) for r in data
             if len(r) == 2 and r[0].strip() and r[1].strip()]
    if len(pairs) != len(data):
        raise SystemExit(f"malformed (non old,new) rows in {name}")
    if len({o for o, _ in pairs}) != len(pairs):
        dupes = sorted(k for k, c in Counter(o for o, _ in pairs).items() if c > 1)
        raise SystemExit(f"duplicate old_name entries: {dupes}")
    for o, n in pairs:
        if '"' in o or '"' in n or "\" in o or "\" in n:
            raise SystemExit(f"id needs Luau escaping: {o!r} -> {n!r}")
    return sorted(pairs, key=lambda p: p[0].lower())


def render(pairs):
    return "\n".join(f'    ["{o}"] = "{n}",' for o, n in pairs)


def split_markers(text):
    if BEGIN not in text:
        raise SystemExit("BEGIN marker not found in Luau file")
    if END not in text:
        raise SystemExit("END marker not found in Luau file")
    ctor_candidates = ["local ATTACHMENT_ALIASES = {", "AttachmentData.ALIASES = {"]
    ctor_start = -1
    for ctor in ctor_candidates:
        pos = text.find(ctor)
        if pos != -1 and pos >= text.index(BEGIN):
            ctor_start = pos
            break
    if ctor_start == -1:
        raise SystemExit("table constructor found before BEGIN marker or not found")
    head_end = text.index("\n", ctor_start) + 1
    end_pos = text.index(END)
    close_start = text.rfind("\n}", 0, end_pos)
    if close_start == -1:
        raise SystemExit('closing "}" line not found before END marker')
    tail_start = close_start + 1
    return text[:head_end], text[tail_start:]


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
    head, tail = split_markers(text)
    current_block = text[len(head):len(text) - len(tail)].strip("\n")
    body_lines = [ln for ln in current_block.splitlines()
                  if not ln.startswith("-- BEGIN") and not ln.startswith("-- END")]
    expected = render(pairs)
    if "\n".join(body_lines).strip() == expected.strip():
        print(f"Luau table in {path.name} is in sync with renames.csv.")
        return 0
    if check_only:
        print(f"DRIFT: Luau table in {path.name} does not match renames.csv. Run without --check to regenerate.")
        return 1
    path.write_text(head + expected + "\n" + tail, encoding="utf-8")
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
