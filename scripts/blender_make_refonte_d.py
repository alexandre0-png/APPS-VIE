import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
import bpy
OUT = sys.argv[1]; M = {}
PI2 = math.pi / 2

# Convention : x = largeur, y = profondeur (devant = -y), z = hauteur, origine au centre du socle (z=0 au sol)

def stretch_z(o, f):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True); bpy.context.view_layer.objects.active = o
    o.scale = (1, 1, f); bpy.ops.object.transform_apply(scale=True)

def toaster():
    box("Corps", "E0392B", (0, 0, 0.65), (2.0, 1.2, 1.3))
    for i in range(4):
        box("ChromeFente", "C9CED6", (-0.6 + i * 0.4, 0, 1.34), (0.3, 0.9, 0.08))
    for x in (-0.75, 0.75):
        cyl("Bouton", "222222", (x, -0.66, 0.7), 0.12, 0.1, rot=(PI2, 0, 0), v=10)

def coffee_maker():
    box("Socle", "2B2B2B", (0, 0, 0.15), (1.6, 1.6, 0.3))
    box("Corps", "3A3A3A", (0, 0, 1.15), (1.4, 1.2, 1.7))
    box("Reservoir", "4FA3E0", (0, 0.1, 2.3), (1.2, 1.0, 0.6))
    cyl("Tasse", "F2E6C8", (0, -0.55, 0.45), 0.2, 0.3, v=12)
    cyl("Cafe", "5A3A1E", (0, -0.55, 0.59), 0.16, 0.02, v=12)
    box("Bouton", "E0392B", (0.4, -0.63, 1.6), (0.25, 0.05, 0.12))

def speaker_pair():
    for x in (-0.5, 0.5):
        cyl("Enceinte", "1E6FD9", (x, 0, 0.8), 0.5, 1.0, rot=(PI2, 0, 0), v=5)
    for x in (-0.5, 0.5):
        pass
    # etirement vertical des enceintes (pentagone -> hauteur 1,6)
    for o in [ob for ob in bpy.context.scene.objects if ob.name.startswith("Enceinte")]:
        stretch_z(o, 1.68)
    for x in (-0.5, 0.5):
        cyl("Membrane", "1A1A1A", (x, -0.53, 0.8), 0.3, 0.06, rot=(PI2, 0, 0), v=12)
        sph("Tweeter", "F2E6C8", (x, -0.56, 1.25), 0.1, seg=8, rings=6)

def plant_pot_a():
    cone("Pot", "B5562E", (0, 0, 0.5), 0.6, 0.8, 1.0, v=12)
    cyl("Terre", "4A2F1A", (0, 0, 0.98), 0.78, 0.06, v=12)
    for i in range(6):
        a = i * 2 * math.pi / 6
        box("Feuille", "3E9B45" if i % 2 == 0 else "4CAF50", (0, 0, 2.0), (0.14, 0.05, 2.2), rot=(0, 0.45, a))

def plant_pot_b():
    cyl("Pot", "6B6F7A", (0, 0, 1.0), 0.8, 2.0, v=16)
    cyl("Terre", "4A2F1A", (0, 0, 2.0), 0.76, 0.08, v=16)
    for i in range(8):
        a = i * 2 * math.pi / 8
        box("Feuille", "3E9B45" if i % 2 == 0 else "2F7D3A", (0, 0, 3.4), (0.2, 0.05, 3.0), rot=(0, 0.35, a))

def coffee_table_round():
    cyl("Plateau", "A0662E", (0, 0, 1.5), 4.0, 0.2, v=32)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("Pied", "6E4C2E", (sx * 1.5, sy * 1.5, 0.7), (0.3, 0.3, 1.5),
                rot=(sy * 0.3, -sx * 0.3, 0))

def wall_lamp():
    box("Laiton", "C9A24A", (0, 0.44, 0.9), (0.5, 0.12, 1.8))
    box("Laiton", "C9A24A", (0, 0.2, 1.45), (0.1, 0.5, 0.1))
    cone("Verre", "F4E3B0", (0, 0, 1.3), 0.6, 0.4, 0.6, v=16)
    sph("Lanterne", "FFF3C4", (0, 0, 1.2), 0.12, seg=8, rings=6)
    torus("Laiton", "C9A24A", (0, 0, 1.0), 0.6, 0.03)

def branch_chandelier():
    cyl("Laiton", "C9A24A", (0, 0, 3.25), 0.05, 2.5, v=8)
    sph("Laiton", "C9A24A", (0, 0, 2.0), 0.25, seg=10, rings=6)
    cone("Laiton", "C9A24A", (0, 0, 4.5), 0.25, 0.1, 0.2, v=8)
    for i in range(6):
        a = i * math.pi / 3
        cyl("Laiton", "C9A24A", (2.0 * math.cos(a), 2.0 * math.sin(a), 2.0), 0.04, 4.0,
            rot=(0, PI2, a), v=6)
        sph("Lanterne", "FFE9A8", (3.7 * math.cos(a), 3.7 * math.sin(a), 1.9), 0.2, seg=8, rings=6)

def oven_stove():
    box("Corps", "D9DCE3", (0, 0, 1.5), (3.0, 2.8, 3.0))
    box("Plan", "2B2B2B", (0, 0, 3.05), (3.0, 2.8, 0.1))
    box("Dosseret", "D9DCE3", (0, 1.25, 3.25), (3.0, 0.3, 0.4))
    for bx, by in ((-0.7, -0.5), (0.7, -0.5), (-0.7, 0.6), (0.7, 0.6)):
        cyl("Grille", "8A8F99", (bx, by, 3.125), 0.3, 0.05, v=12)
        cyl("Capuchon", "E0392B", (bx, by, 3.17), 0.12, 0.06, v=10)
    box("Verre", "9FB7C9", (0, -1.46, 1.2), (2.0, 0.04, 1.1))
    box("Poignee", "C0C4CC", (0, -1.5, 1.95), (2.0, 0.1, 0.1))
    for x in (-1.0, -0.35, 0.35, 1.0):
        cyl("Bouton", "222222", (x, -1.46, 2.6), 0.1, 0.12, rot=(PI2, 0, 0), v=10)

def stool_side():
    cyl("Plateau", "E63946", (0, 0, 2.05), 1.0, 0.3, v=8)
    sph("Vase", "2A9D8F", (0, 0, 2.6), 0.4)
    for i in range(3):
        a = i * 2 * math.pi / 3 + math.pi / 2
        cyl("ChromePied", "C9CED6", (0.45 * math.cos(a), 0.45 * math.sin(a), 0.95), 0.05, 1.9,
            rot=(0.25 * math.sin(a), -0.25 * math.cos(a), 0), v=6)
    torus("ChromeAnneau", "C9CED6", (0, 0, 0.8), 0.58, 0.03)

def vase_big():
    cyl("Socle", "8E93A0", (0, 0, 0.1), 0.5, 0.2, v=16)
    sph("Corps", "3F7CAC", (0, 0, 1.3), 0.9, sc=(1, 1, 1.25), seg=16, rings=10)
    cone("Col", "3F7CAC", (0, 0, 2.6), 0.4, 0.3, 0.6, v=16)
    torus("Levre", "3F7CAC", (0, 0, 2.9), 0.32, 0.06)

def books_stack():
    cols = ["C0392B", "2E86AB", "F4A261", "2A9D8F", "E9C46A", "6A4C93"]
    for i, c in enumerate(cols):
        x = 0.05 if i % 2 else -0.05
        box("Livre", c, (x, 0, 0.1167 + i * 0.2333), (2.0, 1.4, 0.22))

def clock_wall():
    cz = 1.5
    torus("Cadre", "8B5A2B", (0, 0, cz), 1.15, 0.12, rot=(PI2, 0, 0))
    cyl("Cadran", "F5F0E1", (0, -0.04, cz), 1.05, 0.06, rot=(PI2, 0, 0), v=32)
    h1 = 1.05; L1 = 0.55
    box("Aiguille", "222222", (0.5 * L1 * math.sin(h1), -0.1, cz + 0.5 * L1 * math.cos(h1)),
        (0.08, 0.05, L1), rot=(0, h1, 0))
    m1 = -1.57; L2 = 0.9
    box("Aiguille", "222222", (0.5 * L2 * math.sin(m1), -0.11, cz + 0.5 * L2 * math.cos(m1)),
        (0.06, 0.04, L2), rot=(0, m1, 0))
    sph("Pivot", "C0392B", (0, -0.12, cz), 0.06, seg=8, rings=6)
    cyl("Verre", "BFE3F0", (0, -0.1, cz), 1.1, 0.02, rot=(PI2, 0, 0), v=32)
    box("Repere", "222222", (0, -0.06, cz + 0.9), (0.05, 0.03, 0.15))
    box("Repere", "222222", (0, -0.06, cz - 0.9), (0.05, 0.03, 0.15))

def rug_round():
    cyl("Bordure", "8E2C2C", (0, 0, 0.075), 4.0, 0.15, v=40)
    cyl("Fond", "F2E6C8", (0, 0, 0.16), 3.4, 0.02, v=40)
    cyl("Motif", "2A6F97", (0, 0, 0.17), 2.3, 0.02, v=40)
    cyl("Centre", "E9C46A", (0, 0, 0.18), 1.0, 0.02, v=40)

BUDGET = {"toaster": 8, "coffee_maker": 10, "speaker_pair": 8, "plant_pot_a": 12, "plant_pot_b": 14,
          "coffee_table_round": 8, "wall_lamp": 6, "branch_chandelier": 20, "oven_stove": 18,
          "stool_side": 10, "vase_big": 4, "books_stack": 8, "clock_wall": 8, "rug_round": 6}
MODELS = {"toaster": toaster, "coffee_maker": coffee_maker, "speaker_pair": speaker_pair,
          "plant_pot_a": plant_pot_a, "plant_pot_b": plant_pot_b, "coffee_table_round": coffee_table_round,
          "wall_lamp": wall_lamp, "branch_chandelier": branch_chandelier, "oven_stove": oven_stove,
          "stool_side": stool_side, "vase_big": vase_big, "books_stack": books_stack,
          "clock_wall": clock_wall, "rug_round": rug_round}

def dims():
    xs, ys, zs = [], [], []
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            for v in o.data.vertices:
                w = o.matrix_world @ v.co
                xs.append(w.x); ys.append(w.y); zs.append(w.z)
    return [round(max(a) - min(a), 2) for a in (xs, ys, zs)]

for name, fn in MODELS.items():
    reset(); fn()
    d = dims()
    n, t = export(os.path.join(OUT, name + ".fbx"))
    M[name] = {"parts": n, "faces": t, "budget": BUDGET[name], "ok": n <= BUDGET[name], "dims_xyz": d}
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
print("OK", {k: (v["parts"], v["budget"], v["dims_xyz"]) for k, v in M.items()})
