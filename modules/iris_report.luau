-- modules/iris_report.luau
-- Builds a report for iris_viewer.luau and sends it to players' client consoles.
-- Iris (the UI library) only exists on the client and profile stats only on the
-- server, so the server scripts describe what to show and fire_client it as text,
-- one line per item, fields separated by tabs:
--   report  <id> <title> <refresh> <popup>   first line; the viewer's Refresh button
--                                            sends <refresh> back; popup 1 opens the window
--   section <title> <open 1|0> <tip>         collapsing header holding what follows; tip
--                                            (may be empty) shows when it is hovered
--   text    <text>
--   columns <name>...                        starts a table (all names "": no header row)
--   row     <cell>...
-- Backslash, tab and newline inside a field are escaped as \\ \t \n. Each message
-- is "dsp1|<id>|<part>|<parts>|<text>", PART_SIZE bytes of the text at most.
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ('Fiu') that does not
-- accept Luau type annotations, so this file intentionally has none.

local IrisReport = {}
IrisReport.__index = IrisReport

local PREFIX = "dsp1"
local PART_SIZE = 4000
local ESCAPES = { ["\\"] = "\\\\", ["\t"] = "\\t", ["\n"] = "\\n" }

local function escape(value)
    if value == nil then return "" end
    return (tostring(value):gsub("[\\\t\n]", ESCAPES))
end

-- id names the window ("stats:Name"); a later report with the same id replaces it.
-- refresh is "<kind>|<arg>" for IrisReport.serve, or nil for no Refresh button.
function IrisReport.new(id, title, refresh)
    local self = setmetatable({ lines = {}, popup = true }, IrisReport)
    self.id = (tostring(id):gsub("|", "/"))
    self.title = title
    self.refresh = refresh
    return self
end

function IrisReport:add(kind, ...)
    local fields = { kind }
    for i = 1, select("#", ...) do
        fields[i + 1] = escape((select(i, ...)))
    end
    table.insert(self.lines, table.concat(fields, "\t"))
    return self
end

-- tip: optional hover text for the section header, saying what the section shows.
function IrisReport:section(title, open, tip)
    return self:add("section", title, open and "1" or "0", tip)
end

function IrisReport:text(text)
    return self:add("text", text)
end

function IrisReport:columns(names)
    return self:add("columns", table.unpack(names))
end

function IrisReport:row(cells)
    return self:add("row", table.unpack(cells))
end

function IrisReport:encode()
    local header = table.concat({ "report", escape(self.id), escape(self.title), escape(self.refresh),
        self.popup and "1" or "0" }, "\t")
    return header .. (#self.lines > 0 and ("\n" .. table.concat(self.lines, "\n")) or "")
end

-- The messages to fire_client, in order; parts never split a UTF-8 character.
function IrisReport:messages()
    local text, parts = self:encode(), {}
    local start = 1
    while start <= #text do
        local stop = math.min(start + PART_SIZE - 1, #text)
        while stop < #text and stop > start do
            local byte = text:byte(stop + 1)
            if byte < 128 or byte >= 192 then break end -- not a continuation byte
            stop = stop - 1
        end
        table.insert(parts, text:sub(start, stop))
        start = stop + 1
    end
    local messages = {}
    for i, part in ipairs(parts) do
        messages[i] = string.format("%s|%s|%d|%d|%s", PREFIX, self.id, i, #parts, part)
    end
    return messages
end

-- Sends the report to each player (players.get(...) objects). Returns how many got
-- it and the first error, if any player's fire_client failed.
function IrisReport:send(recipients)
    local messages, sent, problem = self:messages(), 0, nil
    for _, player in ipairs(recipients or {}) do
        local ok, err = pcall(function()
            for _, message in ipairs(messages) do
                player.fire_client(message)
            end
        end)
        if ok then sent = sent + 1 else problem = problem or tostring(err) end
    end
    return sent, problem
end

-- One console line saying where a report went, so a missing window can be traced.
function IrisReport.sent_line(what, sent, recipients, problem)
    return string.format("[iris] sent %s to %d of %d players%s", what, sent, recipients,
        problem and (" (fire_client failed: " .. problem .. ")") or "")
end

-- A Refresh request "dsp1|refresh|<kind>|<arg>" from a viewer: build(arg) makes the
-- new report, which goes back to that player only.
local function answer(bridge, sender, message)
    if type(message) ~= "string" then return end
    local kind, arg = message:match("^dsp1|refresh|([^|]*)|?(.*)$")
    local build = kind and bridge.handlers[kind]
    if not build then return end
    local player = sender
    if type(sender) ~= "table" then -- the event may pass a name instead of a player
        player = bridge.players.get(type(sender) == "string" and sender or sender.Name)
    end
    local clock = os and os.clock
    local key = tostring(player and player.name) .. "|" .. message
    if clock then -- each player's same request at most every min_interval seconds, so clicks cannot flood the server
        if bridge.last[key] and clock() - bridge.last[key] < bridge.min_interval then return end
        bridge.last[key] = clock()
    end
    local report = player and build(arg)
    if report then report:send({ player }) end
end

-- Registers build(arg) for Refresh requests of this kind. The listener is connected
-- once per server and finds handlers through `shared`, so running a script again
-- replaces its handler instead of answering twice.
-- console = { players = players, shared = shared, on_client_event = on_client_event }
function IrisReport.serve(console, kind, build)
    local store, event = console.shared, console.on_client_event
    if type(store) ~= "table" then return false end
    local bridge = store.iris_report_bridge
    if not bridge then
        if not event then return false end
        bridge = { handlers = {}, last = {}, min_interval = 0.5 }
        local ok = pcall(function()
            event:Connect(function(sender, message)
                pcall(bridge.answer, bridge, sender, message)
            end)
        end)
        if not ok then return false end
        store.iris_report_bridge = bridge
    end
    bridge.answer = answer
    bridge.players = console.players
    bridge.handlers[kind] = build
    return true
end

return IrisReport
