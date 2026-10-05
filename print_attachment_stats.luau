-- print_attachment_stats.luau
-- Prints every attachment a player has kills with, by in-game name, with the guns
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
--   shared.print_attachment_stats("Name", { gun = "AKM" })          -- kills on one gun only
--   shared.print_attachment_stats("Name", { search = "eotech" })    -- names containing a text
--   shared.print_attachment_stats("Name", { view = "guns" })        -- grouped by gun

local REPO_BASE = "https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/modules/"

-- In-game names come from modules/attachment_names.luau (about 180 KB), generated
-- from recoil-group/deadline-balancing. Set to false to skip that download and
-- print prettified ids instead.
local LOAD_NAMES = true

-- "console" prints here, "iris" sends the table to every human's
-- iris_viewer.luau window (see README), "both" does both.
local SHOW_IN = "both"

-- ===== User Config =====
-- "" counts kills on every gun. Set to one gun to count only kills on it: raw id
-- ("AK_762"), legacy id ("AKMN"), or display name ("AKM"); case-insensitive.
local TARGET_GUN = ""

-- "" lists every attachment; otherwise only those whose in-game name contains
-- this text, e.g. "eotech" or "suppressor"; case-insensitive.
local SEARCH = ""

-- "attachments": one row per attachment, most kills first.
-- "guns": the same kills grouped by gun, each gun's attachments most kills first.
local VIEW = "attachments"

-- How many guns each attachment row lists: its top gun, then "Also: ..." with
-- the next ones. 1 = the top gun only.
local TOP_GUNS = 3
-- ========================

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

local renderer = Renderer.new({ weapon_data = WeaponData, names = Names, top_guns = TOP_GUNS })

local VIEWS = { attachments = true, guns = true }

-- The config, overridden by an options table { gun, search, view }. "|" is
-- dropped since it separates the fields of a Refresh request.
local function settings(options)
    options = type(options) == "table" and options or {}
    local function pick(value, default)
        if value == nil then value = default end
        return (tostring(value):gsub("|", ""))
    end
    local view = string.lower(pick(options.view, VIEW))
    if not VIEWS[view] then
        print(string.format('Unknown view "%s": use "attachments" or "guns". Showing attachments.', view))
        view = "attachments"
    end
    return { gun_name = pick(options.gun, TARGET_GUN), search = pick(options.search, SEARCH), view = view }
end

local function aggregate(player, opts)
    local gun = opts.gun_name ~= "" and WeaponData.resolve(opts.gun_name) or nil
    local aggregated = Aggregator.aggregate(player.get_profile_stats() or {}, AttachmentData, WeaponData,
        Names and Names.GROUPS, gun)
    opts.gun = gun
    return renderer:matching(aggregated, opts.search)
end

-- Refresh in the viewer asks for "attachments|<name>|<gun>|<search>|<view>".
-- Each different view gets its own window.
local function iris_report(player, aggregated, opts)
    local name = tostring(player.name)
    local suffix = table.concat({ opts.view == "guns" and "by gun" or "", opts.gun_name, opts.search }, " ")
        :gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    local report = IrisReport.new("attachments:" .. name .. (suffix ~= "" and (":" .. suffix) or ""),
        "Attachments: " .. name .. (suffix ~= "" and (" (" .. suffix .. ")") or ""),
        table.concat({ "attachments", name, opts.gun_name, opts.search, opts.view }, "|"))
    if opts.view == "guns" then
        renderer:add_by_gun_to_report(report, Aggregator.by_gun(aggregated), opts)
    else
        renderer:add_to_report(report, aggregated, opts)
    end
    return report
end

-- target_player: a player, a name, or nil for the first human in the server.
-- options (optional): { gun = "AKM", search = "eotech", view = "guns" }, each
-- overriding the config above for this call.
local function print_attachment_stats(target_player, options)
    local player = PlayerLookup.find(players, target_player)
    if not player then
        print("Could not retrieve player profile stats.")
        return nil
    end
    local opts = settings(options)
    local aggregated = aggregate(player, opts)
    if #aggregated.items == 0 and (opts.gun or opts.search ~= "") then
        local known = opts.gun and WeaponData.TYPES[opts.gun] ~= nil
        print(string.format("No attachment kills%s.%s", renderer:scope(opts),
            (opts.gun and not known) and string.format(' "%s" is not a gun this script knows: use its'
                .. ' name as in the stat panel ("AKM") or its id ("AK_762").', opts.gun_name) or ""))
    end
    if SHOW_IN ~= "iris" then
        if opts.view == "guns" then
            renderer:render_by_gun(Aggregator.by_gun(aggregated), opts)
        else
            renderer:render_table(aggregated, opts)
        end
    end
    if SHOW_IN ~= "console" then
        local humans = PlayerLookup.humans(players)
        local sent, problem = iris_report(player, aggregated, opts):send(humans)
        print(IrisReport.sent_line(tostring(player.name) .. "'s attachments", sent, #humans, problem))
    end
    return aggregated.items
end

if shared then
    shared.print_attachment_stats = print_attachment_stats
end

if SHOW_IN ~= "console" then
    IrisReport.serve({ players = players, shared = shared, on_client_event = on_client_event }, "attachments",
        function(arg)
            -- Viewers from before the gun / search / view options send only the name.
            local name, gun, search, view = arg:match("^(.-)|(.-)|(.-)|(.*)$")
            local player = PlayerLookup.find(players, name or arg)
            if not player then return nil end
            local opts = settings({ gun = gun, search = search, view = view })
            return iris_report(player, aggregate(player, opts), opts)
        end)
end

print_attachment_stats()

return print_attachment_stats
