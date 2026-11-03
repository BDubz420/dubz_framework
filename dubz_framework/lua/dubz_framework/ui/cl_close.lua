local UI = DFW.UI

local PANEL = {}

function PANEL:Init()
    self:SetText("")
    self:SetCursor("hand")
    self:SetSize(28, 28)
    self.IconKey = "navigation/close"
    self.Target = nil
    self.Anchor = nil
end

function PANEL:SetTarget(panel) self.Target = panel end
function PANEL:GetTarget() return self.Target end
function PANEL:SetIcon(key) self.IconKey = key end

function PANEL:ResolveTarget()
    if IsValid(self.Target) then return self.Target end

    local panel = self:GetParent()
    local top = panel

    while IsValid(panel) do
        if isfunction(panel.Close) then return panel end
        top = panel
        panel = panel:GetParent()
    end

    if IsValid(top) and top ~= vgui.GetWorldPanel() then return top end
end

function PANEL:AnchorTopRight(x, y)
    local parent = self:GetParent()
    if not IsValid(parent) then return end

    self.Anchor = {x = x or 8, y = y or 8}
    self:Reposition()

    if parent.DFWCloseAnchored then
        parent.DFWCloseButton = self
        return
    end

    parent.DFWCloseAnchored = true
    parent.DFWCloseButton = self

    local base = parent.PerformLayout
    parent.PerformLayout = function(panel, w, h)
        if base then base(panel, w, h) end
        if IsValid(panel.DFWCloseButton) then panel.DFWCloseButton:Reposition() end
    end
end

function PANEL:Reposition()
    local parent = self:GetParent()
    if not self.Anchor or not IsValid(parent) then return end
    self:SetPos(parent:GetWide() - self:GetWide() - self.Anchor.x, self.Anchor.y)
end

function PANEL:OnCursorEntered()
    if self:IsEnabled() and UI.HoverSoundAllowed(self) then
        surface.PlaySound("ui/buttonrollover.wav")
    end
end

function PANEL:DoClick()
    local target = self:ResolveTarget()
    if not IsValid(target) then return end

    if isfunction(target.Close) then
        target:Close()
    else
        target:Remove()
    end
end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local hover = DFW.Anim.Lerp(self, "hover", self:IsHovered() and 1 or 0, 16)
    local offset = self:IsDown() and 1 or 0
    local size = math.floor(math.min(w, h) * 0.5)

    draw.RoundedBox(UI.Radius("SM"), 0, offset, w, h - 1, UI.WithAlpha(theme.danger, hover * 255))

    local color = DFW.Anim.Color(theme.textMuted, theme.onAccent, hover)
    DFW.Icons.Draw(self.IconKey, (w - size) / 2, (h - size) / 2 + offset, size, size, color)
end

vgui.Register("DFW.CloseButton", PANEL, "DButton")

function UI.CreateCloseButton(parent, target, x, y)
    local button = vgui.Create("DFW.CloseButton", parent)
    if target then button:SetTarget(target) end
    button:AnchorTopRight(x, y)
    return button
end
