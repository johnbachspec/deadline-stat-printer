-- modules/weapon_data.lua
-- SRP: this module's only job is knowing facts about weapons
-- (legacy id aliasing, display names, caliber/type classification).
-- It has zero knowledge of stats, formatting, or printing.

local WeaponData = {}

-- Legacy ID to Target ID mapping
WeaponData.ALIASES = {
    ["HK416A5"] = "KF416",
    ["AK74N"]   = "AK_545",
    ["AKMN"]    = "AK_762",
    ["PP19"]    = "AK_9",
    ["UMP45"]   = "UMP",
    ["Glock17"] = "Kosch",
    ["Glock20"] = "Kosch",
}

-- Raw Weapon ID -> Formatted Display Name
WeaponData.DISPLAY_NAMES = {
    ["SCARH"]             = "SCAR-H",
    ["AK_762"]            = "AKM",
    ["AUG_A3"]            = "AUG A3",
    ["Remington700"]      = "R700",
    ["SCAR47"]            = "SCAR-47",
    ["AK_545"]            = "AK-74",
    ["AK308"]             = "AK-308",
    ["SCARL"]             = "SCAR-L",
    ["QBZ95"]             = "QBZ-95",
    ["EDC_X9"]            = "EDC X9",
    ["AK12"]              = "AK-12",
    ["Remington870"]      = "R870",
    ["AK_545_Carbine"]    = "AKS-74U",
    ["MosinNagant"]       = "Mosin-Nagant",
    ["AK_9"]              = "AK-9",
    ["M11_EOD"]           = "M11 EOD",
    ["MP133"]             = "MP-133",
    ["PSRL"]              = "PSRL",
    ["IZHEVSK_AKM_TYPE1"] = "AKM Type1",
    ["IZHEVSK_AKM_TYPE2"] = "AKM Type2",
    ["F1"]                = "F-1",
    ["M67"]               = "M67",
    ["M8HC"]              = "M8",
    ["RGD2"]              = "RGD-2",
    ["M84"]               = "M84",
    ["M9"]                = "M9",
    ["RPG7"]              = "RPG-7",
    ["Warhead"]           = "HEAT/HE Warhead",
}

-- Weapon metadata mapping: Maps weapon names directly to their Type
WeaponData.CALIBER_INFO = {
    ["SCARH"]             = "308",
    ["G3"]                = "308",
    ["SA58"]              = "308",
    ["AK308"]             = "308",
    ["Remington700"]      = "Bolt",
    ["MosinNagant"]       = "Bolt",
    ["AK_762"]            = "762",
    ["SCAR47"]            = "762",
    ["M4A1"]              = "556",
    ["AUG_A3"]            = "556",
    ["KF416"]             = "556",
    ["SCARL"]             = "556",
    ["AK_545"]            = "545",
    ["AK12"]              = "545",
    ["AK_545_Carbine"]    = "545",
    ["QBZ95"]             = "58",
    ["Vector"]            = "SMG",
    ["UMP"]               = "SMG",
    ["MP5"]               = "SMG",
    ["AK_9"]              = "SMG",
    ["MK9"]               = "SMG",
    ["TT33"]              = "Pistol",
    ["Makarov"]           = "Pistol",
    ["Kosch"]             = "Pistol",
    ["EDC_X9"]            = "Pistol",
    ["P320"]              = "Pistol",
    ["Remington870"]      = "Shotgun",
    ["MP133"]             = "Shotgun",
    ["M9"]                = "Melee",
    ["M11_EOD"]           = "Melee",
    ["IZHEVSK_AKM_TYPE1"] = "Melee",
    ["IZHEVSK_AKM_TYPE2"] = "Melee",
    ["Warhead"]           = "RPG",
    ["PSRL"]              = "RPG",
    ["RPG7"]              = "RPG",
    ["M67"]               = "Grenade",
    ["F1"]                = "Grenade",
    ["M8HC"]              = "Smoke",
    ["RGD2"]              = "Smoke",
    ["M84"]               = "Flash",
}

-- Accessor helpers keep callers from reaching into the raw tables directly,
-- which means the underlying data shape can change without breaking callers.

function WeaponData.resolve_alias(weapon_name)
    return WeaponData.ALIASES[weapon_name]
end

function WeaponData.is_alias(weapon_name)
    return WeaponData.ALIASES[weapon_name] ~= nil
end

function WeaponData.display_name(weapon_name)
    return WeaponData.DISPLAY_NAMES[weapon_name] or weapon_name
end

function WeaponData.caliber(weapon_name)
    return WeaponData.CALIBER_INFO[weapon_name] or "Unknown"
end

return WeaponData
