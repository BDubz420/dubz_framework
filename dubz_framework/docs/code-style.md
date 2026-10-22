# Code Style

The framework's code is formatted one way. Every module written for it matches. Consistent code is what separates a collection of scripts from a platform.

## The comments convention

The framework's convention, and the default for every module you write, is that **code files contain no comments.** If the project you are working in has conventions of its own (the workspace shows them, or the owner states them), follow the project. Otherwise: no comments.

None means none: no header blocks, no section banners, no explanations, no `TODO`, no commented-out code, no license boilerplate (the repository's `LICENSE` covers that).

The convention is deliberate. Explanations rot; names do not. Make the code explain itself:

- Name functions for what they do: `AcceptInk`, `RollCritical`, `BuildHeatBands`.
- Name booleans as questions: `IsPrinting`, `Overheated`, `CanAfford`.
- Name constants for their meaning: `THINK_INTERVAL`, `LOOP_SOUND`.
- Split a function until each part has a name that says what it is.
- Put the reasoning, the "why", in the documentation next to the addon, or in the final report to the user.

If you feel a comment is needed, the code is not finished. Rename, extract or restructure until the comment is redundant, then do not write it.

String literals that happen to contain `--` or `//` are fine; they are not comments.

## Formatting

- **Indentation:** 4 spaces. No tabs. (If the project's existing files use another style, match the project.)
- **Line length:** keep to about 120 characters. Wrap long calls and tables one item per line.
- **Trailing whitespace:** none. One newline at the end of every file.
- **Blank lines:** one between functions and between logical blocks; never two in a row; none at the start or end of a block.
- **Strings:** double quotes. Single quotes only when the text contains a double quote.
- **Tables:** `{key = value}` with spaces inside the braces for one-liners; multi-line tables with one entry per line and no trailing comma on the last entry.
- **Operators:** spaces around `=`, `==`, `~=`, `..`, `+`, `-`, `*`, `/`. No spaces inside call parentheses.
- **Use standard Lua operators:** `~=` not `!=`, `and`/`or`/`not` not `&&`/`||`/`!`, no `continue`, no `//` or `/* */` comments. Use guard clauses instead of `continue`.
- **Parentheses:** only where they add clarity. No semicolons.

```lua
function ENT:Collect(ply)
    local amount = self:GetStored()

    if amount <= 0 then
        notify(ply, "Nothing to collect.", 1)
        return
    end

    ply:addMoney(amount)
    self:SetStored(0)
    notify(ply, "Collected " .. AcmePrinters.FormatMoney(amount) .. ".", 0)
end
```

## Naming

| Thing | Style | Example |
| --- | --- | --- |
| The addon's global table | `<Prefix><Feature>` PascalCase, exactly one per addon | `AcmePrinters` |
| Functions on a table | PascalCase | `AcmePrinters.BuildHeatBands` |
| Entity and weapon methods | PascalCase | `ENT:AcceptInk` |
| Local variables and local functions | camelCase | `local storeMax`, `local function drawBar` |
| Constants | UPPER_SNAKE_CASE | `local THINK_INTERVAL = 0.5` |
| Config keys | PascalCase, flat | `PrintSeconds`, `ShutdownHeat` |
| Enum tables | PascalCase table, PascalCase keys | `AcmePrinters.State.Overheated` |
| Net messages | `<Namespace>_<Purpose>` | `AcmePrinters_Open` |
| Hook and timer ids | `<Namespace>_<Purpose>` | `AcmePrinters_Items` |
| Files | `sh_`, `sv_`, `cl_` + lowercase snake_case, no numbers | `sv_tasks.lua` |
| Identifiers handed to the framework | lowercase snake_case | `heat_bands` |

Never create more than one global per addon. Everything else hangs off it or is `local`.

## Structure

- **One responsibility per file and per function.** A function that needs "and" in its name is two functions.
- **Short functions.** Aim for under 40 lines. Hard stop around 60: extract.
- **Guard clauses.** Handle the invalid or uninteresting case first and return. Keep the main path unindented.
- **Shallow nesting.** More than three levels means extract a function.
- **Early local capture.** `local config = AcmePrinters.Config` at the top of a file is right; `local price = config.Price` at the top of a file is wrong (stale after an admin edit).
- **Order inside a file:** locals and constants, small helpers, the public functions, then the hooks and registrations at the bottom.
- **Everything `local` unless it must be shared.** No accidental globals. Check with a search for assignments that have no `local`.
- **No magic numbers.** A number that is not obviously structural (0, 1, array index, a half) is a setting or a named constant.
- **No dead code.** Delete unused functions, variables and files. Version control remembers.
- **Return early from hooks** when disabled: `if not AcmePrinters.Enabled() then return end`.

## No monoliths

Large files are where AI-written scripts go wrong. Keep every file small and single-purpose.

| Limit | Value |
| --- | --- |
| Lines per file | About 300 as a target; split before 400 |
| Lines per function | About 40; split before 60 |
| Responsibilities per file | One |
| Files per realm per feature | As many as there are responsibilities |

Split a feature by realm first (`sh_`, `sv_`, `cl_`), then by responsibility:

| Responsibility | File |
| --- | --- |
| Settings and shared helpers | `sh_config.lua` |
| Gamemode and optional-system adapters | `sh_adapter.lua`, `sh_<capability>.lua` |
| Framework registration | `sh_framework.lua` |
| A server system (tasks, persistence, rewards) | `sv_<system>.lua` |
| A client system (HUD, windows) | `cl_<system>.lua` |
| An entity | its own `shared.lua`, `init.lua`, `cl_init.lua` |
| A data table | a collection in `sh_framework.lua`, with defaults in `sh_config.lua` |

When a file grows past the limit, name the part that is growing and move it to its own file. Do not create `utils.lua` or `main.lua` catch-alls.

## Types, validation and safety

- Test entities with `IsValid(ent)`, never `ent ~= nil`. Test players with `IsValid(ply) and ply:IsPlayer()`.
- Validate every value that crosses the network on the server: type, range, entity validity, distance, ownership and permission. Clamp numbers with `math.Clamp`.
- Use `tonumber` and `tostring` at boundaries; do not assume types.
- Use `ipairs` for arrays, `pairs` for key-value tables, `SortedPairs` when iteration order must be stable.
- Do not mutate a table you were handed unless that is the function's purpose; copy with `table.Copy`.
- Wrap work that can fail on bad input in `pcall` only at a boundary and report the failure; do not swallow errors silently.

## Hooks, timers and sounds

- Hook ids are unique and prefixed: `hook.Add("PlayerDisconnected", "AcmePrinters_Cleanup", ...)`.
- Timers have unique names when they must be cancelled; `timer.Simple` callbacks check `IsValid` before touching an entity.
- A sound created with `CreateSound` is stopped in `OnRemove` and when its condition ends.
- Per-frame hooks (`Think` on the client, `HUDPaint`, `PostDrawTranslucentRenderables`, `Draw`) do no allocation that can be avoided, no string building that can be cached, and exit early when there is nothing to draw.

## Documentation instead of comments

Put knowledge where it belongs:

| Knowledge | Where |
| --- | --- |
| What a setting does | The spec's `label` and `description` |
| What the addon does | The module definition's `description` and the addon's README |
| Why a design was chosen | The README or the final report |
| How to use an API | `docs/` |
| What is not finished | The final report. Do not leave unfinished code with a note; finish it or leave it out |

## A before and after

Before:

```lua
-- Check if the printer is overheated
function ENT:CheckHeat()
    -- If heat is above 80 then shut down
    if self:GetHeat() > 80 then
        self.Overheated = true -- set flag
    end
end
```

After:

```lua
function ENT:UpdateOverheat()
    if self:GetHeat() >= config.ShutdownHeat then
        self.Overheated = true
    elseif self.Overheated and self:GetHeat() <= config.ResumeHeat then
        self.Overheated = false
    end
end
```

The second version has no comment, no magic number, a name that says what it does, and a hysteresis the first lacked.
