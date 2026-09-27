-- iris_viewer.luau
-- Shows the stat printer's reports in Iris windows. Iris only exists in the CLIENT
-- console and profile stats only on the server, so the server scripts send reports here:
--   1. Paste this whole file into the client Luau console and run it (the client has no require).
--   2. Run print_player_stats, print_attachment_stats or cap_announcer in the server console.
-- Each report gets its own window; Refresh asks the server for a fresh copy. The viewer
-- stays running all session. It only sends the server Refresh requests.
-- Keep this file under 255 lines (no blank lines): Fiu cannot load a longer chunk.
local PAGE_ROWS = 25   -- table rows per page; longer tables get Prev / Next buttons
local FILTER_ROWS = 12 -- tables with more rows than this get a filter box
local WINDOW_SIZES = { stats = { 1180, 640 }, attachments = { 820, 640 }, caps = { 380, 320 } }
local DEFAULT_SIZE = { 700, 500 }
if not (iris and on_server_event and shared) then
    print("[viewer] iris, on_server_event or shared is missing: run this in the client Luau console")
    return
end
-- Iris 2.4+ tables move to the next cell after drawing one; older ones before it.
local NEW_TABLES = iris.NextHeaderColumn ~= nil
local set_id = iris.SetNextWidgetID or function() end
local viewer = shared.iris_viewer
if not viewer then
    viewer = { reports = {}, order = {}, parts = {} }
    shared.iris_viewer = viewer
    -- Connected once per session; running this file again swaps receive and draw.
    on_server_event:Connect(function(message)
        if viewer.receive then pcall(viewer.receive, message) end
    end)
    iris:Connect(function()
        if viewer.draw then viewer.draw() end
    end)
end
-- ===== Reading reports (format: modules/iris_report.luau) =====
local UNESCAPE = { ["\\"] = "\\", t = "\t", n = "\n" }
local RICH_ESCAPES = { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }
local EMPTY = { "" }
local function fields(line)
    local out = {}
    for field in (line .. "\t"):gmatch("([^\t]*)\t") do
        table.insert(out, (field:gsub("\\(.)", UNESCAPE)))
    end
    return out
end
-- Cells are kept as ready-made iris.Text arguments, so drawing allocates nothing.
-- Iris 2.4+ styles the header row itself; older tables get bold rich text.
local function header_args(name)
    if NEW_TABLES then return { name } end
    return { "<b>" .. name:gsub("[<>&]", RICH_ESCAPES) .. "</b>", nil, nil, true }
end
local function parse(text)
    local report = { blocks = {}, sections = {} }
    local container, current, count = report, nil, 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local f = fields(line)
        local kind = table.remove(f, 1)
        if kind == "report" then
            report.id, report.title, report.refresh, report.popup = f[1], f[2], f[3] or "", f[4] ~= "0"
            report.key = "dsp:" .. f[1]
        elseif kind == "section" then
            count = count + 1
            container = { title = f[1], open = f[2] == "1", blocks = {}, key = report.key .. ":" .. count }
            table.insert(report.sections, container)
        elseif kind == "text" then
            table.insert(container.blocks, { text = { f[1] or "", true } })
        elseif kind == "columns" then
            count = count + 1
            current = { columns = f, rows = {}, slots = {}, header = table.concat(f) ~= "", header_args = {},
                key = report.key .. ":" .. count .. ":" .. #f }
            for c, name in ipairs(f) do current.header_args[c] = header_args(name) end
            table.insert(container.blocks, current)
        elseif kind == "row" and current then
            local cells = { search = string.lower(table.concat(f, " ")) }
            for c, value in ipairs(f) do cells[c] = { value } end
            table.insert(current.rows, cells)
        end
    end
    return report
end
-- One message per part: "dsp1|<id>|<part>|<parts>|<text>".
viewer.receive = function(message)
    viewer.messages = (viewer.messages or 0) + 1 -- shown in the hub while no report has arrived
    if type(message) == "table" then message = message[1] or message.args end
    local id, part, parts, text = tostring(message):match("^dsp1|([^|]*)|(%d+)|(%d+)|(.*)$")
    if not id then viewer.other = type(message) .. " " .. tostring(message):sub(1, 60); return end
    part, parts = tonumber(part), tonumber(parts)
    local pending = viewer.parts[id]
    if part == 1 or not pending then pending = {}; viewer.parts[id] = pending end
    pending[part] = text
    for i = 1, parts do if not pending[i] then return end end
    viewer.parts[id] = nil
    local ok, report = pcall(parse, table.concat(pending))
    if not ok then return print("[viewer] could not read report " .. id .. ": " .. tostring(report)) end
    local old = viewer.reports[report.id]
    if not old then table.insert(viewer.order, report.id) end
    report.ui = old and old.ui or { pages = {}, filters = {}, seen = {} } -- kept across refreshes
    local got_time, time_text = pcall(function() return os.date("%H:%M:%S") end)
    report.received = got_time and tostring(time_text) or "?"
    viewer.reports[report.id] = report
end
-- ===== Drawing =====
local depth = 0 -- open Iris containers, so an error can close them again
local function open(widget) depth = depth + 1; return widget end
local function close() depth = depth - 1; iris.End() end
local function slot_ids(tbl, slot) -- widget ids for one visible row (slot 0 is the header)
    local ids = tbl.slots[slot]
    if not ids then
        ids = {}
        for c = 1, #tbl.columns do ids[c] = tbl.key .. ":" .. slot .. ":" .. c end
        tbl.slots[slot] = ids
    end
    return ids
end
local function cell(id, args)
    if not NEW_TABLES then iris.NextColumn() end
    set_id(id)
    iris.Text(args)
    if NEW_TABLES then iris.NextColumn() end
end
local function visible_rows(tbl, ui)
    if #tbl.rows <= FILTER_ROWS then return tbl.rows end
    set_id(tbl.key .. ":filter")
    local query = string.lower(iris.InputText({ "Filter", "type to filter rows" }).state.text.value or "")
    local cache = ui.filters[tbl.key]
    if not (cache and cache.query == query and cache.source == tbl.rows) then
        cache = { query = query, source = tbl.rows, rows = {} }
        for _, row in ipairs(tbl.rows) do
            if row.search:find(query, 1, true) then table.insert(cache.rows, row) end
        end
        ui.filters[tbl.key] = cache
    end
    return cache.rows
end
local function draw_table(tbl, ui)
    local rows = visible_rows(tbl, ui)
    local pages = math.max(1, math.ceil(#rows / PAGE_ROWS))
    local page = math.min(ui.pages[tbl.key] or 1, pages)
    if pages > 1 then
        open(iris.SameLine())
        set_id(tbl.key .. ":prev")
        if iris.SmallButton({ "< Prev" }).clicked() and page > 1 then page = page - 1 end
        set_id(tbl.key .. ":next")
        if iris.SmallButton({ "Next >" }).clicked() and page < pages then page = page + 1 end
        iris.Text({ string.format("rows %d-%d of %d", (page - 1) * PAGE_ROWS + 1, math.min(page * PAGE_ROWS, #rows), #rows) })
        close()
    end
    ui.pages[tbl.key] = page
    local n = #tbl.columns
    set_id(tbl.key)
    if NEW_TABLES then -- NumColumns, Header, RowBackground, OuterBorders, InnerBorders, Resizable, FixedWidth, ProportionalWidth
        open(iris.Table({ n, tbl.header, true, true, true, false, false, true }))
        if tbl.header then iris.SetHeaderColumnIndex(1) end
    else -- NumColumns, RowBg, BordersOuter, BordersInner
        open(iris.Table({ n, true, true, true }))
    end
    if tbl.header then
        local ids = slot_ids(tbl, 0)
        for c = 1, n do cell(ids[c], tbl.header_args[c]) end
    end
    local first = (page - 1) * PAGE_ROWS
    for slot = 1, math.min(PAGE_ROWS, #rows - first) do
        local row, ids = rows[first + slot], slot_ids(tbl, slot)
        for c = 1, n do cell(ids[c], row[c] or EMPTY) end
    end
    close()
end
local function draw_blocks(blocks, ui)
    for _, block in ipairs(blocks) do
        if block.text then iris.Text(block.text) else draw_table(block, ui) end
    end
end
local function draw_report(report, index)
    local ui = report.ui
    set_id(report.key)
    local window = open(iris.Window({ report.title }))
    if not ui.placed then
        ui.placed = true
        local size = WINDOW_SIZES[report.id:match("^[^:]*")] or DEFAULT_SIZE
        pcall(function() -- stagger new windows; skipped if Vector2 is not available
            window.state.size:set(Vector2.new(size[1], size[2]))
            window.state.position:set(Vector2.new(40 + 30 * index, 60 + 30 * index))
        end)
    end
    if report.popup then report.popup = false; window.state.isOpened:set(true) end
    if window.state.isOpened.value and window.state.isUncollapsed.value then
        open(iris.SameLine())
        if report.refresh ~= "" then
            set_id(report.key .. ":refresh")
            if iris.SmallButton({ "Refresh" }).clicked() and fire_server then
                pcall(fire_server, "dsp1|refresh|" .. report.refresh)
            end
        end
        iris.Text({ "updated " .. report.received })
        close()
        draw_blocks(report.blocks, ui)
        for _, section in ipairs(report.sections) do
            set_id(section.key)
            local header = open(iris.CollapsingHeader({ section.title }))
            if section.open and not ui.seen[section.key] then header.state.isUncollapsed:set(true) end
            ui.seen[section.key] = true -- after the first report, keep what the user opened or closed
            if header.state.isUncollapsed.value then draw_blocks(section.blocks, ui) end
            close()
        end
    end
    close()
end
local function draw_hub()
    set_id("dsp:hub")
    local hub = open(iris.Window({ "Stat printer" }))
    if viewer.show_hub then viewer.show_hub = false; hub.state.isOpened:set(true) end
    if hub.state.isOpened.value and hub.state.isUncollapsed.value then
        if #viewer.order == 0 then
            iris.Text({ string.format("Waiting for reports: run print_player_stats, print_attachment_stats or "
                .. "cap_announcer in the server console. Messages received: %d%s", viewer.messages or 0,
                viewer.other and (", last one not a report: " .. viewer.other) or ""), true })
        end
        for _, id in ipairs(viewer.order) do
            local report = viewer.reports[id]
            open(iris.SameLine())
            set_id(report.key .. ":show")
            if iris.SmallButton({ "Show" }).clicked() then report.popup = true end
            iris.Text({ report.title .. "  (" .. report.received .. ")" })
            close()
        end
        if #viewer.order > 0 then
            set_id("dsp:hub:clear")
            if iris.SmallButton({ "Clear all" }).clicked() then viewer.reports, viewer.order = {}, {} end
        end
        if viewer.error then iris.Text({ "Error: " .. viewer.error, true }) end
    end
    close()
end
-- An error in one window closes what it left open and is reported once,
-- instead of breaking every Iris window each frame.
local function guarded(draw, ...)
    local base = depth
    local ok, err = pcall(draw, ...)
    while depth > base do depth = depth - 1; pcall(iris.End) end
    if not ok and not viewer.error then
        viewer.error = tostring(err)
        print("[viewer] " .. viewer.error)
    end
end
viewer.draw = function()
    depth = 0
    guarded(draw_hub)
    for i, id in ipairs(viewer.order) do
        guarded(draw_report, viewer.reports[id], i)
    end
end
-- shared.iris_viewer.show() in the client console reopens every window without pasting again.
viewer.show = function() viewer.show_hub = true; for _, r in pairs(viewer.reports) do r.popup = true end end
viewer.error = nil; viewer.show()
print(string.format("[viewer] ready (Iris %s tables), %d reports so far. Run a stat script in the server console;"
    .. " shared.iris_viewer.show() reopens closed windows.", NEW_TABLES and "2.4+" or "pre-2.4", #viewer.order))
