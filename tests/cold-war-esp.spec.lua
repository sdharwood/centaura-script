-- Run from the repository root with Lua 5.3+ (or Fengari).
-- Roblox services and the executor hook are simulated; no live compatibility claim.
local SOURCE = assert(COLD_WAR_ESP_SOURCE, "runner must supply COLD_WAR_ESP_SOURCE")
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
        Position=dim(0,0),AbsoluteSize=vec(350,540),Activated=signal(),InputBegan=signal(),Destroying=signal()}
    function o:IsA(c) return self.ClassName==c or (c=="BasePart" and self.ClassName=="Part") end
    function o:FindFirstChild(n) for _,c in ipairs(self.Children) do if c.Name==n then return c end end end
    function o:WaitForChild(n) return assert(self:FindFirstChild(n),n) end
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
local function execute() return assert(load(SOURCE,"cold-war-esp.luau"))() end
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
local gui=ui("ColdWarESP");gui:Destroy()
check(not state.active and next(state.visuals)==nil and environment.SDH_ColdWarESP_v1==nil,"external GUI destruction unloads")
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
print("PASS: "..checks.." Cold War ESP checks")
