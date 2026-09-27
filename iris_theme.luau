-- iris_theme.luau
-- Your look for iris_viewer.luau's windows: colors, spacing, font and text size.
-- It only styles the stat printer's windows, not other Iris windows in the game.
-- Paste it into the CLIENT Luau console (or Client Autorun, after the viewer), then
-- change the values below and paste it again to apply them. Setting everything to
-- nil and pasting goes back to Iris's normal look. More in IRIS_VIEWER.md.

local COLORS = "dark"   -- "dark" or "light" (Iris's two color sets), or nil to leave colors alone
local SPACING = nil     -- "clear" (roomier), "default" (compact), or nil to leave spacing alone
local FONT = 12187365977 -- a Roblox font name, e.g. "Code", "RobotoMono", "BuilderSans", "Ubuntu", "Arial";
                        -- or a Creator Store font's asset id, e.g. 12187365977 (Rubik, Deadline's UI font);
                        -- "?" prints every font name; nil leaves it alone
local FONT_WEIGHT = nil -- nil, or "Light", "Regular", "Medium", "SemiBold", "Bold", "ExtraBold", "Heavy", ...
local TEXT_SIZE = 14    -- text size in pixels, or nil to leave it alone

-- A second font for table cells that are only a number ("12,345", "3.721", "61.28%",
-- "$1,234", "2h 3m 20s"), e.g. a monospaced one so numbers line up while names use FONT.
local NUMBER_FONT = "RobotoMono"   -- a font name ("RobotoMono", "Code") or asset id, like FONT; nil = same as FONT
local NUMBER_WEIGHT = nil -- like FONT_WEIGHT

-- Any other Iris style key, applied last. Needs Roblox types, e.g.
--   WindowBgTransparency = 0.2,
--   TextColor = Color3.fromRGB(230, 230, 230),
--   ItemSpacing = Vector2.new(8, 6),
-- The keys are listed in Iris's config.lua: https://github.com/SirMallard/Iris/blob/main/lib/config.lua
local EXTRA = {}

if not iris then
    print("[theme] iris is missing: run this in the client Luau console")
    return
end
local type_of = typeof or type
local templates = iris.TemplateConfig or {}
local theme = {}

local function copy(template)
    for key, value in pairs(template or {}) do theme[key] = value end
end

if COLORS then copy(templates[COLORS == "light" and "colorLight" or "colorDark"]) end
if SPACING then copy(templates[SPACING == "clear" and "sizeClear" or "sizeDefault"]) end

if FONT == "?" then
    local ok, items = pcall(function() return Enum.Font:GetEnumItems() end)
    if ok then
        local names = {}
        for _, item in ipairs(items) do table.insert(names, item.Name) end
        table.sort(names)
        print("[theme] fonts: " .. table.concat(names, ", "))
    else
        print("[theme] could not list fonts here: " .. tostring(items))
    end
elseif FONT then
    -- Iris 2.1+ takes a Font object (any family, weight); Iris 2.0 and older only an Enum.Font item.
    local ok, font = pcall(function()
        local objects = type_of((templates.sizeDefault or {}).TextFont) == "Font"
        local weight = FONT_WEIGHT and Enum.FontWeight[FONT_WEIGHT]
        if type(FONT) == "number" then
            assert(objects, "this Iris only takes built-in font names")
            return Font.fromId(FONT, weight)
        end
        local item = Enum.Font[FONT]
        if not objects then return item end
        local face = Font.fromEnum(item)
        return weight and Font.new(face.Family, weight, face.Style) or face
    end)
    if ok and font ~= nil then
        theme.TextFont = font
    else
        print(string.format("[theme] font %s not available (%s); set FONT = \"?\" to list the names",
            tostring(FONT), tostring(font)))
    end
end
if TEXT_SIZE then theme.TextSize = TEXT_SIZE end
for key, value in pairs(EXTRA) do theme[key] = value end

-- The number font is a rich-text tag the viewer wraps number cells in.
local WEIGHTS = { Thin = 100, ExtraLight = 200, Light = 300, Regular = 400, Medium = 500, SemiBold = 600,
    Bold = 700, ExtraBold = 800, Heavy = 900 }
local number_font = nil
if NUMBER_FONT then
    number_font = type(NUMBER_FONT) == "number" and string.format('<font family="rbxassetid://%d"', NUMBER_FONT)
        or string.format('<font face="%s"', tostring(NUMBER_FONT))
    if NUMBER_WEIGHT then number_font = number_font .. string.format(' weight="%s"', WEIGHTS[NUMBER_WEIGHT] or NUMBER_WEIGHT) end
    number_font = number_font .. ">"
end

shared.iris_viewer_theme = theme
shared.iris_viewer_number_font = number_font
print(string.format("[theme] applied: colors %s, spacing %s, font %s %s, numbers %s %s, text size %s",
    tostring(COLORS), tostring(SPACING), tostring(FONT), tostring(FONT_WEIGHT or ""),
    tostring(NUMBER_FONT or "same font"), tostring(NUMBER_WEIGHT or ""), tostring(TEXT_SIZE)))
