# Garry's Mod Patterns

Recipes for the things modules are made of. Each snippet follows [code-style.md](code-style.md) and assumes the namespace `AcmePrinters`, a config table `AcmePrinters.Config`, and an `Enabled()` function. Replace the names with the project's (see [project-profile.md](project-profile.md)). DarkRP is the worked example of a gamemode adapter; the rest of the patterns are gamemode-neutral.

## Contents

1. [Entities](#entities)
2. [Physical interaction](#physical-interaction)
3. [Weapons](#weapons)
4. [NPCs](#npcs)
5. [3D2D overlays](#3d2d-overlays)
6. [HUD cards](#hud-cards)
7. [Windows](#windows)
8. [Networking](#networking)
9. [Gamemode integration](#gamemode-integration)
10. [Ownership](#ownership)
11. [World data and admin tools](#world-data-and-admin-tools)
12. [Persistence](#persistence)
13. [Sounds and effects](#sounds-and-effects)
14. [Timing](#timing)
15. [Security](#security)
16. [Performance](#performance)

## Entities

A scripted entity is a folder `lua/entities/<class>/` with three files.

`shared.lua`: identity and network variables.

```lua
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Money Printer"
ENT.Author = "Acme"
ENT.Category = "Acme Printers"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "Stored")
    self:NetworkVar("Float", 0, "Ink")
    self:NetworkVar("Entity", 0, "owning_ent")
end
```

- `ENT.Category` is the spawn menu tab. Read it from config (`ENT.Category = AcmePrinters.Config.SpawnCategory`) so the project chooses it; the default is derived from the project name. `AdminOnly = true` keeps spawn-menu spawning to admins; players obtain it through the project's shop.
- Each network variable type has its own slot numbering starting at 0. Keep a variable for anything the client draws.
- Name the owner variable `owning_ent`: DarkRP fills it on purchased entities, and the adapter fills it elsewhere.

`init.lua`: server behaviour.

```lua
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local config = AcmePrinters.Config
local THINK_INTERVAL = 0.5

function ENT:Initialize()
    self:SetModel(config.Model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local physics = self:GetPhysicsObject()
    if IsValid(physics) then physics:Wake() end

    self.SeizeReward = config.SeizeReward
    self:SetInk(config.InkMax)
end

function ENT:Think()
    if AcmePrinters.Enabled() then
        self:Tick()
    end

    self:NextThink(CurTime() + THINK_INTERVAL)
    return true
end

function ENT:Use(activator)
    if not AcmePrinters.Enabled() then return end
    if not (IsValid(activator) and activator:IsPlayer()) then return end
    self:Collect(activator)
end

function ENT:OnTakeDamage(damage)
    self:SetIntegrity(self:GetIntegrity() - damage:GetDamage())
end

function ENT:OnRemove()
    self:StopLoop()
end
```

`cl_init.lua`: client drawing.

```lua
include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end
```

Entity rules:

- Entities read the config table at the moment of use; never copy a setting into `self` at spawn unless the setting is documented as "applies to entities spawned after the change" (health is the usual case).
- `Think` runs `NextThink` spaced for gameplay (0.25 to 1 second). Return `true` after `NextThink`.
- Per-entity timers are unnecessary; use the tick and timestamps.
- Stop loops and remove child entities in `OnRemove`.
- Set `ENT.SeizeReward` when the gamemode lets enforcement seize it (DarkRP reads it).
- Use `SetUseType(SIMPLE_USE)` for press-once-to-use; use `CONTINUOUS_USE` only for hold-to-use.
- A physics entity needs `PhysicsInit`, `SetMoveType` and `SetSolid` in that order.
- For props that must not be picked up by gravity guns or physics tools, return `false` from the relevant hooks (`GravGunPunt`, `PhysgunPickup`) for that class, in a hook with a unique id.

### A single-file entity

Small entities can live in `lua/entities/<class>.lua` with `if SERVER then ... else ... end` blocks. Prefer the folder form for anything with more than a few functions.

## Physical interaction

Players should interact with the world the way the fiction suggests. Ink goes in by carrying a bottle to the printer. A part is installed by fitting it. A repair is done with a tool at the thing. Key chords and hidden binds feel arbitrary, are not discoverable and cannot be seen by other players.

### The ladder

Choose the highest rung that fits.

| Rung | Use for | Example |
| --- | --- | --- |
| **1. Contact** | Supplies, ammo, fuel, ink, parts, add-on modules | Touch a bottle to a printer to refill it |
| **2. Use (E) on the object** | The one main action of a thing | Collect the money, open the door, start the machine |
| **3. Hold E** | Slow actions | Searching, repairing, hacking, with a progress bar |
| **4. A tool or weapon** | Actions that need equipment | A wrench, a lockpick, a scanner |
| **5. An NPC or a window** | Services and choices | Buying, hiring, picking a recipe |

Avoid, unless the request asks for it:

| Do not | Instead |
| --- | --- |
| `Shift+E`, `Ctrl+E`, `Alt+E` or a custom key for a gameplay action | A supply or module entity touched to the object |
| A console or chat command to refill, repair or upgrade | The same physical entity |
| A menu for something that happens at an object | Use (E) or contact |
| Instant refills that cost money straight from the wallet | A purchasable supply entity, sold in the shop with a price and a per-player limit |
| Several secondary actions on one key | Several entities, each doing one thing |

### Supplies: consumed on contact

A supply is a physics prop. When it touches a host that wants it, the host takes it and the supply is removed. The host decides; the supply never changes the host's state itself.

Supply `init.lua`:

```lua
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
```

Host method:

```lua
function ENT:AcceptInk(bottle)
    if not AcmePrinters.Enabled() or self.Exploded then return false end

    if self:GetInk() >= config.InkMax then
        self:NotifyOwner("InkFull", 1)
        return false
    end

    self:SetInk(math.min(self:GetInk() + config.InkPerBottle, config.InkMax))
    self:EmitSound(config.FillSound)

    return true
end
```

### Modules: installed for good, or used up once

A module is a supply with two behaviours, chosen by a setting (a `choices = {"install", "consume"}` setting is the usual form). Support both unless the request names one.

- **Install:** the host parents the module at a slot position, switches its physics off and counts it. The module stays visible on the machine, the machine's effect grows (more cooling, more output), and removing the host removes its children.
- **Consume:** the host applies a one-time effect (lower the heat, add a charge) and the module is removed.

The host answers with `false` (refused), `"installed"` or `"consumed"`, and the module reacts:

```lua
local result = other:AcceptCoolant(self)

if result == "consumed" then
    self:Remove()
elseif not result then
    self.Used = false
end
```

Host install:

```lua
function ENT:InstallCooler(module)
    local slot = self:GetCoolers()
    local offset = Vector(config.CoolerOffsetX, config.CoolerOffsetY + slot * config.CoolerSpacing, config.CoolerOffsetZ)

    module:SetSolid(SOLID_NONE)
    module:SetMoveType(MOVETYPE_NONE)
    module:SetParent(self)
    module:SetLocalPos(offset)
    module:SetLocalAngles(angle_zero)

    self:SetCoolers(slot + 1)
end
```

### Rules

- **Both touch hooks, one function.** Call a single `TryAttach` from `StartTouch` and `PhysicsCollide`, and defer the work with `timer.Simple(0, ...)`: changing entities inside a collision callback is unsafe.
- **Duck-type the host.** Check the host has the method (`other.AcceptInk`), not its class name, so other machines can accept the same supply.
- **The host validates everything:** the module is enabled, the host is alive, there is room, the slot is free. A refused supply stays intact and can be used elsewhere.
- **Re-layout on change.** The host keeps a list of its installed modules and one function that positions them from the current dial-in settings. Call it on install and, debounced, whenever a placement setting changes ([config-design.md](config-design.md)); otherwise the dial-in values never move what is already attached.
- **One use.** A `Used` flag stops a supply attaching twice in one frame and is cleared only if the host refused.
- **Everything is a setting:** the model, the name, the price, the per-player limit, the amount, the mode, the slots, the effect size, the sounds, and the slot offsets as a dial-in group.
- **Sold through the shop,** with its own entry, limit and command, so supplies are part of the economy. Admin-spawnable from the spawn menu.
- **Feedback:** a sound from the host and a short message to the owner, rate limited so a bouncing supply cannot spam.
- **Owner messages** go through the adapter, with text from the `Text` settings.
- **Nothing breaks without the framework:** the entity files read the config table, not the framework.

## Weapons

A scripted weapon is a file `lua/weapons/<class>.lua` or a folder with `shared.lua`, `init.lua`, `cl_init.lua`.

```lua
SWEP.Base = "weapon_base"
SWEP.PrintName = "Lock Pick"
SWEP.Author = "Acme"
SWEP.Category = "Acme Tools"
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.Slot = 1
SWEP.DrawAmmo = false
SWEP.HoldType = "normal"
SWEP.ViewModel = "models/weapons/c_crowbar.mdl"
SWEP.WorldModel = "models/weapons/w_crowbar.mdl"
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

local config = AcmeTools.Config

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + config.UseDelay)

    if CLIENT or not AcmeTools.Enabled() then return end

    AcmeTools.UseTool(self:GetOwner(), self)
end

function SWEP:SecondaryAttack() end
```

Weapon rules:

- Decide on the server. Client prediction only animates.
- A timed action (lock picking, repairs) is a server state with a start time and a duration read from config, published to the client with a network variable or `SetNWFloat` for the progress bar. Interrupt it when the target is lost or the player moves away.
- Give weapons through the gamemode's job or shop systems (through the adapter), or `ply:Give`. Do not edit the gamemode's weapon lists.
- Reuse the tool base pattern: a shared base weapon plus one small file per tool when several tools behave alike.

## NPCs

An interactable NPC is an `ai` entity.

`shared.lua`:

```lua
ENT.Type = "ai"
ENT.Base = "base_ai"
ENT.PrintName = "Foreman"
ENT.Author = "Acme"
ENT.Category = "Acme NPCs"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.AutomaticFrameAdvance = true
```

`init.lua`:

```lua
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local config = AcmeJobs.Config

function ENT:Initialize()
    self:SetModel(config.NpcModel)
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetNPCState(NPC_STATE_SCRIPT)
    self:SetSolid(SOLID_BBOX)
    self:CapabilitiesAdd(bit.bor(CAP_ANIMATEDFACE, CAP_TURN_HEAD))
    self:SetUseType(SIMPLE_USE)
    self:SetMaxYawSpeed(90)
    self:DropToFloor()
end

function ENT:OnTakeDamage() return 0 end

function ENT:AcceptInput(name, activator)
    if name ~= "Use" then return end
    if not (IsValid(activator) and activator:IsPlayer()) then return end
    AcmeJobs.Talk(activator, self)
end
```

NPC rules:

- Overhead text is the NPC's name and a short prompt, drawn through the project's overhead style (see [styles-and-themes.md](styles-and-themes.md)). Name, prompt, distance and scale are settings.
- Conversations that give jobs, shops or services run on the server; the client only shows the dialog.
- NPC models, names, prompts and idle poses are settings. Admin-placed NPCs keep their positions through `DFW.Data` per map.

## 3D2D overlays

A 3D2D overlay is a card drawn in the world. Build it from the library and the active theme so it matches the rest of the project.

### Facing the viewer (a label above an NPC or object)

```lua
function ENT:Draw()
    self:DrawModel()

    if not (DFW and DFW.UI) then return end

    local config = AcmeJobs.Config
    local origin = self:GetPos() + Vector(0, 0, config.LabelHeight)

    DFW.Draw.Billboard(origin, config.LabelScale, config.LabelDistance, function()
        local theme = DFW.UI.GetTheme()

        DFW.Draw.Text(config.NpcName, "Heading", 0, 0, theme.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        DFW.Draw.Text(config.NpcPrompt, "Small", 0, 4, theme.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end)
end
```

`DFW.Draw.Billboard(position, scale, distance, callback)` turns the canvas to face the viewer, fades it out towards the distance limit, pairs the `cam` calls, resets the alpha and catches errors in the callback, so a bug in a label cannot break the frame. Name, prompt, height, scale and distance are settings. When a project wants several looks for labels (a plate, plain outlined text, a badge), draw through a style registry instead of drawing here: see [styles-and-themes.md](styles-and-themes.md).

### Fixed to a surface (a screen on a machine)

```lua
function ENT:Draw()
    self:DrawModel()

    if not (DFW and DFW.UI) then return end

    local config = AcmePrinters.Config
    local angle = self:GetAngles()

    angle:RotateAroundAxis(angle:Up(), config.ScreenYaw)

    DFW.Draw.World(self:GetPos() + self:GetUp() * config.ScreenUp, angle, config.ScreenScale, config.ScreenDistance, function()
        AcmePrinters.DrawScreen(self)
    end)
end
```

`DFW.Draw.World(position, angle, scale, distance, callback)` skips drawing beyond the distance, fades towards it, pairs `cam.Start3D2D` and `cam.End3D2D`, resets the alpha multiplier and catches errors in the callback. Use it for every world-space overlay instead of calling `cam` yourself.

Recipe rules:

- Screen position, height, yaw and scale are settings (`ScreenUp`, `ScreenYaw`, `ScreenScale`), because every model needs different values. Give the admin sliders for them (`decimals = 3` for the scale).
- Draw on a fixed canvas (for example 300 by 260 units), centred on the origin, then scale the whole thing with the scale argument. Write the layout once in canvas units.
- Draw sharp text with larger fonts and a small scale: create fonts of 20 to 28 pixels with `DFW.UI.CreateFont(name, size, weight)` and use scales around 0.05 to 0.12.
- Get every colour from `DFW.UI.GetTheme()`. Use `theme.background` for the card, `theme.text` and `theme.textMuted` for text, `theme.track` for bar backgrounds, and `theme.accent`, `theme.success`, `theme.warning`, `theme.danger`, `theme.info` for state.
- Build the screen from small named functions: `drawHeader`, `drawBars`, `drawFooter`.

### A bar and a card

```lua
local function drawMeter(theme, x, y, width, label, fraction, color, value)
    DFW.Draw.Text(label, "Small", x, y, theme.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    DFW.Draw.Text(value, "Small", x + width, y, theme.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    DFW.Draw.Bar(x, y + 18, width, 12, fraction, color)
end
```

`DFW.Draw.Bar(x, y, w, h, fraction, color)` draws the themed track and fill. `DFW.Draw.Card(x, y, w, h, {radius = "MD", color = theme.background})` paints the card.

The money printer example builds a complete screen this way.

## HUD cards

HUD elements are drawn from the active theme: cards and bars use `theme.background`, `theme.text`, `theme.track` and `theme.accent`, so whatever look the project chose carries through. Elements that can look more than one way go through a style registry ([styles-and-themes.md](styles-and-themes.md)).

```lua
hook.Add("HUDPaint", "AcmeTools_Progress", function()
    local progress = LocalPlayer():GetNWFloat("AcmeTools_Progress", 0)

    if progress <= 0 then return end

    DFW.Draw.ProgressCard(ScrW() / 2, ScrH() * 0.62, 240, "Picking the lock", progress)
end)
```

- Draw only when there is something to show; return at the top otherwise.
- Prefer `DFW.Draw.ProgressCard` for timed actions.
- Position relative to `ScrW()` and `ScrH()`; scale sizes with `DFW.UI.Scale(value)`.
- Messages go to chat or a toast (`DFW.UI.Notify`), not custom popups.

## Windows

Anything with choices is a window built from the library.

```lua
function AcmeShops.OpenShop(items)
    local frame = DFW.UI.CreateFrame("Shop", 520, 420, "economy/storefront", {compact = true, module = "shops"})
    local content = frame:GetContent()

    local list = vgui.Create("DFW.ScrollPanel", content)
    list:Dock(FILL)

    for _, item in ipairs(items) do
        local row = vgui.Create("DFW.Button", list)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)
        row:SetTall(32)
        row:SetLabel(item.name .. "  " .. item.price)
        row.DoClick = function() AcmeShops.RequestBuy(item.id) end
    end

    return frame
end
```

- Create windows with `DFW.UI.CreateFrame(title, width, height, iconKey, options)`; build inside `frame:GetContent()`.
- Pass `module = "<module id>"` so hover sounds follow the module's own setting, and `ui = true` in the bind options so that setting exists.
- Open only one instance: keep the frame in a local, and if it is valid, remove or focus it before creating another.
- Close with `frame:Close()`. Return `false` from `OnClose` to refuse.
- Buttons, inputs, lists, dialogs and bars are in [ui-library.md](ui-library.md). Do not use raw `DButton`, `DFrame` or hand-painted panels when a library control exists.
- Windows ask the server to do things and show the result. They never decide.

## Networking

Use `DFW.Net` for module messages: names are namespaced, receivers can be rate limited and size capped, and tables travel as compressed JSON.

```lua
DFW.Net.Pool("shops_buy")
DFW.Net.Pool("shops_state")
```

Server receiver:

```lua
DFW.Net.Receive("shops_buy", function(_, ply)
    local itemId = net.ReadString()
    AcmeShops.Buy(ply, itemId)
end, {maxBits = 512, cooldown = 0.5, access = function(ply) return ply:Alive() end})
```

Client request:

```lua
function AcmeShops.RequestBuy(itemId)
    DFW.Net.Start("shops_buy")
    net.WriteString(itemId)
    net.SendToServer()
end
```

Server response with a table:

```lua
function AcmeShops.SendState(ply)
    DFW.Net.Start("shops_state")
    DFW.Net.WriteJSON({items = AcmeShops.PublicItems()})
    net.Send(ply)
end
```

Client receive:

```lua
DFW.Net.Receive("shops_state", function()
    local data = DFW.Net.ReadJSON()
    if not data then return end
    AcmeShops.State = data
end)
```

Rules:

- `Pool` runs on the server (it registers the name); call it from a shared file so both realms load the same list.
- The client only ever sends **intent** (an id, a choice). The server looks up price, stock, distance and permission itself.
- Every receiver checks the player is valid and allowed, that ids exist, that numbers are in range, and that entities are valid and close enough.
- Set `cooldown` for anything a player can spam, and `maxBits` for fixed-size messages.
- Anything the client only needs to display and that never changes per frame goes through a network variable, not a message.
- When a net message is simpler as a plain `net` call (a single entity update), use `util.AddNetworkString` with a name `<Namespace>_<Purpose>`; the validation rules are the same.

## Gamemode integration

Keep the gamemode behind one adapter file (`sh_adapter.lua`, described in [building-modules.md](building-modules.md)): money, notifications, shop or job registration, ownership. Module logic calls `adapter.AddMoney`, `adapter.CanAfford`, `adapter.Notify` and `adapter.FormatMoney`, never the gamemode. Never edit the gamemode; use its own hooks and registration functions.

### DarkRP

The remainder of this section is DarkRP-specific. Skip it for other gamemodes.

Register everything inside the `loadCustomDarkRPItems` hook, guarded by `DarkRP` and the function you need.

```lua
hook.Add("loadCustomDarkRPItems", "AcmeJobs_Items", function()
    local config = AcmeJobs.Config

    if not (DarkRP and DarkRP.createJob) then return end

    AcmeJobs.TeamIndex = DarkRP.createJob(config.JobName, {
        color = config.JobColor,
        model = {"models/player/Group01/male_07.mdl"},
        description = config.JobDescription,
        weapons = config.JobWeapons,
        command = config.JobCommand,
        max = config.JobMax,
        salary = config.JobSalary,
        admin = 0,
        vote = false,
        hasLicense = false,
        candemote = false,
        category = config.JobCategory
    })
end)
```

- Make job creation switchable (a `RegisterJob` setting) so an admin who defines the job themselves is not blocked. Find workers by the job `command`, not by team index.
- `DarkRP.createCategory{name, categorises = "entities" | "jobs" | "weapons" | "shipments" | "ammo" | "vehicles", startExpanded, color, sortOrder, canSee}` creates a section in the shop menu.
- `DarkRP.createEntity(name, {ent, model, price, max, cmd, category, allowed, customCheck})` creates a buyable entity.
- `DarkRP.createShipment` and `DarkRP.createAmmoType` follow the same pattern.
- These values are read at load time. Say "Changes need a restart" in the description.

Money and notifications (call these only from the adapter):

```lua
if ply:canAfford(cost) then
    ply:addMoney(-cost)
end

DarkRP.notify(ply, 0, 4, "Short message.")
DarkRP.formatMoney(amount)
```

`DarkRP.notify(ply, type, seconds, text)`: types are 0 generic, 1 error, 2 undo, 3 hint, 4 cleanup. Keep text to one short sentence.

Checks:

```lua
local job = RPExtraTeams[ply:Team()]
local isWorker = job ~= nil and job.command == config.JobCommand
local arrested = ply.isArrested and ply:isArrested()
```

Hooks worth knowing:

| Hook | Use |
| --- | --- |
| `loadCustomDarkRPItems` | Register jobs, categories, entities, shipments |
| `playerBoughtCustomEntity(ply, entityTable, entity, price)` | React to a purchase (claim ownership, set up) |
| `playerBoughtShipment`, `playerBoughtPistol`, `playerBoughtCustomVehicle` | Same for other purchases |
| `OnPlayerChangedTeam(ply, before, after)` | Job changes |
| `playerArrested`, `playerUnArrested` | Jail |
| `canDropWeapon`, `canPocket` | Allow or refuse |
| `InitPostEntity` | World is ready; place saved spots, NPCs |

Chat commands:

```lua
DarkRP.defineChatCommand("acmecheck", function(ply)
    AcmeJobs.PrintStatus(ply)
    return ""
end)
```

### Other gamemodes

- **No economy or shop (sandbox, minigame gamemodes):** the entity is spawnable from the spawn menu; the adapter's money functions do nothing; features that need money are reported as unsupported.
- **Another roleplay framework:** register items and jobs through its own registration functions, in its own load hook, inside the adapter; implement the four adapter functions with its API; keep module logic unchanged.
- **Unknown gamemode:** implement nothing speculative. Provide the adapter hooks (`<Namespace>CanAfford`, `<Namespace>AddMoney`, `<Namespace>Notify`, `<Namespace>FormatMoney`) so the project can connect its own economy, and say so in the report.

## Ownership

Everything players buy, deploy or drop should belong to someone, and belong to them predictably.

- Entities bought through a shop have their owner set by the gamemode where it supports that (DarkRP sets `owning_ent` and `ent.SID`); otherwise the adapter sets it.
- Entities a script spawns for a player set the owner explicitly: `ent:Setowning_ent(ply)` and `ent.SID = ply.SID`.
- When a player leaves, what they own should disappear after a delay unless they return, if the project's rules say so. The gamemode or an ownership addon usually does this; see [integrations.md](integrations.md).
- Scripts must not assume the owner is online: check `IsValid(owner)` before notifying or reading.

## Persistence

Admin settings persist through the framework automatically. Other data goes through `DFW.Data`:

```lua
local name = "acme_spots/" .. game.GetMap()

function AcmeJobs.SaveSpots()
    DFW.Data.WriteJSON(name, AcmeJobs.Spots)
end

function AcmeJobs.LoadSpots()
    AcmeJobs.Spots = DFW.Data.ReadJSON(name, {})
end
```

- Name files `<addon>/<purpose>`; per-map data adds the map name.
- Writes are atomic and keep a `.previous` copy; unreadable files are preserved as `.corrupt`.
- Store plain tables (numbers, strings, booleans, nested tables). Convert vectors and angles to arrays.
- Save when something changes, not on a timer, and never from a per-frame hook.
- Per-player data is keyed by SteamID64, or by the project's character key if it has a character system (see [integrations.md](integrations.md)), never by entity or user id.

## World data and admin tools

Positions that belong to the map (job spots, spawn points, NPC places, hazards) are placed in game with an admin tool and saved per map. They are never hard-coded and never typed into settings.

The pattern has four parts:

1. **A tool** (a weapon or a command) that only superadmins can use: left click adds, right click removes the nearest, reload refreshes. While held, it draws every saved spot with its number and kind.
2. **A validated net message** for add and remove. The server does the trace itself; the client sends only the kind.
3. **Storage** in `DFW.Data`, one file per map, plain numbers.
4. **A loader** on `InitPostEntity` that reads the file and spawns or registers what it describes.

```lua
local spots = {}

local function dataName()
    return "acme_jobs/spots_" .. game.GetMap()
end

local function save()
    DFW.Data.WriteJSON(dataName(), spots)
end

function AcmeJobs.LoadSpots()
    spots = DFW.Data.ReadJSON(dataName(), {})
end

hook.Add("InitPostEntity", "AcmeJobs_LoadSpots", AcmeJobs.LoadSpots)

DFW.Net.Receive("jobs_spot_add", function(_, ply)
    if not ply:IsSuperAdmin() then return end

    local kind = net.ReadString()

    if not AcmeJobs.SpotKinds[kind] then return end

    local origin = ply:GetShootPos()
    local trace = util.TraceLine({start = origin, endpos = origin + ply:GetAimVector() * 8000, filter = ply, mask = MASK_SHOT})

    if not trace.Hit then return end

    spots[#spots + 1] = {kind = kind, x = trace.HitPos.x, y = trace.HitPos.y, z = trace.HitPos.z, normal = {trace.HitNormal.x, trace.HitNormal.y, trace.HitNormal.z}}
    save()
end, {maxBits = 256, cooldown = 0.3})
```

Rules:

- Trace with `MASK_SHOT` so props the admin placed count as surfaces, and use the hit normal for things that face out of a surface.
- Show a preview of where a click would land while the tool is held (a small marker and a line along the normal), so the admin can verify before placing.
- Pool the net message names from a shared file (`DFW.Net.Pool("jobs_spot_add")`).
- Save on every change, never on a timer.
- Provide a command that clears the map's spots, superadmin only.
- The system that uses the spots reports when there are none, telling the admin to place some (see [workflow.md](workflow.md)).

## Sounds and effects

```lua
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
```

- Sound paths, levels and switches are settings. A switch turned off while a loop is playing takes effect on the next tick because the tick calls `StartLoop` or `StopLoop` from the live setting.
- One-shot sounds use `ent:EmitSound(path, level, pitch, volume)`.
- Effects: `util.Effect("Explosion", data)`, `"ElectricSpark"`, `"WheelDust"` and others take an `EffectData` with `SetOrigin`, `SetNormal`, `SetScale`, `SetMagnitude`.
- Use sounds that ship with the game or the server's content; never reference a file you did not verify exists.

## Timing

- Gameplay logic: one `Think` per entity with `NextThink(CurTime() + interval)`, or one server timer for a system.
- Cooldowns and durations: store a timestamp (`CurTime() + seconds`) and compare; do not nest `timer.Simple`.
- Animation that must be smooth (a swinging door) runs every tick in `Think` or a `Think` hook, not in a 0.1-second timer; slow logic stays in a slow timer.
- Delayed work that can outlive its entity captures the entity in a local and checks `IsValid` first.
- Never use `timer.Simple(0, ...)` to hide an ordering bug; fix the order.

## Security

- The client never decides prices, amounts, rewards, ownership, or success.
- Validate: player is valid and alive, entity is valid and the right class, distance is within the interaction setting, the player has permission, numbers are within the range the setting allows.
- Rate limit anything that can be spammed.
- Do not trust names, strings or entities from the client in `RunConsoleCommand`-style flows; look the thing up on the server by id.
- Do not leak private data to clients: keep `public = false` settings and collections off the wire, and send only the fields a window shows.
- Do not store or print secrets in code or settings that are public.
- Chat commands that change the world need an access check (`ply:IsSuperAdmin()` or `DFW.Access.CanConfigure(ply)`).

## Performance

- Server: tick at the slowest rate that feels right; iterate only the entities you own (`ents.FindByClass`); cache lookups built from collections.
- Client: no per-frame allocations in draw hooks beyond what the draw functions need; skip drawing out of range; compute once per change and store (fonts, materials, wrapped text).
- Networking: prefer network variables for state; send messages on change, not per tick.
- Never loop `player.GetAll()` or `ents.GetAll()` every frame.
- Create fonts and materials once, outside draw functions (or lazily with a cache).
