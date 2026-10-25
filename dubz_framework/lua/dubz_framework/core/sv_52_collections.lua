-- Server side of collections: persistence (data/dubz_framework/collections.json), replication, and the save /
-- reset requests from the config menu. Clients can only ask; every row is validated here.
local Collections = DFW.Collections
local Net = DFW.Net

for _, name in ipairs({"Collections.Request", "Collections.Sync", "Collections.Save", "Collections.Reset", "Collections.Result"}) do
    Net.Pool(name)
end

local FILE = "collections"
local SAVE_DELAY = 0.75
local dirty = false

-- Saved rows are read now; Register() picks them up when each module registers
do
    local data = DFW.Data.ReadJSON(FILE)
    Collections.Pending = istable(data) and istable(data.collections) and data.collections or {}
end

local function save()
    dirty = false

    local out = {}
    for moduleId, byId in pairs(Collections.Rows) do
        for collId, rows in pairs(byId) do
            -- Only collections that differ from their defaults are written
            local def = Collections.GetDefinition(moduleId, collId)
            local defaults = def and Collections.Normalize(moduleId, collId, def.default)
            if not (defaults and DFW.Util.DeepEqual(defaults, rows)) then out[moduleId .. "/" .. collId] = rows end
        end
    end

    local ok, reason = DFW.Data.WriteJSON(FILE, {version = DFW.Version, collections = out})
    if not ok then
        dirty = true
        DFW.Util.Warn("Collections save failed: " .. tostring(reason))
    end
end

local function queueSave()
    dirty = true
    timer.Create("DFW.Collections.Save", SAVE_DELAY, 1, function()
        if DFW and DFW.Collections and dirty then save() end
    end)
end

hook.Add("ShutDown", "DFW.Collections.Flush", function()
    if dirty then save() end
end)

local function admins()
    local list = {}
    for _, ply in ipairs(player.GetAll()) do
        if DFW.Access.CanConfigure(ply) then list[#list + 1] = ply end
    end
    return list
end

local function sendSet(moduleId, collId, recipient)
    local def = Collections.GetDefinition(moduleId, collId)
    if not def then return end

    Net.Start("Collections.Sync")
    net.WriteString(moduleId)
    net.WriteString(collId)
    if not Net.WriteJSON({rows = Collections.Get(moduleId, collId)}) then
        net.Abort()
        DFW.Util.Warn("Collection " .. moduleId .. "/" .. collId .. " is too large to send")
        return
    end

    if recipient == true then net.Broadcast() else net.Send(recipient) end
end

-- Persist and replicate every change (whoever made it)
hook.Add("DFW_CollectionChanged", "DFW.Collections.Replicate", function(moduleId, collId, rows, actor)
    local def = Collections.GetDefinition(moduleId, collId)
    if not def or actor == nil then return end   -- nil actor = registration, nothing to announce

    queueSave()

    if def.public then sendSet(moduleId, collId, true) else
        local list = admins()
        if #list > 0 then sendSet(moduleId, collId, list) end
    end
end)

-- A client asks once after joining: it gets every public collection (admins also get the private ones)
Net.Receive("Collections.Request", function(_, ply)
    local isAdmin = DFW.Access.CanConfigure(ply)

    for moduleId, byId in pairs(Collections.Defs) do
        for collId, def in pairs(byId) do
            if def.public or isAdmin then sendSet(moduleId, collId, ply) end
        end
    end
end, {maxBits = 64, cooldown = 3})

local function result(ply, ok, moduleId, collId, reason)
    Net.Start("Collections.Result")
    net.WriteBool(ok)
    net.WriteString(moduleId)
    net.WriteString(collId)
    net.WriteString(reason or "")
    net.Send(ply)
end

Net.Receive("Collections.Save", function(_, ply)
    local moduleId, collId = net.ReadString(), net.ReadString()
    local data = Net.ReadJSON()

    if not data or not istable(data.rows) then result(ply, false, moduleId, collId, "invalid_payload") return end

    local ok, reason = Collections.Set(moduleId, collId, data.rows, ply)
    result(ply, ok, moduleId, collId, ok and "" or reason)
end, {maxBits = 600000, cooldown = 0.3, access = DFW.Access.CanConfigure})

Net.Receive("Collections.Reset", function(_, ply)
    local moduleId, collId = net.ReadString(), net.ReadString()

    local ok, reason = Collections.Reset(moduleId, collId, ply)
    result(ply, ok, moduleId, collId, ok and "" or reason)
end, {maxBits = 2048, cooldown = 0.3, access = DFW.Access.CanConfigure})
