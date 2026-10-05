-- modules/attachment_renderer.luau
-- Shows aggregated attachment rows (from attachment_aggregator): a readable
-- table with in-game names (printed, or added to an Iris report), the same rows
-- grouped by gun, or Lua-table lines that tests/fixtures are made from.
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ('Fiu') that does not
-- accept Luau type annotations, so this file intentionally has none.

local AttachmentRenderer = {}
AttachmentRenderer.__index = AttachmentRenderer

local NAME_COLUMN_MAX = 72 -- longer names overflow their own row instead of widening every row

-- Used for ids the names module does not know yet (or when it is not loaded).
local ACRONYMS = {
    acog = "ACOG", afg = "AFG", ak = "AK", ar = "AR", bcm = "BCM", bt = "B&T", cqb = "CQB", dd = "DD",
    ecm = "ECM", eotech = "EOTech", fal = "FAL", fmj = "FMJ", fmjbt = "FMJBT", fn = "FN", g3 = "G3",
    hk = "HK", hp = "HP", jsp = "JSP", kac = "KAC", kag = "KAG", m4 = "M4", m4a1 = "M4A1", m16 = "M16",
    mlok = "M-LOK", moa = "MOA", moe = "MOE", mp5 = "MP5", mp5k = "MP5K", mvg = "MVG", oem = "OEM",
    otm = "OTM", pdw = "PDW", pepr = "P.E.P.R.", pmag = "PMAG", prs = "PRS", ps = "PS", psrl = "PSRL",
    qd = "QD", rmr = "RMR", sa58 = "SA58", sat = "SAT", sc = "SC", scar = "SCAR", scarh = "SCAR-H",
    scarl = "SCAR-L", sf = "SF", smr = "SMR", spr = "SPR", sro = "SRO", ssr = "SSR", std = "Standard",
    urgi = "URG-I",
}

local function prettify(id)
    local words = {}
    for part in string.gmatch(tostring(id or "Unknown"), "[^_]+") do
        local lower = string.lower(part)
        local word = ACRONYMS[lower]
        if not word and string.find(lower, "%d[a-wyz]%d") then
            word = string.upper(lower) -- model numbers: m855a1 -> M855A1, 7n6 -> 7N6 (5.56x45 stays)
        elseif not word then
            word = string.upper(string.match(lower, "^.") or "") .. string.sub(lower, 2)
        end
        table.insert(words, word)
    end
    return table.concat(words, " ")
end

-- Printed width in characters (some names contain multi-byte UTF-8 letters).
local function text_width(s)
    return (utf8 and utf8.len(s)) or #s
end

-- deps = { weapon_data = WeaponData, names = attachment_names module or nil,
--         top_guns = how many guns a row lists (default 3; 1 = the top gun only) }
function AttachmentRenderer.new(deps)
    local names = deps.names
    return setmetatable({
        weapon_data = deps.weapon_data,
        names = (names and names.NAMES) or {},
        names_version = names and names.VERSION,
        top_guns = math.max(1, tonumber(deps.top_guns) or 3),
    }, AttachmentRenderer)
end

function AttachmentRenderer:item_name(item)
    if item.group then
        return string.format("%s (%d pieces)", item.group, item.pieces)
    end
    return self.names[item.id] or prettify(item.id)
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

-- Only the rows whose in-game name contains `search` (case-insensitive); "" or nil keeps all.
function AttachmentRenderer:matching(aggregated, search)
    local query = string.lower(search or "")
    if query == "" then return aggregated end
    local items = {}
    for _, item in ipairs(aggregated.items) do
        if string.find(string.lower(self:item_name(item)), query, 1, true) then
            table.insert(items, item)
        end
    end
    return { items = items, legacy_merged = aggregated.legacy_merged }
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

function AttachmentRenderer:names_source()
    if self.names_version then
        return "names: deadline-balancing " .. tostring(self.names_version)
    end
    return "names: prettified ids (attachment_names module not loaded)"
end

-- Names padded to one width (capped at NAME_COLUMN_MAX): name(i) for entry i.
local function name_column(self, entries, item_of)
    local names, width = {}, 0
    for i, entry in ipairs(entries) do
        names[i] = self:item_name(item_of and item_of(entry) or entry)
        width = math.min(math.max(width, text_width(names[i])), NAME_COLUMN_MAX)
    end
    return function(i) return names[i] .. string.rep(" ", math.max(0, width - text_width(names[i]))) end
end

-- The first `rows` entries (all of them when rows is 0 or nil), and how many were left out.
local function first_rows(entries, rows)
    rows = tonumber(rows) or 0
    if rows <= 0 or #entries <= rows then return entries, 0 end
    local shown = {}
    for i = 1, rows do shown[i] = entries[i] end
    return shown, #entries - rows
end

local function print_hidden(hidden)
    if hidden > 0 then
        print(string.format("... %d more not printed here: the Iris window has every row (Export copies them),"
            .. " or set CONSOLE_ROWS = 0", hidden))
    end
end

-- opts (optional): { gun, search } the rows were limited to, for the title, and
-- rows: how many to print (0 or nil = all). With a gun, Kills are kills on that
-- gun and the gun columns are left out.
function AttachmentRenderer:render_table(aggregated, opts)
    opts = opts or {}
    local items, hidden = first_rows(aggregated.items, opts.rows)
    local name = name_column(self, items)
    local scope = self:scope(opts)
    print(string.format("\n================ %s%d ATTACHMENTS BY KILLS%s ================",
        scope == "" and "ALL " or "", #aggregated.items, string.upper(scope)))
    print("-- " .. self:names_source())
    for i, item in ipairs(items) do
        local line = string.format("#%-3d %s | Kills: %-6d", i, name(i), item.kills)
        if not opts.gun then
            line = line .. string.format(" | Top Gun: %s (%d)", self:gun_name(item.top_gun), item.top_gun_kills)
            local others = self:other_guns(item)
            if others ~= "" then line = line .. " | Also: " .. others end
        end
        print(line)
    end
    print_hidden(hidden)
end

-- The rows grouped by gun (attachment_aggregator.by_gun), each gun's attachments
-- by kills on that gun, opts.rows of them per gun. With opts.gun the rows only hold
-- that gun's kills, so the "All guns" total is left out.
function AttachmentRenderer:render_by_gun(by_gun, opts)
    local all_guns = not (opts and opts.gun)
    print(string.format("\n================ ATTACHMENT KILLS BY GUN%s: %d GUNS ================",
        string.upper(self:scope(opts)), #by_gun))
    print("-- " .. self:names_source())
    for _, gun in ipairs(by_gun) do
        print(string.format("\n---- %s: %d attachment%s ----", self:gun_name(gun.id), #gun.items, #gun.items == 1 and "" or "s"))
        local entries, hidden = first_rows(gun.items, opts and opts.rows)
        local name = name_column(self, entries, function(entry) return entry.item end)
        for i, entry in ipairs(entries) do
            print(string.format("#%-3d %s | Kills: %-6d", i, name(i), entry.kills)
                .. (all_guns and string.format(" | All guns: %d", entry.item.kills) or ""))
        end
        print_hidden(hidden)
    end
end

-- The same table for iris_viewer.luau; `report` is a modules/iris_report.luau report.
-- opts as for render_table.
function AttachmentRenderer:add_to_report(report, aggregated, opts)
    opts = opts or {}
    local items = aggregated.items
    local scope = self:scope(opts)
    report:text(self:names_source())
    if opts.gun then
        report:section(string.format("%d attachments%s by kills", #items, scope), true,
            "Every attachment this player has kills with on this gun, most kills first\n"
            .. "Kills: kills on this gun with it equipped   Click a column header to sort by it")
        report:columns({ "#", "Attachment", "Kills" })
        for i, item in ipairs(items) do
            report:row({ tostring(i), self:item_name(item), tostring(item.kills) })
        end
        return
    end
    report:section(string.format("%s%d attachments%s by kills", scope == "" and "All " or "", #items, scope), true,
        "Every attachment this player has kills with, most kills first\n"
        .. "Kills: kills with it equipped, on every gun   Top gun: the gun it got the most kills on\n"
        .. "Other guns: the next guns by kills   Guns: how many guns it has kills on\n"
        .. "Click a column header to sort by it")
    report:columns({ "#", "Attachment", "Kills", "Top gun", "Top gun kills", "Other guns", "Guns" })
    for i, item in ipairs(items) do
        report:row({ tostring(i), self:item_name(item), tostring(item.kills), self:gun_name(item.top_gun),
            tostring(item.top_gun_kills), self:other_guns(item), tostring(#(item.guns or {})) })
    end
end

-- The by-gun view for iris_viewer.luau: one section per gun, the first one open.
function AttachmentRenderer:add_by_gun_to_report(report, by_gun, opts)
    local all_guns = not (opts and opts.gun) -- as in render_by_gun
    report:text(self:names_source())
    report:text(string.format("%d guns%s, most-used first. Open a gun to see its attachments.", #by_gun, self:scope(opts)))
    for g, gun in ipairs(by_gun) do
        report:section(string.format("%s (%d attachment%s)", self:gun_name(gun.id), #gun.items, #gun.items == 1 and "" or "s"), g == 1,
            "Attachments with kills on this gun, most first\n"
            .. "Kills: kills on this gun with it equipped" .. (all_guns and "   All guns: its kills on every gun" or ""))
        report:columns(all_guns and { "#", "Attachment", "Kills", "All guns" } or { "#", "Attachment", "Kills" })
        for i, entry in ipairs(gun.items) do
            local row = { tostring(i), self:item_name(entry.item), tostring(entry.kills) }
            if all_guns then table.insert(row, tostring(entry.item.kills)) end
            report:row(row)
        end
    end
end

-- Lua-table lines of raw ids, chunk_size entries per line; saved copies of this
-- output are the fixtures tools/verify_attachment_merge.py and the tests replay.
function AttachmentRenderer:render_delimited(aggregated, player_name, chunk_size)
    local items = aggregated.items
    chunk_size = chunk_size or 100
    print(string.format("-- TOTAL ATTACHMENTS FOR %s: %d (split into lines of %d)", tostring(player_name), #items, chunk_size))
    if aggregated.legacy_merged > 0 then
        print(string.format("-- ALIASES MERGED: %d legacy attachment ids folded into current ids (renames.csv)", aggregated.legacy_merged))
    end
    print("ATTACHMENT_DATA = {")
    local line_items = {}
    for i, item in ipairs(items) do
        table.insert(line_items, string.format('["%s"]={kills=%d,top_gun="%s",top_gun_kills=%d}',
            item.id, item.kills, item.top_gun, item.top_gun_kills))
        if #line_items == chunk_size or i == #items then
            print(" " .. table.concat(line_items, ", ") .. (i == #items and "" or ","))
            line_items = {}
            if task and task.wait then task.wait(0.05) end -- let long output stream
        end
    end
    print("}")
end

return AttachmentRenderer
