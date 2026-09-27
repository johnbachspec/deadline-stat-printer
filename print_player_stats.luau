-- print_player_stats.luau
-- In the in-game Luau Server Console, run:
--   require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/print_player_stats.luau")
-- Output appears in that console (not the Roblox Studio Output window).

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
-- ========================

local renderer = Renderer.new({ formatters = Formatters, level_data = LevelData })

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

    local stats = target_p.get_profile_stats() or {}
    local player_stats = stats.player or {}

    local combined = Aggregator.combine_weapon_stats(stats, WeaponData)
    local account_totals = Aggregator.account_totals(combined)

    local weapon_list, table_totals = FilterSort.build_weapon_list(combined, WeaponData, filter, target)
    FilterSort.sort(weapon_list, sort_by)

    renderer:print_report(target_p.name, player_stats, stats.spendings or {}, stats.achievements or {},
        Aggregator.collection(stats), weapon_list, table_totals, account_totals)
    return weapon_list
end

-- Every console execution gets a fresh environment, so a plain global would
-- vanish when this script finishes. `shared` persists across executions:
--   shared.print_player_stats(players.get("Name"), "SMG")
--   shared.print_player_stats(players.get("Name"), { filter = "SMG", sort_by = "TYPE" })
--   shared.print_player_stats(players.get("Name"), nil, "AKM")
if shared then
    shared.print_player_stats = print_player_stats
end

-- Print a report for every human currently in the server.
for _, player in ipairs(PlayerLookup.humans(players)) do
    print_player_stats(player)
end

return print_player_stats
