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

