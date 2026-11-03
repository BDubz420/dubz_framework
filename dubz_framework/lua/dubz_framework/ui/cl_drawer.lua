local UI = DFW.UI
local Anim = DFW.Anim

local SIDES = {left = true, right = true, top = true, bottom = true}
local OPEN_DIM_SECONDS = 0.35
local CLOSE_DIM_SECONDS = 0.25

local PANEL = {}

function PANEL:Init()
    self.Side = "right"
    self.Share = 0.42
    self.DimAlpha = 110
    self.DimColor = Color(0, 0, 0, 0)
    self.CloseOnScrim = true
    self.CustomColor = nil
    self.Opened = false
    self.LastW, self.LastH = -1, -1

    self:SetVisible(false)
    self:SetMouseInputEnabled(true)
    Anim.Set(self, "dim", 0)

    self.Card = vgui.Create("DFW.Card", self)
    self.Card:SetVisible(false)
    self.Card:DockPadding(UI.Space("LG"), UI.Space("LG"), UI.Space("LG"), UI.Space("LG"))

    self.Content = vgui.Create("Panel", self.Card)
    self.Content:Dock(FILL)

    self.CloseButton = vgui.Create("DFW.CloseButton", self.Card)
    self.CloseButton:SetTarget(self)
    self.CloseButton:AnchorTopRight(UI.Space("MD"), UI.Space("MD"))
end

function PANEL:SetSide(side)
    if not SIDES[side] then return end

    self.Side = side
    self.LastW = -1
end

function PANEL:SetShare(fraction)
    self.Share = math.Clamp(tonumber(fraction) or 0.42, 0.1, 1)
    self.LastW = -1
end

function PANEL:SetDimAlpha(alpha) self.DimAlpha = math.Clamp(tonumber(alpha) or 0, 0, 255) end
function PANEL:SetCloseOnScrim(enabled) self.CloseOnScrim = enabled == true end
function PANEL:SetShowClose(enabled) self.CloseButton:SetVisible(enabled == true) end
function PANEL:SetCardColor(color) self.CustomColor = color end
function PANEL:GetCard() return self.Card end
function PANEL:GetContent() return self.Content end
function PANEL:Clear() self.Content:Clear() end
function PANEL:IsOpen() return self.Opened end

function PANEL:Sync()
    local parent = self:GetParent()
    if not IsValid(parent) then return end

    local w, h = parent:GetSize()
    if w == self.LastW and h == self.LastH then return end

    self.LastW, self.LastH = w, h
    self:SetPos(0, 0)
    self:SetSize(w, h)

    if self.Side == "left" or self.Side == "right" then
        self.Card:SetSize(math.floor(w * self.Share), h)
    else
        self.Card:SetSize(w, math.floor(h * self.Share))
    end

    Anim.PlaceDrawer(self.Card, self.Side)
end

function PANEL:Think()
    self:Sync()
end

function PANEL:OnOpening() end
function PANEL:OnOpened() end
function PANEL:OnClosing() end
function PANEL:OnClosed() end

function PANEL:Open()
    if self.Opened or not IsValid(self:GetParent()) then return end

    self.Opened = true
    self.LastW = -1
    self.Card:SetCardColor(self.CustomColor or UI.GetTheme().background)
    self:SetVisible(true)
    self:MoveToFront()
    self:Sync()
    self:OnOpening()

    Anim.Number(self, "dim", 1, OPEN_DIM_SECONDS)
    Anim.OpenDrawer(self.Card, self.Side, {finish = function()
        if IsValid(self) then self:OnOpened() end
    end})
end

function PANEL:Close()
    if not self.Opened then return end

    self.Opened = false
    self:OnClosing()

    Anim.Number(self, "dim", 0, CLOSE_DIM_SECONDS)
    Anim.CloseDrawer(self.Card, self.Side, {finish = function()
        if not IsValid(self) or self.Opened then return end

        self:SetVisible(false)
        self:OnClosed()
    end})
end

function PANEL:Toggle()
    if self.Opened then self:Close() else self:Open() end
end

function PANEL:Swap()
    Anim.FadeIn(self.Content, {duration = "fast"})
end

function PANEL:OnMousePressed()
    if self.CloseOnScrim and self.Opened then self:Close() end
end

function PANEL:Paint(w, h)
    local amount = Anim.Get(self, "dim", 0)
    if amount <= 0.01 or self.DimAlpha <= 0 then return end

    self.DimColor.a = self.DimAlpha * amount
    draw.RoundedBox(UI.Radius("MD"), 0, 0, w, h, self.DimColor)
end

vgui.Register("DFW.Drawer", PANEL, "Panel")
