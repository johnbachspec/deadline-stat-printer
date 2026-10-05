-- modules/attachment_renderer.luau
-- Lays out aggregated attachment rows (from attachment_aggregator) as views: the
-- attachments view (one table) or the guns view (one table per gun). A view is plain
-- data, built once; print_view writes it to the console and add_view to an Iris
-- report, so both always show the same cells, and a new view needs no new output code.
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ('Fiu') that does not
-- accept Luau type annotations, so this file intentionally has none.

local AttachmentRenderer = {}
AttachmentRenderer.__index = AttachmentRenderer

local NAME_COLUMN_MAX = 72 -- longer names overflow their own row instead of widening every row

local ATTACHMENT_COLUMNS = { "#", "Attachment", "Kills", "Top gun", "Top gun kills", "Other guns", "Guns" }
local ONE_GUN_COLUMNS = { "#", "Attachment", "Kills" }
local BY_GUN_COLUMNS = { "#", "Attachment", "Kills", "All guns" }
local TIPS = {
    attachments = "Every attachment this player has kills with, most kills first\n"
        .. "Kills: kills with it equipped, on every gun   Top gun: the gun it got the most kills on\n"
        .. "Other guns: the next guns by kills   Guns: how many guns it has kills on\n"
        .. "Click a column header to sort by it",
    one_gun = "Every attachment this player has kills with on this gun, most kills first\n"
        .. "Kills: kills on this gun with it equipped   Click a column header to sort by it",
    by_gun = "Attachments with kills on this gun, most first\nKills: kills on this gun with it equipped",
    all_guns = "   All guns: its kills on every gun",
}

-- deps = { weapon_data = WeaponData, labels = AttachmentLabels object, formatters = Formatters,
--         top_guns = how many guns a row lists (default 3; 1 = the top gun only) }
function AttachmentRenderer.new(deps)
    return setmetatable({
        weapon_data = deps.weapon_data,
        labels = deps.labels,
        fmt = deps.formatters,
        top_guns = math.max(1, tonumber(deps.top_guns) or 3),
    }, AttachmentRenderer)
end

-- Guns use the stat panel's names (weapon_data), so both reports agree.
function AttachmentRenderer:gun_name(gun_id)
    return self.weapon_data.display_name(gun_id)
end

-- The other guns after the top one, up to top_guns in all: "M4A1 (40), MP5 (3), +2 more".
function AttachmentRenderer:other_guns(item)
    local guns, parts = item.guns or {}, {}
    for i = 2, math.min(#guns, self.top_guns) do
        table.insert(parts, string.format("%s (%d)", self:gun_name(guns[i].id), guns[i].kills))
    end
    if #guns > self.top_guns and self.top_guns > 1 then
        table.insert(parts, string.format("+%d more", #guns - self.top_guns))
    end
    return table.concat(parts, ", ")
end

-- What a view is limited to, for titles: ' on AKM matching "eotech"', or "".
-- opts = { gun = current gun id or nil, search = text or nil }
function AttachmentRenderer:scope(opts)
    opts = opts or {}
    local parts = {}
    if opts.gun then table.insert(parts, "on " .. self:gun_name(opts.gun)) end
    if (opts.search or "") ~= "" then table.insert(parts, string.format('matching "%s"', opts.search)) end
    return #parts > 0 and (" " .. table.concat(parts, " ")) or ""
end

-- Console lines, from a row's cells and its name padded to the name column.
local function kills_line(cells, name)
    return string.format("#%-3s %s | Kills: %-6s", cells[1], name, cells[3])
end
local function attachment_line(cells, name)
    local line = kills_line(cells, name) .. string.format(" | Top Gun: %s (%s)", cells[4], cells[5])
    return cells[6] ~= "" and (line .. " | Also: " .. cells[6]) or line
end
local function by_gun_line(cells, name)
    return kills_line(cells, name) .. (cells[4] and (" | All guns: " .. cells[4]) or "")
end

local function plural(count, word)
    return string.format("%d %s%s", count, word, count == 1 and "" or "s")
end

-- A view = { banner = console title, intro = Iris-only text or nil, tables = { {
--   heading = console sub-title or nil, title, open, tip (Iris section),
--   columns, rows = { cell strings }, line = function(cells, padded name) -> console line } } }

-- Every attachment, most kills first. With opts.gun, Kills are kills on that gun and
-- the gun columns are left out.
function AttachmentRenderer:attachments_view(aggregated, opts)
    opts = opts or {}
    local items, scope, rows = aggregated.items, self:scope(opts), {}
    for i, item in ipairs(items) do
        local name = self.labels:name(item)
        rows[i] = opts.gun and { tostring(i), name, tostring(item.kills) }
            or { tostring(i), name, tostring(item.kills), self:gun_name(item.top_gun), tostring(item.top_gun_kills),
                self:other_guns(item), tostring(#(item.guns or {})) }
    end
    return {
        banner = string.format("================ %s%d ATTACHMENTS BY KILLS%s ================",
            scope == "" and "ALL " or "", #items, string.upper(scope)),
        tables = { {
            title = string.format("%s%d attachments%s by kills", (scope == "" and not opts.gun) and "All " or "", #items, scope),
            open = true,
            tip = opts.gun and TIPS.one_gun or TIPS.attachments,
            columns = opts.gun and ONE_GUN_COLUMNS or ATTACHMENT_COLUMNS,
            rows = rows,
            line = opts.gun and kills_line or attachment_line,
        } },
    }
end

-- One table per gun (attachment_aggregator.by_gun), each gun's attachments by kills
-- on that gun. With opts.gun the rows only hold that gun's kills, so the "All guns"
-- total is left out.
function AttachmentRenderer:guns_view(by_gun, opts)
    local all_guns, scope, tables = not (opts and opts.gun), self:scope(opts), {}
    for g, gun in ipairs(by_gun) do
        local rows = {}
        for i, entry in ipairs(gun.items) do
            rows[i] = { tostring(i), self.labels:name(entry.item), tostring(entry.kills) }
            if all_guns then table.insert(rows[i], tostring(entry.item.kills)) end
        end
        local name, count = self:gun_name(gun.id), plural(#gun.items, "attachment")
        tables[g] = {
            heading = name .. ": " .. count,
            title = name .. " (" .. count .. ")",
            open = g == 1,
            tip = TIPS.by_gun .. (all_guns and TIPS.all_guns or ""),
            columns = all_guns and BY_GUN_COLUMNS or ONE_GUN_COLUMNS,
            rows = rows,
            line = by_gun_line,
        }
    end
    return {
        banner = string.format("================ ATTACHMENT KILLS BY GUN%s: %d GUNS ================", string.upper(scope), #by_gun),
        intro = string.format("%d guns%s, most-used first. Open a gun to see its attachments.", #by_gun, scope),
        tables = tables,
    }
end

-- The first `limit` rows (all of them when limit is 0 or nil), and how many were left out.
local function first_rows(rows, limit)
    limit = tonumber(limit) or 0
    if limit <= 0 or #rows <= limit then return rows, 0 end
    local shown = {}
    for i = 1, limit do shown[i] = rows[i] end
    return shown, #rows - limit
end

-- Prints a view to the console, `limit` rows per table (0 or nil = all).
function AttachmentRenderer:print_view(view, limit)
    print("\n" .. view.banner)
    print("-- " .. self.labels:source())
    for _, tbl in ipairs(view.tables) do
        if tbl.heading then print("\n---- " .. tbl.heading .. " ----") end
        local shown, hidden = first_rows(tbl.rows, limit)
        local width = 0
        for _, cells in ipairs(shown) do
            width = math.min(math.max(width, self.fmt.text_width(cells[2])), NAME_COLUMN_MAX)
        end
        for _, cells in ipairs(shown) do
            print(tbl.line(cells, self.fmt.pad_right(cells[2], width)))
        end
        if hidden > 0 then
            print(string.format("... %d more not printed here: the Iris window has every row (Export copies them),"
                .. " or set CONSOLE_ROWS = 0", hidden))
        end
    end
end

-- Adds a view to an Iris report (modules/iris_report.luau): every row of every table.
function AttachmentRenderer:add_view(report, view)
    report:text(self.labels:source())
    if view.intro then report:text(view.intro) end
    for _, tbl in ipairs(view.tables) do
        report:section(tbl.title, tbl.open, tbl.tip)
        report:columns(tbl.columns)
        for _, cells in ipairs(tbl.rows) do report:row(cells) end
    end
end

return AttachmentRenderer
