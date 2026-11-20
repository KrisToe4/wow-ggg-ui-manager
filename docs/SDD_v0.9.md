# Software Design Document (SDD)
## GGG UI Manager (Good Girl Gamer UI Manager)

| | |
|---|---|
| **Version** | 0.9 (draft) |
| **Supersedes** | 0.8 |
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
| 0.9 | Hunter widgets in the player area, as an experiment: CLU-18, HUN-11 to HUN-14, step 8. Party frames postponed | The human wants an ammo indicator and a range indicator in the player area and expects a lot of trial and error |
| 0.8 | Action bars defined: CLU-11 made specific, CLU-17 added, CLU-03 and layout sizes updated for 3 by 4 bars, steps 6 and 7, section 1.4 question 2 settled | The human asked for the four action bars next, as 3 columns by 4 rows |
| 0.7 | Pet bar defined: CLU-09 made specific, CLU-16 added, step 5. Steps after it renumbered | The human asked for the pet bar next |
| 0.6 | Second module, Hunter (section 7.2): the HunterKit addon converted into a module, and the old addon removed. SCP-07, SCP-24, sections 1.2, 1.4, 3, 7.2, 10 (steps 3 and 4), 13, HUN-01..10 | The human will not use HunterKit outside the UI manager (D-016) |
| 0.5 | Cluster keeps the default frames visible until the human turns hiding on: new `hideDefaults` setting, default off. CLU-04, CLU-15, saved data of 7.1, step 2, section 1.2 | The human does not want Blizzard's frames hidden while the cluster is being built (D-012) |
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
- **SCP-07** A second module, **Hunter** (section 7.2): the ammo alert, pet alerts and info, dead zone warning and macros from the personal addon HunterKit, for Hunters only. The HunterKit addon is removed.
- **SCP-06** *(Direction, not a requirement yet.)* The manager will later offer a template system: a base template for all classes and class-specific templates on top of it. Hunter is the first class planned.

## 1.2 Project decisions

- One main addon with internal modules. Features do not become separate addons unless a decision says so.
- Personal use first. The addon targets the human's own client and characters, and public release is not a goal yet.
- No external libraries to start with. A library is added only through a recorded decision.
- Modules are files inside this addon for now (D-001). Whether modules can later be separate addons is a later decision.
- A module that listed tracked creatures was tried and dropped, because the client hides the minimap tooltip text from addons (D-009).
- Cluster builds its own frames and hides Blizzard's. It does not move or restyle Blizzard's frames (D-011).
- Cluster is one module with parts, not one module per part (D-011).
- Cluster leaves the default frames visible until the human turns hiding on (D-012).

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
2. *(Settled in 0.8.)* Action bars 1 and 2 sit side by side on the outer left, 3 and 4 side by side on the outer right, each bar 3 columns by 4 rows (CLU-11).
3. Frame sizes and the total width of the cluster. Step 2 uses defaults that the human adjusts after seeing them (CLU-03).
4. Does the cluster show for every class? It does by default. The pet parts only show while there is a pet (CLU-08).
5. This client hides some values from addons as "secret" values (D-009). Which unit values (health, power, names) can addon code read in and out of combat? Step 2 finds out in the game (CLU-12).
6. Which of the remaining personal addons (BagBuddy, FriendBook, others) should eventually fold into this one as modules, if any? HunterKit is done (section 7.2).
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
        ├── Hunter/                    (second module, section 7.2: Hunter.lua, Ammo.lua, Pet.lua, DeadZone.lua, Macros.lua)
        └── Cluster/                   (first module, section 7.1; one file per part, added step by step)
            ├── Cluster.lua            (module registration, container, layout)
            ├── PlayerFrame.lua        (added in step 2)
            └── UnitFrame.lua, PetFrame.lua, PetBar.lua   (added in steps 3 and 5)
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
- **CLU-03** Parts sit in this order from left to right: action bars 1 and 2 side by side (outer left), the player frame and its information (inner left), the pet frame, its information and the pet bar (inner right), action bars 3 and 4 (outer right). Party frames run horizontally, left to right, in a row above the player and pet area. Frame sizes and the cluster width are defaults in one table at the top of the file and are adjusted after the human sees them in the game.
- **CLU-04** To replace a default frame, the module builds its own and, when `hideDefaults` is on (CLU-15), hides Blizzard's frame. It never edits or re-skins Blizzard's frame. The hide method is recorded as a decision because it must not taint (INV-02).
- **CLU-15** The setting `hideDefaults` is off by default. While it is off, Blizzard's frames are left alone and the new frames show beside them. `/ggg cluster hide on` and `/ggg cluster hide off` change it. Turning it on hides the default frames, and turning it off restores them only after a reload (MOD-03).
- **CLU-05** The layout is fixed in this version. There is no edit mode and no user dragging (SCP-25).

### Parts

- **CLU-06** Player frame: the player's name, health and power, built on a secure unit button for `player` so that clicking and the right-click menu work (INV-02). More information is added when the human lists it (section 1.4, question 1).
- **CLU-07** Pet frame: the same for `pet`. The pet's happiness and other information are added when the human lists them.
- **CLU-08** The pet frame and the pet bar are shown only while the player has a pet, and the container does not move when they appear or disappear.
- **CLU-09** Pet bar: the pet's ten action slots, built on secure action buttons of the game's `pet` action type, in one row under the pet frame inside the inner right area. Each button shows the action's icon, its cooldown, a highlight while the action is active (for example the current stance) and a small mark when auto-cast is allowed or on. Left-click uses the action, right-click toggles auto-cast, and hovering shows the game's tooltip for the action.
- **CLU-16** The pet bar is shown only while the player has a pet, by a secure state driver, so it appears and goes in combat without addon code touching it (INV-01, CLU-13). Empty slots are shown empty. Dragging actions between slots and key bindings on the new buttons are not part of this version. The game's own pet bar key bindings keep working.
- **CLU-10** Party frames: up to four secure unit buttons for `party1` to `party4`, in a horizontal row. Defined in a later step.
- **CLU-11** Action bars 1 to 4: secure action buttons of the `action` type bound to the same action slots as Blizzard's bars, so the same abilities and macros show. Each bar is a grid of 3 columns and 4 rows, numbered across and then down:

  ```text
   1  2  3
   4  5  6
   7  8  9
  10 11 12
  ```

  The bars sit side by side: bars 1 and 2 on the outer left (bar 1 outermost) and bars 3 and 4 on the outer right (bar 4 outermost). The slots are Blizzard's: bar 1 is slots 1 to 12, bar 2 (the bottom left bar) is 61 to 72, bar 3 (the bottom right bar) is 49 to 60 and bar 4 (the right bar) is 25 to 36. Bar 1 does not page in this version, so it always shows slots 1 to 12 and does not change for forms, stealth, stances or vehicles.
- **CLU-18** Cluster tells other modules when it is built. `Cluster:OnBuilt(func)` calls `func(container, areas)` once the container and the parts exist, or at once if they already do. Other modules use it to place widgets in the free space of an area, for example the Hunter widgets under the player frame (HUN-14). The widgets are not secure frames, so they can change in combat.
- **CLU-17** Each action button shows the icon, the cooldown, the item count or charges, the key binding text, the macro name, grey when the action is unusable, red when the target is out of range, and the game's tooltip. Cooldown and count values may be hidden "secret" values in combat, so cooldowns are set from the game's duration object and counts as text without comparing them (CLU-12). Proc glow, equipped and active borders and spell flyouts come in step 7. Key bindings stay on the game's own bar commands, so the keys keep working and the new buttons only show the key text. Dragging actions onto and off the new buttons is not part of this version.

### Behaviour that applies to every part

- **CLU-12** Health, power and names read from game units may be "secret" values on this client, which addon code cannot compare, format or do arithmetic on. Every read is checked with `issecretvalue` before any other use. A secret value is passed straight to a status bar or font string and nothing else is done with it. Step 2 reports in the game which reads work in and out of combat.
- **CLU-13** Creating, showing, hiding or moving any secure frame is not done in combat (INV-01). Work that comes up in combat, such as a pet appearing, is queued and runs when combat ends (LIF-06). Frames that need to change in combat are changed through secure state drivers or attributes set before combat.
- **CLU-14** The module's frames use the `GGGUIManagerCluster` name prefix (INV-03). Updates are driven by unit events for the displayed unit, not by an `OnUpdate` scan (INV-05).

**Saved data** (`ns.db.modules.Cluster`): `{ enabled = true, hideDefaults = false, showLayout = true }` for now. `showLayout` shows or hides the placeholder boxes that mark the layout areas. Settings are added to this section as each part needs them (DAT-04).

**Known limitations.** The default frames come back only after a reload when the module is disabled (MOD-03). A fixed layout will not suit every screen size and resolution. Spell and ability tooltips, cooldown text and range colouring on the new action bars are added with the action bar step.

---

## 7.2 Module: Hunter

The second module. It is the HunterKit addon converted into a module. It is for Hunters only.

- **HUN-01** The module is registered as `Hunter` with `classes = { "HUNTER" }` (MOD-06). Its parts are separate files that add themselves to the module and share its settings and alert helper.
- **HUN-02** Ammo alert. While a ranged weapon is equipped, the player is warned at three levels: low at `warn` ammo (default 200), critical at `critical` (default 50), and none left or none equipped. The count includes ammo in bags. The first check after login is silent. An alert fires only when the level gets worse.
- **HUN-03** Pet alerts. The player is told when the pet becomes unhappy and when the pet gains training points to spend. `/ggg hunter pet alerts` turns them on or off.
- **HUN-04** Pet info. `/ggg hunter pet` prints the pet's name, level, family, happiness and training points to spend.
- **HUN-05** Dead zone warning. A box says "DEAD ZONE" while the target can be attacked, is inside the game's close range check (about 9.9 yards) and is outside Raptor Strike's range. It checks at most 10 times a second (INV-05). `/ggg hunter deadzone on|off|unlock|lock` turns it on or off and moves it. Its position is saved.
- **HUN-06** Macros. `/ggg hunter macros` creates or rewrites the character macros HKAttack, HKMend, HKFollow and HKStay. It does nothing in combat. The macro names are kept so macros already on action bars keep working.
- **HUN-07** Every command is under `/ggg hunter` (CMD-05): `ammo`, `ammo <warn> <critical>`, `pet`, `pet alerts`, `deadzone`, `macros`. The old `/hk` command no longer exists.
- **HUN-08** Pet happiness comes from the shared helper `ns.GetPetMood()` in `Core.lua`, which uses `C_PetInfo.GetPetHappiness` and the pet's damage bonus (D-015). The Cluster pet frame uses the same helper.
- **HUN-09** HunterKit's tracking list is not carried over. It depended on reading minimap tooltip text, which the client hides from addons (D-009).
- **HUN-10** The HunterKit addon is removed from `Interface\AddOns` once this module is in place. A backup copy is kept outside the game folder. The saved data of HunterKit (`HunterKitDB`) is not migrated, because the defaults are the same as the module's.

### Experimental widgets (step 8)

These are an experiment. How they look and work will change as the human tries them, so the requirements are deliberately loose and the step is repeated until the human is happy (section 10, step 8).

- **HUN-11** Ammo indicator: a small widget in the player area of the Cluster showing the equipped ammo's icon and the total count, coloured normal, yellow at the low level and red at the critical level or when none is left (HUN-02). It updates on the same events as the ammo alert. It is shown only for a Hunter with a ranged weapon.
- **HUN-12** Range indicator: a widget in the player area that shows how far the current target is, in bands that change as the player moves closer or further away. The first version has four bands from near to far: melee, dead zone, ranged and out of range. The band the target is in is lit. With no target it is dim. It checks at most 10 times a second (INV-05). The bands and the look are expected to change.
- **HUN-13** Range probe: `/ggg hunter range` prints every range measurement the client offers for the current target, so the human can stand at different distances and report which measurements change. It lists the interact distance checks, the range of several hunter spells with their minimum and maximum range from the spell data, and the unit distance call if the client has it.
- **HUN-14** The widgets are placed by the Hunter module inside the Cluster container, in the free space under the player frame (CLU-18). If Cluster is off or not built, the widgets are not shown.

**Saved data** (`ns.db.modules.Hunter`):

```text
{ enabled = true,
  ammo = { warn = 200, critical = 50 },
  pet = { alerts = true },
  deadzone = { enabled = true, point = { "CENTER", "UIParent", "CENTER", 0, 160 } } }
```

**Known limitations.** Pet training points use `GetPetTrainingPoints`, which may not exist on this client. When it is missing, that alert and that line of `/ggg hunter pet` are skipped. Check it in the game.

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

**Read:** 2, 5, 7.1 (CLU-01..06, CLU-12..15).
**Status:** generated, awaiting the in-game check.
**Prompt:** Add `Modules/Cluster/Cluster.lua` and `PlayerFrame.lua`. Register the module, create the container at the bottom centre of the screen with the layout areas marked by simple placeholder boxes, and build the player frame (name, health bar, power bar) on a secure unit button for `player`. Leave Blizzard's PlayerFrame alone unless `hideDefaults` is on (CLU-15), and record the hide method in `docs/DECISIONS.md`. Pass health and power values straight to the bars and text without comparing or calculating on them (CLU-12), and add `/ggg cluster check`, which prints whether each unit read is a secret value so the human can report it, in and out of combat. If the player is in combat when the module starts, wait until combat ends.
**Covers:** CLU-01..06, CLU-12..15.
**Acceptance:** with no errors, the player frame shows in the inner left spot, with the name, a health bar and a power bar that update as they change. The default player frame is still there. Left-click targets you and right-click opens the menu. `/ggg cluster hide on` and a `/reload` hide the default player frame. After `/reload` in combat, nothing errors.
**Demo:** log in, `/ggg cluster check`, `/reload`, take damage or use an ability that costs power, `/ggg cluster check` in combat, then `/ggg cluster hide on` and `/reload`.

## Step 3: Pet frame (done)

**Covers:** CLU-07, CLU-08. The pet frame at the top of the inner right area, shown only while there is a pet, with the pet's happiness shown as a coloured name and a label. Built on the shared unit frame in `Cluster/UnitFrame.lua`. Confirmed in game.

## Step 4: Hunter module (converted from HunterKit)

**Read:** 2, 5, 7.2, 8.
**Prompt:** Add `Modules/Hunter/` with `Hunter.lua`, `Ammo.lua`, `Pet.lua`, `DeadZone.lua` and `Macros.lua`, ported from the HunterKit addon. Register the module as `Hunter` for Hunters only. Move the commands from `/hk` to `/ggg hunter`. Use the shared pet mood helper for happiness (HUN-08). Do not port the tracking list (HUN-09). Remove the HunterKit addon from the game folder once the module is in place, after keeping a backup copy outside the game folder (HUN-10).
**Covers:** HUN-01..10, SCP-07.
**Acceptance:** the addon loads with no errors on a Hunter and on another class. `/ggg modules` shows Hunter. Each of the five commands works. The HunterKit addon is gone from `Interface\AddOns`.
**Demo:** see HUN-02 to HUN-07 and the checks in the step report.

## Step 5: Pet bar

**Read:** 2, 7.1 (CLU-09, CLU-13, CLU-16).
**Status:** generated, awaiting the in-game check.
**Prompt:** Add `Modules/Cluster/PetBar.lua`. Build ten secure action buttons of the `pet` type in one row under the pet frame, shown only while there is a pet by a secure state driver. Show icon, cooldown, active highlight and an auto-cast mark. Right-click toggles auto-cast and hover shows the game's tooltip. Hide Blizzard's PetActionBar only when `hideDefaults` is on.
**Covers:** CLU-09, CLU-13, CLU-16.
**Acceptance:** with a pet out, the bar shows under the pet frame. Left-click makes the pet attack, follow or stay, and changes its stance, including in combat. The bar disappears when the pet is dismissed. No errors, including after `/reload` in combat.
**Demo:** summon a pet, click each button, dismiss the pet, summon it again in combat if possible.

## Step 6: Action bars 1 to 4, core features

**Read:** 2, 7.1 (CLU-03, CLU-11, CLU-12, CLU-13, CLU-17).
**Status:** generated, awaiting the in-game check.
**Prompt:** Resize the cluster layout for four bars of 3 by 4 buttons and add `Modules/Cluster/ActionBars.lua`. Build the four bars as secure `action` buttons bound to their slots (CLU-11) with the core features of CLU-17: icon, cooldown, count, key text, macro name, unusable and out-of-range colouring, and tooltip. Hide Blizzard's bars only when `hideDefaults` is on. No paging, no proc glow, no borders, no flyouts and no dragging yet.
**Covers:** CLU-03, CLU-11, CLU-17 (core part).
**Acceptance:** with the default bars still visible, the four new bars show the same abilities as the default bars in their slots. Clicking uses the ability, including in combat. Cooldowns, counts and colouring update. No errors, including after `/reload` in combat.
**Demo:** compare each new bar with its default bar, use an ability, watch the cooldown, then `/reload` in combat.

## Step 7: Action bar extras

**Read:** 2, 7.1 (CLU-17).
**Status:** not started.
**Prompt:** Add proc glow, the equipped and active borders and spell flyouts to the action buttons.
**Covers:** CLU-17 (extras).

## Step 8: Hunter widgets (experiment, repeated)

**Read:** 2, 7.2 (HUN-11 to HUN-14), 7.1 (CLU-18).
**Status:** first iteration generated, awaiting the in-game check.
**Prompt:** Add `Cluster:OnBuilt`. Add `Modules/Hunter/Indicators.lua` with the ammo indicator and the first version of the range indicator in the free space under the player frame, and the `/ggg hunter range` probe. Keep the look simple and easy to change. Each round the human reports what is wrong or missing and the widgets change. Record what the probe shows about the client's range data in `docs/DECISIONS.md`.
**Covers:** CLU-18, HUN-11 to HUN-14.
**Acceptance:** with a ranged weapon, the ammo widget shows the ammo icon and count in the player area. With a hostile target, the range widget lights the band that matches the distance and changes when the player or target moves. The probe prints its list. No errors.
**Demo:** target a mob, walk toward and away from it, run `/ggg hunter range` at a few distances, shoot ammo and watch the count.

## Step 9 onward

Not defined in detail. Candidates: the party frames (postponed by the human until they have a group), dragging actions onto the new bars, paging for bar 1, and key bindings on the new buttons. Each step is written after the previous one has been tested in the game.

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
- Folding the remaining personal addons (BagBuddy, FriendBook) in as modules, one at a time, each with a migration of its old saved data. HunterKit was folded in as the Hunter module (section 7.2).
- A template system: a base template for all classes plus class-specific templates (SCP-06), built on the `classes` field (MOD-06).
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
