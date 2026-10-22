# The Working Loop

The framework gives you standards and helpers. This document gives you the process: how to go from whatever the user sends, however short, long, messy or mixed, to a finished, verified, handed-off system, and how to keep improving it as the user tests it.

The same loop works for a one-line request, a rambling message with three ideas in it, a screenshot with notes, or a pasted error log.

```
  Intake  ->  Orient  ->  Plan  ->  Build in slices  ->  Verify  ->  Hand off
     ^                                                                  |
     +---------------  Feedback: triage, fix, guard, hand off  <--------+

  Throughout: keep a record (roadmap, decisions, archives)
```

## 1. Intake: sort every statement

A message is rarely one request. Read all of it, including anything that arrives while you are working, and sort each statement into one type. Each type has its own action.

| Type | Sounds like | Action |
| --- | --- | --- |
| **Build** | "I want a ...", "make me a ..." | Specify and build (see the loop below) |
| **Change** | "Make it do X instead", "swap Y for Z" | Read the existing code, change only what was asked |
| **Bug report** | "It errors", a pasted log, "nothing happens" | Reproduce by reading, find the root cause, fix, add a guard |
| **Tuning feedback** | "Too slow", "wrong spot", a screenshot, "this part is great" | Turn it into settings and defaults; keep what was praised |
| **Idea for later** | "Add to the list", "maybe later", "note this" | Record it in the roadmap. Do not build it |
| **Question** | "How does...", "will it...?" | Answer plainly, from what you read |
| **Rule or preference** | "Always...", "I don't like..." | Apply it now and record it where the project keeps its conventions; do not ask again |

Handling a mixed message:

1. Split it into a numbered list, one line per statement, tagged with its type.
2. Do bug fixes first, then changes, then new builds. Ideas go to the roadmap only.
3. Restate the list in your first reply so the user sees what you understood.
4. If something arrives mid-task, fold it in when it is small and queue it when it is not; say which.
5. Never act on something marked "just note it".

Handling a weak prompt:

- **One line:** expand it with [prompt-to-spec.md](prompt-to-spec.md). Do not ask for details a default can supply.
- **Contradictory:** the later statement wins; note the conflict as an assumption.
- **Large and vague:** state your decomposition first (see "Large and compound requests" in the same document).
- **A screenshot or log you cannot fully read:** work from what is legible, say what you could not read, and build in a way that makes the next round of feedback easy (see the diagnostics below).

## 2. Orient before you touch anything

1. **Resolve the project profile** ([project-profile.md](project-profile.md)): prefix, gamemode, theme, style, categories, conventions.
2. **Read neighbours.** Open two or three existing addons in the workspace: the loader, the config table, the binding, one entity or tool. Your work should be indistinguishable from theirs.
3. **Look for an existing helper** before writing one: in the framework (`DFW.*`), in the project's own addons, in the docs.
4. **Look for the feature already built.** A second copy of something that exists is a defect.
5. **Use references for mechanics only.** If the user points at an existing script as a reference, learn what it does and rebuild it in the standard. Do not copy its structure, its numbers or its mess.
6. **Archive before you change an existing addon.** Copy the original to an archive folder the project keeps (create one if none exists), then edit in place. Never leave only one copy of something you are about to alter.
7. **Respect protected locations.** If the project or the user names folders that must not be written to, do not write there.

## 3. Plan in proportion

| Size | Plan |
| --- | --- |
| Small (a setting, a fix, one entity) | A sentence or two in your reply |
| Medium (a feature with a UI and settings) | The specification block from [prompt-to-spec.md](prompt-to-spec.md) |
| Large (several systems) | The decomposition, the build order, and the specification block for the first system |

A plan names: the profile, the systems, the files, the setting groups, the collections, the UI, the adapter, the assumptions, and what you are deliberately leaving out. Then proceed. Stop and ask only for decisions that are irreversible or that no source can answer.

## 4. Build in slices that always load

Build in this order. After every slice the addon must load with no errors.

1. **Skeleton:** the addon folder, the loader with its missing-file check, the config table, the framework binding. The module appears in `!dubzconfig`.
2. **Core loop on the server:** the state machine or engine, reading config live.
3. **Interaction:** use keys, commands, tools, with validation.
4. **UI:** overlays, HUD, windows, from the library and the theme.
5. **Admin tools and persistence:** placement tools, saved data (see [gmod-patterns.md](gmod-patterns.md)).
6. **Polish:** sounds, effects, animation, messages.

Design choices that make later feedback cheap:

- **Data-driven variants.** If a feature has several kinds (several repair jobs, several recipes, several tasks), build one engine that runs steps and make each kind a small definition. Adding a kind is then a small file or a table row.
- **Everything tunable.** Every number is a setting. Anything spatial or visual (offsets, angles, scale, timing, sound level) is a **dial-in setting** (see [config-design.md](config-design.md)) so the user adjusts it in the menu instead of asking you to re-edit code.
- **Everything nameable.** Names, labels, categories and messages are settings with defaults from the profile.
- **Separate what changes together.** One file per responsibility, so a feedback round touches one place.

## 5. Make it observable

A system that fails silently costs a feedback round to discover. Every module ships with ways to see inside it.

- **A check command** that lists the addon's files and whether it loaded, so an incomplete upload is obvious (`<prefix>_<feature>_check`). See [building-modules.md](building-modules.md).
- **A test command** for anything that is normally gated by time, chance or world state, so it can be triggered on demand by a superadmin (`!<prefix>test` style).
- **A values command** that prints the numbers behind anything visual or spatial, so the user can copy dialled-in values back into defaults.
- **No silent failures.** When a search finds nothing, a target is missing, a file is absent or a pcall fails, say so, to the console and, for admins, in chat, with the module name and the reason.

  Wrong: a function that picks a target returns early when the list is empty and the feature never starts.
  Right: the same function reports "no <thing> to work on: place one with the placement tool", and the code that calls it is wrapped so one failing feature cannot stop the others.

- **Guard loops.** A repeating tick or timer wraps its per-item work in `pcall` and reports once per distinct error, so one bad item cannot silence the rest or flood the console.

## 6. Verify what you can

No agent can prove that a game script works without running the game. Verify everything that can be verified, and say precisely what could not be.

Static checks to run (see the commands in [quality-checklist.md](quality-checklist.md)):

- every file parses (a Lua parser or lexer, or at least a search for unbalanced strings and brackets);
- every setting path in the bindings exists in the config table, and every config key is used;
- the load order lists every file and no file is missing;
- no comments, tabs or trailing whitespace if that is the convention;
- documentation links resolve.

Then list the checks that need the game (rendering, sounds, physics, networking between clients) so the user knows exactly what to test.

## 7. Hand off

End every round with a hand-off. Keep it short and concrete.

```
What changed
  - <file>: <what and why>, one line each

Put it on the server
  - Upload these folders: <addon folders>
  - Restart: <yes/no, why>

Try it
  - Run: <commands>
  - Look for: <the expected result of each step>

Settings
  - Open !dubzconfig > <Module> > <Group>: <what the admin can tune here>

Assumptions
  - <one line each>

Not tested
  - <what needs the game>

Next
  - <follow-up ideas, not built>
```

The upload list matters: say which addon folders changed, so the user does not have to guess.

## 8. The feedback loop

The user tests and comes back with an error, a screenshot or a feeling. Treat each as data.

### Triage

| Symptom | First suspects | Fix pattern |
| --- | --- | --- |
| A red error with a file and line | The line itself: a broken string, a nil, a wrong realm | Read that line and its neighbours, fix it, and add a guard so the same class of mistake is loud next time |
| The module or its menu tab is missing | Registration failed: a setting limit (a list or string too long), a duplicate id, a missing file, the loader returned early | Check the console for the framework's warning, run `dfw_status` and the addon's check command; fix the cause |
| A setting changes nothing | The value was cached at load, was applied once when the thing was placed, was read in the wrong realm, or is not public and the client reads it | Read live; mark client-read settings public; for things already placed, re-apply to the live instances on change (debounced) |
| It appears in the wrong place, size or angle | A guessed offset | Add dial-in settings (sliders) and a values command; stop guessing |
| Too slow, too fast, too cheap, too rich | A default | Change the default and confirm it is a setting |
| It works for one player but not others | Realm, `AddCSLuaFile`, a net message without validation, ownership | Check the file lists and the receiver; test with a second client |
| It looks wrong in a theme | A hard-coded colour or font | Use theme tokens and library fonts |
| Nothing happens and there is no error | A silent early return | Add the diagnostic message, then fix the cause |
| A leftover (sound, timer, entity) after it ends | Missing cleanup | Add `OnRemove` and timer checks |

### Rules for a feedback round

1. **Find the cause, not the symptom.** A patched symptom returns.
2. **Add the guard.** After the fix, add what would have made the failure loud or impossible: a check, a message, a pcall, a range on a setting.
3. **Treat each point separately.** Number the user's points and answer each one. "This part is great" is feedback too: leave it alone.
4. **Turn taste into settings.** "Smaller dots", "slower swing", "different spot" become sliders, not hard-coded changes.
5. **Keep scope tight.** Change what the feedback names. Mention, do not make, other improvements you noticed.
6. **Hand off only what changed**, with the same template.
7. **Say plainly when you fixed your own mistake**, what it was, and what now prevents it.

## 9. Keep a record

- **Roadmap.** One file in the workspace (for example `ROADMAP.md` in the project's planning folder) with three lists: Done, Next, Ideas. Everything the user marks "for later" goes here, and nothing marked "for later" gets built.
- **Decisions and rules.** When the user states a preference or makes a design decision, write it where the project keeps its conventions, and apply it from then on without asking again.
- **Follow-up ideas per system.** Two to four extensions (a second tier, another style, another adapter) go into the hand-off and the roadmap's Ideas list.
- **Archives.** Originals of anything you converted or changed, in the project's archive folder.

If the project has none of these files, create the roadmap on first use and mention it in the hand-off.

## 10. Standing practices

These apply to every system, every time.

- Everything the admin could want to tune is a setting; spatial and visual values are dial-in settings.
- Interaction is physical or contextual (contact, use, hold, tools), never key chords; supplies and modules are entities sold in the shop.
- The defaults are simulated by hand so every state can actually be reached.
- World data (spots, spawn points, NPC positions) is placed with an admin tool and saved per map, never hard-coded ([gmod-patterns.md](gmod-patterns.md)).
- Every feature that is gated by time or chance has a test command.
- Every module has a check command.
- Failures are loud and located (module name and reason).
- Entities are owned, cleaned up and removed when their owner leaves, following the project's rules.
- Tools and weapons that the system needs are given by the system (a job's loadout, a shop), and a worker who joined before a tool existed receives it on the next task.
- Pay, rewards and costs are decided on the server and shown through the adapter.
- Optional systems are reached through adapters and degrade gracefully.
- The report teaches: where the settings are, how the look is controlled, how to extend.

## 11. The loop in action

**A one-line request.** "I want a garbage collector job." You resolve the profile, split the request into a job, a task engine, a giver NPC, placement tools and pay, state the decomposition, build the skeleton and the engine first, add the first task as data, add a check command and a test command, run the static checks, and hand off with the upload list and the commands to try. The user plays it and returns with notes.

**Feedback with a screenshot.** "The marker is in the wrong place and the dots are too big, the swing is great." You number the three points. The first becomes dial-in settings plus a values command. The second becomes a size setting with a smaller default. The third you leave alone. You reply point by point and hand off only the changed files.

**A pasted error.** "Nothing shows up and the console says it failed to load line 315." You read that line, find the broken string, fix it, scan the addon for the same mistake, add a guard to the loader so a failing file is named in the console, and say what you found and what now prevents it.
