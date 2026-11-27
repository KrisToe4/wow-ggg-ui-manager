local addonName, ns = ...

-- Cluster part: the pet bar (SDD CLU-09, CLU-16). Ten secure buttons of the game's "pet" action type in one row
-- under the pet frame. The secure type means clicking works in combat without any addon code running.
-- The bar is shown only while there is a pet, by a secure state driver.

local Cluster = ns.Cluster

local NUM_SLOTS = 10
local GAP = 2
local TOP_GAP = 6 -- space between the pet frame and the bar

local function Build(container, rect)
    local width = rect[3]
    local size = math.floor((width - (NUM_SLOTS - 1) * GAP) / NUM_SLOTS)

    local holder = CreateFrame("Frame", "GGGUIManagerClusterPetBar", container)
    holder:SetPoint("TOPLEFT", container, "TOPLEFT", rect[1], -(rect[2] + Cluster.UNIT_FRAME_HEIGHT + TOP_GAP))
    holder:SetSize(width, size)
    RegisterStateDriver(holder, "visibility", "[@pet,exists] show; hide")

    local buttons = {}

    -- Right-click toggles auto-cast. TogglePetAutocast is a protected function, so addon code cannot call it.
    -- A secure macro button can run /petautocasttoggle instead. Its text names the ability, so it is set here
    -- and, because attributes cannot change in combat, only out of combat.
    local function SetAutocastClick(button, abilityName)
        if InCombatLockdown() then
            ns:AfterCombat(SetAutocastClick, button, abilityName)
            return
        end
        if abilityName then
            button:SetAttribute("type2", "macro")
            button:SetAttribute("macrotext2", "/petautocasttoggle " .. abilityName)
        else
            button:SetAttribute("type2", nil)
            button:SetAttribute("macrotext2", nil)
        end
    end

    local function UpdateButton(button)
        local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(button:GetID())
        local wanted = (autoCastAllowed and name and not isToken) and name or nil
        if button.autocastName ~= wanted then
            button.autocastName = wanted
            SetAutocastClick(button, wanted)
        end
        if texture then
            button.icon:SetTexture(isToken and _G[texture] or texture)
            button.icon:Show()
            local shade = GetPetActionSlotUsable(button:GetID()) and 1 or 0.4
            button.icon:SetVertexColor(shade, shade, shade)
        else
            button.icon:Hide()
        end
        button.active:SetShown(isActive and true or false)
        if autoCastAllowed then
            button.auto:SetText("A")
            if autoCastEnabled then button.auto:SetTextColor(0.2, 1, 0.2) else button.auto:SetTextColor(0.6, 0.6, 0.6) end
        else
            button.auto:SetText("")
        end
    end

    local function UpdateCooldown(button)
        local start, duration, enable = GetPetActionCooldown(button:GetID())
        if CooldownFrame_Set then
            CooldownFrame_Set(button.cooldown, start, duration, enable)
        else
            button.cooldown:SetCooldown(start or 0, duration or 0)
        end
    end

    for i = 1, NUM_SLOTS do
        local button = CreateFrame("Button", "GGGUIManagerClusterPetAction" .. i, holder, "SecureActionButtonTemplate")
        button:SetSize(size, size)
        button:SetPoint("TOPLEFT", holder, "TOPLEFT", (i - 1) * (size + GAP), 0)
        button:SetID(i)
        button:SetAttribute("type1", "pet")
        button:SetAttribute("action", i)
        -- The game's "cast on key down" option makes secure buttons act on the press, not the release. These
        -- buttons are mouse buttons that act on the release, so that option is turned off for them.
        button:SetAttribute("useOnKeyDown", false)
        button:RegisterForClicks("AnyUp")

        local back = button:CreateTexture(nil, "BACKGROUND")
        back:SetAllPoints()
        back:SetColorTexture(0, 0, 0, 0.6)

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 1, -1)
        button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        button.active = button:CreateTexture(nil, "OVERLAY")
        button.active:SetAllPoints()
        button.active:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        button.active:SetBlendMode("ADD")
        button.active:Hide()

        button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.cooldown:SetAllPoints()

        button.auto = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.auto:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)

        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if not pcall(GameTooltip.SetPetAction, GameTooltip, self:GetID()) then GameTooltip:Hide() end
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Dragging as on the game's own pet bar (PetActionButtonMixin): pick the ability up when the bars are
        -- unlocked or the pickup key (Shift by default) is held, and drop a carried pet ability back onto a slot.
        button:RegisterForDrag("LeftButton", "RightButton")
        button:SetScript("OnDragStart", function(self)
            local locked = Cluster.BarsLocked and Cluster.BarsLocked()
            if not locked or IsModifiedClick("PICKUPACTION") then
                if PickupPetAction then PickupPetAction(self:GetID()) end
            end
        end)
        button:SetScript("OnReceiveDrag", function(self)
            if GetCursorInfo() == "petaction" and PickupPetAction then PickupPetAction(self:GetID()) end
        end)

        buttons[i] = button
    end

    -- A failing update is reported once and never raises an error (INV-07, INV-08).
    local failedOnce = false
    local function Safe(func, button)
        local ok, err = pcall(func, button)
        if not ok and not failedOnce then
            failedOnce = true
            print(ns.PREFIX .. "pet bar update failed: " .. tostring(err))
        end
    end

    local function UpdateAll()
        for _, button in ipairs(buttons) do
            Safe(UpdateButton, button)
            Safe(UpdateCooldown, button)
        end
    end

    local function UpdateCooldowns()
        for _, button in ipairs(buttons) do Safe(UpdateCooldown, button) end
    end

    local events = CreateFrame("Frame")
    local handlers = {
        PET_BAR_UPDATE = UpdateAll,
        PET_UI_UPDATE = UpdateAll,
        PET_BAR_UPDATE_USABLE = UpdateAll,
        PLAYER_CONTROL_LOST = UpdateAll,
        PLAYER_CONTROL_GAINED = UpdateAll,
        PLAYER_ENTERING_WORLD = UpdateAll,
        PET_BAR_UPDATE_COOLDOWN = UpdateCooldowns,
    }
    for event in pairs(handlers) do
        -- An event this client does not have is skipped quietly (INV-08).
        pcall(events.RegisterEvent, events, event)
    end
    pcall(events.RegisterUnitEvent, events, "UNIT_PET", "player")
    pcall(events.RegisterUnitEvent, events, "UNIT_FLAGS", "pet")
    pcall(events.RegisterUnitEvent, events, "UNIT_AURA", "pet")
    events:SetScript("OnEvent", function(_, event)
        local handler = handlers[event]
        if handler then handler() else UpdateAll() end
    end)
    holder:HookScript("OnShow", UpdateAll)

    UpdateAll()
end

Cluster:AddPart("PetBar", {
    area = "pet",
    defaultFrames = { "PetActionBar" },
    Build = Build,
})
