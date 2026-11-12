// Lance integration.lua : charge toutes les sources Luau (shared/server/client) + le mini-moteur.
const fs = require('fs'), path = require('path');
const fengari = require(process.env.FENGARI_PATH || 'fengari');
const { lua, lauxlib, lualib, to_luastring } = fengari;
const src = path.join(__dirname, '..', 'src');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
function pushDir(dir) {
  lua.lua_newtable(L);
  for (const f of fs.readdirSync(path.join(src, dir))) {
    if (!f.endsWith('.luau')) continue;
    lua.lua_pushstring(L, to_luastring(fs.readFileSync(path.join(src, dir, f), 'utf8')));
    lua.lua_setfield(L, -2, to_luastring(f.replace(/\.luau$/, '')));
  }
}
lua.lua_newtable(L);
for (const d of ['shared', 'server', 'client']) { pushDir(d); lua.lua_setfield(L, -2, to_luastring(d)); }
lua.lua_setglobal(L, to_luastring('SRC'));
lua.lua_pushstring(L, to_luastring(fs.readFileSync(path.join(__dirname, 'roblox_mock.lua'), 'utf8')));
lua.lua_setglobal(L, to_luastring('MOCK_SRC'));
const code = fs.readFileSync(path.join(__dirname, 'integration.lua'), 'utf8');
if (lauxlib.luaL_loadstring(L, to_luastring(code)) !== 0 || lua.lua_pcall(L, 0, 1, 0) !== 0) {
  console.error('Erreur Lua :', fengari.to_jsstring(lua.lua_tostring(L, -1)));
  process.exit(2);
}
process.exit(lua.lua_tointeger(L, -1) === 0 ? 0 : 1);
