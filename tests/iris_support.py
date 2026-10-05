"""Helpers for tests that run iris_viewer.luau: the mock Iris (tests/mocks/iris.luau) and
readers for what a frame drew."""
import re

from support import ROOT

MOCK = (ROOT / "tests" / "mocks" / "iris.luau").read_text(encoding="utf-8")


def iris_mocks(new_tables=True):
    """The mock as Luau to run first: Iris 2.4+ tables (new_tables) or the older table API."""
    return MOCK.replace("__NEW_TABLES__", "true" if new_tables else "false")


def viewer_prelude(new_tables=True, extra=""):
    """Mocks, then `extra`, then iris_viewer.luau started the way the client console runs it."""
    viewer = (ROOT / "iris_viewer.luau").read_text(encoding="utf-8")
    mocks = iris_mocks(new_tables)
    return f"{mocks}\n{extra}\n;(function()\n{viewer}\nend)()\n"


def drawn(output):
    return [line.split("\t", 1)[1] for line in output.splitlines() if line.startswith("DRAWN\t")]


def grids(output):
    """{table id: [row cells]} from __dump(), rows in order, header bold tags removed."""
    tables = {}
    for line in output.splitlines():
        if line.startswith("ROW\t"):
            _, table_id, *cells = line.split("\t")
            tables.setdefault(table_id, []).append([re.sub(r"</?b>", "", c) for c in cells])
    return tables


def only_table(output, columns):
    found = [rows for rows in grids(output).values() if len(rows[0]) == columns]
    assert len(found) == 1, f"expected one {columns}-column table, found {len(found)}"
    return found[0]
