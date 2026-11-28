#!/usr/bin/env python3
"""Exécute roblox/tests/lot16.luau (intégration pure du lot 16) puis roblox/tests/lot16_e2e.luau (vrai Main.server.lua + Data.lua dans le runtime factice)
SANS Lune, avec lupa (même logique que run_tests.py). Ces deux fichiers sont aussi branchés dans run.luau (python3 roblox/tools/run_tests.py).
Usage : python3 roblox/tests/run_lot16.py [chemin/vers/racine]   (racine = copie de travail, utile pour les mutations)
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
lua.globals().py_listdir = lambda path: lua.table_from(sorted(os.listdir(os.path.join(ROOT, path)))) if os.path.isdir(os.path.join(ROOT, path)) else lua.table()
lua.globals().py_convert = luau_to_lua

prelude = r'''
local exit_code = 0
table.clone = table.clone or function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end
local function shim_load(src, opts)
	local env = setmetatable((opts and opts.environment) or {}, { __index = _G })
	local fn, err = load(py_convert(src), (opts and opts.debugName) or "chunk", "t", env)
	if not fn then error(err) end
	return fn
end
local shims = {
	["@lune/fs"] = { readFile = function(p) return py_read(p) end, readDir = function(p) return py_listdir(p) end },
	["@lune/luau"] = { load = shim_load },
	["@lune/process"] = { exit = function(c) exit_code = c; error("__EXIT__") end },
}
function require(name) return shims[name] or error("require inconnu : " .. tostring(name)) end
return function()
	local fs, luau = require("@lune/fs"), require("@lune/luau")
	local passed, failed = 0, 0
	local function suite(name) print("  > " .. name) end
	local function check(name, cond)
		if cond then passed = passed + 1 else failed = failed + 1; print("  ECHEC : " .. name) end
	end
	local FakeRuntime = luau.load(fs.readFile("roblox/tests/FakeRuntime.lua"), { debugName = "FakeRuntime" })()
	local function newRuntime(opts)
		opts.hook = opts.hook or function(co)
			if debug and debug.sethook then debug.sethook(co, function() error("boucle sans wait (garde d'instructions)") end, "", 4000000) end
		end
		local RT = FakeRuntime.runtime(opts)
		if not RT.selfCheck() then check("Runtime factice : environnement appliqué", false) return nil end
		return RT
	end
	local env = { check = check, suite = suite, luau = luau, fs = fs, newRuntime = newRuntime }
	for _, name in ipairs({ "lot16", "lot16_e2e" }) do
		luau.load(fs.readFile("roblox/tests/" .. name .. ".luau"), { debugName = name })()(env)
	end
	print(string.format("%d assertions réussies, %d échecs", passed, failed))
	return failed
end
'''
def _timeout(signum, frame):
    print("TIMEOUT global (240 s)")
    sys.stdout.flush()
    os._exit(3)
signal.signal(signal.SIGALRM, _timeout)
signal.alarm(240)
runner = lua.execute(prelude)
try:
    failed = runner()
except Exception as e:
    print("ERREUR D'EXÉCUTION dans les tests :", str(e).split("\n")[0][:400])
    sys.exit(1)
print("code de sortie :", 1 if failed else 0)
sys.exit(1 if failed else 0)
