DFW.Addons = DFW.Addons or {}
local registry = DFW.Addons.Registry or {}
DFW.Addons.Registry = registry

function DFW.Addons.Register(definition)
    if not istable(definition) or not DFW.Util.IsIdentifier(definition.id) then
        DFW.Util.Warn("Rejected addon registration: invalid id")
        return false, "invalid_id"
    end
    if registry[definition.id] then
        DFW.Util.Warn("Rejected duplicate addon: " .. definition.id)
        return false, "duplicate"
    end
    if not isstring(definition.name) or definition.name == "" then
        return false, "invalid_name"
    end

    local record = table.Copy(definition)
    record.version = tostring(record.version or "0.0.0")
    record.state = record.state or "registered"
    registry[record.id] = record
    hook.Run("DFW_AddonRegistered", record.id, table.Copy(record))
    return true, table.Copy(record)
end

function DFW.Addons.SetState(id, state, reason)
    local record = registry[id]
    if not record then return false, "unknown_addon" end
    record.state = tostring(state or "unknown")
    record.reason = reason and tostring(reason) or nil
    hook.Run("DFW_AddonStateChanged", id, record.state, record.reason)
    return true
end

function DFW.Addons.Exists(id)
    return registry[id] ~= nil
end

function DFW.Addons.Get(id)
    return registry[id] and table.Copy(registry[id]) or nil
end

function DFW.Addons.GetAll()
    return table.Copy(registry)
end
