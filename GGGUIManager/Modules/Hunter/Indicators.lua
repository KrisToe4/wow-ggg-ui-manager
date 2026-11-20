local addonName, ns = ...

-- Hunter part: experimental widgets in the player area of the Cluster (SDD HUN-11 to HUN-14, step 8).
-- This is R&D. The look and the bands will change as it is tried in the game.
--   an ammo indicator   the equipped ammo's icon and the total count, yellow when low and red when critical
--   a range indicator   four bands from near to far, with the one the target is in lit
--   /ggg hunter range   prints every range measurement the client gives for the target

local Hunter = ns.Hunter
local Indicators = {}
Hunter:AddPart("Indicators", Indicators)

local WIDGET_GAP = 4
local AMMO_H = 22
local AMMO_WIDTH = 96
local RANGE_H = 20
local TICK = 0.1 -- seconds between range checks (INV-05)

local MELEE_SPELL_ID = 2974 -- Raptor Strike
local AUTO_SHOT_ID = 75

-- Range bands, nearest first (HUN-12). The yard bands come from items whose use range is known, the method the
-- Huntmaster addon uses on this client. Melee and the dead zone come from Raptor Strike and Auto Shot.
local function Green(t) return { 0.2 + 0.8 * t, 0.85 - 0.1 * t, 0.2 } end
local BANDS = {
    { label = "M",   colour = { 0.2, 0.5, 1 } },   -- 1 melee
    { label = "D",   colour = { 0.9, 0.15, 0.15 } }, -- 2 dead zone
    { label = "10",  colour = Green(0.9), items = { 17626, 10699, 17689 } },
    { label = "15",  colour = Green(0.7), items = { 4559 } },
    { label = "20",  colour = Green(0.5), items = { 10645, 1191, 4388 } },
    { label = "25",  colour = Green(0.3), items = { 13289 } },
    { label = "30",  colour = Green(0.1), items = { 7734, 17202, 835, 2091 } },
    { label = "35",  colour = Green(0), items = { 18904 } },
    { label = "Max", colour = { 0.3, 0.85, 1 } },  -- 9 shooting range edge
}
local FAR = #BANDS + 1

---------------------------------------------------------------------
-- Measurements
---------------------------------------------------------------------
local function Normalize(value)
    if value == true or value == 1 then return true end
    if value == false or value == 0 then return false end
    return nil
end

local function SpellInRange(id)
    local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id))
    if name and IsSpellInRange then
        local ok, value = pcall(IsSpellInRange, name, "target")
        if ok and Normalize(value) ~= nil then return Normalize(value) end
    end
    if C_Spell and C_Spell.IsSpellInRange then
        local ok, value = pcall(C_Spell.IsSpellInRange, id, "target")
        if ok then return Normalize(value) end
    end
    return nil
end

local function ItemInRange(id)
    if not (C_Item and C_Item.IsItemInRange) then return nil end
    local ok, value = pcall(C_Item.IsItemInRange, id, "target")
    if ok then return Normalize(value) end
    return nil
end

local function RungInRange(items)
    local sawFalse = false
    for _, id in ipairs(items) do
        local value = ItemInRange(id)
        if value == true then return true end
        if value == false then sawFalse = true end
    end
    if sawFalse then return false end
    return nil
end

-- Which band the target is in, 1 to FAR, or nil when there is no attackable target.
local function CurrentBand()
    if not UnitExists("target") or UnitIsDeadOrGhost("target") or not UnitCanAttack("player", "target") then
        return nil
    end
    local melee = SpellInRange(MELEE_SPELL_ID)
    local auto
    if melee == nil then
        melee = ItemInRange(16114)
        if melee == nil and CheckInteractDistance then
            local ok, value = pcall(CheckInteractDistance, "target", 2)
            if ok then melee = Normalize(value) end
        end
    elseif melee == true then
        -- Auto Shot still working means this is not real melee range.
        auto = SpellInRange(AUTO_SHOT_ID)
        if auto ~= nil then melee = (auto == false) end
    end
    if melee == true then return 1 end

    if auto == nil then auto = SpellInRange(AUTO_SHOT_ID) end
    local last
    for index = 3, 8 do
        local result = RungInRange(BANDS[index].items)
        if index == 8 then last = result end
        if result == true then
            if auto == false and index <= 5 then return 2 end -- inside 20 yd but Auto Shot refuses: dead zone
            return index
        end
    end
    if auto == true and last == false then return 9 end
    if auto == true then return 8 end
    return FAR
end

---------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------
local ammoFrame, ammoIcon, ammoText
local segments = {}

local function UpdateAmmo()
    if not ammoFrame then return end
    local ammoID, count, level, rangedID = Hunter.parts.Ammo.Status()
    if not rangedID then
        ammoFrame:Hide()
        return
    end
    ammoFrame:Show()
    if ammoID then
        -- The equipped slot's own texture is the most reliable, then the item lookups.
        local texture = GetInventoryItemTexture("player", 0)
        if not texture and GetIcon then
            local ok, result = pcall(GetIcon, ammoID)
            texture = ok and result or nil
        end
        if not texture and GetItemIcon then texture = GetItemIcon(ammoID) end
        ammoIcon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        ammoIcon:SetDesaturated(false)
        ammoText:SetText(tostring(count))
    else
        ammoIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        ammoIcon:SetDesaturated(true)
        ammoText:SetText("No ammo")
    end
    if level >= 2 then
        ammoText:SetTextColor(1, 0.2, 0.2)
    elseif level == 1 then
        ammoText:SetTextColor(1, 0.85, 0.1)
    else
        ammoText:SetTextColor(1, 1, 1)
    end
end

local function UpdateRange()
    local band = CurrentBand()
    for index, segment in ipairs(segments) do
        local colour = BANDS[index].colour
        if band == index then
            segment.fill:SetColorTexture(colour[1], colour[2], colour[3], 0.95)
            segment.text:SetTextColor(1, 1, 1)
        else
            segment.fill:SetColorTexture(colour[1], colour[2], colour[3], band and 0.2 or 0.1)
            segment.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
end

-- Shot timer state (HUN-17)
local autoRepeat = false -- Auto Shot is switched on
local shotStart          -- when the last Auto Shot went off
local shotGap            -- seconds between the last two shots, measured (the real speed is secret)
local SHOT_TICK = 0.03   -- the glow is redrawn about 30 times a second while Auto Shot is on

local function Build(container, areas)
    local Cluster = ns.Cluster
    local rect = areas.player
    local width = rect[3]
    local y = rect[2] + Cluster.UNIT_FRAME_HEIGHT + 6

    ammoFrame = CreateFrame("Frame", "GGGUIManagerHunterAmmo", container)
    ammoFrame:SetPoint("TOPLEFT", container, "TOPLEFT", rect[1], -y)
    ammoFrame:SetSize(AMMO_WIDTH, AMMO_H) -- the rest of the row is for the essential cooldowns (Cooldowns.lua)
    Hunter.ammoRect = { x = rect[1], y = y, width = AMMO_WIDTH, height = AMMO_H }
    ammoIcon = ammoFrame:CreateTexture(nil, "ARTWORK")
    ammoIcon:SetSize(AMMO_H - 2, AMMO_H - 2)
    ammoIcon:SetPoint("LEFT", ammoFrame, "LEFT", 1, 0)
    ammoIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ammoText = ammoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ammoText:SetPoint("LEFT", ammoIcon, "RIGHT", 6, 0)

    Hunter.playerWidgetsBottom = y + AMMO_H + WIDGET_GAP + RANGE_H -- where the button rows start (Buttons.lua)

    local rangeFrame = CreateFrame("Frame", "GGGUIManagerHunterRange", container)
    rangeFrame:SetPoint("TOPLEFT", container, "TOPLEFT", rect[1], -(y + AMMO_H + WIDGET_GAP))
    rangeFrame:SetSize(width, RANGE_H)
    local gap = 1
    local segmentWidth = (width - gap * (#BANDS - 1)) / #BANDS
    for index, band in ipairs(BANDS) do
        local segment = CreateFrame("Frame", nil, rangeFrame)
        segment:SetSize(segmentWidth, RANGE_H)
        segment:SetPoint("TOPLEFT", rangeFrame, "TOPLEFT", (index - 1) * (segmentWidth + gap), 0)
        segment.fill = segment:CreateTexture(nil, "BACKGROUND")
        segment.fill:SetAllPoints()
        segment.text = segment:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        segment.text:SetPoint("CENTER")
        segment.text:SetText(band.label)
        segments[index] = segment
    end

    local elapsed = 0
    rangeFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= TICK then
            elapsed = 0
            if Hunter.active then pcall(UpdateRange) end
        end
    end)

    -- Shot timer (HUN-17): a glow that sweeps over the range bar from left to right between two Auto Shots.
    -- Your ranged speed is a hidden "secret" number, so it is only handed to a status bar, never compared (D-013).
    local glowFrame = CreateFrame("StatusBar", nil, rangeFrame)
    glowFrame:SetAllPoints()
    glowFrame:SetFrameLevel(rangeFrame:GetFrameLevel() + 10)
    glowFrame:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    glowFrame:SetStatusBarColor(0.5, 0.8, 1, 0.35)
    glowFrame:GetStatusBarTexture():SetBlendMode("ADD")
    glowFrame:SetMinMaxValues(0, 1)
    glowFrame:SetValue(1)
    local spark = glowFrame:CreateTexture(nil, "OVERLAY")
    spark:SetSize(3, RANGE_H)
    spark:SetBlendMode("ADD")
    spark:SetColorTexture(1, 1, 1, 0.9)
    spark:SetPoint("CENTER", glowFrame:GetStatusBarTexture(), "RIGHT", 0, 0)
    glowFrame:Hide()

    local function ShowShotProgress()
        if not autoRepeat then
            glowFrame:Hide()
            return
        end
        local ready = true
        if shotStart then
            local elapsedShot = GetTime() - shotStart
            glowFrame:SetValue(elapsedShot) -- the bar clamps this to the full length
            -- Whether the shot is ready is only known once two shots have measured the gap between them.
            ready = shotGap ~= nil and elapsedShot >= shotGap
        else
            glowFrame:SetMinMaxValues(0, 1)
            glowFrame:SetValue(1)
        end
        spark:SetShown(not ready)
        glowFrame:Show()
    end

    local shotElapsed = 0
    glowFrame:SetScript("OnUpdate", function(_, dt)
        shotElapsed = shotElapsed + dt
        if shotElapsed >= SHOT_TICK then
            shotElapsed = 0
            if Hunter.active then pcall(ShowShotProgress) end
        end
    end)
    glowFrame:SetScript("OnShow", function() shotElapsed = SHOT_TICK end)

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD",
        "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL" }) do
        pcall(events.RegisterEvent, events, event) -- an event this client lacks is skipped (INV-08)
    end
    pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
    events:SetScript("OnEvent", function(_, event, _, _, spellID)
        if not Hunter.active then return end
        if event == "START_AUTOREPEAT_SPELL" then
            autoRepeat = true
            pcall(ShowShotProgress)
        elseif event == "STOP_AUTOREPEAT_SPELL" then
            autoRepeat = false
            shotStart, shotGap = nil, nil
            pcall(ShowShotProgress)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            -- Each Auto Shot starts a new sweep as long as your ranged speed.
            local ok, isAutoShot = pcall(function() return spellID == AUTO_SHOT_ID end)
            if ok and isAutoShot then
                local now = GetTime()
                -- The time since the last shot, when it is a believable gap, is the measured speed.
                shotGap = (shotStart and now - shotStart < 8) and (now - shotStart) or nil
                shotStart = now
                local okSpeed, speed = pcall(UnitRangedDamage, "player")
                if okSpeed and speed then
                    pcall(glowFrame.SetMinMaxValues, glowFrame, 0, speed) -- a secret value is fine here
                elseif shotGap then
                    glowFrame:SetMinMaxValues(0, shotGap)
                end
                glowFrame:SetValue(0)
            end
        else
            pcall(UpdateAmmo)
        end
    end)
    if IsAutoRepeatSpell then
        local ok, active = pcall(IsAutoRepeatSpell, "Auto Shot")
        autoRepeat = ok and active and true or false
    end

    pcall(UpdateAmmo)
    pcall(UpdateRange)
end

function Indicators:Init()
    -- Shown only inside the Cluster, once it is built (HUN-14).
    if ns.Cluster then ns.Cluster:OnBuilt(Build) end
end

function Indicators:Enable()
    pcall(UpdateAmmo)
end

---------------------------------------------------------------------
-- /ggg hunter range: the probe (HUN-13)
---------------------------------------------------------------------
local PROBE_SPELLS = { "Raptor Strike", "Wing Clip", "Mongoose Bite", "Auto Shot", "Arcane Shot", "Serpent Sting",
    "Concussive Shot", "Hunter's Mark", "Scare Beast", "Distracting Shot" }

local function SpellRanges(spell)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spell)
    if type(info) == "table" then return info.minRange, info.maxRange end
    if GetSpellInfo then
        local _, _, _, _, minRange, maxRange = GetSpellInfo(spell)
        return minRange, maxRange
    end
end

function Indicators:Command()
    if not UnitExists("target") then
        print(ns.PREFIX .. "range probe: select a target first.")
        return
    end
    print(ns.PREFIX .. ("range probe for %s, band now: %s"):format(tostring(UnitName("target")),
        tostring(BANDS[CurrentBand() or 0] and BANDS[CurrentBand()].label or (CurrentBand() and "far") or "none")))
    local checks = {}
    for index = 1, 4 do
        local ok, result = pcall(CheckInteractDistance, "target", index)
        checks[#checks + 1] = ("%d=%s"):format(index, ok and tostring(result) or "error")
    end
    print("  interact distance (1 inspect, 2 trade, 3 duel, 4 follow): " .. table.concat(checks, " "))
    local rungs = {}
    for index = 3, 8 do rungs[#rungs + 1] = BANDS[index].label .. "=" .. tostring(RungInRange(BANDS[index].items)) end
    print("  item ladder (yards): " .. table.concat(rungs, " "))
    print(("  Raptor Strike=%s Auto Shot=%s"):format(tostring(SpellInRange(MELEE_SPELL_ID)), tostring(SpellInRange(AUTO_SHOT_ID))))
    for _, spell in ipairs(PROBE_SPELLS) do
        local ok, result = pcall(InRange, spell, "target")
        local minRange, maxRange = SpellRanges(spell)
        print(("  %s: in range=%s, spell range %s to %s"):format(spell, ok and tostring(result) or "error",
            tostring(minRange), tostring(maxRange)))
    end
    if UnitDistanceSquared then
        local ok, distance = pcall(UnitDistanceSquared, "target")
        print("  UnitDistanceSquared: " .. (ok and tostring(distance) or "error"))
    else
        print("  UnitDistanceSquared: this client does not have it")
    end
end
