local addonName, ns = ...

-- Hunter part: creates (or updates) a few character macros (HUN-06). Drag them from the macro window (/macro) to
-- your bars. Running /ggg hunter macros again rewrites them, so edit the text here rather than in the game.

local Hunter = ns.Hunter
local Macros = {}
Hunter:AddPart("Macros", Macros)

local MACROS = {
    { name = "HKAttack", body = "#showtooltip Hunter's Mark\n/petattack\n/cast Hunter's Mark" },
    { name = "HKMend", body = "#showtooltip Mend Pet\n/cast Mend Pet" },
    { name = "HKFollow", body = "#showtooltip Call Pet\n/petfollow" },
    { name = "HKStay", body = "#showtooltip\n/petstay" },
}

function Macros:Command()
    if InCombatLockdown() then
        print(ns.PREFIX .. "macros can't be changed in combat.")
        return
    end

    local made, updated = 0, 0
    for _, macro in ipairs(MACROS) do
        local index = GetMacroIndexByName(macro.name)
        if index and index > 0 then
            EditMacro(index, macro.name, nil, macro.body)
            updated = updated + 1
        else
            local _, perCharacter = GetNumMacros()
            if perCharacter >= (MAX_CHARACTER_MACROS or 18) then
                print(ns.PREFIX .. "your character macros are full, so " .. macro.name .. " was not made.")
            elseif CreateMacro(macro.name, "INV_MISC_QUESTIONMARK", macro.body, true) then
                made = made + 1
            end
        end
    end
    print(ns.PREFIX .. ("macros made: %d, updated: %d. Open /macro to drag them to your bars."):format(made, updated))
end
