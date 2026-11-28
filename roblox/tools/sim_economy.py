#!/usr/bin/env python3
"""Simulation d'économie (tests/Economy.lua, joueur-robot, temps de jeu ACTIF), lot 9.
Usage : python3 roblox/tools/sim_economy.py [mode] [heures]
  rythme [300]  : jalons des 5 graines (premier pet par rareté, niveaux de maison, première éclosion) avec les espèces actuelles
  proj [720]    : même chose avec la projection du lot 11 (espèces virtuelles pour Peu commun, Secret, Exclusif, Divin)
  tapis         : gains de progression (premier Légendaire / Mythique) du tapis doré, du tapis privé et du cumul des bonus (BOOST_CAP)
  prix          : REGLE (3) : temps de gain en pièces de chaque article de Config.PRICING pour 3 profils (débutant, milieu = après 10 h,
                  avancé = après 100 h), rapport au « temps Robux » et bloc Lua à recopier dans Config.PRICING
Mêmes conversions Luau -> Lua que run_tests.py (module lupa)."""
import os, sys, re, statistics
from lupa import LuaRuntime

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
rd = lambda p: open(os.path.join(ROOT, p), encoding="utf-8").read()


def conv(src):  # affectations composées Luau -> Lua (commentaire de fin de ligne gardé hors de la parenthèse)
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
lua.execute("Color3 = { fromRGB = function(r,g,b) return {R=r/255,G=g/255,B=b/255} end }")
lua.globals().src = {k: conv(rd(v)) for k, v in {"c": "roblox/src/ReplicatedStorage/Config.lua", "r": "roblox/src/ServerScriptService/Rules.lua", "e": "roblox/tests/Economy.lua"}.items()}
lua.execute("Config = load(src.c)() ; Rules = load(src.r)().new(Config) ; E = load(src.e)()")
G = lua.globals()
C = G.Config


def sim(hours, **o):
    return G.E.simulate(C, G.Rules, hours * 60, lua.table(**o))


def fmt(s):
    if s is None:
        return "-"
    s = int(s)
    if s < 3600:
        return f"{s // 60}m{s % 60:02d}"
    if s < 172800:
        return f"{s / 3600:.1f}h"
    return f"{s / 86400:.1f}j"


mode = sys.argv[1] if len(sys.argv) > 1 else "rythme"
if mode in ("rythme", "proj"):
    hours = float(sys.argv[2]) if len(sys.argv) > 2 else (300 if mode == "rythme" else 720)
    for seed in range(1, 6):
        L = sim(hours, seed=seed, projected=(mode == "proj"))
        pets = " ".join(f"r{i}:{fmt(L.firstPetTier[i])}" for i in range(1, 11) if L.firstPetTier[i])
        house = " ".join(f"{i}:{fmt(L.baseLevelAt[i])}" for i in range(2, 9) if L.baseLevelAt[i])
        print(f"graine {seed} : 1re éclosion {fmt(L.firstHatch)} | pets {pets} | maison {house} | revenu final {L.final.income:,.0f}/s")
    print("cibles : éclosion 10-15 s ; Rare 3 min ; Épique 15 min ; Légendaire 1h30-2h ; Mythique 6-10 h ; Ultra Rare 2-3 j ; Secret 1-2 semaines ; Divin ≈ 2 mois")
    print("maison : niv.2 3 min ; 3 12 min ; 4 40 min ; 5 2 h ; 6 6 h ; 7 ≈ 2 j ; 8 ≈ 10 j")
elif mode == "tapis":
    def mean(**o):
        t5 = t6 = 0
        for seed in range(1, 6):
            L = sim(14, seed=seed, **o)
            t5 += L.firstPetTier[5] or 1e6
            t6 += L.firstPetTier[6] or 1e6
        return t5 / 5, t6 / 5
    b = mean()
    for name, o in (("tapis doré permanent", dict(golden=True)), ("tapis privé", dict(private=True)), ("potion + pass Chance", dict(potion=True, lucky=True)), ("tout cumulé", dict(golden=True, private=True, potion=True, lucky=True))):
        m = mean(**o)
        print(f"{name} : premier Légendaire {fmt(m[0])} ({(b[0] / m[0] - 1) * 100:+.1f} %), premier Mythique {fmt(m[1])} ({(b[1] / m[1] - 1) * 100:+.1f} %)")
    print(f"référence (tapis standard) : Légendaire {fmt(b[0])}, Mythique {fmt(b[1])} ; plafond du cumul : +{C.BOOST_CAP.gain * 100:.0f} %")
elif mode == "prix":
    items = sorted([(k, v) for k, v in C.PRICING.items() if v.coinCost], key=lambda kv: kv[1].tier)
    costs = [v.coinCost for _, v in items]
    k = C.PRICING_REF.secondsPerRobux
    print(f"temps Robux : {k:.2f} s de revenu par R$ (Sac de pièces : {C.COIN_PACK_MINUTES} min pour {C.PRODUCTS.CoinPack.robux} R$)")
    res = {}
    for prof, start in (("beginner", 0), ("mid", 10 * 3600), ("advanced", 100 * 3600)):
        per = [[] for _ in items]
        for seed in range(1, 6):
            L = sim(start / 3600 + 30 * 24, seed=seed, projected=True, afford=lua.table(*costs), affordFrom=start)
            for i in range(len(items)):
                per[i].append(L.afford[i + 1])
        res[prof] = per
        for i, (name, v) in enumerate(items):
            tr = v.robuxCost * k
            ratios = "/".join(f"{x / tr:.1f}" if x else "-" for x in per[i])
            print(f"{prof:9s} {name:13s} {v.robuxCost:5d} R$ = {fmt(tr)} ; {v.coinCost:,.0f} pièces ({v.where}) : {' / '.join(fmt(x) for x in per[i])} (x{ratios})")
    print("\nbloc Config.PRICING (médianes) :")
    for i, (name, v) in enumerate(items):
        meds = {p: int(statistics.median([x or 0 for x in res[p][i]])) for p in res}
        print(f"\t{name} = {{ ... timeToAffordCoin = {{ beginner = {meds['beginner']}, mid = {meds['mid']}, advanced = {meds['advanced']} }} }},")
else:
    print(__doc__)
