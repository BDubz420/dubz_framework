AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local config = AcmePrinters.Config
local adapter = AcmePrinters.Adapter
local STATE = AcmePrinters.State
local THINK_INTERVAL = 0.5
local NOTICE_COOLDOWN = 3
local MAX_HEAT = 100

local function say(ply, key, kind, values)
    adapter.Notify(ply, AcmePrinters.Phrase(key, values), kind)
end

function ENT:Initialize()
    self:SetModel(config.Model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local physics = self:GetPhysicsObject()
    if IsValid(physics) then physics:Wake() end

    self.SeizeReward = config.SeizeReward
    self.Overheated = false
    self.Exploded = false
    self.NextNotice = 0
    self.Modules = {}
    self.LastThink = CurTime()

    self:SetStored(0)
    self:SetInk(config.InkMax)
    self:SetHeat(0)
    self:SetCoolers(0)
    self:SetIntegrity(config.Health)
    self:SetNextPrint(CurTime() + config.PrintSeconds)
    self:SetState(STATE.Idle)
end

function ENT:NotifyOwner(key, kind, values)
    local now = CurTime()

    if now < self.NextNotice then return end

    self.NextNotice = now + NOTICE_COOLDOWN
    say(self:Getowning_ent(), key, kind, values)
end

function ENT:ComputeState()
    if self:GetStored() >= config.StoreMax then return STATE.Full end
    if self.Overheated then return STATE.Overheated end
    if self:GetInk() < config.InkPerPrint then return STATE.NoInk end

    return STATE.Printing
end

function ENT:UpdateOverheat()
    local heat = self:GetHeat()

    if heat >= config.ShutdownHeat then
        self.Overheated = true
    elseif self.Overheated and heat <= config.ResumeHeat then
        self.Overheated = false
    end
end

function ENT:CoolingRate()
    return config.CoolPerSecond + self:GetCoolers() * config.CoolerPerSecond
end

function ENT:Cool(delta)
    self:SetHeat(math.max(self:GetHeat() - self:CoolingRate() * delta, 0))
    self:UpdateOverheat()
end

function ENT:RollCritical(delta)
    if self:GetHeat() < config.CriticalHeat then return end

    if math.random() * 100 < config.ExplodeChance * delta then
        self:Explode()
    end
end

function ENT:Print(now)
    if now < self:GetNextPrint() then return end

    self:SetNextPrint(now + config.PrintSeconds)

    if self:GetState() ~= STATE.Printing then return end

    self:SetStored(math.min(self:GetStored() + config.PrintAmount, config.StoreMax))
    self:SetInk(math.max(self:GetInk() - config.InkPerPrint, 0))
    self:SetHeat(math.min(self:GetHeat() + config.HeatPerPrint, MAX_HEAT))
    self:UpdateOverheat()
end

function ENT:StartLoop()
    if self.Loop then return end

    self.Loop = CreateSound(self, config.LoopSound)
    self.Loop:SetSoundLevel(config.SoundLevel)
    self.Loop:PlayEx(1, 100)
end

function ENT:StopLoop()
    if not self.Loop then return end

    self.Loop:Stop()
    self.Loop = nil
end

function ENT:Refresh()
    local state = self:ComputeState()

    self:SetState(state)

    if config.Sound and state == STATE.Printing then
        self:StartLoop()
    else
        self:StopLoop()
    end
end

function ENT:Think()
    local now = CurTime()
    local delta = now - self.LastThink

    self.LastThink = now

    if AcmePrinters.Enabled() and not self.Exploded then
        self:Cool(delta)
        self:RollCritical(delta)
        self:Print(now)
        self:Refresh()
    end

    self:NextThink(now + THINK_INTERVAL)

    return true
end

function ENT:Collect(ply)
    local amount = self:GetStored()

    if amount <= 0 then
        say(ply, "NothingToCollect", 1)
        return
    end

    adapter.AddMoney(ply, amount)
    self:SetStored(0)
    say(ply, "Collected", 0, {amount = adapter.FormatMoney(amount)})
    hook.Run("AcmePrintersCollected", ply, self, amount)
end

function ENT:AcceptInk(bottle)
    if not AcmePrinters.Enabled() or self.Exploded then return false end

    if self:GetInk() >= config.InkMax then
        self:NotifyOwner("InkFull", 1)
        return false
    end

    self:SetInk(math.min(self:GetInk() + config.InkPerBottle, config.InkMax))
    self:EmitSound(config.FillSound)
    self:NotifyOwner("InkAdded", 0)

    return true
end

function ENT:LayoutCoolers()
    local valid = {}

    for _, module in ipairs(self.Modules) do
        if IsValid(module) then
            module:SetLocalPos(Vector(config.CoolerOffsetX, config.CoolerOffsetY + #valid * config.CoolerSpacing, config.CoolerOffsetZ))
            module:SetLocalAngles(angle_zero)
            valid[#valid + 1] = module
        end
    end

    self.Modules = valid
    self:SetCoolers(#valid)
end

function ENT:InstallCooler(module)
    module:SetSolid(SOLID_NONE)
    module:SetMoveType(MOVETYPE_NONE)
    module:SetParent(self)

    self.Modules[#self.Modules + 1] = module
    self:LayoutCoolers()
    self:EmitSound(config.InstallSound)
    self:NotifyOwner("CoolerInstalled", 0)
end

function ENT:AcceptCoolant(module)
    if not AcmePrinters.Enabled() or self.Exploded then return false end

    if config.CoolantMode == "install" then
        if self:GetCoolers() >= config.CoolerSlots then
            self:NotifyOwner("CoolerFull", 1)
            return false
        end

        self:InstallCooler(module)

        return "installed"
    end

    if self:GetHeat() <= 0 then
        self:NotifyOwner("AlreadyCool", 1)
        return false
    end

    self:SetHeat(math.max(self:GetHeat() - config.CoolantHeatDrop, 0))
    self:UpdateOverheat()
    self:EmitSound(config.FillSound)
    self:NotifyOwner("Cooled", 0)

    return "consumed"
end

function ENT:Use(activator)
    if not AcmePrinters.Enabled() then return end
    if not (IsValid(activator) and activator:IsPlayer()) then return end

    self:Collect(activator)
end

function ENT:OnTakeDamage(damage)
    if self.Exploded then return end

    self:SetIntegrity(math.Round(self:GetIntegrity() - damage:GetDamage()))

    if self:GetIntegrity() <= 0 then
        self:Explode()
    end
end

function ENT:Explode()
    if self.Exploded then return end

    self.Exploded = true

    local origin = self:GetPos()
    local owner = self:Getowning_ent()
    local effect = EffectData()

    effect:SetOrigin(origin)
    effect:SetScale(1)
    util.Effect("Explosion", effect)
    util.BlastDamage(self, IsValid(owner) and owner or self, origin, config.ExplosionRadius, config.ExplosionDamage)
    say(owner, "Exploded", 1, {name = config.Name})
    self:Remove()
end

function ENT:OnRemove()
    self:StopLoop()
end
