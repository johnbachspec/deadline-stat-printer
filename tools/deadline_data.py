"""The repo's data files, for the build tools and tests: their paths, CSV tables, the
rename list, the weapon aliases, and downloads from recoil-group/deadline-balancing.

Related modules: fixture_replay.py (the saved printer output the tests replay),
luau_source.py (reading and writing Luau tables), luau_cli.py (finding luau and
luau-compile).
"""
import csv
import io
import re
import urllib.request
from collections import Counter
from pathlib import Path

from luau_source import luau_table_body

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


def final_renames(pairs):
    """{old: final new id}, with chains (A -> B, B -> C) collapsed; ValueError if a chain loops."""
    direct = dict(pairs)
    final = {}
    for old in direct:
        chain = [old]
        while chain[-1] in direct:
            chain.append(direct[chain[-1]])
            if chain[-1] in chain[:-1]:
                raise ValueError(f"rename chain loops: {' -> '.join(chain)}")
        final[old] = chain[-1]
    return final


def load_weapon_aliases(path=WEAPON_DATA_LUAU):
    """Legacy gun id -> current gun id, read from WeaponData.ALIASES in modules/weapon_data.luau."""
    return dict(re.findall(r'(\w+)\s*=\s*"([^"]*)"', luau_table_body(path, "WeaponData.ALIASES")))


# --- downloads -------------------------------------------------------------

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
