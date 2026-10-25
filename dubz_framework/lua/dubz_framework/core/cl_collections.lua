local Collections = DFW.Collections
local Net = DFW.Net

Net.Receive("Collections.Sync", function()
    local moduleId, collId = net.ReadString(), net.ReadString()
    local data = Net.ReadJSON()

    if data and istable(data.rows) then
        if Collections.GetDefinition(moduleId, collId) then
            Collections.ApplyRemote(moduleId, collId, data.rows)
        else
            Collections.Waiting[moduleId .. "/" .. collId] = data.rows
        end
    end
end, {maxBits = 600000})

Net.Receive("Collections.Result", function()
    local ok = net.ReadBool()
    local moduleId, collId, reason = net.ReadString(), net.ReadString(), net.ReadString()
    hook.Run("DFW_CollectionResult", ok, moduleId, collId, reason)
end)

local asked = false
hook.Add("DFW_PublicConfigReceived", "DFW.Collections.Request", function()
    if asked then return end
    asked = true

    Net.Start("Collections.Request")
    net.SendToServer()
end)
