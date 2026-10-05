-- modules/renderer.luau
-- The account recap and the per-weapon table, printed to the in-game Luau
-- console or added to an Iris report (modules/iris_report.luau). Formatting and
-- layout only: the numbers come worked out from modules/stats_summary.luau
-- (data.summary, and w.numbers on each weapon row).

local Renderer = {}
Renderer.__index = Renderer

local DEFAULT_GRID_WIDTH = 166
local ROW_FORMAT         = "%-20s %10s %11s %11s %10s %10s %12s %8s %8s %14s %16s %10s  %-8.8s"
local WEAPON_COLUMNS     = { "Weapon", "Kills", "Deaths w/", "Deaths by", "w-KDR", "% allK", "Rds. ct", "K/Min",
    "RFpK", "Weapon XP", "Time used", "% allT", "Type" }
local DEATHS_WITH_NOTE   = "Deaths w/ = deaths while carrying the weapon in any slot (one death counts toward every carried weapon)" -- console only: Iris shows SECTION_TIPS.weapons
local SECTION_TIPS       = { -- hover text for the viewer's section headers
    overall = "Lifetime totals from this player's profile: kills, deaths, headshots, wallbangs, money, XP and time played",
    averages = "Lifetime totals divided by matches played or by minutes alive",
    weapons = "One row per weapon; % columns are shares of the weapons listed. Hover a column's name for what it means",
}
local WEAPON_TIPS        = { -- hover text for the viewer's weapon table headers
    ["Deaths w/"] = "Deaths while carrying it in any slot (a death counts for every weapon carried)",
    ["Deaths by"] = "Deaths to it", ["w-KDR"] = "Kills / Deaths w/", ["% allK"] = "Share of kills",
    ["Rds. ct"] = "Rounds fired", ["K/Min"] = "Kills per minute used", ["RFpK"] = "Rounds fired per kill",
    ["Weapon XP"] = "Weapon XP earned", ["Time used"] = "Time held", ["% allT"] = "Share of time held",
    ["Type"] = "Caliber or class",
}

-- deps = { formatters = ..., grid_width = 166 (optional) }
function Renderer.new(deps)
    local width = deps.grid_width or DEFAULT_GRID_WIDTH
    return setmetatable({
        fmt = deps.formatters,
        grid_width = width,
        bar = string.rep("=", width),
        thin_bar = string.rep("-", width),
    }, Renderer)
end

-- Prints `columns` (a list of equal-length string lists) side by side.
function Renderer:print_columns(columns)
    local width = math.floor((self.grid_width - (#columns - 1)) / #columns)
    for row = 1, #columns[1] do
        local cells = {}
        for col, lines in ipairs(columns) do
            local cell = (col == 1 and " " or "") .. lines[row]
            cells[col] = col < #columns and self.fmt.pad_right(cell, width) or cell
        end
        print(table.concat(cells, "| "))
    end
end

function Renderer:print_title(title)
    print(self.fmt.center_text(title, self.grid_width))
    print("")
end

-- The recap as columns of { label, value } pairs: three columns of account
-- totals, then five columns of per-match / per-minute averages, from data.summary
-- (StatsSummary.account), which covers every weapon whatever FILTER_TYPE is.
function Renderer:recap_cells(data)
    local fmt, s = self.fmt, data.summary
    local next_level = s.xp_to_next > 0 and (fmt.format_num(s.xp_to_next) .. " XP") or "MAX"
    local status = #s.tester_tags > 0 and table.concat(s.tester_tags, ", ") or "None"
    local totals = {
        {
            { "Level:", s.level },
            { "Kills:", fmt.format_num(s.kills) },
            { "Headshots:", fmt.format_num(s.headshots) },
            { "HS %:", string.format("%.2f%%", s.hs_pct) },
            { "Matches Played:", fmt.format_num(s.matches) },
            { "Total Money Spent:", fmt.format_currency(s.spent) },
            { "Time Alive:", fmt.format_duration(s.alive_sec) },
            { "Status:", status },
            { "Owned Weapons:", fmt.format_num(s.collection.weapons) },
        },
        {
            { "Prestige Level:", s.prestige_level },
            { "Deaths:", fmt.format_num(s.deaths) },
            { "Wallbangs:", fmt.format_num(s.wallbangs) },
            { "Wall %:", string.format("%.2f%%", s.wall_pct) },
            { "Objectives Cap:", fmt.format_num(s.points) },
            { "On Attachments:", string.format("%s (%.2f%%)", fmt.format_currency(s.spent_attachments), s.attachments_pct) },
            { "Total Experience:", fmt.format_num(s.xp) },
            { "Next Level In:", next_level },
            { "Owned Attachments:", fmt.format_num(s.collection.attachments) },
        },
        {
            { "Prestige:", s.prestige },
            { "KDR:", string.format("%.5f", s.kdr) },
            { "HE Kills:", fmt.format_num(s.he_kills) },
            { "HE %:", string.format("%.2f%%", s.he_pct) },
            { "Rounds / Kill:", string.format("%.2f", s.rounds_per_kill) },
            { "On Weapons:", string.format("%s (%.2f%%)", fmt.format_currency(s.spent_weapons), s.weapons_pct) },
            { "Dist Travelled:", fmt.format_num(s.distance) .. " st" },
            { "Rounds Fired:", fmt.format_num(s.rounds) },
            { "Owned Camos:", fmt.format_num(s.collection.camos) },
        },
    }
    local averages = {
        { { "Kills / Match:", string.format("%.2f", s.kills_per_match) },
          { "XP / Match:", fmt.format_num(s.xp_per_match) } },
        { { "Kills / Min:", string.format("%.3f", s.kills_per_min) },
          { "XP / Min:", fmt.format_num(s.xp_per_min) } },
        { { "HS / Match:", string.format("%.2f", s.hs_per_match) },
          { "Wall / Match:", string.format("%.2f", s.wall_per_match) } },
        { { "Obj. / Match:", string.format("%.5f", s.points_per_match) }, -- as many decimals as KDR
          { "HE / Match:", string.format("%.2f", s.he_per_match) } },
        { { "Avg Lifespan:", fmt.format_duration(s.lifespan) },
          { "Dist / Match:", fmt.format_num(s.distance_per_match) .. " st" } },
    }
    return totals, averages
end

return (function(printing) printing(); return Renderer end)(function() -- printing: a second part with its own 255 lines (README.md, "The Fiu 255-line limit")
function Renderer:print_overall_recap(data)
    local totals, averages = self:recap_cells(data)
    local function lines(column, format)
        local out = {}
        for i, pair in ipairs(column) do out[i] = format(pair[1], pair[2]) end
        return out
    end

    print(self.bar)
    self:print_title("OVERALL ACCOUNT STATISTICS FOR " .. tostring(data.player_name))
    local columns = {}
    for i, column in ipairs(totals) do
        columns[i] = lines(column, function(label, value)
            return string.format("%-19s%s", label, tostring(value))
        end)
    end
    self:print_columns(columns)
    print(self.bar)

    self:print_title("AVERAGE STATS PER MATCH AND MINUTE")
    columns = {}
    for i, column in ipairs(averages) do
        local label_width = i == 1 and 15 or 16
        columns[i] = lines(column, function(label, value)
            return self.fmt.pad_right(label, label_width) .. string.format("%9s", value)
        end)
    end
    self:print_columns(columns)
    print(self.bar)
end

function Renderer:print_table_header()
    self:print_title("DETAILED WEAPON STATS")
    print(" " .. DEATHS_WITH_NOTE)
    print(string.format(ROW_FORMAT, table.unpack(WEAPON_COLUMNS)))
    print(self.thin_bar)
end

-- One weapon row, as the strings shown under WEAPON_COLUMNS, from w.numbers
-- (StatsSummary.weapon).
function Renderer:weapon_cells(w)
    local fmt, x = self.fmt, w.numbers
    return {
        w.display_name,
        fmt.format_num(x.kills),
        fmt.format_num(x.deaths_with),
        fmt.format_num(x.deaths_from),
        string.format("%.3f", x.kdr),
        string.format("%.2f%%", x.kill_share),
        fmt.format_num(x.rounds),
        string.format("%.2f", x.kills_per_min),
        string.format("%.2f", x.rounds_per_kill),
        fmt.format_num(x.xp),
        fmt.format_duration(x.use_time),
        string.format("%.2f%%", x.time_share),
        w.caliber_type,
    }
end

function Renderer:print_row(w)
    print(string.format(ROW_FORMAT, table.unpack(self:weapon_cells(w))))
end

-- data = { player_name, summary (StatsSummary.account), weapon_list (rows with
--          .numbers from StatsSummary.weapon) }
function Renderer:print_report(data)
    self:print_overall_recap(data)
    self:print_table_header()
    for _, w in ipairs(data.weapon_list) do
        self:print_row(w)
    end
    print(self.thin_bar)
end

-- The same report for iris_viewer.luau; `report` is a modules/iris_report.luau report.
function Renderer:add_to_report(report, data)
    local totals, averages = self:recap_cells(data)
    report:section("Overall account statistics", true, SECTION_TIPS.overall)
    report:columns({ "", "", "", "", "", "" })
    for row = 1, #totals[1] do
        local cells = {}
        for _, column in ipairs(totals) do
            table.insert(cells, column[row][1])
            table.insert(cells, tostring(column[row][2]))
        end
        report:row(cells)
    end
    report:section("Average stats per match and minute", true, SECTION_TIPS.averages)
    report:columns({ "", "", "", "" })
    for _, column in ipairs(averages) do
        report:row({ column[1][1], column[1][2], column[2][1], column[2][2] })
    end
    report:section(string.format("Detailed weapon stats (%d weapons)", #data.weapon_list), true, SECTION_TIPS.weapons)
    report:columns_with_tips(WEAPON_COLUMNS, WEAPON_TIPS)
    for _, w in ipairs(data.weapon_list) do
        report:row(self:weapon_cells(w))
    end
end
end)
