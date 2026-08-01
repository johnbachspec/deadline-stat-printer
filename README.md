# deadline-stat-printer

Prints Deadline Roblox detailed kill stats.

A robust, type-safe **Luau** utility script suite designed for Roblox games to extract, aggregate, process, and display weapon performance statistics from player profile data. Original script from @LegitACarWithAGun.

Features automatic legacy weapon ID merging, real-time performance metric calculations (K/D Ratio, Rounds Fired per Kill, Accuracy, Pace stats), and clean monospaced tabular console output designed specifically for Roblox Studio's output window.

As of this version, the codebase has been refactored into small, single-purpose modules following **SOLID** design principles, while still being runnable from a single `require()` link — see [Project Structure](#project-structure) below.

---

## Key Features

- **Legacy Weapon ID Merging**: Automatically aggregates stats from older or renamed weapon IDs into their modern counterparts (e.g., merging `HK416A5` into `KF416`, `AK74N` into `AK_545`).
- **Full Account Recap**: Prints level/prestige, KDR, headshot %, wallbang %, HE %, accuracy, money spent, tester status, and per-match / per-minute pace stats above the weapon breakdown.
- **Calculated Performance Metrics** (per weapon):
  - **w-KDR (K/D With)**: Kills per death while holding the weapon (`Kills / DeathsWith`).
  - **RFpK (Rounds Fired per Kill)**: Total ammunition expenditure required per kill achieved (`RoundsFired / Kills`).
  - **K/Min**: Kills per minute of time spent using the weapon.
  - **Weapon XP / Time Used**: Experience and playtime attributed to each weapon.
- **Fixed-Width Monospaced Alignment**: Uses string format specifiers and manual padding to keep columns aligned cleanly in the Roblox Studio console output window without wrapping, regardless of player name length.
- **Configurable Filtering & Sorting**: Filter the weapon table by caliber/type (`"556"`, `"SMG"`, `"RPG"`, etc.) or a single weapon, and sort by kills or by type.
- **Type-Safe Luau**: Built with explicit Luau typing conventions for performance and developer readability.
- **Modular, SOLID Architecture**: Data tables, formatting, stats aggregation, filtering/sorting, and rendering each live in their own module, making the script easier to extend, test, and maintain.

---

## How to Use

1. **Insert Code**: Open a private Deadline server. Press tilde (`` ` ``) to open the Luau console. Switch to `Luau Server Console` and insert the code.

2. **Configure Parameters**: at the top of `main/print_player_stat.lua`, set:

   ```lua
   local TARGET_WEAPON = "" -- Set to "AK_762" or leave empty "" for all weapons
   local FILTER_TYPE   = "" -- e.g. "556", "SMG", "RPG", or "" for all (excluding Unknown)
   local SORT_BY       = "KILLS" -- "KILLS" or "TYPE"
   ```

3. **Run**: Execute the code. Output will display in the Roblox Studio Output window.

### Alternatively, run:

```lua
require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/print_player_stat")
```

This single link is unchanged from previous versions — internally it now pulls in the smaller modules under `modules/` via chained `require()` calls, but the call site you use stays exactly the same.

---

## Example Console Output

```
======================================================================================================================================================
                                                       OVERALL ACCOUNT STATISTICS FOR bachancuc123
                                                                                                                                                        
 Level:             66             | Prestige:          0                | Status:            predemo tester, alpha tester
 Kills:             1,250          | Deaths:            430              | KDR:               2.90698
 Headshots:         300            | Wallbangs:         40               | HE Kills:          60
 HS %:              24.00%         | Wall %:            3.20%            | HE %:              4.80%
 Matches Played:    85             | Objectives Cap:    120              | Accuracy:          10.04%
 Total Money Spent: $50,000        | On Attachments:    $12,000 (24.00%) | On Weapons:        $38,000 (76.00%)
 Active Playtime:   6h 40m  0s     | Total Experience:  2,750,000        | Dist Travelled:    543,210 st
======================================================================================================================================================
                                                            AVERAGE STATS PER MATCH AND MINUTE

 Kills / Match:     14.71 | Kills / Min:        3.125 | HS / Match:          3.53 | Obj. / Match:        1.41 | Avg Lifespan:         55s
 Points / Match:   32,352 | EXP / Min:          6,875 | Wall / Match:        0.47 | HE / Match:          0.71 | Dist / Match:    6,390 st
======================================================================================================================================================
                                                                  DETAILED WEAPON STATS

weapon                    kills   deaths w/      w-KDR     % allK      rds. ct    K/Min     RFpK      weapon XP        time used     % allT  type
----------------------------------------------------------------------------------------------------------------------------------------------------
KF416                       500         170      2.941     40.00%        6,200     2.50    12.40         48,000       3h 20m  0s     50.00%  556
AKM                         500         100      5.000     40.00%        6,000     2.50    12.00         50,000       3h 20m  0s     50.00%  762
HEAT/HE Warhead             220           0    220.000     17.60%          220     0.00     1.00              0               0s      0.00%  RPG
M67                          30           0     30.000      2.40%           30     0.00     1.00          1,000               0s      0.00%  Grenade
----------------------------------------------------------------------------------------------------------------------------------------------------
TOTAL                     1,250         270      4.630    100.00%       12,450     3.12     9.96         99,000       6h 40m  0s    100.00%
```

---

## Project Structure

The script is split into single-purpose modules (SOLID) but is still reachable from one `require()` link, since `main/print_player_stat.lua` is a thin composition root that pulls the modules in for you:

```
main/
  print_player_stat.lua   <- entry point; the require() URL never changes

modules/
  weapon_data.lua         <- weapon aliases, display names, caliber/type lookups
  level_data.lua          <- XP thresholds + prestige/level math
  formatters.lua          <- number, currency, time, and padding/centering helpers
  achievements.lua        <- tester-status interpretation from achievement data
  stats_aggregator.lua    <- merges raw profile stats into combined per-weapon stats
  filters_sorters.lua     <- weapon list filtering + pluggable sort strategies
  renderer.lua            <- all console printing/layout logic
```

| Module | Responsibility |
| --- | --- |
| `weapon_data` | Static weapon metadata: legacy ID aliases, display names, caliber/type classification |
| `level_data` | XP-to-level and prestige calculation |
| `formatters` | Pure string/number formatting: `format_num`, `format_currency`, `format_use_time`, `pad_right`, `center_text` |
| `achievements` | Reads an achievements table and returns tester status (`"alpha tester"`, `"predemo tester"`, etc.) |
| `stats_aggregator` | Combines raw per-weapon stats, merging legacy aliases and backfilling untracked (e.g. explosive) kills |
| `filters_sorters` | Builds the filtered weapon list and sorts it via a strategy table (`KILLS`, `TYPE`) |
| `renderer` | Prints the account recap, pace stats, and weapon table using data handed to it — no lookups of its own |

Each module returns a plain table and has no dependency on the others beyond what's passed into it as a parameter (dependency injection), so any single piece can be swapped, tested, or extended without touching the rest of the script. For example, adding a new `SORT_BY` mode only requires adding an entry to `filters_sorters.lua`'s strategy table — no other file needs to change.

> **Note on deployment:** if chained `require()` calls ever prove slower or unsupported on a given VM, the modules can instead be concatenated into a single file at publish time while keeping this same structure in source. See the comment at the bottom of `main/print_player_stat.lua` for details.

---

## Weapon Alias Mapping

The script automatically combines stats for weapons that underwent ID migrations or name changes across game updates:

| Legacy Weapon ID  |  Target Combined Weapon ID |
| ----------------- | -------------------------- |
| `HK416A5`         | `KF416`                    |
| `AK74N`           | `AK_545`                   |
| `AKMN`            | `AK_762`                   |
| `PP19`            | `AK_9`                     |
| `UMP45`           | `UMP`                      |
| `Glock17`         | `Kosch`                    |
| `Glock20`         | `Kosch`                    |

This mapping now lives in `modules/weapon_data.lua`, alongside the display-name and caliber/type tables.

---

## Configuration Reference

| Setting         | Location                     | Values                                                          |
| ---             | ---                          | ---                                                             |
| `TARGET_WEAPON` | `main/print_player_stat.lua` | `""` for all weapons, or a specific weapon ID (e.g. `"AK_762"`) |
| `FILTER_TYPE`   | `main/print_player_stat.lua` | `""`, `"308"`, `"Bolt"`, `"762"`, `"556"`, `"545"`, `"58"`, `"Pistol"`, `"SMG"`, `"Shotgun"`, `"Melee"`, `"RPG"`, `"Grenade"`, `"Smoke"`, `"Flash"`, `"Unknown"` |
| `SORT_BY`       | `main/print_player_stat.lua` | `"KILLS"` (default) or `"TYPE"`                                 |
