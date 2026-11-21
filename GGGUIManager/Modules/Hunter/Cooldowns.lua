local addonName, ns = ...

-- Hunter part: your Essential Cooldowns in the player area, to the right of the ammo widget (SDD HUN-18).
-- Blizzard's own Essential Cooldowns frame cannot be moved into the cluster (the client hides its position from
-- addons), so this draws a row of small icons from the same list. The list comes from the Cooldown Manager, so
-- the spells you pick there in its settings are the ones shown here. Icons have a cooldown swipe and a tooltip.

local Hunter = ns.Hunter
local Cooldowns = {}
Hunter:AddPart("Cooldowns", Cooldowns)

local MAX_ICON, MIN_ICON = 22, 14
local GAP = 2
local MAX_SHOWN = 10

local holder
local icons = {}
local shownIDs = {} -- the spell IDs the row is showing now, for the probe

---------------------------------------------------------------------
-- The list
---------------------------------------------------------------------
-- The cooldown IDs the Cooldown Manager shows in its Essential section, in the player's order.
local function CooldownIDs()
    -- Only the game's own C functions are used here. Calling the viewer frame's Lua methods from addon code
    -- spreads taint into the Cooldown Manager, which broke the Tracked Buffs viewer (D-029).
    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet and Enum and Enum.CooldownViewerCategory then
        local ok, ids = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, Enum.CooldownViewerCategory.Essential, false)
        if ok and type(ids) == "table" then return ids, "the Essential category" end
    end
    return {}, "no list available"
end

-- The spell to show for a cooldown ID, or nil when it should not be shown.
local function SpellFor(cooldownID)
    if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then return nil end
    local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
    if not (ok and type(info) == "table") then return nil end
    if info.isInvisible or info.isKnown == false then return nil end
    return info.overrideSpellID or info.spellID
end

---------------------------------------------------------------------
-- Icons
---------------------------------------------------------------------
local function UpdateCooldown(icon)
    local cooldown = icon.cooldown
    local ok = pcall(function()
        -- Cooldown values can be hidden "secret" values in combat, so the duration object is used when it exists.
        if C_Spell and C_Spell.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
            cooldown:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(icon.spellID))
        elseif C_Spell and C_Spell.GetSpellCooldown then
            local info = C_Spell.GetSpellCooldown(icon.spellID)
            if info and info.duration and info.duration > 0 then
                cooldown:SetCooldown(info.startTime, info.duration)
            else
                cooldown:Clear()
            end
        end
    end)
    if not ok then cooldown:Clear() end
end

local function GetIcon(index)
    local icon = icons[index]
    if icon then return icon end
    icon = CreateFrame("Frame", nil, holder)
    icon:EnableMouse(true)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetPoint("TOPLEFT", 1, -1)
    icon.texture:SetPoint("BOTTOMRIGHT", -1, 1)
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local back = icon:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.6)
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints()
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if not (self.spellID and pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)) then GameTooltip:Hide() end
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icons[index] = icon
    return icon
end

-- Rebuilds the row from the list. The icons are plain frames, so this is safe in combat.
local function Rebuild()
    if not holder then return end
    local ids = CooldownIDs()
    local spells = {}
    for _, cooldownID in ipairs(ids) do
        local spellID = SpellFor(cooldownID)
        if spellID then
            spells[#spells + 1] = spellID
            if #spells >= MAX_SHOWN then break end
        end
    end
    shownIDs = spells

    -- The icons shrink to fit when there are many.
    local count = math.max(#spells, 1)
    local size = math.floor((holder:GetWidth() - GAP * (count - 1)) / count)
    size = math.max(MIN_ICON, math.min(MAX_ICON, size))

    for index = 1, math.max(#spells, #icons) do
        local spellID = spells[index]
        if spellID then
            local icon = GetIcon(index)
            icon.spellID = spellID
            icon:SetSize(size, size)
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", holder, "LEFT", (index - 1) * (size + GAP), 0)
            local texture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
            icon.texture:SetTexture(texture)
            icon:Show()
            UpdateCooldown(icon)
        elseif icons[index] then
            icons[index]:Hide()
        end
    end
end

local function RefreshCooldowns()
    for _, icon in ipairs(icons) do
        if icon:IsShown() then UpdateCooldown(icon) end
    end
end

local function Build(container, areas)
    local rect = areas.player
    local ammo = Hunter.ammoRect -- set by Indicators.lua
    local left = ammo and (ammo.x + ammo.width + 4) or (rect[1] + 104)
    local top = ammo and ammo.y or (rect[2] + ns.Cluster.UNIT_FRAME_HEIGHT + 6)
    local width = rect[1] + rect[3] - left

    -- Our row replaces Blizzard's frame, so it is hidden along with the other default frames when that is on.
    ns.Cluster:ReplaceDefaultFrame("EssentialCooldownViewer")

    holder = CreateFrame("Frame", "GGGUIManagerHunterCooldowns", container)
    holder:SetPoint("TOPLEFT", container, "TOPLEFT", left, -top)
    holder:SetSize(width, ammo and ammo.height or MAX_ICON)

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
        "COOLDOWN_VIEWER_DATA_LOADED", "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", "COOLDOWN_VIEWER_TABLE_HOTFIXED",
        "TRAIT_CONFIG_UPDATED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES" }) do
        pcall(events.RegisterEvent, events, event) -- an event this client lacks is skipped (INV-08)
    end
    events:SetScript("OnEvent", function(_, event)
        if not Hunter.active then return end
        if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
            pcall(RefreshCooldowns)
        else
            pcall(Rebuild)
        end
    end)
    pcall(Rebuild)
end

function Cooldowns:Init()
    -- Shown only inside the Cluster, once it is built (HUN-14).
    if ns.Cluster then ns.Cluster:OnBuilt(Build) end
end

function Cooldowns:Enable()
    pcall(Rebuild)
end

---------------------------------------------------------------------
-- /ggg hunter cooldowns: what the Cooldown Manager gives
---------------------------------------------------------------------
function Cooldowns:Command()
    print(ns.PREFIX .. "essential cooldowns check")
    if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then
        print("  this client has no C_CooldownViewer, so there is no list to read.")
        return
    end
    local ids, source = CooldownIDs()
    print(("  list from: %s, %d cooldown IDs, %d icons shown"):format(source, #ids, #shownIDs))
    for index, cooldownID in ipairs(ids) do
        local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
        if ok and type(info) == "table" then
            local spellID = info.overrideSpellID or info.spellID
            local name = spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
            print(("  %d: id %s spell %s (%s) known %s invisible %s"):format(index, tostring(cooldownID),
                tostring(spellID), tostring(name), tostring(info.isKnown), tostring(info.isInvisible)))
        else
            print(("  %d: id %s has no info"):format(index, tostring(cooldownID)))
        end
        if index >= 15 then
            print("  ...")
            break
        end
    end
    print(("  holder: %s"):format(holder and ("%.0f x %.0f"):format(holder:GetWidth(), holder:GetHeight()) or "not built"))
end
