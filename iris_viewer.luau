-- iris_viewer.luau: shows the stat printer's reports in Iris windows. Paste it whole into the
-- CLIENT Luau console (there is no require there). How it works and how to change it: IRIS_VIEWER.md.
-- Fiu load limit: the top level and the drawing function below each get 255 lines; notes go in IRIS_VIEWER.md.
local PAGE_ROWS = 50   -- table rows per page; longer tables get Prev / Next and Show all buttons
local FILTER_ROWS = 12 -- tables with more rows than this get a filter box
local WINDOW_SIZES = { stats = { 1180, 640 }, attachments = { 1000, 640 }, caps = { 380, 320 } }
local DEFAULT_SIZE = { 700, 500 }
local ONLY_FOR = {} -- player names, e.g. { "bachancuc123" }: in Client Autorun, only they get the viewer; {} = everyone
local allowed = #ONLY_FOR == 0; for _, name in ipairs(ONLY_FOR) do allowed = allowed or name == tostring(local_player) end
if not allowed then return end -- (a loop, not table.find: the client console lacks some standard functions)
if not (iris and on_server_event and shared) then return print("[viewer] iris, on_server_event or shared is missing: run this in the client Luau console") end
local NEW_TABLES = iris.NextHeaderColumn ~= nil -- Iris 2.4+ table API (see IRIS_VIEWER.md)
local set_id = iris.SetNextWidgetID or function() end -- every widget needs an explicit id (see IRIS_VIEWER.md)
local viewer = shared.iris_viewer
if not viewer then
    viewer = { reports = {}, order = {}, parts = {} }
    shared.iris_viewer = viewer
    on_server_event:Connect(function(message) if viewer.receive then pcall(viewer.receive, message) end end)
    iris:Connect(function() if viewer.draw then viewer.draw() end end)
end
local UNESCAPE = { ["\\"] = "\\", t = "\t", n = "\n" }
local RICH_ESCAPES, EMPTY = { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }, { "-" } -- shown for empty cells: pre-2.4 Iris stacks each column on its own, so an empty (shorter) cell would push the rest of its column out of line
local SORT_TIP = "Sort by this column. Click again to reverse, a third time for the original order"
local function fields(line)
    local out = {}
    for field in (line .. "\t"):gmatch("([^\t]*)\t") do table.insert(out, (field:gsub("\\(.)", UNESCAPE))) end
    return out
end
local labels = { fonts = nil, count = 0 } -- rich() results, so a label isn't rebuilt every frame; reset when the fonts change
local function rich(text, regular) -- titles, buttons, headers and tips in the theme's font (bold unless `regular`), by rich
    local theme, fonts = shared.iris_viewer_theme, shared.iris_viewer_fonts -- text, which iris_theme.luau turns on for these windows
    local tag = type(theme) == "table" and theme.RichText and fonts and (regular and fonts.text or fonts.label)
    if not tag then return text end
    if labels.fonts ~= fonts or labels.count > 2000 then labels = { fonts = fonts, count = 0 } end
    local key = (regular and "r" or "b") .. tostring(text)
    if not labels[key] then labels[key], labels.count = tag .. (tostring(text):gsub("[<>&]", RICH_ESCAPES)) .. "</font>", labels.count + 1 end
    return labels[key]
end
local function body(text, wrapped) -- iris.Text args in the theme's regular font
    local tagged = rich(text, true)
    return tagged ~= text and { tagged, wrapped, nil, true } or { text, wrapped }
end
local function tip(widget, text) -- hover help; hands the widget back so calls chain: tip(iris.X(...), "..").clicked()
    if text and iris.Tooltip and widget.hovered and widget.hovered() then set_id("dsp:tip"); iris.Tooltip({ rich(text, true) }) end
    return widget
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
            container = { title = f[1], open = f[2] == "1", tip = f[3] ~= "" and f[3] or nil, blocks = {}, key = report.key .. ":" .. count }
            table.insert(report.sections, container)
        elseif kind == "text" then
            count = count + 1
            table.insert(container.blocks, { text = { f[1] or "", true }, key = report.key .. ":" .. count })
        elseif kind == "columns" then
            count = count + 1
            current = { columns = f, rows = {}, slots = {}, header = table.concat(f) ~= "", key = report.key .. ":" .. count .. ":" .. #f }
            table.insert(container.blocks, current)
        elseif kind == "tips" and current then
            current.tips = f -- hover text per column header
        elseif kind == "row" and current then
            local cells = { search = string.lower(table.concat(f, " ")), number = {} } -- number: cells that are only a number
            for c, value in ipairs(f) do cells[c] = { value }; cells.number[c] = value:find("%d") and not value:find("[^%d%s,%.%%%$%+%-:/()hmstXP]") end
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
    if not ok then print("[viewer] could not read report " .. id .. ": " .. tostring(report)); return end
    local kind, player = report.id:match("^([^:]+):([^:]+)")
    if kind == "stats" or kind == "attachments" then
        local prefix = kind .. ":" .. player
        for i = #viewer.order, 1, -1 do
            local existing_id = viewer.order[i]
            if existing_id ~= report.id and (existing_id == prefix or existing_id:sub(1, #prefix + 1) == prefix .. ":") then
                table.remove(viewer.order, i); viewer.reports[existing_id] = nil
            end
        end
    end
    local old = viewer.reports[report.id]
    if not old then table.insert(viewer.order, report.id) end
    report.ui = old and old.ui or { pages = {}, filters = {}, seen = {}, sorts = {} } -- kept across refreshes
    local got_time, time_text = pcall(function() return os.date("%H:%M:%S") end)
    report.received = got_time and tostring(time_text) or "?"
    viewer.reports[report.id] = report
end
if #viewer.order == 0 and fire_server then pcall(fire_server, "dsp1|hello") end -- the server resends reports sent before this viewer started
return (function(drawing) drawing() end)(function() -- drawing: its own function with its own 255 lines (IRIS_VIEWER.md)
local depth = 0 -- open Iris containers, so an error can close them again
local CHAR_PX = 7 -- about how wide a character of 14px text is: a cell with more text than its column fits shows it all on hover
local HEAD_WIDTH = 1.2 -- a header (bold, in a button) is about this much wider per character; one that doesn't fit leads its tooltip with its name
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
local function cell(id, args, widget, help) -- widget: iris.Text, or iris.SmallButton for a sortable header; returns it
    if not NEW_TABLES then iris.NextColumn() end
    set_id(id)
    local drawn = tip((widget or iris.Text)(args), help) -- the tooltip goes before NextColumn, in this cell
    if NEW_TABLES then iris.NextColumn() end
    return drawn
end
local function styled(row, c, fonts) -- a cell's iris.Text args: rich text in its font (iris_theme.luau), bold for old headers
    local tag = fonts and (row.is_head and fonts.header or (row.number and row.number[c]) and fonts.number or fonts.text) -- (older rows: no .number)
    if row[c][1] == "" then return EMPTY end -- (display only: sorting and Export still see "")
    if not (tag or row.bold) then return row[c] end
    if row.rich_for ~= (fonts or row) then row.rich, row.rich_for = {}, fonts or row end -- cached until the fonts change
    if not row.rich[c] then
        local text = row[c][1]:gsub("[<>&]", RICH_ESCAPES)
        text = (row.bold and not tag) and "<b>" .. text .. "</b>" or text -- with a header font its weight applies instead
        row.rich[c] = { tag and tag .. text .. "</font>" or text, nil, nil, true }
    end
    return row.rich[c]
end
local function sort_key(row, c) -- number cells by value ("1h 2m 3s" in seconds), others as lower-case text
    local text = row[c] and row[c][1] or ""
    if not (row.number and row.number[c]) then return string.lower(text) end
    local seconds, units = 0, 0
    if text:find("^[%d%shms]+$") then
        for n, unit in text:gmatch("(%d+)([hms])") do seconds, units = seconds + (tonumber(n) or 0) * (unit == "h" and 3600 or unit == "m" and 60 or 1), units + 1 end
    end
    return units > 0 and seconds or tonumber((text:gsub(",", ""):match("%-?%d+%.?%d*"))) or 0
end
local function sorted_rows(tbl, ui) -- rows in the order a header click picked; sorted once per click or new report
    local sort = ui.sorts[tbl.key]
    if not sort then return tbl.rows end
    if sort.source ~= tbl.rows then
        local keyed = {}
        for i, row in ipairs(tbl.rows) do keyed[i] = { row = row, key = sort_key(row, sort.col), i = i } end
        table.sort(keyed, function(a, b)
            if a.key == b.key then return a.i < b.i end -- ties keep the server's order
            if type(a.key) ~= type(b.key) then return type(a.key) < type(b.key) end -- numbers before text
            return (a.key < b.key) ~= sort.desc
        end)
        sort.source, sort.rows = tbl.rows, {}
        for i, k in ipairs(keyed) do sort.rows[i] = k.row end
    end
    return sort.rows
end
local function next_sort(tbl, sort, c) -- a header click: number columns most first, text A-Z; again reverses; a third time, server order
    local first = (tbl.rows[1] and tbl.rows[1].number and tbl.rows[1].number[c]) and true or false
    if not sort or sort.col ~= c then return { col = c, desc = first } end
    if sort.desc == first then return { col = c, desc = not first } end
    return nil
end
local function visible_rows(tbl, ui)
    local all = sorted_rows(tbl, ui)
    if #all <= FILTER_ROWS then return all end
    set_id(tbl.key .. ":filter")
    local query = string.lower(tip(iris.InputText({ rich("Filter"), "type to filter rows" }), "Show only rows containing this text (any column)").state.text.value or "")
    local cache = ui.filters[tbl.key]
    if not (cache and cache.query == query and cache.source == all) then
        cache = { query = query, source = all, rows = {} }
        for _, row in ipairs(all) do
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
            if tip(iris.SmallButton({ rich("< Prev") }), "Previous page of rows").clicked() and page > 1 then page = page - 1 end
            set_id(tbl.key .. ":next")
            if tip(iris.SmallButton({ rich("Next >") }), "Next page of rows").clicked() and page < pages then page = page + 1 end
        end
        set_id(tbl.key .. ":all")
        if tip(iris.SmallButton({ rich(all and "Pages" or "Show all") }), all and "Back to paged rows" or "Draw every row (slow on long tables)").clicked() then ui.pages[tbl.key .. ":all"] = not all end
        set_id(tbl.key .. ":rows")
        iris.Text(body(all and string.format("all %d rows", #rows) or string.format("rows %d-%d of %d",
            (page - 1) * per_page + 1, math.min(page * per_page, #rows), #rows)))
        close()
    end
    ui.pages[tbl.key] = page
    local n = #tbl.columns
    set_id(tbl.key)
    if NEW_TABLES then -- NumColumns, Header, RowBackground, OuterBorders, InnerBorders, Resizable, FixedWidth, ProportionalWidth
        open(iris.Table({ n, tbl.header, true, true, true, false, false, true }))
        if tbl.header then iris.SetHeaderColumnIndex(1) end
    else -- NumColumns, RowBg, BordersOuter, BordersInner
        open(iris.Table({ n, true, true, true })) -- every column 1/n wide; Deadline's sandbox forbids resizing them (IRIS_VIEWER.md)
    end
    if tbl.header then -- the header row, made here so reports received by an older viewer have it too; Iris 2.4+ styles it, older gets bold
        if not tbl.head then tbl.head = { number = {}, bold = not NEW_TABLES }; for c, name in ipairs(tbl.columns) do tbl.head[c] = { name } end end
        if not tbl.head.is_head then tbl.head.is_head, tbl.head.rich_for = true, nil end -- (older viewers' header rows lack it; restyle them)
        local ids, sort = slot_ids(tbl, 0), ui.sorts[tbl.key]
        local room = ui.width and (ui.width - 40) / n / CHAR_PX -- characters a column shows
        for c = 1, n do
            local about = tbl.tips and tbl.tips[c] ~= "" and tbl.tips[c] or nil -- what the column means (server's tips line)
            if room and tbl.columns[c] ~= "" and #tbl.columns[c] * HEAD_WIDTH + 1 > room then about = about and (tbl.columns[c] .. ": " .. about) or tbl.columns[c] end
            if #tbl.rows < 2 then cell(ids[c], styled(tbl.head, c, shared.iris_viewer_fonts), nil, about) -- nothing to sort: plain header
            elseif cell(ids[c], { rich(tbl.columns[c] .. (sort and sort.col == c and (sort.desc and " \u{25BC}" or " \u{25B2}") or "")) },
                iris.SmallButton, about and (about .. "\n\n" .. SORT_TIP) or SORT_TIP).clicked() then
                ui.sorts[tbl.key], ui.pages[tbl.key] = next_sort(tbl, sort, c), 1
            end
        end
    end
    local first, fonts = (page - 1) * per_page, shared.iris_viewer_fonts
    local fits = ui.width and math.floor((ui.width - 40) / n / CHAR_PX) -- characters a column shows (columns are 1/n wide)
    for slot = 1, math.min(per_page, #rows - first) do
        local row, ids = rows[first + slot], slot_ids(tbl, slot)
        for c = 1, n do
            local text = row[c] and row[c][1]
            local cut = fits and text and #text > fits and ((utf8 and utf8.len(text)) or #text) > fits -- characters, not bytes
            cell(ids[c], text and styled(row, c, fonts) or EMPTY, nil, cut and text or nil)
        end
    end
    close()
end
local function draw_blocks(blocks, ui)
    for _, block in ipairs(blocks) do
        if block.text then set_id(block.key); iris.Text(body(block.text[1], true)) else draw_table(block, ui) end
    end
end
return (function(windows) windows() end)(function() -- windows: a third part with its own 255 lines (IRIS_VIEWER.md)
-- Iris's own close button (title bar, top right) can't be seen in-game: its X is a Studio-only image and
-- its background is see-through until hovered. So each window gets its own Close button, red if Color3 exists.
local CLOSE_COLORS = Color3 and { ButtonColor = Color3.fromRGB(170, 35, 25), ButtonHoveredColor = Color3.fromRGB(205, 50, 35),
    ButtonActiveColor = Color3.fromRGB(135, 25, 18) }
local EXPORT_BOX = (function() -- the Export box: plain text (rich text would eat "<" and "&" from what you copy), as wide
    local ok, width = pcall(function() return UDim and UDim.new(1, 0) or UDim2.new(1, 0, 0, 0).X end) -- as its window (Iris: 65%; needs UDim)
    return { RichText = false, ContentWidth = ok and width or nil }
end)()
local function configured(key, config, widget, args) -- widget(args) with `config` pushed for it alone
    local pushed = config and iris.PushConfig
    if pushed then set_id(key .. ":config"); pushed = pcall(iris.PushConfig, config) end
    set_id(key)
    local ok, drawn = pcall(widget, args)
    if pushed then pcall(iris.PopConfig) end -- popped even if the widget failed, or it would style everything after it
    if not ok then error(drawn, 0) end
    return drawn
end
local function close_button(key, window, help) -- closes `window` when clicked
    if tip(configured(key .. ":close", CLOSE_COLORS, iris.SmallButton, { rich("Close") }), help).clicked() then window.state.isOpened:set(false) end
end
local function export_text(report, ui) -- the whole report as tab-separated lines: pasted into a spreadsheet, each cell lands in its own column
    local lines, clean = { report.title }, function(value) return (tostring(value or ""):gsub("[\t\r\n]", " ")) end
    local function add(blocks)
        for _, block in ipairs(blocks) do
            if block.text then table.insert(lines, clean(block.text[1])) else
                if block.header then local names = {}; for c, name in ipairs(block.columns) do names[c] = clean(name) end; table.insert(lines, table.concat(names, "\t")) end
                for _, row in ipairs(sorted_rows(block, ui)) do -- in the order the table is sorted to
                    local cells = {}; for c = 1, #block.columns do cells[c] = clean(row[c] and row[c][1]) end; table.insert(lines, table.concat(cells, "\t"))
                end
            end
        end
    end
    add(report.blocks)
    for _, section in ipairs(report.sections) do table.insert(lines, ""); table.insert(lines, clean(section.title)); add(section.blocks) end
    return table.concat(lines, "\n")
end
local function draw_export(report) -- the Export window: a text box to select and copy from
    local ui = report.ui
    set_id(report.key .. ":exportwin")
    local window = open(iris.Window({ rich("Export: " .. report.title) }))
    if ui.export_new then
        window.state.isOpened:set(true)
        pcall(function() window.state.size:set(Vector2.new(700, 500)) end) -- skipped if Vector2 is not available
    end
    if window.state.isOpened.value and window.state.isUncollapsed.value then
        close_button(report.key .. ":export", window, "Close this window (Export opens it again)")
        set_id(report.key .. ":exporthelp"); iris.Text(body("Click in the box, press Ctrl+A then Ctrl+C, and paste into Excel or Google Sheets. Export again after a Refresh or a new sort.", true))
        local box = configured(report.key .. ":exportbox", EXPORT_BOX, iris.InputText, { "", "", false, true }) -- Text, TextHint, ReadOnly, MultiLine
        if ui.export_new then box.state.text:set(ui.export) end
        ui.export_new = nil
    end
    close()
end
local function draw_report(report, index)
    local ui = report.ui
    ui.sorts = ui.sorts or {} -- (reports kept from an older viewer lack it)
    set_id(report.key)
    local window = open(iris.Window({ rich(report.title) }))
    local sized, width = pcall(function() return window.state.size.value.X end)
    ui.width = sized and type(width) == "number" and width or nil -- for draw_table's cut-off cells
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
        close_button(report.key, window, "Close this window (the Stat printer window's Show opens it again)")
        if report.refresh ~= "" then
            set_id(report.key .. ":refresh")
            if tip(iris.SmallButton({ rich("Refresh") }), "Ask the server for a fresh copy of this report").clicked() and fire_server then
                pcall(fire_server, "dsp1|refresh|" .. report.refresh)
            end
        end
        set_id(report.key .. ":export")
        if tip(iris.SmallButton({ rich("Export") }), "Show this report as text to copy into Excel or Google Sheets").clicked() then ui.export, ui.export_new = export_text(report, ui), true end
        set_id(report.key .. ":updated"); iris.Text(body("Updated " .. report.received))
        close()
        draw_blocks(report.blocks, ui)
        for _, section in ipairs(report.sections) do
            set_id(section.key)
            local header = open(iris.CollapsingHeader({ rich(section.title) }))
            tip(header, not header.state.isUncollapsed.value and section.tip or nil) -- only while closed: open, Iris counts the whole section as the header
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
    local hub = open(iris.Window({ rich("Stat printer") }))
    if viewer.show_hub then viewer.show_hub = false; hub.state.isOpened:set(true) end
    if hub.state.isOpened.value and hub.state.isUncollapsed.value then
        close_button("dsp:hub", hub, "Close this window (shared.iris_viewer.show() in the client console opens it again)")
        if #viewer.order == 0 then
            set_id("dsp:hub:waiting")
            iris.Text(body(string.format("Waiting for reports: run print_player_stats, print_attachment_stats or "
                .. "cap_announcer in the server console. Messages received: %d%s", viewer.messages or 0,
                viewer.other and (", last one not a report: " .. viewer.other) or ""), true))
        end
        for _, id in ipairs(viewer.order) do
            local report = viewer.reports[id]
            set_id(report.key .. ":hubrow"); open(iris.SameLine())
            set_id(report.key .. ":show")
            if tip(iris.SmallButton({ rich("Show") }), "Open this report's window again").clicked() then report.popup = true end
            set_id(report.key .. ":hubtitle"); iris.Text(body(report.title .. "  (" .. report.received .. ")"))
            close()
        end
        if #viewer.order > 0 then
            set_id("dsp:hub:clear")
            if tip(iris.SmallButton({ rich("Clear all") }), "Forget every report received so far").clicked() then viewer.reports, viewer.order = {}, {} end
        end
        if viewer.error then set_id("dsp:hub:error"); iris.Text(body("Error: " .. viewer.error, true)) end
    end
    close()
end
local function guarded(draw, ...) -- closes what a failing window left open; reports the error once
    local base = depth
    local ok, err = pcall(draw, ...)
    while depth > base do depth = depth - 1; pcall(iris.End) end
    if not ok and not viewer.error then viewer.error = tostring(err); print("[viewer] " .. viewer.error) end
    return ok, err
end
viewer.draw = function()
    depth = 0
    local theme = type(shared.iris_viewer_theme) == "table" and iris.PushConfig and shared.iris_viewer_theme -- iris_theme.luau
    if theme then set_id("dsp:theme"); theme = pcall(iris.PushConfig, theme) end -- styles only these windows
    local hub_ok, hub_err = guarded(draw_hub)
    if theme and not hub_ok then -- a theme value Iris rejects would break every window: drop the theme
        shared.iris_viewer_theme, viewer.error = nil, "theme turned off, Iris rejected it: " .. tostring(hub_err)
        print("[viewer] " .. viewer.error)
    end
    for i, id in ipairs(viewer.order) do
        guarded(draw_report, viewer.reports[id], i)
        if viewer.reports[id] and viewer.reports[id].ui.export then guarded(draw_export, viewer.reports[id]) end
    end
    if theme then pcall(iris.PopConfig) end
end
viewer.show = function() viewer.show_hub = true; for _, r in pairs(viewer.reports) do r.popup = true end end -- shared.iris_viewer.show()
viewer.error = nil; viewer.show()
print(string.format("[viewer] ready (Iris %s tables); shared.iris_viewer.show() reopens closed windows.", NEW_TABLES and "2.4+" or "pre-2.4"))
end)
end)
