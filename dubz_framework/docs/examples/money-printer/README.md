# Example: Money Printer

A complete reference module for this request:

> I want a money printer addon for my server and I want it to have cooling, ink, and a chance to explode, with health and a nice UI on top of it.

It exists to show the expected structure, depth and style of a Dubz Framework module. Copy it as a starting point for anything similar: rename `Acme` and `acme_` to the project's prefix, rename the feature, and change the mechanics.

These files are reference code written to the framework's conventions. They have not been run in a live server; treat the first run as part of your test.

## Files

```
addon.json
lua/autorun/acme_printers.lua                  loader, check command, missing-file check, package manifest
lua/acme_printers/sh_config.lua                every setting, the Text phrases, the state enum, default heat bands, helpers
lua/acme_printers/sh_framework.lua             DFW.Bind.Module: specs by group, the heat band collection
lua/acme_printers/sh_adapter.lua               money, notifications and the shop entries, behind one gamemode adapter
lua/acme_printers/sv_layout.lua                re-positions installed modules when a dial-in setting changes
lua/entities/acme_money_printer/               the printer: state machine, ink, heat, damage, explosion, 3D2D screen
lua/entities/acme_ink_bottle/                  a supply: touch it to the printer to refill the ink
lua/entities/acme_coolant_module/              a module: touch it to the printer to install it, or to use it up once
```

## How the request became this module

| Request | Where it lives |
| --- | --- |
| "prints money" | `ENT:Print`: every `PrintSeconds` add `PrintAmount` to a store capped by `StoreMax`; `ENT:Collect` pays the player when they press E |
| "ink" | `InkMax`, `InkPerPrint`; refilled by touching an **ink bottle** (a physical entity) to the printer: `ENT:AcceptInk`. No ink means the `NoInk` state |
| "cooling" | `HeatPerPrint`, `CoolPerSecond`, `ShutdownHeat`, `ResumeHeat`; a **coolant module** entity touched to the printer either installs for good (`CoolantMode = "install"`, more cooling per second) or is used up to remove heat once (`"consume"`): `ENT:AcceptCoolant` |
| "chance to explode" | `ENT:RollCritical`: at or above `CriticalHeat`, `ExplodeChance` percent per second. `CriticalHeat` is below `ShutdownHeat`, so a printer that keeps running without cooling can really explode |
| "health" | `Health` sets `Integrity`; `ENT:OnTakeDamage` lowers it; zero explodes |
| "nice UI" | `cl_init.lua`: a 3D2D card with title, owner, money, four bars, status and a hint, fading with distance |
| "sold in the shop, spawn menu category" | `sh_adapter.lua` registers the printer, the bottle and the module as shop entries; every name, category, colour and command is a setting; `ENT.Category` and `ENT.PrintName` come from config |
| "admin control" | 68 settings in 11 groups (52 values plus 16 text phrases) and the `heat_bands` collection |

## Things to notice

- **Interaction is physical.** There are no key chords. Supplies and modules are entities the player carries and touches to the machine: the bottle is consumed on contact, the module either attaches visibly (parented to the printer at a slot position you dial in) or is consumed. E does the one main action, collecting. See "Physical interaction" in [gmod-patterns.md](../../gmod-patterns.md).
- **The supply decides nothing.** The bottle and module call `AcceptInk` or `AcceptCoolant` on whatever they touched; the printer validates, changes its own state and answers. A bottle that cannot be used (the tank is full) stays a bottle.
- **Touch is handled twice.** `StartTouch` and `PhysicsCollide` both call one `TryAttach`, and the work is deferred one tick with `timer.Simple(0, ...)`, because changing entities inside a collision callback is unsafe.
- **The state is computed in one place** (`ENT:ComputeState`) and published through a network variable. The screen only reads it.
- **Defaults that work together.** Passive cooling is slower than the heat each print adds, so an unattended printer reaches the danger heat after many prints; modules or coolant change that. Every state (printing, no ink, full, overheated, exploding) can be reached with the shipped defaults.
- **Hysteresis** on overheating (`UpdateOverheat`): the printer shuts down at `ShutdownHeat` and resumes at `ResumeHeat`, so it does not flicker.
- **Probability scaled by time** (`ExplodeChance * delta`): the same percentage per second regardless of tick rate.
- **One `Think`**, spaced by `NextThink`; no per-entity timers.
- **Settings are read where used.** `config.PrintAmount` appears inside `ENT:Print`, not in a local captured at load.
- **Every player-facing string is a setting.** The `Text` table holds each phrase with `{placeholders}`; `AcmePrinters.Phrase(key, values)` fills them, and `sh_framework.lua` binds the whole table with a loop.
- **Sounds follow live config:** `Refresh` starts or stops the loop from `config.Sound` each tick.
- **The screen is drawn through `DFW.Draw.World` and `DFW.Draw.Bar`:** distance culling, fading, paired render calls and error catching come from the framework. It draws nothing when the framework is missing.
- **The heat band collection** shows the "second menu" pattern: admins rename and recolour the heat labels, and an empty table falls back to the defaults.
- **Dial-in groups** for the screen and for where installed modules sit, so positions are tuned in the menu.
- **One gamemode adapter:** the entities never call the gamemode. `sh_adapter.lua` answers money and notification calls through DarkRP when present and first offers each call to the hooks `AcmePrintersCanAfford`, `AcmePrintersAddMoney`, `AcmePrintersNotify` and `AcmePrintersFormatMoney`.
- **Dial-in values move what is already installed.** The printer keeps its modules in a list and `LayoutCoolers` positions them from the settings; `OnChange` queues a debounced re-layout (`sv_layout.lua`), so saving a new offset moves every attached module without spam.
- **A hook for other addons:** `AcmePrintersCollected(ply, printer, amount)`.
- **Nothing project-specific:** `Acme` is a placeholder. A real project derives names from its profile ([project-profile.md](../../project-profile.md)).

## Playing it

- Press **E** on a printer to collect its money.
- Carry an **ink bottle** into a printer to top up the ink.
- Carry a **coolant module** into a printer to cool it: it installs (up to `CoolerSlots`) or is used up once, by the `CoolantMode` setting.

## Adapting it

1. Replace `Acme` with the project's prefix (`AcmePrinters`, `acme_printers`, `acme_money_printer`) in every file.
2. Change the mechanics in `init.lua`; every new value goes in `sh_config.lua` and gets a spec in `sh_framework.lua`.
3. Change the screen layout in `cl_init.lua` using only theme colours and library fonts.
4. Run the checklist in [quality-checklist.md](../../quality-checklist.md).
