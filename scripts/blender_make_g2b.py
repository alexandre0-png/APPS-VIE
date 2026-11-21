import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
def reg(fn):
    reset(); fn(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx")); M[fn.__name__] = {"parts": n, "faces": t}
# x = largeur, y = profondeur (devant = -y), z = hauteur. Noms de pièces : métal seulement pour Fer/Laiton/Chrome/Poignée/Cadenas.
def g_cage_enfant():
    f="3A3A3A"; box("Sol_Planches","5E4630",(0,0,0.15),(10,8,0.3))
    for x in [i-4.5 for i in range(10)]:
        for y in (-3.9,3.9): box("Barreau_Fer",f,(x+0.0,y,2.8),(0.18,0.18,4.6))
    for y in [i-3.0 for i in range(7)]:
        for x in (-4.9,4.9): box("Barreau_Fer",f,(x,y,2.8),(0.18,0.18,4.6))
    for z in (0.5,2.5,4.8): box("Traverse_Fer",f,(0,-3.9,z),(10,0.2,0.2)); box("Traverse_Fer",f,(0,3.9,z),(10,0.2,0.2)); box("Traverse_Fer",f,(-4.9,0,z),(0.2,8,0.2)); box("Traverse_Fer",f,(4.9,0,z),(0.2,8,0.2))
    box("Toit_Fer","2E2E2E",(0,0,4.9),(10.2,8.2,0.2))
    box("Porte_Fer","444444",(0,-4.0,2.4),(2.6,0.15,4.2)); box("Cadenas_Fer","5A5A5A",(1.0,-4.2,2.3),(0.6,0.3,0.7)); torus("Anneau_Fer","5A5A5A",(1.0,-4.2,2.8),0.22,0.06,(math.pi/2,0,0))
    box("Plaque_Laiton","8A7A50",(-2.8,-4.1,2.2),(1.2,0.1,0.6))
def g_matelas_enfant():
    box("Matelas","B8AE98",(0,0,0.25),(4,4,0.5)); box("Couverture","6A4A3A",(0,0.9,0.55),(3.6,1.6,0.2)); cyl("Couverture_Rouleau","6A4A3A",(0,-1.2,0.65),0.3,3.4,(0,math.pi/2,0),8); box("Oreiller","D8D0B8",(0,1.6,0.65),(1.8,1.0,0.4))
def g_chaine_cave():
    for i in range(8): torus("Maillon_Fer","3A3A3A",(0,0,0.18+i*0.36),0.14,0.045,(math.pi/2 if i%2==0 else 0,0,math.pi/2 if i%2 else 0))
    torus("Anneau_Fer","4A4A4A",(0,0,3.0),0.16,0.06,(math.pi/2,0,0))
def g_chevet():
    b="5A4030"; box("Plateau",b,(0,0,1.9),(2,2,0.15)); box("Caisson",b,(0,0,1.35),(1.8,1.8,0.95)); box("Tiroir","4A3020",(0,-0.92,1.4),(1.5,0.06,0.6)); sph("Poignee_Laiton","B8A060",(0,-1.0,1.4),0.09); [box("Pied",b,(x,y,0.45),(0.14,0.14,0.9)) for x in (-0.8,0.8) for y in (-0.8,0.8)]
def g_table_basse():
    b="5A3E28"; box("Plateau",b,(0,0,1.3),(10,6,0.3)); box("Etagere",b,(0,0,0.45),(9,5,0.2)); [box("Pied",b,(x,y,0.65),(0.4,0.4,1.3)) for x in (-4.5,4.5) for y in (-2.6,2.6)]
def g_meuble_tv():
    b="4A3220"; box("Dessus",b,(0,0,2.35),(10,3.5,0.3)); box("Caisson",b,(0,0,1.3),(9.6,3.3,1.9)); [box("Porte","5A4030",(x,-1.68,1.3),(4.5,0.08,1.6)) for x in (-2.4,2.4)]; [box("Poignee_Laiton","B8A060",(x,-1.78,1.3),(0.1,0.1,0.7)) for x in (-0.3,0.3)]; [box("Pied",b,(x,y,0.15),(0.4,0.4,0.3)) for x in (-4.6,4.6) for y in (-1.4,1.4)]
def g_plan_travail():
    box("Plan","C8C4B0",(0,0,2.9),(11,1.8,0.2)); box("Facade","6A5A48",(0,0,1.4),(10.6,1.6,2.8)); [box("Porte","7A6A58",(x,-0.82,1.4),(2.4,0.06,2.4)) for x in (-3.9,-1.3,1.3,3.9)]; box("Evier_Chrome","B0B0B0",(2.5,0,3.0),(2.6,1.2,0.12)); cyl("Robinet_Chrome","B0B0B0",(2.5,0.7,3.5),0.08,1.0,v=6); box("Bec_Chrome","B0B0B0",(2.5,0.3,3.95),(0.12,0.9,0.12))
def g_penderie():
    b="4A3220"; box("Corps",b,(0,0,3.5),(2,2,7)); box("Porte","5A4030",(0,-1.02,3.5),(1.7,0.06,6.4)); sph("Poignee_Laiton","B8A060",(0.6,-1.1,3.5),0.1); box("Corniche",b,(0,0,7.0),(2.2,2.2,0.2)); box("Socle",b,(0,0,0.1),(2.2,2.2,0.2))
def g_gueridon():
    b="5A3E28"; cyl("Plateau",b,(0,0,0.9),2.0,0.12,v=16); cyl("Pied",b,(0,0,0.5),0.25,0.8,v=8); cyl("Base",b,(0,0,0.08),1.0,0.16,v=12)
def g_banc():
    b="6B4A2F"; box("Assise",b,(0,0,1.1),(8,2,0.25)); box("Dossier",b,(0,0.85,1.6),(8,0.2,0.8)); [box("Pied",b,(x,y,0.5),(0.3,0.3,1.0)) for x in (-3.7,3.7) for y in (-0.8,0.8)]
def g_bidon():
    cyl("Bidon_Fer","5A4A3A",(0,0,1.4),1.6,2.8,v=14); [torus("Cercle_Fer","4A3A2A",(0,0,z),1.62,0.07) for z in (0.4,1.4,2.4)]; cyl("Bouchon_Fer","3A3A3A",(0.5,0.4,2.95),0.3,0.2,v=8)
def g_coffre_cave():
    f="4A4A4A"; box("Fer",f,(0,0,1.0),(6,6,2)); box("Couvercle_Fer","555555",(0,0,2.2),(6.1,6.1,0.5)); sph("Dome_Fer","555555",(0,0,2.4),2.8,(1,1,0.25)); [box("Rivets_Fer","6A6A6A",(x,-3.04,z),(0.2,0.1,0.2)) for x in (-2.6,2.6) for z in (0.4,1.6)]; box("Serrure_Fer","6A6A6A",(0,-3.1,1.9),(0.8,0.15,0.8))
def g_buffet():
    b="4A3220"; box("Corps",b,(0,0,2.5),(5,5,5)); box("Dessus",b,(0,0,5.05),(5.4,5.4,0.2)); [box("Porte","5A4030",(x,-2.54,2.7),(2.3,0.08,4.2)) for x in (-1.25,1.25)]; [box("Poignee_Laiton","B8A060",(x,-2.65,2.7),(0.1,0.1,0.8)) for x in (-0.2,0.2)]; box("Corniche",b,(0,0,5.3),(5.2,5.2,0.2)); box("Socle",b,(0,0,0.2),(5.4,5.4,0.4))
for fn in (g_cage_enfant,g_matelas_enfant,g_chaine_cave,g_chevet,g_table_basse,g_meuble_tv,g_plan_travail,g_penderie,g_gueridon,g_banc,g_bidon,g_coffre_cave,g_buffet): reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1); print("OK", len(M), {k:v["faces"] for k,v in M.items()})
