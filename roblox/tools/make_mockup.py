#!/usr/bin/env python3
"""Génère docs/maquette.html : maquette visuelle autonome de Chipe-Œufs (CSS et SVG inline, aucune ressource externe).
Tous les noms, textes, prix et valeurs viennent de roblox/src/ReplicatedStorage/Config.lua (chargé avec lupa) et des prix de
roblox/publication/LISTING.md : relancer ce script après une modification de Config. Usage : python3 roblox/tools/make_mockup.py"""
import os, re, html
from lupa import LuaRuntime

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
rd = lambda p: open(os.path.join(ROOT, p), encoding="utf-8").read()
conv = lambda s: re.sub(r"^(\s*)([A-Za-z_][\w.\[\]\"']*)\s*([+\-*/%^])=\s*(.+?)\s*$", lambda m: f"{m[1]}{m[2]} = {m[2]} {m[3]} ({m[4]})", s, flags=re.M)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("Color3 = { fromRGB = function(r,g,b) return {R=r/255,G=g/255,B=b/255} end }")
C = lua.execute("local src = ...; return load(src)()", conv(rd("roblox/src/ReplicatedStorage/Config.lua")))
esc = html.escape
fmt = lambda n: C.fmt(n)

def rgb(c):
    return "#%02x%02x%02x" % (round(c.R * 255), round(c.G * 255), round(c.B * 255))

def lst(t):
    return [t[i] for i in range(1, len(t) + 1)]

tiers = lst(C.TIERS); pets = lst(C.PETS); zones = lst(C.ZONES); ranks = lst(C.RANKS); story = lst(C.STORY)
keys = ["red", "orange", "purple", "legendary", "glitch"]
looks = {k: C.EggFx.looks[k] for k in keys}
assets = {k: int(C.Assets.eggs[k]) for k in keys}
tier_of = {k: [i + 1 for i, v in enumerate(lst(C.Assets.eggByTier)) if v == k] for k in keys}

# prix en Robux : tableau de publication/LISTING.md (| Type | Nom | Prix | ... |)
prices = {}
for m in re.finditer(r"^\| (Game Pass|Developer Product) \| ([^|]+) \| (\d+) R\$", rd("roblox/publication/LISTING.md"), flags=re.M):
    prices[m[2].strip()] = (m[1], int(m[3]))

# descriptions des drapeaux d'animation : commentaires de Config.lua
anim_desc = {}
for m in re.finditer(r"^\t(\w+) = (?:true|false),? -- (.+)$", rd("roblox/src/ReplicatedStorage/Config.lua"), flags=re.M):
    anim_desc[m[1]] = m[2]

def egg_svg(k, w=96):
    L = looks[k]; col = rgb(L.color); light = rgb(L.light)
    halo = L.halo; part = L.particles
    parts = []
    parts.append(f'<defs><radialGradient id="g_{k}" cx="38%" cy="30%" r="80%"><stop offset="0" stop-color="#fff" stop-opacity=".75"/><stop offset=".35" stop-color="{col}"/><stop offset="1" stop-color="{col}" stop-opacity=".78"/></radialGradient></defs>')
    parts.append(f'<ellipse cx="60" cy="112" rx="30" ry="6" fill="#000" opacity=".25"/>')
    if halo:
        hc = rgb(halo.color)
        if halo.shape == "ball":
            fl = ' class="flick"' if halo.flicker else ""
            parts.append(f'<ellipse cx="60" cy="64" rx="{46 * halo.scale / 1.3:.0f}" ry="{54 * halo.scale / 1.3:.0f}" fill="{hc}" opacity="{1 - halo.transparency:.2f}"{fl}/>')
        else:
            parts.append(f'<ellipse class="ring" cx="60" cy="68" rx="{44 * halo.scale / 1.3:.0f}" ry="11" fill="none" stroke="{hc}" stroke-width="4" opacity=".95"/>')
    parts.append(f'<ellipse cx="60" cy="64" rx="34" ry="44" fill="url(#g_{k})" stroke="{light}" stroke-width="2.5"/>')
    if part:
        pc = rgb(part.color)
        for i, (x, y) in enumerate([(18, 30), (100, 40), (24, 96), (96, 90), (60, 8)]):
            parts.append(f'<circle class="sp s{i}" cx="{x}" cy="{y}" r="{3 + (i % 2)}" fill="{pc}"/>')
    return f'<svg viewBox="0 0 120 124" width="{w}" role="img" aria-label="Œuf {esc(str(L.name))}">{"".join(parts)}</svg>'

def pet_chip(p):
    return f'<span class="chip" style="--c:{rgb(p.color)}">{p.emoji} {esc(str(p.name))} <b>{fmt(p.inc)}/s</b></span>'

# --- sections -------------------------------------------------------------------------------------------------
ch1 = story[0]
income_demo = 5
obj = f'📜 1/{len(story)} · {esc(str(ch1.title))}'
obj_text = f'{esc(str(C.storyGoalText(ch1)))} (0/{ch1.goal})'

def phone(title, body, cls=""):
    return f'<figure class="phone {cls}"><figcaption>{esc(title)}</figcaption><div class="screen">{body}</div></figure>'

def pill(icon, big, small):
    return f'<div class="pill"><span class="pi">{icon}</span><div><b>{big}</b><small>{small}</small></div></div>'

nav = "".join(f'<div class="nv"><span>{e}</span><small>{n}</small></div>' for e, n in [("🛒", "Boutique"), ("📖", "Pets"), ("🎯", "Missions"), ("🎁", "Bonus"), ("🏆", "Top"), ("♻️", "Plus")])

screen_title = phone("1 · Écran titre", f'''
<div class="sky title">
  <div class="sun"></div>
  <h1>{esc(str(C.TITLE))}</h1>
  <p class="tag">{esc(str(C.TAGLINE))}</p>
  <div class="hero">{egg_svg("legendary", 110)}{egg_svg("purple", 90)}{egg_svg("red", 80)}</div>
  <button class="cta">▶ Jouer</button>
  <p class="lore">{esc(str(C.LORE))[:170]}…</p>
</div>''')

pads = "".join(f'<div class="pad">{egg_svg(k, 54)}<small>🥚 {C.fmtTime(C.HATCH[min(i + 1, 6)] if False else C.HATCH[i + 1])}</small></div>' for i, k in enumerate(["red", "orange"])) + \
       f'<div class="pad pet">{pets[0].emoji}<small>{esc(str(pets[0].name))} · {fmt(pets[0].inc)}/s</small></div><div class="pad empty"><small>vide</small></div>'
screen_farm = phone("2 · Accueil de la ferme", f'''
<div class="grass">
  <div class="hud">{pill("🪙", fmt(C.START_COINS) + " ", f"+{income_demo}/s")}{pill("⚡", "9", "VITESSE")}
    <div class="obj"><b>{obj}</b><span>{obj_text}</span><i><u style="width:0%"></u></i></div></div>
  <div class="hint">Touche ton œuf 🥚 pour accélérer l'éclosion !</div>
  <div class="base"><h4>Ma base · {4} emplacements</h4><div class="pads">{pads}</div></div>
  <div class="treadmill">🏃 Tapis roulant</div>
  <div class="navbar">{nav}</div>
</div>''')

screen_steal = phone("3 · Récolte (vol d'un œuf)", f'''
<div class="grass dusk">
  <div class="hud">{pill("🪙", "693", "+5/s")}{pill("⚡", "9", "VITESSE")}</div>
  <div class="carry">🥚 1/1</div>
  <div class="rival"><span class="face">🤠</span><b>{esc(str(C.RIVALS[1].name))}</b><small>⭐ gardien {int(C.RIVALS[1].guardSpeed)} studs/s</small></div>
  <div class="nest">{egg_svg("red", 70)}</div>
  <div class="dog">🐕</div>
  <div class="holdbar"><span>Maintiens pour chiper… {C.stealTime(0):.2f}s</span><i><u></u></i></div>
  <div class="hint">Rapporte l'œuf dans ta base avant que le gardien t'attrape !</div>
  <div class="navbar">{nav}</div>
</div>''')

egg_cards = "".join(f'''<div class="eggcard" style="--c:{rgb(looks[k].light)}">{egg_svg(k, 84)}<b>{esc(str(looks[k].name))}</b><small>Rareté {" / ".join(esc(str(tiers[t-1].name)) for t in tier_of[k])}</small><small>Modèle Roblox {assets[k]}</small></div>''' for k in keys)
screen_hatch = phone("4 · Éclosion et les cinq œufs", f'''
<div class="panelbg">
  <div class="eggrow">{egg_cards}</div>
  <div class="reveal"><div class="confetti">✨ 🎉 ✨</div><div class="bigpet">{pets[15].emoji}</div>
    <b>Alien · Géant · {esc(str(C.MUTS[3].name))}</b><span>Rareté {esc(str(tiers[5].name))} · {fmt(C.petIncome(16, 4, 3))}/s</span>
    <small>Pitié : une rareté supérieure garantie tous les {int(C.PITY_EVERY)} éclosions</small></div>
</div>''', "wide")

zone_cards = "".join(f'<div class="zone {"open" if z.chapter == 0 else ""}"><b>{esc(str(z.name))}</b><small>{"Ouvert dès le départ" if z.chapter == 0 else "🔒 Chapitre " + str(int(z.chapter)) + " terminé"}</small></div>' for z in zones)
rank_cards = "".join(f'<span class="rank">{r.emoji} {esc(str(r.name))} <small>ch. {int(r.chapter)}</small></span>' for r in ranks)
chap = "".join(f'<li><b>{esc(str(c.title))}</b> <small>{esc(str(C.storyGoalText(c)))} · 🪙 {fmt(c.coins)}{(" ou " + str(int(c.mins)) + " min de revenus") if c.mins > 0 else ""}</small></li>' for i, c in enumerate(story))
screen_prog = phone("5 · Progression entre zones", f'''
<div class="panelbg"><h3>Domaines</h3><div class="zones">{zone_cards}</div><h3>Rangs</h3><div class="ranks">{rank_cards}</div>
<h3>Histoire · {len(story)} chapitres</h3><ol class="story">{chap}</ol></div>''', "wide")

rows = []
for ti, t in enumerate(tiers, 1):
    ps = "".join(pet_chip(p) for p in pets if p.tier == ti)
    rows.append(f'<tr><td><span class="tier" style="--c:{rgb(t.color)}">{esc(str(t.name))}</span></td><td>🪙 {fmt(C.EGG_PRICE[ti])}</td><td>{C.fmtTime(C.HATCH[ti])}</td><td>{ps}</td></tr>')
sizes = " · ".join(f'{esc(str(s.name))} x{s.mult:g}' for s in lst(C.SIZES))
muts = " · ".join(f'{esc(str(m.name))} x{m.mult:g}' for m in lst(C.MUTS) if str(m.name) != "")
screen_pets = phone("6 · Tableau des pets et des raretés", f'''
<div class="panelbg"><table class="tiers"><thead><tr><th>Rareté</th><th>Prix de l'œuf</th><th>Éclosion</th><th>Pets (revenu/s)</th></tr></thead><tbody>{"".join(rows)}</tbody></table>
<p class="note">Tailles : {sizes}.<br>Mutations : {muts}.<br>Collection : tous les {int(C.COLLECTION_STEP)} espèces découvertes = +{int(C.COLLECTION_BONUS * 100)}% de revenus.</p></div>''', "wide")

buy = []
for name, d in [(k, v) for k, v in C.PASSES.items()] + [(k, v) for k, v in C.PRODUCTS.items()]:
    typ, price = prices.get(str(d.name), ("", 0))
    buy.append(f'<div class="buy"><span class="bi">{d.emoji}</span><div><b>{esc(str(d.name))}</b><small>{esc(str(typ))}</small><p>{esc(str(d.desc))}</p></div><button>R$ {price}</button></div>')
screen_buy = phone("7 · Achats Robux (passes et produits)", f'''
<div class="panelbg"><h3>Boutique · Robux</h3>{"".join(buy)}
<p class="note">Tant qu'un ID d'achat vaut 0, l'achat affiche « Bientôt ». Les prix sont des suggestions de publication/LISTING.md.</p></div>''')

toggles = "".join(f'<div class="tg"><span>{esc(k)}<small>{esc(anim_desc.get(k, ""))}</small></span><i class="{"on" if C.Animations[k] else ""}"></i></div>' for k in ["enabled", "eggShake", "eggBounce", "hatchSquash", "popIn", "shockwave", "reward", "zones", "hen", "eggHalo"])
screen_set = phone("8 · Menu Plus et réglages", f'''
<div class="panelbg"><h3>Plus</h3>
<div class="buy"><span class="bi">♻️</span><div><b>Renaissance</b><p>Remet pièces, pets et améliorations à zéro. Garde vitesse et collection. Revenus +50% définitif.</p></div><button>🪙 {fmt(C.rebirthCost(0))}</button></div>
<div class="buy"><span class="bi">🎬</span><div><b>Revoir l'intro</b><p>La ferme, Mère Poule et le but du jeu (tu peux la passer).</p></div><button class="g">Lancer</button></div>
<div class="buy"><span class="bi">🎓</span><div><b>Revoir le tutoriel</b><p>Récolte, éclosion et zones en quelques secondes.</p></div><button class="g">Lancer</button></div>
<p class="note">{esc(str(C.oddsText()))}</p>
<h3>Animations (Config.Animations)</h3><div class="toggles">{toggles}</div></div>''', "wide")

CSS = """
:root{--bg:#0f2a1b;--panel:#1d4d33;--pill:#0a1e14;--yellow:#ffd23f;--text:#f4fff6;--muted:#9fc7ad;--green:#5be37d;--red:#ff6b6b;--page:#102418;--ink:#e9fff0}
@media (prefers-color-scheme: light){:root{--page:#eef8f0;--ink:#0f2a1b}}
*{box-sizing:border-box}body{margin:0;background:var(--page);color:var(--ink);font:16px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
header.top{padding:28px 16px 8px;max-width:1200px;margin:auto}header.top h1{margin:0 0 6px;font-size:clamp(26px,5vw,40px)}header.top p{margin:0;max-width:70ch;opacity:.85}
main{max-width:1200px;margin:auto;padding:8px 16px 48px;display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,300px),1fr));gap:24px}
.phone{margin:0;display:flex;flex-direction:column;gap:8px}.phone.wide{grid-column:span 2}@media(max-width:700px){.phone.wide{grid-column:auto}}
figcaption{font-weight:700;padding-left:4px}
.screen{border-radius:26px;border:6px solid #07140d;background:var(--bg);color:var(--text);overflow:hidden;min-height:540px;position:relative;box-shadow:0 10px 30px #0006}
.screen small{color:var(--muted);font-size:12px}.screen b{font-weight:800}
.sky{height:100%;min-height:528px;padding:26px 18px;text-align:center;background:linear-gradient(#1e6fb5,#8fd4ff 55%,#7fd16f 55%,#2f8f4a);position:relative}
.sky .sun{position:absolute;right:26px;top:22px;width:54px;height:54px;border-radius:50%;background:#ffe27a;box-shadow:0 0 40px #ffe27a}
.sky h1{font-size:clamp(34px,8vw,46px);margin:34px 0 4px;text-shadow:0 4px 0 #0a3a5a,0 8px 18px #0006}.tag{font-weight:700;text-shadow:0 2px 6px #0007;margin:0 auto 14px;max-width:26ch}
.hero{display:flex;justify-content:center;align-items:flex-end;gap:2px;margin:12px 0}.hero svg{animation:float 3s ease-in-out infinite}.hero svg:nth-child(2){animation-delay:.5s}.hero svg:nth-child(3){animation-delay:1s}
.cta{border:0;border-radius:30px;background:var(--yellow);color:#2b2200;font:800 20px system-ui;padding:12px 34px;box-shadow:0 5px 0 #b08d00;cursor:pointer}
.lore{font-size:12px;color:#06324f;background:#ffffffb0;border-radius:12px;padding:8px 10px;margin:16px 0 0}
.grass{min-height:528px;padding:10px;background:linear-gradient(#9be7ff,#c8f3d0 38%,#4caf50 38%,#2e7d32);position:relative}.dusk{background:linear-gradient(#ffb36b,#f3d1a3 38%,#4e9a4f 38%,#2b6b33)}
.hud{display:grid;gap:6px;max-width:210px}.pill{display:flex;gap:8px;align-items:center;background:var(--pill);border:2px solid var(--yellow);border-radius:26px;padding:5px 12px}.pill:nth-child(2){border-color:#6ebeff}.pill .pi{font-size:24px}.pill b{display:block;font-size:20px;line-height:1.1}.pill small{display:block}
.obj{background:var(--pill);border:2px solid var(--panel);border-radius:14px;padding:6px 8px;font-size:11px;display:grid;gap:2px}.obj b{color:var(--yellow);font-size:12px}.obj i{display:block;height:8px;background:var(--bg);border-radius:4px;overflow:hidden}.obj u{display:block;height:100%;background:var(--green)}
.hint{position:absolute;left:50%;transform:translateX(-50%);bottom:92px;width:calc(100% - 28px);max-width:340px;background:var(--yellow);color:#2b2200;border-radius:12px;padding:8px 10px;font-weight:700;font-size:13px;text-align:center}
.base{position:absolute;right:10px;top:12px;left:228px;background:#0a1e14c0;border-radius:14px;padding:8px}@media(max-width:380px){.base{left:10px;top:236px}}
.base h4{margin:0 0 6px;font-size:13px}.pads{display:grid;grid-template-columns:1fr 1fr;gap:6px}.pad{background:#ffffff18;border:2px dashed #ffffff55;border-radius:10px;min-height:76px;display:flex;flex-direction:column;align-items:center;justify-content:center;font-size:30px;text-align:center}.pad.empty{opacity:.5}.pad.pet{font-size:34px}
.treadmill{position:absolute;left:10px;right:10px;bottom:150px;height:34px;border-radius:8px;background:repeating-linear-gradient(90deg,#333 0 18px,#555 18px 36px);color:#fff;text-align:center;line-height:34px;font-weight:700;font-size:13px}
.navbar{position:absolute;left:0;right:0;bottom:8px;display:flex;justify-content:center;gap:4px;padding:0 6px}.nv{width:52px;height:52px;border-radius:14px;background:var(--pill);border:2px solid var(--panel);text-align:center;display:grid;place-items:center;line-height:1}.nv span{font-size:20px}.nv small{font-size:9px;margin-top:-6px}
.carry{position:absolute;left:14px;top:134px;background:var(--pill);border-radius:13px;padding:3px 12px;font-weight:700}
.rival{position:absolute;right:12px;top:14px;background:var(--pill);border:2px solid #e0a43b;border-radius:14px;padding:6px 10px;display:grid;gap:0;text-align:center}.rival .face{font-size:30px}
.nest{position:absolute;left:44%;top:210px}.dog{position:absolute;left:12%;top:300px;font-size:44px;animation:dash 2.4s ease-in-out infinite alternate}
.holdbar{position:absolute;left:14px;right:14px;bottom:150px;background:var(--pill);border-radius:12px;padding:6px 10px;font-size:13px;font-weight:700}.holdbar i{display:block;height:8px;background:var(--bg);border-radius:4px;margin-top:4px;overflow:hidden}.holdbar u{display:block;width:62%;height:100%;background:var(--yellow)}
.panelbg{padding:14px;background:var(--bg);min-height:528px}.panelbg h3{margin:12px 0 8px;font-size:15px;color:var(--yellow)}.panelbg h3:first-child{margin-top:0}
.eggrow{display:grid;grid-template-columns:repeat(auto-fit,minmax(110px,1fr));gap:10px}.eggcard{background:var(--panel);border:2px solid var(--c);border-radius:16px;padding:8px;text-align:center;display:grid;justify-items:center;gap:2px;box-shadow:0 0 18px color-mix(in srgb,var(--c) 40%,transparent)}.eggcard svg{animation:float 3s ease-in-out infinite}
.reveal{margin:16px auto 0;max-width:340px;background:var(--panel);border:2px solid var(--yellow);border-radius:18px;padding:12px;text-align:center;display:grid;gap:2px}.bigpet{font-size:64px;animation:pop .9s ease-out both}.confetti{letter-spacing:8px;animation:pop 1.2s ease-out both}
.zones,.ranks{display:flex;flex-wrap:wrap;gap:8px}.zone{flex:1 1 140px;background:var(--panel);border-radius:12px;padding:8px 10px;display:grid;gap:2px;opacity:.8}.zone.open{border:2px solid var(--green);opacity:1}.rank{background:var(--pill);border-radius:20px;padding:4px 10px;font-size:13px}
.story{margin:0;padding-left:20px;display:grid;gap:6px;font-size:13px}.story small{display:block}
.tiers{width:100%;border-collapse:collapse;font-size:13px}.tiers th{text-align:left;color:var(--muted);font-weight:600;padding:4px 6px}.tiers td{padding:6px;vertical-align:top;border-top:1px solid #ffffff22}.tier{display:inline-block;border-radius:20px;padding:2px 10px;font-weight:800;background:color-mix(in srgb,var(--c) 30%,#0000);border:2px solid var(--c)}
.chip{display:inline-block;margin:2px 4px 2px 0;padding:2px 8px;border-radius:12px;background:color-mix(in srgb,var(--c) 22%,#0000);border:1px solid color-mix(in srgb,var(--c) 70%,#0000);white-space:nowrap}
.note{font-size:12px;color:var(--muted);margin:12px 0 0}
.buy{display:flex;gap:10px;align-items:center;background:var(--panel);border-radius:14px;padding:8px 10px;margin-bottom:8px}.buy .bi{font-size:30px}.buy div{flex:1}.buy p{margin:0;font-size:12px;color:var(--muted)}.buy small{margin-left:6px}
button{font-family:inherit}.buy button{border:0;border-radius:18px;background:var(--yellow);color:#2b2200;font-weight:800;padding:8px 12px;min-width:84px}.buy button.g{background:var(--green)}
.toggles{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:6px}.tg{display:flex;justify-content:space-between;align-items:center;gap:8px;background:var(--panel);border-radius:10px;padding:6px 10px;font-size:13px}.tg small{display:block}.tg i{width:38px;height:22px;border-radius:12px;background:var(--dis,#4b5b51);position:relative;flex:none}.tg i:after{content:"";position:absolute;top:3px;left:3px;width:16px;height:16px;border-radius:50%;background:#fff;transition:.2s}.tg i.on{background:var(--green)}.tg i.on:after{left:19px}
@keyframes float{50%{transform:translateY(-6px)}}@keyframes pop{0%{transform:scale(.3);opacity:0}60%{transform:scale(1.25)}100%{transform:scale(1);opacity:1}}@keyframes dash{to{transform:translateX(80px)}}
.ring{animation:spin 3s linear infinite;transform-origin:60px 68px}@keyframes spin{50%{transform:scaleY(.4)}}.flick{animation:fl .5s steps(2) infinite}@keyframes fl{50%{opacity:.35;transform:translateX(3px)}}
.sp{animation:tw 1.6s ease-in-out infinite}.s1{animation-delay:.3s}.s2{animation-delay:.6s}.s3{animation-delay:.9s}.s4{animation-delay:1.2s}@keyframes tw{50%{opacity:.15}}
@media (prefers-reduced-motion:reduce){*{animation:none!important}}
footer{max-width:1200px;margin:auto;padding:0 16px 40px;font-size:13px;opacity:.8}
"""
doc = f'''<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Chipe-Œufs : maquette visuelle</title><style>{CSS}</style></head>
<body><header class="top"><h1>{esc(str(C.TITLE))} : maquette visuelle</h1>
<p>Maquette des écrans du jeu Roblox. Les noms, textes, prix et valeurs sont lus dans <code>Config.lua</code> (fichier généré par <code>roblox/tools/make_mockup.py</code>). C'est une illustration : le rendu réel (3D, UI Roblox) est à voir dans Studio.</p></header>
<main>{screen_title}{screen_farm}{screen_steal}{screen_hatch}{screen_prog}{screen_pets}{screen_buy}{screen_set}</main>
<footer>Fichier unique et autonome : aucune ressource externe. Les 5 œufs montrent l'apparence construite par le code (<code>Config.EggFx</code>) ; les modèles Roblox listés dans <code>Config.Assets</code> les remplacent quand ils se chargent.</footer></body></html>'''
out = os.path.join(ROOT, "docs", "maquette.html")
os.makedirs(os.path.dirname(out), exist_ok=True)
open(out, "w", encoding="utf-8").write(doc)
print("écrit", out, f"({len(doc)//1024} Ko)")
