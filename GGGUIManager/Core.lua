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

local function StartModules()
    for _, name in ipairs(ns.moduleOrder) do
        local module = ns.modules[name]
        local settings = ns:ModuleDB(name)
        if Call(module, "Init", settings) and settings.enabled then
            Call(module, "Enable")
        end
    end
end

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, arg1)
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

SlashCmdList.GGGUIMANAGER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" or msg == "help" then
        print(ns.PREFIX .. "version " .. ns.version)
        print("  /ggg help   show this list")
        print("  /ggg modules   list the loaded modules")
    elseif msg == "modules" then
        if #ns.moduleOrder == 0 then
            print(ns.PREFIX .. "no modules yet.")
            return
        end
        for _, name in ipairs(ns.moduleOrder) do
            local enabled = ns:ModuleDB(name).enabled
            print(("  %s: %s"):format(name, enabled and "on" or "off"))
        end
    else
        print(ns.PREFIX .. "unknown command. Try /ggg help")
    end
end
