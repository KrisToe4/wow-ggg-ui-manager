local addonName, ns = ...

-- Cluster part: the pet frame (SDD CLU-07, CLU-08). It sits at the top of the inner right area and is shown only
-- while the player has a pet. The rest of the area is kept for the pet bar (a later step), so the layout does not
-- move when the pet appears or goes.

local Cluster = ns.Cluster

Cluster:AddPart("PetFrame", {
    area = "pet",
    defaultFrames = { "PetFrame" },
    Build = function(container, rect)
        Cluster.CreateUnitFrame({
            globalName = "GGGUIManagerClusterPet",
            unit = "pet",
            container = container,
            rect = rect,
            hideWhenMissing = true,
            happiness = true,
        })
    end,
})
