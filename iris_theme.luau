-- iris_theme.luau
-- Your look for iris_viewer.luau's windows: colors, spacing, fonts and text size, and
-- (CONSOLE_FONT / CONSOLE_COLORS) the client Luau console's too.
-- Paste it into the CLIENT Luau console (or use client_autorun.txt, which has it), then
-- change the values below and paste it again to apply them. More in IRIS_VIEWER.md.

local COLORS = "deadline" -- "deadline": black and grey with white text, like Deadline's menus;
                          -- "dark" / "light": Iris's own sets (only if this console exposes them); nil: leave alone
local CONSOLE_COLORS = true -- also give the client console (every Iris window) the "deadline" colors
local SPACING = nil     -- "clear" (roomier), "default" (compact), or nil to leave spacing alone
-- FONT is all the stat printer's text: tables, titles, buttons, section headers and tips (by rich
-- text, so an asset id like Rubik works without the Font type). Only typing boxes keep CONSOLE_FONT.
local FONT = 12187365977  -- Rubik (Deadline's UI font), by its Creator Store asset id. Or a Roblox font
                          -- name in quotes, like "RobotoMono", "BuilderSans", "Ubuntu", "Arial";
                          -- nil for Iris's font (Code); "?" prints every font name
local FONT_WEIGHT = "Regular" -- text: nil, or "Light", "Regular", "Medium", "SemiBold", "Bold", "ExtraBold", "Heavy"
local HEADER_WEIGHT = "Bold"  -- table headers, titles, buttons and section headers (same font as FONT); nil = same as FONT_WEIGHT
local TEXT_SIZE = 14    -- text size in pixels, or nil to leave it alone

-- Font of every Iris window: the client Luau console itself, and the stat printer's typing
-- boxes (filter, Export). A built-in Roblox font name in quotes, with the weight in the name
-- ("BuilderSansBold", "GothamBold", "SourceSansBold"); nil leaves it alone. Rubik isn't built
-- in and needs the Font type, so it can't be used here.
local CONSOLE_FONT = "BuilderSansBold"

-- A second font for table cells that are only a number ("12,345", "3.721", "61.28%",
-- "$1,234", "2h 3m 20s"), e.g. a monospaced one so numbers line up while names use FONT.
local NUMBER_FONT = nil -- a font name in quotes or an asset id, like FONT; nil = same as FONT
                        -- (numbers line up best in a monospaced font: "RobotoMono" or "Code")
local NUMBER_WEIGHT = "Regular" -- like FONT_WEIGHT

-- Any other Iris style key, applied last. Needs Roblox types, e.g.
--   WindowBgTransparency = 0.2,
--   TextColor = Color3.fromRGB(230, 230, 230),
--   ItemSpacing = Vector2.new(8, 6),
-- The keys are listed in Iris's config.lua: https://github.com/SirMallard/Iris/blob/main/lib/config.lua
local EXTRA = {}

-- The "deadline" colors, as grey levels from 0 (black) to 255 (white), and transparencies.
local DEADLINE_GREYS = {
    TextColor = 255, TextDisabledColor = 130, BorderColor = 55, BorderActiveColor = 120,
    WindowBgColor = 10, PopupBgColor = 14, MenubarBgColor = 16,
    TitleBgColor = 16, TitleBgActiveColor = 28, TitleBgCollapsedColor = 16,
    ScrollbarGrabColor = 70, FrameBgColor = 26, FrameBgHoveredColor = 40, FrameBgActiveColor = 56,
    ButtonColor = 44, ButtonHoveredColor = 70, ButtonActiveColor = 100, CheckMarkColor = 255,
    HeaderColor = 30, HeaderHoveredColor = 50, HeaderActiveColor = 70,
    SliderGrabColor = 200, SliderGrabActiveColor = 255, SeparatorColor = 55,
    TableBorderStrongColor = 60, TableBorderLightColor = 36, TableRowBgColor = 0, TableRowBgAltColor = 255,
}
local DEADLINE_TRANSPARENCIES = {
    WindowBgTransparency = 0, TitleBgTransparency = 0, -- opaque: a window behind must not show through TitleBgActiveTransparency = 0,
    ButtonTransparency = 0, HeaderTransparency = 0, FrameBgTransparency = 0,
    TableRowBgTransparency = 1, TableRowBgAltTransparency = 0.95,
}

if not iris then
    print("[theme] iris is missing: run this in the client Luau console")
    return
end
local templates = iris.TemplateConfig or {}
local theme = {}

local function copy(template)
    for key, value in pairs(template or {}) do theme[key] = value end
end

-- Greys without the Color3 type: a hidden TextLabel's default colors are real black
-- (TextStrokeColor3) and white (BackgroundColor3), and Color3:Lerp makes the greys between.
-- Only a checked black and white are used; a bad color would break every Iris window.
local function grey_maker()
    if Color3 and Color3.fromRGB then return function(v) return Color3.fromRGB(v, v, v) end end
    if not create_instance then return nil end
    local ok, black, white = pcall(function()
        local label = create_instance("TextLabel")
        local dark, light = label.TextStrokeColor3, label.BackgroundColor3
        pcall(function() label.destroy() end)
        return dark, light
    end)
    if not ok then return nil end
    local checked, black_and_white = pcall(function()
        return black.R + black.G + black.B == 0 and white.R + white.G + white.B == 3
    end)
    if not (checked and black_and_white) then return nil end
    return function(v) return black:Lerp(white, v / 255) end
end

local palette = nil -- the "deadline" colors, for this theme and (CONSOLE_COLORS) every Iris window
if COLORS == "deadline" then
    local grey = grey_maker()
    local ok = grey and pcall(function()
        palette = {}
        for key, level in pairs(DEADLINE_GREYS) do palette[key] = grey(level) end
        for key, value in pairs(DEADLINE_TRANSPARENCIES) do palette[key] = value end
    end)
    if ok then copy(palette) else
        palette = nil
        print("[theme] COLORS \"deadline\" not applied: no Color3 type here, and no colors from a hidden TextLabel")
    end
elseif COLORS then
    copy(templates[COLORS == "light" and "colorLight" or "colorDark"])
end
if SPACING then copy(templates[SPACING == "clear" and "sizeClear" or "sizeDefault"]) end

return (function(fonts) fonts() end)(function() -- fonts: a second part with its own 255 lines (IRIS_VIEWER.md)
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
-- Font object. Without the Font type there are two sources: Iris's presets (Code, Ubuntu)
-- and a hidden TextLabel's FontFace (any built-in font name).
local function is_font(value) -- a real Font object has a Family like "rbxasset://fonts/families/Ubuntu.json"
    local ok, family = pcall(function() return value.Family end)
    return ok and type(family) == "string" and family:find("rbxasset") ~= nil
end
local function iris_font(name, weight_name)
    local presets = { Code = (templates.sizeDefault or {}).TextFont, Ubuntu = (templates.sizeClear or {}).TextFont }
    if presets[name] and not weight_name then return presets[name] end
    if Font then
        local ok, font = pcall(function()
            local weight = weight_name and Enum.FontWeight[weight_name]
            if type(name) == "number" then return Font.fromId(name, weight) end
            local face = Font.fromEnum(Enum.Font[name])
            return weight and Font.new(face.Family, weight, face.Style) or face
        end)
        return ok and font or nil
    end
    -- No Font type (Deadline's client console): give a hidden TextLabel the font by name and
    -- read its FontFace back. Only a checked, real Font is used; a bad one would break Iris.
    if type(name) ~= "string" or weight_name or not create_instance then return nil end
    local ok, face = pcall(function()
        local label = create_instance("TextLabel")
        label.Font = Enum.Font[name]
        local font = label.FontFace
        pcall(function() label.destroy() end)
        return font
    end)
    return ok and is_font(face) and face or nil
end

-- CONSOLE_FONT and CONSOLE_COLORS go into Iris's global config, so they reach windows the
-- theme doesn't wrap: the client console itself, and any other Iris window.
local global, has_global = {}, false
if CONSOLE_FONT then
    local face = iris_font(CONSOLE_FONT)
    if face then global.TextFont, has_global = face, true else
        print(string.format("[theme] CONSOLE_FONT not applied: could not get the %s font here (Iris's presets: %s, create_instance: %s)",
            tostring(CONSOLE_FONT), iris.TemplateConfig and "yes" or "missing", create_instance and "yes" or "missing"))
    end
end
if CONSOLE_COLORS and palette then
    for key, value in pairs(palette) do global[key] = value end
    has_global = true
end
if has_global and iris.UpdateGlobalConfig then
    local ok, err = pcall(iris.UpdateGlobalConfig, global)
    if not ok then
        print("[theme] console font and colors not applied: " .. tostring(err))
    end
end

local fonts = nil
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
    fonts = { text = text, number = font_tag(NUMBER_FONT, NUMBER_WEIGHT) or text,
        header = HEADER_WEIGHT and font_tag(FONT, HEADER_WEIGHT) or text }
    -- Titles, buttons, section headers and tips get FONT too, by rich text (headers' weight): they can't take an
    -- asset id as a Font here. RichText covers only the viewer's windows; the console keeps CONSOLE_FONT.
    fonts.label = FONT and fonts.header
    if FONT then theme.RichText = true end
    local face = FONT and iris_font(FONT, FONT_WEIGHT)
    if face then theme.TextFont = face end
end
if TEXT_SIZE then theme.TextSize = TEXT_SIZE end
for key, value in pairs(EXTRA) do theme[key] = value end

shared.iris_viewer_theme = theme
shared.iris_viewer_fonts = fonts
end)
