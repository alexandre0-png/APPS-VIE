"""Genere les icones d'interface 256x256 (PNG) du jeu Chipe-Oeufs.

Reutilise les fonctions d'aide de gen_icones_achats.py (fond degrade, bord blanc,
contour sombre) sans lancer sa boucle de generation : seule la partie avant
« ITEMS= » est executee.
Sortie : $S/icones_ui/ (+ copie dans vignettes/icones-ui/).
"""
import math
import os
import shutil

from PIL import Image, ImageDraw, ImageFont

TEMPLATE = "/home/user/APPS-VIE/scripts/gen_icones_achats.py"
OUT = "/tmp/claude-0/-home-user-APPS-VIE/c9e841d1-d554-571c-a61d-bf92920d8724/scratchpad/icones_ui"
COPIE = "/home/user/APPS-VIE/vignettes/icones-ui"

with open(TEMPLATE, encoding="utf-8") as f:
    _head = f.read().split("\nITEMS={", 1)[0]
_ns = {}
exec(compile(_head, TEMPLATE, "exec"), _ns)
bg = _ns["bg"]
o = _ns["o"]
star = _ns["star"]
egg = _ns["egg"]
egg_rare = _ns["egg_rare"]
heart = _ns["heart"]
coin = _ns["coin"]
bolt = _ns["bolt"]
shoe = _ns["shoe"]
gift = _ns["gift"]
potion = _ns["potion"]
S = _ns["S"]

DARK = (30, 30, 40)


def poly(d, pts, fill, w=10):
    """Polygone rempli avec contour sombre d'epaisseur w."""
    d.polygon(pts, fill=fill)
    n = len(pts)
    for i in range(n):
        d.line([pts[i], pts[(i + 1) % n]], fill=DARK, width=w)


def leaf(bx, by, tx, ty, w, n=28):
    dx, dy = tx - bx, ty - by
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    a, b = [], []
    for i in range(n + 1):
        t = i / n
        cx, cy = bx + dx * t, by + dy * t
        off = w * math.sin(math.pi * t)
        a.append((cx + nx * off, cy + ny * off))
        b.append((cx - nx * off, cy - ny * off))
    return a + b[::-1]


def crown_box(d, x0, y0, x1, y1, fill=(255, 205, 60)):
    w, h = x1 - x0, y1 - y0

    def P(u, v):
        return (x0 + u * w, y0 + v * h)

    poly(d, [P(0, 1), P(.04, .1), P(.27, .5), P(.5, 0), P(.73, .5), P(.96, .1), P(1, 1)], fill, w=6)
    for u in (.2, .5, .8):
        x, y = P(u, .8)
        d.ellipse((x - w * .06, y - h * .1, x + w * .06, y + h * .1), fill=(230, 60, 90), outline=DARK, width=4)


def text(d, xy, s, size, fill=(255, 255, 255), stroke=DARK):
    f = ImageFont.load_default(size=size)
    d.text(xy, s, font=f, fill=fill, stroke_width=8, stroke_fill=stroke, anchor="mm")


# ---------- Oeufs de rarete (r1..r10) ----------
def p_r5(im, d):
    egg(d, (255, 200, 50), False)
    crown_box(d, 186, 120, 326, 200)


def p_r6(im, d):
    egg(d, (220, 40, 50), False)
    d.chord((150, 90, 362, 430), 180, 360, fill=(20, 20, 24))
    d.ellipse((150, 90, 362, 430), outline=DARK, width=8)


def p_r7(im, d):
    egg(d, (120, 230, 255), False)
    poly(d, [(256, 120), (330, 200), (256, 262), (190, 200)], (215, 250, 255), w=6)
    poly(d, [(190, 200), (256, 262), (220, 380), (160, 300)], (70, 190, 230), w=6)
    poly(d, [(330, 200), (256, 262), (300, 380), (360, 300)], (90, 210, 240), w=6)
    star(d, 380, 130, 34, (255, 255, 255))
    star(d, 130, 360, 24, (255, 255, 255))


# ---------- Types (symbole simple, couleur du type) ----------
def p_feu(im, d):
    poly(d, [(256, 80), (352, 236), (336, 330), (256, 430), (176, 330), (160, 236)], (255, 120, 30))
    d.ellipse((206, 250, 306, 400), fill=(255, 220, 80))


def p_eau(im, d):
    poly(d, [(256, 70), (300, 160), (352, 230), (372, 290), (356, 360), (300, 410),
             (256, 420), (212, 410), (156, 360), (140, 290), (160, 230), (212, 160)], (60, 160, 255))
    d.ellipse((190, 250, 226, 310), fill=(200, 230, 255))


def p_plante(im, d):
    poly(d, leaf(150, 400, 380, 120, 95), (70, 200, 90))
    d.line((150, 400, 360, 150), fill=(30, 120, 50), width=14)


def p_terre(im, d):
    poly(d, [(80, 400), (200, 170), (262, 260), (300, 200), (432, 400)], (190, 130, 70))
    poly(d, [(200, 170), (236, 220), (262, 200), (300, 260), (262, 260)], (235, 200, 150), w=6)


def p_ciel(im, d):
    c = (110, 190, 255)
    for box in ((110, 220, 250, 380), (170, 150, 340, 330), (270, 200, 410, 380)):
        o(d, d.ellipse, box, fill=c)
    o(d, d.rounded_rectangle, (150, 290, 370, 380), 45, fill=c)


def p_ombre(im, d):
    m = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(m)
    md.ellipse((120, 100, 400, 420), fill=255)
    md.ellipse((200, 60, 440, 340), fill=0)
    im.paste((150, 90, 230), mask=m)
    star(d, 400, 380, 24, (200, 160, 255))
    star(d, 120, 130, 18, (200, 160, 255))


def p_lumiere(im, d):
    for k in range(8):
        a = k * math.pi / 4
        d.line((256 + 150 * math.cos(a), 256 + 150 * math.sin(a),
                256 + 215 * math.cos(a), 256 + 215 * math.sin(a)), fill=(255, 230, 120), width=30)
    o(d, d.ellipse, (136, 136, 376, 376), fill=(255, 215, 60))


def p_glace(im, d):
    c = (150, 230, 255)
    for k in range(6):
        a = k * math.pi / 3
        d.line((256, 256, 256 + 170 * math.cos(a), 256 + 170 * math.sin(a)), fill=c, width=26)
        bx, by = 256 + 105 * math.cos(a), 256 + 105 * math.sin(a)
        for s in (-1, 1):
            b = a + s * math.pi / 3.2
            d.line((bx, by, bx + 62 * math.cos(b), by + 62 * math.sin(b)), fill=c, width=20)
    d.ellipse((226, 226, 286, 286), fill=c)


def p_foudre(im, d):
    bolt(d, (255, 230, 70))


# ---------- Recompenses ----------
def coins(n, rx, ry, step, y0):
    def p(im, d):
        for i in range(n):
            y = y0 - i * step
            d.ellipse((256 - rx, y - ry + 16, 256 + rx, y + ry + 16), fill=(200, 140, 30), outline=DARK, width=8)
            d.ellipse((256 - rx, y - ry, 256 + rx, y + ry), fill=(255, 205, 60), outline=DARK, width=8)
            d.ellipse((256 - rx + 26, y - ry + 14, 256 + rx - 26, y + ry - 14), outline=(255, 235, 140), width=6)
    return p


def p_arrow_up(im, d):
    poly(d, [(256, 80), (400, 240), (320, 240), (320, 420), (192, 420), (192, 240), (112, 240)], (255, 200, 60))


def p_parchemin(im, d):
    for x in (96, 356):
        o(d, d.ellipse, (x, 140, x + 60, 380), fill=(205, 160, 95))
    o(d, d.rounded_rectangle, (120, 150, 392, 370), 30, fill=(245, 225, 175))
    for y in (210, 250, 290, 330):
        d.line((170, y, 340, y), fill=(160, 110, 60), width=12)


def p_plume(im, d):
    d.line((150, 380, 70, 470), fill=DARK, width=30)
    d.line((150, 380, 70, 470), fill=(255, 200, 60), width=14)
    poly(d, leaf(150, 380, 400, 110, 70), (255, 200, 60))
    d.line((150, 380, 390, 130), fill=(160, 100, 20), width=12)


def p_jeton(im, d):
    coin(d, 256, 256, 150)
    poly(d, [(240, 120), (272, 120), (272, 320), (256, 345), (240, 320)], (225, 230, 240), w=8)
    o(d, d.rounded_rectangle, (190, 320, 322, 345), 12, fill=(255, 205, 60))
    o(d, d.rectangle, (246, 345, 266, 400), fill=(160, 40, 40))
    o(d, d.ellipse, (240, 396, 272, 428), fill=(255, 205, 60))


def p_etoile_filante(im, d):
    d.line((90, 440, 230, 300), fill=(255, 240, 170), width=30)
    d.line((50, 370, 170, 300), fill=(255, 240, 170), width=14)
    star(d, 300, 230, 110, (255, 230, 70))


def p_titre(im, d):
    poly(d, [(110, 250), (60, 400), (120, 370), (150, 300)], (150, 30, 50), w=8)
    poly(d, [(402, 250), (452, 400), (392, 370), (362, 300)], (150, 30, 50), w=8)
    o(d, d.rounded_rectangle, (100, 160, 412, 330), 20, fill=(220, 60, 80))
    star(d, 256, 245, 62, (255, 215, 60))


def p_coffre(im, d):
    poly(d, [(110, 250), (140, 150), (372, 150), (402, 250)], (180, 120, 55))
    o(d, d.rounded_rectangle, (110, 250, 402, 420), 30, fill=(150, 90, 40))
    o(d, d.rectangle, (110, 300, 402, 330), fill=(255, 205, 60))
    o(d, d.rounded_rectangle, (236, 296, 276, 346), 8, fill=(255, 230, 120))
    for x in (190, 256, 322):
        o(d, d.ellipse, (x - 34, 190, x + 34, 250), fill=(255, 205, 60), w=6)


def p_calendrier(im, d):
    o(d, d.rounded_rectangle, (120, 140, 392, 410), 30, fill=(245, 245, 250))
    o(d, d.rounded_rectangle, (120, 140, 392, 215), 30, fill=(230, 70, 80))
    for x in (190, 296):
        o(d, d.rounded_rectangle, (x, 100, x + 26, 170), 10, fill=(60, 60, 70))
    for r in range(3):
        for c in range(4):
            x, y = 160 + c * 52, 250 + r * 48
            d.rectangle((x, y, x + 30, y + 30), fill=(190, 190, 205))
    o(d, d.ellipse, (264, 298, 300, 334), fill=(255, 200, 60))


def p_mystere(im, d):
    d.text((256, 270), "?", font=ImageFont.load_default(size=400), fill=(255, 205, 60),
           stroke_width=16, stroke_fill=DARK, anchor="mm")


# ---------- Interface ----------
def p_trophee(im, d):
    d.arc((96, 120, 200, 250), 90, 270, fill=(230, 170, 40), width=26)
    d.arc((312, 120, 416, 250), -90, 90, fill=(230, 170, 40), width=26)
    o(d, d.rounded_rectangle, (160, 100, 352, 300), 60, fill=(255, 205, 60))
    o(d, d.rectangle, (230, 290, 282, 370), fill=(230, 170, 40))
    o(d, d.rounded_rectangle, (170, 360, 342, 415), 20, fill=(200, 140, 30))


def p_vd(im, d):
    o(d, d.rounded_rectangle, (56, 150, 244, 370), 36, fill=(60, 190, 90))
    o(d, d.rounded_rectangle, (268, 150, 456, 370), 36, fill=(230, 60, 70))
    text(d, (150, 262), "V", 230)
    text(d, (362, 262), "D", 230)


def p_epee(im, d):
    poly(d, [(236, 70), (276, 70), (276, 320), (256, 352), (236, 320)], (225, 230, 240), w=8)
    o(d, d.rounded_rectangle, (170, 318, 342, 350), 12, fill=(255, 200, 60))
    o(d, d.rectangle, (242, 350, 270, 410), fill=(140, 80, 40))
    o(d, d.ellipse, (226, 400, 286, 460), fill=(255, 200, 60))


def p_bouclier(im, d):
    poly(d, [(256, 80), (392, 136), (372, 290), (256, 430), (140, 290), (120, 136)], (70, 130, 230), w=12)
    poly(d, [(256, 130), (344, 170), (330, 280), (256, 380), (182, 280), (168, 170)], (120, 180, 255), w=6)
    star(d, 256, 255, 60, (255, 255, 255))


def p_etoile(im, d):
    star(d, 256, 262, 190, (255, 215, 60))


def p_cadenas(im, d):
    d.arc((154, 74, 358, 296), 180, 360, fill=DARK, width=52)
    d.arc((160, 80, 352, 290), 180, 360, fill=(170, 170, 185), width=36)
    o(d, d.rounded_rectangle, (126, 230, 386, 420), 36, fill=(200, 200, 215))
    d.ellipse((234, 290, 278, 334), fill=DARK)
    d.rectangle((246, 320, 266, 370), fill=DARK)


def p_pastille(im, d):
    o(d, d.ellipse, (116, 116, 396, 396), fill=(230, 40, 50))
    d.ellipse((180, 160, 240, 220), fill=(255, 170, 170))


# (nom, couleur haute, couleur basse du fond, peintre)
ICONES = [
    ("egg_r1", (80, 80, 90), (150, 150, 160), lambda im, d: egg(d, (235, 235, 240), True)),
    ("egg_r2", (20, 80, 40), (60, 160, 80), lambda im, d: egg(d, (80, 200, 90), True)),
    ("egg_r3", (15, 40, 100), (50, 100, 200), lambda im, d: egg(d, (60, 140, 255), True)),
    ("egg_r4", (50, 15, 90), (120, 60, 170), lambda im, d: egg(d, (170, 80, 230), True)),
    ("egg_r5", (120, 80, 10), (230, 170, 40), p_r5),
    ("egg_r6", (60, 0, 0), (20, 20, 25), p_r6),
    ("egg_r7", (10, 60, 90), (60, 200, 230), p_r7),
    ("egg_r8", (10, 10, 30), (90, 40, 160), lambda im, d: egg_rare(d, "secret")),
    ("egg_r9", (30, 30, 40), (120, 120, 140), lambda im, d: egg_rare(d, "exclusive")),
    ("egg_r10", (150, 110, 10), (255, 235, 150), lambda im, d: egg_rare(d, "divine")),

    ("type_feu", (25, 28, 45), (60, 66, 100), p_feu),
    ("type_eau", (25, 28, 45), (60, 66, 100), p_eau),
    ("type_plante", (25, 28, 45), (60, 66, 100), p_plante),
    ("type_terre", (25, 28, 45), (60, 66, 100), p_terre),
    ("type_ciel", (25, 28, 45), (60, 66, 100), p_ciel),
    ("type_ombre", (25, 28, 45), (60, 66, 100), p_ombre),
    ("type_lumiere", (25, 28, 45), (60, 66, 100), p_lumiere),
    ("type_glace", (25, 28, 45), (60, 66, 100), p_glace),
    ("type_foudre", (25, 28, 45), (60, 66, 100), p_foudre),

    ("r_coins_s", (50, 35, 10), (120, 85, 20), coins(2, 110, 46, 56, 380)),
    ("r_coins_m", (50, 35, 10), (120, 85, 20), coins(3, 128, 54, 52, 390)),
    ("r_coins_l", (50, 35, 10), (120, 85, 20), coins(5, 150, 62, 40, 410)),
    ("r_potion_chance", (20, 80, 60), (60, 150, 120), lambda im, d: potion(d)),
    ("r_boost_revenu", (50, 40, 10), (120, 95, 20), p_arrow_up),
    ("r_boost_vitesse", (15, 50, 110), (50, 120, 210), lambda im, d: shoe(d)),
    ("r_parchemin_xp", (90, 60, 20), (170, 120, 60), p_parchemin),
    ("r_plume", (60, 40, 10), (150, 100, 30), p_plume),
    ("r_jeton_combat", (90, 20, 20), (160, 50, 40), p_jeton),
    ("r_cosmetique_traine", (20, 20, 60), (70, 50, 140), p_etoile_filante),
    ("r_titre", (60, 10, 30), (130, 30, 60), p_titre),
    ("r_cadeau", (120, 30, 60), (200, 80, 110), lambda im, d: gift(d)),
    ("r_coffre", (50, 30, 10), (120, 80, 30), p_coffre),
    ("r_calendrier", (30, 50, 90), (80, 110, 170), p_calendrier),
    ("r_mystere", (80, 40, 120), (160, 90, 200), p_mystere),

    ("ui_trophee", (90, 60, 10), (200, 140, 30), p_trophee),
    ("ui_victoire_defaite", (30, 30, 60), (70, 70, 120), p_vd),
    ("ui_epee", (40, 40, 60), (110, 110, 140), p_epee),
    ("ui_bouclier", (20, 40, 90), (60, 100, 180), p_bouclier),
    ("ui_etoile", (90, 60, 10), (180, 120, 20), p_etoile),
    ("ui_cadenas", (40, 40, 50), (110, 110, 125), p_cadenas),
    ("ui_coeur", (110, 20, 40), (200, 60, 80), lambda im, d: heart(d)),
    ("ui_pastille_rouge", (60, 60, 70), (120, 120, 130), p_pastille),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(COPIE, exist_ok=True)
    for nom, c1, c2, peindre in ICONES:
        im, d = bg(c1, c2)
        peindre(im, d)
        im.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, nom + ".png"))
        shutil.copy(os.path.join(OUT, nom + ".png"), os.path.join(COPIE, nom + ".png"))
    print(len(ICONES), "icones ->", OUT)


if __name__ == "__main__":
    main()
