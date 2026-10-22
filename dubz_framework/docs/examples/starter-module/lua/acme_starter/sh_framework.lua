DFW.Bind.Module({
    id = "starter",
    name = "Announcements",
    version = "1.0.0",
    icon = "communication/notifications",
    description = "Sends a message from a list to everyone on a timer.",
    dependencies = {"dubz_core"}
}, AcmeStarter.Config, {
    {path = "IntervalSeconds", label = "Seconds Between Messages", min = 10, max = 3600, decimals = 0, group = "Timing"},
    {path = "Prefix", label = "Message Prefix", maxLength = 20, group = "Look"}
}, {
    collections = {
        {
            id = "announcements",
            label = "Announcements",
            description = "The messages that are sent, one after another. Switch a row off to skip it.",
            idKey = "id",
            columns = {
                {key = "id", label = "ID", type = "string", width = 1, maxLength = 30},
                {key = "text", label = "Message", type = "string", width = 4, maxLength = 200},
                {key = "enabled", label = "On", type = "bool", width = 0.6}
            },
            default = AcmeStarter.DefaultAnnouncements
        }
    }
})

DFW.Collections.Watch("starter", "announcements", AcmeStarter.BuildAnnouncements)
