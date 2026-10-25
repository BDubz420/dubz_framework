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
    Version = "0.4.0",
    APIVersion = 1,
    Root = "dubz_framework",
    Ready = false,
    DebugEnabled = false,
    PendingPackages = retainedPackages
}

local LOAD_ORDER = {
    core = {
        "sh_util", "sh_registry", "sh_access", "sh_net", "sh_addons", "sh_packages", "sh_modules", "sh_themes",
        "sh_config", "sh_bind", "sh_collections", "sh_commands", "sh_selftest", "sh_boot",
        "sv_data", "sv_persistence", "sv_network", "sv_collections",
        "cl_network", "cl_collections"
    },
    ui = {
        "cl_fonts", "cl_theme", "cl_anim", "cl_draw", "cl_icons", "cl_frame", "cl_button", "cl_inputs",
        "cl_popups", "cl_layout", "cl_overlays", "cl_game", "cl_items"
    },
    menu = {
        "cl_collection_editor", "cl_collection_picker", "cl_config_menu", "cl_selftest_ui", "cl_ui_demo"
    }
}

local function luaPath(directory, name)
    return DFW.Root .. "/" .. directory .. "/" .. name .. ".lua"
end

local function reportMissingFiles()
    local missing = {}
    for directory, names in pairs(LOAD_ORDER) do
        for _, name in ipairs(names) do
            local path = luaPath(directory, name)
            if not file.Exists(path, "LUA") then missing[#missing + 1] = path end
        end
    end
    table.sort(missing)
    if #missing > 0 then
        MsgC(Color(232, 84, 84), "[Dubz Framework] " .. #missing .. " framework file(s) are missing from the " .. (SERVER and "server" or "client") .. " - the upload or install is incomplete:\n")
        for _, path in ipairs(missing) do MsgC(Color(232, 84, 84), "[Dubz Framework]   missing: " .. path .. "\n") end
    end
    return #missing
end

local function bootPrint(message)
    MsgC(Color(190, 86, 82), "[Dubz Framework] ", color_white, message .. "\n")
end

local function realmPrefix(name)
    return string.sub(name, 1, 3)
end

local function loadDirectory(directory)
    local names = LOAD_ORDER[directory]

    if SERVER then
        for _, name in ipairs(names) do
            local prefix = realmPrefix(name)
            if prefix == "sh_" or prefix == "cl_" then AddCSLuaFile(luaPath(directory, name)) end
        end
    end

    for _, wantedPrefix in ipairs({"sh_", SERVER and "sv_" or "cl_"}) do
        for _, name in ipairs(names) do
            if realmPrefix(name) == wantedPrefix then
                local path = luaPath(directory, name)
                local ok, err = xpcall(function() include(path) end, function(e) return tostring(e) end)
                if not ok then
                    MsgC(Color(232, 84, 84), "[Dubz Framework] ERROR loading " .. path .. ": " .. tostring(err) .. "\n")
                end
            end
        end
    end
end

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
loadDirectory("core")

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

loadDirectory("ui")
loadDirectory("menu")
DFW.Packages.DrainPending()

DFW.Ready = true
DFW.Modules.StartAll()
hook.Run("DFW_FrameworkLoaded", DFW.Version, DFW.APIVersion)

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
