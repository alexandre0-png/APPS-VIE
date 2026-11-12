#!/usr/bin/env python3
"""Génère les visuels de présentation (illustrations stylisées dans l'esprit blocs Roblox).
Sorties : publication/images/icon_512.png et thumbnail_1..3_1920x1080.png"""
import pathlib, random, glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = pathlib.Path(__file__).resolve().parent.parent / "publication" / "images"
OUT.mkdir(parents=True, exist_ok=True)

def font(size):
    for p in glob.glob("/usr/share/fonts/**/*Bold*.ttf", recursive=True) + glob.glob("/usr/share/fonts/**/*.ttf", recursive=True):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return ImageFont.load_default()

def gradient(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img

def skyline(d, w, h, horizon, rng, night=False, scale=1.0):
    x = -40
    while x < w:
        bw = int(rng.randint(70, 150) * scale)
        bh = int(rng.randint(160, 520) * scale)
        col = rng.choice([(86, 98, 120), (110, 118, 135), (70, 82, 104), (130, 120, 112)])
        d.rectangle([x, horizon - bh, x + bw, horizon], fill=col)
        d.rectangle([x - 4, horizon - bh - 8, x + bw + 4, horizon - bh], fill=(60, 62, 72))
        for wy in range(horizon - bh + 18, horizon - 20, int(26 * scale) + 4):
            for wx in range(x + 12, x + bw - 14, int(24 * scale) + 4):
                lit = night and rng.random() < 0.7
                d.rectangle([wx, wy, wx + int(12 * scale), wy + int(14 * scale)], fill=(255, 220, 140) if lit else (150, 190, 220))
        x += bw + rng.randint(4, 20)

def road(d, w, h, horizon):
    d.rectangle([0, horizon, w, h], fill=(58, 60, 66))
    d.rectangle([0, horizon, w, horizon + 28], fill=(176, 176, 180))
    for x in range(-20, w, 160):
        d.rectangle([x, horizon + (h - horizon) * 0.55, x + 90, horizon + (h - horizon) * 0.55 + 12], fill=(240, 200, 60))

def car(d, x, y, s, body, police=False):
    d.rectangle([x, y - 30 * s, x + 220 * s, y], fill=body)
    d.rectangle([x + 40 * s, y - 62 * s, x + 170 * s, y - 28 * s], fill=body)
    d.rectangle([x + 52 * s, y - 56 * s, x + 158 * s, y - 32 * s], fill=(90, 130, 170))
    d.rectangle([x + 214 * s, y - 24 * s, x + 224 * s, y - 12 * s], fill=(255, 244, 200))
    for wx in (x + 24 * s, x + 150 * s):
        d.ellipse([wx, y - 14 * s, wx + 46 * s, y + 32 * s], fill=(25, 25, 28))
        d.ellipse([wx + 14 * s, y + 0 * s, wx + 32 * s, y + 18 * s], fill=(190, 195, 205))
    if police:
        d.rectangle([x + 80 * s, y - 76 * s, x + 110 * s, y - 62 * s], fill=(255, 40, 40))
        d.rectangle([x + 110 * s, y - 76 * s, x + 140 * s, y - 62 * s], fill=(40, 80, 255))

def title(img, text, size, xy, fill=(255, 196, 0)):
    d = ImageDraw.Draw(img)
    f = font(size)
    for off in ((6, 6), (-3, -3), (3, -3), (-3, 3)):
        d.text((xy[0] + off[0], xy[1] + off[1]), text, font=f, fill=(15, 16, 24))
    d.text(xy, text, font=f, fill=fill)

def scene(w, h, seed, night, cars, label, sub):
    rng = random.Random(seed)
    top, bot = ((18, 20, 48), (240, 120, 90)) if night else ((70, 150, 235), (200, 230, 255))
    img = gradient(w, h, top, bot)
    d = ImageDraw.Draw(img)
    hor = int(h * 0.68)
    skyline(d, w, h, hor, rng, night)
    road(d, w, h, hor)
    for (cx, cy, s, col, pol) in cars:
        car(d, int(cx * w), int(cy * h), s * h / 1080, col, pol)
    if night:
        glow = Image.new("RGB", (w, h), (0, 0, 0))
        ImageDraw.Draw(glow).ellipse([w * 0.6, h * 0.6, w * 0.95, h * 0.9], fill=(255, 120, 60))
        glow = glow.filter(ImageFilter.GaussianBlur(120))
        img = Image.blend(img, Image.composite(glow, img, glow.convert("L")), 0.25)
    title(img, label, int(h * 0.15), (int(w * 0.05), int(h * 0.06)))
    title(img, sub, int(h * 0.05), (int(w * 0.055), int(h * 0.24)), fill=(255, 255, 255))
    return img

scene(1920, 1080, 1, False, [(0.12, 0.88, 1.6, (255, 200, 50), False), (0.5, 0.82, 1.3, (230, 60, 60), False), (0.78, 0.9, 1.7, (240, 240, 245), True)],
      "CITY RUSH", "Vole, conduis, fuis la police !").save(OUT / "thumbnail_1_1920x1080.png")
scene(1920, 1080, 2, True, [(0.2, 0.86, 1.7, (150, 70, 230), False), (0.62, 0.9, 1.4, (255, 190, 40), False)],
      "MISSIONS & BRAQUAGES", "Livraisons, taxi, courses, banque").save(OUT / "thumbnail_2_1920x1080.png")
scene(1920, 1080, 3, False, [(0.08, 0.9, 1.5, (60, 120, 220), False), (0.4, 0.84, 1.5, (40, 40, 46), False), (0.7, 0.9, 1.6, (240, 240, 245), True)],
      "VILLE OUVERTE", "30 étoiles cachées, nitro, événements").save(OUT / "thumbnail_3_1920x1080.png")
ic = scene(512, 512, 4, True, [(0.14, 0.85, 1.9, (255, 200, 50), False)], "CITY", "RUSH")
ic.save(OUT / "icon_512.png")
print("images générées dans", OUT)

# ---- plan de la ville (aperçu de la carte du jeu) ----
def city_map():
    S, H = 1000, 700
    img = Image.new("RGB", (S, S), (30, 100, 150))
    d = ImageDraw.Draw(img)
    k = S / (H * 2)
    def R(x, z, w, h, col):
        d.rectangle([(x - w / 2 + H) * k, (z - h / 2 + H) * k, (x + w / 2 + H) * k, (z + h / 2 + H) * k], fill=col)
    R(0, 0, H * 2, H * 2, (96, 150, 78))
    dist = [["residential", "industrial", "industrial", "industrial", "harbor"],
            ["residential", "downtown", "downtown", "downtown", "beach"],
            ["residential", "downtown", "plaza", "downtown", "stadium"],
            ["residential", "downtown", "downtown", "downtown", "beach"],
            ["residential", "payspray", "police", "dealer", "park"]]
    cols = {"residential": (190, 200, 170), "industrial": (140, 140, 145), "downtown": (120, 135, 160), "plaza": (215, 200, 170),
            "harbor": (150, 150, 160), "beach": (231, 208, 150), "stadium": (110, 170, 110), "park": (80, 150, 70),
            "payspray": (200, 195, 160), "police": (120, 140, 190), "dealer": (150, 190, 215)}
    for n in range(6):
        c = -500 + 200 * n
        R(c, 0, 40, 1040, (70, 72, 80)); R(0, c, 1040, 40, (70, 72, 80))
    for j in range(5):
        for i in range(5):
            R((i - 2) * 200, (j - 2) * 200, 160, 160, cols[dist[j][i]])
    pois = [("Pizzeria", -352, -30), ("Taxi", -40, -10), ("Banque", 0, -170), ("Course", 322, 0), ("Concession", 200, 375), ("Pay'n'Spray", -200, 386), ("Police", 0, 420), ("Planque", -30, -345)]
    f = font(18)
    for name, x, z in pois:
        px, py = (x + H) * k, (z + H) * k
        d.ellipse([px - 9, py - 9, px + 9, py + 9], fill=(255, 196, 0), outline=(0, 0, 0))
        d.text((px + 12, py - 10), name, font=f, fill=(255, 255, 255), stroke_width=3, stroke_fill=(0, 0, 0))
    img.save(OUT / "carte_ville.png")
city_map()
