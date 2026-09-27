-- print_player_stats.luau
-- In the in-game Luau Server Console, run:
--   require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/print_player_stats.luau")
-- Output appears in that console (not the Roblox Studio Output window), and in
-- an Iris window for anyone running iris_viewer.luau in their client console.

local REPO_BASE = "https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/modules/"

-- Resolves module locally if present in the Roblox hierarchy, falling back to remote URL.
local function load_module(module_name)
    local current_script = script
    if current_script and current_script.Parent then
        local modules_folder = current_script.Parent:FindFirstChild("modules")
        local local_mod = modules_folder and modules_folder:FindFirstChild(module_name)
        if local_mod then
            return require(local_mod)
        end
    end
    return require(REPO_BASE .. module_name .. ".luau")
end

local WeaponData = load_module("weapon_data")
local LevelData  = load_module("level_data")
local Formatters = load_module("formatters")
local Aggregator = load_module("stats_aggregator")
local FilterSort = load_module("filters_sorters")
local Renderer   = load_module("renderer")
local PlayerLookup = load_module("player_lookup")
local IrisReport = load_module("iris_report")

-- ===== User Config =====
-- "" lists all weapons. Set to one weapon to show only that row: raw id
-- ("AK_762"), legacy id ("AKMN"), or display name ("AKM"); case-insensitive.
-- Overrides FILTER_TYPE when set.
local TARGET_WEAPON = ""

-- "308", "Bolt", "762", "556", "545", "58", "Pistol", "SMG", "Shotgun",
-- "Melee", "RPG", "Grenade", "Fire", "Smoke", "Flash", "Healing", "Turret",
-- "Unknown", or "" for everything except Unknown.
local FILTER_TYPE = ""

-- "KILLS" -> by kills (default). "TYPE" -> by type, then kills.
local SORT_BY = "KILLS"

-- "console" prints here, "iris" sends the report to every human's
-- iris_viewer.luau window (see README), "both" does both.
local SHOW_IN = "both"
-- ========================

local renderer = Renderer.new({ formatters = Formatters, level_data = LevelData })

-- Everything one player's report shows.
local function collect(player, filter, target, sort_by)
    local stats = player.get_profile_stats() or {}
    local combined = Aggregator.combine_weapon_stats(stats, WeaponData)
    local weapon_list, table_totals = FilterSort.build_weapon_list(combined, WeaponData, filter, target)
    FilterSort.sort(weapon_list, sort_by)
    return {
        player_name = player.name,
        player_stats = stats.player or {},
        spendings = stats.spendings or {},
        achievements = stats.achievements or {},
        collection = Aggregator.collection(stats),
        weapon_list = weapon_list,
        table_totals = table_totals,
        account_totals = Aggregator.account_totals(combined),
    }
end

-- Refresh in the viewer asks for "stats|<name>|<filter>|<target>|<sort>".
local function iris_report(data, filter, target, sort_by)
    local name = tostring(data.player_name)
    local report = IrisReport.new("stats:" .. name, "Stats: " .. name,
        table.concat({ "stats", name, filter, target, sort_by }, "|"))
    if target ~= "" or filter ~= "" then
        local shown = target ~= "" and target or (filter .. " weapons")
        report:text("Weapon table: only " .. shown .. ". The recap covers every weapon.")
    end
    renderer:add_to_report(report, data)
    return report
end

-- Supports either:
--   print_player_stats(player, { filter = "SMG", target = "MP5", sort_by = "TYPE" })
-- or legacy positional arguments:
--   print_player_stats(player, filter_override, target_override, sort_override)
local function print_player_stats(player, options_or_filter, target_override, sort_override)
    local filter = FILTER_TYPE
    local target = TARGET_WEAPON
    local sort_by = SORT_BY

    if type(options_or_filter) == "table" then
        if options_or_filter.filter ~= nil then filter = options_or_filter.filter end
        if options_or_filter.target ~= nil then target = options_or_filter.target end
        if options_or_filter.sort_by ~= nil then sort_by = options_or_filter.sort_by end
    else
        if options_or_filter ~= nil then filter = tostring(options_or_filter) end
        if target_override ~= nil then target = tostring(target_override) end
        if sort_override ~= nil then sort_by = tostring(sort_override) end
    end

    local target_p = PlayerLookup.find(players, player)
    if not target_p then
        print(string.format("Player '%s' not found or has no profile stats.", tostring(player)))
        return nil
    end

    local data = collect(target_p, filter, target, sort_by)
    if SHOW_IN ~= "iris" then
        renderer:print_report(data)
    end
    if SHOW_IN ~= "console" then
        local humans = PlayerLookup.humans(players)
        local sent, problem = iris_report(data, filter, target, sort_by):send(humans)
        print(IrisReport.sent_line(tostring(target_p.name) .. "'s stats", sent, #humans, problem))
    end
    return data.weapon_list
end

-- Every console execution gets a fresh environment, so a plain global would
-- vanish when this script finishes. `shared` persists across executions:
--   shared.print_player_stats(players.get("Name"), "SMG")
--   shared.print_player_stats(players.get("Name"), { filter = "SMG", sort_by = "TYPE" })
--   shared.print_player_stats(players.get("Name"), nil, "AKM")
if shared then
    shared.print_player_stats = print_player_stats
end

if SHOW_IN ~= "console" then
    IrisReport.serve({ players = players, shared = shared, on_client_event = on_client_event }, "stats", function(arg)
        local name, filter, target, sort_by = arg:match("^(.-)|(.-)|(.-)|(.*)$")
        local player = name and PlayerLookup.find(players, name)
        if player then
            return iris_report(collect(player, filter, target, sort_by), filter, target, sort_by)
        end
        return nil
    end)
end

-- Print a report for every human currently in the server.
for _, player in ipairs(PlayerLookup.humans(players)) do
    print_player_stats(player)
end

return print_player_stats
