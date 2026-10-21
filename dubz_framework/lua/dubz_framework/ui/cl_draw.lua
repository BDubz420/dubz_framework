DFW.Draw = DFW.Draw or {}
local Draw = DFW.Draw

function Draw.Text(text, font, x, y, color, alignX, alignY)
    return draw.SimpleText(tostring(text or ""), DFW.UI.Font(font), x, y, color or color_white, alignX or TEXT_ALIGN_LEFT, alignY or TEXT_ALIGN_CENTER)
end

function Draw.Shadow(x, y, w, h, radius, alpha)
    return
end

function Draw.Outline(x, y, w, h, color, thickness)
    surface.SetDrawColor(color)
    surface.DrawOutlinedRect(x, y, w, h, thickness or 1)
end

function Draw.Card(x, y, w, h, options)
    options = options or {}
    local theme = DFW.UI.GetTheme()
    local radius = DFW.UI.Radius(options.radius or "MD")
    local background = options.color or theme.surface

    draw.RoundedBox(radius, x, y, w, h, background)

    if options.border then
        surface.SetDrawColor(options.border)
        surface.DrawOutlinedRect(x, y, w, h, 1)
    end
end

function Draw.Icon(key, x, y, size, color)
    DFW.Icons.Draw(key, x, y, size, size, color or DFW.UI.GetTheme().text)
end

function Draw.IconChip(key, x, y, size, color, alpha)
    color = color_white
    local iconSize = math.floor(size * 0.58)
    Draw.Icon(key, x + (size - iconSize) / 2, y + (size - iconSize) / 2, iconSize, color)
end
