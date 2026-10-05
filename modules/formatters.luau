-- modules/formatters.luau
-- Pure string/number formatting helpers (the stat math is in modules/stats_summary.luau).
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ("Fiu") that does not
-- accept Luau type annotations, so this file intentionally has none.

local Formatters = {}

-- 1234567 -> "1,234,567"
function Formatters.format_num(val)
    local formatted = string.format("%.0f", math.floor(tonumber(val) or 0))
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

function Formatters.format_currency(amount)
    return "$" .. Formatters.format_num(amount)
end

-- seconds -> "1h  2m  3s" / " 2m  3s" / " 3s"
function Formatters.format_use_time(total_seconds)
    local sec = tonumber(total_seconds) or 0
    local hours = math.floor(sec / 3600)
    local mins = math.floor((sec % 3600) / 60)
    local secs = math.floor(sec % 60)
    if hours > 0 then return string.format("%dh %2dm %2ds", hours, mins, secs) end
    if mins > 0 then return string.format("%2dm %2ds", mins, secs) end
    return string.format("%2ds", secs)
end

-- seconds -> "2m 3s" / "3s"
function Formatters.format_duration_short(total_seconds)
    local sec = tonumber(total_seconds) or 0
    local mins = math.floor(sec / 60)
    local secs = math.floor(sec % 60)
    if mins > 0 then return string.format("%dm %ds", mins, secs) end
    return string.format("%ds", secs)
end

-- Printed width in characters: names like 'Hellfire 3”' hold multi-byte UTF-8
-- characters, so their byte count (#s) is larger than what the console shows.
function Formatters.text_width(str)
    local s = tostring(str)
    return (utf8 and utf8.len(s)) or #s
end

function Formatters.pad_right(str, length)
    local s = tostring(str)
    return s .. string.rep(" ", math.max(0, length - Formatters.text_width(s)))
end

-- Manual padding instead of "%Ns": Luau caps format widths at two digits and
-- errors once a long player name pushes the width past 99.
function Formatters.center_text(text, width)
    return string.rep(" ", math.max(0, math.floor((width - Formatters.text_width(text)) / 2))) .. text
end

return Formatters
