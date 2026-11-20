# IDS

Item and spell IDs gathered for modules, with where each came from. Check any ID in the game before relying on it
(shift-click an item in chat, or use the module's scan command). Last updated 2026-11-20.

## Camp module (SDD 7.3)

### Items

| Item | Item ID | Source | Status |
|---|---|---|---|
| Hearthstone | 6948 | Classic game data | Known from the game, not checked on this client |
| Cozy Sleeping Bag | 211527 | warcraft.wiki.gg and WarcraftTavern agree | Not checked in game |
| Scarlet Banner | 278030 | WarcraftTavern | Cosmetic, not checked in game |
| Fish Bowl | 279967 | `/ggg camp scan`, 2026-11-20 | Seen in game. Casts spell 1307245 |
| First Aid Kit | 279968 | `/ggg camp scan`, 2026-11-20 | Seen in game. Casts spell 1307244 |
| Unroll Bag (Cozy Sleeping Bag cast) | spell 429961 | `/ggg camp scan` | Seen in game |

### Campsite spells (from WarcraftTavern, "Camping Objects and Buffs")

These are spell IDs from the guides, not item IDs. The scan showed that the items cast different spells (the Fish Bowl
item casts 1307245, not the guide's 1229745), so these may be the placed object's spell and not the item's. The module
matches by item ID and exact name first. Item IDs for the campfires and objects are not published on the pages found. They come
from `/ggg camp scan` once the human has the items in the bags.

| Profession | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|
| Cooking (campfires) | Basic Campfire 818 | Journeyman Campfire 1283400 | Expert Campfire 1291341 |
| Cooking (other) | | Cookie's Feast 1262978 | Iron Oven 1263067 |
| Alchemy | Mana Well 1230564 | Fermenter 1263005 | Alchemy Laboratory 1263078 |
| Blacksmithing | Sharpening Wheel 1230171 | Anvil 1263041 | Master Forge 1263073 |
| Enchanting | Enchanted Lute 1230643 | Arcane Salvager 1263056 | Arcane Forge 1263082 |
| Engineering | Reagent Bot 1230656 | Repair Bot 1263034 | Anarchist's Workbench 1263083 |
| First Aid | First Aid Kit 1230117 | Toxin Study 1262996 | Plague Doctor's Laboratory 1263001 |
| Fishing | Fish Bowl 1229745 | Fishing Rack 1262990 | Fishing Hut 1262998 |
| Herbalism | Incense Candle 1229705 | Greenhouse 1262980 | Seed Hybridizer 1263070 |
| Leatherworking | Camp Tent 1229432 | Tanning Rack 1263031 | Sewing Machine 1263079 |
| Mining | Lodestone 1230161 | Rock Garden 1262975 | Molten Foundry 1263071 |
| Skinning | Camp Chair 1229517 | Field Guide 1262985 | Trapper's Workbench 1262982 |
| Tailoring | Faction Banner 1263425 | Spinning Wheel 1263032 | Loom 1263080 |

### Other

- Well-Rested aura from the Cozy Sleeping Bag: spell 429959.
- Placing a campfire is an item use with a ground targeting reticle (from the human, 2026-11-20).

### Still unknown

- Item IDs of the campfire and campsite object items.
- Food and drink item IDs. These are classified by the game's own data (see SDD CMP-09), not by a fixed list.

### Sources

- WarcraftTavern, Camping Objects and Buffs: https://www.warcrafttavern.com/forever/guides/camping-objects-buffs/
- WarcraftTavern, Cozy Sleeping Bag Guide: https://www.warcrafttavern.com/forever/guides/cozy-sleeping-bag/
- Warcraft Wiki, Cozy Sleeping Bag: https://warcraft.wiki.gg/wiki/Cozy_Sleeping_Bag
