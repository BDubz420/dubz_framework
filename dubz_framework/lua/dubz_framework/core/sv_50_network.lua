-- Server side of config/module synchronisation. Clients can only ask; the
-- server validates, applies, persists, and tells everyone what changed.
local Net = DFW.Net

local messages = {
    "Config.RequestPublic", "Config.Public", "Config.Request", "Config.Snapshot",
    "Config.Delta", "Config.Update", "Config.Reset", "Config.Result",
    "Config.OpenRequest", "Config.Open",
    "Modules.Request", "Modules.State", "Modules.Toggle", "Modules.Result", "Modules.Enabled"
}
for _, name in ipairs(messages) do Net.Pool(name) end

local MAX_NAME = 64
local MAX_VALUE_JSON = 4096

local function sendJSON(name, data, recipient)
    Net.Start(name)
    if not Net.WriteJSON(data) then
        net.Abort()
        DFW.Util.Warn("Payload for " .. name .. " exceeds the size limit and was not sent")
        return false
    end
    if recipient == true then net.Broadcast() else net.Send(recipient) end
    return true
end

local function configurePlayers()
    local list = {}
    for _, ply in ipairs(player.GetAll()) do
        if DFW.Access.CanConfigure(ply) then list[#list + 1] = ply end
    end
    return list
end

local function sendResult(ply, ok, moduleId, key, reason)
    Net.Start("Config.Result")
    net.WriteBool(ok)
    net.WriteString(moduleId or "")
    net.WriteString(key or "")
    net.WriteString(reason or "")
    net.Send(ply)
end

function DFW.Config.SendPublic(ply)
    return sendJSON("Config.Public", {
        values = DFW.Config.Export(true),
        disabled = DFW.Util.SortedKeys(DFW.Modules.Disabled)
    }, ply)
end

function DFW.Config.SendSnapshot(ply)
    if not DFW.Access.CanConfigure(ply) then return false end
    return sendJSON("Config.Snapshot", {values = DFW.Config.Export(false)}, ply)
end

local function moduleList()
    local list = {}
    for id, module in pairs(DFW.Modules.GetAll()) do
        list[#list + 1] = {
            id = id,
            name = module.name,
            addon = module.addon,
            version = module.version,
            icon = module.icon,
            description = module.description,
            enabled = module.enabled == true,
            state = DFW.Modules.GetState(id),
            failure = module.failure,
            waitingFor = module.waitingFor,
            core = module.core == true,
            dependencies = module.dependencies or {}
        }
    end
    table.sort(list, function(a, b) return string.lower(a.name) < string.lower(b.name) end)

    local addons = {}
    for id, addon in pairs(DFW.Addons.GetAll()) do
        addons[id] = {name = addon.name, version = addon.version, state = addon.state, reason = addon.reason}
    end
    return {modules = list, addons = addons, packages = DFW.Packages.GetStats()}
end

function DFW.Modules.SendState(ply)
    if not DFW.Access.CanConfigure(ply) then return false end
    return sendJSON("Modules.State", moduleList(), ply)
end

local function readName()
    local value = net.ReadString()
    if #value > MAX_NAME then return nil end
    return value
end

-- Join sync: clients ask once they are loaded, which avoids join-timing races.
Net.Receive("Config.RequestPublic", function(_, ply)
    DFW.Config.SendPublic(ply)
end, {maxBits = 64, cooldown = 3})

Net.Receive("Config.Request", function(_, ply)
    DFW.Config.SendSnapshot(ply)
end, {maxBits = 64, cooldown = 0.5, access = DFW.Access.CanConfigure})

Net.Receive("Config.OpenRequest", function(_, ply)
    if not DFW.Config.SendSnapshot(ply) then return end
    DFW.Modules.SendState(ply)
    Net.Start("Config.Open")
    net.Send(ply)
end, {maxBits = 64, cooldown = 0.5, access = DFW.Access.CanConfigure})

Net.Receive("Config.Update", function(_, ply)
    local moduleId, key = readName(), readName()
    local json = net.ReadString()
    if not moduleId or not key or #json > MAX_VALUE_JSON then return end

    local decoded = util.JSONToTable(json)
    if not istable(decoded) then sendResult(ply, false, moduleId, key, "invalid_payload") return end

    local ok, reason = DFW.Config.Set(moduleId, key, decoded.v, ply)
    sendResult(ply, ok, moduleId, key, ok and "" or reason)
end, {maxBits = 40000, cooldown = 0.05, access = DFW.Access.CanConfigure})

Net.Receive("Config.Reset", function(_, ply)
    local moduleId, key = readName(), readName()
    if not moduleId or not key then return end

    local ok, reason
    if key == "" then ok, reason = DFW.Config.ResetModule(moduleId, ply) else ok, reason = DFW.Config.Reset(moduleId, key, ply) end
    sendResult(ply, ok == true, moduleId, key, ok and "" or reason)
end, {maxBits = 2048, cooldown = 0.05, access = DFW.Access.CanConfigure})

Net.Receive("Modules.Request", function(_, ply)
    DFW.Modules.SendState(ply)
end, {maxBits = 64, cooldown = 0.5, access = DFW.Access.CanConfigure})

Net.Receive("Modules.Toggle", function(_, ply)
    local id = readName()
    local enabled = net.ReadBool()
    if not id then return end

    local ok, reason = DFW.Modules.SetEnabled(id, enabled)
    Net.Start("Modules.Result")
    net.WriteBool(ok == true)
    net.WriteString(id)
    net.WriteString(ok and "" or tostring(reason))
    net.Send(ply)
    DFW.Modules.SendState(ply)
end, {maxBits = 2048, cooldown = 0.05, access = DFW.Access.CanConfigure})

-- Replication: one changed value goes to everyone if public, otherwise only to config admins.
hook.Add("DFW_ConfigChanged", "DFW.Config.Replicate", function(moduleId, key, value)
    local field = DFW.Config.Schema[moduleId] and DFW.Config.Schema[moduleId][key]
    if not field then return end

    local json = util.TableToJSON({v = value})
    if not json or #json > MAX_VALUE_JSON then return end

    Net.Start("Config.Delta")
    net.WriteString(moduleId)
    net.WriteString(key)
    net.WriteString(json)
    if field.public then net.Broadcast() else net.Send(configurePlayers()) end
end)

hook.Add("DFW_ModuleStateChanged", "DFW.Modules.Replicate", function(id, enabled)
    Net.Start("Modules.Enabled")
    net.WriteString(id)
    net.WriteBool(enabled)
    net.Broadcast()
end)

-- Sends the open command after fresh data so the menu never opens on stale values.
function DFW.Config.OpenFor(ply)
    if not DFW.Access.CanConfigure(ply) then return false end
    if not DFW.Config.SendSnapshot(ply) then return false end
    DFW.Modules.SendState(ply)
    Net.Start("Config.Open")
    net.Send(ply)
    return true
end
