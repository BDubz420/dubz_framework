local UI = DFW.UI

local styleColors = {
    title = "text", heading = "text", body = "text", bodybold = "text",
    muted = "textMuted", small = "textMuted", tiny = "textDim"
}
local styleFonts = {
    title = "Title", heading = "Heading", body = "Body", bodybold = "BodyBold",
    muted = "Body", small = "Small", tiny = "Tiny"
}

---------------------------------------------------------------------------
-- Card: plain rounded surface (SetAccent is accepted for old callers but draws nothing).
---------------------------------------------------------------------------
local PANEL = {}

function PANEL:Init()
    self.Accent = nil
    self.AccentWidth = 4
    self.Shadowed = false
    self.CardColor = nil
end

function PANEL:SetAccent(color) self.Accent = color end
function PANEL:SetShadow(enabled) self.Shadowed = enabled == true end
function PANEL:SetCardColor(color) self.CardColor = color end

function PANEL:Paint(w, h)
    DFW.Draw.Card(0, 0, w, h, {
        radius = "MD",
        color = self.CardColor or UI.GetTheme().surface,
        accent = self.Accent,
        accentWidth = self.Accent and self.AccentWidth or 0,
        shadow = self.Shadowed
    })
end

vgui.Register("DFW.Card", PANEL, "Panel")

---------------------------------------------------------------------------
-- Label: single line of text. Styles: title, heading, body, bodybold, muted, small, tiny.
---------------------------------------------------------------------------
PANEL = {}

function PANEL:Init()
    self.Text = ""
    self.Style = "body"
    self.Color = nil
    self.Align = TEXT_ALIGN_LEFT
end

function PANEL:SetText(text) self.Text = tostring(text or "") end
function PANEL:GetText() return self.Text end
function PANEL:SetStyle(style) self.Style = styleFonts[style] and style or "body" end
function PANEL:SetColor(color) self.Color = color end
function PANEL:SetAlign(align) self.Align = align end

function PANEL:SizeToContents()
    local width, height = UI.TextSize(self.Text, styleFonts[self.Style])
    self:SetSize(width + 2, height + 2)
end

function PANEL:Paint(w, h)
    local color = self.Color or UI.GetTheme()[styleColors[self.Style]]
    local x = self.Align == TEXT_ALIGN_CENTER and w / 2 or (self.Align == TEXT_ALIGN_RIGHT and w or 0)
    DFW.Draw.Text(self.Text, styleFonts[self.Style], x, h / 2, color, self.Align)
end

vgui.Register("DFW.Label", PANEL, "Panel")

---------------------------------------------------------------------------
-- Paragraph: word-wrapped text that sets its own height from its width.
---------------------------------------------------------------------------
PANEL = {}

function PANEL:Init()
    self.Text = ""
    self.Style = "muted"
    self.Color = nil
    self.Lines = {}
    self.LineHeight = 18
    self.LaidOutWidth = nil
end

function PANEL:SetText(text)
    self.Text = tostring(text or "")
    self.LaidOutWidth = nil
    self:InvalidateLayout()
end

function PANEL:SetStyle(style)
    self.Style = styleFonts[style] and style or "muted"
    self.LaidOutWidth = nil
    self:InvalidateLayout()
end

function PANEL:SetColor(color) self.Color = color end

function PANEL:PerformLayout(w)
    if w <= 0 or self.LaidOutWidth == w then return end
    self.LaidOutWidth = w

    local font = styleFonts[self.Style]
    self.Lines = UI.WrapText(self.Text, font, w)
    local _, textHeight = UI.TextSize("Ag", font)
    self.LineHeight = textHeight + 3

    local wanted = math.max(#self.Lines, 1) * self.LineHeight
    if self:GetTall() ~= wanted then
        self:SetTall(wanted)
        self:InvalidateParent()
    end
end

function PANEL:Paint()
    local color = self.Color or UI.GetTheme()[styleColors[self.Style]]
    for index, line in ipairs(self.Lines) do
        DFW.Draw.Text(line, styleFonts[self.Style], 0, (index - 0.5) * self.LineHeight, color)
    end
end

vgui.Register("DFW.Paragraph", PANEL, "Panel")

---------------------------------------------------------------------------
-- Badge: small status pill. Kinds: accent, success, danger, warning, info, muted.
---------------------------------------------------------------------------
PANEL = {}

function PANEL:Init()
    self.Text = ""
    self.Kind = "muted"
end

function PANEL:SetText(text) self.Text = tostring(text or "") end
function PANEL:SetKind(kind) self.Kind = kind or "muted" end

function PANEL:SizeToContents()
    self:SetSize(UI.TextSize(self.Text, "Tiny") + 18, 20)
end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local color = self.Kind == "muted" and theme.textMuted or (theme[self.Kind] or theme.accent)
    draw.RoundedBox(h / 2, 0, 0, w, h, UI.WithAlpha(color, 38))
    DFW.Draw.Text(string.upper(self.Text), "Tiny", w / 2, h / 2, color, TEXT_ALIGN_CENTER)
end

vgui.Register("DFW.Badge", PANEL, "Panel")

---------------------------------------------------------------------------
-- ProgressBar: SetFraction(0..1), optional label drawn on the bar.
---------------------------------------------------------------------------
PANEL = {}

function PANEL:Init()
    self.Fraction = 0
    self.Label = nil
    self.BarColor = nil
end

function PANEL:SetFraction(fraction) self.Fraction = math.Clamp(tonumber(fraction) or 0, 0, 1) end
function PANEL:SetLabel(text) self.Label = text and tostring(text) or nil end
function PANEL:SetBarColor(color) self.BarColor = color end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local fraction = DFW.Anim.Lerp(self, "fraction", self.Fraction, 12)
    draw.RoundedBox(h / 2, 0, 0, w, h, theme.surfaceAlt)
    if fraction > 0 then
        draw.RoundedBox(h / 2, 0, 0, math.max(w * fraction, h), h, self.BarColor or theme.accent)
    end
    if self.Label then DFW.Draw.Text(self.Label, "Tiny", w / 2, h / 2, theme.text, TEXT_ALIGN_CENTER) end
end

vgui.Register("DFW.ProgressBar", PANEL, "Panel")

---------------------------------------------------------------------------
-- NavButton: sidebar row with icon chip, label, optional badge text.
---------------------------------------------------------------------------
PANEL = {}

function PANEL:Init()
    self:SetText("")
    self:SetCursor("hand")
    self.Label = ""
    self.Icon = nil
    self.Active = false
    self.BadgeText = nil
end

function PANEL:SetLabel(text) self.Label = tostring(text or "") end
function PANEL:SetIcon(key) self.Icon = key end
function PANEL:SetActive(active) self.Active = active == true end
function PANEL:SetBadge(text) self.BadgeText = text and tostring(text) or nil end

function PANEL:OnCursorEntered()
    if UI.HoverSoundAllowed(self) then surface.PlaySound("ui/buttonrollover.wav") end
end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local radius = UI.Radius("MD")
    local hover = DFW.Anim.Lerp(self, "hover", self:IsHovered() and 1 or 0, 16)
    local active = DFW.Anim.Lerp(self, "active", self.Active and 1 or 0, 14)

    draw.RoundedBox(radius, 0, 0, w, h, theme.surface)
    local tint = math.max(active * 36, hover * 18)
    if tint > 0.5 then draw.RoundedBox(radius, 0, 0, w, h, UI.WithAlpha(theme.text, tint)) end

    local chipSize = h - 12
    DFW.Draw.IconChip(self.Icon or "navigation/menu", 8, 6, chipSize, color_white)
    DFW.Draw.Text(self.Label, active > 0.5 and "BodyBold" or "Body", 8 + chipSize + 10, h / 2, DFW.Anim.Color(theme.textMuted, theme.text, math.max(active, hover)))

    if self.BadgeText then
        local width = UI.TextSize(self.BadgeText, "Tiny") + 14
        draw.RoundedBox(9, w - width - 8, h / 2 - 9, width, 18, UI.WithAlpha(theme.text, 30))
        DFW.Draw.Text(self.BadgeText, "Tiny", w - 8 - width / 2, h / 2, theme.text, TEXT_ALIGN_CENTER)
    end
end

vgui.Register("DFW.NavButton", PANEL, "DButton")

---------------------------------------------------------------------------
-- TabBar: horizontal strip. AddTab(id, label, icon), SetActive(id), OnTabChanged(id).
---------------------------------------------------------------------------
PANEL = {}

function PANEL:Init()
    self.Tabs = {}
    self.ActiveId = nil
end

function PANEL:OnTabChanged() end

function PANEL:AddTab(id, label, icon)
    local button = vgui.Create("DFW.Button", self)
    button:SetVariant("ghost")
    button:SetLabel(label)
    if icon then button:SetIcon(icon) end
    button.DoClick = function() self:SetActive(id) end
    self.Tabs[#self.Tabs + 1] = {id = id, button = button}
    if not self.ActiveId then self:SetActive(id, true) end
    self:InvalidateLayout()
    return button
end

function PANEL:SetActive(id, quiet)
    if self.ActiveId == id then return end
    self.ActiveId = id
    for _, tab in ipairs(self.Tabs) do tab.button:SetActive(tab.id == id) end
    if not quiet then self:OnTabChanged(id) end
end

function PANEL:GetActive() return self.ActiveId end

function PANEL:PerformLayout(_, h)
    local x = 0
    for _, tab in ipairs(self.Tabs) do
        tab.button:SizeToLabel(28)
        tab.button:SetTall(h - 4)
        tab.button:SetPos(x, 0)
        x = x + tab.button:GetWide() + 4
    end
end

function PANEL:Paint(w, h)
    surface.SetDrawColor(UI.GetTheme().borderSoft)
    surface.DrawRect(0, h - 1, w, 1)
end

vgui.Register("DFW.TabBar", PANEL, "Panel")
