local UI = DFW.UI

function UI.AttachPopup(popup, owner)
    local hookId = "DFW.Popup." .. tostring(popup)

    hook.Add("VGUIMousePressed", hookId, function(pressed)
        if not IsValid(popup) then
            hook.Remove("VGUIMousePressed", hookId)
            return
        end
        if pressed == popup or (IsValid(pressed) and pressed:HasParent(popup)) then return end
        if IsValid(owner) and pressed == owner then return end
        popup:Remove()
    end)

    popup.OnRemove = function() hook.Remove("VGUIMousePressed", hookId) end
    popup.Think = function(self)
        if not IsValid(owner) or not owner:IsVisible() then self:Remove() end
    end
end

local function popupPosition(owner, width, height)
    local x, y = owner:LocalToScreen(0, owner:GetTall() + 2)
    if y + height > ScrH() - 8 then
        local _, top = owner:LocalToScreen(0, 0)
        y = top - height - 2
    end
    x = math.Clamp(x, 8, math.max(ScrW() - width - 8, 8))
    return x, math.max(y, 8)
end

local function paintPopup(_, w, h)
    local theme = UI.GetTheme()
    local radius = UI.Radius("MD")
    draw.RoundedBox(radius, 0, 0, w, h, theme.border)
    draw.RoundedBox(radius, 1, 1, w - 2, h - 2, theme.surface)
end

local PANEL = {}

function PANEL:Init()
    local bar = self:GetVBar()
    bar:SetWide(8)
    bar:SetHideButtons(true)
    bar.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, UI.WithAlpha(UI.GetTheme().surfaceAlt, 200))
    end
    bar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, UI.GetTheme().raised)
    end
end

vgui.Register("DFW.ScrollPanel", PANEL, "DScrollPanel")

PANEL = {}

function PANEL:Init()
    self:SetText("")
    self:SetCursor("hand")
    self.Choices = {}
    self.SelectedIndex = nil
    self.Placeholder = "Select..."
end

function PANEL:AddChoice(label, data, selected)
    self.Choices[#self.Choices + 1] = {label = tostring(label), data = data}
    if selected then self.SelectedIndex = #self.Choices end
    return #self.Choices
end

function PANEL:Clear()
    self.Choices = {}
    self.SelectedIndex = nil
end

function PANEL:GetSelected()
    local choice = self.Choices[self.SelectedIndex or 0]
    if not choice then return nil end
    return choice.label, choice.data
end

function PANEL:OnSelect() end

function PANEL:Choose(index)
    local choice = self.Choices[index]
    if not choice then return end
    self.SelectedIndex = index
    self:OnSelect(index, choice.label, choice.data)
end

function PANEL:SelectByData(data, quiet)
    for index, choice in ipairs(self.Choices) do
        if DFW.Util.DeepEqual(choice.data, data) then
            if quiet then self.SelectedIndex = index else self:Choose(index) end
            return true
        end
    end
    return false
end

function PANEL:SetPlaceholder(text) self.Placeholder = tostring(text or "") end

local SEARCH_FROM = 8

function PANEL:DoClick()
    if IsValid(self.Menu) then self.Menu:Remove() return end
    if #self.Choices == 0 then return end

    local rowHeight, padding = 30, 4
    local searchable = #self.Choices > SEARCH_FROM
    local searchHeight = searchable and 34 or 0
    local width = self:GetWide()
    local height = math.min(#self.Choices * rowHeight + padding * 2, 264) + searchHeight
    local x, y = popupPosition(self, width, height)

    local menu = vgui.Create("EditablePanel")
    menu:SetSize(width, height)
    menu:SetPos(x, y)
    menu:MakePopup()
    menu:SetKeyboardInputEnabled(searchable)
    menu.Paint = paintPopup
    self.Menu = menu

    local search
    if searchable then
        search = vgui.Create("DFW.TextEntry", menu)
        search:Dock(TOP)
        search:SetTall(28)
        search:DockMargin(padding, padding, padding, 0)
        search:SetPlaceholder("Search...")
        search:RequestFocus()
    end

    local scroll = vgui.Create("DFW.ScrollPanel", menu)
    scroll:Dock(FILL)
    scroll:DockMargin(padding, padding, padding, padding)

    local function populate()
        scroll:Clear()

        local query = search and string.lower(string.Trim(search:GetValue())) or ""

        for index, choice in ipairs(self.Choices) do
            if query == "" or string.find(string.lower(choice.label), query, 1, true) then
                local row = vgui.Create("DFW.Button", scroll:GetCanvas())
                row:Dock(TOP)
                row:SetTall(rowHeight)
                row:SetVariant("ghost")
                row:SetLabel(choice.label)
                row:SetTextAlign(TEXT_ALIGN_LEFT)
                row:SetActive(index == self.SelectedIndex)
                row.DoClick = function()
                    menu:Remove()
                    self:Choose(index)
                end
            end
        end
    end

    populate()
    if search then search.OnChange = populate end

    UI.AttachPopup(menu, self)
end

function PANEL:OnRemove()
    if IsValid(self.Menu) then self.Menu:Remove() end
end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local radius = UI.Radius("SM")
    local open = IsValid(self.Menu)
    local hover = DFW.Anim.Lerp(self, "hover", (self:IsHovered() or open) and 1 or 0, 16)

    draw.RoundedBox(radius, 0, 0, w, h, DFW.Anim.Color(theme.border, theme.accent, open and 1 or hover * 0.5))
    draw.RoundedBox(radius, 1, 1, w - 2, h - 2, theme.surfaceAlt)

    local label = self:GetSelected()
    if label then
        DFW.Draw.Text(label, "Body", 10, h / 2, theme.text)
    else
        DFW.Draw.Text(self.Placeholder, "Body", 10, h / 2, theme.textDim)
    end
    DFW.Icons.Draw("actions/arrow_drop_down", w - 26, h / 2 - 10, 20, 20, theme.textMuted)
end

vgui.Register("DFW.Dropdown", PANEL, "DButton")

PANEL = {}

function PANEL:Init()
    self:SetText("")
    self:SetCursor("hand")
    self.Color = Color(255, 255, 255, 255)
    self.AlphaBar = true
end

function PANEL:SetColor(color)
    self.Color = istable(color) and DFW.Util.TableToColor(color) or color_white
end

function PANEL:GetColor() return self.Color end
function PANEL:SetAlphaBar(enabled) self.AlphaBar = enabled == true end
function PANEL:OnValueChanged() end

function PANEL:DoClick()
    if IsValid(self.Menu) then self.Menu:Remove() return end

    local width, height = 250, self.AlphaBar and 230 or 210
    local x, y = popupPosition(self, width, height)

    local menu = vgui.Create("EditablePanel")
    menu:SetSize(width, height)
    menu:SetPos(x, y)
    menu:MakePopup()
    menu:SetKeyboardInputEnabled(false)
    menu.Paint = paintPopup
    self.Menu = menu

    local mixer = vgui.Create("DColorMixer", menu)
    mixer:Dock(FILL)
    mixer:DockMargin(8, 8, 8, 8)
    mixer:SetPalette(false)
    mixer:SetAlphaBar(self.AlphaBar)
    mixer:SetWangs(true)
    mixer:SetColor(self.Color)
    mixer.ValueChanged = function(_, color)
        self.Color = Color(color.r, color.g, color.b, color.a)
        self:OnValueChanged(self.Color)
    end

    UI.AttachPopup(menu, self)
end

function PANEL:OnRemove()
    if IsValid(self.Menu) then self.Menu:Remove() end
end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local radius = UI.Radius("SM")
    local hover = DFW.Anim.Lerp(self, "hover", (self:IsHovered() or IsValid(self.Menu)) and 1 or 0, 16)

    draw.RoundedBox(radius, 0, 0, w, h, DFW.Anim.Color(theme.border, theme.accent, hover))
    draw.RoundedBox(radius, 1, 1, w - 2, h - 2, theme.surfaceAlt)
    draw.RoundedBox(4, 6, 6, 28, h - 12, Color(self.Color.r, self.Color.g, self.Color.b, 255))
    DFW.Draw.Text(string.format("#%02X%02X%02X", self.Color.r, self.Color.g, self.Color.b), "Mono", 44, h / 2, theme.text)
end

vgui.Register("DFW.ColorButton", PANEL, "DButton")
