-- tests/mocks/iris.luau: a mock Iris, client console and server <-> client events for the
-- viewer tests (loaded by tests/iris_support.py, which fills in __NEW_TABLES__). Every table
-- cell is recorded by row and column, widgets drawn without an explicit id fail the frame,
-- and fire_client / fire_server route between the server scripts and the viewer, as "Tester".
local __new_tables = __NEW_TABLES__
local __widgets, __stack, __next_id, __frame_fn, __clicks, __hovers = {}, {}, nil, nil, {}, {}
local __drawn, __grids, __sent, __auto_ids, __configs, __pushed = {}, {}, 0, {}, 0, nil
local function __state(v) return { value = v, set = function(self, x) self.value = x end } end
local function __esc(s) return (tostring(s):gsub("\t", "<TAB>"):gsub("\n", "<NL>")) end
local function __make(kind, container)
  return function(args)
    local id = __next_id or (kind .. "#" .. #__drawn); __next_id = nil
    if id == kind .. "#" .. #__drawn then table.insert(__auto_ids, id .. " " .. __esc(args and args[1])) end
    local w = __widgets[id]
    if not w then
      w = { kind = kind, state = { isOpened = __state(true), isUncollapsed = __state(kind == "Window"),
        text = __state(""), size = __state(nil), position = __state(nil) } }
      __widgets[id] = w
    end
    w.id = id
    w.clicked = function() return __clicks[id] == true end
    w.hovered = function() return __hovers[id] == true end
    local text, parent = args and args[1], __stack[#__stack]
    if text == "boom" then error("boom") end
    if __pushed and __pushed.reject then error("Unable to assign property FontFace. Font expected, got EnumItem") end
    if (kind == "Text" or kind == "SmallButton") and parent and parent.kind == "Table" then  -- sortable headers are buttons
      if not __new_tables then parent.row = math.ceil(parent.index / parent.n); parent.col = (parent.index - 1) % parent.n + 1 end
      __grids[parent.id] = __grids[parent.id] or {}
      local g = __grids[parent.id]; g[parent.row] = g[parent.row] or {}; g[parent.row][parent.col] = text
    else
      table.insert(__drawn, kind .. " " .. __esc(text))
    end
    if kind == "Table" then w.n, w.index, w.row, w.col = args[1], 0, 1, 1 end
    if container then table.insert(__stack, w) end
    return w
  end
end
local iris = {
  Window = __make("Window", true), CollapsingHeader = __make("CollapsingHeader", true),
  SameLine = __make("SameLine", true), Table = __make("Table", true),
  Text = __make("Text"), Tooltip = __make("Tooltip"), SmallButton = __make("SmallButton"), InputText = __make("InputText"),
  SetNextWidgetID = function(id) __next_id = id end,
  End = function() assert(#__stack > 0, "End without an open widget"); table.remove(__stack) end,
  NextColumn = function()
    local t = __stack[#__stack]; assert(t and t.kind == "Table", "NextColumn outside a table")
    if not __new_tables then t.index = t.index + 1
    elseif t.col == t.n then t.col = 1; t.row = t.row + 1 else t.col = t.col + 1 end
  end,
  Connect = function(self, fn) __frame_fn = fn end,
  PushConfig = function(t)
    table.insert(__drawn, string.format("PushConfig %s size=%s font=%s color=%s", tostring(__next_id),
      tostring(t.TextSize), tostring(t.TextFont), tostring(t.TextColor)))
    __next_id = nil; __configs = __configs + 1; __pushed = t
  end,
  PopConfig = function() __configs = __configs - 1; __pushed = nil; table.insert(__drawn, "PopConfig") end,
  UpdateGlobalConfig = function(t)
    print("GLOBAL" .. (t.TextFont and (" font=" .. tostring(t.TextFont)) or "") .. (t.TextColor and (" color=" .. tostring(t.TextColor)) or ""))
  end,
  TemplateConfig = { colorDark = { TextColor = "white" }, colorLight = { TextColor = "black" },
    sizeDefault = { TextFont = "Enum.Font.Code", TextSize = 13 }, sizeClear = { TextFont = "Enum.Font.Ubuntu", TextSize = 15 } },
}
local Enum = { Font = { Code = "Enum.Font.Code", Ubuntu = "Enum.Font.Ubuntu" } }
local Color3 = { fromRGB = function(r, g, b) return "rgb(" .. r .. "," .. g .. "," .. b .. ")" end }
local __font_mt = { __tostring = function(f) return "Font(" .. f.Family .. ")" end }
local Font = { fromEnum = function(item)
  assert(item, "invalid font")
  return setmetatable({ Family = item, Style = "Normal" }, __font_mt)
end }
if __new_tables then
  iris.NextHeaderColumn = function() end
  iris.SetHeaderColumnIndex = function(i) local t = __stack[#__stack]; t.row = 0; t.col = i end
end
local function __frame()
  __drawn, __grids = {}, {}
  __frame_fn()
  assert(#__stack == 0, "a frame left " .. #__stack .. " widgets open")
  assert(__configs == 0, "a frame left " .. __configs .. " PushConfig calls without PopConfig")
  -- Under Fiu, Iris's automatic ids are draw order, so any widget without an explicit id can
  -- take over another one's state (or kind) when a report changes.
  assert(#__auto_ids == 0, "drawn without an explicit id: " .. table.concat(__auto_ids, "; "))
  __clicks, __hovers = {}, {}
end
local function __click(id) assert(__widgets[id], "no widget " .. id); __clicks[id] = true end
local function __hover(id) assert(__widgets[id], "no widget " .. id); __hovers[id] = true end
local function __dump()
  for _, line in ipairs(__drawn) do print("DRAWN\t" .. line) end
  local ids = {}
  for id in pairs(__grids) do table.insert(ids, id) end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local rows = {}
    for r in pairs(__grids[id]) do table.insert(rows, r) end
    table.sort(rows)
    for _, r in ipairs(rows) do
      local cells, last = {}, 0
      for c in pairs(__grids[id][r]) do last = math.max(last, c) end
      for c = 1, last do cells[c] = __esc(__grids[id][r][c] or "<nil>") end
      print("ROW\t" .. id .. "\t" .. table.concat(cells, "\t"))
    end
  end
end
local __client_handlers, __server_handlers = {}, {}
local on_server_event = { Connect = function(self, fn) table.insert(__client_handlers, fn) end }
local on_client_event = { Connect = function(self, fn) table.insert(__server_handlers, fn) end }
function __deliver(message) __sent = __sent + 1; for _, h in ipairs(__client_handlers) do h(message) end end
local __me = type(players) == "table" and players.get and players.get("Tester")
if __me then __me.fire_client = __deliver end
local function fire_server(message) for _, h in ipairs(__server_handlers) do h(__me, message) end end
local __assert = assert
local assert = nil -- Deadline's client console has no assert; scripts run after this line cannot use it
