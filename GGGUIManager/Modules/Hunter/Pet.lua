local addonName, ns = ...

-- Hunter part: pet info and alerts (HUN-03, HUN-04, HUN-08).
--   /ggg hunter pet          prints your pet's level, family, mood and training points
--   alerts                   your pet turning unhappy, and your pet gaining training points to spend

local Hunter = ns.Hunter
local Pet = {}
Hunter:AddPart("Pet", Pet)

local MOOD = { [1] = "unhappy", [2] = "content", [3] = "happy" }

local lastMood
local lastPoints

local function Points()
    if not GetPetTrainingPoints then return nil end
    local total, spent = GetPetTrainingPoints()
    if not total then return nil end
    return total - (spent or 0)
end

local function CheckMood()
    local mood = ns.GetPetMood()
    if not mood then return end
    if Hunter.active and Hunter.settings.pet.alerts and lastMood and mood < lastMood and mood == 1 then
        Hunter.Alert(("%s is unhappy! Feed it."):format(UnitName("pet") or "Your pet"), "RAID_WARNING")
    end
    lastMood = mood
end

local function CheckPoints()
    local points = Points()
    if not points then return end
    if Hunter.active and Hunter.settings.pet.alerts and lastPoints and points > lastPoints and points > 0 then
        Hunter.Alert(("%s has %d training points to spend. Cast Beast Training."):format(
            UnitName("pet") or "Your pet", points))
    end
    lastPoints = points
end

function Pet:Command(text)
    local settings = Hunter.settings.pet
    if text:lower() == "alerts" then
        settings.alerts = not settings.alerts
        print(ns.PREFIX .. "pet alerts are " .. (settings.alerts and "ON" or "OFF"))
        return
    end

    if not UnitExists("pet") then
        print(ns.PREFIX .. "you have no pet out.")
        return
    end

    local mood = ns.GetPetMood()
    local points = Points()
    print(ns.PREFIX .. ("%s, level %d %s"):format(UnitName("pet") or "?", UnitLevel("pet") or 0,
        UnitCreatureFamily("pet") or "pet"))
    if mood then print("  Mood: " .. MOOD[mood]) end
    if points then print(("  Training points to spend: %d"):format(points)) end
end

function Pet:Init()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UNIT_PET")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- An event this client does not have is skipped quietly (INV-08).
    pcall(frame.RegisterEvent, frame, "UNIT_HAPPINESS")
    pcall(frame.RegisterEvent, frame, "UNIT_PET_TRAINING_POINTS")
    frame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_HAPPINESS" then
            CheckMood()
        elseif event == "UNIT_PET_TRAINING_POINTS" then
            CheckPoints()
        elseif event == "UNIT_PET" and unit ~= "player" then
            return
        else
            -- A new pet or a loading screen. Take its current state without announcing it.
            lastMood = ns.GetPetMood()
            lastPoints = Points()
        end
    end)
end
