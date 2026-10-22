AcmeStarter = AcmeStarter or {}

local ROOT = "acme_starter/"
local LOCAL_FILES = {"sh_config.lua"}
local PACKAGE_FILES = {"sh_framework.lua", "sv_announce.lua"}

local function missingFiles()
    local missing = {}

    for _, list in ipairs({LOCAL_FILES, PACKAGE_FILES}) do
        for _, name in ipairs(list) do
            if not file.Exists(ROOT .. name, "LUA") then missing[#missing + 1] = name end
        end
    end

    return missing
end

if SERVER then
    concommand.Add("acme_starter_check", function(ply)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end

        for _, list in ipairs({LOCAL_FILES, PACKAGE_FILES}) do
            for _, name in ipairs(list) do
                local state = file.Exists(ROOT .. name, "LUA") and "found" or "MISSING"
                local text = "[AcmeStarter] lua/" .. ROOT .. name .. ": " .. state

                if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, text .. "\n") else print(text) end
            end
        end
    end)
end

local missing = missingFiles()

if #missing > 0 then
    MsgC(Color(255, 80, 80), "[AcmeStarter] ", color_white, "missing files in lua/" .. ROOT .. ": " .. table.concat(missing, ", ") .. ". Upload the whole addon.\n")
    return
end

if SERVER then
    for _, name in ipairs(LOCAL_FILES) do AddCSLuaFile(ROOT .. name) end
end

for _, name in ipairs(LOCAL_FILES) do include(ROOT .. name) end

local files = {}

for _, name in ipairs(PACKAGE_FILES) do files[#files + 1] = ROOT .. name end

DFW = DFW or {}
DFW.PendingPackages = DFW.PendingPackages or {}

local manifest = {
    id = "acme_starter",
    name = "Acme Starter",
    version = "1.0.0",
    api = 1,
    dependencies = {"dubz_framework"},
    files = files
}

if DFW.Packages and DFW.Packages.Submit then
    DFW.Packages.Submit(manifest)
else
    DFW.PendingPackages[#DFW.PendingPackages + 1] = manifest
end
