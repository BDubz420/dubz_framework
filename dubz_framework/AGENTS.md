# Agent Instructions: Building on the Dubz Framework

You are in a Garry's Mod workspace that contains the Dubz Framework (`DFW`). If the task is to build, change or review any script, module, entity, weapon, NPC, job, HUD or menu, this file is your operating manual. Read it fully, then follow the reading order below. Do not write code before you have read the first four documents.

This framework serves many different projects. It does not assume a server, a gamemode, a theme or a naming scheme. You find those out (see the project profile) and build for the project in front of you.

## Why this exists

Scripts written by AI without a foundation tend to be one large file with hard-coded numbers, no settings, no standards and no cleanup. This framework is the foundation: standards to follow, defaults to start from, helpers to call, and a configuration and UI system that is already built. Your job is to build on it so that even a one-line request produces the kind of system a careful, experienced developer would ship: a self-contained addon, bound into the admin config menu, themed, safe and tidy.

## What the framework gives you

- **Modules and packages.** One manifest per addon, one registered module per feature, with a master switch in the admin menu.
- **Typed settings.** Every tunable value appears in an in-game admin menu (`!dubzconfig`) as a slider, switch, text box, colour picker or drop-down, is validated and saved by the server, and reaches clients live.
- **Collections.** Admin-editable tables of rows (shop items, loot, ranks, recipes, status labels) with a full row editor.
- **Themes and a UI library.** Themed windows, buttons, inputs, bars, dialogs, toasts, item slots and drawing helpers, including world-space (3D2D) helpers. A project picks a preset theme or registers its own, and everything built on the library restyles.
- **Style registries.** A pattern for offering several looks for the same element (overhead labels, HUD elements, windows) that any addon can extend.
- **Storage, networking, registries.** Atomic JSON storage, rate-limited networking, validated registries.

## The standard: what every module contains

A finished module always has all of these. If one is missing, the work is not finished.

1. **Its own addon folder**, `<prefix>_<feature>`, never inside the framework folder, with a loader (`lua/autorun`) that checks its files and submits a package manifest.
2. **A config table** holding every value the feature uses, **bound into the admin menu** with a spec for each value (label, group, range, description), and a collection for every table of things.
3. **A master switch** honoured by all gameplay code, and settings read live.
4. **A gamemode adapter** for money, notifications, shop or job registration and ownership.
5. **Behaviour split by realm and responsibility** into small files. No monoliths.
6. **UI built from the library and the active theme**, with world and HUD drawing through the framework's helpers, and styles in a registry where an element can look more than one way.
7. **Server-authoritative logic**, validated and rate-limited.
8. **Cleanup**: sounds, timers and children are removed; nothing leaks.
9. **Clean code** that follows the project's conventions (default: no comments, 4-space indentation).
10. **Diagnostics and dial-ins:** a check command, a test command for time- or chance-gated features, a values command, dial-in settings for anything spatial or visual, and loud failure messages.
11. **A hand-off report** that states the profile, the file tree, what to upload and run, what players and admins can do, the assumptions made and what was not tested, and that teaches the user how the pieces work.

## Reading order

All paths are relative to the repository root.

1. [project-profile.md](docs/project-profile.md): resolve the project's prefix, gamemode, theme, style, categories and conventions before anything else. Nothing is hard-coded.
2. [workflow.md](docs/workflow.md): the working loop. How to sort a message, plan, build in slices, make a system observable, hand off, and handle feedback.
3. [prompt-to-spec.md](docs/prompt-to-spec.md): turn a short, vague or large request into a complete specification.
4. [building-modules.md](docs/building-modules.md): the end-to-end workflow, file layout, loader, naming and lifecycle.
5. [config-design.md](docs/config-design.md): the rule that every value is an admin setting, and how to expose it.
6. [code-style.md](docs/code-style.md): formatting, naming, file size limits and the comments convention.
7. [gmod-patterns.md](docs/gmod-patterns.md): entities, weapons, NPCs, networking, gamemode adapters, 3D2D and HUD recipes, admin tools.
8. [styles-and-themes.md](docs/styles-and-themes.md): choosing or creating a theme, and offering several presentation styles.
9. [ui-library.md](docs/ui-library.md): every control, helper, theme token and font. Use it before drawing anything.
10. [api-reference.md](docs/api-reference.md): exact signatures for every `DFW` function and hook.
11. [integrations.md](docs/integrations.md): how to work with other systems you may find in a workspace, or none.
12. [quality-checklist.md](docs/quality-checklist.md): run this before you say you are done.
13. [testing.md](docs/testing.md): how to verify the framework and a module in game.
14. [examples/money-printer](docs/examples/money-printer): a complete reference module. [examples/starter-module](docs/examples/starter-module): the smallest valid module. Copy their structure, never their names.

## Working rules

1. **Resolve the profile first.** Prefix, namespace, categories, gamemode, theme, style and conventions come from the prompt or the workspace, never from the examples. Put them in a profile block at the top of your first reply.
2. **Run the working loop.** Sort the whole message, orient, plan in proportion, build in slices that always load, verify, hand off, and treat feedback by root cause ([workflow.md](docs/workflow.md)).
3. **The framework is read-only.** Build modules as separate addons beside it. Change the framework only when the user explicitly asks you to.
4. **Register through the framework.** Every feature ships as an addon with an autorun manifest (`DFW.Packages.Submit`) and a `sh_framework.lua` that calls `DFW.Bind.Module`. No exceptions for "small" scripts.
5. **No hard-coded values in logic.** Every number, string, toggle, colour, model, sound, key, list, chance, name and category lives in the addon's config table and has a setting spec, so the admin has full control. Tables of things become collections. Spatial and visual values are dial-in settings.
6. **Read config live.** Read `config.Value` where you use it. Never copy a number into a local at load time. Keeping a reference to the config table itself is fine; it is updated in place.
7. **Honour the master switch.** Gate gameplay code with the addon's `Enabled()` function, which wraps `DFW.Bind.Enabled`.
8. **Build UI from the library and the theme.** Use `DFW` controls, `DFW.Draw` helpers (including `Draw.World`, `Draw.Billboard` and `Draw.Bar`), theme tokens and library fonts. Never hard-code a colour a token covers. Do not assume a look: the active theme decides it.
9. **Prefer physical, contextual interaction.** Supplies, ink, fuel, ammo, parts and add-on modules are entities the player carries and touches to the machine; E does the one main action; slow actions hold E with a progress bar. Do not invent key chords (Shift+E, Ctrl+E, Alt+E) or hidden binds, and do not use menus or commands for something that happens at an object. See [gmod-patterns.md](docs/gmod-patterns.md).
10. **No monoliths.** One responsibility per file and per function; files stay small (see [code-style.md](docs/code-style.md)). A request that spans several systems becomes several addons or modules, not one big file.
11. **Follow the conventions of the project.** Default to the framework's: no comments in code, 4-space indentation. If the workspace shows other conventions or the user states them, match those.
12. **Clean namespace from the profile.** One global table per addon, `<Prefix><Feature>`; classes `<prefix>_<thing>`; every hook, timer, net message and data file name prefixed with the addon id.
13. **Server is authoritative.** Clients display; the server decides. Validate everything that comes from a client, rate-limit it, and never trust a client-supplied number, entity or price.
14. **Keep other systems behind adapters.** The gamemode, and any optional system you find (progression, inventory, dialogue), is reached through a small adapter file, so the module runs anywhere by changing that file. Never edit the gamemode or another addon.
15. **Degrade gracefully.** If the framework or an optional system is missing, the addon must not error. It runs on its defaults and skips the optional parts.
16. **Make it observable and testable.** Ship a check command, a test command for anything gated by time or chance, and a values command for dialled-in numbers. Failures are loud and say which module and why. Nothing fails silently.
17. **Clean up after yourself.** Entities stop sounds and remove timers in `OnRemove`. Timers that outlive an entity check `IsValid`. Nothing leaks, nothing runs per frame that does not have to.
18. **Teach as you build.** The user may be new to all this. In your report, explain briefly how the pieces work (see below). Explanations go in the report, never in code comments.
19. **Finish properly.** Run the checklist, then hand off with the template in [workflow.md](docs/workflow.md). Do not claim something works in game if you did not run it.

## Teaching the user

Keep it short and concrete. After the work is done, tell the user:

- **Where to configure it:** the module's name in `!dubzconfig`, the groups on its page, and which tables are editable (collections).
- **What is live and what needs a restart:** settings take effect immediately; names or categories read when the game registers items say so in their description.
- **How the look is controlled:** the theme in the admin menu; where a style registry exists, how to add another style.
- **How the code is laid out:** one line per file, so they can find things and ask for changes by name.
- **How to extend it:** the one or two most likely next steps (a second tier, another style, another gamemode adapter) and which file they touch.
- **What you assumed and what you could not test.**

Use plain language. Prefer two clear sentences to a paragraph. Do not lecture; give the user what they need to run, change and trust what you built.

## When the request is vague

Do not interrogate the user. A short prompt such as "I want a money printer with cooling, ink, a chance to explode, health and a nice UI" is a complete request for you: resolve the profile, expand the request with [prompt-to-spec.md](docs/prompt-to-spec.md), make the engineering decisions yourself using the defaults it gives, build the module, and list your assumptions at the end so the user can redirect you. Ask a question only when no source answers something and a wrong guess would force renaming across many files (the prefix is the usual case).

## When the request is large

A request such as "a full drug system" or "a police job with arrests, fines and a station" is several systems. Split it into addons or modules by responsibility, order them by dependency, build and finish one at a time, and connect them through hooks and adapters, not shared globals. See [prompt-to-spec.md](docs/prompt-to-spec.md).

## When the request is to change something that exists

Read the existing addon first. Match its namespace, naming, layout and tone. Add settings for any new value you introduce. Do not rename or restructure working code you were not asked to touch.

## Where things live in this repository

```
lua/autorun/dubz_framework.lua    boot, load order and the loader checks
lua/dubz_framework/core/          registry, access, net, data, packages, modules, themes, config, bind, collections
lua/dubz_framework/ui/            client controls, drawing helpers, themes
lua/dubz_framework/menu/          the admin menu, table editor, picker, self test, showcase
materials/dubz_framework/icons/   icon set
docs/                             this guide, the reference, and the examples
```

Diagnostics: `dfw_status` prints loaded addons, modules and packages. `dfw_selftest` runs the built-in checks. `dfw_ui_demo` opens the UI showcase.

## Starting a session

This file and `CLAUDE.md` sit at the root of the repository so tools that load them automatically find them. If you were pointed here by a prompt, this is your entry.
