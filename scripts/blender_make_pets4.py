import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
def reg(fn):
    reset(); fn(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx")); M[fn.__name__] = {"parts": n, "faces": t}
def PetTigre():
    o="F08C28"; sph("Corps",o,(0,0,0.4),0.3,(0.85,1.5,1)); sph("Ventre","FFF1D6",(0,-0.02,0.3),0.22,(0.8,1.3,0.7)); sph("Tete",o,(0,-0.5,0.68),0.26)
    sph("Museau","FFF1D6",(0,-0.7,0.6),0.12,(1,0.8,0.8)); sph("Nez","2A1A1A",(0,-0.8,0.64),0.045)
    for s in (-1,1):
        sph("Oreille",o,(s*0.2,-0.45,0.92),0.09,(1,0.6,1)); sph("Oeil","FFD23F",(s*0.1,-0.7,0.76),0.05); sph("Oeil","1A1A1A",(s*0.1,-0.74,0.76),0.025)
        for fy in (-0.25,0.28): box("Patte",o,(s*0.17,fy,0.14),(0.12,0.12,0.28))
    for i,y in enumerate((-0.2,0.05,0.3)): box("Rayure","2A1A1A",(0,y,0.7-0.0*i),(0.52,0.07,0.04))
    box("RayureTete","2A1A1A",(0,-0.5,0.94),(0.05,0.1,0.03))
    cone("Queue",o,(0,0.55,0.5),0.06,0.04,0.7,(math.radians(-50),0,0),6); sph("BoutQueue","2A1A1A",(0,0.82,0.74),0.07)
def PetKraken():
    p="8C46BE"; sph("Tete",p,(0,0,0.75),0.42,(1,1,1.15)); sph("Ventre","B98AD8",(0,-0.1,0.6),0.3,(1,0.8,1))
    for s in (-1,1):
        sph("Oeil","FFFFFF",(s*0.17,-0.34,0.82),0.11); sph("Oeil","1A1A1A",(s*0.17,-0.43,0.82),0.055)
    for i in range(8):
        a=math.radians(i*45); x=math.cos(a)*0.28; y=math.sin(a)*0.28
        cone("Tentacule",p,(x*1.4,y*1.4,0.2),0.09,0.03,0.6,(math.radians(-25)*math.sin(a+1.57)*-1,math.radians(25)*math.cos(a+1.57),0),6)
        sph("Ventouse","B98AD8",(x*1.9,y*1.9,0.06),0.045)
    sph("Couronne","FFD23F",(0,0,1.18),0.09)
def PetCalmar():
    t="3CBEC8"; cone("Manteau",t,(0,0.1,0.8),0.34,0.04,0.9,(math.radians(-15),0,0),8); sph("Tete",t,(0,-0.2,0.6),0.26)
    for s in (-1,1):
        sph("Oeil","FFFFFF",(s*0.15,-0.4,0.66),0.1); sph("Oeil","1A1A1A",(s*0.15,-0.49,0.66),0.05)
        box("Nageoire","8FE6EE",(s*0.3,0.3,0.95),(0.04,0.3,0.3))
    for i in range(10):
        a=math.radians(i*36); x=math.cos(a)*0.17; y=math.sin(a)*0.17
        cone("Tentacule",t,(x,-0.2+y,0.25),0.05,0.015,0.55,(math.radians(8)*math.sin(a),0,0),5)
    for i in range(5): sph("Etoile","FFF6A0",(0,0.1+i*0.07,1.12-i*0.1),0.035)
def PetWyrm():
    b="5096FF"; sph("Corps",b,(0,0.1,0.45),0.3,(0.9,1.5,1)); sph("Tete",b,(0,-0.5,0.85),0.25,(1,1.2,0.9)); sph("Museau","8CC2FF",(0,-0.72,0.8),0.12,(1,1.1,0.8))
    for s in (-1,1):
        sph("Oeil","FFF6A0",(s*0.12,-0.64,0.93),0.06); cone("Corne","FFE08A",(s*0.12,-0.45,1.08),0.05,0.0,0.3,(math.radians(-25),0,0),4)
        box("Aile","BCDCFF",(s*0.5,0.15,0.9),(0.55,0.5,0.03)); box("AileOs","3A6ED8",(s*0.3,0.15,0.9),(0.4,0.04,0.04))
        box("Patte",b,(s*0.18,-0.05,0.14),(0.1,0.1,0.28))
    for i in range(6): sph("Anneau",b if i%2==0 else "8CC2FF",(0,0.45+i*0.17,0.4-i*0.03),0.2-i*0.025)
    for i in range(4): cone("Dos","FFE08A",(0,-0.1+i*0.2,0.78),0.05,0.0,0.15,v=4)
for fn in (PetTigre,PetKraken,PetCalmar,PetWyrm): reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1); print("OK", len(M), M)
