"""Vignette B Chipe-Oeufs : compteur « 1 sur N » (composition 2D PIL, sans nouveau modele).
Usage : python3 scripts/vignette_compteur.py
Entree : vignettes/chipe-oeufs-v2-mobs-1920x1080.png ; sortie : vignettes/chipe-oeufs-v3-compteur-1920x1080.png"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 1920, 1080
src = Image.open(f"{R}/vignettes/chipe-oeufs-v2-mobs-1920x1080.png").convert("RGB")
S = 1.9
big = src.resize((int(W * S), int(H * S)), Image.LANCZOS)
cx, cy = int(960 * S), int(455 * S)
ox, oy = cx - 1420, cy - 520
img = big.crop((ox, oy, ox + W, oy + H))
# fond sombre : degrade horizontal opaque a gauche, violet nuit du jeu
night = Image.new("RGB", (W, H), (22, 10, 44))
mask = Image.new("L", (W, H))
md = ImageDraw.Draw(mask)
for x in range(W):
    t = max(0.0, min(1.0, (1180 - x) / 330))
    md.line([(x, 0), (x, H)], fill=int(255 * (0.0 + 1.0 * t) if x < 1180 else 0))
img = Image.composite(night, img, mask.filter(ImageFilter.GaussianBlur(20)))
# vignettage leger
vig = Image.new("L", (W, H), 0)
ImageDraw.Draw(vig).ellipse((-300, -250, W + 300, H + 250), fill=255)
img = Image.composite(img, Image.new("RGB", (W, H), (10, 4, 22)), vig.filter(ImageFilter.GaussianBlur(160)))
d = ImageDraw.Draw(img)
F = "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf"
if not os.path.exists(F):
    F = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
f1 = ImageFont.truetype(F, 190)
f2 = ImageFont.truetype(F, 215)
def txt(xy, s, font, fill):
    x, y = xy
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((x + 8, y + 10), s, font=font, fill=(0, 0, 0, 200))
    sh = sh.filter(ImageFilter.GaussianBlur(8))
    img.paste(sh, (0, 0), sh)
    ImageDraw.Draw(img).text((x, y), s, font=font, fill=fill)
txt((90, 250), "1 sur", f1, (255, 214, 64))
txt((82, 430), "38 494", f2, (255, 255, 255))
d = ImageDraw.Draw(img)
d.rounded_rectangle((96, 700, 760, 716), 8, fill=(255, 120, 200))
d.rounded_rectangle((96, 700, 380, 716), 8, fill=(80, 220, 255))
img.save(f"{R}/vignettes/chipe-oeufs-v3-compteur-1920x1080.png")
img.resize((400, 225), Image.LANCZOS).save("/tmp/claude-0/-home-user-APPS-VIE/c9e841d1-d554-571c-a61d-bf92920d8724/scratchpad/v3_400.png")
