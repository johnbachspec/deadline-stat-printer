-- modules/player_lookup.luau
-- Finds the player a report is for. The console's `players` global is passed in
-- so this module does not depend on the console environment.
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ('Fiu') that does not
-- accept Luau type annotations, so this file intentionally has none.

local PlayerLookup = {}

-- Bots have is_bot() == true; a missing or failing is_bot counts as human.
function PlayerLookup.is_human(player)
    if type(player.is_bot) ~= "function" then
        return true
    end
    local ok, bot = pcall(function() return player.is_bot() end)
    return not (ok and bot)
end

-- Every human currently in the server.
function PlayerLookup.humans(players)
    local found = {}
    if players and type(players.get_all) == "function" then
        for _, player in ipairs(players.get_all()) do
            if PlayerLookup.is_human(player) then
                table.insert(found, player)
            end
        end
    end
    return found
end

-- target: a player, a player name, or nil for the first human in the server.
-- Returns a player with profile stats, or nil (an unknown name is not found,
-- rather than falling back to someone else).
function PlayerLookup.find(players, target)
    local player = target
    if target == nil then
        player = PlayerLookup.humans(players)[1]
    elseif type(target) == "string" then
        player = players and type(players.get) == "function" and players.get(target) or nil
    end
    local kind = type(player)
    if (kind == "table" or kind == "userdata") and type(player.get_profile_stats) == "function" then
        return player
    end
    return nil
end

return PlayerLookup
