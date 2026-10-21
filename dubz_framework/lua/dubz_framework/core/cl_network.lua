local Net = DFW.Net

DFW.Modules.ServerState = DFW.Modules.ServerState or {}

local function readName()
    local value = net.ReadString()
    if #value > 64 then return nil end
    return value
end

Net.Receive("Config.Public", function()
    local data = Net.ReadJSON()
    if not data then return end

    DFW.Config.ApplyExport(data.values)

    local disabled = {}
    for _, id in ipairs(istable(data.disabled) and data.disabled or {}) do disabled[id] = true end
    for id, module in pairs(DFW.Modules.Registry) do
        if not module.core then
            local shouldBeEnabled = not disabled[id]
            if module.enabled ~= shouldBeEnabled then DFW.Modules.SetEnabled(id, shouldBeEnabled, true) end
        end
    end

    hook.Run("DFW_PublicConfigReceived")
end, {maxBits = 600000})

Net.Receive("Config.Snapshot", function()
    local data = Net.ReadJSON()
    if not data then return end
    DFW.Config.ApplyExport(data.values)
    hook.Run("DFW_ConfigSnapshot", data)
end, {maxBits = 600000})

Net.Receive("Config.Delta", function()
    local moduleId, key = readName(), readName()
    local json = net.ReadString()
    if not moduleId or not key or #json > 4096 then return end
    local decoded = util.JSONToTable(json)
    if istable(decoded) and DFW.Config.Schema[moduleId] and DFW.Config.Schema[moduleId][key] then
        DFW.Config.ApplyRemote(moduleId, key, decoded.v)
    end
end)

Net.Receive("Config.Result", function()
    local ok = net.ReadBool()
    local moduleId, key, reason = net.ReadString(), net.ReadString(), net.ReadString()
    hook.Run("DFW_ConfigResult", ok, moduleId, key, reason)
end)

Net.Receive("Config.Open", function()
    hook.Run("DFW_OpenConfigMenu")
end)

Net.Receive("Modules.State", function()
    local data = Net.ReadJSON()
    if not data then return end
    DFW.Modules.ServerState = data
    hook.Run("DFW_ModuleStateSnapshot", data)
end, {maxBits = 600000})

Net.Receive("Modules.Enabled", function()
    local id = readName()
    local enabled = net.ReadBool()
    if id and DFW.Modules.Exists(id) then DFW.Modules.SetEnabled(id, enabled, true) end
end)

Net.Receive("Modules.Result", function()
    local ok = net.ReadBool()
    local id, reason = net.ReadString(), net.ReadString()
    hook.Run("DFW_ModuleResult", ok, id, reason)
end)

function DFW.Config.RequestOpen()
    Net.Start("Config.OpenRequest")
    net.SendToServer()
end

function DFW.Config.RequestSnapshot()
    Net.Start("Config.Request")
    net.SendToServer()
end

function DFW.Modules.RequestState()
    Net.Start("Modules.Request")
    net.SendToServer()
end

local SEND_SPACING = 0.12
local queue = {}
local lastSend = -math.huge

local senders = {
    set = function(entry)
        Net.Start("Config.Update")
        net.WriteString(entry.module)
        net.WriteString(entry.key)
        net.WriteString(entry.json)
        net.SendToServer()
    end,
    reset = function(entry)
        Net.Start("Config.Reset")
        net.WriteString(entry.module)
        net.WriteString(entry.key)
        net.SendToServer()
    end,
    toggle = function(entry)
        Net.Start("Modules.Toggle")
        net.WriteString(entry.module)
        net.WriteBool(entry.enabled)
        net.SendToServer()
    end
}

local flush
flush = function()
    while #queue > 0 and SysTime() - lastSend >= SEND_SPACING do
        local entry = table.remove(queue, 1)
        lastSend = SysTime()
        senders[entry.kind](entry)
    end
    if #queue > 0 then timer.Create("DFW.Config.SendQueue", SEND_SPACING, 1, flush) end
end

local function enqueue(entry)
    if entry.kind == "set" then
        for index = #queue, 1, -1 do
            if queue[index].kind == "set" and queue[index].module == entry.module and queue[index].key == entry.key then
                table.remove(queue, index)
            end
        end
    end
    queue[#queue + 1] = entry
    flush()
end

function DFW.Config.RequestSet(moduleId, key, value)
    local json = util.TableToJSON({v = value})
    if not json or #json > 4096 then return false end
    enqueue({kind = "set", module = moduleId, key = key, json = json})
    return true
end

function DFW.Config.RequestReset(moduleId, key)
    enqueue({kind = "reset", module = moduleId, key = key or ""})
end

function DFW.Modules.RequestToggle(id, enabled)
    enqueue({kind = "toggle", module = id, enabled = enabled == true})
end

hook.Add("InitPostEntity", "DFW.Config.RequestPublic", function()
    Net.Start("Config.RequestPublic")
    net.SendToServer()
end)

if DFW_GamemodeLoaded then
    timer.Simple(1, function()
        if not DFW or not DFW.Net then return end
        Net.Start("Config.RequestPublic")
        net.SendToServer()
    end)
end
