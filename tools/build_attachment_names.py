"""Generate modules/attachment_names.luau: attachment id -> in-game display name,
plus the GROUPS table of products made of several pieces.

Sources:
  data/balancing.csv           recoil-group/deadline-balancing item sheet ("name" -> "pretty_name")
  data/extra_display_names.csv hand-written names for old ids that still show up in
                               profile stats but are gone from balancing.csv and have no
                               current counterpart to rename them to (see data/renames.csv
                               for the ones that do). balancing.csv wins when both name an id.
  data/attachment_groups.csv   pieces always equipped together (the AFT SC stock is five);
                               the printer shows one row per product.

Only attachments are written. Guns are shown with the stat panel's names from
modules/weapon_data.luau, so both panels agree.

The game reuses one name for different parts (aft_stock_cheek_piece,
aft_stock_connector and aft_stock_shoulder_piece are all "AFT"), so attachments
sharing a name, with each other or with a gun, get the part appended from
their id: "AFT (Cheek Piece)".

print_attachment_stats.luau require()s the generated module from GitHub at
run time, so names for newly added attachments reach players as soon as the
regenerated module is pushed; ids it does not know fall back to a prettified id.

Usage:
    python tools/build_attachment_names.py           # regenerate the module
    python tools/build_attachment_names.py --fetch   # download the latest balancing.csv first
    python tools/build_attachment_names.py --check   # exit 1 if the module is out of date
"""
import csv
import io
import re
import sys

import deadline_data as dd
import luau_source as luau

NAME_LINES = 200
MIN_NAMES = 1000  # sanity floor for a downloaded balancing.csv

LABEL_WORDS = {
    "12oclock": "12 O'Clock", "ar9": "AR9", "bcg": "BCG", "castlenut": "Castle Nut", "dustcover": "Dust Cover",
    "gasblock": "Gas Block", "hk": "HK", "ironsight": "Iron Sight", "mlok": "M-LOK", "qd": "QD",
}


def is_weapon(item_id):
    """Gun and tool ids have capitals (SCARH, AK_762); attachment ids are lower case."""
    return item_id != item_id.lower()


# --- sources -----------------------------------------------------------------

def parse_names(text):
    """Returns (version, updated, {name: pretty_name}) from balancing.csv text."""
    rows = list(csv.reader(io.StringIO(text)))
    header_idx = next((i for i, r in enumerate(rows[:5])
                       if {"name", "pretty_name"} <= {c.strip() for c in r}), None)
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


def load_names():
    return parse_names(dd.BALANCING_CSV.read_text(encoding="utf-8-sig"))


def load_extra_names():
    if not dd.EXTRA_NAMES_CSV.is_file():
        return {}
    return {r[0]: r[1] for r in dd.read_table(dd.EXTRA_NAMES_CSV, ["name", "pretty_name"]) if len(r) >= 2 and r[1]}


def load_all_names():
    """balancing.csv names merged over extra_display_names.csv. Returns (version, updated, names, shadowed extras)."""
    version, updated, names = load_names()
    extra = load_extra_names()
    shadowed = sorted(k for k in extra if k in names)
    return version, updated, {**extra, **names}, shadowed


def load_groups(names, path=dd.GROUPS_CSV):
    """{piece id: product name} from attachment_groups.csv, validated against the known ids."""
    if not path.is_file():
        return {}
    renamed = dict(dd.load_renames())  # the printer groups ids after renames
    groups, problems = {}, []
    for row in dd.read_table(path, ["id", "group"]):
        piece, product = row[0], row[1] if len(row) > 1 else ""
        if piece in renamed:
            problems.append(f"{piece} is renamed to {renamed[piece]}; list the current id")
        elif piece not in names or is_weapon(piece):
            problems.append(f"{piece} is not a known attachment id")
        elif piece in groups:
            problems.append(f"{piece} is listed twice")
        groups[piece] = product
    for product in sorted(set(groups.values())):
        if list(groups.values()).count(product) < 2:
            problems.append(f"group {product!r} has only one piece")
    if problems:
        raise SystemExit(f"{path.name}:\n  " + "\n  ".join(problems))
    return groups


def fetch_upstream():
    """Download balancing.csv, replacing the local copy only if it parses sensibly."""
    raw = dd.fetch_upstream("balancing.csv")
    if raw is None:
        return
    try:
        version, _, names = parse_names(raw.decode("utf-8-sig"))
    except ValueError as exc:
        print(f"Warning: upstream balancing.csv did not parse ({exc}); keeping the local copy.")
        return
    if len(names) < MIN_NAMES:
        print(f"Warning: upstream balancing.csv has only {len(names)} names; keeping the local copy.")
        return
    dd.BALANCING_CSV.write_bytes(raw)
    print(f"Fetched balancing.csv {version} ({len(names)} names).")


# --- telling apart parts that share a name -------------------------------------

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


def attachment_display_names(names):
    """Attachment id -> printed name, with "(Part)" appended where a name is shared."""
    by_name = {}
    for item_id, pretty in names.items():
        if not is_weapon(item_id):
            by_name.setdefault(pretty, []).append(item_id)
    weapon_names = {pretty for item_id, pretty in names.items() if is_weapon(item_id)}
    out = {}
    for pretty, ids in by_name.items():
        if len(ids) > 1 or pretty in weapon_names:
            out.update({i: f"{pretty} ({label})" for i, label in part_labels(sorted(ids), pretty).items()})
        else:
            out[ids[0]] = pretty
    return out


# --- output ------------------------------------------------------------------

def render(version, updated, names, groups):
    shown = sorted(attachment_display_names(names).items(), key=lambda p: p[0].lower())
    lines = [
        "-- modules/attachment_names.luau",
        "-- GENERATED by tools/build_attachment_names.py from data/balancing.csv,",
        "-- data/extra_display_names.csv and data/attachment_groups.csv - do not edit by hand.",
        "-- Entries are packed several per line on purpose: Deadline's Fiu VM fails to load any",
        "-- function spanning more than 255 source lines (see tools/check_fiu_compat.py).",
        "",
        "-- attachment id -> in-game name",
        "local NAMES = {",
    ] + luau.pack(luau.luau_entries(shown), NAME_LINES) + [
        "}",
        "",
        "-- piece id -> product, for products made of pieces always equipped together",
        "local GROUPS = {",
    ] + luau.pack(luau.luau_entries(sorted(groups.items())), 8) + [
        "}",
        "",
        "return {",
        f"    VERSION = {luau.luau_string(version)},",
        f"    UPDATED = {luau.luau_string(updated)},",
        f"    COUNT = {len(shown)},",
        "    NAMES = NAMES,",
        "    GROUPS = GROUPS,",
        "}",
        "",
    ]
    return "\n".join(lines)


def main(argv):
    if "--fetch" in argv:
        fetch_upstream()
    version, updated, names, shadowed = load_all_names()
    for k in shadowed:
        print(f"  note: balancing.csv now names {k}; its row in {dd.EXTRA_NAMES_CSV.name} can be removed.")
    groups = load_groups(names)
    expected = render(version, updated, names, groups)
    path = dd.ATTACHMENT_NAMES_LUAU
    summary = f"balancing.csv {version}, {len(groups)} pieces in {len(set(groups.values()))} groups"
    current = path.read_text(encoding="utf-8").replace("\r\n", "\n") if path.is_file() else None
    if current == expected:
        print(f"{path.name} is in sync ({summary}).")
        return 0
    if "--check" in argv:
        print(f"DRIFT: {path.name} does not match its sources. Run without --check to regenerate.")
        return 1
    path.write_text(expected, encoding="utf-8", newline="\n")
    print(f"wrote {path.relative_to(dd.ROOT)} ({summary}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
