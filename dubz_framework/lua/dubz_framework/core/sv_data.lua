DFW.Data = DFW.Data or {}
local Data = DFW.Data
local ROOT = "dubz_framework"

local function cleanName(name)
    name = string.lower(tostring(name or ""))
    name = string.gsub(name, "[^%w_%-/]", "_")
    name = string.gsub(name, "%.%.", "_")
    name = string.Trim(name, "/")
    if name == "" then return nil end
    return name
end

local function ensureDirectory(path)
    local directory = ""
    local parts = string.Explode("/", string.GetPathFromFilename(path))
    for _, part in ipairs(parts) do
        if part ~= "" then
            directory = directory == "" and part or (directory .. "/" .. part)
            if not file.IsDir(directory, "DATA") then file.CreateDir(directory) end
        end
    end
end

function Data.Path(name, suffix)
    name = cleanName(name)
    if not name then return nil end
    return ROOT .. "/" .. name .. (suffix or "") .. ".json"
end

function Data.Exists(name)
    local path = Data.Path(name)
    return path ~= nil and file.Exists(path, "DATA")
end

local function decode(raw)
    if not raw or raw == "" then return nil end
    local decoded = util.JSONToTable(raw)
    return istable(decoded) and decoded or nil
end

function Data.ReadJSON(name, fallback)
    local path = Data.Path(name)
    if not path then return fallback, "invalid_name" end
    if not file.Exists(path, "DATA") then return fallback, "missing" end

    local raw = file.Read(path, "DATA")
    local decoded = decode(raw)
    if decoded then return decoded, "ok" end

    ensureDirectory(path)
    file.Write(Data.Path(name, ".corrupt"), raw or "")
    DFW.Util.Warn("Unreadable data file " .. path .. " was preserved as .corrupt.json")

    local previous = Data.Path(name, ".previous")
    if file.Exists(previous, "DATA") then
        local recovered = decode(file.Read(previous, "DATA"))
        if recovered then
            DFW.Util.Warn("Recovered " .. path .. " from its previous copy")
            return recovered, "recovered"
        end
    end

    return fallback, "corrupt"
end

function Data.WriteJSON(name, data)
    local path = Data.Path(name)
    if not path then return false, "invalid_name" end
    ensureDirectory(path)

    local encoded = util.TableToJSON(data or {}, true)
    if not encoded then return false, "encode_failed" end

    local temporary = Data.Path(name, ".tmp")
    file.Write(temporary, encoded)
    if file.Read(temporary, "DATA") ~= encoded then
        file.Delete(temporary)
        return false, "temporary_write_failed"
    end

    local old
    if file.Exists(path, "DATA") then
        old = file.Read(path, "DATA")
        if old and old ~= "" then file.Write(Data.Path(name, ".previous"), old) end
        file.Delete(path)
    end

    if not file.Rename(temporary, path) then
        if old then file.Write(path, old) end
        return false, "replace_failed"
    end

    return true
end

function Data.Delete(name)
    local path = Data.Path(name)
    if path and file.Exists(path, "DATA") then file.Delete(path) return true end
    return false
end
