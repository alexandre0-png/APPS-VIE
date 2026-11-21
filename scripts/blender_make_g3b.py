import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
def reg(fn):
    reset(); fn(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx")); M[fn.__name__] = {"parts": n, "faces": t}
# x = largeur, y = profondeur (devant/entrée = -y), z = hauteur, origine au centre du socle
def flower(petal, name_cx=0):
    for i,(x,y,h) in enumerate(((0,0,0.9),(0.3,0.15,0.7),(-0.25,-0.1,0.6))):
        cyl("Tige","3E8E44",(x,y,h/2),0.04,h,v=5); sph("Petales",petal,(x,y,h+0.05),0.2,(1,1,0.45),seg=8,rings=5);
def deco_flower_a(): flower("FF789A")
def deco_flower_b(): flower("FFD23F")
def deco_flower_c(): flower("FFFFFF")
def deco_tuft():
    for i in range(7):
        a=i*0.9; c="5CA052" if i%2==0 else "4B8E45"; cone("Brins",c,(0.2*math.cos(a),0.2*math.sin(a),0.5),0.07,0.0,1.0+0.2*(i%3),(0.25*math.sin(a),-0.25*math.cos(a),0),4)
def deco_stone_flat(): sph("Pierre","8E93A0",(0,0,0.25),1.0,(1,0.8,0.25),seg=10,rings=6); sph("Mousse","5CA052",(0.15,0.05,0.42),0.55,(1,0.8,0.15),seg=8,rings=4)
def deco_stone_round(): sph("Pierre","8E93A0",(0,0,0.45),0.7,(1,0.9,0.7),seg=10,rings=6); sph("Mousse","5CA052",(-0.1,0.1,0.8),0.35,(1,1,0.35),seg=8,rings=4); sph("Pierre","7A7F8C",(0.8,0.3,0.2),0.3,seg=8,rings=5)
def deco_lantern():
    box("Pierre","8E93A0",(0,0,0.1),(0.8,0.8,0.2)); cyl("Pierre","8E93A0",(0,0,0.4),0.18,0.4,v=8); box("Pierre","8E93A0",(0,0,0.7),(0.6,0.6,0.1)); sph("Flamme","FFE9A8",(0,0,0.82),0.17,seg=8,rings=5); cone("Pierre","8E93A0",(0,0,1.05),0.45,0.0,0.3,v=4)
def deco_sign_stars():
    box("Poteau","96622C",(0,0,2.0),(0.4,0.4,4.0)); box("Planche","96622C",(0,-0.05,4.0),(3.0,0.25,1.2))
    for i in range(5): sph("Etoile%d"%(i+1),"FFCD46",(-1.12+i*0.56,-0.22,4.0),0.2,(1,0.25,1),seg=8,rings=5)
def layers(L,W,H,rock="8E93A0",rock2="6E7280",grass="5CA052",dirt="C4B494",tilt=True):
    n=4
    for i in range(n): box("Roche",rock if i%2==0 else rock2,(0,0,(H-0.6)*(i+0.5)/n),(L-i*0.0,W,(H-0.6)/n+0.02))
    box("Terre",dirt,(0,0,H-0.55),(L,W,0.1)); box("Herbe",grass,(0,0,H-0.25),(L,W,0.5))
def terrain_cliff_a(): layers(16,6,8); [box("Herbe","4B8E45",(x,-2.6,7.9),(1.5,1,0.4)) for x in (-6,-1,5)]; [sph("Roche","6E7280",(x,-3.1,1.5),0.8,(1,0.5,0.8),seg=8,rings=5) for x in (-7,3)]
def terrain_cliff_b(): layers(16,6,8,"6E7280","8E93A0"); [box("Herbe","4B8E45",(x,2.6,7.9),(1.8,1,0.4)) for x in (-5,2,6.5)]; sph("Roche","8E93A0",(0,-3.2,1.2),0.9,(1.3,0.5,0.7),seg=8,rings=5)
def terrain_cliff_corner():
    for i in range(4): box("Roche","8E93A0" if i%2==0 else "6E7280",(0,0,1.7*(i+0.5)),(12,12,1.72))
    box("Terre","C4B494",(0,0,7.45),(12,12,0.1)); box("Herbe","5CA052",(0,0,7.75),(12,12,0.5)); [sph("Roche","6E7280",(5.5,-5.5,z),0.8,(1,1,0.7),seg=8,rings=5) for z in (1.0,3.4)]
def terrain_stairs():
    for i in range(8):
        box("Marches","C4B494" if i%2==0 else "8E93A0",(0,i*1.5-5.25,(i+0.5)),(8,1.5,1.0))
    box("Marches","6E7280",(-4.1,0,3.5),(0.25,12,7)); box("Marches","6E7280",(4.1,0,3.5),(0.25,12,7))
def terrain_waterfall():
    box("Roche","8E93A0",(0,2.2,5),(8,1.6,10)); box("Roche","6E7280",(-3.9,0.2,5),(0.6,2.2,10)); box("Roche","6E7280",(3.9,0.2,5),(0.6,2.2,10))
    box("Eau","3C96DC",(0,0.9,5.2),(6.4,0.5,9.4)); [box("Eau","6CB6F0",(x,0.6,5.5),(0.6,0.15,8.5)) for x in (-2,0.6,2.4)]; sph("Ecume","FFFFFF",(0,-0.3,0.5),1.8,(1.8,0.7,0.35),seg=10,rings=6)
def terrain_islet():
    cyl("Roche","8E93A0",(0,0,1.0),12,2.0,v=18); cyl("Roche","6E7280",(0,0,0.4),12.2,0.8,v=18); cyl("Herbe","5CA052",(0,0,2.25),11.5,0.5,v=18)
    cyl("Tronc","6E4C2E",(2,2,4.5),0.6,4.0,v=6); sph("Herbe","4B8E45",(2,2,7.0),2.6,(1,1,0.9),seg=10,rings=6)
    sph("Roche","8E93A0",(-5,-3,3.0),1.2,(1,0.8,0.8),seg=8,rings=5); sph("Roche","6E7280",(-3.4,-4.4,2.7),0.7,seg=8,rings=5)
def props_bridge_rail():
    for i in range(13): box("Planches","96622C" if i%2 else "A87038",(i*1.38-8.28,0,1.0),(1.3,5.4,0.22))
    for s in (-1,1):
        box("Rampes","96622C",(0,s*2.8,2.3),(18,0.2,0.2)); box("Rampes","96622C",(0,s*2.8,1.7),(18,0.15,0.15))
        for x in (-8.5,0,8.5): box("Poteaux","6E4C2E",(x,s*2.8,1.6),(0.35,0.35,2.4))
    for s in (-1,1): box("Poteaux","6E4C2E",(0,s*2.2,0.6),(18,0.4,0.4))
def props_fence_corner():
    for p in ((0,0),(2.5,0),(0,2.5)): box("Poteaux","96622C",(p[0],p[1],1.5),(0.35,0.35,3.0))
    for z in (1.0,2.0): box("Lisses","96622C",(1.25,0,z),(2.5,0.2,0.22)); box("Lisses","96622C",(0,1.25,z),(0.2,2.5,0.22))
def props_fence_gate():
    for x in (-2,2): box("Poteaux","6E4C2E",(x,0,1.6),(0.4,0.4,3.2))
    for z in (0.8,1.6,2.4): box("Lisses","96622C",(0,0,z),(3.6,0.18,0.2))
    box("Lisses","96622C",(0,0,1.6),(0.18,0.18,2.0),(0,0,0)); box("Lisses","A87038",(-0.9,0,1.6),(0.16,0.16,2.4),(0,math.radians(35),0))
def hut(h, w, d, chim=True):
    s=h/7.0
    box("Murs","C9A66B",(0,0,1.6*s),(w,d,3.2*s)); 
    box("Toit","B04A3C",(-w*0.28,0,3.9*s),(w*0.62,d+0.9,0.35*s),(0,math.radians(-28),0)); box("Toit","B04A3C",(w*0.28,0,3.9*s),(w*0.62,d+0.9,0.35*s),(0,math.radians(28),0))
    box("Murs","C9A66B",(0,-d/2+0.05,3.6*s),(w*0.55,0.2,1.3*s)); box("Porte","6E4C2E",(0,-d/2-0.05,1.0*s),(1.2*s,0.15,2.0*s)); box("Fenetre_Verre","9CC8E8",(w*0.3,-d/2-0.04,1.9*s),(1.0*s,0.1,1.0*s)); box("Fenetre_Cadre","6E4C2E",(w*0.3,-d/2-0.07,1.9*s),(1.2*s,0.06,1.2*s))
    if chim: box("Cheminee","8E93A0",(w*0.3,d*0.25,4.6*s),(0.8*s,0.8*s,2.2*s))
def props_hut_small(): hut(7,6,5)
def props_hut_big(): hut(11,9,7); box("Murs","C9A66B",(5.5,0,1.4),(3.5,5,2.8)); box("Toit","B04A3C",(5.5,0,3.1),(4.1,5.6,0.35))
# --- niveaux de base : emprise 52x52 centrée, entrée -Y, bâtiment à l'arrière (+Y), avant libre
def fence_ring(c="96622C", n=10, z0=1.2):
    for i in range(n):
        x=-24+i*48/(n-1)
        box("Poteaux",c,(x,-24,1.5),(0.6,0.6,3)); box("Poteaux",c,(x,24,1.5),(0.6,0.6,3))
    box("Lisses",c,(0,24,2.0),(48,0.3,0.3)); box("Lisses",c,(-12.5,-24,2.0),(23,0.3,0.3)); box("Lisses",c,(12.5,-24,2.0),(23,0.3,0.3))
    for y in (-12,0,12): box("Poteaux",c,(-24,y,1.5),(0.6,0.6,3)); box("Poteaux",c,(24,y,1.5),(0.6,0.6,3))
    box("Lisses",c,(-24,0,2.0),(0.3,48,0.3)); box("Lisses",c,(24,0,2.0),(0.3,48,0.3))
def base_level1(): fence_ring(); [box("Paille","E2C878",(x,16,0.6),(3,2,1.2)) for x in (-8,-4,4,8)]; box("Abreuvoir","6E4C2E",(0,12,0.6),(6,1.6,1.2))
def base_level2(): fence_ring(); box("Murs","C9A66B",(0,16,2.0),(14,10,4)); box("Toit","B04A3C",(0,16,4.6),(15,11,0.6)); box("Porte","6E4C2E",(0,10.9,1.2),(2,0.2,2.4)); box("Fenetre_Cadre","6E4C2E",(4,10.9,2.4),(1.8,0.15,1.6))
def base_level3(): fence_ring("8A5A2C"); box("Murs","D9BC8A",(0,16,2.5),(18,12,5)); box("Toit","A89040",(-5,16,6.4),(10,13,0.8),(0,math.radians(-30),0)); box("Toit","A89040",(5,16,6.4),(10,13,0.8),(0,math.radians(30),0)); box("Porte","6E4C2E",(0,9.9,1.4),(2.4,0.2,2.8)); box("Cheminee","8E93A0",(6,18,8),(1.8,1.8,3)); [box("Fenetre_Cadre","6E4C2E",(x,9.9,3),(2,0.15,1.8)) for x in (-6,6)]
def base_level4(): box("Murs","E0CBA4",(0,16,3.5),(22,14,7)); box("Toit","B04A3C",(-6.5,16,8.4),(12,15.5,0.8),(0,math.radians(-30),0)); box("Toit","B04A3C",(6.5,16,8.4),(12,15.5,0.8),(0,math.radians(30),0)); box("Porte","6E4C2E",(0,8.9,1.6),(3,0.2,3.2)); [box("Fenetre_Verre","9CC8E8",(x,8.9,4.5),(2.2,0.15,2.2)) for x in (-7,7)]; [box("Fenetre_Verre","9CC8E8",(x,8.9,1.8),(2.2,0.15,2.2)) for x in (-7,7)]; box("Cheminee","8E93A0",(8,19,11),(2,2,4)); fence_ring("A87038",8); [sph("Buisson","4B8E45",(x,6,1),1.3) for x in (-8,8)]
def base_level5():
    box("Murs","EADBB8",(0,17,5),(26,14,10)); [box("Murs","EADBB8",(x,15,4),(9,12,8)) for x in (-17.5,17.5)]; box("Toit","6B3A2A",(-7,17,11.3),(14,16,0.8),(0,math.radians(-30),0)); box("Toit","6B3A2A",(7,17,11.3),(14,16,0.8),(0,math.radians(30),0)); [box("Toit","6B3A2A",(x,15,9),(10,13,0.7)) for x in (-17.5,17.5)]
    box("Porte","4A3220",(0,9.9,2.2),(4,0.25,4.4)); [box("Colonne","D8D0BC",(x,8.6,3),(0.9,0.9,6)) for x in (-3,3)]; [box("Fenetre_Verre","9CC8E8",(x,9.9,6.5),(2.4,0.15,2.6)) for x in (-9,-4.5,4.5,9)]; [box("Fenetre_Verre","9CC8E8",(x,9.1,4),(2,0.15,2.2)) for x in (-18,-14,14,18)]
def base_level6():
    box("Mur","8E93A0",(0,22,4),(40,2.4,8)); box("Mur","8E93A0",(-20,12,4),(2.4,20,8)); box("Mur","8E93A0",(20,12,4),(2.4,20,8)); [box("Creneaux","6E7280",(x,22,8.6),(1.6,2.6,1.2)) for x in range(-18,20,4)]
    for x in (-20,20): cyl("Tour","7A7F8C",(x,22,7),3.2,14,v=12); cone("Toit","A04830",(x,22,15.5),3.8,0.2,4,v=12)
    box("Donjon","8E93A0",(0,17,7),(12,10,14)); box("Creneaux","6E7280",(0,17,14.5),(12.6,10.6,1.2)); box("Porte","4A3220",(0,11.9,2.2),(4,0.3,4.4)); box("Drapeau","D63A3A",(0,17,17.5),(0.2,2.4,1.6)); cyl("Mat","785028",(0,17,16.5),0.12,5,v=5)
def base_level7():
    box("Mur","8E93A0",(0,23,5),(44,3,10)); box("Mur","8E93A0",(-22,12,5),(3,22,10)); box("Mur","8E93A0",(22,12,5),(3,22,10)); [box("Creneaux","6E7280",(x,23,10.7),(1.8,3.2,1.4)) for x in range(-20,22,4)]
    for x in (-22,22): cyl("Tour","7A7F8C",(x,23,9),4,18,v=14); cone("Toit","A04830",(x,23,20),4.8,0.2,5,v=14)
    for x in (-22,22): cyl("Tour","7A7F8C",(x,2,8),3.2,16,v=12); cone("Toit","A04830",(x,2,17.5),3.8,0.2,4.5,v=12)
    box("Donjon","8E93A0",(0,18,9),(16,12,18)); [box("Creneaux","6E7280",(x,18,18.7),(2,12.6,1.4)) for x in (-6,-2,2,6)]; cone("Toit","A04830",(0,18,21.5),9,0.3,5,v=4); box("Porte","4A3220",(0,11.9,3),(5,0.3,6)); box("Herse_Fer","3A3A42",(0,11.7,3),(4.4,0.15,5.4))
    for x in (-12,12): box("Drapeau","D63A3A",(x,23,14),(0.2,2.4,1.6)); cyl("Mat","785028",(x,23,13),0.12,5,v=5)
def base_level8():
    g="FFCD46"; w="F2E6C8"
    box("Mur",w,(0,23,5),(44,3,10)); box("Mur",w,(-22,12,5),(3,22,10)); box("Mur",w,(22,12,5),(3,22,10)); [box("Creneaux",g,(x,23,10.7),(1.8,3.2,1.4)) for x in range(-20,22,4)]
    for x in (-22,22): cyl("Tour",w,(x,23,10),4.2,20,v=16); cone("Toit",g,(x,23,22.5),5,0.2,6,v=16); sph("Pointe",g,(x,23,26),0.5)
    for x in (-22,22): cyl("Tour",w,(x,2,9),3.4,18,v=14); cone("Toit",g,(x,2,19.5),4,0.2,5,v=14)
    box("Donjon",w,(0,18,11),(18,14,22)); [box("Creneaux",g,(x,18,22.7),(2,14.6,1.4)) for x in (-7,-2.5,2.5,7)]; cone("Toit",g,(0,18,26),10.5,0.4,7,v=4); sph("Pointe",g,(0,18,30.2),0.7)
    box("Porte",g,(0,11.9,3.4),(5.2,0.3,6.8)); [box("Colonne",g,(x,11.5,4),(0.8,0.8,8)) for x in (-3.5,3.5)]; [box("Fenetre_Verre","9CC8E8",(x,11.4,14),(2.2,0.15,3)) for x in (-5,0,5)]
    for x in (-12,12): box("Drapeau","D63A3A",(x,23,15),(0.2,2.6,1.8)); cyl("Mat",g,(x,23,13.5),0.12,6,v=5)
for fn in [globals()[k] for k in list(globals()) if k.startswith(("deco_","terrain_","props_","base_level"))]: reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1); print("OK", len(M), {k:(v["parts"],v["faces"]) for k,v in M.items()})
