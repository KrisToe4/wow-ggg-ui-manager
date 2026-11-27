local addonName, ns = ...

-- Cluster part: action bars 1 to 4 (SDD CLU-11, CLU-17). Each bar is 12 secure buttons of the "action" type in a
-- grid of 3 columns by 4 rows, numbered across and then down. A button is bound to the same action slot as the
-- game's own bar, so the same abilities and macros show and clicking works in combat without addon code.
--
-- Shown on each button: icon, cooldown, count, key text, macro name, grey when unusable, red when out of range
-- and the game's tooltip. Proc glow, borders and flyouts come in step 7. Bar 1 does not page.

local Cluster = ns.Cluster

local COLUMNS, ROWS = 3, 4
local TICK = 0.2 -- seconds between usable and range checks (INV-05)

-- Blizzard's bars: slots and the key binding commands that go with them (CLU-11).
local BARS = {
    { name = "ActionBar1", area = "bar1", first = 1,  binding = "ACTIONBUTTON",         default = "MainActionBar" },
    { name = "ActionBar2", area = "bar2", first = 61, binding = "MULTIACTIONBAR1BUTTON", default = "MultiBarBottomLeft" },
    { name = "ActionBar3", area = "bar3", first = 49, binding = "MULTIACTIONBAR2BUTTON", default = "MultiBarBottomRight" },
    { name = "ActionBar4", area = "bar4", first = 25, binding = "MULTIACTIONBAR3BUTTON", default = "MultiBarRight" },
}

-- This client may have these calls as C_ActionBar functions or as classic globals, so each is looked up once.
local function Api(name)
    return (C_ActionBar and C_ActionBar[name]) or _G[name]
end
local GetTexture = Api("GetActionTexture")
local GetDisplayCount = Api("GetActionDisplayCount")
local GetCount = Api("GetActionCount")
local GetText = Api("GetActionText")
local UsesText = Api("UsesActionText")
local IsUsable = Api("IsUsableAction")
local IsInRange = Api("IsActionInRange")
local GetCooldown = Api("GetActionCooldown")
local GetCooldownDuration = C_ActionBar and C_ActionBar.GetActionCooldownDuration

-- The game's "Lock Action Bars" option. The setting lives in the Settings table in this client, and in a console
-- variable in older ones.
local function BarsLocked()
    if Settings and Settings.GetValue then
        local ok, value = pcall(Settings.GetValue, "lockActionBars")
        if ok and value ~= nil then return value and true or false end
    end
    return GetCVar and GetCVar("lockActionBars") == "1"
end
Cluster.BarsLocked = BarsLocked -- the pet bar uses the same rule (PetBar.lua)
local allButtons = {}
local failedOnce = false
local driverBuilt = false

-- A failing update is reported once and never raises an error (INV-07, INV-08).
local function Safe(func, button)
    local ok, err = pcall(func, button)
    if not ok and not failedOnce then
        failedOnce = true
        print(ns.PREFIX .. "action bar update failed: " .. tostring(err))
    end
end

local function UpdateIcon(button)
    local texture = GetTexture and GetTexture(button.slot)
    if texture then
        button.icon:SetTexture(texture)
        button.icon:Show()
    else
        button.icon:Hide()
    end
    button.hasAction = texture and true or false
end

local function UpdateCooldown(button)
    local cooldown = button.cooldown
    if not button.hasAction then
        cooldown:Clear()
        return
    end
    -- Cooldown values can be hidden "secret" values in combat. The duration object is meant for that case.
    if GetCooldownDuration and cooldown.SetCooldownFromDurationObject then
        cooldown:SetCooldownFromDurationObject(GetCooldownDuration(button.slot))
    elseif GetCooldown then
        local start, duration, enable = GetCooldown(button.slot)
        if type(start) == "table" then -- the C_ActionBar form returns a table
            start, duration, enable = start.startTime, start.duration, start.isEnabled
        end
        if start and duration and duration > 0 and enable ~= false and enable ~= 0 then
            cooldown:SetCooldown(start, duration)
        else
            cooldown:Clear()
        end
    end
end

local function UpdateCount(button)
    local text = ""
    if button.hasAction then
        if GetDisplayCount then
            text = GetDisplayCount(button.slot, 99) or ""
        elseif GetCount then
            local count = GetCount(button.slot)
            text = (type(count) == "number" and count > 1) and tostring(count) or ""
        end
    end
    button.count:SetText(text)
end

local function UpdateName(button)
    local text = ""
    if button.hasAction and GetText and (not UsesText or UsesText(button.slot)) then
        text = GetText(button.slot) or ""
    end
    button.macroName:SetText(text)
end

local function UpdateHotkey(button)
    local key = GetBindingKey(button.bindingCommand)
    button.hotkey:SetText(key and GetBindingText(key, true) or "")
end

-- Grey when the action cannot be used, blue when it needs more power, red when the target is out of range.
local function UpdateColour(button)
    if not button.hasAction then return end
    local usable, noPower = true, false
    if IsUsable then usable, noPower = IsUsable(button.slot) end
    local outOfRange = IsInRange and IsInRange(button.slot) == false
    if outOfRange then
        button.icon:SetVertexColor(1, 0.3, 0.3)
    elseif noPower then
        button.icon:SetVertexColor(0.5, 0.5, 1)
    elseif usable then
        button.icon:SetVertexColor(1, 1, 1)
    else
        button.icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

local function UpdateAll(button)
    UpdateIcon(button)
    Safe(UpdateCooldown, button)
    Safe(UpdateCount, button)
    Safe(UpdateName, button)
    Safe(UpdateHotkey, button)
    Safe(UpdateColour, button)
end

local EVENTS = {
    ACTIONBAR_SLOT_CHANGED = "all",
    ACTIONBAR_UPDATE_STATE = "all",
    ACTIONBAR_UPDATE_USABLE = "colour",
    ACTIONBAR_UPDATE_COOLDOWN = "cooldown",
    SPELL_UPDATE_COOLDOWN = "cooldown",
    SPELL_UPDATE_CHARGES = "count",
    BAG_UPDATE = "count",
    UPDATE_BINDINGS = "hotkey",
    PLAYER_TARGET_CHANGED = "colour",
    PLAYER_ENTERING_WORLD = "all",
    SPELLS_CHANGED = "all",
}

local function BuildDriver()
    if driverBuilt then return end
    driverBuilt = true

    local events = CreateFrame("Frame")
    for event in pairs(EVENTS) do
        -- An event this client does not have is skipped quietly (INV-08).
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event)
        local what = EVENTS[event]
        for _, button in ipairs(allButtons) do
            if what == "all" then UpdateAll(button)
            elseif what == "colour" then Safe(UpdateColour, button)
            elseif what == "cooldown" then Safe(UpdateCooldown, button)
            elseif what == "count" then Safe(UpdateCount, button)
            elseif what == "hotkey" then Safe(UpdateHotkey, button)
            end
        end
    end)

    -- Usable and range change without an event, so they are checked a few times a second.
    local elapsed = 0
    events:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= TICK then
            elapsed = 0
            for _, button in ipairs(allButtons) do Safe(UpdateColour, button) end
        end
    end)
end

local function BuildBar(bar, container, rect)
    local size, gap = Cluster.BUTTON_SIZE, Cluster.BUTTON_GAP

    local holder = CreateFrame("Frame", "GGGUIManagerCluster" .. bar.name, container)
    holder:SetPoint("TOPLEFT", container, "TOPLEFT", rect[1], -rect[2])
    holder:SetSize(rect[3], rect[4])

    for index = 1, COLUMNS * ROWS do
        local column = (index - 1) % COLUMNS
        local row = math.floor((index - 1) / COLUMNS)
        local slot = bar.first + index - 1

        local button = CreateFrame("Button", "GGGUIManagerCluster" .. bar.name .. "Button" .. index, holder,
            "SecureActionButtonTemplate")
        button:SetSize(size, size)
        button:SetPoint("TOPLEFT", holder, "TOPLEFT", column * (size + gap), -row * (size + gap))
        button.slot = slot
        button.bindingCommand = bar.binding .. index
        -- No SetID: with an ID of 0 the secure template uses the "action" attribute as the slot.
        button:SetAttribute("type", "action")
        button:SetAttribute("action", slot)
        -- Same reason as the pet bar: these act on the mouse release whatever the key-down option says (D-018).
        button:SetAttribute("useOnKeyDown", false)
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

        local text = CreateFrame("Frame", nil, button) -- keeps the text above the cooldown swipe
        text:SetAllPoints()
        text:SetFrameLevel(button.cooldown:GetFrameLevel() + 2)
        button.hotkey = text:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        button.hotkey:SetPoint("TOPRIGHT", -1, -2)
        button.count = text:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        button.count:SetPoint("BOTTOMRIGHT", -1, 2)
        button.macroName = text:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.macroName:SetPoint("BOTTOM", 0, 2)
        button.macroName:SetWidth(size - 2)
        button.macroName:SetHeight(10)

        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if not pcall(GameTooltip.SetAction, GameTooltip, self.slot) then GameTooltip:Hide() end
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Dragging works as on the game's own bars (see ActionBarActionButtonMixin:OnDragStart): an action is
        -- picked up when the bars are unlocked or the pickup key (Shift by default) is held, and dropped
        -- onto a button with PlaceAction.
        button:RegisterForDrag("LeftButton", "RightButton")
        button:SetScript("OnDragStart", function(self)
            if not BarsLocked() or IsModifiedClick("PICKUPACTION") then
                if PickupAction then PickupAction(self.slot) end
                if SpellFlyout and SpellFlyout.Hide then SpellFlyout:Hide() end
            end
        end)
        button:SetScript("OnReceiveDrag", function(self)
            if PlaceAction then PlaceAction(self.slot) end
        end)

        allButtons[#allButtons + 1] = button
        UpdateAll(button)
    end
    BuildDriver()
end

for _, bar in ipairs(BARS) do
    Cluster:AddPart(bar.name, {
        area = bar.area,
        defaultFrames = { bar.default },
        Build = function(container, rect) BuildBar(bar, container, rect) end,
    })
end

-- /ggg cluster bars: what the client has, for checking the slot numbers and the default bar names.
function Cluster.PrintBarsCheck()
    print(ns.PREFIX .. "action bar check")
    for _, bar in ipairs(BARS) do
        local button = _G["GGGUIManagerCluster" .. bar.name .. "Button1"]
        print(("  %s: slots %d to %d, default frame %s %s, button 1 icon %s"):format(bar.name, bar.first,
            bar.first + 11, bar.default, _G[bar.default] and "exists" or "NOT FOUND",
            tostring(button and button.hasAction)))
    end
    print(("  C_ActionBar: %s, duration object cooldowns: %s"):format(tostring(C_ActionBar ~= nil),
        tostring(GetCooldownDuration ~= nil)))
end
