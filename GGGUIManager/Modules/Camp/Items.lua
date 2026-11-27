local addonName, ns = ...

-- Camp: the item lists and the bag reading (SDD 7.3, CMP-04 to CMP-09, CMP-12). The lists are plain tables, so
-- adding a name or an ID is a one-line change. IDs and where they came from are in docs/IDS.md.

local Items = {}
ns.CampItems = Items

---------------------------------------------------------------------
-- The lists
---------------------------------------------------------------------
Items.HEARTHSTONE_IDS = { [6948] = true }
Items.HEARTHSTONE_NAMES = { ["hearthstone"] = true }
Items.BAG_IDS = { [211527] = true }
Items.BAG_NAMES = { ["cozy sleeping bag"] = true }

-- Campsite objects, in the order they are shown. The spell ID is what the placing item casts (from the camping
-- guides). Item IDs are not known yet, so a bag item counts when its name is exactly the object's name or when
-- the spell it casts is in this list. `/ggg camp scan` shows what the game reports so this list can be corrected.
Items.CAMPSITE = {
    { 818, "Basic Campfire" }, { 1283400, "Journeyman Campfire" }, { 1291341, "Expert Campfire" },
    { 1262978, "Cookie's Feast" }, { 1263067, "Iron Oven" },
    { 1230564, "Mana Well" }, { 1263005, "Fermenter" }, { 1263078, "Alchemy Laboratory" },
    { 1230171, "Sharpening Wheel" }, { 1263041, "Anvil" }, { 1263073, "Master Forge" },
    { 1230643, "Enchanted Lute" }, { 1263056, "Arcane Salvager" }, { 1263082, "Arcane Forge" },
    { 1230656, "Reagent Bot" }, { 1263034, "Repair Bot" }, { 1263083, "Anarchist's Workbench" },
    { 1230117, "First Aid Kit" }, { 1262996, "Toxin Study" }, { 1263001, "Plague Doctor's Laboratory" },
    { 1229745, "Fish Bowl" }, { 1262990, "Fishing Rack" }, { 1262998, "Fishing Hut" },
    { 1229705, "Incense Candle" }, { 1262980, "Greenhouse" }, { 1263070, "Seed Hybridizer" },
    { 1229432, "Camp Tent" }, { 1263031, "Tanning Rack" }, { 1263079, "Sewing Machine" },
    { 1230161, "Lodestone" }, { 1262975, "Rock Garden" }, { 1263071, "Molten Foundry" },
    { 1229517, "Camp Chair" }, { 1262985, "Field Guide" }, { 1262982, "Trapper's Workbench" },
    { 1263425, "Faction Banner" }, { 1263032, "Spinning Wheel" }, { 1263080, "Loom" },
}
-- A toy used on the campfire (a toy is used from the toy box, not from the bags). The ID is taken from the item's
-- Wowhead and WoWDB links on the Warcraft Wiki and is not yet checked on this client (docs/IDS.md).
Items.TOY_ID = 289439
Items.TOY_NAME = "Pouch of Violet Dust"

Items.CAMPSITE_ITEM_IDS = { -- item IDs seen in the game (docs/IDS.md), with the object name
    [278030] = "Scarlet Banner", [279967] = "Fish Bowl", [279968] = "First Aid Kit",
}

-- Words that mark a drink when nothing better says so (last resort, CMP-09).
Items.DRINK_WORDS = { "water", "juice", "tea", "wine", "ale", "milk", "brew", "cider", "coffee", "punch", "beer",
    "spirits", "nectar" }

local campsiteBySpell, campsiteByName = {}, {}
for index, entry in ipairs(Items.CAMPSITE) do
    campsiteBySpell[entry[1]] = index
    campsiteByName[entry[2]:lower()] = index
end

---------------------------------------------------------------------
-- Reading items
---------------------------------------------------------------------
local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-- name, minLevel, classID, subClassID, icon for an item, or nil while the game has not loaded it yet.
function Items.Info(itemID)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local ok, name, _, _, _, minLevel, _, _, _, _, icon, _, classID, subClassID = pcall(get, itemID)
    if not ok or not name then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
        return nil
    end
    return { name = name, minLevel = minLevel or 0, classID = classID, subClassID = subClassID, icon = icon }
end

-- The spell name and ID an item casts when used.
function Items.UseSpell(itemID)
    if not (C_Item and C_Item.GetItemSpell) then return nil end
    local ok, name, spellID = pcall(C_Item.GetItemSpell, itemID)
    if ok then return name, spellID end
    return nil
end

-- All the tooltip text of a bag item in lower case, or nil when the game gives none or hides it.
function Items.TooltipText(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if not (ok and type(data) == "table" and type(data.lines) == "table") then return nil end
    local parts = {}
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" and not IsSecret(text) then parts[#parts + 1] = text:lower() end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, "\n")
end

-- The bag contents as one entry for each item ID: { id, count, bag, slot }. Needs no combat check.
function Items.Bags()
    local byID, list = {}, {}
    local lastBag = (NUM_BAG_SLOTS or 4) + 1 -- the extra bag index is the reagent bag, if the client has one
    for bag = 0, lastBag do
        local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if type(info) == "table" and info.itemID and not IsSecret(info.itemID) then
                local entry = byID[info.itemID]
                if not entry then
                    entry = { id = info.itemID, count = 0, bag = bag, slot = slot }
                    byID[info.itemID] = entry
                    list[#list + 1] = entry
                end
                entry.count = entry.count + (info.stackCount or 1)
            end
        end
    end
    return list
end

---------------------------------------------------------------------
-- What an item is for
---------------------------------------------------------------------
-- Returns "hearthstone", "bag", "campsite" (and the order number) or nil.
function Items.Special(entry)
    if Items.HEARTHSTONE_IDS[entry.id] then return "hearthstone" end
    if Items.BAG_IDS[entry.id] then return "bag" end
    local known = Items.CAMPSITE_ITEM_IDS[entry.id]
    if known then return "campsite", campsiteByName[known:lower()] or 1000 end
    local info = Items.Info(entry.id)
    if info then
        local lower = info.name:lower()
        if Items.HEARTHSTONE_NAMES[lower] then return "hearthstone" end
        if Items.BAG_NAMES[lower] then return "bag" end
        if campsiteByName[lower] then return "campsite", campsiteByName[lower] end
        -- The item that places an object can carry the name with "Kit" on the end ("Journeyman Campfire Kit").
        local bare = lower:match("^(.-)%s+kit$")
        if bare and campsiteByName[bare] then return "campsite", campsiteByName[bare] end
    end
    local _, spellID = Items.UseSpell(entry.id)
    if spellID and campsiteBySpell[spellID] then return "campsite", campsiteBySpell[spellID] end
    return nil
end

local function HasWord(text, word)
    return text:find("%f[%a]" .. word .. "%f[%A]") ~= nil
end

local cache = {} -- [itemID] = role or false, kept only when the tooltip decided it

-- Returns "food", "drink" or nil, and the source that decided it ("tooltip", "spell" or "name").
function Items.Classify(entry)
    if cache[entry.id] ~= nil then return cache[entry.id] or nil, "tooltip" end
    local info = Items.Info(entry.id)
    if not info then return nil, "not loaded" end
    if info.classID ~= 0 or info.subClassID ~= 5 then -- Consumable, Food and Drink
        cache[entry.id] = false
        return nil, "class"
    end

    local text = Items.TooltipText(entry.bag, entry.slot)
    if text then
        local eats, drinks = text:find("eating", 1, true), text:find("drinking", 1, true)
        local role
        if eats then role = "food" elseif drinks then role = "drink" end
        if role then
            cache[entry.id] = role
            return role, "tooltip"
        end
        -- A readable tooltip with neither word is not food or drink to sit and consume (for example a
        -- transformation treat), so it is left out.
        cache[entry.id] = false
        return nil, "no eating or drinking in the tooltip"
    end

    local spellName = Items.UseSpell(entry.id)
    if spellName then
        local lower = spellName:lower()
        if lower == "drink" then return "drink", "spell" end
        if lower == "food" then return "food", "spell" end
    end

    local lowerName = info.name:lower()
    for _, word in ipairs(Items.DRINK_WORDS) do
        if HasWord(lowerName, word) then return "drink", "name" end
    end
    return "food", "name"
end

-- The best food and the best drink: highest required level first, then the larger stack.
function Items.Best(entries)
    local best = {}
    for _, entry in ipairs(entries) do
        local role = Items.Classify(entry)
        if role then
            local info = Items.Info(entry.id)
            local level = info and info.minLevel or 0
            local current = best[role]
            if not current or level > current.level or (level == current.level and entry.count > current.entry.count) then
                best[role] = { entry = entry, level = level }
            end
        end
    end
    return best.food and best.food.entry, best.drink and best.drink.entry
end
