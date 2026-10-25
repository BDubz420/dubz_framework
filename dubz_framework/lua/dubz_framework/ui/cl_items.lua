local UI = DFW.UI

local PANEL = {}

local FALLBACK_MODEL = "models/props_junk/PopCan01a.mdl"

function PANEL:Init()
    self.SlotIndex = nil
    self.DragGroup = nil
    self.Highlight = false
    self.Item = nil
end

function PANEL:SetSlotIndex(index) self.SlotIndex = index end
function PANEL:SetHighlight(on) self.Highlight = on == true end

function PANEL:SetDragGroup(group)
    self.DragGroup = group
    self:Receiver(group, function(_, dropped, isDropped)
        if not isDropped then return end

        local from = dropped[1] and dropped[1].SlotIndex
        if from and from ~= self.SlotIndex then self:OnDropped(from) end
    end)
end

function PANEL:OnDropped() end
function PANEL:OnClick() end
function PANEL:OnRightClick() end

function PANEL:SetItem(item, tooltip)
    if IsValid(self.Icon) then self.Icon:Remove() end
    self.Icon = nil
    self.Item = item

    if not item then return end

    local model = (item.model and item.model ~= "") and item.model or FALLBACK_MODEL
    local icon

    if item.color or (item.material and item.material ~= "") then
        icon = vgui.Create("DModelPanel", self)
        icon:SetSize(self:GetWide(), self:GetTall())
        icon:SetModel(model)
        icon:SetAmbientLight(Color(170, 170, 170))
        icon:SetDirectionalLight(BOX_TOP, Color(255, 255, 255))
        icon:SetDirectionalLight(BOX_FRONT, Color(210, 210, 210))
        icon:SetFOV(38)

        local entity = icon.Entity
        if IsValid(entity) then
            local mins, maxs = entity:GetRenderBounds()
            local radius = math.max((maxs - mins):Length() / 2, 1)
            local centre = (mins + maxs) / 2
            icon:SetCamPos(centre + Vector(0.55, 0.45, 0.75):GetNormalized() * radius * 2.7)
            icon:SetLookAt(centre)
        end

        local material = item.material or ""
        icon:SetColor(item.color and Color(item.color.r or 255, item.color.g or 255, item.color.b or 255) or color_white)

        icon.LayoutEntity = function(_, ent)
            if material ~= "" then ent:SetMaterial(material) end
        end

        local paint = icon.Paint
        icon.Paint = function(panel, w, h)
            local x, y = panel:LocalToScreen(0, 0)
            render.SetScissorRect(x, y, x + w, y + h, true)
            paint(panel, w, h)
            render.SetScissorRect(0, 0, 0, 0, false)
        end
    else
        icon = vgui.Create("SpawnIcon", self)
        icon:SetSize(self:GetWide(), self:GetTall())
        icon:SetModel(model)
    end

    icon:SetTooltip(tooltip)
    icon.SlotIndex = self.SlotIndex

    if self.DragGroup then
        icon:Droppable(self.DragGroup)
        icon:Receiver(self.DragGroup, function(_, dropped, isDropped)
            if not isDropped then return end

            local from = dropped[1] and dropped[1].SlotIndex
            if from and from ~= self.SlotIndex then self:OnDropped(from) end
        end)
    end

    icon.DoClick = function() self:OnClick() end
    icon.DoRightClick = function() self:OnRightClick() end

    icon.PaintOver = function(_, w, h)
        if (item.qty or 1) > 1 then
            draw.SimpleTextOutlined("x" .. item.qty, UI.Font("Small"), w - 4, h - 3, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black)
        end
    end

    self.Icon = icon
end

function PANEL:PerformLayout(w, h)
    if IsValid(self.Icon) then self.Icon:SetSize(w, h) end
end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    draw.RoundedBox(6, 0, 0, w, h, theme.slot)
    if self.Highlight then draw.RoundedBox(6, 0, 0, w, h, UI.WithAlpha(theme.accent, 60)) end
end

vgui.Register("DFW.ItemSlot", PANEL, "Panel")

PANEL = {}

function PANEL:Init()
    self.Left = ""
    self.Right = ""
    self:SetTall(22)
end

function PANEL:SetLeft(text) self.Left = text end
function PANEL:SetRight(text) self.Right = text end

local function resolve(value)
    if isfunction(value) then return value() end
    return value
end

function PANEL:Paint(w, h)
    local theme = UI.GetTheme()
    DFW.Draw.Text(resolve(self.Left) or "", "Small", 2, h / 2, theme.text)
    DFW.Draw.Text(resolve(self.Right) or "", "Small", w - 2, h / 2, theme.textMuted, TEXT_ALIGN_RIGHT)
end

vgui.Register("DFW.HeaderRow", PANEL, "Panel")

function DFW.Draw.ProgressCard(centerX, y, width, label, fraction)
    local theme = UI.GetTheme()
    local height = 20
    local x = centerX - width / 2

    draw.RoundedBox(8, x - 6, y - 24, width + 12, height + 32, theme.background)
    DFW.Draw.Text(label, "Small", centerX, y - 12, theme.text, TEXT_ALIGN_CENTER)
    draw.RoundedBox(4, x, y, width, height, theme.track)
    draw.RoundedBox(4, x, y, width * math.Clamp(fraction, 0, 1), height, theme.accent)
end
