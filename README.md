# deadline-stat-printer

Prints detailed account and per-weapon statistics for Deadline (Roblox) players from the in-game Luau server console. Original script and inspiration from [@LegitACarWithAGun](https://github.com/LegitACarWithAGun); modular version by [@johnbachspec](https://github.com/johnbachspec); contribution by [@refact0r](https://github.com/refact0r) and [GabeeCoding](https://github.com/GabeeCoding)

## How to Use

1. Open a private Deadline server. Press tilde (`` ` ``) to open the Luau console and switch to **Luau Server Console**.
2. Run:

   ```lua
   require("https://raw.githubusercontent.com/refact0r/deadline-stat-printer/main/print_player_stats.luau")
   ```

   Or paste the contents of `print_player_stats.luau` into the console. Edit the config block at the top first if you want a filter:

   ```lua
   local TARGET_WEAPON = "" -- one weapon only: raw id ("AK_762"), legacy id ("AKMN"), or display name ("AKM")
   local FILTER_TYPE   = "" -- e.g. "556", "SMG", "RPG"; "" = everything except Unknown
   local SORT_BY       = "KILLS" -- "KILLS" or "TYPE"
   ```

3. A report prints for every human player currently in the server. Output appears in the Luau console itself (not the Roblox Studio Output window); the console is monospaced, but the 166-column grid will wrap if the console window is narrow.

After the script has run once, `shared.print_player_stats` stays available in the console for the rest of the session:

```lua
shared.print_player_stats(players.get("SomeName"))            -- default config
shared.print_player_stats(players.get("SomeName"), "SMG")     -- override FILTER_TYPE for this call
shared.print_player_stats(players.get("SomeName"), nil, "AKM") -- override TARGET_WEAPON for this call
```

## What It Shows

**Account recap** — level, unofficial prestige, XP to next level, kills, deaths, KDR, headshot / wallbang / explosive kill percentages, matches played, objectives captured, rounds fired, money spent (split by attachments vs weapons), tester status, time alive, distance travelled, owned weapons / attachments / camos, and per-match / per-minute averages.

**Weapon table** — one row per weapon: kills, deaths while carrying it, deaths caused by it, w-KDR, share of kills, rounds fired, kills per minute, rounds fired per kill, weapon XP, time used, share of time used, and type. Legacy weapon ids are merged into their current weapon (e.g. `HK416A5` → `KF416`, `AKMN` → `AK_762`, `Glock17`/`Glock20` → `KOSCH`).

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
print_player_stats.luau    <- entry point and config; require()s the modules below
modules/
  weapon_data.luau         <- weapon ids: legacy aliases, display names, types
  level_data.luau          <- XP thresholds and level calculation
  formatters.luau          <- number / currency / time / padding helpers
  stats_aggregator.luau    <- merges raw profile stats into one per-weapon table
  filters_sorters.luau     <- filtering and sorting of the weapon list
  renderer.luau            <- all console printing / layout
```

Weapon ids are the exact (case-sensitive) model names under `ReplicatedStorage.data.item` in the game. To add or retype a weapon, edit the tables in `modules/weapon_data.luau`.
