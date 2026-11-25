local addonName, ns = ...

-- Bags: a single combined bag window, plus junk selling. This is the BagBuddy addon turned into a module and kept
-- essentially the same (SDD module Bags). The window is in Window.lua, the bag filters in Filters.lua, items kept
-- in fixed backpack slots in Pinned.lua, items marked for sale in SellList.lua and the new item memory in
-- NewItems.lua. This file holds the module itself, the saved settings, the shared helpers, junk selling and the
-- commands.
--
-- /ggg bags              open or close the bag window (also /bb and /bagbuddy)
-- /ggg bags filters      choose what each bag holds
-- and the other commands listed by /ggg bags help.

local Bags = {}
ns:RegisterModule("Bags", Bags)
ns.Bags = Bags
Bags.active = false

local defaults = {
    autoSell = true,
    hiddenBags = {}, -- [bagID] = true for bags kept out of the combined window
    pinned = {}, -- ordered itemIDs kept in backpack slots 1, 2, 3...
    sellList = {}, -- [itemID] = true for items sold at vendors along with the junk
    chars = {}, -- per-character record of which items are new (see NewItems.lua)
    bagPoint = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -90, 100 },
}

-- The last bag ID to scan. 0 is the backpack, 1-4 are bags, 5 is the reagent bag if the client has one.
Bags.LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

function Bags.MoneyString(copper)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper)
    end
    return GetCoinTextureString(copper)
end

function Bags.IsBagHidden(bag)
    return Bags.db ~= nil and Bags.db.hiddenBags ~= nil and Bags.db.hiddenBags[bag] == true
end

-- Counts total and free slots in the bags shown in the combined window.
function Bags.CountSlots()
    local total, free = 0, 0
    for bag = 0, Bags.LAST_BAG do
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots and slots > 0 and not Bags.IsBagHidden(bag) then
            total = total + slots
            free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
        end
    end
    return total, free
end

---------------------------------------------------------------------
-- Settings from the BagBuddy addon
---------------------------------------------------------------------
-- BagBuddyDB is listed as a saved variable of this addon too, so the game loads it even while BagBuddy itself is
-- switched off. The first time this module starts, the settings are copied over once. BagBuddyDB itself is never
-- changed.
local IMPORT_KEYS = { "autoSell", "hiddenBags", "pinned", "sellList", "chars", "bagPoint" }

local function CopyTable(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, inner in pairs(value) do copy[key] = CopyTable(inner) end
    return copy
end

local function ImportBagBuddy(settings)
    if settings.imported then return end
    if type(BagBuddyDB) ~= "table" then return end -- nothing saved by BagBuddy, nothing to bring over
    for _, key in ipairs(IMPORT_KEYS) do
        if BagBuddyDB[key] ~= nil then settings[key] = CopyTable(BagBuddyDB[key]) end
    end
    settings.imported = true
    print(ns.PREFIX .. "Bags: brought over your BagBuddy settings (pinned items, sell list, hidden bags).")
end

---------------------------------------------------------------------
-- Junk (grey items)
---------------------------------------------------------------------
-- Calls callback(bag, slot, info, sellPrice) for each grey item with a vendor value.
local function ForEachJunk(callback)
    for bag = 0, Bags.LAST_BAG do
        -- Bags marked "Don't sell junk" in the filters window are skipped.
        if not Bags.Config.IsJunkSellExcluded(bag) then
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
                    local sellPrice = select(11, GetItemInfo(info.hyperlink)) or 0
                    if sellPrice > 0 then
                        callback(bag, slot, info, sellPrice)
                    end
                end
            end
        end
    end
end

local function SellJunk()
    local count, copper = 0, 0
    ForEachJunk(function(bag, slot, info, sellPrice)
        count = count + (info.stackCount or 1)
        copper = copper + sellPrice * (info.stackCount or 1)
        C_Container.UseContainerItem(bag, slot) -- sells it while a vendor window is open
    end)
    if count > 0 then
        print(ns.PREFIX .. ("sold %d junk items for %s"):format(count, Bags.MoneyString(copper)))
    end
end

local function ListJunk()
    local count, copper = 0, 0
    ForEachJunk(function(bag, slot, info, sellPrice)
        local n = info.stackCount or 1
        count = count + n
        copper = copper + sellPrice * n
        print(("  %s x%d"):format(info.hyperlink, n))
    end)
    print(ns.PREFIX .. ("%d junk items worth %s"):format(count, Bags.MoneyString(copper)))
end

---------------------------------------------------------------------
-- Module functions
---------------------------------------------------------------------
local function IsBagBuddyRunning()
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return isLoaded and isLoaded("BagBuddy") and true or false
end

function Bags:Init(settings)
    Bags.db = settings
    for key, value in pairs(defaults) do
        if settings[key] == nil then settings[key] = CopyTable(value) end
    end
    if IsBagBuddyRunning() then
        -- Both would replace the bag window and fight over it, so this one stays out of the way.
        Bags.blocked = true
        print(ns.PREFIX .. "Bags: the BagBuddy addon is running, so the Bags module stays off. Disable BagBuddy and /reload.")
        return true
    end
    ImportBagBuddy(settings)
    return true
end

function Bags:Enable()
    if Bags.blocked or Bags.active then return end
    Bags.active = true
    Bags:Start() -- builds the window and takes over the bag keys (Window.lua)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("MERCHANT_SHOW")
    events:SetScript("OnEvent", function(_, event, isLogin, isReload)
        if not Bags.active then return end
        if event == "PLAYER_ENTERING_WORLD" then
            -- At login or reload, take the current bags as already seen. Loading screens later on scan normally.
            Bags.NewItems:Scan(isLogin or isReload)
        elseif event == "MERCHANT_SHOW" then
            if Bags.db.autoSell then SellJunk() end
            Bags.SellList:Sell() -- items you marked, whether or not auto-sell of junk is on
        end
    end)
end

-- The bag keys and the replaced bag functions cannot be handed back safely while playing.
function Bags:Disable()
    if Bags.active then
        print(ns.PREFIX .. "Bags: turned off. The default bags come back after /reload.")
    end
end

---------------------------------------------------------------------
-- Commands: /ggg bags, and /bb or /bagbuddy as before
---------------------------------------------------------------------
local function HandleCommand(msg)
    if Bags.blocked then
        print(ns.PREFIX .. "Bags: the BagBuddy addon is running. Disable it and /reload first.")
        return
    end
    if not Bags.active then
        print(ns.PREFIX .. "Bags: the module is off. /ggg modules shows its state.")
        return
    end
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" then
        Bags:Toggle()
    elseif msg == "config" or msg == "filters" then
        Bags.Config:Toggle()
    elseif msg == "pinned" then
        Bags.Pinned:Toggle()
    elseif msg == "arrange" then
        Bags.Pinned:Arrange()
    elseif msg:match("^pin%s+") then
        -- pin [shift-click an item], or an item ID
        Bags.Pinned:Add(Bags.Pinned:ItemIDFromText(msg:match("^pin%s+(.+)")))
    elseif msg == "selllist" then
        Bags.SellList:ToggleWindow()
    elseif msg == "selllist print" then
        Bags.SellList:Print()
    elseif msg:match("^mark%s+") then
        -- mark [shift-click an item], or an item ID. Do it again to unmark.
        Bags.SellList:Toggle(Bags.SellList:ItemIDFromText(msg:match("^mark%s+(.+)")))
    elseif msg == "junk" then
        ListJunk()
    elseif msg == "sell" then
        Bags.db.autoSell = not Bags.db.autoSell
        print(ns.PREFIX .. "auto-sell junk is " .. (Bags.db.autoSell and "ON" or "OFF"))
    elseif msg == "reset" then
        Bags:ResetPosition()
        print(ns.PREFIX .. "bag window position reset")
    else
        print(ns.PREFIX .. "bags commands:")
        print("  /ggg bags   open or close the bag window")
        print("  /ggg bags filters   choose what each bag holds")
        print("  /ggg bags pinned   choose items to keep in fixed backpack slots")
        print("  /ggg bags pin [item]   pin an item (shift-click it, or give its ID)")
        print("  /ggg bags selllist   choose items to sell at vendors (also Ctrl + Alt + click an item)")
        print("  /ggg bags mark [item]   mark or unmark an item for sale")
        print("  /ggg bags junk   list grey items in your bags")
        print("  /ggg bags sell   toggle auto-selling junk at vendors")
        print("  /ggg bags reset   put the bag window back in the default spot")
        print("  /bb works the same as /ggg bags")
    end
end

ns:RegisterCommand("bags", HandleCommand, "the combined bag window (/ggg bags help)")

-- The old short commands, unless BagBuddy is running and owns them.
if not IsBagBuddyRunning() then
    SLASH_GGGUIMANAGERBAGS1 = "/bb"
    SLASH_GGGUIMANAGERBAGS2 = "/bagbuddy"
    SlashCmdList.GGGUIMANAGERBAGS = HandleCommand
end
