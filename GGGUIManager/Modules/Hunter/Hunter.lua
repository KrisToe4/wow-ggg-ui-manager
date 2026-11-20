local addonName, ns = ...

-- Hunter: small hunter tools (SDD section 7.2), converted from the personal HunterKit addon. For Hunters only.
-- This file registers the module, owns its settings and the /ggg hunter command. Each tool is its own file that
-- adds itself to Hunter.parts: Ammo, Pet, DeadZone, Macros.

local Hunter = {}
ns:RegisterModule("Hunter", Hunter)
ns.Hunter = Hunter

Hunter.classes = { "HUNTER" }
Hunter.parts = {}      -- [name] = { Init = function(), Command = function(rest) }
Hunter.partOrder = {}
Hunter.active = false  -- parts check this so a disabled module stays quiet

function Hunter:AddPart(name, part)
    self.parts[name] = part
    self.partOrder[#self.partOrder + 1] = name
end

-- Shows a message in chat and in the text in the middle of the screen, with an optional sound.
function Hunter.Alert(text, sound)
    print(ns.PREFIX .. text)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, 0.82, 0.2, 1) end
    if sound and SOUNDKIT and SOUNDKIT[sound] then PlaySound(SOUNDKIT[sound]) end
end

local defaultSettings = {
    ammo = { warn = 200, critical = 50 },
    pet = { alerts = true },
    deadzone = { enabled = true, point = { "CENTER", "UIParent", "CENTER", 0, 160 } },
}

function Hunter:Init(settings)
    ns.MergeDefaults(settings, defaultSettings)
    self.settings = settings
    for _, name in ipairs(self.partOrder) do
        local part = self.parts[name]
        if part.Init then
            local ok, err = pcall(part.Init, part)
            if not ok then print(ns.PREFIX .. ("Hunter part %s failed: %s"):format(name, tostring(err))) end
        end
    end
end

function Hunter:Enable()
    self.active = true
    for _, name in ipairs(self.partOrder) do
        local part = self.parts[name]
        if part.Enable then pcall(part.Enable, part) end
    end
end

function Hunter:Disable()
    self.active = false
    for _, name in ipairs(self.partOrder) do
        local part = self.parts[name]
        if part.Disable then pcall(part.Disable, part) end
    end
end

---------------------------------------------------------------------
-- /ggg hunter
---------------------------------------------------------------------
local HELP = {
    "  /ggg hunter ammo   show your ammo. ammo <warn> <critical> sets the alert counts",
    "  /ggg hunter pet   show pet mood, level and training points. pet alerts turns pet alerts on or off",
    "  /ggg hunter deadzone   on, off, unlock or lock the dead zone warning",
    "  /ggg hunter macros   create or update the hunter macros",
    "  /ggg hunter range   print the range measurements for your target (experiment)",
    "  /ggg hunter buttons   list which aspect, tracking and pet spells the game says you know",
}

local PART_FOR_WORD = { ammo = "Ammo", pet = "Pet", deadzone = "DeadZone", macros = "Macros", range = "Indicators", buttons = "Buttons" }

ns:RegisterCommand("hunter", function(rest)
    if not Hunter.settings then
        print(ns.PREFIX .. "this character is not a hunter.")
        return
    end
    local word, arg = rest:match("^(%S*)%s*(.*)$")
    local part = Hunter.parts[PART_FOR_WORD[(word or ""):lower()]]
    if part and part.Command then
        part:Command(arg or "")
        return
    end
    print(ns.PREFIX .. "hunter commands:")
    for _, line in ipairs(HELP) do print(line) end
end, "ammo | pet | deadzone | macros | range | buttons (hunters only)")
