DFW.CollectionPicker = DFW.CollectionPicker or {}
local Picker = DFW.CollectionPicker
local UI = DFW.UI
local Collections = DFW.Collections

local frame

Collections.Browse = Collections.Browse or {}

Collections.Browse.entities = function()
    local list, seen = {}, {}

    for class, ent in pairs(scripted_ents.GetList()) do
        local info = ent.t or ent
        list[#list + 1] = {id = class, label = info.PrintName or class, kind = "entity"}
        seen[class] = true
    end

    for _, swep in ipairs(weapons.GetList()) do
        local class = swep.ClassName
        if class and not seen[class] then
            list[#list + 1] = {id = class, label = swep.PrintName or class, kind = "weapon"}
        end
    end

    table.sort(list, function(a, b) return string.lower(a.id) < string.lower(b.id) end)
    return list
end

Collections.Browse.weapons = function()
    local list = {}

    for _, swep in ipairs(weapons.GetList()) do
        if swep.ClassName then list[#list + 1] = {id = swep.ClassName, label = swep.PrintName or swep.ClassName, kind = "weapon"} end
    end

    table.sort(list, function(a, b) return string.lower(a.id) < string.lower(b.id) end)
    return list
end

local MAX_SHOWN = 150

function Picker.Open(moduleId, collId)
    local def = Collections.GetDefinition(moduleId, collId)
    if not def or not def.picker then return end

    local column = def.picker.column
    local providerName = def.picker.provider or "entities"
    local provider = Collections.Browse[providerName] or Collections.Browse.entities
    local entityMode = providerName == "entities"
    local candidates = provider()

    if IsValid(frame) then frame:Remove() end

    local chosen = {}
    local extras = {}
    for _, row in ipairs(Collections.Get(moduleId, collId)) do
        local key = string.lower(tostring(row[column]))
        chosen[key] = true
        extras[key] = table.Copy(row)
    end

    frame = UI.CreateFrame("Browse: " .. def.label, math.min(900, math.floor(ScrW() * 0.5) - 30), 720, "navigation/search")
    frame:SetSubtitle("Click an entry to add it; click it again to remove it. Press Save when you're done.")
    if DFW.ConfigMenu and DFW.ConfigMenu.AttachSide then DFW.ConfigMenu.AttachSide(frame) end

    local content = frame:GetContent()

    local top = vgui.Create("Panel", content)
    top:Dock(TOP)
    top:SetTall(34)

    local search = vgui.Create("DFW.TextEntry", top)
    search:Dock(FILL)
    search:DockMargin(0, 3, 8, 3)
    search:SetPlaceholder(entityMode and "Search entities and weapons by class or name..." or "Search by name or path...")

    local tabs = vgui.Create("DFW.TabBar", content)
    tabs:Dock(TOP)
    tabs:SetTall(entityMode and 32 or 1)
    tabs:SetVisible(entityMode)
    tabs:DockMargin(0, 4, 0, 4)

    local status = vgui.Create("DFW.Label", content)
    status:Dock(TOP)
    status:SetTall(20)
    status:SetStyle("small")

    local bottom = vgui.Create("Panel", content)
    bottom:Dock(BOTTOM)
    bottom:SetTall(42)
    bottom:DockMargin(0, 8, 0, 0)

    local save = vgui.Create("DFW.Button", bottom)
    save:Dock(RIGHT)
    save:SetWide(110)
    save:DockMargin(8, 4, 0, 4)
    save:SetVariant("primary")
    save:SetLabel("Save")

    local cancel = vgui.Create("DFW.Button", bottom)
    cancel:Dock(RIGHT)
    cancel:SetWide(100)
    cancel:DockMargin(8, 4, 0, 4)
    cancel:SetLabel("Cancel")
    cancel.DoClick = function() frame:Close() end

    local scroll = vgui.Create("DFW.ScrollPanel", content)
    scroll:Dock(FILL)

    local kind = "all"
    local rebuild

    local function counts()
        local total = 0
        for _ in pairs(chosen) do total = total + 1 end
        return total
    end

    function rebuild()
        scroll:Clear()

        local query = string.lower(string.Trim(search:GetValue()))
        local shown, matches = 0, 0

        local ordered = {}
        for _, item in ipairs(candidates) do
            if chosen[string.lower(item.id)] then ordered[#ordered + 1] = item end
        end
        for _, item in ipairs(candidates) do
            if not chosen[string.lower(item.id)] then ordered[#ordered + 1] = item end
        end

        for _, item in ipairs(ordered) do
            local key = string.lower(item.id)
            local kindOk = kind == "all" or kind == item.kind
            local textOk = query == "" or string.find(key, query, 1, true) or string.find(string.lower(item.label), query, 1, true)

            if kindOk and textOk then
                matches = matches + 1

                if shown < MAX_SHOWN then
                    shown = shown + 1

                    local row = vgui.Create("DFW.Button", scroll)
                    row:Dock(TOP)
                    row:SetTall(30)
                    row:DockMargin(0, 0, 6, 2)
                    row:SetTextAlign(TEXT_ALIGN_LEFT)
                    row:SetLabel(item.label ~= item.id and (item.label .. "   (" .. item.id .. ")") or item.id)
                    row:SetActive(chosen[key] == true)

                    row.PaintOver = function(_, w, h)
                        local theme = UI.GetTheme()
                        DFW.Draw.Text(chosen[key] and "ON LIST" or item.kind, "Tiny", w - 10, h / 2, chosen[key] and theme.accent or theme.textDim, TEXT_ALIGN_RIGHT)
                    end

                    row.DoClick = function(self)
                        if chosen[key] then
                            chosen[key] = nil
                        else
                            chosen[key] = true
                            extras[key] = extras[key] or nil
                        end

                        self:SetActive(chosen[key] == true)
                        status:SetText(counts() .. " on the list. " .. matches .. " match your search" .. (matches > MAX_SHOWN and (" (showing the first " .. MAX_SHOWN .. ", refine your search)") or "") .. ".")
                    end
                end
            end
        end

        status:SetText(counts() .. " on the list. " .. matches .. " match your search" .. (matches > MAX_SHOWN and (" (showing the first " .. MAX_SHOWN .. ", refine your search)") or "") .. ".")
    end

    tabs.OnTabChanged = function(_, id)
        kind = id
        rebuild()
    end

    if entityMode then
        tabs:AddTab("all", "All")
        tabs:AddTab("entity", "Entities")
        tabs:AddTab("weapon", "Weapons")
    end

    search.OnChange = function()
        timer.Create("DFW.Picker.Search", 0.15, 1, function()
            if IsValid(frame) then rebuild() end
        end)
    end

    save.DoClick = function()
        local rows = {}

        local kept = {}
        for _, row in ipairs(Collections.Get(moduleId, collId)) do
            local key = string.lower(tostring(row[column]))
            if chosen[key] then rows[#rows + 1] = table.Copy(row) kept[key] = true end
        end

        for _, item in ipairs(candidates) do
            local key = string.lower(item.id)
            if chosen[key] and not kept[key] then
                local row = Collections.NewRow(moduleId, collId)
                row[column] = item.id

                if def.picker.fill then
                    local taken = {}
                    for _, other in ipairs(rows) do taken[tostring(other[def.idKey or "id"])] = true end
                    def.picker.fill(row, item, taken)
                end
                rows[#rows + 1] = row
                kept[key] = true
            end
        end

        for key in pairs(chosen) do
            if not kept[key] and extras[key] then rows[#rows + 1] = extras[key] kept[key] = true end
        end

        local Net = DFW.Net
        Net.Start("Collections.Save")
        net.WriteString(moduleId)
        net.WriteString(collId)
        if not Net.WriteJSON({rows = rows}) then
            net.Abort()
            UI.Notify("That is too much data to save at once.", "danger", 3)
            return
        end
        net.SendToServer()
    end

    rebuild()

    local hookId = "DFW.CollectionPicker." .. moduleId .. "." .. collId
    hook.Add("DFW_CollectionResult", hookId, function(ok, resultModule, resultColl, reason)
        if resultModule ~= moduleId or resultColl ~= collId then return end
        if not IsValid(frame) then hook.Remove("DFW_CollectionResult", hookId) return end

        if ok then
            UI.Notify(def.label .. " saved.", "success", 2)
            frame:Close()
            hook.Remove("DFW_CollectionResult", hookId)
        else
            UI.Notify("Could not save (" .. tostring(reason) .. ")", "danger", 4)
        end
    end)
end
