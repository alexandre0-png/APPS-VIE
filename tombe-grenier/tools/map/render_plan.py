#!/usr/bin/env python3
"""Dessine les plans des quatre niveaux à partir des données générées (vérification visuelle).

Usage (depuis tombe-grenier/) :
    python3 tools/map/render_plan.py [sortie.png]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_map as gm  # noqa: E402

DATA = gm.build()
SCALE = 7                    # pixels par stud
MARGIN = 60
PANEL_W = 120 * SCALE + 2 * MARGIN
PANEL_H = 90 * SCALE + 2 * MARGIN

MAT_COLOR = {
    "carrelage": (150, 150, 145), "ardoise": (60, 62, 68), "plancher": (95, 70, 48),
    "bois": (120, 84, 52), "bois_sombre": (70, 46, 30), "metal": (95, 95, 102),
    "tissu": (120, 50, 50), "pierre": (120, 120, 120), "vert": (60, 100, 60),
    "porcelaine": (235, 235, 230), "carton": (170, 135, 90), "brique": (120, 60, 48),
    "mur": (160, 150, 135), "herbe": (46, 74, 40),
}


def px(x, z):
    return MARGIN + x * SCALE, MARGIN + z * SCALE


def rect_px(x0, z0, x1, z1):
    a, b = px(x0, z0)
    c, d = px(x1, z1)
    return a, b, c, d


def draw_level(draw, level, font):
    base = gm.BASE[level]
    # Dalles du niveau
    for s in DATA["slabs"]:
        if abs(s["y1"] - base) < 1e-6:
            draw.rectangle(rect_px(s["x0"], s["z0"], s["x1"], s["z1"]),
                           fill=MAT_COLOR.get(s["mat"], (90, 90, 90)))
    # Marches : celles qui partent de ce niveau
    for s in DATA["steps"]:
        if abs(s["y0"] - base) < 1e-6:
            draw.rectangle(rect_px(s["x0"], s["z0"], s["x1"], s["z1"]), fill=(150, 110, 70))
    # Meubles posés sur ce niveau
    for f in DATA["furniture"]:
        if abs(f["y0"] - base) < 1e-6:
            draw.rectangle(rect_px(f["x0"], f["z0"], f["x1"], f["z1"]),
                           fill=MAT_COLOR.get(f["mat"], (100, 80, 60)), outline=(20, 14, 10))
    # Murs : tranches qui touchent ce niveau
    for w in DATA["walls"]:
        if abs(w["y0"] - base) < 1e-6 and w["name"] == "mur":
            draw.rectangle(rect_px(w["x0"], w["z0"], w["x1"], w["z1"]), fill=(15, 12, 12))
        elif abs(w["y0"] - base) < 1e-6 and w["name"] == "linteau":
            draw.rectangle(rect_px(w["x0"], w["z0"], w["x1"], w["z1"]), fill=(40, 30, 30))
    # Points de tag de ce niveau
    colors = {
        "Interactable": (220, 60, 60), "Photo": (255, 255, 200), "Key": (230, 190, 40),
        "ExitDoor": (140, 70, 30), "FlickerLight": (255, 170, 60), "Waypoint": (80, 200, 120),
        "FallSpot": (80, 160, 255), "MonsterSpawn": (255, 0, 0),
    }
    for p in DATA["props"]:
        x, y, z = p["pos"]
        if not (base - 1 <= y <= base + gm.H):
            continue
        cx, cz = px(x, z)
        r = 3
        col = colors.get(p["tag"], (255, 255, 255))
        if p["tag"] == "MonsterSpawn":
            draw.line((cx - 6, cz - 6, cx + 6, cz + 6), fill=col, width=2)
            draw.line((cx - 6, cz + 6, cx + 6, cz - 6), fill=col, width=2)
        elif p["tag"] == "ExitDoor":
            draw.rectangle((cx - 15, cz - 2, cx + 15, cz + 2), fill=col)
        else:
            draw.ellipse((cx - r, cz - r, cx + r, cz + r), fill=col)
    for h in DATA["hiding"]:
        x, y, z = h["pos"]
        if abs(y - (base + 1.5)) < 1e-6:
            cx, cz = px(x, z)
            draw.rectangle((cx - 4, cz - 4, cx + 4, cz + 4), outline=(0, 230, 230), width=2)
    for inv in DATA["invisible"]:
        if inv.get("puzzle") and level == "basement" and inv["name"] == "grille sud":
            draw.rectangle(rect_px(inv["x0"], inv["z0"], inv["x1"], inv["z1"]), outline=(255, 60, 60), width=2)
    if level == "attic":
        sx, sy, sz = DATA["spawn"]["pos"]
        cx, cz = px(sx, sz)
        draw.polygon([(cx, cz - 7), (cx + 6, cz + 5), (cx - 6, cz + 5)], fill=(255, 255, 255))
    draw.text((MARGIN, 18), level.upper(), fill=(230, 230, 230), font=font)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "plan.png")
    font = ImageFont.load_default()
    img = Image.new("RGB", (PANEL_W * 2, PANEL_H * 2), (12, 12, 14))
    for i, level in enumerate(["attic", "first", "ground", "basement"]):
        panel = Image.new("RGB", (PANEL_W, PANEL_H), (12, 12, 14))
        d = ImageDraw.Draw(panel)
        d.rectangle(rect_px(0, 0, 120, 90), outline=(90, 90, 96), width=2)
        draw_level(d, level, font)
        img.paste(panel, ((i % 2) * PANEL_W, (i // 2) * PANEL_H))
    img.save(out)
    print(f"écrit : {out}")


if __name__ == "__main__":
    main()
