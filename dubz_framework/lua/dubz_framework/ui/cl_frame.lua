local UI = DFW.UI

local PANEL = {}

function PANEL:Init()
    if not IsValid(self.btnClose) then self.BaseClass.Init(self) end

    self.Title = "Dubz Framework"
    self.Subtitle = nil
    self.IconKey = nil
    self.HeaderHeight = 40
    self.CloseOnEscape = true
    self.Dragging = nil

    self:ShowCloseButton(true)
    self:SetDraggable(false)
    if self.SetPaintShadow then self:SetPaintShadow(false) end
    if IsValid(self.lblTitle) then self.lblTitle:SetVisible(false) end

    self:SetAlpha(0)
    self:AlphaTo(255, 0.14, 0)
    self:DockPadding(12, self.HeaderHeight + 10, 12, 12)

    self.Content = vgui.Create("Panel", self)
    self.Content:Dock(FILL)
end

function PANEL:SetTitle(title) self.Title = tostring(title or "") end
function PANEL:SetSubtitle(text) self.Subtitle = text and tostring(text) or nil end
function PANEL:SetIcon(key) self.IconKey = key end
function PANEL:GetContent() return self.Content end

function PANEL:SetCompact(compact)
    self.Compact = compact == true
    self.HeaderHeight = self.Compact and 24 or 40
    if self.Compact then
        self:DockPadding(5, 29, 5, 5)
        self.Content:DockMargin(0, 0, 0, 0)
    else
        self:DockPadding(12, self.HeaderHeight + 10, 12, 12)
    end
end

function PANEL:OnClose() end

function PANEL:Close()
    if self:OnClose() == false then return end
    if IsValid(self) then self:Remove() end
end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    local radius = UI.Radius("LG")

    if self.Compact then radius = 8 end

    draw.RoundedBox(radius, 0, 0, w, h, theme.background)
    draw.RoundedBoxEx(radius, 0, 0, w, self.HeaderHeight, theme.surface, true, true, false, false)

    if self.Compact then
        DFW.Draw.Text(self.Title, "Small", 8, self.HeaderHeight / 2, theme.text)
        return
    end

    local textX = 18
    if self.IconKey then
        DFW.Draw.IconChip(self.IconKey, 12, (self.HeaderHeight - 26) / 2, 26, color_white)
        textX = 46
    end

    if self.Subtitle then
        DFW.Draw.Text(self.Title, "Heading", textX, self.HeaderHeight / 2 - 7, theme.text)
        DFW.Draw.Text(self.Subtitle, "Small", textX, self.HeaderHeight / 2 + 11, theme.textMuted)
    else
        DFW.Draw.Text(self.Title, "Heading", textX, self.HeaderHeight / 2, theme.text)
    end
end

function PANEL:OnMousePressed(code)
    if code ~= MOUSE_LEFT then return end
    local _, cursorY = self:CursorPos()
    if cursorY <= self.HeaderHeight then
        local x, y = self:GetPos()
        self.Dragging = {gui.MouseX() - x, gui.MouseY() - y}
        self:MouseCapture(true)
    end
end

function PANEL:OnMouseReleased()
    self.Dragging = nil
    self:MouseCapture(false)
end

function PANEL:Think()
    if not self.Dragging then return end
    if not input.IsMouseDown(MOUSE_LEFT) then
        self.Dragging = nil
        self:MouseCapture(false)
        return
    end
    local x = math.Clamp(gui.MouseX() - self.Dragging[1], 120 - self:GetWide(), ScrW() - 120)
    local y = math.Clamp(gui.MouseY() - self.Dragging[2], 0, ScrH() - self.HeaderHeight)
    self:SetPos(x, y)
end

function PANEL:OnKeyCodePressed(key)
    if key == KEY_ESCAPE and self.CloseOnEscape then self:Close() end
end

vgui.Register("DFW.Frame", PANEL, "DFrame")

function UI.HoverSoundAllowed(panel)
    if not DFW.Config.Get("dubz_core", "ui_sounds", true) then return false end

    local parent = panel
    while IsValid(parent) do
        if parent.DFWModule then return DFW.Config.Get(parent.DFWModule, "hover_sounds", true) ~= false end
        parent = parent:GetParent()
    end

    return true
end

function UI.CreateFrame(title, width, height, iconKey, options)
    local frame = vgui.Create("DFW.Frame")
    frame:SetTitle(title)
    if options and options.module then frame.DFWModule = options.module end
    if options and options.compact then frame:SetCompact(true) end
    if iconKey then frame:SetIcon(iconKey) end
    frame:SetSize(math.min(width, ScrW() - 40), math.min(height, ScrH() - 40))
    frame:Center()
    frame:MakePopup()
    return frame
end
