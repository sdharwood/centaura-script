-- Cold War ESP v1.0.0: local visual overlay only.
-- No weapon hooks, introspection, remote calls, shot changes or external UI libraries.
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
local KEY = "SDH_ColdWarESP_v1"
local previous = env[KEY]
local old = type(previous) == "table" and previous.settings or {}
if type(old) ~= "table" then old = {} end
-- Unload our previous overlay and earlier controllers; no scanning or editing game scripts.
if type(previous) == "table" and type(previous.unload) == "function" then previous.unload() end
if type(env.SDH_ColdWar_v1) == "table" and type(env.SDH_ColdWar_v1.unload) == "function" then
    env.SDH_ColdWar_v1.unload()
end
local function bounded(value, fallback, low, high)
    value = tonumber(value)
    if not value or value ~= value then value = fallback end
    return math.clamp(value, low, high)
end
local settings = {
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
local gui, worldFolder
function state.unload()
    if not state.active then return end
    state.active = false
    for _, connection in ipairs(state.links) do connection:Disconnect() end
    state.links = {}
    clear()
    if worldFolder then worldFolder:Destroy() end
    if gui then gui:Destroy() end
    if env[KEY] == state then env[KEY] = nil end
end
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
    gui = make("ScreenGui", {Name = "ColdWarESP", ResetOnSpawn = false, IgnoreGuiInset = false,
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
    local subtitle = label(header, "PLAYER ESP  /  Right Shift: show or hide", 10, muted)
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
    status.Size = UDim2.new(1, -8, 0, 44)
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
connect(UIS.WindowFocusReleased, function() focused = false; dragging = nil; clear() end)
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
    status.Text = message
end)
return state
