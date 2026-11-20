local addonName, ns = ...

-- Hunter part: warns you when your ammo runs low (HUN-02). Two steps: "low" at the warn count, "critical" at the
-- critical count. You are also told when a ranged weapon has no ammo equipped. Ammo counts include your bags.

local Hunter = ns.Hunter
local Ammo = {}
Hunter:AddPart("Ammo", Ammo)

local AMMO_SLOT = 0 -- the ammo slot
local RANGED_SLOT = 18

local GetCount = (C_Item and C_Item.GetItemCount) or GetItemCount

local lastLevel = 0 -- 0 fine, 1 low, 2 critical, 3 none left
local primed = false -- the first check after login is silent

-- Returns ammoID (or nil) and how many you have in total.
local function Read()
    local ammoID = GetInventoryItemID("player", AMMO_SLOT)
    if not ammoID then return nil, 0 end
    return ammoID, GetCount(ammoID) or 0
end

-- The ammo state for the indicator (HUN-11): ammoID (or nil), the total count, the level 0 to 3 and the ranged
-- weapon's ID (nil when there is no ranged weapon).
function Ammo.Status()
    local rangedID = GetInventoryItemID("player", RANGED_SLOT)
    if not rangedID then return nil, 0, 0, nil end
    local ammoID, count = Read()
    local cfg = Hunter.settings.ammo
    local level = 0
    if not ammoID or count <= 0 then
        level = 3
    elseif count <= cfg.critical then
        level = 2
    elseif count <= cfg.warn then
        level = 1
    end
    return ammoID, count, level, rangedID
end

local function Check()
    if not Hunter.active then return end
    local rangedID = GetInventoryItemID("player", RANGED_SLOT)
    if not rangedID then
        lastLevel = 0
        return
    end

    local ammoID, count = Read()
    local cfg = Hunter.settings.ammo
    local level = 0
    if not ammoID or count <= 0 then
        level = 3
    elseif count <= cfg.critical then
        level = 2
    elseif count <= cfg.warn then
        level = 1
    end

    if primed and level > lastLevel then
        if level == 3 then
            Hunter.Alert(ammoID and "You are out of ammo!" or "No ammo equipped!", "RAID_WARNING")
        elseif level == 2 then
            Hunter.Alert(("Ammo critical: %d left"):format(count), "RAID_WARNING")
        else
            Hunter.Alert(("Ammo low: %d left"):format(count))
        end
    end
    lastLevel = level
    primed = true
end

function Ammo:Command(text)
    local cfg = Hunter.settings.ammo
    local warn, critical = text:match("^(%d+)%s+(%d+)$")
    if warn then
        warn, critical = tonumber(warn), tonumber(critical)
        if critical > warn then warn, critical = critical, warn end
        cfg.warn, cfg.critical = warn, critical
        print(ns.PREFIX .. ("ammo alerts at %d (low) and %d (critical)"):format(warn, critical))
        Check()
        return
    end

    local ammoID, count = Read()
    if ammoID then
        local _, link = (C_Item and C_Item.GetItemInfo or GetItemInfo)(ammoID)
        print(ns.PREFIX .. ("%s: %d. Alerts at %d and %d."):format(link or ("item " .. ammoID), count,
            cfg.warn, cfg.critical))
    else
        print(ns.PREFIX .. "no ammo equipped.")
    end
end

function Ammo:Init()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function() Check() end)
end
