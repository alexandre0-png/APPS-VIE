import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
import bpy
from mathutils import Vector
OUT = sys.argv[1]; M = {}
R = math.radians
# Lot P3 du bestiaire (table C.2 de LOTS_9_PLUS.md). Hauteur ~1, devant = -y, origine au sol.
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
# 19 Souris (B, 14) assise
def pet_souris():
    g, p = "9E9E9E", "F2A8B8"
    box("Corps", g, (0, 0.08, 0.3), (0.5, 0.46, 0.5)); box("Tete", g, (0, -0.1, 0.72), (0.5, 0.44, 0.4))
    box("Museau", "B8B8B8", (0, -0.34, 0.66), (0.18, 0.14, 0.14)); box("Nez", p, (0, -0.42, 0.7), (0.07, 0.04, 0.05))
    for k in (-1, 1):
        box("Oreille", g, (k*0.28, -0.05, 0.98), (0.22, 0.06, 0.22)); box("Oreille_Int", p, (k*0.28, -0.09, 0.98), (0.13, 0.04, 0.13))
    box("Patte_AvG", g, (0.2, -0.2, 0.2), (0.1, 0.1, 0.22)); box("Patte_AvD", g, (-0.2, -0.2, 0.2), (0.1, 0.1, 0.22))
    box("Patte_ArG", g, (0.22, -0.12, 0.05), (0.16, 0.26, 0.1)); box("Patte_ArD", g, (-0.22, -0.12, 0.05), (0.16, 0.26, 0.1))
    bar("Queue", p, (0, 0.32, 0.12), (0, 1, 0.5), 0.5, 0.05, 0.02, 5)
    eyesB(-0.33, 0.78, 0.12)
# 20 Grenouille (L, 12) accroupie
def pet_grenouille():
    g, b = "5CB85C", "E8F5D0"
    sph("Corps", g, (0, 0.1, 0.3), 0.34, (1.05, 1.1, 0.8), seg=12, rings=8); sph("Tete", g, (0, -0.2, 0.6), 0.32, (1.15, 1, 0.75), seg=14, rings=9)
    sph("Ventre", b, (0, -0.1, 0.22), 0.24, (0.9, 0.8, 0.6), seg=10, rings=6)
    for k in (-1, 1):
        sph("Bosse", g, (k*0.17, -0.22, 0.86), 0.12, seg=8, rings=5); sph("Oeil", "1A1A1A", (k*0.17, -0.3, 0.88), 0.07, (1, 0.6, 1.2), seg=8, rings=5)
        sph("Reflet", "FFFFFF", (k*0.16, -0.36, 0.92), 0.025, seg=6, rings=4)
    sph("Patte_AvG", g, (0.22, -0.28, 0.1), 0.09, (1, 1.4, 0.8), seg=8, rings=5); sph("Patte_AvD", g, (-0.22, -0.28, 0.1), 0.09, (1, 1.4, 0.8), seg=8, rings=5)
    sph("Patte_ArG", g, (0.36, 0.2, 0.17), 0.14, (0.7, 1.5, 1), seg=8, rings=5); sph("Patte_ArD", g, (-0.36, 0.2, 0.17), 0.14, (0.7, 1.5, 1), seg=8, rings=5)
    sph("Queue", g, (0, 0.46, 0.14), 0.05, seg=6, rings=4)
    cheeks(-0.35, 0.62, 0.24)
# 21 Canard (B, 12) debout
def pet_canard():
    w, o = "F2F2F2", "FFAA28"
    box("Corps", w, (0, 0.05, 0.4), (0.5, 0.56, 0.46)); box("Tete", w, (0, -0.12, 0.8), (0.42, 0.4, 0.38))
    box("Bec", o, (0, -0.4, 0.74), (0.22, 0.2, 0.08)); box("Queue", w, (0, 0.38, 0.5), (0.14, 0.12, 0.14), (0.4, 0, 0))
    for k in (-1, 1):
        sg = "G" if k > 0 else "D"
        box("Bras_" + sg, "E2E2E2", (k*0.3, 0.05, 0.42), (0.08, 0.34, 0.26)); box("Jambe_" + sg, o, (k*0.12, -0.02, 0.1), (0.08, 0.08, 0.2))
        box("Palme", o, (k*0.12, -0.1, 0.02), (0.14, 0.18, 0.04))
    eyesB(-0.325, 0.85, 0.1); cheeks(-0.32, 0.74, 0.17, "FFB0B0")
# 22 Escargot (L, 10) rampant
def pet_escargot():
    b, s, s2 = "C9A66B", "8B5A2B", "A8743C"
    rr = [0.16, 0.15, 0.14, 0.13, 0.115, 0.09]
    for i, r in enumerate(rr): sph(f"Seg{i+1}", b, (0, -0.55 + i*0.22, 0.14 if i else 0.2), r, (1, 1.3, 0.9), seg=10, rings=6)
    sph("Coquille", s, (0, 0.28, 0.5), 0.38, (0.8, 1, 1), seg=14, rings=9); torus("Spirale", s2, (0, 0.28, 0.5), 0.18, 0.05, (0, math.pi/2, 0))
    sph("Tete", b, (0, -0.62, 0.3), 0.01, seg=4, rings=3)
    for k in (-1, 1):
        bar("Antenne", b, (k*0.07, -0.62, 0.3), (k*0.2, -0.3, 1), 0.28, 0.03, 0.02, 6); sph("Oeil", "1A1A1A", (k*0.12, -0.7, 0.56), 0.05, seg=6, rings=4)
# 23 Bebe phoque (L, 12) couche
def pet_bebe_phoque():
    w = "EDEFF5"
    sph("Corps", w, (0, 0.15, 0.25), 0.3, (1, 1.7, 0.8), seg=14, rings=9); sph("Tete", w, (0, -0.35, 0.45), 0.3, (1, 0.95, 0.95), seg=14, rings=9)
    sph("Museau", "FFFFFF", (0, -0.58, 0.4), 0.12, (1.1, 0.8, 0.8), seg=8, rings=5); sph("Nez", "2A2A32", (0, -0.69, 0.43), 0.04, seg=6, rings=4)
    eyes(-0.6, 0.52, 0.12, 0.07); cheeks(-0.54, 0.4, 0.2, "FFB0C0")
    sph("Patte_AvG", w, (0.3, -0.12, 0.12), 0.09, (1.5, 0.6, 0.4), seg=8, rings=5); sph("Patte_AvD", w, (-0.3, -0.12, 0.12), 0.09, (1.5, 0.6, 0.4), seg=8, rings=5)
    sph("Patte_ArG", w, (0.1, 0.75, 0.1), 0.1, (1.2, 1.2, 0.4), seg=8, rings=5); sph("Patte_ArD", w, (-0.1, 0.75, 0.1), 0.1, (1.2, 1.2, 0.4), seg=8, rings=5)
    for k in (-1, 1): cone("Moustache", "FFFFFF", (k*0.14, -0.58, 0.36), 0.012, 0.012, 0.2, (0, 0, k*1.4), 4)
    sph("Queue", "DCE0EA", (0, 0.88, 0.14), 0.06, seg=6, rings=4)
# 24 Abeille (B, 14) vol stationnaire
def pet_abeille():
    y, k_ = "FFD23F", "1E1E1E"
    box("Corps", y, (0, 0.1, 0.5), (0.46, 0.56, 0.44)); box("Tete", y, (0, -0.28, 0.58), (0.4, 0.34, 0.36))
    for i, yy in enumerate((0.0, 0.2)): box("Rayure", k_, (0, yy+0.02, 0.5), (0.48, 0.1, 0.46))
    box("Dard", k_, (0, 0.44, 0.5), (0.06, 0.12, 0.06))
    for k in (-1, 1):
        sg = "G" if k > 0 else "D"
        box("Aile" + sg, "CFEFFF", (k*0.4, 0.08, 0.86), (0.4, 0.3, 0.04), (0, k*0.25, 0))
        box("Bras_" + sg, k_, (k*0.1, -0.16, 0.26), (0.06, 0.06, 0.2)); box("Jambe_" + sg, k_, (k*0.12, 0.2, 0.26), (0.06, 0.06, 0.2))
        bar("Antenne", k_, (k*0.1, -0.35, 0.74), (k*0.3, -0.3, 1), 0.22, 0.02, 0.02, 5)
    eyesB(-0.455, 0.62, 0.11)
# 25 Coccinelle (B, 12) posee
def pet_coccinelle():
    r, k_ = "D63A3A", "1E1E1E"
    box("Corps", r, (0, 0.1, 0.4), (0.6, 0.66, 0.6)); box("Tete", k_, (0, -0.32, 0.34), (0.4, 0.24, 0.36)); box("Raie", k_, (0, 0.1, 0.705), (0.04, 0.66, 0.02))
    for x, y in ((-0.17, -0.05), (0.17, -0.05), (-0.17, 0.27), (0.17, 0.27)): box("Point", k_, (x, y, 0.71), (0.14, 0.14, 0.03))
    for k in (-1, 1):
        sg = "G" if k > 0 else "D"
        box("Patte_Av" + sg, k_, (k*0.27, -0.15, 0.08), (0.12, 0.1, 0.16)); box("Patte_Ar" + sg, k_, (k*0.27, 0.35, 0.08), (0.12, 0.1, 0.16))
        bar("Antenne", k_, (k*0.1, -0.42, 0.48), (k*0.3, -0.4, 1), 0.2, 0.02, 0.02, 5)
    box("Queue", r, (0, 0.46, 0.14), (0.2, 0.14, 0.16)); eyesB(-0.445, 0.36, 0.12, "FFFFFF")
# 33 Lievre arctique (L, 14) assis, longues oreilles
def pet_lievre_arctique():
    w = "F5F8FF"
    sph("Corps", w, (0, 0.15, 0.32), 0.34, (0.9, 1.15, 1), seg=12, rings=8); sph("Tete", w, (0, -0.18, 0.76), 0.28, (1, 1, 0.95), seg=14, rings=9)
    for k in (-1, 1):
        cone("Oreille", w, (k*0.11, -0.12, 1.25), 0.08, 0.04, 0.55, (0, k*0.15, 0), 8); cone("Oreille_Int", "DCE4F5", (k*0.11, -0.17, 1.25), 0.045, 0.025, 0.4, (0, k*0.15, 0), 6)
    sph("Museau", "FFFFFF", (0, -0.4, 0.7), 0.1, (1, 0.8, 0.8), seg=8, rings=5); sph("Nez", "E89AB0", (0, -0.49, 0.73), 0.035, seg=6, rings=4)
    eyes(-0.42, 0.81, 0.12, 0.065, "2A2A3A"); cheeks(-0.4, 0.69, 0.18)
    sph("Patte_AvG", w, (0.14, -0.28, 0.14), 0.08, (1, 1, 1.6), seg=8, rings=5); sph("Patte_AvD", w, (-0.14, -0.28, 0.14), 0.08, (1, 1, 1.6), seg=8, rings=5)
    sph("Patte_ArG", w, (0.28, 0.1, 0.1), 0.13, (0.7, 1.6, 0.8), seg=8, rings=5); sph("Patte_ArD", w, (-0.28, 0.1, 0.1), 0.13, (0.7, 1.6, 0.8), seg=8, rings=5)
    sph("Queue", "FFFFFF", (0, 0.55, 0.3), 0.1, seg=8, rings=5)
# 34 Ecureuil-etincelle (B, 16) debout sur 2 pattes
def pet_ecureuil_etincelle():
    o, c = "C8742A", "FFE14A"
    box("Corps", o, (0, 0.04, 0.42), (0.42, 0.34, 0.44)); box("Ventre", "F5DCB0", (0, -0.14, 0.4), (0.26, 0.04, 0.3)); box("Tete", o, (0, -0.06, 0.84), (0.42, 0.38, 0.36))
    box("Museau", "F5DCB0", (0, -0.28, 0.78), (0.18, 0.12, 0.12)); box("Nez", "2A1A1A", (0, -0.35, 0.81), (0.06, 0.04, 0.05))
    for k in (-1, 1):
        sg = "G" if k > 0 else "D"
        box("Oreille", o, (k*0.15, -0.04, 1.08), (0.1, 0.08, 0.18)); box("Bras_" + sg, o, (k*0.28, -0.08, 0.44), (0.1, 0.12, 0.28)); box("Jambe_" + sg, o, (k*0.1, 0, 0.1), (0.14, 0.22, 0.2))
    eyesB(-0.255, 0.88, 0.11)
    box("Queue", o, (0, 0.34, 0.42), (0.22, 0.2, 0.5), (0.3, 0, 0)); box("Queue_Haut", c, (0, 0.46, 0.78), (0.26, 0.22, 0.3), (0.5, 0, 0))
    for i in range(3):
        a = (i-1)*0.9; bar("Eclairs", c, (math.sin(a)*0.18, 0.5, 0.92), (math.sin(a), 0.3, 1.2), 0.2, 0.05, 0.0, 4)
# 35 Castor (B, 16) 4 pattes
def pet_castor():
    b, d = "7A4E2A", "3A2A1E"
    box("Corps", b, (0, 0.12, 0.42), (0.52, 0.8, 0.46)); box("Tete", b, (0, -0.42, 0.62), (0.46, 0.4, 0.4)); box("Museau", "A67C52", (0, -0.64, 0.56), (0.22, 0.12, 0.14))
    box("Nez", "1A1A1A", (0, -0.71, 0.6), (0.07, 0.04, 0.05)); box("Dent", "FFFFFF", (0, -0.69, 0.5), (0.08, 0.04, 0.08))
    for k in (-1, 1): box("Oreille", d, (k*0.19, -0.4, 0.86), (0.1, 0.08, 0.1))
    for n, x, y in (("Patte_AvG", 0.2, -0.15), ("Patte_AvD", -0.2, -0.15), ("Patte_ArG", 0.2, 0.42), ("Patte_ArD", -0.2, 0.42)): box(n, d, (x, y, 0.1), (0.16, 0.2, 0.2))
    box("Queue", d, (0, 0.82, 0.22), (0.4, 0.56, 0.08), (-0.1, 0, 0))
    for i in range(3): box("Ecaille", "2A1E14", (0, 0.7+i*0.15, 0.27), (0.3, 0.03, 0.03))
    eyesB(-0.625, 0.68, 0.11); cheeks(-0.62, 0.55, 0.2)
# 77 Qilin sacre (B, 36) cabre
def pet_qilin_sacre():
    g, sc, m = "FFE680", "6FD6FF", "FFFFFF"
    box("Corps", g, (0, 0.28, 0.58), (0.5, 0.9, 0.5), (-0.5, 0, 0)); box("Ventre", "FFF6C8", (0, 0.12, 0.42), (0.3, 0.6, 0.06), (-0.5, 0, 0))
    box("Cou", g, (0, -0.22, 0.98), (0.26, 0.26, 0.4), (0.25, 0, 0)); box("Tete", g, (0, -0.36, 1.2), (0.38, 0.36, 0.34)); box("Museau", g, (0, -0.58, 1.14), (0.22, 0.18, 0.18))
    box("Nez", "2A1A1A", (0, -0.68, 1.16), (0.08, 0.04, 0.05))
    for k in (-1, 1):
        sg = "G" if k > 0 else "D"
        bar("Corne", "FFD23F", (k*0.1, -0.34, 1.34), (k*0.2, 0.5, 1), 0.3, 0.05, 0.0, 5)
        box("Oreille", g, (k*0.2, -0.3, 1.3), (0.08, 0.08, 0.14))
        box("Patte_Av" + sg, g, (k*0.2, -0.3, 0.7), (0.12, 0.3, 0.12), (0.7, 0, 0)); box("Sabot", "B8862E", (k*0.2, -0.46, 0.84), (0.14, 0.14, 0.1))
        box("Patte_Ar" + sg, g, (k*0.2, 0.62, 0.22), (0.15, 0.17, 0.44)); box("Sabot", "B8862E", (k*0.2, 0.62, 0.04), (0.17, 0.2, 0.08))
        box("Joue", "FFB090", (k*0.19, -0.5, 1.1), (0.06, 0.04, 0.06))
    for i in range(5): box("Ecaille", sc, (0, 0.05+i*0.14, 0.92-i*0.12), (0.16, 0.12, 0.06), (-0.5, 0, 0))
    for i in range(4): box("Criniere", m, (0, -0.28-i*0.0, 1.38-i*0.14), (0.08, 0.1, 0.16), (0.3, 0, 0))
    bar("Queue", m, (0, 0.78, 0.35), (0, 1, -0.3), 0.5, 0.1, 0.03, 6)
    for p in ((0.0, -0.44, 1.38), (0.28, 0.05, 0.8), (-0.28, 0.05, 0.8)): sph("Lueur", "FFFFFF", p, 0.05, seg=6, rings=4)
    eyesB(-0.545, 1.24, 0.1, "1A1A1A")
    for k in (-1, 1):
        bar("Eclairs", sc, (k*0.3, 0.2, 0.5), (k*0.8, 0.3, 0.4), 0.26, 0.05, 0.0, 4)
# 78 Baleine des etoiles (L, 26) nage dans l'air
def pet_baleine_des_etoiles():
    b, v = "1A2A5A", "3A4A8A"
    sph("Corps", b, (0, 0.1, 0.5), 0.42, (0.9, 1.6, 0.85), seg=16, rings=10); sph("Ventre", v, (0, -0.05, 0.3), 0.34, (0.8, 1.3, 0.5), seg=12, rings=7)
    sph("Tete", b, (0, -0.55, 0.52), 0.36, (0.95, 1, 0.9), seg=14, rings=9)
    bar("Queue", b, (0, 0.65, 0.5), (0, 1, 0.5), 0.5, 0.2, 0.07, 8)
    for k in (-1, 1):
        sg = "G" if k > 0 else "D"
        sph("Aile" + sg, v, (k*0.45, -0.1, 0.38), 0.2, (1.6, 1.0, 0.3), seg=9, rings=6); sph("Fluke", b, (k*0.2, 1.0, 0.82), 0.14, (1.6, 0.7, 0.3), seg=8, rings=5)
        sph("Oeil", "FFFFFF", (k*0.28, -0.8, 0.6), 0.055, (1, 0.6, 1), seg=8, rings=5); sph("Pupille", "1A1A1A", (k*0.28, -0.84, 0.6), 0.03, seg=6, rings=4)
        sph("Joue", "6A7AB0", (k*0.3, -0.84, 0.46), 0.06, (1, 0.4, 0.8), seg=8, rings=5)
    sph("Dos", v, (0, 0.0, 0.88), 0.14, (0.6, 1.8, 0.3), seg=8, rings=5)
    pts = [(0.2, -0.2, 0.9), (-0.25, 0.2, 0.86), (0.1, 0.5, 0.8), (-0.12, -0.5, 0.86), (0.35, 0.1, 0.75), (-0.38, -0.1, 0.72), (0.0, 0.85, 0.7), (0.15, 0.3, 0.9), (-0.1, 0.0, 0.93), (0.3, -0.45, 0.7), (-0.3, 0.55, 0.7)]
    for p in pts: sph("Lueur", "FFFFFF", p, 0.045, seg=6, rings=4)
for fn in [pet_souris, pet_grenouille, pet_canard, pet_escargot, pet_bebe_phoque, pet_abeille, pet_coccinelle, pet_lievre_arctique, pet_ecureuil_etincelle, pet_castor, pet_qilin_sacre, pet_baleine_des_etoiles]: reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
print("OK", {k: (v["parts"], v["tris"], v["height"]) for k, v in M.items()})
