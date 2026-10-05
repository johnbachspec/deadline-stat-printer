"""Finding the Luau command-line tools (luau, luau-compile) for the tests and the Fiu check."""
import os
import shutil
from pathlib import Path

from deadline_data import ROOT


def find_luau_tool(name):
    """Path to a Luau CLI from $LUAU_BIN, luau_bin/, or PATH; None if missing."""
    dirs = [os.environ.get("LUAU_BIN"), ROOT / "luau_bin"]
    for d in dirs:
        if d:
            for candidate in (Path(d) / f"{name}.exe", Path(d) / name):
                if candidate.is_file():
                    return str(candidate)
    return shutil.which(name)
