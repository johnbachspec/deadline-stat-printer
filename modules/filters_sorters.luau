-- modules/filters_sorters.luau
-- Turns the combined stats table into a flat, filtered, sorted list of rows.
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ("Fiu") that does not
-- accept Luau type annotations, so this file intentionally has none.

local FilterSort = {}

-- Checks if a weapon caliber matches the filter query.
-- Matches if weapon_type starts with or contains the filter string (case-insensitive).
-- Dots are ignored, so "5.56" and ".308" (as the weapon table shows them) match "556" and "308".
local function matches_type(weapon_type, filter_lower)
    local type_lower = string.lower(weapon_type)
    return type_lower:find((filter_lower:gsub("%.", "")), 1, true) ~= nil
end

-- filter_type:   "" -> everything except "Unknown"; otherwise a substring
--                match against the weapon type (case-insensitive).
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

        local include
        if target_id then
            include = (id == target_id)
        elseif filter == "" then
            include = (weapon_type ~= "Unknown")
        else
            include = matches_type(weapon_type, filter)
        end

        if include then
            table.insert(list, {
                name = id,
                display_name = weapon_data.display_name(id),
                caliber_type = weapon_type,
                data = data,
            })
            totals.kills = totals.kills + data.kills
            totals.use_time = totals.use_time + data.use_time
            totals.rounds_fired = totals.rounds_fired + data.rounds_fired
        end
    end

    return list, totals
end

local function by_kills_then_name(a, b)
    if a.data.kills ~= b.data.kills then
        return a.data.kills > b.data.kills
    end
    return a.display_name < b.display_name
end

FilterSort.SORT_STRATEGIES = {
    KILLS = by_kills_then_name,
    TYPE = function(a, b)
        if a.caliber_type ~= b.caliber_type then
            return a.caliber_type < b.caliber_type
        end
        return by_kills_then_name(a, b)
    end,
}

function FilterSort.sort(list, sort_by)
    local key = string.upper(sort_by or "")
    local comparator = FilterSort.SORT_STRATEGIES[key] or by_kills_then_name
    table.sort(list, comparator)
    return list
end

return FilterSort
