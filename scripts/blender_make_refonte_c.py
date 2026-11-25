import sys, os, math, json, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
import mathutils
OUT = sys.argv[1]; M = {}
R = math.radians
def bbox():
    mn=[1e9]*3; mx=[-1e9]*3
    for o in bpy.context.scene.objects:
        if o.type!="MESH": continue
        for c in o.bound_box:
            w=o.matrix_world@mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],w[i]); mx[i]=max(mx[i],w[i])
    return [round(mx[i]-mn[i],1) for i in range(3)], [round(mn[i],1) for i in range(3)], [round(mx[i],1) for i in range(3)]
def reg(fn):
    reset(); fn(); n,t = export(os.path.join(OUT, fn.__name__ + ".fbx"))
    s,a,b = bbox(); M[fn.__name__] = {"parts": n, "size": s, "min": a, "max": b}; print(fn.__name__, n, s, a, b)

def limb(name, hexc, p0, p1, r0, r1, v=6):
    d = mathutils.Vector(p1) - mathutils.Vector(p0); L = d.length
    ry = math.acos(d.z / L); rz = math.atan2(d.y, d.x)
    m = [(p0[i] + p1[i]) / 2 for i in range(3)]
    return cone(name, hexc, m, r0, r1, L, (0, ry, rz), v)
def rock(name, hexc, loc, r, sc=(1,1,1), rot=(0,0,0), seg=7, rings=4):
    o = sph(name, hexc, loc, r, sc, seg, rings)
    o.rotation_euler = rot; bpy.context.view_layer.objects.active = o; o.select_set(True)
    bpy.ops.object.transform_apply(rotation=True); return o
def crown(cx, cy, cz, r, pal, rng, n=4, flat=0.6):
    sph("Houppier", pal[0], (cx, cy, cz), r, (1, 1, flat), 9, 6)
    for i in range(n):
        a = 2 * math.pi * i / n + rng.random() * 0.8
        d = r * (0.62 + rng.random() * 0.15)
        sph("Feuilles", pal[(i + 1) % (len(pal) - 1)], (cx + math.cos(a) * d, cy + math.sin(a) * d, cz + (rng.random() - 0.5) * r * 0.3), r * (0.5 + rng.random() * 0.12), (1, 1, flat), 8, 5)
    sph("Feuilles_Haut", pal[-1], (cx, cy, cz + r * 0.32), r * 0.55, (1, 1, flat), 8, 5)

def tree_fork():
    rng = random.Random(1); pal = ["58B947", "7ACF4F", "3F9A3C", "A6E05A"]
    limb("Tronc", "D9792B", (0, 0, 0), (0.2, 0, 4.0), 1.1, 0.65, 7)
    for a in (0, 120, 240):
        limb("Racine", "B8601E", (0, 0, 0.9), (math.cos(R(a)) * 1.8, math.sin(R(a)) * 1.8, 0.05), 0.5, 0.15, 5)
    limb("Branche", "C96B22", (0.2, 0, 4.0), (-2.8, 0, 7.0), 0.6, 0.3)
    limb("Branche", "C96B22", (0.2, 0, 4.0), (3.2, 0.3, 7.3), 0.6, 0.3)
    limb("Rameau", "D9792B", (-1.5, 0, 5.6), (-0.2, -0.3, 8.2), 0.25, 0.1, 5)
    limb("Rameau", "D9792B", (1.7, 0.1, 5.6), (0.4, 0.3, 8.0), 0.25, 0.1, 5)
    limb("Rameau", "D9792B", (-2.2, 0, 6.3), (-4.0, 0.5, 7.9), 0.2, 0.08, 5)
    limb("Rameau", "D9792B", (2.6, 0.2, 6.5), (4.2, -0.3, 8.0), 0.2, 0.08, 5)
    crown(-3.2, 0, 8.2, 2.7, pal, rng); crown(3.6, 0.3, 8.5, 2.7, pal, rng); crown(0.2, 0, 8.9, 2.9, pal, rng)
    for p in ((-5, 1, 7.4), (5, -0.8, 7.6), (0, -2.5, 7.2), (0, 2.6, 7.4)):
        sph("Feuilles", "7ACF4F", p, 0.9, (1, 1, 0.6), 7, 4)

def wide(pal, trunk, trunk2, seed, fall=False):
    rng = random.Random(seed)
    limb("Tronc", trunk, (0, 0, 0), (0.4, 0, 3.4), 1.3, 0.9, 7)
    limb("Tronc", trunk2, (0.4, 0, 3.4), (0, 0, 6.2), 0.9, 0.55, 7)
    for a in (20, 110, 200, 290):
        limb("Racine", trunk, (0, 0, 1.0), (math.cos(R(a)) * 2.4, math.sin(R(a)) * 2.4, 0.05), 0.55, 0.15, 5)
    cs = [(0, 0, 10.4, 3.4), (-4.4, 0.4, 8.3, 3.0), (4.5, -0.3, 8.6, 3.0), (0.6, -4.2, 7.9, 2.8), (-0.4, 4.3, 8.2, 2.8)]
    for c in cs:
        limb("Branche", trunk2, (0, 0, 5.4), (c[0] * 0.8, c[1] * 0.8, c[2] - 1.4), 0.5, 0.25)
    for c in cs: crown(c[0], c[1], c[2], c[3], pal, rng)
    limb("Rameau", trunk2, (-2.2, 0.2, 6.5), (-3.6, 0.8, 7.0), 0.2, 0.08, 5)
    limb("Rameau", trunk2, (2.3, -0.1, 6.8), (3.8, -0.6, 7.2), 0.2, 0.08, 5)
    for p in ((-2.5, -2.4, 7.0), (2.6, 2.4, 7.2), (-2.2, 2.6, 6.8), (2.4, -2.6, 6.8)):
        sph("Feuilles", pal[1], p, 1.0, (1, 1, 0.55), 7, 4)
    if fall:
        for i in range(6):
            a = rng.random() * 6.28; d = 2 + rng.random() * 5
            cyl("Feuille_Tombee", pal[i % 3], (math.cos(a) * d, math.sin(a) * d, 0.03), 0.35, 0.05, v=5)
def tree_wide(): wide(["B9D94A", "9CC83C", "7DB535", "D6E86A"], "8A5A33", "74492A", 2)
def tree_autumn(): wide(["E8892B", "F2C230", "C8452B", "F59E3A"], "7A4A2A", "633B22", 3, True)

def tree_pine_tier():
    gr = ["2F8F46", "3AA654", "27803D"]; dk = ["1F6A33", "256F37"]
    limb("Tronc", "7A4E2D", (0, 0, 0), (0, 0, 13.5), 1.0, 0.3, 7)
    for a in (0, 120, 240):
        limb("Racine", "6A4326", (0, 0, 0.8), (math.cos(R(a)) * 1.6, math.sin(R(a)) * 1.6, 0.05), 0.4, 0.12, 5)
    for i in range(6):
        zc = 2.6 + i * 2.0; r = 5.9 - 0.8 * i; ox = 0.25 * math.cos(i * 2.1); oy = 0.25 * math.sin(i * 2.1)
        cone("Plan", gr[i % 3], (ox, oy, zc), r, 0.12 if i == 5 else r * 0.12, 3.4, (0, 0, R(i * 21)), 7)
        cyl("Dessous", dk[i % 2], (ox, oy, zc - 1.62), r * 0.97, 0.18, (0, 0, R(i * 21)), 7)

def tree_dead():
    c1, c2 = "7A6A5A", "5E5047"
    pts = [(0, 0, 0.3, 1.5), (0.7, 0.3, 3.0, 1.0), (-0.4, 0.2, 5.4, 0.8), (0.4, 0, 7.8, 0.5), (0, 0, 9.5, 0.12)]
    for a, b in zip(pts, pts[1:]): limb("Tronc", c1, a[:3], b[:3], a[3], b[3], 7)
    for a in (0, 70, 150, 220, 290):
        d = 3.2 + (a % 3) * 0.3
        limb("Racine", c2, (0, 0, 1.8), (math.cos(R(a)) * d, math.sin(R(a)) * d, 0.05), 0.85, 0.2, 6)
    br = [((0.7, 0.3, 3.4), (-2.6, 0.5, 5.6)), ((-0.4, 0.2, 5.8), (2.8, -0.4, 7.9)), ((0.3, 0, 7.4), (-2.4, 0.3, 9.4)),
          ((0.4, 0, 8.0), (2.0, 0.5, 9.9)), ((-0.4, 0.2, 5.0), (-1.2, -2.8, 6.8)), ((0.7, 0.3, 4.2), (1.4, 2.8, 6.0))]
    for a, b in br: limb("Branche", c2, a, b, 0.4, 0.1, 5)
    for a, b in (((-1.8, 0.4, 4.9), (-3.6, 0.2, 5.0)), ((1.8, -0.2, 7.0), (3.6, -0.4, 6.4)), ((-1.5, 0.3, 8.7), (-2.8, 0.9, 8.4)), ((1.5, 0.4, 9.0), (3.0, 0.2, 9.0))):
        limb("Rameau", c1, a, b, 0.18, 0.05, 5)
    sph("Noeud", c2, (0.6, -0.8, 2.6), 0.5, (1, 0.7, 1), 7, 4)
    sph("Noeud", c2, (-0.5, -0.5, 5.2), 0.4, (1, 0.7, 1), 7, 4)

def log_hollow():
    cyl("Tronc", "8A5A33", (0, 0, 2), 2.0, 9, (R(90), 0, 0), 10)
    cyl("Coupe", "D9A66B", (0, -4.52, 2), 2.0, 0.06, (R(90), 0, 0), 10)
    cyl("Creux", "3A2414", (0, -4.56, 2), 1.35, 0.1, (R(90), 0, 0), 10)
    cyl("Coupe", "C99555", (0, 4.52, 2), 2.0, 0.06, (R(90), 0, 0), 10)
    limb("Nœud", "74492A", (-1.5, 1.0, 3.2), (-2.6, 1.2, 4.2), 0.35, 0.15, 5)
    limb("Nœud", "74492A", (1.6, -2, 3.0), (2.8, -2.2, 3.4), 0.3, 0.12, 5)
    sph("Mousse", "5FAE46", (0.2, 1.5, 3.85), 1.3, (1, 1.4, 0.3), 8, 4)
    sph("Mousse", "7BC95B", (-0.6, -2.5, 3.9), 0.8, (1, 1, 0.3), 7, 4)
    limb("Tige", "4E9A3A", (0.3, 1.4, 3.9), (0.3, 1.5, 5.3), 0.1, 0.05, 5)
    for i, (x, y, z) in enumerate(((0.3, 1.5, 5.4), (-0.5, 1.4, 4.9), (1.1, 1.7, 5.0), (0.3, 0.9, 4.7))):
        sph("Feuille", ["5FC04A", "7BD65A", "3F9A3C", "A6E05A"][i], (x, y, z), 0.5, (1.2, 0.8, 0.45), 7, 4)

def stump_roots():
    cyl("Souche", "8A5A33", (0, 0, 1.2), 2.5, 2.4, v=12)
    cyl("Coupe", "E5C48A", (0, 0, 2.43), 2.45, 0.08, v=12)
    cyl("Cernes", "C9A468", (0, 0, 2.49), 1.6, 0.06, v=12)
    cyl("Cernes", "B08A4F", (0, 0, 2.53), 0.7, 0.06, v=10)
    for a in (10, 80, 145, 215, 280):
        limb("Racine", "74492A", (math.cos(R(a)) * 1.8, math.sin(R(a)) * 1.8, 1.6), (math.cos(R(a)) * 3.8, math.sin(R(a)) * 3.8, 0.05), 0.8, 0.2, 6)
    sph("Mousse", "5FAE46", (-1.9, -0.9, 0.5), 0.8, (1, 1, 0.45), 7, 4)
    cyl("Pied_Champignon", "F2E8D5", (1.9, -1.3, 0.35), 0.15, 0.7, v=6)
    sph("Chapeau", "D8453B", (1.9, -1.3, 0.8), 0.45, (1, 1, 0.55), 8, 4)

def well_roofed():
    rng = random.Random(5)
    sl = ["B8B6B0", "A9A7A3", "C7C3BA"]
    n = 14
    for i in range(n):
        a = 2 * math.pi * i / n
        box("Dalle", sl[i % 3], (math.cos(a) * 6.1, math.sin(a) * 6.1, 0.15 + (i % 2) * 0.04), (1.5, 2.5, 0.3), (0, 0, a))
    for i in range(9):
        a = 2 * math.pi * i / 9 + 0.2
        box("Dalle", sl[(i + 1) % 3], (math.cos(a) * 4.3, math.sin(a) * 4.3, 0.2), (1.8, 2.3, 0.3), (0, 0, a))
    cyl("Dalle_Centre", "9E9C98", (0, 0, 0.15), 3.3, 0.3, v=12)
    st = ["9A9892", "B3B0A6", "A5A29A", "8F8D88"]
    for i in range(12):
        cyl("Assise", st[i % 4], (0, 0, 0.5 + 0.2 + i * 0.4), 2.4, 0.4, (0, 0, R(i * 17)), 9)
    cyl("Margelle", "BDBAB0", (0, 0, 5.4), 2.75, 0.4, v=9)
    cyl("Eau", "2C3946", (0, 0, 5.63), 1.7, 0.05, v=10)
    wd, wd2 = "8B4A24", "A55A2C"
    for s in (-1, 1):
        box("Poteau", wd, (s * 2.1, 0, 7.4), (0.7, 0.7, 3.6))
        box("Poutre", wd, (s * 2.1, 0, 9.05), (0.6, 6.0, 0.5))
        limb("Jambe_Bois", wd2, (s * 2.1, 0, 7.8), (s * 3.4, 0, 9.0), 0.25, 0.2, 5)
        limb("Jambe_Bois", wd2, (s * 2.1, 0, 7.8), (s * 2.1, -2.2, 9.0), 0.25, 0.2, 5)
    zb = 9.1; rise = 2.3; xe = 3.9; phi = math.atan2(rise, xe)
    for s in (-1, 1):
        box("Sous_Toit", "6E3B20", (s * (xe / 2), 0, zb + rise / 2 + 0.05), (math.hypot(xe, rise) + 0.6, 6.0, 0.3), (0, s * phi, 0))
    box("Faitage", wd, (0, 0, zb + rise + 0.05), (0.5, 6.8, 0.5))
    tint = ["D9503F", "EE7B4A", "F7A06B"]
    for s in (-1, 1):
        for j in range(3):
            t = (j + 0.5) / 3
            for k in range(4):
                y = (k - 1.5) * 1.5 + (0.4 if j % 2 else 0)
                bx = s * xe * (1 - t) + s * math.sin(phi) * 0.28; bz = zb + rise * t + math.cos(phi) * 0.28 + 0.05
                box("Tuile", tint[(j + k + (s > 0)) % 3], (bx, y + rng.uniform(-0.05, 0.05), bz + rng.uniform(-0.03, 0.03)), (1.9, 1.42, 0.22), (0, s * phi + rng.uniform(-0.05, 0.05), 0))
    for i in range(3):
        box("Tuile_Faitage", "F7706A", (0, (i - 1) * 2.1, zb + rise + 0.45), (1.3, 2.05, 0.28), (0, 0, 0))
    cyl("Treuil", wd2, (0.2, 0, 6.8), 0.28, 5.4, (0, R(90), 0), 8)
    for x in (-0.3, 0.3): cyl("Corde_Enroulee", "C98A2E", (x, 0, 6.8), 0.42, 0.5, (0, R(90), 0), 6)
    cyl("Corde", "D9A441", (0, 0, 6.2), 0.07, 1.3, v=5)
    torus("Roue", wd, (2.85, 0, 6.8), 1.1, 0.13, (0, R(90), 0))
    box("Rayon", wd2, (2.85, 0, 6.8), (0.12, 2.1, 0.14)); box("Rayon", wd2, (2.85, 0, 6.8), (0.12, 0.14, 2.1))
    cyl("Moyeu", wd, (2.85, 0, 6.8), 0.3, 0.3, (0, R(90), 0), 6)
    cyl("Seau", "B87A3E", (0, -3.7, 0.75), 0.55, 0.9, v=8)
    for z in (0.5, 1.0): cyl("Anneau", "3E3A38", (0, -3.7, z), 0.58, 0.1, v=8)
    torus("Anse", "4A3A2E", (0, -3.7, 1.25), 0.5, 0.05, (R(90), 0, 0))
    fw = "7A4A26"; fr = "9A5F30"
    for p in ((-8.8, 8.8), (-8.8, 0), (-8.8, -8.8), (0, 8.8), (8.8, 8.8)):
        box("Poteau_Cloture", fw, (p[0], p[1], 1.8), (0.8, 0.8, 3.6))
    for z in (1.3, 2.5):
        for y0 in (0, -8.8): box("Lisse", fr, (-8.8, y0 + 4.4, z + rng.uniform(-0.1, 0.1)), (0.35, 8.6, 0.35))
        for x0 in (0, 8.8): box("Lisse", fr, (x0 - 4.4, 8.8, z + rng.uniform(-0.1, 0.1)), (8.6, 0.35, 0.35))
    gr = ["4FA83A", "7BC94B"]
    for i, (x, y) in enumerate(((-6.8, -5), (5.5, -6.5), (7, 2), (-7.5, 4), (3, 7.3))):
        for j in range(2):
            cone("Herbe", gr[(i + j) % 2], (x + j * 0.25, y, 0.8), 0.2, 0.02, 1.6, (0.25 * (j * 2 - 1), 0.2, 0), 4)
    for p in ((-6, -7.4, 0.3), (7.2, -4.2, 0.3), (6.0, 6.2, 0.3), (-7.4, 7.2, 0.3), (2.4, -8.0, 0.3), (-4.2, -8.2, 0.3)):
        rock("Caillou", "A8A49C", p, 0.55, (1, 0.8, 0.6), (rng.random(), 0, rng.random()))

def island_sakura():
    rng = random.Random(7)
    cyl("Socle_Pierre", "3B3F47", (0, 0, 0.8), 13, 1.6, (0, 0, 0.2), 14)
    cyl("Gazon", "7ED04B", (0, 0, 1.85), 12.6, 0.5, (0, 0, 0.2), 14)
    for p, r, c in (((-5, -5, 2.13), 3.2, "93DC5C"), ((6, 3, 2.13), 2.5, "93DC5C"), ((-6, 5, 2.13), 2.8, "6DBE3E")):
        cyl("Gazon_Plaque", c, p, r, 0.06, v=9)
    tk = ["3A2F33", "2B2328"]
    limb("Tronc", tk[0], (0, 2, 2.0), (0.6, 2, 5.0), 1.2, 0.8, 6)
    limb("Tronc", tk[0], (0.6, 2, 5.0), (-0.4, 2.3, 8.3), 0.8, 0.5, 6)
    limb("Tronc", tk[1], (0.2, 2, 2.0), (1.8, 2.6, 5.8), 0.8, 0.45, 6)
    for a in (30, 150, 270):
        limb("Racine", tk[1], (0.2, 2, 3.0), (0.2 + math.cos(R(a)) * 1.8, 2 + math.sin(R(a)) * 1.8, 1.95), 0.5, 0.15, 5)
    ms = [(0, 2, 13.5, 4.2), (-4.5, 1, 11.5, 3.4), (4.8, 2.2, 11.8, 3.5), (0.5, -2.2, 11, 3.2), (0.5, 6.3, 11.4, 3.3), (-2.5, 5, 13, 3), (3, -0.5, 14, 3), (-3.2, -1.5, 13, 2.9), (7, 3, 10.2, 2.4), (-7, 2, 10.2, 2.4), (1.5, 3.5, 15.5, 2.6)]
    pk = ["F7A8C4", "F48FB1", "FBC4D8"]
    for i, (x, y, z, r) in enumerate(ms):
        sph("Petales", pk[i % 3], (x, y, z), r, (1, 1, 0.75), 9, 6)
        a = rng.random() * 6.28
        sph("Petales_Bouquet", pk[(i + 1) % 3], (x + math.cos(a) * r * 0.55, y + math.sin(a) * r * 0.55, z + r * 0.3), r * 0.55, (1, 1, 0.7), 8, 5)
        if i < 6: limb("Branche", tk[1], (0.4, 2.2, 7.5), (x * 0.8, y * 0.9 + 0.2, z - 1.5), 0.3, 0.12, 5)
    bg = ["D9CDB8", "CBBFA8", "E0D6C2"]
    for i, (x, y, r) in enumerate(((-5.2, -1.2, 2.2), (-2.8, 3.8, 1.8), (3.8, 0.4, 2.0))):
        rock("Rocher", bg[i], (x, y, 1.9 + r * 0.45), r, (1.15, 0.95, 0.75), (0, 0, rng.random() * 3), 7, 5)
    for x, y in ((2.5, 5.5), (-1.5, -0.2)):
        rock("Rocher", "C8BCA5", (x, y, 2.4), 0.9, (1, 0.9, 0.7), (0, 0, rng.random() * 3))
    for i in range(4):
        box("Dalle_Escalier", "D8D0C0" if i % 2 else "CFC7B6", (1.5 + i * 0.5, -3.5 - i * 2.1, 2.2 - i * 0.04), (3.0, 1.9, 0.32 + 0.0), (0, 0, R(rng.uniform(-8, 8))))
    for i in range(12):
        a = rng.random() * 6.28; d = 2 + rng.random() * 9
        cyl("Petale_Sol", "FFB7CE", (math.cos(a) * d, math.sin(a) * d, 2.13), 0.3, 0.04, v=5)

def boulder_cluster():
    rng = random.Random(11)
    cs = ["BDB4A2", "A9A395", "CFC6B3", "9A958A", "B8AE9C"]
    spec = [(-1.6, 0.4, 2.0, (1.15, 1.0, 0.85)), (1.9, 0.8, 1.7, (1.0, 1.1, 0.8)), (0.2, -2.0, 1.3, (1.2, 0.9, 0.8)), (-2.4, -2.0, 1.1, (1.0, 1.0, 0.8)), (3.0, -1.6, 0.9, (1.1, 0.9, 0.9))]
    for i, (x, y, r, sc) in enumerate(spec):
        rock("Rocher", cs[i], (x, y, r * sc[2] * 0.85), r, sc, (rng.random(), rng.random(), rng.random() * 3), 7, 4)
    for x, y, z, r in ((-1.8, 0.6, 3.0, 0.9), (1.7, 1.0, 2.4, 0.7), (0.3, -2.1, 1.8, 0.6), (-2.7, -1.9, 1.5, 0.5), (-0.5, 0.3, 2.6, 0.5)):
        sph("Mousse", "6FA84A", (x, y, z), r, (1, 1, 0.35), 7, 4)
    for x, y in ((3.4, 0.2), (-3.6, 1.3), (1.2, -3.5), (-1.0, -3.4)):
        rock("Caillou", "ADA698", (x, y, 0.3), 0.45, (1, 0.9, 0.7), (rng.random(), 0, rng.random()))

def bench_park():
    cols = ["D83A3A", "2F6FD0", "F2C230"]
    for i, c in enumerate(cols):
        box("Latte_Assise", c, (0, -0.8 + i * 0.65, 1.7), (6, 0.58, 0.18))
        box("Latte_Dossier", c, (0, 1.05 + i * 0.06, 2.5 + i * 0.55), (6, 0.15, 0.48), (R(-8), 0, 0))
    for s in (-1, 1):
        x = s * 2.6
        box("Pied_Fer_Avant", "2B2E35", (x, -1.0, 1.25), (0.22, 0.22, 2.5))
        limb("Pied_Fer_Arriere", "2B2E35", (x, 0.8, 0), (x, 1.2, 3.8), 0.12, 0.1, 6)
        box("Fer_Support", "2B2E35", (x, 0.1, 1.5), (0.2, 2.0, 0.2))
        box("Accoudoir_Fer", "2B2E35", (x, 0.0, 2.5), (0.22, 2.4, 0.16))

def flowerbed():
    cyl("Terre", "5B3A22", (0, 0, 0.275), 2.0, 0.55, v=14)
    sc = ["A9A59B", "C2BDB0", "8F8B82"]
    for i in range(10):
        a = 2 * math.pi * i / 10
        box("Pierre", sc[i % 3], (math.cos(a) * 2.05, math.sin(a) * 2.05, 0.28), (0.9, 0.75, 0.56 - (i % 2) * 0.06), (0, 0, a + 0.15))
    sph("Feuillage", "3F9A3C", (-0.3, 0.3, 0.55), 1.1, (1, 1, 0.45), 8, 4)
    sph("Feuillage", "5FB84A", (0.5, -0.4, 0.55), 0.9, (1, 1, 0.45), 8, 4)
    for x, y, h in ((-1.0, 0.6, 1.5), (0.1, 1.2, 1.7), (0.8, 0.3, 1.4)):
        limb("Tige", "3F9A3C", (x, y, 0.5), (x, y, h), 0.05, 0.04, 5)
        sph("Fleur_Rouge", "E5413C", (x, y, h + 0.1), 0.38, (1, 1, 0.6), 7, 4)
    for x, y, h in ((-0.5, -0.9, 1.5), (0.4, -1.2, 1.6), (1.2, -0.4, 1.4)):
        limb("Tige", "3F9A3C", (x, y, 0.5), (x, y, h), 0.05, 0.04, 5)
        cone("Fleur_Jaune", "F5C02E", (x, y, h + 0.3), 0.35, 0.12, 0.7, v=6)
    for x, y in ((-1.2, -0.3), (-0.2, 0.1), (1.0, 1.0), (0.1, -0.2)):
        sph("Fleur_Violette", "9A63D6", (x, y, 1.0), 0.42, (1, 1, 0.9), 7, 4)

for fn in (tree_fork, tree_wide, tree_autumn, tree_pine_tier, tree_dead, log_hollow, stump_roots, well_roofed, island_sakura, boulder_cluster, bench_park, flowerbed): reg(fn)
json.dump(M, open(os.path.join(OUT, "info17.json"), "w"), indent=1)
