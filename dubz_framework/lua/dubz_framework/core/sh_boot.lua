DFW.Boot = DFW.Boot or {}

local Boot = DFW.Boot
local DONATE_URL = "https://ko-fi.com/bdubz420"
local REPORT_DELAY = 4
local PREFIX = Color(190, 86, 82)
local TEXT = color_white
local DIM = Color(150, 150, 150)
local GOOD = Color(120, 200, 120)
local BAD = Color(232, 84, 84)
local WARN = Color(230, 190, 90)
local RULE = string.rep("=", 64)

local BANNER = {
    " ____  _   _ ____ _______",
    "|  _ \\| | | | __ )__  / /",
    "| | | | | | |  _ \\ / / /",
    "| |_| | |_| | |_) / /_/ ",
    "|____/ \\___/|____/____(_) F R A M E W O R K"
}

local function line(color, text)
    MsgC(PREFIX, "[Dubz Framework] ", color, text .. "\n")
end

local function sorted(map)
    local list = {}

    for id, entry in pairs(map or {}) do list[#list + 1] = {id = id, entry = entry} end

    table.sort(list, function(a, b) return tostring(a.entry.name or a.id) < tostring(b.entry.name or b.id) end)

    return list
end

local function moduleEnabled(id, entry)
    if DFW.Bind and DFW.Bind.Enabled then
        local ok, value = pcall(DFW.Bind.Enabled, id)

        if ok then return value == true end
    end

    return entry.enabled ~= false
end

local function reportAddons()
    local addons = sorted(DFW.Addons and DFW.Addons.GetAll and DFW.Addons.GetAll())

    line(TEXT, "Installed addons (" .. #addons .. ")")

    for _, row in ipairs(addons) do
        local state = tostring(row.entry.state or "loaded")

        line(state == "loaded" and GOOD or WARN, string.format("  %-34s v%-10s %s", tostring(row.entry.name or row.id), tostring(row.entry.version or "?"), state))
    end
end

local function reportModules()
    local modules = sorted(DFW.Modules and DFW.Modules.GetAll and DFW.Modules.GetAll())
    local enabled = 0

    for _, row in ipairs(modules) do
        if moduleEnabled(row.id, row.entry) then enabled = enabled + 1 end
    end

    line(TEXT, "Modules (" .. enabled .. " enabled of " .. #modules .. ")")

    for _, row in ipairs(modules) do
        local on = moduleEnabled(row.id, row.entry)

        line(on and GOOD or DIM, string.format("  %-34s %s", tostring(row.entry.name or row.id), on and "on" or "off"))
    end
end

local function reportPackages()
    local stats = DFW.Packages and DFW.Packages.GetStats and DFW.Packages.GetStats() or {loaded = 0, failed = 0}

    line(stats.failed > 0 and BAD or GOOD, string.format("Packages: %d loaded, %d failed", stats.loaded or 0, stats.failed or 0))

    if stats.failed > 0 then line(WARN, "  Run dfw_status for the reason each package failed.") end
end

function Boot.Report()
    if not (DFW and DFW.Ready) then return end

    MsgC(PREFIX, "\n" .. RULE .. "\n")

    for _, text in ipairs(BANNER) do MsgC(PREFIX, text .. "\n") end

    MsgC(PREFIX, RULE .. "\n")
    line(TEXT, string.format("v%s  (API %d)  |  gamemode %s  |  map %s", DFW.Version, DFW.APIVersion, engine.ActiveGamemode(), game.GetMap()))
    reportAddons()
    reportModules()
    reportPackages()
    line(DIM, "Open the admin menu with !dubzconfig. Self test: dfw_selftest. Status: dfw_status.")
    MsgC(PREFIX, RULE .. "\n")
    line(TEXT, "Made by BDubz. If these scripts help your server, you can support")
    line(TEXT, "their development here, entirely optional and always appreciated:")
    line(GOOD, "  " .. DONATE_URL)
    MsgC(PREFIX, RULE .. "\n\n")
end

if SERVER then timer.Simple(REPORT_DELAY, Boot.Report) end
