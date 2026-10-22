# Configuration Design: The Admin Controls Everything

The framework's value to a server owner is that nothing is hidden in code. If a script uses a number, the admin can change it from `!dubzconfig` without opening a file. This document defines what has to be a setting, how to pick the control, how to describe it, and when a table of rows is better than a list of settings.

## The rule

**Every value that a person could reasonably want to change is a setting. If you hesitate, it is a setting.**

That covers:

- prices, payouts, rewards, costs, fees, refunds;
- durations, intervals, cooldowns, delays, timeouts;
- chances, odds, percentages, multipliers, thresholds;
- counts, limits, capacities, maximums, stack sizes;
- distances, radii, ranges, speeds, sizes, scales, offsets;
- models, materials, sounds, effects, colours, fonts sizes;
- keys, commands, chat prefixes, labels, names, messages;
- feature toggles and sub-feature toggles;
- which jobs, usergroups, weapons or entities something applies to.

The only hard-coded values allowed in logic are mathematical constants, array indices, and engine enumerations.

## How to choose the control

The binder picks the control from the value's type in the config table. You influence it with spec keys.

| Config value | Spec | Control |
| --- | --- | --- |
| `true` / `false` | `{path = "Sound", label = "Sound"}` | Switch |
| Number with `min` and `max` | `{path = "Price", min = 0, max = 100000, decimals = 0}` | Slider with typed entry |
| Number without both limits | `{path = "Price"}` | Text field. Avoid: always give limits |
| String | `{path = "Name", maxLength = 40}` | Text field |
| `Color(...)` | `{path = "ScreenColor"}` | Colour picker |
| One of fixed strings | `{path = "Side", choices = {"left", "right"}}` | Drop-down |
| A key code (`KEY_F6`) | `{path = "OpenKey", keybind = true}` | Drop-down of key names |
| `{"a", "b"}` | `{path = "Commands", list = true}` | Text box: `a, b` |
| `{a = true, b = true}` | `{path = "Groups", set = true}` | Text box: `a, b` |
| `{a = 5, b = 7}` | `{path = "Yields", map = true}` | Text box: `a=5, b=7` |
| `{a = "Eat"}` | `{path = "Verbs", mapText = true}` | Text box: `a=Eat` |
| Nested value | `{path = "movement.baseWalk"}` | Same as the leaf type; dotted paths and numeric parts work (`dayColors.1`) |

Notes:

- A number whose default has a fractional part gets `decimals = 2` automatically; set `decimals` yourself whenever it matters (`decimals = 3` for a 0.025 scale, `decimals = 0` for whole numbers, `decimals = 1` for tenths).
- Whole-number defaults with `decimals` omitted are not rounded; set `decimals = 0` to force integers.
- Lists, sets and maps are one text box each. A list holds 200 characters, a map or text map 240, and a set 240 unless `maxLength` raises it; a plain string holds 200 unless `maxLength` says otherwise. Entries beyond the limit are lost. If it needs more than a handful of entries, make it a collection.
- Choices are strings. The default must be one of them.
- Keybind values must be one of the names the binder offers (`DFW.Bind.GetKeyNames()`).

## Spec keys

| Key | Required | Meaning |
| --- | --- | --- |
| `path` | yes | Where the value lives in the config table (`"Price"`, `"movement.baseWalk"`) |
| `label` | recommended | Name in the menu. Title Case, units in brackets: `"Cycle Time (Seconds)"` |
| `description` | recommended | One sentence under the label. Explain effects, not the label again |
| `group` | recommended | Section heading. Related settings share a group |
| `order` | no | Sort order inside the page; defaults to the order of the spec list |
| `min`, `max`, `decimals` | for numbers | Range and rounding |
| `maxLength` | for strings | Character limit (default 200) |
| `choices` | for choices | List of strings |
| `keybind`, `list`, `set`, `map`, `mapText` | for those kinds | See the table above |
| `public` | no | Default `true`: the value is sent to every client. Set `false` for server-only values |
| `key` | no | Override the generated storage key (default is snake_case of the path) |

## Naming, labels and groups

- **Label:** what the admin sees. Sentence-like Title Case. Put units in brackets: `Seconds`, `Units`, `%`, `Per Second`. Say which direction an odds value goes: `"Overheating Odds (1 in N)"`.
- **Description:** only when the label cannot say it. Mention side effects and restart requirements: "Applies to printers spawned after the change." or "Changes need a restart to reach the shop menu."
- **Groups:** 3 to 8 per module, ordered by how an admin thinks about the feature: Shop, then the core loop, then risks, then looks, then sound. Do not put every setting in "General".
- **Paths:** keys mirror what they are: `PrintAmount`, `InkPerPrint`, `ShutdownHeat`. Avoid abbreviations that are not obvious.
- **Order within a group:** the order of the specs. Put the most important value first.

## Ranges

A range is a safety rail and a hint. Pick ones that allow a wide but sane set of server types.

| Kind | Typical limits |
| --- | --- |
| Money | 0 to 1,000,000 (or 100,000 for per-action amounts) |
| Seconds for a cycle | 1 to 3600 |
| Seconds for an action | 0.1 to 60 |
| Percent | 0 to 100 |
| Chance as 1 in N | 2 to 100000 |
| Count or limit | 1 to 100 |
| Distance in units | 10 to 5000 |
| Multiplier | 0.1 to 10 |
| 3D2D scale | 0.02 to 0.5 with `decimals = 3` |
| Offsets | -100 to 100 with `decimals = 1` |

Never leave a numeric setting without both limits.

## Player-facing text

Every message, label and status name a player reads is a setting, grouped in one `Text` table with `{placeholders}`, so an admin can reword or translate it without touching code.

```lua
Text = {
    Collected = "Collected {amount}.",
    Exploded = "Your {name} exploded.",
    StatePrinting = "Printing"
}
```

```lua
function Namespace.Phrase(key, values)
    local text = Namespace.Config.Text[key] or key

    for name, value in pairs(values or {}) do
        text = string.Replace(text, "{" .. name .. "}", tostring(value))
    end

    return text
end
```

Bind the whole table with a loop so no phrase is forgotten:

```lua
for key in SortedPairs(config.Text) do
    specs[#specs + 1] = {path = "Text." .. key, label = "Text: " .. key, group = "Text", maxLength = 120}
end
```

Code never contains a literal message: it calls `Phrase("Collected", {amount = shown})`.

## Defaults that work together

Settings interact. Before you finish, check that the shipped defaults let every state and every outcome actually happen.

- **Order thresholds.** If a machine shuts down at 80 and explodes at 95, it can never explode, because it stops first. Put the danger threshold below the shutdown threshold, and say so in the description.
- **Simulate the loop.** Walk one cycle by hand: what changes per cycle (income, wear, heat, ink), what changes per second (cooling, decay), and when each state is first reached. A resource that can only fall, or only rise, is a bug.
- **Make the failure reachable but avoidable.** With no attention the machine should end up in trouble in a reasonable time (tens of minutes), and with a little care it should not.
- **Check the ends of every range.** The minimum and maximum of each slider should not produce a broken state (a zero interval, a threshold above 100).
- **State the relationship** in the description of the setting a thought is most likely to break.

## Dial-in settings

Anything spatial or visual cannot be guessed: the position of a 3D2D screen on a model, the angle of a held tool, the offset of a marker, the size of a glow, the timing of a swing, the level of a sound. Make each one a setting so the admin tunes it live while looking at the result, and the developer never re-edits code for a nudge.

```lua
Config = {
    ScreenUp = 11.5,
    ScreenForward = 0,
    ScreenSide = 0,
    ScreenPitch = 0,
    ScreenYaw = 90,
    ScreenRoll = 0,
    ScreenScale = 0.08
}
```

```lua
{path = "ScreenUp", label = "Screen: Up", min = -100, max = 100, decimals = 1, group = "Dial In: Screen",
    description = "Moves the screen up from the model's origin."},
{path = "ScreenScale", label = "Screen: Size", min = 0.02, max = 0.5, decimals = 3, group = "Dial In: Screen"}
```

Rules:

- One group per part, named `Dial In: <Part>`.
- Offsets: range -100 to 100, `decimals = 1`. Angles: -180 to 180, `decimals = 0`. Scales: `decimals = 3`.
- State the coordinate space in a description once per group ("moves are in the machine's own space: forward, left, up").
- Apply while the thing is visible, with no restart, by reading the values every frame or tick. For things placed once from the setting (an attached module, a parented prop), re-apply to every live instance when the setting changes, debounced (see below).
- Pair the group with a values command that prints the current numbers, so the final values can be copied back into the defaults.
- Defaults are best guesses; the dial-in group exists so the first adjustment is the user's, not yours.

## Reading settings

- Keep `local config = Namespace.Config` at the top of a file; the table is updated in place so the reference never goes stale.
- Read the field where it is used: `config.PrintAmount`.
- Do not copy a field into a local that lives longer than one function call.
- For values that feed a timer, a looping sound or a registered object, handle the change in `OnChange`, or recompute from config on each cycle so the new value applies on the next one.
- Values read when the gamemode loads its items (price, max, model, category) apply at load; say so in the description.

## When a table beats a list of settings

Use a collection when the data is **a list of things that each have several properties and the admin will add, remove or reorder entries**:

| Use a collection for | Typical columns |
| --- | --- |
| Shop stock | `id`, `name`, `class`, `price`, `stock`, `enabled` |
| Loot or drop tables | `id`, `name`, `chance`, `min`, `max`, `enabled` |
| Recipes | `id`, `result`, `ingredients` (text), `time`, `skill` |
| Ranks, titles, tiers | `id`, `name`, `price`, `multiplier`, `color` |
| Status levels | `from`, `label`, `colour` |
| Tasks and jobs | `id`, `name`, `payout`, `weight`, `enabled` |
| Spawn lists, whitelists | `class` with `suggest = "entities"` and `picker = {...}` |
| Per-job overrides | `job` with `suggest = "jobs"`, value columns |

Use plain settings for single values and for small fixed groupings.

### Declaring a collection

```lua
collections = {
    {
        id = "tiers",
        label = "Printer Tiers",
        description = "Each row is a printer tier. Weight is how likely it is to be offered; multiplier scales income.",
        idKey = "id",
        columns = {
            {key = "id", label = "ID", type = "string", width = 1, maxLength = 30},
            {key = "name", label = "Name", type = "string", width = 2, maxLength = 40},
            {key = "price", label = "Price", type = "number", min = 0, max = 1000000, decimals = 0, width = 1},
            {key = "multiplier", label = "Income x", type = "number", min = 0.1, max = 10, decimals = 2, width = 1},
            {key = "tint", label = "Tint", type = "color", width = 1},
            {key = "enabled", label = "On", type = "bool", width = 0.6}
        },
        default = AcmePrinters.DefaultTiers
    }
}
```

Rules:

- `id` is lowercase snake_case, unique inside the module.
- `idKey` makes one column unique and non-empty; use it whenever other code looks rows up by id.
- Column types: `string`, `number`, `bool`, `color`, `choice` (with `choices = {...}`).
- `width` is relative: the editor divides the row by the widths.
- `default` is a list of rows whose keys match the columns. Rows missing a column get that column's default. Invalid defaults make registration fail.
- A collection holds at most 600 rows by default (`maxRows` lowers or raises the limit per collection).
- Colour column values are `{r, g, b, a}` tables; convert with `DFW.Collections.ToColor`.
- Collections are replicated to clients by default; set `public = false` to keep one on the server.

### Editor niceties

```lua
{
    id = "ranks", label = "Ranks",
    preview = {kind = "chip", text = "name", color = "color"},
    picker = {column = "class", provider = "entities"},
    columns = {
        {key = "class", label = "Class", type = "string", suggest = "entities"},
        {key = "job", label = "Job", type = "string", suggest = "jobs"},
        {key = "group", label = "Group", type = "string", suggest = "usergroups"}
    },
    default = {}
}
```

- `preview = {kind = "chip", text = <column>, color = <column>}` shows each row as it will look in game; `{kind = "model", model = <column>}` shows a model.
- `column.suggest` autocompletes from `"weapons"`, `"entities"`, `"usergroups"`, `"jobs"`, a registered provider name (`DFW.Collections.Suggest[name]`), or a function that returns a list.
- `picker = {column, provider}` adds a Browse button for lists of entity or weapon classes (providers: `"entities"`, `"weapons"`).

### Reading a collection

```lua
DFW.Collections.Watch("printers", "tiers", function(rows)
    AcmePrinters.BuildTiers(rows)
end)
```

- Build a lookup from the rows in the Watch callback; do not walk the rows every time you need one.
- `DFW.Collections.Get(moduleId, collId)` returns the live rows for a direct read; `DFW.Collections.Find(moduleId, collId, key, value)` returns the first row where a column matches.
- Never edit the returned rows. Use `DFW.Collections.Set` (server) only for programmatic changes.
- Helpers convert between collections and the plain tables addons already use: `RowsFromMap`, `MapFromRows`, `RowsFromList`, `ListFromRows`, `RowsFromSet`, `SetFromRows`.
- Provide default rows in `sh_config.lua` (shared), so the addon works with no admin edits.

### A collection beside plain settings

A module commonly has both: a handful of settings for the mechanic and one or two collections for the content. A crafting module is a typical case: numbers for time and yield, plus two collections, one for materials (model, scale, colour, value) and one for recipes (ingredients, result, time). Each collection appears as an "Edit" card on the module's page.

## Reacting to changes

Pass `OnChange` in the bind options to handle a change that live reads cannot:

```lua
{
    OnChange = function(path, value)
        if not SERVER then return end

        if path == "Sound" then AcmePrinters.RefreshSounds() end
    end
}
```

- It runs on the server and on clients, whenever a bound value is applied.
- Compare `path` against the specs' paths; ignore everything else.
- Keep it short. Anything bigger is a named function in the addon.

## Applying a change to things that already exist

Reading a setting where it is used covers anything that reads every frame or tick. It does not cover things that were placed once from the setting: an attached module, a parented prop, a spawned marker. Their position was set when they were created, so changing the setting does nothing to them.

For these, keep a list of the live instances, give them one function that places them from the current settings, and call it when a placement setting changes.

```lua
function ENT:LayoutCoolers()
    local valid = {}

    for _, module in ipairs(self.Modules) do
        if IsValid(module) then
            module:SetLocalPos(Vector(config.CoolerOffsetX, config.CoolerOffsetY + #valid * config.CoolerSpacing, config.CoolerOffsetZ))
            valid[#valid + 1] = module
        end
    end

    self.Modules = valid
end
```

Call it when the module is installed, and from the bind options when a placement setting changes, debounced so a burst of edits (a reset, a typed value, several sliders) re-applies once:

```lua
local TIMER_NAME = "AcmePrinters_Layout"

function AcmePrinters.QueueLayout()
    timer.Create(TIMER_NAME, 0.4, 1, function()
        for _, printer in ipairs(ents.FindByClass("acme_money_printer")) do printer:LayoutCoolers() end
    end)
end
```

```lua
{
    OnChange = function(path)
        if SERVER and AcmePrinters.QueueLayout and string.StartWith(path, "Cooler") then AcmePrinters.QueueLayout() end
    end
}
```

- The menu sends a slider's value when it is released, not on every step, and `timer.Create` with the same name restarts the wait, so this never spams.
- Filter on the setting names that matter (a shared prefix such as `Cooler` keeps the test short), and test that the function exists: the framework calls `OnChange` for every setting while the module registers, before server files have loaded.
- The re-apply function drops invalid instances, so it also repairs counts.
- Anything drawn on the client is already live: the client reads the setting every frame.

## Reading settings in other realms

- The server always has every value.
- A client has the values of public settings (the default) after it joins; they update live. Use `public = false` for anything that must not reach players, such as secrets, internal tuning, and anything that would reveal hidden mechanics.
- Collections follow the same rule through `public`.

## Anti-patterns

- A magic number in a function body. Make it a setting.
- A label that repeats the path (`"PrintAmount"`). Write `"Money Per Print"`.
- A list of eight settings in "General". Group them.
- A numeric setting with no range.
- A comma-separated setting with twenty entries. Make it a collection.
- Caching `config.Price` in a local at file scope.
- Reading a setting on the client that is `public = false`.
- A colour hard-coded in a draw function when a theme token or a colour setting would do.
- Settings that nothing reads. Every spec must change something observable.
