-- cap_announcer.luau
-- Tells everyone on the server who captured an objective: whenever a player's
-- objective_captures (get_leaderboard_stats) goes up, it posts
--   bachancuc123 captured a point (2 this match)
-- The game only counts finished captures, so this names who completed a
-- capture, not who is standing on a point while it is being captured.
--
-- Anyone running iris_viewer.luau in their client console also gets a live
-- "Captures" window: this match's standings and the latest captures.
--
-- For the rest of the server session it also adds:
--   !caps in chat                 posts this match's captures per player to everyone
--   shared.caps()                 prints them in the console
--   shared.stop_cap_announcer()   stops it
-- Running the script again replaces the copy that is already running.
--
-- In the in-game Luau Server Console, run:
--   require("https://raw.githubusercontent.com/johnbachspec/deadline-stat-printer/main/cap_announcer.luau")

local ANNOUNCE_IN = "announcement" -- "announcement" (banner for everyone), "notification", or "console"
local CHAT_COMMAND = "!caps"       -- "" turns it off; the game's own command bot uses "-" commands
local POLL_SECONDS = 0.5
local SEND_TO_IRIS = true          -- keep the "Captures" window in iris_viewer.luau up to date
local RECENT = 8                   -- captures listed in that window

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

-- The Iris window is optional: if the modules cannot load, chat announcements still work.
local IrisReport, IrisBridge, PlayerLookup = nil, nil, nil
if SEND_TO_IRIS then
    local ok, report_module, bridge_module, lookup_module = pcall(function()
        return load_module("iris_report"), load_module("iris_bridge"), load_module("player_lookup")
    end)
    if ok then IrisReport, IrisBridge, PlayerLookup = report_module, bridge_module, lookup_module end
end
local CONSOLE = { players = players, shared = shared, on_client_event = on_client_event } -- for IrisBridge

-- Posts a line to everyone (ANNOUNCE_IN) and prints it here.
local function announce(text)
    print("[caps] " .. text)
    if ANNOUNCE_IN == "announcement" then
        pcall(function() chat.send_announcement(text) end)
    elseif ANNOUNCE_IN == "notification" then
        pcall(function() chat.send_ingame_notification(text) end)
    end
end

local function captures_of(player)
    local ok, stats = pcall(function() return player.get_leaderboard_stats() end)
    if ok and type(stats) == "table" then
        return tonumber(stats.objective_captures)
    end
    return nil
end

-- This match's captures, most first.
local function standings()
    local rows = {}
    for _, player in ipairs(players.get_all()) do
        local caps = captures_of(player)
        if caps and caps > 0 then
            table.insert(rows, { name = tostring(player.name), caps = caps })
        end
    end
    table.sort(rows, function(a, b)
        if a.caps ~= b.caps then return a.caps > b.caps end
        return a.name < b.name
    end)
    return rows
end

local function standings_text()
    local parts = {}
    for _, row in ipairs(standings()) do
        table.insert(parts, row.name .. " " .. row.caps)
    end
    if #parts == 0 then return "No captures yet this match" end
    return "Captures this match: " .. table.concat(parts, ", ")
end

local wait_for = task and task.wait
if not (task and task.spawn and wait_for) then
    print("[caps] the task library is not available here; cannot run")
    return
end

-- Take over from a copy started by an earlier run.
if shared.stop_cap_announcer then
    pcall(shared.stop_cap_announcer)
end

local running = true
local last = {} -- player id -> captures at the previous check; nil until first seen
local recent = {} -- "12:03:10  Alice captured a point (2 this match)", newest first

local function captures_report()
    local report = IrisReport.new("caps", "Captures", IrisReport.refresh_request("caps"))
    report:section("Captures this match", true, "Objective captures per player since the match started, most first")
    local rows = standings()
    if #rows == 0 then report:text("No captures yet this match") end
    if #rows > 0 then report:columns({ "Player", "Captures" }) end
    for _, row in ipairs(rows) do report:row({ row.name, tostring(row.caps) }) end
    report:section("Latest captures", true, "Each capture as it happened, newest first, with the time it was seen")
    if #recent == 0 then report:text("None yet") end
    for _, line in ipairs(recent) do report:text(line) end
    return report
end

-- popup opens the window; live updates refresh it without reopening it if closed.
local function update_iris(popup)
    if not IrisReport then return end
    local report = captures_report()
    report.popup = popup
    IrisBridge.publish(CONSOLE, report, PlayerLookup.humans(players)) -- no status line: it updates on every capture
end

local function remember(text)
    local ok, stamp = pcall(function() return os.date("%H:%M:%S") end)
    table.insert(recent, 1, (ok and tostring(stamp) .. "  " or "") .. text)
    if #recent > RECENT then table.remove(recent) end
end

local function check()
    local capturers, seen, reset = {}, {}, false
    for _, player in ipairs(players.get_all()) do
        local key = player.player_id or player.name
        seen[key] = true
        local caps = captures_of(player)
        if caps then
            if last[key] and caps > last[key] then
                table.insert(capturers, { name = tostring(player.name), caps = caps })
            elseif last[key] and caps < last[key] then
                reset = true
            end
            last[key] = caps -- a new match starting at 0 just resets it
        end
    end
    for key in pairs(last) do
        if not seen[key] then last[key] = nil end
    end
    if reset then recent = {} end -- a new match
    local text = nil
    if #capturers == 1 then
        text = string.format("%s captured a point (%d this match)", capturers[1].name, capturers[1].caps)
    elseif #capturers > 1 then
        local names = {}
        for _, c in ipairs(capturers) do table.insert(names, c.name) end
        text = table.concat(names, " and ") .. " captured a point"
    end
    if text then
        announce(text)
        remember(text)
    end
    if text or reset then update_iris(false) end
end

local chat_connection = nil
if CHAT_COMMAND ~= "" and chat and chat.player_chatted then
    chat_connection = chat.player_chatted:Connect(function(sender, channel, content)
        if type(content) == "string" and string.lower(string.match(content, "^%s*(.-)%s*$") or "") == CHAT_COMMAND then
            announce(standings_text())
        end
    end)
end

local function stop()
    running = false
    if chat_connection then
        pcall(function() chat_connection:Disconnect() end)
    end
    if shared.stop_cap_announcer == stop then
        shared.stop_cap_announcer = nil
    end
end
shared.stop_cap_announcer = stop
shared.caps = function()
    print(standings_text())
    return standings()
end
if IrisReport then
    IrisBridge.serve(CONSOLE, "caps",
        function() return captures_report() end)
    update_iris(true)
end

task.spawn(function()
    local reported = false
    while running do
        local ok, err = pcall(check)
        if not ok and not reported then
            print("[caps] check failed: " .. tostring(err))
            reported = true
        end
        wait_for(POLL_SECONDS)
    end
end)

print(string.format("[caps] announcing captures (%s)%s", ANNOUNCE_IN,
    CHAT_COMMAND ~= "" and ("; type " .. CHAT_COMMAND .. " in chat for the standings") or ""))
