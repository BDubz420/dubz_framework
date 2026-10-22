local config = AcmeStarter.Config
local TIMER_NAME = "AcmeStarter_Announce"
local nextAt = 0
local position = 0

local function announce()
    local list = AcmeStarter.Announcements

    if #list == 0 then return end

    position = position % #list + 1
    PrintMessage(HUD_PRINTTALK, config.Prefix .. " " .. list[position])
end

timer.Create(TIMER_NAME, 1, 0, function()
    if not AcmeStarter.Enabled() or CurTime() < nextAt then return end

    nextAt = CurTime() + config.IntervalSeconds
    announce()
end)
