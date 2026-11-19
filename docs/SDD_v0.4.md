# Software Design Document (SDD)
## GGG UI Manager (Good Girl Gamer UI Manager)

| | |
|---|---|
| **Version** | 0.4 (draft) |
| **Supersedes** | 0.3 |
| **Audience** | LLM-based coding agents and human reviewers |
| **Platform** | World of Warcraft addon, Lua 5.1, client "WoW Forever" (Interface 16001) |
| **Addon folder** | `GGGUIManager/` |
| **Saved variables** | `GGGUIManagerDB` |
| **Slash commands** | `/ggg`, `/gggui` |
| **Tests** | Plain Lua test runner outside the game, for pure logic (section 9) |

---

# 0. Document control

## 0.1 How this document is used

This SDD is applied **one step at a time** (section 10). After every step the human reviewer loads the addon in the game, tests it, reads the agent's step report (Appendix A), and decides whether the SDD needs to change **before** the next step starts.

- Every requirement has an ID (for example `MOD-03`). Prompts, tests, step reports and change log entries refer to IDs and never to paraphrases.
- The SDD version is bumped on every change. Each prompt states the SDD version it was written against. If the agent finds the SDD ambiguous or contradictory it **stops and asks** (`AGT-03`). It does not guess.
- Words: **shall** is mandatory. **Should** is a default that may be changed with a recorded decision. **May** is optional.
- This version defines the manager and **one** module, Cluster (section 7.1). Only its first piece, the player frame, is planned in detail. Everything else is intentionally left out until that works.

## 0.2 Change log

| Version | Change | Reason |
|---|---|---|
| 0.4 | First module chosen: Cluster, a replacement player and pet layout at the bottom centre of the screen (section 7.1). SCP-04, SCP-20, SCP-24, SCP-25, sections 1.2, 1.4, 3, 7.1, 10, 13, CLU-01..14 | The human chose the first module. Replacing the default frames is back in scope for this module only (D-010, D-011) |
| 0.3 | TrackingList removed as the first module. SCP-04, SCP-06, SCP-24, sections 1.2, 1.4, 3, 7.1, 10 (steps 1 to 3), 13, TRK-01..10 | The game hides minimap tooltip text from addons ("secret" strings), so the module's only data source does not work (D-009). The first module is to be chosen |
| 0.2 | Scope narrowed to the module manager plus one first module, TrackingList (section 7.1). SCP-04..06, SCP-20, SCP-24, section 1.4, STR-03, MOD-05..07, CMD-05, steps 1 to 3, section 13 | The human restarted the product definition with a smaller start (D-006, D-007) |
| 0.1 | First draft: shell, invariants, module contract, saved data model, step plan | Project start. Step 0 delivers the addon shell and this document |

---

# 1. Purpose, scope and non-goals

GGG UI Manager is the main personal addon for managing the game's user interface. It is the home for the interface features the human builds over time. It starts as an empty shell with a module system, so that each feature is added as one self-contained module without touching the others.

The project is built as real software: a written design, numbered requirements, small reviewed steps, recorded decisions and a version history in Git.

## 1.1 Required capabilities

- **SCP-01** An addon shell that loads cleanly on the target client, owns the saved data and registers one slash command (section 8).
- **SCP-02** A module system (section 7) so features are added as separate files with a common contract.
- **SCP-03** Saved data with defaults, a schema version and ordered migrations (section 6).
- **SCP-04** One first module, **Cluster** (section 7.1): a replacement for the default player frame, pet frame, pet bar, party frames and action bars 1 to 4, laid out as one compact group at the bottom centre of the screen. It is built one piece at a time, starting with the player frame.
- **SCP-05** A module may declare which classes it is for. The manager starts it only for those classes (MOD-06). This is the first small step toward class templates.
- **SCP-06** *(Direction, not a requirement yet.)* The manager will later offer a template system: a base template for all classes and class-specific templates on top of it. Hunter is the first class planned.

## 1.2 Project decisions

- One main addon with internal modules. Features do not become separate addons unless a decision says so.
- Personal use first. The addon targets the human's own client and characters, and public release is not a goal yet.
- No external libraries to start with. A library is added only through a recorded decision.
- Modules are files inside this addon for now (D-001). Whether modules can later be separate addons is a later decision.
- A module that listed tracked creatures was tried and dropped, because the client hides the minimap tooltip text from addons (D-009).
- Cluster builds its own frames and hides Blizzard's. It does not move or restyle Blizzard's frames (D-011).
- Cluster is one module with parts, not one module per part (D-011).

## 1.3 Non-goals

- **SCP-20** Overwriting or editing Blizzard's interface code. The addon works with the game's frames through supported calls and hooks. Replacing a default frame means hiding it and building a new one (CLU-04), not editing it. Replacing default pieces other than those listed in section 7.1 is not part of this version.
- **SCP-21** Network access of any kind. WoW addons cannot do it and the addon does not try to work around that.
- **SCP-22** Supporting clients other than the target client until a decision says so.
- **SCP-23** A public release, a packager pipeline and distribution sites. Revisit when the feature set is stable.
- **SCP-24** Listing the objects on the minimap. The game offers no call for it, and the client hides the minimap tooltip text from addons as "secret" strings (D-009).
- **SCP-25** A grid layout, an edit mode, profiles, a settings window, third-party addon wrappers, and replacing default frames other than those in section 7.1. These were discussed and are deliberately left for later versions. Cluster has one fixed layout and is not user-movable in this version.

## 1.4 Open product questions

These are settled by the human.

1. What is "other information" in the player area and the pet area (CLU-06, CLU-07)? Candidates: level, buffs and debuffs, a cast bar, combo or class resources, a portrait. Nothing beyond name, health and power is planned until the human lists it.
2. How are action bars 1 and 2 arranged on the left, and 3 and 4 on the right? Stacked rows of 12 buttons, or side by side as columns? This does not matter until the action bar step.
3. Frame sizes and the total width of the cluster. Step 2 uses defaults that the human adjusts after seeing them (CLU-03).
4. Does the cluster show for every class? It does by default. The pet parts only show while there is a pet (CLU-08).
5. This client hides some values from addons as "secret" values (D-009). Which unit values (health, power, names) can addon code read in and out of combat? Step 2 finds out in the game (CLU-12).
6. Which of the existing personal addons (BagBuddy, FriendBook, HunterKit, others) should eventually fold into this one as modules, if any?
7. Is a licence needed for the repository, and is it public or private?

---

# 2. Invariants

These rules apply to every step and every file. They are stated once here and other sections refer to them by ID. Several come from problems met in earlier personal addons.

- **INV-01** The addon shall never change a protected frame in combat. This includes Show, Hide, SetPoint, SetAttribute and similar calls on protected frames or on frames that have protected children. Work that cannot run in combat is queued and runs on `PLAYER_REGEN_ENABLED`.
- **INV-02** The addon shall not taint Blizzard code. It never replaces or overwrites Blizzard functions or secure scripts, never assigns Blizzard functions as scripts on its own frames, and uses `hooksecurefunc` for observation. Anything that acts on protected actions goes through secure templates.
- **INV-03** The addon creates exactly two kinds of globals: the saved variable `GGGUIManagerDB` and the slash command registrations. Everything else is local or lives in the shared `ns` table. Named frames use the `GGGUIManager` prefix.
- **INV-04** Saved data is read only after `ADDON_LOADED` for this addon. Defaults are merged without overwriting the user's values. Every change to the saved shape bumps `schemaVersion` and adds a migration (section 6).
- **INV-05** No work runs every frame unless it is throttled. Any `OnUpdate` handler accumulates elapsed time and acts at a fixed interval.
- **INV-06** Memory use is bounded. Caches, histories and queues have a size limit.
- **INV-07** A module that fails shall not stop other modules. Every module call is wrapped, and the failure is shown to the user once with the module name and the error text (MOD-04).
- **INV-08** Any game API that may be missing on the target client is checked before use. The addon prints one clear message when a feature is unavailable instead of raising errors.
- **INV-09** No library or external code is added without a recorded decision, and no code is copied from another addon without a recorded decision that includes its licence.
- **INV-10** The addon loads without errors at the end of every step. No step breaks an earlier step's behaviour.
- **INV-11** User-visible text lives in one place per module so it can be reviewed and later localised.

---

# 3. Repository structure and hygiene

```text
<repository root>/                     (ggg-ui-manager)
├── .editorconfig
├── .gitignore
├── README.md                          (what it is, how to install and test)
├── CLAUDE.md                          (instructions for the coding agent)
├── docs/
│   ├── SDD.md                         (this document; owned by the human)
│   ├── PROGRESS.md                    (step status and verification notes)
│   └── DECISIONS.md                   (recorded decisions, D-001 onward)
└── GGGUIManager/                      (the addon; this folder is what the game loads)
    ├── GGGUIManager.toc
    ├── Core.lua                       (shell: saved data, module registry, slash command)
    └── Modules/
        └── Cluster/                   (first module, section 7.1; one file per part, added step by step)
            ├── Cluster.lua            (module registration, container, layout)
            └── PlayerFrame.lua        (added in step 2)
```

The `Cluster/` folder is added in step 2. A `tests/` folder is added at the repository root by the first step that has pure logic (TST-02).

- **STR-01** The addon folder name, the `.toc` file name and the `## SavedVariables` name stay in step: `GGGUIManager`, `GGGUIManager.toc`, `GGGUIManagerDB`.
- **STR-02** The repository root is not the addon folder. The addon is installed by linking or copying `GGGUIManager/` into the game's `Interface\AddOns` folder (README).
- **STR-03** Each module is one file or one folder under `GGGUIManager/Modules/`, listed in the `.toc` after `Core.lua`. Load order in the `.toc` is the only ordering mechanism.
- **STR-04** `## Interface:` is `16001` unless a decision changes the target client.
- **STR-05** `.gitignore` excludes editor files, OS files, scratch output and local test results. It does not exclude `docs/` or any `SDD_v*.md` snapshot.
- **STR-06** Files are UTF-8 with LF line endings in the repository (`.editorconfig`). Lua uses 4 spaces.
- **STR-07** When the human asks for an SDD change, the previous version is saved as `docs/SDD_v<old>.md` first.

---

# 4. Technology defaults

| Concern | Default |
|---|---|
| Language | Lua 5.1 as embedded in the game |
| Client API | Mainline style Blizzard code with Interface 16001. The reference UI source is kept locally at `WoW Addons/wow-ui-source` and is a close but not identical match |
| Namespace | The shared `local addonName, ns = ...` per file |
| Saved data | `GGGUIManagerDB` (account wide), with per-character data under `GGGUIManagerDB.chars` if a decision adds it |
| UI | Blizzard templates and frames. No UI library |
| Time | `GetTime()` for intervals, `time()` for stored timestamps |
| Timers | `C_Timer.After` and `C_Timer.NewTicker` |
| Syntax check | `luaparser` in a Python virtual environment, run by the agent after edits |
| Tests | Plain Lua (section 9) |

---

# 5. Addon lifecycle and composition

- **LIF-01** Load order: the `.toc` lists files. `Core.lua` loads first and defines the namespace helpers. Module files load after it and call `ns:RegisterModule`.
- **LIF-02** On `ADDON_LOADED` for this addon, the saved variable is created if missing, migrated, then merged with defaults, and published as `ns.db`.
- **LIF-03** On `PLAYER_LOGIN`, every registered module is started in registration order: `Init(settings)` first, then `Enable()` if the module's saved `enabled` flag is true.
- **LIF-04** A module's saved settings live at `ns.db.modules[<ModuleName>]`. A missing entry is created with `enabled = true`.
- **LIF-05** Modules communicate through the shared `ns` table and through events they register for themselves. A module never reaches into another module's private locals.
- **LIF-06** Work that must wait for combat to end uses one shared pattern (a queue run on `PLAYER_REGEN_ENABLED`) that is added to `Core.lua` by the first step that needs it (INV-01).

---

# 6. Saved data model

```text
GGGUIManagerDB = {
    schemaVersion = 1,
    modules = {
        ["<ModuleName>"] = { enabled = true, ...module settings },
    },
}
```

- **DAT-01** `schemaVersion` is an integer. Version 1 is the shell's initial shape.
- **DAT-02** Migrations are functions keyed by the version they upgrade to, run in order from the saved version plus one up to the current version (`Core.lua`, `migrations`).
- **DAT-03** Defaults are merged after migration, copying only missing keys (INV-04).
- **DAT-04** A module owns its own settings table and documents its shape in this section when it is added.
- **DAT-05** Nothing derived or recomputable is saved. Only the user's choices and data that cannot be rebuilt.

---

# 7. Module contract

A module is a table registered with `ns:RegisterModule(name, module)`.

| Function | When | Purpose |
|---|---|---|
| `Init(settings)` | Once, at login | Build frames, read settings, hook what is needed. Does not change what the player sees yet |
| `Enable()` | At login if enabled, and when the user turns the module on | Start showing or doing the module's work |
| `Disable()` | When the user turns the module off | Stop and undo what `Enable` did as far as the game allows |

- **MOD-01** `name` is unique. A duplicate name is a programming error and fails loudly at load.
- **MOD-02** All three functions are optional.
- **MOD-03** A module that cannot fully undo its work on `Disable` says so, and the user is told a reload is needed.
- **MOD-04** Core calls every function through `pcall`. A failure prints the module name, the function and the error, and the module is treated as failed for that step (INV-07).
- **MOD-05** A module registers its own slash sub-command through `ns:RegisterCommand(name, handler, helpText)`. Core adds this helper in step 1 (CMD-05).
- **MOD-06** A module may set a `classes` field, a list of class tokens such as `{ "HUNTER" }`. Core skips `Init` and `Enable` for a character whose class is not in the list, and `/ggg modules` shows it as "not for this class". A module with no `classes` field is for every class.
- **MOD-07** The module registry does not decide what the module is for. Class templates (SCP-06) are a later layer on top of `classes` and are not designed yet.

## 7.1 Module: Cluster

The first module. It replaces the default player frame, pet frame, pet bar, party frames and action bars 1 to 4 with new ones, laid out as one compact group at the bottom centre of the screen. The names are Blizzard's own: PlayerFrame, PetFrame, PetActionBar, PartyFrame, and the action bars called Action Bar 1 to Action Bar 4 (the main bar, the bottom left bar, the bottom right bar and the right bar).

### Layout

```text
                  [ Party 1 ][ Party 2 ][ Party 3 ][ Party 4 ]
 +-----------+-----------+----------+----------+-----------+-----------+
 | Action    | Action    | Player   | Pet      | Action    | Action    |
 | Bar 1     | Bar 2     | frame    | frame    | Bar 3     | Bar 4     |
 |           |           | and info | and info |           |           |
 |           |           |          | Pet bar  |           |           |
 +-----------+-----------+----------+----------+-----------+-----------+
   outer left  outer left  inner     inner      outer right outer right
                           left      right
```

- **CLU-01** The module is registered as `Cluster`. It has no `classes` field, so it is for every class (MOD-06).
- **CLU-02** One container frame holds everything. It is anchored to the bottom centre of `UIParent` and the parts are positioned inside it (section 7.1, layout).
- **CLU-03** Parts sit in this order from left to right: action bars 1 and 2 (outer left), the player frame and its information (inner left), the pet frame, its information and the pet bar (inner right), action bars 3 and 4 (outer right). Party frames run horizontally, left to right, in a row above the player and pet area. Frame sizes and the cluster width are defaults in one table at the top of the file and are adjusted after the human sees them in the game.
- **CLU-04** To replace a default frame, the module hides Blizzard's frame and builds its own. It never moves, edits or re-skins Blizzard's frame. The hide method is chosen in step 2 and recorded as a decision, because it must not taint (INV-02).
- **CLU-05** The layout is fixed in this version. There is no edit mode and no user dragging (SCP-25).

### Parts

- **CLU-06** Player frame: the player's name, health and power, built on a secure unit button for `player` so that clicking and the right-click menu work (INV-02). More information is added when the human lists it (section 1.4, question 1).
- **CLU-07** Pet frame: the same for `pet`. The pet's happiness and other information are added when the human lists them.
- **CLU-08** The pet frame and the pet bar are shown only while the player has a pet, and the container does not move when they appear or disappear.
- **CLU-09** Pet bar: the pet's action buttons, built on secure action buttons and placed under the pet frame. Defined in a later step.
- **CLU-10** Party frames: up to four secure unit buttons for `party1` to `party4`, in a horizontal row. Defined in a later step.
- **CLU-11** Action bars 1 to 4: secure action buttons bound to the same action slots as Blizzard's bars, so that keybindings, drag and drop and macros keep working. Defined in a later step.

### Behaviour that applies to every part

- **CLU-12** Health, power and names read from game units may be "secret" values on this client, which addon code cannot compare, format or do arithmetic on. Every read is checked with `issecretvalue` before any other use. A secret value is passed straight to a status bar or font string and nothing else is done with it. Step 2 reports in the game which reads work in and out of combat.
- **CLU-13** Creating, showing, hiding or moving any secure frame is not done in combat (INV-01). Work that comes up in combat, such as a pet appearing, is queued and runs when combat ends (LIF-06). Frames that need to change in combat are changed through secure state drivers or attributes set before combat.
- **CLU-14** The module's frames use the `GGGUIManagerCluster` name prefix (INV-03). Updates are driven by unit events for the displayed unit, not by an `OnUpdate` scan (INV-05).

**Saved data** (`ns.db.modules.Cluster`): `{ enabled = true }` for now. Settings are added to this section as each part needs them (DAT-04).

**Known limitations.** The default frames come back only after a reload when the module is disabled (MOD-03). A fixed layout will not suit every screen size and resolution. Spell and ability tooltips, cooldown text and range colouring on the new action bars are added with the action bar step.

---

# 8. Slash commands

- **CMD-01** `/ggg` and `/gggui` are the only slash commands the addon registers.
- **CMD-02** With no argument or `help`, the command prints the version and the command list.
- **CMD-03** `/ggg modules` lists registered modules and whether each is on.
- **CMD-04** Unknown input prints one line pointing to `/ggg help`.
- **CMD-05** Module sub-commands (`/ggg <name> ...`) are added by modules through `ns:RegisterCommand(name, handler, helpText)` (MOD-05). `/ggg help` lists every registered sub-command with its help text. The handler gets the rest of the line as one string. A name that is already taken is a programming error and fails loudly at load.

---

# 9. Test requirements

The game cannot run unit tests, so testing has two levels.

- **TST-01** Pure logic (data migration, default merging, sorting, list handling) is kept in functions that do not call game APIs, so they can be tested outside the game with a plain Lua runner.
- **TST-02** The runner and its folder layout (`tests/`) are added by the first step that has pure logic worth testing. The choice is recorded as a decision then.
- **TST-03** Each test names the requirement it verifies, for example `-- Requirement: DAT-03`.
- **TST-04** Everything that touches frames or events is verified by hand in the game. The step report lists the exact things to check and what should be seen.
- **TST-05** After every edit the agent syntax-checks all Lua files and reports the result. Passing a syntax check is not described as "tested".

---

# 10. Implementation steps

Use these **one at a time**. Each block gives the prompt, the requirements covered, acceptance criteria and a demo script.

**Common preamble** (prepend to every step prompt):

> You are implementing GGG UI Manager from SDD v0.4. Work **only** on the step below and do not start later steps. Read the listed sections first. Apply the invariants (section 2) and agent rules (section 11). If anything is ambiguous, contradictory or missing, **stop and ask** before writing code. Syntax-check every Lua file you change. You cannot run the game, so say so explicitly and list what the human must check in game. Finish with the step report in Appendix A, including deviations from the SDD and proposed SDD changes.

## Step 0: Shell and design document (done in the initial commit)

**Read:** 1, 2, 3, 5, 6, 7, 8.
**Delivered:** `GGGUIManager.toc`, `Core.lua` (saved data, migrations, module registry, `/ggg`), this SDD, `docs/PROGRESS.md`, `docs/DECISIONS.md`, README, CLAUDE.md.
**Covers:** SCP-01, SCP-02, SCP-03, STR-01..07, LIF-01..04, DAT-01..03, MOD-01, MOD-02, MOD-04, CMD-01..04.
**Acceptance:** the addon loads with no errors, `/ggg` prints the version and help, `/ggg modules` says there are no modules, and `GGGUIManagerDB` appears in the saved variables file after a logout.
**Demo:** log in, run `/ggg`, `/ggg modules`, then `/reload` and confirm no errors.

## Step 1: Manager additions

**Read:** 2, 5, 7 (MOD-05..07), 8 (CMD-05).
**Status:** defined, not started. The human has not approved it yet.
**Prompt:** Extend `Core.lua` with `ns:RegisterCommand`, the `classes` filter on modules, and the combat queue that runs queued work on `PLAYER_REGEN_ENABLED` (LIF-06). `/ggg help` lists registered sub-commands and `/ggg modules` shows "not for this class" where it applies. No module is added.
**Covers:** MOD-05, MOD-06, CMD-05, LIF-06.
**Acceptance:** the addon loads without errors. `/ggg help` and `/ggg modules` still work.
**Demo:** log in, run `/ggg help` and `/ggg modules`, then `/reload`.

## Step 2: Cluster container and player frame

**Read:** 2, 5, 7.1 (CLU-01..06, CLU-12..14).
**Status:** defined, not started. Depends on step 1 for the combat queue.
**Prompt:** Add `Modules/Cluster/Cluster.lua` and `PlayerFrame.lua`. Register the module, create the container at the bottom centre of the screen with the layout areas marked by simple placeholder boxes, and build the player frame (name, health bar, power bar) on a secure unit button for `player`. Hide Blizzard's PlayerFrame and record the hide method in `docs/DECISIONS.md` (CLU-04). Read the player's health, power and name with `issecretvalue` checks and report in the step report which reads worked, in and out of combat (CLU-12). If the player is in combat when the module starts, wait until combat ends. Check the reference UI source for how PlayerFrame handles these values before writing code.
**Covers:** CLU-01..06, CLU-12..14.
**Acceptance:** with no errors, the player frame shows in the inner left spot, with the name, a health bar and a power bar that update as they change. Left-click targets you and right-click opens the menu. The default player frame is gone. After `/reload` in combat, nothing errors.
**Demo:** log in, `/reload`, take damage from a training dummy or fall, use an ability that costs power, then `/reload` while in combat.

## Step 3 onward

Not defined in detail. The expected order is the pet frame, the pet bar, the party frames, then action bars 1 to 4, one step each. Each step is written after the previous one has been tested in the game.

---

# 11. Mandatory agent rules

- **AGT-01** Inspect the repository before modifying it.
- **AGT-02** Work only on the requested step and preserve the module boundaries.
- **AGT-03** If the SDD is ambiguous, contradictory or silent on a material decision, **stop and ask**. Do not invent requirements. Use documented defaults for immaterial ones and record them in `docs/DECISIONS.md`.
- **AGT-04** Syntax-check every Lua file after changes (TST-05) and never claim in-game behaviour was verified when it was not.
- **AGT-05** Do not leave the addon unable to load at the end of a step (INV-10).
- **AGT-06** Document new commands, saved data and module behaviour in `docs/` and the README.
- **AGT-07** Record every deviation from the SDD, and every SDD change you recommend, in the step report. Do not edit `docs/SDD.md` unless the human asks. The human owns it.
- **AGT-08** Update `docs/PROGRESS.md` and `docs/DECISIONS.md` as part of each step.
- **AGT-09** Read the human's writing rules before writing any prose for documents, as the global instructions require.
- **AGT-10** Do not commit or push unless the human asks for it in that turn.

---

# 12. Definition of done

For the shell and for every later feature:

- [ ] The addon loads with no errors on the target client.
- [ ] Saved data is created, migrated and merged with defaults (INV-04).
- [ ] Combat behaviour follows INV-01 and INV-02, checked in a real fight where relevant.
- [ ] No new globals beyond INV-03.
- [ ] Every module failure is isolated (INV-07).
- [ ] Documents match the code: SDD, README, PROGRESS, DECISIONS.
- [ ] The step report lists exactly what was and was not verified.

## Known limitations of the shell

- There is no settings window yet. Everything is controlled by slash commands.
- There are no modules until step 2, so the addon does nothing visible beyond `/ggg`.
- No automated tests exist until a module has pure logic to test.
- The target client's API may differ from the reference source in places, so each new API call is checked in game.

---

# 13. Future seams

- A combat queue helper in `Core.lua` that every module shares (LIF-06).
- A slash sub-command registration helper (MOD-05, CMD-05).
- Profiles (per character, per spec) layered over `ns.db.modules` without changing module code.
- A settings window module that reads each module's declared options.
- Folding existing personal addons in as modules, one at a time, each with a migration of its old saved data.- A template system: a base template for all classes plus class-specific templates (SCP-06), built on the `classes` field (MOD-06).
- Later, if wanted: a user-movable layout, an edit mode, a grid, third-party wrappers and modules as separate addons (SCP-25). None of these are designed.
- Splitting Cluster into one module per part if it grows too large (D-011).
- A packaging step for release if the addon is ever shared (SCP-23).

---

# Appendix A: Step report template

The agent ends every step with:

```markdown
## Step <n> report (SDD v<version>)
**Requirements addressed:** <IDs>
**Files added/changed:** <list>
**Syntax check results:** <file: OK or error, or "NOT RUN">
**What the human must check in game:** <exact steps and what should be seen>
**Tests added (with Requirement tags):** <list or "none">
**Deviations from the SDD:** <none or list with reason>
**Decisions made (also in docs/DECISIONS.md):** <list>
**Ambiguities / questions for the human:** <list>
**Recommended SDD changes:** <list, referencing IDs>
**Known limitations after this step:** <list>
```

# Appendix B: `docs/PROGRESS.md` and `docs/DECISIONS.md` templates

```markdown
# PROGRESS
| Step | SDD version | Date | Status | Syntax check | In game | Notes |
|---|---|---|---|---|---|---|

# DECISIONS
## D-001 <title>
- **Date / step:**
- **Context:**
- **Decision:**
- **Alternatives considered:**
- **Requirement IDs affected:**
```
