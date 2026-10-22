-- Run from the repository root with Lua 5.3+ (or Fengari).
-- Roblox services and the executor hook are simulated; no live compatibility claim.
local SOURCE = assert(COLD_WAR_SOURCE, "runner must supply COLD_WAR_SOURCE")
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
local originals=0
local captured
local function volley(...)
    originals=originals+1; captured=table.pack(...); return "ok",nil,"tail"
end
local cf={fire=function() end,fireVolley=volley}
require=function() return cf end
local checks=0
local function check(condition,description) assert(condition,description);checks=checks+1 end
local function click(label)
    for i=#objects,1,-1 do local o=objects[i]
        if not o.destroyed and o.ClassName=="TextButton" and o.Text==label then o.Activated:Fire();return end
    end
    error("button missing: "..label)
end
local function execute() assert(load(SOURCE,"cold-war.luau"))(); return environment.SDH_ColdWar_v1 end
local state=execute()
check(not state.settings.silent and not state.settings.esp,"safe defaults")
click("Attach / retry")
check(hookCount==1 and state.message:find("Attached: fireVolley",1,true),"select named volley")
local dirs={vec(0,0,5)}
local function shoot(d) return wrappers[volley](nil,nil,nil,vec(0,0,0),d or dirs) end
local a,b,c=shoot()
check(a=="ok" and b==nil and c=="tail" and captured[5]==dirs,"disabled forwarding and return values")
state.settings.silent=true
shoot()
check(state.redirects==1 and captured[5]~=dirs,"clear raycast still redirects with copied directions")
check(math.abs(captured[5][1].Magnitude-5)<0.00001 and dirs[1].X==0,"preserve vector magnitude and original input")
local before=originals
shoot({"invalid"})
check(originals==before+1 and state.redirects==1,"invalid directions forward exactly once")
ui.WindowFocusReleased:Fire();shoot()
check(state.redirects==1,"focus gating")
ui.WindowFocused:Fire()
enemy.Team=teamA;shoot()
check(state.redirects==1,"exclude teammates")
enemy.Team=teamB;enemyHuman.Health=0;shoot()
check(state.redirects==1,"exclude dead targets")
enemyHuman.Health=100
workspace.Raycast=function() return {Instance=object("Part","Wall")} end
shoot();check(state.redirects==1,"walls block redirection")
workspace.Raycast=function() return nil end
state.settings.esp=true;rs.Heartbeat:Fire(0.3)
check(state.visuals[enemy]~=nil,"ESP creates enemy visual")
state.settings.esp=false;rs.Heartbeat:Fire(0.3)
check(next(state.visuals)==nil,"ESP toggle removes visuals")
state.settings.esp=true;rs.Heartbeat:Fire(0.3)
enemy.Team=teamA;rs.Heartbeat:Fire(0.3)
check(next(state.visuals)==nil,"ESP team change cleanup")
enemy.Team=teamB
local oldState=state
state=execute();click("Attach / retry")
check(not oldState.active and hookCount==1,"reload reuses hook bridge")
check(not state.settings.silent,"reload clears silent aim opt-in")
state.settings.silent=true;shoot()
check(state.redirects==1,"reload redirects to current controller")
state.unload();before=originals;shoot()
check(not state.active and next(state.visuals)==nil and originals==before+1 and captured[5]==dirs,"unload passes through and cleans visuals")
cf={fire=function() end,first=function() end,second=function() end}
state=execute();click("Attach / retry")
check(state.message:find("Ambiguous exports",1,true) and hookCount==1,"ambiguous exports do not auto-hook")
state.unload();hookfunction=nil
state=execute();click("Attach / retry")
check(state.message:find("Missing hookfunction",1,true),"missing hook remains diagnosable")
state.settings.esp=true;rs.Heartbeat:Fire(0.3)
check(state.visuals[enemy]~=nil,"ESP works without weapon hook")
state.unload()
print("PASS: "..checks.." Cold War simulation checks")
