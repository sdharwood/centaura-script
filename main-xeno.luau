-- Centaura compatibility revision. Runtime support depends on the executor.
if not game:IsLoaded() then game.Loaded:Wait() end
assert(type(getgenv) == "function", "Executor does not expose getgenv")
local env = getgenv()
env.sneeky_wallcheck = true
if env.sneeky_silent_aim == nil then env.sneeky_silent_aim = true end
if env.sneeky_compat_status then
    if env.sneeky_ui then env.sneeky_ui.show() end
    warn("[Centaura] Revision already loaded; wallcheck enabled. Rejoin before switching scripts.")
    return
end
local status = {installed = 0, calls = 0, redirected = 0, lastError = nil}
local function report(message, isError)
    if isError then status.lastError = message end
    warn("[Centaura] " .. message)
end
local cloneref = cloneref or function(value) return value end
local debuglib = debug or {}
local getEnvironment = getsenv
local readOne = debuglib.getupvalue or getupvalue
local readAll = debuglib.getupvalues or getupvalues
local writeOne = debuglib.setupvalue or setupvalue
local replaceFunction = hookfunction or hookfunc
assert(type(getEnvironment) == "function", "Executor lacks getsenv; cannot access Gun.Shoot")
assert(type(readAll) == "function" or type(readOne) == "function", "Executor lacks upvalue inspection")
assert(type(writeOne) == "function" or type(replaceFunction) == "function", "Executor lacks both setupvalue and hookfunction")
local function notify(message)
    report(message, false)
end

local Players: Players = cloneref(game:GetService("Players"));
local UIS: UserInputService = cloneref(game:GetService("UserInputService"));

local plr = Players.LocalPlayer;
local char = plr.Character;
local cam = workspace.CurrentCamera;


local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled;

local il = workspace:FindFirstChild("IgnoreList");
if not il then
    local err = "Script needs updating";
    report(err, true);
    return warn(err);
end;

local rp = RaycastParams.new();
rp.FilterType = Enum.RaycastFilterType.Exclude;
rp.IgnoreWater = true;

local isVisible = function(part: BasePart, origin: Vector3): (boolean, Instance?)
    if not (char and part) then return false, nil; end;

    rp.FilterDescendantsInstances = {char, il};

    local dir = part.Position - origin;
    local result: RaycastResult = workspace:Raycast(origin, dir, rp);
    if not result then return true, nil; end;

    if result.Instance:IsDescendantOf(part.Parent) then
        return true, result.Instance;
    end;

    return false, result.Instance;
end;

local getTarget = function(origin: Vector3)
    env.sneeky_wallcheck = true
    if not env.sneeky_silent_aim then return nil end
    cam = workspace.CurrentCamera
    if not cam then return nil end
    if typeof(origin) ~= "Vector3" then origin = cam.CFrame.Position end
    local cPart, cDistance = nil, getgenv().sneeky_fov_size or 300;

    for _, player: Player in next, Players:GetPlayers() do
        if player == plr or (plr.Team ~= nil and player.Team == plr.Team) then continue; end;

        local char = player.Character;
        if not char or char:FindFirstChildOfClass("ForceField") or (char:FindFirstChild("Humanoid") and char.Humanoid.Health <= 0) then continue; end;

        local tPart: BasePart = char:FindFirstChild("Head") or char.PrimaryPart or char:FindFirstChild("HumanoidRootPart");
        if not tPart then continue; end;

        local pos, onScreen = cam:WorldToViewportPoint(tPart.Position);
        if not onScreen then continue; end;

        if getgenv().sneeky_wallcheck then
            local v, nTPart = isVisible(tPart, origin);
            if not v then
                v, nTPart = isVisible(char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"), origin);
                if not v then continue; end;
            end;

            if nTPart then tPart = nTPart; end;
        end;

        local distance = (Vector2.new(pos.X, pos.Y) - (isMobile and Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2) or UIS:GetMouseLocation())).Magnitude;
        if distance < cDistance then
            cPart = tPart;
            cDistance = distance;
        end;
    end;

    return cPart;
end;

-- Built-in UI: no remote UI library or Drawing API required.
local interfaceGui
local function createInterface()
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")
    local gui = Instance.new("ScreenGui")
    interfaceGui = gui
    gui.Name = "CentauraControl"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local connections = {}
    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(connections, connection)
        return connection
    end
    local function cleanup()
        for _, connection in ipairs(connections) do connection:Disconnect() end
        table.clear(connections)
        env.sneeky_ui = nil
    end
    connect(gui.Destroying, cleanup)
    local parentOK = pcall(function()
        if type(gethui) == "function" then gui.Parent = gethui()
        else gui.Parent = plr:WaitForChild("PlayerGui") end
    end)
    if not parentOK or not gui.Parent then
        gui:Destroy()
        error("Could not attach the control panel")
    end
    local colors = {
        base = Color3.fromRGB(17, 21, 28), card = Color3.fromRGB(25, 30, 39),
        border = Color3.fromRGB(43, 51, 65), text = Color3.fromRGB(237, 242, 250),
        muted = Color3.fromRGB(146, 158, 179), accent = Color3.fromRGB(105, 219, 190),
        error = Color3.fromRGB(255, 159, 145),
    }
    local function make(className, properties, parent)
        local object = Instance.new(className)
        for key, value in pairs(properties) do object[key] = value end
        object.Parent = parent
        return object
    end
    local function round(object, radius)
        make("UICorner", {CornerRadius = UDim.new(0, radius)}, object)
    end
    local function border(object, color)
        return make("UIStroke", {Color = color or colors.border, Thickness = 1, Transparency = 0.15}, object)
    end
    local function text(parent, value, x, y, width, height, size, color, bold)
        return make("TextLabel", {
            BackgroundTransparency = 1, Text = value, Position = UDim2.fromOffset(x, y),
            Size = UDim2.new(width == -1 and 1 or 0, width == -1 and -40 or width, 0, height),
            TextColor3 = color or colors.text, TextSize = size or 14,
            Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, parent)
    end
    local function tween(object, properties)
        TweenService:Create(object, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties):Play()
    end
    local panel = make("Frame", {
        Name = "Panel", BackgroundColor3 = colors.base, Size = UDim2.fromOffset(360, 474),
        Position = UDim2.fromOffset(28, 100), Active = true,
    }, gui)
    round(panel, 16)
    border(panel)
    local scale = make("UIScale", {Scale = 1}, panel)
    local function fitPanel()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        scale.Scale = math.clamp(math.min((viewport.X - 24) / 360, (viewport.Y - 32) / 474), 0.4, 1)
        local width, height = 360 * scale.Scale, 474 * scale.Scale
        panel.Position = UDim2.fromOffset(
            math.clamp(panel.Position.X.Offset, 8, math.max(8, viewport.X - width - 8)),
            math.clamp(panel.Position.Y.Offset, 8, math.max(8, viewport.Y - height - 8)))
    end
    fitPanel()
    local header = make("Frame", {Name = "DragHandle", BackgroundTransparency = 1, Active = true,
        Size = UDim2.new(1, -60, 0, 82)}, panel)
    text(header, "CENTAURA", 20, 15, 210, 27, 19, colors.text, true)
    text(header, "Precision controls", 20, 44, 230, 20, 12, colors.muted)
    local minimize = make("TextButton", {
        Name = "Minimize", Text = "−", Font = Enum.Font.Gotham, TextSize = 24,
        TextColor3 = colors.muted, BackgroundColor3 = colors.card, AutoButtonColor = false,
        Position = UDim2.new(1, -52, 0, 21), Size = UDim2.fromOffset(32, 32),
    }, panel)
    round(minimize, 9)
    local separator = make("Frame", {BackgroundColor3 = colors.border, BorderSizePixel = 0,
        Position = UDim2.fromOffset(20, 82), Size = UDim2.new(1, -40, 0, 1)}, panel)
    local function toggleRow(name, subtitle, y, initial, onChanged)
        local row = make("TextButton", {
            Name = name, Text = "", AutoButtonColor = false, BackgroundColor3 = colors.card,
            Position = UDim2.fromOffset(20, y), Size = UDim2.new(1, -40, 0, 64),
        }, panel)
        round(row, 10)
        text(row, name, 14, 10, 228, 22, 14, colors.text, true)
        text(row, subtitle, 14, 34, 240, 16, 11, colors.muted)
        local track = make("Frame", {Size = UDim2.fromOffset(38, 22),
            Position = UDim2.new(1, -52, 0, 21), BackgroundColor3 = colors.border}, row)
        round(track, 11)
        local knob = make("Frame", {Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3),
            BackgroundColor3 = colors.text}, track)
        round(knob, 8)
        local enabled = initial
        local function render(animated)
            local trackProperties = {BackgroundColor3 = enabled and colors.accent or colors.border}
            local knobProperties = {Position = UDim2.fromOffset(enabled and 19 or 3, 3),
                BackgroundColor3 = enabled and colors.base or colors.text}
            if animated then tween(track, trackProperties); tween(knob, knobProperties)
            else
                for key, value in pairs(trackProperties) do track[key] = value end
                for key, value in pairs(knobProperties) do knob[key] = value end
            end
        end
        render(false)
        connect(row.Activated, function() enabled = not enabled; render(true); onChanged(enabled) end)
        return row
    end
    toggleRow("Silent aim", "Enable target redirection", 97, env.sneeky_silent_aim == true,
        function(value) env.sneeky_silent_aim = value end)
    if env.sneeky_show_fov == nil then env.sneeky_show_fov = true end
    toggleRow("Show radius", "Display the targeting area", 169, env.sneeky_show_fov == true,
        function(value) env.sneeky_show_fov = value end)
    local radiusCard = make("Frame", {Name = "Radius", BackgroundColor3 = colors.card,
        Position = UDim2.fromOffset(20, 241), Size = UDim2.new(1, -40, 0, 83)}, panel)
    round(radiusCard, 10)
    text(radiusCard, "Targeting radius", 14, 9, 200, 24, 14, colors.text, true)
    local radiusValue = text(radiusCard, "", 231, 9, 75, 24, 13, colors.accent, true)
    radiusValue.TextXAlignment = Enum.TextXAlignment.Right
    local slider = make("TextButton", {Name = "RadiusSlider", Text = "", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 25), AutoButtonColor = false}, radiusCard)
    local rail = make("Frame", {BorderSizePixel = 0, BackgroundColor3 = colors.border,
        Position = UDim2.new(0, 0, 0.5, -2), Size = UDim2.new(1, 0, 0, 4)}, slider)
    round(rail, 2)
    local fill = make("Frame", {BorderSizePixel = 0, BackgroundColor3 = colors.accent,
        Size = UDim2.fromScale(0, 1)}, rail)
    round(fill, 2)
    local handle = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = colors.accent,
        Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(13, 13)}, rail)
    round(handle, 7)
    local function setRadius(value)
        env.sneeky_fov_size = math.clamp(math.floor(value + 0.5), 40, 650)
        local amount = (env.sneeky_fov_size - 40) / 610
        fill.Size = UDim2.fromScale(amount, 1)
        handle.Position = UDim2.fromScale(amount, 0.5)
        radiusValue.Text = tostring(env.sneeky_fov_size) .. " px"
    end
    setRadius(tonumber(env.sneeky_fov_size) or 300)
    local locked = make("Frame", {BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 333), Size = UDim2.new(1, -40, 0, 30)}, panel)
    text(locked, "Wall check", 2, 0, 175, 28, 12, colors.muted)
    local badge = text(locked, "ALWAYS ON", 210, 0, 108, 28, 10, colors.accent, true)
    badge.TextXAlignment = Enum.TextXAlignment.Right
    local statusCard = make("Frame", {BackgroundColor3 = colors.card,
        Position = UDim2.fromOffset(20, 373), Size = UDim2.new(1, -40, 0, 57)}, panel)
    round(statusCard, 10)
    local dot = make("Frame", {BackgroundColor3 = colors.muted, Size = UDim2.fromOffset(6, 6),
        Position = UDim2.fromOffset(14, 16)}, statusCard)
    round(dot, 3)
    local stateLabel = text(statusCard, "Waiting for a gun", 28, 6, 278, 24, 12, colors.text, true)
    stateLabel.TextTruncate = Enum.TextTruncate.AtEnd
    local detail = text(statusCard, "Equip a gun to initialize", 14, 31, 292, 17, 10, colors.muted)
    detail.TextTruncate = Enum.TextTruncate.AtEnd
    text(panel, "Drag to move", 22, 441, 140, 18, 10, colors.muted)
    local shortcut = text(panel, isMobile and "Tap − to minimize" or "RIGHT SHIFT  /  SHOW · HIDE",
        158, 441, 180, 18, 9, colors.muted)
    shortcut.TextXAlignment = Enum.TextXAlignment.Right
    local reopen = make("TextButton", {Name = "Reopen", Text = "CENTAURA  +", Visible = false,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = colors.accent,
        BackgroundColor3 = colors.base, Position = UDim2.fromOffset(20, 100),
        Size = UDim2.fromOffset(150, 40), AutoButtonColor = false}, gui)
    round(reopen, 12)
    border(reopen)
    local ring = make("Frame", {Name = "RadiusCircle", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Size = UDim2.fromOffset(600, 600)}, gui)
    round(ring, 10000)
    make("UIStroke", {Color = colors.accent, Thickness = 1, Transparency = 0.45}, ring)
    local function showPanel(value)
        panel.Visible = value
        reopen.Visible = not value
        if value then fitPanel() end
    end
    connect(minimize.Activated, function() showPanel(false) end)
    connect(reopen.Activated, function() showPanel(true) end)
    local dragInput, dragStart, dragPosition, sliding
    connect(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragInput, dragStart, dragPosition = input, input.Position, panel.Position
        end
    end)
    local function sliderAt(x)
        if slider.AbsoluteSize.X <= 0 then return end
        local amount = math.clamp((x - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
        setRadius(40 + 610 * amount)
    end
    connect(slider.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = input
            sliderAt(input.Position.X)
        end
    end)
    connect(UIS.InputChanged, function(input)
        local moving = input.UserInputType == Enum.UserInputType.MouseMovement
        if sliding and (input == sliding or moving and sliding.UserInputType == Enum.UserInputType.MouseButton1) then
            sliderAt(input.Position.X)
        end
        if dragInput and (input == dragInput or moving and dragInput.UserInputType == Enum.UserInputType.MouseButton1) then
            local delta = input.Position - dragStart
            panel.Position = UDim2.fromOffset(dragPosition.X.Offset + delta.X, dragPosition.Y.Offset + delta.Y)
            fitPanel()
        end
    end)
    connect(UIS.InputEnded, function(input)
        if input == sliding then sliding = nil end
        if input == dragInput then dragInput = nil end
    end)
    connect(UIS.InputBegan, function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightShift and not UIS:GetFocusedTextBox() then
            showPanel(not panel.Visible)
        end
    end)
    local lastStatusUpdate = 0
    local lastViewport
    connect(RunService.RenderStepped, function(delta)
        env.sneeky_wallcheck = true
        local camera = workspace.CurrentCamera
        if not camera then ring.Visible = false; return end
        if camera.ViewportSize ~= lastViewport then lastViewport = camera.ViewportSize; fitPanel() end
        local radius = tonumber(env.sneeky_fov_size) or 300
        local center = isMobile and camera.ViewportSize / 2 or UIS:GetMouseLocation()
        ring.Position = UDim2.fromOffset(center.X, center.Y)
        ring.Size = UDim2.fromOffset(radius * 2, radius * 2)
        ring.Visible = env.sneeky_show_fov == true and env.sneeky_silent_aim == true
        lastStatusUpdate += delta
        if lastStatusUpdate < 0.2 then return end
        lastStatusUpdate = 0
        local label, description, color = "Waiting for a gun", "Equip a gun to initialize", colors.muted
        if status.lastError then
            label, description, color = "Needs attention", status.lastError, colors.error
        elseif not env.sneeky_silent_aim then
            label, description = "Paused", "Silent aim is switched off"
        elseif status.redirected > 0 then
            label, description, color = "Redirection observed", tostring(status.redirected) .. " redirected calls", colors.accent
        elseif status.calls > 0 then
            label, description, color = "Firing calls observed", "Waiting for an eligible visible target", colors.accent
        elseif status.installed > 0 then
            label, description = "Installed · awaiting fire", "Fire to check whether the hook is reached"
        end
        stateLabel.Text, detail.Text, dot.BackgroundColor3 = label, description, color
    end)
    env.sneeky_ui = {show = function() showPanel(true) end, destroy = function() gui:Destroy() end}
end
local uiOK, uiError = pcall(createInterface)
env.sneeky_wallcheck = true
if not uiOK then
    if interfaceGui then interfaceGui:Destroy() end
    report("UI load failed: " .. tostring(uiError), true)
end


-- Normalize executor APIs returning value versus Lua-style name, value.
local function upvalue(fn, index)
    if type(readOne) == "function" then
        local ok, first, second = pcall(readOne, fn, index)
        if ok then
            if second ~= nil then return second end
            return first
        end
    end
    if type(readAll) == "function" then
        local ok, values = pcall(readAll, fn)
        if ok and type(values) == "table" then return values[index] end
    end
    return nil
end
local function upvalues(fn)
    if type(readAll) == "function" then
        local ok, values = pcall(readAll, fn)
        if ok and type(values) == "table" then return values end
    end
    local values = {}
    -- Bounded inspection also handles a nil upvalue before another value.
    for index = 1, 128 do values[index] = upvalue(fn, index) end
    return values
end
local function metadata(fn)
    if type(debuglib.getinfo) == "function" then
        local ok, info = pcall(debuglib.getinfo, fn)
        if ok and type(info) == "table" then return info end
    end
    if type(debuglib.info) == "function" then
        local ok, line, name = pcall(debuglib.info, fn, "ln")
        if ok then return {linedefined = line, name = name} end
    end
    return {}
end
local function expectedPositionFunction(fn)
    if type(fn) ~= "function" then return false end
    local info = metadata(fn)
    return info.currentline == 574 or info.linedefined == 574
end
local function selectTarget(shoot)
    local functions = upvalues(shoot)
    local preferred = upvalue(shoot, 7)
    local candidates = {}
    if type(preferred) == "function" then
        table.insert(candidates, {fn = preferred, index = 7})
    end
    for index, value in pairs(functions) do
        if type(index) == "number" and type(value) == "function" and index ~= 7 then
            table.insert(candidates, {fn = value, index = index})
        end
    end
    for _, entry in ipairs(candidates) do
        local fn = entry.fn
        local values = upvalues(fn)
        local count = 0
        for index in pairs(values) do
            if type(index) == "number" then count = math.max(count, index) end
        end
        -- Retain the upstream identification rules; do not hook arbitrary functions.
        if count == 2 and (fn == preferred or type(preferred) ~= "function") then
            return fn, shoot, entry.index
        end
        if metadata(fn).name ~= "Melee" then
            for _, index in ipairs({15, 19}) do
                local value = upvalue(fn, index)
                if expectedPositionFunction(value) then return value, fn, index end
            end
            for index, value in pairs(values) do
                if type(index) == "number" and expectedPositionFunction(value) then
                    return value, fn, index
                end
            end
        end
    end
    return nil
end
local hooked = setmetatable({}, {__mode = "k"})
local pending = setmetatable({}, {__mode = "k"})
local function hookGun(gun)
    if hooked[gun] then return true end
    local environmentOK, scriptEnvironment = pcall(getEnvironment, gun)
    if not environmentOK or type(scriptEnvironment) ~= "table" then
        return false, "getsenv could not access Gun: " .. tostring(scriptEnvironment)
    end
    local shoot = rawget(scriptEnvironment, "Shoot")
    if type(shoot) ~= "function" then return false, "Gun.Shoot is not available yet" end
    local target, parent, index = selectTarget(shoot)
    if not target then
        return false, "Cannot identify the firing function: upvalues or line metadata do not match upstream"
    end
    local original = target
    local function replacement(origin, ...)
        status.calls += 1
        if status.calls == 1 then report("Hook observed a call from the game", false) end
        local ok, part = pcall(getTarget, origin)
        if ok and part and typeof(origin) == "Vector3" then
            status.redirected += 1
            return part.Position
        end
        if not ok and not status.targetError then
            status.targetError = tostring(part)
            report("Target selection failed: " .. tostring(part), true)
        end
        return original(origin, ...)
    end
    local method
    -- Updating the owner's reference avoids relying on hookfunction when setupvalue works.
    if type(writeOne) == "function" and upvalue(parent, index) == target then
        local ok = pcall(writeOne, parent, index, replacement)
        if ok and upvalue(parent, index) == replacement then method = "setupvalue" end
    end
    if not method and type(replaceFunction) == "function" then
        local wrapped = replacement
        if type(newcclosure) == "function" then
            local ok, closure = pcall(newcclosure, replacement)
            if ok and type(closure) == "function" then wrapped = closure end
        end
        local ok, old = pcall(replaceFunction, target, wrapped)
        if not ok then return false, "hookfunction failed: " .. tostring(old) end
        if type(old) ~= "function" then
            -- Do not retry an API that may already have modified the function.
            hooked[gun] = true
            return false, "hookfunction returned no callable original; rejoin before retrying"
        end
        original = old
        method = "hookfunction"
    end
    if not method then return false, "Executor could neither replace the upvalue nor hook the function" end
    hooked[gun] = true
    status.installed += 1
    notify("Gun hook installed via " .. method .. "; waiting for a firing call. Wallcheck is ON.")
    task.delay(15, function()
        if status.calls == 0 then
            report("No hook calls observed yet. Fire the gun; installation alone does not prove redirection works.", false)
        end
    end)
    return true
end
local function queueTool(tool, character)
    if not tool:IsA("Tool") or pending[tool] then return end
    pending[tool] = true
    task.spawn(function()
        local gun = tool:FindFirstChild("Gun") or tool:WaitForChild("Gun", 5)
        if not gun or not gun:IsA("LocalScript") then pending[tool] = nil; return end
        local lastError
        for attempt = 1, 8 do
            if plr.Character ~= character or not tool:IsDescendantOf(character) then break end
            local ok, installed, reason = pcall(hookGun, gun)
            if ok and installed then pending[tool] = nil; return end
            lastError = ok and reason or tostring(installed)
            if hooked[gun] then break end
            task.wait(0.35)
        end
        pending[tool] = nil
        if lastError then report(lastError, true) end
    end)
end
local childConnection
local function setup(character)
    if plr.Character ~= character then return end
    char = character
    if childConnection then childConnection:Disconnect() end
    childConnection = character.ChildAdded:Connect(function(child) queueTool(child, character) end)
    for _, child in ipairs(character:GetChildren()) do queueTool(child, character) end
end
env.sneeky_compat_status = status
plr.CharacterAdded:Connect(setup)
if plr.Character then setup(plr.Character) end
report("Compatibility revision loaded; equip a gun. Wallcheck is ON. Status: getgenv().sneeky_compat_status", false)
