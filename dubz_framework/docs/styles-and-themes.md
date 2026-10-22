# Styles and Themes

A project's look is chosen by an admin and by the developer, not by this framework. The framework supplies the machinery: a theme system, a library of controls and drawing helpers that read the theme, and patterns for offering several presentation styles (overhead labels, HUD elements, windows) without rewriting anything when the look changes.

## How styling works

- A **theme** is a set of colour tokens plus a radius table and a spacing table.
- Every control (`DFW.Button`, `DFW.Frame`, `DFW.ProgressBar` and the rest) and every drawing helper (`DFW.Draw.Card`, `DFW.Draw.ProgressCard`) reads the active theme at paint time.
- An admin picks the active theme in `!dubzconfig`, in the framework core module under Appearance, and may override the accent colour with a custom one. Everything built from the library restyles immediately, on every client.
- Code that follows the rules in [ui-library.md](ui-library.md) (tokens, library fonts, library helpers) looks right in every theme without changes.

## Built-in presets

| Id | Look |
| --- | --- |
| `classic` | Translucent black cards, white text, gold fills (the default) |
| `slate` | Solid dark blue-grey surfaces, blue accent |
| `light` | Light grey surfaces, dark text, red accent |

Presets are starting points. A project can choose one, register its own, or register a theme with a preset's id to replace it.

## Making a theme

Register it from a shared file that loads with the framework: a file of your addon's package, so it exists on the server and every client.

```lua
local function c(r, g, b, a)
    return Color(r, g, b, a or 255)
end

DFW.Themes.Register("midnight", {
    name = "Midnight",
    colors = {
        background = c(14, 16, 24, 235), surface = c(24, 28, 40, 230), surfaceAlt = c(34, 40, 56, 220),
        raised = c(46, 54, 76), border = c(70, 82, 112), borderSoft = c(44, 52, 74),
        text = c(238, 241, 250), textMuted = c(170, 178, 200), textDim = c(118, 126, 150),
        accent = c(120, 170, 255), accentHover = c(150, 192, 255), onAccent = c(10, 14, 26),
        danger = c(240, 98, 98), success = c(96, 210, 140), warning = c(244, 170, 90),
        info = c(110, 176, 250), gold = c(236, 196, 96),
        shadow = c(0, 0, 0, 80), overlay = c(0, 0, 0, 170),
        track = c(8, 10, 16, 230), outline = c(90, 104, 140), slot = c(10, 12, 20, 160)
    },
    radius = {XS = 2, SM = 4, MD = 6, LG = 8, XL = 12},
    spacing = {XS = 4, SM = 8, MD = 12, LG = 16, XL = 24}
})
```

Rules:

- The id is lowercase snake_case. Registering an existing id replaces that theme.
- Every colour token below is required; a missing one makes registration fail with `missing_color:<token>`. `radius` and `spacing` are optional and default to the classic values.
- It can be registered at any time after the framework has loaded, including after the server has started. The new theme appears in the Appearance dropdown, and if an admin had already chosen it (before a restart, for example) it applies the moment it registers.
- Package it like any module: add the file to the manifest's `files` list, in a `sh_` file.
- Colours are `Color` values. Alpha matters: a theme with opaque surfaces looks flat; one with translucent surfaces lets the game show through.

### The tokens

| Token | Used for | Notes |
| --- | --- | --- |
| `background` | Window and card base | The most visible colour; sets the mood |
| `surface`, `surfaceAlt` | Panels inside windows, input fields | Slightly different from `background` |
| `raised` | Hover and pressed states | Lighter or more opaque than `surface` |
| `border`, `borderSoft` | Outlines and dividers | `borderSoft` is the quieter one |
| `text`, `textMuted`, `textDim` | Primary, secondary, tertiary text | `text` needs strong contrast against `background` |
| `accent`, `accentHover` | Primary buttons, fills, active states | The project's signature colour |
| `onAccent` | Text on top of `accent` | Dark on light accents, light on dark accents |
| `danger`, `success`, `warning`, `info` | State colours | Keep them distinguishable |
| `gold` | Currency and reward highlights | |
| `shadow` | Drop shadows | `Color(0, 0, 0, 0)` for none |
| `overlay` | Dimmer behind modal dialogs | |
| `track` | Bar and slider backgrounds | Darker than `surface` |
| `outline`, `slot` | Slot borders and backgrounds | |

### Designing one from three inputs

Given a background colour, an accent colour and a text colour:

1. Pick the `background` and decide its alpha: 235 for nearly solid, 160 for translucent.
2. Derive `surface` and `surfaceAlt` from the background by shifting lightness a few points in the direction of the text colour.
3. Derive `raised`, `border` and `borderSoft` the same way, with larger shifts.
4. Set `text` to the text colour; make `textMuted` about 70 percent of it and `textDim` about 50 percent.
5. Set `accent` and make `accentHover` a lighter step of it. Choose `onAccent` for contrast with `accent`.
6. Take the four state colours from a palette that reads on your background; keep their hue families (red, green, orange, blue).
7. Make `track` darker than `surface`; `outline` between `border` and `text`.
8. Check text against background for contrast of at least 4.5 to 1.

Radius is the character of the theme: zero to two for hard industrial or terminal looks, four to eight for neutral, ten and above for soft and friendly. Spacing sets how dense windows feel.

### Choosing and previewing

- Switch themes in `!dubzconfig` under the core module's Appearance group. `dfw_ui_demo` opens the showcase, whose Preview theme dropdown shows any registered theme on your screen only (`DFW.UI.PreviewTheme(id)`; pass `nil` to stop).
- A project that ships a theme can also set it as its default by registering it and telling the admin to select it, or by saving the setting through `DFW.Config.Set("dubz_core", "theme", "midnight")` on first run.
- Code that caches colours must rebuild when `DFW_ThemeChanged` fires.

### What themes do not change

- **Fonts.** Every theme uses the framework's font set (Roboto and Consolas). Custom fonts for a module are created with `DFW.UI.CreateFont`.
- **Layout.** Themes change colours, rounding and spacing, not where things go.

## Presentation styles

A theme changes how things are coloured. A **presentation style** changes how a thing is drawn: a plate under an NPC's name versus plain outlined text, a corner card versus a compact bar cluster, a boxed window versus a minimal one. The framework does not ship a catalogue of styles; it lets any module offer them, and makes new ones cheap.

The approach for any element that can look more than one way:

1. Define the element's **context**: the data a style needs to draw, as a plain table.
2. Define each style as a **draw function** that takes the context and draws with tokens and helpers.
3. Keep the styles in a **registry**, so other addons can add more.
4. Let the admin choose the active style with a **choice setting** that lists the registry.
5. Write one function that picks the style and draws.

### A complete overhead label system

`sh_overhead.lua` (shared), a small addon that any other addon calls to draw a label above something:

```lua
AcmeOverhead = AcmeOverhead or {}

AcmeOverhead.Config = {
    Style = "plate",
    Distance = 350,
    Scale = 0.115
}

AcmeOverhead.Styles = DFW.Registry.Create("acme_overhead_styles")

function AcmeOverhead.StyleIds()
    local ids = {}

    for _, style in ipairs(AcmeOverhead.Styles:All()) do ids[#ids + 1] = style.ID end

    return ids
end
```

`cl_overhead.lua` (client): the styles and the draw function.

```lua
local config = AcmeOverhead.Config

AcmeOverhead.Styles:Register("plate", {
    Draw = function(context)
        local theme = context.Theme
        local width = math.max(context.Width, 140) + 28

        DFW.Draw.Card(-width / 2, -42, width, 56, {radius = "SM", color = theme.background})
        DFW.Draw.Text(context.Title, "Heading", 0, -24, theme.text, TEXT_ALIGN_CENTER)
        DFW.Draw.Text(context.Subtitle, "Small", 0, -2, theme.textMuted, TEXT_ALIGN_CENTER)
    end
})

AcmeOverhead.Styles:Register("outline", {
    Draw = function(context)
        local theme = context.Theme
        local shade = Color(0, 0, 0, 255)

        draw.SimpleTextOutlined(context.Title, DFW.UI.Font("Heading"), 0, 0, theme.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, shade)
        draw.SimpleTextOutlined(context.Subtitle, DFW.UI.Font("Small"), 0, 4, theme.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, shade)
    end
})

AcmeOverhead.Styles:Register("badge", {
    Draw = function(context)
        local theme = context.Theme
        local width = math.max(context.Width, 120) + 44

        DFW.Draw.Card(-width / 2, -22, width, 30, {radius = "XL", color = theme.background})
        DFW.Draw.Icon(context.Icon, -width / 2 + 8, -15, 16, theme.accent)
        DFW.Draw.Text(context.Title, "Body", -width / 2 + 30, -7, theme.text)
    end
})

function AcmeOverhead.Draw(position, title, subtitle, icon)
    if not (DFW and DFW.UI) then return end

    local style = AcmeOverhead.Styles:Get(config.Style) or AcmeOverhead.Styles:Get("plate")

    surface.SetFont(DFW.UI.Font("Heading"))

    local context = {
        Theme = DFW.UI.GetTheme(),
        Title = title,
        Subtitle = subtitle or "",
        Icon = icon,
        Width = surface.GetTextSize(title)
    }

    DFW.Draw.Billboard(position, config.Scale, config.Distance, function()
        style.Draw(context)
    end)
end
```

`sh_framework.lua`: the admin chooses the style.

```lua
DFW.Bind.Module({
    id = "overhead",
    name = "Overhead Labels",
    version = "1.0.0",
    icon = "players/badge",
    description = "How labels above NPCs and objects are drawn.",
    dependencies = {"dubz_core"}
}, AcmeOverhead.Config, {
    {path = "Style", label = "Style", group = "Look", choices = AcmeOverhead.StyleIds},
    {path = "Distance", label = "Visible Within (Units)", min = 50, max = 2000, decimals = 0, group = "Look"},
    {path = "Scale", label = "Size", min = 0.03, max = 0.3, decimals = 3, group = "Look"}
})
```

A `choices` value that is a function is evaluated every time the list is needed, so styles registered later by other addons appear in the dropdown and a saved choice survives until its style is registered.

Anyone, including another addon or an AI asked for "a hazard-style overhead", adds a style with one call:

```lua
AcmeOverhead.Styles:Register("hazard", {
    Draw = function(context)
        local theme = context.Theme

        DFW.Draw.Card(-80, -34, 160, 40, {radius = 0, color = theme.background, border = theme.warning})
        DFW.Draw.Text(context.Title, "BodyBold", 0, -14, theme.warning, TEXT_ALIGN_CENTER)
    end
})
```

Other modules call `AcmeOverhead.Draw(position, title, subtitle, icon)` and never draw labels themselves, so one admin setting restyles every label on the server.

### Applying the pattern

| Element | Context | Style examples |
| --- | --- | --- |
| Overhead label | position, title, subtitle, icon, optional fraction | plate, outline, badge, bar plate, dot |
| HUD element (health, money, ammo) | value, maximum, label, icon | card, bar, ring, minimal text |
| HUD layout | list of elements with anchors | corner stack, top bar, bottom bar |
| Notification | text, kind, duration | toast, banner, chat line |
| Window | title, icon, content builder | framed, compact, borderless |
| Progress indicator | label, fraction | card with bar, ring, thin line |

For each, build the registry once, ship one or two styles of your own, and let anyone add others.

### HUD elements

A HUD module follows the same shape: an element registry (`Paint(context, x, y, width, height)` per element), a layout setting (anchor, offset, scale), per-element switches, and one `HUDPaint` hook that loops the enabled elements.

```lua
hook.Add("HUDPaint", "AcmeHud_Paint", function()
    if not (DFW and DFW.UI) or not AcmeHud.Enabled() then return end

    local theme = DFW.UI.GetTheme()
    local x, y = AcmeHud.Anchor()

    for _, element in ipairs(AcmeHud.Elements:All()) do
        if AcmeHud.Config.Elements[element.ID] then
            y = y + element.Paint(AcmeHud.Context(element), theme, x, y) + DFW.UI.Space("SM")
        end
    end
end)
```

Each element's `Paint` returns the height it used. Which elements show, where the stack sits and how large it is are settings, and the colours come from the theme, so a project gets a new HUD by registering elements, not by rewriting the framework.

## Reading vague style requests

People describe looks with adjectives. Translate each into choices of theme, radius, drawing primitives and the style variant, then record the translation as an assumption.

| Request | Theme and tokens | Drawing |
| --- | --- | --- |
| "clean", "minimal" | Low-contrast surfaces, accent used sparingly | No card; outlined text; thin bars |
| "gritty", "industrial" | Dark desaturated palette, warm accent, radius 0 to 2, borders on | Hard cards with a border; stencil-like short labels |
| "futuristic", "sci-fi" | Dark background, cool accent, radius 2 to 4 | Thin outlined cards, segmented bars |
| "friendly", "casual" | Lighter palette, radius 10 and up | Rounded pills and badges |
| "luxury", "premium" | Very dark background, a gold or champagne accent, quiet text | Wide spacing, small caps labels |
| "retro" | High-contrast palette, square corners | Chunky bars, monospace text (`Mono` font) |
| "looks professional" | The framework default or a neutral theme | Library cards and bars, consistent spacing |
| "like X" | Read X in the workspace; reproduce its tokens as a theme | Reuse X's drawing approach through a style |

If the request names a style the project has no theme for, create a theme (see above) and a style variant; do not hard-code colours into the module.

## Rules

1. Colours come from tokens. Sizes come from `DFW.UI.Scale`, radius and spacing from the theme.
2. A module that offers presentation variants stores them in a registry and selects with a setting; it does not hard-code one look.
3. The default style is whichever is neutral; the project's profile may choose another.
4. Styles do not change behaviour. They draw a context; they do not decide anything.
5. Rebuild cached colours and measurements when `DFW_ThemeChanged` fires.
6. Test every style under at least two themes, one dark and one light.
7. Styles skip drawing when out of range or invisible, and reset every global render state they change (`surface.SetAlphaMultiplier`, `cam` stacks).
