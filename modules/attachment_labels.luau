-- modules/attachment_labels.luau
-- What an attachment row is called: its in-game name from attachment_names.luau, the
-- product name for pieces grouped into one row, or a prettified id for ids the names
-- module doesn't know yet (or when it isn't loaded).
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ('Fiu') that does not
-- accept Luau type annotations, so this file intentionally has none.

local AttachmentLabels = {}
AttachmentLabels.__index = AttachmentLabels

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

-- names_module: modules/attachment_names.luau, or nil when it didn't load.
function AttachmentLabels.new(names_module)
    return setmetatable({
        names = (names_module and names_module.NAMES) or {},
        version = names_module and names_module.VERSION,
    }, AttachmentLabels)
end

-- item: an attachment_aggregator row ({ id, group?, pieces? }).
function AttachmentLabels:name(item)
    if item.group then
        return string.format("%s (%d pieces)", item.group, item.pieces)
    end
    return self.names[item.id] or prettify(item.id)
end

-- Where the names came from, for the line above every attachment table.
function AttachmentLabels:source()
    if self.version then
        return "Names: deadline-balancing " .. tostring(self.version)
    end
    return "Names: prettified ids (attachment_names module not loaded)"
end

return AttachmentLabels
