# CLAUDE.md

GGG UI Manager (Good Girl Gamer UI Manager): a main personal World of Warcraft addon for the WoW Forever client
(Interface 16001, Mainline-style Blizzard code). It is built one step at a time from the design document.

## Read first
- `docs/SDD.md`: the design document (SDD v0.6, draft). Read sections 0, 2, 10, 11 and Appendix A before any work,
  plus the sections the requested step lists. When the human asks for an SDD change, save the previous version as
  `docs/SDD_v<old>.md` first.
- `docs/PROGRESS.md`: step status and how each step was verified.
- `docs/DECISIONS.md`: recorded decisions (D-001 to D-016 so far, continue numbering).
- The reference Blizzard UI source is at `C:\Users\Kitten\Documents\source\WoW Addons\wow-ui-source`. It is version
  12.1.5, a close but not identical match for the Forever client, so check new API calls in game.

## Current state
- Step 0 is done: the addon shell (`GGGUIManager/GGGUIManager.toc`, `Core.lua`), the SDD, PROGRESS, DECISIONS and
  this file. It has not been loaded in the game yet.
- SDD v0.6 is the current draft. It defines the manager and two modules: Cluster (section 7.1) and Hunter (7.2). Cluster is a
  replacement player frame, pet frame, pet bar, party frames and action bars 1 to 4 in a fixed layout at the bottom
  centre (action bars and the pet bar and party frames are still to come). Steps 1 to 3 are done and confirmed in game (manager helpers, player frame, pet frame with mood). Step 4 (the Hunter module, converted from HunterKit, which was removed) is generated and awaits an in-game check.
  The addon is linked into the game with a junction (`Interface\AddOns\GGGUIManager`), so edits appear after `/reload`.
  Default Blizzard frames stay visible unless `/ggg cluster hide on` is set (D-012).
- The grid, edit mode, profiles, third-party wrappers and replacing default UI pieces other than Cluster's were dropped
  for now (D-008, D-010).
  Do not design them. Do not invent features. Ask.

## Working rules
- Do only the step requested. Prefix the work with the SDD section 10 common preamble and finish with the
  Appendix A step report.
- If the SDD is ambiguous, contradictory or silent on a material decision, stop and ask (AGT-03).
- Syntax-check every Lua file you change. Never say behaviour was verified in game unless the human confirmed it.
- Do not commit or push unless the human asks in that turn (AGT-10).
- Edit `docs/SDD.md` only when the human explicitly asks. Otherwise put recommended SDD changes in the step report.
- Every step ends with the addon in the game folder. `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\GGGUIManager`
  is a junction to the repository's `GGGUIManager/` folder, so edits land there at once. At the end of each step, check
  that the junction exists and that every file in the `.toc` is visible through it, and put the result in the step
  report. If the junction is missing, recreate it with `New-Item -ItemType Junction`. Tell the human whether
  `/reload` is enough or a full game restart is needed: a restart is needed when a file or the `.toc` was added or
  changed, and `/reload` is enough when only existing Lua files changed.
- Update `docs/PROGRESS.md` and `docs/DECISIONS.md` as part of every step.
- Respect the invariants in SDD section 2: no protected frame changes in combat, no taint, a small set of globals,
  throttled `OnUpdate`, isolated module failures.
- Before writing prose for documents, read the human's writing rules (the global CLAUDE.md points to them). No em
  dashes or en dashes, and no semicolon lists.

## Syntax check
The Python virtual environment with `luaparser` is in the session scratchpad and may need to be recreated:

```
python -m venv venv
venv\Scripts\pip install luaparser
```

Then parse each file with `luaparser.ast.parse`.
