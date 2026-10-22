# Changelog

All notable changes to this project are documented here.

## 0.4.0

### Added
- Custom themes can be registered at any time with `DFW.Themes.Register`. They appear in the Appearance dropdown immediately, and a theme an admin chose before a restart applies as soon as its addon registers it.
- Function-backed choice lists: a choice setting's `choices` may be a function, so lists that grow at runtime (themes, styles registered by other addons) stay current. `DFW.Config.GetChoices(field)` resolves either form.
- `DFW_ThemeRegistered` hook and `DFW.Themes.DefaultId`.
- Developer guide for people and AI coding agents: an operating manual (`AGENTS.md`, at the root) and guides in `docs/`: project profile, prompt-to-spec, module workflow, config design, code style, patterns, themes and styles, UI library, API reference, integrations, quality checklist and testing, with a complete reference module and a starter module.
- A workflow guide (`docs/workflow.md`): sorting a message, orienting, planning in proportion, building in slices, making systems observable, handing off, and handling feedback, with diagnostics and dial-in patterns.
- Guidance on physical, contextual interaction (supplies and add-on modules that act on contact, no key chords), player-facing `Text` settings and checking that defaults work together. The money printer example now uses an ink bottle entity and a coolant module entity (installed for good or used up once, by setting) instead of key presses.
- Drawing helpers: `DFW.Draw.Bar`, `DFW.Draw.World` and `DFW.Draw.Billboard` for world-space overlays and meters that pair their render calls, fade with distance and catch errors.
- `DFW.UI.PreviewTheme(id)` shows a theme on one client only.
- A new UI showcase (`dfw_ui_demo`): three tabs (Overview, Controls, Feedback) and a theme preview, replacing the long list of every control.

### Changed
- The default theme is now `classic`. Servers that saved the previous default id keep working: the old id resolves to `classic`.
- Source files have no numbers in their names and no comments. The load order is an explicit list in `lua/autorun/dubz_framework.lua` instead of file name order.
- Project documentation moved into `docs/`; the old authoring and testing notes are replaced by the new guide.

## 0.3.0

### Core
- Modules start after the gamemode loads (`Initialize`), not during autorun.
- Modules gained `AddHook` and `AddTimer` with automatic cleanup, `OnConfigChanged`, failure isolation with retry, persisted admin enable and disable, and a protected core module. Failed packages are rolled back.
- Config values are validated for NaN and infinity, string length and colour channels; schemas support group, description, step and decimals, `public` (replicated to all clients) and `restart` hints; reset per setting or per module.
- Public settings, such as the theme, reach every client.
- Config saves are debounced and atomic, keep a `.previous` copy, preserve unreadable files as `.corrupt`, recover from the previous copy and flush on shutdown.
- Net traffic is compressed JSON with per-player rate limits and size caps; admin edits go through a paced client queue so rapid changes are never dropped.
- Added `DFW.Registry`, `DFW.Net`, `DFW.Data` and `DFW.Themes`.
- Default access is superadmin, overridable with `DFW_CanAccessConfig`.
- Icons are sent to clients; a missing icon draws nothing.

### UI
- Rebuilt the UI library with the themes `classic`, `slate` and `light`.
- New and rewritten controls: Frame, Button variants, TextEntry, Toggle, Checkbox, Slider, Dropdown, ColorButton, Card, Label, Paragraph, Badge, ProgressBar, NavButton, TabBar and a themed ScrollPanel, plus Confirm, Message and Prompt dialogs and toast notifications.
- The configuration menu is generated from schemas, with search, a Modules page with status and enable switches, per-setting and per-module reset, and live in-place updates.

### Tooling
- Added `dfw_status`, `dfw_selftest`, `dfw_selftest_cl` and `dfw_ui_demo`.

## 0.2.0

- Added explicit external package manifests and API version negotiation.
- Package submission no longer depends on addon autorun order.
- Added package dependency resolution and deterministic realm loading.

## 0.1.0

- Initial framework boot, registries, typed configuration, persistence, networking, icons, VGUI controls and the configuration menu.
