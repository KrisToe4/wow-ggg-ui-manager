local addonName, ns = ...

-- Cluster part: the player frame (SDD CLU-06). Built with the shared unit frame helper in UnitFrame.lua.

local Cluster = ns.Cluster

Cluster:AddPart("PlayerFrame", {
    area = "player",
    defaultFrames = { "PlayerFrame" },
    Build = function(container, rect)
        Cluster.CreateUnitFrame({
            globalName = "GGGUIManagerClusterPlayer",
            unit = "player",
            container = container,
            rect = rect,
        })
    end,
})
