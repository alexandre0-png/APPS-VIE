#!/usr/bin/env python3
"""Génère apercu.html (présentation visuelle) à partir des vraies données du projet."""
import math, re, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
w = open(os.path.join(ROOT, "src/ReplicatedStorage/Shared/Weapons.luau"), encoding="utf-8").read()
weapons = []
for blk in re.split(r"\n\t\{\n\t\tId", w)[1:]:
    blk = "Id" + blk
    g = lambda k: (re.search(rf'\b{k} = "([^"]*)"', blk) or re.search(rf'\b{k} = ([\d.]+)', blk)).group(1)
    weapons.append(dict(id=g("Id"), name=g("Name"), desc=g("Description"), kind=g("Kind"), cls=g("Class"),
                        rar=g("Rarity"), price=g("Price"), lvl=g("LevelReq"), dmg=g("Damage"), cd=g("Cooldown"), acc=g("Accent")))
RC = {"Commune": "#b8c0cc", "Rare": "#4da3ff", "Épique": "#b05cff", "Légendaire": "#ffb020"}
KIND = {"Melee": "Corps à corps", "Slam": "Zone", "Hitscan": "Tir instantané", "Shotgun": "Plombs", "Projectile": "Projectile"}

def rot(k, x, z):
    return [(x, z), (z, -x), (-x, -z), (-z, x)][k]
def rect(cx, cz, sx, sz, fill, extra=""):
    return f'<rect x="{cx-sx/2:.1f}" y="{-cz-sz/2:.1f}" width="{sx}" height="{sz}" fill="{fill}" {extra}/>'
def circ(cx, cz, r, fill, extra=""):
    return f'<circle cx="{cx:.1f}" cy="{-cz:.1f}" r="{r}" fill="{fill}" {extra}/>'

a = [rect(0, 0, 156, 156, "#4a4540"), rect(0, 0, 158, 158, "none", 'stroke="#8a684e" stroke-width="4"')]
for k in range(4):
    for (x, z, sx, sz, f) in [(60, 60, 20, 20, "#78706a"), (60, 40, 8, 21, "#96a0aa"), (48, 14, 3, 12, "#826048"),
                              (14, 48, 5, 5, "#96a0aa"), (44, 46, 8, 8, "#96703c"), (18, 16, 10, 3, "#78726c"), (28, 28, 14, 14, "#ff5c14")]:
        cx, cz = rot(k, x, z)
        if k % 2: sx, sz = sz, sx
        a.append(rect(cx, cz, sx, sz, f, 'opacity=".95"'))
a.append(circ(0, 0, 17, "#68707c"))
for (cx, cz, sx, sz) in [(0, 29, 9, 24), (0, -29, 9, 24), (29, 0, 24, 9), (-29, 0, 24, 9)]:
    a.append(rect(cx, cz, sx, sz, "#96a0aa"))
for k in range(16):
    t = math.radians(k * 22.5 + 11.25)
    a.append(circ(math.cos(t) * 66, math.sin(t) * 66, 2.2, "#7dd87d"))
for (x, z) in [(0, 58), (0, -58), (58, 0), (-58, 0)]:
    a.append(circ(x, z, 3, "#ff4660"))
for (x, z) in [(0, 47), (0, -47), (47, 0), (-47, 0)]:
    a.append(rect(x, z, 7, 7, "#28dcff"))
a.append(circ(0, 0, 3.4, "#ff2828", 'stroke="#ffd0d0" stroke-width=".8"'))
arena = f'<svg viewBox="-90 -90 180 180" role="img" aria-label="Plan de l\'arène vu du dessus">{"".join(a)}</svg>'

h = [rect(0, 0, 196, 196, "#548c3e"), circ(0, 0, 60, "#8e8a82"), circ(0, 0, 22, "#606470"), circ(0, 0, 4, "#ffc428"),
     rect(0, -30, 14, 14, "#4682dc"), rect(0, 44, 16, 4, "#aa5aff"), rect(-40, 14, 22, 18, "#a0603c"),
     rect(40, 14, 10, 2, "#aa8254"), rect(40, -14, 6, 4, "#8a5c2e"), circ(-50, -34, 20, "#78604a"), rect(0, -62, 30, 2, "#ffc428")]
for i in range(5):
    t = (i - 2) * .55 + math.pi / 2
    h.append(circ(-50 + math.cos(t) * 11 - 3, -34 + math.sin(t) * 11 + 6, 1.8, "#d64040"))
hub = f'<svg viewBox="-102 -102 204 204" role="img" aria-label="Plan du hub vu du dessus">{"".join(h)}</svg>'

cards = "".join(
    f'<article class="wc" style="--r:{RC[x["rar"]]};--a:#{x["acc"]}"><i></i><h3>{x["name"]}</h3><p class="rar">{x["rar"]} · niv. {x["lvl"]}</p>'
    f'<p>{x["desc"]}</p><dl><div><dt>Dégâts</dt><dd>{x["dmg"]}</dd></div><div><dt>Cadence</dt><dd>{x["cd"]} s</dd></div>'
    f'<div><dt>Prix</dt><dd>{x["price"] if x["price"]!="0" else "gratuit"}</dd></div></dl><p class="k">{KIND[x["kind"]]}</p></article>'
    for x in weapons)

html = open(os.path.join(ROOT, "tools/preview_template.html"), encoding="utf-8").read()
html = html.replace("{{ARENA}}", arena).replace("{{HUB}}", hub).replace("{{WEAPONS}}", cards)
open(os.path.join(ROOT, "apercu.html"), "w", encoding="utf-8").write(html)
print("apercu.html généré,", len(weapons), "armes")
