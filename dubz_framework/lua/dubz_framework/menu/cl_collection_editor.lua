-- Table editor for collections (see core/sh_47_collections.lua): add, remove, duplicate, reorder and edit rows with
-- one control per column, then Save. Opened from a module's page in the config menu and docked beside it.
--
-- Collection options the editor understands (all optional):
--   preview = {kind = "chip", text = "name", color = "color"}   a live preview of each row (the rank / colour as it
--                                                                shows in game), or {kind = "model", model = "model"}
--   column.suggest = "weapons" | "entities" | "usergroups" | "jobs" | <provider name> | function() return {..} end
--                                                                typing in that column offers matching names
--   Suggestion providers live in DFW.Collections.Suggest[name] (an addon can add its own).
DFW.CollectionEditor = DFW.CollectionEditor or {}
local Editor = DFW.CollectionEditor
local UI = DFW.UI
local Collections = DFW.Collections

local frame

local ACTIONS_W = 3 * 28 + 8
local PREVIEW_W = 150

---------------------------------------------------------------------------
-- Suggestion providers: lists of names to autocomplete from
---------------------------------------------------------------------------
Collections.Suggest = Collections.Suggest or {}
local Suggest = Collections.Suggest

local function sortedKeys(set)
    local list = {}
    for key in pairs(set) do list[#list + 1] = key end
    table.sort(list)
    return list
end

Suggest.weapons = function()
    local set = {}
    for _, swep in ipairs(weapons.GetList()) do if swep.ClassName then set[swep.ClassName] = true end end
    return sortedKeys(set)
end

Suggest.entities = function()
    local set = {}
    for class in pairs(scripted_ents.GetList()) do set[class] = true end
    for _, swep in ipairs(weapons.GetList()) do if swep.ClassName then set[swep.ClassName] = true end end
    return sortedKeys(set)
end

Suggest.usergroups = function()
    local set = {user = true, admin = true, superadmin = true, vip = true, moderator = true}
    if CAMI and CAMI.GetUsergroups then
        for name in pairs(CAMI.GetUsergroups()) do set[string.lower(name)] = true end
    end
    for _, ply in ipairs(player.GetAll()) do set[string.lower(ply:GetUserGroup())] = true end
    return sortedKeys(set)
end

Suggest.jobs = function()
    local list = {}
    for _, job in ipairs(RPExtraTeams or {}) do list[#list + 1] = job.name end
    table.sort(list)
    return list
end

local function suggestions(col)
    local source = col.suggest
    if isfunction(source) then return source() end
    if istable(source) then return source end

    local provider = Suggest[source]
    return provider and provider() or {}
end

-- One popup shared by every suggesting field: shows up to 8 matches under the field being typed in
local suggestPanel

local function closeSuggestions()
    if IsValid(suggestPanel) then suggestPanel:Remove() end
    suggestPanel = nil
end

local function showSuggestions(entry, col, onPick)
    closeSuggestions()

    local typed = string.lower(entry:GetValue())
    local matches = {}

    for _, name in ipairs(suggestions(col)) do
        local lowered = string.lower(name)
        if lowered ~= typed and (typed == "" or string.find(lowered, typed, 1, true)) then
            matches[#matches + 1] = name
            if #matches >= 8 then break end
        end
    end

    if #matches == 0 then return end

    local x, y = entry:LocalToScreen(0, entry:GetTall() + 2)
    local width, rowH = math.max(entry:GetWide(), 220), 24

    suggestPanel = vgui.Create("EditablePanel")
    suggestPanel:SetSize(width, #matches * rowH + 8)
    suggestPanel:SetPos(math.min(x, ScrW() - width - 8), math.min(y, ScrH() - suggestPanel:GetTall() - 8))
    suggestPanel:MakePopup()
    suggestPanel:SetKeyboardInputEnabled(false)   -- typing keeps going to the field
    suggestPanel.Paint = function(_, w, h)
        local theme = UI.GetTheme()
        draw.RoundedBox(6, 0, 0, w, h, theme.border)
        draw.RoundedBox(6, 1, 1, w - 2, h - 2, theme.background)
    end

    for index, name in ipairs(matches) do
        local button = vgui.Create("DFW.Button", suggestPanel)
        button:SetPos(4, 4 + (index - 1) * rowH)
        button:SetSize(width - 8, rowH)
        button:SetVariant("ghost")
        button:SetTextAlign(TEXT_ALIGN_LEFT)
        button:SetLabel(name)
        button.DoClick = function()
            onPick(name)
            closeSuggestions()
        end
    end

    UI.AttachPopup(suggestPanel, entry)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function explain(reason)
    reason = tostring(reason or "")
    local base, detail = string.match(reason, "^([^:]+):?(.*)$")
    local messages = {
        empty_id = "Row " .. tostring(detail) .. " has an empty name / ID.",
        duplicate_id = "'" .. tostring(detail) .. "' appears more than once.",
        too_many_rows = "There are too many rows.",
        invalid_payload = "The server could not read that.",
    }
    return messages[base] or ("Could not save (" .. reason .. ")")
end

local function control(parent, col, row)
    local value = row[col.key]
    local ctl

    if col.type == "bool" then
        ctl = vgui.Create("DFW.Toggle", parent)
        ctl:SetChecked(value == true, true)
        ctl.OnChange = function(_, checked) row[col.key] = checked end
    elseif col.type == "color" then
        ctl = vgui.Create("DFW.ColorButton", parent)
        ctl:SetAlphaBar(false)
        ctl:SetColor(value)
        ctl.OnValueChanged = function(_, color) row[col.key] = {r = color.r, g = color.g, b = color.b, a = 255} end
    elseif col.type == "choice" then
        ctl = vgui.Create("DFW.Dropdown", parent)
        for _, choice in ipairs(col.choices) do ctl:AddChoice(choice, choice, choice == value) end
        ctl.OnSelect = function(_, _, _, data) row[col.key] = data end
    elseif col.type == "number" then
        ctl = vgui.Create("DFW.TextEntry", parent)
        ctl:SetText(tostring(value))
        ctl.OnChange = function(self)
            local number = tonumber(self:GetValue())
            if number then row[col.key] = number end
        end
        ctl.OnLoseFocus = function(self) self:SetText(tostring(row[col.key])) end
    else
        ctl = vgui.Create("DFW.TextEntry", parent)
        ctl:SetText(tostring(value))

        if col.suggest then
            ctl:SetPlaceholder("type to search...")
            ctl.OnChange = function(self)
                row[col.key] = self:GetValue()
                showSuggestions(self, col, function(name)
                    self:SetText(name)
                    row[col.key] = name
                end)
            end
            ctl.OnGetFocus = function(self)
                showSuggestions(self, col, function(name)
                    self:SetText(name)
                    row[col.key] = name
                end)
            end
        else
            ctl.OnChange = function(self) row[col.key] = self:GetValue() end
        end
    end

    return ctl
end

local function rowMatches(def, row, query)
    if query == "" then return true end

    for _, col in ipairs(def.columns) do
        if col.type == "string" and string.find(string.lower(tostring(row[col.key])), query, 1, true) then return true end
    end
    return false
end

-- Draws the live preview of a row (the left part of each row)
local function drawPreview(def, row, w, h)
    local spec = def.preview
    if not spec then return end

    local theme = UI.GetTheme()

    if spec.kind == "chip" then
        local text = tostring(row[spec.text] or "")
        local color = Collections.ToColor(row[spec.color])
        draw.RoundedBox(4, 4, 6, PREVIEW_W - 12, h - 12, theme.track)
        DFW.Draw.Text(text, "Small", 4 + (PREVIEW_W - 12) / 2, h / 2, color, TEXT_ALIGN_CENTER)
    end
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
function Editor.Open(moduleId, collId)
    local def = Collections.GetDefinition(moduleId, collId)
    if not def then return end

    if IsValid(frame) then frame:Remove() end

    local work = table.Copy(Collections.Get(moduleId, collId))
    local rowPanels = {}
    local previewW = def.preview and PREVIEW_W or 0

    -- Sized so it fits beside the config menu (each gets half the screen)
    frame = UI.CreateFrame("Edit " .. def.label, math.min(1040, math.floor(ScrW() * 0.5) - 30), 720, "navigation/settings")
    frame:SetSubtitle(def.description and string.sub(def.description, 1, 90) or "Changes apply when you press Save")
    frame.OnRemove = closeSuggestions
    if DFW.ConfigMenu and DFW.ConfigMenu.AttachSide then DFW.ConfigMenu.AttachSide(frame) end

    local content = frame:GetContent()

    -- Top: filter, sort, paste, row count
    local top = vgui.Create("Panel", content)
    top:Dock(TOP)
    top:SetTall(34)

    local count = vgui.Create("DFW.Label", top)
    count:Dock(RIGHT)
    count:SetWide(110)
    count:SetStyle("small")
    count:SetAlign(TEXT_ALIGN_RIGHT)

    local paste = vgui.Create("DFW.Button", top)
    paste:Dock(RIGHT)
    paste:SetWide(110)
    paste:DockMargin(0, 3, 6, 3)
    paste:SetLabel("Paste list")
    paste:SetTooltip("Add many rows at once, one per line")

    local sort = vgui.Create("DFW.Button", top)
    sort:Dock(RIGHT)
    sort:SetWide(80)
    sort:DockMargin(0, 3, 6, 3)
    sort:SetLabel("Sort A-Z")

    local filter = vgui.Create("DFW.TextEntry", top)
    filter:Dock(FILL)
    filter:DockMargin(0, 3, 8, 3)
    filter:SetPlaceholder("Filter rows...")

    -- Bottom: actions
    local bottom = vgui.Create("Panel", content)
    bottom:Dock(BOTTOM)
    bottom:SetTall(42)
    bottom:DockMargin(0, 8, 0, 0)

    local function bottomButton(label, variant, dock, wide)
        local button = vgui.Create("DFW.Button", bottom)
        button:Dock(dock)
        button:SetWide(wide)
        button:DockMargin(dock == RIGHT and 8 or 0, 4, dock == LEFT and 8 or 0, 4)
        button:SetLabel(label)
        button:SetVariant(variant)
        return button
    end

    local save = bottomButton("Save", "primary", RIGHT, 110)
    local cancel = bottomButton("Cancel", "default", RIGHT, 100)
    local add = bottomButton("+ Add row", "default", LEFT, 120)
    local reset = bottomButton("Reset to default", "danger", LEFT, 150)

    -- Column headers
    local header = vgui.Create("Panel", content)
    header:Dock(TOP)
    header:SetTall(24)

    local totalWeight = 0
    for _, col in ipairs(def.columns) do totalWeight = totalWeight + (col.width or 1) end

    header.Paint = function(_, w, h)
        local theme = UI.GetTheme()
        local x = 4 + previewW
        local available = w - 4 - previewW - ACTIONS_W - 6

        if def.preview then DFW.Draw.Text("PREVIEW", "Tiny", 8, h / 2, theme.textMuted) end

        for _, col in ipairs(def.columns) do
            local colW = available * ((col.width or 1) / totalWeight)
            DFW.Draw.Text(string.upper(col.label), "Tiny", x + 4, h / 2, theme.textMuted)
            x = x + colW
        end
    end

    local scroll = vgui.Create("DFW.ScrollPanel", content)
    scroll:Dock(FILL)

    local function updateCount()
        local visible = 0
        for _, panel in ipairs(rowPanels) do
            if panel:IsVisible() then visible = visible + 1 end
        end
        count:SetText(visible .. " / " .. #work .. " rows")
    end

    local function applyFilter()
        local query = string.lower(string.Trim(filter:GetValue()))
        for index, panel in ipairs(rowPanels) do panel:SetVisible(rowMatches(def, work[index], query)) end
        scroll:InvalidateLayout(true)
        updateCount()
    end

    local rebuild

    local function actionButton(parent, icon, tip, onClick, hoverKind)
        local button = vgui.Create("DFW.Button", parent)
        button:SetVariant("ghost")
        button:SetIcon(icon)
        button:SetTooltip(tip)
        button.DoClick = onClick

        -- Hovering an action lights its row so it is obvious which entry it will change (red for delete)
        local baseEntered = button.OnCursorEntered
        button.OnCursorEntered = function(self)
            parent.Hot = hoverKind
            baseEntered(self)
        end
        button.OnCursorExited = function(self) if parent.Hot == hoverKind then parent.Hot = nil end end
        return button
    end

    function rebuild()
        closeSuggestions()
        scroll:Clear()
        rowPanels = {}

        for index, row in ipairs(work) do
            local panel = vgui.Create("Panel", scroll)
            panel:Dock(TOP)
            panel:SetTall(34)
            panel:DockMargin(0, 0, 6, 2)
            rowPanels[index] = panel

            panel.Paint = function(self, w, h)
                local theme = UI.GetTheme()
                draw.RoundedBox(4, 0, 0, w, h, theme.slot)

                -- Hover tint; the delete button turns the whole row red, the other actions light it up
                if self.Hot == "delete" then
                    draw.RoundedBox(4, 0, 0, w, h, UI.WithAlpha(theme.danger, 55))
                    surface.SetDrawColor(theme.danger.r, theme.danger.g, theme.danger.b, 170)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                elseif self.Hot then
                    draw.RoundedBox(4, 0, 0, w, h, UI.WithAlpha(theme.text, 22))
                end

                drawPreview(def, row, w, h)
            end

            local controls = {}
            for _, col in ipairs(def.columns) do controls[#controls + 1] = {col = col, ctl = control(panel, col, row)} end

            -- Rows can be dragged, so a row's position is looked up when it is needed
            local function position()
                for i, other in ipairs(rowPanels) do
                    if other == panel then return i end
                end
                return index
            end

            -- Drag handle: hold it and move the mouse; the row jumps between the other rows and lands where you let go
            local grip = vgui.Create("DButton", panel)
            grip:SetText("")
            grip:SetCursor("sizeall")
            grip:SetTooltip("Drag to change the order")

            grip.Paint = function(self, w, h)
                local theme = UI.GetTheme()
                local color = (self.Held or self:IsHovered()) and theme.accent or theme.textMuted
                surface.SetDrawColor(color.r, color.g, color.b, 255)

                for line = 0, 2 do surface.DrawRect(6, 8 + line * 5, w - 12, 2) end
            end

            grip.OnMousePressed = function(self, code)
                if code ~= MOUSE_LEFT then return end

                self.Held = true
                panel.Hot = "move"
                self:MouseCapture(true)
            end

            grip.OnMouseReleased = function(self)
                self.Held = false
                panel.Hot = nil
                self:MouseCapture(false)
                scroll:InvalidateLayout(true)
            end

            grip.Think = function(self)
                if not self.Held then return end

                local canvas = scroll:GetCanvas()
                local _, my = canvas:CursorPos()

                -- Where would the row go? Before the first other row whose middle is below the cursor.
                local current = position()
                local target = #rowPanels

                for i, other in ipairs(rowPanels) do
                    if other ~= panel and other:IsVisible() and my < other:GetY() + other:GetTall() / 2 then
                        target = i > current and i - 1 or i
                        break
                    end
                end

                if target ~= current then
                    local moved = table.remove(rowPanels, current)
                    local movedRow = table.remove(work, current)
                    table.insert(rowPanels, target, moved)
                    table.insert(work, target, movedRow)

                    -- Docked rows are laid out in child order, so moving the panel moves the row
                    if target < #rowPanels then panel:MoveToBefore(rowPanels[target + 1]) else panel:MoveToFront() end
                    canvas:InvalidateLayout(true)
                end

                -- Near the top or bottom edge: scroll along
                local _, sy = scroll:CursorPos()
                local bar = scroll:GetVBar()

                if sy < 24 then bar:AddScroll(-0.6) elseif sy > scroll:GetTall() - 24 then bar:AddScroll(0.6) end
            end

            local copy = actionButton(panel, "actions/add", "Duplicate this row", function()
                local at = position()
                local clone = table.Copy(row)
                if def.idKey then clone[def.idKey] = tostring(clone[def.idKey]) .. "_copy" end
                table.insert(work, at + 1, clone)
                rebuild()
            end, "copy")

            local remove = actionButton(panel, "actions/delete", "Remove this row", function()
                table.remove(work, position())
                rebuild()
            end, "delete")

            panel.PerformLayout = function(self, w, h)
                local available = w - 4 - previewW - ACTIONS_W - 6
                local x = 4 + previewW

                for _, entry in ipairs(controls) do
                    local colW = available * ((entry.col.width or 1) / totalWeight)
                    local ctlH = (entry.col.type == "bool") and 22 or 26
                    entry.ctl:SetPos(x, (h - ctlH) / 2)
                    entry.ctl:SetSize(entry.col.type == "bool" and 44 or colW - 8, ctlH)
                    x = x + colW
                end

                local bx = w - ACTIONS_W
                for _, button in ipairs({grip, copy, remove}) do
                    button:SetSize(26, 26)
                    button:SetPos(bx, (h - 26) / 2)
                    bx = bx + 28
                end
            end

            -- Model preview: a small icon for rows that name a model
            if def.preview and def.preview.kind == "model" then
                local icon = vgui.Create("DModelPanel", panel)
                icon:SetPos(4, 2)
                icon:SetSize(30, 30)
                icon:SetModel(tostring(row[def.preview.model] or ""))
                icon:SetMouseInputEnabled(false)
                icon.LayoutEntity = function() end

                local entity = icon.Entity
                if IsValid(entity) then
                    local mins, maxs = entity:GetRenderBounds()
                    local size = math.max(maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z, 1)
                    icon:SetCamPos(Vector(size * 1.1, size * 0.9, size * 0.6))
                    icon:SetLookAt((mins + maxs) / 2)
                    icon:SetFOV(40)
                end
            end
        end

        applyFilter()
    end

    filter.OnChange = applyFilter

    add.DoClick = function()
        local row = Collections.NewRow(moduleId, collId)
        if def.idKey then row[def.idKey] = "new_" .. (#work + 1) end
        work[#work + 1] = row
        filter:SetText("")
        rebuild()
        timer.Simple(0.05, function()
            if IsValid(scroll) then scroll:GetVBar():AnimateTo(scroll:GetVBar().CanvasSize, 0.2) end
        end)
    end

    sort.DoClick = function()
        local key = def.columns[1].key
        for _, col in ipairs(def.columns) do
            if col.type == "string" then key = col.key break end
        end

        table.sort(work, function(a, b) return string.lower(tostring(a[key])) < string.lower(tostring(b[key])) end)
        rebuild()
    end

    -- Paste list: one row per line. The line fills the first text column; "a=b" or "a, b" or a tab fills the first
    -- two columns (a weapon and its chance, an item and its price ...)
    paste.DoClick = function()
        local box = UI.CreateFrame("Paste list", 520, 380, "navigation/settings", {compact = true})
        local boxContent = box:GetContent()

        local hint = vgui.Create("DFW.Paragraph", boxContent)
        hint:Dock(TOP)
        hint:SetStyle("small")
        hint:SetText("One row per line. Use  name=value  (or a comma or tab) to fill the first two columns.")

        local text = vgui.Create("DTextEntry", boxContent)
        text:Dock(FILL)
        text:DockMargin(0, 6, 0, 6)
        text:SetMultiline(true)
        text:SetFont(UI.Font("Body"))

        local addLines = vgui.Create("DFW.Button", boxContent)
        addLines:Dock(BOTTOM)
        addLines:SetTall(34)
        addLines:SetVariant("primary")
        addLines:SetLabel("Add these rows")
        addLines.DoClick = function()
            local first, second
            for _, col in ipairs(def.columns) do
                if not first then first = col elseif not second then second = col end
            end
            for _, col in ipairs(def.columns) do
                if col.type == "string" then
                    if first ~= col then second = first end
                    first = col
                    break
                end
            end

            for rawLine in string.gmatch(text:GetValue(), "[^\r\n]+") do
                local line = string.Trim(rawLine)
                if line ~= "" then
                    local row = Collections.NewRow(moduleId, collId)
                    local a, b = string.match(line, "^(.-)%s*[=,\t]%s*(.+)$")

                    row[first.key] = a or line
                    if b and second and second ~= first then
                        row[second.key] = second.type == "number" and (tonumber(b) or row[second.key]) or b
                    end

                    work[#work + 1] = row
                end
            end

            box:Close()
            rebuild()
        end
    end

    reset.DoClick = function()
        UI.Confirm("Reset " .. def.label, "Replace every row with the defaults? This also discards your unsaved edits.", function()
            work = table.Copy(Collections.Normalize(moduleId, collId, def.default) or {})
            rebuild()
        end, {danger = true, confirmLabel = "Reset"})
    end

    cancel.DoClick = function() frame:Close() end

    save.DoClick = function()
        local Net = DFW.Net
        Net.Start("Collections.Save")
        net.WriteString(moduleId)
        net.WriteString(collId)
        if not Net.WriteJSON({rows = work}) then
            net.Abort()
            UI.Notify("That is too much data to save at once.", "danger", 3)
            return
        end
        net.SendToServer()
    end

    rebuild()

    -- The server answers every save: close on success, explain on failure
    local hookId = "DFW.CollectionEditor." .. moduleId .. "." .. collId
    hook.Add("DFW_CollectionResult", hookId, function(ok, resultModule, resultColl, reason)
        if resultModule ~= moduleId or resultColl ~= collId then return end
        if not IsValid(frame) then hook.Remove("DFW_CollectionResult", hookId) return end

        if ok then
            UI.Notify(def.label .. " saved.", "success", 2)
            frame:Close()
            hook.Remove("DFW_CollectionResult", hookId)
        else
            UI.Notify(explain(reason), "danger", 4)
        end
    end)
end
