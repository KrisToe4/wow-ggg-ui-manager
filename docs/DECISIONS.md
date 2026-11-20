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

## D-014 One shared unit frame builder, and a secure unit watch for the pet
- **Date / step:** 2026-11-19 / step 3
- **Context:** The pet frame needs the same name, health and power display as the player frame, and more frames (party) follow.
- **Decision:** `Cluster/UnitFrame.lua` builds one secure unit frame from options. The player frame was moved onto it. The pet frame uses `RegisterUnitWatch`, so the game shows and hides it securely when the pet appears or goes, even in combat, and it refreshes on `UNIT_PET`.
- **Alternatives considered:** Copying the player frame code. Rejected because the party frames would make it four copies. Showing and hiding the pet frame from addon code, which is blocked in combat.
- **Requirement IDs affected:** CLU-07, CLU-08, CLU-13

## D-015 Pet happiness comes from the damage bonus, through C_PetInfo
- **Date / step:** 2026-11-19 / step 3
- **Context:** The classic global `GetPetHappiness` does not exist on this client. `C_PetInfo.GetPetHappiness` does and returns happiness, a damage bonus and loyalty. The human's installed Huntmaster addon also prefers the damage bonus as the most reliable signal.
- **Decision:** Use `C_PetInfo.GetPetHappiness` (global as fallback). Map the damage bonus to a mood: 115 or more is Happy, 90 or more is Content, below that is Unhappy. Use the plain happiness value if there is no damage bonus. The mood is refreshed by the event and once a second while the pet frame shows.
- **Alternatives considered:** Reading Blizzard's pet happiness face. Not needed.
- **Requirement IDs affected:** CLU-07

## D-016 HunterKit becomes the Hunter module and the old addon is removed
- **Date / step:** 2026-11-19 / SDD 0.6, step 4
- **Context:** The human will not use HunterKit outside the UI manager. Its parts (ammo, pet, dead zone, macros) are small and fit the module contract.
- **Decision:** Port them into one module, `Hunter`, for Hunters only, with commands under `/ggg hunter`. Drop the tracking list (D-009). Pet mood uses a shared helper `ns.GetPetMood()` in `Core.lua`, also used by the Cluster pet frame (D-015). Remove the HunterKit addon from the game folder. A backup copy was kept in the session scratchpad. Saved data of HunterKit is not migrated because the defaults are the same.
- **Alternatives considered:** One module per tool. Rejected as too small to be worth separate modules. Migrating `HunterKitDB`. Rejected because only default values were in use.
- **Requirement IDs affected:** SCP-07, HUN-01..10

## D-017 Pet bar uses the secure pet action type
- **Date / step:** 2026-11-19 / SDD 0.7, step 5
- **Context:** Blizzard's pet bar buttons call `CastPetAction` from the game's own secure code. Addon code cannot rely on calling it in combat. The reference `SecureTemplates.lua` shows that `SecureActionButtonTemplate` has a built-in `pet` action type that casts a pet action from an `action` slot attribute.
- **Decision:** Build the pet bar from ten `SecureActionButtonTemplate` buttons with `type1 = "pet"` and `action = slot`, shown by a secure visibility state driver on `[@pet,exists]`. Right-click auto-cast uses a secure macro (`/petautocasttoggle <ability>`) because `TogglePetAutocast` is protected: an insecure call raised ADDON_ACTION_FORBIDDEN in the game. The macro text is set out of combat through `ns:AfterCombat`. The tooltip runs from an insecure script. Dragging and key bindings on the new buttons are left out.
- **Alternatives considered:** Copying Blizzard's `PetActionButtonTemplate`, which pulls in the Mainline action bar mixins and calls protected functions from addon code.
- **Requirement IDs affected:** CLU-09, CLU-13, CLU-16

## D-018 Secure pet buttons ignore the key-down option
- **Date / step:** 2026-11-19 / step 5
- **Context:** The secure action button template acts on the press when the game option "cast action keys on key down" is on. The pet bar buttons registered for the release only, so clicks did nothing.
- **Decision:** Set the attribute `useOnKeyDown = false` on every pet bar button so they act on the mouse release. Confirmed in game.
- **Alternatives considered:** Registering for both press and release, as Blizzard's action buttons do. Not needed for mouse-only buttons.
- **Requirement IDs affected:** CLU-09

## D-019 Action bars use Blizzard's slots, no paging, duration-object cooldowns
- **Date / step:** 2026-11-19 / SDD 0.8, step 6
- **Context:** The human wants the four action bars as 3 by 4 grids, with core button features first and no paging for bar 1 yet. The reference source gives the page numbers of the multi bars (right 3, left 4, bottom right 5, bottom left 6, 12 slots a page). The API documentation marks cooldown values as secret when cooldowns are restricted.
- **Decision:** Bar 1 is slots 1 to 12, bar 2 (bottom left) 61 to 72, bar 3 (bottom right) 49 to 60, bar 4 (right) 25 to 36. Buttons are `SecureActionButtonTemplate` with `type = "action"` and the `action` attribute set to the slot, with no button ID so the template uses the attribute. Cooldowns use `C_ActionBar.GetActionCooldownDuration` and `SetCooldownFromDurationObject` when they exist. Key bindings stay on the game's commands and the buttons only show the key text. The slot numbers are checked in game with `/ggg cluster bars`.
- **Alternatives considered:** Paging with a secure state driver, left for a later step. Per-button key bindings, left for a later step.
- **Requirement IDs affected:** CLU-11, CLU-17

## D-020 Hunter widgets are an experiment with a range probe first
- **Date / step:** 2026-11-19 / SDD 0.9, step 8
- **Context:** The human wants an ammo indicator and a visual range indicator in the player area and expects a lot of trial and error. The game has no call that returns the exact distance to a hostile target, only yes or no checks (interact distances, spell ranges).
- **Decision:** Build a first rough version from the checks the client offers: four bands in round 1 (melee from Raptor Strike, dead zone from the 9.9 yard interact check, ranged from Auto Shot, and far). Add `/ggg hunter range` to print every measurement the client gives, so the next iteration can use what really changes with distance. The widgets are placed through the new `Cluster:OnBuilt` hook. Party frames are postponed until the human has a group to test with.
- **Alternatives considered:** Waiting for exact distances. Not available. Designing the final look first. The human prefers to try and adjust.
- **Requirement IDs affected:** CLU-18, HUN-11..14

## D-021 Range bands come from item ranges and the Auto Shot rule
- **Date / step:** 2026-11-19 / SDD 0.10, step 8 round 2
- **Context:** In the game Raptor Strike reported "in range" at every distance, so the melee band was always lit. The Huntmaster addon already works on this client and uses an item range ladder plus Auto Shot. The ammo icon from the item lookup was also empty.
- **Decision:** Nine bands: melee, dead zone, 10, 15, 20, 25, 30, 35 yards and Max. The yard bands use `C_Item.IsItemInRange` with items of known reach. Melee needs Raptor Strike in range and Auto Shot out of range. Dead zone is inside about 20 yards with Auto Shot refusing. The ammo icon comes from `GetInventoryItemTexture` on the ammo slot. The human confirmed both work in game.
- **Alternatives considered:** Keeping the interact distance checks. They only give one yes or no step near 10 yards.
- **Requirement IDs affected:** HUN-11, HUN-12, HUN-13

## D-022 Hunter spell buttons are secure spell buttons that show only known spells
- **Date / step:** 2026-11-19 / SDD 0.10, step 9
- **Context:** The human wants buttons to set the Aspect and the Tracking type in the player area, and buttons for the pet actions (Call Pet, Revive Pet, Dismiss Pet, Feed Pet, Mend Pet, Tame Beast, Beast Training, Beast Lore) in the pet area. The player area had only about 20 px of free height left.
- **Decision:** Each button is a `SecureActionButtonTemplate` with `type = "spell"` and the spell name, so it casts the highest known rank and works in combat. A spell counts as known when the game returns data for its name. Unknown spells are hidden and the rest are packed from the left, only out of combat. The Mend Pet button casts on the pet and is one of three wide 30 px buttons (Call Pet, Mend Pet, Beast Training) in a row under the small pet row so they are easy to click. The Cluster main area grows by 20 px for one player row (aspects from the left, tracking from the right). The pet row sits under the pet bar. The human chose to add Call Pet. `/ggg hunter buttons` lists which names the game finds, because the spell names are unchecked on this client.
- **Alternatives considered:** Scanning the spellbook for aspects, left out because the names are enough and the scan differs between clients. Putting the rows beside the range widget, which left too little room.
- **Requirement IDs affected:** CLU-19 (proposed), HUN-15, HUN-16 (proposed)

## D-023 The shot timer is a glow over the range bar, driven by Auto Shot events
- **Date / step:** 2026-11-19 / SDD 0.10, step 10
- **Context:** The human wants a ranged shot timer in the player area, shown as a glow that sweeps over the range bar from left to right with the shot timing.
- **Decision:** A status bar glow and a bright edge sit over the range bar. A new cycle starts each time `UNIT_SPELLCAST_SUCCEEDED` reports Auto Shot (spell 75) for the player, and it lasts as long as the ranged speed from `UnitRangedDamage`. The glow is shown only while `START_AUTOREPEAT_SPELL` says Auto Shot is on. Your ranged speed is a secret value, so it only goes to a status bar. Whether the shot is ready is judged from the measured gap between two shots, so the bright edge shows from the second shot on. It is redrawn about 30 times a second while shown, which is the one place a faster tick than 0.1 s is used. Moving, haste changes and the half second wind-up are not modelled yet.
- **Alternatives considered:** Reading the wind-up from a cast bar event, left for a later round once the basic timing is checked in game.
- **Requirement IDs affected:** HUN-17 (proposed)

## D-024 The essential cooldowns are our own icon row from the Cooldown Manager's list
- **Date / step:** 2026-11-19 / SDD 0.10, step 11
- **Context:** The human wants the Essential Cooldowns frame in the player area, to the right of the ammo icon and count. A first try moved Blizzard's `EssentialCooldownViewer` into a holder. The move was accepted (parent and anchor were ours, the frame was shown with six icons) but the frame and its icons never got a screen position (`GetRect` and `GetCenter` returned nothing), so nothing was drawn. The client appears to hide that frame's geometry from addons.
- **Decision:** Draw our own row of icons in the holder. The list comes from the Essential Cooldowns frame's `GetCooldownIDs` when it exists, otherwise from `C_CooldownViewer.GetCooldownViewerCategorySet`. Each cooldown ID is turned into a spell with `C_CooldownViewer.GetCooldownViewerCooldownInfo` (the override spell when there is one). Icons show the spell texture, a cooldown swipe through the duration object API and a spell tooltip, and shrink to fit up to ten. Blizzard's own frame is left where it is, so the human can set the Cooldown Manager's visibility to hidden if the duplicate is not wanted. `/ggg hunter cooldowns` prints the list and what each ID resolves to.
- **Alternatives considered:** Re-anchoring Blizzard's frame in other ways, which could not be diagnosed because its position is hidden. Dropping the feature.
- **Requirement IDs affected:** HUN-18 (proposed)

## D-025 Managed default frames are told to stay hidden
- **Date / step:** 2026-11-19 / SDD 0.10, step 11
- **Context:** With hiding on, the Blizzard pet frame and the essential cooldowns frame stayed visible. Both are managed frames (`PlayerBottomManagedFrameTemplate` and `BottomManagedFrameTemplate`). Blizzard's layout code moves a managed frame back into its container whenever it is shown, which pulled them out of the hidden frame. The cooldowns frame was also not on the hide list at all.
- **Decision:** When hiding a default frame, set its `ignoreFramePositionManager` flag, remove it from the managed containers' `showingFrames` lists, move it to the hidden frame, and hook `SetParent` so that anything that moves it back is undone after combat. Modules that replace a default frame hand its name to `Cluster:ReplaceDefaultFrame`, and the Hunter cooldowns part does so for `EssentialCooldownViewer`. All of it applies only when `hideDefaults` is on.
- **Alternatives considered:** Hiding the frames with alpha 0, which leaves them taking mouse input and space in the layout.
- **Requirement IDs affected:** CLU-04, CLU-15
