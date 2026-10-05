-- modules/attachment_fixture.luau
-- Prints aggregated attachment rows (from attachment_aggregator) as Lua-table lines
-- of raw ids, chunk_size entries per line. Saved copies of this output are the
-- fixtures tools/verify_attachment_merge.py and the tests replay
-- (tests/fixtures/attachment_stats_output.txt).
-- NOTE: Deadline's Luau console uses a Lua 5.x-style VM ('Fiu') that does not
-- accept Luau type annotations, so this file intentionally has none.

local AttachmentFixture = {}

function AttachmentFixture.print(aggregated, player_name, chunk_size)
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

return AttachmentFixture
