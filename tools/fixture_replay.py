"""The saved attachment-printer output used as a test fixture
(tests/fixtures/attachment_stats_output.txt, from print_attachment_stats.luau's
"fixture" view), and a Python mirror of the Luau merge to check it against."""
import csv
import re
from collections import defaultdict
from pathlib import Path

from deadline_data import EXPECTED_MERGES_CSV, FIXTURE_OUTPUT, read_table, resolve

FIXTURE_ROW = re.compile(r'\["([^"]+)"\]=\{kills=(\d+),top_gun="([^"]+)",top_gun_kills=(\d+)\}')


def parse_fixture(text):
    """(attachment id, kills, top gun, top gun kills) rows from the fixture view's output."""
    return [(a, int(k), g, int(gk)) for a, k, g, gk in FIXTURE_ROW.findall(text)]


def load_fixture(path=FIXTURE_OUTPUT):
    return parse_fixture(Path(path).read_text(encoding="utf-8"))


def top_gun(guns):
    """(gun, kills) with the most kills; ties go to the alphabetically first gun, as in Luau."""
    return min(guns.items(), key=lambda g: (-g[1], g[0]))


def replay_merge(rows, aliases, weapon_aliases):
    """Mirror of the Luau aggregation over fixture rows.

    Returns {current id: {"kills", "guns": {gun: kills}, "sources": {logged ids}}}.
    """
    merged = defaultdict(lambda: {"kills": 0, "guns": defaultdict(int), "sources": set()})
    for att_id, kills, gun, _ in rows:
        bucket = merged[resolve(att_id, aliases)]
        bucket["kills"] += kills
        bucket["guns"][weapon_aliases.get(gun, gun)] += kills
        bucket["sources"].add(att_id)
    return merged


def merges_from_replay(merged):
    """{current id: (kills, top gun, top gun kills, sources)} for ids built from 2+ logged ids."""
    out = {}
    for canon, b in merged.items():
        if len(b["sources"]) > 1:
            gun, gun_kills = top_gun(b["guns"])
            out[canon] = (b["kills"], gun, gun_kills, set(b["sources"]))
    return out


def load_expected_merges(path=EXPECTED_MERGES_CSV):
    rows = read_table(path, ["canonical_id", "kills", "top_gun", "top_gun_kills", "sources"])
    return {r[0]: (int(r[1]), r[2], int(r[3]), set(r[4].split(";"))) for r in rows}


def write_expected_merges(merges, path=EXPECTED_MERGES_CSV):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["canonical_id", "kills", "top_gun", "top_gun_kills", "sources"])
        for canon in sorted(merges):
            kills, gun, gun_kills, sources = merges[canon]
            w.writerow([canon, kills, gun, gun_kills, ";".join(sorted(sources))])
