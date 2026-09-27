-- iris_viewer.luau: shows the stat printer's reports in Iris windows. Paste it whole into the
-- CLIENT Luau console (there is no require there). How it works and how to change it: IRIS_VIEWER.md.
-- Must stay 255 lines or fewer (Fiu load limit), so notes go in IRIS_VIEWER.md, not in comments here.
local PAGE_ROWS = 50   -- table rows per page; longer tables get Prev / Next and Show all buttons
local FILTER_ROWS = 12 -- tables with more rows than this get a filter box
local WINDOW_SIZES = { stats = { 1180, 640 }, attachments = { 820, 640 }, caps = { 380, 320 } }
local DEFAULT_SIZE = { 700, 500 }
if not (iris and on_server_event and shared) then
    print("[viewer] iris, on_server_event or shared is missing: run this in the client Luau console")
    return
end
local NEW_TABLES = iris.NextHeaderColumn ~= nil -- Iris 2.4+ table API (see IRIS_VIEWER.md)
local set_id = iris.SetNextWidgetID or function() end -- every widget needs an explicit id (see IRIS_VIEWER.md)
local viewer = shared.iris_viewer
if not viewer then
    viewer = { reports = {}, order = {}, parts = {} }
    shared.iris_viewer = viewer
    on_server_event:Connect(function(message)
        if viewer.receive then pcall(viewer.receive, message) end
    end)
    iris:Connect(function()
        if viewer.draw then viewer.draw() end
    end)
end
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
            count = count + 1
            table.insert(container.blocks, { text = { f[1] or "", true }, key = report.key .. ":" .. count })
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
viewer.receive = function(message) -- one message per part: "dsp1|<id>|<part>|<parts>|<text>"
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
    local all = ui.pages[tbl.key .. ":all"] -- "Show all": one page with every row (costs frame rate on big tables)
    local per_page = all and math.max(#rows, 1) or PAGE_ROWS
    local pages = math.max(1, math.ceil(#rows / per_page))
    local page = math.min(ui.pages[tbl.key] or 1, pages)
    if #rows > PAGE_ROWS then
        set_id(tbl.key .. ":pager"); open(iris.SameLine())
        if not all then
            set_id(tbl.key .. ":prev")
            if iris.SmallButton({ "< Prev" }).clicked() and page > 1 then page = page - 1 end
            set_id(tbl.key .. ":next")
            if iris.SmallButton({ "Next >" }).clicked() and page < pages then page = page + 1 end
        end
        set_id(tbl.key .. ":all")
        if iris.SmallButton({ all and "Pages" or "Show all" }).clicked() then ui.pages[tbl.key .. ":all"] = not all end
        set_id(tbl.key .. ":rows"); iris.Text({ all and string.format("all %d rows", #rows) or string.format("rows %d-%d of %d",
            (page - 1) * per_page + 1, math.min(page * per_page, #rows), #rows) })
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
    local first = (page - 1) * per_page
    for slot = 1, math.min(per_page, #rows - first) do
        local row, ids = rows[first + slot], slot_ids(tbl, slot)
        for c = 1, n do cell(ids[c], row[c] or EMPTY) end
    end
    close()
end
local function draw_blocks(blocks, ui)
    for _, block in ipairs(blocks) do
        if block.text then set_id(block.key); iris.Text(block.text) else draw_table(block, ui) end
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
        set_id(report.key .. ":bar"); open(iris.SameLine())
        if report.refresh ~= "" then
            set_id(report.key .. ":refresh")
            if iris.SmallButton({ "Refresh" }).clicked() and fire_server then
                pcall(fire_server, "dsp1|refresh|" .. report.refresh)
            end
        end
        set_id(report.key .. ":updated"); iris.Text({ "updated " .. report.received })
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
            set_id("dsp:hub:waiting"); iris.Text({ string.format("Waiting for reports: run print_player_stats, print_attachment_stats or "
                .. "cap_announcer in the server console. Messages received: %d%s", viewer.messages or 0,
                viewer.other and (", last one not a report: " .. viewer.other) or ""), true })
        end
        for _, id in ipairs(viewer.order) do
            local report = viewer.reports[id]
            set_id(report.key .. ":hubrow"); open(iris.SameLine())
            set_id(report.key .. ":show")
            if iris.SmallButton({ "Show" }).clicked() then report.popup = true end
            set_id(report.key .. ":hubtitle"); iris.Text({ report.title .. "  (" .. report.received .. ")" })
            close()
        end
        if #viewer.order > 0 then
            set_id("dsp:hub:clear")
            if iris.SmallButton({ "Clear all" }).clicked() then viewer.reports, viewer.order = {}, {} end
        end
        if viewer.error then set_id("dsp:hub:error"); iris.Text({ "Error: " .. viewer.error, true }) end
    end
    close()
end
local function guarded(draw, ...) -- closes what a failing window left open; reports the error once
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
viewer.show = function() viewer.show_hub = true; for _, r in pairs(viewer.reports) do r.popup = true end end -- shared.iris_viewer.show()
viewer.error = nil; viewer.show()
print(string.format("[viewer] ready (Iris %s tables), %d reports so far. Run a stat script in the server console;"
    .. " shared.iris_viewer.show() reopens closed windows.", NEW_TABLES and "2.4+" or "pre-2.4", #viewer.order))
