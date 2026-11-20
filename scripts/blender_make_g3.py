import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
def reg(fn):
    reset(); fn(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx")); M[fn.__name__] = {"parts": n, "faces": t}
def g_plinthe(): box("Bois","4A3220",(0,0,0.06),(4,0.7,0.12)); box("Bois","4A3220",(0,0.1,0.19),(4,0.45,0.13))
def g_moulure(): box("Platre","D8D0C0",(0,0.1,0.15),(4,0.5,0.3)); box("Platre","D8D0C0",(0,-0.05,0.38),(4,0.3,0.24),(0.0,0,0))
def g_fenetre_rideaux():
    c="5A4030"; v="A8C0C8"; r="7A3A3A"
    box("Cadre",c,(0,0,2.5),(3,0.6,0.2)); box("Cadre",c,(0,0,0.1),(3.2,0.8,0.2)); [box("Cadre",c,(x,0,2.5),(0.2,0.5,4.8)) for x in (-1.4,1.4)]; box("Vitre",v,(0,0,2.6),(2.6,0.06,4.4))
    [box("Cadre",c,(0,0,2.6+i*1.4),(2.6,0.1,0.1)) for i in (-1,0,1)]; box("Cadre",c,(0,0,2.6),(0.1,0.1,4.4)); box("Cadre",c,(-0.65,0,2.6),(0.1,0.1,4.4)); box("Cadre",c,(0.65,0,2.6),(0.1,0.1,4.4))
    [box("Rideau",r,(x,-0.35,2.6),(0.7,0.2,4.6)) for x in (-1.9,1.9)]; box("Tringle",c,(0,-0.35,4.95),(4.4,0.1,0.1))
def g_fenetre_ronde():
    torus("Cadre","5A4A3A",(0,0,1.5),1.4,0.15,(math.pi/2,0,0)); cyl("Vitre","A8C0C8",(0,0,1.5),1.35,0.05,(math.pi/2,0,0),24); box("Cadre","5A4A3A",(0,0,1.5),(2.8,0.1,0.1)); box("Cadre","5A4A3A",(0,0,1.5),(0.1,0.1,2.8)); box("Fissure","DADADA",(0.3,-0.04,1.7),(1.0,0.01,0.03),(0,0.6,0))
def g_balustrade():
    b="4A3220"; box("Main",b,(0,0,3.3),(4,0.35,0.25)); box("Lisse",b,(0,0,0.3),(4,0.3,0.2)); [cyl("Barreau",b,(-1.5+i*0.6,0,1.8),0.07,3.0,v=8) for i in range(6)]; cyl("Poteau",b,(-2,0,1.75),0.2,3.5,v=8); sph("Boule",b,(-2,0,3.6),0.25)
def g_marche(): box("Bois","6B4A2F",(0,0,0.5),(4,1.3,0.7)); box("Nez","8A7A50",(0,-0.66,0.85),(4,0.12,0.12)); box("Contre","5B3F26",(0,-0.64,0.25),(4,0.04,0.5))
def g_encadrement():
    b="4A3220"; [box("Chambranle",b,(x,0,4.5),(0.5,0.8,9)) for x in (-2.25,2.25)]; box("Linteau",b,(0,0,8.7),(5,0.8,0.6)); box("Corniche",b,(0,0.1,9.1),(5.4,0.9,0.25)); [box("Moulure",b,(x,-0.38,4.5),(0.12,0.1,8.2)) for x in (-2.0,2.0)]
def g_applique(): cyl("Laiton","B8A060",(0,0.3,0.75),0.12,0.3,(math.pi/2,0,0),8); box("Laiton","B8A060",(0,0.35,0.9),(0.18,0.1,1.2)); cone("Verre","E8D8A8",(0,0,1.0),0.35,0.15,0.9,v=8); cyl("Laiton","B8A060",(0,0,0.5),0.18,0.1,v=8)
def g_soupirail(): box("Pierre","6A6660",(0,0,0.75),(3,0.6,1.5)); box("Pierre","5A5650",(0,-0.05,0.75),(2.4,0.7,1.0)) if False else None; [box("Fonte","2A2A2A",(-1.0+i*0.5,-0.32,0.75),(0.12,0.1,1.2)) for i in range(5)]; box("Fonte","2A2A2A",(0,-0.32,0.75),(2.4,0.1,0.12)); box("Fonte","2A2A2A",(0,-0.32,1.2),(2.4,0.1,0.12))
def g_radiateur():
    f="6A6A64"; [box("Fonte",f,(-1.5+i*0.5,0,1.2),(0.35,0.5,2.0)) for i in range(7)]; box("Fonte",f,(0,0,2.3),(3.8,0.5,0.15)); box("Fonte",f,(0,0,0.2),(3.8,0.5,0.15)); [cyl("Fonte",f,(x,0.1,0.1),0.1,0.2,v=6) for x in (-1.7,1.7)]
for name, fn in list(globals().items()):
    if callable(fn) and getattr(fn,"__module__","")=="__main__" and name.startswith("g_"): reg(fn)
json.dump(M, open(os.path.join(OUT,"manifest.json"),"w"), indent=1); print("OK", len(M))
