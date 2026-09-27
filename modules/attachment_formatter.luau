-- modules/attachment_formatter.luau
-- Resolves display names for attachments and weapons.
-- Single Responsibility: Translates backend technical IDs (e.g. "ecm_gunslinger_kag")
-- into polished in-game names ("ECM Gunslinger KAG") via ReplicatedStorage query or heuristics.
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ('Fiu') that does not
-- accept Luau type annotations, so this file intentionally has none.

local AttachmentFormatter = {}
AttachmentFormatter.__index = AttachmentFormatter

local ATTACHMENT_ACRONYMS = {
    acog    = "ACOG",
    rmr     = "RMR",
    sro     = "SRO",
    eod     = "EOD",
    cqc     = "CQC",
    oem     = "OEM",
    pepr    = "P.E.P.R.",
    spr     = "SPR",
    ddg     = "DDG",
    hdd     = "HDD",
    ap      = "AP",
    fmj     = "FMJ",
    otm     = "OTM",
    hp      = "HP",
    jsp     = "JSP",
    ps      = "PS",
    sat     = "SAT",
    mvg     = "MVG",
    afg     = "AFG",
    lss     = "LSS",
    nv      = "NV",
    ir      = "IR",
    rsb     = "RSB",
    vg      = "VG",
    pt      = "PT",
    fcu     = "FCU",
    fsp     = "FSP",
    raf     = "RAF",
    tac     = "TAC",
    sdmr    = "SDMR",
    bdc     = "BDC",
    srx     = "SRX",
    urgi    = "URG-I",
    akm     = "AKM",
    ak74    = "AK-74",
    ak74m   = "AK-74M",
    ak12    = "AK-12",
    ak308   = "AK-308",
    ak      = "AK",
    ar15    = "AR-15",
    ar9     = "AR-9",
    m4      = "M4",
    m4a1    = "M4A1",
    m16     = "M16",
    fal     = "FAL",
    sa58    = "SA58",
    g3      = "G3",
    scar    = "SCAR",
    scarh   = "SCAR-H",
    scarl   = "SCAR-L",
    scar20  = "SCAR-20",
    scar47  = "SCAR-47",
    mp5     = "MP5",
    mp5k    = "MP5K",
    aug     = "AUG",
    psg1    = "PSG-1",
    hk      = "HK",
    fn      = "FN",
    atg     = "ATG",
    pbs     = "PBS",
    rpk     = "RPK",
    rpk16   = "RPK-16",
    bcg     = "BCG",
    bcm     = "BCM",
    qd      = "QD",
    kag     = "KAG",
    mlok    = "M-LOK",
    pmag    = "PMAG",
    pmm     = "PMM",
    xl      = "XL",
    mre     = "MRE",
    cmmg    = "CMMG",
    aics    = "AICS",
    pdw     = "PDW",
    prs     = "PRS",
    ubr     = "UBR",
    moe     = "MOE",
    moa     = "MOA",
    aft     = "AFT",
    gdr     = "GDR",
    zvn     = "ZVN",
    std     = "Std",
    socom   = "SOCOM",
    gen1    = "Gen 1",
    gen2    = "Gen 2",
    gen3    = "Gen 3",
    gen4    = "Gen 4",
    gen5    = "Gen 5",
    acr     = "ACR",
    sas     = "SAS",
    rsa     = "RSA",
    sig     = "SIG",
    sauer   = "Sauer",
    okp     = "OKP",
    pso     = "PSO",
    pkas    = "PK-AS",
    edc     = "EDC",
    x9      = "X9",
    qbz95   = "QBZ-95",
    m855    = "M855",
    m855a1  = "M855A1",
    m118lr  = "M118LR",
    m993    = "M993",
    m995    = "M995",
    xm193   = "XM193",
    l7awm   = "L7AWM",
}

local DEFAULT_WEAPON_NAMES = {
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
}

local DEFAULT_WEAPON_ALIASES = {
    HK416A5 = "KF416",
    AK74N   = "AK_545",
    AKMN    = "AK_762",
    PP19    = "AK_9",
    UMP45   = "UMP",
    Glock17 = "KOSCH",
    Glock20 = "KOSCH",
}

function AttachmentFormatter.new(deps)
    local self = setmetatable({}, AttachmentFormatter)
    self.weapon_data = deps and deps.weapon_data
    self.formatters = deps and deps.formatters
    self.cache = {}
    return self
end

function AttachmentFormatter:get_game_item_display_name(id)
    if self.cache[id] then
        return self.cache[id]
    end

    local ok, name = pcall(function()
        if not game then return nil end
        local rs = game:GetService("ReplicatedStorage")
        if not rs then return nil end
        local data = rs:FindFirstChild("data")
        local item_folder = data and data:FindFirstChild("item")
        if not item_folder then return nil end
        local obj = item_folder:FindFirstChild(id)
        if not obj then return nil end

        local attr = obj:GetAttribute("display_name")
            or obj:GetAttribute("DisplayName")
            or obj:GetAttribute("title")
        if attr and type(attr) == "string" and #attr > 0 then
            return attr
        end

        local val = obj:FindFirstChild("display_name")
            or obj:FindFirstChild("DisplayName")
            or obj:FindFirstChild("title")
        if val and val:IsA("StringValue") and #val.Value > 0 then
            return val.Value
        end

        if obj:IsA("ModuleScript") then
            local mod = require(obj)
            if type(mod) == "table" then
                local dname = mod.display_name or mod.DisplayName or mod.title or mod.name
                if dname and type(dname) == "string" and #dname > 0 then
                    return dname
                end
            end
        end

        return nil
    end)

    if ok and name then
        self.cache[id] = name
        return name
    end
    return nil
end

function AttachmentFormatter:polish_word(w)
    local low = string.lower(w)
    if ATTACHMENT_ACRONYMS[low] then
        return ATTACHMENT_ACRONYMS[low]
    end
    if string.match(low, "^%d+%.?%d*x%d+%a*$") then
        return low
    end
    if string.match(low, "^%d+gr$") then
        return low
    end
    if string.match(low, "^%d+r$") then
        return string.upper(low)
    end
    if string.match(low, "^%d+mm$") then
        return low
    end
    local inch_num = string.match(low, "^(%d+%.?%d*)inch$")
    if inch_num then
        return inch_num .. " Inch"
    end
    local i_num = string.match(low, "^(%d+%.?%d*)i$")
    if i_num then
        return i_num .. " Inch"
    end
    if string.match(low, "^%a%d+%a?$") then
        return string.upper(low)
    end

    local parts = {}
    for part in string.gmatch(low, "[^%-]+") do
        local cap = string.upper(string.sub(part, 1, 1)) .. string.sub(part, 2)
        table.insert(parts, cap)
    end
    return table.concat(parts, "-")
end

function AttachmentFormatter:polish_attachment_name(tech_id)
    local words = {}
    for w in string.gmatch(tech_id, "[^_]+") do
        table.insert(words, self:polish_word(w))
    end
    return table.concat(words, " ")
end

function AttachmentFormatter:resolve_attachment_display_name(canonical_id)
    local game_name = self:get_game_item_display_name(canonical_id)
    if game_name and #game_name > 0 then
        return game_name
    end
    return self:polish_attachment_name(canonical_id)
end

function AttachmentFormatter:resolve_weapon_display_name(raw_gun_id)
    if not raw_gun_id or raw_gun_id == "N/A" then
        return "N/A"
    end
    local game_name = self:get_game_item_display_name(raw_gun_id)
    if game_name and #game_name > 0 then
        return game_name
    end

    local aliases = (self.weapon_data and self.weapon_data.ALIASES) or DEFAULT_WEAPON_ALIASES
    local display_names = (self.weapon_data and self.weapon_data.DISPLAY_NAMES) or DEFAULT_WEAPON_NAMES

    local canonical = aliases[raw_gun_id] or raw_gun_id
    if display_names[canonical] then
        return display_names[canonical]
    end
    if display_names[raw_gun_id] then
        return display_names[raw_gun_id]
    end
    return canonical
end

return AttachmentFormatter
