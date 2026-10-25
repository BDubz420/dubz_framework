-- Console and chat entry points. The server owns the access decision; the
-- client commands simply ask the server to open the menu.
if SERVER then
    hook.Add("PlayerSay", "DFW.Config.ChatCommand", function(ply, text)
        text = string.Trim(string.lower(text))
        if text == "!dubzconfig" or text == "!dfw" or text == "/dubzconfig" then
            if not DFW.Config.OpenFor(ply) then ply:ChatPrint("[Dubz Framework] You do not have access to the configuration menu.") end
            return ""
        end
    end)

    concommand.Add("dfw_status", function(ply)
        if IsValid(ply) and not DFW.Access.CanConfigure(ply) then return end
        DFW.Status.Print(IsValid(ply) and ply or nil)
    end)
else
    local function requestOpen() DFW.Config.RequestOpen() end
    concommand.Add("dfw_config", requestOpen)
    concommand.Add("dfw_config_open", requestOpen)
    concommand.Add("dfw_status_cl", function() DFW.Status.Print() end)
end

DFW.Status = DFW.Status or {}

function DFW.Status.Print(ply)
    local lines = {}
    local function add(text) lines[#lines + 1] = text end

    add(string.format("%s v%s (API %d) [%s]", DFW.Name, DFW.Version, DFW.APIVersion, SERVER and "server" or "client"))
    local stats = DFW.Packages.GetStats()
    add(string.format("Packages: %d loaded, %d failed, %d pending", stats.loaded, stats.failed, stats.pending))

    for _, id in ipairs(DFW.Util.SortedKeys(DFW.Packages.GetAll())) do
        local state = DFW.Packages.GetAll()[id]
        add(string.format("  package %-28s %s%s", id, state.state, state.reason and (" (" .. state.reason .. ")") or ""))
    end

    local modules = DFW.Modules.GetAll()
    add("Modules: " .. table.Count(modules))
    for _, id in ipairs(DFW.Util.SortedKeys(modules)) do
        local module = modules[id]
        local extra = module.failure and (" - " .. module.failure) or (module.waitingFor and (" - waiting for " .. module.waitingFor) or "")
        add(string.format("  module  %-28s %-9s addon=%s%s", id, DFW.Modules.GetState(id), module.addon, extra))
    end

    for _, line in ipairs(lines) do
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, line .. "\n") else Msg(line .. "\n") end
    end
end
