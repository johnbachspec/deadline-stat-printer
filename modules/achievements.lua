-- modules/achievements.lua
-- SRP: the only thing this module knows how to do is read an achievements
-- table and describe tester status. Kept separate from stats_aggregator
-- so a future "achievements summary" feature doesn't need to touch or
-- depend on weapon/kill aggregation code (ISP: callers who only need
-- tester status don't have to pull in the whole aggregator).

local Achievements = {}

function Achievements.get_tester_status_string(achievements_table)
    if type(achievements_table) ~= "table" then return "None" end

    local is_predemo = false
    local is_alpha = false

    for key, data in pairs(achievements_table) do
        local key_str = string.lower(tostring(key))
        local name_str = ""
        if type(data) == "table" and (data.name or data.title) then
            name_str = string.lower(tostring(data.name or data.title))
        end

        local combined_identifier = key_str .. " " .. name_str

        local is_unlocked = false
        if type(data) == "boolean" then
            is_unlocked = data
        elseif type(data) == "number" then
            is_unlocked = (data > 0)
        elseif type(data) == "table" then
            local prog = tonumber(data.progress) or 0
            local max_prog = tonumber(data.max_progress) or 0
            is_unlocked = (data.unlocked == true or data.completed == true or data.unlocked_at ~= nil) or
                          (max_prog > 0 and prog >= max_prog)
        end

        if is_unlocked then
            if combined_identifier:find("predemo") then
                is_predemo = true
            end
            if combined_identifier:find("alpha") then
                is_alpha = true
            end
        end
    end

    if is_predemo and is_alpha then
        return "predemo tester, alpha tester"
    elseif is_predemo then
        return "predemo tester"
    elseif is_alpha then
        return "alpha tester"
    else
        return "None"
    end
end

return Achievements
