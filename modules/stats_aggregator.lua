-- modules/stats_aggregator.lua
-- SRP: turns raw profile_stats data into a combined per-weapon stats table
-- (merging legacy aliases, backfilling missing "Warhead" kills).
-- DIP: this module never touches a player object directly. main.lua reads
-- player_obj.get_profile_stats() and passes the plain data table in here.
-- That means this module can be unit-tested with a fake table and won't
-- break if the underlying player API changes shape.

local Aggregator = {}

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

-- weapon_data: an injected module implementing is_alias()/resolve_alias()
-- (see modules/weapon_data.lua). Passed as a parameter rather than
-- required directly here so a different weapon-data source can be
-- substituted without editing this file (DIP/OCP).
function Aggregator.combine_weapon_stats(profile_stats, weapon_data)
    local raw_stats = type(profile_stats.weapon) == "table" and profile_stats.weapon or {}
    local player_stats = type(profile_stats.player) == "table" and profile_stats.player or {}
    local weapon_times = type(player_stats.weapon_use_time) == "table" and player_stats.weapon_use_time or {}

    local combined_stats = {}

    for weapon_name, data in pairs(raw_stats) do
        if not weapon_data.is_alias(weapon_name) then
            local time_sec = tonumber(weapon_times[weapon_name]) or 0
            combined_stats[weapon_name] = clone_weapon_data(data, time_sec)
        end
    end

    for weapon_name, data in pairs(raw_stats) do
        local target_name = weapon_data.resolve_alias(weapon_name)
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

    return combined_stats
end

-- ISP: narrow accessors so a caller that only wants spendings or
-- achievements doesn't need to go through the full weapon-combining path.
function Aggregator.player_stats(profile_stats)
    return type(profile_stats.player) == "table" and profile_stats.player or {}
end

function Aggregator.spendings_stats(profile_stats)
    return type(profile_stats.spendings) == "table" and profile_stats.spendings or {}
end

function Aggregator.achievements_stats(profile_stats)
    return type(profile_stats.achievements) == "table" and profile_stats.achievements or {}
end

return Aggregator
