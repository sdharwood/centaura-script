const fs=require('node:fs');
const path=require('node:path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const root=path.resolve(__dirname,'..');
const L=lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
lua.lua_pushstring(L,to_luastring(fs.readFileSync(path.join(root,'cold-war-esp.luau'),'utf8')));
lua.lua_setglobal(L,to_luastring('COLD_WAR_ESP_SOURCE'));
const rc=lauxlib.luaL_dostring(L,to_luastring(fs.readFileSync(path.join(__dirname,'cold-war-esp.spec.lua'),'utf8')));
if(rc!==lua.LUA_OK){console.error(to_jsstring(lua.lua_tostring(L,-1)));process.exitCode=1;}
lua.lua_close(L);
