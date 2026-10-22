# Integrations

A module rarely lives alone. Depending on the project, a request may touch progression (skills, levels), inventory, jobs and dialogue, character identity, a premium currency or ownership rules. The framework ships none of these and requires none. This document is how to work with whatever a project has, including nothing.

## The rules

1. **Look before you build.** Search the workspace for an existing system before you write your own or assume one.
2. **Never depend on a specific addon.** Reach every optional system through a small adapter of your own, so the module runs on any project by changing that file.
3. **Degrade gracefully.** If the system is absent, the feature is skipped or runs a minimal built-in version; the addon never errors.
4. **Never edit the other system.** Use its public functions and hooks only.
5. **Keep it in its own file.** One capability, one file (`sh_progression.lua`, `sv_ownership.lua`). Removing the integration is deleting a file.
6. **Every number is a setting.** Integrations add settings like everything else.
7. **Say what you found and what you left out** in your report.

## Finding what exists

Search for evidence, in this order:

1. The addon list and each addon's `addon.json` title and README.
2. Global tables defined in `lua/autorun` files: a progression system is usually a table with a name like `Skills`, `Levels` or `XP`; an inventory a table with `Inventory`, `Items` or `Pocket`.
3. Hook names the project fires and listens to (`hook.Run` and `hook.Add` calls).
4. Net message and console command names.
5. Entity and weapon classes that hint at a system (pockets, backpacks, shops, banks).
6. Config files and database tables.

Read the public functions of what you find, and write the adapter against those. Do not guess function names.

## The capability pattern

Every optional system is wrapped the same way. The adapter exposes a few functions in your own namespace. Each function first offers the call to a hook, so a project can connect any system without editing your addon. Then it uses a detected system when there is one. Then it falls back.

```lua
AcmeJobs.Progression = AcmeJobs.Progression or {}

local progression = AcmeJobs.Progression

function progression.Level(ply)
    local custom = hook.Run("AcmeJobsLevel", ply)

    if custom ~= nil then return custom end

    return 0
end

function progression.AddXP(ply, amount)
    if hook.Run("AcmeJobsAddXP", ply, amount) == true then return end
end
```

A project with a skills addon then adds a handler (or the adapter adds a branch for that addon's functions once you have read them). Module logic only ever calls `progression.Level(ply)` and `progression.AddXP(ply, amount)`.

## Capabilities

### Progression (skills, levels, experience)

Use when the request says players get better at something.

- **Adapter functions:** `Level(ply)`, `AddXP(ply, amount)`, and a one-time `Register()` if the system needs skills declared.
- **Settings:** XP per action, the level-0 and level-max values of everything the level changes (time, pay, chance, yield), the XP curve if you own it.
- **Scaling:** interpolate between a level-0 value and a level-max value, both settings.

```lua
function AcmeJobs.TimeAt(level)
    return math.max(Lerp(level / config.MaxLevel, config.TimeAtStart, config.TimeAtMax), config.TimeFloor)
end
```

- **Register early and late:** if the system registers skills, call `Register()` on `Initialize` (the other addon may load after yours) and immediately if it already exists.
- **If none exists and the request needs levels:** write a minimal level store with `DFW.Data` keyed by player id, behind the same adapter, and report it. A hidden mechanic nobody can tune is worse than none, so give it settings.

### Inventory, pockets and ownership

Use when things are carried, dropped, deployed or owned.

- **Adapter functions:** `Claim(ent, ply)` (mark something as a player's), `CanPickUp(ply, ent)`, and optionally `Give(ply, item)` / `Take(ply, item)`.
- **Ownership rule (a sensible default if the project has none):** what a player buys, deploys or drops belongs to them. When the owner leaves, what they own stays for a configurable time, then is removed unless they have returned. Both the time and the exclusions are settings.
- **Refusals:** parts of a machine and fixed props should refuse to be carried; expose the check as a hook so the inventory system can ask.
- **If none exists:** set the owner on the entity (`Setowning_ent`, a `SID` field or your own variable) and use the gamemode's removal delay if it has one.

### Jobs, tasks and dialogue

Use when the request has a job, a quest-giver, a vendor or a conversation.

- **Adapter functions:** `IsWorker(ply)`, `RegisterJob(definition)`, `Talk(ply, npc, lines)`.
- **Jobs** register through the gamemode's own hook (see the gamemode adapter in [building-modules.md](building-modules.md)); find workers by the job's command, not its index. Offer a switch to turn creation off so the owner can define the job themselves.
- **Dialogue:** if the project has a conversation system, call it through `Talk`. If not, a short chat or `DFW.UI.Prompt`-style window is enough, with every line a setting.
- **Tasks:** model a task as a list of steps in a collection (id, name, payout, weight, enabled) rather than code.

### Character identity

Use when data belongs to a character instead of an account.

- **Adapter function:** `Key(ply)`, returning the id that data is stored under.
- **Default:** the player's SteamID64. If the project has characters, return the active character's id.
- Use the key in `DFW.Data` file names and tables so each character keeps its own state.

### Premium currency and perks

Use only when the project has one.

- **Adapter function:** `IsPremium(ply)`.
- Use it for cosmetic or convenience perks (a tint, a faster non-essential animation), never to gate core gameplay.
- Make each perk a setting, and make "premium perks" a single switch.

### Logging and audit

If the project logs events, expose your module's important events (a purchase, a seizure, a large payout) as hooks and let the project's logger listen.

## Exposing your own hooks

Make your addon extensible the same way: fire a hook at the points other systems would care about, named `<Namespace><Event>`, with plain arguments.

```lua
hook.Run("AcmePrintersCollected", ply, printer, amount)
```

Document each hook in the addon's README, and never require anything to listen to them.

## What to put in the report

- Which systems you found and which functions you used.
- Which adapters you wrote, and what each does when nothing is present.
- Anything you built minimally because nothing existed, and how to replace it.
- Follow-up ideas the project could add on top (a premium perk, a second tier, another style).
