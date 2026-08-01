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
local WEAPON_DISPLAY_NAMES: {[string]: string} = {
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
local WEAPON_INFO: {[string]: string} = {
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

type weapon_data = {
    attachment_stats: {[string]: {experience: number, kills: number}},
    kills: number,
    deaths_with: number,
    experience: number,
    owned_attachments: {string},
    deaths_from: number,
    rounds_fired: number,
    rounds_hit: number?,
    owned_camo: {[string]: {string}},
    use_time: number,
}

type weapon_entry = {
    name: string,
    display_name: string,
    caliber_type: string,
    data: weapon_data,
}

local function format_num(val: number): string
    local formatted = string.format("%.0f", math.floor(val))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function format_currency(amount: number): string
    return "$" .. format_num(amount)
end

local function format_use_time(total_seconds: number): string
    if total_seconds >= 3600 then
        local hours = math.floor(total_seconds / 3600)
        local mins = math.floor((total_seconds % 3600) / 60)
        local secs = math.floor(total_seconds % 60)
        return string.format("%dh %2dm %2ds", hours, mins, secs)
    elseif total_seconds >= 60 then
        local mins = math.floor(total_seconds / 60)
        local secs = math.floor(total_seconds % 60)
        return string.format("%2dm %2ds", mins, secs)
    else
        return string.format("%2ds", math.floor(total_seconds))
    end
end

local function format_duration_short(total_seconds: number): string
    local mins = math.floor(total_seconds / 60)
    local secs = math.floor(total_seconds % 60)
    if mins > 0 then
        return string.format("%dm %ds", mins, secs)
    else
        return string.format("%ds", secs)
    end
end

local function get_tester_status_string(achievements_table: any): string
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
            is_unlocked = (data.unlocked == true or data.completed == true or data.unlocked_at ~= nil) or
                          (data.progress and data.max_progress and data.progress >= data.max_progress)
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

-- Strictly calibrated row and header formatting (Grid Width: 154)
-- Replaced w-Acc% (%9.2f%%) with KPM (%8.2f) and adjusted field padding to maintain exact grid width
local ROW_FORMAT    = "%-20s %10s %11s %10.3f %9.2f%% %12s %8.2f %8.2f %14s %16s %9.2f%%  %-8.8s"
local HEADER_FORMAT = "%-20s %10s %11s %10s %10s %12s %8s %8s %14s %16s %10s  %-8.8s"
local GRID_WIDTH    = 154

local function get_local_player_info()
    local p = nil
    if type(players.get_local_player) == "function" then
        p = players.get_local_player()
    elseif players.local_player then
        p = players.local_player
    end

    if p then
        local name = (type(p) == "table" and p.name) or tostring(p)
        return p, name
    end

    if type(players.get_all) == "function" then
        local all = players.get_all()
        if #all > 0 then
            local first_p = all[1]
            return first_p, (type(first_p) == "table" and first_p.name) or tostring(first_p)
        end
    end

    return nil, "Unknown"
end

local function print_overall_recap(player_name: string, player_stats: any, spendings_stats: any, achievements_stats: any, total_playtime_sec: number, total_rounds_fired_all: number, total_rounds_hit_all: number)
    local p = player_stats or {}
    local s = spendings_stats or {}

    local kills = p.total_kills or 0
    local deaths = p.total_deaths or 0
    local headshots = p.total_headshots or 0
    local wallbangs = p.total_penetration_kills or 0
    local explosive_kills = p.total_explosive_kills or 0
    local matches = p.total_matches_played or 0
    local points = p.total_points_captured or 0
    local dist_travelled = p.distance_travelled or 0
    local total_exp = p.experience or 0

    local status_str = get_tester_status_string(achievements_stats)

    local spent_attachments = s.attachments or 0
    local spent_weapons = s.weapons or 0
    local total_spent = spent_attachments + spent_weapons

    local pct_attachments = if total_spent > 0 then (spent_attachments / total_spent) * 100 else 0
    local pct_weapons = if total_spent > 0 then (spent_weapons / total_spent) * 100 else 0

    local kdr = if deaths > 0 then (kills / deaths) else kills
    local hs_pct = if kills > 0 then (headshots / kills) * 100 else 0
    local he_pct = if kills > 0 then (explosive_kills / kills) * 100 else 0
    local wall_pct = if kills > 0 then (wallbangs / kills) * 100 else 0

    local total_fired = if total_rounds_fired_all > 0 then total_rounds_fired_all else (p.total_shots_fired or 0)
    local overall_acc = if total_fired > 0 then (kills / total_fired) * 100 else 0

    local BAR_FULL = string.rep("=", GRID_WIDTH)

    local attach_str = string.format("%s (%.2f%%)", format_currency(spent_attachments), pct_attachments)
    local weapon_str = string.format("%s (%.2f%%)", format_currency(spent_weapons), pct_weapons)
    local header_title = "OVERALL ACCOUNT STATISTICS FOR " .. player_name

    print(BAR_FULL)
    print(string.format("%" .. math.floor((GRID_WIDTH + string.len(header_title)) / 2) .. "s", header_title))
    print(string.rep(" ", GRID_WIDTH))
    
    local col_w = math.floor((GRID_WIDTH - 2) / 3)
    local C_FORMAT = string.format("%%-%ds| %%-%ds| %%-%ds", col_w, col_w, col_w)

    -- Column 1
    local r1_col1 = string.format(" %-19s%s", "Kills:", format_num(kills))
    local r2_col1 = string.format(" %-19s%s", "Headshots:", format_num(headshots))
    local r3_col1 = string.format(" %-19s%.2f%%", "HS %:", hs_pct)
    local r4_col1 = string.format(" %-19s%s", "Matches Played:", format_num(matches))
    local r5_col1 = string.format(" %-19s%s", "Total Money Spent:", format_currency(total_spent))
    local r6_col1 = string.format(" %-19s%s", "Active Playtime:", format_use_time(total_playtime_sec))
    local r7_col1 = string.format(" %-19s%s", "Status:", status_str)

    -- Column 2 (Standardized Label Width: %-19s)
    local r1_col2 = string.format("%-19s%s", "Deaths:", format_num(deaths))
    local r2_col2 = string.format("%-19s%s", "Wallbangs:", format_num(wallbangs))
    local r3_col2 = string.format("%-19s%.2f%%", "Wall %:", wall_pct)
    local r4_col2 = string.format("%-19s%s", "Objectives Cap:", format_num(points))
    local r5_col2 = string.format("%-19s%s", "On Attachments:", attach_str)
    local r6_col2 = string.format("%-19s%s", "Total Experience:", format_num(total_exp))
    local r7_col2 = ""

    -- Column 3
    local r1_col3 = string.format("%-19s%.5f", "KDR:", kdr)
    local r2_col3 = string.format("%-19s%s", "HE Kills:", format_num(explosive_kills))
    local r3_col3 = string.format("%-19s%.2f%%", "HE %:", he_pct)
    local r4_col3 = string.format("%-19s%.2f%%", "Accuracy:", overall_acc)
    local r5_col3 = string.format("%-19s%s", "On Weapons:", weapon_str)
    local r6_col3 = string.format("%-19s%s st", "Dist Travelled:", format_num(dist_travelled))
    local r7_col3 = ""

    print(string.format(C_FORMAT, r1_col1, r1_col2, r1_col3))
    print(string.format(C_FORMAT, r2_col1, r2_col2, r2_col3))
    print(string.format(C_FORMAT, r3_col1, r3_col2, r3_col3))
    print(string.format(C_FORMAT, r4_col1, r4_col2, r4_col3))
    print(string.format(C_FORMAT, r5_col1, r5_col2, r5_col3))
    print(string.format(C_FORMAT, r6_col1, r6_col2, r6_col3))
    print(string.format(C_FORMAT, r7_col1, r7_col2, r7_col3))

    print(BAR_FULL)

    -- Average Stats Panel
    local kpm = if matches > 0 then (kills / matches) else 0
    local hpm = if matches > 0 then (headshots / matches) else 0
    local opm = if matches > 0 then (points / matches) else 0
    local ppm = if matches > 0 then (total_exp / matches) else 0
    
    local total_minutes = total_playtime_sec / 60
    local kills_per_min = if total_minutes > 0 then (kills / total_minutes) else 0
    local exp_per_min = if total_minutes > 0 then (total_exp / total_minutes) else 0
    
    local avg_lifespan_sec = if deaths > 0 then (total_playtime_sec / deaths) else total_playtime_sec
    local avg_lifespan_str = format_duration_short(avg_lifespan_sec)

    local pace_title = "AVERAGE STATS PER MATCH AND MINUTE"
    print(string.format("%" .. math.floor((GRID_WIDTH + string.len(pace_title)) / 2) .. "s", pace_title))
    print(string.rep(" ", GRID_WIDTH))

    local num_cols = 5
    local col_width = math.floor((GRID_WIDTH - (num_cols - 1)) / num_cols)
    local P_FORMAT = string.format("%%-%ds| %%-%ds| %%-%ds| %%-%ds| %%-%ds", col_width, col_width, col_width, col_width, col_width)

    local p1_1 = string.format(" Kills / Match: %9.2f", kpm)
    local p1_2 = string.format("Kills / Min:    %9.3f", kills_per_min)
    local p1_3 = string.format("HS / Match:     %9.2f", hpm)
    local p1_4 = string.format("Obj. / Match:   %9.2f", opm)
    local p1_5 = string.format("Avg Lifespan:   %9s", avg_lifespan_str)

    local p2_1 = string.format(" Points / Match:%9s", format_num(ppm))
    local p2_2 = string.format("EXP / Min:      %9s", format_num(exp_per_min))
    local p2_3 = string.format("Wall / Match:   %9.2f", if matches > 0 then (wallbangs / matches) else 0)
    local p2_4 = string.format("HE / Match:     %9.2f", if matches > 0 then (explosive_kills / matches) else 0)
    local p2_5 = string.format("Dist / Match:   %6s st", format_num(if matches > 0 then (dist_travelled / matches) else 0))

    print(string.format(P_FORMAT, p1_1, p1_2, p1_3, p1_4, p1_5))
    print(string.format(P_FORMAT, p2_1, p2_2, p2_3, p2_4, p2_5))
    print(BAR_FULL)
end

local function print_table_header()
    local pace_title = "DETAILED WEAPON STATS"
    print(string.format("%" .. math.floor((GRID_WIDTH + string.len(pace_title)) / 2) .. "s", pace_title))
    print(string.rep(" ", GRID_WIDTH))
    print(string.format(HEADER_FORMAT, "weapon", "kills", "deaths w/", "w-KDR", "% allK", "rds. ct", "K/Min", "RFpK", "weapon XP", "time used", "% allT", "type"))
    print(string.rep("-", GRID_WIDTH))
end

local function print_weapon_row(entry: weapon_entry, total_kills_all: number, total_time_all: number)
    local data = entry.data
    local kills = data.kills or 0
    local deaths_with = data.deaths_with or 0
    local rounds_fired = data.rounds_fired or 0
    local experience = data.experience or 0
    local use_time_sec = data.use_time or 0
    local use_time_str = format_use_time(use_time_sec)

    local kdr = if deaths_with > 0 then (kills / deaths_with) else kills
    local kills_pct = if total_kills_all > 0 then ((kills / total_kills_all) * 100) else 0
    local time_pct = if total_time_all > 0 then ((use_time_sec / total_time_all) * 100) else 0
    local rfpk = if kills > 0 then (rounds_fired / kills) else rounds_fired
    
    local use_time_mins = use_time_sec / 60
    local kpm = if use_time_mins > 0 then (kills / use_time_mins) else 0.0

    print(string.format(
        ROW_FORMAT, 
        entry.display_name, 
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
        entry.caliber_type
    ))
end

local function print_total_row(weapon_list: {weapon_entry})
    local total_kills = 0
    local total_deaths_with = 0
    local total_rounds_fired = 0
    local total_experience = 0
    local total_use_time = 0

    for _, weapon in ipairs(weapon_list) do
        local data = weapon.data
        total_kills += (data.kills or 0)
        total_deaths_with += (data.deaths_with or 0)
        total_rounds_fired += (data.rounds_fired or 0)
        total_experience += (data.experience or 0)
        total_use_time += (data.use_time or 0)
    end

    local overall_kdr = if total_deaths_with > 0 then (total_kills / total_deaths_with) else total_kills
    local overall_rfpk = if total_kills > 0 then (total_rounds_fired / total_kills) else total_rounds_fired
    
    local total_time_mins = total_use_time / 60
    local overall_kpm = if total_time_mins > 0 then (total_kills / total_time_mins) else 0.0

    local total_kills_pct = if total_kills > 0 then 100.0 else 0.0
    local total_time_pct = if total_use_time > 0 then 100.0 else 0.0
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

local function clone_weapon_data(data: weapon_data, time_seconds: number): weapon_data
    return {
        attachment_stats = data.attachment_stats,
        kills = data.kills or 0,
        deaths_with = data.deaths_with or 0,
        experience = data.experience or 0,
        owned_attachments = data.owned_attachments,
        deaths_from = data.deaths_from or 0,
        rounds_fired = data.rounds_fired or 0,
        rounds_hit = data.rounds_hit or 0,
        owned_camo = data.owned_camo,
        use_time = time_seconds or 0,
    }
end

local function get_processed_weapon_stats(player_obj: any)
    local profile_stats = player_obj.get_profile_stats()
    local raw_stats = profile_stats.weapon or {}
    local player_stats = profile_stats.player or {}
    local spendings_stats = profile_stats.spendings or {}
    local achievements_stats = profile_stats.achievements or {}
    local weapon_times = player_stats.weapon_use_time or {}
    
    local combined_stats: {[string]: weapon_data} = {}

    for weapon_name, data in pairs(raw_stats) do
        if not WEAPON_ALIASES[weapon_name] then
            local time_sec = weapon_times[weapon_name] or 0
            combined_stats[weapon_name] = clone_weapon_data(data :: weapon_data, time_sec)
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
            local legacy = data :: weapon_data
            local legacy_time = weapon_times[weapon_name] or 0

            target.kills = (target.kills or 0) + (legacy.kills or 0)
            target.deaths_with = (target.deaths_with or 0) + (legacy.deaths_with or 0)
            target.deaths_from = (target.deaths_from or 0) + (legacy.deaths_from or 0)
            target.rounds_fired = (target.rounds_fired or 0) + (legacy.rounds_fired or 0)
            target.rounds_hit = (target.rounds_hit or 0) + (legacy.rounds_hit or 0)
            target.experience = (target.experience or 0) + (legacy.experience or 0)
            target.use_time = (target.use_time or 0) + legacy_time
        end
    end

    local overall_kills = player_stats.total_kills or 0
    local sum_weapon_kills = 0
    for _, w_data in pairs(combined_stats) do
        sum_weapon_kills += (w_data.kills or 0)
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
            combined_stats["Warhead"].kills += missing_kills
        end
    end

    return combined_stats, player_stats, spendings_stats, achievements_stats
end

function print_filtered_weapon_stats(filter: string?)
    local player_obj, player_name = get_local_player_info()
    if not player_obj then
        print("Error: Could not locate invoking player instance.")
        return
    end

    local active_filter = filter or FILTER_TYPE
    local weapon_stats, player_stats, spendings_stats, achievements_stats = get_processed_weapon_stats(player_obj)
    local weapon_list: {weapon_entry} = {}
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
            local lower_caliber = string.lower(caliber)
            local lower_filter = string.lower(active_filter)
            
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
            total_kills_all += (data.kills or 0)
            total_time_all += (data.use_time or 0)
            total_rounds_fired_all += (data.rounds_fired or 0)
            total_rounds_hit_all += (data.rounds_hit or 0)
        end
    end

    print_overall_recap(player_name, player_stats, spendings_stats, achievements_stats, total_time_all, total_rounds_fired_all, total_rounds_hit_all)

    table.sort(weapon_list, function(a, b)
        if string.upper(SORT_BY) == "TYPE" then
            if a.caliber_type == b.caliber_type then
                return (a.data.kills or 0) > (b.data.kills or 0)
            end
            return a.caliber_type < b.caliber_type
        else
            return (a.data.kills or 0) > (b.data.kills or 0)
        end
    end)

    print_table_header()
    for _, weapon in ipairs(weapon_list) do
        print_weapon_row(weapon, total_kills_all, total_time_all)
    end
    print_total_row(weapon_list)

    return weapon_list
end

print_filtered_weapon_stats()
