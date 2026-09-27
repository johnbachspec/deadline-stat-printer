-- explore_console.luau
-- Read-only survey of what Deadline's Luau console exposes, to find more to
-- report on. The API is documented at
--   https://recoil-group.github.io/deadline-modding/making-mods/scripting/api/
-- Paste this into the Luau Server Console (or require it from GitHub) and copy the
-- whole output. It only reads: the functions it calls are players.get_all /
-- get_alive, is_bot, get_profile_stats, the getters in LIVE_GETTERS, the two weapon
-- getters and map.get_maps. Everything else, like kill, give_money or map.set_map,
-- is listed by name, never run.
--
--   GLOBALS    the documented globals, and the functions on the API tables
--   GAME DATA  config, server settings (sharedvars), maps and gamemodes
--   PLAYERS    the players table and a player object
--   PROFILE    every key path in get_profile_stats(), with type and a sample value
--   LIVE       what the getters return right now (run it mid-match, while alive)
--   SHARED     what earlier scripts left in `shared`
--
-- In the in-game Luau Server Console, run:
--   require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/explore_console.luau")

local TARGET = nil       -- a player name, or nil for the first human in the server
local LOADOUTS = 5       -- loadouts 0 .. LOADOUTS-1 are read with get_weapon_from_loadout
local MAX_DEPTH = 8
-- Bigger tables are summarized (size, a few keys, and one entry's shape) instead of
-- listed. Lists and collections of tables (one entry per weapon, attachment, ...) are
-- summarized sooner; records with mixed fields are listed in full up to MAX_LISTED.
local MAX_LISTED = 40
local MAX_COLLECTION_LISTED = 12
local STRING_LIMIT = 40  -- characters shown per string; weapon setups get WEAPON_STRING_LIMIT
local WEAPON_STRING_LIMIT = 400

local LIVE_GETTERS = {
    "is_alive", "get_health", "get_team", "get_position", "get_active_slot", "get_animation_speed",
    "get_leaderboard_stats",
}
local WEAPON_SLOTS = { "primary", "secondary", "throwable1", "throwable2" }

local type_of = typeof or type
local string_limit = STRING_LIMIT

local function describe(value)
    local t = type_of(value)
    if t == "string" then
        if #value > string_limit then
            return string.format("string %q... (%d chars)", value:sub(1, string_limit), #value)
        end
        return string.format("string %q", value)
    elseif t == "number" or t == "boolean" then
        return t .. " " .. tostring(value)
    elseif t == "nil" or t == "table" or t == "function" then
        return t
    end
    return t .. " " .. tostring(value):sub(1, 60) -- Vector3, Color3, Instance, ...: show its value
end

local function sorted_keys(t)
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function size_of(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- A list (1..n) or a table whose entries are all tables, like profile.weapon.
local function is_collection(t, n)
    if t[1] ~= nil and #t == n then return true end
    for _, v in pairs(t) do
        if type(v) ~= "table" then return false end
    end
    return true
end

-- One line per key path. A big collection (one entry per weapon, attachment, ...)
-- prints its size and a few keys, the keys its entries have, then its largest entry.
local function survey(value, path, depth)
    if type(value) ~= "table" then
        print(path .. " = " .. describe(value))
        return
    end
    local n = size_of(value)
    if n == 0 then
        print(path .. " = {}")
    elseif depth >= MAX_DEPTH then
        print(string.format("%s = table of %d (not expanded)", path, n))
    elseif n > MAX_LISTED or (n > MAX_COLLECTION_LISTED and is_collection(value, n)) then
        local keys, examples = sorted_keys(value), {}
        for i = 1, math.min(5, #keys) do table.insert(examples, tostring(keys[i])) end
        local largest, largest_size = keys[1], -1
        for _, k in ipairs(keys) do
            local child = value[k]
            local child_size = type(child) == "table" and size_of(child) or 0
            if child_size > largest_size then largest, largest_size = k, child_size end
        end
        print(string.format("%s = table of %d, e.g. %s", path, n, table.concat(examples, ", ")))
        -- Keys found across all entries, so fields only some entries have still show up.
        local seen, names = {}, {}
        for _, child in pairs(value) do
            if type(child) == "table" then
                for ck in pairs(child) do
                    local name = tostring(ck)
                    if not seen[name] then seen[name] = 0; table.insert(names, name) end
                    seen[name] = seen[name] + 1
                end
            end
        end
        if #names > 0 and #names <= 40 then
            table.sort(names)
            local parts = {}
            for _, name in ipairs(names) do table.insert(parts, name .. " x" .. seen[name]) end
            print(string.format("%s entries have: %s", path, table.concat(parts, ", ")))
        elseif #names > 40 then
            print(string.format("%s entries have %d different keys", path, #names))
        end
        survey(value[largest], string.format("%s[%s]", path, tostring(largest)), depth + 1)
    else
        for _, k in ipairs(sorted_keys(value)) do
            survey(value[k], path .. "." .. tostring(k), depth + 1)
        end
    end
end

-- Names and kinds of one level of a table (functions are listed, not called).
local function list_names(label, t)
    if type(t) ~= "table" then
        print(label .. " = " .. describe(t))
        return
    end
    print(string.format("%s: %d names", label, size_of(t)))
    for _, k in ipairs(sorted_keys(t)) do
        print("  " .. tostring(k) .. " = " .. describe(t[k]))
    end
    local ok, mt = pcall(getmetatable, t)
    if ok and mt ~= nil then print("  (metatable: " .. describe(mt) .. ")") end
end

-- Surveys what fn returns, or prints why it failed.
local function call(label, fn)
    local ok, result = pcall(fn)
    if ok then survey(result, label, 0) else print(label .. " failed: " .. tostring(result)) end
end

print("===== GLOBALS =====")
-- The documented globals; reading one that is not defined just gives nil.
local PROBES = {
    { "players", function() return players end }, { "shared", function() return shared end },
    { "weapons", function() return weapons end }, { "config", function() return config end },
    { "sharedvars", function() return sharedvars end }, { "map", function() return map end },
    { "gamemode", function() return gamemode end }, { "spawning", function() return spawning end },
    { "chat", function() return chat end }, { "time", function() return time end },
    { "on_player_died", function() return on_player_died end },
    { "on_player_spawned", function() return on_player_spawned end },
    { "on_player_joined", function() return on_player_joined end },
    { "on_player_left", function() return on_player_left end },
    { "Vector3", function() return Vector3 end }, { "Color3", function() return Color3 end },
    { "game", function() return game end }, { "require", function() return require end },
    -- Undocumented, seen in _G on a live server:
    { "game_data", function() return game_data end }, { "query", function() return query end },
    { "tags", function() return tags end }, { "sound", function() return sound end },
}
local found = {}
for _, probe in ipairs(PROBES) do
    local ok, value = pcall(probe[2])
    if ok then found[probe[1]] = value end
    print(string.format("  %-18s %s", probe[1], ok and describe(value) or ("error: " .. tostring(value))))
end
-- What the API tables offer (functions listed, not called).
for _, name in ipairs({ "weapons", "map", "gamemode", "chat", "spawning", "time", "query", "tags", "sound" }) do
    if type(found[name]) == "table" then list_names(name, found[name]) end
end
list_names("_G", _G) -- everything else the environment defines

print("===== GAME DATA =====")
call("game_data", function() return game_data end) -- undocumented; maybe match / objective state
call("config", function() return config end)
call("sharedvars", function() return sharedvars end)
call("sharedvars_descriptions", function() return sharedvars_descriptions end)
call("gamemode.available_gamemodes", function() return gamemode.available_gamemodes end)
call("map.get_maps()", function() return map.get_maps() end)

print("===== PLAYERS =====")
list_names("players", players)
local target = nil
if players and type(players.get_all) == "function" then
    for _, p in ipairs(players.get_all()) do
        local is_bot = type(p.is_bot) == "function" and select(2, pcall(function() return p.is_bot() end)) == true
        if (TARGET and p.name == TARGET) or (not TARGET and not is_bot and target == nil) then target = p end
    end
end
if target then
    list_names("player " .. tostring(target.name), target)
    print("===== PROFILE (" .. tostring(target.name) .. ") =====")
    call("profile", function() return target.get_profile_stats() end)

    print("===== LIVE (" .. tostring(target.name) .. ") =====")
    for _, getter in ipairs(LIVE_GETTERS) do
        if type(target[getter]) == "function" then
            call(getter .. "()", function() return target[getter]() end)
        end
    end
    string_limit = WEAPON_STRING_LIMIT -- enough of each weapon setup to see its format
    for _, slot in ipairs(WEAPON_SLOTS) do
        call(string.format("get_weapon_data_from_character(%q)", slot),
            function() return target.get_weapon_data_from_character(slot) end)
    end
    for loadout = 0, LOADOUTS - 1 do
        for _, slot in ipairs({ "primary", "secondary" }) do
            call(string.format("get_weapon_from_loadout(%d, %q)", loadout, slot),
                function() return target.get_weapon_from_loadout(loadout, slot) end)
        end
    end
    string_limit = STRING_LIMIT
    call("#players.get_alive()", function() return #players.get_alive() end)
else
    print("no player found")
end

print("===== SHARED =====")
list_names("shared", shared)
print("===== END =====")
