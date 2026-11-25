local addonName, ns = ...
local Bags = ns.Bags

-- Remembers which items are new to you, so the glow survives a reload and doesn't light up everything.
--
-- For each character it saves how many of each item you had the last time we looked. When the count
-- goes up, that item is marked new. It stays new until you hover over it, even across reloads.
-- Moving or splitting stacks doesn't change the totals, so it isn't treated as new.

local NewItems = {}
Bags.NewItems = NewItems

local function Record()
    Bags.db.chars = Bags.db.chars or {}
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    local rec = Bags.db.chars[key]
    if not rec then
        rec = {}
        Bags.db.chars[key] = rec
    end
    rec.new = rec.new or {}
    return rec
end

local function CountItems()
    local counts = {}
    for bag = 0, Bags.LAST_BAG do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    return counts
end

-- Looks at the bags and marks anything you now have more of than before.
-- With quiet = true it only updates the saved totals and marks nothing. That is used at login and reload.
function NewItems:Scan(quiet)
    local rec = Record()
    local counts = CountItems()

    if quiet or not rec.known then
        rec.known = counts
        return
    end

    for itemID, count in pairs(counts) do
        if count > (rec.known[itemID] or 0) then
            rec.new[itemID] = true
        end
    end
    -- If an item is gone completely, forget that it was new.
    for itemID in pairs(rec.new) do
        if not counts[itemID] then rec.new[itemID] = nil end
    end
    rec.known = counts
end

function NewItems:IsNew(itemID)
    return itemID ~= nil and Record().new[itemID] == true
end

function NewItems:MarkSeen(itemID)
    if itemID then Record().new[itemID] = nil end
end
