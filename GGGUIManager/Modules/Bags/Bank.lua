local addonName, ns = ...
local Bags = ns.Bags

-- Bank memory: the Bags module remembers what is in the player's bank each time the bank is open, and a
-- read only window shows it later. The window cannot move, use or sell anything. It is plain
-- frames, so it opens in combat and away from the bank.
--
-- What is remembered, for each character: the time it was seen, and for each bank bag its size and, for each slot
-- that holds an item, the item link, count, icon and quality. The bag IDs of the bank differ between client
-- versions, so the bank bags are found by looking at the IDs after the player's own bags while the bank is open
-- (bag -1 is the keyring, so it is left out). /ggg bags bank probe prints what was found.

local Bank = {}
Bags.Bank = Bank

local COLUMNS, VISIBLE_ROWS = 8, 10 -- 8 wide like the game's own bank window
local BUTTON_SIZE, SPACING = 37, 5
local PADDING_X, PADDING_TOP, FOOTER = 15, 75, 30
local EXTRA_BAGS = 12 -- how many bag IDs after the player's own bags are looked at
local MAX_NAME_SEARCH = 30

local isOpen = false -- the bank window of the game is open now
local frame, searchBox, freeText, seenText, rowsText
local buttons = {}
local entries = {} -- the flat list of slots shown: { data = <slot data or nil> }
local offset = 0 -- the first row shown
local searchText = ""

---------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------
local function Record()
    Bags.db.chars = Bags.db.chars or {}
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    local rec = Bags.db.chars[key]
    if not rec then
        rec = {}
        Bags.db.chars[key] = rec
    end
    return rec
end

local function BankBagIDs()
    -- Bag -1 is the keyring in this client (32 slots, always with you), so it is not part of the bank.
    local ids = {}
    for id = Bags.LAST_BAG + 1, Bags.LAST_BAG + EXTRA_BAGS do ids[#ids + 1] = id end
    return ids
end

---------------------------------------------------------------------
-- Scanning
---------------------------------------------------------------------
-- Reads the open bank into the saved record. Does nothing when no bank bag has slots, so a bank that has not
-- loaded yet never wipes the memory.
function Bank:Scan()
    if not isOpen then return end
    local bags, found = {}, false
    for _, bag in ipairs(BankBagIDs()) do
        local size = C_Container.GetContainerNumSlots(bag) or 0
        if size > 0 then
            local slots = {}
            for slot = 1, size do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.hyperlink then
                    slots[slot] = { link = info.hyperlink, count = info.stackCount or 1, icon = info.iconFileID,
                        quality = info.quality }
                end
            end
            bags[bag] = { size = size, slots = slots }
            found = true
        end
    end
    if found then
        Record().bank = { time = time(), bags = bags }
        if frame and frame:IsShown() then self:Refresh() end
    end
end

-- /ggg bags bank probe: which bag IDs the client gives slots for, and what was remembered.
function Bank:Probe()
    print(ns.PREFIX .. "bank probe")
    print(("  bank window is %s now, the player's own bags are 0 to %d"):format(isOpen and "open" or "closed", Bags.LAST_BAG))
    -- Every ID from -2 to 25 is checked, not only the ones the scan uses, so a bank held under another ID shows up.
    for bag = -2, 25 do
        local size = C_Container.GetContainerNumSlots(bag) or 0
        if size > 0 and (bag < 0 or bag > Bags.LAST_BAG) then
            local used, ids, free = 0, 0, C_Container.GetContainerNumFreeSlots(bag)
            for slot = 1, size do
                if C_Container.GetContainerItemInfo(bag, slot) then used = used + 1 end
                if C_Container.GetContainerItemID(bag, slot) then ids = ids + 1 end
            end
            print(("  bag %d: %d slots, %s free, %d with item info, %d with an item ID"):format(bag, size, tostring(free), used, ids))
        end
    end
    local saved = Record().bank
    if saved then
        local count, items = 0, 0
        for _ in pairs(saved.bags) do count = count + 1 end
        for _, bag in pairs(saved.bags) do for _ in pairs(bag.slots) do items = items + 1 end end
        print(("  remembered: %d bags, %d items, seen %s"):format(count, items, date("%Y-%m-%d %H:%M", saved.time)))
    else
        print("  nothing remembered yet. Open the bank once.")
    end
end

---------------------------------------------------------------------
-- The window
---------------------------------------------------------------------
local function ItemName(data)
    return data.link and data.link:match("%[(.-)%]") or ""
end

local function MakeButton(index)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    local column, row = (index - 1) % COLUMNS, math.floor((index - 1) / COLUMNS)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 10 + column * (BUTTON_SIZE + SPACING),
        -PADDING_TOP - row * (BUTTON_SIZE + SPACING))
    button.border = button:CreateTexture(nil, "BACKGROUND")
    button.border:SetAllPoints()
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -3, 3)
    button:SetScript("OnEnter", function(self)
        if not (self.data and self.data.link) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not pcall(GameTooltip.SetHyperlink, GameTooltip, self.data.link) then GameTooltip:Hide() return end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self)
        -- Shift-click links the item in chat and Ctrl-click previews it, as on any item. Nothing else happens.
        if self.data and self.data.link and HandleModifiedItemClick then
            pcall(HandleModifiedItemClick, self.data.link)
        end
    end)
    return button
end

local function BuildEntries()
    wipe(entries)
    local saved = Record().bank
    if not saved then return nil end
    local ids = {}
    for bag in pairs(saved.bags) do
        if bag >= 0 then ids[#ids + 1] = bag end -- an earlier version also saved the keyring (-1), which is not bank
    end
    table.sort(ids)
    for _, bag in ipairs(ids) do
        local info = saved.bags[bag]
        for slot = 1, info.size do entries[#entries + 1] = { data = info.slots[slot] } end
    end
    return saved
end

function Bank:Refresh()
    if not frame then return end
    local saved = BuildEntries()
    local total, used = #entries, 0
    for _, entry in ipairs(entries) do if entry.data then used = used + 1 end end

    local rows = math.max(1, math.ceil(total / COLUMNS))
    offset = math.max(0, math.min(offset, rows - VISIBLE_ROWS))

    for index = 1, COLUMNS * VISIBLE_ROWS do
        buttons[index] = buttons[index] or MakeButton(index)
        local button = buttons[index]
        local entry = entries[offset * COLUMNS + index]
        if entry then
            local data = entry.data
            button.data = data
            if data then
                button.icon:SetTexture(data.icon)
                button.icon:Show()
                button.count:SetText(data.count > 1 and data.count or "")
                local colour = data.quality and data.quality > 1 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[data.quality]
                if colour then
                    button.border:SetColorTexture(colour.r, colour.g, colour.b, 1)
                else
                    button.border:SetColorTexture(0.25, 0.25, 0.25, 1)
                end
                local match = searchText == "" or ItemName(data):lower():find(searchText, 1, true) ~= nil
                button:SetAlpha(match and 1 or 0.25)
            else
                button.icon:Hide()
                button.count:SetText("")
                button.border:SetColorTexture(0.1, 0.1, 0.1, 0.8)
                button:SetAlpha(searchText == "" and 1 or 0.25)
            end
            button:Show()
        else
            button.data = nil
            button:Hide()
        end
    end

    if saved then
        freeText:SetText(("Free: %d/%d"):format(total - used, total))
        seenText:SetText("Seen " .. date("%Y-%m-%d %H:%M", saved.time))
        rowsText:SetText(rows > VISIBLE_ROWS and "Scroll with the mouse wheel" or "")
    else
        freeText:SetText("")
        seenText:SetText("Never seen. Open your bank once.")
        rowsText:SetText("")
    end
end

local function BuildFrame()
    local gridWidth = COLUMNS * BUTTON_SIZE + (COLUMNS - 1) * SPACING
    local gridHeight = VISIBLE_ROWS * BUTTON_SIZE + (VISIBLE_ROWS - 1) * SPACING
    frame = CreateFrame("Frame", "GGGUIManagerBagsBankMemory", UIParent, "BackdropTemplate")
    frame:SetSize(gridWidth + PADDING_X + 5, gridHeight + PADDING_TOP + FOOTER)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    local bagFrame = _G.GGGUIManagerBagsFrame
    if bagFrame then
        frame:SetPoint("BOTTOMRIGHT", bagFrame, "BOTTOMLEFT", -8, 0)
    else
        frame:SetPoint("CENTER")
    end
    frame:Hide()
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta * 2)
        Bank:Refresh()
    end)
    frame:SetScript("OnShow", function() Bank:Refresh() end)
    tinsert(UISpecialFrames, "GGGUIManagerBagsBankMemory") -- Escape closes it

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText("Bank (remembered)")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    searchBox = CreateFrame("EditBox", "GGGUIManagerBagsBankSearch", frame, "InputBoxTemplate")
    searchBox:SetSize(220, 20)
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -40)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(MAX_NAME_SEARCH)
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = (self:GetText() or ""):lower()
        Bank:Refresh()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", searchBox.ClearFocus)

    rowsText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rowsText:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)

    freeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    freeText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
    seenText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    seenText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
end

function Bank:Toggle()
    if not frame then BuildFrame() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
function Bank:Start()
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "BAG_UPDATE_DELAYED",
        "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED" }) do
        pcall(events.RegisterEvent, events, event) -- an event this client lacks is skipped (INV-08)
    end
    events:SetScript("OnEvent", function(_, event)
        if event == "BANKFRAME_OPENED" then
            isOpen = true
            C_Timer.After(0.5, function() pcall(Bank.Scan, Bank) end) -- the slots may need a moment to load
        elseif event == "BANKFRAME_CLOSED" then
            isOpen = false
        elseif isOpen then
            pcall(Bank.Scan, Bank)
        end
    end)
end
