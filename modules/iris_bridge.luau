-- modules/iris_bridge.luau
-- The server's side of the conversation with iris_viewer.luau. Reports themselves are
-- built and encoded by modules/iris_report.luau; this module
--   * publishes them: sends to players, keeps the latest copy of each, and prints one
--     console status line saying where it went;
--   * answers the viewer: "dsp1|refresh|<kind>|<arg>" (Refresh button) rebuilds that
--     report for the player who asked, and "dsp1|hello" (a viewer starting with no
--     reports) resends every kept report to that player.
-- Console globals come in as console = { players = players, shared = shared,
-- on_client_event = on_client_event }, so this module never reads globals itself.
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ('Fiu') that does not
-- accept Luau type annotations, so this file intentionally has none.

local IrisBridge = {}

local MIN_INTERVAL = 0.5 -- seconds between the same request from the same player, so clicks cannot flood the server

-- Keeps a report's messages for viewers that start later (at most 1 stats and 1 attachments per player).
local function keep(state, id, messages)
    state.latest = state.latest or {}
    state.latest_order = state.latest_order or {}
    local kind, player = id:match("^([^:]+):([^:]+)")
    if kind == "stats" or kind == "attachments" then
        local prefix = kind .. ":" .. player
        for i = #state.latest_order, 1, -1 do
            local existing = state.latest_order[i]
            if existing ~= id and (existing == prefix or existing:sub(1, #prefix + 1) == prefix .. ":") then
                table.remove(state.latest_order, i)
                state.latest[existing] = nil
            end
        end
    end
    if not state.latest[id] then table.insert(state.latest_order, id) end
    state.latest[id] = messages
end

local function answer(state, sender, message)
    if type(message) ~= "string" then return end
    local hello = message == "dsp1|hello"
    local kind, arg = message:match("^dsp1|refresh|([^|]*)|?(.*)$")
    local build = kind and state.handlers[kind]
    if not (build or hello) then return end
    local player = sender
    if type(sender) ~= "table" then -- the event may pass a name instead of a player
        player = state.players.get(type(sender) == "string" and sender or sender.Name)
    end
    if not player then return end
    local clock = os and os.clock
    local key = tostring(player.name) .. "|" .. message
    if clock then
        if state.last[key] and clock() - state.last[key] < state.min_interval then return end
        state.last[key] = clock()
    end
    if hello then
        for _, id in ipairs(state.latest_order or {}) do
            local messages = state.latest[id]
            pcall(function() for _, m in ipairs(messages) do player.fire_client(m) end end)
        end
        return
    end
    local fields = {}
    for field in (arg .. "|"):gmatch("([^|]*)|") do table.insert(fields, field) end
    local report = build(table.unpack(fields))
    if report then
        local _, _, messages = report:send({ player })
        keep(state, report.id, messages)
    end
end

-- The bridge's state, kept in shared.iris_report_bridge (the name older versions used,
-- so a server that ran one reuses its listener). The on_client_event listener is
-- connected once per server and calls state.answer, which every run replaces, so
-- running a script again updates the code instead of answering twice.
-- Returns nil when the console has no shared table or no event to listen on.
local function state_of(console)
    local store, event = console.shared, console.on_client_event
    if type(store) ~= "table" then return nil end
    local state = store.iris_report_bridge
    if not state then
        if not event then return nil end
        state = { handlers = {}, last = {}, min_interval = MIN_INTERVAL }
        local ok = pcall(function()
            event:Connect(function(sender, message)
                pcall(state.answer, state, sender, message)
            end)
        end)
        if not ok then return nil end
        store.iris_report_bridge = state
    end
    state.answer = answer
    state.players = console.players
    return state
end

-- Registers build(...) -> report (or nil) for Refresh requests of this kind. It gets the
-- fields the report's IrisReport.refresh_request was made with, as strings ("" when empty;
-- viewers holding a report from an older script version may send fewer).
function IrisBridge.serve(console, kind, build)
    local state = state_of(console)
    if not state then return false end
    state.handlers[kind] = build
    return true
end

-- One console line saying where a report went, so a missing window can be traced.
function IrisBridge.status_line(what, sent, recipients, problem)
    return string.format("[iris] sent %s to %d of %d players%s", what, sent, recipients,
        problem and (" (fire_client failed: " .. problem .. ")") or "")
end

-- Sends a report to each recipient (players.get(...) objects) and keeps it for viewers
-- that start later. With `what` (e.g. "Name's stats"), prints the status line too.
-- Returns how many got it and the first fire_client error, if any.
function IrisBridge.publish(console, report, recipients, what)
    local sent, problem, messages = report:send(recipients)
    local state = state_of(console)
    if state then keep(state, report.id, messages) end
    if what then print(IrisBridge.status_line(what, sent, #(recipients or {}), problem)) end
    return sent, problem
end

return IrisBridge
