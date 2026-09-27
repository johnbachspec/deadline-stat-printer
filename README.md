# deadline-stat-printer

Prints detailed account and per-weapon statistics for Deadline (Roblox) players from the in-game Luau server console, as console text or as in-game [Iris windows](#iris-windows). Original script and inspiration from [@LegitACarWithAGun](https://github.com/LegitACarWithAGun); modular version by [@johnbachspec](https://github.com/johnbachspec); contribution by [@refact0r](https://github.com/refact0r) and [GabeeCoding](https://github.com/GabeeCoding)

## How to Use

1. Open a private Deadline server. Press tilde (`` ` ``) to open the Luau console and switch to **Luau Server Console**.
2. Run:

   ```lua
   require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/print_player_stats.luau")
   ```

   Or paste the contents of `print_player_stats.luau` into the console. Edit the config block at the top first if you want a filter:

   ```lua
   local TARGET_WEAPON = "" -- one weapon only: raw id ("AK_762"), legacy id ("AKMN"), or display name ("AKM")
   local FILTER_TYPE   = "" -- e.g. "556", "SMG", "RPG"; "" = everything except Unknown
   local SORT_BY       = "KILLS" -- "KILLS" or "TYPE"
   ```

3. A report prints for every human player currently in the server. Output appears in the Luau console itself (not the Roblox Studio Output window); the console is monospaced, but the 166-column grid will wrap if the console window is narrow. To see it in a resizable window instead, see [Iris Windows](#iris-windows).

After the script has run once, `shared.print_player_stats` stays available in the console for the rest of the session:

```lua
shared.print_player_stats(players.get("SomeName"))            -- default config
shared.print_player_stats(players.get("SomeName"), "SMG")     -- override FILTER_TYPE for this call
shared.print_player_stats(players.get("SomeName"), nil, "AKM") -- override TARGET_WEAPON for this call
shared.print_player_stats(players.get("SomeName"), { filter = "SMG", sort_by = "TYPE" }) -- options table
```

### Iris Windows

The reports can also open as windows built with [Iris](https://sirmallard.github.io/Iris/), the UI library Deadline includes. Iris only runs in the **client** console, but profile stats only exist on the server, so this uses both consoles:

1. In the **Luau client console** (the tab that says "This tab runs code for the client"), paste the contents of `iris_viewer.luau` and run it. A small "Stat printer" window opens.
2. In the server console, run `print_player_stats.luau`, `print_attachment_stats.luau` or `cap_announcer.luau` as usual.

Each report opens in its own window, with collapsible sections. Long tables get a filter box and Prev / Next pages. The **Refresh** button asks the server for a fresh copy. The "Stat printer" window lists every report received, and its **Show** button reopens a window you closed. Running `iris_viewer.luau` again reopens them all.

The server sends each report to every human in the server, but only players running the viewer see it. By default the scripts still print to the console as well. Set `SHOW_IN = "iris"` at the top of `print_player_stats.luau` or `print_attachment_stats.luau` for windows only, or `"console"` for no windows. `explore_console.luau` and `print_attachment_stats_delimited.luau` stay console-only, because their output is meant to be copied.

`iris_viewer.luau` works with both table styles Iris has used (before and after Iris 2.4), and its ready message says which one it found. It has to stay under 255 lines because it is pasted in one piece (see [the Fiu limit](#the-fiu-255-line-limit)).

### Attachment Stats

To view aggregated attachment statistics across all weapons, run (or paste `print_attachment_stats.luau`; either way it downloads its modules from this repo, like the stat panel):

```lua
require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/print_attachment_stats.luau")
```

Attachments are listed by their in-game names; the "Top Gun" column uses the same gun names as the weapon table. The game gives some different parts the same name (three parts are all just "AFT"), so those get the part in brackets, taken from the item id: `AFT (Cheek Piece)`, `AFT (Connector)`, `AFT (Shoulder Piece)`. Products the game tracks as several pieces that are always equipped together are listed in `data/attachment_groups.csv` and print as one row, e.g. `AFT Stock (3 pieces)`; the row shows the kills once, since every piece is credited with the same kills. Leave a product out if one of its pieces can be swapped for an add-on (the Veles PT-1 takes a Tailhook adapter).

Names come from `modules/attachment_names.luau` (generated from deadline-balancing `balancing.csv`). An attachment too new to be in that file yet prints as a prettified id, and if that module fails to download the whole list does; the header line says which (`-- names: deadline-balancing 0.25.4`). Set `LOAD_NAMES = false` at the top of the script to skip that download.

After running once, `shared.print_attachment_stats` remains available:

```lua
shared.print_attachment_stats()                        -- the first human player found
shared.print_attachment_stats(players.get("SomeName")) -- a specific player
shared.print_attachment_stats("SomeName")              -- by name
```

### Capture Announcer

`cap_announcer.luau` tells everyone on the server who captured an objective. It watches each player's `objective_captures` in their live leaderboard stats and, when it goes up, posts a banner such as `bachancuc123 captured a point (2 this match)`. The game only counts finished captures, so it names who completed a capture, not who is standing on a point. It also answers `!caps` in chat with this match's captures per player, adds `shared.caps()` to print them in the console, and `shared.stop_cap_announcer()` to stop it. Change `ANNOUNCE_IN` at the top to `"notification"` for a smaller pop-up or `"console"` to only print. Running it again replaces the running copy. Players running `iris_viewer.luau` also get a live "Captures" window with this match's standings and the latest captures. It updates without reopening if you close it; set `SEND_TO_IRIS = false` to turn it off.

### Exploring the Console

The console runs Deadline's modding API, documented at [recoil-group.github.io/deadline-modding](https://recoil-group.github.io/deadline-modding/making-mods/scripting/api/). `explore_console.luau` is a read-only survey of what it returns on your server: the documented globals, game data (`config`, `sharedvars`, maps, gamemodes), the `players` API, every key path in `get_profile_stats()` (with types and sample values; big collections like one entry per weapon are summarized), what the read-only getters (`get_leaderboard_stats`, `get_weapon_data_from_character`, `get_weapon_from_loadout`, ...) return right now, and `shared`. The API also has admin actions (`kill`, `kick`, `give_money`, `map.set_map`, ...); the survey lists those but never calls them. Run it mid-match while alive, the same way as the other scripts; its output is the starting point for new reports.

## What It Shows

**Account recap** — level, unofficial prestige, XP to next level, kills, deaths, KDR, headshot / wallbang / explosive kill percentages, matches played, objectives captured, rounds fired, money spent (split by attachments vs weapons), tester status, time alive, distance travelled, owned weapons / attachments / camos, and per-match / per-minute averages.

**Weapon table** — one row per weapon: kills, deaths while carrying it, deaths caused by it, w-KDR, share of kills, rounds fired, kills per minute, rounds fired per kill, weapon XP, time used, share of time used, and type. Legacy weapon ids are merged into their current weapon (e.g. `HK416A5` → `KF416`, `AKMN` → `AK_762`, `Glock17`/`Glock20` → `KOSCH`, `Vector` → `SCALAR` and `SA58` → `SG58`, which keep their old names "Vector" and "SA58").

**Attachment stats** — per-attachment kills and top weapon across all guns, by in-game name. Legacy attachment ids are folded into their current ids (`data/renames.csv`: deadline-balancing's rename list plus historical renames added here), and legacy gun ids into their current gun, so renamed or merged parts — e.g. `vector_9mm_bolt` + `vector_45acp_bolt` → `kalis_scalar_std_bcg` ("KALIS Scalar Standard (BCG)") — report unified totals.

### How to read the numbers

These follow from how the game records stats, so they're worth knowing:

| Stat | Meaning |
| --- | --- |
| `deaths w/` | Deaths while carrying the weapon in **any** slot. The game increments this for every weapon carried at death, so one death counts toward up to four weapons (which is why the table has no total row). |
| `deaths by` | How many times that weapon killed you. |
| `w-KDR` | `kills with weapon / deaths while carrying it`. Falls back to the kill count if there are no such deaths. |
| `Rounds / Kill`, `RFpK` | Rounds fired per kill. The profile stores no hit counts, so true accuracy can't be computed. |
| `Time Alive`, `time used`, `rds. ct` | Time alive with a weapon equipped, and rounds fired, summed across all weapons. **These are floors:** the game only saves a life's time / rounds / distance when that life ends in a real death — surviving to the end of a match, a map reset, or leaving the server discards them, while kills are counted immediately. Per-minute stats, `Avg Lifespan`, `RFpK` and `Rounds / Kill` are all skewed by this. Tracking also only began in July 2024. |
| `Grenades + old RPG` | Kills the game counted toward the account total but never stored under a weapon. Thrown-grenade kills are still recorded with no weapon name today; rocket launcher kills were too until April 2025 (they now land on `RPG7` / `PSRL`). |
| `% allK`, `% allT` | Relative to the weapons shown in the table (so they respect the filter). The recap above the table is always account-wide. |
| `Level` | The game's level, from its progression table (caps at 85). |
| `Prestige`, `Prestige Level` | Unofficial — the game has no prestige. `Prestige` is how many times the max-level XP total (4,678,000) has been earned; `Prestige Level` is the level the leftover XP would be worth on its own. Together they quantify progress past the level cap. |

Career stats are not recorded in the lobby or in player-owned private servers, so a fresh account will show zeros.

## Project Structure

```
print_player_stats.luau               <- weapon table entry point and config
print_attachment_stats.luau           <- attachment table entry point
print_attachment_stats_delimited.luau <- attachment data as Lua-table lines, to capture test fixtures
cap_announcer.luau                    <- announces who captured a point; live Captures window
explore_console.luau                  <- read-only survey of what the console API returns
iris_viewer.luau                      <- CLIENT console: shows the reports above in Iris windows
modules/                                 downloaded by the entry points at run time
  iris_report.luau           <- builds reports for iris_viewer and sends them (fire_client); Refresh
  weapon_data.luau           <- gun ids: legacy aliases, display names, types (shared by both reports)
  player_lookup.luau         <- finds the player a report is for (shared by all entry points)
  level_data.luau            <- XP thresholds and level calculation
  formatters.luau            <- number / currency / time / padding helpers
  stats_aggregator.luau      <- merges raw profile stats into one per-weapon table
  filters_sorters.luau       <- filtering and sorting of the weapon list
  renderer.luau              <- weapon report layout, for the console and Iris
  attachment_data.luau       <- attachment aliases (GENERATED table) and resolver
  attachment_aggregator.luau <- per-attachment kills, renames and groups applied
  attachment_renderer.luau   <- attachment table (console and Iris) and Lua-table output
  attachment_names.luau      <- GENERATED attachment id -> in-game name, and GROUPS
data/
  balancing.csv              <- deadline-balancing item sheet; source of display names
  renames.csv                <- deadline-balancing rename list plus historical renames added here
  extra_display_names.csv    <- hand-written names for old ids balancing.csv no longer lists
  attachment_groups.csv      <- pieces always equipped together, printed as one product row
tools/
  deadline_data.py            <- shared paths and helpers for the tools and tests
  check_fiu_compat.py         <- fails any script the game's Fiu VM would refuse to load
  build_attachment_names.py   <- regenerates modules/attachment_names.luau
  build_attachment_aliases.py <- regenerates / verifies the alias table in modules/attachment_data.luau
  verify_attachment_merge.py  <- replays the merge over a saved output and checks the totals
  rename.py                   <- applies data/renames.csv to the name column of CSV/Excel balancing sheets
tests/                           python -m unittest discover -s tests
  test_luau.py                <- runs the console scripts under the luau CLI with the console mocked (Iris and networking too)
  test_data.py                <- data files and generated Luau
  test_tools.py               <- unit tests for tools/
  fixtures/attachment_stats_output.txt <- saved print_attachment_stats_delimited output
  fixtures/expected_merges.csv         <- which fixture rows each rename folds together, and the totals
.github/
  workflows/sync-balancing.yml <- daily: pull deadline-balancing, regenerate, check, commit
  workflows/check.yml          <- every push / PR: Fiu load check + tests
  actions/setup-luau/          <- installs luau / luau-compile for both workflows
```

### Keeping names and renames current

`.github/workflows/sync-balancing.yml` runs daily (or on demand from the Actions tab). It downloads `balancing.csv` and `renames.csv` from `recoil-group/deadline-balancing`, regenerates `modules/attachment_names.luau` and the alias table in `modules/attachment_data.luau`, and commits to `main` only if the Fiu load check and the tests pass. Upstream renames are merged into `data/renames.csv`; rows added here by hand are never dropped. A new rename that folds together ids in the test fixture fails the tests on purpose: review the merges `python tools/verify_attachment_merge.py` prints, then run it with `--write-expected`.

If the printer shows a prettified id instead of an in-game name (e.g. `Fn SCAR Mk20 Gas Block`), that id is missing from `balancing.csv`, usually because the game renamed the part. If the part still exists under a new id (here `aft_mk20_gas_block`), add `old,new` to `data/renames.csv` so its kills merge into the current part; otherwise add `id,Name` to `data/extra_display_names.csv`. Then run both build tools.

To do the same by hand:

```
python tools/build_attachment_aliases.py --fetch
python tools/build_attachment_names.py --fetch
python tools/check_fiu_compat.py
python -m unittest discover -s tests
```

The tests run the console scripts themselves, so they need the `luau` and `luau-compile` CLIs (from a [Luau release](https://github.com/luau-lang/luau/releases)) in `luau_bin/`, on `PATH`, or in the folder `$LUAU_BIN` points to; without them those tests are skipped. To refresh the fixture, run `print_attachment_stats_delimited.luau` in-game and save its output as `tests/fixtures/attachment_stats_output.txt`.

### The Fiu 255-line limit

Deadline's console runs scripts in an old build of the Fiu VM with a line-info bug: it fails to load any function whose code spans more than 255 source lines, before a single line runs, with `Fiu:494: attempt to perform arithmetic (add) on nil and number`. Every function counts, including a file's top level, long `[[...]]` strings and big comment blocks inside it. That is why the generated tables are packed several entries per line. A script's top level runs from its first line to its last, and wrapping the code in a function does not change that, so a script pasted in one piece, like `iris_viewer.luau`, must be 255 lines or fewer in total. `python tools/check_fiu_compat.py` checks every file the game loads, and CI runs it on every push.

Weapon ids are the exact (case-sensitive) model names under `ReplicatedStorage.data.item` in the game. To add or retype a weapon, edit the tables in `modules/weapon_data.luau`.
