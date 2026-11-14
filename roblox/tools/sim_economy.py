#!/usr/bin/env python3
"""Affiche la chronologie de la simulation d'économie (tests/Economy.lua) : python3 roblox/tools/sim_economy.py [minutes] [graine]"""
import os, sys, re
from lupa import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
rd = lambda p: open(os.path.join(ROOT, p), encoding="utf-8").read()
conv = lambda s: re.sub(r"^(\s*)([A-Za-z_][\w.\[\]\"']*)\s*([+\-*/%^])=\s*(.+?)\s*$", lambda m: f"{m[1]}{m[2]} = {m[2]} {m[3]} ({m[4]})", s, flags=re.M)
lua = LuaRuntime(unpack_returned_tuples=True)
mins = int(sys.argv[1]) if len(sys.argv) > 1 else 30
seed = int(sys.argv[2]) if len(sys.argv) > 2 else 12345
lua.execute("Color3 = { fromRGB = function(r,g,b) return {R=r/255,G=g/255,B=b/255} end }")
lua.globals().src = {k: conv(rd(v)) for k, v in {"c": "roblox/src/ReplicatedStorage/Config.lua", "r": "roblox/src/ServerScriptService/Rules.lua", "e": "roblox/tests/Economy.lua"}.items()}
out = lua.execute("""
local Config = load(src.c)()
local Rules = load(src.r)().new(Config)
local E = load(src.e)()
return E.simulate(Config, Rules, ...)
""", mins, lua.table(seed=seed))
for t in sorted(out.marks):
    m = out.marks[t]
    print(f"{t//60:>3} min {t%60:02d}s : pièces {m.coins:>12,.0f}  revenu {m.income:>9,.1f}/s  éclosions {m.hatched:>4}  empl. {m.slots}  festin {m.food}  incub. {m.inc}  espèces {m.species}")
print("premier revenu >=10/s :", out.firstIncome10, "s ; >=100/s :", out.firstIncome100, "s ; >=1000/s :", out.firstIncome1000, "s ; blocage max :", out.maxStall, "s")
print("premier achat d'œuf par rareté :", {i: out.firstEggTier[i] for i in range(1, 7)})
