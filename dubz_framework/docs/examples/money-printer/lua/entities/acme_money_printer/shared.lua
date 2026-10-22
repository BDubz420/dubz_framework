ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = AcmePrinters.Config.Name
ENT.Category = AcmePrinters.Config.SpawnCategory
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "Stored")
    self:NetworkVar("Int", 1, "Integrity")
    self:NetworkVar("Int", 2, "State")
    self:NetworkVar("Int", 3, "Coolers")
    self:NetworkVar("Float", 0, "Ink")
    self:NetworkVar("Float", 1, "Heat")
    self:NetworkVar("Float", 2, "NextPrint")
    self:NetworkVar("Entity", 0, "owning_ent")
end
