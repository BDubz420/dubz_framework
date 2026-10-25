DFW.Bind = DFW.Bind or {}
local Bind = DFW.Bind

local KEY_NAMES = {}
for i = 1, 12 do KEY_NAMES[#KEY_NAMES + 1] = "F" .. i end
for c = string.byte("A"), string.byte("Z") do KEY_NAMES[#KEY_NAMES + 1] = string.char(c) end
for i = 0, 9 do KEY_NAMES[#KEY_NAMES + 1] = tostring(i) end
for _, name in ipairs({"INSERT", "HOME", "END", "PAGEUP", "PAGEDOWN", "DELETE", "TAB", "CAPSLOCK", "SPACE", "BACKQUOTE"}) do
    KEY_NAMES[#KEY_NAMES + 1] = name
end

local function keyCode(name) return _G["KEY_" .. tostring(name)] end

local function keyName(code)
    for _, name in ipairs(KEY_NAMES) do
        if keyCode(name) == code then return name end
    end
end

function Bind.GetKeyNames() return table.Copy(KEY_NAMES) end

local function snake(path)
    local text = string.gsub(path, "%.", "_")
    text = string.gsub(text, "(%u)", "_%1")
    text = string.gsub(text, "^_", "")
    return string.lower(text)
end

local function split(path)
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do parts[#parts + 1] = tonumber(part) or part end
    return parts
end

local function getPath(target, parts)
    local node = target
    for i = 1, #parts - 1 do
        node = node[parts[i]]
        if node == nil then return nil end
    end
    return node, parts[#parts]
end

local function describe(spec, current)
    local field = {
        key = spec.key or snake(spec.path),
        label = spec.label or spec.path,
        description = spec.description,
        group = spec.group or "General",
        order = spec.order,
        public = spec.public ~= false
    }

    if spec.keybind then
        field.type = "choice"
        field.choices = KEY_NAMES
        field.default = keyName(current) or KEY_NAMES[1]
    elseif spec.list then
        field.type = "string"
        field.maxLength = 200
        field.default = table.concat(current or {}, ", ")
    elseif spec.set then
        field.type = "string"
        field.maxLength = spec.maxLength or 240
        local parts = {}
        for name, on in SortedPairs(current or {}) do
            if on then parts[#parts + 1] = name end
        end
        field.default = table.concat(parts, ", ")
    elseif spec.map then
        field.type = "string"
        field.maxLength = 240
        local parts = {}
        for name, number in SortedPairs(current or {}) do parts[#parts + 1] = name .. "=" .. tostring(number) end
        field.default = table.concat(parts, ", ")
    elseif spec.mapText then
        field.type = "string"
        field.maxLength = 240
        local parts = {}
        for name, text in SortedPairs(current or {}) do parts[#parts + 1] = name .. "=" .. tostring(text) end
        field.default = table.concat(parts, ", ")
    elseif spec.choices then
        field.type = "choice"
        field.choices = spec.choices
        field.default = current
    elseif isbool(current) then
        field.type = "bool"
        field.default = current
    elseif isnumber(current) then
        field.type = "number"
        field.default = current
        field.min, field.max, field.decimals = spec.min, spec.max, spec.decimals
        if field.decimals == nil and current ~= math.floor(current) then field.decimals = 2 end
    elseif istable(current) and current.r and current.g and current.b then
        field.type = "color"
        field.default = DFW.Util.ColorToTable(current)
    else
        field.type = "string"
        field.default = tostring(current or "")
        field.maxLength = spec.maxLength or 200
    end

    return field
end

local function convert(spec, value)
    if spec.keybind then return keyCode(value) end
    if spec.list then
        local out = {}
        for item in string.gmatch(tostring(value), "[^,]+") do
            local trimmed = string.Trim(item)
            if trimmed ~= "" then out[#out + 1] = string.lower(trimmed) end
        end
        return out
    end
    if spec.set then
        local out = {}
        for item in string.gmatch(tostring(value), "[^,]+") do
            local trimmed = string.Trim(item)
            if trimmed ~= "" then out[string.lower(trimmed)] = true end
        end
        return out
    end
    if spec.map or spec.mapText then
        local out = {}
        for item in string.gmatch(tostring(value), "[^,]+") do
            local name, rest = string.match(string.Trim(item), "^(.-)%s*=%s*(.+)$")
            if name and name ~= "" then
                if spec.map then
                    local number = tonumber(rest)
                    if number then out[name] = number end
                else
                    out[name] = rest
                end
            end
        end
        return out
    end
    if istable(value) and value.r then return Color(value.r, value.g, value.b, value.a or 255) end
    return value
end

function Bind.Enabled(moduleId)
    return not (DFW and DFW.Modules and DFW.Modules.IsEnabled) or DFW.Modules.IsEnabled(moduleId)
end

function Bind.Module(definition, target, specs, options)
    options = options or {}
    local id = definition.id

    local ok, reason = DFW.Modules.Register(definition)
    if not ok then
        DFW.Util.Warn("Could not register module " .. tostring(id) .. ": " .. tostring(reason))
        return false
    end

    local function registerCollections()
        for _, def in ipairs(options.collections or {}) do
            local collOk, collReason = DFW.Collections.Register(id, def)
            if not collOk then DFW.Util.Warn(id .. ": table '" .. tostring(def.id) .. "' failed: " .. tostring(collReason)) end
        end
    end

    local fields, byKey = {}, {}

    local hoverField
    if options.ui then
        hoverField = {key = "hover_sounds", label = "Hover Sounds", type = "bool", default = true, group = "Interface", order = 9000, public = true,
            description = "Play the soft sound when hovering this script's buttons."}
        fields[#fields + 1] = hoverField
    end
    for index, spec in ipairs(specs) do
        local parts = split(spec.path)
        local node, last = getPath(target, parts)
        if node and node[last] ~= nil then
            local field = describe(spec, node[last])
            field.order = field.order or index * 10
            fields[#fields + 1] = field
            byKey[field.key] = {spec = spec, parts = parts}
        else
            DFW.Util.Warn(id .. ": setting '" .. tostring(spec.path) .. "' does not exist in the addon's config, skipped")
        end
    end

    if #fields > 0 then
        local configOk, configReason = DFW.Config.Register(id, fields)
        if not configOk then
            DFW.Util.Warn("Config for " .. id .. " failed: " .. tostring(configReason))
            return false
        end
    end

    registerCollections()

    local function apply(key)
        local entry = byKey[key]
        if not entry then return end

        local node, last = getPath(target, entry.parts)
        if not node then return end

        node[last] = convert(entry.spec, DFW.Config.Get(id, key))
        if options.OnChange then options.OnChange(entry.spec.path, node[last], key) end
    end

    local function applyAll()
        for key in pairs(byKey) do apply(key) end
    end

    local hookId = "DFW.Bind." .. id
    hook.Add("DFW_ConfigChanged", hookId, function(moduleId, key)
        if moduleId == id then apply(key) end
    end)
    hook.Add("DFW_PublicConfigReceived", hookId, applyAll)
    hook.Add("DFW_ConfigSnapshot", hookId, applyAll)

    applyAll()
    return true
end
