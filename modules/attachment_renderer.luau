-- modules/attachment_renderer.luau
-- Console presentation and layout for attachment statistics.
-- Single Responsibility: Renders aggregated attachment data to the Luau console,
-- supporting both formatted tabular reports (with polished names) and delimited
-- chunks (for debugging and log fixture generation).
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ('Fiu') that does not
-- accept Luau type annotations, so this file intentionally has none.

local AttachmentRenderer = {}
AttachmentRenderer.__index = AttachmentRenderer

local function default_pad_right(text, width)
    local s = tostring(text)
    if #s < width then
        return s .. string.rep(" ", width - #s)
    end
    return s
end

function AttachmentRenderer.new(deps)
    local self = setmetatable({}, AttachmentRenderer)
    self.formatter = deps and deps.formatter
    self.formatters = deps and deps.formatters
    return self
end

function AttachmentRenderer:pad(text, width)
    if self.formatters and type(self.formatters.pad_right) == "function" then
        return self.formatters.pad_right(text, width)
    end
    return default_pad_right(text, width)
end

-- Renders formatted tabular report with polished in-game names.
function AttachmentRenderer:render_table(aggregated, player_name, options)
    local items = (aggregated and aggregated.items) or {}
    local limit = #items
    local legacy_merged = (aggregated and aggregated.legacy_merged) or 0
    local sync_status = (options and options.sync_status) or "embedded snapshot"
    local p_name = player_name or "Player"

    local display_items = {}
    local rank_width = math.max(#tostring(math.max(limit, 1)), 3)
    local name_width = 32
    local kills_width = 6
    local gun_width = #("Top Gun")

    for i = 1, limit do
        local it = items[i]
        local dname = it.display_name
        if not dname and self.formatter then
            dname = self.formatter:resolve_attachment_display_name(it.id)
        end
        dname = dname or it.id

        local gname = it.top_gun_display
        if not gname and self.formatter then
            gname = self.formatter:resolve_weapon_display_name(it.top_gun)
        end
        gname = gname or it.top_gun

        if #dname > name_width then name_width = #dname end
        local digits = #tostring(it.kills)
        if digits > kills_width then kills_width = digits end
        if #gname > gun_width then gun_width = #gname end

        table.insert(display_items, {
            id = it.id,
            display_name = dname,
            kills = it.kills,
            top_gun = it.top_gun,
            top_gun_display = gname,
            top_gun_kills = it.top_gun_kills,
        })
    end

    print(string.format("\n================ ALL %d ATTACHMENTS BY KILLS FOR %s ================", limit, tostring(p_name)))
    print(string.format("-- ALIAS SOURCE: %s", sync_status))
    if legacy_merged > 0 then
        print(string.format("-- ALIASES MERGED: %d legacy attachment ids folded into current ids (renames.csv)", legacy_merged))
    end

    if limit == 0 then
        print("No attachment kills found across any weapons.")
    else
        print("Total Unique Attachments Found: " .. limit)
        print("Displaying all " .. limit .. " attachments...\n")

        for i = 1, limit do
            local item = display_items[i]
            print("#" .. self:pad(tostring(i), rank_width)
                .. " " .. self:pad(item.display_name, name_width)
                .. " | Kills: " .. self:pad(tostring(item.kills), kills_width)
                .. " | Top Gun: " .. self:pad(item.top_gun_display, gun_width)
                .. " (" .. tostring(item.top_gun_kills) .. ")")

            if i % 100 == 0 and task and task.wait then
                task.wait(0.05)
            end
        end
    end

    return display_items
end

-- Renders delimited Lua table chunks (100 attachments per line) for debug/fixture generation.
function AttachmentRenderer:render_delimited(aggregated, player_name, options)
    local items = (aggregated and aggregated.items) or {}
    local legacy_merged = (aggregated and aggregated.legacy_merged) or 0
    local sync_status = (options and options.sync_status) or "embedded snapshot"
    local chunk_size = (options and options.chunk_size) or 100
    local p_name = player_name or "Player"

    print(string.format("-- TOTAL ATTACHMENTS FOR %s: %d (split into lines of %d)", tostring(p_name), #items, chunk_size))
    print(string.format("-- ALIAS SOURCE: %s", sync_status))
    if legacy_merged > 0 then
        print(string.format("-- ALIASES MERGED: %d legacy attachment ids folded into current ids (renames.csv)", legacy_merged))
    end
    print("ATTACHMENT_DATA = {")

    local line_items = {}
    for i, item in ipairs(items) do
        table.insert(line_items, string.format('["%s"]={kills=%d,top_gun="%s",top_gun_kills=%d}',
            item.id, item.kills, item.top_gun, item.top_gun_kills))

        if #line_items == chunk_size or i == #items then
            local is_last = (i == #items)
            local suffix = is_last and "" or ","
            print(" " .. table.concat(line_items, ", ") .. suffix)
            table.clear(line_items)
            if task and task.wait then
                task.wait(0.05)
            end
        end
    end

    print("}")
    return items
end

return AttachmentRenderer
