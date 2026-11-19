local addonName, ns = ...

-- Cluster helper: one secure unit frame with a name, a health bar and a power bar. The player frame and the pet
-- frame (and later the party frames) are built with it.
-- Health and power values are passed straight to the bars and text and nothing else is done with them, because
-- this client returns them as secret values (CLU-12, D-013).

local Cluster = ns.Cluster

local TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local HEALTH_COLOR = { 0.1, 0.75, 0.2 }
local FRAME_HEIGHT = 62
Cluster.UNIT_FRAME_HEIGHT = FRAME_HEIGHT -- the pet bar sits under the pet frame

-- options: globalName, unit, container, rect, hideWhenMissing (true for units that may not exist, such as a pet),
-- happiness (true to show the pet happiness label and colour the name)
function Cluster.CreateUnitFrame(options)
    local unit = options.unit
    local container, rect = options.container, options.rect

    local button = CreateFrame("Button", options.globalName, container, "SecureUnitButtonTemplate")
    button:SetPoint("TOPLEFT", container, "TOPLEFT", rect[1], -rect[2])
    button:SetSize(rect[3], FRAME_HEIGHT)
    button:SetAttribute("unit", unit)
    button:SetAttribute("*type1", "target")
    button:SetAttribute("*type2", "togglemenu")
    button:RegisterForClicks("AnyUp")

    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.6)

    local name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    name:SetPoint("TOPRIGHT", button, "TOPRIGHT", -4, -4)
    name:SetJustifyH("LEFT")

    -- Optional happiness label on the right of the name line, and the name coloured to match (pets only).
    local happinessLabel
    if options.happiness then
        happinessLabel = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        happinessLabel:SetPoint("TOPRIGHT", button, "TOPRIGHT", -4, -6)
        name:ClearAllPoints()
        name:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
        name:SetPoint("RIGHT", happinessLabel, "LEFT", -4, 0)
    end

    local health = CreateFrame("StatusBar", nil, button)
    health:SetStatusBarTexture(TEXTURE)
    health:SetStatusBarColor(unpack(HEALTH_COLOR))
    health:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -22)
    health:SetPoint("TOPRIGHT", button, "TOPRIGHT", -4, -22)
    health:SetHeight(22)
    local healthText = health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    healthText:SetPoint("CENTER")

    local power = CreateFrame("StatusBar", nil, button)
    power:SetStatusBarTexture(TEXTURE)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -2)
    power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, -2)
    power:SetHeight(12)
    local powerText = power:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    powerText:SetPoint("CENTER")

    local function UpdateName()
        local unitName = UnitName(unit)
        name:SetText(unitName)
    end

    local function UpdateHealth()
        health:SetMinMaxValues(0, UnitHealthMax(unit))
        health:SetValue(UnitHealth(unit))
        healthText:SetFormattedText("%s / %s", UnitHealth(unit), UnitHealthMax(unit))
    end

    local function UpdatePowerType()
        local powerType, token = UnitPowerType(unit)
        local color = (token and PowerBarColor[token]) or PowerBarColor[powerType] or { r = 0.5, g = 0.5, b = 0.5 }
        power:SetStatusBarColor(color.r, color.g, color.b)
    end

    local function UpdatePower()
        power:SetMinMaxValues(0, UnitPowerMax(unit))
        power:SetValue(UnitPower(unit))
        powerText:SetFormattedText("%s / %s", UnitPower(unit), UnitPowerMax(unit))
    end

    -- 1 = unhappy, 2 = content, 3 = happy. A pet that has no happiness (for example a warlock pet) shows nothing.
    local HAPPINESS = {
        [1] = { "Unhappy", 1, 0.2, 0.2 },
        [2] = { "Content", 1, 0.85, 0.1 },
        [3] = { "Happy", 0.2, 0.9, 0.2 },
    }

    local function UpdateHappiness()
        local happiness = ns.GetPetMood()
        local entry = happiness and HAPPINESS[happiness]
        if entry then
            name:SetTextColor(entry[2], entry[3], entry[4])
            happinessLabel:SetText(entry[1])
            happinessLabel:SetTextColor(entry[2], entry[3], entry[4])
        else
            name:SetTextColor(1, 1, 1)
            happinessLabel:SetText("")
        end
    end

    -- A failing update is reported once per frame and never raises an error (INV-07, INV-08).
    local failedOnce = false
    local function Safe(func)
        local ok, err = pcall(func)
        if not ok and not failedOnce then
            failedOnce = true
            print(ns.PREFIX .. ("%s frame update failed: %s"):format(unit, tostring(err)))
        end
    end

    local function UpdateAll()
        if not UnitExists(unit) then return end
        Safe(UpdateName)
        Safe(UpdateHealth)
        Safe(UpdatePowerType)
        Safe(UpdatePower)
        if happinessLabel then Safe(UpdateHappiness) end
    end

    local handlers = {
        UNIT_HEALTH = function() Safe(UpdateHealth) end,
        UNIT_MAXHEALTH = function() Safe(UpdateHealth) end,
        UNIT_POWER_UPDATE = function() Safe(UpdatePower) end,
        UNIT_POWER_FREQUENT = function() Safe(UpdatePower) end,
        UNIT_MAXPOWER = function() Safe(UpdatePower) end,
        UNIT_DISPLAYPOWER = function() Safe(UpdatePowerType); Safe(UpdatePower) end,
        UNIT_NAME_UPDATE = function() Safe(UpdateName) end,
    }

    if happinessLabel then
        handlers.UNIT_HAPPINESS = function() Safe(UpdateHappiness) end
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    for event in pairs(handlers) do
        -- An event this client does not have is skipped quietly (INV-08).
        pcall(events.RegisterUnitEvent, events, event, unit)
    end
    if options.hideWhenMissing then
        -- The pet is summoned, dismissed or replaced: refresh everything.
        events:RegisterUnitEvent("UNIT_PET", "player")
    end
    events:SetScript("OnEvent", function(_, event)
        local handler = handlers[event]
        if handler then handler() else UpdateAll() end
    end)

    -- The secure unit watch shows and hides the frame when the unit appears or goes, even in combat.
    if options.hideWhenMissing then
        RegisterUnitWatch(button)
    end
    button:HookScript("OnShow", UpdateAll)

    -- The happiness event may not fire for every change on this client, so the happiness is also checked once a
    -- second while the frame is showing (throttled, INV-05).
    if happinessLabel then
        local elapsed = 0
        button:HookScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed >= 1 then
                elapsed = 0
                Safe(UpdateHappiness)
            end
        end)
    end

    UpdateAll()
    return button
end
