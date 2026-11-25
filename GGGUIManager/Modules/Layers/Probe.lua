local addonName, ns = ...

-- Layers: a probe that finds out how WoW Forever's layer refresh warning can be detected. The game shows a notice
-- about five minutes before a forced layer change, but no event, frame or API for it is documented. This module
-- watches while the human plays and writes down what appears around the warning: game events (with their text),
-- chat lines, and Blizzard frames that become visible (with their names and texts). Nothing is ever written to a
-- Blizzard frame, so the probe cannot taint anything (D-029). It only reads.
--
-- /ggg layers probe on    start watching now and at every login. off stops it.
-- /ggg layers note text   put a marker in the log, for example when the warning shows.
-- /ggg layers log [n]     print the last n log lines (default 30). The log is saved with the character.
-- /ggg layers find [word] search the game's global names and C_ APIs for layer related words.

local Layers = {}
ns:RegisterModule("Layers", Layers)

local MAX_LOG = 500
local MAX_KEEP = 300
local LEARN_SECONDS = 20 -- at the start the probe only listens, to learn which events are everyday noise
local LEARN_MIN_COUNT = 4 -- an event seen this often while learning is muted
local WINDOW = 10 -- seconds
local CHATTY = 30 -- an event seen more often than this in one window is muted
local PRINT_PER_SECOND = 6 -- most live lines shown in chat each second (keyword matches always show)
local SCAN_INTERVAL = 1
local WATCH_MAX_LINES = 20 -- text changes logged for one matching frame (the countdown)

local KEYWORDS = { "refresh", "layer", "phas", "shard" }
local NOISE_PREFIXES = { "UNIT_", "COMBAT_LOG", "CURSOR_", "ACTIONBAR_", "NAME_PLATE_", "UPDATE_MOUSEOVER",
    "MODIFIER_STATE", "SPELL_UPDATE", "BAG_UPDATE", "UPDATE_UI_WIDGET", "GLOBAL_MOUSE", "CHAT_MSG_ADDON",
    "SPELL_ACTIVATION", "PLAYER_STARTED", "PLAYER_STOPPED" }

local running, learning = false, false
local session = 0
local scanTicker, eventFrame
local counts, muted, staticNoise = {}, {}, {}
local windowCount, windowStart = {}, 0
local printedThisSecond, printSecond = 0, 0
local wasVisible = setmetatable({}, { __mode = "k" })
local reported = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })

---------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------
local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local function HasKeyword(text)
    text = text:lower():gsub("player", "") -- "player" holds "layer" and would match every PLAYER_ event
    for _, word in ipairs(KEYWORDS) do
        if text:find(word, 1, true) then return true end
    end
    return false
end

local function ShortText(value, limit)
    if IsSecret(value) then return "<secret>" end
    local kind = type(value)
    if kind == "string" then
        value = value:gsub("[\r\n]+", " ")
        if #value > (limit or 80) then value = value:sub(1, limit or 80) .. "..." end
        return value
    elseif kind == "number" or kind == "boolean" then
        return tostring(value)
    elseif kind == "nil" then
        return "nil"
    end
    return "<" .. kind .. ">"
end

local function FormatArgs(...)
    local parts = {}
    for index = 1, math.min(select("#", ...), 5) do
        parts[#parts + 1] = ShortText((select(index, ...)))
    end
    return table.concat(parts, ", ")
end

local function IsStaticNoise(event)
    local cached = staticNoise[event]
    if cached ~= nil then return cached end
    cached = false
    for _, prefix in ipairs(NOISE_PREFIXES) do
        if event:sub(1, #prefix) == prefix then
            cached = true
            break
        end
    end
    staticNoise[event] = cached
    return cached
end

---------------------------------------------------------------------
-- The log
---------------------------------------------------------------------
local function Record(text, important)
    local settings = Layers.settings
    if settings then
        settings.log = settings.log or {}
        local log = settings.log
        local line = date("%H:%M:%S") .. " " .. text
        log[#log + 1] = line
        if #log > MAX_LOG then table.remove(log, 1) end
        -- Important lines (keyword matches, hooks, notes) are also kept in a second, slower list, so chat spam
        -- cannot push them out of the log before the human reads it.
        if important then
            settings.keep = settings.keep or {}
            settings.keep[#settings.keep + 1] = line
            if #settings.keep > MAX_KEEP then table.remove(settings.keep, 1) end
        end
    end
    local second = math.floor(GetTime())
    if second ~= printSecond then
        printSecond, printedThisSecond = second, 0
    end
    if important or printedThisSecond < PRINT_PER_SECOND then
        if not important then printedThisSecond = printedThisSecond + 1 end
        print((important and "|cffffff00probe!|r " or "|cff888888probe|r ") .. text)
    end
end

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
local function OnEvent(_, event, ...)
    if not running then return end
    local now = GetTime()
    if now - windowStart >= WINDOW then
        windowStart = now
        wipe(windowCount)
    end
    windowCount[event] = (windowCount[event] or 0) + 1
    if learning then
        counts[event] = (counts[event] or 0) + 1
        return
    end
    if muted[event] or IsStaticNoise(event) then return end
    if windowCount[event] > CHATTY then
        muted[event] = true
        Record("muted chatty event " .. event, false)
        return
    end
    Record("event " .. event .. " " .. FormatArgs(...), HasKeyword(event))
end

local function RegisterEvents()
    eventFrame = eventFrame or CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", OnEvent)
    local ok = pcall(eventFrame.RegisterAllEvents, eventFrame)
    if ok then return true end
    -- A fallback list for a client that refuses RegisterAllEvents: the events a notice like this would likely use.
    for _, event in ipairs({ "CHAT_MSG_SYSTEM", "CHAT_MSG_SAY", "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE",
        "RAID_BOSS_EMOTE", "RAID_WARNING", "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_ENABLED",
        "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE", "PARTY_INVITE_REQUEST", "PLAYER_LEAVING_WORLD",
        "UPDATE_INSTANCE_INFO", "CHAT_MSG_CHANNEL_NOTICE", "STATIC_POPUP_SHOW" }) do
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    return false
end

---------------------------------------------------------------------
-- Frames that become visible
---------------------------------------------------------------------
-- Up to six texts a frame shows: its own text regions and the text of its direct button children.
local function TextsOf(frame)
    local texts = {}
    local function Add(text)
        if #texts < 6 and type(text) == "string" and not IsSecret(text) and text ~= "" then
            texts[#texts + 1] = ShortText(text, 50)
        end
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("FontString") then Add(region:GetText()) end
    end
    local children = { frame:GetChildren() }
    for index = 1, math.min(#children, 12) do
        local child = children[index]
        if child.IsObjectType and child:IsObjectType("Button") and child.GetText then Add(child:GetText()) end
    end
    return texts
end

local function ParentChain(frame)
    local names = {}
    local parent = frame:GetParent()
    for _ = 1, 3 do
        if not parent then break end
        names[#names + 1] = parent:GetName() or "?"
        parent = parent:GetParent()
    end
    return table.concat(names, " < ")
end

local function CheckFrame(frame)
    if frame:IsForbidden() then return end
    local visible = frame:IsVisible()
    local was = wasVisible[frame]
    wasVisible[frame] = visible or nil

    local watch = watched[frame]
    if watch and visible and watch.lines < WATCH_MAX_LINES then
        local now = table.concat(TextsOf(frame), " | ")
        if now ~= watch.last then
            watch.last = now
            watch.lines = watch.lines + 1
            Record("watched frame " .. (frame:GetName() or "<unnamed>") .. " text now: " .. now, true)
        end
    end

    if not visible or was or learning then return end
    local name = frame:GetName()
    local texts = TextsOf(frame)
    if not name and #texts == 0 then return end -- an unnamed frame with no text says nothing

    local joined = table.concat(texts, " | ")
    local match = HasKeyword((name or "") .. " " .. joined)
    local limit = match and 10 or 3
    reported[frame] = (reported[frame] or 0) + 1
    if reported[frame] > limit then return end
    if match then watched[frame] = watched[frame] or { last = joined, lines = 0 } end

    Record(("frame shown %s [%s], in %s, strata %s%s"):format(name or "<unnamed " .. frame:GetObjectType() .. ">",
        frame:GetObjectType(), ParentChain(frame), frame:GetFrameStrata(),
        joined ~= "" and (", text: " .. joined) or ""), match)
end

local function ScanFrames()
    if not running then return end
    local frame = EnumerateFrames()
    while frame do
        pcall(CheckFrame, frame)
        frame = EnumerateFrames(frame)
    end
end

---------------------------------------------------------------------
-- Hooks on the shard transfer warning
---------------------------------------------------------------------
-- hooksecurefunc and HookScript run after Blizzard's own code and cannot change what it does, so they add no taint.
-- They only write a line to the log. Installed once, and silent while the probe is off.
local hooked = false

local function HookWarning()
    if hooked then return end
    hooked = true
    for _, frameName in ipairs({ "ShardTransferImminentFrame", "ShardTransferImminentMinimizeButton" }) do
        local frame = _G[frameName]
        if type(frame) == "table" then
            if type(frame.Start) == "function" then
                pcall(hooksecurefunc, frame, "Start", function(_, ...)
                    if running then Record(frameName .. ":Start called with " .. FormatArgs(...), true) end
                end)
            end
            for _, script in ipairs({ "OnShow", "OnHide" }) do
                pcall(frame.HookScript, frame, script, function()
                    if running then Record(frameName .. " " .. script, true) end
                end)
            end
        end
    end
end

---------------------------------------------------------------------
-- Start and stop
---------------------------------------------------------------------
local function Stop()
    running = false
    session = session + 1
    if scanTicker then
        scanTicker:Cancel()
        scanTicker = nil
    end
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end
end

local function Start(quiet)
    if running then return end
    running, learning = true, true
    session = session + 1
    local mine = session
    wipe(counts)
    wipe(muted)
    wipe(windowCount)
    windowStart = GetTime()
    local all = RegisterEvents()
    HookWarning()
    scanTicker = C_Timer.NewTicker(SCAN_INTERVAL, ScanFrames)
    if not quiet then
        print(ns.PREFIX .. ("probe on. Listening for %d seconds to learn the everyday events (%s)."):format(
            LEARN_SECONDS, all and "all events" or "a short event list, this client refused all events"))
    end
    C_Timer.After(LEARN_SECONDS, function()
        if not running or session ~= mine then return end
        learning = false
        local mutedCount = 0
        for event, count in pairs(counts) do
            if count >= LEARN_MIN_COUNT then
                muted[event] = true
                mutedCount = mutedCount + 1
            end
        end
        print(ns.PREFIX .. ("probe is watching now. %d everyday events are muted. When the layer warning shows, type /ggg layers note warning is showing"):format(mutedCount))
    end)
end

function Layers:Init(settings)
    self.settings = settings
    settings.log = settings.log or {}
end

function Layers:Enable()
    if self.settings.armed then Start(true) end
end

function Layers:Disable()
    Stop()
end

---------------------------------------------------------------------
-- /ggg layers find
---------------------------------------------------------------------
local function Find(word)
    local top = word and { word } or { "layer", "phasing", "zonerefresh", "phaserefresh" }
    local inside = word and { word } or { "layer", "phase", "refresh", "shard" }
    local hits = {}
    local function Matches(name, words)
        -- "player" holds the word "layer", so it is removed first or nearly every name would match.
        local lower = name:lower():gsub("player", "")
        for _, w in ipairs(words) do
            if lower:find(w, 1, true) then return true end
        end
        return false
    end
    for key, value in pairs(_G) do
        if type(key) == "string" and not key:find("^GGG") and not key:find("^SLASH_") then
            if Matches(key, top) then hits[#hits + 1] = ("%s (%s)"):format(key, type(value)) end
            if type(value) == "table" and (key:find("^C_") or key == "Enum") then
                local ok = pcall(function()
                    for subKey in pairs(value) do
                        if type(subKey) == "string" and Matches(subKey, inside) then
                            hits[#hits + 1] = ("%s.%s"):format(key, subKey)
                        end
                    end
                end)
                if not ok then hits[#hits + 1] = key .. " (could not be read)" end
            end
        end
    end
    table.sort(hits)
    print(ns.PREFIX .. ("find %s: %d names"):format(word or "layer, phase, refresh, shard", #hits))
    for index = 1, math.min(#hits, 60) do print("  " .. hits[index]) end
    if #hits > 60 then print("  ... more, try a narrower word: /ggg layers find <word>") end
end

---------------------------------------------------------------------
-- /ggg layers inspect: reads the shard transfer warning that `find` turned up
---------------------------------------------------------------------
-- Only reads. It never calls C_PlayerInteractionManager.ShardTransferConfirm, which could move the player.
local function SortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)
    return keys
end

local function Inspect()
    print(ns.PREFIX .. "inspect: the shard transfer warning")

    local names = {}
    for key, value in pairs(_G) do
        if type(key) == "string" and type(value) == "string"
            and (key:find("^SHARD_TRANSFER") or key:find("^PARTY_PLAYER_SHARDED") or key == "PARTY_SHARDED_MESSAGE"
                or key == "INVITATION_XSHARD") then
            names[#names + 1] = key
        end
    end
    table.sort(names)
    print("  game text:")
    for _, key in ipairs(names) do print(("    %s = %s"):format(key, ShortText(_G[key], 220))) end

    for _, mixinName in ipairs({ "ShardTransferImminentMixin", "ShardTransferImminentMinimizeMixin" }) do
        local mixin = _G[mixinName]
        if type(mixin) == "table" then
            print(("  %s holds: %s"):format(mixinName, table.concat(SortedKeys(mixin), ", ")))
        else
            print(("  %s: not found"):format(mixinName))
        end
    end

    for _, frameName in ipairs({ "ShardTransferImminentFrame", "ShardTransferImminentMinimizeButton" }) do
        local frame = _G[frameName]
        if type(frame) == "table" and frame.IsShown then
            local scripts = {}
            for _, script in ipairs({ "OnEvent", "OnUpdate", "OnShow", "OnHide", "OnClick" }) do
                if frame.HasScript and frame:HasScript(script) and frame:GetScript(script) then
                    scripts[#scripts + 1] = script
                end
            end
            local point, relative, relPoint, x, y = frame:GetPoint(1)
            print(("  %s: shown %s, visible %s, size %sx%s, parent %s, strata %s, scripts %s"):format(frameName,
                tostring(frame:IsShown()), tostring(frame:IsVisible()), ShortText(frame:GetWidth()),
                ShortText(frame:GetHeight()), frame:GetParent() and (frame:GetParent():GetName() or "?") or "none",
                frame:GetFrameStrata(), #scripts > 0 and table.concat(scripts, ", ") or "none"))
            print(("    anchor %s to %s %s, offset %s, %s"):format(tostring(point),
                relative and (relative.GetName and relative:GetName() or "?") or "none", tostring(relPoint),
                ShortText(x), ShortText(y)))
        else
            print(("  %s: not found"):format(frameName))
        end
    end
    local text = _G.ShardTransferImminentFrameText
    if type(text) == "table" and text.GetText then
        print("  warning text now: " .. ShortText(text:GetText(), 220))
    end

    if type(UnitInPartyShard) == "function" then
        local ok, a, b, c = pcall(UnitInPartyShard, "player")
        print(("  UnitInPartyShard(\"player\") -> %s, %s, %s, %s"):format(tostring(ok), ShortText(a), ShortText(b), ShortText(c)))
    end
    if type(C_PlayerInteractionManager) == "table" then
        print("  C_PlayerInteractionManager holds: " .. table.concat(SortedKeys(C_PlayerInteractionManager), ", "))
    end
end

---------------------------------------------------------------------
-- /ggg layers
---------------------------------------------------------------------
ns:RegisterCommand("layers", function(rest)
    local word, arg = (rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
    word = (word or ""):lower()
    local settings = Layers.settings
    if word == "probe" then
        local state = (arg or ""):lower()
        if state == "on" then
            settings.armed = true
            Start(false)
        elseif state == "off" then
            settings.armed = false
            Stop()
            print(ns.PREFIX .. "probe off.")
        else
            print(ns.PREFIX .. ("probe is %s. /ggg layers probe on | off"):format(running and "on" or "off"))
        end
    elseif word == "note" then
        Record("NOTE " .. (arg ~= "" and arg or "marker"), true)
    elseif word == "log" then
        -- /ggg layers log 80   the last 80 lines. /ggg layers log keep   the important lines kept apart.
        -- /ggg layers log <word>   only the lines that hold the word.
        local log = settings.log or {}
        local count = tonumber(arg) or 30
        if arg:lower() == "keep" then
            log, count = settings.keep or {}, MAX_KEEP
            print(ns.PREFIX .. ("important lines, %d kept"):format(#log))
        elseif not tonumber(arg) and arg ~= "" then
            local matches = {}
            for _, line in ipairs(log) do
                if line:lower():find(arg:lower(), 1, true) then matches[#matches + 1] = line end
            end
            log, count = matches, 60
            print(ns.PREFIX .. ("log lines holding '%s': %d"):format(arg, #matches))
        else
            print(ns.PREFIX .. ("probe log, %d of %d lines"):format(math.min(count, #log), #log))
        end
        for index = math.max(1, #log - count + 1), #log do print("  " .. log[index]) end
    elseif word == "clear" then
        settings.log = {}
        settings.keep = {}
        print(ns.PREFIX .. "probe log cleared.")
    elseif word == "find" then
        Find(arg ~= "" and arg:lower() or nil)
    elseif word == "inspect" then
        local ok, err = pcall(Inspect)
        if not ok then print(ns.PREFIX .. "inspect failed: " .. tostring(err)) end
    else
        print(ns.PREFIX .. ("layer probe is %s, %d log lines saved."):format(running and (learning and "learning" or "on") or "off",
            settings.log and #settings.log or 0))
        print("  /ggg layers probe on | off   watch for the layer refresh warning, also at each login")
        print("  /ggg layers note [text]   mark the log, for example when the warning shows")
        print("  /ggg layers log [n]   print the last n log lines. log keep: the important lines. log <word>: lines with a word")
        print("  /ggg layers clear   empty the log")
        print("  /ggg layers find [word]   search the game's names and C_ APIs for layer words")
        print("  /ggg layers inspect   read the shard transfer warning frame, its text and its functions")
    end
end, "probe on | off, note, log, clear, find (layer refresh warning probe)")
