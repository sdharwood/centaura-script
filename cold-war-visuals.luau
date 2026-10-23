-- Cold War visuals v1.0.0: ballistic crosshair and player ESP.
-- Reads weapon state via bounded upvalue inspection; no decompile, GC scan, weapon hooks or remote calls.
-- Local rendering does not establish that an executor or this overlay is undetectable.
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local player = assert(Players.LocalPlayer, "[Cold War ESP] Local player unavailable")
local env = shared
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then env = value end
end
assert(type(env) == "table", "[Cold War ESP] Shared state unavailable")
local KEY = "SDH_ColdWarVisuals_v1"
local previous = env[KEY]
local old = type(previous) == "table" and previous.settings or {}
if type(old) ~= "table" then old = {} end
-- Unload our previous overlay and earlier controllers; no scanning or editing game scripts.
if type(previous) == "table" and type(previous.unload) == "function" then previous.unload() end
if type(env.SDH_ColdWar_v1) == "table" and type(env.SDH_ColdWar_v1.unload) == "function" then
    env.SDH_ColdWar_v1.unload()
end
if type(env.SDH_ColdWarESP_v1) == "table" and type(env.SDH_ColdWarESP_v1.unload) == "function" then
    env.SDH_ColdWarESP_v1.unload()
end
local function bounded(value, fallback, low, high)
    value = tonumber(value)
    if not value or value ~= value then value = fallback end
    return math.clamp(value, low, high)
end
local settings = {
    crosshair = false, shape = old.shape == "Dot" and "Dot" or "Cross",
    size = math.floor(bounded(old.size, 8, 2, 32)),
    thickness = math.floor(bounded(old.thickness, 2, 1, 8)),
    gap = math.floor(bounded(old.gap, 3, 0, 20)),
    crossColor = type(old.crossColor) == "string" and old.crossColor:match("^%x%x%x%x%x%x$") and old.crossColor or "70D6BC",
    info = old.info ~= false,
    enabled = false, outlines = old.outlines ~= false, tags = old.tags == true,
    health = old.health ~= false, distance = old.distance ~= false,
    teammates = old.teammates == true, fill = old.fill == true,
    range = bounded(old.range, 1500, 100, 5000),
    palette = math.floor(bounded(old.palette, 1, 1, 4)),
}
local state = {active = true, settings = settings, links = {}, visuals = {}, count = 0, message = "ESP off"}
env[KEY] = state
local accent = Color3.fromRGB(112, 214, 188)
local muted = Color3.fromRGB(151, 165, 184)
local palettes = {
    Color3.fromRGB(244, 127, 139), Color3.fromRGB(112, 214, 188),
    Color3.fromRGB(108, 185, 255), Color3.fromRGB(242, 216, 126),
}
local friendColor = Color3.fromRGB(130, 179, 241)
local function connect(signal, fn)
    local connection = signal:Connect(fn)
    table.insert(state.links, connection)
    return connection
end
local function make(class, props, parent)
    local object = Instance.new(class)
    -- If assigning a property fails, destroy the unparented partial object.
    local ok, why = pcall(function()
        for k, v in pairs(props or {}) do object[k] = v end
        object.Parent = parent
    end)
    if not ok then object:Destroy(); error(why, 0) end
    return object
end
local function remove(other)
    local visual = state.visuals[other]
    if not visual then return end
    if visual.highlight then visual.highlight:Destroy() end
    if visual.billboard then visual.billboard:Destroy() end
    state.visuals[other] = nil
end
local function clear()
    for other in pairs(state.visuals) do remove(other) end
    state.count = 0
end
local gui, worldFolder, crossRoot, crossDot, crossInfo
local crossArms = {}
local function resetPrediction(message)
    state.impact, state.prediction = nil, message
    if crossRoot then crossRoot.Visible = false end
end
function state.unload()
    if not state.active then return end
    state.active = false
    resetPrediction("Unloaded")
    for _, connection in ipairs(state.links) do connection:Disconnect() end
    state.links = {}
    clear()
    if worldFolder then worldFolder:Destroy() end
    if gui then gui:Destroy() end
    if env[KEY] == state then env[KEY] = nil end
end
-- Exact free-flight equations from the supplied Ballistics.Trajectory module.
-- Collision queries stop at the first surface; penetration/ricochet are not simulated.
local Physics = {}
function Physics.position(origin, direction, speed, decay, gravity, time)
    local forward = decay > 0.000001 and speed / decay * (1 - math.exp(-decay * time)) or speed * time
    return origin + direction * forward - Vector3.new(0, 1, 0) * (gravity * 0.5 * time * time)
end
function Physics.predict(origin, direction, speed, decay, gravity, maxTime, maxDistance, params, step)
    if speed <= 0 or direction.Magnitude <= 0.000001 then return nil, "Invalid launch" end
    direction = direction.Unit
    decay = math.max(decay, 0)
    step = math.clamp(step or 1 / 60, 1 / 240, 1 / 20)
    local last, time, distance = origin, 0, 0
    -- At most 1,202 segments covers the game's default five-second lifetime even at 240 FPS.
    local cap = math.min(1202, math.ceil(maxTime / step) + 1)
    for _ = 1, cap do
        local nextTime = math.min(time + step, maxTime)
        local position = Physics.position(origin, direction, speed, decay, gravity, nextTime)
        local delta = position - last
        local length = delta.Magnitude
        local atLimit = distance + length >= maxDistance
        if atLimit and length > 0.000001 then
            position = last + delta.Unit * math.max(0, maxDistance - distance)
            delta = position - last
            length = delta.Magnitude
        end
        if length > 0.000001 then
            local hit = workspace:Raycast(last, delta, params)
            if hit then return hit.Position, "Surface", nextTime, distance + (hit.Position - last).Magnitude end
        end
        distance, last, time = distance + length, position, nextTime
        if atLimit then return last, "Range limit", time, distance end
        if time >= maxTime then return last, "Lifetime limit", time, distance end
    end
    return nil, "Prediction budget exceeded"
end
state.Physics = Physics
local gameModules
local function childPath(root, ...)
    for _, name in ipairs({...}) do root = root and root:FindFirstChild(name) end
    return root
end
local function loadWeaponModules()
    if gameModules then return gameModules end
    local storage = game:GetService("ReplicatedStorage")
    local controls = childPath(storage, "Client", "Tools", "Weapon", "controllers")
    local zero = controls and controls:FindFirstChild("ZeroController")
    local view = controls and controls:FindFirstChild("WeaponViewmodel")
    local groups = childPath(storage, "Shared", "CollisionGroups")
    if not zero or not view or not groups then error("Required weapon modules are unavailable", 0) end
    local result = {zero = require(zero), view = require(view), groups = require(groups)}
    if type(result.zero) ~= "table" or type(result.zero.zeroAngle) ~= "function"
        or type(result.view) ~= "table" or type(result.view.isShown) ~= "function"
        or type(result.groups) ~= "table" or type(result.groups.teamRayGroup) ~= "function" then
        error("Weapon interfaces differ from the uploaded source", 0)
    end
    gameModules = result
    return result
end
local function zeroState(zero)
    local values
    if type(debug) == "table" and type(debug.getupvalues) == "function" then
        local ok, result = pcall(debug.getupvalues, zero.zeroAngle)
        if ok and type(result) == "table" then values = result end
    end
    if not values then
        values = {}
        local reader = type(debug) == "table" and debug.getupvalue or getupvalue
        if type(reader) ~= "function" then error("Read-only weapon state access is unavailable", 0) end
        for i = 1, 8 do
            local ok, first, second = pcall(reader, zero.zeroAngle, i)
            if not ok then break end
            values[i] = second ~= nil and second or first
        end
    end
    local found
    for _, value in pairs(values) do
        if type(value) == "table" and type(value.weapon) == "table" and type(value.units) == "table" then
            if found then error("Ambiguous weapon state", 0) end
            found = value.weapon
        end
    end
    return found
end
local function shotState()
    local character = player.Character
    local human = character and character:FindFirstChildOfClass("Humanoid")
    if not human or human.Health <= 0 then return nil, "Waiting for spawn" end
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then return nil, "Equip a gun" end
    local camera = workspace.CurrentCamera
    if not camera then return nil, "Waiting for camera" end
    local modules = loadWeaponModules()
    local weapon = zeroState(modules.zero)
    if not weapon or weapon.tool ~= tool then return nil, "Current weapon data is unavailable" end
    local muzzle = weapon.currentMuzzle
    if type(muzzle) ~= "table" or type(muzzle.config) ~= "table" or type(muzzle.getBulletIndex) ~= "function" then
        return nil, "No active muzzle"
    end
    local bulletIndex = muzzle:getBulletIndex()
    local bullet = muzzle.config.BulletSettings and muzzle.config.BulletSettings[bulletIndex]
    if not bullet or type(bullet.MuzzleVelocity) ~= "number" or bullet.MuzzleVelocity <= 0 then return nil, "No loaded projectile profile" end
    local useView = (camera.CFrame.Position - camera.Focus.Position).Magnitude <= 0.75 and modules.view.isShown()
    local attachment = useView and muzzle.viewmodelAttachment or muzzle.attachment
    if not attachment or not attachment:IsA("Attachment") or not attachment.Parent then return nil, "Muzzle attachment is unavailable" end
    local origin = attachment.WorldPosition
    local look = attachment.WorldCFrame.LookVector
    local arm = character:FindFirstChild("Right Arm")
    if arm then
        local back = (origin - arm.CFrame.Position).Magnitude
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignores = {character}
        local ignore = workspace:FindFirstChild("Ignore")
        if ignore then table.insert(ignores, ignore) end
        params.FilterDescendantsInstances = ignores
        local hit = workspace:Raycast(origin - look * back, look * back, params)
        if hit then origin = hit.Position - look * math.min(0.01, hit.Distance) end
    end
    local angle = modules.zero.zeroAngle()
    if angle == nil then angle = math.rad(muzzle.config.DefaultAngle or 0) end
    if type(angle) ~= "number" or angle ~= angle then return nil, "Invalid zero angle" end
    local direction = (attachment.WorldCFrame * CFrame.Angles(angle, 0, 0)).LookVector
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = false
    params.CollisionGroup = modules.groups.teamRayGroup(player.Team and player.Team.Name)
    local ignores = {character}
    local ignore = workspace:FindFirstChild("Ignore")
    if ignore then
        for _, object in ipairs(ignore:GetChildren()) do
            if object.Name ~= "Duds" then table.insert(ignores, object) end
        end
    end
    params.FilterDescendantsInstances = ignores
    return {
        origin = origin, direction = direction, speed = bullet.MuzzleVelocity,
        decay = bullet.Drag or 1, gravity = workspace.Gravity, params = params,
        tool = tool, character = character, camera = camera, muzzleIndex = weapon.currentMuzzleIndex,
        bulletIndex = bulletIndex, zero = angle, maxTime = 5, maxDistance = 5000,
    }
end
state.ShotState = shotState

local function round(parent, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end
local function label(parent, value, size, color)
    return make("TextLabel", {Text = value, BackgroundTransparency = 1,
        TextColor3 = color or Color3.fromRGB(234, 240, 247), Font = Enum.Font.Gotham,
        TextSize = size or 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 24), RichText = false}, parent)
end
local focused, dragging = true, nil
local panel, reopen, status, body, header
local elapsed = 0.2
local renderToggles = {}
local function fit()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local width = math.max(180, math.min(334, viewport.X - 16))
    local height = math.max(180, math.min(648, viewport.Y - 40))
    panel.Size = UDim2.fromOffset(width, height)
    panel.Position = UDim2.fromOffset(
        math.clamp(panel.Position.X.Offset, 0, math.max(0, viewport.X - width)),
        math.clamp(panel.Position.Y.Offset, 0, math.max(0, viewport.Y - height)))
end
local function createUI()
    gui = make("ScreenGui", {Name = "ColdWarVisuals", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
    connect(gui.Destroying, state.unload)
    worldFolder = make("Folder", {Name = "ColdWarESPVisuals"}, workspace)
    panel = make("Frame", {Name = "Panel", Size = UDim2.fromOffset(334, 648),
        Position = UDim2.fromOffset(22, 60), BackgroundColor3 = Color3.fromRGB(18, 23, 31),
        BorderSizePixel = 0, Active = true}, gui)
    round(panel, 14)
    make("UIStroke", {Color = Color3.fromRGB(48, 60, 77), Thickness = 1}, panel)
    header = make("Frame", {Name = "Header", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -66, 0, 56), Active = true}, panel)
    local title = label(header, "COLD WAR", 20)
    title.Font = Enum.Font.GothamBold
    local subtitle = label(header, "BALLISTIC CROSSHAIR + ESP", 10, muted)
    subtitle.Position = UDim2.fromOffset(0, 29)
    local minimize = make("TextButton", {Name = "Minimize", Text = "-", Font = Enum.Font.GothamBold,
        TextSize = 22, TextColor3 = muted, BackgroundColor3 = Color3.fromRGB(29, 37, 49),
        Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -44, 0, 16)}, panel)
    round(minimize, 8)
    body = make("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(14, 78), Size = UDim2.new(1, -28, 1, -92),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
        ScrollBarThickness = 3, ScrollBarImageColor3 = accent}, panel)
    make("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, body)
    local order = 0
    local function button(name, caption, callback)
        order = order + 1
        local b = make("TextButton", {Name = name, Text = caption, Font = Enum.Font.GothamMedium,
            TextSize = 12, TextColor3 = muted, BackgroundColor3 = Color3.fromRGB(28, 36, 48),
            Size = UDim2.new(1, -5, 0, 36), BorderSizePixel = 0, LayoutOrder = order}, body)
        round(b, 8)
        connect(b.Activated, callback)
        return b
    end
    local function toggle(name, caption, key)
        local b
        local function render()
            b.Text = caption .. "    " .. (settings[key] and "ON" or "OFF")
            b.TextColor3 = settings[key] and accent or muted
        end
        b = button(name, "", function()
            settings[key] = not settings[key]
            elapsed = 0.2
            if key == "crosshair" then state.crossError = nil; resetPrediction(settings.crosshair and "Connecting weapon data" or "Crosshair off") end
            if key == "enabled" then
                state.error = nil
                if not settings.enabled then clear() end
            end
            render()
        end)
        renderToggles[key] = render
        render()
    end
    order = order + 1
    status = label(body, "ESP off", 12, muted)
    status.Name = "Status"
    status.LayoutOrder = order
    status.Size = UDim2.new(1, -8, 0, 64)
    toggle("CrosshairToggle", "Dynamic crosshair", "crosshair")
    local shape
    shape = button("ShapeButton", "Shape: " .. settings.shape, function()
        settings.shape = settings.shape == "Cross" and "Dot" or "Cross"
        shape.Text = "Shape: " .. settings.shape
    end)
    local function numberBox(name, caption, key, low, high)
        order = order + 1
        local row = make("Frame", {Name = name .. "Row", BackgroundColor3 = Color3.fromRGB(28, 36, 48),
            Size = UDim2.new(1, -5, 0, 36), BorderSizePixel = 0, LayoutOrder = order}, body)
        round(row, 8)
        local title = label(row, caption, 12, muted)
        title.Position = UDim2.fromOffset(12, 6)
        title.Size = UDim2.new(1, -100, 0, 24)
        local box = make("TextBox", {Name = name, Text = tostring(settings[key]),
            ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 12,
            TextColor3 = accent, BackgroundTransparency = 1,
            Position = UDim2.new(1, -82, 0, 4), Size = UDim2.fromOffset(68, 28)}, row)
        connect(box.FocusLost, function()
            settings[key] = math.floor(bounded(box.Text, settings[key], low, high))
            box.Text = tostring(settings[key])
        end)
    end
    numberBox("SizeBox", "Size (px)", "size", 2, 32)
    numberBox("ThicknessBox", "Cross thickness (px)", "thickness", 1, 8)
    numberBox("GapBox", "Cross centre gap (px)", "gap", 0, 20)
    order = order + 1
    local colorRow = make("Frame", {BackgroundColor3 = Color3.fromRGB(28, 36, 48),
        Size = UDim2.new(1, -5, 0, 36), LayoutOrder = order}, body)
    round(colorRow, 8)
    local colorTitle = label(colorRow, "Crosshair colour (hex)", 12, muted)
    colorTitle.Position = UDim2.fromOffset(12, 6)
    local colorBox = make("TextBox", {Name = "CrossColorBox", Text = "#" .. settings.crossColor,
        ClearTextOnFocus = false, TextSize = 12, Font = Enum.Font.GothamMedium,
        TextColor3 = accent, BackgroundColor3 = Color3.fromRGB(20, 27, 38),
        Position = UDim2.new(1, -100, 0, 4), Size = UDim2.fromOffset(88, 28)}, colorRow)
    connect(colorBox.FocusLost, function()
        local value = colorBox.Text:gsub("^#", ""):upper()
        if value:match("^%x%x%x%x%x%x$") then settings.crossColor = value end
        colorBox.Text = "#" .. settings.crossColor
    end)
    toggle("InfoToggle", "Impact range label", "info")
    toggle("EnabledToggle", "Player ESP", "enabled")
    toggle("OutlineToggle", "Outlines", "outlines")
    toggle("TagsToggle", "Nametags", "tags")
    toggle("HealthToggle", "Health in nametags", "health")
    toggle("DistanceToggle", "Distance in nametags", "distance")
    toggle("TeammateToggle", "Show teammates", "teammates")
    toggle("FillToggle", "Soft silhouette fill", "fill")
    local range
    local ranges = {250, 500, 1000, 1500, 2500, 5000}
    range = button("RangeButton", "Range: " .. settings.range .. " studs", function()
        local nextRange = ranges[1]
        for i, value in ipairs(ranges) do
            if settings.range == value then nextRange = ranges[i % #ranges + 1]; break end
        end
        settings.range = nextRange
        range.Text = "Range: " .. nextRange .. " studs"
        elapsed = 0.2
    end)
    local color
    local names = {"Coral", "Mint", "Blue", "Gold"}
    color = button("ColorButton", "Enemy colour: " .. names[settings.palette], function()
        settings.palette = settings.palette % #palettes + 1
        color.Text = "Enemy colour: " .. names[settings.palette]
        elapsed = 0.2
    end)
    button("Unload", "Unload ESP", state.unload)
    reopen = make("TextButton", {Name = "Reopen", Text = "CW / ESP", Visible = false,
        Size = UDim2.fromOffset(104, 34), Position = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Color3.fromRGB(24, 32, 44), TextColor3 = accent,
        Font = Enum.Font.GothamBold, TextSize = 12}, gui)
    round(reopen, 9)
    connect(minimize.Activated, function() panel.Visible = false; reopen.Visible = true end)
    connect(reopen.Activated, function() panel.Visible = true; reopen.Visible = false; fit() end)
    crossRoot = make("Frame", {Name = "DynamicCrosshair", BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 0), Visible = false, ZIndex = 5}, gui)
    crossDot = make("Frame", {Name = "CrossDot", BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5}, crossRoot)
    round(crossDot, 100)
    for i = 1, 4 do
        crossArms[i] = make("Frame", {Name = "CrossArm" .. i, BorderSizePixel = 0, ZIndex = 5}, crossRoot)
    end
    crossInfo = label(crossRoot, "", 10, muted)
    crossInfo.Name = "CrossInfo"
    crossInfo.TextXAlignment = Enum.TextXAlignment.Center
    crossInfo.Size = UDim2.fromOffset(200, 24)
    crossInfo.TextStrokeTransparency = 0.3
    crossInfo.ZIndex = 5
    fit()
end
local ok, why = pcall(createUI)
if not ok then state.unload(); error("[Cold War ESP] UI setup failed: " .. tostring(why), 0) end
local function allowed(other)
    if other == player or other.Parent ~= Players then return nil end
    local sameTeam = player.Team ~= nil and player.Team == other.Team and not player.Neutral and not other.Neutral
    if sameTeam and not settings.teammates then return nil end
    local char = other.Character
    local human = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart or char:FindFirstChild("Head"))
    if not char or not char.Parent or not human or human.Health <= 0 or not root or not root:IsA("BasePart")
        or char:FindFirstChildOfClass("ForceField") then return nil end
    return char, human, root, sameTeam
end
local function refresh()
    local camera = workspace.CurrentCamera
    if not settings.enabled or not focused or GuiService.MenuIsOpen or not camera then clear(); return end
    if not settings.outlines and not settings.tags then clear(); return end
    local seen, count = {}, 0
    for _, other in ipairs(Players:GetPlayers()) do
        local char, human, root, sameTeam = allowed(other)
        local distance = root and (root.Position - camera.CFrame.Position).Magnitude or math.huge
        if char and distance <= settings.range then
            local visual = state.visuals[other]
            if visual and visual.character ~= char then remove(other); visual = nil end
            if not visual then
                visual = {character = char}
                state.visuals[other] = visual
            end
            local color = sameTeam and friendColor or palettes[settings.palette]
            if settings.outlines then
                if not visual.highlight then
                    visual.highlight = make("Highlight", {Name = "PlayerOutline", Adornee = char,
                        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, worldFolder)
                end
                visual.highlight.FillColor = color
                visual.highlight.OutlineColor = color
                visual.highlight.FillTransparency = settings.fill and 0.87 or 1
                visual.highlight.OutlineTransparency = 0.1
            elseif visual.highlight then visual.highlight:Destroy(); visual.highlight = nil end
            if settings.tags then
                if not visual.billboard then
                    visual.billboard = make("BillboardGui", {Name = "PlayerTag", AlwaysOnTop = true,
                        LightInfluence = 0, Size = UDim2.fromOffset(220, 42),
                        StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)}, gui)
                    visual.label = label(visual.billboard, "", 12)
                    visual.label.Size = UDim2.fromScale(1, 1)
                    visual.label.TextXAlignment = Enum.TextXAlignment.Center
                    visual.label.TextStrokeTransparency = 0.35
                end
                visual.billboard.Adornee = root
                visual.billboard.MaxDistance = settings.range
                local detail = {}
                if settings.health then table.insert(detail, math.floor(human.Health) .. " HP") end
                if settings.distance then table.insert(detail, math.floor(distance) .. " studs") end
                visual.label.Text = other.DisplayName .. (#detail > 0 and "\n" .. table.concat(detail, " / ") or "")
                visual.label.TextColor3 = color
            elseif visual.billboard then visual.billboard:Destroy(); visual.billboard, visual.label = nil, nil end
            seen[other], count = true, count + 1
        end
    end
    for other in pairs(state.visuals) do if not seen[other] then remove(other) end end
    state.count = count
end
connect(Players.PlayerRemoving, remove)
connect(UIS.WindowFocusReleased, function() focused = false; dragging = nil; clear(); resetPrediction("Crosshair paused") end)
connect(UIS.WindowFocused, function() focused = true; elapsed = 0.2 end)
connect(UIS.InputBegan, function(input, processed)
    if not processed and not UIS:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.RightShift then
        panel.Visible = not panel.Visible; reopen.Visible = not panel.Visible
        if panel.Visible then fit() end
    end
end)
connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = {input = input, start = input.Position, position = panel.Position}
    end
end)
connect(UIS.InputChanged, function(input)
    if dragging and (input == dragging.input or input.UserInputType == Enum.UserInputType.MouseMovement
        and dragging.input.UserInputType == Enum.UserInputType.MouseButton1) then
        local delta = input.Position - dragging.start
        panel.Position = UDim2.fromOffset(dragging.position.X.Offset + delta.X, dragging.position.Y.Offset + delta.Y)
        fit()
    end
end)
connect(UIS.InputEnded, function(input) if dragging and input == dragging.input then dragging = nil end end)
local viewport
connect(RunService.Heartbeat, function(dt)
    if not state.active then return end
    elapsed = elapsed + math.max(0, dt)
    if elapsed < 0.2 then return end
    elapsed = 0
    local camera = workspace.CurrentCamera
    if camera and camera.ViewportSize ~= viewport then viewport = camera.ViewportSize; fit() end
    local success, problem = pcall(refresh)
    if not success then
        clear()
        settings.enabled = false
        state.error = tostring(problem)
        renderToggles.enabled()
        warn("[Cold War ESP] Overlay paused: " .. state.error)
    end
    local message = "ESP off"
    if state.error then message = "Needs attention: " .. state.error
    elseif settings.enabled then
        message = (not focused or GuiService.MenuIsOpen or not camera) and "ESP paused" or
            (not settings.outlines and not settings.tags) and "Enable outlines or nametags" or
            string.format("%d players / %d studs", state.count, settings.range)
    end
    state.message = message
    status.Text = message .. "\n" .. (state.prediction or "Crosshair off")
end)
local predictionElapsed = 1
local function predictionStep(dt)
    if not state.active then return end
    predictionElapsed = predictionElapsed + math.max(0, dt)
    if not settings.crosshair then resetPrediction("Crosshair off"); return end
    if not focused or GuiService.MenuIsOpen or UIS:GetFocusedTextBox() then resetPrediction("Crosshair paused"); return end
    if state.crossError then resetPrediction("Crosshair error: " .. state.crossError); return end
    if predictionElapsed >= 1 / 20 then
        predictionElapsed = 0
        local launch, reason = shotState()
        if not launch then resetPrediction(reason); return end
        local point, kind, time, distance = Physics.predict(launch.origin, launch.direction, launch.speed,
            launch.decay, launch.gravity, launch.maxTime, launch.maxDistance, launch.params, dt)
        if not point then resetPrediction(kind); return end
        state.impact = {position = point, kind = kind, time = time, distance = distance,
            tool = launch.tool, character = launch.character, camera = launch.camera}
        state.prediction = string.format("%s / %.0f m / %s", launch.tool.Name, distance / 3.57, kind)
    end
    local impact = state.impact
    local camera = workspace.CurrentCamera
    local character = player.Character
    local human = character and character:FindFirstChildOfClass("Humanoid")
    if not impact or camera ~= impact.camera or character ~= impact.character or impact.tool.Parent ~= character
        or not human or human.Health <= 0 then resetPrediction("Waiting for current gun"); return end
    local point, onScreen = camera:WorldToViewportPoint(impact.position)
    if not onScreen or point.Z <= 0 then crossRoot.Visible = false; return end
    crossRoot.Position = UDim2.fromOffset(point.X, point.Y)
    local hex = settings.crossColor
    local color = Color3.fromRGB(tonumber(hex:sub(1,2),16), tonumber(hex:sub(3,4),16), tonumber(hex:sub(5,6),16))
    local size, width, gap = settings.size, settings.thickness, settings.gap
    crossDot.Visible = settings.shape == "Dot"
    crossDot.Size = UDim2.fromOffset(size, size)
    crossDot.BackgroundColor3 = color
    local positions = {
        {-gap-size, -width/2, size, width}, {gap, -width/2, size, width},
        {-width/2, -gap-size, width, size}, {-width/2, gap, width, size},
    }
    for i, arm in ipairs(crossArms) do
        local p = positions[i]
        arm.Visible = settings.shape == "Cross"
        arm.BackgroundColor3 = color
        arm.Position = UDim2.fromOffset(p[1], p[2])
        arm.Size = UDim2.fromOffset(p[3], p[4])
    end
    crossInfo.Visible = settings.info
    crossInfo.Text = string.format("%.0f m%s", impact.distance / 3.57, impact.kind == "Surface" and "" or " / limit")
    crossInfo.Position = UDim2.fromOffset(-100, gap + size + 3)
    crossRoot.Visible = true
end
connect(RunService.RenderStepped, function(dt)
    local ok, why = pcall(predictionStep, dt)
    if not ok then
        state.crossError = tostring(why)
        resetPrediction("Crosshair error: " .. state.crossError)
        warn("[Cold War visuals] " .. state.crossError)
    end
end)

return state
