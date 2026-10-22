# Building a Module, Step by Step

This is the workflow from a finished specification to a finished addon. Follow the steps in order. The example addon in [examples/money-printer](examples/money-printer) is a complete instance of everything described here.

## 0. Vocabulary

| Term | Meaning |
| --- | --- |
| **Addon** | A Garry's Mod addon folder (`addon.json`, `lua/`, `materials/`). One feature, one addon |
| **Package** | The addon's manifest as the framework sees it. Id format `<prefix>_<feature>` |
| **Module** | What appears in the admin menu and can be switched off. Id format `<feature>` |
| **Config table** | The plain Lua table that holds every setting, defined in `sh_config.lua` |
| **Spec** | One entry that describes how a config value appears in the admin menu |
| **Collection** | An admin-editable table of rows |

Identifiers (package ids, module ids, collection ids, column keys) are lowercase snake_case: they must match `^[a-z][a-z0-9_]*$` and be at most 64 characters.

## 1. Fix the names

From the specification choose, once, and use everywhere:

| Thing | Format | Example |
| --- | --- | --- |
| Project prefix (from the profile) | Short, lowercase | `acme` |
| Addon folder and package id | `<prefix>_<feature>` | `acme_printers` |
| Namespace (global table) | `<Prefix><Feature>` | `AcmePrinters` |
| Module id | `<feature>` | `printers` |
| Entity or weapon class | `<prefix>_<thing>` | `acme_money_printer` |
| Lua folder under `lua/` | Same as the package id | `lua/acme_printers/` |
| Hook, timer and net names | `<Namespace>_<Purpose>` | `AcmePrinters_Draw` |
| Chat or console command | `<prefix>_<purpose>` | `acme_printers_check` |

Resolve the project profile first ([project-profile.md](project-profile.md)). The prefix, namespace and categories come from the prompt or the workspace, never from the examples. If the workspace already has addons, read two of them and copy their prefix and conventions exactly. A consistent namespace is the first thing that makes a project's scripts look professional.

## 2. Lay out the addon

```
acme_printers/
  addon.json
  lua/
    autorun/acme_printers.lua
    acme_printers/
      sh_config.lua
      sh_framework.lua
      sh_adapter.lua
      sv_<system>.lua      server logic that is not an entity
      cl_<system>.lua      client logic that is not an entity
    entities/acme_money_printer/
      shared.lua
      init.lua
      cl_init.lua
    weapons/acme_tool.lua  a weapon is one file, or a folder with shared/init/cl_init
  materials/               only if the addon ships its own materials
```

Rules for files:

- Every Lua file starts with its realm: `sh_` shared, `sv_` server only, `cl_` client only. The framework loader refuses package files that do not.
- One responsibility per file. A file that reads as two systems becomes two files.
- Never number files. If order matters, the autorun lists them in order.
- Entities use the folder form (`shared.lua`, `init.lua`, `cl_init.lua`). Weapons use a single file unless they are large.

`addon.json`:

```json
{
  "title": "Acme Printers",
  "type": "servercontent",
  "tags": ["roleplay"],
  "ignore": ["*.psd", "*.blend", ".git/*"]
}
```

## 3. The autorun: loader and manifest

The autorun is the only file the game runs on its own. It does four jobs: checks that the addon is complete, includes the files the addon needs before the framework starts, sends client files, and hands the framework a manifest.

```lua
AcmePrinters = AcmePrinters or {}

local ROOT = "acme_printers/"
local LOCAL_FILES = {"sh_config.lua", "sh_adapter.lua"}
local PACKAGE_FILES = {"sh_framework.lua"}

local function missingFiles()
    local missing = {}

    for _, list in ipairs({LOCAL_FILES, PACKAGE_FILES}) do
        for _, name in ipairs(list) do
            if not file.Exists(ROOT .. name, "LUA") then missing[#missing + 1] = name end
        end
    end

    return missing
end

local missing = missingFiles()

if #missing > 0 then
    MsgC(Color(255, 80, 80), "[AcmePrinters] ", color_white, "missing files in lua/" .. ROOT .. ": " .. table.concat(missing, ", ") .. ". Upload the whole addon.\n")
    return
end

if SERVER then
    for _, name in ipairs(LOCAL_FILES) do AddCSLuaFile(ROOT .. name) end
end

for _, name in ipairs(LOCAL_FILES) do include(ROOT .. name) end

DFW = DFW or {}
DFW.PendingPackages = DFW.PendingPackages or {}

local manifest = {
    id = "acme_printers",
    name = "Acme Printers",
    version = "1.0.0",
    api = 1,
    dependencies = {"dubz_framework"},
    files = {ROOT .. "sh_framework.lua"}
}

if DFW.Packages and DFW.Packages.Submit then
    DFW.Packages.Submit(manifest)
else
    DFW.PendingPackages[#DFW.PendingPackages + 1] = manifest
end
```

Why it is written this way:

- **Works before or after the framework.** Autorun order between addons is not guaranteed. If the framework has loaded, `Submit` runs now. If not, the manifest waits in `DFW.PendingPackages` and the framework drains it when it starts.
- **Missing files are named.** A half-uploaded addon prints which files are missing instead of failing later with a confusing nil error.
- **Local files versus package files.** `sh_config.lua` and anything else the addon needs even when the framework is absent are included by the autorun and sent to clients with `AddCSLuaFile`. `sh_framework.lua` is loaded by the framework from the manifest; the framework sends it to clients itself. This split is what lets the addon run on its defaults without the framework installed.
- **`api = 1`** is the framework API version the addon was written against. The framework refuses a package that needs a newer API.
- **Manifest file paths** are relative to `lua/`, use forward slashes, must exist, and must begin with `sh_`, `sv_` or `cl_`.
- **Dependencies** in the manifest are addon ids that must be loaded first. Add other addons your files need at load time.

Entities, weapons and effects are found by the game on their own from `lua/entities`, `lua/weapons` and `lua/effects`; they are not listed in the manifest.

If the addon has server-only or client-only files of its own (a task engine, a HUD), list them in the manifest too: the framework loads shared files first, then the current realm's files, in the order listed.

## 4. The config table: `sh_config.lua`

This file defines every setting with its default, plus shared helpers. It is loaded with or without the framework.

```lua
AcmePrinters.Config = {
    Name = "Money Printer",
    Price = 1500,
    PrintSeconds = 30,
    PrintAmount = 125,
}

function AcmePrinters.Enabled()
    return not (DFW and DFW.Bind) or DFW.Bind.Enabled("printers")
end
```

Conventions:

- One table, `Namespace.Config`, with flat PascalCase keys. Nested tables are allowed for grouped vectors or colours but flat keys are easier to bind.
- Booleans are real booleans, numbers are numbers, colours are `Color(...)` values, lists are `{"a", "b"}`, sets are `{a = true}`, maps are `{a = 5}`. The binder chooses the control from the value's type.
- Defaults are the values the project should ship with; they are what a fresh install uses and what "Reset" restores.
- `Enabled()` wraps `DFW.Bind.Enabled(moduleId)`, which is true when the framework is not installed. Gate gameplay code on it.
- Shared constants that are not settings (state enums, default row tables) live next to the config, in their own tables.

See [config-design.md](config-design.md) for how to choose what becomes a setting (everything) and how to describe it.

## 5. The binding: `sh_framework.lua`

This file runs only when the framework loads the package. It registers the module and binds the table.

```lua
local config = AcmePrinters.Config

DFW.Bind.Module({
    id = "printers",
    name = "Money Printers",
    version = "1.0.0",
    icon = "economy/payments",
    description = "Printer income, ink, cooling, damage and the on-screen display.",
    dependencies = {"dubz_core"}
}, config, {
    {path = "Name", label = "Display Name", group = "Shop", maxLength = 40},
    {path = "Price", label = "Price", min = 0, max = 1000000, decimals = 0, group = "Shop",
        description = "Changes need a restart to reach the shop menu."},
    {path = "PrintSeconds", label = "Seconds Per Print", min = 1, max = 3600, decimals = 0, group = "Printing"},
    {path = "PrintAmount", label = "Money Per Print", min = 1, max = 100000, decimals = 0, group = "Printing"}
})
```

Facts the binder enforces:

- It must run while the package is loading, so the module is owned by the right addon. Never include `sh_framework.lua` from the autorun.
- Every `path` must exist in the config table, or the spec is skipped with a warning.
- Defaults come from the table's current values.
- Admin edits are written back into the same table in place, on the server and on clients that received the setting.
- Specs are public (replicated to clients) unless `public = false`.
- Module `dependencies = {"dubz_core"}` makes the module start after the framework core.

The full list of spec keys and the other field kinds (keybinds, lists, sets, maps, choices) are in [config-design.md](config-design.md) and [api-reference.md](api-reference.md).

Collections are passed in the fourth argument and read with `DFW.Collections.Watch`:

```lua
DFW.Bind.Module(definition, config, specs, {
    collections = {
        {
            id = "heat_bands", label = "Heat Bands",
            columns = {
                {key = "heat", label = "From Heat", type = "number", min = 0, max = 100, decimals = 0, width = 1},
                {key = "label", label = "Label", type = "string", maxLength = 24, width = 2},
                {key = "color", label = "Colour", type = "color", width = 1}
            },
            default = AcmePrinters.DefaultHeatBands
        }
    }
})

DFW.Collections.Watch("printers", "heat_bands", AcmePrinters.BuildHeatBands)
```

`Watch` calls the function immediately with the current rows and again every time an admin saves the table.

## 6. The gamemode adapter: `sh_adapter.lua`

Module logic never calls a gamemode directly. Money, notifications and shop or job registration live in one shared file, so supporting a different gamemode means editing that file, not the module.

The adapter exposes the same four functions whatever the gamemode: `FormatMoney(amount)`, `CanAfford(ply, amount)`, `AddMoney(ply, amount)` and `Notify(ply, text, kind)`. Each one first offers the call to a hook named for the addon (`<Namespace>CanAfford`, and so on), so a project on an unsupported gamemode can implement it without editing the addon. Then it uses the gamemode's own API when that exists. Then it falls back.

```lua
AcmePrinters.Adapter = AcmePrinters.Adapter or {}

local adapter = AcmePrinters.Adapter

function adapter.FormatMoney(amount)
    local custom = hook.Run("AcmePrintersFormatMoney", amount)

    if custom then return custom end
    if DarkRP and DarkRP.formatMoney then return DarkRP.formatMoney(amount) end

    return "$" .. string.Comma(amount)
end

function adapter.CanAfford(ply, amount)
    local custom = hook.Run("AcmePrintersCanAfford", ply, amount)

    if custom ~= nil then return custom == true end
    if ply.canAfford then return ply:canAfford(amount) end

    return false
end

function adapter.AddMoney(ply, amount)
    if hook.Run("AcmePrintersAddMoney", ply, amount) == true then return end

    if ply.addMoney then ply:addMoney(amount) end
end

function adapter.Notify(ply, text, kind)
    if not IsValid(ply) then return end

    if hook.Run("AcmePrintersNotify", ply, text, kind) == true then return end

    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, kind or 0, 4, text)
    else
        ply:ChatPrint(text)
    end
end
```

The same file registers the addon's shop entries, jobs or items through the gamemode's own hook. For DarkRP that is `loadCustomDarkRPItems`:

```lua
hook.Add("loadCustomDarkRPItems", "AcmePrinters_Items", function()
    local config = AcmePrinters.Config

    if not (DarkRP and DarkRP.createCategory and DarkRP.createEntity) then return end

    DarkRP.createCategory{
        name = config.Category,
        categorises = "entities",
        startExpanded = true,
        color = Color(35, 35, 35),
        sortOrder = 20,
        canSee = function() return true end
    }

    DarkRP.createEntity(config.Name, {
        ent = "acme_money_printer",
        model = config.Model,
        price = config.Price,
        max = config.MaxPerPlayer,
        cmd = "buymoneyprinter",
        category = config.Category
    })
end)
```

The category, name, command, price and limit are all config values. They are read when the gamemode loads its items, so changes need a restart; say so in the settings' descriptions.

Write the adapter for the gamemode the profile found:

- **DarkRP:** as above. See [gmod-patterns.md](gmod-patterns.md) for jobs, shipments, ownership and the buy hooks.
- **A gamemode with no economy or shop (sandbox, minigames):** keep the four functions, return `false` and do nothing from the money functions, and leave the entity spawnable from the spawn menu (`ENT.Spawnable`). Say in your report that purchase features need the project's economy.
- **Another roleplay gamemode:** implement the functions with its API, register the shop or item entry through its own registration, and keep everything else unchanged.

## 7. The behaviour

Write the entities, weapons, NPCs and systems. Use [gmod-patterns.md](gmod-patterns.md) for structure and [ui-library.md](ui-library.md) for anything drawn. The rules that apply everywhere:

- **State machine first.** Decide the states and transitions on paper; implement them as one function that computes the current state and one that reacts to it. Do not scatter flags.
- **One tick.** Per-entity logic runs in a single `Think` with `NextThink` spacing it (0.25 to 1 second for gameplay logic), not many timers and never every frame unless it animates.
- **Network variables for state the client draws.** Use `NetworkVar`, declared in `shared.lua`. Do not send per-tick net messages for something a network variable can carry.
- **Read config at use.** `config.PrintAmount` inside the function, not a local captured at load.
- **Guard with `Enabled()`** at every entry point a player or tick can reach.
- **Notify briefly.** One short sentence, through the adapter's `Notify`.

## 8. The UI

Draw with the framework so every theme restyles it. World overlays use `cam.Start3D2D` with `DFW.Draw` and `DFW.UI.GetTheme()`; windows use `DFW.UI.CreateFrame` with `DFW` controls; toasts use `DFW.UI.Notify`. Recipes are in [gmod-patterns.md](gmod-patterns.md) and the controls in [ui-library.md](ui-library.md). If the framework is not loaded, skip the overlay rather than erroring.

## 9. Lifecycle and cleanup

- Modules register at load but start only after the gamemode has loaded. Gameplay code that must wait for the gamemode uses the gamemode's own hooks (`InitPostEntity`, or its item-loading hook).
- If you need hooks and timers that stop when an admin switches the module off, create them from the module's `OnStart` through `self:AddHook` and `self:AddTimer`. They are removed automatically on stop. Otherwise gate with `Enabled()`.
- Entities remove sounds, timers and spawned children in `OnRemove`.
- When config changes should take effect immediately beyond what live reads give (a looping sound, a created timer, a registered skill), pass `OnChange(path, value, key)` in the bind options and handle only the affected paths.

## 10. Test

The framework gives you:

- `dfw_status`: shows your package and module state (`loaded`, `started`, `failed`, `waiting`).
- `!dubzconfig`: your module should appear with every group and control from the specs, and a "Reset" per setting.
- `dfw_selftest`: the framework's own checks; run it after loading.

Checks to run in game, and to list in your report if you could not run them:

1. The module appears under `!dubzconfig` with every setting in its group.
2. Changing a value changes behaviour immediately, without a restart (except the documented restart-only ones).
3. Switching the module off in the Modules page stops the gameplay without errors.
4. Spawning, using, damaging and removing the entity produces no Lua errors in either console.
5. Restarting the server keeps the admin's values.
6. With the framework removed, the addon still loads on its defaults and the overlay is skipped.

### Diagnostics

Register a check command in the autorun, before the missing-file check returns, so it works even when files are missing.

```lua
if SERVER then
    concommand.Add("acme_printers_check", function(ply)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end

        for _, list in ipairs({LOCAL_FILES, PACKAGE_FILES}) do
            for _, name in ipairs(list) do
                local state = file.Exists(ROOT .. name, "LUA") and "found" or "MISSING"
                local text = "[AcmePrinters] lua/" .. ROOT .. name .. ": " .. state

                if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, text .. "\n") else print(text) end
            end
        end
    end)
end
```

Add a test command for anything gated by time, chance or world state (superadmin only), and a values command that prints dialled-in numbers. See [workflow.md](workflow.md) for why every module ships them.

## 11. Finish

Run [quality-checklist.md](quality-checklist.md). Then report:

- the final file tree;
- what the player can do and what the admin can configure;
- the assumptions you made, one line each;
- what you did not or could not test.
