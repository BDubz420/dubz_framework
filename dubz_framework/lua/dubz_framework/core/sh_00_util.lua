DFW.Util = DFW.Util or {}
local Util = DFW.Util

local prefixColor = Color(190, 86, 82)
local warnColor = Color(238, 146, 80)

function Util.IsIdentifier(value)
    return isstring(value) and #value <= 64 and string.match(value, "^[a-z][a-z0-9_]*$") ~= nil
end

function Util.Copy(value)
    if istable(value) then return table.Copy(value) end
    return value
end

-- Server: runs "stopsound" on every player. Looping or already playing sounds keep going after a sound setting
-- is switched off, so call this when an admin turns one off to make it take effect cleanly.
function Util.StopAllSounds()
    if not SERVER then return end
    for _, ply in ipairs(player.GetAll()) do ply:ConCommand("stopsound") end
end

function Util.Log(message)
    MsgC(prefixColor, "[Dubz Framework] ", color_white, tostring(message) .. "\n")
end

function Util.Warn(message)
    if Util.Muted then return end
    MsgC(warnColor, "[Dubz Framework] WARNING: ", color_white, tostring(message) .. "\n")
end

function Util.Debug(message)
    if not DFW.DebugEnabled then return end
    MsgC(prefixColor, "[Dubz Framework] ", Color(150, 150, 160), "[debug] " .. tostring(message) .. "\n")
end

-- Runs fn under pcall and logs failures with a label. Returns ok followed by the results.
function Util.SafeCall(label, fn, ...)
    if not isfunction(fn) then return false, "not_a_function" end
    local results = {pcall(fn, ...)}
    if not results[1] then
        Util.Warn(tostring(label) .. " failed: " .. tostring(results[2]))
    end
    return unpack(results)
end

function Util.DeepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for key, value in pairs(a) do
        if not Util.DeepEqual(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

function Util.Round(value, decimals)
    decimals = math.max(0, math.floor(tonumber(decimals) or 0))
    local power = 10 ^ decimals
    return math.floor(value * power + 0.5) / power
end

function Util.IsFiniteNumber(value)
    return isnumber(value) and value == value and value ~= math.huge and value ~= -math.huge
end

function Util.SortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

-- Colour tables are stored as plain {r,g,b,a} so they survive JSON and never carry metatables.
function Util.ColorToTable(color)
    color = color or {}
    return {
        r = math.Clamp(math.floor(tonumber(color.r) or 255), 0, 255),
        g = math.Clamp(math.floor(tonumber(color.g) or 255), 0, 255),
        b = math.Clamp(math.floor(tonumber(color.b) or 255), 0, 255),
        a = math.Clamp(math.floor(tonumber(color.a) or 255), 0, 255)
    }
end

function Util.TableToColor(tbl)
    tbl = Util.ColorToTable(tbl)
    return Color(tbl.r, tbl.g, tbl.b, tbl.a)
end

function Util.TrimString(value, maxLength)
    value = tostring(value or "")
    if maxLength and #value > maxLength then value = string.sub(value, 1, maxLength) end
    return value
end
