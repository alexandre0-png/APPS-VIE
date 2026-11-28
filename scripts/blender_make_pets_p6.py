import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
import bpy
from mathutils import Vector
OUT = sys.argv[1]; M = {}
R = math.radians
# Lot P6 (lot 31) : 4 creatures de combat sans modele (Tigre, Kraken, Calmar stellaire, Wyrm astral ; couleurs du Bestiary). Hauteur normalisee a ~1, devant = -y, origine au sol, gauche = +x.
# Noms de pieces : lettres et _ seulement (+ Seg1..Seg6) ; neon seulement via Yeux/Lueur/Runes/Eclairs/Flammes/Aureole.
def normalize():
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    zmin = min(p.z for p in pts); h = max(p.z for p in pts) - zmin
    f = 1.0 / h if (h < 0.95 or h > 1.15) else 1.0
    for o in objs:
        o.location = (o.location.x * f, o.location.y * f, (o.location.z - zmin) * f); o.scale = (o.scale.x * f,) * 3
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, scale=True)
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    return max(p.z for p in pts) - min(p.z for p in pts)
LOW = set()
_sph = sph
def sph(name, hexc, loc, r, sc=(1,1,1), seg=12, rings=8):
    # spheres lisses : pas de biseau (evite des triangles inutiles)
    old = os.environ.get("BEVEL"); os.environ["BEVEL"] = "0"
    try: return _sph(name, hexc, loc, r, sc, seg, rings)
    finally:
        if old is None: os.environ.pop("BEVEL", None)
        else: os.environ["BEVEL"] = old
CUR = ""
def reg(fn):
    global CUR
    CUR = fn.__name__; reset(); fn(); h = normalize(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx"))
    names = sorted(o.name.split("__")[0].split(".")[0] for o in bpy.context.scene.objects)
    M[fn.__name__] = {"parts": n, "tris": t, "height": round(h, 2), "names": names}
def eyes(y, z, s=0.14, r=0.075, c="1A1A1A", rf="FFFFFF"):
    for k in (-1, 1):
        sph("Oeil", c, (k*s, y, z), r, (1, 0.6, 1.2), seg=10, rings=6)
        sph("Reflet", rf, (k*s*0.9, y-0.04, z+0.04), r*0.4, seg=6, rings=4)
def eyesB(y, z, s=0.12, c="1A1A1A"):
    for k in (-1, 1):
        box("Oeil", c, (k*s, y, z), (0.09, 0.04, 0.12)); box("Reflet", "FFFFFF", (k*s*0.9, y-0.025, z+0.035), (0.04, 0.03, 0.04))
def cheeks(y, z, s=0.25, c="FF9AA8", r=0.06):
    for k in (-1, 1): sph("Joue", c, (k*s, y, z), r, (1, 0.4, 0.8), seg=8, rings=5)
def legsB(c, x=0.2, yf=-0.2, yb=0.4, h=0.3, w=0.15):
    for n, y in (("Av", yf), ("Ar", yb)):
        for s, k in (("G", 1), ("D", -1)): box(f"Patte_{n}{s}", c, (k*x, y, h/2), (w, w, h))
def legsL(c, x=0.2, yf=-0.2, yb=0.38, h=0.3, r=0.11):
    for n, y in (("Av", yf), ("Ar", yb)):
        for s, k in (("G", 1), ("D", -1)): sph(f"Patte_{n}{s}", c, (k*x, y, h/2), r, (1, 1, h/(2*r)), seg=8, rings=5)

def bar(name, c, base, d, ln, r1, r2, v=8):
    d = Vector(d).normalized(); loc = Vector(base) + d * ln / 2
    cone(name, c, tuple(loc), r1, r2, ln, tuple(d.to_track_quat("Z", "Y").to_euler()), v)
def G(k): return "G" if k > 0 else "D"


# Tigre (L) rare tier 5 : orange F58C28, rayures noires, ventre/museau creme, debout 4 pattes, queue rayee
def pet_tigre():
    o, k0, w = "F58C28", "1E1E1E", "FFF1DC"
    sph("Corps", o, (0, 0.12, 0.55), 0.3, (1, 1.55, 0.95), seg=14, rings=9)
    sph("Ventre", w, (0, 0.06, 0.4), 0.22, (1, 1.5, 0.6), seg=10, rings=6)
    sph("Tete", o, (0, -0.5, 0.78), 0.28, (1.1, 1, 1), seg=14, rings=9)
    sph("Museau", w, (0, -0.74, 0.7), 0.13, (1.2, 0.9, 0.8), seg=8, rings=5); sph("Nez", "E87A8A", (0, -0.85, 0.74), 0.045, seg=6, rings=4)
    eyes(-0.74, 0.86, 0.14, 0.065, "2A6A2A"); cheeks(-0.7, 0.68, 0.27, "FFF1DC", 0.07)
    for y in (-0.1, 0.12, 0.34): box("Rayure", k0, (0, y, 0.84), (0.32, 0.07, 0.05))
    for k in (-1, 1):
        for y in (-0.02, 0.26): box("Rayure", k0, (k*0.28, y, 0.6), (0.05, 0.07, 0.34), (0, 0, k*R(-12)))
        sph("Oreille", o, (k*0.2, -0.46, 1.02), 0.09, (1, 0.6, 1), seg=8, rings=5); sph("Oreille_in", w, (k*0.2, -0.5, 1.02), 0.05, (1, 0.5, 1), seg=6, rings=4)
        box("Rayure", k0, (k*0.1, -0.7, 1.0), (0.06, 0.04, 0.1))
    legsL(o, 0.2, -0.28, 0.5, 0.36, 0.1)
    for n2, y in (("Av", -0.28), ("Ar", 0.5)):
        for k in (-1, 1): sph("Pied", w, (k*0.2, y - 0.05, 0.05), 0.09, (1, 1.3, 0.55), seg=8, rings=5)
    bar("Queue", o, (0, 0.5, 0.6), (0, 0.6, 0.55), 0.4, 0.08, 0.07, 8); bar("Queue", k0, (0, 0.74, 0.8), (0, 0.15, 1), 0.34, 0.07, 0.06, 8)
    sph("Queue", k0, (0, 0.79, 1.14), 0.06, seg=8, rings=5)
# Kraken (L) rare tier 6 : violet 8C46BE, dome, 8 tentacules a ventouses
def pet_kraken():
    v, d, w = "8C46BE", "6A2E96", "E6C8F5"
    sph("Corps", v, (0, 0.0, 0.62), 0.4, (1, 1, 1.1), seg=16, rings=10)
    sph("Manteau", d, (0, 0.1, 0.9), 0.3, (1, 0.9, 0.8), seg=12, rings=7)
    sph("Ventre", w, (0, -0.2, 0.5), 0.26, (1, 0.6, 0.8), seg=10, rings=6)
    eyes(-0.34, 0.74, 0.17, 0.1, "1A1A1A"); cheeks(-0.3, 0.6, 0.3, "E6A0F0", 0.07)
    for k in (-1, 1): sph("Sourcil", d, (k*0.17, -0.3, 0.9), 0.08, (1.4, 0.5, 0.5), seg=8, rings=5)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        dx, dy = math.sin(a), -math.cos(a)
        b = (dx * 0.3, dy * 0.3, 0.25)
        bar("Tentacule", v if i % 2 == 0 else d, b, (dx, dy, -0.12), 0.46, 0.13, 0.085, 8)
        e = Vector(b) + Vector((dx, dy, -0.12)).normalized() * 0.46
        bar("Tentacule", v if i % 2 == 0 else d, tuple(e), (dx * 0.35, dy * 0.35, 1), 0.38, 0.085, 0.04, 8)
        sph("Articulation", v if i % 2 == 0 else d, tuple(e), 0.087, seg=8, rings=5)
# Calmar stellaire (L) epique tier 7 : turquoise 3CBEC8, manteau pointu, 2 nageoires, bras + 2 tentacules a massue etoilee, taches stellaires
def pet_calmar_stellaire():
    t, d, w = "3CBEC8", "2A8FA0", "D8FAFF"
    sph("Manteau", t, (0, 0.05, 0.95), 0.24, (1, 1, 2.1), seg=14, rings=10)
    cone("Pointe", d, (0, 0.05, 1.5), 0.12, 0.0, 0.3, v=8)
    sph("Tete", t, (0, -0.02, 0.56), 0.24, (1.1, 1, 0.9), seg=14, rings=9)
    sph("Ventre", w, (0, -0.15, 0.7), 0.15, (0.9, 0.5, 1.6), seg=8, rings=6)
    eyes(-0.21, 0.6, 0.17, 0.095, "1A1A1A"); cheeks(-0.18, 0.46, 0.2, "A8F0FF", 0.06)
    for k in (-1, 1):
        sph("Nageoire", d, (k*0.3, 0.1, 1.2), 0.2, (0.3, 0.9, 1.2), seg=9, rings=6)
        bar("Tentacule", t, (k*0.1, -0.1, 0.4), (k*0.5, -0.6, -0.3), 0.55, 0.05, 0.03, 6)
        sph("Massue", "7FF0FF", (k*0.1 + k*0.5*0.55*0.64, -0.1 - 0.6*0.55*0.64, 0.4 - 0.3*0.55*0.64), 0.075, (1, 1, 0.8), seg=6, rings=4)
    for i in range(6):
        a = math.radians(i * 60 + 30)
        bar("Bras", t if i % 2 == 0 else d, (math.sin(a)*0.13, -math.cos(a)*0.13 + 0.0, 0.42), (math.sin(a)*0.35, -math.cos(a)*0.35, -1), 0.4, 0.06, 0.02, 6)
    for p in ((0, -0.2, 1.1), (0.14, -0.1, 0.92), (-0.12, -0.12, 1.28), (0.1, 0.2, 1.0), (-0.1, 0.22, 0.8)): sph("Lueur", "FFFFFF", p, 0.04, seg=6, rings=4)
    sph("Etoile", "FFE680", (0, -0.24, 0.9), 0.05, (1, 0.5, 1), seg=5, rings=3)
# Wyrm astral (L) tier 7 : bleu 50A0FF, dragon assis, ailes, queue enroulee, cornes, taches stellaires
def pet_wyrm_astral():
    b, d, g, s = "50A0FF", "2E6ED0", "C8E4FF", "FFE680"
    sph("Corps", b, (0, 0.1, 0.5), 0.36, (1, 0.95, 1.15), seg=14, rings=9); sph("Ventre", g, (0, -0.1, 0.46), 0.3, (0.8, 0.5, 1.0), seg=10, rings=7)
    sph("Cou", b, (0, -0.12, 0.82), 0.17, (1, 1, 1.2), seg=10, rings=7)
    sph("Tete", b, (0, -0.28, 1.0), 0.28, (1, 1.05, 0.9), seg=14, rings=9); sph("Museau", g, (0, -0.55, 0.94), 0.13, (1, 0.9, 0.7), seg=8, rings=5)
    eyes(-0.52, 1.04, 0.14, 0.07, "FFE680", "FFFFFF"); cheeks(-0.47, 0.92, 0.24, "A8D0FF", 0.06)
    for k in (-1, 1):
        sg = G(k)
        cone("Corne", s, (k*0.18, -0.2, 1.33), 0.07, 0.0, 0.32, (R(-20), k*0.3, 0), 5)
        sph("Aile" + sg, d, (k*0.52, 0.25, 0.95), 0.36, (0.3, 0.75, 1.15), seg=9, rings=6)
        sph("Aile_Bout" + sg, "7AB8FF", (k*0.62, 0.3, 1.28), 0.12, (0.3, 0.8, 1.2), seg=7, rings=5)
        sph("Patte_Av" + sg, b, (k*0.28, -0.25, 0.35), 0.1, (0.9, 0.9, 1.5), seg=8, rings=5)
        sph("Patte_Ar" + sg, b, (k*0.3, 0.12, 0.17), 0.2, (0.9, 1.3, 0.85), seg=9, rings=6)
        sph("Pied", g, (k*0.28, -0.33, 0.07), 0.09, (1, 1.3, 0.6), seg=8, rings=5)
        sph("Lueur", "FFFFFF", (k*0.55, 0.2, 1.0), 0.04, seg=6, rings=4)
    sph("Queue", b, (0.05, 0.5, 0.2), 0.16, (1, 1.4, 0.8), seg=10, rings=6); sph("Queue", d, (0.22, 0.85, 0.12), 0.12, (1, 1.3, 0.8), seg=9, rings=6)
    sph("Queue", b, (0.42, 1.0, 0.1), 0.09, (1.3, 1, 0.8), seg=8, rings=5); cone("Pointe_queue", s, (0.58, 1.02, 0.1), 0.09, 0.0, 0.2, (0, R(90), 0), 4)
    for i in range(4): cone("Pic", s, (0, 0.38 + i*0.0, 0.8 - i*0.14) if False else (0, 0.4 + i*0.07, 0.88 - i*0.17), 0.05, 0.0, 0.15 + 0.01*i, (R(40), 0, 0), 4)
    for p in ((0.18, 0.0, 0.7), (-0.2, 0.05, 0.6), (0.0, -0.3, 0.64)): sph("Lueur", "FFFFFF", p, 0.04, seg=6, rings=4)
    sph("Etoile", s, (0, -0.4, 0.78), 0.06, seg=5, rings=3)

for fn in [pet_tigre, pet_kraken, pet_calmar_stellaire, pet_wyrm_astral]: reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1); print("OK", len(M), {k:(v["parts"],v["tris"],v["height"]) for k,v in M.items()})
