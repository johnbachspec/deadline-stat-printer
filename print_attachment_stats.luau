-- print_attachment_stats.luau
-- Prints every attachment a player has kills with, by in-game name, with the gun
-- it has the most kills on. Legacy attachment and gun ids are folded into their
-- current ids, and products made of several pieces print as one row. The table
-- also opens in an Iris window for anyone running iris_viewer.luau in their
-- client console.
-- In the in-game Luau Server Console, run:
--   require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/print_attachment_stats.luau")
-- Afterwards, for the rest of the session:
--   shared.print_attachment_stats()                      -- first human player
--   shared.print_attachment_stats(players.get("Name"))   -- specific player
--   shared.print_attachment_stats("Name")                -- by name

local REPO_BASE = "https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/modules/"

-- In-game names come from modules/attachment_names.luau (about 180 KB), generated
-- from recoil-group/deadline-balancing. Set to false to skip that download and
-- print prettified ids instead.
local LOAD_NAMES = true

-- "console" prints here, "iris" sends the table to every human's
-- iris_viewer.luau window (see README), "both" does both.
local SHOW_IN = "both"

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

local AttachmentData = load_module("attachment_data")
local WeaponData     = load_module("weapon_data")
local Aggregator     = load_module("attachment_aggregator")
local Renderer       = load_module("attachment_renderer")
local PlayerLookup   = load_module("player_lookup")
local IrisReport     = load_module("iris_report")

local Names = nil
if LOAD_NAMES then
    local ok, mod = pcall(function() return load_module("attachment_names") end)
    if ok and type(mod) == "table" then Names = mod end
end

local renderer = Renderer.new({ weapon_data = WeaponData, names = Names })

local function aggregate(player)
    return Aggregator.aggregate(player.get_profile_stats() or {}, AttachmentData, WeaponData,
        Names and Names.GROUPS)
end

-- Refresh in the viewer asks for "attachments|<name>".
local function iris_report(player, aggregated)
    local name = tostring(player.name)
    local report = IrisReport.new("attachments:" .. name, "Attachments: " .. name, "attachments|" .. name)
    renderer:add_to_report(report, aggregated)
    return report
end

local function print_attachment_stats(target_player)
    local player = PlayerLookup.find(players, target_player)
    if not player then
        print("Could not retrieve player profile stats.")
        return nil
    end
    local aggregated = aggregate(player)
    if SHOW_IN ~= "iris" then
        renderer:render_table(aggregated)
    end
    if SHOW_IN ~= "console" then
        local humans = PlayerLookup.humans(players)
        local sent, problem = iris_report(player, aggregated):send(humans)
        print(IrisReport.sent_line(tostring(player.name) .. "'s attachments", sent, #humans, problem))
    end
    return aggregated.items
end

if shared then
    shared.print_attachment_stats = print_attachment_stats
end

if SHOW_IN ~= "console" then
    IrisReport.serve({ players = players, shared = shared, on_client_event = on_client_event }, "attachments",
        function(name)
            local player = PlayerLookup.find(players, name)
            return player and iris_report(player, aggregate(player)) or nil
        end)
end

print_attachment_stats()

return print_attachment_stats
