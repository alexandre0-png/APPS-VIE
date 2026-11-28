import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
def reg(fn):
    reset(); fn(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx")); M[fn.__name__] = {"parts": n, "faces": t}
# x = largeur, y = profondeur (devant/entrée = -y), z = hauteur, origine au centre du socle
def scn_puits():
    s="9A9AA4"; s2="8A8A94"
    for i in range(14): a=i*2*math.pi/14; box("Pierre",s if i%2 else s2,(2.0*math.cos(a),2.0*math.sin(a),1.0+0.0*i),(1.4,1.0,2.0),(0,0,a+math.pi/2))
    for i in range(14): a=i*2*math.pi/14+0.2; box("Pierre",s2 if i%2 else s,(2.0*math.cos(a),2.0*math.sin(a),2.2),(1.4,1.0,0.5),(0,0,a+math.pi/2))
    cyl("Eau","3C96DC",(0,0,1.7),1.5,0.2,v=14)
    for i in range(10): a=i*2*math.pi/10; box("Dalle","B3B0A4" if i%2 else "9E9C92",(3.6*math.cos(a),3.6*math.sin(a),0.12),(1.6,1.0,0.25),(0,0,a+math.pi/2))
    for s_ in (-1,1): box("Montant","96622C",(s_*2.3,0,4.2),(0.5,0.5,4.4)); box("Etai","96622C",(s_*1.6,0,5.4),(0.3,0.3,1.8),(0,s_*0.6,0))
    cyl("Treuil","96622C",(0,0,5.0),0.28,5.0,(0,math.pi/2,0),8); cyl("Corde","D9B65A",(0,0,3.8),0.05,2.4,v=4)
    box("Toit","D9593D",(-1.45,0,7.2),(3.3,5.2,0.35),(0,math.radians(-32),0)); box("Toit","E8704F",(1.45,0,7.2),(3.3,5.2,0.35),(0,math.radians(32),0)); box("Faitage","96622C",(0,0,7.95),(0.4,5.4,0.3))
    cyl("Seau","96622C",(0,-2.6,0.6),0.5,0.9,v=8); torus("Cerclage_Fer","4A4A4A",(0,-2.6,0.7),0.52,0.05)
def scn_pin_haut():
    cone("Tronc","5A3E28",(0,0,3.0),0.6,0.35,6.0,v=6)
    for i in range(7):
        r=3.4-i*0.42; z=2.6+i*1.7
        for k in range(10): a=k*0.628+i*0.3; box("Branches","2F6B3A" if (k+i)%2 else "3A7F45",(r*0.62*math.cos(a),r*0.62*math.sin(a),z),(0.5,r*0.85,0.18),(0.0,-0.5,a+math.pi/2))
    cone("Branches","4B9A55",(0,0,15.3),0.5,0.0,2.2,v=6)
def scn_pont_pierre():
    c="C9BE9E"; c2="B9AE8E"
    box("Tablier",c,(0,0,8.0),(40,6,1.0)); box("Parapet",c2,(0,2.7,9.0),(40,0.6,1.0)); box("Parapet",c2,(0,-2.7,9.0),(40,0.6,1.0)); [box("Creneau",c,(x,s*2.7,9.8),(1.2,0.6,0.7)) for x in range(-19,20,3) for s in (-1,1)]
    for x in (-15,-5,5,15):
        box("Pile",c2,(x+5,0,3.5),(1.8,5.4,7.0)); 
    for x in (-15,-5,5,15):
        for k in range(8): a=math.pi*k/7; box("Voussoir",c,(x+math.cos(a)*4.2*-1,0,3.5+math.sin(a)*3.5) if False else (x+math.cos(a)*4.2,0,3.2+math.sin(a)*4.0),(1.1,5.6,0.9),(0,-a+math.pi/2,0))
    box("Pile",c2,(-20,0,3.5),(2.0,5.6,7.0)); box("Pile",c2,(20,0,3.5),(2.0,5.6,7.0))
def scn_maison_colombages():
    box("Soubassement_Pierre","8E93A0",(0,0,1.2),(12,10,2.4)); box("Murs","E8DCC0",(0,0,4.6),(11.6,9.6,4.4))
    for x in (-5.6,-2.8,0,2.8,5.6): box("Colombage","4A3220",(x,-4.85,4.6),(0.4,0.2,4.4))
    box("Colombage","4A3220",(0,-4.85,2.5),(11.6,0.2,0.4)); box("Colombage","4A3220",(0,-4.85,6.7),(11.6,0.2,0.4)); box("Colombage","4A3220",(-2.8,-4.9,4.6),(5.8,0.2,0.3),(0,math.radians(35),0))
    box("Toit","3F6F66",(-3.4,0,9.2),(7.6,11,0.5),(0,math.radians(-38),0)); box("Toit","3F6F66",(3.4,0,9.2),(7.6,11,0.5),(0,math.radians(38),0)); box("Faitage","4A3220",(0,0,11.0),(0.5,11.4,0.4))
    box("Porte","7A4A22",(0,-4.9,2.1),(2.0,0.25,3.4)); box("Auvent","B35B2A",(0,-5.7,4.4),(4.4,2.0,0.3),(math.radians(18),0,0)); [box("Poteaux","4A3220",(x,-6.4,2.5),(0.3,0.3,4)) for x in (-2,2)]
    for x in (-4,4): box("Fenetre_Verre","9CC8E8",(x,-4.9,4.8),(1.4,0.15,1.6)); box("Fenetre_Cadre","4A3220",(x,-4.95,4.8),(1.7,0.1,1.9))
    box("Cheminee","8E93A0",(3.5,2,12),(1.6,1.6,3.4)); box("Tour","E8DCC0",(-7,2,6),(4,4,12)); cone("Toit_Tour","D9593D",(-7,2,14.5),3.6,0.15,5,v=8); box("Fenetre_Verre","9CC8E8",(-7,0.05,8.5),(1.0,0.15,1.6))
def scn_rocher_a(): sph("Roche","9A9AA4",(0,0,2.2),3.2,(1,0.9,0.7),seg=10,rings=6); sph("Roche","8A8A94",(2.6,1,1.2),1.6,seg=8,rings=5); sph("Mousse","5CA052",(-0.4,0.3,4.0),1.4,(1,1,0.3),seg=8,rings=5)
def scn_rocher_b(): sph("Roche","8E93A0",(0,0,3.0),2.6,(0.8,0.8,1.3),seg=10,rings=6); sph("Roche","9A9AA4",(-1.8,-1,1.0),1.4,seg=8,rings=5); sph("Mousse","5CA052",(0.2,0.2,5.6),1.1,(1,1,0.3),seg=8,rings=5)
def scn_rocher_c(): [sph("Roche","9A9AA4" if i%2 else "8A8A94",(1.4*math.cos(i*1.3)*(i%3+1)*0.6,1.2*math.sin(i*1.3)*(i%3+1)*0.6,0.5+0.3*i%1.0),0.7+0.3*(i%3),(1,1,0.7),seg=8,rings=5) for i in range(7)]
def scn_ile_sakura():
    cyl("Roche","4A4F5A",(0,0,0.8),9,1.6,v=18); cyl("Herbe","7DBB4F",(0,0,1.85),8.6,0.5,v=18)
    cone("Tronc","3A2A20",(0.5,0.5,4.0),0.8,0.35,4.5,(0.06,0.04,0),7)
    for (x,y,z,r) in ((0.5,0.5,8.0,3.8),(-2.6,0.8,6.8,2.6),(3.3,0.6,7.0,2.7),(0.4,3.0,7.2,2.4),(0.5,-2.2,7.6,2.3)): sph("Fleurs","F6A8C8" if (x+y)>0.4 else "F9BFD6",(x,y,z),r,(1,1,0.8),seg=10,rings=6)
    for (x,y,r) in ((-2.4,-1,1.1),(-0.9,-1.9,0.9),(2.3,-2.1,1.0)): sph("Roche","C9C5BB",(x,y,2.6),r,(1,0.9,0.7),seg=8,rings=5)
    for i in range(4): box("Dalle","D8D4C8",(2.0+i*0.95,-3.6-i*0.7,2.2+0.0),(1.3,0.8,0.25),(0,0,0.3))
    for i in range(10): a=i*0.7; sph("Petale","FFD7E6",(5.5*math.cos(a)*(0.5+(i%3)*0.2),5.5*math.sin(a)*(0.5+(i%3)*0.2),2.15),0.22,(1,1,0.2),seg=6,rings=4)
def scn_tour_cloche():
    box("Murs","E0D4B8",(0,0,5),(6,6,10)); [box("Colombage","4A3220",(x,-3.05,5),(0.35,0.12,10)) for x in (-2.8,0,2.8)]; box("Colombage","4A3220",(0,-3.08,5),(6,0.12,0.35)); cone("Toit","D9593D",(0,0,13),4.6,0.2,6,v=8); sph("Pointe","E8B923",(0,0,16.2),0.3); box("Porte","7A4A22",(0,-3.1,1.6),(1.8,0.2,3.0)); [box("Fenetre_Verre","9CC8E8",(0,-3.1,y),(1.0,0.15,1.6)) for y in (6,8.6)]
for fn in [globals()[k] for k in list(globals()) if k.startswith("scn_")]: reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1); print("OK", len(M), {k:(v["parts"],v["faces"]) for k,v in M.items()})
