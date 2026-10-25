DFW.ConfigMenu = DFW.ConfigMenu or {}
local Menu = DFW.ConfigMenu
local UI = DFW.UI

local frame
local state = {}

local SIDEBAR_WIDTH = 250
local HOOK_ID = "DFW.ConfigMenu"

local stateKinds = {
    started = "success", disabled = "muted", failed = "danger", waiting = "warning", registered = "info"
}

local function canOpen()
    local ply = LocalPlayer()
    return IsValid(ply) and DFW.Access.CanConfigure(ply)
end

local function makeLabel(parent, text, style, height)
    local label = vgui.Create("DFW.Label", parent)
    label:SetText(text)
    label:SetStyle(style or "body")
    label:SetTall(height or 22)
    return label
end

local function rowKey(moduleId, key)
    return moduleId .. "/" .. key
end

local function moduleDisplayName(moduleId)
    local module = DFW.Modules.Registry[moduleId]
    return module and module.name or moduleId
end

local function configurableModules()
    local list = {}
    for moduleId in pairs(DFW.Config.Schema) do
        if DFW.Modules.Registry[moduleId] and next(DFW.Config.Schema[moduleId]) ~= nil then
            list[#list + 1] = moduleId
        end
    end
    for moduleId in pairs(DFW.Collections.Defs) do
        if DFW.Modules.Registry[moduleId] and not table.HasValue(list, moduleId) then list[#list + 1] = moduleId end
    end
    table.sort(list, function(a, b) return string.lower(moduleDisplayName(a)) < string.lower(moduleDisplayName(b)) end)
    return list
end

local lastSavedToast = 0
local function toastSaved()
    if SysTime() - lastSavedToast < 1.5 then return end
    lastSavedToast = SysTime()
    UI.Notify("Setting saved.", "success", 1.6)
end

local reasonText = {
    invalid_value = "That value is not allowed for this setting.",
    unknown_setting = "That setting no longer exists.",
    unknown_module = "That module is not registered on the server.",
    invalid_payload = "The server could not read the value.",
    core_module = "The framework core cannot be disabled.",
    unknown_module_toggle = "That module is not registered on the server."
}

local function explain(reason)
    reason = tostring(reason or "")
    if string.StartWith(reason, "required_by:") then
        return "Another enabled module depends on it (" .. string.sub(reason, 13) .. ")."
    end
    return reasonText[reason] or reason
end

local controlWidths = {bool = 44, choice = 220, color = 150, string = 240, number = 260}

local function buildField(parent, moduleId, field)
    local row = vgui.Create("DFW.Card", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 10, 8)
    row:SetTall(56)

    local isRanged = field.type == "number" and field.min ~= nil and field.max ~= nil
    local controlWidth = controlWidths[field.type]
    if field.type == "number" and not isRanged then controlWidth = 130 end

    row.Title = makeLabel(row, field.label, "bodybold", 22)
    row.Description = vgui.Create("DFW.Paragraph", row)
    row.Description:SetStyle("small")
    row.Description:SetText(field.description or "")

    if field.restart then
        row.RestartBadge = vgui.Create("DFW.Badge", row)
        row.RestartBadge:SetText("restart")
        row.RestartBadge:SetKind("warning")
        row.RestartBadge:SizeToContents()
    end

    row.ResetButton = vgui.Create("DFW.Button", row)
    row.ResetButton:SetVariant("ghost")
    row.ResetButton:SetIcon("actions/refresh")
    row.ResetButton:SetTooltip("Reset to default")
    row.ResetButton:SetSize(28, 28)
    row.ResetButton.DoClick = function() DFW.Config.RequestReset(moduleId, field.key) end

    local function send(value)
        DFW.Config.RequestSet(moduleId, field.key, value)
    end

    local current = DFW.Config.Get(moduleId, field.key)
    local control

    if field.type == "bool" then
        control = vgui.Create("DFW.Toggle", row)
        control:SetChecked(current == true, true)
        control.OnChange = function(_, value) send(value) end
        row.SetExternal = function(_, value) control:SetChecked(value == true, true) end

    elseif field.type == "choice" then
        control = vgui.Create("DFW.Dropdown", row)
        for _, choice in ipairs(DFW.Config.GetChoices(field)) do control:AddChoice(tostring(choice), choice) end
        control:SelectByData(current, true)
        control.OnSelect = function(_, _, _, data) send(data) end
        row.SetExternal = function(_, value) control:SelectByData(value, true) end

    elseif field.type == "color" then
        control = vgui.Create("DFW.ColorButton", row)
        control:SetColor(current)
        local timerName = "DFW.ConfigMenu.Color." .. tostring(row)
        control.OnValueChanged = function(_, color)
            timer.Create(timerName, 0.4, 1, function()
                send({r = color.r, g = color.g, b = color.b, a = color.a})
            end)
        end
        row.OnRemove = function() timer.Remove(timerName) end
        row.SetExternal = function(_, value) control:SetColor(value) end

    elseif isRanged then
        control = vgui.Create("DFW.Slider", row)
        control:SetRange(field.min, field.max)
        control:SetDecimals(field.decimals or 0)
        control:SetValue(current, true)
        control.OnValueCommitted = function(_, value) send(value) end
        row.SetExternal = function(_, value) if not control.Dragging then control:SetValue(value, true) end end

    else
        control = vgui.Create("DFW.TextEntry", row)
        local function show(value) control:SetText(tostring(value)) end
        show(current)

        local function commit()
            local text = control:GetValue()
            local value = field.type == "number" and tonumber(text) or text
            if value == nil then show(DFW.Config.Get(moduleId, field.key)) return end
            if not DFW.Util.DeepEqual(value, DFW.Config.Get(moduleId, field.key)) then send(value) end
        end
        control.OnEnter = commit
        local baseLoseFocus = control.OnLoseFocus
        control.OnLoseFocus = function(self)
            if baseLoseFocus then baseLoseFocus(self) end
            commit()
        end
        row.SetExternal = function(_, value) if not control:HasFocus() then show(value) end end
    end
    row.Control = control

    local function refreshReset()
        row.ResetButton:SetVisible(not DFW.Config.IsDefault(moduleId, field.key))
    end
    refreshReset()

    local setExternal = row.SetExternal
    row.SetExternal = function(self, value)
        setExternal(self, value)
        refreshReset()
    end

    row.PerformLayout = function(self, w, h)
        local resetX = w - 10 - 28
        local controlX = resetX - 8 - controlWidth
        local controlHeight = field.type == "bool" and 22 or 30
        local textWidth = math.max(controlX - 32, 60)

        self.Title:SetPos(16, 10)
        self.Title:SetWide(textWidth)
        if self.RestartBadge then
            local titleWidth = UI.TextSize(field.label, "BodyBold")
            self.RestartBadge:SetPos(16 + titleWidth + 10, 12)
        end

        self.Description:SetPos(16, 33)
        self.Description:SetWide(textWidth)

        local wanted = math.max(56, 33 + self.Description:GetTall() + 14)
        if wanted ~= h then
            self:SetTall(wanted)
            self:InvalidateParent()
        end

        control:SetSize(controlWidth, controlHeight)
        control:SetPos(controlX, (wanted - controlHeight) / 2)
        self.ResetButton:SetPos(resetX, (wanted - 28) / 2)
    end

    state.rows[rowKey(moduleId, field.key)] = row
    return row
end

local function addGroupHeader(canvas, text)
    local header = makeLabel(canvas, string.upper(text), "tiny", 26)
    header:Dock(TOP)
    header:DockMargin(4, 10, 0, 2)
end

local function emptyState(canvas, text)
    local card = vgui.Create("DFW.Card", canvas)
    card:Dock(TOP)
    card:DockMargin(0, 0, 10, 8)
    card:SetTall(64)
    local label = makeLabel(card, text, "muted", 22)
    label:SetPos(18, 21)
    label:SetWide(600)
end

local function statRow(parent, label, value, kind)
    local row = vgui.Create("Panel", parent)
    row:Dock(TOP)
    row:SetTall(28)

    local title = makeLabel(row, label, "muted", 28)
    title:Dock(LEFT)
    title:SetWide(170)

    if kind then
        local badge = vgui.Create("DFW.Badge", row)
        badge:SetText(value)
        badge:SetKind(kind)
        badge:SizeToContents()
        badge:Dock(LEFT)
        badge:DockMargin(0, 4, 0, 4)
    else
        local text = makeLabel(row, value, "body", 28)
        text:Dock(FILL)
    end
    return row
end

local function infoCard(canvas, title, accent, rows)
    local card = vgui.Create("DFW.Card", canvas)
    card:Dock(TOP)
    card:DockMargin(0, 0, 10, 10)
    card:SetAccent(accent)
    card:DockPadding(20, 14, 16, 12)

    local heading = makeLabel(card, title, "heading", 26)
    heading:Dock(TOP)
    heading:DockMargin(0, 0, 0, 6)

    for _, entry in ipairs(rows) do statRow(card, entry[1], entry[2], entry[3]) end
    card:SetTall(14 + 26 + 6 + #rows * 28 + 12)
    return card
end

local function buildOverview(canvas)
    local theme = UI.GetTheme()
    local server = DFW.Modules.ServerState or {}
    local moduleCount, startedCount = 0, 0
    for _, module in ipairs(server.modules or {}) do
        moduleCount = moduleCount + 1
        if module.state == "started" then startedCount = startedCount + 1 end
    end
    local packages = server.packages or DFW.Packages.GetStats()

    infoCard(canvas, "Framework", theme.accent, {
        {"Version", DFW.Version .. "  (API " .. DFW.APIVersion .. ")"},
        {"Theme", theme.name},
        {"Access", "Superadmin (or your permission addon)"}
    })

    infoCard(canvas, "Server status", theme.success, {
        {"Modules", server.modules and (startedCount .. " running of " .. moduleCount) or "Loading..."},
        {"Packages loaded", tostring(packages.loaded or 0), "success"},
        {"Packages failed", tostring(packages.failed or 0), (packages.failed or 0) > 0 and "danger" or "muted"}
    })

    local addons = server.addons or DFW.Addons.GetAll()
    local rows = {}
    for _, id in ipairs(DFW.Util.SortedKeys(addons)) do
        local addon = addons[id]
        local kind = addon.state == "loaded" and "success" or (addon.state == "failed" and "danger" or "warning")
        rows[#rows + 1] = {(addon.name or id) .. "  v" .. tostring(addon.version), addon.state or "?", kind}
    end
    infoCard(canvas, "Installed addons", theme.info, rows)

    infoCard(canvas, "Console commands", theme.gold, {
        {"dfw_config", "Open this menu"},
        {"dfw_status / dfw_status_cl", "Print server / client status"},
        {"dfw_selftest / dfw_selftest_cl", "Run the built-in self tests"},
        {"dfw_ui_demo", "Show every interface component"}
    })
end

local function buildModules(canvas)
    local server = DFW.Modules.ServerState
    local list = server and server.modules

    if not list then
        emptyState(canvas, "Waiting for the server to send the module list...")
        return
    end

    local theme = UI.GetTheme()
    for _, module in ipairs(list) do
        local card = vgui.Create("DFW.Card", canvas)
        card:Dock(TOP)
        card:DockMargin(0, 0, 10, 8)
        card:SetTall(module.failure and 84 or 64)

        card.Paint = function(self, w, h)
            DFW.Draw.Card(0, 0, w, h, {radius = "MD", color = UI.GetTheme().surface})
            DFW.Draw.IconChip(module.icon or "misc/handyman", 14, 14, 36, UI.GetTheme().accent)
            DFW.Draw.Text(module.name, "BodyBold", 64, 24, UI.GetTheme().text)
            local detail = module.id .. "  -  " .. module.addon .. "  -  v" .. module.version
            DFW.Draw.Text(detail, "Small", 64, 44, UI.GetTheme().textDim)
            if module.failure then
                DFW.Draw.Text("Failed: " .. string.sub(module.failure, 1, 90), "Small", 64, 66, UI.GetTheme().danger)
            elseif module.waitingFor then
                DFW.Draw.Text("Waiting for: " .. module.waitingFor, "Small", 64, 66, UI.GetTheme().warning)
            end
        end

        local toggle = vgui.Create("DFW.Toggle", card)
        toggle:SetChecked(module.enabled, true)
        toggle:SetEnabled(not module.core)
        toggle:SetSize(40, 22)
        toggle.OnChange = function(_, value) DFW.Modules.RequestToggle(module.id, value) end

        local badge = vgui.Create("DFW.Badge", card)
        badge:SetText(module.core and "core" or module.state)
        badge:SetKind(module.core and "accent" or (stateKinds[module.state] or "muted"))
        badge:SizeToContents()

        card.PerformLayout = function(self, w, h)
            toggle:SetPos(w - 16 - 40, h / 2 - 11)
            badge:SetPos(w - 16 - 40 - 14 - badge:GetWide(), h / 2 - 10)
        end
    end
end

local function buildCollectionCard(canvas, moduleId, def)
    local card = vgui.Create("DFW.Card", canvas)
    card:Dock(TOP)
    card:DockMargin(0, 0, 10, 8)
    card:SetTall(72)

    local title = makeLabel(card, def.label, "bodybold", 22)
    title:SetPos(16, 10)
    title:SetWide(500)

    local description = makeLabel(card, def.description or "Editable table.", "small", 20)
    description:SetPos(16, 34)
    description:SetWide(520)

    local count = makeLabel(card, "", "small", 20)
    count:SetPos(16, 50)
    count:SetWide(300)
    count.Think = function(self)
        self:SetText(#DFW.Collections.Get(moduleId, def.id) .. " rows")
    end

    local edit = vgui.Create("DFW.Button", card)
    edit:SetVariant(def.picker and "default" or "primary")
    edit:SetLabel("Edit " .. def.label)
    edit:SetSize(170, 34)
    edit.DoClick = function() DFW.CollectionEditor.Open(moduleId, def.id) end

    local browse
    if def.picker and DFW.CollectionPicker then
        browse = vgui.Create("DFW.Button", card)
        browse:SetVariant("primary")
        browse:SetIcon("navigation/search")
        browse:SetLabel("Browse")
        browse:SetSize(110, 34)
        browse.DoClick = function() DFW.CollectionPicker.Open(moduleId, def.id) end
    end

    local extra = {}
    for _, action in ipairs(def.actions or {}) do
        local button = vgui.Create("DFW.Button", card)
        button:SetVariant(action.primary and "primary" or "default")
        button:SetLabel(action.label)
        button:SetSize(130, 34)
        button.DoClick = function() action.fn(moduleId, def.id) end
        extra[#extra + 1] = button
    end

    card.PerformLayout = function(self, w, h)
        local x = w - 186
        edit:SetPos(x, (h - 34) / 2)
        if browse then x = x - 118 browse:SetPos(x, (h - 34) / 2) end

        for _, button in ipairs(extra) do
            x = x - 138
            button:SetPos(x, (h - 34) / 2)
        end
    end
end

local function buildLauncherCard(canvas, moduleId, launcher)
    local card = vgui.Create("DFW.Card", canvas)
    card:Dock(TOP)
    card:DockMargin(0, 0, 10, 8)
    card:SetTall(72)

    local title = makeLabel(card, launcher.label, "bodybold", 22)
    title:SetPos(16, 10)
    title:SetWide(500)

    local description = makeLabel(card, launcher.description or "", "small", 20)
    description:SetPos(16, 34)
    description:SetWide(620)

    local open = vgui.Create("DFW.Button", card)
    open:SetVariant("primary")
    open:SetLabel(launcher.button or "Open")
    open:SetSize(170, 34)
    open.DoClick = function() launcher.fn(moduleId) end

    card.PerformLayout = function(self, w, h)
        open:SetPos(w - 186, (h - 34) / 2)
    end
end

local function buildModule(canvas, moduleId)
    local fields = DFW.Config.GetFields(moduleId)
    local collections = DFW.Collections.ListFor(moduleId)
    local launchers = DFW.Modules.Registry[moduleId].launchers or {}

    if #fields == 0 and #collections == 0 and #launchers == 0 then
        emptyState(canvas, "This module has no configurable values.")
        return
    end

    if #launchers > 0 then
        addGroupHeader(canvas, "Tools")
        for _, launcher in ipairs(launchers) do buildLauncherCard(canvas, moduleId, launcher) end
    end

    if #collections > 0 then
        addGroupHeader(canvas, "Tables")
        for _, def in ipairs(collections) do buildCollectionCard(canvas, moduleId, def) end
    end

    local lastGroup
    for _, field in ipairs(fields) do
        if field.group and field.group ~= lastGroup then
            addGroupHeader(canvas, field.group)
            lastGroup = field.group
        end
        buildField(canvas, moduleId, field)
    end
end

local function buildSearch(canvas, query)
    query = string.lower(string.Trim(query))
    local shown = 0

    for _, moduleId in ipairs(configurableModules()) do
        local moduleName = string.lower(moduleDisplayName(moduleId))
        local matches = {}
        for _, field in ipairs(DFW.Config.GetFields(moduleId)) do
            local haystack = string.lower(field.label .. " " .. field.key .. " " .. (field.description or "") .. " " .. (field.group or ""))
            if string.find(haystack, query, 1, true) or string.find(moduleName, query, 1, true) then
                matches[#matches + 1] = field
            end
        end

        if #matches > 0 and shown < 60 then
            addGroupHeader(canvas, moduleDisplayName(moduleId))
            for _, field in ipairs(matches) do
                if shown < 60 then
                    buildField(canvas, moduleId, field)
                    shown = shown + 1
                end
            end
        end
    end

    if shown == 0 then emptyState(canvas, "No settings match \"" .. query .. "\".") end
end

local function setHeader(title, subtitle, moduleId)
    state.headerTitle = title
    state.headerSubtitle = subtitle
    state.resetModuleButton:SetVisible(moduleId ~= nil)
    state.resetModuleId = moduleId
    state.header:InvalidateLayout()
end

local function showPage(page, argument)
    if not IsValid(frame) then return end

    local scrollValue = 0
    if state.page == page and state.pageArgument == argument then
        scrollValue = state.scroll:GetVBar():GetScroll()
    end

    state.page, state.pageArgument = page, argument
    state.rows = {}
    state.scroll:GetCanvas():Clear()
    local canvas = state.scroll:GetCanvas()

    for navId, button in pairs(state.nav) do button:SetActive(navId == page .. ":" .. tostring(argument or "")) end

    if page == "overview" then
        setHeader("Overview", "Framework status and installed addons")
        buildOverview(canvas)
    elseif page == "modules" then
        setHeader("Modules", "Enable or disable modules. Changes apply immediately and are remembered.")
        buildModules(canvas)
    elseif page == "module" then
        local module = DFW.Modules.Registry[argument]
        setHeader(module and module.name or argument, module and module.description or "", argument)
        buildModule(canvas, argument)
    elseif page == "search" then
        setHeader("Search results", "Matching settings across every module")
        buildSearch(canvas, argument)
    end

    if scrollValue > 0 then
        timer.Simple(0, function()
            if IsValid(state.scroll) then state.scroll:GetVBar():SetScroll(scrollValue) end
        end)
    end
end

local function addNav(id, label, icon, badge, page, argument)
    local button = vgui.Create("DFW.NavButton", state.navCanvas)
    button:Dock(TOP)
    button:DockMargin(0, 0, 6, 6)
    button:SetTall(40)
    button:SetLabel(label)
    button:SetIcon(icon)
    if badge then button:SetBadge(badge) end
    button.DoClick = function()
        state.ignoreSearch = true
        state.search:SetText("")
        state.ignoreSearch = false
        showPage(page, argument)
    end
    state.nav[id] = button
    return button
end

local function buildNavigation()
    state.navCanvas:Clear()
    state.nav = {}

    addNav("overview:", "Overview", "economy/leaderboard", nil, "overview")
    addNav("modules:", "Modules", "misc/handyman", nil, "modules")

    local divider = makeLabel(state.navCanvas, "MODULE SETTINGS", "tiny", 28)
    divider:Dock(TOP)
    divider:DockMargin(6, 8, 0, 0)

    for _, moduleId in ipairs(configurableModules()) do
        local module = DFW.Modules.Registry[moduleId]
        addNav("module:" .. moduleId, module.name, module.icon or "navigation/settings", nil, "module", moduleId)
    end
end

local function installHooks()
    hook.Add("DFW_ConfigChanged", HOOK_ID, function(moduleId, key, value)
        local row = state.rows and state.rows[rowKey(moduleId, key)]
        if IsValid(row) then row:SetExternal(value) end
    end)

    hook.Add("DFW_ConfigResult", HOOK_ID, function(ok, moduleId, key, reason)
        if ok then
            toastSaved()
            return
        end
        UI.Notify("Rejected: " .. explain(reason), "danger", 4)
        local row = state.rows and state.rows[rowKey(moduleId, key)]
        if IsValid(row) then row:SetExternal(DFW.Config.Get(moduleId, key)) end
    end)

    hook.Add("DFW_ModuleStateSnapshot", HOOK_ID, function()
        if not IsValid(frame) then return end
        if state.page == "overview" or state.page == "modules" then showPage(state.page, state.pageArgument) end
    end)

    hook.Add("DFW_ModuleResult", HOOK_ID, function(ok, id, reason)
        if not ok then UI.Notify("Could not change " .. moduleDisplayName(id) .. ": " .. explain(reason), "danger", 4) end
    end)
end

local function removeHooks()
    for _, event in ipairs({"DFW_ConfigChanged", "DFW_ConfigResult", "DFW_ModuleStateSnapshot", "DFW_ModuleResult"}) do
        hook.Remove(event, HOOK_ID)
    end
end

function Menu.GetFrame() return frame end
function Menu.GetPage() return state.page end
function Menu.GetRows() return state.rows or {} end
function Menu.ShowPage(page, argument) showPage(page, argument) end

function Menu.Close()
    if IsValid(frame) then frame:Close() end
end

local sides = {}
local SLIDE_TIME = 0.4

local function slideTo(panel, x, y)
    if IsValid(panel) then panel:MoveTo(x, y, SLIDE_TIME, 0, 0.35) end
end

local function relayout()
    for index = #sides, 1, -1 do
        if not IsValid(sides[index]) then table.remove(sides, index) end
    end

    local side = sides[#sides]
    local mainOpen = IsValid(frame)

    if mainOpen and side then
        local mainW, sideW = frame:GetWide(), side:GetWide()
        local leftX = math.max(10, ScrW() * 0.25 - mainW / 2)
        local rightX = math.min(ScrW() - sideW - 10, ScrW() * 0.75 - sideW / 2)

        slideTo(frame, leftX, (ScrH() - frame:GetTall()) / 2)
        slideTo(side, rightX, (ScrH() - side:GetTall()) / 2)
    elseif mainOpen then
        slideTo(frame, (ScrW() - frame:GetWide()) / 2, (ScrH() - frame:GetTall()) / 2)
    elseif side then
        slideTo(side, (ScrW() - side:GetWide()) / 2, (ScrH() - side:GetTall()) / 2)
    end
end

function Menu.AttachSide(side)
    if not IsValid(side) then return end

    side:SetPos(math.min(ScrW() - side:GetWide() - 10, ScrW() * 0.75 - side:GetWide() / 2) + 90, (ScrH() - side:GetTall()) / 2)
    sides[#sides + 1] = side

    local previous = side.OnRemove
    side.OnRemove = function(self)
        if previous then previous(self) end
        timer.Simple(0, relayout)
    end

    relayout()
end

function Menu.Open()
    if not canOpen() then return end

    if IsValid(frame) then
        frame:MakePopup()
        frame:MoveToFront()
        DFW.Modules.RequestState()
        return
    end

    state = {rows = {}, nav = {}}

    frame = UI.CreateFrame("Dubz Framework Configuration", 1120, 740, "navigation/settings")
    frame:SetSubtitle("Version " .. DFW.Version)
    frame.OnRemove = function(self)
        removeHooks(self)
        timer.Simple(0, function() if relayout then relayout() end end)
    end

    local content = frame:GetContent()

    local sidebar = vgui.Create("Panel", content)
    sidebar:Dock(LEFT)
    sidebar:SetWide(SIDEBAR_WIDTH)
    sidebar:DockMargin(0, 0, 12, 0)

    state.search = vgui.Create("DFW.TextEntry", sidebar)
    state.search:Dock(TOP)
    state.search:SetTall(34)
    state.search:DockMargin(0, 0, 6, 10)
    state.search:SetPlaceholder("Search settings...")
    state.search.OnChange = function(self)
        if state.ignoreSearch then return end
        local query = string.Trim(self:GetValue())
        if query == "" then showPage("overview") else showPage("search", query) end
    end

    local support = vgui.Create("DFW.Button", sidebar)
    support:Dock(BOTTOM)
    support:SetTall(32)
    support:DockMargin(0, 8, 6, 0)
    support:SetVariant("ghost")
    support:SetLabel("Support on Ko-fi")
    support.DoClick = function() gui.OpenURL("https://ko-fi.com/bdubz420") end

    local navScroll = vgui.Create("DFW.ScrollPanel", sidebar)
    navScroll:Dock(FILL)
    state.navCanvas = navScroll:GetCanvas()

    local right = vgui.Create("Panel", content)
    right:Dock(FILL)

    state.header = vgui.Create("Panel", right)
    state.header:Dock(TOP)
    state.header:SetTall(56)
    state.header:DockMargin(0, 0, 10, 10)
    state.header.Paint = function(_, w)
        DFW.Draw.Text(state.headerTitle or "", "Title", 4, 16, UI.GetTheme().text)
        DFW.Draw.Text(state.headerSubtitle or "", "Small", 5, 42, UI.GetTheme().textMuted)
    end

    state.resetModuleButton = vgui.Create("DFW.Button", state.header)
    state.resetModuleButton:SetLabel("Reset module")
    state.resetModuleButton:SetIcon("actions/refresh")
    state.resetModuleButton:SizeToLabel(36)
    state.resetModuleButton:SetTall(30)
    state.resetModuleButton:SetVisible(false)
    state.resetModuleButton.DoClick = function()
        local moduleId = state.resetModuleId
        if not moduleId then return end
        UI.Confirm("Reset module", "Restore every setting in " .. moduleDisplayName(moduleId) .. " to its default value?", function()
            DFW.Config.RequestReset(moduleId, nil)
        end, {danger = true, confirmLabel = "Reset"})
    end
    state.header.PerformLayout = function(self, w)
        state.resetModuleButton:SetPos(w - state.resetModuleButton:GetWide(), 12)
    end

    state.scroll = vgui.Create("DFW.ScrollPanel", right)
    state.scroll:Dock(FILL)

    buildNavigation()
    installHooks()
    showPage("overview")
    DFW.Modules.RequestState()
end

concommand.Add("dfw_config_menu_local", Menu.Open)
hook.Add("DFW_OpenConfigMenu", "DFW.ConfigMenu.Open", Menu.Open)

hook.Add("DFW_ConfigRegistered", "DFW.ConfigMenu.Refresh", function()
    if IsValid(frame) and state.navCanvas then buildNavigation() end
end)
