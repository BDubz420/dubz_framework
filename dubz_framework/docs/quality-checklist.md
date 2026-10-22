# Quality Checklist

Run this list before you say a module is finished. Every item is a yes or no. A "no" is either fixed or reported as an assumption or limitation.

## 0. Profile

- [ ] The project profile (prefix, gamemode, theme, style, categories, conventions) was resolved and stated at the start.
- [ ] No name, category, price or style was copied from an example or from another project.
- [ ] Every name and category a player or admin sees is a setting whose default derives from the profile.
- [ ] Money, notifications, shop or job registration and ownership go through the adapter; module logic never calls the gamemode.
- [ ] Where an element can look more than one way, styles live in a registry selected by a setting.

## 1. Structure

- [ ] The addon folder is `<prefix>_<feature>` with `addon.json`, `lua/autorun/<prefix>_<feature>.lua`, and `lua/<prefix>_<feature>/`.
- [ ] Every Lua file under the addon folder starts with `sh_`, `sv_` or `cl_` (entity and weapon files follow the engine's names: `shared.lua`, `init.lua`, `cl_init.lua`).
- [ ] No file name contains a number.
- [ ] One responsibility per file; none longer than a few hundred lines.
- [ ] The autorun checks for missing files and names them.
- [ ] The autorun works whether it runs before or after the framework autorun.
- [ ] `sh_config.lua` is included by the autorun and sent to clients; `sh_framework.lua` is loaded only through the manifest.
- [ ] Manifest paths are relative to `lua/`, use forward slashes and exist.

## 2. Framework registration

- [ ] The package manifest has `id`, `name`, `version`, `api = 1`, `dependencies`, `files`.
- [ ] `sh_framework.lua` calls `DFW.Bind.Module` with a module id that is lowercase snake_case, an icon from the catalogue, a description, and `dependencies = {"dubz_core"}`.
- [ ] Every spec `path` exists in the config table (check the console for "does not exist in the addon's config, skipped").
- [ ] `dfw_status` shows the package `loaded` and the module `started`.
- [ ] `!dubzconfig` shows the module with every group and control.
- [ ] `Enabled()` exists and gates gameplay entry points.
- [ ] If the module opens windows, the bind options include `ui = true` and frames pass `module = "<id>"`.

## 3. Configuration

- [ ] Every number, string, toggle, colour, model, sound, key, list, chance and duration used by gameplay is a setting.
- [ ] Every numeric setting has `min`, `max` and a sensible `decimals`.
- [ ] Every setting has a label in Title Case with units in brackets, and a description when the label is not enough.
- [ ] Settings are grouped into three to eight groups in the order an admin thinks.
- [ ] Settings that must not reach players have `public = false`.
- [ ] Tables of things (items, loot, recipes, tiers, labels, tasks) are collections with default rows, `idKey` where rows are looked up by id, and a `Watch`.
- [ ] Nothing reads a setting into a long-lived local.
- [ ] A setting that affects things already in the world (a position, a model, an attachment) re-applies to the live instances when it changes, debounced.
- [ ] Settings read only when the gamemode loads its items say "Changes need a restart" in their description.
- [ ] No spec exists that nothing reads.

## 4. Behaviour

- [ ] The states and transitions were written down, and the code has one function that computes the state.
- [ ] Per-entity logic runs in one `Think` with `NextThink`, not many timers.
- [ ] Anything the client draws travels in network variables.
- [ ] Interaction is physical or contextual: supplies and add-on modules act on contact, E does the one main action, slow actions hold E. There are no key chords (Shift, Ctrl or Alt plus a key) unless the request asked for them.
- [ ] Every state and failure path can be reached with the default settings (thresholds are ordered, and one cycle was simulated by hand).
- [ ] Every message a player reads is a setting in a `Text` table.
- [ ] The server validates every client request: player, entity, distance, permission, ranges.
- [ ] Anything that can be spammed is rate limited.
- [ ] Prices, rewards and outcomes are decided on the server.
- [ ] Messages to players are one short sentence, through the adapter's `Notify`.

## 5. UI

- [ ] Windows use `DFW.UI.CreateFrame` and `DFW` controls only.
- [ ] Overlays and HUD use `DFW.Draw`, theme tokens and library fonts.
- [ ] No hard-coded colours that a theme token covers; the look comes from the active theme and the chosen style.
- [ ] Overlays skip drawing beyond a configurable distance and when the framework is absent.
- [ ] 3D2D position, scale and yaw are settings.
- [ ] `cam.Start3D2D` and `cam.End3D2D` are paired, and `surface.SetAlphaMultiplier` is reset to 1.
- [ ] Only one instance of each window can be open.
- [ ] Icons come from the catalogue.

## 6. Cleanup and lifecycle

- [ ] `OnRemove` stops sounds and removes timers and child entities.
- [ ] Delayed callbacks check `IsValid`.
- [ ] Hooks and timers have unique, prefixed ids.
- [ ] Switching the module off stops gameplay without errors.
- [ ] Owned entities follow the ownership rules (`owning_ent`, `SID`, abandonment).
- [ ] No global state besides the one namespace table.

## 7. Code style

- [ ] No comments anywhere in code files (run the checks below).
- [ ] 4-space indentation, no tabs, no trailing whitespace, one newline at the end of each file.
- [ ] Double-quoted strings; `~=`, `and`, `or`, `not`; no `continue`, no `//`.
- [ ] Names follow the naming table in [code-style.md](code-style.md).
- [ ] Functions are short, guard clauses are used, nesting is shallow.
- [ ] No dead code, no unused variables, no debugging prints.
- [ ] No magic numbers in logic.

## 8. Resilience

- [ ] With the framework removed, the addon loads on its defaults and nothing errors.
- [ ] With an optional integration removed, the rest still works.
- [ ] Missing files are reported by name at start.
- [ ] Bad input (a nil entity, a removed owner, a disconnected player) is handled, not assumed.

## 9. Diagnostics

- [ ] A check command exists and works even when files are missing.
- [ ] A test command (superadmin only) triggers anything gated by time, chance or world state.
- [ ] A values command prints dialled-in numbers.
- [ ] Spatial and visual values are dial-in settings in their own groups.
- [ ] Every early return that stops a feature explains why to the admin.
- [ ] Repeating work guards each item with `pcall` and reports once per distinct error.
- [ ] Admin tools exist for any world data, and the data is saved per map.

## 10. Verification commands

Run these from the addon folder and fix everything they report.

Comment check (should print nothing for code files; string literals containing `--` are fine):

```bash
grep -rn -- "--" lua | grep -v "\"[^\"]*--[^\"]*\""
```

Tab check:

```bash
grep -rnP "\t" lua
```

Trailing whitespace:

```bash
grep -rnE " +$" lua
```

Global assignments that are not local (review each hit):

```bash
grep -rnE "^[a-z][A-Za-z0-9_]* = " lua
```

Numbers in logic (review each hit for something that should be a setting):

```bash
grep -rnE "[^A-Za-z_\"][0-9]+\.?[0-9]*[^A-Za-z_\"0-9]" lua/<addon>/sv_*.lua lua/entities
```

In game:

1. `dfw_status`: package loaded, module started.
2. `!dubzconfig`: every setting present and editable; change one and see the behaviour change without a restart.
3. Switch the module off and on in the Modules page.
4. Use the feature as a player; damage it, remove it, leave the server mid-use.
5. Read both consoles for Lua errors.
6. Restart; confirm the values persisted.

If you cannot run the game, say so, and list which of these you could not do.

## 11. The final report

Finish with these parts, in this order (the hand-off template in [workflow.md](workflow.md) lists the same parts with an upload list and commands to try):

1. **Files:** the final tree.
2. **Player experience:** what a player can do, in a few lines.
3. **Admin control:** where the settings are (`!dubzconfig`, module name), the groups, and the collections.
4. **Assumptions:** every default you chose that the request did not state, one line each.
5. **Not tested:** what you did not or could not verify.
6. **How it works:** a short, plain explanation of where the settings live, how the look is controlled and how to extend the module (see the teaching section of [AGENTS.md](../AGENTS.md)).
7. **Follow-up ideas:** two to four optional extensions the project could add on top (another tier, another style, another gamemode adapter).
8. **Next steps:** anything the owner must do (upload the folder, restart, set a price).
