"""Generate modules/attachment_names.luau (id -> in-game display name) from
recoil-group/deadline-balancing balancing.csv (tracked here as balancing.csv),
plus extra_display_names.csv: hand-written names for old ids that still show
up in profile stats but are gone from balancing.csv and have no current
counterpart to rename them to (see renames.csv for the ones that do).
balancing.csv wins when both name the same id.

The game reuses one name for different parts (aft_stock_cheek_piece,
aft_stock_connector and aft_stock_shoulder_piece are all "AFT"), so attachments
sharing a name get the part appended from their id: "AFT (Cheek Piece)".

print_attachment_stats.luau require()s the generated module from GitHub at
run time, so names for newly added attachments reach players as soon as the
regenerated module is pushed; ids it does not know fall back to a prettified id.

Usage:
    python tools/build_attachment_names.py           # regenerate the module from balancing.csv
    python tools/build_attachment_names.py --fetch   # download the latest balancing.csv first
    python tools/build_attachment_names.py --check   # exit 1 if the module is out of date

The table is packed several entries per line so the module takes about
NAME_LINES lines however many names there are: Deadline's Fiu VM fails to
load a function whose code spans more than 255 source lines (see
tools/check_fiu_compat.py). Non-ASCII characters are written as \\ddd byte
escapes so the module is plain ASCII.
"""
import csv
import io
import math
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "balancing.csv"
EXTRA_PATH = ROOT / "extra_display_names.csv"
LUAU_PATH = ROOT / "modules" / "attachment_names.luau"
NAME_LINES = 200
MIN_NAMES = 1000  # sanity floor for a downloaded balancing.csv

UPSTREAM_URL = "https://raw.githubusercontent.com/recoil-group/deadline-balancing/main/balancing.csv"


def parse_names(text):
    """Returns (version, updated, {name: pretty_name}) from balancing.csv text."""
    rows = list(csv.reader(io.StringIO(text)))
    header_idx = next((i for i, r in enumerate(rows[:5])
                       if "name" in [c.strip() for c in r] and "pretty_name" in [c.strip() for c in r]), None)
    if header_idx is None:
        raise ValueError("no header row with name and pretty_name columns")
    header = [c.strip() for c in rows[header_idx]]
    name_idx, pretty_idx = header.index("name"), header.index("pretty_name")
    version_row = rows[0] if header_idx > 0 else []
    version = version_row[0].strip() if len(version_row) > 0 else ""
    updated = version_row[1].strip() if len(version_row) > 1 else ""
    names = {}
    for row in rows[header_idx + 1:]:
        if len(row) > pretty_idx:
            name, pretty = row[name_idx].strip(), row[pretty_idx].strip()
            if name and pretty:
                names[name] = pretty
    return version, updated, names


def load_names(path=None):
    return parse_names(Path(path or CSV_PATH).read_text(encoding="utf-8-sig"))


def load_extra_names(path=None):
    """{name: pretty_name} from extra_display_names.csv (empty if the file is missing)."""
    path = Path(path or EXTRA_PATH)
    if not path.is_file():
        return {}
    rows = list(csv.reader(io.StringIO(path.read_text(encoding="utf-8-sig"))))
    if not rows or [c.strip() for c in rows[0][:2]] != ["name", "pretty_name"]:
        raise SystemExit(f"unexpected header in {path.name}: {rows[0] if rows else None}")
    extra = {}
    for row in rows[1:]:
        if len(row) >= 2 and row[0].strip() and row[1].strip():
            extra[row[0].strip()] = row[1].strip()
    return extra


def load_all_names():
    """balancing.csv names merged over extra_display_names.csv. Returns (version, updated, names, shadowed extras)."""
    version, updated, names = load_names()
    extra = load_extra_names()
    shadowed = sorted(k for k in extra if k in names)
    return version, updated, {**extra, **names}, shadowed


def fetch_upstream():
    """Download balancing.csv, replacing the local copy only if it parses sensibly."""
    try:
        req = urllib.request.Request(UPSTREAM_URL, headers={"User-Agent": "deadline-stat-printer"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read()
        version, _, names = parse_names(data.decode("utf-8-sig"))
    except Exception as exc:
        print(f"Warning: could not fetch {UPSTREAM_URL} ({exc}); using the local balancing.csv.")
        return False
    if len(names) < MIN_NAMES:
        print(f"Warning: upstream balancing.csv has only {len(names)} names; keeping the local copy.")
        return False
    CSV_PATH.write_bytes(data)
    print(f"Fetched balancing.csv {version} ({len(names)} names) from {UPSTREAM_URL}")
    return True


LABEL_WORDS = {
    "12oclock": "12 O'Clock", "ar9": "AR9", "bcg": "BCG", "castlenut": "Castle Nut", "dustcover": "Dust Cover",
    "gasblock": "Gas Block", "hk": "HK", "ironsight": "Iron Sight", "mlok": "M-LOK", "qd": "QD",
}


def label_word(token):
    if token in LABEL_WORDS:
        return LABEL_WORDS[token]
    if re.fullmatch(r"(gen|mk)\d+", token):
        return token.capitalize()  # gen2 -> Gen2
    if re.fullmatch(r"\d+r", token):
        return token.upper()  # 20r -> 20R (rounds)
    if re.search(r"\d", token) and re.search(r"[a-z]", token) and not re.search(r"\d(mm|gr|inch)$|\dx\d", token):
        return token.upper()  # ak74 -> AK74, scar47 -> SCAR47; 30mm, 62gr, 5.45x39 stay
    return token.capitalize()


def part_labels(ids, pretty):
    """For attachment ids sharing one display name: id -> short label for what differs (the part)."""
    token_lists = [i.split("_") for i in ids]
    shared = 0
    if len(ids) > 1:
        for column in zip(*token_lists):
            if len(set(column)) != 1:
                break
            shared += 1
    name_words = set(re.findall(r"[a-z0-9]+", pretty.lower()))
    compact_name = re.sub(r"[^a-z0-9]", "", pretty.lower())

    def tidy(tokens):
        tokens = [t for t in tokens if t not in name_words and t != "std"]
        # drop leading model tokens the name already spells differently (ak74 in "Kazarov AK-74", 416 a5 in "KF416A5")
        joined = ""
        while len(tokens) > 1 and len(joined + tokens[0]) >= 3 and joined + tokens[0].replace(".", "") in compact_name:
            joined += tokens[0].replace(".", "")
            tokens = tokens[1:]
        return tokens

    labels = {}
    for i, tokens in zip(ids, token_lists):
        rest = tokens[shared:]
        labels[i] = (tidy(rest) or rest) if rest else ["standard"]  # the plain base part of its variants
    if len(set(map(tuple, labels.values()))) < len(labels):  # tidying made two labels equal: keep them raw
        labels = {i: t[shared:] or ["standard"] for i, t in zip(ids, token_lists)}
    return {i: " ".join(label_word(t) for t in toks) for i, toks in labels.items()}


def disambiguate(names):
    """Appends "(Part)" to attachment names shared by several ids. Weapon ids (they have capitals) keep their name."""
    by_name = {}
    for item_id, pretty in names.items():
        if item_id == item_id.lower():
            by_name.setdefault(pretty, []).append(item_id)
    weapon_names = {pretty for item_id, pretty in names.items() if item_id != item_id.lower()}
    out = dict(names)
    for pretty, ids in by_name.items():
        if len(ids) > 1 or pretty in weapon_names:
            for item_id, label in part_labels(sorted(ids), pretty).items():
                out[item_id] = f"{pretty} ({label})"
    return out


def luau_string(s):
    """Double-quoted Luau literal; anything outside printable ASCII becomes \\ddd byte escapes."""
    out = []
    for b in s.encode("utf-8"):
        c = chr(b)
        if c in '"\\':
            out.append("\\" + c)
        elif 32 <= b < 127 and c not in "{}":  # braces escaped so brace-balance checks stay meaningful
            out.append(c)
        else:
            out.append(f"\\{b:03d}")  # always 3 digits so a following digit is not absorbed
    return '"' + "".join(out) + '"'


def render(version, updated, names):
    pairs = sorted(disambiguate(names).items(), key=lambda p: p[0].lower())
    per_line = max(1, math.ceil(len(pairs) / NAME_LINES))
    entries = [f"[{luau_string(k)}] = {luau_string(v)}," for k, v in pairs]
    rows = [" ".join(entries[i:i + per_line]) for i in range(0, len(entries), per_line)]
    lines = [
        "-- modules/attachment_names.luau",
        "-- GENERATED by tools/build_attachment_names.py from recoil-group/deadline-balancing",
        "-- balancing.csv and extra_display_names.csv - do not edit by hand. Maps item ids (the",
        "-- \"name\" column, attachments and weapons) to their in-game display names (\"pretty_name\").",
        "-- Entries are packed several per line on purpose: Deadline's Fiu VM fails to load any",
        "-- function spanning more than 255 source lines (see tools/check_fiu_compat.py).",
        "",
        "local NAMES = {",
    ] + ["    " + r for r in rows] + [
        "}",
        "",
        "return {",
        f"    VERSION = {luau_string(version)},",
        f"    UPDATED = {luau_string(updated)},",
        f"    COUNT = {len(pairs)},",
        "    NAMES = NAMES,",
        "}",
        "",
    ]
    return "\n".join(lines)


def main(argv=None):
    if argv is None:
        argv = sys.argv
    if "--fetch" in argv:
        fetch_upstream()
    version, updated, names, shadowed = load_all_names()
    print(f"{CSV_PATH.name} {version} + {EXTRA_PATH.name}: {len(names)} display names.")
    for k in shadowed:
        print(f"  note: balancing.csv now names {k}; its row in {EXTRA_PATH.name} can be removed.")
    expected = render(version, updated, names)
    current = LUAU_PATH.read_text(encoding="utf-8") if LUAU_PATH.is_file() else None
    if current is not None and current.replace("\r\n", "\n") == expected:
        print(f"{LUAU_PATH.name} is in sync with {CSV_PATH.name}.")
        return 0
    if "--check" in argv:
        print(f"DRIFT: {LUAU_PATH.name} does not match {CSV_PATH.name}. Run without --check to regenerate.")
        return 1
    LUAU_PATH.write_text(expected, encoding="utf-8", newline="\n")
    print(f"wrote {LUAU_PATH.relative_to(ROOT)} ({len(names)} names).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
