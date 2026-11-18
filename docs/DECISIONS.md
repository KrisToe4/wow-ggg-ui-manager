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
