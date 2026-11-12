// Lance specs.lua dans une VM Lua (fengari) avec les sources Luau injectées.
// Usage : node run.js  (nécessite `npm i fengari` dans un dossier accessible)
const fs = require('fs'), path = require('path');
const fengari = require(process.env.FENGARI_PATH || 'fengari');
const { lua, lauxlib, lualib, to_luastring } = fengari;
const src = path.join(__dirname, '..', 'src');
const files = { Config: 'shared/Config.luau', Util: 'shared/Util.luau', DinoShapes: 'shared/DinoShapes.luau', Economy: 'shared/Economy.luau', Anim: 'shared/Anim.luau', CinematicLogic: 'shared/CinematicLogic.luau', DataService: 'server/DataService.luau' };
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
lua.lua_newtable(L);
for (const [name, rel] of Object.entries(files)) {
  lua.lua_pushstring(L, to_luastring(fs.readFileSync(path.join(src, rel), 'utf8')));
  lua.lua_setfield(L, -2, to_luastring(name));
}
lua.lua_setglobal(L, to_luastring('SRC'));
const code = fs.readFileSync(path.join(__dirname, 'specs.lua'), 'utf8');
if (lauxlib.luaL_loadstring(L, to_luastring(code)) !== 0 || lua.lua_pcall(L, 0, 1, 0) !== 0) {
  console.error('Erreur Lua :', fengari.to_jsstring(lua.lua_tostring(L, -1)));
  process.exit(2);
}
process.exit(lua.lua_tointeger(L, -1) === 0 ? 0 : 1);
