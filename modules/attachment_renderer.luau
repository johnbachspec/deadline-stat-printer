-- modules/attachment_renderer.luau
-- Shows aggregated attachment rows (from attachment_aggregator): a readable
-- table with in-game names (printed, or added to an Iris report), or Lua-table
-- lines that tests/fixtures are made from.
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

-- deps = { weapon_data = WeaponData, names = attachment_names module or nil }
function AttachmentRenderer.new(deps)
    local names = deps.names
    return setmetatable({
        weapon_data = deps.weapon_data,
        names = (names and names.NAMES) or {},
        names_version = names and names.VERSION,
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

function AttachmentRenderer:names_source()
    if self.names_version then
        return "names: deadline-balancing " .. tostring(self.names_version)
    end
    return "names: prettified ids (attachment_names module not loaded)"
end

function AttachmentRenderer:render_table(aggregated)
    local items = aggregated.items
    local names, width = {}, 0
    for i, item in ipairs(items) do
        names[i] = self:item_name(item)
        width = math.min(math.max(width, text_width(names[i])), NAME_COLUMN_MAX)
    end
    print(string.format("\n================ ALL %d ATTACHMENTS BY KILLS ================", #items))
    print("-- " .. self:names_source())
    for i, item in ipairs(items) do
        print(string.format("#%-3d %s | Kills: %-6d | Top Gun: %s (%d)",
            i,
            names[i] .. string.rep(" ", math.max(0, width - text_width(names[i]))),
            item.kills,
            self:gun_name(item.top_gun),
            item.top_gun_kills))
    end
end

-- The same table for iris_viewer.luau; `report` is a modules/iris_report.luau report.
function AttachmentRenderer:add_to_report(report, aggregated)
    local items = aggregated.items
    report:text(self:names_source())
    report:section(string.format("All %d attachments by kills", #items), true, "Every attachment this player has kills with, most kills first\n"
        .. "Kills: kills with it equipped   Top gun: the weapon it got the most kills on, with those kills")
    report:columns({ "Attachment", "Kills", "Top gun (kills)" })
    for i, item in ipairs(items) do
        report:row({ string.format("%d. %s", i, self:item_name(item)), tostring(item.kills),
            string.format("%s (%d)", self:gun_name(item.top_gun), item.top_gun_kills) })
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
