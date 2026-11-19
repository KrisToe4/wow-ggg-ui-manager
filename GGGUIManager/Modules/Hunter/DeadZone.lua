local addonName, ns = ...

-- Hunter part: shows "DEAD ZONE" while your target is too close for ranged attacks but too far for melee (HUN-05).
-- The "too close" test uses the game's 9.9 yard check, so it is a little wider than the true 8 yard dead zone.
-- The melee test uses Raptor Strike's range, so the spell has to be in your spellbook.
--
--   /ggg hunter deadzone on | off     turn the warning on or off
--   /ggg hunter deadzone unlock       show the box so you can drag it. lock hides it again.

local Hunter = ns.Hunter
local DeadZone = {}
Hunter:AddPart("DeadZone", DeadZone)

local MELEE_SPELL = "Raptor Strike"

local frame
local unlocked = false

local InRange = (C_Spell and C_Spell.IsSpellInRange) or IsSpellInRange

local function MeleeRange()
    local ok, result = pcall(InRange, MELEE_SPELL, "target")
    return ok and (result == 1 or result == true)
end

local function TooClose()
    local ok, result = pcall(CheckInteractDistance, "target", 3)
    return ok and result and true or false
end

local function Update()
    if unlocked then return end
    local show = Hunter.active and Hunter.settings.deadzone.enabled
        and UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target")
        and TooClose() and not MeleeRange()
    frame:SetShown(show and true or false)
end

local function SavePosition()
    local point, _, relativePoint, x, y = frame:GetPoint()
    Hunter.settings.deadzone.point = { point, "UIParent", relativePoint, x, y }
end

local function Build()
    frame = CreateFrame("Frame", "GGGUIManagerHunterDeadZone", UIParent)
    frame:SetSize(180, 40)
    local p = Hunter.settings.deadzone.point
    frame:SetPoint(p[1], _G[p[2]] or UIParent, p[3], p[4], p[5])
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if unlocked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    frame:Hide()

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.6, 0, 0, 0.55)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetPoint("CENTER")
    text:SetText("DEAD ZONE")
    text:SetTextColor(1, 0.9, 0.9)
end

function DeadZone:Command(arg)
    local settings = Hunter.settings.deadzone
    arg = arg:lower()
    if arg == "on" then
        settings.enabled = true
    elseif arg == "off" then
        settings.enabled = false
        frame:Hide()
    elseif arg == "unlock" then
        unlocked = true
        frame:EnableMouse(true)
        frame:Show()
        print(ns.PREFIX .. "drag the box where you want it, then /ggg hunter deadzone lock")
        return
    elseif arg == "lock" then
        unlocked = false
        frame:EnableMouse(false)
        Update()
        return
    end
    print(ns.PREFIX .. "dead zone warning is " .. (settings.enabled and "ON" or "OFF"))
end

function DeadZone:Disable()
    unlocked = false
    if frame then frame:Hide() end
end

function DeadZone:Init()
    Build()
    local elapsed = 0
    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.1 then
            elapsed = 0
            Update()
        end
    end)
end
