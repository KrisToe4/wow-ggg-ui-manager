local addonName, ns = ...
local Bags = ns.Bags

-- A list of items you have marked for sale. Every copy of a marked item is sold at a vendor,
-- right along with the grey junk. Items in bags marked "Don't sell junk" in the filters window are left alone.
--
-- Ways to mark an item:
--   * Ctrl + Alt + left-click it in the bag window (do it again to unmark)
--   * drop it on the Sell list window
--   * /ggg bags mark [item link or ID]

local SellList = {}
Bags.SellList = SellList

local PREFIX = ns.PREFIX

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local function List()
    Bags.db.sellList = Bags.db.sellList or {}
    return Bags.db.sellList
end

function SellList:IsMarked(itemID)
    return itemID ~= nil and Bags.db ~= nil and Bags.db.sellList ~= nil and Bags.db.sellList[itemID] == true
end

local function IsPinned(itemID)
    for _, id in ipairs(Bags.db.pinned or {}) do
        if id == itemID then return true end
    end
    return false
end

local function Changed()
    SellList:Refresh()
    if Bags and Bags.Refresh then Bags:Refresh() end
end

function SellList:Add(itemID)
    if not itemID then return false end
    if List()[itemID] then
        print(PREFIX .. "that item is already on your sell list")
        return false
    end
    if IsPinned(itemID) then
        print(PREFIX .. "that item is pinned. Unpin it before marking it for sale.")
        return false
    end
    List()[itemID] = true
    Changed()
    return true
end

function SellList:Remove(itemID)
    List()[itemID] = nil
    Changed()
end

function SellList:Toggle(itemID)
    if not itemID then return end
    if self:IsMarked(itemID) then
        self:Remove(itemID)
        print(PREFIX .. ("%s will no longer be sold"):format(select(2, GetItemInfo(itemID)) or ("item " .. itemID)))
    elseif self:Add(itemID) then
        print(PREFIX .. ("%s will be sold at vendors"):format(select(2, GetItemInfo(itemID)) or ("item " .. itemID)))
    end
end

-- Takes an item link, "item:1234" or a plain number.
function SellList:ItemIDFromText(text)
    if not text then return nil end
    local id = text:match("item:(%d+)") or text:match("^%s*(%d+)%s*$")
    return id and tonumber(id) or nil
end

---------------------------------------------------------------------
-- Finding what to sell
---------------------------------------------------------------------
-- Calls callback(bag, slot, info, sellPrice) for each marked item that a vendor will buy.
function SellList:ForEach(callback)
    if next(List()) == nil then return end
    for bag = 0, Bags.LAST_BAG do
        if not Bags.Config.IsJunkSellExcluded(bag) then
            for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and List()[info.itemID] and not info.hasNoValue and not info.isLocked then
                    local sellPrice = select(11, GetItemInfo(info.hyperlink)) or 0
                    if sellPrice > 0 then
                        callback(bag, slot, info, sellPrice)
                    end
                end
            end
        end
    end
end

function SellList:Sell()
    local count, copper = 0, 0
    self:ForEach(function(bag, slot, info, sellPrice)
        local n = info.stackCount or 1
        count = count + n
        copper = copper + sellPrice * n
        C_Container.UseContainerItem(bag, slot) -- sells it while a vendor window is open
    end)
    if count > 0 then
        print(PREFIX .. ("sold %d marked items for %s"):format(count, Bags.MoneyString(copper)))
    end
end

function SellList:Print()
    local ids = {}
    for itemID in pairs(List()) do ids[#ids + 1] = itemID end
    if #ids == 0 then
        print(PREFIX .. "your sell list is empty.")
        return
    end
    print(PREFIX .. ("%d items on your sell list:"):format(#ids))
    for _, itemID in ipairs(ids) do
        print("  " .. (select(2, GetItemInfo(itemID)) or ("item " .. itemID)))
    end
end

---------------------------------------------------------------------
-- The window
---------------------------------------------------------------------
local ROW_HEIGHT = 26
local VISIBLE_ROWS = 10
local WIDTH = 322

local frame, countText
local rows = {}
local offset = 0
local sorted = {}

local function SortedIDs()
    local ids = {}
    for itemID in pairs(List()) do ids[#ids + 1] = itemID end
    table.sort(ids, function(a, b)
        local na = GetItemInfo(a) or tostring(a)
        local nb = GetItemInfo(b) or tostring(b)
        return na:lower() < nb:lower()
    end)
    return ids
end

local function MakeRow(i)
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(WIDTH - 32, ROW_HEIGHT - 2)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -72 - (i - 1) * ROW_HEIGHT)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(200)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    remove:SetSize(24, 22)
    remove:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    remove:SetText("X")
    remove:SetScript("OnClick", function()
        if row.itemID then SellList:Remove(row.itemID) end
    end)

    return row
end

function SellList:Refresh()
    if not frame or not frame:IsShown() then return end

    sorted = SortedIDs()
    offset = math.min(offset, math.max(0, #sorted - VISIBLE_ROWS))

    for i = 1, VISIBLE_ROWS do
        rows[i] = rows[i] or MakeRow(i)
        local row = rows[i]
        local itemID = sorted[offset + i]
        row.itemID = itemID
        if itemID then
            local _, _, _, _, icon = GetItemInfoInstant(itemID)
            row.icon:SetTexture(icon)
            row.name:SetText(select(2, GetItemInfo(itemID)) or ("item " .. itemID))
            row:Show()
        else
            row:Hide()
        end
    end

    countText:SetText(#sorted == 0 and "Nothing marked yet." or ("%d items marked. Scroll for more."):format(#sorted))
end

local function AddFromCursor()
    local kind, itemID = GetCursorInfo()
    if kind == "item" then
        ClearCursor() -- the item goes back to where it came from
        SellList:Add(itemID)
    end
end

local function BuildFrame()
    frame = CreateFrame("Frame", "GGGUIManagerBagsSellList", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, 72 + VISIBLE_ROWS * ROW_HEIGHT + 34)
    frame:SetPoint("CENTER", UIParent, "CENTER", -300, 40)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText("Items to sell")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    local drop = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    drop:SetSize(WIDTH - 32, 26)
    drop:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -38)
    drop:SetText("Drop an item here to sell it")
    drop:SetScript("OnReceiveDrag", AddFromCursor)
    drop:SetScript("OnClick", AddFromCursor)

    countText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 12)

    frame:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta * 3)
        SellList:Refresh()
    end)
    frame:SetScript("OnEvent", function() SellList:Refresh() end)
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:SetScript("OnShow", function() SellList:Refresh() end)
end

function SellList:ToggleWindow()
    if not frame then BuildFrame() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
