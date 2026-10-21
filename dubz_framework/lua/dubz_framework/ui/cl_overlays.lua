local UI = DFW.UI

local function createOverlay()
    local overlay = vgui.Create("EditablePanel")
    overlay:SetSize(ScrW(), ScrH())
    overlay:SetPos(0, 0)
    overlay:MakePopup()
    overlay:SetAlpha(0)
    overlay:AlphaTo(255, 0.12, 0)
    overlay.Paint = function(_, w, h)
        surface.SetDrawColor(UI.GetTheme().overlay)
        surface.DrawRect(0, 0, w, h)
    end
    return overlay
end

local function buildModal(title, message, iconKey, extraHeight)
    local overlay = createOverlay()
    local width = 440
    local lines = UI.WrapText(message or "", "Body", width - 56)
    local height = 52 + 12 + #lines * 21 + 12 + (extraHeight or 0) + 44 + 17

    local frame = vgui.Create("DFW.Frame", overlay)
    frame:SetTitle(title)
    frame:SetIcon(iconKey or "admin/warning")
    frame:SetSize(width, height)
    frame:Center()
    frame.OnClose = function() overlay:Remove() end

    local content = frame:GetContent()
    local paragraph = vgui.Create("DFW.Paragraph", content)
    paragraph:Dock(TOP)
    paragraph:SetStyle("body")
    paragraph:SetText(message or "")

    local buttons = vgui.Create("Panel", content)
    buttons:Dock(BOTTOM)
    buttons:SetTall(36)

    return overlay, frame, content, buttons
end

local function addButton(parent, label, variant, callback)
    local button = vgui.Create("DFW.Button", parent)
    button:Dock(RIGHT)
    button:DockMargin(8, 0, 0, 0)
    button:SetLabel(label)
    button:SetVariant(variant)
    button:SizeToLabel(36)
    button.DoClick = callback
    return button
end

function UI.Confirm(title, message, onConfirm, options)
    options = options or {}
    local _, frame, _, buttons = buildModal(title, message, options.icon)

    addButton(buttons, options.confirmLabel or "Confirm", options.danger and "danger" or "primary", function()
        frame:Close()
        if onConfirm then onConfirm() end
    end)
    addButton(buttons, options.cancelLabel or "Cancel", "default", function()
        frame:Close()
        if options.onCancel then options.onCancel() end
    end)
    return frame
end

function UI.Message(title, message, onClose, iconKey)
    local _, frame, _, buttons = buildModal(title, message, iconKey or "communication/notifications")
    addButton(buttons, "OK", "primary", function()
        frame:Close()
        if onClose then onClose() end
    end)
    return frame
end

function UI.Prompt(title, message, default, onSubmit, options)
    options = options or {}
    local _, frame, content, buttons = buildModal(title, message, options.icon or "actions/edit_square", 44)

    local entry = vgui.Create("DFW.TextEntry", content)
    entry:Dock(TOP)
    entry:DockMargin(0, 8, 0, 0)
    entry:SetTall(32)
    entry:SetText(default or "")
    entry:SetPlaceholder(options.placeholder or "")
    entry:RequestFocus()

    local function submit()
        local value = entry:GetValue()
        frame:Close()
        if onSubmit then onSubmit(value) end
    end

    entry.OnEnter = submit
    addButton(buttons, options.confirmLabel or "OK", "primary", submit)
    addButton(buttons, "Cancel", "default", function() frame:Close() end)
    return frame
end

UI.Toasts = UI.Toasts or {}
local MAX_TOASTS = 5

local function relayoutToasts()
    local live = {}
    for _, toast in ipairs(UI.Toasts) do
        if IsValid(toast) then live[#live + 1] = toast end
    end
    UI.Toasts = live

    local y = 16
    for _, toast in ipairs(UI.Toasts) do
        toast.TargetY = y
        y = y + toast:GetTall() + 8
    end
end

function UI.Notify(text, kind, duration)
    kind = kind or "info"
    duration = duration or 3.5

    while #UI.Toasts >= MAX_TOASTS do
        local oldest = table.remove(UI.Toasts, 1)
        if IsValid(oldest) then oldest:Remove() end
    end

    local width = 330
    local lines = UI.WrapText(text, "Small", width - 44)
    local height = math.max(40, 18 + #lines * 16)

    local toast = vgui.Create("EditablePanel")
    toast:SetSize(width, height)
    toast:SetMouseInputEnabled(false)
    toast:SetKeyboardInputEnabled(false)
    toast:SetPos(ScrW() + 10, 16)
    toast:SetZPos(32000)

    toast.Born = SysTime()
    toast.Duration = duration
    toast.Kind = kind
    toast.Lines = lines
    toast.TargetY = 16

    toast.OnRemove = function() timer.Simple(0, relayoutToasts) end

    toast.Think = function(self)
        local age = SysTime() - self.Born
        local x, y = self:GetPos()
        local targetX = ScrW() - width - 16
        local speed = math.min(FrameTime() * 12, 1)
        self:SetPos(Lerp(speed, x, targetX), Lerp(speed, y, self.TargetY))

        local remaining = self.Duration - age
        if remaining < 0.35 then self:SetAlpha(math.Clamp(remaining / 0.35, 0, 1) * 255) end
        if remaining <= 0 then self:Remove() end
    end

    toast.Paint = function(self, w, h)
        local theme = UI.GetTheme()
        local color = theme[self.Kind] or theme.info
        DFW.Draw.Card(0, 0, w, h, {radius = "MD", color = theme.background})
        for index, line in ipairs(self.Lines) do
            DFW.Draw.Text(line, "Small", 14, 10 + (index - 0.5) * 16, index == 1 and color or theme.text)
        end
    end

    UI.Toasts[#UI.Toasts + 1] = toast
    relayoutToasts()
    return toast
end
