#!/usr/bin/env python3
"""Exécute roblox/tests/lot12a.luau (moteur de combat refait : Battle.lua) SANS Lune, avec lupa (même logique que run_lot15.py : conversion des `+=`,
simulation de `@lune/fs`, `@lune/luau`, `@lune/process`). Le fichier de test attend `env = { check, suite, luau, fs }`.
Usage : python3 roblox/tests/run_lot12a.py [chemin/vers/racine]   (racine = dossier PARENT de `roblox/`, par défaut le parent de ce dépôt)
Limites : Lua 5.x, pas Luau (voir run_tests.py). Ne remplace pas un playtest Studio."""
import os, re, signal, sys
try:
    from lupa import LuaRuntime
except ImportError:
    print("lupa manquant : pip install --only-binary :all: lupa")
    sys.exit(2)

ROOT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
COMPOUND = re.compile(r"^(\s*)([A-Za-z_][\w.\[\]\"']*)\s*([+\-*/%^])=\s*(.+?)\s*$")

def luau_to_lua(src):
    out = []
    for line in src.split("\n"):
        m = COMPOUND.match(line)
        if m and not line.lstrip().startswith("--"):
            indent, lhs, op, rhs = m.groups()
            comment = ""
            cut = rhs.find(" --")
            if cut >= 0:
                rhs, comment = rhs[:cut].rstrip(), rhs[cut:]
            line = f"{indent}{lhs} = {lhs} {op} ({rhs}){comment}"
        out.append(line)
    return "\n".join(out)

lua = LuaRuntime(unpack_returned_tuples=True)

def read_file(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()

lua.globals().py_read = read_file
lua.globals().py_convert = luau_to_lua

prelude = r'''
table.clone = table.clone or function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end
local function shim_load(src, opts)
	local env = setmetatable((opts and opts.environment) or {}, { __index = _G })
	local fn, err = load(py_convert(src), (opts and opts.debugName) or "chunk", "t", env)
	if not fn then error(err) end
	return fn
end
local shims = {
	["@lune/fs"] = { readFile = function(p) return py_read(p) end },
	["@lune/luau"] = { load = shim_load },
}
function require(name) return shims[name] or error("require inconnu : " .. tostring(name)) end
return function()
	local fs, luau = require("@lune/fs"), require("@lune/luau")
	local passed, failed = 0, 0
	local function suite(name) print("  > " .. name) end
	local function check(name, cond)
		if cond then passed = passed + 1 else failed = failed + 1; print("  ECHEC : " .. name) end
	end
	luau.load(fs.readFile("roblox/tests/lot12a.luau"), { debugName = "lot12a" })()({ check = check, suite = suite, luau = luau, fs = fs })
	print(string.format("%d assertions réussies, %d échecs", passed, failed))
	return failed
end
'''
def _timeout(signum, frame):
    print("TIMEOUT global (900 s)")
    sys.stdout.flush()
    os._exit(3)
signal.signal(signal.SIGALRM, _timeout)
signal.alarm(900)
runner = lua.execute(prelude)
try:
    failed = runner()
except Exception as e:
    print("ERREUR D'EXÉCUTION dans les tests :", str(e).split("\n")[0][:400])
    sys.exit(1)
print("code de sortie :", 1 if failed else 0)
sys.exit(1 if failed else 0)
