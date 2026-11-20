local addonName, ns = ...

-- Startup: prints a short message in chat at login (SDD section 7.4). Later it will also apply the player's
-- preferred settings. It is registered last, so it sees the state of every other module.

local Startup = {}
ns:RegisterModule("Startup", Startup)

local DELAY = 2 -- seconds after login, so the message lands after most other addons' own messages (STA-02)

local function ModuleStates()
    local parts = {}
    for _, name in ipairs(ns.moduleOrder) do
        local module = ns.modules[name]
        local state
        if not ns:ModuleIsForThisClass(module) then
            state = "not for this class"
        else
            state = ns:ModuleDB(name).enabled and "on" or "off"
        end
        parts[#parts + 1] = name .. " " .. state
    end
    return table.concat(parts, ", ")
end

local function PrintMessage()
    print(ns.PREFIX .. "version " .. tostring(ns.version) .. ". Type /ggg help for the commands.")
    print(ns.PREFIX .. "modules: " .. ModuleStates())
end

function Startup:Init(settings)
    self.settings = settings
end

function Startup:Enable()
    -- Runs once for each login and reload (STA-03). Zoning does not start it again.
    C_Timer.After(DELAY, PrintMessage)
end

ns:RegisterCommand("startup", function(rest)
    local word = (rest or ""):match("^%s*(%S*)"):lower()
    local settings = ns:ModuleDB("Startup")
    if word == "on" or word == "off" then
        settings.enabled = word == "on"
        print(ns.PREFIX .. ("login message %s. It takes effect at the next login."):format(word))
    else
        PrintMessage()
    end
end, "show the login message again. on | off turns it at login on or off")
