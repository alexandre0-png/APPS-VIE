import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
import bpy
from mathutils import Vector
OUT = sys.argv[1]; M = {}
R = math.radians
# Lot P5 du bestiaire (table C.2 de LOTS_9_PLUS.md). Hauteur normalisee a ~1, devant = -y, origine au sol, gauche = +x.
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

# 52 Griffon (L, 30) assis, ailes repliees
def pet_griffon():
    b, w, bk = "C9A27A", "FAFAFA", "F0B84A"
    sph("Corps", b, (0, 0.25, 0.4), 0.32, (1, 1.15, 1.0), seg=12, rings=8)
    sph("Poitrail", w, (0, -0.05, 0.5), 0.26, (1, 0.8, 1.1), seg=10, rings=6)
    sph("Collerette", w, (0, -0.1, 0.78), 0.26, (1.1, 0.8, 0.9), seg=10, rings=6)
    sph("Tete", w, (0, -0.2, 0.98), 0.26, (1, 0.95, 0.95), seg=12, rings=8)
    cone("Bec", bk, (0, -0.45, 0.93), 0.1, 0.0, 0.22, (R(90) + R(15), 0, 0), 6)
    for k in (-1, 1):
        sph("Oeil", "1A1A1A", (k*0.12, -0.42, 1.02), 0.06, (1, 0.6, 1.2), seg=8, rings=5)
        sph("Reflet", "FFFFFF", (k*0.11, -0.46, 1.05), 0.022, seg=6, rings=4)
        cone("Aigrette", b, (k*0.16, -0.1, 1.24), 0.06, 0.0, 0.2, (0, k*0.3, 0), 5)
        sph("Aile" + G(k), w, (k*0.34, 0.35, 0.62), 0.26, (0.3, 1.0, 1.2), seg=10, rings=6)
        sph("Pointe_Aile", b, (k*0.34, 0.55, 0.42), 0.12, (0.4, 1.2, 1.4), seg=8, rings=5)
        sph("Patte_Av" + G(k), w, (k*0.15, -0.15, 0.18), 0.09, (1, 1, 2.0), seg=8, rings=5)
        sph("Griffe", bk, (k*0.15, -0.22, 0.05), 0.08, (1, 1.3, 0.6), seg=8, rings=5)
        sph("Patte_Ar" + G(k), b, (k*0.3, 0.4, 0.17), 0.15, (0.9, 1.5, 1.0), seg=8, rings=5)
        sph("Griffe", bk, (k*0.3, 0.2, 0.05), 0.08, (1, 1.3, 0.6), seg=8, rings=5)
    bar("Queue", b, (0, 0.55, 0.3), (0, 1, -0.2), 0.45, 0.09, 0.04, 7)
    sph("Queue_Touffe", w, (0, 0.98, 0.22), 0.1, (1, 1.3, 1), seg=8, rings=5)
    sph("Ventre", "E8D2B0", (0, 0.1, 0.25), 0.2, (1, 1.2, 0.5), seg=8, rings=5)

# 53 Mammouth (B, 26)
def pet_mammouth():
    f, iv, d = "7A4E2A", "F5EBD7", "5A3820"
    box("Corps", f, (0, 0.1, 0.55), (0.7, 0.95, 0.62)); box("Pelage", d, (0, 0.05, 0.92), (0.5, 0.6, 0.12))
    box("Tete", f, (0, -0.5, 0.7), (0.55, 0.45, 0.5)); box("Toupet", d, (0, -0.48, 1.02), (0.3, 0.3, 0.12))
    for i, (y, z, s) in enumerate(((-0.78, 0.6, 0.17), (-0.84, 0.43, 0.15), (-0.84, 0.27, 0.13))): box("Trompe", f, (0, y, z), (s, s, 0.18))
    for k in (-1, 1):
        box("Oreille", f, (k*0.37, -0.45, 0.78), (0.08, 0.3, 0.34))
        box("Defense", iv, (k*0.22, -0.74, 0.5), (0.07, 0.1, 0.34), (R(-25), 0, 0))
        box("Defense", iv, (k*0.24, -0.86, 0.34), (0.07, 0.2, 0.08), (R(-10), 0, 0))
        box("Oeil", "1A1A1A", (k*0.15, -0.73, 0.78), (0.07, 0.04, 0.09))
        box("Patte_Av" + G(k), f, (k*0.23, -0.2, 0.17), (0.24, 0.26, 0.34)); box("Pied", d, (k*0.23, -0.2, 0.03), (0.26, 0.3, 0.07))
        box("Patte_Ar" + G(k), f, (k*0.23, 0.45, 0.17), (0.24, 0.26, 0.34)); box("Pied", d, (k*0.23, 0.45, 0.03), (0.26, 0.3, 0.07))
    box("Queue", d, (0, 0.62, 0.5), (0.08, 0.08, 0.3)); box("Ventre", d, (0, 0.1, 0.27), (0.6, 0.8, 0.08))

# 54 Pegase (L, 30) cabre
def pet_pegase():
    w, g = "FAFAFA", "FFE680"
    bar("Corps", w, (0, -0.1, 0.8), (0, 0.6, -0.5), 0.75, 0.27, 0.23, 10)
    bar("Cou", w, (0, -0.22, 0.88), (0, -0.4, 0.9), 0.5, 0.15, 0.1, 8)
    sph("Tete", w, (0, -0.45, 1.38), 0.17, (0.9, 1.3, 1.0), seg=12, rings=8); sph("Museau", w, (0, -0.6, 1.3), 0.1, (0.9, 1.0, 0.85), seg=8, rings=5)
    sph("Nez", "E89AA8", (0, -0.69, 1.3), 0.035, seg=6, rings=4)
    sph("Criniere", g, (0, -0.2, 1.3), 0.1, (0.6, 1.2, 1.4), seg=8, rings=5); sph("Criniere", g, (0, -0.1, 1.05), 0.1, (0.6, 1.2, 1.4), seg=8, rings=5)
    sph("Toupet", g, (0, -0.4, 1.55), 0.07, (0.6, 1, 1.2), seg=8, rings=5)
    for k in (-1, 1):
        sph("Oeil", "1A1A1A", (k*0.11, -0.55, 1.42), 0.04, (1, 0.6, 1.2), seg=8, rings=5)
        cone("Oreille", w, (k*0.07, -0.37, 1.58), 0.04, 0.0, 0.12, v=5)
        bar("Patte_Av" + G(k), w, (k*0.15, -0.3, 0.72), (0, -0.7, 0.35), 0.4, 0.07, 0.05, 8); sph("Sabot", "8A6A3A", (k*0.15, -0.6, 0.9), 0.06, (1, 1, 0.8), seg=6, rings=4)
        bar("Patte_Ar" + G(k), w, (k*0.15, 0.4, 0.55), (0, 0.1, -1), 0.5, 0.09, 0.05, 8); sph("Sabot", "8A6A3A", (k*0.15, 0.45, 0.04), 0.065, (1, 1, 0.7), seg=6, rings=4)
        sph("Aile" + G(k), g, (k*0.3, 0.2, 1.0), 0.34, (0.18, 0.9, 1.1), seg=9, rings=6)
        sph("Plume_Aile", w, (k*0.34, 0.4, 0.78), 0.18, (0.18, 0.7, 1.2), seg=8, rings=5)
    bar("Queue", g, (0, 0.5, 0.6), (0, 0.6, -0.8), 0.6, 0.09, 0.03, 7); sph("Queue_Touffe", g, (0, 0.78, 0.15), 0.09, (0.8, 1, 1.5), seg=8, rings=5)
    sph("Joue", "FFB0D0", (0.14, -0.55, 1.33), 0.03, seg=6, rings=4)

# 55 Panthere d'ombre (L, 24) a l'affut
def pet_panthere_d_ombre():
    d, e = "1E1A28", "B04DFF"
    sph("Corps", d, (0, 0.2, 0.42), 0.27, (0.85, 1.9, 0.8), seg=14, rings=8)
    sph("Epaule", "2A2438", (0, -0.2, 0.5), 0.22, (1, 0.9, 0.9), seg=10, rings=6)
    sph("Tete", d, (0, -0.65, 0.4), 0.22, (1, 0.95, 0.9), seg=12, rings=8); sph("Museau", "2A2438", (0, -0.84, 0.35), 0.1, (1, 0.9, 0.7), seg=8, rings=5)
    sph("Nez", "6A4A7A", (0, -0.93, 0.37), 0.03, seg=6, rings=4)
    for k in (-1, 1):
        cone("Oreille", d, (k*0.14, -0.58, 0.62), 0.07, 0.0, 0.14, (0, k*0.2, 0), 5)
        sph("Yeux", e, (k*0.1, -0.84, 0.46), 0.04, (1, 0.5, 1.2), seg=8, rings=5)
        sph("Patte_Av" + G(k), d, (k*0.2, -0.45, 0.14), 0.08, (1, 1.8, 1.7), seg=8, rings=5); sph("Pied", "2A2438", (k*0.2, -0.58, 0.04), 0.08, (1, 1.3, 0.6), seg=8, rings=5)
        sph("Patte_Ar" + G(k), d, (k*0.25, 0.62, 0.2), 0.14, (0.9, 1.5, 1.2), seg=8, rings=5); sph("Pied", "2A2438", (k*0.25, 0.45, 0.04), 0.08, (1, 1.3, 0.6), seg=8, rings=5)
    bar("Queue", d, (0, 0.66, 0.4), (0, 1.0, 0.6), 0.7, 0.09, 0.04, 7); sph("Queue_Bout", "2A2438", (0, 1.23, 0.8), 0.06, seg=8, rings=5)
    for i in range(3): sph("Rayure", "2A2438", (0, 0.0 + i*0.3, 0.6 - 0.03*i), 0.07, (1, 1.5, 0.3), seg=8, rings=5)

# 58 Hydre des marais (L, 30) dressee, 3 tetes
def pet_hydre_des_marais():
    g, v, p = "3E6E3A", "A8C070", "E8E0A0"
    sph("Corps", g, (0, 0.15, 0.32), 0.38, (1, 1.2, 0.8), seg=14, rings=8); sph("Ventre", v, (0, -0.1, 0.25), 0.28, (0.85, 0.7, 0.6), seg=10, rings=6)
    for n, x, a in (("Tete", 0, 0), ("TeteG", 0.3, 0.5), ("TeteD", -0.3, -0.5)):
        s = 1 if x >= 0 else -1
        top = (x*1.0, -0.2 - abs(x)*0.2, 0.9 if x == 0 else 0.78)
        bar("Cou", g, (x*0.4, -0.15, 0.5), (top[0]-x*0.4, top[1]+0.15, top[2]-0.5), 0.5 if x == 0 else 0.4, 0.12, 0.09, 8)
        sph(n, g, top, 0.17, (1, 1.15, 0.9), seg=10, rings=6); sph("Museau", v, (top[0], top[1]-0.15, top[2]-0.04), 0.1, (1, 1, 0.7), seg=8, rings=5)
        for k in (-1, 1): sph("Oeil", "FFD23F", (top[0]+k*0.08, top[1]-0.1, top[2]+0.07), 0.04, (1, 0.6, 1.2), seg=6, rings=4)
    for k in (-1, 1):
        sph("Patte_Av" + G(k), g, (k*0.28, -0.12, 0.12), 0.12, (1, 1.1, 1), seg=8, rings=5)
        sph("Patte_Ar" + G(k), g, (k*0.3, 0.45, 0.12), 0.12, (1, 1.1, 1), seg=8, rings=5)
    bar("Queue", g, (0, 0.5, 0.28), (0, 1, 0.1), 0.65, 0.16, 0.03, 8)
    for i in range(3): cone("Pic", "5A8A48", (0, -0.0 + i*0.25, 0.7 - i*0.05), 0.05, 0.0, 0.14, v=4)
    for i in range(2): sph("Mousse", "6AA040", (0.15 - i*0.3, 0.25, 0.65), 0.09, (1, 1, 0.5), seg=6, rings=4)

# 59 Golem de pierre (B, 26)
def pet_golem_de_pierre():
    s, d, r = "8E93A0", "70757F", "7FE8FF"
    box("Corps", s, (0, 0, 0.62), (0.75, 0.5, 0.6)); box("Ceinture", d, (0, 0, 0.3), (0.5, 0.4, 0.1)); box("Tete", s, (0, -0.02, 1.08), (0.4, 0.38, 0.32))
    box("Front", d, (0, -0.19, 1.18), (0.36, 0.04, 0.06))
    for k in (-1, 1):
        box("Yeux", r, (k*0.1, -0.2, 1.08), (0.09, 0.03, 0.06))
        box("Epaule", d, (k*0.5, 0, 0.9), (0.28, 0.3, 0.22))
        box("Bras_" + G(k), s, (k*0.52, 0, 0.55), (0.24, 0.26, 0.5)); box("Poing", d, (k*0.52, -0.02, 0.22), (0.3, 0.3, 0.24))
        box("Jambe_" + G(k), s, (k*0.18, 0, 0.12), (0.26, 0.3, 0.26)); box("Pied", d, (k*0.18, -0.08, 0.03), (0.3, 0.4, 0.06))
        box("Caillou", d, (k*0.3, 0.1, 1.02), (0.1, 0.1, 0.1), (0.3, 0.3, 0.3))
    for i, (x, z) in enumerate(((0, 0.78), (-0.2, 0.6), (0.2, 0.5), (0, 0.45), (-0.18, 0.88))): box("Runes", r, (x, -0.255, z), (0.1, 0.02, 0.1), (0, 0, 0.3*i))
    box("Mousse", "6A9A4A", (0.2, 0.0, 0.94), (0.18, 0.2, 0.05)); box("Fissure", d, (-0.2, -0.26, 0.7), (0.03, 0.02, 0.2), (0, 0, 0.5))

# 61 Serpent foudre (L, 20) enroule 5 segments
def pet_serpent_foudre():
    n, e, y = "2A2A5A", "3A3A7A", "FFE14A"
    P = ((0.28, 0.0, 0.14, 0.17), (0.0, 0.3, 0.17, 0.16), (-0.3, 0.0, 0.2, 0.15), (0.0, -0.25, 0.3, 0.14), (0.05, -0.02, 0.56, 0.13))
    for i, (x, yy, z, r) in enumerate(P): sph(f"Seg{i+1}", n if i % 2 == 0 else e, (x, yy, z), r, (1, 1.1, 1), seg=10, rings=7)
    bar("Cou", n, (0.05, -0.02, 0.56), (0, -0.1, 1), 0.3, 0.12, 0.1, 8)
    sph("Tete", n, (0.05, -0.1, 0.92), 0.16, (1, 1.2, 0.9), seg=12, rings=8)
    sph("Museau", e, (0.05, -0.25, 0.88), 0.08, (1, 1, 0.7), seg=8, rings=5); cone("Langue", "E83A5A", (0.05, -0.36, 0.86), 0.015, 0.0, 0.12, (R(90), 0, 0), 4)
    for k in (-1, 1):
        sph("Yeux", y, (0.05 + k*0.09, -0.2, 0.97), 0.04, (1, 0.6, 1.2), seg=6, rings=4)
        box("Eclairs", y, (0.05 + k*0.12, -0.02, 0.78), (0.05, 0.05, 0.14), (0, 0, k*0.5))
    for i, (x, yy, z) in enumerate(((0.38, 0.0, 0.3), (0.0, 0.42, 0.3), (-0.4, 0.0, 0.34))): box("Eclairs", y, (x, yy, z), (0.06, 0.06, 0.16), (0.3*i, 0.3, 0.5*i))
    cone("Queue", n, (0.3, -0.12, 0.08), 0.06, 0.0, 0.3, (R(90), 0, 0), 6)
    sph("Lueur", y, (0.05, -0.02, 0.4), 0.05, seg=6, rings=4)

# 65 Oiseau-tonnerre (L, 32) en vol
def pet_oiseau_tonnerre():
    n, y, g = "2A3A6A", "FFE14A", "4A5A90"
    sph("Corps", n, (0, 0.05, 0.6), 0.28, (0.9, 1.2, 1.0), seg=12, rings=8); sph("Ventre", g, (0, -0.1, 0.52), 0.2, (0.9, 0.8, 0.9), seg=10, rings=6)
    sph("Tete", n, (0, -0.22, 0.98), 0.2, seg=12, rings=8); cone("Bec", y, (0, -0.42, 0.95), 0.07, 0.0, 0.2, (R(90) + R(10), 0, 0), 6)
    for i in range(3): cone("Crete", y, (0, -0.15 + i*0.07, 1.18 - i*0.02), 0.04, 0.0, 0.2, (R(-20)*(i-1) + R(10), 0, 0), 4)
    for k in (-1, 1):
        sph("Oeil", "FFFFFF", (k*0.1, -0.36, 1.02), 0.05, (1, 0.6, 1.2), seg=8, rings=5); sph("Reflet", "1A1A1A", (k*0.1, -0.4, 1.02), 0.025, seg=6, rings=4)
        box("Bras_" + G(k), n, (k*0.26, -0.05, 0.62), (0.1, 0.12, 0.2))
        sph("Aile" + G(k), n, (k*0.7, 0.1, 0.9), 0.5, (1, 0.3, 0.5), seg=10, rings=6)
        for j in range(2): sph("Plume_Aile", y, (k*(1.0 + j*0.2), 0.12 + j*0.1, 0.9 + 0.05*j), 0.2, (1, 0.25, 0.3), seg=8, rings=5)
        box("Jambe_" + G(k), "E8A030", (k*0.12, 0.05, 0.3), (0.07, 0.07, 0.34)); box("Serre", "E8A030", (k*0.12, -0.04, 0.1), (0.14, 0.16, 0.06))
        box("Eclairs", y, (k*0.95, 0.0, 1.1), (0.06, 0.06, 0.22), (0, 0.4*k, 0.5))
    bar("Queue", n, (0, 0.35, 0.55), (0, 1, -0.3), 0.4, 0.14, 0.05, 6)
    for i, a in enumerate((-0.3, 0, 0.3)): box("Plume_Queue", y, (math.sin(a)*0.2, 0.8, 0.42), (0.08, 0.3, 0.04), (R(-15), 0, -a))
    sph("Lueur", y, (0, -0.12, 0.62), 0.06, seg=6, rings=4)
    box("Eclairs", y, (0, 0.5, 0.95), (0.05, 0.05, 0.2), (0.2, 0, 0.4))

# 66 Chimere d'ombre (L, 36) lion + chevre + serpent
def pet_chimere_d_ombre():
    d, m, f = "2A1A3A", "3E2A58", "8A3CFF"
    sph("Corps", d, (0, 0.2, 0.5), 0.3, (0.9, 1.5, 0.9), seg=14, rings=8); sph("Ventre", m, (0, 0.1, 0.35), 0.2, (0.9, 1.3, 0.5), seg=8, rings=5)
    sph("Criniere", m, (0, -0.35, 0.72), 0.3, (1.1, 0.8, 1.0), seg=12, rings=7)
    sph("Tete", d, (0, -0.5, 0.78), 0.22, (1, 0.95, 0.95), seg=12, rings=8); sph("Museau", m, (0, -0.68, 0.7), 0.1, (1, 0.9, 0.75), seg=8, rings=5)
    sph("Nez", "1A1A1A", (0, -0.77, 0.73), 0.03, seg=6, rings=4)
    cone("Croc", "F2F2F2", (0.05, -0.74, 0.62), 0.015, 0.0, 0.07, (R(180), 0, 0), 4); cone("Croc", "F2F2F2", (-0.05, -0.74, 0.62), 0.015, 0.0, 0.07, (R(180), 0, 0), 4)
    bar("Cou_Chevre", d, (0.0, 0.1, 0.78), (0, 0.1, 1), 0.3, 0.09, 0.07, 7)
    sph("TeteChevre", m, (0, 0.05, 1.2), 0.14, (0.9, 1.2, 1.0), seg=10, rings=6); sph("Barbiche", "F2F2F2", (0, -0.08, 1.08), 0.04, (0.7, 0.7, 1.4), seg=6, rings=4)
    for k in (-1, 1):
        sph("Oeil", "FFD23F", (k*0.09, -0.69, 0.84), 0.04, (1, 0.6, 1.2), seg=6, rings=4)
        cone("Oreille", d, (k*0.15, -0.47, 0.98), 0.06, 0.0, 0.13, (0, k*0.3, 0), 5)
        sph("Oeil_Chevre", "FFD23F", (k*0.07, -0.05, 1.23), 0.03, (1, 0.6, 1.2), seg=6, rings=4)
        bar("Corne", "C8C0D0", (k*0.07, 0.08, 1.3), (k*0.5, 0.5, 1), 0.24, 0.04, 0.0, 5)
        sph("Patte_Av" + G(k), d, (k*0.2, -0.2, 0.2), 0.1, (1, 1, 2.0), seg=8, rings=5)
        sph("Patte_Ar" + G(k), d, (k*0.22, 0.58, 0.2), 0.12, (1, 1.2, 1.7), seg=8, rings=5)
    bar("Queue", d, (0, 0.6, 0.55), (0, 1, 0.5), 0.6, 0.07, 0.04, 7); sph("Queue_Tete", m, (0, 1.14, 0.83), 0.09, (1, 1.2, 0.9), seg=8, rings=5)
    cone("Queue_Langue", "E83A5A", (0, 1.25, 0.83), 0.01, 0.0, 0.1, (R(-90), 0, 0), 4)
    for i, (y, z, s) in enumerate(((-0.3, 1.0, 0.12), (-0.1, 0.9, 0.1), (0.25, 0.9, 0.12), (0.55, 0.82, 0.1))): cone("Flammes", f, (0, y, z), s, 0.0, s*2.2, v=5)
    sph("Lueur", f, (0, 0.2, 0.52), 0.05, seg=6, rings=4)

# 72 Loup-garou citrouille (B, 30)
def pet_loup_garou_citrouille():
    o, k0 = "FF7A1A", "1E1E1E"
    box("Corps", k0, (0, 0.02, 0.5), (0.52, 0.36, 0.5)); box("Ceinture", "6A3A1A", (0, 0.02, 0.28), (0.54, 0.38, 0.06)); box("Boucle", "FFD24A", (0, -0.18, 0.28), (0.1, 0.03, 0.08))
    box("Tete", o, (0, -0.05, 0.98), (0.56, 0.5, 0.5)); cone("Tige", "4E7A3A", (0, -0.05, 1.3), 0.07, 0.05, 0.14, v=6)
    box("Feuille", "4E7A3A", (0.09, -0.05, 1.33), (0.12, 0.05, 0.03), (0, 0.3, 0.4))
    box("Nez", "1E1E1E", (0, -0.31, 0.95), (0.08, 0.04, 0.08)); box("Bouche", "1E1E1E", (0, -0.31, 0.82), (0.3, 0.03, 0.08))
    for x in (-0.1, 0, 0.1): box("Dent", "F5EBD7", (x, -0.33, 0.87 if x == 0 else 0.87), (0.05, 0.03, 0.06))
    for k in (-1, 1):
        box("Yeux", "FFD24A", (k*0.14, -0.31, 1.04), (0.13, 0.03, 0.09), (0, 0, k*0.3))
        cone("Oreille", k0, (k*0.2, -0.02, 1.3), 0.09, 0.0, 0.2, (0, k*0.15, 0), 4)
        box("Bras_" + G(k), k0, (k*0.36, 0, 0.5), (0.14, 0.16, 0.42), (0, 0, k*0.1)); box("Main", o, (k*0.4, -0.02, 0.26), (0.18, 0.2, 0.14))
        for j in (-1, 0, 1): box("Griffe", "F5EBD7", (k*0.4 + j*0.05, -0.14, 0.2), (0.025, 0.06, 0.04))
        box("Jambe_" + G(k), k0, (k*0.14, 0.02, 0.13), (0.2, 0.24, 0.26)); box("Pied", o, (k*0.14, -0.06, 0.03), (0.22, 0.34, 0.06))
    box("Queue", o, (0, 0.28, 0.4), (0.14, 0.28, 0.14), (R(-30), 0, 0))

# 73 Renne etoile (L, 30)
def pet_renne_etoile():
    w, g, d = "FAFAFA", "FFD24A", "6A4E32"
    sph("Corps", w, (0, 0.15, 0.55), 0.28, (0.85, 1.5, 0.95), seg=12, rings=8)
    bar("Cou", w, (0, -0.2, 0.65), (0, -0.4, 0.8), 0.35, 0.1, 0.08, 8)
    sph("Tete", w, (0, -0.38, 1.0), 0.17, (0.9, 1.1, 1.0), seg=12, rings=8); sph("Museau", "F0E8E0", (0, -0.5, 0.95), 0.09, (0.9, 1, 0.8), seg=8, rings=5)
    sph("Nez", "E83A3A", (0, -0.58, 0.96), 0.045, seg=8, rings=5)
    for k in (-1, 1):
        sph("Oeil", "1A1A1A", (k*0.09, -0.5, 1.05), 0.04, (1, 0.6, 1.2), seg=6, rings=4); sph("Oreille", w, (k*0.18, -0.35, 1.05), 0.06, (1.4, 0.5, 0.8), seg=6, rings=4)
        bar("Bois", g, (k*0.08, -0.33, 1.12), (k*0.5, 0, 1), 0.3, 0.025, 0.02, 5)
        bar("Andouiller", g, (k*0.15, -0.33, 1.28), (k*0.6, -0.8, 0.5), 0.14, 0.02, 0.0, 4)
        bar("Andouiller", g, (k*0.2, -0.33, 1.34), (k*0.6, 0.5, 0.9), 0.14, 0.02, 0.0, 4)
        cyl("Patte_Av" + G(k), w, (k*0.14, -0.1, 0.22), 0.05, 0.44, v=8); cyl("Sabot", d, (k*0.14, -0.1, 0.03), 0.055, 0.06, v=8)
        cyl("Patte_Ar" + G(k), w, (k*0.14, 0.5, 0.22), 0.055, 0.44, v=8); cyl("Sabot", d, (k*0.14, 0.5, 0.03), 0.06, 0.06, v=8)
    sph("Queue", w, (0, 0.68, 0.62), 0.07, seg=6, rings=4)
    torus("Guirlande", "2E9A4A", (0, -0.2, 0.8), 0.15, 0.025, (R(70), 0, 0))
    for i, a in enumerate((0.3, 1.5, 2.7, 4.0)): sph("Lueur", "FF5A5A" if i % 2 else "FFE680", (math.cos(a)*0.15, -0.2 + math.sin(a)*0.04, 0.8 + math.sin(a)*0.14), 0.035, seg=6, rings=4)
    sph("Etoile", g, (0, -0.2, 0.62), 0.05, seg=5, rings=3)

# 74 Corbeau couronne (B, 24) perche
def pet_corbeau_couronne():
    k0, w = "141414", "F2F2F2"
    box("Perchoir", "8B5A2B", (0, 0, 0.04), (0.7, 0.1, 0.08))
    box("Corps", k0, (0, 0.04, 0.55), (0.42, 0.4, 0.5)); box("Ventre", w, (0, -0.17, 0.5), (0.26, 0.04, 0.3)); box("Tete", k0, (0, -0.08, 0.98), (0.4, 0.38, 0.34))
    box("Bec", w, (0, -0.33, 0.94), (0.12, 0.18, 0.1)); box("Queue", k0, (0, 0.3, 0.36), (0.2, 0.18, 0.5), (R(-15), 0, 0))
    box("Couronne", k0, (0, -0.08, 1.2), (0.3, 0.28, 0.07))
    for x in (-0.11, 0, 0.11): box("Pointe", "2A2A2A", (x, -0.08, 1.28), (0.06, 0.06, 0.1))
    for k in (-1, 1):
        box("Oeil", w, (k*0.11, -0.275, 1.0), (0.08, 0.04, 0.1)); box("Reflet", k0, (k*0.11, -0.3, 1.0), (0.03, 0.02, 0.05))
        box("Bras_" + G(k), k0, (k*0.24, -0.08, 0.5), (0.08, 0.12, 0.2)); box("Aile" + G(k), "2A2A2A", (k*0.27, 0.06, 0.55), (0.09, 0.34, 0.48), (0, 0, k*0.08))
        box("Jambe_" + G(k), "3A3A3A", (k*0.1, 0, 0.17), (0.07, 0.07, 0.18)); box("Griffe", k0, (k*0.1, -0.05, 0.1), (0.11, 0.12, 0.04))
    box("Plume", w, (0, -0.2, 0.8), (0.12, 0.04, 0.05))

for fn in [pet_griffon, pet_mammouth, pet_pegase, pet_panthere_d_ombre, pet_hydre_des_marais, pet_golem_de_pierre, pet_serpent_foudre, pet_oiseau_tonnerre, pet_chimere_d_ombre, pet_loup_garou_citrouille, pet_renne_etoile, pet_corbeau_couronne]: reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1); print("OK", len(M), {k:(v["parts"],v["tris"],v["height"]) for k,v in M.items()})
