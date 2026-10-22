# UI Library Reference

Everything drawn by a module comes from here. The library is client-side (`DFW.UI`, `DFW.Draw`, `DFW.Icons`, `DFW.Anim`, and the `DFW.*` panels). Changing the theme in the admin menu restyles every control and overlay built from it.

The look comes from the active theme. The default preset draws plain translucent cards with white text and gold fills; other themes look different. Code that follows these rules works in every theme. To choose or create a theme, and to offer several presentation styles for one element, see [styles-and-themes.md](styles-and-themes.md).

See it live: the `dfw_ui_demo` console command opens the showcase, with a Preview theme dropdown to try any theme on your screen.

## Rules

1. Use a library control when one exists. Do not subclass `DButton` or `DFrame` for something a `DFW` control already does.
2. Take every colour from the theme (`DFW.UI.GetTheme()` or `DFW.UI.Color(token)`). A hard-coded `Color` is allowed only for a user-facing colour setting or a pure white/black outline.
3. Take every font from `DFW.UI.Font(key)` or `DFW.UI.CreateFont`. Do not create ad hoc fonts in draw code.
4. Take every icon from the catalogue below. A missing icon draws nothing; it never shows the error texture.
5. Draw windows, 3D2D overlays and HUD elements with the same primitives (`DFW.Draw.Card`, `DFW.Draw.Text`, theme tokens) so they match.
6. Windows never decide anything; they request actions from the server.
7. Guard overlays with `if not (DFW and DFW.UI) then return end` so the addon runs when the framework is absent.

## Theme

`DFW.UI.GetTheme()` returns a table of colours plus `radius` and `spacing`. Colour tokens:

| Token | Use |
| --- | --- |
| `background` | Window and card base (translucent black in the default theme) |
| `surface`, `surfaceAlt` | Inner panels, input backgrounds |
| `raised` | Hover and raised states |
| `border`, `borderSoft` | Outlines |
| `text`, `textMuted`, `textDim` | Primary, secondary, tertiary text |
| `accent`, `accentHover`, `onAccent` | Primary actions and fills; text on accent |
| `danger`, `success`, `warning`, `info`, `gold` | State colours |
| `shadow`, `overlay` | Shadow and modal backdrop |
| `track` | Bar and slider backgrounds |
| `outline`, `slot` | Slot borders and backgrounds |

`theme.radius` has keys `XS, SM, MD, LG, XL` (4, 6, 10, 14, 18). `theme.spacing` has `XS, SM, MD, LG, XL` (4, 8, 12, 16, 24).

Built-in themes: `classic` (default), `slate`, `light`. A project can register more; the admin chooses one and may override the accent colour.

Functions:

| Function | Returns |
| --- | --- |
| `DFW.UI.GetTheme()` | The active theme table (cached; rebuilt on config change) |
| `DFW.UI.Color(key, fallback)` | One token colour |
| `DFW.UI.Radius(key)` | A radius by key (`"SM"`) or the number you pass |
| `DFW.UI.Space(key)` | A spacing value |
| `DFW.UI.WithAlpha(color, alpha)` | A copy of the colour with a new alpha |
| `DFW.UI.RegisterTheme(id, data)` | Adds a theme; `data = {name, colors = {all required tokens}, radius?, spacing?}` |
| `DFW.UI.PreviewTheme(id)` | Shows a theme on this client only; `nil` returns to the chosen theme |
| `DFW.UI.Scale(value)` | A pixel size scaled to the screen height (0.75 to 1.3 of 1080p) |

Hooks: `DFW_ThemeReady(theme)`, `DFW_ThemeRegistered(id)`, `DFW_ThemeChanged()` (rebuild anything cached from theme colours when it fires).

## Fonts

| Key | Use |
| --- | --- |
| `Title` | Window titles, big headings (24) |
| `Heading` | Section headings (19) |
| `Body` | Normal text (16) |
| `BodyBold` | Emphasis (16 bold) |
| `Small` | Secondary text (13) |
| `Tiny` | Labels and badges (11) |
| `Button` | Button text (14 bold) |
| `Mono` | Numbers and code (Consolas 14) |

- `DFW.UI.Font(key)` returns the font name for a key (or the string you pass).
- `DFW.UI.CreateFont(name, size, weight, family)` creates and caches a font and returns its name. Use it for 3D2D screens that need larger, sharper text.
- `DFW.UI.TextSize(text, fontKey)` returns width and height.
- `DFW.UI.WrapText(text, fontKey, maxWidth)` returns a list of lines.

## Icons

Icons are white PNGs at `materials/dubz_framework/icons/<category>/<name>.png`. Pass the key without the extension.

Use them with `button:SetIcon(key)`, `frame:SetIcon(key)`, `DFW.Draw.Icon(key, x, y, size, color)`, `DFW.Draw.IconChip(key, x, y, size)`, or `DFW.Icons.Draw(key, x, y, w, h, color)`. In module definitions, `icon = "economy/payments"`.

| Category | Keys |
| --- | --- |
| `actions` | `add`, `arrow_drop_down`, `arrow_drop_up`, `back`, `cancel`, `check`, `delete`, `download`, `edit_square`, `muted`, `refresh`, `save`, `unmuted`, `upload` |
| `admin` | `bug_report`, `freeze`, `gavel`, `kick`, `security`, `shield`, `verified`, `warning` |
| `communication` | `chat`, `chat_bubble`, `forum`, `link`, `mail`, `mark_unread_chat_alt`, `no_connection`, `notifications`, `notifications_active`, `notifications_off` |
| `darkrp` | `account_circle`, `agenda`, `apartment`, `badge`, `health_cross`, `local_police`, `medical_information`, `rocket_launch`, `sports_esports`, `wallet`, `work` |
| `economy` | `attach_money`, `currency_exchange`, `diamond`, `house`, `inventory_2`, `leaderboard`, `payments`, `sell`, `shopping_bag`, `shopping_cart_checkout`, `storefront` |
| `misc` | `bolt`, `directions_run`, `door`, `groups`, `handyman`, `health_cross`, `label`, `map`, `signal_cellular_0` to `signal_cellular_4`, `spo2`, `water_drop` |
| `navigation` | `close`, `close_small`, `menu`, `more_horiz`, `search`, `settings`, `unfold_more` |
| `players` | `badge`, `face`, `groups`, `id_card`, `person`, `skull`, `smile`, `support_agent`, `workspace` |

The complete list is in [icon-catalog.md](icon-catalog.md). Always write keys as `category/name`, for example `economy/storefront`. Pick the closest existing icon; do not invent keys. Functions: `DFW.Icons.Path(key)`, `DFW.Icons.Get(key)`, `DFW.Icons.Exists(key)`, `DFW.Icons.Draw(key, x, y, w, h, color)`.

## Windows

```lua
local frame = DFW.UI.CreateFrame(title, width, height, iconKey, options)
local content = frame:GetContent()
```

- `options.compact = true` gives the slim classic header (title only, no icon or subtitle). Use it for in-game menus.
- `options.module = "<module id>"` ties hover sounds to the module's own setting. Add `ui = true` to the bind options so the module has that setting.
- Size is clamped to the screen. The window is centred, popup-modal and draggable by its header.

Frame methods: `SetTitle(text)`, `SetSubtitle(text)`, `SetIcon(key)`, `SetCompact(bool)`, `GetContent()`, `Close()`. Override `frame.OnClose = function() return false end` to refuse closing. Escape closes it by default (`frame.CloseOnEscape = false` to disable).

Keep one window per feature: store the frame in a local, and remove it before creating another.

## Controls

All controls are created with `vgui.Create("DFW.<Name>", parent)` and docked like normal panels.

| Control | Purpose | Methods and callbacks |
| --- | --- | --- |
| `DFW.Button` | A button with variants | `SetLabel(text)`, `GetLabel()`, `SetIcon(key)`, `SetVariant("default" \| "primary" \| "danger" \| "ghost")`, `SetPrimary(bool)`, `SetDanger(bool)`, `SetAccent(color)`, `SetActive(bool)`, `SetTextAlign(align)`, `SizeToLabel(padding)`; override `DoClick` |
| `DFW.TextEntry` | Single-line input | `SetPlaceholder(text)`, plus `GetValue`, `SetText`, `OnEnter`, `OnChange` from `DTextEntry` |
| `DFW.Toggle` | Switch | `SetChecked(value, quiet)`, `GetChecked()`, `SetLabel(text)`; override `OnChange(value)` |
| `DFW.Checkbox` | Checkbox | Same as `DFW.Toggle` |
| `DFW.Slider` | Number slider with click-to-type | `SetRange(min, max)`, `SetDecimals(n)`, `SetValue(value, quiet)`, `GetValue()`; override `OnValueChanged()` (while dragging) and `OnValueCommitted()` (on release; use this for anything sent to the server) |
| `DFW.Dropdown` | Choice list with search for long lists | `AddChoice(label, data, selected)`, `Clear()`, `Choose(index)`, `SelectByData(data, quiet)`, `GetSelected()` returns label, data; `SetPlaceholder(text)`; override `OnSelect(index, label, data)` |
| `DFW.ColorButton` | Swatch that opens a colour picker | `SetColor(color)`, `GetColor()`, `SetAlphaBar(bool)`; override `OnValueChanged(color)` |
| `DFW.ScrollPanel` | Scrolling container with a thin bar | As `DScrollPanel` |
| `DFW.Card` | Plain rounded surface | `SetCardColor(color)`, `SetShadow(bool)` |
| `DFW.Label` | One line of text | `SetText(text)`, `GetText()`, `SetStyle(style)`, `SetColor(color)`, `SetAlign(align)`, `SizeToContents()`. Styles: `title`, `heading`, `body`, `bodybold`, `muted`, `small`, `tiny` |
| `DFW.Paragraph` | Wrapped text that sets its own height | `SetText(text)`, `SetStyle(style)`, `SetColor(color)` |
| `DFW.Badge` | Small status pill | `SetText(text)`, `SetKind("accent" \| "success" \| "danger" \| "warning" \| "info" \| "muted")`, `SizeToContents()` |
| `DFW.ProgressBar` | Fraction bar | `SetFraction(0..1)`, `SetLabel(text)`, `SetBarColor(color)` |
| `DFW.NavButton` | Sidebar row with icon | `SetLabel`, `SetIcon`, `SetActive`, `SetBadge(text)` |
| `DFW.TabBar` | Horizontal tabs | `AddTab(id, label, icon)`, `SetActive(id, quiet)`, `GetActive()`; override `OnTabChanged(id)` |
| `DFW.XPBar` | Level caption over a bar | `SetLevel(n)`, `SetFraction(0..1)`, `SetTooltipFunc(fn)`, `GetWantedHeight()` |
| `DFW.SkillBox` | Skill name with level blocks | `SetSkill(name, maxLevel, levelFn, progressFn, tooltipFn)` |
| `DFW.SectionHeader` | Heading with a divider | `SetText(text)` |
| `DFW.ItemSlot` | Item cell with drag and drop | `SetSlotIndex(i)`, `SetItem({model, qty}, tooltip)`, `SetDragGroup(name)`, `SetHighlight(bool)`; callbacks `OnDropped(fromIndex)`, `OnClick()`, `OnRightClick()` |
| `DFW.HeaderRow` | Line with left and right text | `SetLeft(textOrFn)`, `SetRight(textOrFn)` |

Layout is standard Derma: `Dock`, `DockMargin`, `SetTall`, `SetWide`, `DockPadding`.

A typical settings-style form:

```lua
local function addRow(parent, labelText, control)
    local row = vgui.Create("DFW.Card", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 6)
    row:SetTall(40)

    local label = vgui.Create("DFW.Label", row)
    label:Dock(LEFT)
    label:DockMargin(12, 0, 0, 0)
    label:SetWide(160)
    label:SetText(labelText)

    control:SetParent(row)
    control:Dock(FILL)
    control:DockMargin(8, 6, 8, 6)
end
```

## Dialogs and toasts

```lua
DFW.UI.Confirm("Remove printer", "Remove this printer?", function() doIt() end, {danger = true, confirmLabel = "Remove"})
DFW.UI.Message("Done", "The printer was removed.")
DFW.UI.Prompt("Rename", "New name:", "Printer", function(value) rename(value) end, {placeholder = "Name"})
DFW.UI.Notify("Saved.", "success", 3.5)
```

- `Confirm(title, message, onConfirm, options)`: options `confirmLabel`, `cancelLabel`, `danger`, `icon`, `onCancel`.
- `Message(title, message, onClose, iconKey)`.
- `Prompt(title, message, default, onSubmit, options)`: options `placeholder`, `confirmLabel`, `icon`.
- `Notify(text, kind, duration)`: kinds `info`, `success`, `warning`, `danger`; at most five toasts show at once.
- `DFW.UI.AttachPopup(popup, owner)` makes a custom popup close when the player clicks elsewhere.

Prefer toasts for transient feedback in windows and the adapter's `Notify` for gameplay messages.

## Drawing helpers

Use these in `Paint`, `HUDPaint`, `cam.Start3D2D` blocks and entity draw code.

| Function | Use |
| --- | --- |
| `DFW.Draw.Text(text, font, x, y, color, alignX, alignY)` | Text with a font key; defaults: left aligned, vertically centred |
| `DFW.Draw.Card(x, y, w, h, {radius, color, border})` | A rounded card; `radius` is a key or a number |
| `DFW.Draw.Outline(x, y, w, h, color, thickness)` | A rectangle outline |
| `DFW.Draw.Icon(key, x, y, size, color)` | An icon |
| `DFW.Draw.IconChip(key, x, y, size)` | An icon centred in a square |
| `DFW.Draw.ProgressCard(centerX, y, width, label, fraction)` | The "Picking up..." card with a bar, for HUD hooks |
| `DFW.Draw.Bar(x, y, w, h, fraction, color)` | A themed bar: track and fill, fraction 0 to 1 |
| `DFW.Draw.World(position, angle, scale, distance, callback)` | A world-space (3D2D) canvas: skips beyond the distance, fades, pairs the `cam` calls, resets alpha, catches errors in the callback |
| `DFW.Draw.Billboard(position, scale, distance, callback)` | The same, turned to face the viewer, for labels |
| `DFW.Anim.Lerp(panel, key, target, speed)` | A smoothed value stored on a panel; the first read snaps to the target |
| `DFW.Anim.Set(panel, key, value)` | Sets a smoothed value directly |
| `DFW.Anim.Color(from, to, fraction)` | A blended colour |

`DFW.Draw.Shadow` is a no-op kept for old callers; do not use it.

## Patterns

### A card with title, value, bar, status

```lua
local function drawCard(theme, width, height)
    DFW.Draw.Card(-width / 2, -height / 2, width, height, {radius = "MD", color = theme.background})
end

local function drawTitle(theme, fonts, y, title, subtitle)
    DFW.Draw.Text(title, fonts.title, -140, y, theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    DFW.Draw.Text(subtitle, fonts.small, 140, y + 6, theme.textMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end
```

### A state colour

```lua
local function stateColor(theme, state)
    if state == AcmePrinters.State.Printing then return theme.success end
    if state == AcmePrinters.State.Overheated then return theme.danger end
    if state == AcmePrinters.State.NoInk then return theme.warning end
    if state == AcmePrinters.State.Full then return theme.accent end
    return theme.textMuted
end
```

### Rebuilding cached colours when the theme changes

```lua
hook.Add("DFW_ThemeChanged", "AcmePrinters_Theme", function()
    AcmePrinters.ThemeCache = nil
end)
```

## Do not

- Do not draw accent strips, gradients, shadows or coloured card backgrounds unless the project's theme or style asks for them; backgrounds come from theme tokens.
- Do not use `Derma_*` helpers, `DFrame` or raw `DButton` for new windows.
- Do not create fonts inside `Paint` or `Draw`.
- Do not hard-code theme colours such as `Color(0, 0, 0, 160)` for a card; use `theme.background`.
- Do not draw when nothing is visible.
- Do not leave a window open after the entity or the player state it depends on is gone.
