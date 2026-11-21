import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
def reg(fn):
    reset(); fn(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx")); M[fn.__name__] = {"parts": n, "faces": t}
# x = largeur, y = profondeur (devant = -y), z = hauteur, origine au centre du socle
def trunk(h, r0, r1, c="6E4C2E", x=0, y=0, lean=(0,0,0)):
    cone("Tronc", c, (x,y,h/2), r0, r1, h, lean, 8)
def tree_oak_a():
    trunk(5,0.9,0.55); cone("Racines","6E4C2E",(0,0,0.3),1.5,0.8,0.6,v=8)
    for (x,y,z,r) in ((0,0,8.2,3.4),(-2.1,0.5,6.6,2.5),(2.0,-0.4,6.9,2.6),(0.2,1.8,7.0,2.3),(-0.6,-1.8,7.4,2.2)): sph("Feuillage","4B8E45" if (x+y)>0 else "5CA052",(x,y,z),r,(1,1,0.85),seg=10,rings=6)
    sph("Feuillage","78B85A",(0.6,-0.8,9.6),1.7,seg=9,rings=5)
def tree_oak_b():
    trunk(4.2,0.8,0.5,"7A5430"); 
    for (x,y,z,r) in ((0,0,7.0,3.0),(-1.8,0.3,5.6,2.0),(1.9,0.2,5.8,2.2)): sph("Feuillage","3F7F3F",(x,y,z),r,(1,1,0.9),seg=10,rings=6)
    sph("Feuillage","5CA052",(0.4,-0.6,8.3),1.6,seg=9,rings=5); sph("Pomme","D63A3A",(1.2,-2.2,5.2),0.25,seg=6,rings=4); sph("Pomme","D63A3A",(-1.4,-1.8,6.4),0.25,seg=6,rings=4)
def tree_birch():
    trunk(7,0.45,0.3,"E8E4D8"); [box("Ecorce","3A3A3A",(0,-0.4,z),(0.5,0.1,0.18)) for z in (1.2,2.8,4.4,5.6)]
    for (x,y,z,r) in ((0,0,8.0,2.1),(-1.1,0.3,6.6,1.5),(1.2,-0.3,6.9,1.6),(0,0.5,9.4,1.3)): sph("Feuillage","9CCB5A",(x,y,z),r,(1,1,1.15),seg=9,rings=5)
def tree_pine():
    trunk(3,0.55,0.4,"5A3E28")
    for i,(r,z) in enumerate(((3.0,3.0),(2.5,5.0),(2.0,6.8),(1.4,8.4))): cone("Branches","2F6B3A" if i%2 else "3A7F45",(0,0,z+1.0),r,0.15,2.4,v=9)
    cone("Branches","4B9A55",(0,0,10.4),0.7,0.0,1.4,v=7)
def tree_sakura():
    trunk(4.5,0.7,0.4,"5A3E28",lean=(0.08,0,0))
    for (x,y,z,r) in ((0,0,7.4,3.0),(-2.0,0.4,6.2,2.2),(2.0,-0.3,6.4,2.3),(0.3,1.6,6.6,2.0)): sph("Fleurs","F6A8C8" if (x>0) else "F9BFD6",(x,y,z),r,(1,1,0.85),seg=10,rings=6)
    for i in range(6): sph("Petale","FFD7E6",(1.2*math.cos(i*1.0),1.2*math.sin(i*1.0),0.08),0.22,(1,1,0.2),seg=6,rings=4)
def tree_round():
    trunk(3.5,0.6,0.4); sph("Feuillage","5CA052",(0,0,6.2),3.0,seg=10,rings=6); sph("Feuillage","78B85A",(-0.8,-0.9,7.3),1.6,seg=8,rings=5)
def path_straight():
    box("Terre","C4B494",(0,0,0.1),(8,8,0.2))
    for i,(x,y) in enumerate(((-2.4,-2.4),(0,-2.6),(2.4,-2.2),(-2.6,0),(-0.2,0.1),(2.5,0.2),(-2.3,2.4),(0.1,2.5),(2.5,2.3))): cyl("Pave","B3B0A4" if i%2 else "9E9C92",(x,y,0.28),1.05,0.2,v=8)
    [box("Bordure","8E93A0",(x,y,0.3),(8,0.5,0.36)) for x,y in ((0,3.85),(0,-3.85))]
def path_curve():
    box("Terre","C4B494",(0,0,0.1),(8,8,0.2))
    for i in range(7):
        a=math.radians(i*15); cyl("Pave","B3B0A4" if i%2 else "9E9C92",(-4+7.2*math.cos(a)*0.55+0.0,-4+7.2*math.sin(a)*0.55+0.0,0.28),1.0,0.2,v=8)
    for i in range(7): a=math.radians(i*15); box("Bordure","8E93A0",(-4+7.8*math.cos(a)*0.55*1.18,-4+7.8*math.sin(a)*0.55*1.18,0.3),(1.2,0.5,0.36),(0,0,a+math.pi/2))
def path_stones():
    for i,(x,y,r) in enumerate(((0,-3,0.9),(0.5,-1.1,1.0),(-0.4,1.0,0.95),(0.3,3.0,1.0))): sph("Dalle","B3B0A4" if i%2 else "9E9C92",(x,y,0.15),r,(1,1,0.25),seg=9,rings=5)
    for (x,y) in ((-1.6,-2,),(1.8,0.2),(-1.8,2.2)): sph("Touffe","5CA052",(x,y,0.15),0.35,(1,1,0.6),seg=6,rings=4)
def egg_dome():
    cyl("Socle","8E93A0",(0,0,0.25),2.2,0.5,v=14); cyl("Socle","6E7280",(0,0,0.65),1.8,0.3,v=14); cyl("Coussin","C0504A",(0,0,0.95),1.3,0.3,v=12)
    sph("Dome_Verre","BFE6FF",(0,0,2.4),1.75,seg=14,rings=8); torus("Anneau_Or","E8B923",(0,0,0.9),1.75,0.1)
    [cyl("Pilier_Pierre","8E93A0",(1.9*math.cos(i*math.pi/2+0.78),1.9*math.sin(i*math.pi/2+0.78),1.0),0.2,2.0,v=6) for i in range(4)]
def egg_nest_fence():
    cyl("Paille","D9B65A",(0,0,0.3),2.4,0.6,v=14); torus("Nid","B58A3C",(0,0,0.6),2.2,0.4); torus("Nid","8A6A2E",(0,0,0.5),2.5,0.3)
    for i in range(12):
        a=i*math.pi/6; x=3.2*math.cos(a); y=3.2*math.sin(a); box("Piquet","96622C",(x,y,1.0),(0.35,0.35,2.0),(0,0,a)); cone("Pointe","96622C",(x,y,2.2),0.28,0.0,0.4,v=4)
    torus("Lisse","6E4C2E",(0,0,1.4),3.2,0.1)
def egg_cage():
    box("Socle","5E4630",(0,0,0.2),(4.6,4.6,0.4))
    for i in range(10):
        a=i*2*math.pi/10; cyl("Barreau_Fer","3A3A3A",(1.9*math.cos(a),1.9*math.sin(a),1.9),0.1,3.0,v=6)
    torus("Anneau_Fer","4A4A4A",(0,0,3.4),1.9,0.1); torus("Anneau_Fer","4A4A4A",(0,0,0.6),1.9,0.1); sph("Toit_Fer","4A4A4A",(0,0,3.45),1.9,(1,1,0.3),seg=10,rings=5); torus("Anneau_Fer","8A7A50",(0,0,4.0),0.3,0.07,(math.pi/2,0,0))
def egg_shield():
    cyl("Socle","6E7280",(0,0,0.2),2.6,0.4,v=16)
    for i in range(6):
        a=i*math.pi/3; box("Bouclier_Cristal","7FD6FF",(2.0*math.cos(a),2.0*math.sin(a),1.6),(0.7,0.35,3.0),(0.0,0.25,a+math.pi/2)); 
    sph("Aura","BFF0FF",(0,0,1.5),1.1,(1,1,1.2),seg=10,rings=6)
for fn in [globals()[k] for k in list(globals()) if k.startswith(("tree_","path_","egg_"))]: reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1); print("OK", len(M), {k:(v["parts"],v["faces"]) for k,v in M.items()})
