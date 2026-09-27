"""Validate the runtime-only BEAUTIFIED_NAMES setup in
modules/attachment_formatter.luau from deadline-balancing balancing.csv
(tracked in this repo as balancing.csv).

Usage:
    python tools/build_attachment_names.py           # report available names
    python tools/build_attachment_names.py --fetch   # download latest balancing.csv
    python tools/build_attachment_names.py --check   # validate no large table is embedded
"""
import csv
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "balancing.csv"
LUAU_PATH = ROOT / "modules" / "attachment_formatter.luau"
BEGIN = "-- BEGIN BEAUTIFIED_NAMES"
END = "-- END BEAUTIFIED_NAMES"

UPSTREAM_URLS = [
    "https://raw.githubusercontent.com/recoil-studio/deadline-balancing/main/balancing.csv",
    "https://raw.githubusercontent.com/recoil-group/deadline-balancing/main/balancing.csv",
]


def fetch_upstream():
    """Download the latest balancing.csv from upstream repository."""
    for url in UPSTREAM_URLS:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = resp.read()
                if len(data) > 50000:
                    CSV_PATH.write_bytes(data)
                    print(f"Fetched latest balancing.csv from {url} ({len(data)} bytes)")
                    return True
        except Exception:
            continue
    print("Warning: Failed to fetch upstream balancing.csv, using existing local copy.")
    return False


def load_names(path=None):
    """Read balancing.csv and extract (name, pretty_name) pairs sorted by name."""
    if path is None:
        path = CSV_PATH
    with open(path, encoding="utf-8", errors="replace") as f:
        reader = csv.reader(f)
        header_found = False
        name_idx, pretty_idx = 2, 3
        pairs = {}
        for row in reader:
            if not header_found:
                for idx, col in enumerate(row):
                    if col.strip() == "name":
                        name_idx = idx
                    elif col.strip() == "pretty_name":
                        pretty_idx = idx
                if "name" in [c.strip() for c in row]:
                    header_found = True
            else:
                if len(row) > max(name_idx, pretty_idx):
                    tech = row[name_idx].strip()
                    pretty = row[pretty_idx].strip()
                    if tech and pretty and tech != "name":
                        pairs[tech] = pretty

    sorted_pairs = sorted(pairs.items(), key=lambda p: p[0].lower())
    return sorted_pairs


def escape_luau_string(s):
    """Escape backslashes and double quotes for Luau double-quoted literal."""
    # Escape backslashes first, then double quotes
    s = s.replace("\\", "\\\\")
    s = s.replace('"', '\\"')
    return s


def render(pairs):
    lines = []
    for tech, pretty in pairs:
        esc_pretty = escape_luau_string(pretty)
        lines.append(f'    ["{tech}"] = "{esc_pretty}",')
    return "\n".join(lines)


def split_markers(text):
    if BEGIN not in text:
        raise SystemExit(f"BEGIN marker not found in {LUAU_PATH.name}")
    if END not in text:
        raise SystemExit(f"END marker not found in {LUAU_PATH.name}")
    ctor = "AttachmentFormatter.BEAUTIFIED_NAMES = {"
    pos = text.find(ctor)
    if pos == -1 or pos < text.index(BEGIN):
        raise SystemExit("table constructor not found after BEGIN marker")
    head_end = text.index("\n", pos) + 1
    end_pos = text.index(END)
    close_start = text.rfind("\n}", 0, end_pos)
    if close_start == -1:
        raise SystemExit('closing "}" line not found before END marker')
    tail_start = close_start + 1
    return text[:head_end], text[tail_start:]


def sync_table(path, pairs, check_only=False):
    text = path.read_text(encoding="utf-8")
    runtime_marker = "-- BEGIN BEAUTIFIED_NAMES (runtime loaded; intentionally no embedded table)"
    empty_table = "AttachmentFormatter.BEAUTIFIED_NAMES = {}"
    if runtime_marker in text and empty_table in text and "[\"kalis_scalar_std_bcg\"]" not in text:
        print(f"{path.name}: runtime name loading configured; {len(pairs)} names available in balancing.csv.")
        return 0
    print(f"ERROR: {path.name} must use the runtime-only name table to stay Fiu-compatible.")
    return 1


def main(argv=None):
    if argv is None:
        argv = sys.argv
    if "--fetch" in argv:
        fetch_upstream()
    check_only = "--check" in argv
    pairs = load_names()
    print(f"{CSV_PATH.name}: loaded {len(pairs)} unique beautified attachment names.")
    rc = sync_table(LUAU_PATH, pairs, check_only)
    return rc


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
