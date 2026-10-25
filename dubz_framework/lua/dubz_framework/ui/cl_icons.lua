DFW.Icons = DFW.Icons or {cache = {}}

function DFW.Icons.Path(key)
    if not isstring(key) or key == "" or string.find(key, "..", 1, true) then return nil end
    return "dubz_framework/icons/" .. string.Trim(string.lower(key), "/") .. ".png"
end

function DFW.Icons.Get(key, flags)
    local path = DFW.Icons.Path(key)
    if not path then return nil end
    local cacheKey = path .. (flags or "smooth mips")
    if DFW.Icons.cache[cacheKey] == nil then
        local material = Material(path, flags or "smooth mips")
        DFW.Icons.cache[cacheKey] = (material and not material:IsError()) and material or false
    end
    return DFW.Icons.cache[cacheKey] or nil
end

function DFW.Icons.Exists(key)
    return DFW.Icons.Get(key) ~= nil
end

function DFW.Icons.Draw(key, x, y, w, h, color)
    local material = DFW.Icons.Get(key)
    if not material then return end
    surface.SetMaterial(material)
    surface.SetDrawColor(color or color_white)
    surface.DrawTexturedRect(x, y, w, h)
end
