local UI = DFW.UI
local showcase

local WINDOW_WIDTH = 720
local WINDOW_HEIGHT = 520
local CARD_GAP = 12
local ROW_HEIGHT = 34
local LABEL_WIDTH = 150
local SWATCH_KEYS = {"accent", "success", "warning", "danger", "info", "gold"}
local SWATCH_COLUMNS = 3
local SWATCH_ROW_HEIGHT = 84

local function newCard(parent, title)
    local card = vgui.Create("DFW.Card", parent)
    card:DockPadding(16, 12, 16, 16)

    local heading = vgui.Create("DFW.Label", card)
    heading:Dock(TOP)
    heading:SetTall(28)
    heading:SetStyle("heading")
    heading:SetText(title)

    return card
end

local function newRow(card, labelText)
    local row = vgui.Create("Panel", card)
    row:Dock(TOP)
    row:DockMargin(0, 8, 0, 0)
    row:SetTall(ROW_HEIGHT)

    local label = vgui.Create("DFW.Label", row)
    label:Dock(LEFT)
    label:SetWide(LABEL_WIDTH)
    label:SetStyle("muted")
    label:SetText(labelText)

    return row
end

local function addField(card, labelText, control, width)
    local row = newRow(card, labelText)

    control:SetParent(row)
    control:Dock(LEFT)
    control:SetWide(width)

    return control
end

local function addButtons(card, labelText, buttons)
    local row = newRow(card, labelText)

    for _, entry in ipairs(buttons) do
        local button = vgui.Create("DFW.Button", row)
        button:Dock(LEFT)
        button:DockMargin(0, 0, 8, 0)
        button:SetWide(entry.width or 110)
        button:SetLabel(entry.label)
        button:SetVariant(entry.variant or "default")
        button.DoClick = entry.click
    end
end

local function paintSwatches(_, width)
    local theme = UI.GetTheme()
    local cell = width / SWATCH_COLUMNS

    for index, key in ipairs(SWATCH_KEYS) do
        local column = (index - 1) % SWATCH_COLUMNS
        local line = math.floor((index - 1) / SWATCH_COLUMNS)
        local x = column * cell
        local y = line * SWATCH_ROW_HEIGHT

        DFW.Draw.Card(x, y, cell - 10, 52, {radius = "SM", color = theme[key]})
        DFW.Draw.Text(key, "Small", x, y + 66, theme.textMuted)
    end
end

local function buildModuleCard(page)
    local card = newCard(page, "A module card")
    card:Dock(LEFT)
    card:SetWide(336)
    card:DockMargin(0, 0, CARD_GAP, 0)

    local summary = vgui.Create("DFW.Paragraph", card)
    summary:Dock(TOP)
    summary:DockMargin(0, 4, 0, 12)
    summary:SetStyle("muted")
    summary:SetText("Windows, overlays and HUD elements are drawn from the active theme, so one choice restyles them all.")

    local badges = vgui.Create("Panel", card)
    badges:Dock(TOP)
    badges:SetTall(26)

    local x = 0

    for _, entry in ipairs({{"Running", "success"}, {"Low ink", "warning"}, {"Hot", "danger"}}) do
        local badge = vgui.Create("DFW.Badge", badges)
        badge:SetText(entry[1])
        badge:SetKind(entry[2])
        badge:SizeToContents()
        badge:SetPos(x, 2)
        x = x + badge:GetWide() + 8
    end

    for _, entry in ipairs({{"Ink", 0.72}, {"Heat", 0.38}, {"Health", 0.9}}) do
        local row = vgui.Create("Panel", card)
        row:Dock(TOP)
        row:DockMargin(0, 10, 0, 0)
        row:SetTall(24)

        local label = vgui.Create("DFW.Label", row)
        label:Dock(LEFT)
        label:SetWide(64)
        label:SetStyle("small")
        label:SetText(entry[1])

        local bar = vgui.Create("DFW.ProgressBar", row)
        bar:Dock(FILL)
        bar:DockMargin(0, 4, 0, 4)
        bar:SetFraction(entry[2])
        bar:SetLabel(math.floor(entry[2] * 100) .. "%")
    end

    local actions = vgui.Create("Panel", card)
    actions:Dock(BOTTOM)
    actions:SetTall(34)

    for index, entry in ipairs({{"Collect", "primary"}, {"Refill", "default"}}) do
        local button = vgui.Create("DFW.Button", actions)
        button:Dock(LEFT)
        button:DockMargin(index == 1 and 0 or 8, 0, 0, 0)
        button:SetWide(116)
        button:SetLabel(entry[1])
        button:SetVariant(entry[2])
    end
end

local function buildColourCard(page)
    local card = newCard(page, "Theme colours")
    card:Dock(FILL)

    local swatches = vgui.Create("Panel", card)
    swatches:Dock(FILL)
    swatches:DockMargin(0, 12, 0, 0)
    swatches.Paint = paintSwatches
end

local function buildOverview(page)
    buildModuleCard(page)
    buildColourCard(page)
end

local function buildControls(page)
    local card = newCard(page, "Settings controls")
    card:Dock(FILL)

    local toggle = vgui.Create("DFW.Toggle")
    toggle:SetChecked(true, true)
    addField(card, "Switch", toggle, 52)

    local slider = vgui.Create("DFW.Slider")
    slider:SetRange(0, 100)
    slider:SetDecimals(0)
    slider:SetValue(40, true)
    addField(card, "Slider", slider, 300)

    local dropdown = vgui.Create("DFW.Dropdown")

    for index, name in ipairs({"Standard", "Strict", "Relaxed"}) do dropdown:AddChoice(name, index, index == 1) end

    addField(card, "Drop-down", dropdown, 220)

    local entry = vgui.Create("DFW.TextEntry")
    entry:SetPlaceholder("Type here")
    addField(card, "Text", entry, 260)

    local colour = vgui.Create("DFW.ColorButton")
    colour:SetColor(UI.GetTheme().accent)
    addField(card, "Colour", colour, 120)

    addButtons(card, "Buttons", {
        {label = "Default"},
        {label = "Primary", variant = "primary"},
        {label = "Danger", variant = "danger"},
        {label = "Ghost", variant = "ghost"}
    })
end

local function buildFeedback(page)
    local notifications = newCard(page, "Notifications")
    notifications:Dock(TOP)
    notifications:SetTall(112)
    notifications:DockMargin(0, 0, 0, CARD_GAP)

    local kinds = {}

    for _, kind in ipairs({"info", "success", "warning", "danger"}) do
        kinds[#kinds + 1] = {label = kind, width = 100, click = function() UI.Notify("A " .. kind .. " notification.", kind) end}
    end

    addButtons(notifications, "Toasts", kinds)

    local dialogs = newCard(page, "Dialogs")
    dialogs:Dock(TOP)
    dialogs:SetTall(112)

    addButtons(dialogs, "Dialogs", {
        {label = "Confirm", click = function()
            UI.Confirm("Confirm action", "Continue with this action?", function() UI.Notify("Confirmed.", "success", 2) end)
        end},
        {label = "Message", click = function() UI.Message("Heads up", "Messages have a single button.") end},
        {label = "Prompt", click = function()
            UI.Prompt("Name it", "Type a name and press Enter.", "Example", function(value) UI.Notify("You typed " .. value .. ".", "info", 3) end)
        end}
    })
end

local PAGES = {
    {id = "overview", label = "Overview", icon = "navigation/menu", build = buildOverview},
    {id = "controls", label = "Controls", icon = "actions/edit_square", build = buildControls},
    {id = "feedback", label = "Feedback", icon = "communication/notifications", build = buildFeedback}
}

local function buildFooter(content)
    local footer = vgui.Create("Panel", content)
    footer:Dock(BOTTOM)
    footer:DockMargin(0, 8, 0, 0)
    footer:SetTall(36)

    local label = vgui.Create("DFW.Label", footer)
    label:Dock(LEFT)
    label:SetWide(110)
    label:SetStyle("muted")
    label:SetText("Preview theme")

    local dropdown = vgui.Create("DFW.Dropdown", footer)
    dropdown:Dock(LEFT)
    dropdown:SetWide(200)

    for _, id in ipairs(DFW.Themes.GetIds()) do
        dropdown:AddChoice(DFW.Themes.Get(id).name, id, id == UI.GetTheme().id)
    end

    dropdown.OnSelect = function(_, _, _, id) UI.PreviewTheme(id) end

    local hint = vgui.Create("DFW.Label", footer)
    hint:Dock(FILL)
    hint:DockMargin(14, 0, 0, 0)
    hint:SetStyle("small")
    hint:SetText("Previews on this screen only. Choose the real theme in the admin menu.")
end

local function open()
    local ply = LocalPlayer()

    if not IsValid(ply) or not DFW.Access.CanConfigure(ply) then return end
    if IsValid(showcase) then showcase:Remove() end

    showcase = UI.CreateFrame("Showcase", WINDOW_WIDTH, WINDOW_HEIGHT, "misc/handyman")
    showcase:SetSubtitle("Dubz Framework")
    showcase.OnRemove = function() UI.PreviewTheme(nil) end

    local content = showcase:GetContent()

    local tabs = vgui.Create("DFW.TabBar", content)
    tabs:Dock(TOP)
    tabs:SetTall(40)
    tabs:DockMargin(0, 0, 0, 10)

    buildFooter(content)

    local host = vgui.Create("Panel", content)
    host:Dock(FILL)

    local function show(id)
        host:Clear()

        for _, page in ipairs(PAGES) do
            if page.id == id then page.build(host) end
        end
    end

    for _, page in ipairs(PAGES) do tabs:AddTab(page.id, page.label, page.icon) end

    tabs.OnTabChanged = function(_, id) show(id) end
    show(PAGES[1].id)
end

DFW.UIDemo = {Open = open, GetFrame = function() return showcase end}
concommand.Add("dfw_ui_demo", open)
