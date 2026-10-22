# API Reference

Every public `DFW` function and hook, with the realm it runs in. Realms: **SH** shared, **SV** server, **CL** client. Identifiers are lowercase snake_case and match `^[a-z][a-z0-9_]*$` (64 characters at most).

## Contents

- [DFW](#dfw)
- [DFW.Util](#dfwutil)
- [DFW.Addons](#dfwaddons)
- [DFW.Packages](#dfwpackages)
- [DFW.Modules](#dfwmodules)
- [DFW.Config](#dfwconfig)
- [DFW.Bind](#dfwbind)
- [DFW.Collections](#dfwcollections)
- [DFW.Registry](#dfwregistry)
- [DFW.Net](#dfwnet)
- [DFW.Data](#dfwdata)
- [DFW.Themes](#dfwthemes)
- [DFW.Access](#dfwaccess)
- [Hooks](#hooks)
- [Console and chat commands](#console-and-chat-commands)

## DFW

| Field | Meaning |
| --- | --- |
| `DFW.Name`, `DFW.Version`, `DFW.APIVersion` | Identity. Manifests declare `api = 1` |
| `DFW.Root` | `"dubz_framework"` |
| `DFW.Ready` | True once the core, UI and menu have loaded |
| `DFW.DebugEnabled` | The "Debug Logging" setting of the core module |
| `DFW.PendingPackages` | Manifests waiting for the framework; autoruns append to it when `DFW.Packages` does not exist yet |

## DFW.Util

| Function | Realm | Description |
| --- | --- | --- |
| `IsIdentifier(value)` | SH | True for valid ids |
| `Copy(value)` | SH | Deep copy for tables, identity for other values |
| `DeepEqual(a, b)` | SH | Structural equality |
| `Round(value, decimals)` | SH | Round half up |
| `IsFiniteNumber(value)` | SH | True for numbers that are not NaN or infinite |
| `SortedKeys(table)` | SH | Keys sorted as strings |
| `ColorToTable(color)`, `TableToColor(table)` | SH | Convert between `Color` and `{r, g, b, a}` |
| `TrimString(value, maxLength)` | SH | Coerce and truncate |
| `Log(message)`, `Warn(message)`, `Debug(message)` | SH | Prefixed console output; `Debug` prints only when debugging is on |
| `SafeCall(label, fn, ...)` | SH | `pcall` that logs failures; returns the `pcall` results |
| `StopAllSounds()` | SV | Runs `stopsound` for every player; use when a sound setting is switched off |

## DFW.Addons

An addon record is `{id, name, version, api, state, reason, description}`; states: `registered`, `loading`, `loaded`, `failed`.

| Function | Description |
| --- | --- |
| `Register(definition)` | Adds an addon; returns `ok, record` |
| `SetState(id, state, reason)` | Changes state; fires `DFW_AddonStateChanged` |
| `Exists(id)`, `Get(id)`, `GetAll()` | Lookups |

Packages register their addon automatically; modules normally do not call these.

## DFW.Packages

A manifest:

```lua
{
    id = "acme_printers",
    name = "Acme Printers",
    version = "1.0.0",
    api = 1,
    dependencies = {"dubz_framework"},
    files = {"acme_printers/sh_framework.lua"}
}
```

Validation: `id` identifier; `name` non-empty string; `files` a non-empty list of unique paths that end in `.lua`, start with `sh_`, `sv_` or `cl_` in the file name, contain no `..`, no leading `/`, no backslashes, and exist; `api` an integer at least 1 and not newer than the framework; `dependencies` a list of unique ids other than the package itself (default `{"dubz_framework"}`).

| Function | Description |
| --- | --- |
| `Submit(manifest)` | Validates, then loads now if dependencies are loaded, otherwise waits; returns `ok, reason` (`"pending"` while waiting) |
| `DrainPending()` | Submits everything in `DFW.PendingPackages` (the framework calls it) |
| `FinalizePending()` | Marks packages with missing dependencies as failed (called after the first frame) |
| `GetActiveId()` | The package whose files are loading; `Bind.Module` and `Modules.Register` use it as the module's owner |
| `GetAll()`, `GetStats()`, `ExportManifests()` | State and counts |

Load behaviour: shared files first, then the current realm's, in manifest order; the server sends `sh_` and `cl_` files to clients. A file that errors fails the package and rolls back its modules.

## DFW.Modules

A module definition:

```lua
{
    id = "printers",
    name = "Money Printers",
    version = "1.0.0",
    icon = "economy/payments",
    description = "Shown in the Modules page.",
    dependencies = {"dubz_core"},
    OnStart = function(self) end,
    OnStop = function(self, reason) end,
    OnConfigChanged = function(self, key, value, actor) end
}
```

| Function | Description |
| --- | --- |
| `Register(definition)` | Adds a module owned by the active package; returns `ok, record` |
| `Get(id)`, `GetAll()`, `Exists(id)` | Lookups |
| `IsEnabled(id)` | False only when an admin switched the module off; unknown modules count as enabled |
| `IsStarted(id)`, `GetState(id)` | `started`, `disabled`, `failed`, `waiting`, `registered`, `unknown` |
| `SetEnabled(id, enabled)` | Switch a module; core modules cannot be disabled; modules required by enabled ones cannot be disabled |
| `StartAll()`, `StopAll(reason)` | Start or stop everything in dependency order |
| `Unregister(id)`, `RemoveByAddon(addonId)` | Remove modules |

Module methods (on `self` in `OnStart`, `OnStop` and `OnConfigChanged`):

| Method | Description |
| --- | --- |
| `self:AddHook(event, name, callback)` | Adds a hook removed when the module stops |
| `self:AddTimer(name, delay, repetitions, callback)` | Adds a timer removed when the module stops |
| `self:GetConfig(key, fallback)` | Reads one of the module's settings by storage key |
| `self:Cleanup()` | Removes the hooks and timers (called for you) |

Lifecycle: modules start after the gamemode's `Initialize` and after their dependencies. An error in `OnStart` marks the module `failed` without affecting others; re-enabling retries. `OnStop` runs when disabled, on framework reload, and when the package is rolled back.

## DFW.Config

Schema field (used by `Register`; `Bind.Module` builds these for you):

```lua
{key = "amount", label = "Amount", type = "number", default = 10, min = 0, max = 100, decimals = 0,
    group = "General", order = 10, description = "...", public = true}
```

Types: `bool`, `string` (`maxLength`, default 256), `number` (`min`, `max`, `decimals`), `choice` (`choices`, a list or a function that returns one: a function makes an open set whose list is read whenever it is needed, so entries registered later appear and a saved choice survives until its entry exists), `color` (`{r, g, b, a}`).

| Function | Realm | Description |
| --- | --- | --- |
| `Register(moduleId, fields)` | SH | Registers a schema; the module must exist |
| `Get(moduleId, key, fallback)` | SH | Current value |
| `GetChoices(field)` | SH | The current list of a choice field, resolving function-backed lists |
| `GetColor(moduleId, key, fallback)` | SH | A value as a `Color` |
| `GetDefault(moduleId, key)` | SH | The default |
| `Set(moduleId, key, value, actor)` | SH | Validates and applies; fires `DFW_ConfigChanged` |
| `Validate(moduleId, key, value)` | SH | Returns `ok, normalized` or `false, reason` |
| `Reset(moduleId, key, actor)`, `ResetModule(moduleId, actor)` | SH | Back to defaults |
| `IsDefault(moduleId, key)` | SH | True when unchanged |
| `GetFields(moduleId)`, `GetSchema()`, `GetModuleValues(moduleId)` | SH | Introspection |
| `Export(publicOnly)`, `ApplyExport(data)` | SH | Bulk values |
| `OpenFor(ply)` | SV | Opens the admin menu for an authorised player |
| `RequestOpen()`, `RequestSnapshot()` | CL | Ask the server |

Values are validated for type, range, length, finite numbers and colour channels. Saves are debounced and written atomically.

## DFW.Bind

| Function | Description |
| --- | --- |
| `Bind.Module(definition, target, specs, options)` | Registers the module and binds the config table; returns `true` on success |
| `Bind.Enabled(moduleId)` | Master switch for gameplay code; true when the framework or the module is missing |
| `Bind.GetKeyNames()` | The key names a keybind control offers |

Spec keys: `path`, `key`, `label`, `description`, `group`, `order`, `public`, `min`, `max`, `decimals`, `maxLength`, `choices`, `keybind`, `list`, `set`, `map`, `mapText`. See [config-design.md](config-design.md).

Options table:

| Key | Meaning |
| --- | --- |
| `collections` | A list of collection definitions |
| `ui = true` | Adds a "Hover Sounds" switch for modules that open windows |
| `OnChange(path, value, key)` | Called after a bound value is applied |

## DFW.Collections

Collection definition: `id`, `label`, `description`, `idKey`, `columns`, `default`, `public`, `maxRows`, `preview`, `picker`. Column: `key`, `label`, `type` (`string`, `number`, `bool`, `color`, `choice`), `width`, `min`, `max`, `decimals`, `maxLength`, `choices`, `default`, `suggest`.

| Function | Realm | Description |
| --- | --- | --- |
| `Register(moduleId, definition)` | SH | Registers a table (normally through `Bind.Module`) |
| `Get(moduleId, collId)` | SH | Live rows; do not modify |
| `Find(moduleId, collId, key, value)` | SH | First row where a column matches |
| `Watch(moduleId, collId, fn)` | SH | Calls `fn(rows)` now and after every change |
| `Set(moduleId, collId, rows, actor)` | SH | Replaces rows after validation |
| `Reset(moduleId, collId, actor)` | SH | Restore default rows |
| `NewRow(moduleId, collId)` | SH | A row at column defaults |
| `Normalize(moduleId, collId, rows)` | SH | Validated copy or `false, reason` |
| `GetDefinition(moduleId, collId)`, `ListFor(moduleId)` | SH | Introspection |
| `ToColor(value)` | SH | `{r, g, b, a}` to `Color` |
| `RowsFromMap` / `MapFromRows`, `RowsFromList` / `ListFromRows`, `RowsFromSet` / `SetFromRows` | SH | Convert between plain tables and rows |
| `Suggest[name]`, `Browse[name]` | CL | Providers for autocomplete and the class picker; addons may add their own |

## DFW.Registry

Generic validated registry for definitions (items, skills, recipes).

```lua
local items = DFW.Registry.Create("items", {
    validate = function(definition) return definition.name ~= nil, "name_required" end,
    sort = function(a, b) return a.name < b.name end,
    allowOverride = false
})

items:Register("bandage", {name = "Bandage"})
```

Methods: `Register(id, definition)`, `Get(id)`, `Has(id)`, `Count()`, `Remove(id)`, `All()`, `Each(callback)`. Functions: `DFW.Registry.Create(name, options)`, `DFW.Registry.Get(name)`, `DFW.Registry.GetNames()`. Hooks: `DFW_RegistryRegistered(name, id, definition)`, `DFW_RegistryRemoved(name, id)`.

## DFW.Net

| Function | Realm | Description |
| --- | --- | --- |
| `Name(name)` | SH | The full message name, `DFW.<name>` |
| `Pool(name)` | SH | Registers the name (the server calls `util.AddNetworkString`) |
| `Start(name)` | SH | `net.Start` for a pooled name |
| `Receive(name, callback, options)` | SH | Receiver with `maxBits`, `cooldown` (seconds per player) and `access(ply)`; the callback runs under `pcall` and gets `(length, ply)` |
| `WriteJSON(table, maxBytes)` | SH | Writes a compressed table; returns `ok, reason`; default cap 60,000 bytes |
| `ReadJSON(maxBytes)` | SH | Reads a table or `nil` |

## DFW.Data

Server-side storage under `garrysmod/data/dubz_framework/`.

| Function | Description |
| --- | --- |
| `ReadJSON(name, fallback)` | Returns the table or the fallback, and a status: `ok`, `missing`, `recovered`, `corrupt`, `invalid_name` |
| `WriteJSON(name, table)` | Atomic write that keeps `<name>.previous.json`; returns `ok, reason` |
| `Exists(name)`, `Delete(name)`, `Path(name, suffix)` | File helpers |

Names use letters, digits, `_`, `-` and `/`; anything else becomes `_`. Unreadable files are kept as `.corrupt.json`.

## DFW.Themes

`DFW.Themes.Register(id, {name, colors, radius?, spacing?})` requires every colour token (see [ui-library.md](ui-library.md)) and may be called at any time, on both realms; the theme appears in the Appearance dropdown and applies if an admin had already chosen it. `Get(id)` (older saved ids resolve to the theme that replaced them), `GetIds()`, `GetRequiredColors()`, and `DFW.Themes.DefaultId`, the theme used until an admin picks another. Making a theme and offering presentation styles are covered in [styles-and-themes.md](styles-and-themes.md).

## DFW.Access

`DFW.Access.CanConfigure(ply)` is true for superadmins unless a `DFW_CanAccessConfig(ply)` hook returns a boolean.

## Hooks

Framework hooks (all through `hook.Run`; add listeners with `hook.Add` and unique ids):

| Hook | Arguments | When |
| --- | --- | --- |
| `DFW_FrameworkLoaded` | `version, apiVersion` | Framework finished loading |
| `DFW_AddonRegistered` | `id, record` | An addon was registered |
| `DFW_AddonStateChanged` | `id, state, reason` | An addon's state changed |
| `DFW_PackageLoaded` | `id` | A package's files all loaded |
| `DFW_ModuleRegistered` | `id, addon` | A module was registered |
| `DFW_ModuleStarted`, `DFW_ModuleStopped`, `DFW_ModuleFailed`, `DFW_ModuleUnregistered` | `id` (`reason` or `failure`) | Lifecycle |
| `DFW_ModuleStateChanged` | `id, enabled` | An admin switched a module |
| `DFW_ConfigRegistered` | `moduleId` | A schema was registered |
| `DFW_ConfigChanged` | `moduleId, key, value, actor` | A setting changed (server and clients) |
| `DFW_ConfigSnapshot`, `DFW_PublicConfigReceived` | none | Clients received settings |
| `DFW_CollectionRegistered` | `moduleId, collId` | A collection was registered |
| `DFW_CollectionChanged` | `moduleId, collId, rows, actor` | Rows changed (also fires at registration) |
| `DFW_RegistryRegistered`, `DFW_RegistryRemoved` | `registryName, id[, definition]` | Registry changes |
| `DFW_ThemeRegistered` | `id` | A theme was registered (any time) |
| `DFW_ThemeReady`, `DFW_ThemeChanged` | `theme` / none | Client theme state |
| `DFW_CanAccessConfig` | `ply` | Return a boolean to override who may open the admin menu |
| `DFW_OpenConfigMenu` | none | The admin menu opened |

## Console and chat commands

| Command | Realm | Description |
| --- | --- | --- |
| `!dubzconfig`, `!dfw`, `/dubzconfig` | chat | Open the admin menu |
| `dfw_config`, `dfw_config_open` | CL | Same |
| `dfw_status`, `dfw_status_cl` | SV/CL | Packages, modules and states |
| `dfw_selftest`, `dfw_selftest_cl` | SV/CL | Built-in checks |
| `dfw_ui_demo` | CL | Every control on screen |
