-- Centaura camera aim assist v2.1.0. Optional aligned autofire and enemy ESP.
-- Uses normal Roblox camera, input, GUI and raycast APIs; no gun-function hooks.
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
assert(player, "[Centaura] Run this on the local client")

local environment = shared
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then environment = value end
end
assert(type(environment) == "table", "[Centaura] Shared state is unavailable")

-- Old hooks cannot be undone safely by the new script.
if environment.sneeky_compat_status then
    warn("[Centaura] Rejoin first to clear the old silent-aim script, then run this loader again.")
    return
end

local KEY = "centaura_camera_assist"
local BINDING = "CentauraCameraAssistV2"
local PANEL_HEIGHT = 818
local FIRE_TOLERANCE = 8 -- Screen pixels from the camera crosshair.
local ESP_DISTANCE = 2000 -- Studs.
local clickFunction = type(mouse1click) == "function" and mouse1click or nil
local previous = environment[KEY]
local saved = type(previous) == "table" and previous.Config or {}
if type(saved) ~= "table" then saved = {} end
local function number(value, default, low, high)
    value = tonumber(value)
    if not value or value ~= value then value = default end
    return math.clamp(value, low, high)
end
local config = {
    Enabled = saved.Enabled ~= false,
    ShowRadius = saved.ShowRadius ~= false,
    Radius = number(saved.Radius, 300, 40, 650),
    Strength = number(saved.Strength, 12, 3, 30),
    AutoFire = saved.AutoFire == true and clickFunction ~= nil,
    FireRate = number(saved.FireRate, 5, 2, 10),
    ESP = saved.ESP == true,
}
if type(previous) == "table" and type(previous.Destroy) == "function" then
    previous.Destroy()
end

local connections = {}
local gui, panel, reopen, ring, scale, statusLabel, statusDetail, statusDot
local dragging, sliding
local alive, focused = true, true
local lockedPlayer
local espEntries, toggleRenderers = {}, {}
local espWorldFolder, espGuiFolder
local clock, nextFireAt, firePending, espElapsed = 0, 0, false, 0.2
local fireFocusReady = false
local api = {Config = config, Status = {cameraUpdates = 0, fireAttempts = 0,
    autoFireSupported = clickFunction ~= nil, espCount = 0, target = nil, message = "Starting"}}
local status = api.Status
local colors = {
    base = Color3.fromRGB(17, 21, 28), card = Color3.fromRGB(25, 30, 39),
    border = Color3.fromRGB(43, 51, 65), text = Color3.fromRGB(237, 242, 250),
    muted = Color3.fromRGB(146, 158, 179), accent = Color3.fromRGB(105, 219, 190),
    error = Color3.fromRGB(255, 159, 145),
    enemy = Color3.fromRGB(246, 130, 130),
}
local function removeESP(other)
    local entry = espEntries[other]
    if entry then
        if entry.highlight then entry.highlight:Destroy() end
        if entry.billboard then entry.billboard:Destroy() end
        espEntries[other] = nil
    end
end
local function clearESP()
    for other in pairs(espEntries) do removeESP(other) end
    status.espCount = 0
end
local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end
local function destroy()
    if not alive then return end
    alive = false
    RunService:UnbindFromRenderStep(BINDING)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    connections = {}
    lockedPlayer, dragging, sliding = nil, nil, nil
    clearESP()
    if espWorldFolder then espWorldFolder:Destroy() end
    if espGuiFolder then espGuiFolder:Destroy() end
    status.target, status.message = nil, "Unloaded"
    if environment[KEY] == api then environment[KEY] = nil end
    if gui then gui:Destroy() end
end
api.Destroy = destroy

local function make(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end
local function round(object, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius)}, object)
end
local function text(parent, value, x, y, width, height, size, color, bold)
    return make("TextLabel", {
        BackgroundTransparency = 1, Text = value, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(width, height), TextColor3 = color or colors.text,
        TextSize = size or 14, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end
local function fitPanel()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    scale.Scale = math.clamp(math.min((viewport.X - 24) / 360, (viewport.Y - 24) / PANEL_HEIGHT), 0.35, 1)
    panel.Position = UDim2.fromOffset(
        math.clamp(panel.Position.X.Offset, 8, math.max(8, viewport.X - 360 * scale.Scale - 8)),
        math.clamp(panel.Position.Y.Offset, 8, math.max(8, viewport.Y - PANEL_HEIGHT * scale.Scale - 8)))
end
local function showPanel(visible)
    panel.Visible, reopen.Visible = visible, not visible
    if visible then fitPanel() end
end
api.Show = function() showPanel(true) end

local function toggleRow(name, title, subtitle, y, key)
    local row = make("TextButton", {
        Name = name, Text = "", AutoButtonColor = false, BackgroundColor3 = colors.card,
        Position = UDim2.fromOffset(20, y), Size = UDim2.fromOffset(320, 58),
    }, panel)
    round(row, 10)
    text(row, title, 14, 8, 240, 22, 14, colors.text, true)
    text(row, subtitle, 14, 31, 240, 18, 11, colors.muted)
    local track = make("Frame", {Size = UDim2.fromOffset(38, 22),
        Position = UDim2.fromOffset(268, 18)}, row)
    round(track, 11)
    local knob = make("Frame", {Size = UDim2.fromOffset(16, 16)}, track)
    round(knob, 8)
    local function render()
        track.BackgroundColor3 = config[key] and colors.accent or colors.border
        knob.BackgroundColor3 = config[key] and colors.base or colors.text
        knob.Position = UDim2.fromOffset(config[key] and 19 or 3, 3)
    end
    toggleRenderers[key] = render
    render()
    connect(row.Activated, function()
        if key == "AutoFire" and not clickFunction then
            status.fireError = "Xeno does not expose mouse1click"
            warn("[Centaura] Autofire unavailable: " .. status.fireError)
            return
        end
        config[key] = not config[key]
        if key == "Enabled" then lockedPlayer = nil; status.lastError = nil end
        if key == "AutoFire" then status.fireError = nil; fireFocusReady = true end
        if key == "ESP" then
            status.espError, espElapsed = nil, 0.2
            if not config.ESP then clearESP() end
        end
        render()
    end)
end
local function sliderCard(name, title, subtitle, y, key, low, high, suffix)
    local card = make("Frame", {Name = name, BackgroundColor3 = colors.card,
        Position = UDim2.fromOffset(20, y), Size = UDim2.fromOffset(320, 78)}, panel)
    round(card, 10)
    text(card, title, 14, 6, 210, 22, 14, colors.text, true)
    text(card, subtitle, 14, 28, 290, 16, 10, colors.muted)
    local valueLabel = text(card, "", 230, 6, 76, 22, 12, colors.accent, true)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    local slider = make("TextButton", {Name = name .. "Slider", Text = "", BackgroundTransparency = 1,
        AutoButtonColor = false, Position = UDim2.fromOffset(14, 48), Size = UDim2.fromOffset(292, 24)}, card)
    local rail = make("Frame", {BorderSizePixel = 0, BackgroundColor3 = colors.border,
        Position = UDim2.new(0, 0, 0.5, -2), Size = UDim2.new(1, 0, 0, 4)}, slider)
    round(rail, 2)
    local fill = make("Frame", {BorderSizePixel = 0, BackgroundColor3 = colors.accent}, rail)
    round(fill, 2)
    local knob = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = colors.accent, Size = UDim2.fromOffset(12, 12)}, rail)
    round(knob, 6)
    local function setValue(value)
        config[key] = math.clamp(math.floor(value + 0.5), low, high)
        local amount = (config[key] - low) / (high - low)
        fill.Size = UDim2.fromScale(amount, 1)
        knob.Position = UDim2.fromScale(amount, 0.5)
        valueLabel.Text = tostring(config[key]) .. suffix
    end
    local function at(x)
        if slider.AbsoluteSize.X > 0 then
            local amount = math.clamp((x - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
            setValue(low + amount * (high - low))
        end
    end
    setValue(config[key])
    connect(slider.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = {input = input, at = at}
            at(input.Position.X)
        end
    end)
end

local function createInterface()
    gui = make("ScreenGui", {Name = "CentauraCameraAssist", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, nil)
    connect(gui.Destroying, destroy)
    gui.Parent = player:WaitForChild("PlayerGui")
    panel = make("Frame", {Name = "Panel", BackgroundColor3 = colors.base,
        Position = UDim2.fromOffset(28, 80), Size = UDim2.fromOffset(360, PANEL_HEIGHT), Active = true}, gui)
    round(panel, 16)
    make("UIStroke", {Color = colors.border, Thickness = 1}, panel)
    scale = make("UIScale", {Scale = 1}, panel)
    fitPanel()
    local header = make("Frame", {Name = "DragHandle", BackgroundTransparency = 1, Active = true,
        Size = UDim2.fromOffset(290, 78)}, panel)
    text(header, "CENTAURA", 20, 14, 230, 26, 19, colors.text, true)
    text(header, "Camera assist + ESP  /  v2.1", 20, 43, 250, 20, 12, colors.muted)
    local minimize = make("TextButton", {Name = "Minimize", Text = "-", TextSize = 24,
        Font = Enum.Font.Gotham, TextColor3 = colors.muted, BackgroundColor3 = colors.card,
        Position = UDim2.fromOffset(308, 22), Size = UDim2.fromOffset(32, 32)}, panel)
    round(minimize, 9)
    connect(minimize.Activated, function() showPanel(false) end)
    toggleRow("AssistToggle", "Camera assist", "Hold right-click while a gun is equipped", 92, "Enabled")
    toggleRow("RadiusToggle", "Show radius", "Centered on the camera crosshair", 158, "ShowRadius")
    toggleRow("AutoFireToggle", "Autofire", clickFunction and "Right-click held + crosshair aligned" or "Unavailable: mouse1click is missing", 224, "AutoFire")
    toggleRow("ESPToggle", "Enemy ESP", "Outlines, names, distance and health", 290, "ESP")
    sliderCard("Radius", "Targeting radius", "Only acquire targets inside this circle", 356, "Radius", 40, 650, " px")
    sliderCard("Strength", "Aim strength", "Higher values turn the camera faster", 442, "Strength", 3, 30, " /s")
    sliderCard("FireRate", "Autofire rate", "Click attempts; weapon fire rate still applies", 528, "FireRate", 2, 10, " /s")
    text(panel, "Aim / fire: team + wall checks", 22, 614, 245, 22, 11, colors.muted)
    text(panel, "ALWAYS ON", 264, 614, 80, 22, 10, colors.accent, true)
    local statusCard = make("Frame", {Name = "Status", BackgroundColor3 = colors.card,
        Position = UDim2.fromOffset(20, 644), Size = UDim2.fromOffset(320, 88)}, panel)
    round(statusCard, 10)
    statusDot = make("Frame", {BackgroundColor3 = colors.muted, Size = UDim2.fromOffset(6, 6),
        Position = UDim2.fromOffset(14, 16)}, statusCard)
    round(statusDot, 3)
    statusLabel = text(statusCard, "Starting", 28, 6, 278, 24, 12, colors.text, true)
    statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
    statusDetail = text(statusCard, "", 14, 31, 292, 48, 10, colors.muted)
    statusDetail.TextWrapped = true
    text(panel, "Drag header to move", 22, 742, 160, 22, 10, colors.muted)
    local shortcut = text(panel, "RIGHT SHIFT: SHOW / HIDE", 172, 742, 166, 22, 9, colors.muted)
    shortcut.TextXAlignment = Enum.TextXAlignment.Right
    local unload = make("TextButton", {Name = "Unload", Text = "Unload assist", TextSize = 12,
        Font = Enum.Font.Gotham, TextColor3 = colors.muted, BackgroundColor3 = colors.card,
        Position = UDim2.fromOffset(20, 772), Size = UDim2.fromOffset(320, 30)}, panel)
    round(unload, 9)
    connect(unload.Activated, destroy)
    reopen = make("TextButton", {Name = "Reopen", Text = "CENTAURA  +", Visible = false,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = colors.accent,
        BackgroundColor3 = colors.base, Position = UDim2.fromOffset(8, 80), Size = UDim2.fromOffset(150, 40)}, gui)
    round(reopen, 12)
    connect(reopen.Activated, function() showPanel(true) end)
    ring = make("Frame", {Name = "RadiusCircle", BackgroundTransparency = 1, Visible = false,
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(600, 600), ZIndex = 0}, gui)
    round(ring, 10000)
    make("UIStroke", {Color = colors.accent, Thickness = 1, Transparency = 0.5}, ring)
    connect(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = {input = input, start = input.Position, position = panel.Position}
        end
    end)
    connect(Input.InputChanged, function(input)
        local moving = input.UserInputType == Enum.UserInputType.MouseMovement
        if sliding and (input == sliding.input or moving and sliding.input.UserInputType == Enum.UserInputType.MouseButton1) then
            sliding.at(input.Position.X)
        end
        if dragging and (input == dragging.input or moving and dragging.input.UserInputType == Enum.UserInputType.MouseButton1) then
            local delta = input.Position - dragging.start
            panel.Position = UDim2.fromOffset(dragging.position.X.Offset + delta.X, dragging.position.Y.Offset + delta.Y)
            fitPanel()
        end
    end)
    connect(Input.InputEnded, function(input)
        if sliding and input == sliding.input then sliding = nil end
        if dragging and input == dragging.input then dragging = nil end
    end)
    connect(Input.InputBegan, function(input, processed)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then fireFocusReady = true end
        if not processed and not Input:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.RightShift then
            showPanel(not panel.Visible)
        end
    end)
    connect(Input.WindowFocusReleased, function() focused = false; fireFocusReady = false; lockedPlayer = nil; dragging = nil; sliding = nil end)
    connect(Input.WindowFocused, function() focused = true; fireFocusReady = true end)
    connect(player.CharacterAdded, function() lockedPlayer = nil end)
    espWorldFolder = make("Folder", {Name = "CentauraAssistHighlights"}, workspace)
    espGuiFolder = make("Folder", {Name = "CentauraAssistLabels"}, player:WaitForChild("PlayerGui"))
end

local function updateESP(delta)
    if not config.ESP or not focused or GuiService.MenuIsOpen or not workspace.CurrentCamera then
        clearESP()
        espElapsed = 0.2
        return
    end
    espElapsed = espElapsed + delta
    if espElapsed < 0.2 then return end
    espElapsed = 0
    local seen, count = {}, 0
    local camera = workspace.CurrentCamera
    for _, other in ipairs(Players:GetPlayers()) do
        local character = other.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local anchor = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
        local eligible = other ~= player and other.Parent == Players and character and character.Parent
            and (player.Team == nil or other.Team ~= player.Team) and humanoid and humanoid.Health > 0
            and not character:FindFirstChildOfClass("ForceField") and anchor and anchor:IsA("BasePart")
        local distance = eligible and (anchor.Position - camera.CFrame.Position).Magnitude or math.huge
        if eligible and distance <= ESP_DISTANCE then
            seen[other] = true
            local entry = espEntries[other]
            if entry and entry.character ~= character then removeESP(other); entry = nil end
            if not entry then
                entry = {character = character}
                espEntries[other] = entry
                -- Parent highlights in workspace and labels in PlayerGui; both use explicit adornees.
                entry.highlight = make("Highlight", {Name = "EnemyOutline", Adornee = character,
                    DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, FillTransparency = 0.9,
                    OutlineTransparency = 0.1, Enabled = true}, espWorldFolder)
                entry.billboard = make("BillboardGui", {Name = "EnemyLabel", Adornee = anchor,
                    AlwaysOnTop = true, LightInfluence = 0, MaxDistance = ESP_DISTANCE,
                    StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0), Size = UDim2.fromOffset(180, 40)}, espGuiFolder)
                entry.label = make("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
                    Font = Enum.Font.GothamBold, TextSize = 12, TextStrokeTransparency = 0.3,
                    TextWrapped = false, RichText = false}, entry.billboard)
            end
            local color = status.target == other.Name and colors.accent or colors.enemy
            entry.highlight.FillColor, entry.highlight.OutlineColor = color, color
            entry.billboard.Adornee = anchor
            entry.label.TextColor3 = color
            entry.label.Text = string.format("%s\n%d studs | %d HP", other.DisplayName,
                math.floor(distance + 0.5), math.floor(humanoid.Health + 0.5))
            count = count + 1
        end
    end
    for other in pairs(espEntries) do if not seen[other] then removeESP(other) end end
    status.espCount = count
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local function unobstructed(origin, part, character)
    local direction = part.Position - origin
    if direction.Magnitude < 0.001 then return false end
    local hit = workspace:Raycast(origin, direction, rayParams)
    return not hit or hit.Instance:IsDescendantOf(character)
end
local function candidate(other, camera, center, muzzle, localCharacter)
    if other == player or other.Parent ~= Players or (player.Team ~= nil and other.Team == player.Team) then return nil end
    local character = other.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or character == localCharacter or not humanoid or humanoid.Health <= 0
        or character:FindFirstChildOfClass("ForceField") then return nil end
    local parts = {character:FindFirstChild("Head"), character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart}
    -- Explicit indices retain the root fallback if the head is absent.
    for index = 1, 2 do
        local part = parts[index]
        if part and part:IsA("BasePart") then
            local projected, onScreen = camera:WorldToViewportPoint(part.Position)
            local distance = (Vector2.new(projected.X, projected.Y) - center).Magnitude
            if onScreen and projected.Z > 0 and distance <= config.Radius
                and unobstructed(camera.CFrame.Position, part, character)
                and unobstructed(muzzle, part, character) then
                return part, distance
            end
        end
    end
    return nil
end
local function findTarget(camera, center, muzzle, localCharacter)
    -- Keep a valid target while held; revalidate visibility, health and team each frame.
    if lockedPlayer then
        local part = candidate(lockedPlayer, camera, center, muzzle, localCharacter)
        if part then return lockedPlayer, part end
        lockedPlayer = nil
    end
    local bestPlayer, bestPart, bestDistance = nil, nil, config.Radius + 1
    for _, other in ipairs(Players:GetPlayers()) do
        local part, distance = candidate(other, camera, center, muzzle, localCharacter)
        if part and distance < bestDistance then
            bestPlayer, bestPart, bestDistance = other, part, distance
        end
    end
    return bestPlayer, bestPart
end
local function mouseOver(object)
    if not object.Visible then return false end
    local mouse = Input:GetMouseLocation()
    local position, size = object.AbsolutePosition, object.AbsoluteSize
    return mouse.X >= position.X and mouse.Y >= position.Y
        and mouse.X <= position.X + size.X and mouse.Y <= position.Y + size.Y
end
local function idle(message, detail)
    lockedPlayer, status.target = nil, nil
    status.message, status.detail = message, detail
end
local function fireFailure(problem)
    config.AutoFire = false
    status.fireError, status.fireState = tostring(problem), "Error"
    toggleRenderers.AutoFire()
    warn("[Centaura] Autofire disabled: " .. status.fireError)
end
local function maybeFire(camera, center, other, part, character, tool, barrel)
    if not config.AutoFire or not clickFunction then return end
    if not fireFocusReady then status.fireState = "Press right-click again"; return end
    if firePending then status.fireState = "Pending"; return end
    if Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then status.fireState = "Manual fire"; return end
    local point, onScreen = camera:WorldToViewportPoint(part.Position)
    if not onScreen or point.Z <= 0 or (Vector2.new(point.X, point.Y) - center).Magnitude > FIRE_TOLERANCE then
        status.fireState = "Aligning"; return
    end
    if clock < nextFireAt then status.fireState = "Cooldown"; return end
    firePending = true
    nextFireAt = clock + 1 / config.FireRate
    status.fireState = "Pending"
    -- Some executors yield during a complete click; keep that off the render callback.
    task.spawn(function()
        local ok, problem = pcall(function()
            -- Recheck when the task actually runs, including after a queued unload or target loss.
            if not alive or not config.Enabled or not config.AutoFire or not focused or not fireFocusReady
                or GuiService.MenuIsOpen or Input:GetFocusedTextBox() or dragging or sliding
                or mouseOver(panel) or mouseOver(reopen) or workspace.CurrentCamera ~= camera
                or player.Character ~= character or tool.Parent ~= character
                or camera.CameraType == Enum.CameraType.Scriptable or status.target ~= other.Name
                or not Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                or Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then return end
            if candidate(other, camera, center, barrel.Position, character) ~= part then return end
            local current, visible = camera:WorldToViewportPoint(part.Position)
            if not visible or current.Z <= 0 or (Vector2.new(current.X, current.Y) - center).Magnitude > FIRE_TOLERANCE then return end
            status.fireAttempts = status.fireAttempts + 1
            clickFunction()
            if alive then status.fireState = "Click attempted" end
        end)
        firePending = false
        if not ok and alive then fireFailure(problem) end
    end)
end
local lastViewport
local function update(delta)
    clock = clock + math.max(delta, 0)
    status.fireState = status.fireError and "Error" or (not clickFunction and "Unavailable" or (config.AutoFire and "Waiting" or "Off"))
    local camera = workspace.CurrentCamera
    if not camera then ring.Visible = false; idle("Waiting for camera", "Camera unavailable"); return end
    if camera.ViewportSize ~= lastViewport then lastViewport = camera.ViewportSize; fitPanel() end
    local center = camera.ViewportSize / 2
    ring.Position = UDim2.fromOffset(center.X, center.Y)
    ring.Size = UDim2.fromOffset(config.Radius * 2, config.Radius * 2)
    ring.Visible = config.Enabled and config.ShowRadius and focused and not GuiService.MenuIsOpen
    if status.lastError then idle("Needs attention", status.lastError); return end
    if not config.Enabled then idle("Paused", "Enable camera assist to resume"); return end
    if not focused or Input:GetFocusedTextBox() or GuiService.MenuIsOpen or dragging or sliding
        or mouseOver(panel) or mouseOver(reopen) then
        idle("Input paused", "Return to the game to aim"); return
    end
    if not Input.MouseEnabled then idle("Mouse required", "This version uses right mouse button"); return end
    if camera.CameraType == Enum.CameraType.Scriptable then idle("Camera paused", "Waiting for the normal gameplay camera"); return end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then idle("Waiting for spawn", "Assist resumes after respawn"); return end
    local tool = character:FindFirstChildOfClass("Tool")
    local barrel = tool and tool:FindFirstChild("Barrel")
    if not barrel or not barrel:IsA("BasePart") then idle("Equip a gun", "A gun with a Barrel part is required"); return end
    if not Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        idle("Ready", "Hold right-click to assist camera aim"); return
    end
    local excluded = {character, camera}
    local ignoreList = workspace:FindFirstChild("IgnoreList")
    if ignoreList then table.insert(excluded, ignoreList) end
    rayParams.FilterDescendantsInstances = excluded
    local targetPlayer, part = findTarget(camera, center, barrel.Position, character)
    if not part then idle("No visible target", "Keep an enemy inside the radius with a clear line of sight"); return end
    local position = camera.CFrame.Position
    local direction = part.Position - position
    if direction.Magnitude < 0.001 then idle("No visible target", "Target is too close to the camera"); return end
    local wanted = CFrame.lookAt(position, part.Position)
    -- Exponential response is consistent across normal frame rates.
    local alpha = 1 - math.exp(-config.Strength * math.clamp(delta, 0, 0.1))
    camera.CFrame = camera.CFrame:Lerp(wanted, alpha)
    lockedPlayer = targetPlayer
    status.target = targetPlayer.Name
    status.cameraUpdates = status.cameraUpdates + 1
    status.message = "Tracking: " .. targetPlayer.DisplayName
    status.detail = "Camera updates: " .. tostring(status.cameraUpdates) .. "  |  Release right-click to stop"
    maybeFire(camera, center, targetPlayer, part, character, tool, barrel)
end

local startupOK, startupError = pcall(function()
    createInterface()
    environment[KEY] = api
    RunService:BindToRenderStep(BINDING, Enum.RenderPriority.Camera.Value + 1, function(delta)
        if not alive then return end
        local ok, problem = pcall(update, delta)
        if not ok then
            local firstError = status.lastError == nil
            status.lastError = tostring(problem)
            idle("Needs attention", status.lastError)
            ring.Visible = false
            if firstError then warn("[Centaura] Camera assist error: " .. status.lastError) end
        end
        local espOK, espProblem = pcall(updateESP, delta)
        if not espOK then
            config.ESP = false
            status.espError = tostring(espProblem)
            clearESP()
            toggleRenderers.ESP()
            warn("[Centaura] ESP disabled: " .. status.espError)
        end
        local extras = status.fireError and ("Auto: " .. status.fireError)
            or ("Auto: " .. tostring(status.fireState) .. " | ESP: " .. tostring(status.espCount))
        if status.espError then extras = "ESP: " .. status.espError end
        statusLabel.Text, statusDetail.Text = status.message, (status.detail or "") .. "\n" .. extras
        statusDot.BackgroundColor3 = status.lastError and colors.error or (status.target and colors.accent or colors.muted)
    end)
end)
if not startupOK then destroy(); error("[Centaura] Startup failed: " .. tostring(startupError)) end
warn("[Centaura] Camera assist v2.1 loaded. Autofire and enemy ESP have separate toggles. Right Shift shows/hides the panel.")
return api
