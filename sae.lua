-- SAO / Project Vector: mob ESP. API: project-vector-lua-api.md.
-- Version: first GitHub publication = 1.0; each update increments the minor
-- digit, with 1.9 -> 2.0. Initial line-ending-only commit is excluded.
local SAE_VERSION = "2.3"
local SAE_TITLE = "Sword Art Eternity v" .. SAE_VERSION
-- Collider.Position is a runtime capability probe: generic BasePart properties
-- are not fully specified in the supplied API. No offsets or fallbacks invented.
local TAB, GROUP = "SAO", "Mob ESP"
menu.AddTab(TAB, "S")
menu.AddGroup(TAB, GROUP)
local function checkbox(id, label, value)
    menu.AddCheckbox(TAB, GROUP, "sao_" .. id, label, value)
end
checkbox("enabled", "Enable mob ESP", true)
menu.AddSliderInt(TAB, GROUP, "sao_range", "Maximum distance", 25, 3000, 500, "%d studs")
menu.AddSliderInt(TAB, GROUP, "sao_limit", "Maximum labels", 1, 150, 50)
menu.AddSliderInt(TAB, GROUP, "sao_font", "Font size", 10, 24, 14)
menu.AddColorpicker(TAB, GROUP, "sao_normal_color", "Normal color", {1, 0.8, 0.3, 1})
menu.AddColorpicker(TAB, GROUP, "sao_corrupted_color", "Corrupted color", {0.8, 0.3, 1, 1})

-- Names from Overhead, Animations and MobSets. Animation variants are grouped
-- with their base mob; an unknown live model is never excluded by this catalog.
local MOB_TYPES = {
    "Boar", "Wolf",
    "KoboldTrooper", "KoboldSentinel", "WindWasp", "IceWasp",
    "Nepenthes", "NepenthesMatriarch", "EvilSnowman", "SnowApe",
    "TaurusSentinel", "AlphaWolf", "WaspQueen",
    "FrostQueen", "FrostTyrant", "SnowApeKing", "EliteTaurusSentinel",
    "Minotaur", "Illfang", "GrimReaper", "SwampMantis", "BogToad", "MireMosquito",
}
local typeIds = {}
menu.AddGroup(TAB, "Mob types")
for _, name in ipairs(MOB_TYPES) do
    local id = "sao_mob_" .. name:lower()
    typeIds[name:lower()] = id
    menu.AddCheckbox(TAB, "Mob types", id, name, true)
end
typeIds.illfangblade = typeIds.illfang
typeIds.minotaurboss = typeIds.minotaur
menu.AddCheckbox(TAB, "Mob types", "sao_mob_other", "Other / unknown mobs", true)

local function mobTypeId(name)
    -- Share the base toggle for every Corrupted<BaseName> variant.
    -- CorruptedMiniboss has no confirmed base species; keep it under Other.
    local base = name:lower():gsub("^corrupted", "")
    return typeIds[base] or "sao_mob_other"
end

local models, lastScan = {}, -math.huge
local function get(id) return menu.Get("sao_" .. id) end
local function finite(n)
    return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function xyz(pos)
    if not pos then return nil end
    local x, y, z = pos.X, pos.Y, pos.Z
    if finite(x) and finite(y) and finite(z) then return x, y, z end
end
-- The dump confirms RemakeNameplate.TextLabel.Text. Text access is a
-- capability probe, not a documented Vector guarantee. Never reuse dump levels.
local function readNameplate(model)
    local ok, text = pcall(function()
        local plate = model:FindFirstChild("RemakeNameplate")
        local label = plate and plate:FindFirstChildWhichIsA("TextLabel")
        return label and label.Text
    end)
    if ok and type(text) == "string" then
        text = text:gsub("<[^>]*>", "")
        local name, level = text:match("^(.-)%s*Lv%.%s*(%d+)")
        if level then
            name = name:gsub("%s+$", "")
            return name ~= "" and name or model.Name, level
        end
    end
    return model.Name, "?"
end
local function scan()
    local nextModels = {}
    local folder = game.Workspace:FindFirstChild("Mobs")
    if not utility.IsValid(folder) then
        models = {}
        return
    end
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") then
            local root = model:FindFirstChild("Collider")
                or model:FindFirstChild("HumanoidRootPart")
                or model:FindFirstChild("Torso")
            local displayName, level = readNameplate(model)
            nextModels[#nextModels + 1] = {
                model = model, root = root, name = model.Name,
                head = model:FindFirstChild("Head"),
                displayName = displayName, level = level,
                typeId = mobTypeId(model.Name),
                corrupted = model.Name:find("Corrupted", 1, true) ~= nil,
            }
        end
    end
    models = nextModels
end

local function project(x, y, z)
    local sx, sy, valid = draw.WorldToScreen(x, y, z)
    if valid and finite(sx) and finite(sy) then return sx, sy end
end
local function frame()
    if not get("enabled") then return end
    local now = utility.GetTime()
    if now - lastScan >= 0.75 then
        lastScan = now
        local ok, err = pcall(scan)
        if not ok then models = {}; error(err) end
    end
    local lp = entity.GetLocalPlayer()
    local ox, oy, oz
    if lp then ox, oy, oz = xyz(lp.Position) end
    if not ox then return end
    local candidates = {}
    for _, entry in ipairs(models) do
        if menu.Get(entry.typeId) then
            local ok, x, y, z = pcall(function()
                if not utility.IsValid(entry.model) or not utility.IsValid(entry.root) then return end
                if not entry.model.Parent then return end
                return xyz(entry.root.Position)
            end)
            if ok and x then
                local distance = math.sqrt((x-ox)^2 + (y-oy)^2 + (z-oz)^2)
                if distance <= get("range") then
                    candidates[#candidates + 1] = {entry = entry, x = x, y = y, z = z, distance = distance}
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.distance < b.distance end)
    local drawn, size = 0, get("font")
    for _, point in ipairs(candidates) do
        if drawn >= get("limit") then break end
        local sx, sy = project(point.x, point.y, point.z)
        if sx then
            local color = menu.GetColor(point.entry.corrupted and "sao_corrupted_color" or "sao_normal_color")
            local topX, topY = project(point.x, point.y + 3, point.z)
            local headOK, hx, hy, hz = pcall(function()
                if utility.IsValid(point.entry.head) then return xyz(point.entry.head.Position) end
            end)
            if headOK and hx then topX, topY = project(hx, hy + 1.5, hz) end
            local bottomX, bottomY = project(point.x, point.y - 2, point.z)
            -- Keep labels separated even when the projected anchors overlap.
            topX, topY = topX or sx, math.min(topY or sy, sy) - size - 5
            bottomX, bottomY = bottomX or sx, math.max(bottomY or sy, sy) + 5
            local label = string.format("%s [Lv.%s]", point.entry.displayName, point.entry.level)
            local width = draw.GetTextSize(label, size)
            draw.Text(topX - width / 2, topY, label, color, size)
            local distanceLabel = string.format("%.0f studs", point.distance)
            local distanceWidth = draw.GetTextSize(distanceLabel, size)
            draw.Text(bottomX - distanceWidth / 2, bottomY, distanceLabel, color, size)
            drawn = drawn + 1
        end
    end
end

-- Mining nodes are identified by their live hierarchy, not snapshot coordinates.
-- A Crater distinguishes a mineable node from loose ore templates in OreNodes.
local ORES = {
    {"IronOre", "Iron Ore", {0.72, 0.75, 0.8, 1}},
    {"SteelOre", "Steel Ore", {0.88, 0.92, 1, 1}},
    {"KoboldOre", "Kobold Ore", {0.75, 0.5, 0.25, 1}},
    {"CrystalliteOre", "Crystallite Ore", {0.3, 0.75, 1, 1}},
    {"ObsidianOre", "Obsidian Ore", {0.7, 0.45, 0.9, 1}},
    {"VerditeOre", "Verdite Ore", {0.25, 1, 0.55, 1}},
}
menu.AddGroup(TAB, "Ore ESP")
menu.AddCheckbox(TAB, "Ore ESP", "sao_ore_enabled", "Enable ore ESP", true)
menu.AddCheckbox(TAB, "Ore ESP", "sao_ore_depleted", "Show depleted nodes", false)
menu.AddSliderInt(TAB, "Ore ESP", "sao_ore_range", "Maximum distance", 25, 5000, 1000, "%d studs")
menu.AddSliderInt(TAB, "Ore ESP", "sao_ore_limit", "Maximum labels", 1, 150, 50)
menu.AddSliderInt(TAB, "Ore ESP", "sao_ore_font", "Font size", 10, 24, 14)
for _, ore in ipairs(ORES) do
    menu.AddCheckbox(TAB, "Ore ESP", "sao_ore_" .. ore[1], ore[2], true)
end
local oreNodes, oreScanAt = {}, -math.huge
local function scanOres()
    local found = {}
    local folder = game.Workspace:FindFirstChild("OreNodes")
    if not utility.IsValid(folder) then oreNodes = {}; return end
    for _, node in ipairs(folder:GetDescendants()) do
        if node:IsA("Model") and node:FindFirstChild("Crater") then
            for _, ore in ipairs(ORES) do
                if node.Name == ore[1] or node.Name:match("^" .. ore[1] .. "Spot%d+$") then
                    found[#found + 1] = { model = node, definition = ore }
                    break
                end
            end
        end
    end
    oreNodes = found
end
local function oreFrame()
    if not get("ore_enabled") then return end
    local now = utility.GetTime()
    if now - oreScanAt >= 1 then
        oreScanAt = now
        local ok, err = pcall(scanOres)
        if not ok then oreNodes = {}; error(err) end
    end
    local lp = entity.GetLocalPlayer()
    local ox, oy, oz = xyz(lp and lp.Position)
    if not ox then return end
    local candidates = {}
    for _, entry in ipairs(oreNodes) do
        if get("ore_" .. entry.definition[1]) then
            local ok, x, y, z, depleted = pcall(function()
                local node = entry.model
                if not utility.IsValid(node) or not node.Parent then return end
                local ore = node:FindFirstChild("Ore")
                local empty = not utility.IsValid(ore)
                if empty and not get("ore_depleted") then return end
                local geometry = empty and node:FindFirstChild("Crater") or ore
                if not utility.IsValid(geometry) then return end
                local part = geometry:IsA("BasePart") and geometry or nil
                if not part then
                    for _, child in ipairs(geometry:GetDescendants()) do
                        if child:IsA("BasePart") then part = child; break end
                    end
                end
                if not utility.IsValid(part) then return end
                local px, py, pz = xyz(part.Position)
                return px, py, pz, empty
            end)
            if ok and x then
                local distance = math.sqrt((x-ox)^2 + (y-oy)^2 + (z-oz)^2)
                if distance <= get("ore_range") then
                    candidates[#candidates + 1] = {x=x, y=y, z=z, distance=distance,
                        definition=entry.definition, depleted=depleted}
                end
            end
        end
    end
    table.sort(candidates, function(a,b) return a.distance < b.distance end)
    local drawn, size = 0, get("ore_font")
    for _, point in ipairs(candidates) do
        if drawn >= get("ore_limit") then break end
        local sx, sy = project(point.x, point.y, point.z)
        if sx then
            local color = point.depleted and {0.5, 0.5, 0.5, 1} or point.definition[3]
            local label = point.definition[2] .. (point.depleted and " (depleted)" or "")
            local width = draw.GetTextSize(label, size)
            draw.Text(sx - width/2, sy-size-5, label, color, size)
            local distance = string.format("%.0f studs", point.distance)
            local dw = draw.GetTextSize(distance, size)
            draw.Text(sx-dw/2, sy+5, distance, color, size)
            drawn = drawn + 1
        end
    end
end

local lastError, lastOreError = -math.huge, -math.huge
OnFrame = function()
    local ok, err = pcall(frame)
    if not ok and utility.GetTime() - lastError >= 5 then
        lastError = utility.GetTime()
        print("[SAO ESP] " .. tostring(err))
    end
    local oreOK, oreError = pcall(oreFrame)
    if not oreOK and utility.GetTime() - lastOreError >= 5 then
        lastOreError = utility.GetTime()
        print("[SAO Ore ESP] " .. tostring(oreError))
    end
end
print("[SAO] " .. SAE_TITLE .. " loaded. Open SAO for settings.")

local function makeSAETracker()
-- AnimationTracker for Project Vector
-- Ported from executor-based AnimationTracker v1.1
--
-- API changes from original:
--   memory_read("uintptr_t", addr)  → memory.Read(addr, "ptr")
--   memory_read("float", addr)      → memory.Read(addr, "float")
--   memory_read("string", addr)     → memory.ReadString(addr)
--   memory_read("byte", addr)       → memory.Read(addr, "u8")
--   game:HttpGet(url)               → utility.HttpGet(url)
--   HttpService:JSONDecode(str)     → parseJSON(str)  (built-in)
--   table.find (Luau)               → table_find helper
--   continue  (Luau)                → if/end guard

---------------------------------------------------------------------------
-- Minimal JSON parser (Vector environment has no JSONDecode)
---------------------------------------------------------------------------
local function parseJSON(str)
    local pos = 1

    local function skip_ws()
        local p = str:find("[^ \t\r\n]", pos)
        pos = p or (#str + 1)
    end

    local function parse_string()
        pos = pos + 1 -- skip opening "
        local chunks = {}
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == '"' then
                pos = pos + 1
                return table.concat(chunks)
            elseif c == '\\' then
                pos = pos + 1
                local esc = str:sub(pos, pos)
                if     esc == '"'  then chunks[#chunks + 1] = '"'
                elseif esc == '\\' then chunks[#chunks + 1] = '\\'
                elseif esc == 'n'  then chunks[#chunks + 1] = '\n'
                elseif esc == 'r'  then chunks[#chunks + 1] = '\r'
                elseif esc == 't'  then chunks[#chunks + 1] = '\t'
                elseif esc == '/'  then chunks[#chunks + 1] = '/'
                else                    chunks[#chunks + 1] = esc
                end
            else
                chunks[#chunks + 1] = c
            end
            pos = pos + 1
        end
        return table.concat(chunks)
    end

    local function parse_number()
        local start = pos
        if str:sub(pos, pos) == '-' then pos = pos + 1 end
        while pos <= #str and str:sub(pos, pos):match("[%d%.eE%+%-]") do
            pos = pos + 1
        end
        return tonumber(str:sub(start, pos - 1))
    end

    local parse_value -- forward declaration

    local function parse_object()
        pos = pos + 1 -- skip {
        local obj = {}
        skip_ws()
        if str:sub(pos, pos) == '}' then pos = pos + 1; return obj end
        while true do
            skip_ws()
            local key = parse_string()
            skip_ws()
            pos = pos + 1 -- skip :
            skip_ws()
            obj[key] = parse_value()
            skip_ws()
            if str:sub(pos, pos) == ',' then
                pos = pos + 1
            else
                break
            end
        end
        skip_ws()
        if str:sub(pos, pos) == '}' then pos = pos + 1 end
        return obj
    end

    local function parse_array()
        pos = pos + 1 -- skip [
        local arr = {}
        skip_ws()
        if str:sub(pos, pos) == ']' then pos = pos + 1; return arr end
        while true do
            skip_ws()
            arr[#arr + 1] = parse_value()
            skip_ws()
            if str:sub(pos, pos) == ',' then
                pos = pos + 1
            else
                break
            end
        end
        skip_ws()
        if str:sub(pos, pos) == ']' then pos = pos + 1 end
        return arr
    end

    parse_value = function()
        skip_ws()
        local c = str:sub(pos, pos)
        if     c == '"' then return parse_string()
        elseif c == '{' then return parse_object()
        elseif c == '[' then return parse_array()
        elseif c == 't' then pos = pos + 4; return true
        elseif c == 'f' then pos = pos + 5; return false
        elseif c == 'n' then pos = pos + 4; return nil
        else                  return parse_number()
        end
    end

    skip_ws()
    return parse_value()
end

---------------------------------------------------------------------------
-- Luau compatibility (Vector uses standard Lua, not Luau)
---------------------------------------------------------------------------
local function table_find(t, value)
    for i = 1, #t do
        if t[i] == value then return i end
    end
    return nil
end

---------------------------------------------------------------------------
-- Fetch offsets via HTTP
---------------------------------------------------------------------------
local offsets

for _, url in ipairs({
    "https://offsets.imtheo.lol/Offsets.json",
    "https://artxficial.dev/misc/theo",
}) do
    local body, status = utility.HttpGet(url)
    if body and status == 200 then
        local ok, result = pcall(function()
            local data = parseJSON(body)
            return data.Offsets or data
        end)
        if ok and type(result) == "table" and next(result) then
            print("[DEBUG] Successfully using offsets from: " .. url)
            offsets = result
            break
        end
    end
end

if not offsets then
    error("Offsets unavailable")
end

---------------------------------------------------------------------------
-- Offset table (nil-safe access)
---------------------------------------------------------------------------
local KnownOffsets = {
    ["AnimationId"]                = offsets.Misc and offsets.Misc.AnimationId or 0,
    ["TimePosition"]               = offsets.AnimationTrack and offsets.AnimationTrack.TimePosition or 0,
    ["ActiveAnimations"]           = offsets.Animator and offsets.Animator.ActiveAnimations or 0,    -- const
    ["Animation"]                  = offsets.AnimationTrack and offsets.AnimationTrack.Animation or 0,
    ["Speed"]                      = offsets.AnimationTrack and offsets.AnimationTrack.Speed or 0,
    ["IsPlaying"]                  = offsets.AnimationTrack and offsets.AnimationTrack.IsPlaying or 0,
    -- Node Structure
    ["NodeNext"] = 0x10,
}

---------------------------------------------------------------------------
-- Core memory-reading functions
---------------------------------------------------------------------------
for _, key in ipairs({"AnimationId", "TimePosition", "ActiveAnimations", "Animation", "Speed", "IsPlaying"}) do
    assert(type(KnownOffsets[key]) == "number" and KnownOffsets[key] > 0, "Missing offset: " .. key)
end
local function GetAnimatorAddress(Character)
    if not Character or Character.Address == 0 then return nil end

    local Humanoid = Character:FindFirstChildWhichIsA("Humanoid") or Character:FindFirstChildWhichIsA("AnimationController")
    if not Humanoid then return nil end

    local Animator = Humanoid:FindFirstChildWhichIsA("Animator")
    return Animator and Animator.Address or nil
end

local function GetPlayingAnimationTracks(Character)
    local AnimatorAddress = GetAnimatorAddress(Character)
    if not AnimatorAddress then
        return nil, "Animator not found"
    end

    -- Head of the linked list of active animations
    local ListHead_Ptr = memory.Read(AnimatorAddress + KnownOffsets.ActiveAnimations, "ptr")
    if not ListHead_Ptr or ListHead_Ptr == 0 then
        return nil, "ActiveAnimations pointer unavailable"
    end

    -- First node (or head itself if empty)
    local firstNode = memory.Read(ListHead_Ptr, "ptr")
    if not firstNode or firstNode == 0 or firstNode == ListHead_Ptr then
        return {}
    end

    local AnimationTracks = {}
    local currentNode = firstNode
    local foundCount = 0
    local visited, steps = {}, 0

    while currentNode and currentNode ~= 0 and currentNode ~= ListHead_Ptr do
        if visited[currentNode] or steps >= 128 then break end
        visited[currentNode] = true
        steps = steps + 1
        -- Read the track pointer from the current node
        local track = memory.Read(currentNode + KnownOffsets.NodeNext, "ptr")

        if track and track > 0 then
            foundCount = foundCount + 1
            AnimationTracks[foundCount] = track
        end

        if foundCount >= 50 then
            break
        end

        -- Advance to the next node
        local nextNode = memory.Read(currentNode, "ptr")

        if nextNode == ListHead_Ptr then
            break -- looped back to head
        elseif nextNode == 0 or not nextNode then
            break -- end of list
        end

        currentNode = nextNode
    end

    return AnimationTracks
end

local function GetTimePosition(AnimationTrackAddress)
    if not AnimationTrackAddress or AnimationTrackAddress == 0 then return nil end
    return memory.Read(AnimationTrackAddress + KnownOffsets.TimePosition, "float")
end

local function ExtractAnimationTrackInfo(AnimationTrackAddress)
    if not AnimationTrackAddress or AnimationTrackAddress == 0 then return nil end

    local Animation      = memory.Read(AnimationTrackAddress + KnownOffsets.Animation, "ptr")
    if not Animation or Animation == 0 then return nil end
    local AnimIdPointer = memory.Read(Animation + KnownOffsets.AnimationId, "ptr")
    if not AnimIdPointer or AnimIdPointer == 0 then return nil end
    local AnimationId    = memory.ReadString(AnimIdPointer, 256)

    local TimePosition   = memory.Read(AnimationTrackAddress + KnownOffsets.TimePosition, "float")
    local Speed          = memory.Read(AnimationTrackAddress + KnownOffsets.Speed, "float")
    local IsPlaying      = memory.Read(AnimationTrackAddress + KnownOffsets.IsPlaying, "u8")

    return {
        Address      = AnimationTrackAddress,
        Name         = "", -- Parry identifies attacks by AnimationId, not track name.
        AnimationId  = AnimationId,
        TimePosition = TimePosition,
        Speed        = Speed,
        IsPlaying    = IsPlaying,
    }
end

---------------------------------------------------------------------------
-- Signal (lightweight event emitter)
---------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({ _listeners = {} }, Signal)
end

function Signal:Connect(callback)
    table.insert(self._listeners, callback)
    return {
        Disconnect = function()
            for i = 1, #self._listeners do
                if self._listeners[i] == callback then
                    table.remove(self._listeners, i)
                    break
                end
            end
        end,
    }
end

function Signal:Fire(...)
    for i = 1, #self._listeners do
        self._listeners[i](...)
    end
end

---------------------------------------------------------------------------
-- AnimationTracker class
---------------------------------------------------------------------------
local AnimationTracker = {}
AnimationTracker.__index = AnimationTracker

function AnimationTracker.new(IgnoreIds)
    local self = setmetatable({}, AnimationTracker)

    self.AnimationAdded   = Signal.new()
    self.AnimationUpdated = Signal.new()
    self.AnimationRemoved = Signal.new()
    self.IgnoreIds        = IgnoreIds or {}
    self._cachedTracks    = {}

    return self
end

-- Batch update: reads, caches, fires signals, cleans up stopped tracks
function AnimationTracker:Update(character)
    local tracksPlaying, reason = GetPlayingAnimationTracks(character)
    self.Status = reason or "OK"
    if not tracksPlaying then self._cachedTracks = {}; return {} end

    local currentAddresses = {}
    local activeSnapshot   = {}

    -- Process all currently playing tracks
    for i = 1, #tracksPlaying do
        local address = tracksPlaying[i]
        currentAddresses[address] = true

        local wasKnown = self._cachedTracks[address] ~= nil
        local info = ExtractAnimationTrackInfo(address)
        if info then self._cachedTracks[address] = info end
        local newlyExtracted = false

        -- Extract and cache if not seen before
        if not wasKnown then
            info = info or ExtractAnimationTrackInfo(address)
            if info then
                self._cachedTracks[address] = info
                newlyExtracted = true
            end
        end

        if info then
            -- Check ignore list  (replaces Luau `continue`)
            local assetId   = info.AnimationId
            local numericId = assetId and tonumber(string.match(tostring(assetId), "%d+"))
            local ignored   = numericId and table_find(self.IgnoreIds, numericId)

            if not ignored then
                if newlyExtracted then
                    self.AnimationAdded:Fire(info)
                end

                local liveTime = GetTimePosition(address) or info.TimePosition
                info.TimePosition = liveTime

                self.AnimationUpdated:Fire(info, liveTime)
                table.insert(activeSnapshot, info)
            end
        end
    end

    -- Purge tracks that are no longer playing
    for address, cachedInfo in pairs(self._cachedTracks) do
        if not currentAddresses[address] then
            self.AnimationRemoved:Fire(cachedInfo)
            self._cachedTracks[address] = nil
        end
    end

    return activeSnapshot
end

print("[AnimationTracker] Vector port loaded, use Tracker:Update() in a loop v1.1")

-- Tracker is private to SAE.
return AnimationTracker

end
-- Experimental basic-mob parry. Hold activation key only while in Roblox.
local function setupParry(makeTracker)
    local tab, group = "SAO", "Auto parry (experimental)"
    menu.AddGroup(tab, group)
    menu.AddCheckbox(tab, group, "sae_ap_enabled", "Enable auto parry", false)
    menu.AddHotkey(tab, group, "sae_ap_hold", "Activation key", 0x56)
    menu.AddCombo(tab, group, "sae_ap_mode", "Activation mode", {"Hold", "Toggle", "Always"}, 0)
    menu.AddCheckbox(tab, group, "sae_ap_manual_lmb", "Also activate while holding LMB", true)
    menu.AddHotkey(tab, group, "sae_ap_key", "Block / parry key", 0x46)
    menu.AddSliderFloat(tab, group, "sae_ap_range", "Maximum distance", 2, 20, 10, "%.1f")
    menu.AddSliderInt(tab, group, "sae_ap_delay", "Animation delay (ms)", 0, 500, 0)
    menu.AddCheckbox(tab, group, "sae_ap_log", "Log detected attacks", false)
    menu.AddCheckbox(tab, group, "sae_ap_status", "Show parry diagnostics", true)
    menu.AddHotkey(tab, group, "sae_ap_test", "Test parry (while active)", 0x77)
    menu.AddLabel(tab, group, "Activation mode applies to parry and auto attacks. LMB option also activates parry.")
    local fight = "Auto combat"
    menu.AddGroup(tab, fight)
    menu.AddCheckbox(tab, fight, "sae_fight_enabled", "Auto attack while active", false)
    menu.AddCheckbox(tab, fight, "sae_fight_lmb", "Use LMB attacks", true)
    menu.AddSliderFloat(tab, fight, "sae_fight_range", "Attack distance", 2, 12, 7, "%.1f")
    menu.AddSliderInt(tab, fight, "sae_fight_interval", "LMB interval (ms)", 150, 1500, 400)
    menu.AddSliderInt(tab, fight, "sae_fight_pause", "Pause after parry (ms)", 400, 2000, 700)
    for slot = 1, 4 do
        menu.AddCheckbox(tab, fight, "sae_fight_skill" .. slot, "Use skill " .. slot, false)
        menu.AddHotkey(tab, fight, "sae_fight_bind" .. slot, "Skill " .. slot .. " key", 0x30 + slot)
    end
    menu.AddSliderFloat(tab, fight, "sae_fight_skill_interval", "Retry same skill after (s)", 2, 60, 10, "%.1f")
    menu.AddSliderInt(tab, fight, "sae_fight_skill_pause", "Pause attacks after skill (ms)", 300, 4000, 1200)
    menu.AddLabel(tab, fight, "Face your target. Skills may prevent parry during their animation.")
    local attacks = {
        boar = {[13774059143]=true, [76704099847113]=true}, wolf = {[13803750988]=true},
        koboldtrooper = {[13803854864]=true}, koboldsentinel = {[13803854864]=true},
        nepenthes = {[116371641636454]=true}, windwasp = {[94230248318965]=true},
    }
    local state, Tracker, failed = {}, nil, false
    local lastPress = -math.huge
    local lastClick, attackAfter, lastSkill = -math.huge, 0, {}
    local combatLogAt, clickCount = -math.huge, 0
    local status, testWasDown = "Enable parry, then hold V", false
    local nearestInfo = ""
    local toggleActive, bindWasDown, previousMode, previousBind = false, false, nil, nil
    menu.AddButton(tab, group, "sae_ap_retry", "Retry tracker initialization", function()
        failed, Tracker, state = false, nil, {}
        status = "Tracker reset; enable parry and hold activation"
    end)
    return function()
        if menu.Get("sae_ap_status") then
            draw.Text(20, 110, "SAE parry: " .. status, {1, 0.85, 0.3, 1}, 14)
            if nearestInfo ~= "" then draw.Text(20, 128, nearestInfo, {1, 1, 1, 1}, 14) end
        end
        if not menu.Get("sae_ap_enabled") then
            toggleActive, bindWasDown = false, false
            status = "Disabled"; state = {}; testWasDown = false; return
        end
        local mode, bind = menu.Get("sae_ap_mode"), menu.GetKey("sae_ap_hold")
        local bindDown = bind > 0 and input.IsKeyDown(bind)
        if mode ~= previousMode or bind ~= previousBind then
            toggleActive = false
            -- Changing mode/bind while holding a key is not a Toggle press.
            bindWasDown = bindDown
            previousMode, previousBind = mode, bind
        end
        if mode == 1 and bindDown and not bindWasDown then toggleActive = not toggleActive end
        bindWasDown = bindDown
        local holdActive = mode == 2 or (mode == 1 and toggleActive) or (mode == 0 and bindDown)
        local manualAttack = menu.Get("sae_ap_manual_lmb") and input.IsKeyDown(0x01)
        if not holdActive and not manualAttack then
            status = mode == 1 and "Toggle OFF" or "Waiting for activation key"; testWasDown = false
            state = {}; return
        end
        local testDown = holdActive and input.IsKeyDown(menu.GetKey("sae_ap_test"))
        if testDown and not testWasDown then
            local key = menu.GetKey("sae_ap_key")
            if key > 0 and not input.IsKeyDown(key) then
                utility.KeyPress(key, 50); lastPress = utility.GetTime()
                attackAfter = lastPress + menu.Get("sae_fight_pause") / 1000
                print("[SAE parry] Test key sent: " .. key)
            end
        end
        testWasDown = testDown
        if failed then return end
        if not Tracker then
            local ok, result = pcall(makeTracker)
            if not ok then
                failed = true; menu.Set("sae_ap_enabled", false)
                status = "Tracker initialization failed (see console)"
                print("[SAE parry] Tracker unavailable: " .. tostring(result)); return
            end
            Tracker = result
        end
        local now = utility.GetTime()
        local lp = entity.GetLocalPlayer()
        if not lp or not lp.IsAlive or not lp.Position then status = "Local player unavailable/dead"; state = {}; return end
        local origin = lp.Position
        local folder = game.Workspace:FindFirstChild("Mobs")
        if not utility.IsValid(folder) then status = "Workspace.Mobs missing"; state = {}; return end
        local present, ready = {}, {}
        local nearby, trackCount, matched, nearest = 0, 0, 0, math.huge
        local threatening = 0
        local attackDistance = math.huge
        local look = camera.GetLookVector()
        nearestInfo = ""
        for _, mob in ipairs(folder:GetChildren()) do
            local baseName = mob.Name:lower():gsub("[%s_%-]", ""):gsub("^corrupted", "")
            local allowed = attacks[baseName]
            if allowed and mob:IsA("Model") then
                local ok, err = pcall(function()
                    local root = mob:FindFirstChild("Collider") or mob:FindFirstChild("HumanoidRootPart")
                    if not utility.IsValid(root) or not root.Position then return end
                    local p = root.Position
                    local distance = math.sqrt((p.X-origin.X)^2+(p.Y-origin.Y)^2+(p.Z-origin.Z)^2)
                    if distance > menu.Get("sae_ap_range") then return end
                    nearby = nearby + 1
                    local key = mob.Address
                    present[key] = true
                    local s = state[key] or {tracker=Tracker.new(), tracks={}}
                    state[key] = s
                    local active = {}
                    local tracks = s.tracker:Update(mob)
                    trackCount = trackCount + #tracks
                    if distance < nearest then
                        nearest = distance
                        local info = tracks[1]
                        nearestInfo = mob.Name .. " | " .. string.format("%.1f studs", distance)
                            .. " | " .. tostring(s.tracker.Status)
                            .. (info and (" | ID=" .. tostring(info.AnimationId) .. " t=" .. tostring(info.TimePosition)) or " | no tracks")
                    end
                    for _, info in ipairs(tracks) do
                        local id = tonumber(tostring(info.AnimationId):match("%d+"))
                        local t = info.TimePosition
                        -- Use the active-list membership and bounded clip time;
                        -- do not gate input on the unverified IsPlaying byte offset.
                        if allowed[id] and type(t)=="number" and t==t and t>=0 then
                            matched = matched + 1
                            local k = tostring(info.Address) .. ":" .. tostring(id)
                            active[k] = true
                            local old = s.tracks[k]
                            if not old or t < old.time-0.05 then
                                old = {used=false, time=t, movedAt=now}; s.tracks[k] = old
                                if menu.Get("sae_ap_log") then print("[SAE parry] " .. mob.Name .. " animation=" .. id .. " time=" .. t) end
                            end
                            if t > old.time + 0.001 then old.movedAt = now end
                            old.time = t
                            old.lastSeen = now
                            -- Clip time is used directly, so changed animation speed is reflected.
                            local target = menu.Get("sae_ap_delay")/1000
                            local moving = now - (old.movedAt or now) <= 0.15
                            if moving and t <= target+0.9 then threatening = threatening + 1 end
                            if moving and not old.used and t >= target and t <= target+0.6 then
                                ready[#ready+1] = {state=old, distance=distance}
                            end
                        end
                    end
                    -- A single missing sample must not re-arm the same animation.
                    for k, record in pairs(s.tracks) do
                        if not active[k] and now-(record.lastSeen or now)>0.15 then s.tracks[k]=nil end
                    end
                    if distance <= menu.Get("sae_fight_range") and distance > 0.01 and look then
                        local dot = ((p.X-origin.X)*look.X+(p.Y-origin.Y)*look.Y+(p.Z-origin.Z)*look.Z)/distance
                        if dot >= 0.5 and s.tracker.Status == "OK" then
                            attackDistance = math.min(attackDistance, distance)
                        end
                    end
                end)
                if not ok then
                    failed = true; menu.Set("sae_ap_enabled", false)
                    print("[SAE parry] Disabled after tracker error: " .. tostring(err)); return
                end
            end
        end
        for key in pairs(state) do if not present[key] then state[key]=nil end end
        table.sort(ready,function(a,b) return a.distance<b.distance end)
        local key = menu.GetKey("sae_ap_key")
        status = string.format("mobs=%d tracks=%d attacks=%d ready=%d", nearby, trackCount, matched, #ready)
        if ready[1] and now-lastPress < 0.95 then
            status = status .. string.format(" | cooldown %.2fs", 0.95-(now-lastPress))
        end
        if ready[1] and now-lastPress >= 0.95 and key>0 and not input.IsKeyDown(key) then
            lastPress = now
            attackAfter = now + menu.Get("sae_fight_pause") / 1000
            for _, attack in ipairs(ready) do attack.state.used = true end
            utility.KeyPress(key, 50)
            status = status .. " | F sent"
            return
        end
        -- Never start an automated attack while a known enemy attack is active,
        -- during manual block, or in the recovery period after our last input.
        if menu.Get("sae_fight_enabled") then
            if threatening > 0 then status = status .. " | waiting: enemy attack"
            elseif now < attackAfter then status = status .. " | waiting: recovery"
            elseif attackDistance == math.huge then status = status .. " | waiting: target within attack range / facing" end
        end
        if menu.Get("sae_ap_log") and now-combatLogAt >= 2 then
            combatLogAt = now
            local reason
            if not menu.Get("sae_fight_enabled") then reason = "auto combat OFF"
            elseif not holdActive then reason = "combat activation OFF (LMB activates parry only)"
            elseif threatening > 0 then reason = "enemy attack active"
            elseif now < attackAfter then reason = string.format("recovery %.2fs", attackAfter-now)
            elseif attackDistance == math.huge then reason = "no target in attack range and facing"
            elseif input.IsKeyDown(key) then reason = "parry key held"
            elseif not menu.Get("sae_fight_lmb") then reason = "auto LMB OFF"
            elseif input.IsKeyDown(0x01) then reason = "manual LMB held"
            else reason = "auto LMB ready" end
            print(string.format("[SAE combat] %s | range=%.1f | LMB sent=%d | %s",
                reason, menu.Get("sae_fight_range"), clickCount, nearestInfo))
        end
        if not holdActive or not menu.Get("sae_fight_enabled") or threatening > 0
            or now < attackAfter or attackDistance == math.huge
            or input.IsKeyDown(key) then return end
        for slot = 1, 4 do
            if menu.Get("sae_fight_skill" .. slot)
                and now - (lastSkill[slot] or -math.huge) >= menu.Get("sae_fight_skill_interval") then
                local skillKey = menu.GetKey("sae_fight_bind" .. slot)
                if skillKey > 0 and skillKey ~= key and skillKey ~= menu.GetKey("sae_ap_hold")
                    and not input.IsKeyDown(skillKey) then
                    lastSkill[slot] = now
                    attackAfter = now + menu.Get("sae_fight_skill_pause") / 1000
                    utility.KeyPress(skillKey, 30)
                    return
                end
            end
        end
        if menu.Get("sae_fight_lmb") and not input.IsKeyDown(0x01)
            and now-lastClick >= menu.Get("sae_fight_interval")/1000 then
            lastClick = now
            utility.MouseClick("left")
            clickCount = clickCount + 1
        end
    end
end

local function setupLootESP()
    local group="Loot ESP"
    menu.AddGroup(TAB,group)
    menu.AddCheckbox(TAB,group,"sae_loot_enabled","Enable chest / pickup ESP",true)
    local categories={Chest={"Treasure chests",{1,0.8,0.2,1}},
        Storage={"Inn storage",{0.6,0.7,1,1}},Pickup={"Story pickups",{0.4,1,0.65,1}}}
    for _,kind in ipairs({"Chest","Storage","Pickup"})do
        menu.AddCheckbox(TAB,group,"sae_loot_"..kind,categories[kind][1],true)
        menu.AddColorpicker(TAB,group,"sae_loot_color_"..kind,categories[kind][1].." color",categories[kind][2])
    end
    menu.AddCheckbox(TAB,group,"sae_loot_hide_inactive","Hide disabled / collected",true)
    menu.AddSliderInt(TAB,group,"sae_loot_range","Maximum distance",50,10000,2500,"%d studs")
    menu.AddSliderInt(TAB,group,"sae_loot_limit","Maximum labels",1,100,40)
    menu.AddSliderInt(TAB,group,"sae_loot_font","Font size",10,24,14)
    local candidates,stack,pending,seen={},nil,{},{}
    local scanAt=-math.huge
    local function beginScan()
        stack,pending,seen={},{},{}
        for _,child in ipairs(game.Workspace:GetChildren())do
            if child.Name=="Dungeon" or child.Name=="StoryLocal" or child.Name=="InnChest" then
                stack[#stack+1]=child
            else
                local room=child:FindFirstChild("InnRoom")
                if utility.IsValid(room)then stack[#stack+1]=room end
            end
        end
    end
    local function inspect(obj)
        local kind,part,prompt,label
        if obj:IsA("Model") and (obj.Name=="Chest" or obj.Name=="InnChest")then
            local main=obj:FindFirstChild("Main")
            if utility.IsValid(main) and main:IsA("BasePart")then
                prompt=main:FindFirstDescendantOfClass("ProximityPrompt")
                if utility.IsValid(prompt) and (obj.Name=="InnChest" or obj:FindFirstChild("Lid"))then
                    kind=obj.Name=="InnChest" and "Storage" or "Chest"
                    part,label=main,kind=="Storage" and "Inn storage" or "Treasure chest"
                end
            end
        elseif obj.Name=="StoryPickup" and obj:IsA("BasePart")then
            prompt=obj:FindFirstChildOfClass("ProximityPrompt")
            if utility.IsValid(prompt)then kind,part,label="Pickup",obj,"Story pickup" end
        end
        if kind then
            local key=tostring(part.Address)
            if not seen[key]then
                seen[key]=true
                pending[#pending+1]={part=part,prompt=prompt,kind=kind,label=label}
            end
        end
    end
    return function()
        if not menu.Get("sae_loot_enabled")then stack=nil;return end
        local now=utility.GetTime()
        if not stack and now-scanAt>=5 then scanAt=now;beginScan()end
        -- Incremental traversal of confirmed loot containers only.
        if stack then
            local began=utility.GetTime()
            for _=1,150 do
                if #stack==0 then candidates=pending;stack=nil;break end
                local obj=table.remove(stack)
                if utility.IsValid(obj)then
                    local ok=pcall(function()
                        inspect(obj)
                        for _,child in ipairs(obj:GetChildren())do stack[#stack+1]=child end
                    end)
                    -- A streamed-out object is retried on the next scan.
                end
                if utility.GetTime()-began>=0.002 then break end
            end
        end
        local lp=entity.GetLocalPlayer()
        local ox,oy,oz=xyz(lp and lp.Position)
        if not ox then return end
        local points={}
        for _,entry in ipairs(candidates)do
            if menu.Get("sae_loot_"..entry.kind)then
                local ok,x,y,z,label=pcall(function()
                    if not utility.IsValid(entry.part) or not entry.part.Parent
                        or not utility.IsValid(entry.prompt) or not entry.prompt.Parent then return end
                    if menu.Get("sae_loot_hide_inactive")then
                        -- These properties are capability probes like NPC Text.
                        -- If unsupported, retain the object instead of assuming empty.
                        local readable,enabled=pcall(function()return entry.prompt.Enabled end)
                        if readable and enabled==false then return end
                        if entry.kind=="Pickup" then
                            local valid,transparency=pcall(function()return entry.part.Transparency end)
                            if valid and transparency==1 then return end
                        end
                    end
                    local label=entry.label
                    if entry.kind=="Pickup"then
                        local readable,text=pcall(function()return entry.prompt.ObjectText end)
                        if readable and type(text)=="string" and text~="" then label=text.." [Pickup]" end
                    end
                    local x,y,z=xyz(entry.part.Position)
                    return x,y,z,label
                end)
                if ok and x then
                    local distance=math.sqrt((x-ox)^2+(y-oy)^2+(z-oz)^2)
                    if distance<=menu.Get("sae_loot_range")then
                        points[#points+1]={x=x,y=y,z=z,label=label,kind=entry.kind,distance=distance}
                    end
                end
            end
        end
        table.sort(points,function(a,b)return a.distance<b.distance end)
        local drawn,size=0,menu.Get("sae_loot_font")
        for _,p in ipairs(points)do
            if drawn>=menu.Get("sae_loot_limit")then break end
            local x,y=project(p.x,p.y+2,p.z)
            if x then
                local color=menu.GetColor("sae_loot_color_"..p.kind)
                local w=draw.GetTextSize(p.label,size)
                draw.Text(x-w/2,y-size-4,p.label,color,size)
                local distance=string.format("%.0f studs",p.distance)
                local dw=draw.GetTextSize(distance,size)
                draw.Text(x-dw/2,y+4,distance,color,size)
                drawn=drawn+1
            end
        end
    end
end
local lootFrame=setupLootESP()
local lootErrorAt=-math.huge
local function setupStaminaDiagnostics()
    local group="Stamina diagnostics"
    menu.AddGroup(TAB,group)
    menu.AddCheckbox(TAB,group,"sae_stamina_constants","Include function constants",false)
    menu.AddLabel(TAB,group,"Scan while in game. Results are printed to the console.")
    local scanning=false
    menu.AddButton(TAB,group,"sae_stamina_scan","Scan stamina parameters",function()
        if scanning then return end
        scanning=true
        local ok,err=pcall(function()
            assert(type(getgc)=="function","Vector getgc is unavailable")
            local keys={"Stamina","MaxStamina","staminaCost","staminaPerDamage",
                "staminaDrainPerSecond","staminaDrain","staminaRegen","staminaRegenRate"}
            local matches,scanError=getgc(keys,menu.Get("sae_stamina_constants"))
            assert(not scanError,tostring(scanError))
            assert(type(matches)=="table","getgc returned no table")
            print("[SAE stamina] Matches="..#matches.."; read-only scan, no values changed")
            for i,match in ipairs(matches)do
                if i>40 then print("[SAE stamina] Output capped at 40 records");break end
                local fields={}
                if type(match.fields)=="table"then
                    for _,key in ipairs(keys)do
                        local value=match.fields[key]
                        if type(value)=="number" or type(value)=="boolean"then
                            fields[#fields+1]=key.."="..tostring(value)
                        end
                    end
                end
                print("[SAE stamina] #"..i.." table="..tostring(match.table)
                    .." constant="..tostring(match.constant==true).." | "..table.concat(fields,", "))
            end
            if #matches==0 then print("[SAE stamina] No matching Lua fields found. Character attributes may not appear in getgc.")end
            print("[SAE stamina] Numeric matches may be skill costs or unrelated data; they do not prove control of server stamina.")
        end)
        scanning=false
        if not ok then print("[SAE stamina] Scan failed: "..tostring(err))end
    end)
end
setupStaminaDiagnostics()
local function setupNPCESP()
    local group = "NPC ESP"
    menu.AddGroup(TAB,group)
    menu.AddCheckbox(TAB,group,"sae_npc_enabled","Enable NPC ESP",true)
    menu.AddSliderInt(TAB,group,"sae_npc_range","Maximum distance",50,10000,2000,"%d studs")
    menu.AddSliderInt(TAB,group,"sae_npc_limit","Maximum labels",1,100,40)
    menu.AddSliderInt(TAB,group,"sae_npc_font","Font size",10,24,14)
    local categories = {
        Trader={"Traders / shops",{0.95,0.8,0.25,1}},
        Quest={"Quest givers / story NPCs",{0.3,1,0.5,1}},
        Blacksmith={"Blacksmiths",{1,0.5,0.25,1}},
        Cooking={"Cooking fires",{1,0.35,0.3,1}},
    }
    for _, category in ipairs({"Trader","Quest","Blacksmith","Cooking"}) do
        local definition=categories[category]
        menu.AddCheckbox(TAB,group,"sae_npc_"..category,definition[1],true)
        menu.AddColorpicker(TAB,group,"sae_npc_color_"..category,definition[1].." color",definition[2])
    end
    -- Filled from the dump: exact ancestor names, including empty names.
    local catalog = {
{path={"World","Folder","Model","Model","Merchant","HumanoidRootPart","Attachment","ProximityPrompt"},category="Trader",label="Merchant (sell items)"},
{path={"World","Folder","Model","Model","BeginnerWeapons","HumanoidRootPart","Attachment","ProximityPrompt"},category="Trader",label="Beginner weapons"},
{path={"World","Folder","Model","Model","BeginnerWeapons","Part","ProximityPrompt"},category="Trader",label="Beginner weapons"},
{path={"World","Folder","Model","Model","BeginnerArmor","HumanoidRootPart","Attachment","ProximityPrompt"},category="Trader",label="Beginner armor"},
{path={"World","Folder","Model","Model","BeginnerArmor","Part","ProximityPrompt"},category="Trader",label="Beginner armor"},
{path={"World","Folder","BeginningQuestNPC2","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Quest giver [Quest]"},
{path={"World","Folder","Cooking Fire","CookPrompt","ProximityPrompt"},category="Cooking",label="Cooking fire"},
{path={"World","Folder","BeginningQuestNPC3","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Quest giver [Quest]"},
{path={"World","Folder","BeginningQuestNPC4","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Guide [Quest]"},
{path={"World","Folder","BeginningQuestNPC5","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Blacksmith Guide [Quest]"},
{path={"World","Folder","Blacksmith Vendor","Blacksmith","HumanoidRootPart","Attachment","ProximityPrompt"},category="Blacksmith",label="Blacksmith"},
{path={"World","Folder","BeginningQuestNPC","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Quest giver [Quest]"},
{path={"World","Folder","TutorialNPC","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Tutorial Guide [Quest]"},
{path={"World","Shops","Potions","ProximityPrompt"},category="Trader",label="Starter items"},
{path={"Medai","WaspQuestNPC","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Quest giver [Quest]"},
{path={"Medai","HorunkaQuestNPC2","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Quest giver [Quest]"},
{path={"Medai","Model","Model","Merchant","HumanoidRootPart","Attachment","ProximityPrompt"},category="Trader",label="Merchant (sell items)"},
{path={"Medai","Model","Model","Model","Blacksmith","HumanoidRootPart","Attachment","ProximityPrompt"},category="Blacksmith",label="Blacksmith"},
{path={"Medai","Model","Horunka","ProximityPrompt"},category="Blacksmith",label="Blacksmith"},
{path={"Medai","Cooking Fire","CookPrompt","ProximityPrompt"},category="Cooking",label="Cooking fire"},
{path={"Medai","HorunkaQuestNPC1","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Quest giver [Quest]"},
{path={"Medai","Potions","ProximityPrompt"},category="Trader",label="Potions"},
{path={"Medai","TownOfBeginnings","ProximityPrompt"},category="Trader",label="Merchant (sell items)"},
{path={"Horunka","Iron","Merchant","HumanoidRootPart","Attachment","ProximityPrompt"},category="Trader",label="Iron weapons"},
{path={"Horunka","Iron","Part","ProximityPrompt"},category="Trader",label="Iron weapons"},
{path={"Horunka","Cooking Fire","CookPrompt","ProximityPrompt"},category="Cooking",label="Cooking fire"},
{path={"Horunka","Blacksmith Vendor","Blacksmith","HumanoidRootPart","Attachment","ProximityPrompt"},category="Blacksmith",label="Blacksmith"},
{path={"Horunka","BeginningQuestNPC6","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Quest giver [Quest]"},
{path={"Horunka","Model","Model","Merchant","HumanoidRootPart","Attachment","ProximityPrompt"},category="Trader",label="Merchant (sell items)"},
{path={"Horunka","MedaiQuestNPC","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Quest giver [Quest]"},
{path={"Horunka","Potions","ProximityPrompt"},category="Trader",label="Potions"},
{path={"Tolbana","AdvancedArmor","HumanoidRootPart","Attachment","ProximityPrompt"},category="Trader",label="Advanced armor"},
{path={"Tolbana","AdvancedArmor","Part","ProximityPrompt"},category="Trader",label="Advanced armor"},
{path={"Tolbana","Cooking Fire","CookPrompt","ProximityPrompt"},category="Cooking",label="Cooking fire"},
{path={"Tolbana","Model","Model","Merchant","HumanoidRootPart","Attachment","ProximityPrompt"},category="Trader",label="Merchant (sell items)"},
{path={"Tolbana","TolbanaQuestNPC","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Quest giver [Quest]"},
{path={"Tolbana","Steel","Merchant","HumanoidRootPart","Attachment","ProximityPrompt"},category="Trader",label="Steel weapons"},
{path={"Tolbana","Steel","Part","ProximityPrompt"},category="Trader",label="Steel weapons"},
{path={"Tolbana","TolbanaQuestNPC2","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Quest giver [Quest]"},
{path={"Tolbana","Blacksmith Vendor","Blacksmith","HumanoidRootPart","Attachment","ProximityPrompt"},category="Blacksmith",label="Blacksmith"},
{path={"Tolbana","TownOfBeginnings","ProximityPrompt"},category="Trader",label="Merchant (sell items)"},
{path={"Tolbana","Potions","ProximityPrompt"},category="Trader",label="Potions"},
{path={"Dungeon","BossRoom","MainDungeonQuestNPC1","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Quest giver [Quest]"},
{path={"StoryLine","Kirito","HumanoidRootPart","StoryPrompt"},category="Quest",label="Kirito [Quest]"},
{path={"BeginnerWeapons","HumanoidRootPart","Attachment","ProximityPrompt"},category="Trader",label="Beginner weapons"},
{path={"BeginnerWeapons","Part","ProximityPrompt"},category="Trader",label="Beginner weapons"},
{path={"ElfNPC","BeginningQuestNPC3","","HumanoidRootPart","QuestPrompt"},category="Quest",label="Quest giver [Quest]"},
{path={"InnMerchant","HumanoidRootPart","Attachment","ProximityPrompt"},category="Trader",label="Iron weapons"},
{path={"StoryLocal","Story_Agil","HumanoidRootPart","StoryMission"},category="Quest",label="Agil [Quest]"},
{path={"StoryLocal","Story_Kirito","HumanoidRootPart","StoryMission"},category="Quest",label="Kirito [Quest]"},
{path={"StoryLocal","Story_Klein","HumanoidRootPart","StoryMission"},category="Quest",label="Klein [Quest]"}
}
    local trie={}
    for _, entry in ipairs(catalog) do
        local branch=trie
        for _, segment in ipairs(entry.path) do
            branch.children=branch.children or {}
            branch.children[segment]=branch.children[segment] or {}
            branch=branch.children[segment]
        end
        branch.entry=entry
    end
    local candidates, scanAt={},-math.huge
    local function scan()
        local found,seen={},{}
        local function add(prompt,entry)
            if not prompt:IsA("ProximityPrompt") then return end
            local current=prompt.Parent
            local root,owner
            while utility.IsValid(current) and current~=game.Workspace do
                if not root and current:IsA("BasePart") then root=current end
                if current:IsA("Model") then
                    local hrp=current:FindFirstChild("HumanoidRootPart")
                    if utility.IsValid(hrp) then root=hrp;owner=current;break end
                end
                current=current.Parent
            end
            if not utility.IsValid(root) then return end
            local key=tostring((owner or root).Address)..":"..entry.category
            if seen[key] then return end
            seen[key]=true
            found[#found+1]={root=root,prompt=prompt,label=entry.label,category=entry.category}
        end
        local function walk(parent,branch)
            if branch.entry then add(parent,branch.entry) end
            if not branch.children then return end
            -- Iterate matching siblings instead of FindFirstChild: many map
            -- ancestors share the name Model and may contain distinct vendors.
            for _, child in ipairs(parent:GetChildren()) do
                local nextBranch=branch.children[child.Name]
                if nextBranch then walk(child,nextBranch) end
            end
        end
        walk(game.Workspace,trie)
        candidates=found
    end
    return function()
        if not menu.Get("sae_npc_enabled") then return end
        local now=utility.GetTime()
        if now-scanAt>=3 then scanAt=now;scan() end
        local lp=entity.GetLocalPlayer()
        local ox,oy,oz=xyz(lp and lp.Position)
        if not ox then return end
        local points={}
        for _, entry in ipairs(candidates) do
            if menu.Get("sae_npc_"..entry.category) then
                local ok,x,y,z=pcall(function()
                    if utility.IsValid(entry.root) and utility.IsValid(entry.prompt)
                        and entry.root.Parent and entry.prompt.Parent then return xyz(entry.root.Position) end
                end)
                if ok and x then
                    local distance=math.sqrt((x-ox)^2+(y-oy)^2+(z-oz)^2)
                    if distance<=menu.Get("sae_npc_range") then
                        points[#points+1]={entry=entry,x=x,y=y,z=z,distance=distance}
                    end
                end
            end
        end
        table.sort(points,function(a,b)return a.distance<b.distance end)
        local size,drawn=menu.Get("sae_npc_font"),0
        for _, point in ipairs(points) do
            if drawn>=menu.Get("sae_npc_limit") then break end
            local x,y=project(point.x,point.y+3,point.z)
            if x then
                local color=menu.GetColor("sae_npc_color_"..point.entry.category)
                local label=point.entry.label
                local width=draw.GetTextSize(label,size)
                draw.Text(x-width/2,y-size-4,label,color,size)
                local distance=string.format("%.0f studs",point.distance)
                local dw=draw.GetTextSize(distance,size)
                draw.Text(x-dw/2,y+4,distance,color,size)
                drawn=drawn+1
            end
        end
    end
end

local npcFrame = setupNPCESP()
local npcErrorAt = -math.huge
local function setupZoneESP()
    local group = "Mob zones ESP"
    menu.AddGroup(TAB, group)
    menu.AddCheckbox(TAB, group, "sae_zones_enabled", "Enable mob zones ESP", true)
    menu.AddSliderInt(TAB, group, "sae_zones_range", "Maximum distance", 100, 15000, 5000, "%d studs")
    menu.AddSliderInt(TAB, group, "sae_zones_limit", "Maximum labels", 1, 50, 20)
    menu.AddSliderInt(TAB, group, "sae_zones_font", "Font size", 10, 24, 14)
    menu.AddColorpicker(TAB, group, "sae_zones_color", "Zone color", {0.4, 0.85, 1, 1})
    local zones, scanAt = {}, -math.huge
    local function words(name) return (name:gsub("(%l)(%u)", "%1 %2")) end
    local function collect(folder, result)
        if not utility.IsValid(folder) then return end
        for _, part in ipairs(folder:GetChildren()) do
            if part:IsA("BasePart") then
                local area, mob, low, high = part.Name:match("^(.-)_(.-)_Lv(%d+)%-?(%d*)$")
                if area then
                    result[#result+1] = {part=part, area=words(area), mob=words(mob),
                        low=low, high=high~="" and high or low}
                end
            end
        end
    end
    return function()
        if not menu.Get("sae_zones_enabled") then return end
        local now = utility.GetTime()
        if now-scanAt >= 2 then
            scanAt = now
            local result = {}
            -- Confirmed hierarchy: Workspace.Floor1.MobZones.
            -- Also accept equivalent containers on other loaded floors.
            collect(game.Workspace:FindFirstChild("MobZones"), result)
            for _, child in ipairs(game.Workspace:GetChildren()) do
                collect(child:FindFirstChild("MobZones"), result)
            end
            zones = result
        end
        local lp = entity.GetLocalPlayer()
        local ox, oy, oz = xyz(lp and lp.Position)
        if not ox then return end
        local grouped = {}
        for _, zone in ipairs(zones) do
            local ok, x, y, z = pcall(function()
                if utility.IsValid(zone.part) and zone.part.Parent then return xyz(zone.part.Position) end
            end)
            if ok and x then
                local distance = math.sqrt((x-ox)^2+(y-oy)^2+(z-oz)^2)
                if distance <= menu.Get("sae_zones_range") then
                    -- Co-located zones with the same level range share one label.
                    local key = string.format("%s|%s|%s|%.1f|%.1f|%.1f", zone.area,zone.low,zone.high,x,y,z)
                    local group = grouped[key]
                    if not group then
                        group = {x=x,y=y,z=z,distance=distance,area=zone.area,
                            level=zone.low==zone.high and zone.low or zone.low.."-"..zone.high,
                            mobs={}, seen={}}
                        grouped[key] = group
                    end
                    if not group.seen[zone.mob] then
                        group.seen[zone.mob] = true; group.mobs[#group.mobs+1] = zone.mob
                    end
                end
            end
        end
        local points = {}
        for _, point in pairs(grouped) do points[#points+1] = point end
        table.sort(points,function(a,b)return a.distance<b.distance end)
        local size, color, drawn = menu.Get("sae_zones_font"), menu.GetColor("sae_zones_color"), 0
        for _, point in ipairs(points) do
            if drawn >= menu.Get("sae_zones_limit") then break end
            local x, y = project(point.x,point.y,point.z)
            if x then
                table.sort(point.mobs)
                local lines = {point.area, table.concat(point.mobs," / ").." [Lv."..point.level.."]",
                    string.format("%.0f studs",point.distance)}
                for i, line in ipairs(lines) do
                    local width = draw.GetTextSize(line,size)
                    draw.Text(x-width/2,y+(i-2)*(size+3),line,color,size)
                end
                drawn = drawn+1
            end
        end
    end
end
local zoneFrame = setupZoneESP()
local zoneErrorAt = -math.huge
local parryFrame = setupParry(makeSAETracker)
local espFrame = OnFrame
local function watermarkFrame()
    local screenWidth, screenHeight = draw.GetScreenSize()
    if type(screenWidth)~="number" or type(screenHeight)~="number" or screenWidth<=0 or screenHeight<=0 then return end
    local width=draw.GetTextSize(SAE_TITLE,16)
    draw.Text(math.max(8,screenWidth-width-20),20,SAE_TITLE,{0.5,0.88,1,1},16)
end
OnFrame = function()
    local ok, err = pcall(parryFrame)
    if not ok then
        menu.Set("sae_ap_enabled", false)
        print("[SAE parry] Disabled: " .. tostring(err))
    end
    espFrame()
    local lootOK,lootError=pcall(lootFrame)
    if not lootOK and utility.GetTime()-lootErrorAt>=5 then
        lootErrorAt=utility.GetTime()
        print("[SAE Loot ESP] "..tostring(lootError))
    end
    local npcOK,npcError=pcall(npcFrame)
    if not npcOK and utility.GetTime()-npcErrorAt>=5 then
        npcErrorAt=utility.GetTime()
        print("[SAE NPC ESP] "..tostring(npcError))
    end
    local zoneOK, zoneError = pcall(zoneFrame)
    if not zoneOK and utility.GetTime()-zoneErrorAt >= 5 then
        zoneErrorAt = utility.GetTime()
        print("[SAE zone ESP] "..tostring(zoneError))
    end
    pcall(watermarkFrame)
end
