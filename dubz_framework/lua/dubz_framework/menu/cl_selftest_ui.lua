-- Client-only self-test group, run by `dfw_selftest_cl` after the shared tests.
-- Creates every registered control inside a hidden parent to prove each one
-- builds and paints without errors, then removes it again.
local controls = {
    "DFW.Frame", "DFW.Button", "DFW.TextEntry", "DFW.Toggle", "DFW.Checkbox", "DFW.Slider",
    "DFW.Dropdown", "DFW.ColorButton", "DFW.ScrollPanel", "DFW.Card", "DFW.Label",
    "DFW.Paragraph", "DFW.Badge", "DFW.ProgressBar", "DFW.NavButton", "DFW.TabBar"
}

table.insert(DFW.SelfTest.Extra, function(run)
    local theme = DFW.UI.GetTheme()
    local complete = true
    for _, key in ipairs(DFW.Themes.GetRequiredColors()) do
        if theme[key] == nil then complete = false end
    end
    run.check("UI theme resolves every colour token", complete)
    run.check("UI fonts defined", DFW.UI.Font("Body") == "DFW.Body" and DFW.UI.Font("Title") == "DFW.Title")
    run.check("icon catalogue loads (navigation/settings)", DFW.Icons.Exists("navigation/settings"))

    local holder = vgui.Create("Panel")
    holder:SetSize(300, 200)
    holder:SetVisible(false)

    for _, name in ipairs(controls) do
        local registered = vgui.GetControlTable(name) ~= nil
        run.check("control registered: " .. name, registered)
        if registered then
            local ok, result = pcall(function()
                local panel = vgui.Create(name, name == "DFW.Frame" and nil or holder)
                panel:SetSize(200, 40)
                if panel.PaintManual then panel:PaintManual() end
                panel:Remove()
            end)
            run.check("control builds and removes cleanly: " .. name, ok, result)
        end
    end

    holder:Remove()

    local toastOk, toastError = pcall(function()
        local toast = DFW.UI.Notify("Self test toast", "info", 0.2)
        if IsValid(toast) then toast:Remove() end
    end)
    run.check("toast notification builds", toastOk, toastError)

    local wrapped = DFW.UI.WrapText("one two three four five six seven eight nine ten", "Body", 80)
    run.check("text wrapping produces multiple lines", #wrapped > 1)
end)
