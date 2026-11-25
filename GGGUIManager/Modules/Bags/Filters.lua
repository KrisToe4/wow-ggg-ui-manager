local addonName, ns = ...
local Bags = ns.Bags

-- A window for choosing which items each bag should hold.
--
-- These are the game's own bag filters, the same ones as Blizzard's right-click bag menu.
-- The game saves them for the character. Pressing Sort in the bag window moves matching items
-- into the bag that is assigned to them.

local Config = {}
Bags.Config = Config

local frame
local rows = {} -- rows[bag] = { name = fontString, boxes = { [key] = checkButton } }

-- The item types a bag can be assigned to. Only one can be active per bag.
local CLASS_FILTERS = {
    { key = "ClassEquipment", label = BAG_FILTER_EQUIPMENT or "Equipment" },
    { key = "ClassConsumables", label = BAG_FILTER_CONSUMABLES or "Consumables" },
    { key = "ClassProfessionGoods", label = BAG_FILTER_PROFESSION_GOODS or "Trade Goods" },
    { key = "ClassJunk", label = BAG_FILTER_JUNK or "Junk" },
    { key = "ClassQuestItems", label = BAG_FILTER_QUEST_ITEMS or "Quest Items" },
    { key = "ClassReagents", label = BAG_FILTER_REAGENTS or "Reagents" },
}

-- Extra per-bag switches.
local OPTION_FILTERS = {
    { key = "DisableAutoSort", label = "Skip when sorting" },
    { key = "ExcludeJunkSell", label = "Don't sell junk" },
    -- This module's own switch, kept in the saved settings rather than in the game. Needs no game support.
    { key = "HideInView", label = "Hide from view", own = true },
}

local columns = {} -- the filters this client actually has, in display order
local classKeys = {}

local function Flag(key)
    return Enum and Enum.BagSlotFlags and Enum.BagSlotFlags[key]
end

function Config.IsSupported()
    return C_Container ~= nil and C_Container.GetBagSlotFlag ~= nil
        and C_Container.SetBagSlotFlag ~= nil and Flag("ClassEquipment") ~= nil
end

---------------------------------------------------------------------
-- Reading and writing flags
---------------------------------------------------------------------
local function IsSet(bag, key)
    if key == "HideInView" then
        return Bags.IsBagHidden(bag)
    end
    if key == "DisableAutoSort" and bag == 0 and C_Container.GetBackpackAutosortDisabled then
        return C_Container.GetBackpackAutosortDisabled() and true or false
    end
    return C_Container.GetBagSlotFlag(bag, Flag(key)) and true or false
end

local function SetFlag(bag, key, value)
    if key == "HideInView" then
        Bags.db.hiddenBags[bag] = value or nil
        Bags:LayoutChanged()
        return
    end
    if key == "DisableAutoSort" and bag == 0 and C_Container.SetBackpackAutosortDisabled then
        C_Container.SetBackpackAutosortDisabled(value)
    else
        C_Container.SetBagSlotFlag(bag, Flag(key), value)
    end
end

-- Used by the junk seller: bags marked "Don't sell junk" are skipped.
function Config.IsJunkSellExcluded(bag)
    if not (C_Container and C_Container.GetBagSlotFlag) then return false end
    local flag = Flag("ExcludeJunkSell")
    if not flag then return false end
    return C_Container.GetBagSlotFlag(bag, flag) and true or false
end

local function OnCheckClicked(box)
    local bag, key = box.bag, box.key
    local checked = box:GetChecked()
    checked = (checked == true or checked == 1)

    if checked and classKeys[key] then
        -- A bag holds one item type, so turn the others off first.
        for otherKey in pairs(classKeys) do
            if otherKey ~= key and IsSet(bag, otherKey) then
                SetFlag(bag, otherKey, false)
            end
        end
    end

    SetFlag(bag, key, checked)
    Config:Refresh()
end

---------------------------------------------------------------------
-- The window
---------------------------------------------------------------------
local NAME_WIDTH = 120
local COLUMN_WIDTH = 66
local ROW_HEIGHT = 30
local HEADER_HEIGHT = 40
local TOP = 70

local function BagLabel(bag)
    if bag == 0 then return BACKPACK_TOOLTIP or "Backpack" end
    return (C_Container.GetBagName and C_Container.GetBagName(bag)) or ("Bag " .. bag)
end

local function Build()
    local supported = Config.IsSupported()
    if supported then
        for _, filter in ipairs(CLASS_FILTERS) do
            if Flag(filter.key) then
                columns[#columns + 1] = filter
                classKeys[filter.key] = true
            end
        end
    end
    for _, filter in ipairs(OPTION_FILTERS) do
        if filter.own or (supported and Flag(filter.key)) then
            columns[#columns + 1] = filter
        end
    end

    local lastBag = NUM_BAG_SLOTS or 4
    local width = 30 + NAME_WIDTH + #columns * COLUMN_WIDTH
    local height = TOP + HEADER_HEIGHT + (lastBag + 1) * ROW_HEIGHT + 20

    frame = CreateFrame("Frame", "GGGUIManagerBagsFilters", UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnShow", function() Config:Refresh() end)
    tinsert(UISpecialFrames, "GGGUIManagerBagsFilters")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("Bag Filters")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    local help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOP", title, "BOTTOM", 0, -6)
    help:SetWidth(width - 40)
    if supported then
        help:SetText("Tick what each bag should hold, then press Sort in the bag window.")
    else
        help:SetText("This game client has no bag filters. You can still hide bags from the bag window.")
    end

    -- Column headings.
    for i, filter in ipairs(columns) do
        local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header:SetSize(COLUMN_WIDTH - 4, HEADER_HEIGHT)
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", 20 + NAME_WIDTH + (i - 1) * COLUMN_WIDTH + 2, -TOP)
        header:SetJustifyV("BOTTOM")
        header:SetText(filter.label)
    end

    -- One row per bag.
    for bag = 0, lastBag do
        local y = -(TOP + HEADER_HEIGHT + bag * ROW_HEIGHT)
        local row = { boxes = {} }

        row.name = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y - 7)
        row.name:SetWidth(NAME_WIDTH - 6)
        row.name:SetJustifyH("LEFT")

        for i, filter in ipairs(columns) do
            local box = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
            box:SetSize(26, 26)
            box:SetPoint("TOP", frame, "TOPLEFT", 20 + NAME_WIDTH + (i - 1) * COLUMN_WIDTH + COLUMN_WIDTH / 2, y)
            box.bag = bag
            box.key = filter.key
            box:SetScript("OnClick", OnCheckClicked)
            row.boxes[filter.key] = box
        end

        rows[bag] = row
    end

    -- Keep the window up to date if the filters change somewhere else.
    local events = CreateFrame("Frame")
    pcall(events.RegisterEvent, events, "BAG_SLOT_FLAGS_UPDATED")
    pcall(events.RegisterEvent, events, "BAG_CONTAINER_UPDATE")
    events:SetScript("OnEvent", function()
        if frame:IsShown() then Config:Refresh() end
    end)
end

---------------------------------------------------------------------
-- Public functions
---------------------------------------------------------------------
function Config:Refresh()
    if not frame or not columns[1] then return end

    for bag, row in pairs(rows) do
        local hasBag = (C_Container.GetContainerNumSlots(bag) or 0) > 0
        row.name:SetText(hasBag and BagLabel(bag) or "(no bag)")
        row.name:SetTextColor(hasBag and 1 or 0.5, hasBag and 1 or 0.5, hasBag and 1 or 0.5)

        for key, box in pairs(row.boxes) do
            -- The backpack can't be assigned an item type, only the two switches.
            local usable = hasBag and not (classKeys[key] and bag == 0)
            if usable then
                box:Enable()
                box:SetChecked(IsSet(bag, key))
            else
                box:SetChecked(false)
                box:Disable()
            end
        end
    end
end

function Config:Toggle()
    if not frame then
        Build()
    end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
