local addonName, ns = ...

-- Hunter part: the ammo block beside the Feign Death button, and the range and shot timer measuring (SDD HUN-11 to HUN-14, HUN-17, HUN-19).
-- The range bar and the shot glow that used to be drawn in the player area are gone. They live on the target nameplate (Nameplates.lua).
--   an ammo indicator   the equipped ammo's icon and the total count, yellow when low and red when critical
--   range and shot timing   measured in the background and handed to the nameplate bar
--   /ggg hunter range   prints every range measurement the client gives for the target

local Hunter = ns.Hunter
local Indicators = {}
Hunter:AddPart("Indicators", Indicators)

local AMMO_W = 34 -- the ammo block beside Feign Death: icon on top, count under it
Hunter.AMMO_W = AMMO_W
local COOLDOWN_H = 30 -- the essential cooldowns row, under the unit frame
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
Hunter.BANDS = BANDS      -- the nameplate bar (Nameplates.lua) draws the same bands
Hunter.shotBars = {}      -- extra status bars that sweep with the shot timer, added by Nameplates.lua

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
        ammoText:SetText("0")
    end
    if level >= 2 then
        ammoText:SetTextColor(1, 0.2, 0.2)
    elseif level == 1 then
        ammoText:SetTextColor(1, 0.85, 0.1)
    else
        ammoText:SetTextColor(1, 1, 1)
    end
end

-- The range is measured in the background for the nameplate bar (HUN-19). Nothing is drawn here any more.
local function UpdateRange()
    local nameplate = Hunter.settings and Hunter.settings.nameplate
    if nameplate and nameplate.enabled == false then
        Hunter.bandNow = nil -- nobody reads the band, so no range checks are made
        return
    end
    Hunter.bandNow = CurrentBand() -- read by the nameplate bar, so it makes no range checks of its own
end

-- Shot timer state (HUN-17)
local autoRepeat = false -- Auto Shot is switched on
local shotStart          -- when the last Auto Shot went off
local shotGap            -- seconds between the last two shots, measured (the real speed is secret)

-- The shot timer state, for the nameplate bar: Auto Shot on, when the last shot went off, the measured gap.
function Hunter.ShotState() return autoRepeat, shotStart, shotGap end

local function Build(container, areas)
    local Cluster = ns.Cluster
    local rect = areas.player
    local width = rect[3]
    local y = rect[2] + Cluster.UNIT_FRAME_HEIGHT + (Cluster.PLAYER_CAST_H or 0) + 6 -- under the player cast bar

    -- The essential cooldowns (Cooldowns.lua) take the row under the unit frame, the whole width of the area.
    Hunter.cooldownRect = { x = rect[1], y = y, width = width, height = COOLDOWN_H }
    Hunter.playerWidgetsBottom = y + COOLDOWN_H -- where the button rows start (Buttons.lua)

    -- The ammo block sits beside the Feign Death button, as tall as its three rows: the icon on top, the count under
    -- it. The sizes of the rows and of Feign Death come from Buttons.lua, which is loaded before the Cluster is built.
    local feignWidth, rowGap = Hunter.FEIGN_W or 46, Hunter.ROW_GAP or 4
    local blockHeight = Hunter.THREE_ROWS_H or 74
    ammoFrame = CreateFrame("Frame", "GGGUIManagerHunterAmmo", container)
    ammoFrame:SetPoint("TOPLEFT", container, "TOPLEFT", rect[1] + width - feignWidth - 2 - AMMO_W,
        -(Hunter.playerWidgetsBottom + rowGap))
    ammoFrame:SetSize(AMMO_W, blockHeight)
    local back = ammoFrame:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.6)
    ammoIcon = ammoFrame:CreateTexture(nil, "ARTWORK")
    ammoIcon:SetSize(AMMO_W - 2, AMMO_W - 2)
    ammoIcon:SetPoint("TOP", ammoFrame, "TOP", 0, -1)
    ammoIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ammoText = ammoFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ammoText:SetPoint("TOP", ammoIcon, "BOTTOM", 0, -4)

    -- The range is measured about ten times a second for the nameplate bar. This frame only carries the timer.
    local ticker = CreateFrame("Frame", "GGGUIManagerHunterRange", container)
    local elapsed = 0
    ticker:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= TICK then
            elapsed = 0
            if Hunter.active then pcall(UpdateRange) end
        end
    end)

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
        elseif event == "STOP_AUTOREPEAT_SPELL" then
            autoRepeat = false
            shotStart, shotGap = nil, nil
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            -- Each Auto Shot starts a new sweep as long as your ranged speed.
            local ok, isAutoShot = pcall(function() return spellID == AUTO_SHOT_ID end)
            if ok and isAutoShot then
                local now = GetTime()
                -- The time since the last shot, when it is a believable gap, is the measured speed.
                shotGap = (shotStart and now - shotStart < 8) and (now - shotStart) or nil
                shotStart = now
                -- The speed is a secret value, so it is only ever handed to status bars (D-013).
                local okSpeed, speed = pcall(UnitRangedDamage, "player")
                for _, bar in ipairs(Hunter.shotBars) do
                    if okSpeed and speed then
                        pcall(bar.SetMinMaxValues, bar, 0, speed)
                    elseif shotGap then
                        bar:SetMinMaxValues(0, shotGap)
                    end
                    bar:SetValue(0)
                end
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
