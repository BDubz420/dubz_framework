-- Dubz Framework bootstrap. Systems live under lua/dubz_framework/{core,ui,menu}.
-- Package manifests survive Lua auto-refresh, so independent module addons can
-- be reloaded without relying on Garry's Mod addon autorun order.
local retainedPackages = {}

if DFW then
    if DFW.Modules and DFW.Modules.StopAll then
        pcall(DFW.Modules.StopAll, "framework_reload")
    end

    if DFW.Packages and DFW.Packages.ExportManifests then
        for _, manifest in ipairs(DFW.Packages.ExportManifests()) do
            retainedPackages[#retainedPackages + 1] = manifest
        end
    end

    for _, manifest in ipairs(DFW.PendingPackages or {}) do
        retainedPackages[#retainedPackages + 1] = manifest
    end
end

DFW = {
    Name = "Dubz Framework",
    Version = "0.3.0",
    APIVersion = 1,
    Root = "dubz_framework",
    Ready = false,
    DebugEnabled = false,
    PendingPackages = retainedPackages
}

-- Every framework file. Checked at boot so an incomplete upload or install is
-- reported by name instead of surfacing later as a confusing nil error.
local EXPECTED_FILES = {
    "dubz_framework/core/cl_50_network.lua",
    "dubz_framework/core/sh_00_util.lua",
    "dubz_framework/core/sh_05_registry.lua",
    "dubz_framework/core/sh_10_access.lua",
    "dubz_framework/core/sh_15_net.lua",
    "dubz_framework/core/sh_20_addons.lua",
    "dubz_framework/core/sh_25_packages.lua",
    "dubz_framework/core/sh_30_modules.lua",
    "dubz_framework/core/sh_35_themes.lua",
    "dubz_framework/core/sh_40_config.lua",
    "dubz_framework/core/sh_45_bind.lua",
    "dubz_framework/core/sh_47_collections.lua",
    "dubz_framework/core/sv_52_collections.lua",
    "dubz_framework/core/cl_52_collections.lua",
    "dubz_framework/core/sh_60_commands.lua",
    "dubz_framework/core/sh_90_selftest.lua",
    "dubz_framework/core/sv_35_data.lua",
    "dubz_framework/core/sv_41_persistence.lua",
    "dubz_framework/core/sv_50_network.lua",
    "dubz_framework/menu/cl_collection_editor.lua",
    "dubz_framework/menu/cl_collection_picker.lua",
    "dubz_framework/menu/cl_config_menu.lua",
    "dubz_framework/menu/cl_selftest_ui.lua",
    "dubz_framework/menu/cl_ui_demo.lua",
    "dubz_framework/ui/cl_00_fonts.lua",
    "dubz_framework/ui/cl_05_theme.lua",
    "dubz_framework/ui/cl_10_anim.lua",
    "dubz_framework/ui/cl_15_draw.lua",
    "dubz_framework/ui/cl_20_icons.lua",
    "dubz_framework/ui/cl_30_frame.lua",
    "dubz_framework/ui/cl_31_button.lua",
    "dubz_framework/ui/cl_32_inputs.lua",
    "dubz_framework/ui/cl_33_popups.lua",
    "dubz_framework/ui/cl_34_layout.lua",
    "dubz_framework/ui/cl_35_overlays.lua",
    "dubz_framework/ui/cl_36_game.lua",
    "dubz_framework/ui/cl_37_items.lua"
}

local function reportMissingFiles()
    local missing = {}
    for _, luaPath in ipairs(EXPECTED_FILES) do
        if not file.Exists(luaPath, "LUA") then missing[#missing + 1] = luaPath end
    end
    if #missing > 0 then
        MsgC(Color(232, 84, 84), "[Dubz Framework] " .. #missing .. " framework file(s) are missing from the " .. (SERVER and "server" or "client") .. " - the upload or install is incomplete:\n")
        for _, luaPath in ipairs(missing) do MsgC(Color(232, 84, 84), "[Dubz Framework]   missing: " .. luaPath .. "\n") end
    end
    return #missing
end

local function bootPrint(message)
    MsgC(Color(190, 86, 82), "[Dubz Framework] ", color_white, message .. "\n")
end

local function collect(path, output)
    local files, directories = file.Find(path .. "/*", "LUA")
    table.sort(files)
    table.sort(directories)

    for _, name in ipairs(files) do
        if string.EndsWith(name, ".lua") then
            output[#output + 1] = path .. "/" .. name
        end
    end

    for _, name in ipairs(directories) do
        collect(path .. "/" .. name, output)
    end
end

local function realmPrefix(luaPath)
    return string.sub(string.GetFileFromFilename(luaPath), 1, 3)
end

-- Realm files load shared first, then the current realm, each in name order.
local function loadTree(path)
    local files = {}
    collect(path, files)
    table.sort(files)

    if SERVER then
        for _, luaPath in ipairs(files) do
            local prefix = realmPrefix(luaPath)
            if prefix == "sh_" or prefix == "cl_" then AddCSLuaFile(luaPath) end
        end
    end

    for _, wantedPrefix in ipairs({"sh_", SERVER and "sv_" or "cl_"}) do
        for _, luaPath in ipairs(files) do
            if realmPrefix(luaPath) == wantedPrefix then
                -- Wrapped in a closure so include() resolves paths from this file, not from pcall.
                local ok, err = xpcall(function() include(luaPath) end, function(e) return tostring(e) end)
                if not ok then
                    MsgC(Color(232, 84, 84), "[Dubz Framework] ERROR loading " .. luaPath .. ": " .. tostring(err) .. "\n")
                end
            end
        end
    end
end

-- Icons are plain client resources; send them so clients never see the error texture.
local function addResourceTree(path)
    local total = 0
    local files, directories = file.Find(path .. "/*", "GAME")
    for _, name in ipairs(files or {}) do
        local extension = string.lower(string.GetExtensionFromFilename(name) or "")
        if extension == "png" or extension == "vmt" or extension == "vtf" then
            resource.AddFile(path .. "/" .. name)
            total = total + 1
        end
    end
    for _, directory in ipairs(directories or {}) do
        total = total + addResourceTree(path .. "/" .. directory)
    end
    return total
end

bootPrint("Booting v" .. DFW.Version .. " (API " .. DFW.APIVersion .. ")")
reportMissingFiles()
loadTree(DFW.Root .. "/core")

-- Core must be fully loaded before anything else runs; stop with a clear message otherwise.
local coreNamespaces = {"Util", "Registry", "Access", "Net", "Addons", "Packages", "Modules", "Themes", "Config"}
for _, name in ipairs(coreNamespaces) do
    if DFW[name] == nil then
        MsgC(Color(232, 84, 84), "[Dubz Framework] FATAL: DFW." .. name .. " did not load, so the framework cannot start. Check the lines above for missing files or Lua errors.\n")
        return
    end
end

DFW.Addons.Register({
    id = "dubz_framework",
    name = DFW.Name,
    version = DFW.Version,
    api = DFW.APIVersion,
    state = "loaded"
})

DFW.Modules.Register({
    id = "dubz_core",
    addon = "dubz_framework",
    name = "Framework Core",
    version = DFW.Version,
    icon = "navigation/settings",
    description = "Themes, interface behaviour and diagnostics for every Dubz Framework module.",
    core = true,
    enabled = true,
    OnConfigChanged = function(_, key, value)
        if key == "debug" then DFW.DebugEnabled = value == true end
    end
})

DFW.Config.Register("dubz_core", {
    {key = "theme", label = "Theme", type = "choice", default = DFW.Themes.DefaultId, choices = DFW.Themes.GetIds, public = true, order = 10, group = "Appearance",
        description = "Colour scheme used by every Dubz Framework window and HUD element."},
    {key = "use_custom_accent", label = "Custom Accent", type = "bool", default = false, public = true, order = 20, group = "Appearance",
        description = "Replace the theme's accent colour with the one below."},
    {key = "accent", label = "Accent Colour", type = "color", default = {r = 190, g = 86, b = 82, a = 255}, public = true, order = 30, group = "Appearance"},
    {key = "ui_sounds", label = "Interface Sounds", type = "bool", default = true, public = true, order = 40, group = "Interface",
        description = "Play a soft sound when hovering buttons."},
    {key = "debug", label = "Debug Logging", type = "bool", default = false, order = 50, group = "Diagnostics",
        description = "Print extra framework diagnostics to the console."}
})
DFW.DebugEnabled = DFW.Config.Get("dubz_core", "debug", false) == true

if SERVER then
    local iconCount = addResourceTree("materials/dubz_framework/icons")
    bootPrint("Queued " .. iconCount .. " icon resources for clients")
end

-- UI first, so package client files can use DFW.UI the moment they load.
loadTree(DFW.Root .. "/ui")
loadTree(DFW.Root .. "/menu")
DFW.Packages.DrainPending()

DFW.Ready = true
DFW.Modules.StartAll()
hook.Run("DFW_FrameworkLoaded", DFW.Version, DFW.APIVersion)

-- Autorun files from other addons may still run later in this frame. Resolve
-- missing package dependencies only after every addon has had a chance to submit.
timer.Simple(0, function()
    if DFW and DFW.Packages then DFW.Packages.FinalizePending() end
end)

local packageStats = DFW.Packages.GetStats()
bootPrint(string.format(
    "Ready (%d addons, %d modules, %d external packages, %d failed)",
    table.Count(DFW.Addons.GetAll()),
    table.Count(DFW.Modules.GetAll()),
    packageStats.loaded,
    packageStats.failed
))
