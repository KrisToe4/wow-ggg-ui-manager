local addonName, ns = ...

-- Cluster: a replacement player and pet layout at the bottom centre of the screen (SDD section 7.1).
-- This file registers the module, builds the container and marks the layout areas. Each part (player frame and
-- later the pet frame, pet bar, party frames and action bars) is its own file that adds itself to Cluster.parts.

local Cluster = {}
ns:RegisterModule("Cluster", Cluster)
ns.Cluster = Cluster

Cluster.parts = {}      -- [name] = { area = "player", defaultFrames = { "PlayerFrame" }, Build = function(container, rect) }
Cluster.partOrder = {}

function Cluster:AddPart(name, part)
    self.parts[name] = part
    self.partOrder[#self.partOrder + 1] = name
end

---------------------------------------------------------------------
-- Layout (CLU-03). All sizes are defaults to adjust after seeing them in the game.
---------------------------------------------------------------------
local GAP = 6
local BAR_W, BAR_H = 180, 60       -- one action bar area
local UNIT_W = 240                 -- player area, pet area
local PARTY_H = 40                 -- the party row
local MAIN_H = BAR_H * 2 + GAP     -- height under the party row
local OFFSET_Y = 24                -- distance from the bottom of the screen

local CONTAINER_W = BAR_W * 2 + UNIT_W * 2 + GAP * 3
local CONTAINER_H = PARTY_H + GAP + MAIN_H

-- Rectangles are { x, y, w, h } measured from the container's top left corner, y going down.
local x_player = BAR_W + GAP
local x_pet = x_player + UNIT_W + GAP
local x_right = x_pet + UNIT_W + GAP
local mainY = PARTY_H + GAP

Cluster.areas = {
    party   = { x_player, 0, UNIT_W * 2 + GAP, PARTY_H, "Party frames" },
    bar1    = { 0, mainY, BAR_W, BAR_H, "Action bar 1" },
    bar2    = { 0, mainY + BAR_H + GAP, BAR_W, BAR_H, "Action bar 2" },
    player  = { x_player, mainY, UNIT_W, MAIN_H, "Player" },
    pet     = { x_pet, mainY, UNIT_W, MAIN_H, "Pet and pet bar" },
    bar3    = { x_right, mainY, BAR_W, BAR_H, "Action bar 3" },
    bar4    = { x_right, mainY + BAR_H + GAP, BAR_W, BAR_H, "Action bar 4" },
}

---------------------------------------------------------------------
-- Container and placeholders
---------------------------------------------------------------------
local container
local placeholders = {}

local function BuildContainer()
    container = CreateFrame("Frame", "GGGUIManagerClusterContainer", UIParent)
    container:SetSize(CONTAINER_W, CONTAINER_H)
    container:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, OFFSET_Y)
    container:SetFrameStrata("LOW")

    for name, rect in pairs(Cluster.areas) do
        local box = container:CreateTexture(nil, "BACKGROUND")
        box:SetPoint("TOPLEFT", container, "TOPLEFT", rect[1], -rect[2])
        box:SetSize(rect[3], rect[4])
        box:SetColorTexture(0, 0, 0, 0.35)
        local label = container:CreateFontString(nil, "BACKGROUND", "GameFontDisableSmall")
        label:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
        label:SetText(rect[5])
        placeholders[#placeholders + 1] = box
        placeholders[#placeholders + 1] = label
    end
end

local function ApplyPlaceholders()
    for _, region in ipairs(placeholders) do
        region:SetShown(Cluster.settings.showLayout)
    end
end

---------------------------------------------------------------------
-- Hiding Blizzard's frames (CLU-04, CLU-15)
---------------------------------------------------------------------
-- A hidden frame takes the default frames as children. Moving a protected frame is not allowed in combat,
-- so this runs through ns:AfterCombat. Nothing of Blizzard's code is edited or replaced (INV-02).
local graveyard

local function HideDefaultFrames()
    graveyard = graveyard or CreateFrame("Frame")
    graveyard:Hide()
    for _, name in ipairs(Cluster.partOrder) do
        for _, frameName in ipairs(Cluster.parts[name].defaultFrames or {}) do
            local frame = _G[frameName]
            if frame then
                frame:UnregisterAllEvents()
                frame:SetParent(graveyard)
            end
        end
    end
end

---------------------------------------------------------------------
-- Module functions
---------------------------------------------------------------------
local defaultSettings = { hideDefaults = false, showLayout = true }

function Cluster:Init(settings)
    for key, value in pairs(defaultSettings) do
        if settings[key] == nil then settings[key] = value end
    end
    self.settings = settings
    ns:AfterCombat(function() self:Build() end)
end

function Cluster:Build()
    if container then return end
    BuildContainer()
    ApplyPlaceholders()
    for _, name in ipairs(self.partOrder) do
        local part = self.parts[name]
        local ok, err = pcall(part.Build, container, self.areas[part.area])
        if not ok then print(ns.PREFIX .. ("Cluster part %s failed: %s"):format(name, tostring(err))) end
    end
    if self.settings.hideDefaults then HideDefaultFrames() end
end

function Cluster:Enable()
    if container then container:Show() end
end

function Cluster:Disable()
    if container then container:Hide() end
    print(ns.PREFIX .. "Cluster is off. Reload the interface to get the default frames back if they were hidden.")
end

---------------------------------------------------------------------
-- /ggg cluster
---------------------------------------------------------------------
local SECRET_CHECKS = {
    { "UnitHealth", function() return UnitHealth("player") end },
    { "UnitHealthMax", function() return UnitHealthMax("player") end },
    { "UnitPower", function() return UnitPower("player") end },
    { "UnitPowerMax", function() return UnitPowerMax("player") end },
    { "UnitName", function() return (UnitName("player")) end },
}

local function RunCheck()
    if not issecretvalue then
        print(ns.PREFIX .. "this client has no issecretvalue, so values are never secret.")
        return
    end
    print(ns.PREFIX .. ("secret value check, %s:"):format(InCombatLockdown() and "in combat" or "out of combat"))
    for _, check in ipairs(SECRET_CHECKS) do
        local ok, value = pcall(check[2])
        local result = not ok and "error" or (issecretvalue(value) and "SECRET" or "readable")
        print(("  %s: %s"):format(check[1], result))
    end
end

local function OnOff(word)
    if word == "on" then return true end
    if word == "off" then return false end
    return nil
end

ns:RegisterCommand("cluster", function(rest)
    local settings = Cluster.settings
    if not settings then
        print(ns.PREFIX .. "Cluster is not running.")
        return
    end
    local word, arg = rest:lower():match("^(%S*)%s*(%S*)$")
    if word == "check" then
        RunCheck()
    elseif word == "hide" and OnOff(arg) ~= nil then
        settings.hideDefaults = OnOff(arg)
        print(ns.PREFIX .. (settings.hideDefaults
            and "default frames will be hidden. Reload the interface to apply."
            or "default frames will show again. Reload the interface to apply."))
    elseif word == "layout" and OnOff(arg) ~= nil then
        settings.showLayout = OnOff(arg)
        ApplyPlaceholders()
    else
        print(ns.PREFIX .. "usage: /ggg cluster check | hide on|off | layout on|off")
        print(("  default frames hidden: %s, layout boxes: %s"):format(
            settings.hideDefaults and "yes" or "no", settings.showLayout and "shown" or "hidden"))
    end
end, "check | hide on|off | layout on|off")
