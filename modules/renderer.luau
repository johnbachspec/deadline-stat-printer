-- modules/renderer.luau
-- SRP: this module's only job is turning already-computed numbers into
-- printed grid output. It does no stats math beyond simple ratios/percents
-- derived from numbers it's handed, and no data lookups of its own.
-- DIP: formatters/level_data/achievements are injected via Renderer.new(),
-- so the renderer never requires them itself -- swap in different
-- implementations (e.g. a test double, or a compact-mode formatter)
-- without touching this file.

local Renderer = {}
Renderer.__index = Renderer

local ROW_FORMAT    = "%-20s %10s %11s %10.3f %9.2f%% %12s %8.2f %8.2f %14s %16s %9.2f%%  %-8.8s"
local HEADER_FORMAT = "%-20s %10s %11s %10s %10s %12s %8s %8s %14s %16s %10s  %-8.8s"
local GRID_WIDTH    = 154

-- deps = { formatters = ..., level_data = ..., achievements = ... }
function Renderer.new(deps)
    local self = setmetatable({}, Renderer)
    self.fmt = deps.formatters
    self.level_data = deps.level_data
    self.achievements = deps.achievements
    return self
end

function Renderer:print_overall_recap(player_name, player_stats, spendings_stats, achievements_stats, total_playtime_sec, total_rounds_fired_all)
    local fmt = self.fmt
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

    local prestige, calculated_level = self.level_data.get_prestige_and_level(total_exp)
    local status_str = self.achievements.get_tester_status_string(achievements_stats)

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

    local attach_str = string.format("%s (%.2f%%)", fmt.format_currency(spent_attachments), pct_attachments)
    local weapon_str = string.format("%s (%.2f%%)", fmt.format_currency(spent_weapons), pct_weapons)
    local header_title = "OVERALL ACCOUNT STATISTICS FOR " .. tostring(player_name)

    print(BAR_FULL)
    print(fmt.center_text(header_title, GRID_WIDTH))
    print(string.rep(" ", GRID_WIDTH))

    local col_w = math.floor((GRID_WIDTH - 2) / 3)

    local r1_col1 = string.format(" %-19s%d", "Level:", calculated_level)
    local r2_col1 = string.format(" %-19s%s", "Kills:", fmt.format_num(kills))
    local r3_col1 = string.format(" %-19s%s", "Headshots:", fmt.format_num(headshots))
    local r4_col1 = string.format(" %-19s%.2f%%", "HS %:", hs_pct)
    local r5_col1 = string.format(" %-19s%s", "Matches Played:", fmt.format_num(matches))
    local r6_col1 = string.format(" %-19s%s", "Total Money Spent:", fmt.format_currency(total_spent))
    local r7_col1 = string.format(" %-19s%s", "Active Playtime:", fmt.format_use_time(total_playtime_sec))

    local r1_col2 = string.format("%-19s%d", "Prestige:", prestige)
    local r2_col2 = string.format("%-19s%s", "Deaths:", fmt.format_num(deaths))
    local r3_col2 = string.format("%-19s%s", "Wallbangs:", fmt.format_num(wallbangs))
    local r4_col2 = string.format("%-19s%.2f%%", "Wall %:", wall_pct)
    local r5_col2 = string.format("%-19s%s", "Objectives Cap:", fmt.format_num(points))
    local r6_col2 = string.format("%-19s%s", "On Attachments:", attach_str)
    local r7_col2 = string.format("%-19s%s", "Total Experience:", fmt.format_num(total_exp))

    local r1_col3 = string.format("%-19s%s", "Status:", status_str)
    local r2_col3 = string.format("%-19s%.5f", "KDR:", kdr)
    local r3_col3 = string.format("%-19s%s", "HE Kills:", fmt.format_num(explosive_kills))
    local r4_col3 = string.format("%-19s%.2f%%", "HE %:", he_pct)
    local r5_col3 = string.format("%-19s%.2f%%", "Accuracy:", overall_acc)
    local r6_col3 = string.format("%-19s%s", "On Weapons:", weapon_str)
    local r7_col3 = string.format("%-19s%s st", "Dist Travelled:", fmt.format_num(dist_travelled))

    print(fmt.pad_right(r1_col1, col_w) .. "| " .. fmt.pad_right(r1_col2, col_w) .. "| " .. r1_col3)
    print(fmt.pad_right(r2_col1, col_w) .. "| " .. fmt.pad_right(r2_col2, col_w) .. "| " .. r2_col3)
    print(fmt.pad_right(r3_col1, col_w) .. "| " .. fmt.pad_right(r3_col2, col_w) .. "| " .. r3_col3)
    print(fmt.pad_right(r4_col1, col_w) .. "| " .. fmt.pad_right(r4_col2, col_w) .. "| " .. r4_col3)
    print(fmt.pad_right(r5_col1, col_w) .. "| " .. fmt.pad_right(r5_col2, col_w) .. "| " .. r5_col3)
    print(fmt.pad_right(r6_col1, col_w) .. "| " .. fmt.pad_right(r6_col2, col_w) .. "| " .. r6_col3)
    print(fmt.pad_right(r7_col1, col_w) .. "| " .. fmt.pad_right(r7_col2, col_w) .. "| " .. r7_col3)

    print(BAR_FULL)

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
    local avg_lifespan_str = fmt.format_duration_short(avg_lifespan_sec)

    local pace_title = "AVERAGE STATS PER MATCH AND MINUTE"
    print(fmt.center_text(pace_title, GRID_WIDTH))
    print(string.rep(" ", GRID_WIDTH))

    local num_cols = 5
    local p_col_width = math.floor((GRID_WIDTH - (num_cols - 1)) / num_cols)

    local p1_1 = string.format(" Kills / Match: %9.2f", kpm)
    local p1_2 = string.format("Kills / Min:    %9.3f", kills_per_min)
    local p1_3 = string.format("HS / Match:     %9.2f", hpm)
    local p1_4 = string.format("Obj. / Match:   %9.2f", opm)
    local p1_5 = string.format("Avg Lifespan:   %9s", avg_lifespan_str)

    local p2_1 = string.format(" Points / Match:%9s", fmt.format_num(ppm))
    local p2_2 = string.format("EXP / Min:      %9s", fmt.format_num(exp_per_min))
    local p2_3 = string.format("Wall / Match:   %9.2f", wpm)
    local p2_4 = string.format("HE / Match:     %9.2f", epm)
    local p2_5 = string.format("Dist / Match:   %6s st", fmt.format_num(dpm))

    print(fmt.pad_right(p1_1, p_col_width) .. "| " .. fmt.pad_right(p1_2, p_col_width) .. "| " .. fmt.pad_right(p1_3, p_col_width) .. "| " .. fmt.pad_right(p1_4, p_col_width) .. "| " .. p1_5)
    print(fmt.pad_right(p2_1, p_col_width) .. "| " .. fmt.pad_right(p2_2, p_col_width) .. "| " .. fmt.pad_right(p2_3, p_col_width) .. "| " .. fmt.pad_right(p2_4, p_col_width) .. "| " .. p2_5)
    print(BAR_FULL)
end

function Renderer:print_table_header()
    local pace_title = "DETAILED WEAPON STATS"
    print(self.fmt.center_text(pace_title, GRID_WIDTH))
    print(string.rep(" ", GRID_WIDTH))
    print(string.format(HEADER_FORMAT, "weapon", "kills", "deaths w/", "w-KDR", "% allK", "rds. ct", "K/Min", "RFpK", "weapon XP", "time used", "% allT", "type"))
    print(string.rep("-", GRID_WIDTH))
end

function Renderer:print_weapon_row(entry, total_kills_all, total_time_all)
    local fmt = self.fmt
    local data = entry.data or {}
    local kills = tonumber(data.kills) or 0
    local deaths_with = tonumber(data.deaths_with) or 0
    local rounds_fired = tonumber(data.rounds_fired) or 0
    local experience = tonumber(data.experience) or 0
    local use_time_sec = tonumber(data.use_time) or 0
    local use_time_str = fmt.format_use_time(use_time_sec)

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
        fmt.format_num(kills),
        fmt.format_num(deaths_with),
        kdr,
        kills_pct,
        fmt.format_num(rounds_fired),
        kpm,
        rfpk,
        fmt.format_num(experience),
        use_time_str,
        time_pct,
        tostring(entry.caliber_type)
    ))
end

function Renderer:print_total_row(weapon_list)
    local fmt = self.fmt
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

    local total_time_str = fmt.format_use_time(total_use_time)

    print(string.rep("-", GRID_WIDTH))
    print(string.format(
        ROW_FORMAT,
        "TOTAL",
        fmt.format_num(total_kills),
        fmt.format_num(total_deaths_with),
        overall_kdr,
        total_kills_pct,
        fmt.format_num(total_rounds_fired),
        overall_kpm,
        overall_rfpk,
        fmt.format_num(total_experience),
        total_time_str,
        total_time_pct,
        ""
    ))
end

-- High-level entry point: prints the full report for one player given
-- already-aggregated/filtered/sorted data. This is the only function
-- main.lua needs to call per player.
function Renderer:print_report(player_name, player_stats, spendings_stats, achievements_stats, weapon_list, totals)
    self:print_overall_recap(player_name, player_stats, spendings_stats, achievements_stats, totals.use_time, totals.rounds_fired)
    self:print_table_header()
    for _, weapon in ipairs(weapon_list) do
        self:print_weapon_row(weapon, totals.kills, totals.use_time)
    end
    self:print_total_row(weapon_list)
end

return Renderer
