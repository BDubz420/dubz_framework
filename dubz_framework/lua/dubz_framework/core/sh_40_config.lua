-- Typed, schema-driven configuration. Modules declare fields once; the server
-- validates and persists, public fields replicate to every client, and the
-- admin menu is generated from the schema (no per-module panels needed).
--
-- Field keys: key, label, type (bool|string|number|choice|color), default,
-- description, group, order, min, max, decimals, step, choices, maxLength,
-- public (replicate to all clients), restart (UI hint: needs a map change).
DFW.Config = DFW.Config or {}
DFW.Config.Schema = DFW.Config.Schema or {}
DFW.Config.Values = DFW.Config.Values or {}
DFW.Config.Waiting = DFW.Config.Waiting or {}   -- client: values received for modules that haven't registered yet

local DEFAULT_MAX_STRING = 256
local validTypes = {bool = true, string = true, number = true, choice = true, color = true}

-- A choice field's `choices` is a list, or a function returning one (a list that grows while the server runs, like
-- the theme list: addons register themes after the framework has booted).
function DFW.Config.GetChoices(field)
    if isfunction(field.choices) then return field.choices() or {} end
    return field.choices or {}
end

local function validate(field, value)
    if field.type == "bool" then
        return isbool(value), value
    end

    if field.type == "string" then
        if not isstring(value) then return false end
        local limit = field.maxLength or DEFAULT_MAX_STRING
        if #value > limit then return false end
        return true, value
    end

    if field.type == "number" then
        if not DFW.Util.IsFiniteNumber(value) then return false end
        value = math.Clamp(value, field.min or -math.huge, field.max or math.huge)
        if field.decimals then value = DFW.Util.Round(value, field.decimals) end
        return true, value
    end

    if field.type == "choice" then
        -- A function-backed list is an open set: any identifier is kept, so a saved choice (a theme from an addon that
        -- loads later) survives until the thing it names is registered.
        if isfunction(field.choices) then return DFW.Util.IsIdentifier(value), value end

        for _, choice in ipairs(field.choices or {}) do
            if value == choice then return true, value end
        end
        return false
    end

    if field.type == "color" then
        if not istable(value) then return false end
        for _, channel in ipairs({"r", "g", "b"}) do
            if not DFW.Util.IsFiniteNumber(tonumber(value[channel])) then return false end
        end
        return true, DFW.Util.ColorToTable(value)
    end

    return false
end

function DFW.Config.Validate(moduleId, key, value)
    local field = DFW.Config.Schema[moduleId] and DFW.Config.Schema[moduleId][key]
    if not field then return false, "unknown_setting" end
    local ok, normalized = validate(field, value)
    if not ok then return false, "invalid_value" end
    return true, normalized
end

function DFW.Config.Register(moduleId, fields)
    if not DFW.Util.IsIdentifier(moduleId) or not istable(fields) then return false, "invalid_schema" end
    if not DFW.Modules or not DFW.Modules.Exists(moduleId) then return false, "unknown_module" end
    if DFW.Config.Schema[moduleId] then return false, "duplicate" end

    local normalized = {}
    for _, field in ipairs(fields) do
        if not istable(field) or not DFW.Util.IsIdentifier(field.key) or not validTypes[field.type] or normalized[field.key] then
            return false, "invalid_field"
        end
        if field.type == "choice" and not isfunction(field.choices) and (not istable(field.choices) or #field.choices == 0) then
            return false, "invalid_choices:" .. field.key
        end
        if field.type == "number" and field.min and field.max and field.min > field.max then
            return false, "invalid_range:" .. field.key
        end

        local ok, default = validate(field, field.default)
        if not ok then return false, "invalid_default:" .. field.key end

        local copy = table.Copy(field)
        copy.default = default
        copy.label = isstring(copy.label) and copy.label or copy.key
        copy.order = tonumber(copy.order) or 1000
        normalized[field.key] = copy
    end

    DFW.Config.Schema[moduleId] = normalized
    local stored = istable(DFW.Config.Values[moduleId]) and DFW.Config.Values[moduleId] or {}
    DFW.Config.Values[moduleId] = stored
    for key, field in pairs(normalized) do
        local ok, value = validate(field, stored[key])
        stored[key] = ok and value or DFW.Util.Copy(field.default)
    end

    -- Client: the server's values may have arrived before this module registered (joining players get them early).
    -- They were kept aside; apply them now so the settings you saved are not replaced by defaults.
    local waiting = DFW.Config.Waiting and DFW.Config.Waiting[moduleId]
    if waiting then
        for key, value in pairs(waiting) do
            if normalized[key] then
                local ok, checked = validate(normalized[key], value)
                if ok then stored[key] = checked end
            end
        end
        DFW.Config.Waiting[moduleId] = nil
    end

    hook.Run("DFW_ConfigRegistered", moduleId)
    return true
end

function DFW.Config.Unregister(moduleId)
    DFW.Config.Schema[moduleId] = nil
    DFW.Config.Values[moduleId] = nil
end

function DFW.Config.GetDefault(moduleId, key)
    local field = DFW.Config.Schema[moduleId] and DFW.Config.Schema[moduleId][key]
    return field and DFW.Util.Copy(field.default) or nil
end

function DFW.Config.Get(moduleId, key, fallback)
    local values = DFW.Config.Values[moduleId]
    if values and values[key] ~= nil then return values[key] end
    local field = DFW.Config.Schema[moduleId] and DFW.Config.Schema[moduleId][key]
    if field then return field.default end
    return fallback
end

function DFW.Config.GetColor(moduleId, key, fallback)
    local value = DFW.Config.Get(moduleId, key)
    if istable(value) then return DFW.Util.TableToColor(value) end
    return fallback or color_white
end

-- Applies a value and announces it. Persistence and replication hang off the
-- DFW_ConfigChanged hook (server), so this stays realm-neutral.
function DFW.Config.Set(moduleId, key, value, actor)
    local ok, normalized = DFW.Config.Validate(moduleId, key, value)
    if not ok then return false, normalized end

    local values = DFW.Config.Values[moduleId]
    if DFW.Util.DeepEqual(values[key], normalized) then return true, normalized, false end

    values[key] = normalized
    hook.Run("DFW_ConfigChanged", moduleId, key, normalized, actor)
    return true, normalized, true
end

function DFW.Config.Reset(moduleId, key, actor)
    local field = DFW.Config.Schema[moduleId] and DFW.Config.Schema[moduleId][key]
    if not field then return false, "unknown_setting" end
    return DFW.Config.Set(moduleId, key, DFW.Util.Copy(field.default), actor)
end

function DFW.Config.ResetModule(moduleId, actor)
    local schema = DFW.Config.Schema[moduleId]
    if not schema then return false, "unknown_module" end
    for _, key in ipairs(DFW.Util.SortedKeys(schema)) do DFW.Config.Reset(moduleId, key, actor) end
    return true
end

-- Used by the client when the server pushes a value: store + announce, no persistence.
function DFW.Config.ApplyRemote(moduleId, key, value)
    local ok, normalized = DFW.Config.Validate(moduleId, key, value)
    if not ok then return false end
    if DFW.Util.DeepEqual(DFW.Config.Values[moduleId][key], normalized) then return true end
    DFW.Config.Values[moduleId][key] = normalized
    hook.Run("DFW_ConfigChanged", moduleId, key, normalized, nil)
    return true
end

function DFW.Config.IsDefault(moduleId, key)
    local field = DFW.Config.Schema[moduleId] and DFW.Config.Schema[moduleId][key]
    if not field then return true end
    return DFW.Util.DeepEqual(DFW.Config.Get(moduleId, key), field.default)
end

-- Fields of one module as a list sorted by order then key.
function DFW.Config.GetFields(moduleId)
    local list = {}
    for _, field in pairs(DFW.Config.Schema[moduleId] or {}) do list[#list + 1] = field end
    table.sort(list, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.key < b.key
    end)
    return list
end

function DFW.Config.GetSchema() return table.Copy(DFW.Config.Schema) end
function DFW.Config.GetModuleValues(moduleId) return table.Copy(DFW.Config.Values[moduleId] or {}) end

-- Builds {module = {key = value}} limited to schema'd keys; publicOnly keeps only public fields.
function DFW.Config.Export(publicOnly)
    local out = {}
    for moduleId, schema in pairs(DFW.Config.Schema) do
        local values = DFW.Config.Values[moduleId] or {}
        for key, field in pairs(schema) do
            if not publicOnly or field.public then
                out[moduleId] = out[moduleId] or {}
                out[moduleId][key] = values[key]
            end
        end
    end
    return out
end

-- Bulk apply (client snapshot). Fires DFW_ConfigChanged for each changed value.
function DFW.Config.ApplyExport(data)
    if not istable(data) then return end
    for moduleId, values in pairs(data) do
        if istable(values) and DFW.Config.Schema[moduleId] then
            for key, value in pairs(values) do
                if DFW.Config.Schema[moduleId][key] then DFW.Config.ApplyRemote(moduleId, key, value) end
            end
        elseif istable(values) and CLIENT then
            DFW.Config.Waiting[moduleId] = values
        end
    end
end
