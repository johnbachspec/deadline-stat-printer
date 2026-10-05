"""Mock player profiles and console setups shared by several test files."""

STAT_PROFILE = """{
  player = { total_kills = 3000, weapon_use_time = { Vector = 3600, SCALAR = 1800, M4A1 = 7200 } },
  weapon = {
    Vector = { kills = 700, deaths_with = 300, deaths_from = 20, experience = 1000, rounds_fired = 9000 },
    SCALAR = { kills = 250, deaths_with = 100, deaths_from = 5, experience = 400, rounds_fired = 3000 },
    SA58 = { kills = 400, deaths_with = 150, deaths_from = 10, experience = 800, rounds_fired = 5000 },
    SG58 = { kills = 43, deaths_with = 20, deaths_from = 1, experience = 90, rounds_fired = 600 },
    M4A1 = { kills = 1500, deaths_with = 500, deaths_from = 60, experience = 3000, rounds_fired = 20000 },
  },
}"""


ATTACHMENT_PROFILE = """{ weapon = {
  AK_762 = { attachment_stats = { ["10mm_thread_protector"] = { kills = 10 }, ["15mm_cqr"] = { kills = 4 } } },
  AKMN = { attachment_stats = { ["15mm_cqr"] = { kills = 3 } } },
  M4A1 = { attachment_stats = { ["10mm_thread_protector"] = { kills = 7 } } },
  SCALAR = { attachment_stats = { ["10mm_thread_protector"] = { kills = 2 } } },
  MP5 = { attachment_stats = { ["10mm_thread_protector"] = { kills = 1 } } },
} }"""


CAP_PRELUDE = """
local __threads, __chat_handlers = {}, {}
local task = {
  spawn = function(f) local co = coroutine.create(f); table.insert(__threads, co); assert(coroutine.resume(co)); return co end,
  wait = function() coroutine.yield() end,
}
local function __tick()  -- runs one more check in every waiting loop
  for _, co in ipairs(__threads) do if coroutine.status(co) == "suspended" then assert(coroutine.resume(co)) end end
end
local function __say(content)
  for _, h in pairs(__chat_handlers) do if h then h("Bob", "all", content) end end
end
local chat = {
  send_announcement = function(t) print("ANNOUNCE: " .. t) end,
  send_ingame_notification = function(t) print("NOTIFY: " .. t) end,
  player_chatted = { Connect = function(self, fn)
    local i = #__chat_handlers + 1; __chat_handlers[i] = fn
    return { Disconnect = function() __chat_handlers[i] = false end } end },
}
local __caps = { Alice = 0, Bob = 0 }
local function __player(name, id)
  return { name = name, player_id = id, is_bot = function() return false end,
    get_leaderboard_stats = function() return { objective_captures = __caps[name], kills = 0 } end }
end
players = { get_all = function() return { __player("Alice", 1), __player("Bob", 2) } end }
"""
