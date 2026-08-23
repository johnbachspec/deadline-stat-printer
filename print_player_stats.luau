-- print_player_stats.luau
-- In the in-game Luau Server Console, run:
--   require("https://raw.githubusercontent.com/refact0r/deadline-stat-printer/main/print_player_stats.luau")
-- Output appears in that console (not the Roblox Studio Output window).

local REPO_BASE = "https://raw.githubusercontent.com/refact0r/deadline-stat-printer/main/modules/"

local WeaponData = require(REPO_BASE .. "weapon_data.luau")
local LevelData  = require(REPO_BASE .. "level_data.luau")
local Formatters = require(REPO_BASE .. "formatters.luau")
local Aggregator = require(REPO_BASE .. "stats_aggregator.luau")
local FilterSort = require(REPO_BASE .. "filters_sorters.luau")
local Renderer   = require(REPO_BASE .. "renderer.luau")

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

local function print_player_stats(player, filter_override, target_override)
    local stats = player.get_profile_stats() or {}
    local player_stats = stats.player or {}

    local combined = Aggregator.combine_weapon_stats(stats, WeaponData)
    local account_totals = Aggregator.account_totals(combined)

    local weapon_list, table_totals = FilterSort.build_weapon_list(
        combined, WeaponData, filter_override or FILTER_TYPE, target_override or TARGET_WEAPON)
    FilterSort.sort(weapon_list, SORT_BY)

    renderer:print_report(player.name, player_stats, stats.spendings or {}, stats.achievements or {}, weapon_list, table_totals, account_totals)
    return weapon_list
end

-- Every console execution gets a fresh environment, so a plain global would
-- vanish when this script finishes. `shared` persists across executions:
--   shared.print_player_stats(players.get("Name"), "SMG")
--   shared.print_player_stats(players.get("Name"), nil, "AKM")
shared.print_player_stats = print_player_stats

-- Print a report for every human currently in the server.
for _, player in ipairs(players.get_all()) do
    if not player.is_bot() then print_player_stats(player) end
end

return print_player_stats
