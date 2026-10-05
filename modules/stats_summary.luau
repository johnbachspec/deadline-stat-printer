-- modules/stats_summary.luau
-- The numbers the stat panel shows, worked out from a player's data: account totals,
-- percentages, per-match and per-minute averages, level and prestige, and each weapon
-- row's ratios. Plain numbers only; modules/renderer.luau formats and lays them out.
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ('Fiu') that does not
-- accept Luau type annotations, so this file intentionally has none.

local StatsSummary = {}

local function n(value)
    return tonumber(value) or 0
end

-- a / b when b > 0, otherwise default (0 when not given).
function StatsSummary.safe_div(a, b, default)
    local num, den = n(a), n(b)
    if den > 0 then
        return num / den
    end
    if default == nil then
        return 0
    end
    return default
end

-- (a / b) * 100, or 0 when b <= 0.
function StatsSummary.pct(a, b)
    return StatsSummary.safe_div(a, b, 0) * 100
end

local safe_div, pct = StatsSummary.safe_div, StatsSummary.pct

-- Profile achievements are { is_alpha_tester = bool, is_predemo_tester = bool }.
local function tester_tags(achievements)
    local ach = achievements or {}
    local tags = {}
    if ach.is_predemo_tester then table.insert(tags, "predemo tester") end
    if ach.is_alpha_tester then table.insert(tags, "alpha tester") end
    return tags
end

-- data = { player_stats, spendings, achievements, collection, account_totals }
-- (account_totals = { use_time, rounds_fired } over ALL weapons, so the summary does
-- not change with FILTER_TYPE). level_data: modules/level_data.luau.
function StatsSummary.account(data, level_data)
    local p = data.player_stats or {}
    local spendings = data.spendings or {}
    local totals = data.account_totals or {}

    local s = {
        kills = n(p.total_kills), deaths = n(p.total_deaths),
        headshots = n(p.total_headshots), wallbangs = n(p.total_penetration_kills), he_kills = n(p.total_explosive_kills),
        matches = n(p.total_matches_played), points = n(p.total_points_captured),
        distance = n(p.distance_travelled), xp = n(p.experience),
        alive_sec = n(totals.use_time), rounds = n(totals.rounds_fired),
        spent_attachments = n(spendings.attachments), spent_weapons = n(spendings.weapons),
        collection = data.collection or {},
        tester_tags = tester_tags(data.achievements),
    }
    s.alive_min = s.alive_sec / 60
    s.spent = s.spent_attachments + s.spent_weapons
    s.level, s.xp_to_next = level_data.get_level(s.xp)
    s.prestige, s.prestige_level = level_data.get_prestige(s.xp)

    s.kdr = safe_div(s.kills, s.deaths, s.kills)
    s.hs_pct, s.wall_pct, s.he_pct = pct(s.headshots, s.kills), pct(s.wallbangs, s.kills), pct(s.he_kills, s.kills)
    s.rounds_per_kill = safe_div(s.rounds, s.kills, s.rounds) -- the profile stores no hit counts, so no real accuracy
    s.attachments_pct, s.weapons_pct = pct(s.spent_attachments, s.spent), pct(s.spent_weapons, s.spent)

    s.kills_per_match, s.xp_per_match = safe_div(s.kills, s.matches), safe_div(s.xp, s.matches)
    s.kills_per_min, s.xp_per_min = safe_div(s.kills, s.alive_min), safe_div(s.xp, s.alive_min)
    s.hs_per_match, s.wall_per_match = safe_div(s.headshots, s.matches), safe_div(s.wallbangs, s.matches)
    s.points_per_match, s.he_per_match = safe_div(s.points, s.matches), safe_div(s.he_kills, s.matches)
    s.lifespan = safe_div(s.alive_sec, s.deaths, s.alive_sec)
    s.distance_per_match = safe_div(s.distance, s.matches)
    return s
end

-- One weapon row's numbers. d = the weapon's combined stats (stats_aggregator);
-- total_kills / total_time: over the weapons shown, for the share columns.
function StatsSummary.weapon(d, total_kills, total_time)
    return {
        kills = d.kills, deaths_with = d.deaths_with, deaths_from = d.deaths_from,
        rounds = d.rounds_fired, xp = d.experience, use_time = d.use_time,
        kdr = safe_div(d.kills, d.deaths_with, d.kills),
        kill_share = pct(d.kills, total_kills),
        kills_per_min = safe_div(d.kills, d.use_time / 60),
        rounds_per_kill = safe_div(d.rounds_fired, d.kills, d.rounds_fired),
        time_share = pct(d.use_time, total_time),
    }
end

return StatsSummary
