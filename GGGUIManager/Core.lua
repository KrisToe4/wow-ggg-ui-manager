local addonName, ns = ...

-- GGG UI Manager: the shell.
-- This file is the whole addon for now. It owns the saved data, the module registry and the slash command.
-- Features arrive later as modules in their own files (SDD section 7). See docs/SDD.md.

ns.name = "GGG UI Manager"
ns.PREFIX = "|cffff69b4GGG UI Manager:|r "

local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = GetMetadata and GetMetadata(addonName, "Version") or "unknown"

---------------------------------------------------------------------
-- Saved data (SDD section 6)
---------------------------------------------------------------------
local SCHEMA_VERSION = 1

local defaults = {
    schemaVersion = SCHEMA_VERSION,
    modules = {}, -- ["ModuleName"] = { enabled = true, ... } filled in by each module
}

-- Copies any missing key from `source` into `target`, including inside nested tables.
local function MergeDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

-- Brings old saved data up to the current schema. Each step runs once, in order.
local migrations = {
    -- [2] = function(db) ... end,
}

local function Migrate(db)
    local from = db.schemaVersion or 0
    for version = from + 1, SCHEMA_VERSION do
        if migrations[version] then migrations[version](db) end
    end
    db.schemaVersion = SCHEMA_VERSION
end

---------------------------------------------------------------------
-- Modules (SDD section 7)
---------------------------------------------------------------------
-- A module is a table with optional Init, Enable and Disable functions.
-- Every call is wrapped so a broken module cannot stop the others from loading.
ns.modules = {}
ns.moduleOrder = {}

function ns:RegisterModule(name, module)
    assert(type(name) == "string" and not ns.modules[name], "GGG UI Manager: bad or duplicate module name")
    module.name = name
    ns.modules[name] = module
    ns.moduleOrder[#ns.moduleOrder + 1] = name
    return module
end

local function Call(module, method, ...)
    if type(module[method]) ~= "function" then return true end
    local ok, err = pcall(module[method], module, ...)
    if not ok then
        print(ns.PREFIX .. ("module %s failed in %s: %s"):format(module.name, method, tostring(err)))
    end
    return ok
end

-- The saved settings table for one module.
function ns:ModuleDB(name)
    local modules = ns.db.modules
    modules[name] = modules[name] or { enabled = true }
    return modules[name]
end

-- True when the module has no `classes` list or the player's class is in it (MOD-06).
function ns:ModuleIsForThisClass(module)
    if type(module.classes) ~= "table" then return true end
    local _, class = UnitClass("player")
    for _, token in ipairs(module.classes) do
        if token == class then return true end
    end
    return false
end

local function StartModules()
    for _, name in ipairs(ns.moduleOrder) do
        local module = ns.modules[name]
        if ns:ModuleIsForThisClass(module) then
            local settings = ns:ModuleDB(name)
            if Call(module, "Init", settings) and settings.enabled then
                Call(module, "Enable")
            end
        end
    end
end

---------------------------------------------------------------------
-- Combat queue (SDD LIF-06, INV-01)
---------------------------------------------------------------------
-- Work that must not run in combat is passed to ns:AfterCombat. It runs at once when the player is out of
-- combat, otherwise when combat ends, in the order it was queued.
local queue = {}

function ns:AfterCombat(func, ...)
    if not InCombatLockdown() then
        func(...)
        return
    end
    queue[#queue + 1] = { func = func, n = select("#", ...), ... }
end

local function RunQueue()
    local pending = queue
    queue = {}
    for _, item in ipairs(pending) do
        local ok, err = pcall(item.func, unpack(item, 1, item.n))
        if not ok then print(ns.PREFIX .. "queued work failed: " .. tostring(err)) end
    end
end

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_REGEN_ENABLED" then
        RunQueue()
        return
    end
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        GGGUIManagerDB = GGGUIManagerDB or {}
        Migrate(GGGUIManagerDB)
        MergeDefaults(GGGUIManagerDB, defaults)
        ns.db = GGGUIManagerDB
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        StartModules()
    end
end)

---------------------------------------------------------------------
-- Slash commands: /ggg or /gggui
---------------------------------------------------------------------
SLASH_GGGUIMANAGER1 = "/ggg"
SLASH_GGGUIMANAGER2 = "/gggui"

-- Sub-commands added by modules (MOD-05, CMD-05): /ggg <name> <rest of the line>
local commands = {}
local commandOrder = {}
local RESERVED = { help = true, modules = true }

function ns:RegisterCommand(name, handler, helpText)
    assert(type(name) == "string" and name ~= "" and type(handler) == "function",
        "GGG UI Manager: bad command registration")
    name = name:lower()
    assert(not RESERVED[name] and not commands[name], "GGG UI Manager: duplicate command name " .. name)
    commands[name] = handler
    commandOrder[#commandOrder + 1] = { name = name, help = helpText or "" }
end

local function PrintModules()
    if #ns.moduleOrder == 0 then
        print(ns.PREFIX .. "no modules yet.")
        return
    end
    for _, name in ipairs(ns.moduleOrder) do
        local state
        if not ns:ModuleIsForThisClass(ns.modules[name]) then
            state = "not for this class"
        else
            state = ns:ModuleDB(name).enabled and "on" or "off"
        end
        print(("  %s: %s"):format(name, state))
    end
end

SlashCmdList.GGGUIMANAGER = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local word, rest = msg:match("^(%S*)%s*(.*)$")
    word = word:lower()
    if word == "" or word == "help" then
        print(ns.PREFIX .. "version " .. ns.version)
        print("  /ggg help   show this list")
        print("  /ggg modules   list the loaded modules")
        for _, command in ipairs(commandOrder) do
            print(("  /ggg %s   %s"):format(command.name, command.help))
        end
    elseif word == "modules" then
        PrintModules()
    elseif commands[word] then
        local ok, err = pcall(commands[word], rest)
        if not ok then print(ns.PREFIX .. ("command %s failed: %s"):format(word, tostring(err))) end
    else
        print(ns.PREFIX .. "unknown command. Try /ggg help")
    end
end
