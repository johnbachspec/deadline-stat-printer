-- main/print_player_stat.lua
-- in Server Luau console, run `require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/print_player_stats.luau")`

local REPO_BASE = "https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/modules/"

local WeaponData    = require(REPO_BASE .. "weapon_data.luau")
local LevelData     = require(REPO_BASE .. "level_data.luau")
local Formatters    = require(REPO_BASE .. "formatters.luau")
local Achievements  = require(REPO_BASE .. "achievements.luau")
local Aggregator    = require(REPO_BASE .. "stats_aggregator.luau")
local FilterSort    = require(REPO_BASE .. "filters_sorters.luau")
local Renderer      = require(REPO_BASE .. "renderer.luau")

-- ===== User Config =====
local TARGET_WEAPON = "" -- Leave empty "" to list all or set to a weapon name (e.g. "AK_762")

-- Options: "308", "Bolt", "762", "556", "545", "58", "Pistol", "SMG",
-- "Shotgun", "Melee", "RPG", "Grenade", "Smoke", "Flash", "Unknown", or ""
local FILTER_TYPE = ""

-- "KILLS" -> Sorts purely by highest total Kills (DEFAULT)
-- "TYPE"  -> Sorts purely by Type designation, then by Kills
local SORT_BY = "KILLS"
-- ========================

local renderer = Renderer.new({
    formatters   = Formatters,
    level_data   = LevelData,
    achievements = Achievements,
})

local function print_filtered_weapon_stats_for_player(player_obj, filter_override)
    local player_name = (player_obj and player_obj.name) or "Unknown"

    local profile_stats = {}
    if player_obj and type(player_obj.get_profile_stats) == "function" then
        profile_stats = player_obj.get_profile_stats() or {}
    end

    local combined_stats      = Aggregator.combine_weapon_stats(profile_stats, WeaponData)
    local player_stats        = Aggregator.player_stats(profile_stats)
    local spendings_stats     = Aggregator.spendings_stats(profile_stats)
    local achievements_stats  = Aggregator.achievements_stats(profile_stats)

    local active_filter       = filter_override or FILTER_TYPE
    local weapon_list, totals = FilterSort.build_weapon_list(combined_stats, WeaponData, active_filter)
    FilterSort.sort(weapon_list, SORT_BY)

    renderer:print_report(player_name, player_stats, spendings_stats, achievements_stats, weapon_list, totals)

    return weapon_list
end

-- Exposed globally so external callers (e.g. a command handler) can still
-- invoke this the same way the original single-file script allowed.
print_filtered_weapon_stats_for_player = print_filtered_weapon_stats_for_player

if type(players) == "table" and type(players.get_all) == "function" then
    for _, plr in ipairs(players.get_all()) do
        if plr and type(plr.is_bot) == "function" and plr.is_bot() == false then
            print_filtered_weapon_stats_for_player(plr, TARGET_WEAPON ~= "" and nil or nil)
        end
    end
end
