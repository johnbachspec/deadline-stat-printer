"""Check that Luau scripts load in Deadline's in-game Fiu VM.

The game's console runs an old Fiu build (rce-incorporated/Fiu 471b9da) whose
line-info decoder reads one entry past the end of `abslineinfo` for the last
instruction of any function whose instruction count is a multiple of
2^linegaplog2. The script then dies while loading, before any of it runs:

    ReplicatedStorage.data.luau_in_luau.Fiu:494: attempt to perform arithmetic (add) on nil and number

The Luau compiler only lowers linegaplog2 below its maximum (24) when a
function's code spans more than 255 source lines, so this check requires every
function to stay within 255 lines. That holds whatever exact instruction
counts the game's own compiler produces; an instruction count that merely
happens to avoid a multiple does not.

Long `[[...]]` strings and big comment blocks inside a function count toward
the span, and so does a long table constructor assigned to a field
(`M.X = { ... }` stores back on its first line), so generated data tables are
packed several entries per line.

Usage:
    python tools/check_fiu_compat.py              # files the game loads: root scripts + modules they load
    python tools/check_fiu_compat.py --all        # every .luau in the repo root and modules/
    python tools/check_fiu_compat.py FILE...      # specific files
    python tools/check_fiu_compat.py -v           # also list passing functions

luau-compile is taken from $LUAU_BIN, then luau_bin/, then PATH.
"""
import re
import struct
import subprocess
import sys
from pathlib import Path

import deadline_data as dd

ROOT = dd.ROOT
MAX_LINEGAPLOG2 = 24
MAX_SPAN = 255
MAX_BYTECODE_VERSION = 6  # the format read_protos understands
PINNED_LUAU = "0.712"     # the last Luau release that writes it


def game_loaded_files():
    """Entry scripts in the repo root plus every module they load (load_module("x") or a modules/x.luau URL)."""
    scripts = sorted(ROOT.glob("*.luau"))
    names = set()
    for script in scripts:
        text = script.read_text(encoding="utf-8")
        names.update(re.findall(r'load_module\("(\w+)"\)', text))
        names.update(re.findall(r'/modules/(\w+)\.luau', text))
    return scripts + sorted(p for p in (ROOT / "modules").glob("*.luau") if p.stem in names)


def find_compiler():
    return dd.find_luau_tool("luau-compile")


class Reader:
    def __init__(self, data):
        self.data, self.pos = data, 0

    def byte(self):
        b = self.data[self.pos]
        self.pos += 1
        return b

    def int32(self):
        (v,) = struct.unpack_from("<i", self.data, self.pos)
        self.pos += 4
        return v

    def varint(self):
        result = shift = 0
        while True:
            b = self.byte()
            result |= (b & 127) << shift
            shift += 7
            if not b & 128:
                return result

    def skip(self, n):
        self.pos += n


def read_protos(bytecode):
    """Yields one dict per function: name, linedefined, sizecode, linegaplog2, first/last line."""
    r = Reader(bytecode)
    version = r.byte()
    if version == 0:
        raise ValueError(bytecode[1:].decode("utf-8", "replace"))
    if version > MAX_BYTECODE_VERSION:
        raise ValueError(f"luau-compile wrote bytecode version {version}, but this checker reads versions up to "
                         f"{MAX_BYTECODE_VERSION}. Use Luau {PINNED_LUAU} or older (the release CI pins in "
                         ".github/actions/setup-luau/action.yml); luau 0.713 and later write newer versions.")
    types_version = r.byte() if version >= 4 else 0
    strings = [None]
    for _ in range(r.varint()):
        n = r.varint()
        strings.append(bytecode[r.pos:r.pos + n].decode("utf-8", "replace"))
        r.skip(n)
    if types_version == 3:
        while r.byte() != 0:
            r.varint()

    protos = []
    for _ in range(r.varint()):
        r.skip(4)  # maxstacksize, numparams, nups, is_vararg
        if version >= 4:
            r.byte()  # flags
            r.skip(r.varint())  # type info
        sizecode = r.varint()
        r.skip(4 * sizecode)
        for _ in range(r.varint()):
            kind = r.byte()
            if kind == 1:
                r.skip(1)
            elif kind == 2:
                r.skip(8)
            elif kind in (3, 6):
                r.varint()
            elif kind == 4:
                r.skip(4)
            elif kind == 5:
                for _ in range(r.varint()):
                    r.varint()
            elif kind == 7:
                r.skip(16)
            elif kind == 8:
                for _ in range(r.varint()):
                    r.varint()
                    r.skip(4)
            elif kind != 0:
                raise ValueError(f"unknown constant type {kind}")
        for _ in range(r.varint()):
            r.varint()  # child proto ids
        proto = {"linedefined": r.varint(), "name": strings[r.varint()], "sizecode": sizecode,
                 "linegaplog2": None, "first": None, "last": None}
        if r.byte():
            lg2 = r.byte()
            intervals = ((sizecode - 1) >> lg2) + 1
            offsets, last = [], 0
            for _ in range(sizecode):
                last = (last + r.byte()) & 0xFF
                offsets.append(last)
            bases, line = [], 0
            for _ in range(intervals):
                line += r.int32()
                bases.append(line)
            lines = [bases[pc >> lg2] + offsets[pc] for pc in range(sizecode)]
            proto.update(linegaplog2=lg2, first=min(lines), last=max(lines))
        if r.byte():  # debug info
            for _ in range(r.varint()):
                r.varint()
                r.varint()
                r.varint()
                r.byte()
            for _ in range(r.varint()):
                r.varint()
        protos.append(proto)
    main_id = r.varint()
    for i, proto in enumerate(protos):
        if i == main_id:
            proto["name"] = "main chunk"
        elif proto["name"] is None:
            proto["name"] = "anonymous function"
    return protos


def check_file(compiler, path, verbose=False):
    """Returns a list of problem strings for one file."""
    result = subprocess.run([compiler, "--binary", str(path)], capture_output=True)
    if result.returncode != 0:
        return [f"compile error: {result.stderr.decode('utf-8', 'replace').strip()}"]
    problems = []
    for p in read_protos(result.stdout):
        if p["linegaplog2"] is None:
            continue
        label = f"{p['name']} (lines {p['first']}-{p['last']}, {p['sizecode']} instructions)"
        if p["linegaplog2"] < MAX_LINEGAPLOG2:
            span = p["last"] - p["first"]
            crash = p["sizecode"] % (1 << p["linegaplog2"]) == 0
            problems.append(f"{label} spans {span} lines (max {MAX_SPAN})"
                            + ("; crashes Fiu with this compiler's instruction count" if crash else
                               "; loads only if the game's compiler emits a lucky instruction count"))
        elif verbose:
            print(f"  ok  {label}")
    return problems


def main(argv):
    verbose = "-v" in argv
    files = [Path(a) for a in argv[1:] if a not in ("-v", "--all")]
    if not files and "--all" in argv:
        files = sorted(ROOT.glob("*.luau")) + sorted((ROOT / "modules").glob("*.luau"))
    elif not files:
        files = game_loaded_files()
        skipped = sorted(p.name for p in (ROOT / "modules").glob("*.luau") if p not in files)
        if skipped:
            print(f"not loaded by any entry script, skipped (use --all): {', '.join(skipped)}")
    compiler = find_compiler()
    if not compiler:
        print("luau-compile not found: set LUAU_BIN to its folder, or put it in luau_bin/ or on PATH")
        return 2
    failed = 0
    for path in files:
        try:
            shown = path.resolve().relative_to(ROOT)
        except ValueError:
            shown = path
        try:
            problems = check_file(compiler, path, verbose)
        except ValueError as error:  # bytecode this checker can't read, e.g. from a newer Luau
            print(f"cannot check {shown}: {error}")
            return 2
        print(f"{'FAIL' if problems else 'ok  '} {shown}")
        for problem in problems:
            print(f"       {problem}")
        failed += bool(problems)
    if failed:
        print(f"\n{failed} file(s) would crash or risk crashing Deadline's Fiu VM on load.")
        return 1
    print(f"\nAll {len(files)} file(s) are safe for Deadline's Fiu VM.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
