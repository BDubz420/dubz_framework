DFW.UI = DFW.UI or {}
local UI = DFW.UI

local cache

local function rebuild()
    local id = DFW.Config.Get("dubz_core", "theme", DFW.Themes.DefaultId)
    local base = DFW.Themes.Get(id) or DFW.Themes.Get(DFW.Themes.DefaultId)

    local theme = {id = id, name = base.name, radius = base.radius, spacing = base.spacing}
    for key, color in pairs(base.colors) do theme[key] = color end

    if DFW.Config.Get("dubz_core", "use_custom_accent", false) == true then
        local accent = DFW.Util.TableToColor(DFW.Config.Get("dubz_core", "accent"))
        theme.accent = accent
        theme.accentHover = Color(math.min(accent.r + 24, 255), math.min(accent.g + 20, 255), math.min(accent.b + 20, 255), accent.a)
    end

    cache = theme
    return theme
end

-- Colour tokens: background, surface, surfaceAlt, raised, border, borderSoft,
-- text, textMuted, textDim, accent, accentHover, onAccent, danger, success,
-- warning, info, gold, shadow, overlay, track, outline, slot. Also .radius and .spacing tables.
function UI.GetTheme()
    return cache or rebuild()
end

function UI.Color(key, fallback)
    return UI.GetTheme()[key] or fallback or color_white
end

function UI.Radius(key)
    if isnumber(key) then return key end
    local radius = UI.GetTheme().radius
    return radius[key or "MD"] or radius.MD
end

function UI.Space(key)
    local spacing = UI.GetTheme().spacing
    return spacing[key or "MD"] or spacing.MD
end

function UI.WithAlpha(color, alpha)
    color = color or color_white
    return Color(color.r, color.g, color.b, alpha)
end

function UI.RegisterTheme(id, data)
    local ok, reason = DFW.Themes.Register(string.lower(tostring(id)), data)
    if ok then cache = nil end
    return ok, reason
end

hook.Add("DFW_ConfigChanged", "DFW.UI.ThemeCache", function(moduleId)
    if moduleId == "dubz_core" then
        cache = nil
        hook.Run("DFW_ThemeChanged")
    end
end)

-- A theme registered after the framework booted may be the one the admin already chose: rebuild so it applies.
hook.Add("DFW_ThemeRegistered", "DFW.UI.ThemeCache", function()
    cache = nil
    hook.Run("DFW_ThemeChanged")
end)

hook.Run("DFW_ThemeReady", UI.GetTheme())
