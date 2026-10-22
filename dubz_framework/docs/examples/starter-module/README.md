# Example: Starter Module

The smallest module that does everything the framework expects: it registers a package, binds settings into the admin menu, offers an editable table, honours the master switch, and reads its settings live. Start here to see the moving parts; use the [money printer](../money-printer) to see a full system.

It sends a message from a list to everyone on a timer.

## Files

```
addon.json
lua/autorun/acme_starter.lua            loader, missing-file check, package manifest
lua/acme_starter/sh_config.lua          the settings, the default rows, the shared helpers
lua/acme_starter/sh_framework.lua       DFW.Bind.Module: two settings and one collection
lua/acme_starter/sv_announce.lua        the behaviour, on the server
```

## What each part shows

| Part | Pattern |
| --- | --- |
| `autorun/acme_starter.lua` | The standard loader. Shared config is included straight away; the framework file and the server file are listed in the manifest, so they load only when the framework is ready. A missing file is named in the console |
| `sh_config.lua` | A config table of plain values, default collection rows, a function that turns rows into a lookup, and `Enabled()` wrapping `DFW.Bind.Enabled` |
| `sh_framework.lua` | `DFW.Bind.Module` with two specs (a slider and a text box) and one collection (`announcements`: id, message, on). `DFW.Collections.Watch` rebuilds the lookup whenever an admin saves the table |
| `sv_announce.lua` | One timer that checks the master switch and reads `config.IntervalSeconds` on every tick, so edits apply immediately with no restart |

In the admin menu (`!dubzconfig`) the module appears as "Announcements" with a Timing group, a Look group and an Edit card for the table.

## Growing it

- Add a setting: add the key to `sh_config.lua` and a spec to `sh_framework.lua`; read it with `config.Key` where you use it.
- Add a column to the table: add it to the collection's `columns` and to the default rows.
- Add a second system: make a second addon with its own prefix-feature name rather than adding to this one.
- Send the message through your gamemode's notifications: write an adapter (see [building-modules.md](../../building-modules.md)) and call it instead of `PrintMessage`.

## Adapting it

Replace `Acme` and `acme_` with the project's prefix, rename the feature, and keep the structure. The prefix and names come from the project profile ([project-profile.md](../../project-profile.md)), never from this example.
