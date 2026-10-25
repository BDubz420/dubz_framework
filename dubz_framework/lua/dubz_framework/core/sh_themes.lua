DFW.Themes = DFW.Themes or {}
local themes = DFW.Themes.Registry or {}
DFW.Themes.Registry = themes

local REQUIRED_COLORS = {
    "background", "surface", "surfaceAlt", "raised", "border", "borderSoft",
    "text", "textMuted", "textDim", "accent", "accentHover", "onAccent",
    "danger", "success", "warning", "info", "gold", "shadow", "overlay",
    "track", "outline", "slot"
}

local function c(r, g, b, a) return Color(r, g, b, a or 255) end

function DFW.Themes.Register(id, data)
    if not DFW.Util.IsIdentifier(id) or not istable(data) then return false, "invalid_theme" end
    if not isstring(data.name) or not istable(data.colors) then return false, "invalid_theme" end

    for _, key in ipairs(REQUIRED_COLORS) do
        if data.colors[key] == nil then return false, "missing_color:" .. key end
    end

    data.radius = data.radius or {XS = 4, SM = 6, MD = 10, LG = 14, XL = 18}
    data.spacing = data.spacing or {XS = 4, SM = 8, MD = 12, LG = 16, XL = 24}
    themes[id] = data
    hook.Run("DFW_ThemeRegistered", id)
    return true
end

DFW.Themes.DefaultId = "classic"

local ALIASES = {liminal = "classic"}

function DFW.Themes.Get(id) return themes[id] or themes[ALIASES[id]] end

function DFW.Themes.GetIds()
    local ids = {}
    for id in pairs(themes) do ids[#ids + 1] = id end
    table.sort(ids)
    for index, id in ipairs(ids) do
        if id == DFW.Themes.DefaultId then table.remove(ids, index) table.insert(ids, 1, id) break end
    end
    return ids
end

function DFW.Themes.GetRequiredColors() return table.Copy(REQUIRED_COLORS) end

DFW.Themes.Register("classic", {
    name = "Classic",
    colors = {
        background = c(0, 0, 0, 160), surface = c(0, 0, 0, 120), surfaceAlt = c(255, 255, 255, 10),
        raised = c(255, 255, 255, 24), border = c(255, 255, 255, 45), borderSoft = c(255, 255, 255, 20),
        text = c(255, 255, 255), textMuted = c(200, 200, 200), textDim = c(140, 140, 140),
        accent = c(241, 196, 15), accentHover = c(255, 214, 60), onAccent = c(20, 20, 20),
        danger = c(232, 84, 84), success = c(91, 201, 121), warning = c(238, 146, 80),
        info = c(91, 159, 232), gold = c(241, 196, 15),
        shadow = c(0, 0, 0, 0), overlay = c(0, 0, 0, 150),
        track = c(20, 20, 20, 220), outline = c(90, 90, 90), slot = c(0, 0, 0, 120)
    }
})

DFW.Themes.Register("slate", {
    name = "Slate",
    colors = {
        background = c(27, 28, 33), surface = c(36, 37, 44), surfaceAlt = c(30, 31, 37),
        raised = c(48, 50, 58), border = c(60, 62, 72), borderSoft = c(46, 48, 56),
        text = c(236, 237, 240), textMuted = c(165, 168, 178), textDim = c(118, 121, 132),
        accent = c(91, 159, 232), accentHover = c(118, 178, 243), onAccent = c(255, 255, 255),
        danger = c(232, 84, 84), success = c(91, 201, 121), warning = c(238, 146, 80),
        info = c(91, 159, 232), gold = c(221, 177, 74),
        shadow = c(0, 0, 0, 70), overlay = c(0, 0, 0, 170),
        track = c(20, 21, 26, 220), outline = c(84, 88, 100), slot = c(18, 19, 24, 150)
    }
})

DFW.Themes.Register("light", {
    name = "Light",
    colors = {
        background = c(226, 226, 230), surface = c(246, 246, 248), surfaceAlt = c(236, 236, 240),
        raised = c(218, 218, 224), border = c(176, 176, 186), borderSoft = c(200, 200, 208),
        text = c(28, 28, 32), textMuted = c(88, 88, 98), textDim = c(128, 128, 138),
        accent = c(176, 62, 58), accentHover = c(198, 78, 73), onAccent = c(255, 255, 255),
        danger = c(196, 52, 52), success = c(44, 146, 78), warning = c(200, 110, 40),
        info = c(52, 118, 196), gold = c(180, 138, 40),
        shadow = c(0, 0, 0, 50), overlay = c(0, 0, 0, 120),
        track = c(204, 204, 210), outline = c(150, 150, 160), slot = c(210, 210, 216)
    }
})
