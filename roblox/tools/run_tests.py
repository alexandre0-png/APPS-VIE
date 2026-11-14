#!/usr/bin/env python3
"""Exécute roblox/tests/run.luau SANS Lune, avec un interpréteur Lua (module Python `lupa`, qui embarque Lua 5.5 dans sa version actuelle).
Alternative pour les environnements où Lune n'est pas disponible. Adaptations (les tests ne portent que sur de la logique pure) :
  - les affectations composées de Luau (`x += 1`) sont converties en Lua 5.4 ;
  - `require("@lune/fs" | "@lune/luau" | "@lune/process")` et `luau.load` sont simulés.
Limites : c'est du Lua 5.x, pas Luau (les petites différences de sémantique, comme `math.floor` entier, sont sans effet ici).
Installation : pip install --only-binary :all: lupa     Usage : python3 roblox/tools/run_tests.py"""
import os, re, sys
try:
    from lupa import LuaRuntime
except ImportError:
    print("lupa manquant : pip install --only-binary :all: lupa")
    sys.exit(2)

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
COMPOUND = re.compile(r"^(\s*)([A-Za-z_][\w.\[\]\"']*)\s*([+\-*/%^])=\s*(.+?)\s*$")

def luau_to_lua(src):
    out = []
    for line in src.split("\n"):
        m = COMPOUND.match(line)
        if m and not line.lstrip().startswith("--"):
            indent, lhs, op, rhs = m.groups()
            line = f"{indent}{lhs} = {lhs} {op} ({rhs})"
        out.append(line)
    return "\n".join(out)

lua = LuaRuntime(unpack_returned_tuples=True)

def read_file(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()

lua.globals().py_read = read_file
lua.globals().py_convert = luau_to_lua

prelude = r'''
local exit_code = 0
table.clone = table.clone or function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end -- Luau seulement
local function shim_load(src, opts)
	local env = setmetatable((opts and opts.environment) or {}, { __index = _G })
	local fn, err = load(py_convert(src), (opts and opts.debugName) or "chunk", "t", env)
	if not fn then error(err) end
	return fn
end
local shims = {
	["@lune/fs"] = { readFile = function(p) return py_read(p) end },
	["@lune/luau"] = { load = shim_load },
	["@lune/process"] = { exit = function(c) exit_code = c; error("__EXIT__") end },
}
function require(name) return shims[name] or error("require inconnu : " .. tostring(name)) end
return function(src)
	local env = setmetatable({}, { __index = _G })
	local fn, err = load(py_convert(src), "run.luau", "t", env)
	if not fn then error(err) end
	local ok, e = pcall(fn)
	if not ok and not tostring(e):find("__EXIT__", 1, true) then error(e) end
	return exit_code
end
'''
runner = lua.execute(prelude)
try:
    code = runner(read_file("roblox/tests/run.luau"))
except Exception as e:  # erreur d'exécution Lua (ex. index sur nil dans un test) : pas de trace brute, échec explicite
    print("ERREUR D'EXÉCUTION dans les tests :", str(e).split("\n")[0][:300])
    print("code de sortie : 1")
    sys.exit(1)
print("code de sortie :", code)
sys.exit(int(code or 0))
