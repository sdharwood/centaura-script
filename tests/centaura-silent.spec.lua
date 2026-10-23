-- Run from the repository root with Lua 5.3+ (or Fengari).
-- Roblox services and the executor hook are simulated; no live compatibility claim.
local SOURCE = assert(CENTAURA_SILENT_SOURCE, "runner must supply CENTAURA_SILENT_SOURCE")
local function signal()
    local s = {handlers = {}}
    function s:Connect(fn)
        local c = {active = true, fn = fn}
        function c:Disconnect() self.active = false end
        table.insert(self.handlers, c)
        return c
    end
    function s:Fire(...)
        for _, c in ipairs(self.handlers) do if c.active then c.fn(...) end end
    end
    return s
end
local vector = {}
vector.__index = function(v, key)
    if key == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + (v.Z or 0)^2) end
    if key == "Unit" then return v / v.Magnitude end
end
local function vec(x, y, z) return setmetatable({X=x, Y=y, Z=z or 0, kind="Vector3"}, vector) end
vector.__add = function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vector.__sub = function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vector.__mul = function(a,b) return vec(a.X*b,a.Y*b,a.Z*b) end
vector.__div = function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
Vector3 = {new=vec}
Vector2 = {new=function(x,y) return vec(x,y) end}
local function dim(x,y) return {X={Offset=x},Y={Offset=y}} end
UDim2 = {fromOffset=dim, fromScale=dim, new=function(_,x,_,y) return dim(x,y) end}
UDim = {new=function(a,b) return {Scale=a,Offset=b} end}
Color3 = {fromRGB=function(...) return {...} end}
Enum = setmetatable({}, {__index=function(t,k)
    local e=setmetatable({}, {__index=function(_,v) return k.."."..v end}); rawset(t,k,e); return e
end})
local objects = {}
local function object(class, name, parent)
    local o = {ClassName=class,Name=name or class,Parent=parent,Children={},Visible=true,
        Position=dim(0,0),AbsoluteSize=vec(350,540),Activated=signal(),InputBegan=signal()}
    function o:IsA(c) return self.ClassName==c or (c=="BasePart" and self.ClassName=="Part") end
    function o:FindFirstChild(n) for _,c in ipairs(self.Children) do if c.Name==n then return c end end end
    function o:WaitForChild(n) return assert(self:FindFirstChild(n),n) end
    function o:FindFirstChildOfClass(c) for _,child in ipairs(self.Children) do if child.ClassName==c then return child end end end
    function o:IsDescendantOf(ancestor)
        local p=self.Parent
        while p do if p==ancestor then return true end; p=p.Parent end
        return false
    end
    function o:Destroy() self.destroyed=true; for _,c in ipairs(self.Children) do c:Destroy() end end
    if parent then table.insert(parent.Children,o) end
    table.insert(objects,o)
    return o
end
Instance={new=function(c) return object(c) end}
RaycastParams={new=function() return {} end}
typeof=function(v) return type(v)=="table" and v.kind or type(v) end
math.clamp=function(x,a,b) return math.max(a,math.min(b,x)) end
local environment={}
getgenv=function() return environment end
warn=function() end
task={spawn=function(fn) fn() end}
identifyexecutor=function() return "simulated executor" end
newcclosure=function(f) return f end
local wrappers={}
local hookCount=0
hookfunction=function(fn, replacement) hookCount=hookCount+1; wrappers[fn]=replacement; return fn end
local localPlayer=object("Player","Local")
localPlayer.Neutral=false
local teamA,teamB={},{}
localPlayer.Team=teamA
object("PlayerGui","PlayerGui",localPlayer)
local scripts=object("Folder","PlayerScripts",localPlayer)
local ballistics=object("Folder","BallisticsClient",scripts)
object("ModuleScript","ClientFire",ballistics)
local function character(owner, x, y)
    local char=object("Model",owner.Name.."Char")
    local root=object("Part","HumanoidRootPart",char); root.Position=vec(x,y,10)
    local head=object("Part","Head",char); head.Position=vec(x,y,10)
    local human=object("Humanoid","Humanoid",char); human.Health=100
    owner.Character=char; char.PrimaryPart=root
    return char,human,root
end
character(localPlayer,0,0)
local enemy=object("Player","Enemy"); enemy.DisplayName="Enemy"; enemy.Team=teamB; enemy.Neutral=false
local enemyChar,enemyHuman=character(enemy,100,100)
local playerList={localPlayer,enemy}
local players={LocalPlayer=localPlayer,PlayerRemoving=signal(),GetPlayers=function() return playerList end}
local ui={TouchEnabled=false,MouseEnabled=true,WindowFocusReleased=signal(),WindowFocused=signal(),
    InputBegan=signal(),InputEnded=signal(),InputChanged=signal(),
    GetMouseLocation=function() return vec(100,136) end,GetFocusedTextBox=function() return nil end}
local rs={Heartbeat=signal(),RenderStepped=signal()}
local gs={GetGuiInset=function() return vec(0,36) end,MenuIsOpen=false}
workspace={CurrentCamera={ViewportSize=vec(1280,720),CFrame={Position=vec(0,0,0)},
    WorldToViewportPoint=function(_,position) return position,true end},
    FindFirstChild=function() return nil end,Raycast=function() return nil end}
local services={Players=players,UserInputService=ui,RunService=rs,GuiService=gs}
game={IsLoaded=function() return true end,GetService=function(_,n) return assert(services[n],n) end,PlaceId=123}
local tool=object("Tool","Rifle",localPlayer.Character)
local gun=object("LocalScript","Gun",tool)
local barrel=object("Part","Barrel",tool); barrel.Position=vec(0,-1,1)
local originals=0
local captured
local function spread(...)
    originals=originals+1; captured=table.pack(...); return captured[1],"original",nil,"tail"
end
local function semi() end
local function shootRoot() end
local functionNames={[spread]="getSpread"}
local functionUpvalues={[spread]={tool,0.1},[semi]={spread},[shootRoot]={semi}}
debug.info=function(fn) return functionNames[fn] end
debug.getupvalues=function(fn) return functionUpvalues[fn] or {} end
getsenv=function() return {Shoot=shootRoot} end
local checks=0
local function check(condition,description) assert(condition,description);checks=checks+1 end
local function click(label)
    for i=#objects,1,-1 do local o=objects[i]
        if not o.destroyed and o.ClassName=="TextButton" and o.Text==label then o.Activated:Fire();return end
    end
    error("button missing: "..label)
end
local function execute() assert(load(SOURCE,"centaura-silent.luau"))(); return environment.SDH_CentauraSilent_v1 end
local state=execute()
check(not state.settings.silent and not state.settings.esp and state.settings.tags,"defaults")
click("Attach / retry")
check(hookCount==1 and state.message:find("Attached to getSpread",1,true),"identify named function and owning tool")
local point=vec(50,0,100)
local function shoot(p) return wrappers[spread](p or point,false) end
local a,b,c,d=shoot()
check(a==point and b=="original" and c==nil and d=="tail" and originals==1,"disabled forwards args and all returns")
state.settings.silent=true
local hit=shoot()
check(state.redirects==1 and hit.X==100 and originals==1,"clear raycasts redirect aimpoint, not origin")
local baseline=state.redirects
local function blockedCheck(rule,label)
    workspace.Raycast=rule
    local before=originals
    shoot()
    check(state.redirects==baseline and originals==before+1,label.." | redirects="..state.redirects.." baseline="..baseline.." originals="..originals.." expected="..(before+1).." "..state.message)
    workspace.Raycast=function() return nil end
end
blockedCheck(function(_,origin) if origin.Y==-1 then return {Instance=object("Part","BarrelWall")} end end,"barrel obstruction blocks")
blockedCheck(function(_,origin) if origin.Z==10 then return {Instance=object("Part","HeadWall")} end end,"head obstruction blocks")
blockedCheck(function(_,origin) if origin.X==0 and origin.Y==0 and origin.Z==0 then return {Instance=object("Part","CameraWall")} end end,"camera obstruction blocks")
blockedCheck(function() return {Instance=object("Part","Terrain")} end,"all obstruction blocks")
workspace.Raycast=function() return {Instance=enemyChar:FindFirstChild("Head")} end
shoot();check(state.redirects==baseline+1,"target body hits remain visible")
workspace.Raycast=function() return nil end
baseline=state.redirects
local before=originals
wrappers[spread]("wrong",false)
check(originals==before+1 and state.redirects==baseline,"wrong aimpoint type forwards once")
ui.WindowFocusReleased:Fire();shoot()
check(state.redirects==baseline,"focus gating")
ui.WindowFocused:Fire()
enemy.Team=teamA;shoot();check(state.redirects==baseline,"team gating")
enemy.Team=teamB;enemyHuman.Health=0;shoot();check(state.redirects==baseline,"health gating")
enemyHuman.Health=100
local force=object("ForceField","ForceField",enemyChar)
shoot();check(state.redirects==baseline,"forcefield gating")
force:Destroy();force.Parent=nil
for i,c in ipairs(enemyChar.Children) do if c==force then table.remove(enemyChar.Children,i);break end end
state.settings.fov=40
enemyChar:FindFirstChild("Head").Position=vec(300,300,10)
enemyChar.PrimaryPart.Position=vec(300,300,10)
shoot();check(state.redirects==baseline,"outside radius")
enemyChar:FindFirstChild("Head").Position=vec(100,100,10)
enemyChar.PrimaryPart.Position=vec(100,100,10)
state.settings.fov=180
local originalParent=tool.Parent;tool.Parent=nil;shoot()
check(state.redirects==baseline,"unequipped gun does not redirect")
tool.Parent=originalParent
state.settings.esp=true;rs.Heartbeat:Fire(0.3)
check(state.visuals[enemy]~=nil,"ESP creates")
click("ESP nametags    ON");rs.Heartbeat:Fire(0.3)
check(state.visuals[enemy].label.Enabled==false and not state.visuals[enemy].highlight.destroyed,"nametags off keeps outlines")
click("ESP nametags    OFF");rs.Heartbeat:Fire(0.3)
check(state.visuals[enemy].label.Enabled==true,"nametags reenable")
state.settings.esp=false;rs.Heartbeat:Fire(0.3)
check(next(state.visuals)==nil,"ESP disable cleans")
state.settings.esp=true;rs.Heartbeat:Fire(0.3)
enemy.Team=teamA;rs.Heartbeat:Fire(0.3)
check(next(state.visuals)==nil,"ESP team cleanup")
enemy.Team=teamB
local old=state
state=execute();click("Attach / retry")
check(not old.active and hookCount==1 and not state.settings.silent,"reload cleanup and bridge reuse")
state.settings.silent=true;shoot();check(state.redirects==1,"reload hook uses current controller")
state.unload();before=originals;shoot()
check(originals==before+1 and captured[1]==point and next(state.visuals)==nil,"unload pass-through")
functionNames[spread]="Unknown"
state=execute();click("Attach / retry")
check(hookCount==1 and state.message:find("Cannot identify",1,true),"unknown function name refuses hooking")
state.unload();functionNames[spread]="getSpread"
functionUpvalues[spread]={object("Tool","WrongGun"),0.1}
state=execute();click("Attach / retry")
check(hookCount==1 and state.message:find("Cannot identify",1,true),"wrong owner refuses hooking")
state.unload();functionUpvalues[spread]={tool,0.1}
local otherSpread=function() end
functionNames[otherSpread]="getSpread";functionUpvalues[otherSpread]={tool,0.1}
functionUpvalues[semi]={spread,otherSpread}
state=execute();click("Attach / retry")
check(hookCount==1 and state.message:find("Ambiguous",1,true),"ambiguous matching functions refuse hooking")
state.unload();functionUpvalues[semi]={spread}
getsenv=nil
getgc=function() return {spread} end
getfenv=function() return {script=gun} end
state=execute();click("Attach / retry")
check(state.tool==tool and hookCount==1,"GC fallback matches exact script and owning tool")
state.unload()
getfenv=function() return {script=object("LocalScript","Unrelated")} end
state=execute();click("Attach / retry")
check(state.tool==nil,"GC fallback rejects unrelated script")
state.unload()
hookfunction=nil
state=execute();click("Attach / retry")
check(state.message:find("Missing hookfunction",1,true),"missing hook diagnostic")
state.settings.esp=true;rs.Heartbeat:Fire(0.3)
check(state.visuals[enemy]~=nil,"ESP independent of missing hook")
state.unload()
print("PASS: "..checks.." Centaura silent-aim simulation checks")
