--!strict
-- modules/weapon_data.luau
-- Static facts about weapons: legacy id aliases, display names, type classification.
-- Weapon ids are the exact (case-sensitive) model names under
-- ReplicatedStorage.data.item in the game; profile stats are keyed by them.

local WeaponData = {}

-- Legacy id -> current id. The game does not migrate weapon stats when a
-- weapon is renamed, so old ids linger in profiles under their old key.
WeaponData.ALIASES = {
    HK416A5 = "KF416",
    AK74N   = "AK_545",
    AKMN    = "AK_762",
    PP19    = "AK_9",
    UMP45   = "UMP",
    Glock17 = "KOSCH",
    Glock20 = "KOSCH",
}

-- Synthetic row for kills the game counts toward total_kills but never stored
-- under a weapon key: thrown-grenade kills (F1, M67, ...) to this day, and
-- rocket (RPG7/PSRL) kills from before April 2025.
WeaponData.UNATTRIBUTED_ID = "Unattributed"

WeaponData.DISPLAY_NAMES = {
    SCARH             = "SCAR-H",
    AK_762            = "AKM",
    AUG_A3            = "AUG A3",
    Remington700      = "R700",
    SCAR47            = "SCAR-47",
    AK_545            = "AK-74",
    AK308             = "AK-308",
    SCARL             = "SCAR-L",
    QBZ95             = "QBZ-95",
    EDC_X9            = "EDC X9",
    AK12              = "AK-12",
    Remington870      = "R870",
    AK_545_Carbine    = "AKS-74U",
    MosinNagant       = "Mosin-Nagant",
    AK_9              = "AK-9",
    KOSCH             = "Kosch",
    M11_EOD           = "M11 EOD",
    MP133             = "MP-133",
    IZHEVSK_AKM_TYPE1 = "AKM Type1",
    IZHEVSK_AKM_TYPE2 = "AKM Type2",
    F1                = "F-1",
    M8HC              = "M8",
    RGD2              = "RGD-2",
    RPG7              = "RPG-7",
    Zarya3            = "Zarya-3",
    PlacingTool       = "Placing Tool",
    [WeaponData.UNATTRIBUTED_ID] = "Grenades + old RPG",
}

WeaponData.TYPES = {
    SCARH = "308", G3 = "308", SA58 = "308", AK308 = "308",
    Remington700 = "Bolt", MosinNagant = "Bolt",
    AK_762 = "762", SCAR47 = "762",
    M4A1 = "556", AUG_A3 = "556", KF416 = "556", SCARL = "556",
    AK_545 = "545", AK12 = "545", AK_545_Carbine = "545",
    QBZ95 = "58",
    Vector = "SMG", UMP = "SMG", MP5 = "SMG", AK_9 = "SMG", MK9 = "SMG",
    TT33 = "Pistol", Makarov = "Pistol", KOSCH = "Pistol", EDC_X9 = "Pistol", P320 = "Pistol",
    Remington870 = "Shotgun", MP133 = "Shotgun",
    M9 = "Melee", M11_EOD = "Melee", IZHEVSK_AKM_TYPE1 = "Melee", IZHEVSK_AKM_TYPE2 = "Melee",
    PSRL = "RPG", RPG7 = "RPG",
    M67 = "Grenade", F1 = "Grenade", [WeaponData.UNATTRIBUTED_ID] = "Grenade",
    Molotov = "Fire",
    M8HC = "Smoke", RGD2 = "Smoke",
    M84 = "Flash", Zarya3 = "Flash",
    Crayon = "Healing",
    Turret = "Turret", PlacingTool = "Turret",
}

-- Pre-indexed lowercase map for O(1) resolution:
-- maps lowercase (raw id | alias | display name) -> canonical weapon id.
local RESOLVE_LOOKUP: { [string]: string } = {}

for legacy, target in pairs(WeaponData.ALIASES) do
    RESOLVE_LOOKUP[string.lower(legacy)] = target
end
for id in pairs(WeaponData.TYPES) do
    RESOLVE_LOOKUP[string.lower(id)] = id
    local dname = WeaponData.DISPLAY_NAMES[id]
    if dname then
        RESOLVE_LOOKUP[string.lower(dname)] = id
    end
end

function WeaponData.display_name(id: string): string
    return WeaponData.DISPLAY_NAMES[id] or id
end

function WeaponData.type_of(id: string): string
    return WeaponData.TYPES[id] or "Unknown"
end

-- Resolves user input (raw id, legacy id, or display name; case-insensitive)
-- to the id used as a key in the combined stats table.
function WeaponData.resolve(name: string): string
    local lower = string.lower(name)
    return RESOLVE_LOOKUP[lower] or name
end

return WeaponData
