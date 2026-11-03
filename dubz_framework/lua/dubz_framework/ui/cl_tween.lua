DFW.Anim = DFW.Anim or {}

local Anim = DFW.Anim

local HOOK = "DFW.Anim.Drive"
local MIN_DURATION = 0.03
local MAX_DURATION = 3

local active, count, driving = {}, 0, false

Anim.Durations = {fast = 0.12, normal = 0.2, slow = 0.35}

local function bezier(x1, y1, x2, y2)
    local cx = 3 * x1
    local bx = 3 * (x2 - x1) - cx
    local ax = 1 - cx - bx
    local cy = 3 * y1
    local by = 3 * (y2 - y1) - cy
    local ay = 1 - cy - by

    return function(x)
        local t = x

        for _ = 1, 6 do
            local error = ((ax * t + bx) * t + cx) * t - x
            if math.abs(error) < 0.0001 then break end

            local slope = (3 * ax * t + 2 * bx) * t + cx
            if math.abs(slope) < 0.000001 then break end

            t = t - error / slope
        end

        t = math.Clamp(t, 0, 1)

        return ((ay * t + by) * t + cy) * t
    end
end

Anim.Bezier = bezier

Anim.Ease = {
    linear = function(t) return t end,
    inQuad = function(t) return t * t end,
    outQuad = function(t) return 1 - (1 - t) * (1 - t) end,
    inOutQuad = function(t) if t < 0.5 then return 2 * t * t end return 1 - (-2 * t + 2) ^ 2 / 2 end,
    inCubic = function(t) return t * t * t end,
    outCubic = function(t) local u = 1 - t return 1 - u * u * u end,
    inOutCubic = function(t) if t < 0.5 then return 4 * t * t * t end return 1 - (-2 * t + 2) ^ 3 / 2 end,
    outQuart = function(t) local u = 1 - t return 1 - u * u * u * u end,
    outBack = function(t) local u = t - 1 return 1 + 2.1 * u * u * u + 1.1 * u * u end,
    smooth = bezier(0.4, 0, 0.2, 1),
    drawer = bezier(0.32, 0.72, 0, 1)
}

function Anim.Enabled()
    return not (DFW.Config and DFW.Config.Get("dubz_core", "animations", true) == false)
end

function Anim.Speed()
    local speed = DFW.Config and DFW.Config.Get("dubz_core", "animation_speed", 1) or 1
    return math.Clamp(tonumber(speed) or 1, 0.25, 4)
end

function Anim.Duration(value, fallback)
    local seconds = Anim.Durations[value] or tonumber(value) or Anim.Durations[fallback] or fallback or Anim.Durations.normal
    return math.Clamp(seconds, MIN_DURATION, MAX_DURATION) / Anim.Speed()
end

local function guarded(callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok then ErrorNoHalt("[Dubz Framework] animation callback failed: " .. tostring(err) .. "\n") end
    return ok
end

local function unlink(tween)
    local panel = tween.panel
    if IsValid(panel) and panel.DFWTween and panel.DFWTween[tween.key] == tween then
        panel.DFWTween[tween.key] = nil
    end
end

local function drive()
    local now = RealTime()
    local index = 1

    while index <= count do
        local tween = active[index]
        local panel = tween.panel
        local finished, finish = false, false

        if tween.dead or not IsValid(panel) then
            finished = true
        elseif now >= tween.start then
            local fraction = (now - tween.start) / tween.duration

            if fraction >= 1 then
                finished, finish = true, true
                if not guarded(tween.update, panel, tween.to) then finish = false end
            elseif not guarded(tween.update, panel, tween.from + (tween.to - tween.from) * tween.ease(fraction)) then
                finished = true
            end
        end

        if finished then
            unlink(tween)
            active[index] = active[count]
            active[count] = nil
            count = count - 1
            tween.dead = true

            if finish and tween.finish and IsValid(panel) then guarded(tween.finish, panel) end
        else
            index = index + 1
        end
    end

    if count == 0 then
        hook.Remove("Think", HOOK)
        driving = false
    end
end

local function resolveEase(ease)
    if isfunction(ease) then return ease end
    return Anim.Ease[ease] or Anim.Ease.outCubic
end

function Anim.Stop(panel, key, complete)
    local tweens = IsValid(panel) and panel.DFWTween
    local tween = tweens and tweens[key]
    if not tween then return end

    tween.dead = true
    tweens[key] = nil

    if complete then
        guarded(tween.update, panel, tween.to)
        if tween.finish then guarded(tween.finish, panel) end
    end
end

function Anim.StopAll(panel)
    if not IsValid(panel) or not panel.DFWTween then return end

    for key in pairs(panel.DFWTween) do Anim.Stop(panel, key) end
end

function Anim.IsRunning(panel, key)
    return IsValid(panel) and panel.DFWTween ~= nil and panel.DFWTween[key] ~= nil
end

function Anim.Target(panel, key)
    local tween = IsValid(panel) and panel.DFWTween and panel.DFWTween[key]
    return tween and tween.to or nil
end

function Anim.Tween(panel, key, from, to, duration, update, options)
    if not IsValid(panel) or not isfunction(update) then return false end

    options = options or {}
    Anim.Stop(panel, key)

    local seconds = Anim.Duration(duration)
    local delay = math.max(tonumber(options.delay) or 0, 0) / Anim.Speed()

    if not Anim.Enabled() then
        guarded(update, panel, to)
        if options.finish then guarded(options.finish, panel) end
        return true
    end

    guarded(update, panel, from)

    local tween = {
        panel = panel, key = key, from = from, to = to, update = update, finish = options.finish,
        ease = resolveEase(options.ease), duration = seconds, start = RealTime() + delay, dead = false
    }

    panel.DFWTween = panel.DFWTween or {}
    panel.DFWTween[key] = tween

    count = count + 1
    active[count] = tween

    if not driving then
        driving = true
        hook.Add("Think", HOOK, drive)
    end

    return true
end

function Anim.ActiveCount() return count end
