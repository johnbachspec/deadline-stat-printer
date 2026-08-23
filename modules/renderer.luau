-- modules/renderer.luau
-- Prints the account recap and the per-weapon table. Does only simple ratios
-- on numbers it is handed; no data lookups of its own.
-- Output goes through the global `print`, i.e. the in-game Luau console.

local Renderer = {}
Renderer.__index = Renderer

local GRID_WIDTH    = 166
local ROW_FORMAT    = "%-20s %10s %11s %11s %10.3f %9.2f%% %12s %8.2f %8.2f %14s %16s %9.2f%%  %-8.8s"
local HEADER_FORMAT = "%-20s %10s %11s %11s %10s %10s %12s %8s %8s %14s %16s %10s  %-8.8s"
local BAR           = string.rep("=", GRID_WIDTH)
local THIN_BAR      = string.rep("-", GRID_WIDTH)

-- deps = { formatters = ..., level_data = ... }
function Renderer.new(deps)
    return setmetatable({ fmt = deps.formatters, level_data = deps.level_data }, Renderer)
end

local function ratio(a, b)
    if b > 0 then return a / b end
    return 0
end

local function pct(a, b)
    return ratio(a, b) * 100
end

-- Profile achievements are { is_alpha_tester = bool, is_predemo_tester = bool }.
local function tester_status(achievements)
    local tags = {}
    if achievements.is_predemo_tester then table.insert(tags, "predemo tester") end
    if achievements.is_alpha_tester then table.insert(tags, "alpha tester") end
    return #tags > 0 and table.concat(tags, ", ") or "None"
end

-- Prints `columns` (a list of equal-length string lists) side by side.
function Renderer:print_columns(columns)
    local width = math.floor((GRID_WIDTH - (#columns - 1)) / #columns)
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
    print(self.fmt.center_text(title, GRID_WIDTH))
    print("")
end

-- account_totals = { use_time, rounds_fired } over ALL weapons, so the recap
-- does not change with FILTER_TYPE.
function Renderer:print_overall_recap(player_name, p, spendings, achievements, account_totals, collection)
    local fmt = self.fmt
    local n = function(v) return tonumber(v) or 0 end
    local label = function(name, value) return string.format("%-19s%s", name, value) end

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

    print(BAR)
    self:print_title("OVERALL ACCOUNT STATISTICS FOR " .. tostring(player_name))
    self:print_columns({
        {
            label("Level:", level),
            label("Kills:", fmt.format_num(kills)),
            label("Headshots:", fmt.format_num(headshots)),
            label("HS %:", string.format("%.2f%%", pct(headshots, kills))),
            label("Matches Played:", fmt.format_num(matches)),
            label("Total Money Spent:", fmt.format_currency(spent)),
            label("Time Alive:", fmt.format_use_time(alive_sec)),
            label("Status:", tester_status(achievements)),
            label("Owned Weapons:", fmt.format_num(collection.weapons)),
        },
        {
            label("Prestige Level:", prestige_level),
            label("Deaths:", fmt.format_num(deaths)),
            label("Wallbangs:", fmt.format_num(wallbangs)),
            label("Wall %:", string.format("%.2f%%", pct(wallbangs, kills))),
            label("Objectives Cap:", fmt.format_num(points)),
            label("On Attachments:", string.format("%s (%.2f%%)", fmt.format_currency(spent_attachments), pct(spent_attachments, spent))),
            label("Total Experience:", fmt.format_num(xp)),
            label("Next Level In:", next_level),
            label("Owned Attachments:", fmt.format_num(collection.attachments)),
        },
        {
            label("Prestige:", prestige),
            label("KDR:", string.format("%.5f", deaths > 0 and kills / deaths or kills)),
            label("HE Kills:", fmt.format_num(he_kills)),
            label("HE %:", string.format("%.2f%%", pct(he_kills, kills))),
            -- The profile stores no hit counts, so real accuracy can't be computed.
            label("Rounds / Kill:", string.format("%.2f", kills > 0 and rounds / kills or rounds)),
            label("On Weapons:", string.format("%s (%.2f%%)", fmt.format_currency(spent_weapons), pct(spent_weapons, spent))),
            label("Dist Travelled:", fmt.format_num(distance) .. " st"),
            label("Rounds Fired:", fmt.format_num(rounds)),
            label("Owned Camos:", fmt.format_num(collection.camos)),
        },
    })
    print(BAR)

    self:print_title("AVERAGE STATS PER MATCH AND MINUTE")
    self:print_columns({
        {
            string.format("Kills / Match: %9.2f", ratio(kills, matches)),
            string.format("Points / Match:%9s", fmt.format_num(ratio(xp, matches))),
        },
        {
            string.format("Kills / Min:    %9.3f", ratio(kills, alive_min)),
            string.format("EXP / Min:      %9s", fmt.format_num(ratio(xp, alive_min))),
        },
        {
            string.format("HS / Match:     %9.2f", ratio(headshots, matches)),
            string.format("Wall / Match:   %9.2f", ratio(wallbangs, matches)),
        },
        {
            string.format("Obj. / Match:   %9.2f", ratio(points, matches)),
            string.format("HE / Match:     %9.2f", ratio(he_kills, matches)),
        },
        {
            string.format("Avg Lifespan:   %9s", fmt.format_duration_short(deaths > 0 and alive_sec / deaths or alive_sec)),
            string.format("Dist / Match:   %6s st", fmt.format_num(ratio(distance, matches))),
        },
    })
    print(BAR)
end

function Renderer:print_table_header()
    self:print_title("DETAILED WEAPON STATS")
    print(" deaths w/ = deaths while carrying the weapon in any slot (one death counts toward every carried weapon)")
    print(string.format(HEADER_FORMAT, "weapon", "kills", "deaths w/", "deaths by", "w-KDR", "% allK", "rds. ct", "K/Min", "RFpK", "weapon XP", "time used", "% allT", "type"))
    print(THIN_BAR)
end

function Renderer:print_row(w, total_kills, total_time)
    local fmt, d = self.fmt, w.data
    print(string.format(
        ROW_FORMAT,
        w.display_name,
        fmt.format_num(d.kills),
        fmt.format_num(d.deaths_with),
        fmt.format_num(d.deaths_from),
        d.deaths_with > 0 and d.kills / d.deaths_with or d.kills,
        pct(d.kills, total_kills),
        fmt.format_num(d.rounds_fired),
        ratio(d.kills, d.use_time / 60),
        d.kills > 0 and d.rounds_fired / d.kills or d.rounds_fired,
        fmt.format_num(d.experience),
        fmt.format_use_time(d.use_time),
        pct(d.use_time, total_time),
        w.caliber_type
    ))
end

-- table_totals   = totals over the rows shown (for % allK / % allT)
-- account_totals = totals over ALL weapons (for the recap)
function Renderer:print_report(player_name, player_stats, spendings, achievements, collection, weapon_list, table_totals, account_totals)
    self:print_overall_recap(player_name, player_stats, spendings, achievements, account_totals, collection)
    self:print_table_header()
    for _, w in ipairs(weapon_list) do
        self:print_row(w, table_totals.kills, table_totals.use_time)
    end
    print(THIN_BAR)
end

return Renderer
