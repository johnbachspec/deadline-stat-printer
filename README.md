# deadline-stat-printer
Prints Deadline Roblox detailed kill stats.

A robust, type-safe **Luau** utility script designed for Roblox games to extract, aggregate, process, and display weapon performance statistics from player profile data. Original script from @LegitACarWithAGun.

Features automatic legacy weapon ID merging, real-time performance metric calculations (K/D Ratio, Rounds Fired per Kill), and clean monospaced tabular console output designed specifically for Roblox Studio's output window.

---

## Key Features

- **Legacy Weapon ID Merging**: Automatically aggregates stats from older or renamed weapon IDs into their modern counterparts (e.g., merging `HK416A5` into `KF416`, `AK74N` into `AK_545`).
- **Calculated Performance Metrics**:
  - **KDR (K/D With)**: Kills per death while holding the weapon ($Kills / DeathsWith$).
  - **RFpK (Rounds Fired per Kill)**: Total ammunition expenditure required per kill achieved ($RoundsFired / Kills$).
  - **EXP With**: Total experience accrued with each weapon.
- **Fixed-Width Monospaced Alignment**: Utilizes string format specifiers (`%-20s %8d...`) to ensure columns align cleanly in the Roblox Studio console output window without wrapping.
- **Single or All Weapon Targeting**: Easily filter by a single weapon or output a complete breakdown sorted by total kill count.
- **Type-Safe Luau**: Built with explicit Luau type annotations (`weapon_data`, `weapon_entry`) for performance and developer readability.

---

## How to Use

1. **Insert Code**: Open a private Deadline server. Press tilde (```) to open the Luau console. Switch to `Luau Server Console` and insert the code.
2. **Configure Parameters**:
   Change `TARGET_WEAPON` to either a specific weapon string or leave empty `""` to display all weapons.

   ```luau
   local TARGET_WEAPON = "" -- Set to "M4A1" or leave empty "" for all weapons
   ```
3. **Run**: Execute the code. Output will display in the Roblox Studio Output window.

Alternatively, run require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/print_player_stats.luau")
---

## Example Console Output

```text
weapon               kills  deaths with     kdr  rounds fired     RFpK     EXP with
--------------------------------------------------------------------------------------
SCARH                67394        18079    3.73        192768     2.86    9771652.3
M4A1                  8443         2769    3.05         48243     5.71    1575245.5
AK_762                7186         2394    3.00         36217     5.04     825844.3
AUG_A3                5315         1720    3.09         29151     5.48     804497.2
KF416                 2734          847    3.23         13826     5.06     464680.2
G3                    2592          854    3.04          8323     3.21     341296.8
MK9                   2458         1040    2.36         29925    12.17     383567.9
AK_545                1187          520    2.28         13051    10.99     184712.7
```

---

## Code Overview

```luau
local PLAYER_NAME = "bachancuc123"
local TARGET_WEAPON = ""

local WEAPON_ALIASES = {
    ["HK416A5"] = "KF416",
    ["AK74N"]   = "AK_545",
    ["AKMN"]    = "AK_762",
    ["PP19"]    = "AK_9",
    ["UMP45"]   = "UMP",
}

-- Column Layout Formatting
local ROW_FORMAT    = "%-20s %8d %12d %7.2f %13d %8.2f %12.1f"
local HEADER_FORMAT = "%-20s %8s %12s %7s %13s %8s %12s"

-- Complete script merges legacy data before calculating ratios and printing rows.
```

---

## Luau Type Definitions

```luau
type weapon_data = {
    attachment_stats: {[string]: {
        experience: number,
        kills: number,
    }},
    kills: number,
    deaths_with: number,
    experience: number,
    owned_attachments: {string},
    deaths_from: number,
    rounds_fired: number,
    owned_camo: {[string]: {string}}, 
}

type weapon_entry = {
    name: string,
    data: weapon_data,
}
```

---

## Weapon Alias Mapping

The script automatically combines stats for weapons that underwent ID migrations or name changes across game updates:

| Legacy Weapon ID | Target Combined Weapon ID |
| :--- | :--- |
| `HK416A5` | `KF416` |
| `AK74N` | `AK_545` |
| `AKMN` | `AK_762` |
| `PP19` | `AK_9` |
| `UMP45` | `UMP` |

---
