#!/usr/bin/env python3
"""Génère docs/maquette.html (fichier unique, CSS/SVG inline, aucune ressource externe) depuis les vraies données du jeu.

Usage : python3 tools/build_maquette.py   (nécessite le binaire `luau` : variable LUAU, défaut « luau »)
"""
import html, json, math, os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUAU = os.environ.get("LUAU", "luau")
ANALYZE = os.environ.get("LUAU_ANALYZE", "luau-analyze")

def load_data():
    emit = os.path.join(ROOT, ".emit")
    shutil.rmtree(emit, ignore_errors=True)
    env = dict(os.environ, INJECT_MOCK="1")
    subprocess.run([sys.executable, os.path.join(ROOT, "tools/check.py"), "--analyze", ANALYZE, "--emit", emit], env=env, capture_output=True)
    out = subprocess.run([LUAU, os.path.join(ROOT, "tools/dump_data.luau")], capture_output=True, text=True, cwd=os.path.join(ROOT, "tests"))
    shutil.rmtree(emit, ignore_errors=True)
    if out.returncode != 0:
        sys.exit(out.stderr)
    return json.loads(out.stdout)

D = load_data()
C, W, L, Q = D["Config"], D["Weapons"], D["Lore"], D["Quests"]
e = html.escape
RC = C["Rarities"]

def fmt(n):
    return f"{int(n):,}".replace(",", " ")

# ---------- SVG : personnage en blocs Roblox ----------
def figure(color, skin="#f0c08a", w=70, weapon=None, pose="idle"):
    arm = '<rect x="-17" y="26" width="9" height="30" rx="2" fill="{s}"/><rect x="26" y="26" width="9" height="30" rx="2" fill="{s}"/>'.format(s=skin)
    if pose == "aim":
        arm = '<rect x="-17" y="26" width="9" height="30" rx="2" fill="{s}"/><rect x="8" y="30" width="34" height="9" rx="2" fill="{s}"/>'.format(s=skin)
    return (f'<svg viewBox="-22 -2 80 118" width="{w}" role="img" aria-label="Personnage"><g>'
            f'<rect x="4" y="0" width="24" height="24" rx="3" fill="{skin}"/><rect x="9" y="9" width="4" height="4" fill="#222"/><rect x="19" y="9" width="4" height="4" fill="#222"/>'
            f'<rect x="0" y="26" width="32" height="34" rx="3" fill="{color}"/>{arm}'
            f'<rect x="1" y="62" width="14" height="38" rx="2" fill="#39414f"/><rect x="17" y="62" width="14" height="38" rx="2" fill="#39414f"/>'
            f'{weapon or ""}</g></svg>')

# ---------- SVG : silhouette d'arme depuis Weapons.luau (vue de côté Z/Y) ----------
def weapon_svg(wp, width=190, height=64):
    rects, xs, ys = [], [], []
    for p in wp["Parts"]:
        sz, off = p["Size"], p["Offset"]
        cx, cy = off[2], -off[1]
        shape = f'<rect x="{cx - sz[2]/2:.2f}" y="{cy - sz[1]/2:.2f}" width="{sz[2]:.2f}" height="{sz[1]:.2f}" rx="0.1" fill="#{p["Color"]}"' + (' filter="url(#glow)"' if p.get("Neon") else "") + "/>"
        if p.get("Shape") == "Ball":
            shape = f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{sz[1]/2:.2f}" fill="#{p["Color"]}" filter="url(#glow)"/>'
        rects.append(shape)
        xs += [cx - sz[2]/2, cx + sz[2]/2]; ys += [cy - sz[1]/2, cy + sz[1]/2]
    pad = 0.4
    x0, x1, y0, y1 = min(xs) - pad, max(xs) + pad, min(ys) - pad, max(ys) + pad
    vw, vh = x1 - x0, y1 - y0
    rot = ""
    if vh > vw * 1.6:  # arme verticale (épée…) : on la couche pour la lisibilité
        rot = f' transform="rotate(-90 {(x0+x1)/2:.2f} {(y0+y1)/2:.2f})"'
        vw, vh = vh, vw
        cx0, cy0 = (x0 + x1) / 2, (y0 + y1) / 2
        x0, y0 = cx0 - vw / 2, cy0 - vh / 2
    return (f'<svg viewBox="{x0:.2f} {y0:.2f} {vw:.2f} {vh:.2f}" width="{width}" height="{height}" role="img" aria-label="{e(wp["Name"])}">'
            f'<defs><filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="0.12"/></filter></defs><g{rot}>{"".join(rects)}</g></svg>')

# ---------- SVG : plans (arène / hub) ----------
def rot(k, x, z): return [(x, z), (z, -x), (-x, -z), (-z, x)][k]
def rect(cx, cz, sx, sz, fill, extra=""): return f'<rect x="{cx-sx/2:.1f}" y="{-cz-sz/2:.1f}" width="{sx}" height="{sz}" fill="{fill}" {extra}/>'
def circ(cx, cz, r, fill, extra=""): return f'<circle cx="{cx:.1f}" cy="{-cz:.1f}" r="{r}" fill="{fill}" {extra}/>'
a = [rect(0, 0, 156, 156, "#4a4540"), rect(0, 0, 158, 158, "none", 'stroke="#8a684e" stroke-width="4"')]
for k in range(4):
    for (x, z, sx, sz, f) in [(60, 60, 20, 20, "#78706a"), (60, 40, 8, 21, "#96a0aa"), (48, 14, 3, 12, "#826048"), (14, 48, 5, 5, "#96a0aa"), (44, 46, 8, 8, "#96703c"), (18, 16, 10, 3, "#78726c"), (28, 28, 14, 14, "#ff5c14")]:
        cx, cz = rot(k, x, z)
        if k % 2: sx, sz = sz, sx
        a.append(rect(cx, cz, sx, sz, f))
a.append(circ(0, 0, 17, "#68707c"))
for (cx, cz, sx, sz) in [(0, 29, 9, 24), (0, -29, 9, 24), (29, 0, 24, 9), (-29, 0, 24, 9)]: a.append(rect(cx, cz, sx, sz, "#96a0aa"))
for k in range(16):
    t = math.radians(k * 22.5 + 11.25); a.append(circ(math.cos(t) * 66, math.sin(t) * 66, 2.2, "#7dd87d"))
for (x, z) in [(0, 58), (0, -58), (58, 0), (-58, 0)]: a.append(circ(x, z, 3, "#ff4660"))
for (x, z) in [(0, 47), (0, -47), (47, 0), (-47, 0)]: a.append(rect(x, z, 7, 7, "#28dcff"))
a.append(circ(0, 0, 3.4, "#ff2828", 'stroke="#ffd0d0" stroke-width=".8"'))
ARENA = f'<svg viewBox="-90 -90 180 180" role="img" aria-label="Plan de l\'arène">{"".join(a)}</svg>'
h = [rect(0, 0, 196, 196, "#548c3e"), circ(0, 0, 60, "#8e8a82"), circ(0, 0, 22, "#606470"), circ(0, 0, 4, "#ffc428"), rect(0, -30, 14, 14, "#4682dc"), rect(0, 44, 16, 4, "#aa5aff"), rect(-40, 14, 22, 18, "#a0603c"), rect(40, 14, 10, 2, "#aa8254"), rect(40, -14, 6, 4, "#8a5c2e"), circ(-50, -34, 20, "#78604a"), rect(0, -62, 30, 2, "#ffc428")]
HUB = f'<svg viewBox="-102 -102 204 204" role="img" aria-label="Plan du hub">{"".join(h)}</svg>'

# ---------- Données dérivées ----------
M = C["Match"]
heroes = L["Heroes"]
unlock = {c["Unlock"]: c for c in L["Chapters"] if c.get("Unlock")}
chapter_no = {c["Id"]: i + 1 for i, c in enumerate(L["Chapters"])}
mode_names = C["ModeNames"]
S = C["Season"]
MON = C["Monetization"]
KIND = {"Melee": "Corps à corps", "Slam": "Zone", "Hitscan": "Tir instantané", "Shotgun": "Plombs", "Projectile": "Projectile"}

hero_cards = "".join(
    f'<article class="card hero" style="--c:#{x["Color"]}">{figure("#" + x["Color"], w=84)}<h3>{e(x["Name"])} <small>{e(x["Epithet"])}</small></h3><p>{e(x["Story"])}</p>'
    + (f'<p class="lock">🔒 Débloqué par le chapitre {chapter_no[unlock[x["Key"]]["Id"]]} « {e(unlock[x["Key"]]["Title"])} »</p>' if x["Key"] in unlock else '<p class="free">✔ Disponible dès le départ</p>') + "</article>"
    for x in heroes)

pistol = next(w for w in W if w["Id"] == "pistol")
gun_on_fig = ('<g transform="translate(36,26) scale(1.6)">' + "".join(
    f'<rect x="{p["Offset"][2]*-1 - p["Size"][2]/2:.2f}" y="{-p["Offset"][1] - p["Size"][1]/2:.2f}" width="{p["Size"][2]:.2f}" height="{p["Size"][1]:.2f}" fill="#{p["Color"]}"/>' for p in pistol["Parts"]) + "</g>")

weapon_cards = "".join(
    f'<article class="card wc" style="--r:{"#" + RC[x["Rarity"]] if not RC[x["Rarity"]].startswith("#") else RC[x["Rarity"]]}">{weapon_svg(x)}<h3>{e(x["Name"])}</h3><p class="rar">{e(x["Rarity"])} · niveau {x["LevelReq"]}</p><p>{e(x["Description"])}</p>'
    f'<dl><div><dt>Dégâts</dt><dd>{x["Damage"]}{"×" + str(x["Pellets"]) if x.get("Pellets") else ""}</dd></div><div><dt>Cadence</dt><dd>{x["Cooldown"]} s</dd></div><div><dt>Prix</dt><dd>{"gratuit" if x["Price"] == 0 else fmt(x["Price"]) + " 🪙"}</dd></div></dl><p class="k">{KIND[x["Kind"]]}</p></article>'
    for x in W)

modes = [
    ("FFA", f"Premier à {M['FFAScoreLimit']} éliminations ou meilleur score au bout de {M['MatchSeconds']//60} min. Chacun pour soi.", "#ffc857"),
    ("TEAM", f"Rouges contre Bleus, équipes équilibrées automatiquement. {M['TeamScoreLimit']} éliminations d'équipe pour gagner.", "#5b9bff"),
    ("HILL", f"+1 point par seconde sur le plateau central de la tour. {M['HillScoreLimit']} points pour régner.", "#ff8a3d"),
]
mode_cards = "".join(f'<article class="card" style="--c:{c}"><h3>{e(mode_names[k])}</h3><p>{e(t)}</p></article>' for k, t, c in modes)

names = ["Nova", "Lyra", "Orion", "Kaz", "Mika", "Sol", "Ivy", "Rune", "Teo", "Aya"]
kills = [187, 164, 151, 133, 120, 98, 87, 71, 66, 52]
board = "".join(f'<li><b>{i+1}</b><span>{n}</span><em>{fmt(k)}</em></li>' for i, (n, k) in enumerate(zip(names, kills)))
tiers = "".join(f'<li><b>Palier {i}</b><span>{i*S["TierPoints"]} pts</span><em>+{i*S["CoinsPerTier"]} 🪙{" · titre 🏆" if i == S["Tiers"] else ""}</em></li>' for i in range(1, S["Tiers"] + 1))
pts = S["Points"]

passes = "".join(f'<article class="card"><h3>{e(p["Name"])}</h3><p>{e(p["Desc"])}</p><p class="price">R$ {p["Price"]}</p><p class="tag">Game Pass · clé <code>{p["Key"]}</code></p></article>' for p in MON["Passes"])
products = "".join(f'<article class="card"><h3>{e(p["Name"])}</h3><p>+{fmt(p["Coins"])} pièces à dépenser en armes.</p><p class="price">R$ {p["Price"]}</p><p class="tag">Produit · clé <code>{p["Key"]}</code></p></article>' for p in MON["Products"])

def toggles(title, d, skip=()):
    rows = "".join(f'<li><span>{e(k)}</span><i class="sw {"on" if v else ""}" aria-label="{"activé" if v else "désactivé"}"></i></li>' for k, v in d.items() if isinstance(v, bool) and k not in skip)
    return f'<div class="box"><h3>{title}</h3><ul class="tg">{rows}</ul></div>'
settings = toggles("Animations (Config.Animations)", C["Animations"]) + toggles("Cinématiques (Config.Cinematics)", C["Cinematics"]) + toggles("Modèles importés (Config.Assets)", C["Assets"], skip=("LoadReserve",))

chapters = "".join(f'<li><b>Chapitre {i+1}</b><span>{e(c["Title"])}</span><em>{e(c["Text"])}</em></li>' for i, c in enumerate(L["Chapters"]))
quests = "".join(f'<li><b>{e(q["Title"])}</b><span>{e(q["Desc"])}</span><em>+{q["Coins"]} 🪙 · +{q["XP"]} XP</em></li>' for q in Q)
cin = "".join(f'<li><b>{e(n)}</b><span>{round(sum(s["Duration"] for s in v["Shots"]))} s · {len(v["Shots"])} plans</span><em>{"caméra scriptée" if v["Camera"] else "légendes seules"}</em></li>' for n, v in D["Cin"].items())

kill_hud = f'<div class="kp"><b>ÉLIMINATION</b><span>Orion · +{C["Rewards"]["KillCoins"] + C["Rewards"]["StreakCoinStep"]} 🪙  +{C["Rewards"]["KillXP"]} XP</span></div>'
scene = f'''<div class="scene" role="img" aria-label="Combat dans l'arène">
<svg viewBox="0 0 160 90" preserveAspectRatio="xMidYMid slice"><defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5f7fae"/><stop offset="1" stop-color="#e8c9a0"/></linearGradient><filter id="g2"><feGaussianBlur stdDeviation=".6"/></filter></defs>
<rect width="160" height="90" fill="url(#sky)"/><rect y="52" width="160" height="38" fill="#6e6a64"/><rect y="40" width="160" height="14" fill="#8a684e"/>
<rect x="64" y="34" width="32" height="22" fill="#68707c"/><circle cx="80" cy="30" r="4" fill="#ff2828" filter="url(#g2)"/>
<rect x="10" y="44" width="22" height="12" fill="#ff5c14" opacity=".9"/><rect x="128" y="44" width="22" height="12" fill="#ff5c14" opacity=".9"/>
<g transform="translate(26,34) scale(.34)">{figure("#FF8A3D", pose="aim", w=1, weapon=gun_on_fig).replace('<svg viewBox="-22 -2 80 118" width="1" role="img" aria-label="Personnage">','').replace('</svg>','')}</g>
<line x1="44" y1="48" x2="108" y2="52" stroke="#35e0ff" stroke-width="1.2" filter="url(#g2)"/><line x1="44" y1="48" x2="108" y2="52" stroke="#fff" stroke-width=".4"/>
<g transform="translate(112,34) scale(.34)">{figure("#35C9D8", w=1).replace('<svg viewBox="-22 -2 80 118" width="1" role="img" aria-label="Personnage">','').replace('</svg>','')}</g>
<g opacity=".9"><rect x="108" y="44" width="3" height="3" fill="#35C9D8" transform="rotate(20 108 44)"/><rect x="121" y="41" width="2.4" height="2.4" fill="#9be8f0"/><rect x="104" y="52" width="2.4" height="2.4" fill="#35C9D8"/><rect x="127" y="49" width="3" height="3" fill="#9be8f0"/><rect x="116" y="38" width="2" height="2" fill="#fff"/></g>
</svg>
<div class="ban"><small>{e(mode_names["TEAM"]).upper()}</small><b>2:14</b><small>Rouges 12 — 9 Bleus</small></div>
<div class="feed"><span>Nova [Katana] Orion</span><span>Lyra [Arc] 🎯 Kaz</span><span>Orion [Fusil Brasier] Nova</span></div>
{kill_hud}
<div class="card2"><u>12</u><span>Joueur · Gladiateur · Kael</span><s><b></b></s><em>🪙 1 240</em></div>
<div class="bar"><span>1<br>Katana</span><span class="on">2<br>Pistolet</span><span>3<br>Arc</span></div><div class="hp"><b></b></div></div>'''

nav = [("titre", "Titre"), ("heros", "Héros"), ("combat", "Combat"), ("armes", "Armes"), ("modes", "Modes"), ("carte", "Carte"), ("classement", "Classement"), ("boutique", "Boutique"), ("histoire", "Histoire"), ("reglages", "Réglages")]
navhtml = "".join(f'<a href="#{i}">{t}</a>' for i, t in nav)

PAGE = f'''<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Arène des Légendes — maquette</title>
<style>
:root{{--bg:#12141b;--panel:#1b1f2a;--line:#2b3140;--fg:#e8eaf0;--dim:#9aa3b5;--ember:#ff8a3d;--gold:#ffc857;--good:#5fd68a;--blue:#5b9bff;color-scheme:dark}}
*{{box-sizing:border-box}}html{{scroll-behavior:smooth}}
body{{margin:0;background:var(--bg);color:var(--fg);font:15px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;padding-bottom:64px}}
.wrap{{max-width:1040px;margin:0 auto;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}}
nav{{position:sticky;top:0;z-index:20;background:#12141bee;border-bottom:1px solid var(--line);overflow-x:auto;white-space:nowrap}}
nav a{{display:inline-block;padding:12px 12px;color:var(--dim);text-decoration:none;font-weight:600;font-size:13px}}nav a:hover,nav a:focus{{color:var(--gold)}}
section{{padding-block:34px 6px;scroll-margin-top:48px}}
h1,h2,h3{{font-family:Impact,"Arial Black","Segoe UI",sans-serif;letter-spacing:.02em;margin:0;text-wrap:balance;font-weight:400}}
h2{{font-size:26px;margin-bottom:6px;color:var(--gold)}}h3{{font-size:17px}}h3 small{{font-size:12px;color:var(--dim);font-family:system-ui,sans-serif;letter-spacing:0}}
.sub{{color:var(--dim);max-width:66ch;margin:0 0 16px}}
.title{{padding-block:52px 30px;text-align:center;background:radial-gradient(circle at 50% 30%,#ff8a3d44,transparent 60%),linear-gradient(#1b2236,#12141b)}}
.title h1{{font-size:clamp(38px,9vw,78px);line-height:1;text-shadow:0 6px 0 #0008}}.title h1 em{{font-style:normal;color:var(--gold)}}
.title p{{color:#c8cede;max-width:56ch;margin:14px auto 22px}}
.btns{{display:flex;flex-wrap:wrap;gap:10px;justify-content:center}}.btns span{{padding:12px 26px;border-radius:10px;font-weight:700;background:#e74c3c;font-size:18px}}.btns span+span{{background:#2b3140;font-size:15px}}
.chips{{display:flex;flex-wrap:wrap;gap:8px 22px;justify-content:center;margin-top:24px;color:var(--dim)}}.chips b{{color:var(--gold);font-size:22px;display:block;text-align:center;font-family:Impact,sans-serif;font-weight:400}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,220px),1fr));gap:12px}}
.card{{background:var(--panel);border:1px solid var(--c,var(--r,var(--line)));border-radius:10px;padding:14px;min-width:0}}
.card p{{margin:6px 0;color:var(--dim);font-size:13.5px}}.card.hero{{text-align:center;border-top:4px solid var(--c)}}.card.hero svg{{display:block;margin:0 auto 6px}}
.lock{{color:var(--gold)!important}}.free{{color:var(--good)!important}}
.wc{{border-top:4px solid var(--r)}}.wc svg{{display:block;width:100%;height:auto;max-height:70px;margin-bottom:6px}}.rar{{color:var(--r)!important;font-weight:700}}.k{{color:var(--ember)!important;font-weight:600}}
dl{{display:flex;gap:14px;margin:8px 0 0;flex-wrap:wrap}}dt{{font-size:11px;color:var(--dim);text-transform:uppercase;letter-spacing:.06em}}dd{{margin:0;font-weight:700;font-variant-numeric:tabular-nums}}
.row{{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,320px),1fr));gap:16px;align-items:start}}.row>*{{min-width:0}}
.box{{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:14px}}.box svg{{width:100%;height:auto;display:block;border-radius:6px;background:#2a2622}}.box h3{{margin-bottom:8px;color:var(--gold)}}
ol.list,ul.list,ul.tg{{list-style:none;margin:0;padding:0;display:grid;gap:6px}}
.list li{{display:grid;grid-template-columns:auto 1fr;gap:2px 12px;background:#161923;border-radius:8px;padding:9px 12px;align-items:baseline}}.list li b{{color:var(--gold);min-width:3.2em}}.list li span{{font-weight:600}}.list li em{{grid-column:1/-1;color:var(--dim);font-style:normal;font-size:13px}}
.lb li{{grid-template-columns:2.2em 1fr auto}}.lb li em{{grid-column:auto;color:var(--fg);font-weight:700;font-variant-numeric:tabular-nums}}
.price{{color:var(--gold)!important;font-size:22px!important;font-weight:800;font-family:Impact,sans-serif}}.tag{{font-size:12px!important}}code{{background:#10131a;padding:1px 6px;border-radius:5px;color:var(--ember)}}
.tg li{{display:flex;justify-content:space-between;align-items:center;gap:10px;background:#161923;border-radius:8px;padding:8px 12px;font-size:13.5px}}
.sw{{width:40px;height:22px;border-radius:11px;background:#39414f;position:relative;flex:none}}.sw:after{{content:"";position:absolute;top:3px;left:3px;width:16px;height:16px;border-radius:50%;background:#aab;transition:.2s}}.sw.on{{background:var(--good)}}.sw.on:after{{left:21px;background:#fff}}
.scene{{position:relative;aspect-ratio:16/9;border-radius:12px;overflow:hidden;border:1px solid var(--line);container-type:inline-size;color:#fff}}.scene>svg{{position:absolute;inset:0;width:100%;height:100%}}
.scene>*:not(svg){{position:absolute}}
.ban{{left:50%;top:2%;transform:translateX(-50%);width:36%;padding:.8cqw;background:#161922cc;border:1px solid #2b3140;border-radius:1cqw;text-align:center}}.ban *{{display:block}}.ban small{{font-size:1.2cqw;color:#9aa3b5}}.ban b{{font-size:2.8cqw}}
.feed{{right:1.2%;top:20%;display:grid;gap:.4cqw;font-size:1.15cqw}}.feed span{{background:#161922bb;padding:.3cqw .8cqw;border-radius:.5cqw;text-align:right}}
.kp{{left:50%;top:60%;transform:translateX(-50%);text-align:center}}.kp b,.kp span{{display:block}}.kp b{{font-size:2.8cqw;color:#ffc857;text-shadow:0 .2cqw .4cqw #000}}.kp span{{font-size:1.5cqw}}
.card2{{left:1.2%;bottom:2%;width:27%;height:15%;background:#161922cc;border:1px solid #2b3140;border-radius:1cqw}}.card2 u{{position:absolute;left:1cqw;top:1.2cqw;width:4cqw;height:4cqw;border-radius:50%;background:#588cff;text-align:center;line-height:4cqw;text-decoration:none;font-size:2cqw}}.card2 span{{position:absolute;left:6cqw;top:.9cqw;font-size:1.25cqw}}.card2 s{{position:absolute;left:6cqw;right:1cqw;top:4cqw;height:.8cqw;background:#10121a;border-radius:1cqw;text-decoration:none}}.card2 s b{{position:absolute;left:0;top:0;bottom:0;width:62%;background:#588cff;border-radius:1cqw}}.card2 em{{position:absolute;left:6cqw;bottom:.5cqw;font-size:1.5cqw;color:#ffc857;font-style:normal}}
.bar{{left:50%;bottom:7%;transform:translateX(-50%);display:flex;gap:.8cqw}}.bar span{{width:9cqw;height:5.4cqw;background:#161922dd;border:.25cqw solid #2b3140;border-radius:.8cqw;font-size:1.2cqw;padding:.4cqw .6cqw}}.bar span.on{{border-color:#ffc857}}
.hp{{left:50%;bottom:2%;transform:translateX(-50%);width:34%;height:2.2cqw;background:#0e1016;border-radius:2cqw;border:1px solid #000;overflow:hidden}}.hp b{{position:absolute;left:0;top:0;bottom:0;width:82%;background:#5fd68a}}
.cap{{font-size:12.5px;color:var(--dim);margin:8px 0 0}}
footer{{margin-top:44px;color:var(--dim);font-size:12.5px;border-top:1px solid var(--line);padding-top:16px}}
@media(max-width:520px){{.feed{{display:none}}.scene .card2 span{{display:none}}}}
</style></head><body>
<nav><div class="wrap">{navhtml}</div></nav>
<header class="title" id="titre"><div class="wrap"><h1>ARÈNE<br><em>DES LÉGENDES</em></h1>
<p>{e(L["Intro"]["Text"])}</p>
<div class="btns"><span>⚔ JOUER</span><span>🛒 Boutique</span><span>⚙ Réglages</span></div>
<div class="chips"><div><b>{len(W)}</b>armes</div><div><b>{len(mode_names)}</b>modes</div><div><b>{len(heroes)}</b>héros</div><div><b>{len(L["Chapters"])}</b>chapitres</div><div><b>{C["MaxLevel"]}</b>niveaux</div></div></div></header>
<main class="wrap">
<section id="heros"><h2>Choisis ton héros</h2><p class="sub">Chaque héros a sa couleur, son aura et son nom sur la plaque. Purement visuel : aucun effet sur les dégâts. Les éliminations se désintègrent en éclats colorés, sans sang.</p><div class="grid">{hero_cards}</div></section>
<section id="combat"><h2>L'arène en combat</h2><p class="sub">Interface en jeu : manche en cours, kill-feed, élimination, carte joueur, barre d'armes et vie. Un tir de pistolet laisse une traînée lumineuse ; l'adversaire se désintègre en éclats.</p>{scene}<p class="cap">Maquette dessinée à partir des vraies valeurs et dispositions du jeu. Ce n'est pas une capture de Roblox Studio.</p></section>
<section id="armes"><h2>Les {len(W)} armes</h2><p class="sub">Silhouettes tracées depuis les pièces de chaque arme. Stats lues dans <code>Weapons.luau</code>.</p><div class="grid">{weapon_cards}</div></section>
<section id="modes"><h2>Modes de jeu</h2><p class="sub">Manches de {M["MatchSeconds"]//60} min, intermission de {M["IntermissionSeconds"]} s, rotation automatique. Entrée et sortie libres.</p><div class="grid">{mode_cards}</div></section>
<section id="carte"><h2>Carte</h2><p class="sub">Arène de 156 × 156 studs (tour centrale, bunkers, lave, jump pads, soins, orbe de rage ×{C["RageOrb"]["Multiplier"]}) et hub (portail, armurerie, quêtes, coffre, entraînement, classement).</p><div class="row"><div class="box"><h3>Arène</h3>{ARENA}</div><div class="box"><h3>Hub</h3>{HUB}</div></div></section>
<section id="classement"><h2>Classement et saison</h2><p class="sub">« {e(S["Name"])} » : {S["Tiers"]} paliers de {S["TierPoints"]} points. Éliminations +{pts["Kill"]}, assistances +{pts["Assist"]}, parties +{pts["Match"]}, victoires +{pts["Win"]}. Palier {S["Tiers"]} : titre « {e(S["ChampionTitle"])} ».</p><div class="row"><div class="box"><h3>Top éliminations (exemple, pseudos fictifs)</h3><ol class="list lb">{board}</ol></div><div class="box"><h3>Paliers de saison</h3><ul class="list">{tiers}</ul></div></div></section>
<section id="boutique"><h2>Boutique Robux</h2><p class="sub">Aucun achat n'augmente les dégâts. Les Id Roblox restent à renseigner ({e("Config.Monetization")}).</p><h3 style="margin:14px 0 8px">Game Passes</h3><div class="grid">{passes}</div><h3 style="margin:18px 0 8px">Packs de pièces</h3><div class="grid">{products}</div></section>
<section id="histoire"><h2>Histoire, quêtes, cinématiques</h2><div class="row"><div class="box"><h3>Chronique</h3><ul class="list">{chapters}</ul></div><div class="box"><h3>Quêtes quotidiennes (3 tirées parmi {len(Q)})</h3><ul class="list">{quests}</ul></div><div class="box"><h3>Cinématiques (skippables)</h3><ul class="list">{cin}</ul></div></div></section>
<section id="reglages"><h2>Réglages</h2><p class="sub">Commutateurs de configuration du jeu (valeurs actuelles de <code>Config.luau</code>).</p><div class="row">{settings}</div></section>
<footer>Maquette générée par <code>tools/build_maquette.py</code> depuis les fichiers du jeu. Fichier autonome : CSS et SVG inline, aucune ressource externe. Aucun sang ni effet gore. Non publié sur Roblox.</footer>
</main></body></html>'''
out = os.path.join(ROOT, "docs", "maquette.html")
os.makedirs(os.path.dirname(out), exist_ok=True)
open(out, "w", encoding="utf-8").write(PAGE)
print("docs/maquette.html :", len(PAGE), "octets")
