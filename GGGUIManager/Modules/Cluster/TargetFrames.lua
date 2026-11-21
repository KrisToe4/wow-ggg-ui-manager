local addonName, ns = ...

-- Cluster part: target, target of target, focus and focus target frames in the strip above the player and pet
-- areas (SDD CLU-20 to CLU-24). Each is a secure unit button. Health and names may be secret values on this
-- client, so they go straight to the bar and text and nothing else is done with them (CLU-12, D-013).

local Cluster = ns.Cluster

local TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local FRIEND_COLOR = { 0.1, 0.75, 0.2 }
local ENEMY_COLOR = { 0.8, 0.15, 0.15 }
local GAP = 6

local CLASSIFICATION = { elite = "Elite", rareelite = "Rare Elite", rare = "Rare", worldboss = "Boss" }

local function Readable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- "Level 25 Elite Beast", or "Level 60 Hunter" for a player. Only readable values are used (CLU-23).
local function InfoLine(unit)
    local parts = {}
    local ok, level = pcall(UnitLevel, unit)
    if ok and Readable(level) and type(level) == "number" then
        parts[#parts + 1] = "Level " .. (level < 0 and "??" or tostring(level))
    end
    local okClass, classification = pcall(UnitClassification, unit)
    if okClass and Readable(classification) and CLASSIFICATION[classification] then
        parts[#parts + 1] = CLASSIFICATION[classification]
    end
    local okPlayer, isPlayer = pcall(UnitIsPlayer, unit)
    if okPlayer and Readable(isPlayer) then
        local okType, kind
        if isPlayer then
            okType, kind = pcall(UnitClass, unit)
        else
            okType, kind = pcall(UnitCreatureType, unit)
        end
        if okType and Readable(kind) and type(kind) == "string" and kind ~= "Not specified" then
            parts[#parts + 1] = kind
        end
    end
    return table.concat(parts, " ")
end

local function CreateFrameFor(options)
    local unit, container = options.unit, options.container
    local isFocus = unit == "focus"

    local button = CreateFrame("Button", options.globalName, container, "SecureUnitButtonTemplate")
    button:SetPoint("TOPLEFT", container, "TOPLEFT", options.x, -options.y)
    button:SetSize(options.width, options.height)
    -- A secure unit button ignores every click while its unit does not exist, which is the case for an empty focus.
    -- The focus button uses the unit "none" so it can be clicked to set a focus (D-028). Its own code still reads
    -- the real focus.
    button:SetAttribute("unit", isFocus and "none" or unit)
    if isFocus then
        -- Left-click makes the current target the focus and right-click clears it (CLU-22).
        button:SetAttribute("type1", "macro")
        -- A secure macro on a button with a unit attribute uses that unit by default, which here is the focus
        -- itself, so the real target is named.
        button:SetAttribute("macrotext1", "/focus [@target]")
        button:SetAttribute("type2", "macro")
        button:SetAttribute("macrotext2", "/clearfocus")
    else
        button:SetAttribute("*type1", "target")
        button:SetAttribute("*type2", "togglemenu")
    end
    button:SetAttribute("useOnKeyDown", false) -- the clicks are registered on release (D-018)
    button:RegisterForClicks("AnyUp")

    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.6)

    local name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    name:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -3)
    name:SetJustifyH("LEFT")
    name:SetHeight(12)

    local health = CreateFrame("StatusBar", nil, button)
    health:SetStatusBarTexture(TEXTURE)
    health:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -16)
    health:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -16)
    health:SetHeight(14)
    local healthBack = health:CreateTexture(nil, "BACKGROUND")
    healthBack:SetAllPoints()
    healthBack:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    local healthText = health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    healthText:SetPoint("CENTER")

    local info = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    info:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -32)
    info:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -32)
    info:SetJustifyH("LEFT")

    local function UpdateEmpty()
        back:SetColorTexture(0, 0, 0, 0.35)
        name:SetText("No focus")
        name:SetTextColor(0.6, 0.6, 0.6)
        health:Hide()
        info:SetText("Left-click to set")
    end

    local function UpdateAll()
        if not UnitExists(unit) then
            if isFocus then UpdateEmpty() end
            return
        end
        back:SetColorTexture(0, 0, 0, 0.6)
        name:SetText(UnitName(unit))
        name:SetTextColor(1, 1, 1)
        health:Show()
        local enemy = UnitIsEnemy("player", unit)
        local color = (Readable(enemy) and enemy) and ENEMY_COLOR or FRIEND_COLOR
        health:SetStatusBarColor(color[1], color[2], color[3])
        health:SetMinMaxValues(0, UnitHealthMax(unit))
        health:SetValue(UnitHealth(unit))
        healthText:SetFormattedText("%s / %s", UnitHealth(unit), UnitHealthMax(unit))
        info:SetText(InfoLine(unit))
    end

    -- A failing update is reported once per frame and never raises an error (INV-07, INV-08).
    local failedOnce = false
    local function Safe()
        local ok, err = pcall(UpdateAll)
        if not ok and not failedOnce then
            failedOnce = true
            print(ns.PREFIX .. ("%s frame update failed: %s"):format(unit, tostring(err)))
        end
    end

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_LEVEL",
        "UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION" }) do
        pcall(events.RegisterUnitEvent, events, event, unit) -- an event this client lacks is skipped (INV-08)
    end
    events:SetScript("OnEvent", Safe)

    -- The secure unit watch shows and hides the frame with its unit, even in combat (CLU-21).
    if not isFocus then RegisterUnitWatch(button) end
    button:HookScript("OnShow", Safe)
    button.Refresh = Safe
    Safe()
    return button
end

Cluster:AddPart("TargetFrames", {
    area = "targets",
    defaultFrames = { "TargetFrame", "FocusFrame" }, -- their target of target frames are their children (CLU-24)
    Build = function(container, rect)
        local width = math.floor((rect[3] - GAP * 3) / 4)
        local frames = {}
        for index, unit in ipairs({ "target", "targettarget", "focus", "focustarget" }) do
            frames[#frames + 1] = CreateFrameFor({
                globalName = "GGGUIManagerCluster" .. unit:gsub("^%l", string.upper),
                unit = unit,
                container = container,
                x = rect[1] + (index - 1) * (width + GAP),
                y = rect[2],
                width = width,
                height = rect[4],
            })
        end

        -- A new target or focus changes what every frame shows, including the target of target frames.
        local events = CreateFrame("Frame")
        for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_ENTERING_WORLD" }) do
            pcall(events.RegisterEvent, events, event)
        end
        pcall(events.RegisterUnitEvent, events, "UNIT_TARGET", "target", "focus")
        events:SetScript("OnEvent", function()
            for _, frame in ipairs(frames) do frame.Refresh() end
        end)
    end,
})
