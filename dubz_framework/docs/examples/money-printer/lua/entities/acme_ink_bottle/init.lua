AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local config = AcmePrinters.Config

function ENT:Initialize()
    self:SetModel(config.BottleModel)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    local physics = self:GetPhysicsObject()
    if IsValid(physics) then physics:Wake() end

    self.Used = false
end

function ENT:TryAttach(other)
    if self.Used then return end
    if not (IsValid(other) and other.AcceptInk) then return end

    self.Used = true

    timer.Simple(0, function()
        if not (IsValid(self) and IsValid(other)) then return end

        if other:AcceptInk(self) then
            self:Remove()
        else
            self.Used = false
        end
    end)
end

function ENT:StartTouch(other)
    self:TryAttach(other)
end

function ENT:PhysicsCollide(data)
    self:TryAttach(data.HitEntity)
end
