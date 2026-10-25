DFW.Access = DFW.Access or {}

-- Default policy: superadmins only. Permission addons can answer explicitly by
-- returning true/false from the DFW_CanAccessConfig hook.
function DFW.Access.CanConfigure(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local override = hook.Run("DFW_CanAccessConfig", ply)
    if override ~= nil then return override == true end
    return ply:IsSuperAdmin()
end
