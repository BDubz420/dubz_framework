local Anim = DFW.Anim

local DRAWER_OPEN_SECONDS = 0.45
local DRAWER_CLOSE_SECONDS = 0.32

local function setAlpha(panel, value) panel:SetAlpha(value) end

local function setHeight(panel, value)
    panel:SetTall(value)
    panel:InvalidateParent()
end

local function entryOffset(side, distance)
    if side == "left" then return -distance, 0 end
    if side == "right" then return distance, 0 end
    if side == "top" then return 0, -distance end
    return 0, distance
end

local function restPosition(panel)
    if Anim.IsRunning(panel, "pos") and panel.DFWRestX then return panel.DFWRestX, panel.DFWRestY end

    local x, y = panel:GetPos()
    panel.DFWRestX, panel.DFWRestY = x, y
    return x, y
end

function Anim.FadeIn(panel, options)
    if not IsValid(panel) then return end

    options = options or {}
    local target = options.to or 255
    if Anim.Target(panel, "alpha") == target then return end

    panel:SetVisible(true)
    Anim.Tween(panel, "alpha", options.from or 0, target, options.duration, setAlpha, {
        delay = options.delay, ease = options.ease or "outQuad", finish = options.finish
    })
end

function Anim.FadeOut(panel, options)
    if not IsValid(panel) then return end

    options = options or {}
    local target = options.to or 0
    if Anim.Target(panel, "alpha") == target then return end

    local finish = options.finish

    Anim.Tween(panel, "alpha", panel:GetAlpha(), target, options.duration, setAlpha, {
        delay = options.delay, ease = options.ease or "outQuad",
        finish = function(p)
            if options.remove then p:Remove() return end
            if options.hide then
                p:SetVisible(false)
                p:SetAlpha(255)
            end
            if finish then finish(p) end
        end
    })
end

function Anim.SlideTo(panel, x, y, options)
    if not IsValid(panel) then return end

    options = options or {}
    local fromX, fromY = panel:GetPos()

    Anim.Tween(panel, "pos", 0, 1, options.duration, function(p, fraction)
        p:SetPos(math.floor(fromX + (x - fromX) * fraction + 0.5), math.floor(fromY + (y - fromY) * fraction + 0.5))
    end, {delay = options.delay, ease = options.ease or "outCubic", finish = options.finish})
end

function Anim.SlideIn(panel, side, options)
    if not IsValid(panel) then return end

    options = options or {}
    local x, y = restPosition(panel)
    local offsetX, offsetY = entryOffset(side, options.distance or 32)

    panel:SetVisible(true)
    panel:SetPos(x + offsetX, y + offsetY)
    Anim.SlideTo(panel, x, y, options)

    if options.fade ~= false then
        Anim.Stop(panel, "alpha")
        Anim.FadeIn(panel, {duration = options.duration, delay = options.delay})
    end
end

function Anim.SlideOut(panel, side, options)
    if not IsValid(panel) then return end

    options = options or {}
    local x, y = restPosition(panel)
    local offsetX, offsetY = entryOffset(side, options.distance or 32)
    local finish = options.finish

    Anim.SlideTo(panel, x + offsetX, y + offsetY, {
        duration = options.duration, delay = options.delay, ease = options.ease or "inCubic",
        finish = function(p)
            p:SetPos(x, y)
            if options.remove then p:Remove() return end
            if options.hide ~= false then
                p:SetVisible(false)
                p:SetAlpha(255)
            end
            if finish then finish(p) end
        end
    })

    if options.fade ~= false then
        Anim.Stop(panel, "alpha")
        Anim.FadeOut(panel, {duration = options.duration, delay = options.delay})
    end
end

function Anim.RiseIn(panel, options)
    options = options or {}
    Anim.SlideIn(panel, "bottom", {
        distance = options.distance or 10, duration = options.duration, delay = options.delay,
        ease = options.ease, finish = options.finish
    })
end

function Anim.Stagger(panels, preset, options)
    options = options or {}
    local run = Anim[preset or "FadeIn"]
    if not isfunction(run) or not istable(panels) then return end

    local total = #panels
    local step = math.min(options.step or 0.03, (options.maxTotal or 0.4) / math.max(total, 1))

    for index, panel in ipairs(panels) do
        if IsValid(panel) then
            local each = {
                duration = options.duration, ease = options.ease, distance = options.distance,
                delay = (options.delay or 0) + (index - 1) * step
            }

            if preset == "SlideIn" then run(panel, options.side or "bottom", each) else run(panel, each) end
        end
    end
end

function Anim.Height(panel, target, options)
    if not IsValid(panel) then return end

    options = options or {}
    Anim.Tween(panel, "tall", panel:GetTall(), target, options.duration, setHeight, {
        delay = options.delay, ease = options.ease or "outCubic", finish = options.finish
    })
end

function Anim.Shake(panel, options)
    if not IsValid(panel) then return end

    options = options or {}
    local amplitude = options.amplitude or 6
    local x, y

    if Anim.IsRunning(panel, "shake") then
        x, y = panel.DFWShakeX, panel.DFWShakeY
    else
        x, y = panel:GetPos()
        panel.DFWShakeX, panel.DFWShakeY = x, y
    end

    Anim.Tween(panel, "shake", 0, 1, options.duration or 0.32, function(p, fraction)
        p:SetPos(x + math.floor(math.sin(fraction * math.pi * 8) * amplitude * (1 - fraction) + 0.5), y)
    end, {ease = "linear", finish = function(p) p:SetPos(x, y) end})
end

function Anim.Number(panel, key, target, duration, options)
    if not IsValid(panel) then return end

    options = options or {}
    panel.DFWAnim = panel.DFWAnim or {}

    local from = panel.DFWAnim[key]
    if from == nil then from = options.from or target end

    Anim.Tween(panel, "number:" .. key, from, target, duration, function(p, value)
        p.DFWAnim[key] = value
    end, {delay = options.delay, ease = options.ease or "outCubic", finish = options.finish})
end

function Anim.Get(panel, key, default)
    local values = panel.DFWAnim
    if values and values[key] ~= nil then return values[key] end
    return default
end

local function drawerPositions(panel, side)
    local parent = panel:GetParent()
    local parentWidth, parentHeight = parent:GetSize()
    local width, height = panel:GetSize()
    local x, y = panel:GetPos()

    if side == "left" then return 0, y, -width, y end
    if side == "top" then return x, 0, x, -height end
    if side == "bottom" then return x, parentHeight - height, x, parentHeight end
    return parentWidth - width, y, parentWidth, y
end

function Anim.OpenDrawer(panel, side, options)
    if not IsValid(panel) or not IsValid(panel:GetParent()) then return end

    options = options or {}
    local openX, openY, closedX, closedY = drawerPositions(panel, side)

    if not panel:IsVisible() then
        panel:SetPos(closedX, closedY)
        panel:SetVisible(true)
    end

    panel.DFWDrawerOpen = true
    Anim.SlideTo(panel, openX, openY, {duration = options.duration or DRAWER_OPEN_SECONDS, ease = options.ease or "drawer", finish = options.finish})
end

function Anim.CloseDrawer(panel, side, options)
    if not IsValid(panel) or not IsValid(panel:GetParent()) then return end

    options = options or {}
    local _, _, closedX, closedY = drawerPositions(panel, side)
    local finish = options.finish

    panel.DFWDrawerOpen = false

    Anim.SlideTo(panel, closedX, closedY, {
        duration = options.duration or DRAWER_CLOSE_SECONDS, ease = options.ease or "smooth",
        finish = function(p)
            if not p.DFWDrawerOpen then p:SetVisible(false) end
            if finish then finish(p) end
        end
    })
end

function Anim.IsDrawerOpen(panel)
    return IsValid(panel) and panel.DFWDrawerOpen == true
end

function Anim.PlaceDrawer(panel, side)
    if not IsValid(panel) or not IsValid(panel:GetParent()) then return end

    local openX, openY, closedX, closedY = drawerPositions(panel, side)

    if panel.DFWDrawerOpen then
        panel:SetPos(openX, openY)
    else
        panel:SetPos(closedX, closedY)
    end
end
