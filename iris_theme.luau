-- iris_theme.luau
-- Your look for iris_viewer.luau's windows: colors, spacing, font and text size.
-- It only styles the stat printer's windows, not other Iris windows in the game.
-- Paste it into the CLIENT Luau console (or Client Autorun, after the viewer), then
-- change the values below and paste it again to apply them. Setting everything to
-- nil and pasting goes back to Iris's normal look. More in IRIS_VIEWER.md.

local COLORS = "dark"   -- "dark" or "light" (Iris's two color sets), or nil to leave colors alone
local SPACING = nil     -- "clear" (roomier), "default" (compact), or nil to leave spacing alone
-- FONT styles the tables (cells and headers). Titles, buttons and section headers can
-- only use "Code" or "Ubuntu" in Deadline's client console (it has no Font type) and keep
-- Iris's font for anything else.
local FONT = 12187365977  -- Rubik (Deadline's UI font), by its Creator Store asset id. Or a Roblox font
                          -- name in quotes, like "RobotoMono", "BuilderSans", "Ubuntu", "Arial";
                          -- nil for Iris's font (Code); "?" prints every font name
local FONT_WEIGHT = "Medium" -- nil, or "Light", "Regular", "Medium", "SemiBold", "Bold", "ExtraBold", "Heavy", ...
local TEXT_SIZE = 14    -- text size in pixels, or nil to leave it alone

-- Font of every Iris window: the client Luau console itself, and the stat printer's
-- titles, buttons and section headers. Only "Ubuntu" or "Code" in Deadline's client
-- console (Iris's own two fonts); nil leaves it alone. The tables keep FONT / NUMBER_FONT.
local CONSOLE_FONT = "Ubuntu"

-- A second font for table cells that are only a number ("12,345", "3.721", "61.28%",
-- "$1,234", "2h 3m 20s"), e.g. a monospaced one so numbers line up while names use FONT.
local NUMBER_FONT = "RobotoMono" -- a font name in quotes or an asset id, like FONT; nil = same as FONT
                                 -- (numbers line up best in a monospaced font: "RobotoMono" or "Code")
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
local templates = iris.TemplateConfig or {}
local theme = {}

local function copy(template)
    for key, value in pairs(template or {}) do theme[key] = value end
end

if COLORS then copy(templates[COLORS == "light" and "colorLight" or "colorDark"]) end
if SPACING then copy(templates[SPACING == "clear" and "sizeClear" or "sizeDefault"]) end

-- Table cells and headers get their font through rich text (<font face="...">), which
-- needs no Font type. Weights are numbers there.
local WEIGHTS = { Thin = 100, ExtraLight = 200, Light = 300, Regular = 400, Medium = 500, SemiBold = 600,
    Bold = 700, ExtraBold = 800, Heavy = 900 }
local function font_tag(font, weight)
    if font == nil then return nil end
    local tag = type(font) == "number" and string.format('<font family="rbxassetid://%d"', font)
        or string.format('<font face="%s"', tostring(font))
    if weight then tag = tag .. string.format(' weight="%s"', tostring(WEIGHTS[weight] or weight)) end
    return tag .. ">"
end

-- Titles, buttons and section headers use Iris's own font setting, which only takes a
-- Font object. Deadline's client console has no Font type, but Iris's presets hold two
-- Font objects (Code and Ubuntu), so those two work there too.
local function iris_font(name, weight_name)
    local presets = { Code = (templates.sizeDefault or {}).TextFont, Ubuntu = (templates.sizeClear or {}).TextFont }
    if presets[name] and not weight_name then return presets[name] end
    if not Font then return nil end
    local ok, font = pcall(function()
        local weight = weight_name and Enum.FontWeight[weight_name]
        if type(name) == "number" then return Font.fromId(name, weight) end
        local face = Font.fromEnum(Enum.Font[name])
        return weight and Font.new(face.Family, weight, face.Style) or face
    end)
    return ok and font or nil
end

-- CONSOLE_FONT goes into Iris's global config, so it reaches windows the theme doesn't wrap.
local console = "unchanged"
if CONSOLE_FONT then
    local face = iris_font(CONSOLE_FONT)
    local ok, err = false, "only \"Ubuntu\" or \"Code\" work in this console"
    if face and iris.UpdateGlobalConfig then ok, err = pcall(iris.UpdateGlobalConfig, { TextFont = face }) end
    if ok then console = tostring(CONSOLE_FONT) else print("[theme] CONSOLE_FONT not applied: " .. tostring(err)) end
end

local fonts, chrome = nil, "Iris's font"
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
elseif FONT or NUMBER_FONT then
    local text = font_tag(FONT, FONT_WEIGHT)
    fonts = { text = text, number = font_tag(NUMBER_FONT, NUMBER_WEIGHT) or text }
    local face = FONT and iris_font(FONT, FONT_WEIGHT)
    if face then theme.TextFont, chrome = face, tostring(FONT) end
end
if TEXT_SIZE then theme.TextSize = TEXT_SIZE end
for key, value in pairs(EXTRA) do theme[key] = value end

shared.iris_viewer_theme = theme
shared.iris_viewer_fonts = fonts
if chrome == "Iris's font" and console ~= "unchanged" then chrome = console end
print(string.format("[theme] applied: colors %s, spacing %s, text size %s; tables: font %s %s, numbers %s %s;"
    .. " titles and buttons: %s; console: %s", tostring(COLORS), tostring(SPACING), tostring(TEXT_SIZE),
    tostring(FONT or "Iris's"), tostring(FONT_WEIGHT or ""), tostring(NUMBER_FONT or "same"),
    tostring(NUMBER_WEIGHT or ""), chrome, console))
