import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
def reg(fn):
    reset(); fn(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx")); M[fn.__name__] = {"parts": n, "faces": t}
# x = largeur, y = profondeur (devant = -y), z = hauteur. Métal seulement via Fer/Laiton/Chrome/Poignée.
def m_buffet_bas():
    b="5A4030"; b2="4A3220"
    box("Corps",b,(0,0,2.0),(10,3,3.2)); box("Dessus","6B4A2F",(0,0,3.75),(10.4,3.4,0.3)); [box("Tiroir",b2,(x,-1.52,3.1),(2.2,0.08,0.7)) for x in (-3.5,-1.2,1.2,3.5)]; [box("Porte",b2,(x,-1.52,1.7),(4.4,0.08,2.2)) for x in (-2.4,2.4)]
    [sph("Poignee_Laiton","B8A060",(x,-1.62,3.1),0.1) for x in (-3.5,-1.2,1.2,3.5)]; [sph("Poignee_Laiton","B8A060",(x,-1.62,1.9),0.12) for x in (-0.4,0.4)]; [box("Pied",b2,(x,y,0.2),(0.5,0.5,0.4)) for x in (-4.7,4.7) for y in (-1.2,1.2)]
def m_placard_haut():
    b="6A5A48"; box("Corps",b,(0,0,1.5),(10,1.6,3)); [box("Porte","7A6A58",(x,-0.82,1.5),(2.3,0.08,2.7)) for x in (-3.8,-1.3,1.3,3.8)]; [box("Poignee_Laiton","B8A060",(x+0.9*s,-0.9,1.5),(0.08,0.08,0.7)) for x in (-3.8,-1.3,1.3,3.8) for s in (1,)]; box("Corniche","5A4A38",(0,0,3.05),(10.2,1.7,0.2))
def m_fauteuil_osier():
    for i in range(16): a=i*2*math.pi/16; box("Osier","B8914F" if i%2 else "A8813F",(2.0*math.cos(a),2.0*math.sin(a),1.6),(0.3,0.3,2.4),(0,0,a))
    torus("Osier","A8813F",(0,0,0.4),2.0,0.18); torus("Osier","A8813F",(0,0,2.9),2.0,0.18); torus("Osier","A8813F",(0,0,1.6),2.0,0.12); cyl("Coussin","D8C8A0",(0,0,0.9),1.6,0.5,v=14); sph("Oreiller","6A8A9A",(0.3,1.2,1.9),0.9,(1,0.5,1.1),seg=9,rings=5); [cyl("Pied","5A3E28",(x,y,0.15),0.2,0.3,v=6) for x in (-1.2,1.2) for y in (-1.2,1.2)]
def m_table_ronde_pied():
    b="5A3E28"; cyl("Plateau",b,(0,0,2.6),3.4,0.3,v=20); cyl("Pied",b,(0,0,1.4),0.35,2.4,v=8); [box("Griffe",b,(1.1*math.cos(a),1.1*math.sin(a),0.3),(1.6,0.4,0.4),(0,0,a)) for a in (0,2.09,4.18)]; sph("Noeud",b,(0,0,0.9),0.5,seg=8,rings=5)
def m_chaise_accoudoirs():
    b="5A3E28"; box("Assise","7A2E2E",(0,0,1.3),(1.9,1.9,0.25)); [box("Pied",b,(x,y,0.6),(0.2,0.2,1.2)) for x in (-0.8,0.8) for y in (-0.8,0.8)]; [box("Dossier",b,(x,0.85,2.2),(0.18,0.18,1.8)) for x in (-0.8,0.8)]; box("Dossier",b,(0,0.85,3.0),(1.8,0.18,0.3)); [box("Accoudoir",b,(x,0,1.9),(0.18,1.5,0.18)) for x in (-0.9,0.9)]; [box("Barreau",b,(x,0.85,2.2),(0.1,0.1,1.2)) for x in (-0.3,0.3)]
def m_suspension():
    cyl("Tige_Fer","3A3A3A",(0,0,2.2),0.06,3.6,v=5); cone("Abat_jour","6A5A3A",(0,0,0.9),1.4,0.3,1.2,v=14); sph("Ampoule_Neon","FFE9A8",(0,0,0.55),0.28,seg=8,rings=5); cyl("Culot_Fer","3A3A3A",(0,0,1.55),0.3,0.3,v=8)
def m_chandeliers():
    for (x,h,r) in ((-0.8,3.2,0.5),(0.2,2.4,0.55),(1.0,3.6,0.45)):
        cyl("Base_Laiton","B8A060",(x,0,0.1),r,0.2,v=10); cyl("Tige_Laiton","B8A060",(x,0,h/2),0.14,h,v=8); sph("Noeud_Laiton","B8A060",(x,0,h*0.4),0.3,seg=8,rings=5); sph("Noeud_Laiton","B8A060",(x,0,h*0.72),0.26,seg=8,rings=5); cyl("Bougie","EADBB8",(x,0,h+0.4),0.17,0.8,v=8); sph("Flamme","FFD27A",(x,0,h+1.0),0.14,(1,1,1.6),seg=6,rings=4)
def m_renard_statuette():
    c="C8C0B0"; sph("Corps",c,(0,0.2,0.6),0.55,(0.7,1.5,0.9),seg=9,rings=6); sph("Tete",c,(0,-0.55,1.0),0.4,(1,0.9,0.9),seg=9,rings=6); [cone("Oreille",c,(s*0.2,-0.5,1.4),0.12,0.0,0.4,v=4) for s in (-1,1)]; cone("Museau",c,(0,-0.95,0.95),0.18,0.04,0.45,(math.pi/2,0,0),6); cone("Queue",c,(0,1.1,0.9),0.3,0.06,1.4,(math.radians(-60),0,0),8); [box("Patte",c,(s*0.2,y,0.12),(0.12,0.12,0.24)) for s in (-1,1) for y in (-0.1,0.5)]
def m_livres():
    for i,(h,c) in enumerate(((1.4,"7A2E2E"),(1.6,"3F5F7A"),(1.3,"5A7A3F"),(1.7,"7A5A2E"),(1.2,"4A3A6A"))): box("Livre",c,(-1.0+i*0.5,0,h/2),(0.42,1.0,h))
    box("Livre","6A4A3A",(1.5,0,0.2),(0.9,1.1,0.4),(0,0,0.3)); box("Livre","8A6A4A",(1.5,0,0.55),(0.8,1.0,0.3),(0,0,-0.2))
def m_tabouret_bar():
    b="5A3E28"; box("Assise","7A2E2E",(0,0,3.0),(1.5,1.5,0.3)); [box("Pied",b,(x,y,1.4),(0.18,0.18,2.8)) for x in (-0.6,0.6) for y in (-0.6,0.6)]; torus("Anneau_Fer","5A5A5A",(0,0,1.2),0.7,0.06); box("Dossier",b,(0,0.7,3.7),(1.4,0.15,1.0))
def m_gueridon_lampe():
    b="5A3E28"; cyl("Plateau",b,(0,0,2.4),1.2,0.15,v=14); [cyl("Pied",b,(0.5*math.cos(a),0.5*math.sin(a),1.2),0.08,2.4,(0.0,0,0),6) for a in (0,2.09,4.18)]; cyl("Pied_bas",b,(0,0,0.5),0.8,0.1,v=10)
    cyl("Pied_lampe","6A8A9A",(0,0,3.0),0.3,1.0,v=10); sph("Pied_lampe","6A8A9A",(0,0,2.9),0.45,(1,1,1.2),seg=9,rings=5); cone("Abat_jour","D8C8A0",(0,0,3.9),0.75,0.4,0.9,v=12)
for fn in [globals()[k] for k in list(globals()) if k.startswith("m_")]: reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1); print("OK", len(M), {k:(v["parts"],v["faces"]) for k,v in M.items()})
