DFW.Modules = DFW.Modules or {}
local registry = DFW.Modules.Registry or {}
DFW.Modules.Registry = registry
-- Module ids an administrator has switched off. Persisted by the server, mirrored to clients.
DFW.Modules.Disabled = DFW.Modules.Disabled or {}
local disabled = DFW.Modules.Disabled
local startSequence = {}

-- Methods available on every live module record (the table passed to OnStart/OnStop).
-- Hooks and timers made through them are removed automatically when the module stops.
local Methods = {}
Methods.__index = Methods

function Methods:AddHook(event, name, callback)
    local id = "DFW." .. self.id .. "." .. tostring(name)
    hook.Add(event, id, callback)
    self._hooks = self._hooks or {}
    self._hooks[#self._hooks + 1] = {event = event, id = id}
    return id
end

function Methods:AddTimer(name, delay, repetitions, callback)
    local id = "DFW." .. self.id .. "." .. tostring(name)
    timer.Create(id, delay, repetitions, callback)
    self._timers = self._timers or {}
    self._timers[#self._timers + 1] = id
    return id
end

function Methods:Cleanup()
    for _, entry in ipairs(self._hooks or {}) do hook.Remove(entry.event, entry.id) end
    for _, id in ipairs(self._timers or {}) do timer.Remove(id) end
    self._hooks, self._timers = {}, {}
end

function Methods:GetConfig(key, fallback)
    return DFW.Config.Get(self.id, key, fallback)
end

local function removeFromStartSequence(id)
    for index = #startSequence, 1, -1 do
        if startSequence[index] == id then table.remove(startSequence, index) end
    end
end

local function dependenciesAvailable(definition, requireStarted)
    if not DFW.Addons.Exists(definition.addon) or DFW.Addons.Get(definition.addon).state ~= "loaded" then
        return false, "addon:" .. tostring(definition.addon)
    end

    for _, dependency in ipairs(definition.dependencies or {}) do
        local module = registry[dependency]
        if not module or module.enabled == false or module.failure or (requireStarted and not module.started) then
            return false, dependency
        end
    end
    return true
end

local function stopModule(module, reason)
    if module.started and isfunction(module.OnStop) then
        DFW.Util.SafeCall("Module " .. module.id .. " stop", module.OnStop, module, reason)
    end
    module:Cleanup()
    module.started = false
    removeFromStartSequence(module.id)
    hook.Run("DFW_ModuleStopped", module.id, reason)
end

local function startModule(module)
    local success, reason = true, nil
    if isfunction(module.OnStart) then success, reason = pcall(module.OnStart, module) end

    if not success then
        module:Cleanup()
        module.started = false
        module.failure = tostring(reason)
        DFW.Util.Warn("Module " .. module.id .. " failed to start: " .. module.failure)
        hook.Run("DFW_ModuleFailed", module.id, module.failure)
        return false
    end

    module.started = true
    module.failure = nil
    module.waitingFor = nil
    module.lastWaitingWarning = nil
    removeFromStartSequence(module.id)
    startSequence[#startSequence + 1] = module.id
    hook.Run("DFW_ModuleStarted", module.id)
    return true
end

function DFW.Modules.GamemodeReady()
    return DFW_GamemodeLoaded == true
end

function DFW.Modules.Register(definition)
    if not istable(definition) or not DFW.Util.IsIdentifier(definition.id) then
        DFW.Util.Warn("Rejected module registration: invalid id")
        return false, "invalid_id"
    end
    if registry[definition.id] then
        DFW.Util.Warn("Rejected duplicate module: " .. definition.id)
        return false, "duplicate"
    end
    if definition.dependencies ~= nil and not istable(definition.dependencies) then
        return false, "invalid_dependencies"
    end

    for _, dependency in ipairs(definition.dependencies or {}) do
        if not DFW.Util.IsIdentifier(dependency) or dependency == definition.id then
            return false, "invalid_dependency"
        end
    end

    local owner = definition.addon or (DFW.Packages and DFW.Packages.GetActiveId())
    if not DFW.Util.IsIdentifier(owner) or not DFW.Addons.Exists(owner) then
        DFW.Util.Warn("Rejected module " .. definition.id .. ": unknown addon owner")
        return false, "unknown_addon"
    end

    local record = table.Copy(definition)
    record.addon = owner
    record.name = isstring(record.name) and record.name ~= "" and record.name or record.id
    record.version = tostring(record.version or "0.0.0")
    record.core = definition.core == true and owner == "dubz_framework"
    record.enabled = record.enabled ~= false
    record.started = false
    record.failure = nil
    if disabled[record.id] and not record.core then
        record.enabled = false
        record.disabledByAdmin = true
    end
    setmetatable(record, Methods)
    registry[record.id] = record
    hook.Run("DFW_ModuleRegistered", record.id, record.addon)

    if DFW.Ready then
        timer.Simple(0, function()
            if DFW and DFW.Modules then DFW.Modules.StartAll() end
        end)
    end

    return true, table.Copy(record)
end

function DFW.Modules.Get(id)
    return registry[id] and table.Copy(registry[id]) or nil
end

function DFW.Modules.GetAll()
    return table.Copy(registry)
end

function DFW.Modules.Exists(id)
    return registry[id] ~= nil
end

-- Master switch: false only when the module exists and an admin turned it off. Unknown modules (framework
-- not installed or not registered yet) count as enabled, so gating on this never breaks an addon by accident.
function DFW.Modules.IsEnabled(id)
    local module = registry[id]
    return module == nil or module.enabled ~= false
end

function DFW.Modules.IsStarted(id)
    return registry[id] ~= nil and registry[id].started == true
end

-- started | disabled | failed | waiting | registered | unknown
function DFW.Modules.GetState(id)
    local module = registry[id]
    if not module then return "unknown" end
    if module.failure then return "failed" end
    if module.started then return "started" end
    if not module.enabled then return "disabled" end
    if module.waitingFor then return "waiting" end
    return "registered"
end

-- Removes a module entirely (used for failed packages and tests). Stops it first.
function DFW.Modules.Unregister(id)
    local module = registry[id]
    if not module then return false end
    stopModule(module, "unregistered")
    registry[id] = nil
    if DFW.Config and DFW.Config.Unregister then DFW.Config.Unregister(id) end
    hook.Run("DFW_ModuleUnregistered", id)
    return true
end

function DFW.Modules.RemoveByAddon(addonId)
    local ids = {}
    for id, module in pairs(registry) do
        if module.addon == addonId then ids[#ids + 1] = id end
    end
    for _, id in ipairs(ids) do DFW.Modules.Unregister(id) end
    return #ids
end

-- remote = true when applying a state the server already decided (client mirror).
function DFW.Modules.SetEnabled(id, enabled, remote)
    local module = registry[id]
    if not module then return false, "unknown_module" end
    enabled = enabled == true
    if module.core and not enabled then return false, "core_module" end
    if enabled == module.enabled and (not enabled or module.started) then return true end

    if enabled then
        module.enabled = true
        module.disabledByAdmin = nil
        module.failure = nil
        disabled[id] = nil
        if not remote and DFW.Modules.SaveState then DFW.Modules.SaveState() end
        DFW.Modules.StartAll()
    else
        if not remote then
            for otherId, other in pairs(registry) do
                if other.enabled then
                    for _, dependency in ipairs(other.dependencies or {}) do
                        if dependency == id then return false, "required_by:" .. otherId end
                    end
                end
            end
        end
        stopModule(module, "disabled")
        module.enabled = false
        module.disabledByAdmin = true
        disabled[id] = true
        if not remote and DFW.Modules.SaveState then DFW.Modules.SaveState() end
    end

    hook.Run("DFW_ModuleStateChanged", id, enabled)
    return true
end

function DFW.Modules.StartAll()
    if not DFW.Modules.GamemodeReady() then return end

    local ids = table.GetKeys(registry)
    table.sort(ids)
    local pending = {}
    for _, id in ipairs(ids) do
        local module = registry[id]
        if module.enabled and not module.started and not module.failure then pending[id] = true end
    end

    local progressed = true
    while progressed do
        progressed = false
        for _, id in ipairs(ids) do
            local module = registry[id]
            if pending[id] then
                local ok, dependency = dependenciesAvailable(module, true)
                if ok then
                    startModule(module)
                    pending[id] = nil
                    progressed = true
                else
                    module.waitingFor = dependency
                end
            end
        end
    end

    for id in pairs(pending) do
        local module = registry[id]
        local waitingFor = module.waitingFor or "unknown"
        if module.lastWaitingWarning ~= waitingFor then
            DFW.Util.Warn("Module " .. id .. " waiting for dependency " .. waitingFor)
            module.lastWaitingWarning = waitingFor
        end
    end
end

function DFW.Modules.StopAll(reason)
    for index = #startSequence, 1, -1 do
        local module = registry[startSequence[index]]
        if module and module.started then stopModule(module, reason or "shutdown") end
    end
    startSequence = {}
end

-- Convenience: modules can implement OnConfigChanged(self, key, value, actor).
hook.Add("DFW_ConfigChanged", "DFW.Modules.DispatchConfig", function(moduleId, key, value, actor)
    local module = registry[moduleId]
    if module and module.started and isfunction(module.OnConfigChanged) then
        DFW.Util.SafeCall("Module " .. moduleId .. " OnConfigChanged", module.OnConfigChanged, module, key, value, actor)
    end
end)

-- Modules start only once the gamemode (DarkRP) has loaded, so OnStart can rely on it.
hook.Add("Initialize", "DFW.Modules.Start", function()
    DFW_GamemodeLoaded = true
    if DFW and DFW.Modules then DFW.Modules.StartAll() end
end)
