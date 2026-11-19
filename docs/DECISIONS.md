# DECISIONS

## D-001 One main addon with internal modules
- **Date / step:** 2026-11-18 / step 0
- **Context:** The human wants a main addon called GGG UI Manager that grows over time. Earlier personal addons were separate and each carried its own boilerplate.
- **Decision:** One addon folder with a module registry in `Core.lua`. Features are added as modules, each in its own file, listed in the `.toc`.
- **Alternatives considered:** Several separate addons with a shared library. Rejected for now because it adds a dependency before there is a feature to share.
- **Requirement IDs affected:** SCP-02, MOD-01..05, STR-03

## D-002 Repository root is not the addon folder
- **Date / step:** 2026-11-18 / step 0
- **Context:** The repository holds documents next to the addon, but the game must load only the addon folder.
- **Decision:** The addon lives in `GGGUIManager/` inside the repository. It is linked or copied into `Interface\AddOns`. The README gives the link command.
- **Alternatives considered:** Making the repository root the addon folder and keeping documents elsewhere. Rejected because the documents belong with the code.
- **Requirement IDs affected:** STR-01, STR-02

## D-003 Saved data has a schema version and ordered migrations from the start
- **Date / step:** 2026-11-18 / step 0
- **Context:** Earlier addons changed their saved shape without a plan. A version number is cheap now and expensive later.
- **Decision:** `GGGUIManagerDB.schemaVersion` starts at 1. `Core.lua` runs migrations in order, then merges defaults.
- **Alternatives considered:** Merging defaults only. Rejected because renames and restructures cannot be expressed that way.
- **Requirement IDs affected:** SCP-03, DAT-01..03, INV-04

## D-004 No test runner in the shell
- **Date / step:** 2026-11-18 / step 0
- **Context:** The shell has almost no pure logic. A runner chosen now would be chosen without a feature to test.
- **Decision:** The shell is verified by syntax check and an in-game check. The runner is chosen in step 2, when the first pure logic exists.
- **Alternatives considered:** Adding busted now. Deferred.
- **Requirement IDs affected:** TST-01, TST-02, TST-05

## D-005 Interface 16001, no libraries
- **Date / step:** 2026-11-18 / step 0
- **Context:** The target client is WoW Forever. Earlier personal addons used `## Interface: 16001` successfully.
- **Decision:** Target 16001 and add no libraries. A library needs its own decision (INV-09).
- **Alternatives considered:** Ace3 for saved data and options. Deferred until a feature needs it.
- **Requirement IDs affected:** STR-04, INV-09

## D-006 TrackingList collects names from the minimap tooltip
- **Date / step:** 2026-11-18 / SDD 0.2
- **Context:** The human wants a window listing the objects visible with the active tracking. The game's minimap API has no call that lists tracked objects. It only reports and sets the tracking types.
- **Decision:** Read the game tooltip while the mouse is over the minimap and collect the names. The list is only as complete as the mouse sweep. Step 3 verifies in the game that the tooltip can be read.
- **Alternatives considered:** A tracking-state window that only shows and switches the active type, which is reliable but does not list objects. Kept as a fallback if the tooltip cannot be read.
- **Requirement IDs affected:** SCP-24, TRK-02..04, TRK-09

## D-007 Modules may declare the classes they are for
- **Date / step:** 2026-11-18 / SDD 0.2
- **Context:** The human plans a template system with a base template and class-specific ones, starting with Hunter.
- **Decision:** Add an optional `classes` list to a module. Core starts the module only for those classes. Templates themselves are not designed yet.
- **Alternatives considered:** Designing the template system now. Rejected as too much before the first module works.
- **Requirement IDs affected:** SCP-05, SCP-06, MOD-06, MOD-07

## D-008 Larger ideas parked, not recorded
- **Date / step:** 2026-11-18 / SDD 0.2
- **Context:** An earlier round described a grid front end, an edit mode, replacing default interface pieces, third-party wrappers and modules as separate addons. The human decided it was too much to start with and asked to drop it.
- **Decision:** None of it is in the SDD except a one-line non-goal (SCP-25). D-001 stays: modules are files inside this addon for now.
- **Alternatives considered:** Keeping the notes in a parked file. The human chose to drop them.
- **Requirement IDs affected:** SCP-25

## D-009 TrackingList dropped as the first module
- **Date / step:** 2026-11-19 / SDD 0.3
- **Context:** HunterKit's tracking list was tried in the game as a test of the hover-collect idea (D-006). The client returns minimap tooltip text as a "secret" string. Addon code cannot index, compare or sort it, and the list stayed empty.
- **Decision:** Remove TrackingList and its requirements (TRK-01..10) from the SDD. D-006 no longer applies. The first module is not chosen yet. D-007 (the `classes` field) stays.
- **Alternatives considered:** A tracking-state switcher window that shows and changes the active tracking type. The human did not want it as the first module.
- **Requirement IDs affected:** SCP-04, SCP-24, MOD-06, steps 1 to 3

## D-010 Replacing the default frames is back in scope for Cluster only
- **Date / step:** 2026-11-19 / SDD 0.4
- **Context:** D-008 dropped replacing default interface pieces as too much to start with. The human has now chosen a first module that replaces the player frame, pet frame, pet bar, party frames and action bars 1 to 4, in a fixed compact layout at the bottom centre.
- **Decision:** Replacement is allowed for the pieces listed in SDD section 7.1 only. The grid, edit mode, profiles, third-party wrappers and separate-addon modules stay dropped. The layout is fixed and not user-movable.
- **Alternatives considered:** Starting with a smaller module first. The human chose this one.
- **Requirement IDs affected:** SCP-04, SCP-20, SCP-25, CLU-01..14

## D-011 Cluster builds its own frames and is one module
- **Date / step:** 2026-11-19 / SDD 0.4
- **Context:** Blizzard's unit frames and action bars are protected and cannot be changed in combat. Two choices were put to the human: build new frames and hide Blizzard's, or move and restyle Blizzard's. A second choice was one module per part or one module for the whole cluster.
- **Decision:** Build new secure frames and hide Blizzard's. Keep everything in one module, Cluster, with one file per part. The hide method is decided in step 2.
- **Alternatives considered:** Moving Blizzard's frames, which cannot be changed in combat and may be repositioned by the game. One module per part, which can be adopted later if Cluster grows too large.
- **Requirement IDs affected:** CLU-01..04, CLU-13

## D-012 Default frames stay visible until the human turns hiding on
- **Date / step:** 2026-11-19 / SDD 0.5, step 2
- **Context:** The human does not want Blizzard's frames hidden while the cluster is still being built.
- **Decision:** Cluster has a `hideDefaults` setting, off by default. `/ggg cluster hide on|off` changes it and a reload applies it. When on, Blizzard's frame is moved under a hidden frame and its events are unregistered. Nothing of Blizzard's code is edited. The move runs out of combat through `ns:AfterCombat`.
- **Alternatives considered:** Calling Hide and hooking Show, which is blocked in combat for protected frames. Not chosen.
- **Requirement IDs affected:** CLU-04, CLU-15

## D-013 Secret values go straight to bars and text
- **Date / step:** 2026-11-19 / step 2
- **Context:** The reference API documentation marks UnitHealth as returning secret values, and UnitHealthMax, UnitPower and UnitPowerMax as secret when restricted. The same documentation allows secret arguments to StatusBar SetValue and SetMinMaxValues and to FontString SetText and SetFormattedText from addon code.
- **Decision:** The player frame passes these values directly to the bars and `SetFormattedText` and never compares or calculates with them. `/ggg cluster check` reports which reads are secret on the real client.
- **Alternatives considered:** Calculating percentages in Lua, which fails on secret values.
- **Requirement IDs affected:** CLU-12
