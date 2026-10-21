DFW.SelfTest = DFW.SelfTest or {}
DFW.SelfTest.Extra = DFW.SelfTest.Extra or {}

local TEMP_PREFIX = "dfw_selftest_"

local function newRun()
    local run = {pass = 0, fail = 0, lines = {}}
    function run.check(name, condition, detail)
        if condition then
            run.pass = run.pass + 1
            run.lines[#run.lines + 1] = "[PASS] " .. name
        else
            run.fail = run.fail + 1
            run.lines[#run.lines + 1] = "[FAIL] " .. name .. (detail and (" -> " .. tostring(detail)) or "")
        end
    end
    return run
end

local function cleanup(ids)
    for _, id in ipairs(ids) do
        DFW.Modules.Unregister(id)
        DFW.Modules.Disabled[id] = nil
    end
    if SERVER and DFW.Modules.SaveState then DFW.Modules.SaveState() end
end

local function testContract(run)
    local contract = {
        "Util.IsIdentifier", "Util.SafeCall", "Registry.Create", "Access.CanConfigure",
        "Net.Pool", "Net.Receive", "Addons.Register", "Packages.Submit", "Modules.Register",
        "Modules.SetEnabled", "Modules.StartAll", "Config.Register", "Config.Get", "Config.Set",
        "Config.Reset", "Themes.Register", "Themes.Get"
    }
    for _, path in ipairs(contract) do
        local value = DFW
        for part in string.gmatch(path, "[^.]+") do value = istable(value) and value[part] or nil end
        run.check("API present: DFW." .. path, isfunction(value))
    end
    run.check("framework addon registered and loaded",
        DFW.Addons.Get("dubz_framework") ~= nil and DFW.Addons.Get("dubz_framework").state == "loaded")
    run.check("core module registered", DFW.Modules.Exists("dubz_core"))
end

local function testUtilAndRegistry(run)
    run.check("IsIdentifier accepts snake_case", DFW.Util.IsIdentifier("good_id_1"))
    run.check("IsIdentifier rejects uppercase", not DFW.Util.IsIdentifier("Bad"))
    run.check("IsIdentifier rejects leading digit", not DFW.Util.IsIdentifier("1bad"))
    run.check("DeepEqual compares nested tables", DFW.Util.DeepEqual({a = {1, 2}}, {a = {1, 2}}) and not DFW.Util.DeepEqual({a = 1}, {a = 2}))

    local registry = DFW.Registry.Create(TEMP_PREFIX .. "registry", {validate = function(def) return def.ok == true, "not_ok" end})
    run.check("registry created", registry ~= nil)
    run.check("registry registers valid definition", registry:Register("alpha", {ok = true}))
    run.check("registry rejects duplicate", select(2, registry:Register("alpha", {ok = true})) == "duplicate")
    run.check("registry validator rejects", select(2, registry:Register("beta", {ok = false})) == "not_ok")
    run.check("registry count/order", registry:Count() == 1 and registry:All()[1].ID == "alpha")
    run.check("registry remove", registry:Remove("alpha") and registry:Count() == 0)
end

local function testThemes(run)
    run.check("default theme exists", DFW.Themes.Get("liminal") ~= nil)
    for _, id in ipairs(DFW.Themes.GetIds()) do
        local theme = DFW.Themes.Get(id)
        local complete = true
        for _, key in ipairs(DFW.Themes.GetRequiredColors()) do
            if theme.colors[key] == nil then complete = false end
        end
        run.check("theme '" .. id .. "' defines every colour token", complete)
    end
    local field = DFW.Config.Schema.dubz_core and DFW.Config.Schema.dubz_core.theme
    run.check("core theme setting lists every theme", field ~= nil and #field.choices == #DFW.Themes.GetIds())
end

local function testModules(run)
    local ids = {TEMP_PREFIX .. "a", TEMP_PREFIX .. "b", TEMP_PREFIX .. "c", TEMP_PREFIX .. "d"}
    local order = {}
    local hookName

    run.check("register dependent module first", DFW.Modules.Register({
        id = ids[2], addon = "dubz_framework", name = "Self Test B", dependencies = {ids[1]},
        OnStart = function() order[#order + 1] = "b" end
    }))
    run.check("register dependency second", DFW.Modules.Register({
        id = ids[1], addon = "dubz_framework", name = "Self Test A",
        OnStart = function(self)
            order[#order + 1] = "a"
            hookName = self:AddHook("Think", "probe", function() end)
        end,
        OnStop = function() order[#order + 1] = "stop_a" end
    }))
    run.check("duplicate module rejected", select(2, DFW.Modules.Register({id = ids[1], addon = "dubz_framework", name = "x"})) == "duplicate")
    run.check("unknown addon owner rejected", select(2, DFW.Modules.Register({id = ids[3], addon = "no_such_addon", name = "x"})) == "unknown_addon")

    if DFW.Modules.GamemodeReady() then
        DFW.Modules.StartAll()
        run.check("dependency starts before dependent", order[1] == "a" and order[2] == "b", table.concat(order, ","))
        run.check("module hook registered through AddHook", hookName ~= nil and hook.GetTable().Think[hookName] ~= nil)

        local refused, reason = DFW.Modules.SetEnabled(ids[1], false)
        run.check("cannot disable a module others depend on", refused == false and string.StartWith(tostring(reason), "required_by"), reason)
        run.check("disabling dependent then dependency works", DFW.Modules.SetEnabled(ids[2], false) and DFW.Modules.SetEnabled(ids[1], false))
        run.check("module hooks removed on stop", hook.GetTable().Think == nil or hook.GetTable().Think[hookName] == nil)
        run.check("disabled state reported", DFW.Modules.GetState(ids[1]) == "disabled")
        run.check("re-enable restarts modules", DFW.Modules.SetEnabled(ids[1], true) and DFW.Modules.SetEnabled(ids[2], true) and DFW.Modules.IsStarted(ids[2]))
    else
        run.check("gamemode not loaded yet: lifecycle ordering skipped", true)
    end

    run.check("core module cannot be disabled", select(2, DFW.Modules.SetEnabled("dubz_core", false)) == "core_module")

    DFW.Modules.Register({id = ids[3], addon = "dubz_framework", name = "Self Test C", OnStart = function() error("boom") end})
    DFW.Modules.Register({id = ids[4], addon = "dubz_framework", name = "Self Test D"})
    if DFW.Modules.GamemodeReady() then
        DFW.Modules.StartAll()
        run.check("failing module is isolated", DFW.Modules.GetState(ids[3]) == "failed" and DFW.Modules.IsStarted(ids[4]))
    end

    cleanup(ids)
    run.check("temporary modules removed", not DFW.Modules.Exists(ids[1]) and not DFW.Modules.Exists(ids[3]))
end

local function testConfig(run)
    local id = TEMP_PREFIX .. "config"
    DFW.Modules.Register({id = id, addon = "dubz_framework", name = "Self Test Config"})

    local fields = {
        {key = "flag", label = "Flag", type = "bool", default = true},
        {key = "amount", label = "Amount", type = "number", default = 5, min = 0, max = 10, decimals = 1, public = true},
        {key = "mode", label = "Mode", type = "choice", default = "a", choices = {"a", "b"}},
        {key = "tint", label = "Tint", type = "color", default = {r = 10, g = 20, b = 30, a = 255}},
        {key = "name", label = "Name", type = "string", default = "x", maxLength = 8}
    }

    run.check("config schema registers", DFW.Config.Register(id, fields))
    run.check("duplicate schema rejected", select(2, DFW.Config.Register(id, fields)) == "duplicate")
    run.check("unknown module schema rejected", select(2, DFW.Config.Register("dfw_selftest_missing", fields)) == "unknown_module")
    run.check("invalid default rejected", select(2, DFW.Config.Register(TEMP_PREFIX .. "x", {{key = "n", type = "number", default = "oops"}})) ~= nil)
    run.check("defaults applied", DFW.Config.Get(id, "amount") == 5 and DFW.Config.Get(id, "flag") == true)

    local ok, value = DFW.Config.Set(id, "amount", 99)
    run.check("number clamped to max", ok and value == 10)
    ok, value = DFW.Config.Set(id, "amount", 3.14159)
    run.check("number rounded to decimals", ok and value == 3.1)
    run.check("wrong type rejected", select(2, DFW.Config.Set(id, "amount", "7")) == "invalid_value")
    run.check("NaN rejected", select(2, DFW.Config.Set(id, "amount", 0 / 0)) == "invalid_value")
    run.check("choice outside list rejected", select(2, DFW.Config.Set(id, "mode", "z")) == "invalid_value")
    run.check("string over maxLength rejected", select(2, DFW.Config.Set(id, "name", "123456789")) == "invalid_value")
    run.check("unknown key rejected", select(2, DFW.Config.Set(id, "ghost", 1)) == "unknown_setting")
    ok, value = DFW.Config.Set(id, "tint", {r = 300, g = -5, b = 9})
    run.check("colour normalised", ok and value.r == 255 and value.g == 0 and value.b == 9 and value.a == 255)
    run.check("IsDefault false after change", not DFW.Config.IsDefault(id, "amount"))
    run.check("Reset restores default", DFW.Config.Reset(id, "amount") and DFW.Config.Get(id, "amount") == 5 and DFW.Config.IsDefault(id, "amount"))

    local publicOnly = DFW.Config.Export(true)[id]
    run.check("public export contains only public fields", publicOnly ~= nil and publicOnly.amount ~= nil and publicOnly.flag == nil)

    local changed
    hook.Add("DFW_ConfigChanged", "dfw_selftest_probe", function(moduleId, key) if moduleId == id then changed = key end end)
    DFW.Config.Set(id, "flag", false)
    hook.Remove("DFW_ConfigChanged", "dfw_selftest_probe")
    run.check("DFW_ConfigChanged fires", changed == "flag")

    cleanup({id})
    run.check("config schema removed with module", DFW.Config.Schema[id] == nil and DFW.Config.Values[id] == nil)
end

local function testServer(run)
    local ok = DFW.Data.WriteJSON(TEMP_PREFIX .. "data", {a = 1, nested = {b = "two"}})
    local data, status = DFW.Data.ReadJSON(TEMP_PREFIX .. "data")
    run.check("data write/read round trip", ok and status == "ok" and data.a == 1 and data.nested.b == "two", status)
    DFW.Data.WriteJSON(TEMP_PREFIX .. "data", {a = 2})
    run.check("data keeps previous copy", file.Exists(DFW.Data.Path(TEMP_PREFIX .. "data", ".previous"), "DATA"))
    DFW.Data.Delete(TEMP_PREFIX .. "data")
    DFW.Data.Delete(TEMP_PREFIX .. "data.previous")
    run.check("data missing file reports missing", select(2, DFW.Data.ReadJSON(TEMP_PREFIX .. "data")) == "missing")
    run.check("data name sanitised against traversal", DFW.Data.Path("../../etc/passwd") == "dubz_framework/____etc_passwd.json" or string.find(DFW.Data.Path("../../etc/passwd"), "..", 1, true) == nil)
    run.check("config persistence file is readable", DFW.Config.Save() == true)
end

function DFW.SelfTest.Run()
    local run = newRun()
    DFW.Util.Muted = true
    testContract(run)
    testUtilAndRegistry(run)
    testThemes(run)
    testModules(run)
    testConfig(run)
    if SERVER then testServer(run) end
    for _, extra in ipairs(DFW.SelfTest.Extra) do
        local ok, err = pcall(extra, run)
        if not ok then run.check("extra test group", false, err) end
    end
    DFW.Util.Muted = false
    return run
end

function DFW.SelfTest.Print(run, ply)
    local function out(text)
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, text .. "\n") else Msg(text .. "\n") end
    end
    out("---- Dubz Framework self test (" .. (SERVER and "server" or "client") .. ") ----")
    for _, line in ipairs(run.lines) do out(line) end
    out(string.format("---- %d passed, %d failed ----", run.pass, run.fail))
    if IsValid(ply) then
        ply:ChatPrint(string.format("[Dubz Framework] Self test: %d passed, %d failed (see console).", run.pass, run.fail))
    end
end

if SERVER then
    concommand.Add("dfw_selftest", function(ply)
        if IsValid(ply) and not DFW.Access.CanConfigure(ply) then return end
        DFW.SelfTest.Print(DFW.SelfTest.Run(), ply)
    end)
else
    concommand.Add("dfw_selftest_cl", function()
        DFW.SelfTest.Print(DFW.SelfTest.Run())
    end)
end
