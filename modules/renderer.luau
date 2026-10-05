-- modules/renderer.luau
-- The account recap and the per-weapon table, printed to the in-game Luau
-- console or added to an Iris report (modules/iris_report.luau). Does simple
-- ratios on numbers it is handed; no data lookups of its own.

local Renderer = {}
Renderer.__index = Renderer

local DEFAULT_GRID_WIDTH = 166
local ROW_FORMAT         = "%-20s %10s %11s %11s %10s %10s %12s %8s %8s %14s %16s %10s  %-8.8s"
local WEAPON_COLUMNS     = { "weapon", "kills", "deaths w/", "deaths by", "w-KDR", "% allK", "rds. ct", "K/Min",
    "RFpK", "weapon XP", "time used", "% allT", "type" }
local DEATHS_WITH_NOTE   = "deaths w/ = deaths while carrying the weapon in any slot (one death counts toward every carried weapon)"
local SECTION_TIPS       = { -- hover text for the viewer's section headers
    overall = "Lifetime totals from this player's profile: kills, deaths, headshots, wallbangs, money, XP and time played",
    averages = "Lifetime totals divided by matches played or by minutes alive",
    weapons = "One row per weapon; % columns are shares of the weapons listed\n"
        .. "deaths w/: deaths while carrying it   deaths by: deaths to it   w-KDR: kills / deaths w/\n"
        .. "% allK: share of kills   rds. ct: rounds fired   K/Min: kills per minute used\n"
        .. "RFpK: rounds fired per kill   time used / % allT: time held and its share   type: caliber",
}

-- deps = { formatters = ..., level_data = ..., grid_width = 166 (optional) }
function Renderer.new(deps)
    local width = deps.grid_width or DEFAULT_GRID_WIDTH
    return setmetatable({
        fmt = deps.formatters,
        level_data = deps.level_data,
        grid_width = width,
        bar = string.rep("=", width),
        thin_bar = string.rep("-", width),
    }, Renderer)
end

-- Profile achievements are { is_alpha_tester = bool, is_predemo_tester = bool }.
local function tester_status(achievements)
    local ach = achievements or {}
    local tags = {}
    if ach.is_predemo_tester then table.insert(tags, "predemo tester") end
    if ach.is_alpha_tester then table.insert(tags, "alpha tester") end
    return #tags > 0 and table.concat(tags, ", ") or "None"
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
-- totals, then five columns of per-match / per-minute averages.
-- data.account_totals = { use_time, rounds_fired } over ALL weapons, so the
-- recap does not change with FILTER_TYPE.
function Renderer:recap_cells(data)
    local fmt = self.fmt
    local safe_div = fmt.safe_div
    local pct = fmt.pct
    local n = function(v) return tonumber(v) or 0 end

    local p = data.player_stats or {}
    local spendings = data.spendings or {}
    local account_totals = data.account_totals or {}
    local collection = data.collection or {}

    local kills, deaths = n(p.total_kills), n(p.total_deaths)
    local headshots, wallbangs, he_kills = n(p.total_headshots), n(p.total_penetration_kills), n(p.total_explosive_kills)
    local matches, points, distance, xp = n(p.total_matches_played), n(p.total_points_captured), n(p.distance_travelled), n(p.experience)
    local alive_sec, rounds = n(account_totals.use_time), n(account_totals.rounds_fired)
    local alive_min = alive_sec / 60

    local level, xp_to_next = self.level_data.get_level(xp)
    local next_level = xp_to_next > 0 and (fmt.format_num(xp_to_next) .. " XP") or "MAX"
    local prestige, prestige_level = self.level_data.get_prestige(xp)

    local spent_attachments, spent_weapons = n(spendings.attachments), n(spendings.weapons)
    local spent = spent_attachments + spent_weapons

    local totals = {
        {
            { "Level:", level },
            { "Kills:", fmt.format_num(kills) },
            { "Headshots:", fmt.format_num(headshots) },
            { "HS %:", string.format("%.2f%%", pct(headshots, kills)) },
            { "Matches Played:", fmt.format_num(matches) },
            { "Total Money Spent:", fmt.format_currency(spent) },
            { "Time Alive:", fmt.format_use_time(alive_sec) },
            { "Status:", tester_status(data.achievements) },
            { "Owned Weapons:", fmt.format_num(collection.weapons) },
        },
        {
            { "Prestige Level:", prestige_level },
            { "Deaths:", fmt.format_num(deaths) },
            { "Wallbangs:", fmt.format_num(wallbangs) },
            { "Wall %:", string.format("%.2f%%", pct(wallbangs, kills)) },
            { "Objectives Cap:", fmt.format_num(points) },
            { "On Attachments:", string.format("%s (%.2f%%)", fmt.format_currency(spent_attachments), pct(spent_attachments, spent)) },
            { "Total Experience:", fmt.format_num(xp) },
            { "Next Level In:", next_level },
            { "Owned Attachments:", fmt.format_num(collection.attachments) },
        },
        {
            { "Prestige:", prestige },
            { "KDR:", string.format("%.5f", safe_div(kills, deaths, kills)) },
            { "HE Kills:", fmt.format_num(he_kills) },
            { "HE %:", string.format("%.2f%%", pct(he_kills, kills)) },
            -- The profile stores no hit counts, so real accuracy can't be computed.
            { "Rounds / Kill:", string.format("%.2f", safe_div(rounds, kills, rounds)) },
            { "On Weapons:", string.format("%s (%.2f%%)", fmt.format_currency(spent_weapons), pct(spent_weapons, spent)) },
            { "Dist Travelled:", fmt.format_num(distance) .. " st" },
            { "Rounds Fired:", fmt.format_num(rounds) },
            { "Owned Camos:", fmt.format_num(collection.camos) },
        },
    }
    local averages = {
        { { "Kills / Match:", string.format("%.2f", safe_div(kills, matches)) },
          { "Points / Match:", fmt.format_num(safe_div(xp, matches)) } },
        { { "Kills / Min:", string.format("%.3f", safe_div(kills, alive_min)) },
          { "EXP / Min:", fmt.format_num(safe_div(xp, alive_min)) } },
        { { "HS / Match:", string.format("%.2f", safe_div(headshots, matches)) },
          { "Wall / Match:", string.format("%.2f", safe_div(wallbangs, matches)) } },
        { { "Obj. / Match:", string.format("%.5f", safe_div(points, matches)) }, -- as many decimals as KDR
          { "HE / Match:", string.format("%.2f", safe_div(he_kills, matches)) } },
        { { "Avg Lifespan:", fmt.format_duration_short(safe_div(alive_sec, deaths, alive_sec)) },
          { "Dist / Match:", fmt.format_num(safe_div(distance, matches)) .. " st" } },
    }
    return totals, averages
end

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

-- One weapon row, as the strings shown under WEAPON_COLUMNS.
function Renderer:weapon_cells(w, total_kills, total_time)
    local fmt, d = self.fmt, w.data
    local safe_div = fmt.safe_div
    local pct = fmt.pct
    return {
        w.display_name,
        fmt.format_num(d.kills),
        fmt.format_num(d.deaths_with),
        fmt.format_num(d.deaths_from),
        string.format("%.3f", safe_div(d.kills, d.deaths_with, d.kills)),
        string.format("%.2f%%", pct(d.kills, total_kills)),
        fmt.format_num(d.rounds_fired),
        string.format("%.2f", safe_div(d.kills, d.use_time / 60)),
        string.format("%.2f", safe_div(d.rounds_fired, d.kills, d.rounds_fired)),
        fmt.format_num(d.experience),
        fmt.format_use_time(d.use_time),
        string.format("%.2f%%", pct(d.use_time, total_time)),
        w.caliber_type,
    }
end

function Renderer:print_row(w, total_kills, total_time)
    print(string.format(ROW_FORMAT, table.unpack(self:weapon_cells(w, total_kills, total_time))))
end

-- data = { player_name, player_stats, spendings, achievements, collection,
--          weapon_list, table_totals, account_totals }
-- table_totals   = totals over the rows shown (for % allK / % allT)
-- account_totals = totals over ALL weapons (for the recap)
function Renderer:print_report(data)
    self:print_overall_recap(data)
    self:print_table_header()
    for _, w in ipairs(data.weapon_list) do
        self:print_row(w, data.table_totals.kills, data.table_totals.use_time)
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
    report:text(DEATHS_WITH_NOTE)
    report:columns(WEAPON_COLUMNS)
    for _, w in ipairs(data.weapon_list) do
        report:row(self:weapon_cells(w, data.table_totals.kills, data.table_totals.use_time))
    end
end

return Renderer
