# Testing

How to verify the framework after installing it, and how to verify a module built on it. Run these in game: the framework is a Garry's Mod addon and its rendering, popups and animation can only be judged on a real client.

## 1. Install and boot

1. Copy the `dubz_framework` folder into `garrysmod/addons/` and restart the server.
2. The server console should print, with no red text and no `WARNING` or `ERROR` lines:

   ```
   [Dubz Framework] Booting v0.4.0 (API 1)
   [Dubz Framework] Queued 85 icon resources for clients
   [Dubz Framework] Ready (...)
   ```

   The numbers in the `Ready` line depend on which addons are installed.

If boot shows red `missing:` lines, or `FATAL: DFW.<Name> did not load`, the upload is incomplete (FTP transfers can silently fail). The folder must contain 37 `.lua` files and 85 `.png` icons. Re-upload it and restart. The boot message names every missing file.

## 2. Built-in self tests

- Server console: `dfw_selftest`. Expect `... 0 failed`.
- Client console in game: `dfw_selftest_cl`. Expect `... 0 failed`.
- Server console: `dfw_status` lists packages and modules; every module should be `started`.

If any line says `[FAIL]`, copy the whole block into a bug report.

## 3. Configuration menu (superadmin)

Open with `!dubzconfig` in chat or `dfw_config` in the client console.

| Check | Expected |
| --- | --- |
| Window opens with an icon, a title and a close button | Drag by the header; Escape or the close button closes it |
| Sidebar: Overview, Modules, then Framework Core and every installed module | Clicking a row switches the page and highlights it |
| Modules page | Every module has a state badge; Framework Core is marked `core` with a disabled switch |
| Switch a module off, then on | The badge changes to `disabled` then `started`; the menu does not flicker |
| A module page | Settings are grouped; sliders, switches, text fields, drop-downs and colour swatches all work |
| Drag a slider and release | A "Setting saved" toast appears once and the row shows a reset arrow |
| The reset arrow on a row | The value returns to its default and the arrow disappears |
| "Reset module" | A confirmation dialog; confirming restores every setting |
| Search box, type part of a setting name | The page switches to matching settings; clearing returns to Overview |
| Change a setting while the menu is open | The menu stays on the same page |

## 4. Themes

| Check | Expected |
| --- | --- |
| Framework Core page: change Theme to `slate`, then `light`, then `classic` | Every open window and overlay recolours immediately |
| Tick Custom Accent and pick a colour | The accent colour changes everywhere |
| Register a custom theme from an addon (see [styles-and-themes.md](styles-and-themes.md)) and restart | It appears in the Theme dropdown and can be selected |
| Select it, restart the server | It is still selected and applied after the restart |
| Remove the theme's addon and restart | The framework falls back to the default theme without errors |

## 5. A non-admin player

Join with an account that is not a superadmin.

- `!dubzconfig` says access is denied and the menu does not open.
- Their screen uses the theme the admin chose (public settings replicate to everyone).

## 6. Component demo

Client console: `dfw_ui_demo`, which opens the showcase. Walk through the Overview, Controls and Feedback tabs. Every control should react to hover and click; toast buttons stack notifications; Confirm, Message and Prompt open centred dialogs over a dimmed screen. Use the Preview theme dropdown to check each theme; closing the window returns to the chosen theme.

## 7. Persistence

1. Change a few settings and switch one module off.
2. Restart the server.
3. Reopen `!dubzconfig`: the settings are kept and the module is still off.
4. `garrysmod/data/dubz_framework/` contains `config.json` and `modules.json`.

## 8. Testing a module you built

Work through [quality-checklist.md](quality-checklist.md). In short:

1. `dfw_status` shows the package `loaded` and the module `started`.
2. The module appears in `!dubzconfig` with every group and control.
3. Changing a setting changes behaviour immediately, without a restart (except settings documented as restart-only).
4. Switching the module off stops its gameplay without errors; switching it on restores it.
5. Use the feature as a player: spawn, use, damage, remove, leave the server mid-use.
6. Both consoles stay free of Lua errors.
7. Restart: the admin's values persist.
8. Remove the framework: the addon still loads on its defaults and nothing errors.

## 9. Reporting a problem

Include the output of `dfw_selftest` and `dfw_selftest_cl`, the step that failed, and any Lua error text from the server or client console, copied exactly.
