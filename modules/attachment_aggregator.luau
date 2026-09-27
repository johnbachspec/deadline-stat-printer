-- modules/attachment_aggregator.luau
-- Pure statistical aggregation of attachment usage and kills across player weapon profiles.
-- Single Responsibility: Extracts raw attachment statistics from profile stats,
-- maps attachment IDs to canonical forms via AttachmentData, accumulates total kills,
-- and determines the top attributing weapon with deterministic tie-breaking.
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ('Fiu') that does not
-- accept Luau type annotations, so this file intentionally has none.

local AttachmentAggregator = {}

function AttachmentAggregator.aggregate(profile_stats, attachment_data, weapon_data)
    local raw_weapons = (profile_stats and profile_stats.weapon) or {}
    local attachment_totals = {}
    local legacy_merged = 0
    local merged_legacy_ids = {}

    local resolve_fn = (attachment_data and attachment_data.resolve) or function(id) return id end
    local gun_aliases = (weapon_data and weapon_data.ALIASES) or {}

    local function add_kill_record(att_id, weapon_id, kills)
        if not kills or kills <= 0 then return end
        local canonical_id = resolve_fn(att_id)
        if canonical_id ~= att_id and not merged_legacy_ids[att_id] then
            merged_legacy_ids[att_id] = true
            legacy_merged = legacy_merged + 1
        end

        local bucket = attachment_totals[canonical_id]
        if not bucket then
            bucket = { kills = 0, weapons = {} }
            attachment_totals[canonical_id] = bucket
        end
        bucket.kills = bucket.kills + kills

        local canonical_gun = gun_aliases[weapon_id] or weapon_id
        bucket.weapons[canonical_gun] = (bucket.weapons[canonical_gun] or 0) + kills
    end

    for weapon_id, w_data in pairs(raw_weapons) do
        local att_stats = (type(w_data) == "table" and w_data.attachment_stats) or {}
        local found_att_stats = false

        for att_id, data in pairs(att_stats) do
            found_att_stats = true
            local kills = 0
            if type(data) == "table" then
                kills = tonumber(data.kills or data.kill_count or 0) or 0
            elseif type(data) == "number" then
                kills = data
            end
            add_kill_record(att_id, weapon_id, kills)
        end

        -- Fallback: check custom_inventory if attachment_stats was not present
        if not found_att_stats then
            local custom_inv = (type(w_data) == "table" and w_data.custom_inventory) or {}
            for _, build in pairs(custom_inv) do
                local att_map = (type(build) == "table" and build.attachments) or {}
                local kills = (type(build) == "table" and tonumber(build.kills)) or 0
                for _, att_id in pairs(att_map) do
                    add_kill_record(att_id, weapon_id, kills)
                end
            end
        end
    end

    local sorted = {}
    local total_attachment_kills = 0
    for att_id, info in pairs(attachment_totals) do
        local top_gun = "N/A"
        local top_gun_kills = 0
        for g_id, g_kills in pairs(info.weapons) do
            -- Ties break toward the lexicographically smallest gun for deterministic output
            if g_kills > top_gun_kills or (g_kills == top_gun_kills and g_id < top_gun) then
                top_gun = g_id
                top_gun_kills = g_kills
            end
        end

        total_attachment_kills = total_attachment_kills + info.kills
        table.insert(sorted, {
            id = att_id,
            kills = info.kills,
            top_gun = top_gun,
            top_gun_kills = top_gun_kills,
        })
    end

    table.sort(sorted, function(a, b)
        if a.kills ~= b.kills then
            return a.kills > b.kills
        end
        return a.id < b.id
    end)

    return {
        items = sorted,
        legacy_merged = legacy_merged,
        total_attachments = #sorted,
        total_kills = total_attachment_kills,
    }
end

return AttachmentAggregator
