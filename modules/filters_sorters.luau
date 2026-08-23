-- modules/filters_sorters.luau
-- Turns the combined stats table into a flat, filtered, sorted list of rows.

local FilterSort = {}

-- filter_type:   "" -> everything except "Unknown"; otherwise a two-way
--                substring match against the weapon type (case-insensitive).
-- target_weapon: "" -> no restriction; otherwise only that weapon (raw id,
--                legacy id, or display name). Overrides filter_type.
-- Returns the row list and totals over the rows included.
function FilterSort.build_weapon_list(combined, weapon_data, filter_type, target_weapon)
    local target_id = (target_weapon or "") ~= "" and weapon_data.resolve(target_weapon) or nil
    local filter = string.lower(filter_type or "")

    local list = {}
    local totals = { kills = 0, use_time = 0, rounds_fired = 0 }

    for id, data in pairs(combined) do
        local weapon_type = weapon_data.type_of(id)
        local type_lower = string.lower(weapon_type)

        local include
        if target_id then
            include = (id == target_id)
        elseif filter == "" then
            include = (weapon_type ~= "Unknown")
        else
            include = type_lower:find(filter, 1, true) ~= nil or filter:find(type_lower, 1, true) ~= nil
        end

        if include then
            table.insert(list, {
                name = id,
                display_name = weapon_data.display_name(id),
                caliber_type = weapon_type,
                data = data,
            })
            totals.kills += data.kills
            totals.use_time += data.use_time
            totals.rounds_fired += data.rounds_fired
        end
    end

    return list, totals
end

local function by_kills_then_name(a, b)
    if a.data.kills ~= b.data.kills then return a.data.kills > b.data.kills end
    return a.display_name < b.display_name
end

FilterSort.SORT_STRATEGIES = {
    KILLS = by_kills_then_name,
    TYPE = function(a, b)
        if a.caliber_type ~= b.caliber_type then return a.caliber_type < b.caliber_type end
        return by_kills_then_name(a, b)
    end,
}

function FilterSort.sort(list, sort_by)
    table.sort(list, FilterSort.SORT_STRATEGIES[string.upper(sort_by or "")] or by_kills_then_name)
    return list
end

return FilterSort
