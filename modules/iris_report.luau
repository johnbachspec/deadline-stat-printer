-- modules/iris_report.luau
-- Builds a report for iris_viewer.luau, encodes it, and sends it to players' client
-- consoles. Publishing, Refresh and resending to late viewers: modules/iris_bridge.luau.
-- Iris (the UI library) only exists on the client and profile stats only on the
-- server, so the server scripts describe what to show and fire_client it as text,
-- one line per item, fields separated by tabs:
--   report  <id> <title> <refresh> <popup>   first line; the viewer's Refresh button
--                                            sends <refresh> back; popup 1 opens the window
--   section <title> <open 1|0> <tip>         collapsing header holding what follows; tip
--                                            (may be empty) shows when it is hovered, closed
--   text    <text>
--   columns <name>...                        starts a table (all names "": no header row)
--   tips    <tip>...                         hover text for the columns line before it, per
--                                            column ("" for none); older viewers skip it
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
-- refresh is "<kind>|<arg>" for IrisBridge.serve (modules/iris_bridge.luau), or nil for no Refresh button.
function IrisReport.new(id, title, refresh)
    local self = setmetatable({ lines = {}, popup = true }, IrisReport)
    self.id = (tostring(id):gsub("|", "/"))
    self.title = title
    self.refresh = refresh
    return self
end

-- The `refresh` field for IrisReport.new: what the viewer's Refresh button sends back,
-- "<kind>|<field>|<field>...". IrisBridge.serve's build gets the fields back as its
-- arguments. "|" inside a field is dropped, since it separates them.
function IrisReport.refresh_request(kind, ...)
    local parts = { kind }
    for i = 1, select("#", ...) do
        parts[i + 1] = (tostring((select(i, ...)) or ""):gsub("|", ""))
    end
    return table.concat(parts, "|")
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

-- names: column names; tips: {name = hover text}. Adds the columns line, and a tips line if any name has one.
function IrisReport:columns_with_tips(names, tips)
    self:columns(names)
    local out, any = {}, false
    for i, name in ipairs(names) do out[i] = tips[name] or ""; any = any or out[i] ~= "" end
    if any then self:add("tips", table.unpack(out)) end
    return self
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
-- it, the first error if any player's fire_client failed, and the messages sent.
-- modules/iris_bridge.luau's publish is what scripts call: it also keeps the report
-- for viewers that start later and prints where it went.
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
    return sent, problem, messages
end

return IrisReport
