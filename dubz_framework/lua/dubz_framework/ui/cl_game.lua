local UI = DFW.UI

local PANEL = {}

function PANEL:Init()
    self.Level = nil
    self.Fraction = 0
    self.CaptionHeight = 22
    self.BarHeight = 12
    self.TooltipFunc = nil
end

function PANEL:SetLevel(level)
    self.Level = level
    local wanted = self:GetWantedHeight()
    if self:GetTall() ~= wanted then self:SetTall(wanted) end
end
function PANEL:SetFraction(fraction) self.Fraction = math.Clamp(tonumber(fraction) or 0, 0, 1) end
function PANEL:SetTooltipFunc(fn) self.TooltipFunc = fn end

function PANEL:GetWantedHeight()
    return (self.Level ~= nil and self.CaptionHeight or 0) + self.BarHeight + 2
end

function PANEL:OnCursorEntered()
    if self.TooltipFunc then self:SetTooltip(self.TooltipFunc()) end
end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local y = 0

    if self.Level ~= nil then
        DFW.Draw.Text("Level " .. tostring(self.Level), "Heading", w / 2, self.CaptionHeight / 2, theme.text, TEXT_ALIGN_CENTER)
        y = self.CaptionHeight
    end

    local barY = y + 1
    surface.SetDrawColor(theme.track)
    surface.DrawRect(0, barY, w, self.BarHeight)

    local fraction = DFW.Anim.Lerp(self, "fraction", self.Fraction, 10)
    surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 230)
    surface.DrawRect(1, barY + 1, (w - 2) * fraction, self.BarHeight - 2)

    surface.SetDrawColor(theme.outline)
    surface.DrawOutlinedRect(0, barY, w, self.BarHeight)
end

vgui.Register("DFW.XPBar", PANEL, "Panel")

PANEL = {}

local BLOCK, GAP = 14, 3

function PANEL:Init()
    self.Name = ""
    self.MaxLevel = 10
    self.LevelFunc = function() return 0 end
    self.ProgressFunc = function() return 0 end
    self.TooltipFunc = nil
    self:SetTall(24)
end

function PANEL:SetSkill(name, maxLevel, levelFn, progressFn, tooltipFn)
    self.Name = tostring(name or "")
    self.MaxLevel = maxLevel or 10
    self.LevelFunc = levelFn or self.LevelFunc
    self.ProgressFunc = progressFn or self.ProgressFunc
    self.TooltipFunc = tooltipFn
end

function PANEL:OnCursorEntered()
    if self.TooltipFunc then self:SetTooltip(self.TooltipFunc()) end
end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local level = self.LevelFunc()
    local progress = self.ProgressFunc()

    if self:IsHovered() then
        surface.SetDrawColor(theme.text.r, theme.text.g, theme.text.b, 14)
        surface.DrawRect(0, 0, w, h)
    end

    DFW.Draw.Text(self.Name, "Body", 16, h / 2, level > 0 and theme.accent or theme.text)

    local startX = w - self.MaxLevel * (BLOCK + GAP) - 4
    local y = (h - BLOCK) / 2

    for i = 1, self.MaxLevel do
        local x = startX + (i - 1) * (BLOCK + GAP)

        surface.SetDrawColor(theme.track)
        surface.DrawRect(x, y, BLOCK, BLOCK)

        if i <= level then
            surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 230)
            surface.DrawRect(x + 1, y + 1, BLOCK - 2, BLOCK - 2)
        elseif i == level + 1 and progress > 0 then
            surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 140)
            surface.DrawRect(x + 1, y + 1, (BLOCK - 2) * progress, BLOCK - 2)
        end

        surface.SetDrawColor(theme.outline)
        surface.DrawOutlinedRect(x, y, BLOCK, BLOCK)
    end
end

vgui.Register("DFW.SkillBox", PANEL, "Panel")

PANEL = {}

function PANEL:Init()
    self.Text = ""
    self:SetTall(26)
end

function PANEL:SetText(text) self.Text = tostring(text or "") end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    DFW.Draw.Text(self.Text, "Heading", 8, h - 14, theme.text)
    surface.SetDrawColor(theme.text.r, theme.text.g, theme.text.b, 40)
    surface.DrawRect(0, h - 1, w, 1)
end

vgui.Register("DFW.SectionHeader", PANEL, "Panel")
