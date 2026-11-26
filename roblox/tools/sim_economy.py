#!/usr/bin/env python3
"""Affiche la chronologie de la simulation d'économie (tests/Economy.lua) : python3 roblox/tools/sim_economy.py [minutes] [graine] [dore|sans-tapis]
Lot 8A : tapis roulant (prix x 0,6, rareté visible), revenu de maison, 20 emplacements ; « dore » = tapis doré permanent ; « sans-tapis » = boutique seule."""
import os, sys, re
from lupa import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
rd = lambda p: open(os.path.join(ROOT, p), encoding="utf-8").read()
def conv(src):  # affectations composées Luau -> Lua (même conversion que run_tests.py, commentaire de fin de ligne gardé hors de la parenthèse)
    out = []
    for line in src.split("\n"):
        m = re.match(r"^(\s*)([A-Za-z_][\w.\[\]\"']*)\s*([+\-*/%^])=\s*(.+?)\s*$", line)
        if m and not line.lstrip().startswith("--"):
            ind, lhs, op, rhs = m.groups()
            com = ""
            cut = rhs.find(" --")
            if cut >= 0:
                rhs, com = rhs[:cut].rstrip(), rhs[cut:]
            line = f"{ind}{lhs} = {lhs} {op} ({rhs}){com}"
        out.append(line)
    return "\n".join(out)
lua = LuaRuntime(unpack_returned_tuples=True)
mins = int(sys.argv[1]) if len(sys.argv) > 1 else 30
seed = int(sys.argv[2]) if len(sys.argv) > 2 else 12345
mode = sys.argv[3] if len(sys.argv) > 3 else ""
lua.execute("Color3 = { fromRGB = function(r,g,b) return {R=r/255,G=g/255,B=b/255} end }")
lua.globals().src = {k: conv(rd(v)) for k, v in {"c": "roblox/src/ReplicatedStorage/Config.lua", "r": "roblox/src/ServerScriptService/Rules.lua", "e": "roblox/tests/Economy.lua"}.items()}
out = lua.execute("""
local Config = load(src.c)()
local Rules = load(src.r)().new(Config)
local E = load(src.e)()
return E.simulate(Config, Rules, ...)
""", mins, lua.table(seed=seed, golden=(mode == "dore"), belt=(mode != "sans-tapis")))
for t in sorted(out.marks):
    m = out.marks[t]
    print(f"{t//60:>4} min {t%60:02d}s : pièces {m.coins:>12,.0f}  revenu {m.income:>9,.1f}/s  éclosions {m.hatched:>4}  empl. {m.slots}  festin {m.food}  incub. {m.inc}  espèces {m.species}  score {m.score}")
print("premier revenu >=10/s :", out.firstIncome10, "s ; >=100/s :", out.firstIncome100, "s ; >=1000/s :", out.firstIncome1000, "s ; blocage max :", out.maxStall, "s")
print("premier achat d'œuf par rareté :", {i: out.firstEggTier[i] for i in range(1, 7)})
print("niveaux de maison (s) :", {i: out.baseLevelAt[i] for i in range(2, 9)}, "(cibles : niv. 2 < 180 s, niv. 4 < 1800 s, niv. 6 < 7200 s, niv. 8 > 18000 s)")
print("fin : niveau de maison", out.final.level, "; score", out.final.score, "; emplacements", out.final.cap, "; éclosions", out.final.hatched)
print("tapis : œufs achetés", out.beltBought, "; perdus faute de place", out.beltLost, "; pièces dépensées au tapis", out.spentBelt)
print("cibles de rareté (pets) : Rare < 240 s, Épique < 720 s, Légendaire < 2700 s, Mythique < 10800 s")
print("première éclosion :", out.firstHatch, "s ; premier pet par rareté :", {i: out.firstPetTier[i] for i in range(1, 7)}, "; niveaux de base :", {i: out.baseLevelAt[i] for i in range(2, 9)})
