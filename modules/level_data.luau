-- modules/level_data.luau
-- XP thresholds and the level calculation.

local LevelData = {}

-- Mirrors the CHARACTER list in the game's progression spreadsheet
-- (Max Level: 85). The game has no prestige system.
LevelData.THRESHOLDS = {
    [0] = 0, [1] = 1000, [2] = 3500, [3] = 6000, [4] = 9000,
    [5] = 12500, [6] = 16500, [7] = 21000, [8] = 26000, [9] = 31300,
    [10] = 37000, [11] = 43000, [12] = 49500, [13] = 56500, [14] = 64000,
    [15] = 72000, [16] = 80500, [17] = 89500, [18] = 99000, [19] = 109000,
    [20] = 119500, [21] = 130500, [22] = 141700, [23] = 153500, [24] = 165500,
    [25] = 178000, [26] = 192000, [27] = 207000, [28] = 222300, [29] = 238000,
    [30] = 255000, [31] = 275000, [32] = 298000, [33] = 323000, [34] = 350000,
    [35] = 380000, [36] = 420000, [37] = 463000, [38] = 510000, [39] = 560000,
    [40] = 612000, [41] = 666000, [42] = 724000, [43] = 784000, [44] = 846000,
    [45] = 910000, [46] = 976000, [47] = 1044000, [48] = 1114000, [49] = 1184000,
    [50] = 1254000, [51] = 1324000, [52] = 1404000, [53] = 1485000, [54] = 1567000,
    [55] = 1650000, [56] = 1734000, [57] = 1819000, [58] = 1905000, [59] = 1995000,
    [60] = 2086000, [61] = 2178000, [62] = 2271000, [63] = 2365000, [64] = 2460000,
    [65] = 2556000, [66] = 2656000, [67] = 2757000, [68] = 2859000, [69] = 2962000,
    [70] = 3066000, [71] = 3171000, [72] = 3277000, [73] = 3387000, [74] = 3498000,
    [75] = 3610000, [76] = 3723000, [77] = 3837000, [78] = 3952000, [79] = 4068000,
    [80] = 4188000, [81] = 4309000, [82] = 4431000, [83] = 4554000, [84] = 4678000,
    [85] = 4678000
}

LevelData.MAX_LEVEL = 85

-- Returns level, xp_to_next_level (0 at max level).
-- Matches the game's ProgressionData: a threshold is passed only once XP is
-- strictly greater than it, and the level caps at MAX_LEVEL (no prestige).
function LevelData.get_level(xp)
    xp = tonumber(xp) or 0

    local level = 0
    for lvl = 1, LevelData.MAX_LEVEL do
        if xp > LevelData.THRESHOLDS[lvl] then level = lvl else break end
    end

    if level >= LevelData.MAX_LEVEL then return level, 0 end
    return level, LevelData.THRESHOLDS[level + 1] - xp + 1
end

return LevelData
