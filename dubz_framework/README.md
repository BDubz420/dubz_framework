# Dubz Framework

A small framework for Garry's Mod roleplay addons. It gives every addon the same pieces: a module registry, a settings system with an in-game admin menu, saved editable tables, themes, and a set of ready-made UI controls.

Other addons describe their settings once and get an admin menu page, saving, loading and syncing to clients without writing any of it themselves.

## Install

Put the `dubz_framework` folder in `garrysmod/addons/` on the server (and in the client content if you distribute it by workshop or a content pack). Restart the server. The console prints `[Dubz Framework] Ready` when it has loaded; a missing file is reported by name.

## Use

| Command | What it does |
| --- | --- |
| `!dubzconfig`, `!dfw`, `/dubzconfig` | Open the admin menu (superadmins) |
| `dfw_config` | The same, from the console |
| `dfw_status` | Print the loaded addons, modules and packages |
| `dfw_selftest` | Run the built-in checks on the server (`dfw_selftest_cl` on a client) |
| `dfw_ui_demo` | Open a demo of the interface controls |

Who may open the menu is decided by `DFW.Access.CanConfigure`. By default that is superadmins; return `true` or `false` from the `DFW_CanAccessConfig` hook to change it.

## Registering an addon

Submit a manifest from the addon's autorun file. If the framework has not loaded yet, the manifest is held and picked up when it does.

```lua
DFW = DFW or {}
DFW.PendingPackages = DFW.PendingPackages or {}

local manifest = {
    id = "my_addon",
    name = "My Addon",
    version = "1.0.0",
    api = 1,
    dependencies = {"dubz_framework"},
    files = {"my_addon/sh_framework.lua"}
}

if DFW.Packages and DFW.Packages.Submit then
    DFW.Packages.Submit(manifest)
else
    DFW.PendingPackages[#DFW.PendingPackages + 1] = manifest
end
```

The listed files run once the framework is ready. In one of them, bind a plain config table to the admin menu:

```lua
local config = {
    Enabled = true,
    Payout = 100,
    Mode = "normal"
}

DFW.Bind.Module({
    id = "my_addon",
    name = "My Addon",
    version = "1.0.0",
    icon = "navigation/settings",
    description = "What the addon does.",
    dependencies = {"dubz_core"}
}, config, {
    {path = "Enabled", label = "Enabled", group = "General"},
    {path = "Payout", label = "Payout", min = 0, max = 10000, decimals = 0, group = "General"},
    {path = "Mode", label = "Mode", choices = {"normal", "hard"}, group = "General"}
})
```

The values in `config` are replaced by whatever the admin saves, so the addon just reads `config.Payout`. A setting's control follows its value: a number gets a slider, a boolean a switch, a colour a colour picker, and `choices` a drop-down.

### Editable tables

A module can also declare tables the admin edits row by row (shops, jobs, spawn points), with typed columns and defaults:

```lua
DFW.Bind.Module(definition, config, specs, {
    collections = {
        {
            id = "tasks", label = "Tasks", idKey = "id",
            columns = {
                {key = "id", label = "Id", type = "string"},
                {key = "payout", label = "Payout", type = "number", min = 0, max = 100000, decimals = 0}
            },
            default = {{id = "first", payout = 100}}
        }
    }
})

DFW.Collections.Watch("my_addon", "tasks", function(rows)
end)
```

The watch function runs now and every time an admin saves the table.

## Layout

```
lua/autorun/dubz_framework.lua    boot and load order
lua/dubz_framework/core/          registry, access, networking, packages, modules, themes, config, bind, collections, storage
lua/dubz_framework/ui/            client controls: frames, buttons, inputs, popups, layout, overlays, drawing helpers, icons
lua/dubz_framework/menu/          the admin menu, the table editor and picker, the self test panel, the demo
materials/dubz_framework/icons/   icon set
```

Files start with their realm: `sh_` shared, `sv_` server, `cl_` client. The load order is the explicit list in `lua/autorun/dubz_framework.lua`; add a new framework file to it.

## License

MIT. See [LICENSE](LICENSE).
