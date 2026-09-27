"""Regenerate / verify the embedded ATTACHMENT_ALIASES table in
print-attachment-stats.luau from deadline-balancing renames.csv
(tracked in this repo as renames.csv).

Usage:
    python tools/build_attachment_aliases.py           # rewrite the table in place
    python tools/build_attachment_aliases.py --check   # exit 0 if table matches CSV, 1 on drift

The Luau file must contain the marker lines:
    -- BEGIN ATTACHMENT_ALIASES ...
    -- END ATTACHMENT_ALIASES
Only the lines between the markers are replaced; all hand-written
logic in the file is left untouched.
"""
import csv
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "renames.csv"
LUAU_PATH = ROOT / "print-attachment-stats.luau"
BEGIN = "-- BEGIN ATTACHMENT_ALIASES"
END = "-- END ATTACHMENT_ALIASES"


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
        if '"' in o or '"' in n or "\\" in o or "\\" in n:
            raise SystemExit(f"id needs Luau escaping: {o!r} -> {n!r}")
    return sorted(pairs, key=lambda p: p[0].lower())


def render(pairs):
    return "\n".join(f'    ["{o}"] = "{n}",' for o, n in pairs)


def split_markers(text):
    # head: everything through the `local ATTACHMENT_ALIASES = {` line.
    # tail: from the closing `}` line (which precedes the END marker) onward.
    # This preserves the table constructor and both marker lines across rewrites.
    if BEGIN not in text:
        raise SystemExit("BEGIN marker not found in Luau file")
    if END not in text:
        raise SystemExit("END marker not found in Luau file")
    ctor = "local ATTACHMENT_ALIASES = {"
    ctor_start = text.index(ctor)
    if ctor_start < text.index(BEGIN):
        raise SystemExit("table constructor found before BEGIN marker")
    head_end = text.index("\n", ctor_start) + 1
    end_pos = text.index(END)
    close_start = text.rfind("\n}", 0, end_pos)
    if close_start == -1:
        raise SystemExit('closing "}" line not found before END marker')
    tail_start = close_start + 1  # keep the "}" line in the tail
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


def sync_table(pairs, check_only=False):
    """Rewrite the alias block if it drifted; returns 0/1 exit code."""
    text = LUAU_PATH.read_text(encoding="utf-8")
    head, tail = split_markers(text)
    current_block = text[len(head):len(text) - len(tail)].strip("\n")
    # strip marker lines from the extracted block for comparison
    body_lines = [ln for ln in current_block.splitlines()
                  if not ln.startswith("-- BEGIN") and not ln.startswith("-- END")]
    expected = render(pairs)
    if "\n".join(body_lines).strip() == expected.strip():
        print("Luau table is in sync with renames.csv.")
        return 0
    if check_only:
        print("DRIFT: Luau table does not match renames.csv. Run without --check to regenerate.")
        return 1
    LUAU_PATH.write_text(head + expected + "\n" + tail, encoding="utf-8")
    print(f"rewrote ATTACHMENT_ALIASES in {LUAU_PATH.name} ({len(pairs)} entries).")
    return 0


def main(argv=None):
    check_only = argv is not None and "--check" in argv
    pairs = load_pairs()
    report_stats(pairs)
    return sync_table(pairs, check_only)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

