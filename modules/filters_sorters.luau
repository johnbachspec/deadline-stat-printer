-- modules/filters_sorters.lua
-- OCP: filtering and sorting are expressed as strategy tables/functions.
-- To add a new sort mode or filter behavior, ADD an entry here rather
-- than editing an if/else chain buried in unrelated code.

local FilterSort = {}

-- Turns the combined weapon-stats table into a flat, sorted/filterable
-- list of {name, display_name, caliber_type, data} entries.
function FilterSort.build_weapon_list(combined_stats, weapon_data, filter_type)
    local list = {}
    local totals = {
        kills = 0,
        use_time = 0,
        rounds_fired = 0,
        rounds_hit = 0,
    }

    for weapon_name, data in pairs(combined_stats) do
        local caliber = weapon_data.caliber(weapon_name)
        local display_name = weapon_data.display_name(weapon_name)

        local should_include
        if filter_type == "" or filter_type == nil then
            should_include = (caliber ~= "Unknown")
        else
            local lower_caliber = string.lower(tostring(caliber))
            local lower_filter = string.lower(tostring(filter_type))
            should_include = lower_caliber:find(lower_filter, 1, true) ~= nil
                          or lower_filter:find(lower_caliber, 1, true) ~= nil
        end

        if should_include then
            table.insert(list, {
                name = weapon_name,
                display_name = display_name,
                caliber_type = caliber,
                data = data,
            })
            totals.kills = totals.kills + (tonumber(data.kills) or 0)
            totals.use_time = totals.use_time + (tonumber(data.use_time) or 0)
            totals.rounds_fired = totals.rounds_fired + (tonumber(data.rounds_fired) or 0)
            totals.rounds_hit = totals.rounds_hit + (tonumber(data.rounds_hit) or 0)
        end
    end

    return list, totals
end

-- Sort strategies: add a new key here to support a new SORT_BY value
-- without touching FilterSort.sort or any calling code.
FilterSort.SORT_STRATEGIES = {
    KILLS = function(list)
        table.sort(list, function(a, b)
            local a_kills = tonumber(a.data and a.data.kills) or 0
            local b_kills = tonumber(b.data and b.data.kills) or 0
            return a_kills > b_kills
        end)
    end,
    TYPE = function(list)
        table.sort(list, function(a, b)
            local a_kills = tonumber(a.data and a.data.kills) or 0
            local b_kills = tonumber(b.data and b.data.kills) or 0
            if a.caliber_type == b.caliber_type then
                return a_kills > b_kills
            end
            return tostring(a.caliber_type) < tostring(b.caliber_type)
        end)
    end,
}

function FilterSort.sort(list, sort_by)
    local strategy = FilterSort.SORT_STRATEGIES[string.upper(tostring(sort_by))]
        or FilterSort.SORT_STRATEGIES.KILLS
    strategy(list)
    return list
end

return FilterSort
