"""Shared paths and helpers for the build tools and tests.

Everything that reads the repo's data files (renames, the saved printer output
used as a test fixture, weapon aliases) or writes generated Luau goes through
here, so the tools and the tests agree on formats.
"""
import csv
import io
import math
import os
import re
import shutil
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
MODULES = ROOT / "modules"
FIXTURES = ROOT / "tests" / "fixtures"

RENAMES_CSV = DATA / "renames.csv"
BALANCING_CSV = DATA / "balancing.csv"
EXTRA_NAMES_CSV = DATA / "extra_display_names.csv"
GROUPS_CSV = DATA / "attachment_groups.csv"

ATTACHMENT_DATA_LUAU = MODULES / "attachment_data.luau"
ATTACHMENT_NAMES_LUAU = MODULES / "attachment_names.luau"
WEAPON_DATA_LUAU = MODULES / "weapon_data.luau"

FIXTURE_OUTPUT = FIXTURES / "attachment_stats_output.txt"
EXPECTED_MERGES_CSV = FIXTURES / "expected_merges.csv"

UPSTREAM_BASE = "https://raw.githubusercontent.com/recoil-group/deadline-balancing/main/"


# --- CSV -------------------------------------------------------------------

def read_table(path, header):
    """Rows of a CSV whose first row must equal `header`; blank rows are skipped, cells stripped."""
    path = Path(path)
    return parse_table(path.read_text(encoding="utf-8-sig"), header, path.name)


def parse_table(text, header, name):
    rows = list(csv.reader(io.StringIO(text)))
    if not rows or [c.strip() for c in rows[0][:len(header)]] != list(header):
        raise SystemExit(f"unexpected header in {name}: {rows[0] if rows else None} (expected {list(header)})")
    return [[c.strip() for c in r] for r in rows[1:] if any(c.strip() for c in r)]


# --- renames ---------------------------------------------------------------

def parse_renames(text, name="renames.csv"):
    """Validated (old, new) pairs sorted by old id."""
    rows = parse_table(text, ["old_name", "new_name"], name)
    pairs = [(r[0], r[1]) for r in rows if len(r) == 2 and r[0] and r[1]]
    if len(pairs) != len(rows):
        raise SystemExit(f"malformed (non old,new) rows in {name}")
    dupes = sorted(k for k, c in Counter(o for o, _ in pairs).items() if c > 1)
    if dupes:
        raise SystemExit(f"duplicate old_name entries in {name}: {dupes}")
    for o, n in pairs:
        if any(c in o + n for c in '"\\'):
            raise SystemExit(f"id needs Luau escaping: {o!r} -> {n!r}")
    return sorted(pairs, key=lambda p: p[0].lower())


def load_renames(path=RENAMES_CSV):
    path = Path(path)
    return parse_renames(path.read_text(encoding="utf-8-sig"), path.name)


def resolve(item_id, aliases):
    """Follows the rename chain to the current id (cycle-safe), like AttachmentData.resolve in Luau."""
    seen = set()
    while item_id in aliases and item_id not in seen:
        seen.add(item_id)
        item_id = aliases[item_id]
    return item_id


def load_weapon_aliases(path=WEAPON_DATA_LUAU):
    """Legacy gun id -> current gun id, read from WeaponData.ALIASES in modules/weapon_data.luau."""
    return dict(re.findall(r'(\w+)\s*=\s*"([^"]*)"', luau_table_body(path, "WeaponData.ALIASES")))


def luau_table_body(path, name):
    match = re.search(re.escape(name) + r" = \{(.*?)\n\}", Path(path).read_text(encoding="utf-8"), re.S)
    if not match:
        raise SystemExit(f"{name} table not found in {Path(path).name}")
    return match.group(1)


# --- saved printer output (test fixture) -----------------------------------

FIXTURE_ROW = re.compile(r'\["([^"]+)"\]=\{kills=(\d+),top_gun="([^"]+)",top_gun_kills=(\d+)\}')


def parse_fixture(text):
    """(attachment id, kills, top gun, top gun kills) rows from print_attachment_stats_delimited output."""
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


# --- generated Luau --------------------------------------------------------

def luau_string(s):
    """Double-quoted Luau literal; anything outside printable ASCII becomes 3-digit \\ddd byte escapes."""
    out = []
    for b in s.encode("utf-8"):
        c = chr(b)
        if c in '"\\':
            out.append("\\" + c)
        elif 32 <= b < 127 and c not in "{}":  # braces escaped so the file only has structural braces
            out.append(c)
        else:
            out.append(f"\\{b:03d}")  # always 3 digits so a following digit is not absorbed
    return '"' + "".join(out) + '"'


def luau_entries(mapping):
    return [f"[{luau_string(k)}] = {luau_string(v)}," for k, v in mapping]


def pack(entries, max_lines, indent="    "):
    """Joins entries onto at most `max_lines` lines. Deadline's Fiu VM cannot load a
    function spanning more than 255 source lines, so big generated tables are packed."""
    per_line = max(1, math.ceil(len(entries) / max_lines))
    return [indent + " ".join(entries[i:i + per_line]) for i in range(0, len(entries), per_line)]


# --- external programs and downloads ---------------------------------------

def find_luau_tool(name):
    """Path to a Luau CLI (luau, luau-compile) from $LUAU_BIN, luau_bin/, or PATH; None if missing."""
    dirs = [os.environ.get("LUAU_BIN"), ROOT / "luau_bin"]
    for d in dirs:
        if d:
            for candidate in (Path(d) / f"{name}.exe", Path(d) / name):
                if candidate.is_file():
                    return str(candidate)
    return shutil.which(name)


def fetch_upstream(filename):
    """Raw bytes of a deadline-balancing file, or None (with a warning) if it cannot be downloaded."""
    url = UPSTREAM_BASE + filename
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "deadline-stat-printer"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read()
    except Exception as exc:
        print(f"Warning: could not fetch {url} ({exc}); using the local copy.")
        return None
