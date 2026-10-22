AcmeStarter.Config = {
    IntervalSeconds = 120,
    Prefix = "[Info]"
}

AcmeStarter.DefaultAnnouncements = {
    {id = "welcome", text = "Welcome to the server.", enabled = true},
    {id = "help", text = "Ask an admin if you need a hand.", enabled = true}
}

AcmeStarter.Announcements = {}

function AcmeStarter.BuildAnnouncements(rows)
    local list = {}

    for _, row in ipairs(rows) do
        if row.enabled then list[#list + 1] = row.text end
    end

    AcmeStarter.Announcements = list
end

function AcmeStarter.Enabled()
    return not (DFW and DFW.Bind) or DFW.Bind.Enabled("starter")
end

AcmeStarter.BuildAnnouncements(AcmeStarter.DefaultAnnouncements)
