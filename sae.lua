-- SAO / Project Vector: mob ESP. API: project-vector-lua-api.md.
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
print("[SAO] Mob and Ore ESP loaded. Open SAO > Mob ESP / Ore ESP.")

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
    ["ClassDescriptor"]            = offsets.Instance and offsets.Instance.ClassDescriptor or 0,    -- const
    ["ClassDescriptorToClassName"] = offsets.Instance and offsets.Instance.ClassName or 0,          -- const
    ["Name"]                       = offsets.Instance and offsets.Instance.Name or 0,               -- const
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
for _, key in ipairs({"AnimationId", "TimePosition", "ActiveAnimations", "Animation", "Speed", "IsPlaying", "Name"}) do
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
        print("Failed to resolve Animator.")
        return
    end

    -- Head of the linked list of active animations
    local ListHead_Ptr = memory.Read(AnimatorAddress + KnownOffsets.ActiveAnimations, "ptr")
    if not ListHead_Ptr or ListHead_Ptr == 0 then
        return
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

    local NamePtr        = memory.Read(AnimationTrackAddress + KnownOffsets.Name, "ptr")
    local Name = NamePtr and NamePtr ~= 0 and memory.ReadString(NamePtr, 256) or ""
    local TimePosition   = memory.Read(AnimationTrackAddress + KnownOffsets.TimePosition, "float")
    local Speed          = memory.Read(AnimationTrackAddress + KnownOffsets.Speed, "float")
    local IsPlaying      = memory.Read(AnimationTrackAddress + KnownOffsets.IsPlaying, "u8")

    return {
        Address      = AnimationTrackAddress,
        Name         = Name,
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
    local tracksPlaying = GetPlayingAnimationTracks(character)
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
    menu.AddHotkey(tab, group, "sae_ap_hold", "Hold to activate", 0x56)
    menu.AddHotkey(tab, group, "sae_ap_key", "Block / parry key", 0x46)
    menu.AddSliderFloat(tab, group, "sae_ap_range", "Maximum distance", 2, 20, 10, "%.1f")
    menu.AddSliderInt(tab, group, "sae_ap_delay", "Animation delay (ms)", 0, 500, 0)
    menu.AddCheckbox(tab, group, "sae_ap_log", "Log detected attacks", false)
    menu.AddLabel(tab, group, "Basic mobs only. Hold V in game; F must match your bind.")
    local attacks = {
        boar = {[13774059143]=true}, wolf = {[13803750988]=true},
        koboldtrooper = {[13803854864]=true}, koboldsentinel = {[13803854864]=true},
        nepenthes = {[116371641636454]=true}, windwasp = {[94230248318965]=true},
    }
    local state, Tracker, failed = {}, nil, false
    local lastPress, lastPoll = -math.huge, -math.huge
    return function()
        if not menu.Get("sae_ap_enabled") or not input.IsKeyDown(menu.GetKey("sae_ap_hold")) then
            state = {}; return
        end
        if failed then return end
        if not Tracker then
            local ok, result = pcall(makeTracker)
            if not ok then
                failed = true; menu.Set("sae_ap_enabled", false)
                print("[SAE parry] Tracker unavailable: " .. tostring(result)); return
            end
            Tracker = result
        end
        local now = utility.GetTime()
        if now-lastPoll < 0.02 then return end
        lastPoll = now
        local lp = entity.GetLocalPlayer()
        if not lp or not lp.IsAlive or not lp.Position then state = {}; return end
        local origin = lp.Position
        local folder = game.Workspace:FindFirstChild("Mobs")
        if not utility.IsValid(folder) then state = {}; return end
        local present, ready = {}, {}
        for _, mob in ipairs(folder:GetChildren()) do
            local allowed = attacks[mob.Name:lower():gsub("^corrupted", "")]
            if allowed and mob:IsA("Model") then
                local ok, err = pcall(function()
                    local root = mob:FindFirstChild("Collider") or mob:FindFirstChild("HumanoidRootPart")
                    if not utility.IsValid(root) or not root.Position then return end
                    local p = root.Position
                    local distance = math.sqrt((p.X-origin.X)^2+(p.Y-origin.Y)^2+(p.Z-origin.Z)^2)
                    if distance > menu.Get("sae_ap_range") then return end
                    local key = mob.Address
                    present[key] = true
                    local s = state[key] or {tracker=Tracker.new(), tracks={}}
                    state[key] = s
                    local active = {}
                    for _, info in ipairs(s.tracker:Update(mob)) do
                        local id = tonumber(tostring(info.AnimationId):match("%d+"))
                        local t = info.TimePosition
                        if allowed[id] and type(t)=="number" and t==t and t>=0 and info.IsPlaying~=0 then
                            local k = tostring(info.Address) .. ":" .. tostring(id)
                            active[k] = true
                            local old = s.tracks[k]
                            if not old or t < old.time-0.05 then
                                old = {used=false, time=t}; s.tracks[k] = old
                                if menu.Get("sae_ap_log") then print("[SAE parry] " .. mob.Name .. " animation=" .. id .. " time=" .. t) end
                            end
                            old.time = t
                            -- Clip time is used directly, so changed animation speed is reflected.
                            local target = menu.Get("sae_ap_delay")/1000
                            if not old.used and t >= target and t <= target+0.15 then
                                ready[#ready+1] = {state=old, distance=distance}
                            end
                        end
                    end
                    for k in pairs(s.tracks) do if not active[k] then s.tracks[k]=nil end end
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
        if ready[1] and now-lastPress >= 0.95 and key>0 and not input.IsKeyDown(key) then
            lastPress = now
            for _, attack in ipairs(ready) do attack.state.used = true end
            utility.KeyPress(key, 30)
        end
    end
end

local parryFrame = setupParry(makeSAETracker)
local espFrame = OnFrame
OnFrame = function()
    espFrame()
    local ok, err = pcall(parryFrame)
    if not ok then
        menu.Set("sae_ap_enabled", false)
        print("[SAE parry] Disabled: " .. tostring(err))
    end
end
