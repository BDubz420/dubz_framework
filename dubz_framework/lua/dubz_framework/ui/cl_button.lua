local UI = DFW.UI

local PANEL = {}

function PANEL:Init()
    self:SetText("")
    self:SetCursor("hand")
    self.Label = ""
    self.Icon = nil
    self.Variant = "default"
    self.Accent = nil
    self.Active = false
    self.TextAlign = TEXT_ALIGN_CENTER
end

function PANEL:SetLabel(value) self.Label = tostring(value or "") end
function PANEL:GetLabel() return self.Label end
function PANEL:SetIcon(value) self.Icon = value end
function PANEL:SetVariant(value) self.Variant = value or "default" end
function PANEL:SetDanger(value) self.Variant = value and "danger" or "default" end
function PANEL:SetPrimary(value) self.Variant = value and "primary" or "default" end
function PANEL:SetAccent(color) self.Accent = color end
function PANEL:SetActive(value) self.Active = value == true end
function PANEL:SetTextAlign(align) self.TextAlign = align end

function PANEL:SizeToLabel(padding)
    local width = UI.TextSize(self.Label, "Button")
    self:SetWide(width + (self.Icon and 24 or 0) + (padding or 32))
end

function PANEL:OnCursorEntered()
    if self:IsEnabled() and UI.HoverSoundAllowed(self) then
        surface.PlaySound("ui/buttonrollover.wav")
    end
end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local enabled = self:IsEnabled()
    local hover = DFW.Anim.Lerp(self, "hover", (enabled and self:IsHovered()) and 1 or 0, 16)
    local pressed = enabled and self:IsDown()
    local accent = self.Accent or theme.accent
    local radius = UI.Radius("SM")
    local variant = self.Variant
    local offset = pressed and 1 or 0

    local background, foreground, iconColor = theme.surfaceAlt, theme.text, theme.text
    local overlay

    if variant == "primary" then
        background = DFW.Anim.Color(accent, theme.accentHover, hover)
        foreground, iconColor = theme.onAccent, theme.onAccent
    elseif variant == "danger" then
        background = DFW.Anim.Color(theme.surfaceAlt, theme.danger, hover * 0.8)
        foreground = DFW.Anim.Color(theme.text, theme.onAccent, hover)
        iconColor = DFW.Anim.Color(theme.danger, theme.onAccent, hover)
    elseif variant == "ghost" then
        background = Color(0, 0, 0, 0)
        foreground = DFW.Anim.Color(theme.textMuted, theme.text, hover)
        iconColor = foreground
        overlay = UI.WithAlpha(theme.raised, hover * 230)
    else
        overlay = UI.WithAlpha(theme.text, 8 + hover * 28)
    end

    if self.Active then
        overlay = UI.WithAlpha(theme.text, 36)
        foreground = theme.text
    end

    if not enabled then
        foreground, iconColor = theme.textDim, theme.textDim
        overlay = nil
        if variant == "primary" then background = theme.surfaceAlt end
    end

    if background.a > 0 then draw.RoundedBox(radius, 0, offset, w, h - 1, background) end
    if overlay then draw.RoundedBox(radius, 0, offset, w, h - 1, overlay) end

    local iconSize = math.min(16, h - 12)
    local labelWidth = self.Label ~= "" and UI.TextSize(self.Label, "Button") or 0
    local groupWidth = labelWidth + (self.Icon and (iconSize + (labelWidth > 0 and 8 or 0)) or 0)
    local x = self.TextAlign == TEXT_ALIGN_LEFT and 12 or (w - groupWidth) / 2
    local centerY = h / 2 - 0.5 + offset

    if self.Icon then
        DFW.Icons.Draw(self.Icon, x, centerY - iconSize / 2, iconSize, iconSize, iconColor)
        x = x + iconSize + (labelWidth > 0 and 8 or 0)
    end
    if self.Label ~= "" then
        DFW.Draw.Text(self.Label, "Button", x, centerY, foreground)
    end
end

vgui.Register("DFW.Button", PANEL, "DButton")
