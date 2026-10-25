DFW.Collections = DFW.Collections or {}
local Collections = DFW.Collections

Collections.Defs = Collections.Defs or {}
Collections.Rows = Collections.Rows or {}
Collections.Waiting = Collections.Waiting or {}

local MAX_ROWS = 600
local MAX_STRING = 240
local validTypes = {string = true, number = true, bool = true, color = true, choice = true}

local function defaultFor(col)
    if col.default ~= nil then return DFW.Util.Copy(col.default) end
    if col.type == "number" then return col.min or 0 end
    if col.type == "bool" then return false end
    if col.type == "color" then return {r = 255, g = 255, b = 255, a = 255} end
    if col.type == "choice" then return (col.choices or {})[1] end
    return ""
end

local function normalizeValue(col, value)
    local kind = col.type

    if kind == "string" then
        value = tostring(value == nil and defaultFor(col) or value)
        return string.sub(value, 1, col.maxLength or MAX_STRING)
    elseif kind == "number" then
        value = tonumber(value)
        if not DFW.Util.IsFiniteNumber(value) then value = defaultFor(col) end
        value = math.Clamp(value, col.min or -math.huge, col.max or math.huge)
        if col.decimals then value = DFW.Util.Round(value, col.decimals) end
        return value
    elseif kind == "bool" then
        return value == true
    elseif kind == "color" then
        return DFW.Util.ColorToTable(istable(value) and value or defaultFor(col))
    elseif kind == "choice" then
        for _, choice in ipairs(col.choices or {}) do
            if value == choice then return value end
        end
        return defaultFor(col)
    end
end

local function normalizeRow(def, row)
    local out = {}
    for _, col in ipairs(def.columns) do out[col.key] = normalizeValue(col, istable(row) and row[col.key]) end
    return out
end

function Collections.Normalize(moduleId, collId, rows)
    local def = Collections.Defs[moduleId] and Collections.Defs[moduleId][collId]
    if not def then return false, "unknown_collection" end
    if not istable(rows) then return false, "invalid_rows" end
    if #rows > (def.maxRows or MAX_ROWS) then return false, "too_many_rows" end

    local clean, seen = {}, {}
    for index, row in ipairs(rows) do
        local normalized = normalizeRow(def, row)

        if def.idKey then
            local id = normalized[def.idKey]
            if id == "" then return false, "empty_id:" .. index end
            if seen[id] then return false, "duplicate_id:" .. id end
            seen[id] = true
        end

        clean[#clean + 1] = normalized
    end

    return clean
end

function Collections.Register(moduleId, def)
    if not DFW.Util.IsIdentifier(moduleId) or not istable(def) or not DFW.Util.IsIdentifier(def.id) then return false, "invalid_definition" end
    if not DFW.Modules or not DFW.Modules.Exists(moduleId) then return false, "unknown_module" end
    if not istable(def.columns) or #def.columns == 0 then return false, "invalid_columns" end

    local seen = {}
    for _, col in ipairs(def.columns) do
        if not DFW.Util.IsIdentifier(col.key) or seen[col.key] or not validTypes[col.type] then return false, "invalid_column" end
        if col.type == "choice" and (not istable(col.choices) or #col.choices == 0) then return false, "invalid_choices" end
        seen[col.key] = true
        col.label = col.label or col.key
    end

    local copy = table.Copy(def)
    copy.label = copy.label or copy.id
    copy.public = copy.public ~= false
    copy.default = copy.default or {}

    Collections.Defs[moduleId] = Collections.Defs[moduleId] or {}
    if Collections.Defs[moduleId][copy.id] then return false, "duplicate" end
    Collections.Defs[moduleId][copy.id] = copy

    local rows = Collections.Normalize(moduleId, copy.id, copy.default)
    if not rows then
        Collections.Defs[moduleId][copy.id] = nil
        return false, "invalid_default"
    end

    Collections.Rows[moduleId] = Collections.Rows[moduleId] or {}
    local saved = Collections.Pending and Collections.Pending[moduleId .. "/" .. copy.id]
    local restored = saved and Collections.Normalize(moduleId, copy.id, saved)

    local key = moduleId .. "/" .. copy.id
    local waiting = Collections.Waiting and Collections.Waiting[key]
    if waiting then
        restored = Collections.Normalize(moduleId, copy.id, waiting) or restored
        Collections.Waiting[key] = nil
    end
    Collections.Rows[moduleId][copy.id] = restored or rows

    hook.Run("DFW_CollectionRegistered", moduleId, copy.id)
    hook.Run("DFW_CollectionChanged", moduleId, copy.id, Collections.Rows[moduleId][copy.id], nil)
    return true
end

function Collections.NewRow(moduleId, collId)
    local def = Collections.Defs[moduleId] and Collections.Defs[moduleId][collId]
    return def and normalizeRow(def, {}) or {}
end

function Collections.GetDefinition(moduleId, collId)
    return Collections.Defs[moduleId] and Collections.Defs[moduleId][collId]
end

function Collections.Get(moduleId, collId)
    return Collections.Rows[moduleId] and Collections.Rows[moduleId][collId] or {}
end

function Collections.ToColor(value)
    return istable(value) and DFW.Util.TableToColor(value) or color_white
end

function Collections.Find(moduleId, collId, key, value)
    for _, row in ipairs(Collections.Get(moduleId, collId)) do
        if row[key] == value then return row end
    end
end

function Collections.ListFor(moduleId)
    local list = {}
    for id, def in pairs(Collections.Defs[moduleId] or {}) do list[#list + 1] = def end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

function Collections.Set(moduleId, collId, rows, actor)
    local clean, reason = Collections.Normalize(moduleId, collId, rows)
    if not clean then return false, reason end

    Collections.Rows[moduleId][collId] = clean
    hook.Run("DFW_CollectionChanged", moduleId, collId, clean, actor)
    return true
end

function Collections.Reset(moduleId, collId, actor)
    local def = Collections.GetDefinition(moduleId, collId)
    if not def then return false, "unknown_collection" end
    return Collections.Set(moduleId, collId, def.default, actor)
end

function Collections.RowsFromMap(map, keyColumn, valueColumn)
    local rows = {}
    for key, value in SortedPairs(map or {}) do rows[#rows + 1] = {[keyColumn] = tostring(key), [valueColumn] = value} end
    return rows
end

function Collections.MapFromRows(rows, keyColumn, valueColumn, lowerKeys)
    local map = {}
    for _, row in ipairs(rows) do
        local key = tostring(row[keyColumn])
        if key ~= "" then map[lowerKeys and string.lower(key) or key] = row[valueColumn] end
    end
    return map
end

function Collections.RowsFromList(list, column)
    local rows = {}
    for _, value in ipairs(list or {}) do rows[#rows + 1] = {[column] = tostring(value)} end
    return rows
end

function Collections.ListFromRows(rows, column, lower)
    local list = {}
    for _, row in ipairs(rows) do
        local value = tostring(row[column])
        if value ~= "" then list[#list + 1] = lower and string.lower(value) or value end
    end
    return list
end

function Collections.RowsFromSet(set, column)
    local rows = {}
    for key, on in SortedPairs(set or {}) do
        if on then rows[#rows + 1] = {[column] = tostring(key)} end
    end
    return rows
end

function Collections.SetFromRows(rows, column)
    local set = {}
    for _, row in ipairs(rows) do
        local value = string.lower(tostring(row[column]))
        if value ~= "" then set[value] = true end
    end
    return set
end

function Collections.Watch(moduleId, collId, fn)
    local hookId = "DFW.Collections.Watch." .. moduleId .. "." .. collId .. "." .. tostring(fn)

    hook.Add("DFW_CollectionChanged", hookId, function(changedModule, changedColl, rows)
        if changedModule == moduleId and changedColl == collId then fn(rows) end
    end)

    if Collections.GetDefinition(moduleId, collId) then fn(Collections.Get(moduleId, collId)) end
end

function Collections.ApplyRemote(moduleId, collId, rows)
    local clean = Collections.Normalize(moduleId, collId, rows)
    if not clean then return false end

    if DFW.Util.DeepEqual(Collections.Rows[moduleId][collId], clean) then return true end

    Collections.Rows[moduleId][collId] = clean
    hook.Run("DFW_CollectionChanged", moduleId, collId, clean, nil)
    return true
end
