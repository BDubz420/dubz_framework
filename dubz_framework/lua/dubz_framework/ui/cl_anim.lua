DFW.Anim = DFW.Anim or {}

function DFW.Anim.Lerp(panel, key, target, speed)
    panel.DFWAnim = panel.DFWAnim or {}
    local current = panel.DFWAnim[key]
    if current == nil then current = target end

    current = Lerp(math.min(FrameTime() * (speed or 14), 1), current, target)
    if math.abs(current - target) < 0.002 then current = target end

    panel.DFWAnim[key] = current
    return current
end

function DFW.Anim.Set(panel, key, value)
    panel.DFWAnim = panel.DFWAnim or {}
    panel.DFWAnim[key] = value
end

function DFW.Anim.Color(from, to, fraction)
    fraction = math.Clamp(fraction, 0, 1)
    return Color(
        Lerp(fraction, from.r, to.r),
        Lerp(fraction, from.g, to.g),
        Lerp(fraction, from.b, to.b),
        Lerp(fraction, from.a or 255, to.a or 255)
    )
end
