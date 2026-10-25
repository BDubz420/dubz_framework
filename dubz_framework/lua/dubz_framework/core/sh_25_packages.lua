-- External package loader. A module addon owns its files and submits one
-- explicit manifest from lua/autorun; the framework never scans another addon.
DFW.Packages = DFW.Packages or {}

local manifests = {}
local states = {}
local activePackage
local resolving = false

local function validLuaPath(path)
    if not isstring(path) or path == "" then return false end
    if string.find(path, "..", 1, true) or string.StartWith(path, "/") or string.find(path, "\\", 1, true) then
        return false
    end
    if not string.EndsWith(path, ".lua") then return false end
    local prefix = string.sub(string.GetFileFromFilename(path), 1, 3)
    return prefix == "sh_" or prefix == "sv_" or prefix == "cl_"
end

local function normalize(manifest)
    if not istable(manifest) or not DFW.Util.IsIdentifier(manifest.id) then
        return nil, "invalid_id"
    end
    if not isstring(manifest.name) or manifest.name == "" then
        return nil, "invalid_name"
    end
    if not istable(manifest.files) or #manifest.files == 0 then
        return nil, "invalid_files"
    end

    local result = table.Copy(manifest)
    result.version = tostring(result.version or "0.0.0")
    result.api = tonumber(result.api) or 1
    if result.api < 1 or result.api ~= math.floor(result.api) then return nil, "invalid_api" end
    result.dependencies = result.dependencies or {"dubz_framework"}
    if not istable(result.dependencies) then return nil, "invalid_dependencies" end

    local seenDependencies = {}
    for _, dependency in ipairs(result.dependencies) do
        if not DFW.Util.IsIdentifier(dependency) or dependency == result.id or seenDependencies[dependency] then
            return nil, "invalid_dependency"
        end
        seenDependencies[dependency] = true
    end

    local seenFiles = {}
    for _, luaPath in ipairs(result.files) do
        if not validLuaPath(luaPath) or seenFiles[luaPath] then return nil, "invalid_file" end
        seenFiles[luaPath] = true
    end

    return result
end

local function dependenciesLoaded(manifest)
    for _, dependency in ipairs(manifest.dependencies) do
        local addon = DFW.Addons.Get(dependency)
        if not addon or addon.state ~= "loaded" then return false, dependency end
    end
    return true
end

-- A failed package must not leave half-registered modules or config behind.
local function rollback(manifestId)
    if DFW.Modules and DFW.Modules.RemoveByAddon then DFW.Modules.RemoveByAddon(manifestId) end
end

local function includeManifest(manifest)
    if manifest.api > DFW.APIVersion then return false, "requires_api:" .. manifest.api end

    for _, luaPath in ipairs(manifest.files) do
        if not file.Exists(luaPath, "LUA") then
            return false, "missing_file:" .. luaPath
        end
    end

    local ok, reason = DFW.Addons.Register({
        id = manifest.id,
        name = manifest.name,
        version = manifest.version,
        api = manifest.api,
        state = "loading",
        description = manifest.description
    })
    if not ok then return false, "addon_registration:" .. tostring(reason) end

    if SERVER then
        for _, luaPath in ipairs(manifest.files) do
            local prefix = string.sub(string.GetFileFromFilename(luaPath), 1, 3)
            if prefix == "sh_" or prefix == "cl_" then AddCSLuaFile(luaPath) end
        end
    end

    activePackage = manifest.id
    for _, wantedPrefix in ipairs({"sh_", SERVER and "sv_" or "cl_"}) do
        for _, luaPath in ipairs(manifest.files) do
            local prefix = string.sub(string.GetFileFromFilename(luaPath), 1, 3)
            if prefix == wantedPrefix then
                local included, includeError = xpcall(function() include(luaPath) end, function(e) return tostring(e) end)
                if not included then
                    activePackage = nil
                    rollback(manifest.id)
                    DFW.Addons.SetState(manifest.id, "failed", "include_failed:" .. luaPath)
                    return false, "include_failed:" .. tostring(includeError)
                end
            end
        end
    end
    activePackage = nil

    DFW.Addons.SetState(manifest.id, "loaded")
    states[manifest.id] = {state = "loaded"}
    hook.Run("DFW_PackageLoaded", manifest.id)

    if DFW.Ready then
        timer.Simple(0, function()
            if DFW and DFW.Modules then DFW.Modules.StartAll() end
        end)
    end

    return true
end

local function resolvePending(markMissing)
    if resolving then return end
    resolving = true

    local progressed = true
    while progressed do
        progressed = false
        local ids = table.GetKeys(manifests)
        table.sort(ids)

        for _, id in ipairs(ids) do
            if states[id] and states[id].state == "pending" then
                local available = dependenciesLoaded(manifests[id])
                if available then
                    local ok, reason = includeManifest(manifests[id])
                    if not ok then
                        states[id] = {state = "failed", reason = reason}
                        DFW.Util.Warn("Package " .. id .. " failed: " .. tostring(reason))
                    end
                    progressed = true
                end
            end
        end
    end

    if markMissing then
        for id, state in pairs(states) do
            if state.state == "pending" then
                local _, dependency = dependenciesLoaded(manifests[id])
                state.state = "failed"
                state.reason = "missing_dependency:" .. tostring(dependency)
                DFW.Util.Warn("Package " .. id .. " disabled: " .. state.reason)
            end
        end
    end

    resolving = false
end

local function reviveDependencyFailures()
    for _, state in pairs(states) do
        if state.state == "failed" and isstring(state.reason) and string.StartWith(state.reason, "missing_dependency:") then
            state.state = "pending"
            state.reason = nil
        end
    end
end

function DFW.Packages.GetActiveId()
    return activePackage
end

function DFW.Packages.Submit(manifest)
    local normalized, reason = normalize(manifest)
    if not normalized then
        DFW.Util.Warn("Rejected package manifest: " .. tostring(reason))
        return false, reason
    end
    if manifests[normalized.id] then return false, "duplicate" end

    manifests[normalized.id] = normalized
    states[normalized.id] = {state = "pending"}

    local available = dependenciesLoaded(normalized)
    if available then
        local ok, loadReason = includeManifest(normalized)
        if not ok then
            states[normalized.id] = {state = "failed", reason = loadReason}
            DFW.Util.Warn("Package " .. normalized.id .. " failed: " .. tostring(loadReason))
        else
            reviveDependencyFailures()
            resolvePending(false)
        end
        return ok, loadReason
    end

    return true, "pending"
end

function DFW.Packages.DrainPending()
    local queued = DFW.PendingPackages or {}
    DFW.PendingPackages = {}

    table.sort(queued, function(a, b)
        return tostring(a and a.id or "") < tostring(b and b.id or "")
    end)

    for _, manifest in ipairs(queued) do
        local ok, reason = DFW.Packages.Submit(manifest)
        if not ok and reason ~= "duplicate" then
            DFW.Util.Warn("Could not queue package: " .. tostring(reason))
        end
    end

    resolvePending(false)
end

function DFW.Packages.FinalizePending()
    resolvePending(true)
end

function DFW.Packages.ExportManifests()
    local output = {}
    for _, manifest in pairs(manifests) do output[#output + 1] = table.Copy(manifest) end
    return output
end

function DFW.Packages.GetAll()
    return table.Copy(states)
end

function DFW.Packages.GetStats()
    local result = {loaded = 0, failed = 0, pending = 0}
    for _, state in pairs(states) do
        if result[state.state] ~= nil then result[state.state] = result[state.state] + 1 end
    end
    return result
end
