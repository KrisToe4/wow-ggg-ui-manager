local addonName, ns = ...

-- Cluster part: the player frame (SDD CLU-06). Built with the shared unit frame helper in UnitFrame.lua.
-- Under the frame sits the player's cast bar, below the power bar, replacing Blizzard's own cast bar.

local Cluster = ns.Cluster

local CAST_H, CAST_GAP = 14, 2
Cluster.PLAYER_CAST_H = CAST_H + CAST_GAP -- the room the cast bar takes under the unit frame, for the parts below it

local function BuildCastBar(container, rect)
    local bar = CreateFrame("StatusBar", "GGGUIManagerClusterPlayerCast", container)
    bar:SetPoint("TOPLEFT", container, "TOPLEFT", rect[1], -(rect[2] + Cluster.UNIT_FRAME_HEIGHT + CAST_GAP))
    bar:SetSize(rect[3], CAST_H)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.6)
    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", bar, "LEFT", 4, 0)
    local timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar:Hide()

    local channel, startMS, endMS = false, 0, 0

    local function Stop()
        bar:Hide()
    end

    -- Reads the current cast or channel. The values can be hidden "secret" values, so every read is guarded.
    local function Start()
        local name, _, _, s, e = UnitCastingInfo("player")
        channel = false
        if not name then
            name, _, _, s, e = UnitChannelInfo("player")
            channel = true
        end
        if not name then return Stop() end
        if issecretvalue and (issecretvalue(s) or issecretvalue(e)) then return Stop() end
        startMS, endMS = s, e
        if channel then bar:SetStatusBarColor(0.3, 0.7, 1) else bar:SetStatusBarColor(1, 0.75, 0.2) end
        label:SetText(name)
        bar:SetMinMaxValues(0, math.max(endMS - startMS, 1))
        bar:Show()
    end

    bar:SetScript("OnUpdate", function()
        local now = GetTime() * 1000
        if now >= endMS then return Stop() end
        local done = now - startMS
        local length = endMS - startMS
        bar:SetValue(channel and (length - done) or done)
        timeText:SetFormattedText("%.1f", (endMS - now) / 1000)
    end)

    local function Safe()
        local ok = pcall(Start)
        if not ok then Stop() end
    end

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE" }) do
        pcall(events.RegisterUnitEvent, events, event, "player") -- an event this client lacks is skipped (INV-08)
    end
    pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", function(_, event)
        if event:find("STOP") or event:find("FAILED") or event:find("INTERRUPTED") then
            Stop()
        else
            Safe()
        end
    end)
    Safe()
end

Cluster:AddPart("PlayerFrame", {
    area = "player",
    defaultFrames = { "PlayerFrame", "PlayerCastingBarFrame" },
    Build = function(container, rect)
        Cluster.CreateUnitFrame({
            globalName = "GGGUIManagerClusterPlayer",
            unit = "player",
            container = container,
            rect = rect,
        })
        local ok, err = pcall(BuildCastBar, container, rect)
        if not ok then print(ns.PREFIX .. "player cast bar failed: " .. tostring(err)) end
    end,
})
