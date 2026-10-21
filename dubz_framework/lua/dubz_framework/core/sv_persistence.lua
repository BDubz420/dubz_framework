local CONFIG_FILE = "config"
local MODULES_FILE = "modules"
local SAVE_DELAY = 0.75
local dirty = false

function DFW.Config.Load()
    local data, status = DFW.Data.ReadJSON(CONFIG_FILE)
    if not istable(data) or not istable(data.values) then return status == "missing", status end

    for moduleId, values in pairs(data.values) do
        if DFW.Util.IsIdentifier(moduleId) and istable(values) then
            DFW.Config.Values[moduleId] = values
        end
    end
    return true, status
end

function DFW.Config.Save()
    dirty = false
    local ok, reason = DFW.Data.WriteJSON(CONFIG_FILE, {version = DFW.Version, values = DFW.Config.Values})
    if not ok then
        dirty = true
        DFW.Util.Warn("Config save failed: " .. tostring(reason))
    end
    return ok, reason
end

function DFW.Config.QueueSave()
    dirty = true
    timer.Create("DFW.Config.Save", SAVE_DELAY, 1, function()
        if DFW and DFW.Config and dirty then DFW.Config.Save() end
    end)
end

function DFW.Modules.LoadState()
    local data = DFW.Data.ReadJSON(MODULES_FILE)
    for id in pairs(DFW.Modules.Disabled) do DFW.Modules.Disabled[id] = nil end
    if istable(data) and istable(data.disabled) then
        for _, id in ipairs(data.disabled) do
            if DFW.Util.IsIdentifier(id) then DFW.Modules.Disabled[id] = true end
        end
    end
end

function DFW.Modules.SaveState()
    local list = DFW.Util.SortedKeys(DFW.Modules.Disabled)
    local ok, reason = DFW.Data.WriteJSON(MODULES_FILE, {disabled = list})
    if not ok then DFW.Util.Warn("Module state save failed: " .. tostring(reason)) end
    return ok
end

hook.Add("DFW_ConfigChanged", "DFW.Config.Persist", function()
    DFW.Config.QueueSave()
end)

hook.Add("ShutDown", "DFW.Config.FlushOnShutdown", function()
    if dirty and DFW and DFW.Config then DFW.Config.Save() end
end)

DFW.Config.Load()
DFW.Modules.LoadState()
