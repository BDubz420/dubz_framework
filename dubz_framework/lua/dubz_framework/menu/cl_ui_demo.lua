local UI = DFW.UI
local demo

local function section(canvas, title)
    local label = vgui.Create("DFW.Label", canvas)
    label:Dock(TOP)
    label:DockMargin(2, 14, 0, 6)
    label:SetTall(24)
    label:SetStyle("heading")
    label:SetText(title)
    return label
end

local function row(canvas, height)
    local panel = vgui.Create("Panel", canvas)
    panel:Dock(TOP)
    panel:DockMargin(0, 0, 10, 8)
    panel:SetTall(height or 36)
    return panel
end

local function place(parent, child, x, width, height)
    child:SetPos(x, 0)
    child:SetSize(width, height or parent:GetTall())
    return x + width + 10
end

local function buildButtons(canvas)
    section(canvas, "Buttons")
    local line = row(canvas)
    local x = 0
    for _, variant in ipairs({"default", "primary", "danger", "ghost"}) do
        local button = vgui.Create("DFW.Button", line)
        button:SetLabel(variant)
        button:SetVariant(variant)
        button:SetIcon("actions/check")
        button.DoClick = function() UI.Notify("Clicked the " .. variant .. " button", "info", 2) end
        x = place(line, button, x, 130)
    end

    section(canvas, "Disabled and icon-only")
    line = row(canvas)
    local disabled = vgui.Create("DFW.Button", line)
    disabled:SetLabel("Disabled")
    disabled:SetEnabled(false)
    x = place(line, disabled, 0, 130)
    for _, icon in ipairs({"actions/add", "actions/delete", "actions/save", "actions/refresh"}) do
        local button = vgui.Create("DFW.Button", line)
        button:SetIcon(icon)
        x = place(line, button, x, 40)
    end

    section(canvas, "Badges and progress")
    line = row(canvas, 28)
    x = 0
    for _, kind in ipairs({"accent", "success", "warning", "danger", "info", "muted"}) do
        local badge = vgui.Create("DFW.Badge", line)
        badge:SetText(kind)
        badge:SetKind(kind)
        badge:SizeToContents()
        badge:SetPos(x, 4)
        x = x + badge:GetWide() + 8
    end

    line = row(canvas, 18)
    local bar = vgui.Create("DFW.ProgressBar", line)
    bar:SetSize(360, 16)
    bar:SetFraction(0.62)
    bar:SetLabel("62%")
end

local function buildInputs(canvas)
    section(canvas, "Text")
    local line = row(canvas)
    local entry = vgui.Create("DFW.TextEntry", line)
    entry:SetPlaceholder("Type something...")
    place(line, entry, 0, 280, 32)

    section(canvas, "Toggle, checkbox, slider")
    line = row(canvas, 30)
    local toggle = vgui.Create("DFW.Toggle", line)
    toggle:SetLabel("Toggle")
    toggle:SetChecked(true, true)
    toggle:SetPos(0, 4)
    toggle:SetSize(150, 22)

    local checkbox = vgui.Create("DFW.Checkbox", line)
    checkbox:SetLabel("Checkbox")
    checkbox:SetPos(170, 4)
    checkbox:SetSize(150, 22)

    line = row(canvas, 30)
    local slider = vgui.Create("DFW.Slider", line)
    slider:SetRange(0, 10)
    slider:SetDecimals(1)
    slider:SetValue(3.5, true)
    slider:SetSize(320, 28)
    slider.OnValueCommitted = function(_, value) UI.Notify("Slider released at " .. value, "info", 2) end

    section(canvas, "Dropdown and colour")
    line = row(canvas)
    local dropdown = vgui.Create("DFW.Dropdown", line)
    for index, name in ipairs({"Alpha", "Bravo", "Charlie", "Delta", "Echo"}) do dropdown:AddChoice(name, index, index == 2) end
    dropdown.OnSelect = function(_, _, label) UI.Notify("Selected " .. label, "info", 2) end
    local x = place(line, dropdown, 0, 200, 32)

    local colorButton = vgui.Create("DFW.ColorButton", line)
    colorButton:SetColor({r = 190, g = 86, b = 82, a = 255})
    place(line, colorButton, x, 150, 32)
end

local function buildFeedback(canvas)
    section(canvas, "Toasts")
    local line = row(canvas)
    local x = 0
    for _, kind in ipairs({"info", "success", "warning", "danger"}) do
        local button = vgui.Create("DFW.Button", line)
        button:SetLabel(kind)
        button.DoClick = function() UI.Notify("This is a " .. kind .. " notification.", kind) end
        x = place(line, button, x, 120)
    end

    section(canvas, "Dialogs")
    line = row(canvas)
    local confirm = vgui.Create("DFW.Button", line)
    confirm:SetLabel("Confirm")
    confirm.DoClick = function()
        UI.Confirm("Confirm action", "Are you sure you want to continue? This is only a demonstration.", function()
            UI.Notify("Confirmed", "success", 2)
        end)
    end
    x = place(line, confirm, 0, 120)

    local message = vgui.Create("DFW.Button", line)
    message:SetLabel("Message")
    message.DoClick = function() UI.Message("Heads up", "Messages have a single OK button.") end
    x = place(line, message, x, 120)

    local prompt = vgui.Create("DFW.Button", line)
    prompt:SetLabel("Prompt")
    prompt.DoClick = function()
        UI.Prompt("Name it", "Type a name and press Enter.", "Example", function(value) UI.Notify("You typed: " .. value, "info", 3) end)
    end
    place(line, prompt, x, 120)
end

local function buildTypography(canvas)
    section(canvas, "Type scale")
    for _, style in ipairs({"title", "heading", "bodybold", "body", "muted", "small", "tiny"}) do
        local label = vgui.Create("DFW.Label", canvas)
        label:Dock(TOP)
        label:DockMargin(2, 0, 0, 4)
        label:SetTall(30)
        label:SetStyle(style)
        label:SetText(style .. " - Sector 18 // Liminal RP")
    end

    section(canvas, "Paragraph")
    local paragraph = vgui.Create("DFW.Paragraph", canvas)
    paragraph:Dock(TOP)
    paragraph:DockMargin(2, 0, 12, 0)
    paragraph:SetStyle("muted")
    paragraph:SetText("Paragraphs wrap to the width of their container and size their own height, so descriptions and dialog text never need manual measuring. Resize the window to watch it reflow.")

    section(canvas, "Card with accent")
    local card = vgui.Create("DFW.Card", canvas)
    card:Dock(TOP)
    card:DockMargin(0, 0, 10, 8)
    card:SetTall(60)
    card:SetAccent(UI.GetTheme().accent)
end

local pages = {
    {id = "buttons", label = "Buttons", icon = "misc/bolt", build = buildButtons},
    {id = "inputs", label = "Inputs", icon = "actions/edit_square", build = buildInputs},
    {id = "feedback", label = "Feedback", icon = "communication/notifications", build = buildFeedback},
    {id = "type", label = "Type", icon = "navigation/menu", build = buildTypography}
}

local function open()
    local ply = LocalPlayer()
    if not IsValid(ply) or not DFW.Access.CanConfigure(ply) then return end
    if IsValid(demo) then demo:Remove() end

    demo = UI.CreateFrame("Interface Components", 760, 620, "misc/handyman")
    demo:SetSubtitle("Every control in the Dubz Framework UI library")

    local content = demo:GetContent()
    local tabs = vgui.Create("DFW.TabBar", content)
    tabs:Dock(TOP)
    tabs:SetTall(40)
    tabs:DockMargin(0, 0, 0, 8)

    local scroll = vgui.Create("DFW.ScrollPanel", content)
    scroll:Dock(FILL)

    local function show(id)
        local canvas = scroll:GetCanvas()
        canvas:Clear()
        for _, page in ipairs(pages) do
            if page.id == id then page.build(canvas) end
        end
    end

    for _, page in ipairs(pages) do tabs:AddTab(page.id, page.label, page.icon) end
    tabs.OnTabChanged = function(_, id) show(id) end
    show(pages[1].id)
end

DFW.UIDemo = {Open = open, GetFrame = function() return demo end}
concommand.Add("dfw_ui_demo", open)
