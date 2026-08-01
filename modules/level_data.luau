-- modules/level_data.luau
-- SRP: owns XP thresholds and the prestige/level calculation.
-- Nothing here knows about weapons, printing, or player objects.

local LevelData = {}

-- Level Experience Thresholds (Max Level: 85)
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
LevelData.MAX_LEVEL_XP = LevelData.THRESHOLDS[LevelData.MAX_LEVEL]

function LevelData.get_prestige_and_level(xp)
    local safe_xp = tonumber(xp) or 0
    local prestige = math.floor(safe_xp / LevelData.MAX_LEVEL_XP)
    local remaining_xp = safe_xp % LevelData.MAX_LEVEL_XP

    local current_level = 0
    for lvl = 0, LevelData.MAX_LEVEL do
        local threshold = LevelData.THRESHOLDS[lvl] or 0
        if remaining_xp >= threshold then
            current_level = lvl
        else
            break
        end
    end

    return prestige, current_level
end

return LevelData
