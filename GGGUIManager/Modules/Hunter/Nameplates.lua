local addonName, ns = ...

-- Hunter part: a small range and shot timer bar on the current target's nameplate (SDD HUN-19, step 17).
-- It is a copy of the range bar in the player area. The band comes from the measurement that bar already made
-- (Hunter.bandNow), and the shot glow is fed by the same shots (Hunter.shotBars), so no range checks are added.
-- The bar is our own frame, a child of Blizzard's nameplate and anchored to its health bar. Nothing is ever written
-- to a Blizzard frame, because writing to them from addon code spreads taint (D-029).

local Hunter = ns.Hunter
local Nameplates = {}
Hunter:AddPart("Nameplates", Nameplates)

local SEGMENT_W, SEGMENT_GAP, BAR_H = 10, 1, 6
local TICK = 0.03 -- the glow is redrawn about 30 times a second

local bar, glow, spark
local segments = {}
local attachedTo

local function Enabled()
    local settings = Hunter.settings
    return Hunter.active and settings and settings.nameplate and settings.nameplate.enabled
end

---------------------------------------------------------------------
-- The bar
---------------------------------------------------------------------
local function Create()
    local bands = Hunter.BANDS
    if not bands then return false end -- Indicators.lua has not loaded
    local width = #bands * SEGMENT_W + (#bands - 1) * SEGMENT_GAP

    bar = CreateFrame("Frame", "GGGUIManagerHunterNameplate", UIParent)
    bar:SetSize(width, BAR_H)
    bar:Hide()
    for index, band in ipairs(bands) do
        local fill = bar:CreateTexture(nil, "BACKGROUND")
        fill:SetSize(SEGMENT_W, BAR_H)
        fill:SetPoint("TOPLEFT", bar, "TOPLEFT", (index - 1) * (SEGMENT_W + SEGMENT_GAP), 0)
        segments[index] = { fill = fill, colour = band.colour }
    end

    -- The shot timer glow, the same as on the player bar (HUN-17). The speed is a secret value, so it is only
    -- ever handed to the status bar by Indicators.lua (D-013).
    glow = CreateFrame("StatusBar", nil, bar)
    glow:SetAllPoints()
    glow:SetFrameLevel(bar:GetFrameLevel() + 5)
    glow:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetStatusBarColor(0.5, 0.8, 1, 0.45)
    glow:GetStatusBarTexture():SetBlendMode("ADD")
    glow:SetMinMaxValues(0, 1)
    glow:SetValue(1)
    spark = glow:CreateTexture(nil, "OVERLAY")
    spark:SetSize(2, BAR_H)
    spark:SetBlendMode("ADD")
    spark:SetColorTexture(1, 1, 1, 0.9)
    spark:SetPoint("CENTER", glow:GetStatusBarTexture(), "RIGHT", 0, 0)
    glow:Hide()
    Hunter.shotBars[#Hunter.shotBars + 1] = glow

    local function ShowShot()
        local autoRepeat, shotStart, shotGap = Hunter.ShotState()
        if not autoRepeat then
            glow:Hide()
            return
        end
        local ready = true
        if shotStart then
            local elapsed = GetTime() - shotStart
            glow:SetValue(elapsed) -- the bar clamps this to the full length
            ready = shotGap ~= nil and elapsed >= shotGap
        else
            glow:SetMinMaxValues(0, 1)
            glow:SetValue(1)
        end
        spark:SetShown(not ready)
        glow:Show()
    end

    local function ShowBand()
        local band = Hunter.bandNow
        for index, segment in ipairs(segments) do
            local c = segment.colour
            if band == index then
                segment.fill:SetColorTexture(c[1], c[2], c[3], 0.95)
            else
                segment.fill:SetColorTexture(c[1], c[2], c[3], band and 0.2 or 0.1)
            end
        end
    end

    local elapsedTotal, elapsedBand = 0, 1
    bar:SetScript("OnUpdate", function(_, dt)
        elapsedTotal = elapsedTotal + dt
        elapsedBand = elapsedBand + dt
        if elapsedTotal < TICK then return end
        elapsedTotal = 0
        pcall(ShowShot)
        if elapsedBand >= 0.1 then -- the band changes at most 10 times a second (INV-05)
            elapsedBand = 0
            pcall(ShowBand)
        end
    end)
    bar:SetScript("OnShow", function() elapsedBand = 1 end)
    return true
end

---------------------------------------------------------------------
-- Attaching to the target's nameplate
---------------------------------------------------------------------
-- Returns the frame to hang the bar under and the gap. The cast bar sits below the health bar and covers anything
-- placed there while a cast shows, so the bar goes under the cast bar when the plate has one. A hidden cast bar
-- still keeps its place, so the bar does not jump when a cast starts. Without a cast bar the gap is wider, to
-- leave room for one.
local function AnchorOf(plate)
    local unitFrame = plate.UnitFrame
    if unitFrame then
        local castBar = unitFrame.castBar or unitFrame.CastBar
        if type(castBar) == "table" and castBar.GetObjectType then return castBar, -2 end
        return unitFrame.healthBar or unitFrame.HealthBarsContainer or unitFrame, -16
    end
    return plate, -16
end

local function Hide()
    if bar then bar:Hide() end
    attachedTo = nil
end

local function Refresh()
    if not Enabled() then
        Hide()
        return
    end
    if not UnitExists("target") or UnitIsDeadOrGhost("target") or not UnitCanAttack("player", "target") then
        Hide()
        return
    end
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
    if not plate or plate:IsForbidden() then
        Hide()
        return
    end
    if not bar and not Create() then return end
    if attachedTo ~= plate then
        local anchor, gap = AnchorOf(plate)
        bar:SetParent(plate)
        bar:ClearAllPoints()
        bar:SetPoint("TOP", anchor, "BOTTOM", 0, gap)
        attachedTo = plate
    end
    bar:Show()
end

local failedOnce = false
local function Safe()
    local ok, err = pcall(Refresh)
    if not ok then
        Hide()
        if not failedOnce then
            failedOnce = true
            print(ns.PREFIX .. "nameplate bar failed: " .. tostring(err))
        end
    end
end

function Nameplates:Init()
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
        "PLAYER_ENTERING_WORLD" }) do
        pcall(events.RegisterEvent, events, event) -- an event this client lacks is skipped (INV-08)
    end
    events:SetScript("OnEvent", Safe)
end

function Nameplates:Enable()
    Safe()
end

function Nameplates:Disable()
    Hide()
end

---------------------------------------------------------------------
-- /ggg hunter nameplate
---------------------------------------------------------------------
function Nameplates:Command(rest)
    local word = (rest or ""):match("^%s*(%S*)"):lower()
    local settings = Hunter.settings.nameplate
    if word == "on" or word == "off" then
        settings.enabled = word == "on"
        print(ns.PREFIX .. ("nameplate bar %s."):format(word))
        Safe()
    else
        print(ns.PREFIX .. ("nameplate bar is %s. /ggg hunter nameplate on | off"):format(settings.enabled and "on" or "off"))
    end
end
