local addonName, ns = ...

-- Camp: a grid of buttons in its own area beside the player area (SDD section 7.3, CLU-25). Hearthstone, Cozy Sleeping Bag, the campfire and
-- campsite objects in the bags, and the best food and best drink. Every button is a secure button that uses the
-- item, so clicking works in combat. Showing, hiding and changing a button only happens out of combat.

local Camp = {}
ns:RegisterModule("Camp", Camp)
ns.Camp = Camp
Camp.active = false

local Items = ns.CampItems
local SIZE, GAP = 22, 2
local COLUMNS = 2
local MAX_CAMPSITE = 7 -- the grid holds 12 buttons, five of them fixed (CMP-13)

local holder
local buttons = {}  -- every button, for cooldown refresh
local fixed = {}    -- hearthstone, bag, food, drink, toy
local campsite = {} -- the pool for campsite objects
local shown = {}    -- what the row shows now: { label, name, id, count }, for the command
local scheduled, queued = false, false

---------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------
local function UpdateCooldown(button)
    if not (button.itemID and button:IsShown()) then return end
    local cooldown = button.cooldown
    local ok = pcall(function()
        local get = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown)
        if not get then return end
        local start, duration = get(button.itemID)
        if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then return end
        if duration and duration > 0 then cooldown:SetCooldown(start, duration) else cooldown:Clear() end
    end)
    if not ok then cooldown:Clear() end
end

local function CreateButton(name)
    local button = CreateFrame("Button", "GGGUIManagerCamp" .. name, holder, "SecureActionButtonTemplate")
    button:SetSize(SIZE, SIZE)
    button:SetAttribute("type", "macro")
    button:SetAttribute("useOnKeyDown", false) -- same reason as the pet bar (D-018)
    button:RegisterForClicks("AnyUp")

    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.6)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints()
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.count:SetPoint("BOTTOMRIGHT", -1, 1)

    button:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if not pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID) then GameTooltip:Hide() return end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:Hide()
    buttons[#buttons + 1] = button
    return button
end

-- Points a button at an item, or hides it when there is none. Out of combat only.
local function SetItem(button, entry)
    if not entry then
        button.itemID = nil
        button:Hide()
        return false
    end
    if button.itemID ~= entry.id then
        button.itemID = entry.id
        if button.toy then
            button:SetAttribute("type", "toy") -- a toy is used from the toy box
            button:SetAttribute("toy", entry.id)
        else
            button:SetAttribute("macrotext", "/use item:" .. entry.id)
        end
        local info = Items.Info(entry.id)
        local icon = info and info.icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id))
        button.icon:SetTexture(icon)
    end
    button.count:SetText(entry.count > 1 and entry.count or "")
    button:Show()
    UpdateCooldown(button)
    return true
end


---------------------------------------------------------------------
-- The grid
---------------------------------------------------------------------
local function Rebuild()
    queued = false
    if not (holder and Camp.active) then return end
    if InCombatLockdown() then
        queued = true
        ns:AfterCombat(Rebuild)
        return
    end

    local entries = Items.Bags()
    local hearth, sleeping, camp = nil, nil, {}
    for _, entry in ipairs(entries) do
        local kind, order = Items.Special(entry)
        if kind == "hearthstone" then hearth = hearth or entry
        elseif kind == "bag" then sleeping = sleeping or entry
        elseif kind == "campsite" then
            entry.order = order
            camp[#camp + 1] = entry
        end
    end
    table.sort(camp, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.id < b.id end)
    local food, drink = Items.Best(entries)
    local toy = PlayerHasToy and Items.TOY_ID and PlayerHasToy(Items.TOY_ID) and { id = Items.TOY_ID, count = 1 } or nil

    shown = {}
    local function Note(label, entry)
        local info = Items.Info(entry.id)
        shown[#shown + 1] = { label = label, name = info and info.name or "?", id = entry.id, count = entry.count }
    end

    -- The buttons keep fixed places in the grid (CMP-13), so only their items change here.
    if SetItem(fixed.hearth, hearth) then Note("hearthstone", hearth) end
    if SetItem(fixed.bag, sleeping) then Note("sleeping bag", sleeping) end
    if SetItem(fixed.drink, drink) then Note("drink", drink) end
    if SetItem(fixed.food, food) then Note("food", food) end
    if SetItem(fixed.toy, toy) then Note("toy", toy) end
    for index, button in ipairs(campsite) do
        local entry = camp[index]
        if SetItem(button, entry) then Note("campsite", entry) end
    end
end

local function Schedule()
    if scheduled then return end
    scheduled = true
    C_Timer.After(0.2, function()
        scheduled = false
        if not queued then pcall(Rebuild) end
    end)
end

---------------------------------------------------------------------
-- Cluster placement (CMP-02, CLU-25)
---------------------------------------------------------------------
local function Build(container, areas)
    local rect = areas.camp
    holder = CreateFrame("Frame", "GGGUIManagerCamp", container)
    holder:SetPoint("TOPLEFT", container, "TOPLEFT", rect[1], -rect[2])
    holder:SetSize(rect[3], rect[4])

    fixed.hearth = CreateButton("Hearthstone")
    fixed.bag = CreateButton("SleepingBag")
    fixed.food = CreateButton("Food")
    fixed.drink = CreateButton("Drink")
    fixed.toy = CreateButton("Toy")
    fixed.toy.toy = true
    for index = 1, MAX_CAMPSITE do campsite[index] = CreateButton("Campsite" .. index) end

    -- Two wide, numbered across and then down: hearthstone, bag, drink, food, toy, then the campsite objects.
    local order = { fixed.hearth, fixed.bag, fixed.drink, fixed.food, fixed.toy }
    for _, button in ipairs(campsite) do order[#order + 1] = button end
    for slot, button in ipairs(order) do
        local column, row = (slot - 1) % COLUMNS, math.floor((slot - 1) / COLUMNS)
        button:SetPoint("TOPLEFT", holder, "TOPLEFT", column * (SIZE + GAP), -row * (SIZE + GAP))
    end

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
        "GET_ITEM_INFO_RECEIVED", "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "TOYS_UPDATED",
        "NEW_TOY_ADDED" }) do
        pcall(events.RegisterEvent, events, event) -- an event this client lacks is skipped (INV-08)
    end
    events:SetScript("OnEvent", function(_, event)
        if not Camp.active then return end
        if event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
            for _, button in ipairs(buttons) do pcall(UpdateCooldown, button) end
        else
            Schedule()
        end
    end)
    Schedule()
end

function Camp:Init(settings)
    self.settings = settings
    -- Shown only inside the Cluster, once it is built (CMP-02).
    if ns.Cluster then ns.Cluster:OnBuilt(Build) end
end

function Camp:Enable()
    self.active = true
    if holder then
        holder:Show()
        Schedule()
    end
end

function Camp:Disable()
    self.active = false
    if holder then ns:AfterCombat(function() holder:Hide() end) end
end

---------------------------------------------------------------------
-- /ggg camp (CMP-11)
---------------------------------------------------------------------
local function Scan(all)
    print(ns.PREFIX .. "camp scan of your bags")
    local count = 0
    for _, entry in ipairs(Items.Bags()) do
        local info = Items.Info(entry.id)
        local kind, order = Items.Special(entry)
        local role, source = Items.Classify(entry)
        local spellName, spellID = Items.UseSpell(entry.id)
        if all or kind or role or (info and info.classID == 0 and info.subClassID == 5) then
            count = count + 1
            if count > 60 then
                print("  ... more items, not shown")
                return
            end
            print(("  %s (id %d) x%d, class %s/%s, level %s, casts %s (%s)"):format(info and info.name or "not loaded",
                entry.id, entry.count, tostring(info and info.classID), tostring(info and info.subClassID),
                tostring(info and info.minLevel), tostring(spellName), tostring(spellID)))
            local text = Items.TooltipText(entry.bag, entry.slot)
            local note = {}
            if kind then note[#note + 1] = "counts as " .. kind end
            if role then note[#note + 1] = ("%s by %s"):format(role, source) end
            if text then
                if text:find("eating", 1, true) then note[#note + 1] = "tooltip says eating" end
                if text:find("drinking", 1, true) then note[#note + 1] = "tooltip says drinking" end
            else
                note[#note + 1] = "no tooltip text"
            end
            print("      " .. table.concat(note, ", "))
        end
    end
    if count == 0 then print("  nothing relevant found. Use /ggg camp scan all to list every item.") end
end

ns:RegisterCommand("camp", function(rest)
    local word, arg = (rest or ""):match("^(%S*)%s*(.*)$")
    if (word or ""):lower() == "scan" then
        Scan((arg or ""):lower() == "all")
        return
    end
    print(ns.PREFIX .. "camp row now:")
    if #shown == 0 then print("  nothing shown. The bags hold none of the items, or the module is off.") end
    for _, item in ipairs(shown) do
        print(("  %s: %s (id %d) x%d"):format(item.label, item.name, item.id, item.count))
    end
    -- The toy's ID is not checked on this client yet, so the game's own name for that ID is shown.
    local gameName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(Items.TOY_ID)
    local known = PlayerHasToy and PlayerHasToy(Items.TOY_ID)
    print(("  toy %s (id %d): the game calls it %s, %s"):format(Items.TOY_NAME, Items.TOY_ID, tostring(gameName),
        known and "it is in your toy box" or "it is not in your toy box"))
    print("  /ggg camp scan   list the bag items the module cares about. scan all lists every item")
end, "scan | scan all (camp row)")
