"""Regenerate / verify the ATTACHMENT_ALIASES table in modules/attachment_data.luau
from data/renames.csv.

data/renames.csv is deadline-balancing's rename list plus renames added by hand
here (historical ids upstream never listed). --fetch merges the upstream list
into it (upstream wins on conflicts) and never drops the hand-added rows.

Usage:
    python tools/build_attachment_aliases.py           # rewrite the table in place
    python tools/build_attachment_aliases.py --fetch   # merge latest upstream renames.csv, then rewrite
    python tools/build_attachment_aliases.py --check   # exit 0 if the table matches the CSV, 1 on drift

Only the lines between the marker lines
    -- BEGIN ATTACHMENT_ALIASES ...
    -- END ATTACHMENT_ALIASES
are replaced; the rest of the module is left untouched.
"""
import sys

import deadline_data as dd

BEGIN = "-- BEGIN ATTACHMENT_ALIASES"
END = "-- END ATTACHMENT_ALIASES"
ALIAS_LINES = 32


def write_renames(pairs):
    lines = ["old_name,new_name"] + [f"{o},{n}" for o, n in pairs]
    dd.RENAMES_CSV.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def merge_pairs(local_pairs, upstream_pairs):
    """Upstream wins on conflicts; local-only rows are kept. Returns (sorted pairs, added ids, changed ids)."""
    merged, upstream = dict(local_pairs), dict(upstream_pairs)
    added = sorted(o for o in upstream if o not in merged)
    changed = sorted(o for o in upstream if o in merged and merged[o] != upstream[o])
    merged.update(upstream)
    return sorted(merged.items(), key=lambda p: p[0].lower()), added, changed


def fetch_upstream():
    raw = dd.fetch_upstream("renames.csv")
    if raw is None:
        return
    upstream = dict(dd.parse_renames(raw.decode("utf-8-sig"), "upstream renames.csv"))
    merged, added, changed = merge_pairs(dd.load_renames(), upstream.items())
    if added or changed:
        write_renames(merged)
    print(f"Merged {len(upstream)} upstream renames: {len(added)} new, {len(changed)} retargeted, "
          f"{len(merged) - len(upstream)} kept from local-only rows.")
    for o in added:
        print(f"  new: {o} -> {upstream[o]}")
    for o in changed:
        print(f"  retargeted: {o} -> {upstream[o]}")


def render(pairs):
    return "\n".join(["local ATTACHMENT_ALIASES = {"] + dd.pack(dd.luau_entries(pairs), ALIAS_LINES) + ["}", ""])


def split_markers(text):
    if BEGIN not in text or END not in text:
        raise SystemExit(f"{BEGIN} / {END} markers not found in {dd.ATTACHMENT_DATA_LUAU.name}")
    body_start = text.index("\n", text.index(BEGIN)) + 1
    body_end = text.index(END)
    return text[:body_start], text[body_start:body_end], text[body_end:]


def main(argv):
    if "--fetch" in argv:
        fetch_upstream()
    pairs = dd.load_renames()
    path = dd.ATTACHMENT_DATA_LUAU
    head, body, tail = split_markers(path.read_text(encoding="utf-8"))
    expected = render(pairs)
    if body.replace("\r\n", "\n") == expected:
        print(f"ATTACHMENT_ALIASES in {path.name} is in sync with {dd.RENAMES_CSV.name} ({len(pairs)} renames).")
        return 0
    if "--check" in argv:
        print(f"DRIFT: ATTACHMENT_ALIASES in {path.name} does not match {dd.RENAMES_CSV.name}. Run without --check.")
        return 1
    path.write_text(head + expected + tail, encoding="utf-8", newline="\n")
    print(f"rewrote ATTACHMENT_ALIASES in {path.name} ({len(pairs)} renames).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
