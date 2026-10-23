const fs = require('node:fs');
const path = require('node:path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring} = require('fengari');
const root = path.resolve(__dirname,'..');
const state = lauxlib.luaL_newstate();
lualib.luaL_openlibs(state);
lua.lua_pushstring(state,to_luastring(fs.readFileSync(path.join(root,'centaura-silent.luau'),'utf8')));
lua.lua_setglobal(state,to_luastring('CENTAURA_SILENT_SOURCE'));
const rc = lauxlib.luaL_dostring(state,to_luastring(fs.readFileSync(path.join(__dirname,'centaura-silent.spec.lua'),'utf8')));
if(rc !== lua.LUA_OK) { console.error(to_jsstring(lua.lua_tostring(state,-1))); process.exitCode=1; }
lua.lua_close(state);
