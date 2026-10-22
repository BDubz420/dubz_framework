# From a Vague Request to a Complete Specification

People who ask for scripts describe what they want to see, not what has to be built. "A money printer with cooling, ink, a chance to explode, health and a nice UI" says almost nothing about files, settings, networking, gamemode integration or cleanup. You supply all of that. This document is how.

## The principle

The request gives you the **intent**. This framework gives you the **engineering defaults**. The project gives you the **identity**: its names, its look, its gamemode. Your work is to combine the three, decide everything the user did not say, and write the decisions down before you write code.

Do not ask questions to fill gaps that a default or the workspace can fill. Make the decision, record it as an assumption, and list the assumptions at the end of your work.

## Step 0: resolve the project profile

Before interpreting the request, resolve the project's profile: prefix, namespace, gamemode, theme, style, categories, conventions. See [project-profile.md](project-profile.md). Everything below uses `<prefix>`, `<Prefix>`, `<Project>` and `<Feature>` as placeholders for the profile's values and the feature's name.

## Step 1: restate the request as an engineering brief

Write a brief like the following for yourself (and show it to the user if they asked for a plan). It is the vague request after expansion.

> Make a new addon for `<Project>`, using the project's prefix and conventions, formatted to work and register inside the Dubz Framework environment. The addon adds a physics entity, `<prefix>_money_printer`, that prints a configurable amount of money every configurable number of seconds into an internal store the player collects with E. It consumes ink and generates heat; cooling removes heat; at high heat it shuts down and can explode. It has health and takes damage. It is sold through the project's shop (registered by the gamemode adapter) in a category named from config, and appears in the spawn menu under a category derived from the project name. It has a 3D2D screen built from the active theme and the framework's drawing helpers showing money, ink, heat, health and status. Every number, name and category is a setting in the framework admin menu; tables of tunable things are collections. The code follows the project's conventions, has a clean namespace, and cleans up after itself.

Everything in that brief that the user did not literally say came from the profile and the tables below.

## Step 2: run the dimension checklist

For every request, walk these dimensions and decide each one. The defaults are what you use when the request and the workspace are silent.

| Dimension | Decide | Default |
| --- | --- | --- |
| **Identity** | Addon id, namespace, class, module id, display name | Package id `<prefix>_<feature>`; namespace `<Prefix><Feature>`; module id `<feature>`; class `<prefix>_<thing>` |
| **Kind** | Entity, weapon, NPC, job, system, HUD element, menu, or a mix | Pick the smallest set of kinds that delivers the described behaviour |
| **Where it appears** | Shop or purchase menu, spawn menu, NPC, chat command, keybind | Buyable things: the project's shop (through the adapter) in their own section, plus the spawn menu for admins. Services: an NPC. Tools: a weapon given by a job, bought, or spawned |
| **Core loop** | What happens every tick or cycle, what the player does, what ends it | Write it as a state machine with named states before coding |
| **Economy** | Price, income, costs, limits, refunds | Price and limits in config; income balanced so payback takes 20 to 60 minutes of play |
| **Risk and failure** | Health, damage, fire, explosion, theft, cooldowns | Anything that can break has health; anything that can explode has a per-second chance, a radius and a damage value, all configurable |
| **Resources** | Fuel, ink, power, ammo, heat, stamina | Each is a numeric network variable with a maximum, a use rate and a refill action |
| **Interaction** | How the player acts on it: contact, use, hold, tools | Physical first: supplies and add-ons are entities touched to the machine; E does the one main action; hold E for slow actions; never key chords (Shift+E, Ctrl+E). See [gmod-patterns.md](gmod-patterns.md) |
| **UI** | 3D2D screen, HUD element, window, dialog, toast | World objects: a 3D2D card. Per-player state: a HUD element. Anything with choices: a `DFW.Frame` window. Where the element can look more than one way, a style registry (see [styles-and-themes.md](styles-and-themes.md)) |
| **Progression** | Skills, levels, unlocks | Optional: add a skill only if the request mentions getting better at something and a skills addon exists. See [integrations.md](integrations.md) |
| **Persistence** | What must survive restarts | Admin settings persist automatically. Player or world data through `DFW.Data` only if the request needs it |
| **Multiplayer** | Who sees what, who may do what, abuse cases | Server decides, clients display, every net message is validated and rate-limited |
| **Config exposure** | Which values the admin can change | All of them, including names and categories. See [config-design.md](config-design.md) |
| **Cleanup** | Sounds, timers, effects, ownership, leaving players | Everything created is stopped and removed in `OnRemove`; ownership follows the project's rules |

## Step 3: translate the user's words

Users describe features in game words. Each word hides a mechanism. Use this table.

| User says | Build this |
| --- | --- |
| "prints money every X seconds" | A repeating server-side cycle. Interval and amount are settings. Money accumulates in a capped internal store the owner collects |
| "ink", "fuel", "battery", "ammo", "paper" | A consumable resource: a numeric network variable with a maximum setting and a cost per cycle setting, refilled by a **supply entity** (a bottle, a canister, a battery) the player touches to the machine. The supply is consumed on contact, adds a configured amount, is sold in the shop with a price and a per-player limit, and is refused when the tank is full. A "no resource" state stops the cycle. Never a refill key |
| "cooling", "heat", "overheating" | A heat value that rises per cycle and decays per second. Shutdown, resume and danger thresholds, ordered so every state can be reached. A **coolant module** entity touched to the machine either installs permanently (extra cooling per second, limited slots, visibly attached) or is used up once to remove heat: choose with a mode setting and support both. Heat labels and colours as a collection |
| "module", "upgrade part", "attachment", "add-on", "filter" | An installable entity: touch it to the host, the host validates, parents it at a slot position (dial-in settings), and applies its effect for good. Slots, effect size, price and limits are settings |
| "chance to explode" | A per-second probability while a condition holds (critical heat, low health). Chance, radius and damage are settings. Never roll per frame |
| "health" | An integrity value initialised from a setting, reduced in `OnTakeDamage`, destruction at zero, shown as a bar |
| "nice UI", "screen", "display" | A 3D2D card for world objects built from the active theme: card background, title, numeric readout, labelled bars, status line, key hints. Fades with distance |
| "can be stolen", "raid" | Anyone can use it; owner and enforcement rules are settings |
| "upgrade", "tier", "level" | A collection of tiers (id, name, price, multiplier columns) read with `DFW.Collections.Watch` |
| "shop", "vendor" | An NPC plus a collection of items with price columns, `suggest = "entities"` for class columns |
| "loot", "drops", "rare" | A collection with a weight column; pick by weighted random |
| "recipe", "craft" | A collection with ingredient and result columns, plus a skill only if the request implies getting better |
| "job", "work", "task" | A job registered through the gamemode adapter, a task engine of steps, an NPC giver, pay per task |
| "skill", "get better at" | A skill through the project's skills addon if one exists, with an effect function and time or pay scaling from config |
| "sound", "noise" | A sound setting (toggle and level), played and stopped through the entity, honoured live |
| "only for X job or group" | A job or usergroup setting read at check time, with `suggest = "jobs"` or `"usergroups"` for collections |
| "cooldown", "timer" | A server timestamp compared with `CurTime()`; the duration is a setting |
| "looks cool", "professional", "clean", "gritty", "futuristic" | The active theme, a style variant if the element needs one, short labels. See the style table in [styles-and-themes.md](styles-and-themes.md) |
| "like X but better" | Read X in the workspace if it exists, keep its behaviour, replace hard-coded values with settings, restyle with the library |

When a word is not in the table, ask what mechanism a player could observe and what number would control it. That number is a setting.

## Step 4: write the specification

Before coding, produce this block (in your reply if the user asked for a plan, otherwise in your head and in the final report):

```
Project profile: <as resolved>
Addon id:        <prefix>_printers
Namespace:       <Prefix>Printers
Module id:       printers
Classes:         <prefix>_money_printer
Files:           autorun, sh_config, sh_adapter, sh_framework, entity shared/init/cl_init
Shop entry:      section from config, command from config, price and maximum per player in settings
Spawn menu:      category from config, derived from the project name
States:          printing, full, no ink, overheated
Loop:            every PrintSeconds: if printing, add PrintAmount, use InkPerPrint, add HeatPerPrint
Player actions:  E collect; touch an ink bottle to refill; touch a coolant module to install or use it
Failure:         heat shutdown at ShutdownHeat, resume at ResumeHeat, explosion chance per second at CriticalHeat, health from damage
UI:              3D2D card in the active theme: owner, money, print progress, ink bar, heat bar with band label, health bar, status, key hints
Settings:        <every config key with group, range, default>
Collections:     heat_bands (heat, label, colour)
Integrations:    gamemode adapter; optional none
Assumptions:     <list every default you chose>
```

Then build to that block. If the user disagrees with an assumption later, you change a default, not an architecture.

## Worked example: the money printer

Request: "I want a money printer addon for my server and I want it to have cooling, ink, and a chance to explode, with health and a nice UI on top of it."

Decisions made:

- Kind: one physics entity, a shop entry through the adapter, one framework module.
- Money: store with a cap, so a neglected printer stops and the owner has a reason to return.
- Ink: resource with a maximum and a use per print, refilled by an ink bottle entity touched to the printer.
- Cooling: heat resource; passive decay per second; danger, shutdown and resume thresholds; a coolant module entity touched to the printer that either installs for good or is used up once (a setting); a collection of heat bands for the labels and colours the screen shows.
- Explosion: a per-second percentage at critical heat, plus destruction when health reaches zero; radius and damage in settings.
- Health: integrity from a setting, reduced by damage, shown as a bar.
- UI: 3D2D card on top of the entity, theme colours, fades with distance.
- Admin control: price, maximum per player, seize reward, model, names, categories, interval, amount, store cap, ink maximum and use, refill cost, heat per print, cooling rate, three thresholds, explosion chance, coolant cost and amount, health, blast radius and damage, screen distance, height, scale and yaw, sound switch and level, and the heat band collection.

The complete result is in [examples/money-printer](examples/money-printer). Read it end to end: it is the template for the structure and level of completeness expected of every module. Its names are placeholders; yours come from the profile.

## Worked example: a job with tasks

Request: "A garbage collector job. They get sent to dumpsters, and it pays per pickup."

Decisions:

- A job registered through the adapter (for a gamemode with jobs). Command, name, colour, salary and maximum are settings, with an off switch for creating the job so the admin can define it themselves.
- A task engine: a list of task definitions, each a sequence of steps (go to a spot, interact, deliver). Per-task payout, weight and an enabled switch are a collection (`tasks`).
- A marker or waypoint to the current spot, drawn with the active theme; removed when the task ends.
- An NPC job giver if the project has a conversation addon, otherwise a command.
- Pay in cash on completion, optionally scaled by a skill if one exists.
- Every duration, distance and count is a setting; spots placed by an admin tool and saved per map through `DFW.Data`.

## Worked example: a hand tool

Request: "A lockpick that has a chance to break."

Decisions:

- A weapon (SWEP) with its own class, spawnable for admins, handed out through the project's job or shop systems.
- A timed action with a progress bar drawn from the library's progress helper, interrupted by looking away.
- Time, break chance, breaking sound, and which doors or entities it may open are settings; the allowed class list is a collection with `suggest = "entities"`.
- Server decides the outcome; the client only draws the bar.

## Worked example: a HUD

Request: "I want a HUD with health, armor and money."

Decisions:

- A HUD module with an element registry (health, armor, money), each element a style-aware draw function reading the active theme.
- A layout setting (anchor, offset, scale), per-element switches and an element style choice, all in the admin menu.
- Elements read player state through network variables or the gamemode adapter; none decides anything.
- A style registry so the project, or anyone, can add another look without touching the module. See [styles-and-themes.md](styles-and-themes.md).

## Large and compound requests

Some requests are several systems: "a full drug system", "a police job with arrests, fines and a station", "an economy with banks and loans". Do not build them as one addon or one file.

1. **List the systems.** Write one line per system the request implies (production, selling, effects; arrests, fines, jail; accounts, loans, interest).
2. **Find the dependencies.** Which system needs another's data or events? Draw the order.
3. **One addon per system.** Each has its own prefix-feature name, config, module and adapter. Shared data travels through hooks and small adapter functions, not shared globals.
4. **Build in order and finish each.** Run the checklist on the first before starting the second. Report after each, or once with a section per addon.
5. **Make the seams explicit.** Each addon fires hooks at its important events (`<Namespace>Collected`, `<Namespace>Arrested`) and offers settings for how it reacts to the others.
6. **Keep the first pass small.** Build the core loop of each system first and list the extensions as follow-up ideas.

If the request is large and vague, state your decomposition in the first reply so the user can redirect you before you build.

## Quality bar

The result of this process must read as if a careful senior developer who knew the framework and the project well had written it by hand: fully configurable, consistent with the rest of the project, in its theme, free of hard-coded values, and safe to run in front of players. The checklist in [quality-checklist.md](quality-checklist.md) is the definition of done.
