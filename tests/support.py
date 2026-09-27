"""Shared test setup: makes tools/ importable and runs the console scripts under
the luau CLI with the game console mocked (players, shared, and a require that
serves modules/*.luau for the GitHub URLs the scripts load)."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import deadline_data as dd  # noqa: E402

LUAU = dd.find_luau_tool("luau")
LUAU_COMPILE = dd.find_luau_tool("luau-compile")

needs_luau = unittest.skipUnless(LUAU, "luau CLI not found (set LUAU_BIN or add it to luau_bin/)")
needs_luau_compile = unittest.skipUnless(LUAU_COMPILE, "luau-compile not found (set LUAU_BIN or add it to luau_bin/)")


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def players_lua(profile_lua, name="Tester"):
    """A console `players` global with a bot and one human whose profile is `profile_lua`."""
    return (
        f"(function() local p = {{ name = {lua_string(name)}, is_bot = function() return false end,\n"
        f"  get_profile_stats = function() return {profile_lua} end }}\n"
        "return { get_all = function() return { { name = 'Bot', is_bot = function() return true end }, p } end,\n"
        "         get = function(n) if n == p.name then return p end return nil end } end)()"
    )


def fixture_profile_lua(rows):
    """Profile whose attachment kills reproduce saved printer output: each row's kills on its top gun."""
    guns = {}
    for att_id, kills, gun, _ in rows:
        guns.setdefault(gun, []).append(f"[{lua_string(att_id)}] = {{ kills = {kills} }}")
    body = ",\n".join(f"[{lua_string(g)}] = {{ attachment_stats = {{ {', '.join(v)} }} }}" for g, v in guns.items())
    return "{ weapon = {\n" + body + "\n} }"


def run_script(script, players, after="", missing_modules=()):
    """Runs a console script (path relative to the repo root) and returns its printed output.

    `after` is Luau run once the script has finished (e.g. shared.print_x(...) calls).
    Modules named in `missing_modules` fail to load, like a failed download.
    """
    parts = ["local __module_sources = {}\n"]
    for path in sorted(dd.MODULES.glob("*.luau")):
        if path.stem not in missing_modules:
            parts.append(f"__module_sources[{lua_string(path.stem)}] = function()\n{path.read_text(encoding='utf-8')}\nend\n")
    parts.append(
        "local __loaded = {}\n"
        "local require = function(url)\n"
        "  local name = string.match(url, '/modules/([%w_]+)%.luau$')\n"
        "  if not (name and __module_sources[name]) then error('HTTP 404 (mock) ' .. tostring(url)) end\n"
        "  if __loaded[name] == nil then __loaded[name] = __module_sources[name]() end\n"
        "  return __loaded[name]\n"
        "end\n"
        f"local players = {players}\n"
        "local shared = {}\n"
        "local script = nil\n"
        "local __result = (function()\n"
        + (ROOT / script).read_text(encoding="utf-8") +
        "\nend)()\n" + after + "\n")
    with tempfile.TemporaryDirectory() as tmp:
        harness = Path(tmp) / "harness.luau"
        harness.write_text("".join(parts), encoding="utf-8", newline="\n")
        result = subprocess.run([LUAU, str(harness)], capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        raise AssertionError(f"{script} failed:\n{result.stdout[-2000:]}\n{result.stderr[-2000:]}")
    return result.stdout
