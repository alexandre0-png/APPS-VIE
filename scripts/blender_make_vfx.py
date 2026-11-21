import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
def reg(fn):
    reset(); fn(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx")); M[fn.__name__] = {"parts": n, "faces": t}
W="FFFFFF"
def vfx_cercle_runique():
    cyl("Disque",W,(0,0,0.02),6.0,0.04,v=48)
    for r,w in ((5.6,0.12),(4.4,0.08),(3.0,0.1)): torus("Anneau",W,(0,0,0.06),r,w)
    for i in range(24):
        a=i*math.pi/12; box("Rune",W,(5.0*math.cos(a),5.0*math.sin(a),0.07),(0.5,0.12,0.04),(0,0,a+math.pi/2))
    for i in range(6):
        a=i*math.pi/3; box("Etoile",W,(0,0,0.08),(7.0,0.1,0.03),(0,0,a))
def vfx_ailes():
    for s in (-1,1):
        for i in range(7):
            L=4.0-0.35*i; box("Plume",W,(s*(1.3+0.9*i),0.1*i,2.2+0.35*(6-i)*0.5+0.0),(L*0.5,0.12,0.5),(0,0,s*(0.5+0.07*i)))
        box("Os",W,(s*2.6,0,3.0),(0.12,0.12,3.5),(0,0,s*1.1))
def vfx_halo(): torus("Halo",W,(0,0,0.5),2.0,0.14); torus("Halo2",W,(0,0,0.5),1.6,0.05)
def vfx_rayons():
    for i in range(16):
        a=i*math.pi/8; cone("Rayon",W,(3.0*math.cos(a),3.0*math.sin(a),0.1),0.12,0.0,6.0,(0,math.pi/2,a),4)
def vfx_etoile():
    for i in range(8):
        a=i*math.pi/4; cone("Pointe",W,(1.2*math.cos(a),0,1.2*math.sin(a)),0.35,0.0,2.4 if i%2==0 else 1.4,(0,math.pi/2,0) if False else (math.pi/2 if False else 0,0,0),4) if False else cone("Pointe",W,(1.2*math.cos(a),0,1.2*math.sin(a)),0.3,0.0,2.4 if i%2==0 else 1.4,(math.pi/2,0,0) if False else (0,a+math.pi/2,0),4)
    sph("Coeur",W,(0,0,0),0.5)
def vfx_cristaux():
    for i,(x,y,h,r) in enumerate([(0,0,3.0,0.4),(0.8,0.3,2.0,0.3),(-0.7,0.4,2.2,0.32),(0.3,-0.7,1.5,0.25),(-0.4,-0.6,1.8,0.28),(1.1,-0.4,1.2,0.22)]):
        cone("Cristal",W,(x,y,h/2),r,0.0,h,(0.1*i,0.08*(i%3),0),5); cyl("Base",W,(x,y,0.1),r*1.05,0.2,v=5)
def vfx_onde():
    torus("Onde",W,(0,0,0.05),3.0,0.12); torus("Onde2",W,(0,0,0.05),2.5,0.06); cyl("Disque",W,(0,0,0.02),3.1,0.03,v=40)
def vfx_torii():
    box("Poteau",W,(-3.0,0,3.0),(0.5,0.5,6.0)); box("Poteau",W,(3.0,0,3.0),(0.5,0.5,6.0)); box("Linteau",W,(0,0,5.6),(8.4,0.5,0.5)); box("Traverse",W,(0,0,4.6),(7.0,0.4,0.3)); box("Toit",W,(0,0,6.1),(9.4,0.7,0.35),(0,0,0))
def vfx_spirale():
    for i in range(36):
        a=i*0.5; box("Marche",W,(1.2*math.cos(a),1.2*math.sin(a),i*0.14),(0.5,0.18,0.12),(0,0,a))
def vfx_pilier_lumiere(): cyl("Pilier",W,(0,0,6),0.8,12,v=16); cyl("Base",W,(0,0,0.1),1.6,0.2,v=24); torus("Anneau",W,(0,0,0.3),1.4,0.08)
def vfx_etincelles():
    for i in range(24):
        a=i*2.4; r=1+ (i%5)*0.5; sph("Etincelle",W,(r*math.cos(a),r*math.sin(a),0.3+(i%7)*0.35),0.07+0.02*(i%3),seg=6,rings=4)
def vfx_cone_lumiere(): cone("Faisceau",W,(0,0,5),3.0,0.15,10,v=20)
def vfx_bouclier():
    sph("Dome",W,(0,0,0),3.0,(1,1,0.9),18,10); torus("Bord",W,(0,0,0),3.0,0.1)
for name, fn in list(globals().items()):
    if callable(fn) and getattr(fn,"__module__","")=="__main__" and name.startswith("vfx_"): reg(fn)
json.dump(M, open(os.path.join(OUT,"manifest.json"),"w"), indent=1); print("OK", len(M), {k:v["faces"] for k,v in M.items()})
