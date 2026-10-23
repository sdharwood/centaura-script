-- Run from the repository root with Lua 5.3+ (or Fengari).
-- Roblox services and the executor hook are simulated; no live compatibility claim.
local SOURCE = assert(COLD_WAR_VISUALS_SOURCE, "runner must supply COLD_WAR_VISUALS_SOURCE")
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
    local o = {ClassName=class,Name=name or class,Children={},Visible=true,
        Position=dim(0,0),AbsoluteSize=vec(350,540),Activated=signal(),InputBegan=signal(),FocusLost=signal(),Destroying=signal()}
    function o:IsA(c) return self.ClassName==c or (c=="BasePart" and self.ClassName=="Part") end
    function o:FindFirstChild(n) for _,c in ipairs(self.Children) do if c.Name==n then return c end end end
    function o:WaitForChild(n) return assert(self:FindFirstChild(n),n) end
    function o:GetChildren() return self.Children end
    function o:FindFirstChildOfClass(c) for _,child in ipairs(self.Children) do if child.ClassName==c then return child end end end
    function o:IsDescendantOf(ancestor)
        local p=self.Parent
        while p do if p==ancestor then return true end; p=p.Parent end
        return false
    end
    setmetatable(o,{
        __index=function(t,k) if k=="Parent" then return rawget(t,"_parent") end end,
        __newindex=function(t,k,v)
            if k~="Parent" then rawset(t,k,v);return end
            local old=rawget(t,"_parent")
            if old and old.Children then for i,c in ipairs(old.Children) do if c==t then table.remove(old.Children,i);break end end end
            rawset(t,"_parent",v)
            if v then v.Children=v.Children or {};table.insert(v.Children,t) end
        end
    })
    function o:Destroy()
        if self.destroyed then return end
        self.destroyed=true
        self.Destroying:Fire()
        while #self.Children>0 do self.Children[1]:Destroy() end
        self.Parent=nil
    end
    if parent then o.Parent=parent end
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
    local char=object("Model",owner.Name.."Char");char.Parent={Children={}}
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
localPlayer.Parent=players;enemy.Parent=players
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

local checks=0
local function check(condition,message) assert(condition,message);checks=checks+1 end
local function ui(name)
    for i=#objects,1,-1 do local o=objects[i];if not o.destroyed and o.Name==name then return o end end
end
local function click(name) assert(ui(name),"missing UI: "..name).Activated:Fire() end
local function step() rs.Heartbeat:Fire(0.21) end
local function execute() return assert(load(SOURCE,"cold-war-visuals.luau"))() end
-- These deliberately fail if the overlay tries to alter weapons or inspect source.
hookfunction=function() error("weapon hook attempted") end
decompile=function() error("decompile attempted") end
getgc=function() error("GC scan attempted") end
getsenv=function() error("script inspection attempted") end
local state=execute()
check(not state.settings.enabled and not state.settings.tags and state.settings.outlines,"default off; nametags independent")
step();check(next(state.visuals)==nil,"no default visuals")
click("EnabledToggle");step()
check(state.count==1 and state.visuals[enemy].highlight~=nil,"enemy outline")
check(state.visuals[enemy].billboard==nil,"nametags create no objects while off")
click("TagsToggle");step()
local visual=state.visuals[enemy]
check(visual.billboard and visual.label.Text:find("Enemy",1,true) and visual.label.RichText==false,"enable plain-text nametags")
check(visual.label.Text:find("100 HP",1,true) and visual.label.Text:find("studs",1,true),"health and distance")
click("HealthToggle");click("DistanceToggle");step()
check(visual.label.Text=="Enemy","details independently disabled")
click("TagsToggle");step()
check(visual.billboard==nil and visual.highlight and not visual.highlight.destroyed,"hide nametags keeps outline")
click("OutlineToggle");step()
check(state.count==0 and next(state.visuals)==nil,"no visual modes clears entries")
click("TagsToggle");step()
check(state.visuals[enemy].billboard and not state.visuals[enemy].highlight,"tag-only mode")
click("OutlineToggle");click("FillToggle");step()
check(state.visuals[enemy].highlight.FillTransparency==0.87,"soft fill")
local priorColor=state.visuals[enemy].highlight.FillColor
click("ColorButton");step()
check(state.visuals[enemy].highlight.FillColor~=priorColor,"colour updates")
enemy.Team=teamA;step();check(state.count==0,"teammates hidden")
click("TeammateToggle");step();check(state.count==1,"teammates opt-in")
click("TeammateToggle");enemy.Team=teamB
enemyHuman.Health=0;step();check(state.count==0,"dead players hidden")
enemyHuman.Health=100;local force=object("ForceField","ForceField",enemy.Character)
step();check(state.count==0,"protected players hidden")
force:Destroy()
local root=enemy.Character.PrimaryPart
root.Position=vec(2000,0,10);step();check(state.count==0,"range filter")
root.Position=vec(100,100,10);step();check(state.count==1,"range recovery")
local oldVisual=state.visuals[enemy].highlight
character(enemy,110,100);step()
check(oldVisual.destroyed and state.visuals[enemy].character==enemy.Character,"respawn replaces adornments")
-- Use the actual mocked service for focus/menu checks.
services.UserInputService.WindowFocusReleased:Fire()
check(state.count==0,"focus loss clears immediately")
services.UserInputService.WindowFocused:Fire();step();check(state.count==1,"focus recovery")
gs.MenuIsOpen=true;step();check(state.count==0,"menu pause")
gs.MenuIsOpen=false;step()
local cam=workspace.CurrentCamera
workspace.CurrentCamera=nil;step();check(state.count==0,"missing camera")
workspace.CurrentCamera=cam;step()
click("Minimize");check(not ui("Panel").Visible and ui("Reopen").Visible,"collapse panel")
click("Reopen");check(ui("Panel").Visible,"reopen")
services.UserInputService.InputBegan:Fire({KeyCode=Enum.KeyCode.RightShift},false)
check(not ui("Panel").Visible,"keyboard toggle")
click("Reopen")
enemy.Parent=nil
players.PlayerRemoving:Fire(enemy);check(state.visuals[enemy]==nil,"departure clears immediately")
enemy.Parent=players;step()
click("EnabledToggle");check(state.count==0,"master off clears immediately")
local oldState=state;state=execute()
check(not oldState.active and not state.settings.enabled and state.settings.palette==2,"reload cleanup and settings preservation")
local active=0
for _,connection in ipairs(rs.Heartbeat.handlers) do if connection.active then active=active+1 end end
check(active==1,"reload leaves one update listener")
click("EnabledToggle");step();check(state.count==1,"replacement works")
local gui=ui("ColdWarVisuals");gui:Destroy()
check(not state.active and next(state.visuals)==nil and environment.SDH_ColdWarVisuals_v1==nil,"external GUI destruction unloads")
local originalNew=Instance.new
Instance.new=function(class) if class=="BillboardGui" then error("simulated label failure") end;return originalNew(class) end
state=execute();click("EnabledToggle");click("TagsToggle");step()
check(not state.settings.enabled and state.error and next(state.visuals)==nil,"partial creation failure cleans highlights and disables ESP")
Instance.new=originalNew
click("EnabledToggle");step()
check(state.count==1 and not state.error,"explicit retry recovers")
state.unload()
check(next(state.visuals)==nil and not state.active,"unload cleanup")
active=0
for _,connection in ipairs(rs.Heartbeat.handlers) do if connection.active then active=active+1 end end
check(active==0,"unload disconnects updates")

-- Ballistic crosshair integration. Module APIs and state mirror the uploaded source.
local frame={}
frame.__index=frame
local function cf(position,look)
    return setmetatable({Position=position,LookVector=look or vec(0,0,1)},frame)
end
frame.__mul=function(a,b)
    if b.angle then return cf(a.Position,vec(0,math.sin(b.angle),math.cos(b.angle))) end
    error("unsupported CFrame multiply in mock")
end
CFrame={Angles=function(angle) return {angle=angle} end}
local storage=object("Folder","ReplicatedStorage")
services.ReplicatedStorage=storage
local client=object("Folder","Client",storage)
local tools=object("Folder","Tools",client)
local wm=object("ModuleScript","Weapon",tools)
local controls=object("Folder","controllers",wm)
local zeroScript=object("ModuleScript","ZeroController",controls)
local viewScript=object("ModuleScript","WeaponViewmodel",controls)
local sharedFolder=object("Folder","Shared",storage)
local groupsScript=object("ModuleScript","CollisionGroups",sharedFolder)
local tool=object("Tool","Rifle",localPlayer.Character)
local handle=object("Part","Handle",tool)
local attachment=object("Attachment","Muzzle1",handle)
attachment.WorldPosition=vec(0,2,1)
attachment.WorldCFrame=cf(attachment.WorldPosition)
local viewAttach=object("Attachment","Muzzle1",handle)
viewAttach.WorldPosition=vec(5,3,2)
viewAttach.WorldCFrame=cf(viewAttach.WorldPosition)
local bullet={MuzzleVelocity=100,Drag=0.1}
local muzzle={attachment=attachment,viewmodelAttachment=viewAttach,config={DefaultAngle=10,BulletSettings={bullet}}}
function muzzle:getBulletIndex() return 1 end
local weapon={tool=tool,currentMuzzle=muzzle,currentMuzzleIndex=1}
local angle=0
local zeroFn=function() return angle end
local zero={zeroAngle=zeroFn}
local viewShown=false
local modules={
    [zeroScript]=zero,
    [viewScript]={isShown=function() return viewShown end},
    [groupsScript]={teamRayGroup=function() return "RayTeamTest" end},
}
require=function(module) return assert(modules[module],"unexpected module require") end
debug.getupvalues=function(fn) if fn==zeroFn then return {{weapon=weapon,units={}}} end;return {} end
workspace.Gravity=196.2
local cam=workspace.CurrentCamera
cam.CFrame=cf(vec(0,0,0))
cam.Focus=cf(vec(0,0,10))
state=execute()
local P=state.Physics
local origin,dir=vec(0,2,0),vec(0,0,1)
local p=P.position(origin,dir,100,0,10,2)
check(math.abs(p.Z-200)<1e-8 and math.abs(p.Y+18)<1e-8,"zero drag parabolic flight")
p=P.position(origin,dir,100,0.5,10,2)
check(math.abs(p.Z-200*(1-math.exp(-1)))<1e-8 and math.abs(p.Y+18)<1e-8,"exported exponential decay model")
local launch=state.ShotState()
check(launch.tool==tool and launch.speed==100 and launch.decay==0.1 and launch.gravity==196.2,"active ammo profile")
check(launch.direction.Y==0,"zero angle of zero overrides nonzero DefaultAngle")
angle=0.2
launch=state.ShotState()
check(math.abs(launch.direction.Y-math.sin(0.2))<1e-8,"live zeroing angle affects direction")
angle=0
cam.Focus=cf(vec(0,0,0.1));viewShown=true
launch=state.ShotState()
check(launch.origin.X==5 and launch.origin.Y==3,"shown first-person viewmodel muzzle")
viewShown=false;launch=state.ShotState()
check(launch.origin.X==0 and launch.origin.Y==2,"hidden viewmodel uses physical muzzle")
cam.Focus=cf(vec(0,0,10))
local ignore=object("Folder","Ignore")
local tracer=object("Folder","Tracers",ignore)
local duds=object("Folder","Duds",ignore)
local originalFind=workspace.FindFirstChild
workspace.FindFirstChild=function(_,name) return name=="Ignore" and ignore or nil end
workspace.Raycast=function() return nil end
launch=state.ShotState()
check(launch.params.IgnoreWater==false and launch.params.CollisionGroup=="RayTeamTest","weapon collision group and water")
local hasTracer,hasDuds=false,false
for _,o in ipairs(launch.params.FilterDescendantsInstances) do if o==tracer then hasTracer=true end;if o==duds then hasDuds=true end end
check(hasTracer and not hasDuds,"Arming exclusion rules preserve live duds")
local calls=0
workspace.Raycast=function(_,a,d,params)
    calls=calls+1
    if a.Z<20 and a.Z+d.Z>=20 then
        local fraction=(20-a.Z)/d.Z
        return {Position=a+d*fraction,Distance=(d*fraction).Magnitude}
    end
end
local position,kind=P.predict(origin,dir,100,0,0,5,5000,launch.params,1/60)
check(kind=="Surface" and math.abs(position.Z-20)<1e-8,"predict first obstructing surface")
check(calls<20,"stop raycasts once impact found")
workspace.Raycast=function() return nil end
position,kind=P.predict(origin,dir,100,0,0,5,25,launch.params,1/60)
check(kind=="Range limit" and math.abs(position.Z-25)<1e-7,"arc-length range limit")
position,kind=P.predict(origin,dir,100,0,0,0.5,5000,launch.params,1/60)
check(kind=="Lifetime limit" and math.abs(position.Z-50)<1e-7,"lifetime limit")
local oldCalls=calls
position,kind=P.predict(origin,dir,0,0,0,5,5000,launch.params,1/60)
check(not position and kind=="Invalid launch","zero speed rejected")
check(not state.settings.crosshair,"crosshair starts off")
click("CrosshairToggle")
rs.RenderStepped:Fire(1/60)
check(state.impact and state.prediction:find("Rifle",1,true),"crosshair predicts active weapon")
local marker=ui("DynamicCrosshair")
check(marker.Visible and marker.Position.Y.Offset~=cam.ViewportSize.Y/2,"crosshair moves to ballistic point")
click("ShapeButton");rs.RenderStepped:Fire(1/60)
check(ui("CrossDot").Visible and not ui("CrossArm1").Visible,"dot style")
local box=ui("SizeBox");box.Text="14";box.FocusLost:Fire()
check(state.settings.size==14,"custom size")
box=ui("ThicknessBox");box.Text="99";box.FocusLost:Fire()
check(state.settings.thickness==8,"thickness clamps")
box=ui("GapBox");box.Text="garbage";box.FocusLost:Fire()
check(state.settings.gap==3,"invalid size text preserves prior value")
box=ui("CrossColorBox");box.Text="#ff8800";box.FocusLost:Fire()
check(state.settings.crossColor=="FF8800","custom hex colour")
box.Text="invalid";box.FocusLost:Fire()
check(state.settings.crossColor=="FF8800","invalid colour rejected")
click("InfoToggle");rs.RenderStepped:Fire(1/60)
check(not ui("CrossInfo").Visible,"range label toggles")
services.UserInputService.WindowFocusReleased:Fire()
check(not marker.Visible and not state.impact,"focus hides prediction")
services.UserInputService.WindowFocused:Fire();rs.RenderStepped:Fire(0.1)
check(state.impact~=nil,"focus recovery")
gs.MenuIsOpen=true;rs.RenderStepped:Fire(1/60)
check(not marker.Visible,"menu gating")
gs.MenuIsOpen=false;rs.RenderStepped:Fire(0.1)
tool.Parent=nil;rs.RenderStepped:Fire(1/60)
check(not marker.Visible,"unequip hides stale impact")
tool.Parent=localPlayer.Character;rs.RenderStepped:Fire(0.1)
local oldCam=workspace.CurrentCamera
workspace.CurrentCamera=nil;rs.RenderStepped:Fire(1/60)
check(not marker.Visible,"camera loss hides")
workspace.CurrentCamera=oldCam;rs.RenderStepped:Fire(0.1)
local originalReader=debug.getupvalues
debug.getupvalues=function() return {} end
rs.RenderStepped:Fire(0.1)
check(not marker.Visible and state.prediction=="Current weapon data is unavailable","unsupported state does not fake centered crosshair")
debug.getupvalues=originalReader
rs.RenderStepped:Fire(0.1)
check(state.impact~=nil,"state discovery recovers")
local arm=object("Part","Right Arm",localPlayer.Character)
arm.CFrame=cf(vec(0,2,0))
workspace.Raycast=function(_,a,d,params)
    if a.Y==2 and math.abs(d.Z-1)<0.001 then return {Position=vec(0,2,0.5),Distance=0.5} end
end
launch=state.ShotState()
check(math.abs(launch.origin.Z-0.49)<1e-8,"source muzzle wall-push origin correction")
workspace.Raycast=function() return nil end
state.unload()
local count=0
for _,c in ipairs(rs.RenderStepped.handlers) do if c.active then count=count+1 end end
check(count==0,"unload disconnects prediction rendering")
check(not marker.Parent and marker.destroyed,"unload removes marker")
print("PASS: "..checks.." Cold War visuals checks")

