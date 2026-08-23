-- modules/formatters.luau
-- Pure string/number formatting helpers.

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
    local hours, mins, secs = math.floor(sec / 3600), math.floor((sec % 3600) / 60), math.floor(sec % 60)
    if hours > 0 then return string.format("%dh %2dm %2ds", hours, mins, secs) end
    if mins > 0 then return string.format("%2dm %2ds", mins, secs) end
    return string.format("%2ds", secs)
end

-- seconds -> "2m 3s" / "3s"
function Formatters.format_duration_short(total_seconds)
    local sec = tonumber(total_seconds) or 0
    local mins, secs = math.floor(sec / 60), math.floor(sec % 60)
    if mins > 0 then return string.format("%dm %ds", mins, secs) end
    return string.format("%ds", secs)
end

function Formatters.pad_right(str, length)
    str = tostring(str)
    return str .. string.rep(" ", math.max(0, length - #str))
end

-- Manual padding instead of "%Ns": Luau caps format widths at two digits and
-- errors once a long player name pushes the width past 99.
function Formatters.center_text(text, width)
    return string.rep(" ", math.max(0, math.floor((width - #text) / 2))) .. text
end

return Formatters
