-- modules/attachment_aggregator.luau
-- Turns profile stats into one row per attachment: kills summed over every gun,
-- legacy attachment ids folded into their current id (attachment_data), legacy
-- gun ids folded into their current gun (weapon_data), and every gun it has kills
-- on, most first. by_gun regroups those rows into one list per gun.
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ('Fiu') that does not
-- accept Luau type annotations, so this file intentionally has none.

local AttachmentAggregator = {}

local function kills_of(data)
    if type(data) == "number" then
        return data
    elseif type(data) == "table" then
        local raw = data.kills
        if raw == nil then raw = data.kill_count end
        return tonumber(raw) or 0
    end
    return 0
end

local function by_kills_then_id(a, b)
    if a.kills ~= b.kills then return a.kills > b.kills end
    return a.id < b.id
end

-- { { id = gun, kills = n }, ... }, most kills first (ties by gun id).
local function sorted_guns(weapons)
    local guns = {}
    for gun, kills in pairs(weapons) do
        table.insert(guns, { id = gun, kills = kills })
    end
    table.sort(guns, by_kills_then_id)
    return guns
end

-- Pieces of one product become one row. Every piece is credited with the same
-- kills, so the row keeps the largest count rather than the sum. A product with
-- only one piece in the profile stays that piece's own row.
local function collapse_groups(totals, groups)
    local products = {}
    for att_id, info in pairs(totals) do
        local product = groups[att_id]
        if product then
            local p = products[product] or { kills = 0, weapons = {}, members = {} }
            products[product] = p
            p.kills = math.max(p.kills, info.kills)
            table.insert(p.members, att_id)
            for gun, kills in pairs(info.weapons) do
                p.weapons[gun] = math.max(p.weapons[gun] or 0, kills)
            end
        end
    end
    for product, p in pairs(products) do
        if #p.members > 1 then
            for _, att_id in ipairs(p.members) do totals[att_id] = nil end
            totals["group:" .. product] = { kills = p.kills, weapons = p.weapons, group = product, pieces = #p.members }
        end
    end
end

-- attachment_data: resolves legacy attachment ids. weapon_data: its ALIASES fold
-- legacy gun ids. groups (optional): piece id -> product name. gun (optional): a
-- current gun id (WeaponData.resolve); only kills on that gun are counted.
-- Returns { items = { { id, kills, top_gun, top_gun_kills, guns, group?, pieces? } sorted by kills },
--           legacy_merged = number of legacy attachment ids folded in }.
-- guns is every gun the attachment has kills on: { { id, kills }, ... }, most first.
function AttachmentAggregator.aggregate(profile_stats, attachment_data, weapon_data, groups, gun)
    local gun_aliases = (weapon_data and weapon_data.ALIASES) or {}
    local totals, legacy, legacy_merged = {}, {}, 0

    local function add(att_id, gun_id, kills)
        local current_gun = gun_aliases[gun_id] or gun_id
        if kills <= 0 or (gun and current_gun ~= gun) then return end
        local canon = attachment_data.resolve(att_id)
        if canon ~= att_id and not legacy[att_id] then
            legacy[att_id] = true
            legacy_merged = legacy_merged + 1
        end
        local bucket = totals[canon]
        if not bucket then
            bucket = { kills = 0, weapons = {} }
            totals[canon] = bucket
        end
        bucket.kills = bucket.kills + kills
        bucket.weapons[current_gun] = (bucket.weapons[current_gun] or 0) + kills
    end

    for gun_id, w_data in pairs((profile_stats and profile_stats.weapon) or {}) do
        local att_stats = type(w_data) == "table" and w_data.attachment_stats
        if type(att_stats) == "table" and next(att_stats) ~= nil then
            for att_id, data in pairs(att_stats) do
                add(att_id, gun_id, kills_of(data))
            end
        else
            -- No per-attachment stats: credit each saved build's kills to its attachments.
            local builds = (type(w_data) == "table" and w_data.custom_inventory) or {}
            for _, build in pairs(builds) do
                local kills = (type(build) == "table" and tonumber(build.kills)) or 0
                for _, att_id in pairs((type(build) == "table" and build.attachments) or {}) do
                    add(att_id, gun_id, kills)
                end
            end
        end
    end

    if groups then
        collapse_groups(totals, groups)
    end

    local items = {}
    for id, info in pairs(totals) do
        local guns = sorted_guns(info.weapons)
        local top = guns[1] or { id = "N/A", kills = 0 }
        table.insert(items, {
            id = id, kills = info.kills, top_gun = top.id, top_gun_kills = top.kills, guns = guns,
            group = info.group, pieces = info.pieces,
        })
    end
    table.sort(items, by_kills_then_id)

    return { items = items, legacy_merged = legacy_merged }
end

-- The same rows regrouped by gun: { { id = gun, kills = most kills of any one of
-- its attachments, items = { { item = row, kills = kills on this gun }, ... } }, ... },
-- guns and each gun's attachments most kills first. A gun's own kill count is not
-- in the attachment stats; its best attachment's kills are the nearest stand-in.
function AttachmentAggregator.by_gun(aggregated)
    local guns, list = {}, {}
    for _, item in ipairs(aggregated.items) do
        for _, g in ipairs(item.guns or {}) do
            local entry = guns[g.id]
            if not entry then
                entry = { id = g.id, kills = 0, items = {} }
                guns[g.id] = entry
                table.insert(list, entry)
            end
            entry.kills = math.max(entry.kills, g.kills)
            table.insert(entry.items, { item = item, kills = g.kills, id = item.id })
        end
    end
    for _, entry in ipairs(list) do
        table.sort(entry.items, by_kills_then_id)
    end
    table.sort(list, by_kills_then_id)
    return list
end

return AttachmentAggregator
