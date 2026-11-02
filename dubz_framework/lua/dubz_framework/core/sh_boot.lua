DFW.Boot = DFW.Boot or {}

local Boot = DFW.Boot
local DONATE_URL = "https://ko-fi.com/bdubz420"
local PREFIX = Color(190, 86, 82)
local TEXT = color_white
local DIM = Color(150, 150, 150)
local GOOD = Color(120, 200, 120)
local BAD = Color(232, 84, 84)
local WARN = Color(230, 190, 90)
local RULE = string.rep("=", 64)

local BANNER = {
    "d8888b. db    db d8888b. d88888D ",
    "88  `8D 88    88 88  `8D YP  d8' ",
    "88   88 88    88 88oooY'    d8'  ",
    "88   88 88    88 88~~~b.   d8'   ",
    "88  .8D 88b  d88 88   8D  d8' db ",
    "Y8888D' ~Y8888P' Y8888P' d88888P   F R A M E W O R K"
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

local function reportAddons()
    local addons = sorted(DFW.Addons and DFW.Addons.GetAll and DFW.Addons.GetAll())

    line(TEXT, "Addons (" .. #addons .. ")")

    for _, row in ipairs(addons) do
        local state = tostring(row.entry.state or "loaded")

        line(state == "loaded" and GOOD or BAD, string.format("  %-34s v%-10s %s", tostring(row.entry.name or row.id), tostring(row.entry.version or "?"), state))
    end
end

local function moduleLine(id, entry)
    local state = tostring(DFW.Modules.GetState and DFW.Modules.GetState(id) or "?")
    local color = GOOD
    local extra = ""

    if entry.failure then
        color, extra = BAD, " - " .. tostring(entry.failure)
    elseif entry.waitingFor then
        color, extra = WARN, " - waiting for " .. tostring(entry.waitingFor)
    elseif string.find(state, "disab", 1, true) or state == "off" or state == "stopped" then
        color = DIM
    end

    line(color, string.format("  %-34s %-10s%s", tostring(entry.name or id), state, extra))
end

local function reportModules()
    local modules = sorted(DFW.Modules and DFW.Modules.GetAll and DFW.Modules.GetAll())

    line(TEXT, "Modules (" .. #modules .. ")")

    for _, row in ipairs(modules) do moduleLine(row.id, row.entry) end
end

local function reportPackages()
    local stats = DFW.Packages.GetStats()
    local packages = DFW.Packages.GetAll()

    line(stats.failed > 0 and BAD or GOOD, string.format("Packages: %d loaded, %d failed, %d pending", stats.loaded or 0, stats.failed or 0, stats.pending or 0))

    for _, id in ipairs(DFW.Util.SortedKeys(packages)) do
        local state = packages[id]

        if state.state ~= "loaded" then
            line(state.state == "failed" and BAD or WARN, string.format("  %-30s %s%s", id, tostring(state.state), state.reason and (" (" .. tostring(state.reason) .. ")") or ""))
        end
    end
end

local function reportWarnings()
    local warnings = DFW.BootWarnings or {}

    if #warnings == 0 then
        line(GOOD, "Warnings: none")
        return
    end

    line(WARN, "Warnings (" .. #warnings .. ")")

    for _, message in ipairs(warnings) do line(WARN, "  " .. message) end
end

local function reportNotes()
    for _, note in ipairs(DFW.BootNotes or {}) do line(DIM, note) end
end

function Boot.Report()
    if not (DFW and DFW.Ready) or not SERVER or DFW.BootReported then return end

    MsgC(PREFIX, "\n" .. RULE .. "\n")

    for _, text in ipairs(BANNER) do MsgC(PREFIX, "  " .. text .. "\n") end

    MsgC(PREFIX, RULE .. "\n")
    line(TEXT, string.format("v%s  (API %d)  |  gamemode %s  |  map %s", DFW.Version, DFW.APIVersion, engine.ActiveGamemode(), game.GetMap()))
    reportNotes()
    reportAddons()
    reportModules()
    reportPackages()
    reportWarnings()
    line(DIM, "Open the admin menu with !dubzconfig. Self test: dfw_selftest. Status: dfw_status.")
    MsgC(PREFIX, RULE .. "\n")
    line(TEXT, "Made by BDubz. If these scripts help your server, you can support")
    line(TEXT, "their development here, entirely optional and always appreciated:")
    line(GOOD, "  " .. DONATE_URL)
    MsgC(PREFIX, RULE .. "\n\n")

    DFW.BootReported = true
end
