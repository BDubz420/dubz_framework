local UI = DFW.UI

local PANEL = {}

function PANEL:Init()
    self:SetFont(UI.Font("Body"))
    self:SetPaintBackground(false)
    self.Placeholder = ""
end

function PANEL:SetPlaceholder(text) self.Placeholder = tostring(text or "") end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local radius = UI.Radius("SM")
    local focus = DFW.Anim.Lerp(self, "focus", self:HasFocus() and 1 or 0, 14)

    draw.RoundedBox(radius, 0, 0, w, h, DFW.Anim.Color(theme.border, theme.accent, focus))
    draw.RoundedBox(radius, 1, 1, w - 2, h - 2, theme.surfaceAlt)

    if self.Placeholder ~= "" and self:GetValue() == "" and not self:HasFocus() then
        DFW.Draw.Text(self.Placeholder, "Body", 6, h / 2, theme.textDim)
    end

    self:DrawTextEntryText(theme.text, theme.accent, theme.text)
end

vgui.Register("DFW.TextEntry", PANEL, "DTextEntry")

local function checkableBase()
    local base = {}

    function base:Init()
        self:SetText("")
        self:SetCursor("hand")
        self.Checked = false
        self.Label = ""
    end

    function base:SetLabel(text) self.Label = tostring(text or "") end

    function base:SetChecked(value, quiet)
        value = value == true
        if value == self.Checked then return end
        self.Checked = value
        if not quiet then self:OnChange(value) end
    end

    function base:GetChecked() return self.Checked end
    function base:OnChange() end

    function base:DoClick()
        if not self:IsEnabled() then return end
        self:SetChecked(not self.Checked)
    end

    return base
end

PANEL = checkableBase()

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local trackW, trackH = 40, 22
    local y = (h - trackH) / 2
    local state = DFW.Anim.Lerp(self, "state", self.Checked and 1 or 0, 16)
    local hover = DFW.Anim.Lerp(self, "hover", self:IsHovered() and 1 or 0, 16)
    local enabled = self:IsEnabled()

    local off = DFW.Anim.Color(theme.raised, theme.border, hover)
    local track = DFW.Anim.Color(off, theme.accent, state)
    if not enabled then track = UI.WithAlpha(track, 90) end

    draw.RoundedBox(trackH / 2, 0, y, trackW, trackH, track)
    local knobX = 3 + state * (trackW - trackH)
    draw.RoundedBox(8, knobX, y + 3, 16, 16, enabled and theme.onAccent or theme.textDim)

    if self.Label ~= "" then
        DFW.Draw.Text(self.Label, "Body", trackW + 10, h / 2, enabled and theme.text or theme.textDim)
    end
end

vgui.Register("DFW.Toggle", PANEL, "DButton")

PANEL = checkableBase()

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local size = math.min(20, h - 2)
    local y = (h - size) / 2
    local state = DFW.Anim.Lerp(self, "state", self.Checked and 1 or 0, 18)
    local hover = DFW.Anim.Lerp(self, "hover", self:IsHovered() and 1 or 0, 16)

    draw.RoundedBox(5, 0, y, size, size, DFW.Anim.Color(theme.border, theme.accent, math.max(state, hover * 0.5)))
    draw.RoundedBox(4, 1, y + 1, size - 2, size - 2, DFW.Anim.Color(theme.surfaceAlt, theme.accent, state))
    if state > 0.05 then
        DFW.Icons.Draw("actions/check", (size - 14) / 2, y + (size - 14) / 2, 14, 14, UI.WithAlpha(theme.onAccent, state * 255))
    end

    if self.Label ~= "" then
        DFW.Draw.Text(self.Label, "Body", size + 9, h / 2, self:IsEnabled() and theme.text or theme.textDim)
    end
end

vgui.Register("DFW.Checkbox", PANEL, "DButton")

PANEL = {}

function PANEL:Init()
    self.Min, self.Max, self.Decimals = 0, 100, 0
    self.Value = 0
    self.Dragging = false
    self.ShowValue = true
    self:SetCursor("hand")
end

function PANEL:SetRange(minimum, maximum)
    self.Min, self.Max = minimum, maximum
    self.Value = math.Clamp(self.Value, minimum, maximum)
end

function PANEL:SetDecimals(decimals) self.Decimals = math.max(0, decimals or 0) end

function PANEL:SetValue(value, quiet)
    value = math.Clamp(DFW.Util.Round(value, self.Decimals), self.Min, self.Max)
    if value == self.Value then return end
    self.Value = value
    if not quiet then self:OnValueChanged(value) end
end

function PANEL:GetValue() return self.Value end
function PANEL:OnValueChanged() end
function PANEL:OnValueCommitted() end

function PANEL:TrackBounds()
    local reserved = self.ShowValue and 56 or 0
    return 8, math.max(self:GetWide() - reserved - 8, 20)
end

function PANEL:SetFromCursor()
    local x = self:CursorPos()
    local left, right = self:TrackBounds()
    local fraction = math.Clamp((x - left) / (right - left), 0, 1)
    self:SetValue(self.Min + (self.Max - self.Min) * fraction)
end

function PANEL:EndDrag()
    self.Dragging = false
    self:MouseCapture(false)
    self:OnValueCommitted(self.Value)
end

function PANEL:BeginEdit()
    local _, right = self:TrackBounds()

    if not IsValid(self.Entry) then
        local entry = vgui.Create("DFW.TextEntry", self)
        entry.OnEnter = function(e)
            local typed = tonumber(e:GetValue())
            e:SetVisible(false)
            if typed then
                self:SetValue(typed)
                self:OnValueCommitted(self.Value)
            end
        end
        entry.OnLoseFocus = function(e) e:SetVisible(false) end
        self.Entry = entry
    end

    local entry = self.Entry
    entry:SetPos(right + 4, 1)
    entry:SetSize(self:GetWide() - right - 5, self:GetTall() - 2)
    entry:SetText(string.format("%." .. self.Decimals .. "f", self.Value))
    entry:SetVisible(true)
    entry:RequestFocus()
    entry:SelectAllText()
end

function PANEL:OnMousePressed(code)
    if code ~= MOUSE_LEFT or not self:IsEnabled() then return end

    local _, right = self:TrackBounds()
    if self.ShowValue and self:CursorPos() > right + 4 then self:BeginEdit() return end

    self.Dragging = true
    self:MouseCapture(true)
    self:SetFromCursor()
end

function PANEL:OnMouseReleased()
    if self.Dragging then self:EndDrag() end
end

function PANEL:Think()
    if not self.Dragging then return end
    if input.IsMouseDown(MOUSE_LEFT) then self:SetFromCursor() else self:EndDrag() end
end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local left, right = self:TrackBounds()
    local range = self.Max - self.Min
    local fraction = range > 0 and (self.Value - self.Min) / range or 0
    local display = DFW.Anim.Lerp(self, "fraction", fraction, 22)
    local hover = DFW.Anim.Lerp(self, "hover", (self.Dragging or self:IsHovered()) and 1 or 0, 16)
    local knobX = left + (right - left) * display

    draw.RoundedBox(3, left, h / 2 - 3, right - left, 6, theme.raised)
    draw.RoundedBox(3, left, h / 2 - 3, math.max(knobX - left, 0), 6, UI.WithAlpha(theme.accent, 200))
    draw.RoundedBox(8, knobX - 8, h / 2 - 8, 16, 16, DFW.Anim.Color(theme.text, theme.accentHover, hover))

    if self.ShowValue then
        local text = string.format("%." .. self.Decimals .. "f", self.Value)
        DFW.Draw.Text(text, "BodyBold", w - 2, h / 2, theme.text, TEXT_ALIGN_RIGHT)
    end
end

vgui.Register("DFW.Slider", PANEL, "Panel")
