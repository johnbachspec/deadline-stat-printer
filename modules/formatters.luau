-- modules/formatters.luau
-- SRP: pure string/number formatting helpers. No knowledge of weapons,
-- players, or layout widths beyond what's passed in as arguments.
-- Every function here is a pure function: same input -> same output,
-- no side effects (no print calls), which makes them trivially testable.

local Formatters = {}

function Formatters.format_num(val)
    local safe_val = tonumber(val) or 0
    local formatted = string.format("%.0f", math.floor(safe_val))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

function Formatters.format_currency(amount)
    return "$" .. Formatters.format_num(amount)
end

function Formatters.format_use_time(total_seconds)
    local safe_sec = tonumber(total_seconds) or 0
    if safe_sec >= 3600 then
        local hours = math.floor(safe_sec / 3600)
        local mins = math.floor((safe_sec % 3600) / 60)
        local secs = math.floor(safe_sec % 60)
        return string.format("%dh %2dm %2ds", hours, mins, secs)
    elseif safe_sec >= 60 then
        local mins = math.floor(safe_sec / 60)
        local secs = math.floor(safe_sec % 60)
        return string.format("%2dm %2ds", mins, secs)
    else
        return string.format("%2ds", math.floor(safe_sec))
    end
end

function Formatters.format_duration_short(total_seconds)
    local safe_sec = tonumber(total_seconds) or 0
    local mins = math.floor(safe_sec / 60)
    local secs = math.floor(safe_sec % 60)
    if mins > 0 then
        return string.format("%dm %ds", mins, secs)
    else
        return string.format("%ds", secs)
    end
end

-- Pad a string on the right with spaces up to `length`. Never truncates.
function Formatters.pad_right(str, length)
    str = tostring(str or "")
    if #str >= length then
        return str
    end
    return str .. string.rep(" ", length - #str)
end

-- Centers text within `width` using manual space-repeat instead of a
-- dynamic-width format specifier ("%Ns"), which some Lua/Luau VMs cap
-- and will error on ("invalid format: width or precision too long")
-- once the computed width crosses ~100, e.g. from long player names.
function Formatters.center_text(text, width)
    text = tostring(text or "")
    local pad = (width or 0) - string.len(text)
    if pad < 0 then pad = 0 end
    return string.rep(" ", math.floor(pad / 2)) .. text
end

return Formatters
