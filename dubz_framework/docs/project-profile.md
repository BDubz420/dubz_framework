# The Project Profile

The framework is used in many kinds of projects: roleplay servers, event servers, minigames, sandbox communities. Nothing in these documents assumes one of them. Every name, category, colour direction and convention in the code you write comes from the **project profile**, which you resolve at the start of the task. It never comes from the examples, from habit, or from a default baked into this repository.

The examples use the placeholder prefix `Acme` and the placeholder project "Acme". They are samples of structure. Do not copy their names, categories, prices or style into a real project.

## What a profile contains

| Field | Meaning | Used for |
| --- | --- | --- |
| **Project name** | The human name of the server or game | Display strings, spawn menu categories |
| **Prefix** | Short lowercase token, for example `acme` | Addon folders, package ids, entity and weapon classes, command names, data folders |
| **Namespace prefix** | The prefix in PascalCase, for example `Acme` | Global tables (`AcmePrinters`), hook, timer and net names |
| **Gamemode and economy** | Which gamemode runs and how money, jobs and shops work | Which adapter functions you write (see [gmod-patterns.md](gmod-patterns.md)) |
| **Theme direction** | The built-in preset the project uses, or a custom theme to create | UI colours, radius, spacing (see [styles-and-themes.md](styles-and-themes.md)) |
| **Presentation style** | How overhead labels, HUD elements and windows should feel | Which style variants to build |
| **Categories** | Names for shop sections, spawn menu tabs, admin settings groups | Config defaults (always settings) |
| **Conventions** | Comments, indentation, message tone, language | Code style and strings |
| **Present addons** | Skills, inventory, jobs and other addons found in the workspace | Optional integrations |

## How to resolve it

Resolve each field in this order and stop at the first source that answers it.

1. **The prompt.** If the user names a project, a prefix, a gamemode, a style ("minimal", "industrial", "like our scoreboard") or a convention, use it exactly.
2. **The workspace.** Look before you decide:
   - **Prefix:** list the addon folders and the `lua/autorun` files. If two or more share a leading token before the first underscore (`acme_atm`, `acme_jobs`), that token is the prefix. Check the global tables (`AcmeJobs`) and entity classes for the same pattern.
   - **Project name:** `addon.json` titles, README headings, the server's `server.cfg` hostname.
   - **Gamemode:** a `gamemodes/` folder, a global such as `DarkRP`, `nut`, `ix`, or a `GM.Name` string. If several exist, the one the project's other addons call is the one in use.
   - **Theme:** search for `Themes.Register` and `RegisterTheme` to find custom themes; read `data/dubz_framework/config.json` for the saved `theme`; read existing HUD and overlay code for the style in use.
   - **Present addons:** search for the global tables listed in [integrations.md](integrations.md).
   - **Conventions:** read two existing files: do they use comments, tabs or spaces, what do messages sound like.
   - **Match the neighbours.** If the project already has working code, your module should be indistinguishable from it in naming, layout and tone.
3. **Defaults.** Use the table below only for fields that nothing else answered. Record each one as an assumption.
4. **Ask.** Ask one short question only when all of these hold: no source answered it, a wrong guess would force renaming across many files (the prefix is the main case), and nothing sensible can be derived. Otherwise do not ask; decide and report.

## Defaults when nothing answers

| Field | Default |
| --- | --- |
| Prefix | Derived from the project folder name or the project's display name: lowercase, letters and digits only, 10 characters at most. A one-word project `Frostline` becomes `frostline`; `Dead Zone RP` becomes `dzrp` |
| Namespace prefix | The prefix with the first letter capitalised |
| Project name | The folder name, title-cased |
| Gamemode | Detected; if none is found, treat the project as gamemode-neutral and write the adapter with hook overrides only |
| Theme | The framework's default preset. Do not create a theme unless asked or the project's style demands one |
| Presentation style | Neutral: library cards and bars, themed |
| Categories | The feature's display name for shop sections; `<Project name> <Feature>` for the spawn menu |
| Conventions | The framework's conventions: no comments in code, 4-space indentation, short second-person messages |

## Where profile values go

Profile values appear in code in exactly three kinds of places. Anything else is a mistake.

| Where | Example |
| --- | --- |
| **Identifiers** | `acme_printers`, `AcmePrinters`, `acme_money_printer`, `AcmePrinters_Items` |
| **Config defaults** | `Category = "Printers"`, `SpawnCategory = "Acme Printers"`, `Name = "Money Printer"` |
| **Strings players read** | Built from config settings (`config.Name`), never typed into logic |

Every category, section, label and name that a player or admin sees is a config setting whose default is derived from the profile. Spawn menu tabs and shop sections are read from config when the entity or item registers, so say "Changes need a restart" in the setting's description.

Keep the profile visible. Put it at the top of your first reply:

```
Project profile
  Project:     Acme
  Prefix:      acme / Acme
  Gamemode:    DarkRP (found gamemodes/darkrp)
  Theme:       framework default
  Style:       neutral
  Categories:  shop "Printers", spawn menu "Acme Printers"
  Conventions: no comments, 4 spaces
  Assumed:     prefix derived from neighbouring addons acme_atm and acme_jobs
```

and repeat the assumed lines in the final report.

## What never to assume

- That the project is a roleplay server, or that it runs DarkRP. Money, jobs, shops and notifications go through the adapter, so any gamemode can be supported by changing one file.
- That a particular addon (skills, inventory, jobs) exists. Search for it; if it is absent, leave the integration out and say so.
- That a particular look is wanted. The look is the theme and the chosen style, resolved above.
- That a name from an example, a neighbouring project or this documentation applies. Names come from the profile.
- That the project's existing conventions are wrong because the framework's differ. Match the project when it has conventions of its own and the owner has not asked for the framework's.

## When the project has no conventions yet

A new project starts clean: use the framework's conventions, choose the prefix once, put it in the first file you create, and write the profile block so the owner can correct it before you build more. Changing a prefix later means renaming files, globals, classes, hooks and settings keys, so make the choice deliberately.
