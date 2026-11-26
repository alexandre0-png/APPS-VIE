import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
import bpy
from mathutils import Vector
OUT = sys.argv[1]; M = {}
R = math.radians
# Lot P1 du bestiaire (table C.2 de LOTS_9_PLUS.md). Hauteur normalisee a ~1, devant = -y, origine au sol, gauche = +x.
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

# 26 Tortue (L, 18)
def pet_tortue():
    g, sh = "6F8F3A", "5A3E28"
    sph("Corps", g, (0, 0.05, 0.3), 0.34, (1, 1.1, 0.6), seg=12, rings=7)
    sph("Carapace", sh, (0, 0.08, 0.5), 0.42, (1, 1.1, 0.8), seg=14, rings=9)
    for p in ((0, -0.05, 0.84), (0, 0.3, 0.74), (0.3, 0.1, 0.7), (-0.3, 0.1, 0.7)): sph("Plaque", "A07848", p, 0.13, (1, 1, 0.5), seg=8, rings=5)
    sph("Tete", g, (0, -0.5, 0.58), 0.22, (1, 1, 0.95), seg=12, rings=8)
    eyes(-0.69, 0.62, 0.11, 0.06); cheeks(-0.64, 0.5, 0.17)
    legsL(g, 0.3, -0.25, 0.38, 0.24, 0.13)
    cone("Queue", g, (0, 0.62, 0.22), 0.08, 0.02, 0.24, (R(-70), 0, 0), 6)
# 27 Cochon (B, 16)
def pet_cochon():
    p, d = "F5A0B4", "F28AA0"
    box("Corps", p, (0, 0.1, 0.5), (0.5, 0.7, 0.42)); box("Tete", p, (0, -0.42, 0.74), (0.46, 0.42, 0.42))
    box("Museau", d, (0, -0.67, 0.68), (0.24, 0.12, 0.16))
    for k in (-1, 1): box("Oreille", d, (k*0.17, -0.4, 1.0), (0.14, 0.06, 0.16), (0, k*0.3, 0))
    eyesB(-0.64, 0.82, 0.12); cheeks(-0.63, 0.7, 0.22)
    legsB(p, 0.17, -0.12, 0.34, 0.29, 0.15)
    box("Queue", d, (0, 0.5, 0.62), (0.08, 0.08, 0.14))
# 28 Mouton (L, 18)
def pet_mouton():
    w, h = "FAFAFA", "3A3A42"
    sph("Corps", w, (0, 0.1, 0.55), 0.34, (1, 1.1, 0.95), seg=12, rings=8)
    for p in ((0.22, 0.1, 0.8), (-0.22, 0.1, 0.8), (0, -0.08, 0.86), (0, 0.3, 0.82), (0, 0.12, 0.94)): sph("Laine", w, p, 0.2, seg=10, rings=6)
    sph("Tete", h, (0, -0.4, 0.68), 0.24, (1, 1, 1.05), seg=12, rings=8)
    for k in (-1, 1): sph("Oreille", h, (k*0.3, -0.38, 0.7), 0.1, (1, 0.5, 0.8), seg=8, rings=5)
    eyes(-0.61, 0.74, 0.1, 0.06, "F5F5F5", "3A3A42")
    legsL(h, 0.18, -0.15, 0.36, 0.3, 0.07)
    sph("Queue", w, (0, 0.5, 0.55), 0.09, seg=8, rings=5)
# 29 Herisson (B, 16)
def pet_herisson():
    b, d, l = "8B6A48", "5A3C28", "C9A27A"
    box("Corps", b, (0, 0.1, 0.4), (0.54, 0.6, 0.46)); box("Piquants", d, (0, 0.15, 0.74), (0.58, 0.64, 0.22))
    for p, r in (((0, -0.05, 0.92), (R(-20), 0, 0)), ((0.16, 0.2, 0.94), (0, R(20), 0)), ((-0.16, 0.2, 0.94), (0, R(-20), 0))): box("Pic", d, p, (0.15, 0.15, 0.22), r)
    box("Tete", l, (0, -0.4, 0.45), (0.36, 0.34, 0.34)); box("Museau", l, (0, -0.62, 0.4), (0.18, 0.14, 0.14))
    eyesB(-0.58, 0.52, 0.1)
    legsB(b, 0.18, -0.12, 0.36, 0.18, 0.14)
    box("Queue", d, (0, 0.46, 0.3), (0.1, 0.1, 0.1))
def wolf(body, belly, crest, eyec, eye_neon, n_crest, ruff, tailtip, extra=0):
    box("Corps", body, (0, 0.12, 0.58), (0.46, 0.8, 0.44)); box("Ventre", belly, (0, 0.0, 0.42), (0.36, 0.6, 0.14))
    box("Collier", ruff, (0, -0.25, 0.7), (0.5, 0.22, 0.5))
    box("Tete", body, (0, -0.5, 0.94), (0.4, 0.36, 0.34)); box("Museau", belly, (0, -0.74, 0.88), (0.2, 0.26, 0.16)); box("Nez", "2A2A3A", (0, -0.87, 0.92), (0.09, 0.05, 0.07))
    for k in (-1, 1):
        box("Oreille", body, (k*0.14, -0.46, 1.19), (0.1, 0.08, 0.2)); box("Sourcil", ruff, (k*0.12, -0.7, 1.06), (0.12, 0.06, 0.05))
        box("Yeux" if eye_neon else "Oeil", eyec, (k*0.12, -0.69, 0.98), (0.07, 0.04, 0.06))
    legsB(body, 0.16, -0.2, 0.44, 0.38, 0.14)
    for n, y in (("G", 1), ("D", -1)):
        for yy in (-0.2, 0.44): box("Pied", belly, (y*0.16, yy-0.03, 0.04), (0.16, 0.22, 0.08))
    box("Queue", body, (0, 0.66, 0.64), (0.14, 0.5, 0.14), (R(-25), 0, 0)); box("Queue_Pointe", tailtip, (0, 0.88, 0.58), (0.16, 0.16, 0.16))
    for i in range(n_crest): cone("Cristal", crest, (0, -0.1 + i*0.15, 0.9 + (0.04 if i % 2 else 0)), 0.07, 0.0, 0.26 + (0.08 if i % 2 else 0), v=4)
# 57 Loup de glace (B, 32)
def pet_loupdeglace():
    wolf("D6E4F0", "EEF6FF", "9AD8FF", "6FD6FF", True, 5, "FFFFFF", "FFFFFF")
    for k in (-1, 1): box("Epaule", "BFD6E8", (k*0.26, -0.15, 0.78), (0.12, 0.3, 0.3)); cone("Cristal", "9AD8FF", (k*0.12, -0.5, 1.2), 0.05, 0.0, 0.2, v=4)
    cone("Corne", "9AD8FF", (0, -0.55, 1.15), 0.05, 0.0, 0.18, v=4)
# 62 Loup de cristaux (B, 36)
def pet_loupdecristaux():
    wolf("BFEFFF", "E8FAFF", "7AD0F0", "2A4A8A", False, 6, "FFFFFF", "FFFFFF")
    for k in (-1, 1):
        cone("Cristal", "7AD0F0", (k*0.3, -0.15, 0.95), 0.09, 0.0, 0.34, (0, k*0.35, 0), 4); box("Epaule", "FFFFFF", (k*0.26, -0.15, 0.76), (0.12, 0.3, 0.3))
        cone("Cristal", "FFFFFF", (k*0.14, 0.7, 0.9), 0.06, 0.0, 0.22, (0, k*0.3, 0), 4)
    cone("Corne", "7AD0F0", (0, -0.55, 1.18), 0.06, 0.0, 0.24, v=4); cone("Cristal", "FFFFFF", (0, 0.5, 1.0), 0.08, 0.0, 0.3, v=4)
# 64 Dragon de lave (B, 38)
def pet_dragondelave():
    d, f, lite = "2A1A14", "FF3020", "4A2A20"
    box("Corps", d, (0, 0.12, 0.56), (0.5, 0.8, 0.46)); box("Ventre", lite, (0, 0.0, 0.4), (0.4, 0.6, 0.14))
    box("Tete", d, (0, -0.5, 0.92), (0.42, 0.38, 0.36)); box("Museau", d, (0, -0.74, 0.86), (0.28, 0.28, 0.18)); box("Machoire", lite, (0, -0.72, 0.74), (0.24, 0.24, 0.08))
    for k in (-1, 1):
        cone("Corne", "5A3A2A", (k*0.15, -0.42, 1.2), 0.07, 0.0, 0.3, (R(-20), k*0.3, 0), 4); box("Yeux", "FFB020", (k*0.13, -0.69, 0.98), (0.08, 0.04, 0.06))
        box("Aile" + ("G" if k > 0 else "D"), "3A1E18", (k*0.62, 0.15, 1.0), (0.7, 0.34, 0.04), (0, 0, k*R(-18)))
        for j in (0, 1): box("Doigt", d, (k*(0.45 + j*0.35), 0.0 + j*0.05, 1.04), (0.3, 0.07, 0.07), (0, k*R(-10), k*R(-25)))
    legsB(d, 0.17, -0.2, 0.46, 0.36, 0.15)
    for k in (-1, 1):
        for yy in (-0.2, 0.46): box("Pied", lite, (k*0.17, yy-0.03, 0.04), (0.17, 0.22, 0.08))
    box("Queue", d, (0, 0.72, 0.6), (0.16, 0.6, 0.16), (R(-15), 0, 0)); cone("Flammes", f, (0, 1.05, 0.58), 0.12, 0.0, 0.3, (R(-90), 0, 0), 5)
    for i in range(4): box("Pic", "5A3A2A", (0, -0.05 + i*0.2, 0.84 - i*0.0), (0.08, 0.1, 0.14))
    for i, p in enumerate(((0.26, 0.05, 0.6), (-0.26, 0.2, 0.62), (0, 0.3, 0.8), (0, -0.08, 0.8))): box("Flammes", f, p, (0.04 if i < 2 else 0.2, 0.2 if i < 2 else 0.04, 0.2 if i < 2 else 0.04) if False else ((0.05, 0.3, 0.22) if i < 2 else (0.22, 0.3, 0.05)))
    box("Flammes", f, (0, -0.55, 1.12), (0.06, 0.14, 0.05))
# 67 Demon enchaine (B, 36)
def pet_demonenchaine():
    d, ch, e = "1E1428", "3A3A42", "C86BFF"
    box("Corps", d, (0, 0.0, 0.6), (0.5, 0.3, 0.5)); box("Ceinture", ch, (0, 0.0, 0.38), (0.54, 0.34, 0.1))
    box("Tete", d, (0, -0.02, 1.0), (0.42, 0.36, 0.36)); box("Machoire", "2A1E38", (0, -0.12, 0.84), (0.3, 0.2, 0.08))
    box("Runes", e, (0, -0.16, 0.62), (0.18, 0.03, 0.18))
    for k in (-1, 1):
        cone("Corne", "3A3A42", (k*0.16, 0.0, 1.3), 0.08, 0.0, 0.3, (0, k*0.4, 0), 4); box("Yeux", e, (k*0.1, -0.2, 1.04), (0.09, 0.03, 0.06))
        box("Croc", "FFFFFF", (k*0.07, -0.21, 0.88), (0.04, 0.03, 0.07))
        sg = "G" if k > 0 else "D"
        box("Bras_" + sg, d, (k*0.38, 0.0, 0.58), (0.15, 0.15, 0.46), (0, k*R(-8), 0)); box("Main", d, (k*0.42, 0.0, 0.3), (0.18, 0.18, 0.15))
        box("Jambe_" + sg, d, (k*0.14, 0.0, 0.2), (0.18, 0.18, 0.32)); box("Pied", "2A1E38", (k*0.14, -0.05, 0.04), (0.2, 0.28, 0.08))
        box("Chaine", ch, (k*0.42, 0.0, 0.2), (0.14, 0.04, 0.1)); box("Chaine", ch, (k*0.43, 0.0, 0.1), (0.1, 0.14, 0.05))
        box("Epaule", ch, (k*0.36, 0.0, 0.86), (0.2, 0.2, 0.1))
    for i in range(5): box("Chaine", ch, ((i-2)*0.13, -0.18, 0.5 + (0.1 if i % 2 else 0.0) - abs(i-2)*0.0), (0.1, 0.05, 0.1), (0, 0, R(30) if i % 2 else 0))
    for i, z in enumerate((0.7, 0.5, 0.32)): box("Chaine", ch, (0.12*(1 if i % 2 else -1), 0.2, z), (0.14, 0.05, 0.09), (0, 0, R(20)))
    cone("Queue", d, (0, 0.28, 0.32), 0.07, 0.0, 0.5, (R(-70), 0, 0), 4)
    box("Cape", "2A1E38", (0, 0.22, 0.68), (0.44, 0.06, 0.5))
# 68 Phenix solaire (B, 38)
def pet_phenixsolaire():
    c, w, o = "FFF3B0", "FFD24A", "FF9A2A"
    box("Corps", c, (0, 0.05, 0.5), (0.44, 0.5, 0.46)); box("Ventre", "FFFFFF", (0, -0.12, 0.44), (0.3, 0.2, 0.3))
    box("Tete", c, (0, -0.2, 0.88), (0.4, 0.38, 0.38)); cone("Bec", o, (0, -0.46, 0.84), 0.09, 0.0, 0.2, (R(90), 0, 0), 4)
    box("Aureole", w, (0, 0.0, 1.22), (0.5, 0.05, 0.06)); box("Aureole", w, (0.22, 0.0, 1.14), (0.06, 0.05, 0.16)); box("Aureole", w, (-0.22, 0.0, 1.14), (0.06, 0.05, 0.16))
    for i, x in enumerate((-0.07, 0, 0.07)): box("Flammes", w, (x, -0.15, 1.12 + (0.08 if i == 1 else 0)), (0.06, 0.08, 0.18 + (0.08 if i == 1 else 0)))
    for k in (-1, 1):
        sg = "G" if k > 0 else "D"
        eyesB_c = box("Oeil", "1A1A1A", (k*0.12, -0.4, 0.92), (0.07, 0.04, 0.1))
        box("Aile" + sg, w, (k*0.58, 0.1, 0.66), (0.7, 0.3, 0.06), (0, k*R(-20), 0))
        for j in range(3): box("Flammes", w, (k*(0.5 + j*0.16), 0.3 + j*0.1, 0.72 - j*0.1), (0.24, 0.1, 0.05), (0, 0, k*R(-20)))
        box("Flammes", o, (k*0.98, 0.1, 0.8), (0.12, 0.3, 0.05))
        box("Jambe_" + sg, o, (k*0.12, 0.0, 0.16), (0.08, 0.08, 0.3)); box("Pied", o, (k*0.12, -0.05, 0.03), (0.18, 0.22, 0.06))
    box("Queue", w, (0, 0.5, 0.52), (0.14, 0.4, 0.08), (R(-15), 0, 0))
    for i, x in enumerate((-0.14, 0, 0.14)): box("Flammes", w if i != 1 else o, (x, 0.82, 0.4 - abs(x)*0.8), (0.08, 0.4, 0.05), (R(-25), 0, R(x*100)))
    box("Lueur", "FFFFFF", (0, -0.2, 0.66), (0.2, 0.05, 0.12))
# 70 Dragon de cristal (L, 38) assis
def pet_dragondecristal():
    c, d, g = "BFEFFF", "7AD0F0", "E8FAFF"
    sph("Corps", c, (0, 0.1, 0.5), 0.36, (1, 0.95, 1.15), seg=14, rings=9); sph("Ventre", g, (0, -0.1, 0.48), 0.3, (0.8, 0.5, 1.0), seg=10, rings=7)
    sph("Tete", c, (0, -0.2, 1.0), 0.3, (1, 0.95, 0.9), seg=14, rings=9); sph("Museau", g, (0, -0.46, 0.94), 0.14, (1, 0.9, 0.7), seg=8, rings=5)
    eyes(-0.45, 1.04, 0.14, 0.075, "2A4A8A"); cheeks(-0.4, 0.92, 0.25, "FFB0D0")
    for k in (-1, 1):
        sg = "G" if k > 0 else "D"
        cone("Corne", d, (k*0.2, -0.15, 1.34), 0.07, 0.0, 0.3, (0, k*0.3, 0), 5)
        sph("Patte_Av" + sg, c, (k*0.3, -0.25, 0.4), 0.12, (0.9, 0.9, 1.5), seg=8, rings=5)
        sph("Patte_Ar" + sg, c, (k*0.3, 0.12, 0.17), 0.2, (0.9, 1.3, 0.85), seg=9, rings=6)
        sph("Pied", g, (k*0.3, -0.34, 0.08), 0.1, (1, 1.3, 0.6), seg=8, rings=5)
        sph("Aile" + sg, d, (k*0.5, 0.25, 0.85), 0.34, (0.3, 0.7, 1.1), seg=9, rings=6)
        for j in range(2): cone("Cristal", "FFFFFF", (k*(0.55 + j*0.12), 0.3 + j*0.2, 1.1 - j*0.15), 0.05, 0.0, 0.22, (0, k*0.4, 0), 4)
    cone("Queue", c, (0, 0.52, 0.2), 0.14, 0.03, 0.6, (R(-80), 0, 0), 7); cone("Cristal", d, (0, 0.95, 0.2), 0.1, 0.0, 0.2, (R(-90), 0, 0), 4)
    for i in range(5): cone("Cristal", d if i % 2 else "FFFFFF", (0, 0.35 - i*0.0, 0.7 + i*0.0) if False else (0, 0.44, 0.45 + i*0.12), 0.06, 0.0, 0.16 + 0.02*i, (R(30), 0, 0), 4)
    sph("Lueur", "FFFFFF", (0, -0.1, 0.62), 0.05, seg=6, rings=4)
    for k in (-1, 1): sph("Perle", g, (k*0.16, -0.38, 1.3), 0.05, seg=6, rings=4)
# 75 Seraphin-lion (L, 38) assis, 2 paires d'ailes, aureole
def pet_seraphinlion():
    c, m, w = "FFF3B0", "FFD24A", "FFFFFF"
    sph("Criniere", m, (0, 0.0, 0.88), 0.46, (1, 0.6, 1), seg=14, rings=9)
    sph("Corps", c, (0, 0.12, 0.5), 0.34, (1, 0.95, 1.15), seg=14, rings=9); sph("Ventre", w, (0, -0.06, 0.46), 0.26, (0.8, 0.5, 1.0), seg=10, rings=7)
    sph("Tete", c, (0, -0.1, 0.92), 0.32, (1, 0.95, 0.92), seg=14, rings=9); sph("Museau", w, (0, -0.38, 0.86), 0.13, (1, 0.8, 0.7), seg=8, rings=5)
    sph("Nez", "C86B7A", (0, -0.5, 0.9), 0.04, seg=6, rings=4)
    eyes(-0.37, 0.96, 0.14, 0.07, "7A4A1A"); cheeks(-0.33, 0.84, 0.24, "FFB08A")
    torus("Aureole", "FFE680", (0, -0.05, 1.42), 0.2, 0.025, (R(80), 0, 0))
    for k in (-1, 1):
        sg = "G" if k > 0 else "D"
        sph("Oreille", c, (k*0.27, -0.08, 1.16), 0.1, (1, 0.6, 1), seg=8, rings=5)
        sph("Patte_Av" + sg, c, (k*0.24, -0.22, 0.28), 0.11, (0.9, 0.9, 1.5), seg=8, rings=5)
        sph("Patte_Ar" + sg, c, (k*0.3, 0.14, 0.17), 0.19, (0.9, 1.3, 0.85), seg=9, rings=6)
        sph("Pied", w, (k*0.24, -0.3, 0.07), 0.09, (1, 1.3, 0.6), seg=8, rings=5)
        sph("Aile" + sg, w, (k*0.52, 0.25, 0.98), 0.3, (0.3, 0.7, 1.1), seg=9, rings=6, ) ; sph("Aile_Bas" + sg, "FFF8DC", (k*0.46, 0.28, 0.6), 0.26, (0.3, 0.7, 1.0), seg=9, rings=6)
        sph("Plume", m, (k*0.6, 0.3, 1.18), 0.1, (0.3, 0.8, 1.2), seg=7, rings=5); sph("Plume", m, (k*0.54, 0.34, 0.38), 0.09, (0.3, 0.8, 1.2), seg=7, rings=5)
    cone("Queue", c, (0, 0.5, 0.2), 0.1, 0.03, 0.55, (R(-80), 0, 0), 7); sph("Queue_Touffe", m, (0, 0.82, 0.2), 0.12, seg=8, rings=5)
    sph("Lueur", w, (0, -0.06, 0.62), 0.05, seg=6, rings=4)
# 76 Dragon celeste (L, 40) en vol, 6 segments
def pet_dragonceleste():
    n, h, g = "F2F6FF", "FFE680", "C9D8F5"
    P = [(0.0, -0.18, 0.74, 0.22), (0.1, 0.02, 0.66, 0.2), (0.0, 0.22, 0.5, 0.18), (-0.1, 0.42, 0.34, 0.16), (0.0, 0.6, 0.2, 0.13), (0.1, 0.76, 0.1, 0.1)]
    for i, (x, y, z, r) in enumerate(P): sph(f"Seg{i+1}", n if i % 2 == 0 else g, (x, y, z), r, (1, 1.1, 1), seg=10, rings=7)
    for i, (x, y, z, r) in enumerate(P[:5]): cone("Pic", h, (x, y, z + r), 0.05, 0.0, 0.13, v=4)
    cone("Pic", h, (0.1, 0.9, 0.1), 0.07, 0.0, 0.18, (R(-90), 0, 0), 4)
    sph("Tete", n, (0, -0.42, 0.9), 0.28, (1, 1, 0.95), seg=14, rings=9); sph("Museau", g, (0, -0.65, 0.84), 0.13, (1, 0.9, 0.7), seg=8, rings=5)
    eyes(-0.65, 0.95, 0.13, 0.07, "3A5AA0"); cheeks(-0.6, 0.83, 0.23, "FFB0D0")
    for k in (-1, 1):
        sg = "G" if k > 0 else "D"
        cone("Corne", h, (k*0.16, -0.38, 1.18), 0.06, 0.0, 0.3, (R(-25), k*0.3, 0), 5)
        cone("Moustache", h, (k*0.2, -0.62, 0.78), 0.025, 0.01, 0.4, (R(80), 0, k*R(60)), 4)
        sph("Aile" + sg, "DCE8FF", (k*0.5, -0.02, 0.98), 0.36, (0.3, 0.7, 1.1), seg=9, rings=6)
        sph("Plume", h, (k*0.66, 0.05, 1.22), 0.1, (0.3, 0.8, 1.2), seg=7, rings=5); sph("Plume", h, (k*0.62, 0.15, 0.7), 0.09, (0.3, 0.8, 1.2), seg=7, rings=5)
        sph("Patte_Av" + sg, n, (k*0.2, -0.08, 0.42), 0.07, (1, 1, 1.5), seg=8, rings=5); sph("Patte_Ar" + sg, n, (k*0.2, 0.3, 0.2), 0.07, (1, 1, 1.5), seg=8, rings=5)
        sph("Perle", h, (k*0.24, -0.5, 1.02), 0.04, seg=6, rings=4)
    sph("Perle", "FFFFFF", (0, -0.55, 1.12), 0.06, seg=8, rings=5); sph("Perle", h, (0, -0.2, 0.6), 0.06, seg=6, rings=4)
    sph("Nuage", "FFFFFF", (0, 0.1, 0.05), 0.1, (1.6, 1.4, 0.6), seg=8, rings=5)
for fn in [pet_tortue, pet_cochon, pet_mouton, pet_herisson, pet_loupdeglace, pet_loupdecristaux, pet_dragondelave, pet_demonenchaine, pet_phenixsolaire, pet_dragondecristal, pet_seraphinlion, pet_dragonceleste]: reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
print("OK", {k: (v["parts"], v["tris"], v["height"]) for k, v in M.items()})
