"""Génère les visuels de publication (icône, miniatures, icônes de pass) à partir des vraies formes de dinos du jeu.
Usage : python3 make_images.py  (nécessite Pillow). Aucun appel réseau."""
import re, math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "src", "shared")
OUT = os.path.join(HERE, "images")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
if not os.path.exists(FONT):
    FONT = "/usr/share/fonts/opentype/inter/Inter-Bold.otf"

# ---------- lecture des données Lua ----------
shapes_src = open(os.path.join(SRC, "DinoShapes.luau"), encoding="utf-8").read()
cfg_src = open(os.path.join(SRC, "Config.luau"), encoding="utf-8").read()
PART = re.compile(r'P\("(\w+)",\s*\{([^}]*)\},\s*\{([^}]*)\}(?:,\s*(nil|\{[^}]*\}))?(?:,\s*(true))?\)')
def nums(s): return [float(x) for x in s.split(",")]
shapes, extends = {}, {}
for m in re.finditer(r'^S\.(\w+) = \{(.*?)^\}', shapes_src, re.S | re.M):
    name, body = m.group(1), m.group(2)
    e = re.search(r'extends = "(\w+)"', body)
    if e: extends[name] = e.group(1)
    shapes[name] = [(p.group(1), nums(p.group(2)), nums(p.group(3)),
                     nums(p.group(4)[1:-1]) if p.group(4) and p.group(4) != "nil" else None, bool(p.group(5)))
                    for p in PART.finditer(body)]
def get_shape(n): return (get_shape(extends[n]) if n in extends else []) + shapes[n]

dinos = []
cfg_norm = re.sub(r"\s+", " ", cfg_src)
for m in re.finditer(r'\{ id = "(\w+)", name = "([^"]+)", rarity = "(\w+)", archetype = "(\w+)", scale = ([\d.]+), body = Color3.fromRGB\((\d+), (\d+), (\d+)\), accent = Color3.fromRGB\((\d+), (\d+), (\d+)\)', cfg_norm):
    g = m.groups()
    dinos.append(dict(id=g[0], name=g[1], rarity=g[2], arch=g[3], scale=float(g[4]), body=tuple(map(int, g[5:8])), accent=tuple(map(int, g[8:11])), neon="Neon" in cfg_norm[m.end():m.end()+120].split("}")[0]))
RAR = {"commun": (190,190,190), "peucommun": (110,220,110), "rare": (80,160,255), "epique": (190,100,255), "legendaire": (255,170,40), "mythique": (255,80,120)}
GOLD_BODY, GOLD_ACC = (255, 200, 40), (255, 140, 30)

def role_colors(d, golden=False):
    b, a = (GOLD_BODY, GOLD_ACC) if golden else (d["body"], d["accent"])
    light = lambda c, k: tuple(min(255, int(x + 255 * k)) for x in c)
    dark = lambda c, f: tuple(int(x * f) for x in c)
    return {"body": b, "belly": light(b, .25), "dark": dark(b, .65), "accent": a, "eye": (15,15,15), "tooth": (250,250,245)}

# ---------- rendu isométrique ----------
def rotmat(rx, ry, rz):
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    X = [[1,0,0],[0,cx,-sx],[0,sx,cx]]; Y = [[cy,0,sy],[0,1,0],[-sy,0,cy]]; Z = [[cz,-sz,0],[sz,cz,0],[0,0,1]]
    mul = lambda A,B: [[sum(A[i][k]*B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mul(mul(Z, Y), X)
def apply(R, v): return [sum(R[i][k]*v[k] for k in range(3)) for i in range(3)]

YAW, PITCH = math.radians(-38), math.radians(24)
def view(p):
    # rotation autour de Y puis inclinaison ; renvoie (x écran, y écran, profondeur)
    x, y, z = p
    x1 = x*math.cos(YAW) + z*math.sin(YAW); z1 = -x*math.sin(YAW) + z*math.cos(YAW)
    y2 = y*math.cos(PITCH) - z1*math.sin(PITCH); z2 = y*math.sin(PITCH) + z1*math.cos(PITCH)
    return x1, -y2, z2

FACES = [((0,1,2,3), (0,0,-1)), ((4,5,6,7), (0,0,1)), ((0,1,5,4), (-1,0,0)), ((2,3,7,6), (1,0,0)), ((0,3,7,4), (0,-1,0)), ((1,2,6,5), (0,1,0))]
def boxes_of(d, golden=False, flip=1.0):
    cols = role_colors(d, golden); out = []
    for role, size, pos, rot, mirror in get_shape(d["arch"]):
        for sign in ([1, -1] if mirror else [1]):
            R = rotmat(math.radians(rot[0]), math.radians(rot[1]*sign), math.radians(rot[2]*sign)) if rot else rotmat(0,0,0)
            hx, hy, hz = [s/2*d["scale"] for s in size]
            c = [pos[0]*sign*d["scale"], pos[1]*d["scale"], pos[2]*d["scale"]]
            corners = []
            for dx in (-1,1):
                for dy in (-1,1):
                    for dz in (-1,1):
                        corners.append(None)
            pts = [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]
            vs = []
            for sx, sy, sz in pts:
                w = apply(R, [sx*hx, sy*hy, sz*hz]); vs.append([c[0]+w[0], c[1]+w[1], c[2]+w[2]])
            out.append((role, cols.get(role, cols["body"]), vs, R))
    return out

def draw_dino(img, d, cx, base_y, unit, golden=False, glow=True):
    """Dessine le dino ; cx,base_y = point au sol ; unit = pixels par stud."""
    dr = ImageDraw.Draw(img, "RGBA")
    bx = boxes_of(d, golden)
    items = []
    for role, col, vs, R in bx:
        vp = [view(v) for v in vs]
        depth = sum(p[2] for p in vp) / 8
        items.append((depth, role, col, vs, vp, R))
    items.sort(key=lambda t: t[0])
    # ombre
    allx = [p[0] for it in items for p in it[4]]
    sh = Image.new("RGBA", img.size, (0,0,0,0)); sd = ImageDraw.Draw(sh)
    w = (max(allx) - min(allx)) * unit * .55
    sd.ellipse([cx - w, base_y - w*.18, cx + w, base_y + w*.22], fill=(0,0,0,90))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)))
    dr = ImageDraw.Draw(img, "RGBA")
    light = (0.4, 0.8, -0.5)
    for depth, role, col, vs, vp, R in items:
        for idx, normal in FACES:
            n = apply(R, list(normal))
            # visibilité : normale vue en espace écran (z2 négatif = face vers la caméra)
            nx, ny, nz = view(n)
            if nz > 0.02: continue
            lum = max(0.0, n[0]*light[0] + n[1]*light[1] + n[2]*light[2]) / 1.0
            k = 0.62 + 0.45 * lum
            c = tuple(max(0, min(255, int(x * k))) for x in col)
            poly = [(cx + vp[i][0]*unit, base_y + vp[i][1]*unit) for i in idx]
            dr.polygon(poly, fill=c + (255,), outline=tuple(int(x*.55) for x in col) + (255,))
    return img

def dino_extent(d):
    ps = [view(v)[:2] for _, _, vs, _ in boxes_of(d) for v in vs]
    return min(p[0] for p in ps), max(p[0] for p in ps), min(p[1] for p in ps), max(p[1] for p in ps)

def gradient(size, top, bottom):
    w, h = size; im = Image.new("RGBA", size)
    px = im.load()
    for y in range(h):
        t = y / (h - 1)
        c = tuple(int(top[i] + (bottom[i]-top[i])*t) for i in range(3)) + (255,)
        for x in range(w): px[x, y] = c
    return im

def sky_scene(size, rng):
    w, h = size
    im = gradient(size, (90, 170, 245), (190, 235, 255))
    d = ImageDraw.Draw(im, "RGBA")
    for _ in range(7):
        x, y, s = rng.randint(0, w), rng.randint(0, int(h*.4)), rng.randint(int(w*.06), int(w*.12))
        for dx, dy, r in [(0,0,1),(.7,.1,.8),(-.7,.15,.75),(.2,-.25,.7)]:
            d.ellipse([x+dx*s-s*r*.6, y+dy*s-s*r*.4, x+dx*s+s*r*.6, y+dy*s+s*r*.4], fill=(255,255,255,200))
    # collines + sol à blocs
    d.polygon([(0,h*.62),(w*.25,h*.5),(w*.5,h*.6),(w*.8,h*.48),(w,h*.58),(w,h),(0,h)], fill=(70,150,80,255))
    d.rectangle([0, h*.7, w, h], fill=(95, 175, 85, 255))
    for i in range(0, w, 90):
        d.rectangle([i, h*.7, i+45, h*.7+10], fill=(80,160,70,255))
    return im

def text(im, xy, s, size, fill=(255,255,255), stroke=(25,35,60), sw=None, anchor="la"):
    f = ImageFont.truetype(FONT, size)
    ImageDraw.Draw(im).text(xy, s, font=f, fill=fill, stroke_width=sw or max(3, size//12), stroke_fill=stroke, anchor=anchor)

def title_block(im, cx, y, size, sub=None):
    text(im, (cx+size//14, y+size//14), "DINO DIG PARK", size, fill=(20,30,40), stroke=(20,30,40), sw=size//10, anchor="ma")
    text(im, (cx, y), "DINO DIG PARK", size, fill=(255,214,60), stroke=(120,50,10), sw=size//9, anchor="ma")
    if sub: text(im, (cx, y + int(size*1.25)), sub, int(size*.42), fill=(255,255,255), stroke=(20,60,40), anchor="ma")

by_id = {d["id"]: d for d in dinos}
def place(im, did, cx, base, height_px, golden=False):
    d = by_id[did]
    x0, x1, y0, y1 = dino_extent(d)
    unit = height_px / (y1 - y0)
    # recentre horizontalement et cale le bas sur base
    draw_dino(im, d, cx - (x0+x1)/2*unit, base - y1*unit, unit, golden)

def rarity_chip(im, x, y, name, color, size=38):
    f = ImageFont.truetype(FONT, size)
    d = ImageDraw.Draw(im, "RGBA"); w = d.textlength(name, font=f)
    d.rounded_rectangle([x-w/2-18, y-4, x+w/2+18, y+size+10], radius=18, fill=color+(255,), outline=(20,25,40,255), width=4)
    d.text((x, y+size/2+3), name, font=f, fill=(255,255,255), anchor="mm", stroke_width=3, stroke_fill=(20,25,40))

def save(im, name):
    p = os.path.join(OUT, name); im.convert("RGB").save(p, optimize=True); print("écrit", p, im.size)

rng = random.Random(7)

# ---------- ICÔNE 512x512 ----------
ic = sky_scene((512, 512), rng)
place(ic, "rex", 256, 440, 300, golden=True)
text(ic, (256, 28), "DINO DIG", 76, fill=(255,214,60), stroke=(120,50,10), anchor="ma")
text(ic, (256, 100), "PARK", 76, fill=(255,214,60), stroke=(120,50,10), anchor="ma")
save(ic, "icone_512.png")

# ---------- MINIATURE 1 : héros 1920x1080 ----------
t1 = sky_scene((1920, 1080), rng)
place(t1, "brachio", 330, 800, 560)
place(t1, "ptera", 1560, 420, 260)
place(t1, "tricera", 640, 930, 300)
place(t1, "stego", 1300, 960, 330)
place(t1, "rex", 960, 1000, 650, golden=True)
title_block(t1, 960, 40, 190, "Creuse • Fais éclore • Construis ton parc")
save(t1, "miniature_1_heros.png")

# ---------- MINIATURE 2 : raretés ----------
t2 = gradient((1920, 1080), (45, 30, 90), (110, 60, 160))
d2 = ImageDraw.Draw(t2, "RGBA")
for _ in range(120):
    x, y, r = rng.randint(0,1920), rng.randint(0,700), rng.randint(2,5)
    d2.ellipse([x-r,y-r,x+r,y+r], fill=(255,255,255,rng.randint(90,230)))
d2.rectangle([0, 860, 1920, 1080], fill=(60, 140, 80, 255))
lineup = [("compy","commun"),("velo","peucommun"),("anky","rare"),("rex","epique"),("carno","legendaire"),("crystal","mythique")]
for i, (did, r) in enumerate(lineup):
    cx = 190 + i * 308
    h = 150 + i * 62
    place(t2, did, cx, 860, h)
    rarity_chip(t2, cx, 890, {"commun":"COMMUN","peucommun":"PEU COMMUN","rare":"RARE","epique":"ÉPIQUE","legendaire":"LÉGENDAIRE","mythique":"MYTHIQUE"}[r], RAR[r], 34)
text(t2, (960, 60), "18 DINOS À COLLECTIONNER", 130, fill=(255,255,255), stroke=(50,20,90), anchor="ma")
text(t2, (960, 215), "Dorés, légendaires, mythiques… et un dino secret !", 58, fill=(255,214,60), stroke=(50,20,90), anchor="ma")
save(t2, "miniature_2_raretes.png")

# ---------- MINIATURE 3 : fonctionnalités ----------
t3 = sky_scene((1920, 1080), rng)
d3 = ImageDraw.Draw(t3, "RGBA")
cards = [("⛏", "FOUILLE", "Déterre des fossiles", (255,160,60)), ("EGG", "ÉCLOSION", "Œufs jusqu'au Cosmique", (80,160,255)), ("$", "PARC", "6 enclos, boutiques, grande roue", (80,200,110)), ("*", "ÈRES", "Renaissance & bonus", (255,214,80))]
for i, (ic_, ttl, sub, col) in enumerate(cards):
    x = 130 + i * 445
    d3.rounded_rectangle([x, 560, x+400, 960], radius=40, fill=(30,40,70,235), outline=col+(255,), width=10)
    cxm = x + 200
    if ic_ == "EGG":
        d3.ellipse([cxm-55, 590, cxm+55, 740], fill=(235,225,195,255), outline=(160,130,90,255), width=8)
        for sx, sy in [(-20,640),(15,670),(-8,705)]: d3.ellipse([cxm+sx-12, sy-12, cxm+sx+12, sy+12], fill=(160,130,90,255))
    elif ic_ == "⛏":
        d3.rectangle([cxm-8, 600, cxm+8, 740], fill=(140,100,60,255)); d3.polygon([(cxm-70,630),(cxm,590),(cxm+70,630),(cxm+50,650),(cxm,625),(cxm-50,650)], fill=(200,205,215,255))
    elif ic_ == "$":
        d3.ellipse([cxm-60, 590, cxm+60, 710], fill=(255,214,60,255), outline=(160,110,20,255), width=8); text(t3, (cxm, 650), "$", 90, fill=(160,110,20), stroke=(255,240,160), sw=3, anchor="mm")
    else:
        pts = []
        for k in range(10):
            r = 70 if k % 2 == 0 else 30; a = -math.pi/2 + k*math.pi/5; pts.append((cxm + r*math.cos(a), 660 + r*math.sin(a)))
        d3.polygon(pts, fill=(255,214,80,255), outline=(160,110,20,255))
    text(t3, (cxm, 770), ttl, 62, fill=col, stroke=(15,20,40), anchor="ma")
    f = ImageFont.truetype(FONT, 32)
    text(t3, (cxm, 860), sub if len(sub) < 24 else sub[:24], 32, fill=(255,255,255), stroke=(15,20,40), sw=3, anchor="ma") if len(sub) < 24 else (text(t3, (cxm, 850), sub[:sub.rfind(" ", 0, 22)], 30, anchor="ma"), text(t3, (cxm, 895), sub[sub.rfind(" ", 0, 22)+1:], 30, anchor="ma"))
place(t3, "spino", 480, 520, 330)
place(t3, "dilopho", 1020, 520, 230)
place(t3, "galaxy", 1520, 520, 400)
title_block(t3, 960, 20, 150)
save(t3, "miniature_3_fonctions.png")

# ---------- ICÔNES DE PASS / PRODUITS (512x512) ----------
def pass_icon(name, line1, line2, col, did, golden=False):
    im = gradient((512, 512), tuple(int(c*.55) for c in col), col)
    d = ImageDraw.Draw(im, "RGBA")
    for _ in range(40):
        x, y, r = rng.randint(0,512), rng.randint(0,512), rng.randint(2,5)
        d.ellipse([x-r,y-r,x+r,y+r], fill=(255,255,255,120))
    place(im, did, 256, 400, 230, golden)
    text(im, (256, 30), line1, 96, fill=(255,255,255), stroke=(20,25,40), anchor="ma")
    text(im, (256, 130), line2, 52, fill=(255,230,90), stroke=(20,25,40), anchor="ma")
    save(im, name)
pass_icon("pass_revenus_x2.png", "x2", "REVENUS", (60,170,90), "rex", True)
pass_icon("pass_fouille_auto.png", "AUTO", "FOUILLE", (230,140,50), "anky")
pass_icon("pass_eclosion_rapide.png", "VITE !", "ÉCLOSION x2", (70,140,230), "velo")
pass_icon("produit_pack_fossiles.png", "FOSSILES", "PACK", (160,110,70), "kentro")
pass_icon("produit_pack_pieces.png", "PIÈCES", "PACK", (230,190,50), "dilopho")
pass_icon("pass_turbo.png", "TURBO", "COURS VITE", (200, 70, 70), "velo")
pass_icon("produit_boost_x2.png", "BOOST", "x2 • 10 MIN", (140, 90, 220), "rex", True)
pass_icon("produit_pack_depart.png", "DÉPART", "PACK + ŒUF", (60, 160, 200), "tricera")
