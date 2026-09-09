# Project Vector — Lua API Reference

---

## Thread (`thread.*`)

### thread.Create → integer

Registers a recurring callback that fires every interval_ms milliseconds. Returns an integer ID for use with thread.Stop, thread.IsRunning, and thread.SetInterval.

**Signature**
```
function thread.Create(callback: function, interval_ms?: integer) → integer
```

**Parameters**

- `callback` — function
- `interval_ms (optional)` — integer

**Example**
```lua
local id = thread.Create(function()
  print("tick")
end)
local id2 = thread.Create(function()
  print("slow tick")
end, 500)
```

### thread.Stop → void

Stops the thread with the given ID and releases its callback. Silent no-op if the ID does not exist.

**Signature**
```
function thread.Stop(id: integer) → void
```

**Parameters**

- `id` — integer

**Example**
```lua
local id = thread.Create(function()
  print("running")
end)

thread.Stop(id)
```

### thread.StopAll → void

Stops all active threads and releases their callbacks. Called automatically when a script is unloaded.

**Signature**
```
function thread.StopAll() → void
```

**Example**
```lua
thread.StopAll()
```

### thread.IsRunning → boolean

Returns true if a thread with the given ID exists and is active.

**Signature**
```
function thread.IsRunning(id: integer) → boolean
```

**Parameters**

- `id` — integer

**Example**
```lua
local id = thread.Create(function() end)

print(thread.IsRunning(id))
thread.Stop(id)
print(thread.IsRunning(id))
```

### thread.SetInterval → void

Updates the fire interval of an existing thread in-place. interval_ms is clamped to a minimum of 1. Silent no-op if the ID does not exist.

**Signature**
```
function thread.SetInterval(id: integer, interval_ms: integer) → void
```

**Parameters**

- `id` — integer
- `interval_ms` — integer

**Example**
```lua
local id = thread.Create(function()
  print("tick")
end, 100)
thread.SetInterval(id, 1000)
```

### sleep → void

Pauses the script for the given number of seconds. Not valid inside a thread.Create callback.

**Signature**
```
function sleep(seconds: number) → void
```

**Parameters**

- `seconds` — number

**Example**
```lua
while true do
  print("hello")
  sleep(1)
end
```

### OnFrame

Set this global to a function and it will be called every render frame. All three naming styles work: OnFrame, onFrame, on_frame.

**Example**
```lua
OnFrame = function()
  local lp = game.LocalPlayer
end
```

### OnPlayerAdded

Called when a player joins. The new Player instance is passed as the first argument.

**Example**
```lua
OnPlayerAdded = function(player)
  print(player.Name, "joined")
end
```

### OnPlayerRemoved

Called when a player leaves. The departing Player instance is passed as the first argument.

**Example**
```lua
OnPlayerRemoved = function(player)
  print(player.Name, "left")
end
```

---

## Game (`game.*`)

### game.LocalPlayer → instance

Returns the local Player instance. Equivalent to game.Players.LocalPlayer.

**Example**
```lua
local lp = game.LocalPlayer
local char = lp.Character
print(lp.Name, lp.UserId)
```

### game.GetService → instance

Returns any Roblox service by class name. Both dot and colon syntax work.

**Signature**
```
function game.GetService(name: string) → instance
```

**Parameters**

- `name` — string

**Example**
```lua
local RS = game.GetService("ReplicatedStorage")
local Run = game.GetService("RunService")
local Players = game:GetService("Players")
```

### game.Workspace → instance

The Workspace service; root container for all 3D world objects.

**Example**
```lua
local ws = game.Workspace
for _, obj in ipairs(ws:GetChildren()) do
  print(obj.Name, obj.ClassName)
end
```

### game.Players → instance

The Players service. Children are all connected Player instances.

**Example**
```lua
for _, p in ipairs(game.Players:GetChildren()) do
  print(p.Name, p.UserId)
end
```

### game.PlaceId

The place ID of the currently running Roblox game. game.GameId is the parent universe ID.

**Example**
```lua
print("Place:", game.PlaceId)
print("Game:",  game.GameId)
```

### Service Shortcuts

Convenience properties for the most common services. Each is equivalent to game.GetService("<ServiceName>"). Available shortcuts: ReplicatedStorage, ReplicatedFirst, StarterGui, StarterPack, StarterPlayer, Teams, SoundService, Chat, RunService.

**Example**
```lua
local gui = game.StarterGui
local run = game.RunService
local rstor = game.ReplicatedStorage
local gui2 = game.GetService("StarterGui")
```

### Instance Properties

Common properties available on every instance returned by the API.

**Properties**

- `Name` — string
- `ClassName` — string
- `Parent` — instance
- `Address` — integer

**Example**
```lua
local lp = game.LocalPlayer
print(lp.Name)
print(lp.ClassName)
print(lp.Parent.Name)
print(string.format("0x%X", lp.Address))
```

### inst:GetChildren → table

Returns a table of all direct children of this instance.

**Signature**
```
function inst:GetChildren() → table
```

**Example**
```lua
local children = game.Workspace:GetChildren()
for _, c in ipairs(children) do
  print(c.Name, c.ClassName)
end
```

### inst:GetDescendants → table

Returns a flat table of all descendants, searched recursively. GetDescendantsOfClass filters by class name.

**Variants**

- `inst:GetDescendants()` — All descendants
- `inst:GetDescendantsOfClass(className)` — Only descendants whose ClassName matches

**Example**
```lua
local parts = game.Workspace:GetDescendantsOfClass("Part")
print(#parts, "parts found")
local all = game.Workspace:GetDescendants()
print(#all, "total objects")
```

### inst:FindFirstChild → instance?

Searches children by name or class; returns nil if not found.

**Variants**

- `inst:FindFirstChild(name, recursive?)` — First child whose Name matches
- `inst:FindFirstChildOfClass(className)` — First child whose ClassName matches
- `inst:FindFirstChildWhichIsA(className)` — First child whose class inherits from className

**Example**
```lua
local char = game.LocalPlayer.Character
local hrp = char:FindFirstChild("HumanoidRootPart")
local hum = char:FindFirstChildOfClass("Humanoid")

if hum then
  print("Health:", hum.Health)
end
```

### inst:FindFirstDescendant → instance?

Searches all descendants and ancestors by name or class. Returns nil if not found.

**Variants**

- `inst:FindFirstDescendant(name)` — First descendant whose Name matches
- `inst:FindFirstDescendantOfClass(className)` — First descendant whose ClassName matches
- `inst:FindFirstAncestor(name)` — First ancestor whose Name matches
- `inst:FindFirstAncestorOfClass(className)` — First ancestor whose ClassName matches

**Example**
```lua
local part = game.Workspace:FindFirstDescendant("Baseplate")
local model = part:FindFirstAncestorOfClass("Model")
```

### inst:IsA → boolean

Tests class membership and hierarchy relationships between instances.

**Variants**

- `inst:IsA(className)` — True if inst's class inherits from className
- `inst:IsDescendantOf(ancestor)` — True if inst is a descendant of ancestor
- `inst:IsAncestorOf(descendant)` — True if inst is an ancestor of descendant

**Example**
```lua
local hum = game.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

print(hum:IsA("Humanoid"))
print(hum:IsDescendantOf(game.Workspace))
print(game.Workspace:IsAncestorOf(hum))
```

### Vector3.New → Vector3

Creates a Vector3 userdata value. All three components default to 0 if omitted. Supports arithmetic operators (+ - * / -unary), ==, # (magnitude), and tostring.

**Signature**
```
function Vector3.New(x?: number, y?: number, z?: number) → Vector3
```

**Fields & Methods**

- `x / X, y / Y, z / Z` — number
- `Magnitude` — number
- `Unit` — Vector3
- `:Dot(other)` — number
- `:Cross(other)` — Vector3
- `:Lerp(goal, alpha)` — Vector3

**Example**
```lua
local a = Vector3.New(1, 0, 0)
local b = Vector3.New(0, 1, 0)

print(a.Magnitude)
print(a:Dot(b))
print(a:Cross(b))
print(a:Lerp(b, 0.5))
print(a + b)
print(a * 2)
```

---

## Menu (`menu.*`)

### menu.AddTab

Creates a top-level tab. All menu functions are available as PascalCase, camelCase, and snake_case (AddTab / addTab / add_tab).

**Signature**
```
function menu.AddTab(name: string, icon?: string, size?: string)
```

**Parameters**

- `name` — string
- `icon` — string
- `size` — string

**Example**
```lua
menu.AddTab("Combat", "C")
menu.AddTab("Visuals", "V")
menu.AddTab("Misc", "M", "half")
```

### menu.AddGroup

Creates a group container inside a tab that holds elements.

**Signature**
```
function menu.AddGroup(tab: string, name: string, width?: number, same_line?: boolean)
```

**Parameters**

- `tab` — string
- `name` — string
- `width` — number
- `same_line` — boolean

**Example**
```lua
menu.AddTab("Combat", "C")
menu.AddGroup("Combat", "Aimbot")
menu.AddGroup("Combat", "Target", 0, true)
```

### menu.AddCheckbox

Adds a toggle checkbox. Supports an optional inline hotkey, color picker, and parent visibility dependency via the options table.

**Signature**
```
function menu.AddCheckbox(tab, group, id, label: string, default?: boolean, options?: table)
```

**Common Parameters**

- `tab` — string
- `group` — string
- `id` — string
- `label` — string
- `default` — boolean

**Options Table**

- `key` — integer
- `colorpicker` — {r,g,b,a}
- `parent` — string
- `show_mode` — boolean

**Example**
```lua
menu.AddCheckbox("Combat", "Aimbot", "aim_enabled", "Enable", false)
menu.AddCheckbox("Visuals", "ESP", "esp_box", "Boxes", true, {
  key = 0x42,
  colorpicker = {1,0,0,1},
})
menu.AddCheckbox("Combat", "Aimbot", "aim_silent", "Silent", false, {
  parent = "aim_enabled"
})
```

### menu.AddSliderInt / AddSliderFloat

Adds an integer or float slider. The format string uses standard printf syntax and is shown next to the current value.

**Variants**

- `AddSliderInt(tab, group, id, label, min, max, default?, format?, options?)` — Integer values. Default format: "%d"
- `AddSliderFloat(tab, group, id, label, min, max, default?, format?, options?)` — Float values. Default format: "%.2f"

**Options Table**

- `parent` — string
- `parent_value` — integer

**Example**
```lua
menu.AddSliderInt("Combat", "Aimbot", "fov", "FOV", 1, 360, 90, "%d°")
menu.AddSliderFloat("Combat", "Aimbot", "smooth", "Smooth", 0.1, 10.0, 1.0, "%.1f")

menu.SetCallback("fov", function(v)
  print("FOV changed to", v)
end)
```

### menu.AddButton

Adds a full-width clickable button. The callback is set at creation time — use the callback parameter, not SetCallback (which has no effect on buttons).

**Signature**
```
function menu.AddButton(tab, group, id, label: string, callback?: function)
```

**Example**
```lua
menu.AddButton("Misc", "Utils", "btn_clear", "Clear logs", function()
  print("logs cleared")
end)
```

### menu.AddCombo

Adds a single-select dropdown. Get returns the current 0-based selected index. The change callback receives the new index.

**Signature**
```
function menu.AddCombo(tab, group, id, label: string, items: table, default_idx?: integer, options?: table)
```

**Parameters**

- `items` — string[]
- `default_idx` — integer

**Example**
```lua
menu.AddCombo("Combat", "Aimbot", "aim_bone", "Bone",
  {"Head", "Neck", "Chest"}, 0)

menu.SetCallback("aim_bone", function(idx)
  print("Selected bone index:", idx)
end)

local bone = menu.Get("aim_bone")
```

### menu.AddMulticombo

Adds a multi-select dropdown. Get returns an array of booleans, one per item. No change callback is fired.

**Signature**
```
function menu.AddMulticombo(tab, group, id, label: string, items: table, defaults?: table)
```

**Example**
```lua
menu.AddMulticombo("Visuals", "ESP", "esp_flags", "Show",
  {"Name", "Health", "Weapon"},
  {true, true, false})

local flags = menu.Get("esp_flags")
if flags[1] then print("Name enabled") end
```

### menu.AddInput

Adds a text input field with a 256-character buffer. Get returns the current string. No change callback is fired.

**Signature**
```
function menu.AddInput(tab, group, id, label: string, default?: string)
```

**Example**
```lua
menu.AddInput("Misc", "Settings", "cfg_name", "Config name", "default")

local name = menu.Get("cfg_name")
```

### menu.AddHotkey

Adds a standalone key-binding widget. Use GetKey/SetKey to read and write its value — Get/Set do not correctly round-trip on hotkey elements.

**Signature**
```
function menu.AddHotkey(tab, group, id, label: string, default_key?: integer, options?: table)
```

**Example**
```lua
menu.AddHotkey("Misc", "Binds", "menu_key", "Menu toggle", 0x2D)

local key = menu.GetKey("menu_key")
menu.SetKey("menu_key", 0x2D)
```

### menu.AddColorpicker

Adds an RGBA color picker. All color values are floats in the range [0.0, 1.0]. Use GetColor/SetColor to read and write.

**Signature**
```
function menu.AddColorpicker(tab, group, id, label: string, default?: {r,g,b,a}, options?: table)
```

**Example**
```lua
menu.AddColorpicker("Visuals", "ESP", "col_team", "Team color",
  {0, 0.47, 1, 1})

local c = menu.GetColor("col_team")
print(c[1], c[2], c[3], c[4])

menu.SetColor("col_team", {1, 0, 0, 1})
```

### menu.AddLabel / AddSeparator

Static decorative elements. AddLabel renders muted text. AddSeparator inserts a spacing gap. Neither takes an id or supports Get/Set.

**Variants**

- `menu.AddLabel(tab, group, text)` — Muted static text line
- `menu.AddSeparator(tab, group)` — Vertical spacing gap

**Example**
```lua
menu.AddLabel("Combat", "Aimbot", "-- Targeting --")
menu.AddSeparator("Combat", "Aimbot")
menu.AddCheckbox("Combat", "Aimbot", "aim_enabled", "Enable")
```

### menu.Get → any

Returns the current value of an element by its ID. Return type depends on the element.

**Signature**
```
function menu.Get(id: string) → any
```

**Return Types by Element**

- `checkbox` — boolean
- `slider_int` — integer
- `slider_float` — number
- `combo` — integer
- `multicombo` — boolean[]
- `input` — string
- `colorpicker` — {r,g,b,a}
- `hotkey` — integer
- `button / not found` — nil

**Example**
```lua
if menu.Get("aim_enabled") then
  local fov = menu.Get("fov")
  local smooth = menu.Get("smooth")
end
```

### menu.GetColor / GetKey

Typed getters for color and key values. Prefer these over menu.Get for colorpicker and hotkey elements.

**Variants**

- `menu.GetColor(id) → {r,g,b,a}` — RGBA floats. Returns {1,1,1,1} if not found
- `menu.GetKey(id) → integer` — VK key code. Returns 0 if not found

**Example**
```lua
local col = menu.GetColor("col_team")
local key = menu.GetKey("menu_key")
```

### menu.Set

Sets an element's value by ID. Does not fire the registered change callback. For hotkey elements, use SetKey instead — Set writes to the wrong field on hotkeys.

**Signature**
```
function menu.Set(id: string, value: any)
```

**Example**
```lua
menu.Set("aim_enabled", true)
menu.Set("fov", 120)
menu.Set("aim_bone", 1)
menu.Set("cfg_name", "my_config")
```

### menu.SetColor / SetKey

Typed setters for color and key values.

**Variants**

- `menu.SetColor(id, {r,g,b,a})` — Sets colorpicker value. RGBA floats [0.0–1.0]
- `menu.SetKey(id, key: integer)` — Sets VK key code on a hotkey or checkbox hotkey

**Example**
```lua
menu.SetColor("col_team", {0, 1, 0, 1})
menu.SetKey("menu_key", 0x2D)
```

### menu.SetCallback

Registers a change callback for an element. Fires on checkbox, slider, and combo changes. Has no effect on buttons or hotkeys.

**Signature**
```
function menu.SetCallback(id: string, callback: function)
```

**Example**
```lua
menu.SetCallback("aim_enabled", function(enabled)
  print("Aimbot:", enabled)
end)

menu.SetCallback("fov", function(v)
  print("FOV set to", v)
end)
```

### menu.SetVisible

Shows or hides an element. Hidden elements retain their values and can still be read via Get.

**Signature**
```
function menu.SetVisible(id: string, visible: boolean)
```

**Example**
```lua
menu.SetCallback("esp_enabled", function(on)
  menu.SetVisible("esp_box",    on)
  menu.SetVisible("esp_health", on)
end)
```

---

## Entity (`entity.*`)

### entity.GetPlayers → table

Returns a 1-indexed array of all player objects currently in the cache. If no players are cached, returns an empty table. Players are not sorted in any guaranteed order.

**Signature**
```
function entity.GetPlayers() → table
```

**Example**
```lua
for _, p in ipairs(entity.GetPlayers()) do
  if not p.IsLocal and p.IsAlive then
    print(p.Name, p.Health)
  end
end
```

### entity.GetLocalPlayer / GetPlayerCount

GetLocalPlayer returns the local player object, or nil if invalid. GetPlayerCount returns the total number of cached players as an integer.

**Example**
```lua
local lp = entity.GetLocalPlayer()
if lp then
  print(lp.Name, lp.Health)
end

print("Players online:", entity.GetPlayerCount())
```

### Cached Properties

These fields are read from the internal cache at the time the player object is created, not live-read on each access. They reflect the state at the last cache refresh.

- `Name` — string
- `DisplayName` — string
- `UserId` — integer
- `Team` — string
- `HasTeam` — boolean
- `IsLocal` — boolean
- `IsValid` — boolean
- `IsWorkspaceEntity` — boolean
- `ToolName` — string
- `RigType` — string

**Example**
```lua
for _, p in ipairs(entity.GetPlayers()) do
  print(p.Name, p.UserId, p.RigType, p.ToolName)
end
```

### Instance Refs

Returns live Roblox instance handles compatible with the game API. Each may be nil if the character is not loaded or the player has left.

- `Character` — instance?
- `Humanoid` — instance?
- `Player` — instance?

**Example**
```lua
local lp = entity.GetLocalPlayer()
local char = lp.Character
local hum = lp.Humanoid

if char then
  local tool = char:FindFirstChildOfClass("Tool")
end
```

### Health & Alive State

Health values are live-read from the humanoid's memory on every access. They can also be written directly. Returns 0 (Health) or 100 (MaxHealth) if the humanoid is null.

- `Health` — number
- `MaxHealth` — number
- `IsAlive` — boolean
- `IsDead` — boolean

**Example**
```lua
for _, p in ipairs(entity.GetPlayers()) do
  if not p.IsLocal and p.IsAlive then
    p.Health = 0
  end
end
```

### State / StateName

State returns the raw Enum.HumanoidStateType integer, live-read each access. StateName returns a human-readable string for the same value. Both are readable; State is also writable.

**Example**
```lua
local lp = entity.GetLocalPlayer()
print(lp.State)
print(lp.StateName)

lp.State = 11
```

### Physics Properties

All live-read from humanoid memory. Sensible defaults are returned when the humanoid is null (e.g. WalkSpeed → 16, JumpPower → 50). Boolean flags return false when null. All are writable.

- `WalkSpeed` — 16.0
- `JumpPower` — 50.0
- `JumpHeight` — 7.2
- `HipHeight` — 0.0
- `MaxSlopeAngle` — 89.0
- `Sit` — false
- `IsJumping` — false
- `PlatformStand` — false
- `AutoRotate` — false
- `IsWalking` — false

**Example**
```lua
local lp = entity.GetLocalPlayer()
lp.WalkSpeed = 100
lp.JumpPower = 200
lp.Jump = true
```

### Position & Movement

All live-read. Position and Velocity return nil if the root primitive is null. LookVector and MoveDirection fall back to a default forward vector. Position, Velocity, and CameraOffset are writable.

- `Position` — Vector3?
- `HeadPosition` — Vector3?
- `Velocity` — Vector3?
- `LookVector` — Vector3
- `MoveDirection` — Vector3
- `CameraOffset` — Vector3

**Example**
```lua
local lp = entity.GetLocalPlayer()
local pos = lp.Position
if pos then
  print(pos.X, pos.Y, pos.Z)
end
lp.Position = Vector3.New(0, 100, 0)
lp.Velocity = Vector3.New(0, 0, 0)
```

### player:GetBoneScreen → x, y, visible

Projects a named body part to screen coordinates. Returns three values: screen X, screen Y, and a boolean for whether it is on-screen. Returns 0, 0, false for unknown bone names or parts behind the camera. Bone names are case-sensitive.

**Signature**
```
function player:GetBoneScreen(bone_name: string) → number, number, boolean
```

**Valid Bone Names**

- `Head, Torso, HumanoidRootPart` — Head, UpperTorso, LowerTorso, HumanoidRootPart
- `Left Arm, Right Arm` — LeftUpperArm, LeftLowerArm, LeftHand
- `Left Leg, Right Leg` — RightUpperArm, RightLowerArm, RightHand
- `—` — LeftUpperLeg, LeftLowerLeg, LeftFoot
- `—` — RightUpperLeg, RightLowerLeg, RightFoot

**Example**
```lua
for _, p in ipairs(entity.GetPlayers()) do
  local x, y, vis = p:GetBoneScreen("Head")
  if vis then
  end
end
```

### player:GetBonesScreen → table

Returns screen-space positions of all visible bones as a dictionary. Keys are bone names; values are {x, y} arrays. Off-screen bones are excluded.

**Signature**
```
function player:GetBonesScreen() → table
```

**Example**
```lua
local bones = p:GetBonesScreen()
local head = bones["Head"]
if head then
  print(head[1], head[2])
end
```

### player:GetBounds → table

Returns a screen-space bounding box for the full character. If no part is on screen, valid is false and all values are 0.

**Signature**
```
function player:GetBounds() → {x, y, w, h, valid}
```

**Return Table**

- `x` — number
- `y` — number
- `w` — number
- `h` — number
- `valid` — boolean

**Example**
```lua
local b = p:GetBounds()
if b.valid then
  draw.Rect(b.x, b.y, b.w, b.h)
end
```

### player:DistanceTo → number

Returns the distance from the player's root part to a given point. Without an argument, uses the camera position. Returns 0 if the root part is null.

**Signature**
```
function player:DistanceTo(vec3?: Vector3) → number
```

**Example**
```lua
local dist = p:DistanceTo()
local origin = Vector3.New(0, 0, 0)
print(p:DistanceTo(origin))
local players = entity.GetPlayers()
table.sort(players, function(a, b)
  return a:DistanceTo() < b:DistanceTo()
end)
```

---

## Draw (`draw.*`)

### draw.Line

Draws a straight line from (x1,y1) to (x2,y2). Coordinates outside [-5000, 5000] or exactly (0,0) are silently rejected. All primitives automatically include a shadow pass.

**Signature**
```
function draw.Line(x1, y1, x2, y2: number, color: {r,g,b,a}, thickness?: number)
```

**Parameters**

- `x1, y1` — number
- `x2, y2` — number
- `color` — {r,g,b,a}
- `thickness` — number

**Example**
```lua
draw.Line(100, 100, 400, 300, {1, 0, 0, 1})
draw.Line(100, 100, 400, 300, {1, 1, 1, 1}, 2.0)
```

### draw.Rect / draw.RectFilled

Draws an outlined or solid-filled rectangle. rounding rounds the corners in pixels.

**Variants**

- `draw.Rect(x, y, w, h, color, rounding?, thickness?)` — Outlined rect. Default thickness: 1.0
- `draw.RectFilled(x, y, w, h, color, rounding?)` — Solid filled rect

**Example**
```lua
draw.RectFilled(50, 50, 200, 30, {0, 0, 0, 0.6})
draw.Rect(50, 50, 200, 30, {1, 1, 1, 1})
```

### draw.Circle / draw.CircleFilled

Draws a circle centered at (x, y). The unfilled variant draws shadow rings on both sides of the line for a bracketed look.

**Variants**

- `draw.Circle(x, y, radius, color, segments?, thickness?)` — Outlined circle. Default segments: 32, thickness: 1.0
- `draw.CircleFilled(x, y, radius, color, segments?)` — Solid filled circle. Default segments: 32

**Example**
```lua
local sw, sh = draw.GetScreenSize()
draw.Circle(sw/2, sh/2, 80, {1, 1, 1, 0.5})
```

### draw.Text / draw.GetTextSize

draw.Text renders a string at (x, y) with a 4-direction black shadow outline. draw.GetTextSize measures the pixel dimensions of text at a given font size without drawing.

**Variants**

- `draw.Text(x, y, text, color, size?)` — Nothing. Default size: 14.0
- `draw.GetTextSize(text, size?) → w, h` — Two numbers: pixel width, pixel height

**Example**
```lua
local label = "Player Name"
local tw, th = draw.GetTextSize(label, 14)
draw.Text(b.x + b.w/2 - tw/2, b.y - th - 2,
  label, {1, 1, 1, 1}, 14)
```

### draw.Box / draw.CornerBox

ESP box helpers. draw.Box has a style integer that selects between internal box rendering variants. draw.CornerBox renders corner-bracket style with no style param. Both validate (x,y) and (x+w, y+h). Colors are {r,g,b,a} floats.

**Variants**

- `draw.Box(x, y, w, h, color, style?)` — ESP box. Default style: 0
- `draw.CornerBox(x, y, w, h, color)` — Corner-bracket box, no style param

**Example**
```lua
local b = p:GetBounds()
if b.valid then
  draw.CornerBox(b.x, b.y, b.w, b.h, {1, 1, 1, 1})
end
```

### draw.HealthBar

Draws an ESP health bar with an internal green-to-red gradient. No color parameter — the gradient is hardcoded. Fill ratio is health / max_health.

**Signature**
```
function draw.HealthBar(x, y, height, health, max_health: number)
```

**Example**
```lua
local b = p:GetBounds()
if b.valid then
  draw.HealthBar(b.x - 6, b.y, b.h, p.Health, p.MaxHealth)
end
```

### draw.Poly / PolyClosed / PolyFilled

Draws polylines or filled polygons from a table of {x, y} screen-space points. PolyFilled requires points to be in convex winding order — use draw.ComputeHull first if they are unordered.

**Variants**

- `draw.Poly(points, color, thickness?)` — Open polyline. Default thickness: 1.5
- `draw.PolyClosed(points, color, thickness?)` — Closed polyline (end connects to start)
- `draw.PolyFilled(points, color)` — Filled convex polygon. Requires ≥3 convex-ordered points

**Example**
```lua
local pts = {{100,100}, {200,80}, {250,200}, {80,220}}
local hull = draw.ComputeHull(pts)
draw.PolyFilled(hull, {1, 0, 0, 0.4})
draw.PolyClosed(hull, {1, 0, 0, 1})
```

### draw.ComputeHull → {{x,y},...}

Computes the convex hull of an unordered 2D point set. Returns a new table of {x, y} pairs in convex winding order, suitable for passing directly to draw.PolyFilled or draw.PolyClosed.

**Signature**
```
function draw.ComputeHull(points: {{x,y},...}) → {{x,y},...}
```

**Example**
```lua
local corners = {}
for _, c in ipairs(world_corners) do
  local sx, sy, ok = draw.WorldToScreen(c[1], c[2], c[3])
  if ok then table.insert(corners, {sx, sy}) end
end
local hull = draw.ComputeHull(corners)
draw.PolyClosed(hull, {1, 1, 0, 1})
```

### draw.ChamsPlayer / GetPlayerHulls / Chams

Native chams renderer. Merges overlapping body-part hulls before rendering, eliminating seams that draw.PolyFilled per-part cannot.

**Variants**

- `draw.ChamsPlayer(player, color, style?)` — Draws chams directly from a player object
- `draw.ChamsPlayer(player, color, color2, style?)` — Gradient chams with primary + secondary color
- `draw.GetPlayerHulls(player) → hulls` — Returns per-part screen hulls without drawing
- `draw.Chams(hulls, color, style?)` — Renders pre-built hulls through the chams pipeline

**Style Values**

- `0` — Filled (default)
- `1` — Outline only
- `2` — Glow

**Example**
```lua
for _, p in ipairs(entity.GetPlayers()) do
  if not p.IsLocal and p.IsAlive then
    draw.ChamsPlayer(p, {1, 0, 0, 0.6})
    draw.ChamsPlayer(p, {1,0,0,1}, {0,0,1,1}, 0)
  end
end
local hulls = draw.GetPlayerHulls(p)
draw.Chams(hulls, {0, 1, 0, 0.5}, 2)
```

### draw.WorldToScreen → sx, sy, valid

Projects a 3D world-space point to 2D screen coordinates using the cached view matrix. Always returns three values — check valid before using sx/sy.

**Signature**
```
function draw.WorldToScreen(x, y, z: number) → number, number, boolean
```

**Example**
```lua
local pos = p.Position
if pos then
  local sx, sy, ok = draw.WorldToScreen(pos.X, pos.Y + 3, pos.Z)
  if ok then
    draw.Text(sx, sy, p.Name, {1,1,1,1})
  end
end
```

### draw.GetScreenSize → width, height

Returns the current overlay render dimensions in pixels. Useful for centering elements or positioning HUD items relative to screen edges.

**Signature**
```
function draw.GetScreenSize() → number, number
```

**Example**
```lua
local sw, sh = draw.GetScreenSize()
draw.Text(sw/2, 20, "Vector", {1,1,1,1}, 16)
```

### draw.Window → width, height

Renders a floating info window at (x, y). Returns the computed pixel dimensions. Shows a dimmed placeholder when items is empty.

**Signature**
```
function draw.Window(x, y: number, id: string, title?: string, items?: string[]) → number, number
```

**Parameters**

- `id` — string
- `title` — string
- `items` — string[]

**Example**
```lua
local target = entity.GetLocalPlayer()
local info = {
  "HP: " .. target.Health,
  "Speed: " .. target.WalkSpeed,
  "State: " .. target.StateName,
}
draw.Window(20, 20, "info", target.Name, info)
```

### Image Functions

Images are loaded asynchronously from HTTP/HTTPS URLs. LoadImage returns a handle immediately; use ImageLoaded to check when it is ready. The tint channels for draw.Image use [0–255] integer range, unlike every other color parameter in this API which uses [0.0–1.0].

**Functions**

- `draw.LoadImage(url) → handle` — Starts async download. Deduplicates by URL
- `draw.Image(handle, x, y, w, h, r?, g?, b?, a?)` — Draws image. Tint default: 255,255,255,255
- `draw.ImageLoaded(handle) → bool` — True when fully on GPU
- `draw.ImageFailed(handle) → bool` — True if download/decode failed
- `draw.ImageSize(handle) → w, h` — Native pixel dimensions, or nil if not loaded
- `draw.FreeImage(handle)` — Releases GPU texture, invalidates handle

**Example**
```lua
local img = draw.LoadImage("https://example.com/icon.png")
if draw.ImageLoaded(img) then
  local iw, ih = draw.ImageSize(img)
  draw.Image(img, 100, 100, iw, ih)
  draw.Image(img, 100, 100, iw, ih, 255,255,255,128)
elseif draw.ImageFailed(img) then
  draw.Text(100, 100, "load failed", {1,0,0,1})
end
```

---

## Utility (`utility.*`)

### Screen Functions

Core screen-space query functions. WorldToScreen accepts either a Vector3 object or three separate numbers. The on_screen boolean is strict — (0,0) counts as off-screen.

**Functions**

- `utility.WorldToScreen(vec3) → x, y, on_screen` — Accepts a Vector3 object
- `utility.WorldToScreen(x, y, z) → x, y, on_screen` — Accepts three separate numbers
- `utility.GetScreenSize() → w, h` — Overlay render dimensions
- `utility.GetMousePos() → x, y` — Absolute cursor position

**Example**
```lua
local sw, sh = utility.GetScreenSize()
local mx, my = utility.GetMousePos()

local pos = entity.GetLocalPlayer().Position
if pos then
  local sx, sy, ok = utility.WorldToScreen(pos)
  if ok then
    draw.Text(sx, sy, "local player", {1,1,1,1})
  end
end
```

### Timing Functions

Frame timing and monotonic clocks. GetDeltaTime is clamped to [0.0001, 0.1] so extremely fast or frozen frames don't produce garbage values. GetFPS is a 60-frame rolling average initialized to 60.

- `utility.GetDeltaTime()` — number
- `utility.GetFPS()` — number
- `utility.GetTime()` — number
- `utility.GetTickCount()` — number

**Example**
```lua
local dt  = utility.GetDeltaTime()
local fps = utility.GetFPS()
print(string.format("FPS: %.1f  dt: %.4f", fps, dt))
local last_fire = 0
local function fire()
  if utility.GetTime() - last_fire < 0.5 then return end
  last_fire = utility.GetTime()
end
```

### utility.IsValid → boolean

Returns true if an instance userdata is live and has a valid address. Safe to call on stale or nil instances.

**Signature**
```
function utility.IsValid(instance) → boolean
```

**Example**
```lua
local char = entity.GetLocalPlayer().Character
if utility.IsValid(char) then
  print(char.Name)
end
```

### utility.OnKey → integer

Registers a callback that fires based on a virtual key's state. Returns an ID used to remove or query the binding later. Callback exceptions are caught and logged without crashing the engine.

**Signature**
```
function utility.OnKey(vk_code: integer, mode: string, callback: function) → integer
```

**Mode Behavior**

- `"hold"` — On press and on release
- `"always"` — Every frame
- `"toggle"` — On press only

**Related Functions**

- `utility.RemoveKey(id)` — Removes binding, unreferences callback for GC
- `utility.ClearKeys()` — Removes all bindings, resets ID counter
- `utility.IsKeyToggled(id) → boolean` — Current toggle state. Always false for hold/always modes

**Example**
```lua
local aim_id = utility.OnKey(0x46, "toggle", function(on)
  menu.Set("aim_enabled", on)
end)
utility.OnKey(0xA0, "hold", function(held)
  entity.GetLocalPlayer().WalkSpeed = held and 60 or 16
end)
print(utility.IsKeyToggled(aim_id))
```

### utility.HttpGet / LoadUrl

HTTP fetch functions. HTTPS certificate checks are disabled. LoadUrl fetches a URL and executes the response as Lua code.

**Variants**

- `utility.HttpGet(url) → body, status` — Success: response body string + HTTP status code. Failure: nil, error_string
- `utility.LoadUrl(url) → true / false, err` — Success: true. Failure: false, error_string

**Example**
```lua
local body, status = utility.HttpGet("https://example.com/data.json")
if body then
  print("HTTP", status, "#bytes:", #body)
else
  print("error:", status)
end
local ok, err = utility.LoadUrl("https://example.com/module.lua")
if not ok then print(err) end
```

### Mouse Input

OS-level mouse simulation. Affects whichever window is in the foreground.

**Functions**

- `utility.MouseClick(button?, x?, y?)` — Full click at current or given position. button: "left" (default), "right", "middle"
- `utility.MouseMove(x, y, absolute?)` — Move by pixel delta (default) or to absolute coords when absolute=true
- `utility.MouseScroll(amount)` — Scroll wheel. Positive = up. Each unit = one standard notch (WHEEL_DELTA=120)

**Example**
```lua
utility.MouseClick()
utility.MouseClick("right", 960, 540)
utility.MouseMove(10, -5)
utility.MouseScroll(2)
```

### Keyboard Input

OS-level keyboard simulation. Works with games that filter standard virtual-key events. TypeString supports full UTF-8.

**Functions**

- `utility.KeyPress(vk, hold_ms?)` — Down → sleep → up. Releases Lua mutex during sleep. Default hold: 30ms
- `utility.KeyDown(vk)` — Key-down event only
- `utility.KeyUp(vk)` — Key-up event only
- `utility.TypeString(text, delay_ms?)` — Types text char-by-char with Unicode events. Default delay: 5ms per char

**Example**
```lua
utility.KeyPress(0x0D)
utility.KeyDown(0x20)
sleep(500)
utility.KeyUp(0x20)
utility.KeyPress(0x0D)
utility.TypeString("hello!")
utility.KeyPress(0x0D)
```

---

## Raycast (`raycast.*`)

### raycast.IsReady → boolean

Returns true once the visibility cache is ready. Poll before using other raycast functions if accuracy matters.

**Signature**
```
function raycast.IsReady() → boolean
```

**Example**
```lua
if not raycast.IsReady() then
  print("cache not ready yet")
  return
end
```

### raycast.IsPlayerVisible → boolean

Returns true if any part of the player's character is visible from the local camera. Returns true (fail-open) while the cache isn't ready. Accepts an instance or a raw address.

**Signature**
```
function raycast.IsPlayerVisible(player: instance | integer) → boolean
```

**Example**
```lua
for _, p in ipairs(entity.GetPlayers()) do
  if not p.IsLocal and raycast.IsPlayerVisible(p.Character) then
    print(p.Name, "is visible")
  end
end
```

### raycast.IsVisible → boolean

Returns true if the line segment from from to to is unobstructed. Throws on bad argument types. Accepts Vector3 objects or six separate numbers.

**Signature**
```
function raycast.IsVisible(from: Vector3, to: Vector3) → boolean
```

**Overloads**

- `raycast.IsVisible(vec3_from, vec3_to)` — Two Vector3 objects
- `raycast.IsVisible(x1,y1,z1, x2,y2,z2)` — Six separate numbers

**Example**
```lua
local lp = entity.GetLocalPlayer()
local cam = lp.HeadPosition

for _, p in ipairs(entity.GetPlayers()) do
  if not p.IsLocal and p.HeadPosition then
    local clear = raycast.IsVisible(cam, p.HeadPosition)
    print(p.Name, clear and "visible" or "behind wall")
  end
end
```

### raycast.Cast → hit, pos, dist, inst, isTerrain

Full raycast. Always returns 5 values — returns all-false/nil/zero on miss.

**Signature**
```
function raycast.Cast(from: Vector3, to: Vector3) → boolean, Vector3?, number, instance?, boolean
```

**Return Values**

- `1` — true
- `2` — Vector3
- `3` — number
- `4` — instance
- `5` — boolean

**Example**
```lua
local from = entity.GetLocalPlayer().HeadPosition
local to = from + lp.LookVector * 500

local hit, pos, dist, inst, terrain = raycast.Cast(from, to)
if hit then
  print(string.format("hit %s at %.1f studs%s",
    inst.Name, dist, terrain and " (terrain)" or ""))
end
```

### Silent Aim — Enable / Disable / Status

Enables or disables silent aim. When active, SetSilentTarget/TrackSilentTarget redirect hit detection toward your target. Must be enabled before Set/Track have any effect.

**Functions**

- `raycast.EnableSilentHook() → bool` — true on success. Call before Set/Track
- `raycast.DisableSilentHook()` — Disables silent aim
- `raycast.IsSilentHookActive() → bool` — True if active

**Example**
```lua
local ok = raycast.EnableSilentHook()
print("enabled:", ok)
print("active:", raycast.IsSilentHookActive())
raycast.DisableSilentHook()
```

### raycast.SetSilentTarget / ClearSilentTarget

Sets the ray origin and direction for this frame. Call each frame from OnFrame. Requires EnableSilentHook first. Accepts Vector3 only.

**Functions**

- `raycast.SetSilentTarget(origin, direction)` — Sets the ray origin and direction. Call each frame
- `raycast.ClearSilentTarget()` — Clears the override

**Example**
```lua
raycast.EnableSilentHook()
local lp = entity.GetLocalPlayer()
local target = entity.GetPlayers()[1]

if target and target.HeadPosition then
  local origin = lp.HeadPosition
  local dir    = target.HeadPosition - origin
  raycast.SetSilentTarget(origin, dir)
else
  raycast.ClearSilentTarget()
end
```

### raycast.TrackSilentTarget / StopSilentTracking

Like SetSilentTarget but runs in the background. Fires the override while the given key is held. Update the origin and direction each frame. StopSilentTracking clears the override and pauses tracking.

**Functions**

- `raycast.TrackSilentTarget(origin, dir, key) → true` — Fires override while key is held. Update each frame
- `raycast.StopSilentTracking() → true` — Clears the override and pauses tracking

**Example**
```lua
raycast.EnableSilentHook()
local lp = entity.GetLocalPlayer()
local target = entity.GetPlayers()[1]

if target and target.HeadPosition then
  local origin = lp.HeadPosition
  local dir    = target.HeadPosition - origin
  raycast.TrackSilentTarget(origin, dir, 0x01)
end
raycast.StopSilentTracking()
```

---

## FFlag (`fflag.*`)

### fflag.GetValue → integer | nil

Returns the current value of a flag by name. Returns nil if not found or the scan hasn't completed.

**Signature**
```
function fflag.GetValue(name: string) → integer | nil
```

**Parameters**

- `name` — string

**Example**
```lua
local val = fflag.GetValue("FFlagDebugGraphicsReporter")
if val then
  print("value:", val)
else
  print("not found or not yet scanned")
end
```

### fflag.SetValue → boolean

Sets a flag's value by name. Returns true on success, false if not found.

**Signature**
```
function fflag.SetValue(name: string, value: integer) → boolean
```

**Parameters**

- `name` — string
- `value` — integer

**Example**
```lua
local ok = fflag.SetValue("FFlagDebugGraphicsReporter", 1)
print(ok)
```

### fflag.ResetValue → boolean

Resets a flag to its original scanned value. Returns true on success, false if not found.

**Signature**
```
function fflag.ResetValue(name: string) → boolean
```

**Parameters**

- `name` — string

**Example**
```lua
fflag.SetValue("FFlagDebugGraphicsReporter", 999)
fflag.ResetValue("FFlagDebugGraphicsReporter")
```

### fflag.ResetAll → void

Restores every flag in the cache to its original scanned value. Returns nothing.

**Signature**
```
function fflag.ResetAll() → void
```

**Example**
```lua
fflag.ResetAll()
```

### fflag.GetAll → table

Returns an array of all flags in the cache. Empty if the scan hasn't completed.

**Signature**
```
function fflag.GetAll() → table
```

**Entry fields**

- `name` — string
- `value` — integer
- `original` — integer
- `changed` — boolean
- `address` — integer

**Example**
```lua
local flags = fflag.GetAll()
print("total flags:", #flags)

for _, f in ipairs(flags) do
  if f.changed then
    print(f.name, f.original, "→", f.value)
  end
end
```

### fflag.Find → table

Case-insensitive substring search across flag names. Returns matching entries. Each entry has index instead of address.

**Signature**
```
function fflag.Find(pattern: string) → table
```

**Parameters**

- `pattern` — string

**Entry fields**

- `name` — string
- `value` — integer
- `original` — integer
- `changed` — boolean
- `index` — integer

**Example**
```lua
local results = fflag.Find("graphics")
print(#results, "flags match")

for _, f in ipairs(results) do
  print(f.name, f.value)
end
```

### fflag.GetCount → integer

Returns the number of flags in the cache.

**Signature**
```
function fflag.GetCount() → integer
```

**Example**
```lua
if fflag.IsScanned() then
  print(fflag.GetCount(), "flags loaded")
end
```

### fflag.IsScanned → boolean

Returns true once the flag scan is complete.

**Signature**
```
function fflag.IsScanned() → boolean
```

**Example**
```lua
while not fflag.IsScanned() do
  sleep(0.1)
end

print(fflag.GetCount(), "flags ready")
```

---

## Memory (`memory.*`)

### memory.Read → integer | number | boolean | nil

Reads from address and returns a Lua value whose type depends on the type string. Integer types return an integer, floating-point types return a number, bool/boolean returns a boolean. Returns nil if address is 0. Throws if type is not recognised.

**Signature**
```
function memory.Read(address: integer, type: string) → integer | number | boolean | nil
```

**Parameters**

- `address` — integer
- `type` — string

**Valid type strings**

- `uint8, u8, byte` — 1 byte
- `uint16, u16, word, ushort` — 2 bytes
- `uint32, u32, dword, uint` — 4 bytes
- `uint64, u64, qword, ptr, pointer, uintptr` — 8 bytes
- `int8, i8, sbyte` — 1 byte
- `int16, i16, short` — 2 bytes
- `int32, i32, int` — 4 bytes
- `int64, i64, long` — 8 bytes
- `float, f32, single` — 4 bytes
- `double, f64` — 8 bytes
- `bool, boolean` — 1 byte

**Example**
```lua
local base = memory.base
local hp = memory.Read(base + 0x1A4, "float")
print("hp:", hp)
local ptr = memory.Read(base + 0x3B8C20, "ptr")
local val = memory.Read(ptr + 0x50, "int32")
print("val:", val)
```

### memory.Write → boolean

Writes value to address using the given type. Returns true on success, false if address is 0. Throws if type is not recognised. The same type aliases as Read are accepted.

**Signature**
```
function memory.Write(address: integer, type: string, value) → boolean
```

**Parameters**

- `address` — integer
- `type` — string
- `value` — integer | number | boolean

**Example**
```lua
local addr = memory.Read(memory.base + 0x3B8C20, "ptr") + 0x1A4

memory.Write(addr, "float", 9999.0)
memory.Write(addr, "bool", true)
memory.Write(addr, "uint32", 0xFF)
```

### memory.ReadBuffer → string | nil, string

Reads size raw bytes starting at address and returns them as a Lua binary string. On error (address 0, size ≤ 0, or size > 65536) returns nil followed by an error message string.

**Signature**
```
function memory.ReadBuffer(address: integer, size: integer) → string | (nil, string)
```

**Parameters**

- `address` — integer
- `size` — integer

**Example**
```lua
local buf, err = memory.ReadBuffer(memory.base, 16)
if not buf then
  print("error:", err)
else
  for i = 1, #buf do
    io.write(string.format("%02X ", buf:byte(i)))
  end
end
```

### memory.ReadString → string

Reads a null-terminated C string from address, up to max_len bytes. max_len defaults to 256 and is clamped to a maximum of 4096. Returns an empty string if address is 0.

**Signature**
```
function memory.ReadString(address: integer [, max_len: integer]) → string
```

**Parameters**

- `address` — integer
- `max_len (optional)` — integer

**Example**
```lua
local name_ptr = memory.Read(memory.base + 0x1234, "ptr")
local name     = memory.ReadString(name_ptr)
print(name)
local long = memory.ReadString(name_ptr, 1024)
```

### memory.WriteString → boolean

Writes a Lua string to address. max_len defaults to len(str) + 1 (the exact byte count including null terminator). Returns false if address is 0 or the string is empty.

**Signature**
```
function memory.WriteString(address: integer, str: string [, max_len: integer]) → boolean
```

**Parameters**

- `address` — integer
- `str` — string
- `max_len (optional)` — integer

**Example**
```lua
local dest = memory.Read(memory.base + 0x1234, "ptr")
local ok   = memory.WriteString(dest, "hello")
print(ok)
```

### memory.GetBase → integer

Returns the base address of the Roblox module. The field memory.base holds the same value and is preferred for frequent reads.

**Signature**
```
function memory.GetBase() → integer
```

**Example**
```lua
local base = memory.base
local base2 = memory.GetBase()

print(string.format("base: 0x%X", base))
```

---

## Camera (`camera.*`)

### camera.GetPosition → Vector3

Returns the camera's current world-space position as a Vector3.

**Signature**
```
function camera.GetPosition() → Vector3
```

**Example**
```lua
local pos = camera.GetPosition()
print(string.format("%.2f, %.2f, %.2f", pos.X, pos.Y, pos.Z))
```

### camera.GetLookVector → Vector3

Returns the normalized forward direction of the camera as a Vector3.

**Signature**
```
function camera.GetLookVector() → Vector3
```

**Example**
```lua
local look = camera.GetLookVector()
print(string.format("look: %.3f, %.3f, %.3f", look.X, look.Y, look.Z))
```

### camera.LookAt → boolean

Orients the camera toward a target. Accepts either an Instance or three coordinate numbers. An optional smooth value greater than 1 enables interpolation.

**Variants**

- `camera.LookAt(target [, smooth])` — Orient toward an Instance's position
- `camera.LookAt(x, y, z [, smooth])` — Orient toward world-space coordinates

**Example**
```lua
local hrp = game.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
camera.LookAt(hrp)
camera.LookAt(100, 10, 200, 5)
```

### camera.GetFov → number

Returns the current camera field of view in degrees.

**Signature**
```
function camera.GetFov() → number
```

**Example**
```lua
print("FOV:", camera.GetFov())
```

### camera.SetFov → boolean

Sets the camera field of view in degrees. Returns true on success.

**Signature**
```
function camera.SetFov(fov: number) → boolean
```

**Example**
```lua
camera.SetFov(90)
```

### camera.TrackTarget → boolean

Starts a tracking thread that locks the camera onto a target while key is held. Requires both the target part and its Humanoid to be passed separately. The optional maxDist stops tracking if the target exceeds that distance.

**Signature**
```
function camera.TrackTarget(part: Instance, humanoid: Instance, key: integer [, maxDist: number]) → boolean
```

**Parameters**

- `part` — Instance
- `humanoid` — Instance
- `key` — integer
- `maxDist (optional)` — number

**Example**
```lua
local char = game.Players:GetChildren()[2].Character
local hrp = char:FindFirstChild("HumanoidRootPart")
local hum = char:FindFirstChildOfClass("Humanoid")

camera.TrackTarget(hrp, hum, 0x46, 500)
```

### camera.StopTracking → boolean

Stops any active camera tracking thread.

**Signature**
```
function camera.StopTracking() → boolean
```

**Example**
```lua
camera.StopTracking()
```

---

## Input (`input.*`)

### input.MoveMouse → void

Moves the mouse cursor by the given pixel delta.

**Signature**
```
function input.MoveMouse(dx: number, dy: number) → void
```

**Example**
```lua
input.MoveMouse(10, -5)
```

### input.IsKeyDown → boolean

Returns true if the given virtual key is currently held down.

**Signature**
```
function input.IsKeyDown(vk: integer) → boolean
```

**Example**
```lua
if input.IsKeyDown(0x46) then
  print("F held")
end
```

### input.GetScreenCenter → number, number

Returns the center of the overlay window in screen coordinates as two separate numbers.

**Signature**
```
function input.GetScreenCenter() → number, number
```

**Example**
```lua
local cx, cy = input.GetScreenCenter()
print(cx, cy)
```

### input.GetMousePosition → number, number

Returns the cursor position mapped to overlay client coordinates as two separate numbers.

**Signature**
```
function input.GetMousePosition() → number, number
```

**Example**
```lua
local mx, my = input.GetMousePosition()
print(mx, my)
```

---

## World (`workspace.* · lighting.* · terrain.*`)

### workspace.GetGravity / SetGravity

Reads or sets the current workspace gravity.

**Example**
```lua
print(workspace.GetGravity())
workspace.SetGravity(0)
```

### workspace.GetTickRate / SetTickRate

Reads or sets the physics simulation tick rate.

**Example**
```lua
print(workspace.GetTickRate())
workspace.SetTickRate(240)
```

### lighting.GetBrightness / SetBrightness

Reads or sets scene brightness.

**Example**
```lua
print(lighting.GetBrightness())
lighting.SetBrightness(2)
```

### lighting.GetExposure / SetExposure

Reads or sets camera exposure.

**Example**
```lua
lighting.SetExposure(0)
```

### lighting.Fog functions

Reads or sets the fog start and end distances. Setting both to the same large value effectively removes fog.

**Functions**

- `lighting.GetFogStart() → number` — Fog start distance
- `lighting.SetFogStart(v)` — Sets fog start distance
- `lighting.GetFogEnd() → number` — Fog end distance
- `lighting.SetFogEnd(v)` — Sets fog end distance

**Example**
```lua
lighting.SetFogStart(100000)
lighting.SetFogEnd(100000)
```

### lighting.DiffuseScale / SpecularScale

Reads or sets the diffuse and specular lighting scale multipliers.

**Example**
```lua
lighting.SetDiffuseScale(0)
lighting.SetSpecularScale(0)
```

### lighting.Ambient / OutdoorAmbient

Reads or sets ambient and outdoor ambient light levels.

**Example**
```lua
lighting.SetAmbient(1)
lighting.SetOutdoorAmbient(1)
```

### lighting.GetFogColor / SetFogColor

Reads or sets the fog color as a packed integer value.

**Example**
```lua
print(string.format("0x%X", lighting.GetFogColor()))
lighting.SetFogColor(0x00FFFFFF)
```

### terrain.GetGrassLength / SetGrassLength

Reads or sets the terrain grass blade length.

**Example**
```lua
terrain.SetGrassLength(0)
```

### terrain.Water properties

Reads or sets water transparency and reflectance values.

**Functions**

- `terrain.GetWaterTransparency() → number` — Water transparency [0..1]
- `terrain.SetWaterTransparency(v)` — Sets water transparency
- `terrain.GetWaterReflectance() → number` — Water reflectance [0..1]
- `terrain.SetWaterReflectance(v)` — Sets water reflectance

**Example**
```lua
terrain.SetWaterTransparency(1)
terrain.SetWaterReflectance(0)
```

### terrain.Wave properties

Reads or sets water wave size (amplitude) and speed.

**Example**
```lua
terrain.SetWaterWaveSize(0)
terrain.SetWaterWaveSpeed(0)
```

### terrain.GetWaterColor / SetWaterColor

Reads or sets the water color as a packed integer value.

**Example**
```lua
terrain.SetWaterColor(0x0000FF80)
```

---

## GC (`bare globals`)

### getgc → integer

Pre-warms the internal node cache for the given key(s) and returns how many cached nodes were found. Call this before a tight loop to pay the scan cost upfront — applygc auto-scans on cache miss anyway.

**Variants**

- `getgc(key: string) → integer` — Pre-warm for a single key
- `getgc(keys: string[]) → integer` — Pre-warm for an array of key names

**Example**
```lua
local count = getgc({"WalkSpeed", "JumpPower"})
print(count, "nodes found")
```

### applygc → integer

Patches cached Lua table nodes matching the given key(s). Uses an internal throttle — safe to call every OnFrame. Returns the number of nodes patched.

**Variants**

- `applygc(key, value) → integer` — Patch a single key
- `applygc({key=val, ...}) → integer` — Patch multiple keys at once

**Example**
```lua
OnFrame = function()
  applygc("WalkSpeed", 100)
  applygc({JumpPower = 200, MaxSlopeAngle = 89})
end
```

### setgc → number

Performs a full GC walk and patches every Lua table that contains the given key(s). More thorough than applygc but significantly slower — use for one-shot patches, not per-frame loops.

**Variants**

- `setgc(key, value) → number` — Patch a single key across all tables
- `setgc({key=val, ...}) → number` — Patch multiple keys across all tables

**Example**
```lua
local n = setgc("WalkSpeed", 100)
print(n, "tables patched")
```

### dumpgc → integer

Dumps GC table contents. Without a key list, does a full walk and dumps every string-keyed value found (discovery mode). With a key list, does a targeted scan for those keys only. An optional file path writes the output to disk.

**Variants**

- `dumpgc([filepath]) → integer` — Full walk — dump all string-keyed entries
- `dumpgc(keys, [filepath]) → integer` — Targeted — dump only the listed keys

**Example**
```lua
dumpgc("C:\\dump.txt")
local n = dumpgc({"WalkSpeed", "JumpPower"}, "C:\\keys.txt")
print(n, "entries dumped")
```

### refreshgc → integer

Validates the internal VM cache and triggers a rescan if stale. Returns the current VM count.

**Signature**
```
function refreshgc() → integer
```

**Example**
```lua
local vms = refreshgc()
print(vms, "VMs found")
```

### findstr → table

Scans for a string in the Lua VM and returns an array of matching addresses. Expensive — use getgc/applygc for repeated access.

**Signature**
```
function findstr(name: string) → integer[]
```

**Example**
```lua
local addrs = findstr("WalkSpeed")
print(#addrs, "hits")
for _, a in ipairs(addrs) do
  print(string.format("0x%X", a))
end
```

---

## Notify (`notify.*`)

### notify.Success → void

Shows a green success toast.

**Signature**
```
function notify.Success(message: string [, subtitle: string [, duration: number]]) → void
```

**Parameters**

- `message` — string
- `subtitle (optional)` — string
- `duration (optional)` — number

**Example**
```lua
notify.Success("Script loaded")
notify.Warning("Low memory", "consider restarting")
notify.Error("Connection failed", "check your settings", 5)
```

### notify.Warning → void

Shows a yellow warning toast. Same signature as notify.Success.

**Signature**
```
function notify.Warning(message: string [, subtitle: string [, duration: number]]) → void
```

### notify.Error → void

Shows a red error toast. Same signature as notify.Success.

**Signature**
```
function notify.Error(message: string [, subtitle: string [, duration: number]]) → void
```

---

## Instance (`instance.*`)

### instance.New → instance

Creates a new Roblox instance of the given class and parents it. Throws on failure.

**Signature**
```
function instance.New(className: string, parent: Instance) → instance
```

**Parameters**

- `className` — string
- `parent` — Instance

**Example**
```lua
thread.Create(function()
  for _, ply in ipairs(entity.GetPlayers()) do
    local ok, char = pcall(function() return ply.Character end)
    if ok and char and not char:FindFirstChildOfClass("Highlight") then
      instance.New("Highlight", char)
    end
  end
end, 500)
```

### instance.Destroy → void

Destroys an instance and removes it from the hierarchy.

**Signature**
```
function instance.Destroy(inst: Instance) → void
```

**Example**
```lua
local part = instance.New("Part", game.Workspace)
instance.Destroy(part)
```

### instance.IsReady → boolean

Returns true when the instance creation system has finished initializing and is safe to use.

**Signature**
```
function instance.IsReady() → boolean
```

**Example**
```lua
if instance.IsReady() then
  local p = instance.New("Part", game.Workspace)
end
```

---

## Exploits (`exploits.*`)

### exploits.ApplyChamsToInstance → boolean

Applies engine chams to a single renderable part. Only works on leaf geometry instances (Part, MeshPart, WedgePart, etc.) — passing a Model or Character returns false. To cham a whole character, iterate its descendants and filter by class. Also accepts a raw integer memory address in place of an Instance userdata.

**Signature**
```
function exploits.ApplyChamsToInstance(inst: Instance) → boolean
```

**Accepted part classes**

- `Part` — Standard block / sphere / cylinder
- `MeshPart` — Imported mesh — most character limbs use this
- `WedgePart` — Wedge geometry
- `CornerWedgePart` — Corner-wedge geometry
- `TrussPart` — Structural truss
- `UnionOperation` — CSG union

**Example**
```lua
local PART_CLASSES = {
  Part=true, MeshPart=true, WedgePart=true,
  CornerWedgePart=true, TrussPart=true, UnionOperation=true
}
local applied = {}

local function cham_char(char)
  for _, part in ipairs(char:GetDescendants()) do
    if PART_CLASSES[part.ClassName] and not applied[part.Address] then
      if exploits.ApplyChamsToInstance(part) then
        applied[part.Address] = true
      end
    end
  end
end

exploits.SetChamsMode(2)
exploits.SetChamsColor(2)

local char = game.LocalPlayer.Character
if char then cham_char(char) end
```

### exploits.RevertChams → void

Removes all active chams applied via ApplyChamsToInstance.

**Signature**
```
function exploits.RevertChams() → void
```

**Example**
```lua
exploits.RevertChams()
```

### exploits.GetChamsMode / SetChamsMode

Reads or sets the chams rendering mode. Value is clamped to 0–3.

**Variants**

- `exploits.GetChamsMode() → integer` — Returns current mode (0–3)
- `exploits.SetChamsMode(mode) → void` — Sets mode, clamped to [0, 3]

**Example**
```lua
print(exploits.GetChamsMode())
exploits.SetChamsMode(1)
```

### exploits.GetChamsColor / SetChamsColor

Reads or sets the chams color preset. Value is clamped to 0–6.

**Variants**

- `exploits.GetChamsColor() → integer` — Returns current color preset (0–6)
- `exploits.SetChamsColor(color) → void` — Sets color preset, clamped to [0, 6]

**Example**
```lua
print(exploits.GetChamsColor())
exploits.SetChamsColor(2)
```
