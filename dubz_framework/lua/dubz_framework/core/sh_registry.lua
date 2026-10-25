DFW.Registry = DFW.Registry or {}
local registries = {}

local Registry = {}
Registry.__index = Registry

function Registry:Register(id, definition)
    if not DFW.Util.IsIdentifier(id) then return false, "invalid_id" end
    if not istable(definition) then return false, "invalid_definition" end

    local existing = self.Items[id]
    if existing and not self.Options.allowOverride then return false, "duplicate" end

    if isfunction(self.Options.validate) then
        local ok, reason = self.Options.validate(definition, id)
        if not ok then return false, tostring(reason or "validation_failed") end
    end

    definition.ID = id
    self.Items[id] = definition
    if not existing then self.Order[#self.Order + 1] = id end

    hook.Run("DFW_RegistryRegistered", self.Name, id, definition)
    return true, definition
end

function Registry:Get(id) return self.Items[id] end
function Registry:Has(id) return self.Items[id] ~= nil end
function Registry:Count() return #self.Order end

function Registry:Remove(id)
    if not self.Items[id] then return false end
    self.Items[id] = nil
    for index = #self.Order, 1, -1 do
        if self.Order[index] == id then table.remove(self.Order, index) end
    end
    hook.Run("DFW_RegistryRemoved", self.Name, id)
    return true
end

function Registry:All()
    local list = {}
    for _, id in ipairs(self.Order) do list[#list + 1] = self.Items[id] end
    if isfunction(self.Options.sort) then table.sort(list, self.Options.sort) end
    return list
end

function Registry:Each(callback)
    for _, definition in ipairs(self:All()) do callback(definition.ID, definition) end
end

function DFW.Registry.Create(name, options)
    if not DFW.Util.IsIdentifier(name) then return nil, "invalid_name" end
    if registries[name] then return registries[name] end

    local registry = setmetatable({
        Name = name,
        Items = {},
        Order = {},
        Options = istable(options) and options or {}
    }, Registry)
    registries[name] = registry
    return registry
end

function DFW.Registry.Get(name) return registries[name] end

function DFW.Registry.GetNames()
    return DFW.Util.SortedKeys(registries)
end
