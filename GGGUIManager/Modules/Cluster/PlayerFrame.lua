local addonName, ns = ...

-- Cluster part: the player frame (SDD CLU-06). A secure unit button for "player" with a name, a health bar and a
-- power bar. Health and power values are passed straight to the bars and text and nothing else is done with them,
-- because this client may return them as secret values (CLU-12).

local Cluster = ns.Cluster

local TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local HEALTH_COLOR = { 0.1, 0.75, 0.2 }
local failedOnce = false

local function Build(container, rect)
    local button = CreateFrame("Button", "GGGUIManagerClusterPlayer", container, "SecureUnitButtonTemplate")
    button:SetPoint("TOPLEFT", container, "TOPLEFT", rect[1], -rect[2])
    button:SetSize(rect[3], 62)
    button:SetAttribute("unit", "player")
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
        local playerName = UnitName("player")
        name:SetText(playerName)
    end

    local function UpdateHealth()
        health:SetMinMaxValues(0, UnitHealthMax("player"))
        health:SetValue(UnitHealth("player"))
        healthText:SetFormattedText("%s / %s", UnitHealth("player"), UnitHealthMax("player"))
    end

    local function UpdatePowerType()
        local powerType, token = UnitPowerType("player")
        local color = (token and PowerBarColor[token]) or PowerBarColor[powerType] or { r = 0.5, g = 0.5, b = 0.5 }
        power:SetStatusBarColor(color.r, color.g, color.b)
    end

    local function UpdatePower()
        power:SetMinMaxValues(0, UnitPowerMax("player"))
        power:SetValue(UnitPower("player"))
        powerText:SetFormattedText("%s / %s", UnitPower("player"), UnitPowerMax("player"))
    end

    -- A failing update is reported once and never raises an error (INV-07, INV-08).
    local function Safe(func)
        local ok, err = pcall(func)
        if not ok and not failedOnce then
            failedOnce = true
            print(ns.PREFIX .. "player frame update failed: " .. tostring(err))
        end
    end

    local function UpdateAll()
        Safe(UpdateName)
        Safe(UpdateHealth)
        Safe(UpdatePowerType)
        Safe(UpdatePower)
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

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    for event in pairs(handlers) do
        -- An event this client does not have is skipped quietly (INV-08).
        pcall(events.RegisterUnitEvent, events, event, "player")
    end
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            UpdateAll()
        else
            handlers[event]()
        end
    end)

    UpdateAll()
end

Cluster:AddPart("PlayerFrame", {
    area = "player",
    defaultFrames = { "PlayerFrame" },
    Build = Build,
})
