DFW.Access = DFW.Access or {}

function DFW.Access.CanConfigure(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local override = hook.Run("DFW_CanAccessConfig", ply)
    if override ~= nil then return override == true end
    return ply:IsSuperAdmin()
end
