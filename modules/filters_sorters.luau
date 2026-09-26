--!strict
-- modules/filters_sorters.luau
-- Turns the combined stats table into a flat, filtered, sorted list of rows.

local FilterSort = {}

export type WeaponStats = {
    kills: number,
    deaths_with: number,
    deaths_from: number,
    experience: number,
    rounds_fired: number,
    use_time: number,
}

export type WeaponRow = {
    name: string,
    display_name: string,
    caliber_type: string,
    data: WeaponStats,
}

export type TableTotals = {
    kills: number,
    use_time: number,
    rounds_fired: number,
}

-- Checks if a weapon caliber matches the filter query.
-- Matches if weapon_type starts with or contains the filter string (case-insensitive).
local function matches_type(weapon_type: string, filter_lower: string): boolean
    local type_lower = string.lower(weapon_type)
    return type_lower:find(filter_lower, 1, true) ~= nil
end

-- filter_type:   "" -> everything except "Unknown"; otherwise a substring
--                match against the weapon type (case-insensitive).
-- target_weapon: "" -> no restriction; otherwise only that weapon (raw id,
--                legacy id, or display name). Overrides filter_type.
-- Returns the row list and totals over the rows included.
function FilterSort.build_weapon_list(
    combined: { [string]: WeaponStats },
    weapon_data: any,
    filter_type: string?,
    target_weapon: string?
): ({ WeaponRow }, TableTotals)
    local target_id = (target_weapon or "") ~= "" and weapon_data.resolve(target_weapon) or nil
    local filter = string.lower(filter_type or "")

    local list: { WeaponRow } = {}
    local totals: TableTotals = { kills = 0, use_time = 0, rounds_fired = 0 }

    for id, data in pairs(combined) do
        local weapon_type = weapon_data.type_of(id)

        local include: boolean
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
            totals.kills += data.kills
            totals.use_time += data.use_time
            totals.rounds_fired += data.rounds_fired
        end
    end

    return list, totals
end

local function by_kills_then_name(a: WeaponRow, b: WeaponRow): boolean
    if a.data.kills ~= b.data.kills then
        return a.data.kills > b.data.kills
    end
    return a.display_name < b.display_name
end

FilterSort.SORT_STRATEGIES = {
    KILLS = by_kills_then_name,
    TYPE = function(a: WeaponRow, b: WeaponRow): boolean
        if a.caliber_type ~= b.caliber_type then
            return a.caliber_type < b.caliber_type
        end
        return by_kills_then_name(a, b)
    end,
}

function FilterSort.sort(list: { WeaponRow }, sort_by: string?): { WeaponRow }
    local key = string.upper(sort_by or "")
    local comparator = FilterSort.SORT_STRATEGIES[key] or by_kills_then_name
    table.sort(list, comparator)
    return list
end

return FilterSort
