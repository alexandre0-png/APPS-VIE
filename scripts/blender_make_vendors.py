# Lot 30 Chipe-Oeufs : 8 PNJ vendeurs (personnage + etal, pieces Etiquette et Lueur).
# Usage : python scripts/blender_make_vendors.py <dossier_sortie>   (devant = -Y, 1 unite = 1 stud)
# Perso debout derriere l'etal (y=+0.9), comptoir y -3..0, planche Etiquette 4x1.2 face avant plane a y=-3.0.
import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
from mathutils import Vector
OUT = sys.argv[1]; M = {}; PI = math.pi
def dims():
    mn=[1e9]*3; mx=[-1e9]*3; n=0
    for o in bpy.context.scene.objects:
        if o.type!="MESH": continue
        n+=1
        for c in o.bound_box:
            w=o.matrix_world@Vector(c)
            for i in range(3): mn[i]=min(mn[i],w[i]); mx[i]=max(mx[i],w[i])
    return [round(mx[i]-mn[i],2) for i in range(3)], [round(mn[i],2) for i in range(3)], n
def reg(name, fn, limit=40):
    reset(); fn(); d, mn, n = dims(); _, t = export(os.path.join(OUT, name + ".fbx"))
    M[name] = {"parts": n, "faces": t, "size": d, "min": mn}
    if n > limit: print("ATTENTION", name, n, ">", limit)

def stall(wood, cloth, trim, post="6B4F35", lamp="FFD76A"):
    """Comptoir 6x3x1.5, nappe, 2 poteaux, planche Etiquette, lanterne Lueur."""
    box("Comptoir", wood, (0, -1.5, 0.75), (6, 3, 1.5))
    box("Dessus", trim, (0, -1.5, 1.6), (6.4, 3.3, 0.2))
    box("Nappe", cloth, (0, -3.02, 0.8), (5.6, 0.12, 1.4))
    for s in (1, -1):
        cyl("Poteau", post, (s*2.9, -2.9, 3.0), 0.16, 6.0, v=8)
    box("Cadre_etiquette", trim, (0, -2.88, 6.2), (4.5, 0.16, 1.55))
    box("Etiquette", "F5EBD7", (0, -3.02, 6.2), (4, 0.12, 1.2))
    sph("Lueur", lamp, (0, -2.9, 7.55), 0.45, (1, 1, 1.2), seg=10, rings=6)

def char(body, skin, hair, legs, bw=2.0, bd=1.1, y=0.9, sleeve=None, arm_col=None, x=0, mouth=True, hair_on=True):
    box("Corps", body, (x, y, 2.3), (bw, bd, 1.6))
    sph("Tete", skin, (x, y, 4.0), 0.9)
    if hair_on: sph("Cheveux", hair, (x, y+0.12, 4.3), 0.93, (1, 1, 0.8), seg=10, rings=6)
    for s in (1, -1):
        sph("Oeil", "1A1A1A", (x+s*0.36, y-0.82, 4.02), 0.12, seg=6, rings=4)
        a = 0.9; L = 1.6; sx = x+s*(bw/2+0.3); sy = y; sz = 3.0
        c = Vector((sx, sy, sz)) + Vector((0, -math.sin(a), -math.cos(a)))*(L/2)
        e = Vector((sx, sy, sz)) + Vector((0, -math.sin(a), -math.cos(a)))*L
        box("Bras", sleeve or body, (c.x, c.y, c.z), (0.55, 0.55, L), (-a, 0, 0))
        sph("Main", skin, (e.x, e.y, e.z), 0.34, seg=8, rings=6)
    if mouth: box("Bouche", "B5453A", (x, y-0.86, 3.65), (0.36, 0.1, 0.1))

def egg(col, x, y, z, r=0.42): sph("Oeufs", col, (x, y, z), r, (0.85, 0.85, 1.2), seg=10, rings=6)

# 1 ---------------------------------------------------------------- Mere Poule
def eggs():
    stall("A9713A", "D9342B", "F5EBD7", lamp="FFD23F")
    char("F2C94C", "F8E3B0", "F2C94C", "D9342B", bw=2.3, bd=1.4, mouth=False)
    cone("Bec", "F28C28", (0, 0.9-0.95, 3.7), 0.3, 0.05, 0.7, (PI/2+PI, 0, 0), v=8)
    for i, x in enumerate((-0.35, 0, 0.35)): sph("Crete", "D9342B", (x, 0.9, 5.0+(0.15 if i==1 else 0)), 0.3, (0.8, 0.8, 1.2), seg=8, rings=5)
    sph("Aile", "F5D26A", (-1.5, 1.0, 2.5), 0.55, (0.5, 1, 1.4), seg=8, rings=5)
    box("Tablier", "F5EBD7", (0, 0.9-0.58, 2.1), (1.6, 0.12, 1.3))
    cols = ["F5EBD7", "E8B923", "5AA9E6", "E0557A", "7ACB6A", "9B6FD6", "F28C28", "C0392B"]
    for r in range(2):
        for i in range(6): egg(cols[(i+r*3) % 8], -2.25+i*0.9+(0.45 if r else 0), -1.0-r*0.9, 2.1)
    cyl("Panier", "C0793A", (2.2, -2.2, 1.95), 0.65, 0.5, v=10)
    for i, c in enumerate(("F5EBD7", "E8B923", "E0557A")): egg(c, 2.2+(i-1)*0.4, -2.2, 2.55)
reg("vendor_eggs", eggs)

# 2 ---------------------------------------------------------------- Madame Chance
def luck():
    stall("3B2A7A", "7B4FC9", "F2C94C", lamp="B58CFF")
    char("7B4FC9", "E8B48C", "2A1E3A", "4A2E8A", bw=2.3, bd=1.3)
    cone("Chapeau", "3B2A7A", (0, 0.9, 5.65), 1.0, 0.05, 2.0, v=12)
    cyl("Bord_chapeau", "3B2A7A", (0, 0.9, 4.75), 1.3, 0.15, v=14)
    for k, (x, z) in enumerate(((-0.3, 5.3), (0.25, 5.8), (-0.1, 6.3))): sph("Etoile", "F2C94C", (x, 0.5, z), 0.13, seg=6, rings=4)
    sph("Cheveux_long", "2A1E3A", (0, 1.5, 3.3), 0.8, (1.1, 0.5, 1.4), seg=8, rings=6)
    cyl("Socle_boule", "F2C94C", (0, -1.5, 1.85), 0.7, 0.3, v=10)
    sph("Cristaux", "6FE3F2", (0, -1.5, 2.65), 0.85, seg=14, rings=8)
    for i, (x, c, h) in enumerate(((1.4, "E0557A", 0.9), (2.0, "5AD17A", 1.1), (2.55, "F2C94C", 0.8))):
        sph("Potion", c, (x, -1.2, 2.0+h*0.25), 0.4, (1, 1, 0.9+h*0.3), seg=10, rings=6)
        cyl("Potion_col", "DDEAF5", (x, -1.2, 2.45+h*0.5), 0.14, 0.4, v=8)
    for i, x in enumerate((-2.4, -1.95, -1.5)):
        sph("Trefle", "3FBF5A", (x, -2.3, 1.9), 0.28, (1, 1, 0.5), seg=8, rings=5)
        sph("Trefle", "5AD17A", (x+0.2, -2.3, 2.08), 0.22, (1, 1, 0.5), seg=8, rings=5)
reg("vendor_luck", luck)

# 3 ---------------------------------------------------------------- Bob le Banquier
def coins():
    stall("4A4A55", "1F3F7A", "E8B923", lamp="FFD23F")
    # corps rond
    sph("Corps", "2B3A55", (0, 0.9, 2.4), 1.45, (1, 0.95, 0.9), seg=12, rings=8)
    sph("Gilet", "F2C94C", (0, 0.45, 2.3), 0.95, (1, 0.5, 1.0), seg=10, rings=6)
    box("Cravate", "C0392B", (0, 0.3, 2.95), (0.3, 0.12, 0.7))
    sph("Tete", "F2C8A0", (0, 0.9, 4.1), 0.85)
    for s in (1, -1):
        sph("Oeil", "1A1A1A", (s*0.34, 0.1, 4.2), 0.11, seg=6, rings=4)
        a = 0.8; sx = s*1.5; e = Vector((sx, 0.9, 2.9))+Vector((0, -math.sin(a), -math.cos(a)))*1.5
        c = Vector((sx, 0.9, 2.9))+Vector((0, -math.sin(a), -math.cos(a)))*0.75
        box("Bras", "2B3A55", (c.x, c.y, c.z), (0.6, 0.6, 1.5), (-a, 0, 0)); sph("Main", "F2C8A0", (e.x, e.y, e.z), 0.34, seg=8, rings=6)
    box("Moustache", "4A3A2A", (0, 0.05, 3.9), (0.9, 0.15, 0.2))
    cyl("Chapeau", "1A1A22", (0, 0.9, 5.0), 0.6, 0.9, v=12); cyl("Bord_chapeau", "1A1A22", (0, 0.9, 4.6), 1.05, 0.12, v=14)
    cyl("Ruban", "E8B923", (0, 0.9, 4.75), 0.62, 0.15, v=12)
    torus("Monocle", "E8B923", (0.34, 0.07, 4.2), 0.25, 0.04, (PI/2, 0, 0))
    # coffre + sacs + pieces
    box("Coffre", "8A5A2B", (-1.6, -1.6, 2.3), (1.9, 1.3, 1.0))
    cyl("Coffre_couvercle", "8A5A2B", (-1.6, -1.6, 2.8), 0.65, 1.9, (0, PI/2, 0), v=10)
    box("Coffre_bande", "E8B923", (-1.6, -2.27, 2.4), (0.3, 0.1, 1.2))
    for k in range(3): cyl("Pieces", "FFD23F", (-1.6+(k-1)*0.5, -1.6, 3.5+0.0), 0.25, 0.08, (PI/2, 0, 0), v=10) if False else None
    for i, (x, y, c) in enumerate(((1.0, -1.3, "6BAF5A"), (1.9, -1.9, "C9A66B"), (2.5, -1.0, "6BAF5A"))):
        sph("Sac", c, (x, y, 2.3), 0.55, (1, 1, 1.1), seg=10, rings=6)
    for i, (x, y, n) in enumerate(((0.0, -2.2, 4), (0.7, -2.4, 3), (-0.5, -0.8, 2))):
        for k in range(n): cyl("Pieces", "FFD23F", (x, y, 1.78+k*0.13), 0.38, 0.1, v=12)
reg("vendor_coins", coins)

# 4 ---------------------------------------------------------------- Gaston le Batisseur
def base():
    stall("A9713A", "F28C28", "3A3A42", lamp="FFB347")
    char("F28C28", "E0A878", "6B3A1E", "2E5AAC", bw=2.3, bd=1.3)
    box("Salopette", "2E5AAC", (0, 0.9-0.66, 2.0), (1.5, 0.12, 1.2))
    sph("Casque", "F2C94C", (0, 0.9, 4.45), 1.0, (1, 1, 0.75), seg=12, rings=6)
    cyl("Casque_bord", "F2C94C", (0, 0.9-0.2, 4.2), 1.1, 0.12, v=14)
    box("Casque_crete", "E8A317", (0, 0.9, 5.15), (0.3, 1.5, 0.25))
    box("Moustache", "6B3A1E", (0, 0.9-0.86, 3.75), (0.85, 0.14, 0.18))
    # maquettes de maisons
    for i, (x, c, rf) in enumerate(((-2.0, "F5EBD7", "C0392B"), (-0.2, "F2C94C", "2E8B3C"))):
        box("Maison", c, (x, -1.4, 2.3), (1.4, 1.2, 1.0)); cone("Maison_toit", rf, (x, -1.4, 3.2), 1.1, 0.05, 0.9, (0, 0, PI/4), v=4)
    # planches
    for k in range(3): box("Planches", "C9A27A" if k%2 else "B5834F", (2.0, -1.2, 1.85+k*0.2), (2.0, 0.7, 0.2), (0, 0, 0.1*k))
    # cles
    for x in (-2.4, -1.6):
        torus("Cle", "B8BEC4", (x, -2.5, 2.1), 0.22, 0.06, (PI/2, 0, 0)); box("Cle", "B8BEC4", (x, -2.5, 1.85), (0.1, 0.1, 0.7))
    cyl("Maillet", "6B4F35", (1.0, -2.3, 1.85), 0.08, 1.3, (0, PI/2, 0), v=6); box("Maillet_tete", "7A8590", (1.55, -2.3, 1.9), (0.5, 0.45, 0.45))
    box("Regle", "E8B923", (2.4, -2.5, 1.75), (1.8, 0.2, 0.08), (0, 0, 0.0))
reg("vendor_base", base)

# 5 ---------------------------------------------------------------- Capitaine Aldo
def combat():
    stall("5A5A66", "C0392B", "B8BEC4", post="3A3A42", lamp="FF8A3D")
    char("9AA0A6", "D9A070", "3A2A1E", "5A3A22", bw=2.5, bd=1.3, sleeve="C0392B")
    sph("Casque", "C8CDD2", (0, 0.9, 4.35), 1.0, (1, 1, 0.8), seg=12, rings=6)
    box("Casque_visiere", "8A9097", (0, 0.9-0.9, 4.2), (1.5, 0.15, 0.3))
    box("Crete", "D9342B", (0, 0.9, 5.3), (0.3, 1.6, 0.7))
    box("Cape", "C0392B", (0, 1.7, 2.3), (2.6, 0.2, 2.6), (-0.1, 0, 0))
    box("Baudrier", "5A3A22", (0, 0.9-0.66, 2.4), (0.25, 0.1, 1.7), (0, 0, 0.6))
    for x, c in ((-1.9, "3B82D9"), (1.9, "F2C94C")):
        cyl("Bouclier", c, (x, -3.0, 0.95), 0.9, 0.2, (PI/2, 0, 0), v=14)
        cyl("Bouclier_bord", "B8BEC4", (x, -3.05, 0.95), 1.0, 0.12, (PI/2, 0, 0), v=14)
        sph("Bouclier_boss", "E8E8EE", (x, -3.15, 0.95), 0.3, (1, 0.5, 1), seg=8, rings=5)
    for s in (1, -1):
        box("Epee", "D8DCE2", (s*0.0, -1.5, 2.9), (0.2, 0.12, 2.8), (0, -s*0.7, 0) if False else (0, s*0.7, 0))
        box("Epee_garde", "E8B923", (s*0.0, -1.5, 1.85), (0.2, 0.12, 0.2))
    box("Epee_garde", "E8B923", (0, -1.55, 2.35), (0.9, 0.1, 0.18), (0, 0, 0.0))
    cyl("Hampe", "5A3A22", (-2.9, -0.3, 3.3), 0.08, 3.5, v=6) if False else None
    cyl("Hampe_banniere", "5A3A22", (2.5, 0.9, 3.5), 0.1, 4.0, v=6)
    box("Banniere", "D9342B", (2.5, 0.9-0.5, 3.4), (0.15, 0.1, 0.1)) if False else None
    box("Banniere", "D9342B", (2.5, 0.9, 4.8), (1.2, 0.1, 1.8)); box("Banniere_embleme", "F2C94C", (2.5, 0.84, 4.9), (0.5, 0.05, 0.8))
    cone("Banniere_pointe", "B8BEC4", (2.5, 0.9, 5.7), 0.15, 0.02, 0.5, v=6)
    sph("Casque_lueur", "FF8A3D", (-2.4, -1.5, 2.1), 0.3, seg=8, rings=5)
reg("vendor_combat", combat)

# 6 ---------------------------------------------------------------- Maitre de saison
def season():
    stall("1F3F8F", "2A2A6A", "F2C94C", post="F2C94C", lamp="B58CFF")
    char("2A2A6A", "E8C09A", "DADADA", "1F2F6A", bw=2.4, bd=1.2, y=0.9, sleeve="2A2A6A")
    box("Cape", "5A2AA0", (0, 1.55, 2.3), (3.0, 0.22, 3.0), (-0.08, 0, 0))
    box("Col_dore", "F2C94C", (0, 0.9, 3.15), (2.7, 1.4, 0.3))
    box("Ceinture", "F2C94C", (0, 0.9-0.62, 1.75), (2.0, 0.1, 0.25))
    cone("Chapeau", "F2C94C", (0, 0.9, 5.1), 0.8, 0.5, 0.9, v=8)
    sph("Barbe", "DADADA", (0, 0.2, 3.5), 0.55, (1, 0.6, 1.0), seg=8, rings=6)
    cyl("Hampe", "6B4F35", (-3.2, 0.9, 3.3), 0.1, 6.0, v=6)
    box("Etendard", "5A2AA0", (-3.2+0.55, 0.9, 5.4), (1.1, 0.08, 1.8)); sph("Etendard_etoile", "FFE14A", (-2.65, 0.84, 5.4), 0.4, (1, 0.3, 1), seg=8, rings=5)
    for s in range(5):
        a = s*2*PI/5; cone("Etendard_etoile", "FFE14A", (-2.65+0.45*math.sin(a), 0.84, 5.4+0.45*math.cos(a)), 0.18, 0.02, 0.5, (0, a, 0), v=5)
    # panneau de paliers
    box("Panneau", "2A2A6A", (0, 2.2, 3.4), (5.6, 0.3, 3.4)); box("Panneau_bord", "F2C94C", (0, 2.3, 3.4), (5.9, 0.15, 3.7))
    pc = ["B8BEC4", "5AA9E6", "5AD17A", "F2C94C", "E0557A", "B58CFF"]
    for i in range(6): box("Palier", pc[i], (-2.3+i*0.92, 1.9, 2.1+i*0.28), (0.8, 0.12, 0.5+i*0.5))
    sph("Palier_etoile", "FFE14A", (2.3, 1.85, 4.9), 0.3, (1, 0.3, 1), seg=8, rings=5)
reg("vendor_pass", season)

# 7 ---------------------------------------------------------------- Colis Colette
def packs():
    stall("B5834F", "E0557A", "F5EBD7", lamp="FF9ED0")
    char("E0557A", "F2C8A0", "5A3A22", "5A3A8A", bw=2.1, bd=1.2, sleeve="F5EBD7")
    cyl("Casquette", "E0557A", (0, 0.9, 4.75), 0.9, 0.35, v=12); box("Visiere", "C0356A", (0, 0.9-0.95, 4.65), (1.3, 0.8, 0.1))
    sph("Natte", "5A3A22", (-0.7, 1.4, 3.7), 0.4, (0.8, 0.8, 1.5), seg=8, rings=5)
    box("Etiquette_colis", "F5EBD7", (0, 0.9-0.62, 2.3), (0.9, 0.08, 0.5))
    for i, (x, y, z, s, c, r) in enumerate((( -1.6, -1.5, 2.45, 1.5, "5AA9E6", "F2C94C"), (0.3, -1.4, 2.5, 1.6, "9B6FD6", "F5EBD7"), (2.0, -1.5, 2.35, 1.3, "5AD17A", "D9342B"), (-0.9, -1.5, 3.65, 1.0, "F28C28", "5AA9E6"))):
        box("Cadeau", c, (x, y, z), (s, s, s*0.9), (0, 0, 0.15*(i-1)))
        box("Ruban", r, (x, y, z), (0.25*s+0.05, s+0.06, s*0.9+0.06), (0, 0, 0.15*(i-1)))
        box("Ruban", r, (x, y, z), (s+0.06, 0.25*s+0.05, s*0.9+0.06), (0, 0, 0.15*(i-1)))
        sph("Noeud", r, (x, y, z+s*0.45+0.12), 0.22*s+0.05, (1.4, 0.8, 0.6), seg=8, rings=5)
    box("Petit_colis", "C9A27A", (1.0, -2.4, 1.95), (0.8, 0.6, 0.5))
reg("vendor_packs", packs)

# 8 ---------------------------------------------------------------- Stylo le Styliste
def cosm():
    stall("2EC4B6", "FF5DA2", "F5EBD7", lamp="FF8AD8")
    char("2EC4B6", "C98E66", "FF5DA2", "3A3A55", bw=2.0, bd=1.1, sleeve="2EC4B6")
    cyl("Beret", "7B4FC9", (0.2, 0.9, 4.95), 0.95, 0.28, v=12)
    for s in (1, -1): torus("Lunettes", "F2C94C", (s*0.4, 0.9-0.9, 4.02), 0.28, 0.05, (PI/2, 0, 0))
    # cintres + portant
    cyl("Barre", "B8BEC4", (-2.3, 0.1, 4.0), 0.06, 2.0, (0, PI/2, 0), v=6) if False else None
    for i, c in enumerate(("FF5DA2", "7B4FC9", "F2C94C")):
        torus("Cintre", c, (-2.5+i*0.5, -1.0, 2.9), 0.22, 0.04, (PI/2, 0, 0)); box("Cintre_robe", c, (-2.5+i*0.5, -1.0, 2.2), (0.4, 0.1, 1.2))
    # couronne
    cyl("Couronne", "F2C94C", (0.2, -1.6, 1.95), 0.55, 0.3, v=10)
    for k in range(3):
        a = k*2*PI/3; cone("Couronne", "F2C94C", (0.2+0.5*math.cos(a), -1.6+0.5*math.sin(a), 2.3), 0.12, 0.02, 0.4, v=5)
    # aura
    torus("Aura", "7BE8FF", (1.5, -1.2, 2.6), 0.6, 0.1, (PI/2, 0, 0)); torus("Aura", "FF8AD8", (1.5, -1.2, 2.6), 0.4, 0.07, (PI/2, 0, 0))
    # medailles
    for i, c in enumerate(("F2C94C", "C8CDD2", "C9793A")):
        cyl("Medaille", c, (2.3, -1.2-i*0.6+0.4, 1.8), 0.28, 0.08, (PI/2, 0, 0), v=10) if False else cyl("Medaille", c, (-0.9+i*0.6, -2.5, 1.8), 0.25, 0.08, (PI/2, 0, 0), v=10)
    # pose : mini mannequin
    cyl("Socle_pose", "F5EBD7", (2.5, -2.2, 1.85), 0.45, 0.2, v=10); box("Pose", "B58CFF", (2.5, -2.2, 2.4), (0.3, 0.3, 0.9))
    box("Pose_bras", "B58CFF", (2.5, -2.2, 2.7), (1.0, 0.18, 0.18), (0, 0.5, 0))
reg("vendor_cosmetics", cosm)

json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
for k, v in M.items(): print(k, v["parts"], v["faces"], v["size"], v["min"])
