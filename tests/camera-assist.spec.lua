-- Runs the actual entrypoint against a small Roblox API simulation.
-- Supply its source as the global SOURCE; see tests/README.md.
local tests, assertions = 0, 0
local function expect(condition, message)
    assertions = assertions + 1
    assert(condition, message or "Expectation failed")
end
math.clamp = function(value, low, high) return math.min(high, math.max(low, value)) end
local vector = {}
vector.__index = function(self, key)
    if key == "Magnitude" then return math.sqrt(self.X ^ 2 + self.Y ^ 2 + (self.Z or 0) ^ 2) end
    if key == "Unit" then return self / self.Magnitude end
end
vector.__add = function(a, b) return setmetatable({X=a.X+b.X, Y=a.Y+b.Y, Z=(a.Z or 0)+(b.Z or 0)}, vector) end
vector.__sub = function(a, b) return setmetatable({X=a.X-b.X, Y=a.Y-b.Y, Z=(a.Z or 0)-(b.Z or 0)}, vector) end
vector.__div = function(a, b) return setmetatable({X=a.X/b, Y=a.Y/b, Z=(a.Z or 0)/b}, vector) end
vector.__mul = function(a, b) return setmetatable({X=a.X*b, Y=a.Y*b, Z=(a.Z or 0)*b}, vector) end
Vector2 = {new=function(x,y) return setmetatable({X=x,Y=y}, vector) end}
Vector3 = {new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vector) end}
UDim = {new=function(s,o) return {Scale=s,Offset=o} end}
UDim2 = {
    new=function(xs,xo,ys,yo) return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo)} end,
    fromOffset=function(x,y) return {X=UDim.new(0,x),Y=UDim.new(0,y)} end,
    fromScale=function(x,y) return {X=UDim.new(x,0),Y=UDim.new(y,0)} end,
}
Color3 = {fromRGB=function(r,g,b) return {r,g,b} end}
Enum = {
    Font={Gotham="Gotham",GothamBold="GothamBold"},
    TextXAlignment={Left="Left",Right="Right"}, TextTruncate={AtEnd="AtEnd"},
    ZIndexBehavior={Sibling="Sibling"}, RaycastFilterType={Exclude="Exclude"},
    UserInputType={MouseButton1="MB1",MouseButton2="MB2",MouseMovement="Move",Touch="Touch"},
    KeyCode={RightShift="RightShift"}, CameraType={Scriptable="Scriptable",Custom="Custom"},
    RenderPriority={Camera={Value=200}},
}
RaycastParams = {new=function() return {} end}
local frame = {}
frame.__index = frame
function frame:Lerp(wanted, alpha)
    return setmetatable({Position=self.Position, LookVector=wanted.LookVector, lastAlpha=alpha}, frame)
end
CFrame = {lookAt=function(position,target)
    return setmetatable({Position=position,LookVector=(target-position).Unit}, frame)
end}
local signals
local function signal()
    local event = {listeners={}}
    function event:Connect(callback)
        local connection = {Connected=true,callback=callback}
        function connection:Disconnect() self.Connected=false end
        table.insert(self.listeners, connection)
        return connection
    end
    function event:Fire(...)
        for _, connection in ipairs(self.listeners) do
            if connection.Connected then connection.callback(...) end
        end
    end
    function event:Wait() end
    table.insert(signals, event)
    return event
end
local methods, objectMeta = {}, {}
objectMeta.__index = function(self,key)
    if key == "Parent" then return rawget(self,"_parent") end
    if key == "AbsolutePosition" then
        local parent = self.Parent
        local position, size = parent and parent.AbsolutePosition or Vector2.new(0,0), parent and parent.AbsoluteSize or Vector2.new(1920,1080)
        return position + Vector2.new(self.Position.X.Offset+self.Position.X.Scale*size.X, self.Position.Y.Offset+self.Position.Y.Scale*size.Y)
    end
    if key == "AbsoluteSize" then
        if self.ClassName == "ScreenGui" then return Vector2.new(1920,1080) end
        local size = self.Parent and self.Parent.AbsoluteSize or Vector2.new(1920,1080)
        return Vector2.new(self.Size.X.Offset+self.Size.X.Scale*size.X,self.Size.Y.Offset+self.Size.Y.Scale*size.Y)
    end
    return methods[key]
end
objectMeta.__newindex = function(self,key,value)
    if key ~= "Parent" then rawset(self,key,value); return end
    local old = rawget(self,"_parent")
    if old then
        for index, child in ipairs(old.children) do if child == self then table.remove(old.children,index); break end end
    end
    rawset(self,"_parent",value)
    if value then table.insert(value.children,self) end
end
function methods:IsA(class)
    return self.ClassName == class or class == "BasePart" and self.ClassName == "Part"
end
function methods:GetChildren() return self.children end
function methods:FindFirstChild(name)
    for _, child in ipairs(self.children) do if child.Name == name then return child end end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),"Missing mock child: "..name) end
function methods:FindFirstChildOfClass(class)
    for _, child in ipairs(self.children) do if child.ClassName == class then return child end end
end
function methods:IsDescendantOf(parent)
    local current = self.Parent
    while current do if current == parent then return true end; current = current.Parent end
    return false
end
function methods:Destroy()
    if self.destroyed then return end
    self.destroyed = true
    self.Destroying:Fire()
    local children = {}; for _, child in ipairs(self.children) do table.insert(children,child) end
    for _, child in ipairs(children) do child:Destroy() end
    self.Parent = nil
end
Instance = {new=function(class)
    local object = setmetatable({ClassName=class,Name=class,children={},Visible=true,
        Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(0,0)},objectMeta)
    object.Destroying, object.Activated, object.InputBegan = signal(),signal(),signal()
    return object
end}
local world, players, input, run, menu, me, enemy, team, wall, warnings, rayRule
local function named(class,name,parent)
    local object = Instance.new(class); object.Name=name; object.Parent=parent; return object
end
local function character(name,x,y,z)
    local model = named("Model",name,world)
    local humanoid = named("Humanoid","Humanoid",model); humanoid.Health=100
    local head = named("Part","Head",model); head.Position=Vector3.new(x,y,z)
    local root = named("Part","HumanoidRootPart",model); root.Position=Vector3.new(x,y-2,z)
    model.PrimaryPart=root
    return model
end
local function newPlayer(name,x)
    local p = named("Player",name,players); p.DisplayName=name; p.Character=character(name,x,0,100)
    p.Team={}; p.CharacterAdded=signal(); return p
end
local function camera()
    local cam = named("Camera","Camera",world)
    cam.ViewportSize=Vector2.new(1920,1080); cam.CameraType=Enum.CameraType.Custom
    cam.CFrame=CFrame.lookAt(Vector3.new(0,0,0),Vector3.new(0,0,100))
    function cam:WorldToViewportPoint(position)
        local x,y=self.ViewportSize.X/2+position.X,self.ViewportSize.Y/2-position.Y
        return Vector3.new(x,y,position.Z), position.Z>0 and x>=0 and y>=0 and x<=self.ViewportSize.X and y<=self.ViewportSize.Y
    end
    return cam
end
local function setup()
    signals={}; warnings={}; rayRule=nil
    shared={}; getgenv=nil; getsenv=nil; getgc=nil; getconnections=nil; hookfunction=nil
    world=named("Workspace","Workspace",nil); workspace=world
    players=named("Players","Players",nil); input={MouseEnabled=true,held=false,mouse=Vector2.new(1800,900)}
    for _, name in ipairs({"InputBegan","InputEnded","InputChanged","WindowFocusReleased","WindowFocused"}) do input[name]=signal() end
    function input:GetFocusedTextBox() return self.textbox end
    function input:GetMouseLocation() return self.mouse end
    function input:IsMouseButtonPressed(button) expect(button==Enum.UserInputType.MouseButton2); return self.held end
    run={bindings={}}; menu={MenuIsOpen=false}
    function run:BindToRenderStep(name,priority,callback) self.bindings[name]={callback=callback,priority=priority} end
    function run:UnbindFromRenderStep(name) self.bindings[name]=nil end
    world.CurrentCamera=camera()
    function world:Raycast(origin,direction,params)
        expect(params.FilterType==Enum.RaycastFilterType.Exclude and params.IgnoreWater)
        expect(params.FilterDescendantsInstances[1]==me.Character and params.FilterDescendantsInstances[2]==self.CurrentCamera)
        return rayRule and rayRule(origin,origin+direction,params) or nil
    end
    named("Folder","IgnoreList",world)
    me=newPlayer("Local",0); players.LocalPlayer=me; team={}; me.Team=team
    named("PlayerGui","PlayerGui",me)
    local tool=named("Tool","Rifle",me.Character)
    local barrel=named("Part","Barrel",tool); barrel.Position=Vector3.new(0,-1,1)
    enemy=newPlayer("Enemy",60)
    function players:GetPlayers() return self.children end
    wall=named("Part","Wall",world)
    local services={Players=players,UserInputService=input,RunService=run,GuiService=menu}
    game={Loaded=signal(),IsLoaded=function() return true end,GetService=function(_,name) return assert(services[name],name) end}
    warn=function(message) table.insert(warnings,message) end
end
local function start() return assert(load(SOURCE,"main-xeno.luau","t",_G))() end
local function step(dt)
    for _, binding in pairs(run.bindings) do binding.callback(dt or 1/60) end
end
local function ui(name)
    local function search(object)
        if object.Name==name then return object end
        for _, child in ipairs(object.children) do local result=search(child); if result then return result end end
    end
    return search(me:FindFirstChild("PlayerGui"))
end
local function activeConnections()
    local count=0
    for _, event in ipairs(signals) do for _, c in ipairs(event.listeners) do if c.Connected then count=count+1 end end end
    return count
end
local function test(name, body)
    setup(); body(); tests=tests+1; print("PASS "..name)
end

test("starts with no executor introspection APIs; requires RMB",function()
    local api=start(); step(); expect(api.Status.message=="Ready"); expect(api.Status.cameraUpdates==0)
    input.held=true; step(); expect(api.Status.target=="Enemy"); expect(api.Status.cameraUpdates==1)
    expect(run.bindings.CentauraCameraAssistV2.priority==201)
    expect(world.CurrentCamera.CFrame.Position.X==0)
    input.held=false; step(); expect(api.Status.target==nil and api.Status.message=="Ready")
end)
test("chooses nearest eligible enemy and retains valid held target",function()
    local friend=newPlayer("Friend",1); friend.Team=team
    local distant=newPlayer("Distant",160)
    local api=start(); input.held=true; step(); expect(api.Status.target=="Enemy")
    local closer=newPlayer("Closer",2); step(); expect(api.Status.target=="Enemy")
    enemy.Character:FindFirstChild("Humanoid").Health=0; step(); expect(api.Status.target==closer.Name)
    closer.Team=team; step(); expect(api.Status.target==distant.Name)
end)
test("dead and protected enemies are excluded",function()
    enemy.Character:FindFirstChild("Humanoid").Health=0
    local protected=newPlayer("Protected",2); named("ForceField","ForceField",protected.Character)
    local api=start(); input.held=true; step(); expect(api.Status.target==nil)
end)
test("rejects targets outside radius, behind camera or offscreen",function()
    local api=start(); input.held=true; api.Config.Radius=40; step(); expect(api.Status.target==nil)
    enemy.Character:FindFirstChild("Head").Position=Vector3.new(1,0,-1)
    enemy.Character:FindFirstChild("HumanoidRootPart").Position=Vector3.new(1,0,-1)
    step(); expect(api.Status.target==nil)
    enemy.Character:FindFirstChild("Head").Position=Vector3.new(1100,0,100)
    enemy.Character:FindFirstChild("HumanoidRootPart").Position=Vector3.new(1100,0,100)
    api.Config.Radius=650; step(); expect(api.Status.target==nil)
end)
test("root fallback when head absent",function()
    enemy.Character:FindFirstChild("Head"):Destroy()
    local api=start(); input.held=true; step(); expect(api.Status.target=="Enemy")
end)
test("checks camera and muzzle walls and drops newly occluded lock",function()
    local api=start(); input.held=true; step(); expect(api.Status.target=="Enemy")
    rayRule=function() return {Instance=wall} end
    step(); expect(api.Status.target==nil)
    rayRule=function(origin) if origin.Y==-1 then return {Instance=wall} end end
    step(); expect(api.Status.target==nil, "Muzzle obstruction must block assistance")
    rayRule=nil; step(); expect(api.Status.target=="Enemy")
end)
test("falls back to visible root and accepts target body ray hits",function()
    rayRule=function(_,endpoint)
        if endpoint.Y==0 then return {Instance=wall} end
        return {Instance=enemy.Character:FindFirstChild("HumanoidRootPart")}
    end
    local api=start(); input.held=true; step(); expect(api.Status.target=="Enemy")
end)
test("focus, typing, menus and panel interactions pause aim",function()
    local api=start(); input.held=true; step(); local updates=api.Status.cameraUpdates
    input.WindowFocusReleased:Fire(); step(); expect(api.Status.cameraUpdates==updates)
    input.WindowFocused:Fire(); input.textbox={}; step(); expect(api.Status.cameraUpdates==updates)
    input.textbox=nil; menu.MenuIsOpen=true; step(); expect(api.Status.cameraUpdates==updates)
    menu.MenuIsOpen=false; input.mouse=Vector2.new(50,100); step(); expect(api.Status.cameraUpdates==updates)
    input.mouse=Vector2.new(1800,900); step(); expect(api.Status.cameraUpdates==updates+1)
end)
test("death, unequip and respawn recover automatically",function()
    local api=start(); input.held=true; step()
    me.Character:FindFirstChild("Humanoid").Health=0; step(); expect(api.Status.message=="Waiting for spawn")
    me.Character=character("Respawn",0,0,100); me.CharacterAdded:Fire(me.Character)
    step(); expect(api.Status.message=="Equip a gun")
    local tool=named("Tool","Rifle",me.Character); local barrel=named("Part","Barrel",tool); barrel.Position=Vector3.new(0,-1,1)
    step(); expect(api.Status.target=="Enemy")
    tool.Parent=nil; step(); expect(api.Status.message=="Equip a gun")
end)
test("camera replacement and scriptable camera are handled",function()
    local api=start(); input.held=true
    world.CurrentCamera=nil; step(); expect(api.Status.message=="Waiting for camera")
    world.CurrentCamera=camera(); world.CurrentCamera.CameraType=Enum.CameraType.Scriptable
    step(); expect(api.Status.message=="Camera paused")
    world.CurrentCamera.CameraType=Enum.CameraType.Custom; step(); expect(api.Status.target=="Enemy")
end)
test("toggles, minimize, reopen and keyboard controls work",function()
    local api=start(); input.held=true
    ui("AssistToggle").Activated:Fire(); step(); expect(api.Status.message=="Paused")
    ui("AssistToggle").Activated:Fire(); step(); expect(api.Status.target=="Enemy")
    ui("RadiusToggle").Activated:Fire(); step(); expect(not ui("RadiusCircle").Visible)
    ui("Minimize").Activated:Fire(); expect(not ui("Panel").Visible and ui("Reopen").Visible)
    ui("Reopen").Activated:Fire(); expect(ui("Panel").Visible)
    input.InputBegan:Fire({KeyCode=Enum.KeyCode.RightShift},true); expect(ui("Panel").Visible)
    input.InputBegan:Fire({KeyCode=Enum.KeyCode.RightShift},false); expect(not ui("Panel").Visible)
end)
test("sliders update clamped values; drag and focus loss release input",function()
    local api=start()
    local slider=ui("RadiusSlider")
    local press={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector3.new(slider.AbsolutePosition.X,0,0)}
    slider.InputBegan:Fire(press); expect(api.Config.Radius==40)
    input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector3.new(10000,0,0)})
    expect(api.Config.Radius==650)
    input.InputEnded:Fire(press)
    local strength=ui("StrengthSlider")
    press={UserInputType=Enum.UserInputType.Touch,Position=Vector3.new(strength.AbsolutePosition.X+strength.AbsoluteSize.X,0,0)}
    strength.InputBegan:Fire(press); expect(api.Config.Strength==30)
    input.WindowFocusReleased:Fire(); input.WindowFocused:Fire()
    local panel=ui("Panel"); local old=panel.Position
    press={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector3.new(20,20,0)}
    ui("DragHandle").InputBegan:Fire(press)
    input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector3.new(40,40,0)})
    expect(panel.Position.X.Offset==old.X.Offset+20)
    input.InputEnded:Fire(press)
    input.held=true; step(); expect(api.Status.target=="Enemy")
end)
test("rerun replaces listeners and preserves settings; unload removes everything",function()
    local api=start(); local count=activeConnections(); local oldGui=ui("CentauraCameraAssist")
    api.Config.Radius=450
    local replacement=start(); expect(oldGui.destroyed and api.Status.message=="Unloaded")
    expect(replacement.Config.Radius==450); expect(activeConnections()==count)
    input.held=true; step(); local updates=replacement.Status.cameraUpdates
    ui("Unload").Activated:Fire(); step()
    expect(activeConnections()==0 and shared.centaura_camera_assist==nil)
    expect(next(run.bindings)==nil and replacement.Status.cameraUpdates==updates)
end)
test("external GUI destruction also cleans up",function()
    start(); ui("CentauraCameraAssist"):Destroy()
    expect(activeConnections()==0 and next(run.bindings)==nil and shared.centaura_camera_assist==nil)
end)
test("runtime error appears once and can recover after toggling",function()
    local api=start(); input.held=true
    rayRule=function() error("Simulated raycast failure") end
    step(); expect(api.Status.lastError and api.Status.message=="Needs attention")
    local count=#warnings; step(); expect(#warnings==count)
    rayRule=nil
    ui("AssistToggle").Activated:Fire(); ui("AssistToggle").Activated:Fire()
    step(); expect(api.Status.lastError==nil and api.Status.target=="Enemy")
end)
test("legacy script requires rejoin and creates no second controller",function()
    shared.sneeky_compat_status={installed=0}; expect(start()==nil)
    expect(next(run.bindings)==nil and shared.centaura_camera_assist==nil)
    expect(warnings[1]:find("Rejoin first",1,true)~=nil)
end)
test("optional getgenv failures fall back to shared",function()
    getgenv=function() error("Unavailable") end
    local api=start(); expect(shared.centaura_camera_assist==api)
end)
test("smoothing parameters are consistent at 30, 60 and 144 FPS",function()
    local previousRemaining
    for _, fps in ipairs({30,60,144}) do
        setup(); local api=start(); input.held=true; local remaining=1
        for _=1,fps do step(1/fps); remaining=remaining*(1-world.CurrentCamera.CFrame.lastAlpha) end
        expect(api.Status.cameraUpdates==fps)
        if previousRemaining then expect(math.abs(remaining-previousRemaining)<0.000000001) end
        previousRemaining=remaining
    end
end)
print(string.format("PASS: %d scenarios, %d assertions",tests,assertions))
