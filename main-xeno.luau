-- Centaura camera aim assist v2.0.0. Hold right-click to assist camera aim.
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
}
if type(previous) == "table" and type(previous.Destroy) == "function" then
    previous.Destroy()
end

local connections = {}
local gui, panel, reopen, ring, scale, statusLabel, statusDetail, statusDot
local dragging, sliding
local alive, focused = true, true
local lockedPlayer
local api = {Config = config, Status = {cameraUpdates = 0, target = nil, message = "Starting"}}
local status = api.Status
local colors = {
    base = Color3.fromRGB(17, 21, 28), card = Color3.fromRGB(25, 30, 39),
    border = Color3.fromRGB(43, 51, 65), text = Color3.fromRGB(237, 242, 250),
    muted = Color3.fromRGB(146, 158, 179), accent = Color3.fromRGB(105, 219, 190),
    error = Color3.fromRGB(255, 159, 145),
}
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
    scale.Scale = math.clamp(math.min((viewport.X - 24) / 360, (viewport.Y - 24) / 578), 0.35, 1)
    panel.Position = UDim2.fromOffset(
        math.clamp(panel.Position.X.Offset, 8, math.max(8, viewport.X - 360 * scale.Scale - 8)),
        math.clamp(panel.Position.Y.Offset, 8, math.max(8, viewport.Y - 578 * scale.Scale - 8)))
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
    render()
    connect(row.Activated, function()
        config[key] = not config[key]
        if key == "Enabled" then lockedPlayer = nil; status.lastError = nil end
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
        Position = UDim2.fromOffset(28, 80), Size = UDim2.fromOffset(360, 578), Active = true}, gui)
    round(panel, 16)
    make("UIStroke", {Color = colors.border, Thickness = 1}, panel)
    scale = make("UIScale", {Scale = 1}, panel)
    fitPanel()
    local header = make("Frame", {Name = "DragHandle", BackgroundTransparency = 1, Active = true,
        Size = UDim2.fromOffset(290, 78)}, panel)
    text(header, "CENTAURA", 20, 14, 230, 26, 19, colors.text, true)
    text(header, "Camera aim assist  /  v2.0", 20, 43, 250, 20, 12, colors.muted)
    local minimize = make("TextButton", {Name = "Minimize", Text = "-", TextSize = 24,
        Font = Enum.Font.Gotham, TextColor3 = colors.muted, BackgroundColor3 = colors.card,
        Position = UDim2.fromOffset(308, 22), Size = UDim2.fromOffset(32, 32)}, panel)
    round(minimize, 9)
    connect(minimize.Activated, function() showPanel(false) end)
    toggleRow("AssistToggle", "Camera assist", "Hold right-click while a gun is equipped", 92, "Enabled")
    toggleRow("RadiusToggle", "Show radius", "Centered on the camera crosshair", 158, "ShowRadius")
    sliderCard("Radius", "Targeting radius", "Only acquire targets inside this circle", 224, "Radius", 40, 650, " px")
    sliderCard("Strength", "Aim strength", "Higher values turn the camera faster", 310, "Strength", 3, 30, " /s")
    text(panel, "Team + wall checks", 22, 396, 210, 22, 12, colors.muted)
    text(panel, "ALWAYS ON", 264, 396, 80, 22, 10, colors.accent, true)
    local statusCard = make("Frame", {Name = "Status", BackgroundColor3 = colors.card,
        Position = UDim2.fromOffset(20, 426), Size = UDim2.fromOffset(320, 66)}, panel)
    round(statusCard, 10)
    statusDot = make("Frame", {BackgroundColor3 = colors.muted, Size = UDim2.fromOffset(6, 6),
        Position = UDim2.fromOffset(14, 16)}, statusCard)
    round(statusDot, 3)
    statusLabel = text(statusCard, "Starting", 28, 6, 278, 24, 12, colors.text, true)
    statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
    statusDetail = text(statusCard, "", 14, 31, 292, 28, 10, colors.muted)
    statusDetail.TextWrapped = true
    text(panel, "Drag header to move", 22, 502, 160, 22, 10, colors.muted)
    local shortcut = text(panel, "RIGHT SHIFT: SHOW / HIDE", 172, 502, 166, 22, 9, colors.muted)
    shortcut.TextXAlignment = Enum.TextXAlignment.Right
    local unload = make("TextButton", {Name = "Unload", Text = "Unload assist", TextSize = 12,
        Font = Enum.Font.Gotham, TextColor3 = colors.muted, BackgroundColor3 = colors.card,
        Position = UDim2.fromOffset(20, 532), Size = UDim2.fromOffset(320, 30)}, panel)
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
        if not processed and not Input:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.RightShift then
            showPanel(not panel.Visible)
        end
    end)
    connect(Input.WindowFocusReleased, function() focused = false; lockedPlayer = nil; dragging = nil; sliding = nil end)
    connect(Input.WindowFocused, function() focused = true end)
    connect(player.CharacterAdded, function() lockedPlayer = nil end)
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
local lastViewport
local function update(delta)
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
        statusLabel.Text, statusDetail.Text = status.message, status.detail or ""
        statusDot.BackgroundColor3 = status.lastError and colors.error or (status.target and colors.accent or colors.muted)
    end)
end)
if not startupOK then destroy(); error("[Centaura] Startup failed: " .. tostring(startupError)) end
warn("[Centaura] Camera assist v2.0 loaded. Equip a gun and hold right-click. Right Shift shows/hides the panel.")
return api
