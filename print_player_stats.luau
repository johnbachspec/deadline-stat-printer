local TARGET_WEAPON = "" -- Leave empty "" to list all or set to a weapon name (e.g. "AK_762")

-- Filter Configuration:
-- Options: "308", "Bolt", "762", "556", "545", "58", "Pistol", "SMG", "Shotgun", "Melee", "RPG", "Grenade", "Smoke", "Flash", "Unknown", or "" for ALL (excluding Unknown)
local FILTER_TYPE = "" 

-- Sorting Configuration:
-- "KILLS"  -> Sorts purely by highest total Kills (DEFAULT)
-- "TYPE"   -> Sorts purely by Type designation, then by Kills
local SORT_BY = "KILLS" 

-- Legacy ID to Target ID mapping
local WEAPON_ALIASES = {
    ["HK416A5"] = "KF416",
    ["AK74N"]   = "AK_545",
    ["AKMN"]    = "AK_762",
    ["PP19"]    = "AK_9",
    ["UMP45"]   = "UMP",
    ["Glock17"] = "Kosch",
    ["Glock20"] = "Kosch",
}

-- Raw Weapon ID -> Formatted Display Name
local WEAPON_DISPLAY_NAMES = {
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
local WEAPON_INFO = {
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

-- Level Experience Thresholds (Max Level: 85)
local LevelData = {
    [0] = 0, [1] = 1000, [2] = 3500, [3] = 6000, [4] = 9000,
    [5] = 12500, [6] = 16500, [7] = 21000, [8] = 26000, [9] = 31300,
    [10] = 37000, [11] = 43000, [12] = 49500, [13] = 56500, [14] = 64000,
    [15] = 72000, [16] = 80500, [17] = 89500, [18] = 99000, [19] = 109000,
    [20] = 119500, [21] = 130500, [22] = 141700, [23] = 153500, [24] = 165500,
    [25] = 178000, [26] = 192000, [27] = 207000, [28] = 222300, [29] = 238000,
    [30] = 255000, [31] = 275000, [32] = 298000, [33] = 323000, [34] = 350000,
    [35] = 380000, [36] = 420000, [37] = 463000, [38] = 510000, [39] = 560000,
    [40] = 612000, [41] = 666000, [42] = 724000, [43] = 784000, [44] = 846000,
    [45] = 910000, [46] = 976000, [47] = 1044000, [48] = 1114000, [49] = 1184000,
    [50] = 1254000, [51] = 1324000, [52] = 1404000, [53] = 1485000, [54] = 1567000,
    [55] = 1650000, [56] = 1734000, [57] = 1819000, [58] = 1905000, [59] = 1995000,
    [60] = 2086000, [61] = 2178000, [62] = 2271000, [63] = 2365000, [64] = 2460000,
    [65] = 2556000, [66] = 2656000, [67] = 2757000, [68] = 2859000, [69] = 2962000,
    [70] = 3066000, [71] = 3171000, [72] = 3277000, [73] = 3387000, [74] = 3498000,
    [75] = 3610000, [76] = 3723000, [77] = 3837000, [78] = 3952000, [79] = 4068000,
    [80] = 4188000, [81] = 4309000, [82] = 4431000, [83] = 4554000, [84] = 4678000,
    [85] = 4678000
}

local MAX_LEVEL = 85
local MAX_LEVEL_XP = LevelData[MAX_LEVEL]

-- Helper string padding to bypass VM dynamic specifier limit errors
local function pad_right(str, length)
    str = tostring(str or "")
    if #str >= length then
        return str
    end
    return str .. string.rep(" ", length - #str)
end

local function get_prestige_and_level(xp)
    local safe_xp = tonumber(xp) or 0
    local prestige = math.floor(safe_xp / MAX_LEVEL_XP)
    local remaining_xp = safe_xp % MAX_LEVEL_XP

    local current_level = 0
    for lvl = 0, MAX_LEVEL do
        local threshold = LevelData[lvl] or 0
        if remaining_xp >= threshold then
            current_level = lvl
        else
            break
        end
    end

    return prestige, current_level
end

local function format_num(val)
    local safe_val = tonumber(val) or 0
    local formatted = string.format("%.0f", math.floor(safe_val))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function format_currency(amount)
    return "$" .. format_num(amount)
end

local function format_use_time(total_seconds)
    local safe_sec = tonumber(total_seconds) or 0
    if safe_sec >= 3600 then
        local hours = math.floor(safe_sec / 3600)
        local mins = math.floor((safe_sec % 3600) / 60)
        local secs = math.floor(safe_sec % 60)
        return string.format("%dh %2dm %2ds", hours, mins, secs)
    elseif safe_sec >= 60 then
        local mins = math.floor(safe_sec / 60)
        local secs = math.floor(safe_sec % 60)
        return string.format("%2dm %2ds", mins, secs)
    else
        return string.format("%2ds", math.floor(safe_sec))
    end
end

local function format_duration_short(total_seconds)
    local safe_sec = tonumber(total_seconds) or 0
    local mins = math.floor(safe_sec / 60)
    local secs = math.floor(safe_sec % 60)
    if mins > 0 then
        return string.format("%dm %ds", mins, secs)
    else
        return string.format("%ds", secs)
    end
end

local function get_tester_status_string(achievements_table)
    if type(achievements_table) ~= "table" then return "None" end

    local is_predemo = false
    local is_alpha = false

    for key, data in pairs(achievements_table) do
        local key_str = string.lower(tostring(key))
        local name_str = ""
        if type(data) == "table" and (data.name or data.title) then
            name_str = string.lower(tostring(data.name or data.title))
        end

        local combined_identifier = key_str .. " " .. name_str

        local is_unlocked = false
        if type(data) == "boolean" then
            is_unlocked = data
        elseif type(data) == "number" then
            is_unlocked = (data > 0)
        elseif type(data) == "table" then
            local prog = tonumber(data.progress) or 0
            local max_prog = tonumber(data.max_progress) or 0
            is_unlocked = (data.unlocked == true or data.completed == true or data.unlocked_at ~= nil) or
                          (max_prog > 0 and prog >= max_prog)
        end

        if is_unlocked then
            if combined_identifier:find("predemo") then
                is_predemo = true
            end
            if combined_identifier:find("alpha") then
                is_alpha = true
            end
        end
    end

    if is_predemo and is_alpha then
        return "predemo tester, alpha tester"
    elseif is_predemo then
        return "predemo tester"
    elseif is_alpha then
        return "alpha tester"
    else
        return "None"
    end
end

-- Grid Formatting (Width: 154)
local ROW_FORMAT    = "%-20s %10s %11s %10.3f %9.2f%% %12s %8.2f %8.2f %14s %16s %9.2f%%  %-8.8s"
local HEADER_FORMAT = "%-20s %10s %11s %10s %10s %12s %8s %8s %14s %16s %10s  %-8.8s"
local GRID_WIDTH    = 154

local function print_overall_recap(player_name, player_stats, spendings_stats, achievements_stats, total_playtime_sec, total_rounds_fired_all, total_rounds_hit_all)
    local p = type(player_stats) == "table" and player_stats or {}
    local s = type(spendings_stats) == "table" and spendings_stats or {}

    local kills = tonumber(p.total_kills) or 0
    local deaths = tonumber(p.total_deaths) or 0
    local headshots = tonumber(p.total_headshots) or 0
    local wallbangs = tonumber(p.total_penetration_kills) or 0
    local explosive_kills = tonumber(p.total_explosive_kills) or 0
    local matches = tonumber(p.total_matches_played) or 0
    local points = tonumber(p.total_points_captured) or 0
    local dist_travelled = tonumber(p.distance_travelled) or 0
    local total_exp = tonumber(p.experience) or 0

    local prestige, calculated_level = get_prestige_and_level(total_exp)
    local status_str = get_tester_status_string(achievements_stats)

    local spent_attachments = tonumber(s.attachments) or 0
    local spent_weapons = tonumber(s.weapons) or 0
    local total_spent = spent_attachments + spent_weapons

    local pct_attachments = 0
    local pct_weapons = 0
    if total_spent > 0 then
        pct_attachments = (spent_attachments / total_spent) * 100
        pct_weapons = (spent_weapons / total_spent) * 100
    end

    local kdr = kills
    if deaths > 0 then kdr = kills / deaths end

    local hs_pct = 0
    if kills > 0 then hs_pct = (headshots / kills) * 100 end

    local he_pct = 0
    if kills > 0 then he_pct = (explosive_kills / kills) * 100 end

    local wall_pct = 0
    if kills > 0 then wall_pct = (wallbangs / kills) * 100 end

    local total_fired = tonumber(total_rounds_fired_all) or 0
    if total_fired <= 0 then total_fired = tonumber(p.total_shots_fired) or 0 end

    local overall_acc = 0
    if total_fired > 0 then overall_acc = (kills / total_fired) * 100 end

    local BAR_FULL = string.rep("=", GRID_WIDTH)

    local attach_str = string.format("%s (%.2f%%)", format_currency(spent_attachments), pct_attachments)
    local weapon_str = string.format("%s (%.2f%%)", format_currency(spent_weapons), pct_weapons)
    local header_title = "OVERALL ACCOUNT STATISTICS FOR " .. tostring(player_name)

    print(BAR_FULL)
    print(string.format("%" .. math.floor((GRID_WIDTH + string.len(header_title)) / 2) .. "s", header_title))
    print(string.rep(" ", GRID_WIDTH))
    
    local col_w = math.floor((GRID_WIDTH - 2) / 3)

    -- Column 1
    local r1_col1 = string.format(" %-19s%d", "Level:", calculated_level)
    local r2_col1 = string.format(" %-19s%s", "Kills:", format_num(kills))
    local r3_col1 = string.format(" %-19s%s", "Headshots:", format_num(headshots))
    local r4_col1 = string.format(" %-19s%.2f%%", "HS %:", hs_pct)
    local r5_col1 = string.format(" %-19s%s", "Matches Played:", format_num(matches))
    local r6_col1 = string.format(" %-19s%s", "Total Money Spent:", format_currency(total_spent))
    local r7_col1 = string.format(" %-19s%s", "Active Playtime:", format_use_time(total_playtime_sec))

    -- Column 2
    local r1_col2 = string.format("%-19s%d", "Prestige:", prestige)
    local r2_col2 = string.format("%-19s%s", "Deaths:", format_num(deaths))
    local r3_col2 = string.format("%-19s%s", "Wallbangs:", format_num(wallbangs))
    local r4_col2 = string.format("%-19s%.2f%%", "Wall %:", wall_pct)
    local r5_col2 = string.format("%-19s%s", "Objectives Cap:", format_num(points))
    local r6_col2 = string.format("%-19s%s", "On Attachments:", attach_str)
    local r7_col2 = string.format("%-19s%s", "Total Experience:", format_num(total_exp))

    -- Column 3
    local r1_col3 = string.format("%-19s%s", "Status:", status_str)
    local r2_col3 = string.format("%-19s%.5f", "KDR:", kdr)
    local r3_col3 = string.format("%-19s%s", "HE Kills:", format_num(explosive_kills))
    local r4_col3 = string.format("%-19s%.2f%%", "HE %:", he_pct)
    local r5_col3 = string.format("%-19s%.2f%%", "Accuracy:", overall_acc)
    local r6_col3 = string.format("%-19s%s", "On Weapons:", weapon_str)
    local r7_col3 = string.format("%-19s%s st", "Dist Travelled:", format_num(dist_travelled))

    print(pad_right(r1_col1, col_w) .. "| " .. pad_right(r1_col2, col_w) .. "| " .. r1_col3)
    print(pad_right(r2_col1, col_w) .. "| " .. pad_right(r2_col2, col_w) .. "| " .. r2_col3)
    print(pad_right(r3_col1, col_w) .. "| " .. pad_right(r3_col2, col_w) .. "| " .. r3_col3)
    print(pad_right(r4_col1, col_w) .. "| " .. pad_right(r4_col2, col_w) .. "| " .. r4_col3)
    print(pad_right(r5_col1, col_w) .. "| " .. pad_right(r5_col2, col_w) .. "| " .. r5_col3)
    print(pad_right(r6_col1, col_w) .. "| " .. pad_right(r6_col2, col_w) .. "| " .. r6_col3)
    print(pad_right(r7_col1, col_w) .. "| " .. pad_right(r7_col2, col_w) .. "| " .. r7_col3)

    print(BAR_FULL)

    -- Average Stats Panel
    local kpm = 0; if matches > 0 then kpm = kills / matches end
    local hpm = 0; if matches > 0 then hpm = headshots / matches end
    local opm = 0; if matches > 0 then opm = points / matches end
    local ppm = 0; if matches > 0 then ppm = total_exp / matches end
    local wpm = 0; if matches > 0 then wpm = wallbangs / matches end
    local epm = 0; if matches > 0 then epm = explosive_kills / matches end
    local dpm = 0; if matches > 0 then dpm = dist_travelled / matches end
    
    local total_minutes = (tonumber(total_playtime_sec) or 0) / 60
    local kills_per_min = 0
    local exp_per_min = 0
    if total_minutes > 0 then
        kills_per_min = kills / total_minutes
        exp_per_min = total_exp / total_minutes
    end
    
    local avg_lifespan_sec = (tonumber(total_playtime_sec) or 0)
    if deaths > 0 then avg_lifespan_sec = (tonumber(total_playtime_sec) or 0) / deaths end
    local avg_lifespan_str = format_duration_short(avg_lifespan_sec)

    local pace_title = "AVERAGE STATS PER MATCH AND MINUTE"
    print(string.format("%" .. math.floor((GRID_WIDTH + string.len(pace_title)) / 2) .. "s", pace_title))
    print(string.rep(" ", GRID_WIDTH))

    local num_cols = 5
    local p_col_width = math.floor((GRID_WIDTH - (num_cols - 1)) / num_cols)

    local p1_1 = string.format(" Kills / Match: %9.2f", kpm)
    local p1_2 = string.format("Kills / Min:    %9.3f", kills_per_min)
    local p1_3 = string.format("HS / Match:     %9.2f", hpm)
    local p1_4 = string.format("Obj. / Match:   %9.2f", opm)
    local p1_5 = string.format("Avg Lifespan:   %9s", avg_lifespan_str)

    local p2_1 = string.format(" Points / Match:%9s", format_num(ppm))
    local p2_2 = string.format("EXP / Min:      %9s", format_num(exp_per_min))
    local p2_3 = string.format("Wall / Match:   %9.2f", wpm)
    local p2_4 = string.format("HE / Match:     %9.2f", epm)
    local p2_5 = string.format("Dist / Match:   %6s st", format_num(dpm))

    print(pad_right(p1_1, p_col_width) .. "| " .. pad_right(p1_2, p_col_width) .. "| " .. pad_right(p1_3, p_col_width) .. "| " .. pad_right(p1_4, p_col_width) .. "| " .. p1_5)
    print(pad_right(p2_1, p_col_width) .. "| " .. pad_right(p2_2, p_col_width) .. "| " .. pad_right(p2_3, p_col_width) .. "| " .. pad_right(p2_4, p_col_width) .. "| " .. p2_5)
    print(BAR_FULL)
end

local function print_table_header()
    local pace_title = "DETAILED WEAPON STATS"
    print(string.format("%" .. math.floor((GRID_WIDTH + string.len(pace_title)) / 2) .. "s", pace_title))
    print(string.rep(" ", GRID_WIDTH))
    print(string.format(HEADER_FORMAT, "weapon", "kills", "deaths w/", "w-KDR", "% allK", "rds. ct", "K/Min", "RFpK", "weapon XP", "time used", "% allT", "type"))
    print(string.rep("-", GRID_WIDTH))
end

local function print_weapon_row(entry, total_kills_all, total_time_all)
    local data = entry.data or {}
    local kills = tonumber(data.kills) or 0
    local deaths_with = tonumber(data.deaths_with) or 0
    local rounds_fired = tonumber(data.rounds_fired) or 0
    local experience = tonumber(data.experience) or 0
    local use_time_sec = tonumber(data.use_time) or 0
    local use_time_str = format_use_time(use_time_sec)

    local kdr = kills
    if deaths_with > 0 then kdr = kills / deaths_with end

    local kills_pct = 0
    if total_kills_all > 0 then kills_pct = (kills / total_kills_all) * 100 end

    local time_pct = 0
    if total_time_all > 0 then time_pct = (use_time_sec / total_time_all) * 100 end

    local rfpk = rounds_fired
    if kills > 0 then rfpk = rounds_fired / kills end
    
    local use_time_mins = use_time_sec / 60
    local kpm = 0.0
    if use_time_mins > 0 then kpm = kills / use_time_mins end

    print(string.format(
        ROW_FORMAT, 
        tostring(entry.display_name), 
        format_num(kills), 
        format_num(deaths_with), 
        kdr, 
        kills_pct, 
        format_num(rounds_fired), 
        kpm,
        rfpk, 
        format_num(experience), 
        use_time_str, 
        time_pct, 
        tostring(entry.caliber_type)
    ))
end

local function print_total_row(weapon_list)
    local total_kills = 0
    local total_deaths_with = 0
    local total_rounds_fired = 0
    local total_experience = 0
    local total_use_time = 0

    for _, weapon in ipairs(weapon_list) do
        local data = weapon.data or {}
        total_kills = total_kills + (tonumber(data.kills) or 0)
        total_deaths_with = total_deaths_with + (tonumber(data.deaths_with) or 0)
        total_rounds_fired = total_rounds_fired + (tonumber(data.rounds_fired) or 0)
        total_experience = total_experience + (tonumber(data.experience) or 0)
        total_use_time = total_use_time + (tonumber(data.use_time) or 0)
    end

    local overall_kdr = total_kills
    if total_deaths_with > 0 then overall_kdr = total_kills / total_deaths_with end

    local overall_rfpk = total_rounds_fired
    if total_kills > 0 then overall_rfpk = total_rounds_fired / total_kills end
    
    local total_time_mins = total_use_time / 60
    local overall_kpm = 0.0
    if total_time_mins > 0 then overall_kpm = total_kills / total_time_mins end

    local total_kills_pct = 0.0
    if total_kills > 0 then total_kills_pct = 100.0 end

    local total_time_pct = 0.0
    if total_use_time > 0 then total_time_pct = 100.0 end

    local total_time_str = format_use_time(total_use_time)

    print(string.rep("-", GRID_WIDTH))
    print(string.format(
        ROW_FORMAT, 
        "TOTAL", 
        format_num(total_kills), 
        format_num(total_deaths_with), 
        overall_kdr, 
        total_kills_pct, 
        format_num(total_rounds_fired), 
        overall_kpm,
        overall_rfpk, 
        format_num(total_experience), 
        total_time_str, 
        total_time_pct, 
        ""
    ))
end

local function clone_weapon_data(data, time_seconds)
    local is_tbl = (type(data) == "table")
    return {
        attachment_stats = (is_tbl and type(data.attachment_stats) == "table" and data.attachment_stats) or {},
        kills = tonumber(is_tbl and data.kills) or 0,
        deaths_with = tonumber(is_tbl and data.deaths_with) or 0,
        experience = tonumber(is_tbl and data.experience) or 0,
        owned_attachments = (is_tbl and type(data.owned_attachments) == "table" and data.owned_attachments) or {},
        deaths_from = tonumber(is_tbl and data.deaths_from) or 0,
        rounds_fired = tonumber(is_tbl and data.rounds_fired) or 0,
        rounds_hit = tonumber(is_tbl and data.rounds_hit) or 0,
        owned_camo = (is_tbl and type(data.owned_camo) == "table" and data.owned_camo) or {},
        use_time = tonumber(time_seconds) or 0,
    }
end

local function get_processed_weapon_stats(player_obj)
    local profile_stats = {}
    if player_obj and type(player_obj.get_profile_stats) == "function" then
        profile_stats = player_obj.get_profile_stats() or {}
    end

    local raw_stats = type(profile_stats.weapon) == "table" and profile_stats.weapon or {}
    local player_stats = type(profile_stats.player) == "table" and profile_stats.player or {}
    local spendings_stats = type(profile_stats.spendings) == "table" and profile_stats.spendings or {}
    local achievements_stats = type(profile_stats.achievements) == "table" and profile_stats.achievements or {}
    local weapon_times = type(player_stats.weapon_use_time) == "table" and player_stats.weapon_use_time or {}
    
    local combined_stats = {}

    for weapon_name, data in pairs(raw_stats) do
        if not WEAPON_ALIASES[weapon_name] then
            local time_sec = tonumber(weapon_times[weapon_name]) or 0
            combined_stats[weapon_name] = clone_weapon_data(data, time_sec)
        end
    end

    for weapon_name, data in pairs(raw_stats) do
        local target_name = WEAPON_ALIASES[weapon_name]
        if target_name then
            if not combined_stats[target_name] then
                combined_stats[target_name] = {
                    attachment_stats = {}, kills = 0, deaths_with = 0,
                    experience = 0, owned_attachments = {}, deaths_from = 0,
                    rounds_fired = 0, rounds_hit = 0, owned_camo = {}, use_time = 0,
                }
            end

            local target = combined_stats[target_name]
            local legacy_time = tonumber(weapon_times[weapon_name]) or 0
            local is_tbl = (type(data) == "table")

            target.kills = (tonumber(target.kills) or 0) + (tonumber(is_tbl and data.kills) or 0)
            target.deaths_with = (tonumber(target.deaths_with) or 0) + (tonumber(is_tbl and data.deaths_with) or 0)
            target.deaths_from = (tonumber(target.deaths_from) or 0) + (tonumber(is_tbl and data.deaths_from) or 0)
            target.rounds_fired = (tonumber(target.rounds_fired) or 0) + (tonumber(is_tbl and data.rounds_fired) or 0)
            target.rounds_hit = (tonumber(target.rounds_hit) or 0) + (tonumber(is_tbl and data.rounds_hit) or 0)
            target.experience = (tonumber(target.experience) or 0) + (tonumber(is_tbl and data.experience) or 0)
            target.use_time = (tonumber(target.use_time) or 0) + legacy_time
        end
    end

    local overall_kills = tonumber(player_stats.total_kills) or 0
    local sum_weapon_kills = 0
    for _, w_data in pairs(combined_stats) do
        sum_weapon_kills = sum_weapon_kills + (tonumber(w_data.kills) or 0)
    end

    local missing_kills = overall_kills - sum_weapon_kills
    if missing_kills > 0 then
        if not combined_stats["Warhead"] then
            combined_stats["Warhead"] = {
                attachment_stats = {},
                kills = missing_kills,
                deaths_with = 0,
                experience = 0,
                owned_attachments = {},
                deaths_from = 0,
                rounds_fired = missing_kills,
                rounds_hit = missing_kills,
                owned_camo = {},
                use_time = 0,
            }
        else
            combined_stats["Warhead"].kills = (tonumber(combined_stats["Warhead"].kills) or 0) + missing_kills
        end
    end

    return combined_stats, player_stats, spendings_stats, achievements_stats
end

function print_filtered_weapon_stats_for_player(player_obj, filter)
    local player_name = (player_obj and player_obj.name) or "Unknown"
    
    local active_filter = filter or FILTER_TYPE
    local weapon_stats, player_stats, spendings_stats, achievements_stats = get_processed_weapon_stats(player_obj)
    local weapon_list = {}
    local total_kills_all = 0
    local total_time_all = 0
    local total_rounds_fired_all = 0
    local total_rounds_hit_all = 0

    for weapon_name, data in pairs(weapon_stats) do
        local caliber = WEAPON_INFO[weapon_name] or "Unknown"
        local display_name = WEAPON_DISPLAY_NAMES[weapon_name] or weapon_name
        
        local should_include = false
        if active_filter == "" then
            should_include = (caliber ~= "Unknown")
        else
            local lower_caliber = string.lower(tostring(caliber))
            local lower_filter = string.lower(tostring(active_filter))
            
            should_include = lower_caliber:find(lower_filter, 1, true) ~= nil 
                          or lower_filter:find(lower_caliber, 1, true) ~= nil
        end

        if should_include then
            table.insert(weapon_list, {
                name = weapon_name,
                display_name = display_name,
                caliber_type = caliber,
                data = data,
            })
            total_kills_all = total_kills_all + (tonumber(data.kills) or 0)
            total_time_all = total_time_all + (tonumber(data.use_time) or 0)
            total_rounds_fired_all = total_rounds_fired_all + (tonumber(data.rounds_fired) or 0)
            total_rounds_hit_all = total_rounds_hit_all + (tonumber(data.rounds_hit) or 0)
        end
    end

    print_overall_recap(player_name, player_stats, spendings_stats, achievements_stats, total_time_all, total_rounds_fired_all, total_rounds_hit_all)

    table.sort(weapon_list, function(a, b)
        local a_kills = tonumber(a.data and a.data.kills) or 0
        local b_kills = tonumber(b.data and b.data.kills) or 0
        if string.upper(tostring(SORT_BY)) == "TYPE" then
            if a.caliber_type == b.caliber_type then
                return a_kills > b_kills
            end
            return tostring(a.caliber_type) < tostring(b.caliber_type)
        else
            return a_kills > b_kills
        end
    end)

    print_table_header()
    for _, weapon in ipairs(weapon_list) do
        print_weapon_row(weapon, total_kills_all, total_time_all)
    end
    print_total_row(weapon_list)

    return weapon_list
end

if type(players) == "table" and type(players.get_all) == "function" then
    for _, plr in ipairs(players.get_all()) do
        if plr and type(plr.is_bot) == "function" and plr.is_bot() == false then
            print_filtered_weapon_stats_for_player(plr)
        end
    end
end
