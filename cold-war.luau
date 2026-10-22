-- Cold War tools v1.0.0. Based on the user-supplied Sneekys script.
-- Live compatibility is unverified. No external UI or Drawing dependency.
-- Silent aim expects ClientFire's original (arg4=origin, arg5=directions) ABI.
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local env = getgenv and getgenv() or shared
local KEY = "SDH_ColdWar_v1"
local previous = env[KEY]
local settings = previous and previous.settings or {
    silent = false, esp = false, radius = true, fov = 180,
    head = false, team = true, distance = 2000,
}
if previous and previous.unload then previous.unload() end
settings.silent = false -- every execution requires an explicit opt-in
local state = {settings = settings, active = true, links = {}, visuals = {},
    bridges = previous and previous.bridges or {}, calls = 0, redirects = 0,
    message = "Not attached. Equip a gun, then Attach / retry.", hooks = {}}
env[KEY] = state
local accent = Color3.fromRGB(111, 207, 185)
local red = Color3.fromRGB(243, 123, 131)
local muted = Color3.fromRGB(156, 166, 184)
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(state.links, c)
    return c
end
local function make(class, props, parent)
    local object = Instance.new(class)
    for k, v in pairs(props or {}) do object[k] = v end
    object.Parent = parent
    return object
end
local gui = make("ScreenGui", {Name = "ColdWarTools", ResetOnSpawn = false,
    IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
local panel = make("Frame", {Size = UDim2.fromOffset(350, 540), Position = UDim2.fromOffset(24, 64),
    BackgroundColor3 = Color3.fromRGB(19, 23, 32), BorderSizePixel = 0, Active = true}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 14)}, panel)
make("UIStroke", {Color = Color3.fromRGB(51, 61, 77), Thickness = 1}, panel)
local function text(parent, value, size, color)
    return make("TextLabel", {BackgroundTransparency = 1, Text = value,
        Font = Enum.Font.Gotham, TextSize = size or 13, TextColor3 = color or Color3.fromRGB(233, 238, 245),
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, 0, 0, 24)}, parent)
end
local header = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -32, 0, 60),
    Position = UDim2.fromOffset(16, 8), Active = true}, panel)
local title = text(header, "COLD WAR", 21)
title.Font = Enum.Font.GothamBold
title.Position = UDim2.fromOffset(0, 5)
local subtitle = text(header, "TOOLS  /  v1.0  /  Right Shift: hide", 11, muted)
subtitle.Position = UDim2.fromOffset(0, 31)
local body = make("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0,
    Position = UDim2.fromOffset(16, 72), Size = UDim2.new(1, -32, 1, -86),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 3,
    ScrollBarImageColor3 = accent}, panel)
make("UIListLayout", {Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder}, body)
local order = 0
local function row(class, height, props)
    order = order + 1
    props = props or {}
    props.Size = UDim2.new(1, -5, 0, height)
    props.LayoutOrder = order
    return make(class, props, body)
end
local function section(label)
    local t = row("TextLabel", 20, {BackgroundTransparency = 1, Text = label,
        TextColor3 = muted, Font = Enum.Font.GothamBold, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left})
    return t
end
local function button(label, callback)
    local b = row("TextButton", 36, {Text = label, BackgroundColor3 = Color3.fromRGB(32, 40, 53),
        TextColor3 = Color3.fromRGB(229, 235, 244), Font = Enum.Font.GothamMedium,
        TextSize = 12, BorderSizePixel = 0, AutoButtonColor = true})
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, b)
    connect(b.Activated, callback)
    return b
end
local function toggle(label, key)
    local b
    local function refresh()
        b.Text = label .. "    " .. (settings[key] and "ON" or "OFF")
        b.TextColor3 = settings[key] and accent or muted
    end
    b = button("", function() settings[key] = not settings[key]; refresh() end)
    refresh()
    return refresh
end
local status = row("TextLabel", 96, {BackgroundColor3 = Color3.fromRGB(26, 33, 45),
    Text = state.message, TextColor3 = muted, Font = Enum.Font.Gotham, TextSize = 12,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top})
make("UICorner", {CornerRadius = UDim.new(0, 8)}, status)
make("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
    PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, status)
section("TARGETING")
local refreshSilent = toggle("Silent aim", "silent")
toggle("Prefer head", "head")
toggle("Team filter", "team")
toggle("Show targeting radius", "radius")
local fovButton
local radii = {80, 120, 180, 250, 350, 500}
fovButton = button("Radius: " .. settings.fov .. " px  /  click to change", function()
    local nextRadius = radii[1]
    for i, v in ipairs(radii) do if v == settings.fov then nextRadius = radii[i % #radii + 1]; break end end
    settings.fov = nextRadius
    fovButton.Text = "Radius: " .. nextRadius .. " px  /  click to change"
end)
section("VISUALS")
local refreshESP = toggle("Enemy ESP", "esp")
local distanceButton
distanceButton = button("ESP range: " .. settings.distance .. " studs", function()
    settings.distance = settings.distance == 2000 and 500 or settings.distance == 500 and 1000 or 2000
    distanceButton.Text = "ESP range: " .. settings.distance .. " studs"
end)
section("WEAPON ADAPTER")
local exportButton
local exports, moduleValue, selected = {}, nil, 1
exportButton = button("Export: not loaded", function()
    if #exports > 0 then selected = selected % #exports + 1; exportButton.Text = "Export: " .. exports[selected].name end
end)
local circle = make("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.fromOffset(settings.fov * 2, settings.fov * 2), Visible = false}, gui)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, circle)
make("UIStroke", {Color = accent, Thickness = 1, Transparency = 0.3}, circle)
local reopen = make("TextButton", {Text = "CW", Size = UDim2.fromOffset(44, 36),
    Position = UDim2.fromOffset(12, 8), BackgroundColor3 = Color3.fromRGB(26, 33, 45),
    TextColor3 = accent, Font = Enum.Font.GothamBold, TextSize = 13, Visible = false}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, reopen)
connect(reopen.Activated, function() panel.Visible = true; reopen.Visible = false end)
local focused, dragging, dragOrigin, panelOrigin = true, false, nil, nil
connect(UIS.WindowFocusReleased, function() focused = false; dragging = false end)
connect(UIS.WindowFocused, function() focused = true end)
connect(UIS.InputBegan, function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift and not UIS:GetFocusedTextBox() then
        panel.Visible = not panel.Visible; reopen.Visible = not panel.Visible
    end
end)
connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = input; dragOrigin = input.Position; panelOrigin = panel.Position
    end
end)
connect(UIS.InputEnded, function(input)
    if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1) then dragging = false end
end)
local function clampPanel(x, y)
    local camera = workspace.CurrentCamera
    local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
    panel.Position = UDim2.fromOffset(math.clamp(x, 0, math.max(0, size.X - panel.AbsoluteSize.X)),
        math.clamp(y, 0, math.max(0, size.Y - panel.AbsoluteSize.Y)))
end
connect(UIS.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == dragging) then
        local delta = input.Position - dragOrigin
        clampPanel(panelOrigin.X.Offset + delta.X, panelOrigin.Y.Offset + delta.Y)
    end
end)
local function cursor(camera)
    if UIS.TouchEnabled and not UIS.MouseEnabled then return camera.ViewportSize / 2 end
    local inset = GuiService:GetGuiInset()
    return UIS:GetMouseLocation() - inset
end
local function paused()
    return not state.active or not focused or dragging or UIS:GetFocusedTextBox() ~= nil or GuiService.MenuIsOpen
end
local function eligible(other)
    if other == player then return nil end
    -- Two unassigned teams are not automatically treated as teammates.
    if settings.team and player.Team ~= nil and other.Team == player.Team and not player.Neutral and not other.Neutral then return nil end
    if other.Team and other.Team.Name == "Neutral" then return nil end
    local char = other.Character
    local human = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    if not char or not human or human.Health <= 0 or not root or not root:IsA("BasePart") or char:FindFirstChildOfClass("ForceField") then return nil end
    return char, human, root
end
local function visible(part, origin)
    if not part or not part:IsA("BasePart") then return false end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.IgnoreWater = true
    local excludes = {}
    if player.Character then table.insert(excludes, player.Character) end
    local ignore = workspace:FindFirstChild("Ignore")
    if ignore then table.insert(excludes, ignore) end
    rp.FilterDescendantsInstances = excludes
    local hit = workspace:Raycast(origin, part.Position - origin, rp)
    return not hit or hit.Instance:IsDescendantOf(part.Parent)
end
local function target(origin)
    if not settings.silent or paused() then return nil end
    local ownHuman = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not ownHuman or ownHuman.Health <= 0 then return nil end
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local best, bestDistance = nil, settings.fov
    local mouse = cursor(camera)
    for _, other in ipairs(Players:GetPlayers()) do
        local char = eligible(other)
        if char then
            local names = settings.head and {"Head", "UpperTorso", "Torso", "HumanoidRootPart"} or {"UpperTorso", "Torso", "HumanoidRootPart", "Head"}
            for _, name in ipairs(names) do
                local part = char:FindFirstChild(name)
                if part and part:IsA("BasePart") then
                    local p, onScreen = camera:WorldToViewportPoint(part.Position)
                    local distance = (Vector2.new(p.X, p.Y) - mouse).Magnitude
                    if onScreen and p.Z > 0 and distance < bestDistance and visible(part, origin) and visible(part, camera.CFrame.Position) then
                        best, bestDistance = part, distance
                        break
                    end
                end
            end
        end
    end
    -- Always return the actual position, including when raycasts hit nothing.
    return best and best.Position or nil
end
local function redirect(args)
    if typeof(args[4]) ~= "Vector3" or type(args[5]) ~= "table" or #args[5] == 0 then
        state.message = "Hook called; argument layout differs. Silent aim unchanged."
        return
    end
    for i = 1, #args[5] do
        if typeof(args[5][i]) ~= "Vector3" then
            state.message = "Hook called; direction data differs. Silent aim unchanged."
            return
        end
    end
    state.message = "Shot layout matched. Waiting for an eligible target."
    local position = target(args[4])
    if not position then return end
    local delta = position - args[4]
    if delta.Magnitude < 0.001 then return end
    local directions = {}
    for k, v in pairs(args[5]) do directions[k] = v end
    for i = 1, #directions do directions[i] = delta.Unit * directions[i].Magnitude end
    args[5] = directions
    state.redirects = state.redirects + 1
    state.message = "Direction redirected locally; server hit is not verified."
end
local attaching = false
local function attach()
    if attaching or not state.active then return end
    if type(hookfunction) ~= "function" then state.message = "Missing hookfunction. ESP remains available."; return end
    attaching = true
    state.message = "Loading ClientFire..."
    task.spawn(function()
        local ok, err = pcall(function()
            local scripts = player:FindFirstChild("PlayerScripts")
            local ballistics = scripts and scripts:FindFirstChild("BallisticsClient")
            local module = ballistics and ballistics:FindFirstChild("ClientFire")
            if not module or not module:IsA("ModuleScript") then error("BallisticsClient.ClientFire not found. Spawn / equip, then retry.", 0) end
            local cf = require(module)
            if not state.active then return end
            if type(cf) ~= "table" then error("ClientFire did not return a table.", 0) end
            if cf ~= moduleValue then
                moduleValue, exports, selected = cf, {}, 1
                for name, fn in pairs(cf) do
                    if type(fn) == "function" and type(name) == "string" then
                        table.insert(exports, {name = name, fn = fn})
                    end
                end
                table.sort(exports, function(a, b) return a.name < b.name end)
                local preferred, fallback, count = nil, nil, 0
                for i, entry in ipairs(exports) do
                    if string.lower(entry.name) == "firevolley" then preferred = i end
                    if string.lower(entry.name) ~= "fire" then fallback = i; count = count + 1 end
                end
                selected = preferred or (count == 1 and fallback) or 1
                if #exports == 0 then error("ClientFire has no named function exports.", 0) end
                exportButton.Text = "Export: " .. exports[selected].name
                if not preferred and count ~= 1 then
                    state.message = "Ambiguous exports. Choose an export above, then Attach again."
                    return
                end
            end
            local entry = exports[selected]
            if not entry then error("No export selected.", 0) end
            -- One bridge per function across reloads; unloaded controllers pass through.
            local bridge = state.bridges[entry.fn]
            if not bridge then
                bridge = {}
                local wrapper = function(...)
                    local args = table.pack(...)
                    local controller = bridge.controller
                    if controller and controller.active then
                        controller.calls = controller.calls + 1
                        local success, why = pcall(controller.redirect, args)
                        if not success then
                            controller.settings.silent = false
                            controller.message = "Redirect disabled: " .. tostring(why)
                        end
                    end
                    return bridge.original(table.unpack(args, 1, args.n))
                end
                if newcclosure then wrapper = newcclosure(wrapper) end
                bridge.original = hookfunction(entry.fn, wrapper)
                if type(bridge.original) ~= "function" then error("hookfunction did not return the original function.", 0) end
                state.bridges[entry.fn] = bridge
            end
            for _, oldBridge in pairs(state.bridges) do
                if oldBridge.controller == state then oldBridge.controller = nil end
            end
            bridge.controller = state
            state.message = "Attached: " .. entry.name .. ". Fire manually to verify callbacks."
        end)
        if not ok and state.active then state.message = tostring(err); warn("[Cold War] " .. state.message) end
        attaching = false
    end)
end
state.redirect = redirect
button("Attach / retry", attach)
button("Print diagnostics to F9", function()
    local executor = identifyexecutor and identifyexecutor() or "unknown"
    local names = {}
    for _, entry in ipairs(exports) do table.insert(names, entry.name) end
    print("[Cold War] v1.0 | place=" .. game.PlaceId .. " | executor=" .. tostring(executor))
    print("[Cold War] " .. state.message .. " | calls=" .. state.calls .. " | redirects=" .. state.redirects)
    print("[Cold War] exports=" .. table.concat(names, ", "))
end)
local function removeVisual(other)
    local v = state.visuals[other]
    if v then
        if v.highlight then v.highlight:Destroy() end
        if v.label then v.label:Destroy() end
        state.visuals[other] = nil
    end
end
local visualFolder = make("Folder", {Name = "SDH_ColdWar_ESP"}, workspace)
local function updateESP()
    local camera = workspace.CurrentCamera
    local seen, count = {}, 0
    if settings.esp and not paused() and camera then
        for _, other in ipairs(Players:GetPlayers()) do
            local char, human, root = eligible(other)
            if char and (root.Position - camera.CFrame.Position).Magnitude <= settings.distance then
                local v = state.visuals[other]
                if v and v.char ~= char then removeVisual(other); v = nil end
                if not v then
                    local h = make("Highlight", {Adornee = char, FillColor = red, OutlineColor = red,
                        FillTransparency = 0.82, OutlineTransparency = 0.15,
                        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, visualFolder)
                    v = {char = char, highlight = h}
                    state.visuals[other] = v -- retain partial creations for cleanup if a later step fails
                    local b = make("BillboardGui", {Adornee = root, Size = UDim2.fromOffset(220, 44),
                        StudsOffset = Vector3.new(0, 3.5, 0), AlwaysOnTop = true, MaxDistance = settings.distance}, gui)
                    v.label = b
                    local label = text(b, "", 12)
                    label.Size = UDim2.fromScale(1, 1)
                    label.TextXAlignment = Enum.TextXAlignment.Center
                    label.TextStrokeTransparency = 0.35
                    v.text = label
                end
                v.label.MaxDistance = settings.distance
                v.text.Text = string.format("%s\n%d HP  /  %d studs", other.DisplayName, math.max(0, math.floor(human.Health)),
                    math.floor((root.Position - camera.CFrame.Position).Magnitude))
                seen[other], count = true, count + 1
            end
        end
    end
    for other in pairs(state.visuals) do if not seen[other] then removeVisual(other) end end
    state.espCount = count
end
function state.unload()
    if not state.active then return end
    state.active, settings.silent = false, false
    for _, bridge in pairs(state.bridges) do if bridge.controller == state then bridge.controller = nil end end
    for _, c in ipairs(state.links) do c:Disconnect() end
    for other in pairs(state.visuals) do removeVisual(other) end
    visualFolder:Destroy()
    gui:Destroy()
end
button("Unload", state.unload)
section("Wall checks stay on. Live compatibility unverified.")
local elapsed = 0
connect(RunService.Heartbeat, function(dt)
    elapsed = elapsed + dt
    if elapsed < 0.2 then return end
    elapsed = 0
    local ok, why = pcall(updateESP)
    if not ok then
        settings.esp = false
        for other in pairs(state.visuals) do removeVisual(other) end
        state.message = "ESP paused: " .. tostring(why)
    end
    refreshSilent()
    refreshESP()
    status.Text = state.message .. string.format("\nCallbacks %d  /  Redirects %d  /  ESP %d", state.calls, state.redirects, state.espCount or 0)
end)
connect(RunService.RenderStepped, function()
    local camera = workspace.CurrentCamera
    circle.Visible = settings.radius and camera ~= nil and not paused()
    if camera then
        local pos = cursor(camera)
        circle.Position = UDim2.fromOffset(pos.X, pos.Y)
        circle.Size = UDim2.fromOffset(settings.fov * 2, settings.fov * 2)
        local height = math.max(180, math.min(650, camera.ViewportSize.Y - 32))
        local width = math.max(180, math.min(350, camera.ViewportSize.X - 16))
        panel.Size = UDim2.fromOffset(width, height)
        if not dragging then clampPanel(panel.Position.X.Offset, panel.Position.Y.Offset) end
    end
end)
connect(Players.PlayerRemoving, removeVisual)
print("[Cold War] v1.0 loaded. Silent aim and ESP are optional. Use Attach / retry; no live compatibility guarantee.")
