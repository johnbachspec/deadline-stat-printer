-- modules/stats_aggregator.luau
-- Turns raw profile statistics into one combined per-weapon table:
-- merges legacy aliases, attaches use time, and adds a row for kills the
-- game never attributed to a weapon.
--
-- Profile weapon entries have: kills, deaths_with, deaths_from, experience,
-- rounds_fired (plus attachment/camo tables). There is no hit count.
-- deaths_with is incremented for EVERY weapon carried at death (all slots),
-- not just the equipped one.

local Aggregator = {}

local FIELDS = { "kills", "deaths_with", "deaths_from", "experience", "rounds_fired" }

local function empty()
    return { kills = 0, deaths_with = 0, deaths_from = 0, experience = 0, rounds_fired = 0, use_time = 0 }
end

local function add_into(target, data, use_time)
    for _, field in ipairs(FIELDS) do
        target[field] = target[field] + (tonumber(type(data) == "table" and data[field]) or 0)
    end
    target.use_time = target.use_time + (tonumber(use_time) or 0)
end

function Aggregator.combine_weapon_stats(profile_stats, weapon_data)
    local raw_stats = profile_stats.weapon or {}
    local player_stats = profile_stats.player or {}
    local use_times = player_stats.weapon_use_time or {}

    local combined = {}
    local function row(id)
        combined[id] = combined[id] or empty()
        return combined[id]
    end

    for id, data in pairs(raw_stats) do
        add_into(row(weapon_data.ALIASES[id] or id), data, use_times[id])
    end
    -- Items with use time but no stats entry (e.g. a smoke never carried at death).
    for id, seconds in pairs(use_times) do
        if not raw_stats[id] then add_into(row(weapon_data.ALIASES[id] or id), nil, seconds) end
    end

    local attributed = 0
    for _, data in pairs(combined) do attributed = attributed + data.kills end
    local missing = (tonumber(player_stats.total_kills) or 0) - attributed
    if missing > 0 then
        row(weapon_data.UNATTRIBUTED_ID).kills += missing
    end

    return combined
end

-- Totals across ALL weapons, independent of any table filter.
function Aggregator.account_totals(combined)
    local totals = { use_time = 0, rounds_fired = 0 }
    for _, data in pairs(combined) do
        totals.use_time += data.use_time
        totals.rounds_fired += data.rounds_fired
    end
    return totals
end

return Aggregator
