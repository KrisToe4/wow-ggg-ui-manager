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
local BUTTON_SIZE, BUTTON_GAP = 32, 2                -- action buttons (CLU-11, CLU-17)
local BAR_W = 3 * BUTTON_SIZE + 2 * BUTTON_GAP        -- one action bar: 3 columns
local BAR_H = 4 * BUTTON_SIZE + 3 * BUTTON_GAP        -- and 4 rows
local UNIT_W = 240                                    -- player area, pet area
local PARTY_H = 40                                    -- the party row
local EXTRA_H = 46                                    -- room under the bars for two more rows of 22 px buttons (CLU-19)
local MAIN_H = BAR_H + EXTRA_H                        -- height under the party row
local OFFSET_Y = 24                                   -- distance from the bottom of the screen

-- Rectangles are { x, y, w, h } measured from the container's top left corner, y going down.
local x_bar2 = BAR_W + GAP
local x_player = BAR_W * 2 + GAP * 2
local x_pet = x_player + UNIT_W + GAP
local x_bar3 = x_pet + UNIT_W + GAP
local x_bar4 = x_bar3 + BAR_W + GAP
local mainY = PARTY_H + GAP

local CONTAINER_W = x_bar4 + BAR_W
local CONTAINER_H = PARTY_H + GAP + MAIN_H

Cluster.BUTTON_SIZE, Cluster.BUTTON_GAP = BUTTON_SIZE, BUTTON_GAP

Cluster.areas = {
    party   = { x_player, 0, UNIT_W * 2 + GAP, PARTY_H, "Party frames" },
    bar1    = { 0, mainY, BAR_W, BAR_H, "Action bar 1" },
    bar2    = { x_bar2, mainY, BAR_W, BAR_H, "Action bar 2" },
    player  = { x_player, mainY, UNIT_W, MAIN_H, "Player" },
    pet     = { x_pet, mainY, UNIT_W, MAIN_H, "Pet and pet bar" },
    bar3    = { x_bar3, mainY, BAR_W, BAR_H, "Action bar 3" },
    bar4    = { x_bar4, mainY, BAR_W, BAR_H, "Action bar 4" },
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
      -- The party row stays reserved but its placeholder is not drawn until the party frames are built.
      if name ~= "party" then
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

local MANAGER_GETTERS = { "GetPlayerBottomManagedFrameContainer", "GetBottomManagedFrameContainer",
    "GetRightManagedFrameContainer" }

-- Some default frames (the pet frame, the cooldown viewers) are "managed frames": whenever one is shown,
-- Blizzard's layout code moves it back out of the hidden frame. So the layout code is told to leave it alone,
-- it is forgotten by the containers that already have it, and if anything moves it back it is buried again.
local function Bury(frame)
    frame:UnregisterAllEvents()
    frame.ignoreFramePositionManager = true
    for _, getter in ipairs(MANAGER_GETTERS) do
        local get = _G[getter]
        local container = get and get()
        if container and container.showingFrames then container.showingFrames[frame] = nil end
    end
    frame:SetParent(graveyard)
    if not frame.gggBuried then
        frame.gggBuried = true
        hooksecurefunc(frame, "SetParent", function(self, parent)
            if parent ~= graveyard and Cluster.settings and Cluster.settings.hideDefaults then
                ns:AfterCombat(function() self:SetParent(graveyard) end)
            end
        end)
    end
end

local function HideFrames(names)
    graveyard = graveyard or CreateFrame("Frame")
    graveyard:Hide()
    for _, frameName in ipairs(names) do
        local frame = _G[frameName]
        if frame then
            local ok, err = pcall(Bury, frame)
            if not ok then print(ns.PREFIX .. ("could not hide %s: %s"):format(frameName, tostring(err))) end
        end
    end
end

-- Default frames that other modules replace, for example the essential cooldowns viewer. The utility cooldowns
-- viewer is hidden for now and comes into the layout later.
local extraDefaultFrames = { "UtilityCooldownViewer" }

local function HideDefaultFrames()
    local names = {}
    for _, name in ipairs(Cluster.partOrder) do
        for _, frameName in ipairs(Cluster.parts[name].defaultFrames or {}) do names[#names + 1] = frameName end
    end
    for _, frameName in ipairs(extraDefaultFrames) do names[#names + 1] = frameName end
    HideFrames(names)
end

-- Another module that replaces a default frame (CLU-15) hands its name here. It is hidden with the others when
-- hiding is on.
function Cluster:ReplaceDefaultFrame(frameName)
    extraDefaultFrames[#extraDefaultFrames + 1] = frameName
    if self.built and self.settings.hideDefaults then
        ns:AfterCombat(HideFrames, { frameName })
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

-- Other modules place their own widgets in the free space of an area once the container exists (CLU-18).
local builtCallbacks = {}

function Cluster:OnBuilt(func)
    if self.built then
        func(container, self.areas)
    else
        builtCallbacks[#builtCallbacks + 1] = func
    end
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
    self.built = true
    for _, func in ipairs(builtCallbacks) do
        local ok, err = pcall(func, container, self.areas)
        if not ok then print(ns.PREFIX .. "Cluster callback failed: " .. tostring(err)) end
    end
    builtCallbacks = {}
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
    elseif word == "bars" then
        Cluster.PrintBarsCheck()
    elseif word == "petbar" then
        local button = _G.GGGUIManagerClusterPetAction1
        print(ns.PREFIX .. "pet bar check, pet exists: " .. tostring(UnitExists("pet")))
        print(("  ActionButtonUseKeyDown cvar: %s"):format(tostring(GetCVar and GetCVar("ActionButtonUseKeyDown"))))
        if not button then
            print("  button 1 does not exist.")
        else
            print(("  button 1: shown=%s type1=%s action=%s useOnKeyDown=%s"):format(tostring(button:IsShown()),
                tostring(button:GetAttribute("type1")), tostring(button:GetAttribute("action")),
                tostring(button:GetAttribute("useOnKeyDown"))))
            print(("  GetPetActionInfo(1): %s"):format(tostring((GetPetActionInfo(1)))))
            print(("  PetHasActionBar: %s"):format(tostring(PetHasActionBar and PetHasActionBar())))
        end
    elseif word == "pet" then
        print(ns.PREFIX .. "pet happiness search, pet exists: " .. tostring(UnitExists("pet")))
        local found = {}
        for key, value in pairs(_G) do
            if type(key) == "string" and key:lower():find("happi") then
                found[#found + 1] = key .. " (" .. type(value) .. ")"
            end
        end
        for _, tableName in ipairs({ "C_PetInfo", "C_Pet", "C_StableInfo", "C_UnitAuras" }) do
            local t = _G[tableName]
            if type(t) == "table" then
                for key in pairs(t) do
                    if type(key) == "string" and (key:lower():find("happi") or key:lower():find("mood")) then
                        found[#found + 1] = tableName .. "." .. key
                    end
                end
            end
        end
        table.sort(found)
        print("  names with 'happi': " .. (#found > 0 and table.concat(found, ", ") or "none"))
        local face = _G.PetFrameHappiness
        print(("  PetFrameHappiness: exists=%s shown=%s tooltip=%s"):format(tostring(face ~= nil),
            tostring(face and face.IsShown and face:IsShown()), tostring(face and face.tooltip)))
        print("  UnitHappiness: " .. tostring(_G.UnitHappiness) .. ", GetPetLoyalty: " .. tostring(_G.GetPetLoyalty))
        local api = (C_PetInfo and C_PetInfo.GetPetHappiness) or GetPetHappiness
        if api then
            local happiness, damage, loyalty = api()
            print(("  GetPetHappiness returns: happiness=%s damage=%s loyalty=%s"):format(
                tostring(happiness), tostring(damage), tostring(loyalty)))
        end
    elseif word == "hide" and OnOff(arg) ~= nil then
        settings.hideDefaults = OnOff(arg)
        print(ns.PREFIX .. (settings.hideDefaults
            and "default frames will be hidden. Reload the interface to apply."
            or "default frames will show again. Reload the interface to apply."))
    elseif word == "layout" and OnOff(arg) ~= nil then
        settings.showLayout = OnOff(arg)
        ApplyPlaceholders()
    else
        print(ns.PREFIX .. "usage: /ggg cluster check | pet | petbar | bars | hide on|off | layout on|off")
        print(("  default frames hidden: %s, layout boxes: %s"):format(
            settings.hideDefaults and "yes" or "no", settings.showLayout and "shown" or "hidden"))
    end
end, "check | pet | petbar | bars | hide on|off | layout on|off")
