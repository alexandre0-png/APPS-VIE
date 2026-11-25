import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
PI2 = math.pi / 2
WOOD = "8B5A2B"; WOOD_L = "A0662E"; CREAM = "F2E6C8"

# Convention : x = largeur, y = profondeur (devant = -y), z = hauteur, origine au centre du socle (z=0 au sol)

def stall_frame(c1, c2):
    """Structure commune des deux étals : 4 poteaux, auvent rayé 6 bandes, comptoir, fond."""
    for x, y in ((-1.4, -0.9), (1.4, -0.9), (-1.4, 0.9), (1.4, 0.9)):
        cyl("Poteau", WOOD, (x, y, 2.3), 0.07, 4.6, v=6)
    for i in range(6):
        x = -1.25 + i * 0.5
        box("Auvent", c1 if i % 2 == 0 else c2, (x, 0, 4.6), (0.5, 2.4, 0.12), (-0.12, 0, 0))
    box("Fond", CREAM, (0, 0.95, 2.2), (2.9, 0.08, 2.6))
    box("Comptoir", WOOD_L, (0, -0.6, 0.5), (2.6, 0.7, 1.0))
    box("Plateau", CREAM, (0, -0.6, 1.04), (2.8, 0.8, 0.08))

def stall_a():
    stall_frame("E0392B", "F5F5F5")
    box("Caisse", "D9A441", (-0.7, -0.6, 1.3), (0.6, 0.5, 0.4))
    box("Caisse", "E0523A", (0.7, -0.6, 1.3), (0.6, 0.5, 0.4))
    sph("Fruit", "FF3B30", (-0.7, -0.6, 1.6), 0.12)
    sph("Fruit", "FFB000", (0.6, -0.6, 1.6), 0.12)
    sph("Fruit", "7ED957", (0.8, -0.5, 1.6), 0.12)
    box("Etagere", WOOD, (0, 0.85, 2.0), (2.8, 0.2, 0.1))

def stall_b():
    stall_frame("1E6FD9", "F5F5F5")
    for x in (-1.05, 1.05):
        cyl("Tonneau", "9C6B3A", (x, -1.45, 0.45), 0.3, 0.9, v=8)
        cyl("Cercle", "4A4A4A", (x, -1.45, 0.25), 0.32, 0.08, v=8)
        cyl("Cercle", "4A4A4A", (x, -1.45, 0.65), 0.32, 0.08, v=8)

def crate_stack():
    h = 4.0 / 3
    for i in range(3):
        z = h / 2 + i * h
        box("Caisse", "C9873F" if i % 2 == 0 else "B5722F", (0, 0, z), (4, 3, h - 0.04))
        box("Lattes", "8B5A2B", (0, -1.52, z), (3.6, 0.1, 0.18))

def barrel_pair():
    for x in (-0.8, 0.8):
        cyl("Tonneau", "9C6B3A", (x, 0, 0.8), 0.6, 1.6, v=10)
        cyl("Cercle", "4A4A4A", (x, 0, 0.35), 0.63, 0.12, v=10)
        cyl("Cercle", "4A4A4A", (x, 0, 1.25), 0.63, 0.12, v=10)

def hay_bale():
    cyl("Paille", "E2C878", (0, 0, 1.5), 1.5, 2.0, rot=(0, PI2, 0), v=16)
    cyl("Corde", "6E4C2E", (-0.6, 0, 1.5), 1.53, 0.12, rot=(0, PI2, 0), v=16)
    cyl("Corde", "6E4C2E", (0.6, 0, 1.5), 1.53, 0.12, rot=(0, PI2, 0), v=16)

def reeds():
    for i, (x, y) in enumerate(((-0.5, -0.3), (0.0, 0.2), (0.45, -0.25), (-0.2, -0.6), (0.3, 0.45), (0.05, -0.05))):
        a = i * 1.1
        cone("Roseau", "5CA052" if i % 2 == 0 else "4B8E45", (x, y, 1.0), 0.05, 0.025, 2.0,
             (0.1 * math.sin(a), 0.1 * math.cos(a), 0), v=5)
    cyl("Epi", "7A4A2A", (-0.5, -0.3, 1.75), 0.09, 0.45, v=6)
    cyl("Epi", "8B5A2B", (0.45, -0.25, 1.75), 0.09, 0.45, v=6)

def lily_pad():
    box("Socle", "3C96DC", (0, 0, 0.1), (4, 4, 0.2))
    for x, y in ((-0.9, -0.6), (0.9, -0.6), (0.0, 0.9)):
        cyl("Nenuphar", "3FA34D", (x, y, 0.24), 0.9, 0.08, v=12)
    # une seule fleur rose (3 pétales) posée sur le nénuphar du fond
    for dx, dy in ((-0.16, 0.9), (0.16, 0.9), (0.0, 1.06)):
        sph("Fleur", "FF8FC1", (dx, dy, 0.36), 0.16, (1, 1, 0.5), seg=8, rings=4)

def bush_round():
    sph("Buisson", "4B8E45", (0, 0, 1.1), 1.1, seg=12, rings=8)
    sph("Buisson", "5CA052", (-0.8, 0.1, 0.75), 0.75, seg=10, rings=6)
    sph("Buisson", "5CA052", (0.8, 0.1, 0.75), 0.75, seg=10, rings=6)
    sph("Buisson", "5CA052", (-0.4, -0.6, 0.6), 0.6, seg=8, rings=5)
    sph("Buisson", "4B8E45", (0.2, 0.0, 2.1), 0.7, seg=10, rings=6)

def sign_base():
    box("Socle", "6E7280", (0, 0, 0.15), (0.6, 0.6, 0.3))
    box("Poteau", WOOD, (0, 0, 2.5), (0.3, 0.3, 5.0))
    box("Planche", "C58B4A", (0, -0.2, 3.9), (3.0, 0.2, 1.2))
    box("Lettrage", CREAM, (0, -0.32, 3.9), (2.0, 0.04, 0.5))
    cone("Fleche", "FFCD46", (-1.8, -0.2, 3.9), 0.35, 0.0, 0.6, (0, -PI2, 0), v=4)
    cone("Fleche", "FFCD46", (1.8, -0.2, 3.9), 0.35, 0.0, 0.6, (0, PI2, 0), v=4)

def flag_banner():
    cyl("Mat", "785028", (0, 0, 4.0), 0.12, 8.0, v=8)
    sph("Pointe", "FFCD46", (0, 0, 8.1), 0.2, seg=8, rings=5)
    box("Toile", "D63A3A", (1.42, 0, 6.5), (2.6, 0.1, 1.8))
    box("Toile", "D63A3A", (2.9, 0, 7.2), (0.8, 0.1, 0.8), (0, 0, math.pi / 4))
    box("Toile", "D63A3A", (2.9, 0, 5.8), (0.8, 0.1, 0.8), (0, 0, math.pi / 4))
    box("Bande", CREAM, (1.42, -0.06, 7.4), (2.6, 0.02, 0.18))

def lantern_post():
    box("Socle", "6E7280", (0, 0, 0.15), (0.8, 0.8, 0.3))
    cyl("Poteau", "7A4E2A", (0, 0, 3.15), 0.15, 5.7, v=8)
    box("Traverse", "7A4E2A", (0, 0, 5.7), (1.4, 0.12, 0.12))
    box("Lanterne", "FFB347", (0, 0, 6.35), (0.5, 0.5, 0.7))
    sph("Flamme", "FFE9A8", (0, 0, 6.35), 0.2, seg=8, rings=5)
    cone("Toit", "3A2A1A", (0, 0, 6.85), 0.42, 0.0, 0.3, v=4)

def well_small():
    for i in range(10):
        a = i * 2 * math.pi / 10
        box("Pierre", "8E93A0" if i % 2 == 0 else "7A7F8C",
            (1.25 * math.cos(a), 1.25 * math.sin(a), 0.9), (0.8, 0.55, 1.8), (0, 0, a + PI2))
    cyl("Eau", "3C96DC", (0, 0, 1.0), 0.9, 0.1, v=10)
    for x in (-1.1, 1.1):
        box("Poteau", WOOD, (x, 0, 2.5), (0.25, 0.25, 5.0))
    box("Traverse", "6E4C2E", (0, 0, 4.9), (2.6, 0.2, 0.2))
    box("Toit", "A87038", (-0.8, 0, 5.5), (2.2, 2.6, 0.2), (0, 0, 0))
    box("Toit", "A87038", (0.8, 0, 5.5), (2.2, 2.6, 0.2), (0, 0, 0))
    cyl("Corde", "8B7355", (0, 0, 3.8), 0.03, 2.0, v=4)
    cyl("Seau", WOOD, (0, -1.9, 0.3), 0.3, 0.5, v=8)

BUDGET = {"stall_a": 25, "stall_b": 25, "crate_stack": 8, "barrel_pair": 8, "hay_bale": 4, "reeds": 12,
          "lily_pad": 8, "bush_round": 6, "sign_base": 8, "flag_banner": 6, "lantern_post": 10, "well_small": 30}
MODELS = {"stall_a": stall_a, "stall_b": stall_b, "crate_stack": crate_stack, "barrel_pair": barrel_pair,
          "hay_bale": hay_bale, "reeds": reeds, "lily_pad": lily_pad, "bush_round": bush_round,
          "sign_base": sign_base, "flag_banner": flag_banner, "lantern_post": lantern_post, "well_small": well_small}

for name, fn in MODELS.items():
    reset(); fn()
    n, t = export(os.path.join(OUT, name + ".fbx"))
    M[name] = {"parts": n, "faces": t, "budget": BUDGET[name], "ok": n <= BUDGET[name]}
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
print("OK", {k: (v["parts"], v["budget"]) for k, v in M.items()})
