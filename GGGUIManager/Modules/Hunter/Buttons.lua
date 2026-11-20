local addonName, ns = ...

-- Hunter part: spell buttons in the Cluster (SDD HUN-15, HUN-16).
--   Aspects (from the left) and Tracking (from the right) share one row in the player area, under the range indicator
--   Pet action row                in the pet area, under the pet bar
-- Each button is a secure "spell" button, so clicking works in combat without addon code. Only the spells the
-- character knows are shown. Showing and hiding buttons is a protected change, so it only happens out of combat.

local Hunter = ns.Hunter
local Buttons = {}
Hunter:AddPart("Buttons", Buttons)

local SIZE, GAP = 22, 2
local ROW_GAP = 4

local ASPECTS = { "Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Cheetah", "Aspect of the Pack",
    "Aspect of the Wild", "Aspect of the Beast", "Aspect of the Viper", "Aspect of the Wolf",
    "Aspect of the Dragonhawk" }
local TRACKING = { "Track Beasts", "Track Humanoids", "Track Hidden", "Track Elementals", "Track Undead",
    "Track Demons", "Track Giants", "Track Dragonkin" }
local PET_ACTIONS = { "Revive Pet", "Dismiss Pet", "Feed Pet", "Tame Beast", "Beast Lore" }
-- The three used most get wide buttons in a row of their own under the small ones (HUN-16). They keep fixed slots.
local PET_BIG = { "Call Pet", "Mend Pet", "Beast Training" }
local BIG_H = 30
local PET_TARGET = { ["Mend Pet"] = "pet" } -- the unit the spell is cast on, when it is not the current target

local rows = {}

---------------------------------------------------------------------
-- Spell data
---------------------------------------------------------------------
-- The game returns data for a spell name only when the spell is in the character's spellbook.
-- Returns spellID and icon, or nil when the spell is not known.
local function SpellData(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        if ok and type(info) == "table" then return info.spellID, info.iconID end
    end
    if GetSpellInfo then
        local ok, _, _, icon, _, _, _, id = pcall(GetSpellInfo, name)
        if ok and (id or icon) then return id, icon end
    end
    return nil
end

local function IsActive(row, name)
    local ok, result = pcall(function()
        if row.kind == "aspect" then
            if AuraUtil and AuraUtil.FindAuraByName then return AuraUtil.FindAuraByName(name, "player") ~= nil end
        elseif row.kind == "tracking" then
            if GetTrackingTexture then
                local _, icon = SpellData(name)
                return icon ~= nil and GetTrackingTexture() == icon
            end
        end
        return false
    end)
    return ok and result or false
end

---------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------
local function UpdateCooldown(button)
    local cooldown = button.cooldown
    local ok = pcall(function()
        if C_Spell and C_Spell.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
            cooldown:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(button.spell))
        elseif C_Spell and C_Spell.GetSpellCooldown then
            local info = C_Spell.GetSpellCooldown(button.spell)
            if info and info.duration and info.duration > 0 then
                cooldown:SetCooldown(info.startTime, info.duration)
            else
                cooldown:Clear()
            end
        end
    end)
    if not ok then cooldown:Clear() end
end

local function CreateButton(parent, name, index, spellName, big)
    local button = CreateFrame("Button", "GGGUIManagerHunter" .. name .. "Button" .. index, parent,
        "SecureActionButtonTemplate")
    button:SetSize(big and big.width or SIZE, big and big.height or SIZE)
    button.spell = spellName
    button:SetAttribute("type", "spell")
    button:SetAttribute("spell", spellName)
    if PET_TARGET[spellName] then button:SetAttribute("unit", PET_TARGET[spellName]) end
    button:SetAttribute("useOnKeyDown", false) -- same reason as the pet bar (D-018)
    button:RegisterForClicks("AnyUp")

    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.6)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if big then
        -- A wide button: a square icon on the left and the spell name beside it.
        button.icon:SetSize(big.height - 2, big.height - 2)
        button.icon:SetPoint("LEFT", 1, 0)
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", button.icon, "RIGHT", 3, 0)
        label:SetPoint("RIGHT", button, "RIGHT", -2, 0)
        label:SetJustifyH("CENTER")
        label:SetText(spellName)
        button.label = label
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.12)
    else
        button.icon:SetPoint("TOPLEFT", 1, -1)
        button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints()

    -- A green tint on the aspect or tracking that is on now.
    button.active = button:CreateTexture(nil, "OVERLAY")
    button.active:SetAllPoints()
    button.active:SetColorTexture(0.2, 1, 0.2, 0.35)
    button.active:Hide()

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local id = SpellData(self.spell)
        if not (id and pcall(GameTooltip.SetSpellByID, GameTooltip, id)) then GameTooltip:SetText(self.spell) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

local function Refresh(row)
    for _, button in ipairs(row.buttons) do
        if button:IsShown() then
            UpdateCooldown(button)
            button.active:SetShown(IsActive(row, button.spell))
        end
    end
end

-- Shows the known spells in a line from the left and hides the rest. Needs to be out of combat.
local function Layout(row)
    if InCombatLockdown() then
        ns:AfterCombat(Layout, row)
        return
    end
    local x = 0
    for index, button in ipairs(row.buttons) do
        if row.fixed then x = (index - 1) * row.step end
        local id, icon = SpellData(button.spell)
        if id or icon then
            if not icon and C_Spell and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(button.spell) end
            button.icon:SetTexture(icon)
            button:ClearAllPoints()
            if row.fromRight then
                button:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT", -x, 0)
            else
                button:SetPoint("TOPLEFT", row.frame, "TOPLEFT", x, 0)
            end
            button:Show()
            x = x + (row.step or (SIZE + GAP))
        else
            button:Hide()
        end
    end
    Refresh(row)
end

local function BuildRow(container, name, kind, left, top, width, spells, fromRight, big)
    local frame = CreateFrame("Frame", "GGGUIManagerHunter" .. name, container)
    frame:SetPoint("TOPLEFT", container, "TOPLEFT", left, -top)
    frame:SetSize(width, big and big.height or SIZE)
    local row = { name = name, kind = kind, frame = frame, buttons = {}, fromRight = fromRight }
    if big then row.step, row.fixed = big.width + GAP, true end
    for index, spellName in ipairs(spells) do
        row.buttons[index] = CreateButton(frame, name, index, spellName, big)
        row.buttons[index]:Hide()
    end
    rows[#rows + 1] = row
    Layout(row)
end

local function Build(container, areas)
    local Cluster = ns.Cluster
    local player, pet = areas.player, areas.pet

    local top = Hunter.playerWidgetsBottom or (player[2] + Cluster.UNIT_FRAME_HEIGHT + 6 + 22 + 4 + 20)
    BuildRow(container, "Aspects", "aspect", player[1], top + ROW_GAP, player[3], ASPECTS)
    -- Tracking shares the row with the aspects and grows from the right edge.
    BuildRow(container, "Tracking", "tracking", player[1], top + ROW_GAP, player[3], TRACKING, true)

    -- Under the pet bar, which is one 22 px row under the pet frame (PetBar.lua).
    local petTop = pet[2] + Cluster.UNIT_FRAME_HEIGHT + 6 + SIZE + ROW_GAP
    BuildRow(container, "PetActions", "pet", pet[1], petTop, pet[3], PET_ACTIONS)
    -- Call Pet, Mend Pet and Beast Training: three wide buttons sharing the pet area's width.
    BuildRow(container, "PetBig", "pet", pet[1], petTop + SIZE + ROW_GAP, pet[3], PET_BIG, false,
        { width = math.floor((pet[3] - GAP * (#PET_BIG - 1)) / #PET_BIG), height = BIG_H })

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "LEARNED_SPELL_IN_TAB", "UNIT_AURA",
        "MINIMAP_UPDATE_TRACKING", "SPELL_UPDATE_COOLDOWN" }) do
        pcall(events.RegisterEvent, events, event) -- an event this client lacks is skipped (INV-08)
    end
    events:SetScript("OnEvent", function(_, event, unit)
        if not Hunter.active then return end
        if event == "UNIT_AURA" and unit ~= "player" then return end
        local relayout = event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD"
            or event == "LEARNED_SPELL_IN_TAB"
        for _, row in ipairs(rows) do
            pcall(relayout and Layout or Refresh, row)
        end
    end)
end

function Buttons:Init()
    -- Shown only inside the Cluster, once it is built (HUN-14).
    if ns.Cluster then ns.Cluster:OnBuilt(Build) end
end

---------------------------------------------------------------------
-- /ggg hunter buttons: which spells the game says the character knows
---------------------------------------------------------------------
function Buttons:Command()
    print(ns.PREFIX .. "hunter button spells (shown when the game finds the spell by name):")
    for _, group in ipairs({ { "Aspects", ASPECTS }, { "Tracking", TRACKING }, { "Pet actions", PET_ACTIONS }, { "Big pet buttons", PET_BIG } }) do
        local found, missing = {}, {}
        for _, spell in ipairs(group[2]) do
            if SpellData(spell) then found[#found + 1] = spell else missing[#missing + 1] = spell end
        end
        print(("  %s found: %s"):format(group[1], #found > 0 and table.concat(found, ", ") or "none"))
        print(("  %s not found: %s"):format(group[1], #missing > 0 and table.concat(missing, ", ") or "none"))
    end
end
