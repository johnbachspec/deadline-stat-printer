-- print-attachment-stats.luau
-- Prints aggregated attachment statistics (kills and top weapon) across all weapons.

local my_player = nil
for _, plr in ipairs(players.get_all()) do
    if not plr:is_bot() then my_player = plr break end
end

if my_player and type(my_player.get_profile_stats) == "function" then
    local stats = my_player.get_profile_stats() or {}
    local weapons_table = stats.weapon or {}

    -- Aggregator: [attachment_id] = { kills = X, weapons = { [gun_id] = kills } }
    local attachment_totals = {}

    for weapon_id, weapon_data in pairs(weapons_table) do
        local att_stats = weapon_data.attachment_stats or {}
        
        for att_id, data in pairs(att_stats) do
            local kills = 0
            if type(data) == "table" then
                kills = tonumber(data.kills or data.kill_count or 0) or 0
            elseif type(data) == "number" then
                kills = data
            end

            if kills > 0 then
                if not attachment_totals[att_id] then
                    attachment_totals[att_id] = { kills = 0, weapons = {} }
                end
                attachment_totals[att_id].kills = attachment_totals[att_id].kills + kills
                attachment_totals[att_id].weapons[weapon_id] = kills
            end
        end
    end

    -- Convert to sorted array
    local sorted = {}
    for att_id, info in pairs(attachment_totals) do
        local top_gun = "N/A"
        local top_gun_kills = 0
        for g_id, g_kills in pairs(info.weapons) do
            if g_kills > top_gun_kills then
                top_gun = g_id
                top_gun_kills = g_kills
            end
        end

        table.insert(sorted, {
            id = att_id,
            kills = info.kills,
            top_gun = top_gun,
            top_gun_kills = top_gun_kills
        })
    end

    table.sort(sorted, function(a, b)
        return a.kills > b.kills
    end)

    print(string.format("-- TOTAL ATTACHMENTS: %d (split into lines of 100)", #sorted))
    print("ATTACHMENT_DATA = {")

    local line_items = {}
    local CHUNK_SIZE = 100

    for i, item in ipairs(sorted) do
        table.insert(line_items, string.format('["%s"]={kills=%d,top_gun="%s",top_gun_kills=%d}', 
            item.id, item.kills, item.top_gun, item.top_gun_kills))

        if #line_items == CHUNK_SIZE or i == #sorted then
            local is_last = (i == #sorted)
            local suffix = is_last and "" or ","
            print("    " .. table.concat(line_items, ", ") .. suffix)
            table.clear(line_items)
            task.wait(0.05) -- brief yield to let output stream cleanly
        end
    end

    print("}")
else
    print("Could not retrieve player profile stats.")
end
