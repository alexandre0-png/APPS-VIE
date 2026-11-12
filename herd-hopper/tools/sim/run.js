// Lance la simulation serveur dans fengari (Lua 5.3 en JS). Usage : node run.js [A|B|C|CLIENT]
const fs = require('fs'), path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');
const root = path.join(__dirname, '..', '..', 'src');
const scenario = process.argv[2] || 'A';
function walk(d) { return fs.readdirSync(d, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(path.join(d, e.name)) : [path.join(d, e.name)]); }
let defs = 'SOURCES = {}\n';
for (const f of walk(root).filter(f => f.endsWith('.luau'))) {
  let key = path.relative(root, f).replace(/\\/g, '/').replace(/\.(server\.|client\.)?luau$/, '');
  const src = fs.readFileSync(f, 'utf8');
  if (src.includes(']==]')) throw new Error('séparateur interdit dans ' + f);
  defs += `SOURCES[${JSON.stringify(key)}] = [==[${src}]==]\n`;
}
defs += `SOURCES["../tests/pure.spec"] = [==[${fs.readFileSync(path.join(__dirname, '..', '..', 'tests', 'pure.spec.luau'), 'utf8')}]==]\n`;
defs += `SCENARIO = ${JSON.stringify(scenario)}\n`;
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
let code = defs + fs.readFileSync(path.join(__dirname, 'harness.lua'), 'utf8');
if (lauxlib.luaL_dostring(L, to_luastring(code)) !== 0) {
  console.error('Erreur Lua :', lua.lua_tojsstring(L, -1));
  process.exit(1);
}
