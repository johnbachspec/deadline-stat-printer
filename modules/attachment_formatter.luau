-- modules/attachment_formatter.luau
-- Resolves display names for attachments and weapons.
-- Single Responsibility: Translates backend technical IDs into polished,
-- official in-game names pulled from recoil-studio/deadline-balancing/balancing.csv,
-- with fallback to ReplicatedStorage queries and heuristic polishing.
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ('Fiu') that does not
-- accept Luau type annotations, so this file intentionally has none.

local AttachmentFormatter = {}
AttachmentFormatter.__index = AttachmentFormatter

-- Beautified names populated at runtime via sync_balancing_names()

-- (fetches from recoil-studio/deadline-balancing/balancing.csv over HTTP).

-- Static table removed to keep bytecode small for Deadline's Fiu interpreter.

-- BEGIN BEAUTIFIED_NAMES (runtime loaded; intentionally no embedded table)
AttachmentFormatter.BEAUTIFIED_NAMES = {}
-- END BEAUTIFIED_NAMES


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
    urg     = "URG",
    dd      = "DD",
    kac     = "KAC",
    sbr     = "SBR",
    cqb     = "CQB",
    pvs     = "PVS",
    an      = "AN",
    peq     = "PEQ",
    la5     = "LA-5",
    dbal    = "DBAL",
    surefire = "SureFire",
    modlite = "Modlite",
    cloud   = "Cloud",
    inforce = "InForce",
    streamlight = "Streamlight",
    scalarworks = "Scalarworks",
    geissele = "Geissele",
    reptilia = "Reptilia",
    unity   = "Unity",
    wilcox  = "Wilcox",
    eotech  = "EOTech",
    aimpoint = "Aimpoint",
    trijicon = "Trijicon",
    vortex  = "Vortex",
    leupold = "Leupold",
    nightforce = "Nightforce",
    schmidt = "Schmidt",
    steiner = "Steiner",
    primary = "Primary",
    holosun = "Holosun",
}

local DEFAULT_WEAPON_NAMES = {
    AK_762  = "AKM",
    AK_545  = "AK-74N",
    AK_9    = "PP-19 Vityaz",
    KF416   = "KF416",
    KOSCH   = "Kosch (Glock)",
    M4A1    = "M4A1",
    SCARH   = "SCAR-H",
    SCARL   = "SCAR-L",
    Vector  = "Vector",
    MP5     = "MP5",
    MP5K    = "MP5K",
    FAL     = "FAL",
    G3      = "G3",
    AUG     = "AUG A3",
    QBZ95   = "QBZ-95",
    M16A4   = "M16A4",
    Remington870 = "Model 870",
    Saiga12 = "Saiga-12",
    Mosin   = "Mosin-Nagant",
    R700    = "R700",
    DVL10   = "DVL-10",
    AX50    = "AX-50",
    WA2000  = "WA2000",
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
    self.attachment_data = deps and deps.attachment_data
    self.formatters = deps and deps.formatters
    self.beautified_names = (deps and deps.beautified_names) or AttachmentFormatter.BEAUTIFIED_NAMES
    self.cache = {}
    self.sync_status = "not yet synced"
    -- Eagerly sync beautified names from upstream balancing.csv over HTTP
    pcall(function() self:sync_balancing_names() end)
    return self
end

function AttachmentFormatter:get_sync_status()
    return self.sync_status or "embedded snapshot (balancing.csv)"
end

-- Safe string slice helper to prevent Luau compiler from emitting FASTCALL3 (opcode 60 with aux word),
-- which crashes Deadline's older in-game Fiu bytecode interpreter on line 494.
local function safe_sub(s, i, j)
    return (string.sub)(s, i, j)
end

-- Robust CSV line parser supporting double-quoted fields
local function parse_csv_line(line)
    local fields = {}
    local pos = 1
    local len = #line
    while pos <= len do
        local c = safe_sub(line, pos, pos)
        if c == '"' then
            local txt = ""
            pos = pos + 1
            while pos <= len do
                local c2 = safe_sub(line, pos, pos)
                if c2 == '"' then
                    if pos + 1 <= len and safe_sub(line, pos + 1, pos + 1) == '"' then
                        txt = txt .. '"'
                        pos = pos + 2
                    else
                        pos = pos + 1
                        break
                    end
                else
                    txt = txt .. c2
                    pos = pos + 1
                end
            end
            table.insert(fields, txt)
            while pos <= len and safe_sub(line, pos, pos) ~= "," do
                pos = pos + 1
            end
            if pos <= len and safe_sub(line, pos, pos) == "," then
                pos = pos + 1
            end
        else
            local next_comma = string.find(line, ",", pos, true)
            if next_comma then
                table.insert(fields, safe_sub(line, pos, next_comma - 1))
                pos = next_comma + 1
            else
                table.insert(fields, safe_sub(line, pos))
                pos = len + 1
            end
        end
    end
    return fields
end

-- Pulls latest beautified names from recoil-studio/deadline-balancing/balancing.csv
function AttachmentFormatter:sync_balancing_names(custom_url)
    local ok, http = pcall(function() return game:GetService("HttpService") end)
    if not ok or not http then
        self.sync_status = "offline (HttpService unavailable)"
        return false, self.sync_status
    end

    local urls = {
        custom_url,
        "https://raw.githubusercontent.com/recoil-studio/deadline-balancing/main/balancing.csv",
        "https://raw.githubusercontent.com/recoil-group/deadline-balancing/main/balancing.csv",
    }

    local body = nil
    local active_url = nil
    for _, url in ipairs(urls) do
        if url and type(url) == "string" and #url > 0 then
            local fetch_ok, res = pcall(function()
                return http:GetAsync(url, true)
            end)
            if fetch_ok and type(res) == "string" and #res > 0 then
                body = res
                active_url = url
                break
            end
        end
    end

    if not body then
        self.sync_status = "offline (fetch failed)"
        return false, self.sync_status
    end

    local header_found = false
    local name_col, pretty_col = 3, 4 -- 1-indexed for Luau
    local count = 0

    for line in body:gmatch("[^\r\n]+") do
        local fields = parse_csv_line(line)
        if not header_found then
            for idx, col in ipairs(fields) do
                if col == "name" then name_col = idx end
                if col == "pretty_name" then pretty_col = idx end
            end
            if name_col and pretty_col then
                header_found = true
            end
        else
            if #fields >= math.max(name_col, pretty_col) then
                local tech_name = fields[name_col]
                local pretty_name = fields[pretty_col]
                if tech_name and pretty_name and #tech_name > 0 and #pretty_name > 0 and tech_name ~= "name" then
                    self.beautified_names[tech_name] = pretty_name
                    AttachmentFormatter.BEAUTIFIED_NAMES[tech_name] = pretty_name
                    count = count + 1
                end
            end
        end
    end

    self.sync_status = string.format("live synced (%d names from %s)", count, active_url)
    return true, self.sync_status
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
        local cap = string.upper(safe_sub(part, 1, 1)) .. safe_sub(part, 2)
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

function AttachmentFormatter:resolve_attachment_display_name(raw_or_canon_id)
    if not raw_or_canon_id then return "Unknown" end

    -- 1. Check if an alias resolver was provided to find current canonical id
    local canon_id = raw_or_canon_id
    if self.attachment_data and type(self.attachment_data.resolve) == "function" then
        canon_id = self.attachment_data.resolve(raw_or_canon_id) or raw_or_canon_id
    end

    -- 2. Pull from official beautified names (balancing.csv)
    local names_table = self.beautified_names or AttachmentFormatter.BEAUTIFIED_NAMES
    if names_table[canon_id] and #names_table[canon_id] > 0 then
        return names_table[canon_id]
    end
    if names_table[raw_or_canon_id] and #names_table[raw_or_canon_id] > 0 then
        return names_table[raw_or_canon_id]
    end

    -- 3. Check in-game ReplicatedStorage item query
    local game_name = self:get_game_item_display_name(canon_id)
    if game_name and #game_name > 0 then
        return game_name
    end

    -- 4. Fallback to heuristic acronym/unit polishing
    return self:polish_attachment_name(canon_id)
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
