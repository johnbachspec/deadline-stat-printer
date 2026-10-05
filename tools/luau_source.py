"""Reading tables out of Luau source files and writing generated Luau, for the build
tools and tests. Deadline's Fiu VM cannot load a function spanning more than 255
source lines (see check_fiu_compat.py), so generated tables are packed several
entries per line."""
import math
import re
from pathlib import Path


def luau_table_body(path, name):
    """The text between `<name> = {` and its closing `}` line in a Luau file."""
    match = re.search(re.escape(name) + r" = \{(.*?)\n\}", Path(path).read_text(encoding="utf-8"), re.S)
    if not match:
        raise LookupError(f"{name} table not found in {Path(path).name}")
    return match.group(1)


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
    """Joins entries onto at most `max_lines` lines, so a big generated table stays loadable."""
    per_line = max(1, math.ceil(len(entries) / max_lines))
    return [indent + " ".join(entries[i:i + per_line]) for i in range(0, len(entries), per_line)]
