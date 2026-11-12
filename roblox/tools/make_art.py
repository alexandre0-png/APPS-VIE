#!/usr/bin/env python3
"""Génère l'icône (512x512), les miniatures (1920x1080) et les icônes d'achats (512x512) de Chipe-Œufs.
Art 100 % original (emoji Noto + formes + texte), sans logo ni asset tiers. Usage : python3 make_art.py"""
import math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "publication", "art")
EMOJI_FONT = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
TITLE_FONT = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
os.makedirs(OUT, exist_ok=True)
_cache = {}

def emoji(ch, size):
    key = (ch, size)
    if key in _cache:
        return _cache[key]
    f = ImageFont.truetype(EMOJI_FONT, 109)
    im = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((10, 10), ch, font=f, embedded_color=True)
    im = im.crop(im.getbbox())
    ratio = size / max(im.size)
    im = im.resize((max(1, int(im.width * ratio)), max(1, int(im.height * ratio))), Image.LANCZOS)
    _cache[key] = im
    return im

def put(base, ch, cx, cy, size, shadow=True, angle=0):
    e = emoji(ch, size)
    if angle:
        e = e.rotate(angle, resample=Image.BICUBIC, expand=True)
    if shadow:
        m = int(size * 0.2)
        a = Image.new("L", (e.width + 2 * m, e.height + 2 * m), 0)
        a.paste(e.split()[3].point(lambda v: int(v * 0.35)), (m, m))
        a = a.filter(ImageFilter.GaussianBlur(size * 0.04))
        sh = Image.new("RGBA", a.size, (0, 0, 0, 255))
        sh.putalpha(a)
        base.alpha_composite(sh, (int(cx - e.width / 2 - m + size * 0.04), int(cy - e.height / 2 - m + size * 0.06)))
    base.alpha_composite(e, (int(cx - e.width / 2), int(cy - e.height / 2)))

def gradient(w, h, top, bottom):
    im = Image.new("RGBA", (w, h))
    px = ImageDraw.Draw(im)
    for y in range(h):
        t = y / (h - 1)
        px.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return im

def rays(base, cx, cy, color, count=18, alpha=40):
    ov = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    R = max(base.size) * 1.5
    for i in range(count):
        a0 = 2 * math.pi * i / count
        a1 = a0 + math.pi / count
        d.polygon([(cx, cy), (cx + R * math.cos(a0), cy + R * math.sin(a0)), (cx + R * math.cos(a1), cy + R * math.sin(a1))], fill=color + (alpha,))
    base.alpha_composite(ov)

def outlined(base, text, cx, cy, size, fill=(255, 255, 255), stroke=(20, 40, 25), sw=None, anchor="mm"):
    f = ImageFont.truetype(TITLE_FONT, size)
    d = ImageDraw.Draw(base)
    sw = sw if sw is not None else max(3, size // 9)
    d.text((cx, cy + size * 0.05), text, font=f, fill=(0, 0, 0, 90), anchor=anchor, stroke_width=sw, stroke_fill=(0, 0, 0, 90))
    d.text((cx, cy), text, font=f, fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=stroke)

def rounded(base, box, radius, fill, outline=None, width=0):
    ImageDraw.Draw(base).rounded_rectangle(box, radius, fill=fill, outline=outline, width=width)

def grass_scene(w, h, horizon=0.55):
    im = gradient(w, h, (120, 205, 255), (205, 240, 255))
    g = gradient(w, int(h * (1 - horizon)) + 2, (96, 178, 84), (52, 120, 62))
    im.alpha_composite(g, (0, int(h * horizon)))
    d = ImageDraw.Draw(im)
    for x in range(-80, w + 80, 260):
        d.ellipse([x, int(h * horizon) - 70, x + 360, int(h * horizon) + 90], fill=(92, 170, 86, 255))
    return im

TIERS = [("Commun", (170, 180, 191), "🐥"), ("Rare", (74, 163, 255), "🦊"), ("Épique", (184, 120, 255), "🐼"),
         ("Légendaire", (255, 176, 32), "🦄"), ("Mythique", (255, 77, 109), "🐲"), ("Cosmique", (61, 255, 208), "👽")]

def icon():
    im = gradient(512, 512, (255, 214, 90), (255, 140, 60))
    rays(im, 256, 270, (255, 255, 255), 14, 55)
    d = ImageDraw.Draw(im)
    d.ellipse([60, 330, 452, 470], fill=(60, 130, 70, 255))
    put(im, "🥚", 256, 300, 330)
    put(im, "🐣", 256, 245, 230)
    put(im, "✨", 98, 110, 90, shadow=False)
    put(im, "✨", 420, 150, 70, shadow=False)
    put(im, "🪙", 405, 400, 90)
    im = im.convert("RGB")
    im.save(os.path.join(OUT, "icon_512.png"))

def hero():
    w, h = 1920, 1080
    im = grass_scene(w, h)
    rays(im, w // 2, 520, (255, 255, 255), 22, 38)
    d = ImageDraw.Draw(im)
    d.ellipse([260, 760, 1660, 1040], fill=(60, 130, 70, 255))
    for i, (ch, x, y, s) in enumerate([("🥚", 250, 700, 250), ("🐲", 560, 640, 330), ("🦄", 1360, 640, 330), ("🥚", 1670, 700, 250), ("👽", 960, 760, 300)]):
        put(im, ch, x, y, s)
    outlined(im, "CHIPE-ŒUFS", w // 2, 230, 260, fill=(255, 218, 70), sw=22)
    outlined(im, "VOLE · FAIS ÉCLORE · DEVIENS RICHE", w // 2, 410, 74, sw=9)
    for x, y, s in [(130, 130, 120), (1790, 150, 100), (420, 880, 90), (1520, 900, 110)]:
        put(im, "✨", x, y, s, shadow=False)
    im.convert("RGB").save(os.path.join(OUT, "thumb_1_hero_1920x1080.png"))

def steal():
    w, h = 1920, 1080
    im = grass_scene(w, h, 0.45)
    d = ImageDraw.Draw(im)
    rounded(im, (140, 250, 1000, 700), 60, (60, 45, 35, 215), (224, 87, 90, 255), 12)
    put(im, "🤖", 330, 320, 80)
    outlined(im, "ZED  ★★★", 600, 320, 70, sw=8)
    for i, (t, x) in enumerate([(3, 330), (4, 570), (5, 810)]):
        d.ellipse([x - 90, 520, x + 90, 600], fill=(122, 84, 56, 255))
        put(im, "🥚", x, 500, 150)
    put(im, "🐻", 560, 640, 210)
    put(im, "😎", 1280, 700, 230)
    put(im, "🥚", 1280, 520, 160)
    put(im, "💨", 1120, 760, 130, shadow=False)
    put(im, "❗", 700, 560, 130, shadow=False)
    outlined(im, "VOLE LEURS ŒUFS !", w // 2, 140, 130, fill=(255, 218, 70), sw=14)
    outlined(im, "…et évite les gardiens", w // 2, 880, 78, sw=9)
    outlined(im, "Cours sur le tapis pour devenir plus rapide", w // 2, 980, 60, sw=8)
    im.convert("RGB").save(os.path.join(OUT, "thumb_2_vol_1920x1080.png"))

def pets():
    w, h = 1920, 1080
    im = gradient(w, h, (30, 70, 50), (12, 36, 26))
    rays(im, w // 2, 540, (255, 255, 255), 24, 22)
    outlined(im, "6 RARETÉS · 18 PETS · MUTATIONS", w // 2, 120, 110, fill=(255, 218, 70), sw=12)
    cw, gap = 270, 36
    x0 = (w - (6 * cw + 5 * gap)) // 2
    for i, (name, col, ch) in enumerate(TIERS):
        x = x0 + i * (cw + gap)
        rounded(im, (x, 270, x + cw, 880), 38, (255, 255, 255, 235), col + (255,), 12)
        ImageDraw.Draw(im).rounded_rectangle((x, 270, x + cw, 345), 38, fill=col + (255,))
        outlined(im, name.upper(), x + cw // 2, 308, 40, sw=5)
        put(im, ch, x + cw // 2, 570, 190)
        put(im, "🥚", x + cw // 2, 790, 90)
    outlined(im, "Doré · Néon · Arc-en-ciel · Alien", w // 2, 970, 78, fill=(120, 255, 190), sw=9)
    im.convert("RGB").save(os.path.join(OUT, "thumb_3_pets_1920x1080.png"))

def product(fname, top, bottom, big, small, label):
    im = gradient(512, 512, top, bottom)
    rays(im, 256, 240, (255, 255, 255), 12, 50)
    put(im, big, 256, 230, 270)
    if small:
        put(im, small, 400, 130, 120)
    outlined(im, label, 256, 440, 78, sw=9)
    im.convert("RGB").save(os.path.join(OUT, fname))

def story():
    w, h = 1920, 1080
    im = gradient(w, h, (24, 52, 40), (8, 22, 16))
    rays(im, w // 2, 600, (255, 220, 120), 20, 26)
    outlined(im, "11 CHAPITRES · 3 DOMAINES · 1 LÉGENDE", w // 2, 120, 84, fill=(255, 218, 70), sw=10)
    cards = [("Domaine de Gus", "🤠", "🐕", (111, 191, 115), False), ("Domaine de Mara", "🧛", "🐺", (224, 164, 59), True), ("Citadelle de Zed", "🤖", "🐻", (224, 87, 90), True)]
    for i, (name, boss, guard, col, locked) in enumerate(cards):
        x = 130 + i * 570
        rounded(im, (x, 270, x + 520, 840), 46, (14, 30, 22, 240), col + (255,), 12)
        put(im, boss, x + 260, 440, 190)
        put(im, guard, x + 260, 650, 130)
        outlined(im, name, x + 260, 770, 52, sw=7)
        if locked:
            ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
            ImageDraw.Draw(ov).rounded_rectangle((x, 270, x + 520, 840), 46, fill=(120, 20, 40, 110))
            im.alpha_composite(ov)
            put(im, "🔒", x + 440, 340, 110)
    outlined(im, "Réussis l'histoire pour ouvrir chaque domaine", w // 2, 940, 66, fill=(120, 255, 190), sw=8)
    outlined(im, "Collectionne · Récolte des bonus · Deviens Roi des Couvées", w // 2, 1020, 44, sw=6)
    im.convert("RGB").save(os.path.join(OUT, "thumb_4_histoire_1920x1080.png"))

if __name__ == "__main__":
    icon(); hero(); steal(); pets(); story()
    product("pass_fast_512.png", (255, 230, 90), (255, 140, 30), "⚡", "🥚", "-25%")
    product("product_coinpack_512.png", (110, 220, 140), (30, 130, 90), "👛", "🪙", "PIÈCES")
    product("pass_coins2x_512.png", (255, 200, 60), (230, 120, 30), "💰", "✨", "x2")
    product("pass_lucky_512.png", (90, 220, 120), (30, 140, 80), "🍀", "✨", "+10%")
    product("product_instanthatch_512.png", (120, 190, 255), (70, 90, 220), "🥚", "⚡", "VITE !")
    product("product_luckpotion_512.png", (190, 130, 255), (110, 60, 190), "🧪", "🍀", "CHANCE")
    print("ok", sorted(os.listdir(OUT)))
