DFW.UI = DFW.UI or {}
local UI = DFW.UI

UI.Fonts = {
    Title = "DFW.Title",
    Heading = "DFW.Heading",
    Body = "DFW.Body",
    BodyBold = "DFW.BodyBold",
    Small = "DFW.Small",
    Tiny = "DFW.Tiny",
    Button = "DFW.Button",
    Mono = "DFW.Mono"
}

local function make(name, font, size, weight)
    surface.CreateFont(name, {font = font, size = size, weight = weight, antialias = true, extended = true})
end

make(UI.Fonts.Title, "Roboto", 24, 800)
make(UI.Fonts.Heading, "Roboto", 19, 700)
make(UI.Fonts.Body, "Roboto", 16, 500)
make(UI.Fonts.BodyBold, "Roboto", 16, 700)
make(UI.Fonts.Small, "Roboto", 13, 500)
make(UI.Fonts.Tiny, "Roboto", 11, 600)
make(UI.Fonts.Button, "Roboto", 14, 700)
make(UI.Fonts.Mono, "Consolas", 14, 500)

function UI.Font(key)
    return UI.Fonts[key] or key or UI.Fonts.Body
end

-- Modules can create their own cached fonts through here so names never collide.
local custom = {}
function UI.CreateFont(name, size, weight, family)
    local fullName = "DFW.Custom." .. tostring(name) .. "." .. tostring(size) .. "." .. tostring(weight or 500)
    if not custom[fullName] then
        make(fullName, family or "Roboto", size, weight or 500)
        custom[fullName] = true
    end
    return fullName
end

function UI.Scale(value)
    return math.max(1, math.floor(value * math.Clamp(ScrH() / 1080, 0.75, 1.3)))
end

function UI.TextSize(text, font)
    surface.SetFont(UI.Font(font))
    return surface.GetTextSize(tostring(text or ""))
end

-- Greedy word wrap. Returns a list of lines that each fit within maxWidth.
function UI.WrapText(text, font, maxWidth)
    surface.SetFont(UI.Font(font))
    local lines = {}
    for _, paragraph in ipairs(string.Explode("\n", tostring(text or ""))) do
        local line = ""
        for word in string.gmatch(paragraph, "%S+") do
            local candidate = line == "" and word or (line .. " " .. word)
            if surface.GetTextSize(candidate) > maxWidth and line ~= "" then
                lines[#lines + 1] = line
                line = word
            else
                line = candidate
            end
        end
        lines[#lines + 1] = line
    end
    return lines
end
