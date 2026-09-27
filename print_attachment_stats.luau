-- print_attachment_stats.luau
-- Prints every attachment a player has kills with, by in-game name, with the gun
-- it has the most kills on. Legacy attachment and gun ids are folded into their
-- current ids, and products made of several pieces print as one row.
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

local Names = nil
if LOAD_NAMES then
    local ok, mod = pcall(function() return load_module("attachment_names") end)
    if ok and type(mod) == "table" then Names = mod end
end

local renderer = Renderer.new({ weapon_data = WeaponData, names = Names })

local function print_attachment_stats(target_player)
    local player = PlayerLookup.find(players, target_player)
    if not player then
        print("Could not retrieve player profile stats.")
        return nil
    end
    local aggregated = Aggregator.aggregate(player.get_profile_stats() or {}, AttachmentData, WeaponData,
        Names and Names.GROUPS)
    renderer:render_table(aggregated)
    return aggregated.items
end

if shared then
    shared.print_attachment_stats = print_attachment_stats
end

print_attachment_stats()

return print_attachment_stats
