# GGG UI Manager

Good Girl Gamer UI Manager. A main personal addon for managing the World of Warcraft interface, built for the WoW Forever client (Interface 16001).

The addon is a small shell with a module system. Features are added one module at a time, each planned in the design document before it is built.

## Status

Version 0.1.0. The shell loads, owns the saved data and answers `/ggg`. There are no feature modules yet. The product requirements are still to be written (see section 1.4 of the design document).

## Documents

| File | Purpose |
|---|---|
| [docs/SDD.md](docs/SDD.md) | The software design document. Requirements, invariants, module contract and the step plan |
| [docs/PROGRESS.md](docs/PROGRESS.md) | What each step delivered and how it was checked |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Recorded decisions and the reasons |
| [CLAUDE.md](CLAUDE.md) | Instructions for the coding agent |

## Install for development

The game loads the `GGGUIManager` folder, not the repository root. Link it into the game's AddOns folder so edits show up after a `/reload`. A junction needs no administrator rights. Run this in a Command Prompt, with the paths adjusted if yours differ:

```bat
mklink /J "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\GGGUIManager" "C:\Users\Kitten\Documents\source\WoW Addons\GGG-UI-Manager\GGGUIManager"
```

To remove the link later, delete the `GGGUIManager` entry in the AddOns folder. That removes only the link, not the repository.

## Use

| Command | What it does |
|---|---|
| `/ggg` or `/gggui` | Show the version and the command list |
| `/ggg modules` | List the registered modules and whether each is on |

## Check that it works

1. Start the game and log in. No error pop-ups should appear.
2. Type `/ggg`. You should see the version and the help list.
3. Type `/ggg modules`. You should see "no modules yet."
4. Type `/reload`. Again, no errors.
5. Log out. `GGGUIManagerDB` should now exist in `WTF\Account\<account>\SavedVariables\GGGUIManager.lua`.

## Working on it

Read the SDD sections the next step lists before changing anything. Each change is one step, ends with a step report, and updates `docs/PROGRESS.md` and `docs/DECISIONS.md`. Syntax-check Lua files after editing. The checker used so far is `luaparser`, installed in a Python virtual environment.
