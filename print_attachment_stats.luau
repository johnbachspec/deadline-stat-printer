-- print_attachment_stats.luau
-- Lists every attachment a player has kills with, by in-game name, with the guns it
-- has the most kills on. Legacy attachment and gun ids are folded into their current
-- ids, and products made of several pieces show as one row. The table opens in an
-- Iris window for anyone running iris_viewer.luau in their client console; this
-- console gets one status line per report (SHOW_IN below).
-- In the in-game Luau Server Console, run:
--   require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/print_attachment_stats.luau")
-- Afterwards, for the rest of the session:
--   shared.print_attachment_stats()                      -- first human player
--   shared.print_attachment_stats(players.get("Name"))   -- specific player
--   shared.print_attachment_stats("Name")                -- by name
--   shared.print_attachment_stats("Name", { gun = "AKM" })          -- kills on one gun only
--   shared.print_attachment_stats("Name", { search = "eotech" })    -- names containing a text
--   shared.print_attachment_stats("Name", { view = "guns" })        -- grouped by gun
--   shared.print_attachment_stats("Name", { rows = 0 })             -- print every row here (SHOW_IN "both")
--   shared.print_attachment_stats("Name", { view = "fixture" })     -- raw ids for tests/fixtures (console)

local REPO_BASE = "https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/modules/"

-- In-game names come from modules/attachment_names.luau (about 180 KB), generated
-- from recoil-group/deadline-balancing. Set to false to skip that download and
-- show prettified ids instead.
local LOAD_NAMES = true

-- "iris": the table goes to every human's iris_viewer.luau window (see README) and
-- this console gets one status line. "both": the table is printed here too.
-- "console": printed here only, for players without the viewer.
local SHOW_IN = "iris"

-- ===== User Config =====
-- "" counts kills on every gun. Set to one gun to count only kills on it: raw id
-- ("AK_762"), legacy id ("AKMN"), or display name ("AKM"); case-insensitive.
local TARGET_GUN = ""

-- "" lists every attachment; otherwise only those whose in-game name contains
-- this text, e.g. "eotech" or "suppressor"; case-insensitive.
local SEARCH = ""

-- "attachments": one row per attachment, most kills first.
-- "guns": the same kills grouped by gun, each gun's attachments most kills first.
-- "fixture": every raw attachment id as Lua-table lines, printed here, for
-- refreshing tests/fixtures/attachment_stats_output.txt (no groups, gun or search).
local VIEW = "attachments"

-- How many guns each attachment row lists: its top gun, then "Also: ..." with
-- the next ones. 1 = the top gun only.
local TOP_GUNS = 3

-- With SHOW_IN "both" or "console": how many rows to print here (per gun in the
-- "guns" view); 0 = all. The Iris window always gets every row, and Export copies them.
local CONSOLE_ROWS = 50
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

local AttachmentData   = load_module("attachment_data")
local WeaponData       = load_module("weapon_data")
local Formatters       = load_module("formatters")
local Aggregator       = load_module("attachment_aggregator")
local AttachmentLabels = load_module("attachment_labels")
local Renderer         = load_module("attachment_renderer")
local PlayerLookup     = load_module("player_lookup")
local IrisReport       = load_module("iris_report")
local IrisBridge       = load_module("iris_bridge")

local Names = nil
if LOAD_NAMES then
    local ok, mod = pcall(function() return load_module("attachment_names") end)
    if ok and type(mod) == "table" then Names = mod end
end

local labels = AttachmentLabels.new(Names)
local renderer = Renderer.new({ weapon_data = WeaponData, labels = labels, formatters = Formatters, top_guns = TOP_GUNS })
local CONSOLE = { players = players, shared = shared, on_client_event = on_client_event } -- for IrisBridge
local function name_of(item) return labels:name(item) end

local VIEWS = { attachments = true, guns = true, fixture = true }

-- The config, overridden by an options table { gun, search, view, rows }. "|" is
-- dropped since it separates the fields of a Refresh request.
local function settings(options)
    options = type(options) == "table" and options or {}
    local function pick(value, default)
        if value == nil then value = default end
        return (tostring(value):gsub("|", ""))
    end
    local view = string.lower(pick(options.view, VIEW))
    if not VIEWS[view] then
        print(string.format('Unknown view "%s": use "attachments", "guns" or "fixture". Showing attachments.', view))
        view = "attachments"
    end
    return { gun_name = pick(options.gun, TARGET_GUN), search = pick(options.search, SEARCH), view = view,
        rows = tonumber(options.rows) or CONSOLE_ROWS }
end

local function aggregate(player, opts)
    local gun = opts.gun_name ~= "" and WeaponData.resolve(opts.gun_name) or nil
    local aggregated = Aggregator.aggregate(player.get_profile_stats() or {}, AttachmentData, WeaponData,
        Names and Names.GROUPS, gun)
    opts.gun = gun
    return Aggregator.matching(aggregated, name_of, opts.search)
end

local function view_of(aggregated, opts)
    if opts.view == "guns" then
        return renderer:guns_view(Aggregator.by_gun(aggregated), opts)
    end
    return renderer:attachments_view(aggregated, opts)
end

-- Refresh in the viewer asks for "attachments|<name>|<gun>|<search>|<view>".
-- Each player has at most one attachment report window; new options replace it.
local function iris_report(player, view, opts)
    local name = tostring(player.name)
    local suffix = table.concat({ opts.view == "guns" and "by gun" or "", opts.gun_name, opts.search }, " ")
        :gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    local report = IrisReport.new("attachments:" .. name,
        "Attachments: " .. name .. (suffix ~= "" and (" (" .. suffix .. ")") or ""),
        IrisReport.refresh_request("attachments", name, opts.gun_name, opts.search, opts.view))
    renderer:add_view(report, view)
    return report
end

-- The fixture view: every raw id, no groups, printed here for copying.
local function print_fixture(player)
    local aggregated = Aggregator.aggregate(player.get_profile_stats() or {}, AttachmentData, WeaponData)
    load_module("attachment_fixture").print(aggregated, player.name or "Player", 100)
    return aggregated.items
end

-- target_player: a player, a name, or nil for the first human in the server.
-- options (optional): { gun = "AKM", search = "eotech", view = "guns", rows = 0 },
-- each overriding the config above for this call.
local function print_attachment_stats(target_player, options)
    local player = PlayerLookup.find(players, target_player)
    if not player then
        print(PlayerLookup.not_found(target_player))
        return nil
    end
    local opts = settings(options)
    if opts.view == "fixture" then return print_fixture(player) end
    local aggregated = aggregate(player, opts)
    if #aggregated.items == 0 and (opts.gun or opts.search ~= "") then
        local known = opts.gun and WeaponData.TYPES[opts.gun] ~= nil
        print(string.format("No attachment kills%s.%s", renderer:scope(opts),
            (opts.gun and not known) and string.format(' "%s" is not a gun this script knows: use its'
                .. ' name as in the stat panel ("AKM") or its id ("AK_762").', opts.gun_name) or ""))
    end
    local view = view_of(aggregated, opts)
    if SHOW_IN ~= "iris" then
        renderer:print_view(view, opts.rows)
    end
    if SHOW_IN ~= "console" then
        IrisBridge.publish(CONSOLE, iris_report(player, view, opts), PlayerLookup.humans(players),
            tostring(player.name) .. "'s attachments")
    end
    return aggregated.items
end

if shared then
    shared.print_attachment_stats = print_attachment_stats
end

if SHOW_IN ~= "console" then
    IrisBridge.serve(CONSOLE, "attachments", function(name, gun, search, view)
        -- Viewers holding a report from before the gun / search / view options send only the name.
        local player = PlayerLookup.find(players, name)
        if not player then return nil end
        local opts = settings({ gun = gun, search = search, view = view })
        if opts.view == "fixture" then return nil end
        return iris_report(player, view_of(aggregate(player, opts), opts), opts)
    end)
end

print_attachment_stats()

return print_attachment_stats
