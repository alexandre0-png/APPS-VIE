#!/usr/bin/env python3
"""Génère docs/maquette.html (fichier unique autonome : CSS et SVG inline, aucune ressource externe)
à partir des VRAIES valeurs de src/ReplicatedStorage/Shared/Config.lua (lecture via lupa).
Usage : pip install lupa && python3 tools/make_maquette.py"""
import html, json, pathlib
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT.parent / "docs" / "maquette.html"

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Vector3 = { new = function(x,y,z) return {X=x,Y=y,Z=z} end }
Color3 = { fromRGB = function(r,g,b) return {r=r,g=g,b=b} end, new = function(r,g,b) return {r=r*255,g=g*255,b=b*255} end }
''')
cfg = lua.execute((ROOT / "src/ReplicatedStorage/Shared/Config.lua").read_text())

def py(t):
    if lua.eval("function(x) return type(x) end")(t) != "table":
        return t
    keys = list(t.keys())
    if keys and all(isinstance(k, int) for k in keys):
        return [py(t[k]) for k in sorted(keys)]
    return {k: py(t[k]) for k in keys}

C = py(cfg)
def rgb(c): return f"rgb({int(c['r'])},{int(c['g'])},{int(c['b'])})" if isinstance(c, dict) and 'r' in c else "#888"
def money(n): return f"{int(n):,}".replace(",", " ") + " $"
def esc(s): return html.escape(str(s))

vehicles = C["Vehicles"]; missions = C["Missions"]; products = C["Products"]; passes = C["GamePasses"]
story = C["Story"]; vis = C["Visual"]; anim = C["Animations"]; cin = C["Cinematics"]; ach = C["Achievements"]
pois = C["POIs"]; districts = C["Districts"]; decor = C["Assets"]["Decor"]; wanted = C["Wanted"]
DIST_COL = {"residential": "#bec8aa", "industrial": "#8c8c91", "downtown": "#7887a0", "plaza": "#d7c8aa", "harbor": "#969aa0",
            "beach": "#e7d096", "stadium": "#6eaa6e", "park": "#50964a", "payspray": "#c8c3a0", "police": "#788cbe", "dealer": "#96bed7"}
DIST_FR = {"residential": "Résidentiel", "industrial": "Industriel", "downtown": "Centre-ville", "plaza": "Place", "harbor": "Port",
           "beach": "Plage", "stadium": "Stade", "park": "Parc", "payspray": "Pay'n'Spray", "police": "Commissariat", "dealer": "Concession"}

def city_svg(size=520, labels=True, hero=False):
    s = size / 1400.0
    H = 700
    def r(x, z, w, d, col, extra=""):
        return f'<rect x="{(x - w/2 + H)*s:.1f}" y="{(z - d/2 + H)*s:.1f}" width="{w*s:.1f}" height="{d*s:.1f}" fill="{col}" {extra}/>'
    out = [f'<svg viewBox="0 0 {size} {size}" role="img" aria-label="Plan de la ville" class="citymap">',
           f'<rect width="{size}" height="{size}" fill="#1e6496"/>', r(0, 0, 1400, 1400, "#609a4e")]
    for n in range(6):
        c = -500 + 200 * n
        out.append(r(c, 0, 40, 1040, "#464850")); out.append(r(0, c, 1040, 40, "#464850"))
    for j in range(5):
        for i in range(5):
            out.append(r((i - 2) * 200, (j - 2) * 200, 160, 160, DIST_COL[districts[j][i]], 'rx="2"'))
    for p in pois:
        x, y = (p["x"] + H) * s, (p["z"] + H) * s
        out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{max(6, size/60):.1f}" fill="{rgb(p["color"])}" stroke="#000" stroke-width="1"/>')
        out.append(f'<text x="{x:.1f}" y="{y+3.5:.1f}" text-anchor="middle" font-size="{max(8,size/52):.0f}" font-weight="800" fill="#000">{esc(p["glyph"])}</text>')
    out.append("</svg>")
    return "".join(out)

def stars(n, total=5):
    return "".join(f'<span class="star {"on" if i < n else ""}">★</span>' for i in range(total))

def bar(label, val, mx, col):
    return f'<div class="bar"><span>{label}</span><i><b style="width:{min(100, val/mx*100):.0f}%;background:{col}"></b></i></div>'

# ---- sections ----
veh_rows = []
for v in vehicles:
    price = "VIP" if v.get("gamepass") else ("Gratuit" if v["price"] == 0 else money(v["price"]))
    veh_rows.append(f'''<div class="row car"><div class="swatch" style="background:{rgb(v["color"])}"></div><div class="grow"><b>{esc(v["name"])}</b>
      <small>Niveau {v["level"]} · {esc(v["style"])}</small>{bar("Vitesse", v["maxSpeed"], 180, "#e84c4c")}{bar("Accél.", v["accel"], 90, "#ffc400")}{bar("Maniab.", v["turn"], 2.3, "#4696f0")}</div>
      <div class="pill {'gold' if v.get('gamepass') else ''}">{price}</div></div>''')

mis_cards = []
hub = {"delivery": "Pizzeria", "taxi": "Station taxi", "race": "Stade (Course de rue)", "heist": "Banque centrale"}
for k, m in missions.items():
    extra = f"Temps limite {m['timeLimit']} s · {m['checkpoints']} points" if k == "race" else (f"Percer le coffre {m['crackTime']} s" if k == "heist" else f"{money(m['perStud']*100)} /100 studs")
    mis_cards.append(f'''<article class="card mission {k}"><h3>{esc(m["title"])}</h3><p class="muted">Départ : {esc(hub[k])}</p>
      <ul><li>Niveau minimum <b>{m["minLevel"]}</b></li><li>Gain de base <b>{money(m["baseReward"])}</b></li><li>XP <b>+{m["xp"]}</b></li><li>Délai de relance <b>{m["cooldown"]} s</b></li><li>{esc(extra)}</li></ul></article>''')

ach_rows = "".join(f'<div class="row"><div class="grow"><b>{esc(a["name"])}</b><small>{esc(a["desc"])}</small></div><div class="pill good">+{money(a["reward"])}</div></div>' for a in ach)
prod_rows = "".join(f'<div class="row"><div class="grow"><b>{esc(p["name"])}</b><small>{esc(p["desc"])}</small></div><div class="pill robux">R$ {p["robux"]}</div></div>' for p in products)
pass_rows = "".join(f'<div class="row"><div class="grow"><b>{esc(p["name"])}</b><small>{esc(p["desc"])}</small></div><div class="pill robux">R$ {p["robux"]}</div></div>' for p in passes)
# comme en jeu : seules les énigmes résolues (1-2) et l'énigme en cours (3) sont visibles ; la 4e reste cachée
riddles = "".join(f'<div class="riddle {"done" if i < 2 else ""}"><b>Énigme {i+1}{" · " + esc(ch["name"]) if i < 2 else ""}</b><p>{esc(ch["riddle"])}</p></div>' for i, ch in enumerate(story["Chapters"]) if i < 3)
digits = "".join(f'<div class="digit {"on" if i < 2 else ""}">{ch["digit"] if i < 2 else "?"}</div>' for i, ch in enumerate(story["Chapters"]))
cin_rows = "".join(f'<div class="row"><div class="grow"><b>{esc(s["title"])}</b><small>{len(s["shots"])} plans · {sum(sh["dur"] for sh in s["shots"])} s · {esc(k)}</small></div><div class="pill {"good" if s["enabled"] else ""}">{"activée" if s["enabled"] else "coupée"}</div></div>' for k, s in cin["Sequences"].items())

def onoff(v): return '<span class="tg on">ON</span>' if v is True else ('<span class="tg">OFF</span>' if v is False else f'<span class="tg val">{esc(v)}</span>')
vis_rows = "".join(f'<tr><td>Config.Visual.{esc(k)}</td><td>{onoff(v) if not isinstance(v, dict) else esc(", ".join(f"{a}={b}" for a, b in v.items()))}</td></tr>' for k, v in vis.items())
anim_rows = ""
for k, v in anim.items():
    if isinstance(v, dict):
        for kk, vv in v.items():
            anim_rows += f'<tr><td>Config.Animations.{esc(k)}.{esc(kk)}</td><td>{onoff(vv)}</td></tr>'
    else:
        anim_rows += f'<tr><td>Config.Animations.{esc(k)}</td><td>{onoff(v)}</td></tr>'

decor_items = "".join(f'<li><b>{esc(k)}</b> · {d["count"]}× · ~{d["size"]} studs{" · solide" if d.get("solid") else ""}</li>' for k, d in decor.items())
levelXp = 120 + 80 * 4
HTML = f'''<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CITY RUSH - Maquette visuelle</title>
<style>
:root{{--bg:#12141c;--panel:#1c1e26;--panel2:#2c2f3c;--acc:#ffc400;--good:#4cc86e;--bad:#e84c4c;--info:#4696f0;--txt:#f5f5fa;--mut:#a5aab9}}
*{{box-sizing:border-box}}html{{scroll-behavior:smooth}}
body{{margin:0;background:var(--bg);color:var(--txt);font-family:Gotham,"Segoe UI",system-ui,-apple-system,Roboto,sans-serif;line-height:1.45}}
header.top{{position:sticky;top:0;z-index:10;background:#0d0f15e8;backdrop-filter:blur(6px);border-bottom:2px solid var(--acc)}}
nav{{display:flex;gap:6px;overflow-x:auto;padding:8px 12px;scrollbar-width:thin}}
nav a{{flex:none;color:var(--txt);text-decoration:none;background:var(--panel2);padding:6px 12px;border-radius:999px;font-size:.85rem;font-weight:700}}
nav a:hover{{background:var(--acc);color:#000}}
main{{max-width:1100px;margin:0 auto;padding:0 16px 60px}}
section{{padding:34px 0 8px;scroll-margin-top:56px}}
h2{{font-size:1.5rem;margin:0 0 4px;color:var(--acc)}}h3{{margin:.2rem 0}}
.muted,small{{color:var(--mut)}}small{{display:block;font-size:.8rem}}
.grid{{display:grid;gap:14px;grid-template-columns:repeat(auto-fit,minmax(min(100%,300px),1fr))}}
.card,.panel{{background:var(--panel);border:1px solid var(--panel2);border-radius:14px;padding:14px}}
.panel.win{{border:2px solid var(--acc);box-shadow:0 10px 30px #0008}}
.win .bar-title{{display:flex;justify-content:space-between;align-items:center;margin:-4px 0 10px;color:var(--acc);font-weight:900;font-size:1.1rem}}
.x{{background:var(--bad);color:#fff;border-radius:8px;padding:2px 10px;font-weight:900}}
.row{{display:flex;gap:10px;align-items:center;background:var(--panel2);border-radius:10px;padding:8px 10px;margin:6px 0}}
.grow{{flex:1;min-width:0}}.pill{{background:var(--acc);color:#000;font-weight:900;border-radius:8px;padding:5px 9px;white-space:nowrap;font-size:.85rem}}
.pill.good{{background:var(--good)}}.pill.robux{{background:#00aa5a;color:#fff}}.pill.gold{{background:linear-gradient(90deg,#ffd24a,#ff9a1a)}}
.swatch{{width:38px;height:24px;border-radius:6px;border:2px solid #0006}}
.bar{{display:flex;align-items:center;gap:6px;font-size:.72rem;color:var(--mut)}}.bar span{{width:56px}}.bar i{{flex:1;height:7px;background:#12141c;border-radius:4px;overflow:hidden}}.bar b{{display:block;height:100%}}
.scene{{border-radius:16px;overflow:hidden;border:2px solid var(--panel2);position:relative;background:#000}}.scene svg{{display:block;width:100%;height:auto}}
.cap{{position:absolute;left:0;right:0;bottom:0;padding:10px 14px;background:linear-gradient(transparent,#000d);font-weight:800;text-align:center}}
.hero{{background:radial-gradient(circle at 50% 30%,#2a3a6a,#0b0d14 70%);border-radius:20px;padding:46px 16px;text-align:center;border:2px solid var(--panel2)}}
.logo{{font-size:clamp(2.6rem,10vw,5.4rem);font-weight:1000;color:var(--acc);letter-spacing:.04em;text-shadow:0 6px 0 #0008,0 0 40px #ffc40055;margin:0;font-style:italic}}
.btn{{display:inline-block;background:var(--acc);color:#000;font-weight:900;padding:12px 28px;border-radius:12px;margin:8px 4px;font-size:1.05rem}}.btn.alt{{background:var(--panel2);color:var(--txt)}}
.star{{color:#50505a;font-size:2.2rem;text-shadow:0 2px 0 #000}}.star.on{{color:#ffd728}}
.hud{{position:relative;aspect-ratio:16/10;min-height:340px;background:linear-gradient(#6fb4ff,#cfe8ff 46%,#464850 46%,#3a3c44);overflow:hidden;border-radius:16px;border:2px solid var(--panel2)}}
.hud>*{{position:absolute}}.hud .lvl{{left:10px;top:8px;width:190px}}.hud .cash{{right:10px;top:8px;font-weight:1000;color:var(--good);font-size:1.4rem;background:var(--panel);padding:6px 12px;border-radius:10px;border:2px solid var(--good)}}
.hud .stars{{left:50%;top:6px;transform:translateX(-50%)}}.hud .stars .star{{font-size:1.7rem}}
.hud .mini{{left:10px;top:70px;width:96px;height:96px;border:2px solid var(--acc);border-radius:10px;overflow:hidden}}
.hud .mis{{right:10px;top:58px;width:170px;font-size:.75rem}}
.hud .speedo{{left:50%;bottom:10px;transform:translateX(-50%);width:200px;text-align:center}}
.hud .speedo b{{font-size:2rem;font-weight:1000}}
.xp{{height:12px;background:var(--panel2);border-radius:6px;overflow:hidden}}.xp i{{display:block;height:100%;background:var(--acc)}}
.lvlbox{{background:var(--panel);padding:6px 8px;border-radius:10px;border:2px solid var(--panel2);font-weight:900}}
.digit{{width:52px;height:56px;border-radius:10px;background:var(--panel2);display:grid;place-items:center;font-size:2rem;font-weight:1000;color:var(--mut)}}.digit.on{{background:var(--good);color:#000}}
.digits{{display:flex;gap:8px;margin:10px 0}}.riddle{{background:var(--panel2);border-radius:10px;padding:8px 12px;margin:6px 0}}.riddle.done{{opacity:.7;border-left:4px solid var(--good)}}.riddle p{{margin:.2rem 0;font-style:italic}}
table{{width:100%;border-collapse:collapse;font-size:.85rem}}td{{padding:6px 8px;border-bottom:1px solid var(--panel2)}}td:last-child{{text-align:right}}
.tg{{display:inline-block;min-width:44px;text-align:center;border-radius:999px;padding:2px 10px;font-weight:900;background:#444;color:#ccc}}.tg.on{{background:var(--good);color:#000}}.tg.val{{background:var(--info);color:#fff}}
.siren-a{{animation:fa .5s steps(1) infinite}}.siren-b{{animation:fb .5s steps(1) infinite}}
@keyframes fa{{50%{{opacity:.15}}}}@keyframes fb{{0%{{opacity:.15}}50%{{opacity:1}}}}
.glow{{animation:pulse 2s ease-in-out infinite}}@keyframes pulse{{50%{{opacity:.6}}}}
.legend{{display:flex;flex-wrap:wrap;gap:6px;margin-top:8px;font-size:.78rem}}.legend span{{background:var(--panel2);padding:3px 8px;border-radius:999px}}
footer{{color:var(--mut);text-align:center;padding:24px 16px;font-size:.85rem}}
@media(max-width:560px){{.hud{{aspect-ratio:auto;height:500px}}.hud .lvl{{width:150px}}.hud .stars{{top:70px;left:calc(50% + 24px)}}.hud .stars .star{{font-size:1.3rem}}.hud .mini{{top:84px}}.hud .mis{{top:112px;right:10px;width:150px}}.hud .cash{{font-size:1rem;padding:4px 8px}}.hud .speedo{{width:170px}}}}
@media(prefers-reduced-motion:reduce){{*{{animation:none!important}}}}
</style></head><body>
<header class="top"><nav>
<a href="#titre">Écran titre</a><a href="#ville">Ville</a><a href="#poursuite">Poursuite</a><a href="#missions">Missions</a><a href="#hud">HUD</a><a href="#menus">Menus G/B/P/M</a><a href="#journal">Journal</a><a href="#club">Club billard</a><a href="#boutique">Boutique</a><a href="#cine">Cinématiques</a><a href="#reglages">Réglages</a></nav></header>
<main>
<section id="titre"><div class="hero"><h1 class="logo">CITY RUSH</h1><p style="font-size:1.15rem;margin:.2rem">Vole, conduis, fuis la police !</p>
<p class="muted">Mini monde ouvert au style blocs Roblox · missions · niveau de recherche · énigmes</p>
<div><span class="btn">JOUER</span><span class="btn alt">Garage (G)</span></div>
<svg viewBox="0 0 600 120" style="width:min(100%,560px);margin-top:10px" aria-hidden="true"><rect y="86" width="600" height="34" fill="#3a3c44"/>{''.join(f'<rect x="{x}" y="{86-h}" width="{w}" height="{h}" fill="#{c}"/>' for x,w,h,c in [(10,40,60,"56627a"),(60,50,84,"6e768a"),(120,34,48,"46526a"),(160,56,70,"8c7864"),(230,40,90,"505a70"),(280,60,56,"6e768a"),(350,44,78,"56627a"),(404,52,62,"8c7864"),(466,36,88,"46526a"),(510,60,68,"6e768a")])}
<g transform="translate(120,70)"><rect width="70" height="14" rx="3" fill="#ffc832"/><rect x="14" y="-9" width="40" height="11" fill="#ffc832"/><circle cx="14" cy="14" r="7" fill="#111"/><circle cx="56" cy="14" r="7" fill="#111"/></g>
<g transform="translate(380,70)"><rect width="76" height="14" rx="3" fill="#f0f0f5"/><rect x="14" y="-9" width="44" height="11" fill="#f0f0f5"/><rect x="28" y="-17" width="10" height="8" class="siren-a" fill="#ff2828"/><rect x="38" y="-17" width="10" height="8" class="siren-b" fill="#2850ff"/><circle cx="14" cy="14" r="7" fill="#111"/><circle cx="60" cy="14" r="7" fill="#111"/></g></svg></div></section>

<section id="ville"><h2>La ville</h2><p class="muted">Grille 5×5 de blocs (200 studs), 36 carrefours avec feux tricolores, enseignes néon sur les toits, lampadaires qui éclairent la nuit.</p>
<div class="grid"><div class="scene"><svg viewBox="0 0 640 380" role="img" aria-label="Vue de la ville de nuit"><defs><linearGradient id="sk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#141a3a"/><stop offset="1" stop-color="#f07a5a"/></linearGradient></defs>
<rect width="640" height="380" fill="url(#sk)"/><circle cx="520" cy="70" r="26" fill="#fff6d0" opacity=".9"/>
{''.join(f'<g><rect x="{x}" y="{250-h}" width="{w}" height="{h}" fill="#{c}"/>' + ''.join(f'<rect x="{x+6+wx}" y="{250-h+8+wy}" width="7" height="9" fill="#{"ffdc8c" if (wx*3+wy)%5 else "6a7fa0"}"/>' for wx in range(0,w-12,15) for wy in range(0,h-20,18)) + '</g>' for x,w,h,c in [(10,70,170,"465068"),(90,60,210,"5a6480"),(160,80,130,"384058"),(250,64,240,"505a74"),(324,76,160,"465068"),(410,60,200,"5a6480"),(480,70,140,"384058"),(560,70,190,"465068")])}
<rect x="104" y="30" width="46" height="14" rx="3" fill="#ff50a0" class="glow"/><text x="127" y="41" font-size="9" text-anchor="middle" font-weight="800" fill="#fff">CINEMA</text>
<rect x="270" y="22" width="52" height="14" rx="3" fill="#50dcff" class="glow"/><text x="296" y="33" font-size="9" text-anchor="middle" font-weight="800" fill="#003">NEON CITY</text>
<rect x="420" y="40" width="40" height="14" rx="3" fill="#ffc83c" class="glow"/><text x="440" y="51" font-size="9" text-anchor="middle" font-weight="800" fill="#000">HOTEL</text>
<rect y="250" width="640" height="130" fill="#464850"/><rect y="250" width="640" height="14" fill="#b0b0b4"/>{''.join(f'<rect x="{x}" y="318" width="40" height="5" fill="#f0c83c"/>' for x in range(0,640,90))}
<g>{''.join(f'<rect x="{x}" y="200" width="3" height="52" fill="#3c3e46"/><circle cx="{x+1}" cy="196" r="7" fill="#ffeaa0" opacity=".9"/>' for x in (60,230,400,580))}</g>
<g transform="translate(300,200)"><rect width="4" height="62" fill="#323238"/><rect x="-5" y="-6" width="14" height="28" rx="3" fill="#1c1c22"/><circle cx="2" cy="0" r="3.4" fill="#eb3c3c"/><circle cx="2" cy="8" r="3.4" fill="#f0be28"/><circle cx="2" cy="16" r="3.4" fill="#46d264"/></g>
<g transform="translate(120,300)"><rect width="84" height="22" rx="4" fill="#3c78dc"/><rect x="16" y="-14" width="48" height="16" fill="#3c78dc"/><rect x="22" y="-11" width="36" height="10" fill="#5a82aa"/><circle cx="18" cy="24" r="9" fill="#111"/><circle cx="66" cy="24" r="9" fill="#111"/><rect x="82" y="6" width="8" height="5" fill="#fff3c8"/></g>
</svg><div class="cap">Centre-ville la nuit · feux tricolores · enseignes néon · fenêtres allumées</div></div>
<div class="panel"><b>Plan de la ville</b>{city_svg(380)}<div class="legend">{''.join(f'<span style="border-left:6px solid {DIST_COL[k]}">{v}</span>' for k, v in DIST_FR.items())}</div></div></div></section>

<section id="poursuite"><h2>Poursuite de police</h2><p class="muted">Niveau de recherche 0 à {wanted["MaxStars"]} : policiers à pied ({", ".join(str(x) for x in wanted["MaxCopsByStars"])} selon les étoiles), voitures de patrouille ({", ".join(str(x) for x in wanted["MaxCruisersByStars"])}), arrestation avec amende de {int(wanted["BustedCashPercent"]*100)} % (max {money(wanted["BustedMaxLoss"])}). Pay'n'Spray : {money(wanted["SprayCostPerStar"])} par étoile.</p>
<div class="scene"><svg viewBox="0 0 800 380"><rect width="800" height="380" fill="#1a1f3c"/><rect y="210" width="800" height="170" fill="#3a3c44"/><rect y="210" width="800" height="12" fill="#aaa"/>
{''.join(f'<rect x="{x}" y="300" width="60" height="6" fill="#f0c83c"/>' for x in range(0,800,120))}
<g class="glow"><ellipse cx="560" cy="250" rx="200" ry="80" fill="#ff2828" opacity=".16"/><ellipse cx="640" cy="250" rx="200" ry="80" fill="#2850ff" opacity=".16"/></g>
<g transform="translate(120,250)"><rect width="150" height="40" rx="7" fill="#e84c4c"/><rect x="30" y="-24" width="90" height="26" fill="#e84c4c"/><rect x="40" y="-20" width="70" height="18" fill="#5a82aa"/><circle cx="34" cy="42" r="16" fill="#111"/><circle cx="116" cy="42" r="16" fill="#111"/><rect x="146" y="12" width="14" height="8" fill="#fff3c8"/><path d="M-60 20 h50 M-90 36 h70" stroke="#fff" stroke-opacity=".5" stroke-width="4"/></g>
<g transform="translate(420,255)"><rect width="150" height="40" rx="7" fill="#f0f0f5"/><rect x="30" y="-24" width="90" height="26" fill="#f0f0f5"/><rect x="40" y="-20" width="70" height="18" fill="#5a82aa"/><rect x="60" y="-34" width="22" height="12" class="siren-a" fill="#ff2828"/><rect x="82" y="-34" width="22" height="12" class="siren-b" fill="#2850ff"/><rect y="14" width="150" height="9" fill="#192850"/><circle cx="34" cy="42" r="16" fill="#111"/><circle cx="116" cy="42" r="16" fill="#111"/></g>
<g transform="translate(640,262) scale(.8)"><rect width="150" height="40" rx="7" fill="#f0f0f5"/><rect x="30" y="-24" width="90" height="26" fill="#f0f0f5"/><rect x="60" y="-34" width="22" height="12" class="siren-b" fill="#ff2828"/><rect x="82" y="-34" width="22" height="12" class="siren-a" fill="#2850ff"/><circle cx="34" cy="42" r="16" fill="#111"/><circle cx="116" cy="42" r="16" fill="#111"/></g>
<g fill="#ffd728" text-anchor="middle" font-size="40" font-weight="900"><text x="330" y="52">★ ★ ★ <tspan fill="#50505a">★ ★</tspan></text></g><text x="400" y="82" text-anchor="middle" fill="#e84c4c" font-size="18" font-weight="800">La police te poursuit !</text></svg>
<div class="cap">Gyrophares rouge et bleu · étincelles au choc · traînée de vitesse · secousse caméra</div></div>
<div class="grid" style="margin-top:12px"><div class="panel"><b>Mini tutoriel</b><p class="muted">« CONDUIRE : ta Citadine t'attend. WASD ou joystick, Shift = nitro, Espace = sortir. »</p></div><div class="panel"><b>Arrestation</b><p class="muted">Menottes stylisées, écran « ARRÊTÉ ! », amende, retour au commissariat. Aucune violence graphique.</p></div></div></section>

<section id="missions"><h2>Missions</h2><div class="grid">{''.join(mis_cards)}</div>
<div class="panel" style="margin-top:14px"><b>Autres activités</b><p class="muted">{C["Collectibles"]["Count"]} étoiles dorées cachées ({money(C["Collectibles"]["Reward"])} chacune, paliers {', '.join(money(v) for v in C["Collectibles"]["Milestones"])}) · largage de caisses ({C["Airdrop"]["Crates"]} caisses × {money(C["Airdrop"]["Reward"])}) · heure double XP · récompense quotidienne ({money(C["Daily"]["Base"])} + {money(C["Daily"]["PerStreak"])}/jour de série).</p></div></section>

<section id="hud"><h2>HUD en jeu</h2><div class="hud" role="img" aria-label="Interface en conduite">
<svg viewBox="0 0 800 500" preserveAspectRatio="xMidYMax slice" style="position:absolute;inset:0;width:100%;height:100%"><g>{''.join(f'<rect x="{x}" y="{230-h}" width="{w}" height="{h}" fill="#{c}"/>' for x,w,h,c in [(0,90,140,"7d8aa5"),(100,70,190,"6a7894"),(180,110,110,"8896b0"),(300,80,170,"6a7894"),(390,100,200,"7d8aa5"),(500,90,120,"8896b0"),(600,110,180,"6a7894"),(710,90,150,"7d8aa5")])}</g>
<rect y="230" width="800" height="270" fill="#42444c"/><rect y="230" width="800" height="14" fill="#aaa"/>{''.join(f'<rect x="{x}" y="400" width="70" height="8" fill="#f0c83c"/>' for x in range(20,800,150))}
<g transform="translate(300,330)"><rect width="200" height="56" rx="10" fill="#ffc832"/><rect x="40" y="-34" width="120" height="36" fill="#ffc832"/><rect x="52" y="-28" width="96" height="26" fill="#5a82aa"/><circle cx="46" cy="58" r="22" fill="#111"/><circle cx="154" cy="58" r="22" fill="#111"/><rect x="188" y="16" width="14" height="9" fill="#fff3c8"/></g></svg>
<div class="lvl"><div class="lvlbox">Niv. 5 <span class="muted" style="float:right;font-size:.75rem">XP x2 !</span><div class="xp"><i style="width:62%"></i></div><small>{levelXp-180} / {levelXp} XP</small></div></div>
<div class="cash">{money(12340)}</div><div class="stars">{stars(3)}</div>
<div class="mini">{city_svg(96, False)}</div>
<div class="panel mis"><b style="color:var(--acc)">{esc(missions["delivery"]["title"])}</b><br>Livre la pizza avant la fin du temps !<div style="font-size:1.5rem;font-weight:1000">0:42</div><small>Distance : 214 m</small><small style="color:var(--good)">Gain : {money(206)}</small></div>
<div class="panel speedo"><b>96</b> <span class="muted">km/h</span><div class="xp" style="margin-top:4px"><i style="width:70%;background:#ff8c1e"></i></div><small>NITRO · Shift</small></div></div></section>

<section id="menus"><h2>Menus</h2><p class="muted">Touches G (garage), B (boutique), P (profil), M (carte), J (journal) ; boutons en haut à droite sur mobile.</p>
<div class="grid"><div class="panel win"><div class="bar-title">Garage / Concession (G)<span class="x">✕</span></div>{''.join(veh_rows)}</div>
<div class="panel win"><div class="bar-title">Profil (P)<span class="x">✕</span></div><div class="row"><div class="grow">Niveau <b>5</b> · Argent <b>{money(12340)}</b></div></div><div class="row"><div class="grow">Missions réussies <b>12</b> · Distance <b>8,4 km</b> · Étoiles dorées <b>7 / {C["Collectibles"]["Count"]}</b></div></div><b style="color:var(--acc)">Succès</b>{ach_rows}</div>
<div class="panel win"><div class="bar-title">Carte de la ville (M)<span class="x">✕</span></div>{city_svg(420)}<div class="legend">{''.join(f'<span style="border-left:6px solid {rgb(p["color"])}">{esc(p["glyph"])} {esc(p["name"])}</span>' for p in pois)}</div></div></div></section>

<section id="journal"><h2>Journal d'enquête (J)</h2><div class="grid"><div class="panel win"><div class="bar-title">Journal d'enquête<span class="x">✕</span></div>
<h3 style="color:var(--acc)">{esc(story["Title"])}</h3><p class="muted">{esc(story["Intro"])}</p><div class="digits">{digits}</div>{riddles}
<p class="muted">Rends-toi sur place (à pied ou en voiture) : le chiffre apparaît tout seul. Quand les 4 chiffres sont réunis, entre le code pour ouvrir le coffre ({money(story["FinalReward"])} + {story["FinalXP"]} XP).</p></div>
<div class="panel"><b>Animations du journal</b><p class="muted">Les chiffres « tombent » en place avec un rebond, l'énigme s'écrit lettre par lettre. Le coffre ouvert débloque le succès « Détective de la ville ».</p></div></div></section>

<section id="club"><h2>Club billard</h2><p class="muted">Pièce praticable sur le côté est de la place, meublée par des modèles Roblox externes (chargés côté serveur, nettoyés de tout script). Les voitures de la ville peuvent aussi prendre l'apparence de ces modèles ; une épave visuelle décore la zone industrielle.</p>
<div class="grid"><div class="scene"><svg viewBox="0 0 640 400"><rect width="640" height="400" fill="#3a2a22"/><rect x="40" y="40" width="560" height="320" fill="#78553c" stroke="#d2c8b9" stroke-width="10"/><rect x="40" y="150" width="14" height="100" fill="#3a2a22"/>
<g><rect x="280" y="140" width="220" height="120" rx="10" fill="#2a6a3a" stroke="#5a3a24" stroke-width="10"/><circle cx="380" cy="200" r="7" fill="#fff"/><circle cx="410" cy="190" r="7" fill="#e84c4c"/><circle cx="410" cy="210" r="7" fill="#ffc400"/></g>
<rect x="110" y="70" width="90" height="56" rx="6" fill="#a8825a" stroke="#6a4a2a" stroke-width="4"/><circle cx="130" cy="64" r="5" fill="#ffe28a"/><rect x="190" y="52" width="14" height="14" fill="#ffe28a" opacity=".9"/>
<rect x="110" y="270" width="90" height="56" rx="6" fill="#b8bcc4" stroke="#6a6e76" stroke-width="4"/><rect x="132" y="282" width="34" height="22" fill="#222"/>
{''.join(f'<rect x="{x}" y="{y}" width="22" height="22" rx="4" fill="#4a6a9a"/>' for x,y in [(80,80),(214,80),(80,278),(214,278)])}
{''.join(f'<circle cx="{x}" cy="{y}" r="14" fill="#3c8c46"/><circle cx="{x}" cy="{y}" r="7" fill="#2a6a34"/>' for x,y in [(570,70),(570,330),(70,330),(300,60),(300,340)])}
<text x="320" y="30" text-anchor="middle" fill="#ff78c8" font-size="20" font-weight="900">CLUB BILLARD</text></svg><div class="cap">Table de billard · tables · chaises · ordinateur · lampe · plantes</div></div>
<div class="panel"><b>Décor (Config.Assets.Decor)</b><ul>{decor_items}</ul><p class="muted">Noms génériques dans le jeu. Si un modèle est invalide ou introuvable, il est simplement ignoré.</p></div></div></section>

<section id="boutique"><h2>Boutique (B)</h2><div class="grid"><div class="panel win"><div class="bar-title">Boutique<span class="x">✕</span></div><b style="color:var(--acc)">Argent</b>{prod_rows}<b style="color:var(--acc)">Passes</b>{pass_rows}<p class="muted">Prix fixes, aucun contenu aléatoire. Le jeu reste 100 % jouable sans achat.</p></div>
<div class="panel"><b>Avantages</b><ul><li>VIP : gains ×2, Phantom Doré exclusif, badge VIP</li><li>Nitro Infini+ : consommation divisée par 2, recharge ×2</li></ul></div></div></section>

<section id="cine"><h2>Cinématiques (3 moments clés)</h2><div class="panel">{cin_rows}<p class="muted">Skippables (bouton, Espace, Entrée, B), jouées une seule fois, jamais bloquantes.</p></div></section>

<section id="reglages"><h2>Réglages</h2><div class="grid"><div class="panel"><b>Config.Visual</b><table>{vis_rows}</table></div><div class="panel"><b>Config.Animations</b><table>{anim_rows}</table></div></div></section>
</main>
<footer>Maquette illustrative générée par <code>roblox-city-rush/tools/make_maquette.py</code> à partir de <code>Config.lua</code> (noms, textes et valeurs réels). Les scènes sont dessinées en SVG : ce ne sont pas des captures du jeu. Fichier autonome, aucune ressource externe.</footer>
</body></html>'''
OUT.parent.mkdir(exist_ok=True)
OUT.write_text(HTML, encoding="utf-8")
print(f"OK : {OUT} ({len(HTML)//1024} Ko)")
