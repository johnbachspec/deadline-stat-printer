-- print_attachment_stats_delimited.luau
-- Prints a player's attachment kills as Lua-table lines of raw ids (100 per line)
-- instead of a readable table. Save the console output to
-- tests/fixtures/attachment_stats_output.txt to refresh the test fixture.
-- In the in-game Luau Server Console, run:
--   require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/print_attachment_stats_delimited.luau")
-- Afterwards, for the rest of the session:
--   shared.print_attachment_stats_delimited()                     -- first human player
--   shared.print_attachment_stats_delimited(players.get("Name"))  -- specific player

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

local AttachmentData = load_module("attachment_data")
local WeaponData     = load_module("weapon_data")
local Aggregator     = load_module("attachment_aggregator")
local Renderer       = load_module("attachment_renderer")
local PlayerLookup   = load_module("player_lookup")

local renderer = Renderer.new({ weapon_data = WeaponData })

local function print_attachment_stats_delimited(target_player)
    local player = PlayerLookup.find(players, target_player)
    if not player then
        print("Could not retrieve player profile stats.")
        return nil
    end
    -- No groups: the fixture keeps every attachment id.
    local aggregated = Aggregator.aggregate(player.get_profile_stats() or {}, AttachmentData, WeaponData)
    renderer:render_delimited(aggregated, player.name or "Player", 100)
    return aggregated.items
end

if shared then
    shared.print_attachment_stats_delimited = print_attachment_stats_delimited
end

print_attachment_stats_delimited()

return print_attachment_stats_delimited
