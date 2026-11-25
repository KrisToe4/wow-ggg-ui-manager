local addonName, ns = ...

-- A single combined bag window that replaces Blizzard's combined bag.
-- Layout numbers (10 columns, 37px slots, 5px gaps) come from Blizzard's ContainerFrame code.

local Bags = ns.Bags

local COLUMNS = 10
local BUTTON_SIZE = 37
local SPACING = 5
local PADDING_X = 15 -- total horizontal padding around the grid
local PADDING_TOP = 75 -- title bar and search row above the grid
local FOOTER = 30 -- money and free-slot row below the grid
local RIGHT_INSET = 7

local frame, content, searchBox, moneyText, freeText
local bagParents = {} -- [bagID] = invisible frame whose ID is the bag ID (item buttons read it)
local pool = {} -- pool[bag][slot] = item button
local active = {} -- ordered list of buttons currently laid out
local layoutKey = "" -- describes the last layout so we only re-anchor when slots change
local searchText = ""
local needsLayout = false

---------------------------------------------------------------------
-- Item buttons
---------------------------------------------------------------------
local function CreateBagParent(bag)
    local parent = CreateFrame("Frame", "GGGUIManagerBagsBag" .. bag, content)
    parent:SetAllPoints(content)
    parent:SetID(bag)
    -- The stock item button template may ask its parent a few questions about itself.
    parent.GetBagID = function() return bag end
    parent.IsCombinedBagContainer = function() return true end
    parent.IsBackpack = function() return bag == 0 end
    parent.MatchesBagID = function(_, id) return id == bag end
    return parent
end

local function GetButton(bag, slot)
    pool[bag] = pool[bag] or {}
    local button = pool[bag][slot]
    if button then return button end

    bagParents[bag] = bagParents[bag] or CreateBagParent(bag)
    button = CreateFrame("ItemButton", "GGGUIManagerBagsItem" .. bag .. "_" .. slot, bagParents[bag],
        "ContainerFrameItemButtonTemplate, SecureActionButtonTemplate")
    button:SetID(slot)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button.bbBag = bag
    button.bbSlot = slot

    -- Using an item (right-click) is a protected action in combat. Addon code can't do it, but the game's
    -- secure "item" action can, the same way action buttons do. It always points at this bag and slot.
    -- Clicks with Shift, Ctrl or Alt held are turned off for it; those go through Blizzard's handler instead.
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- The secure click handler ignores mouse-up when "use on key down" is on, so tell it to act on mouse-up.
    -- Don't set the OnClick script from here: a script set by addon code runs tainted and can't use items.
    button:SetAttribute("useOnKeyDown", false)
    -- "type2" (the right-click action) is switched on in UpdateButton only while the slot holds an item.
    -- A "/use bag slot" macro, not the "item" action: the item action equips gear directly and never hands
    -- the item to a spell that is waiting for a target (Disenchant), while /use does both.
    button:SetAttribute("macrotext", "/use " .. bag .. " " .. slot)
    for _, modifier in ipairs({ "shift-", "ctrl-", "alt-", "ctrl-shift-", "alt-shift-", "alt-ctrl-", "alt-ctrl-shift-" }) do
        button:SetAttribute(modifier .. "type2", "noop")
        button:SetAttribute(modifier .. "type1", "noop")
    end

    -- Everything else about a click is still Blizzard's own handler (picking up, splitting, linking, dressing up).
    -- It runs from PreClick, so it happens just before the secure action.
    local blizzardOnClick = button.OnClick
    button.OnClick = function(self, mouseButton, down)
        -- The real click script passes `down`; drag handlers call this without it. Ignore the former.
        if down ~= nil then return end
        blizzardOnClick(self, mouseButton)
    end
    button:SetScript("PreClick", function(self, mouseButton)
        -- Ctrl + Alt + left-click marks or unmarks the item for selling at vendors.
        if mouseButton == "LeftButton" and IsControlKeyDown() and IsAltKeyDown() and not IsShiftKeyDown()
            and not CursorHasItem() then
            local info = C_Container.GetContainerItemInfo(self.bbBag, self.bbSlot)
            if info then Bags.SellList:Toggle(info.itemID) end
            return
        end
        local modified = IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
        if mouseButton == "RightButton" and not modified then return end -- the secure action uses the item
        if mouseButton == "LeftButton" and not modified and self.bbTargeting then return end -- a spell is targeting
        blizzardOnClick(self, mouseButton)
    end)

    -- Our own glows: blue for new items (Blizzard's is switched off in UpdateButton), green for quest items.
    local function MakeGlow(r, g, b)
        local glow = button:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(r, g, b, 0.9)
        glow:SetSize(BUTTON_SIZE * 1.8, BUTTON_SIZE * 1.8)
        glow:SetPoint("CENTER")
        glow:Hide()
        return glow
    end
    button.bbGlow = MakeGlow(0.3, 0.6, 1)
    button.bbQuestGlow = MakeGlow(0.2, 1, 0.2)

    -- Bright overlay shown while you hover this slot's bag on the bag bar.
    local hover = button:CreateTexture(nil, "OVERLAY")
    hover:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    hover:SetBlendMode("ADD")
    hover:SetAllPoints()
    hover:Hide()
    button.bbHover = hover

    -- Small gold coin in the corner of items marked for sale.
    local coin = button:CreateTexture(nil, "OVERLAY", nil, 2)
    coin:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    coin:SetSize(14, 14)
    coin:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    coin:Hide()
    button.bbSellMark = coin

    -- Hovering an item means you've seen it, so it stops glowing.
    button:HookScript("OnEnter", function(self)
        local info = C_Container.GetContainerItemInfo(self.bbBag, self.bbSlot)
        if info and Bags.NewItems:IsNew(info.itemID) then
            Bags.NewItems:MarkSeen(info.itemID)
            Bags:Refresh()
        end
    end)

    pool[bag][slot] = button
    return button
end

-- Blizzard's buttons can light up their own "new item" glow. Keep it off so only ours shows.
local function HideBlizzardNewGlow(button)
    if button.NewItemTexture then button.NewItemTexture:Hide() end
    if button.BattlepayItemTexture then button.BattlepayItemTexture:Hide() end
    if button.flashAnim and button.flashAnim:IsPlaying() then button.flashAnim:Stop() end
    if button.newitemglowAnim and button.newitemglowAnim:IsPlaying() then button.newitemglowAnim:Stop() end
end

local function ItemMatchesSearch(info)
    if searchText == "" then return true end
    if not info then return false end
    local name = info.itemName
    if not name and info.hyperlink then
        local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        name = getInfo(info.hyperlink)
    end
    return name ~= nil and name:lower():find(searchText, 1, true) ~= nil
end

-- True for quest items, and for items that start a quest.
local function IsQuestItem(info, bag, slot)
    if not info then return false end

    if C_Container.GetContainerItemQuestInfo then
        local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
        if quest and (quest.isQuestItem or quest.questID) then return true end
    end

    -- Fall back to the item's type if the client has no quest info call.
    if info.hyperlink and Enum.ItemClass and Enum.ItemClass.Questitem then
        local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        local classID = select(12, getInfo(info.hyperlink))
        return classID == Enum.ItemClass.Questitem
    end

    return false
end

-- Updates the picture, count, border, lock and cooldown for one slot.
local function UpdateButton(button)
    local bag, slot = button.bbBag, button.bbSlot
    local info = C_Container.GetContainerItemInfo(bag, slot)

    SetItemButtonTexture(button, info and info.iconFileID or nil)
    SetItemButtonCount(button, info and info.stackCount or 0)
    SetItemButtonDesaturated(button, info and info.isLocked or false)
    if SetItemButtonQuality then
        SetItemButtonQuality(button, info and info.quality or nil, info and info.hyperlink or nil)
    end
    button.hasItem = info and 1 or nil

    -- Right-click only does something on a slot with an item, so empty slots don't raise errors.
    -- Attributes can't change in combat, so this catches up when combat ends.
    local usable = info ~= nil
    -- While a spell is waiting for a target (Disenchant, Prospecting, enchants...), a left-click must hand the
    -- item to the spell. That is a protected action too, so left-click becomes the secure "item" action then.
    local targeting = usable and SpellIsTargeting() or false
    if (button.bbUsable ~= usable or button.bbTargeting ~= targeting) and not InCombatLockdown() then
        button:SetAttribute("type2", usable and "macro" or nil)
        button:SetAttribute("type1", targeting and "macro" or nil)
        button.bbUsable = usable
        button.bbTargeting = targeting
    end

    local cooldown = button.Cooldown or _G[button:GetName() .. "Cooldown"]
    if cooldown and CooldownFrame_Set then
        local ok, start, duration, enable = pcall(C_Container.GetContainerItemCooldown, bag, slot)
        if ok then
            CooldownFrame_Set(cooldown, start or 0, duration or 0, (enable == true or enable == 1) and 1 or 0)
        end
    end

    button:SetAlpha(ItemMatchesSearch(info) and 1 or 0.25)

    HideBlizzardNewGlow(button)

    -- Quest items get a steady green glow. It shows instead of the blue new-item glow.
    local isQuest = IsQuestItem(info, bag, slot)
    button.bbQuestGlow:SetShown(isQuest)
    button.bbGlow:SetShown(not isQuest and info ~= nil and Bags.NewItems:IsNew(info.itemID))
    button.bbSellMark:SetShown(info ~= nil and Bags.SellList:IsMarked(info.itemID))
end

---------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------
-- Which slots exist right now, as a string. If it changes, the grid needs rebuilding.
local function BuildLayoutKey()
    local parts = {}
    for bag = 0, Bags.LAST_BAG do
        -- A hidden bag counts as zero slots, so hiding or showing one changes the key.
        parts[#parts + 1] = Bags.IsBagHidden(bag) and 0 or (C_Container.GetContainerNumSlots(bag) or 0)
    end
    return table.concat(parts, ",")
end

local function Relayout()
    for _, button in ipairs(active) do button:Hide() end
    wipe(active)

    for bag = 0, Bags.LAST_BAG do
        if not Bags.IsBagHidden(bag) then
            for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
                active[#active + 1] = GetButton(bag, slot)
            end
        end
    end

    local total = #active
    local rows = math.max(1, math.ceil(total / COLUMNS))
    local gridWidth = COLUMNS * BUTTON_SIZE + (COLUMNS - 1) * SPACING
    local gridHeight = rows * BUTTON_SIZE + (rows - 1) * SPACING

    -- Blizzard fills the grid from the bottom right, so a partly full row ends up at the top.
    for i, button in ipairs(active) do
        local fromEnd = total - i
        local col = fromEnd % COLUMNS
        local row = math.floor(fromEnd / COLUMNS)
        button:ClearAllPoints()
        button:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT",
            -col * (BUTTON_SIZE + SPACING), row * (BUTTON_SIZE + SPACING))
        button:Show()
    end

    content:SetSize(gridWidth, gridHeight)
    frame:SetSize(gridWidth + PADDING_X, gridHeight + PADDING_TOP + FOOTER)
    layoutKey = BuildLayoutKey()
    needsLayout = false
end

local function UpdateFooter()
    local total, free = Bags.CountSlots()
    local color = "|cff00ff00"
    if free <= 5 then
        color = "|cffff0000"
    elseif free <= 15 then
        color = "|cffffff00"
    end
    freeText:SetText(("Free: %s%d|r/%d"):format(color, free, total))
    moneyText:SetText(Bags.MoneyString(GetMoney()))
end

---------------------------------------------------------------------
-- Refreshing
---------------------------------------------------------------------
-- Updates every visible slot. Re-anchors the grid only when the slot count changed.
function Bags:Refresh()
    if not frame or not frame:IsShown() then return end

    if layoutKey ~= BuildLayoutKey() then needsLayout = true end
    if needsLayout then
        if InCombatLockdown() then
            -- Item buttons are protected, so they can't be moved or hidden during combat.
            self.pendingLayout = true
        else
            Relayout()
        end
    end

    for _, button in ipairs(active) do UpdateButton(button) end
    UpdateFooter()
end

-- Called when a bag is hidden or shown from the filters window.
function Bags:LayoutChanged()
    needsLayout = true
    self:Refresh()
end

-- Keeps the buttons ready while the window is closed. Opening it in combat can't build or change buttons,
-- so everything is laid out and up to date beforehand, whenever the bags change out of combat.
function Bags:Maintain()
    if not frame or frame:IsShown() or InCombatLockdown() then return end
    if layoutKey ~= BuildLayoutKey() or needsLayout then Relayout() end
    for _, button in ipairs(active) do UpdateButton(button) end
end

function Bags:RefreshSlot(bag, slot)
    if not frame or not frame:IsShown() then return end
    local button = pool[bag] and pool[bag][slot]
    if button and button:IsShown() then UpdateButton(button) end
end

---------------------------------------------------------------------
-- Opening and closing
---------------------------------------------------------------------
-- The window holds protected item buttons, so the game won't let addon code show or hide it during combat.
-- A request made in combat is remembered here and carried out when combat ends.
local pendingVisible

function Bags:Show()
    if not frame then return end
    if InCombatLockdown() then
        if not frame:IsShown() then
            pendingVisible = true
            print(ns.PREFIX .. "the bags will open when combat ends")
        else
            pendingVisible = nil
        end
        return
    end
    pendingVisible = nil
    needsLayout = true
    frame:Show()
end

function Bags:Hide()
    if not frame then return end
    if InCombatLockdown() then
        if frame:IsShown() then
            pendingVisible = false
        else
            pendingVisible = nil
        end
        return
    end
    pendingVisible = nil
    frame:Hide()
end

function Bags:Toggle()
    if not frame then return end
    -- If a request is already waiting for the end of combat, a toggle reverses that one.
    local visible = frame:IsShown()
    if pendingVisible ~= nil then visible = pendingVisible end
    if visible then self:Hide() else self:Show() end
end

-- Called when combat ends.
function Bags:ApplyPendingVisibility()
    local want = pendingVisible
    pendingVisible = nil
    if want == true then self:Show() elseif want == false then self:Hide() end
end

-- The small "(free slots)" number on the backpack button of the main menu bar.
-- Blizzard's code normally shows it when its bags are closed. Since our window replaces those bags,
-- we make sure it is shown and up to date whenever our window is closed.
function Bags:UpdateBackpackIndicator()
    local button = MainMenuBarBackpackButton
    if not button or not button.Count then return end

    if frame and frame:IsShown() then return end
    button.Count:Show()

    if button.UpdateFreeSlots then
        button:UpdateFreeSlots()
    else
        local free = 0
        for bag = 0, Bags.LAST_BAG do
            free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
        end
        button.Count:SetText("(" .. free .. ")")
    end
end

-- Lights up every slot belonging to one bag (or turns the light off with nil).
local hoverBag
function Bags:HighlightBag(bag)
    if hoverBag and pool[hoverBag] then
        for _, button in pairs(pool[hoverBag]) do button.bbHover:Hide() end
    end
    hoverBag = bag
    if not bag or not frame or not frame:IsShown() or Bags.IsBagHidden(bag) then return end
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
        local button = pool[bag] and pool[bag][slot]
        if button and button:IsShown() then button.bbHover:Show() end
    end
end

-- Hooks the bag buttons on the main menu bar so hovering one highlights its slots in our window.
local hooked = {}
local function HookBagButton(button, bag)
    if not button or hooked[button] then return end
    hooked[button] = true
    button:HookScript("OnEnter", function() Bags:HighlightBag(bag) end)
    button:HookScript("OnLeave", function() Bags:HighlightBag(nil) end)
end

local function HookBagBar()
    HookBagButton(MainMenuBarBackpackButton, 0)
    for i = 0, 3 do
        HookBagButton(_G["CharacterBag" .. i .. "Slot"], i + 1)
    end
    HookBagButton(CharacterReagentBag0Slot, 5)
end

function Bags:ResetPosition()
    Bags.db.bagPoint = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -90, 100 }
    if frame then
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -90, 100)
    end
end

---------------------------------------------------------------------
-- Building the window
---------------------------------------------------------------------
local function BuildFrame()
    -- SecureHandlerBaseTemplate marks the window as protected on purpose, so the game's secure code
    -- (the toggle key and close button below) is allowed to show and hide it during combat.
    frame = CreateFrame("Frame", "GGGUIManagerBagsFrame", UIParent, "BackdropTemplate, SecureHandlerBaseTemplate")
    frame:SetFrameStrata("MEDIUM")
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
    frame:SetSize(COLUMNS * BUTTON_SIZE + (COLUMNS - 1) * SPACING + PADDING_X, 300)

    local p = Bags.db.bagPoint
    frame:SetPoint(p[1], _G[p[2]] or UIParent, p[3], p[4], p[5])

    frame:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then self:StartMoving() end -- a protected window can't be moved in combat
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        Bags.db.bagPoint = { point, "UIParent", relPoint, x, y }
    end)
    frame:SetScript("OnShow", function()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN or 862)
        Bags:Refresh()
        Bags:UpdateBackpackIndicator()
    end)
    frame:SetScript("OnHide", function()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_BACKPACK_CLOSE or 863)
        Bags.openedBy = nil
        Bags:UpdateBackpackIndicator()
    end)

    -- Escape closes the window like other panels.
    tinsert(UISpecialFrames, "GGGUIManagerBagsFrame")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText(COMBINED_BAG_TITLE or "Backpack")

    -- The close button hides the window through a secure snippet, so it works in combat too.
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton, SecureHandlerClickTemplate")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    close:SetFrameRef("window", frame)
    close:SetAttribute("_onclick", [[ self:GetFrameRef("window"):Hide() ]])

    -- Search box: dims slots whose item name doesn't contain the text.
    searchBox = CreateFrame("EditBox", "GGGUIManagerBagsSearch", frame, "InputBoxTemplate")
    searchBox:SetSize(220, 20)
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -40)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(30)
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = (self:GetText() or ""):lower()
        Bags:Refresh()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", searchBox.ClearFocus)

    -- Sort button, if this client can sort bags.
    local sort = (C_Container and C_Container.SortBags) or SortBags
    if sort then
        local sortButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        sortButton:SetSize(56, 22)
        sortButton:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
        sortButton:SetText("Sort")
        sortButton:SetScript("OnClick", function()
            sort()
            -- Let the sort finish, then put pinned items back in their slots.
            Bags.Pinned:Pause(3)
        end)
    end

    -- Opens the window where you choose what each bag holds.
    local filterButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    filterButton:SetSize(64, 22)
    filterButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -39)
    filterButton:SetText("Filters")
    filterButton:SetScript("OnClick", function() Bags.Config:Toggle() end)

    -- The grid and the footer.
    content = CreateFrame("Frame", nil, frame)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -RIGHT_INSET, FOOTER)
    content:SetSize(COLUMNS * BUTTON_SIZE + (COLUMNS - 1) * SPACING, BUTTON_SIZE)

    -- Opens the list of items pinned to fixed backpack slots.
    local pinnedButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    pinnedButton:SetSize(64, 20)
    pinnedButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
    pinnedButton:SetText("Pinned")
    pinnedButton:SetScript("OnClick", function() Bags.Pinned:Toggle() end)

    -- Opens the list of items marked for sale at vendors.
    local sellButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    sellButton:SetSize(64, 20)
    sellButton:SetPoint("LEFT", pinnedButton, "RIGHT", 4, 0)
    sellButton:SetText("Sell list")
    sellButton:SetScript("OnClick", function() Bags.SellList:ToggleWindow() end)

    freeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    freeText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)

    moneyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    moneyText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
end

---------------------------------------------------------------------
-- Replacing Blizzard's bag functions
---------------------------------------------------------------------
-- Blizzard code, key bindings and the vendor window all call these global functions to open and close bags.
-- Pointing them at our window means Blizzard's bags never open.
local function InstallOverrides()
    ToggleAllBags = function() Bags:Toggle() end
    ToggleBackpack = function() Bags:Toggle() end
    ToggleBag = function() Bags:Toggle() end

    OpenAllBags = function(opener)
        if frame:IsShown() then return end
        Bags:Show()
        Bags.openedBy = opener
    end
    OpenBackpack = function() Bags:Show() end
    OpenBag = function() Bags:Show() end

    -- Like Blizzard, only close if no opener is named or it was the same window that opened the bags.
    CloseAllBags = function(opener)
        if opener and Bags.openedBy and opener ~= Bags.openedBy then return end
        Bags:Hide()
    end
    CloseBackpack = function() Bags:Hide() end
    CloseBag = function() Bags:Hide() end
end

local function HideBlizzardBags()
    local blizzard = { ContainerFrameCombinedBags }
    for i = 1, 13 do blizzard[#blizzard + 1] = _G["ContainerFrame" .. i] end
    for _, f in pairs(blizzard) do
        if f and f:IsShown() then f:Hide() end
    end
end

---------------------------------------------------------------------
-- Opening and closing in combat
---------------------------------------------------------------------
-- Addon code can't show or hide the window in combat, but the game's own secure code can. So the bag keys
-- are pointed at a hidden secure button whose click shows or hides the window. That works in and out of combat.
local toggler
local BAG_COMMANDS = {
    "TOGGLEBACKPACK", "OPENALLBAGS", "TOGGLEBAG1", "TOGGLEBAG2", "TOGGLEBAG3", "TOGGLEBAG4", "TOGGLEREAGENTBAG1",
}

local function BuildToggler()
    toggler = CreateFrame("Button", "GGGUIManagerBagsToggle", UIParent, "SecureHandlerClickTemplate")
    toggler:SetFrameRef("window", frame)
    toggler:SetAttribute("_onclick", [[
        local window = self:GetFrameRef("window")
        if window:IsShown() then window:Hide() else window:Show() end
    ]])
    toggler:RegisterForClicks("AnyUp") -- once per key press, not once for down and once for up
end

-- Key bindings can't change in combat, so a change made then waits until combat ends.
local bindingsPending = false
function Bags:UpdateBindings()
    if not toggler then return end
    if InCombatLockdown() then
        bindingsPending = true
        return
    end
    bindingsPending = false
    ClearOverrideBindings(toggler)
    for _, command in ipairs(BAG_COMMANDS) do
        for _, key in ipairs({ GetBindingKey(command) }) do
            SetOverrideBindingClick(toggler, true, key, "GGGUIManagerBagsToggle")
        end
    end
end

---------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------
function Bags:Start()
    if frame then return end

    BuildFrame()
    BuildToggler()
    self:UpdateBindings()
    InstallOverrides()
    HideBlizzardBags()
    self:Maintain() -- lay the buttons out now, while it is safe, so the window can open in combat
    self:UpdateBackpackIndicator()
    HookBagBar()

    local events = CreateFrame("Frame")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("BAG_UPDATE_COOLDOWN")
    events:RegisterEvent("ITEM_LOCK_CHANGED")
    events:RegisterEvent("PLAYER_MONEY")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("UPDATE_BINDINGS")
    -- Not every client has these events.
    pcall(events.RegisterEvent, events, "BAG_CONTAINER_UPDATE")
    -- Quest changes can switch an item's quest glow on or off.
    -- Starting or ending spell targeting (Disenchant and the like) changes what a left-click does.
    for _, questEvent in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "CURRENT_SPELL_CAST_CHANGED" }) do
        pcall(events.RegisterEvent, events, questEvent)
    end

    events:SetScript("OnEvent", function(_, event, bag, slot)
        if event == "ITEM_LOCK_CHANGED" then
            if bag and slot then Bags:RefreshSlot(bag, slot) else Bags:Refresh() end
        elseif event == "BAG_UPDATE_DELAYED" then
            Bags.NewItems:Scan(false) -- runs even when the window is closed
            Bags:Refresh()
            Bags:Maintain() -- same, while the window is closed
            Bags:UpdateBackpackIndicator()
            Bags.Pinned:Arrange() -- one step toward the pinned order; the next step follows the next bag update
        elseif event == "PLAYER_REGEN_ENABLED" then
            Bags.Pinned:Arrange()
            Bags:ApplyPendingVisibility()
            if bindingsPending then Bags:UpdateBindings() end
            Bags.pendingLayout = false
            Bags:Refresh() -- also brings right-click availability up to date after combat
            Bags:Maintain()
        elseif event == "UPDATE_BINDINGS" then
            Bags:UpdateBindings()
        else
            Bags:Refresh()
        end
    end)
end
