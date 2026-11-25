local addonName, ns = ...
local Bags = ns.Bags

-- A list of items that always sit in fixed backpack slots, in the order you choose.
-- Item 1 goes in backpack slot 1, item 2 in slot 2, and so on. The Bags module moves them there
-- whenever your bags change. If you don't have an item, its slot is simply left to whatever is there.

local Pinned = {}
Bags.Pinned = Pinned

local MAX_MOVES = 40 -- safety limit per run of moves, so a failed move can never loop forever
local moves = 0
local pausedUntil = 0

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local function List()
    Bags.db.pinned = Bags.db.pinned or {}
    return Bags.db.pinned
end

local function BackpackSize()
    return C_Container.GetContainerNumSlots(0) or 16
end

local function IndexOf(itemID)
    for i, id in ipairs(List()) do
        if id == itemID then return i end
    end
end

---------------------------------------------------------------------
-- Moving items
---------------------------------------------------------------------
-- Finds a copy of the item anywhere in your bags except backpack slot `skipSlot`.
local function FindItem(itemID, skipSlot)
    for bag = 0, Bags.LAST_BAG do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            if not (bag == 0 and slot == skipSlot) then
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == itemID then return bag, slot, info end
            end
        end
    end
end

-- Makes one move toward the right arrangement. The next one happens when the bags report the change.
function Pinned:Arrange()
    local list = List()
    if #list == 0 or InCombatLockdown() or CursorHasItem() or GetTime() < pausedUntil then return end

    local size = BackpackSize()
    for i, itemID in ipairs(list) do
        if i > size then break end
        local here = C_Container.GetContainerItemInfo(0, i)
        if not (here and here.itemID == itemID) then
            local bag, slot, info = FindItem(itemID, i)
            if bag and not info.isLocked and not (here and here.isLocked) then
                -- A swap sends the item that was in the way to the other bag, so that bag must be able to hold it.
                local _, family = C_Container.GetContainerNumFreeSlots(bag)
                local canSwap = not here or not family or family == 0
                if canSwap then
                    if moves >= MAX_MOVES then return end
                    moves = moves + 1
                    C_Container.PickupContainerItem(bag, slot)
                    C_Container.PickupContainerItem(0, i)
                    -- If something was in the way it is now on the cursor. Put it where our item came from.
                    if CursorHasItem() then C_Container.PickupContainerItem(bag, slot) end
                    if CursorHasItem() then ClearCursor() end
                    return
                end
            end
        end
    end
    moves = 0 -- everything is in place
end

-- Holds off arranging for a few seconds, for example while the game's own Sort button works.
function Pinned:Pause(seconds)
    pausedUntil = GetTime() + seconds
    C_Timer.After(seconds + 0.2, function() Pinned:Arrange() end)
end

---------------------------------------------------------------------
-- Editing the list
---------------------------------------------------------------------
function Pinned:Add(itemID)
    local list = List()
    if not itemID then return false end
    if IndexOf(itemID) then
        print(ns.PREFIX .. "that item is already pinned")
        return false
    end
    if #list >= BackpackSize() then
        print(ns.PREFIX .. "the backpack is full of pinned items")
        return false
    end
    list[#list + 1] = itemID
    moves = 0
    self:Refresh()
    self:Arrange()
    return true
end

function Pinned:Remove(index)
    table.remove(List(), index)
    self:Refresh()
end

function Pinned:Move(index, delta)
    local list = List()
    local other = index + delta
    if other < 1 or other > #list then return end
    list[index], list[other] = list[other], list[index]
    moves = 0
    self:Refresh()
    self:Arrange()
end

-- Takes an item link, "item:1234" or a plain number.
function Pinned:ItemIDFromText(text)
    if not text then return nil end
    local id = text:match("item:(%d+)") or text:match("^%s*(%d+)%s*$")
    return id and tonumber(id) or nil
end

---------------------------------------------------------------------
-- The window
---------------------------------------------------------------------
local ROW_HEIGHT = 28
local frame, dropButton
local rows = {}

local function MakeRow(i)
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(290, ROW_HEIGHT - 2)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -72 - (i - 1) * ROW_HEIGHT)

    row.number = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.number:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.number:SetWidth(20)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", row, "LEFT", 24, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(120)
    row.name:SetJustifyH("LEFT")

    local function SmallButton(text, width, x, onClick)
        local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        b:SetSize(width, 22)
        b:SetPoint("LEFT", row, "LEFT", x, 0)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end
    SmallButton("Up", 30, 180, function() Pinned:Move(row.index, -1) end)
    SmallButton("Dn", 30, 212, function() Pinned:Move(row.index, 1) end)
    SmallButton("X", 24, 246, function() Pinned:Remove(row.index) end)

    return row
end

function Pinned:Refresh()
    if not frame then return end
    local list = List()

    for i, itemID in ipairs(list) do
        rows[i] = rows[i] or MakeRow(i)
        local row = rows[i]
        row.index = i
        row.number:SetText(i)
        local _, _, _, _, icon = GetItemInfoInstant(itemID)
        row.icon:SetTexture(icon)
        row.name:SetText(GetItemInfo(itemID) or ("item " .. itemID))
        row:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end

    frame:SetHeight(72 + math.max(#list, 1) * ROW_HEIGHT + 16)
end

local function AddFromCursor()
    local kind, itemID = GetCursorInfo()
    if kind == "item" then
        ClearCursor() -- the item goes back to where it came from
        Pinned:Add(itemID)
    end
end

local function BuildFrame()
    frame = CreateFrame("Frame", "GGGUIManagerBagsPinned", UIParent, "BackdropTemplate")
    frame:SetSize(322, 200)
    frame:SetPoint("CENTER", UIParent, "CENTER", -300, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
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
    title:SetText("Pinned items")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    dropButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    dropButton:SetSize(290, 26)
    dropButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -38)
    dropButton:SetText("Drop an item here to pin it")
    dropButton:SetScript("OnReceiveDrag", AddFromCursor)
    dropButton:SetScript("OnClick", AddFromCursor)

    frame:SetScript("OnEvent", function() if frame:IsShown() then Pinned:Refresh() end end)
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:SetScript("OnShow", function() Pinned:Refresh() end)
end

function Pinned:Toggle()
    if not frame then BuildFrame() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
