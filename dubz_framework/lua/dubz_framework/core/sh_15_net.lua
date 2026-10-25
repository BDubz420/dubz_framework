-- Networking helpers: namespaced message names, server-side rate limits and
-- size caps, and compressed JSON payloads. Every Dubz Framework message goes through here.
DFW.Net = DFW.Net or {}
local Net = DFW.Net

local cooldowns = {}
local MAX_JSON_BYTES = 60000

function Net.Name(name)
    return "DFW." .. tostring(name)
end

function Net.Pool(name)
    if SERVER then util.AddNetworkString(Net.Name(name)) end
end

function Net.Start(name)
    net.Start(Net.Name(name))
end

local function limited(ply, name, delay)
    if not delay or delay <= 0 or not IsValid(ply) then return false end
    local key = ply:UserID() .. ":" .. name
    local now = CurTime()
    if (cooldowns[key] or 0) > now then return true end
    cooldowns[key] = now + delay
    return false
end

-- options: maxBits (reject larger messages), cooldown (seconds per player),
-- access (function(ply) -> bool, server only).
function Net.Receive(name, callback, options)
    options = options or {}
    net.Receive(Net.Name(name), function(length, ply)
        if options.maxBits and length > options.maxBits then return end
        if SERVER then
            if not IsValid(ply) then return end
            if options.access and not options.access(ply) then return end
            if limited(ply, name, options.cooldown) then return end
        end
        local ok, err = pcall(callback, length, ply)
        if not ok then DFW.Util.Warn("Net handler " .. name .. " failed: " .. tostring(err)) end
    end)
end

function Net.WriteJSON(data, maxBytes)
    local json = util.TableToJSON(data or {})
    if not json then return false, "encode_failed" end
    local packed = util.Compress(json)
    if not packed or #packed > (maxBytes or MAX_JSON_BYTES) then return false, "too_large" end
    net.WriteUInt(#packed, 16)
    net.WriteData(packed, #packed)
    return true
end

function Net.ReadJSON(maxBytes)
    local size = net.ReadUInt(16)
    if size == 0 or size > (maxBytes or MAX_JSON_BYTES) then return nil end
    local packed = net.ReadData(size)
    if not packed then return nil end
    local ok, json = pcall(util.Decompress, packed, 1048576)
    if not ok or not json then return nil end
    local data = util.JSONToTable(json)
    return istable(data) and data or nil
end

if SERVER then
    hook.Add("PlayerDisconnected", "DFW.Net.ClearCooldowns", function(ply)
        local prefix = ply:UserID() .. ":"
        for key in pairs(cooldowns) do
            if string.StartWith(key, prefix) then cooldowns[key] = nil end
        end
    end)
end
