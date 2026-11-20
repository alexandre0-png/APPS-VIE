import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
def reg(fn):
    reset(); fn(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx")); M[fn.__name__] = {"parts": n, "faces": t}
W="E8ECEF"; G="9AA5AD"; D="3A4047"; R="B0151F"; B="5B8DB8"
# ---------- Hôpital ----------
def H_LitHopital(): box("Cadre",G,(0,0,1.6),(3,6.5,0.4)); box("Matelas",W,(0,0,2.0),(2.8,6.2,0.6)); box("Oreiller","F6F6F6",(0,2.4,2.5),(2.0,1.3,0.4)); box("Drap",B,(0,-0.8,2.4),(2.8,3.6,0.2)); box("Tete",G,(0,3.3,2.4),(3,0.2,2.0)); box("Pied",G,(0,-3.3,2.0),(3,0.2,1.4)); [cyl("Roue",D,(x,y,0.5),0.4,0.3,(0,math.pi/2,0),8) for x in (-1.3,1.3) for y in (-2.8,2.8)]; [box("Pied2",G,(x,y,1.0),(0.2,0.2,1.2)) for x in (-1.4,1.4) for y in (-3.1,3.1)]
def H_Civiere(): box("Plateau",G,(0,0,3),(2.6,7,0.3)); box("Matelas",B,(0,0,3.4),(2.4,6.6,0.5)); [box("Pied",G,(x,y,1.5),(0.2,0.2,3)) for x in (-1.1,1.1) for y in (-3,3)]; [cyl("Roue",D,(x,y,0.35),0.35,0.25,(0,math.pi/2,0),8) for x in (-1.1,1.1) for y in (-3,3)]; box("Sangle","B0151F",(0,0,3.7),(2.5,0.4,0.1))
def H_FauteuilRoulant(): box("Assise","3A4A6B",(0,0,2.0),(2.4,2.4,0.3)); box("Dossier","3A4A6B",(0,1.2,3.2),(2.4,0.3,2.4)); [cyl("Grande",D,(x,0.6,1.3),1.3,0.25,(0,math.pi/2,0),14) for x in (-1.5,1.5)]; [cyl("Petite",D,(x,-1.2,0.5),0.5,0.2,(0,math.pi/2,0),8) for x in (-1.0,1.0)]; [box("Accoudoir",G,(x,0,2.8),(0.2,2.2,0.2)) for x in (-1.2,1.2)]; box("Repose",G,(0,-1.4,1.0),(1.8,0.8,0.15))
def H_Perfusion(): cyl("Pied",G,(0,0,3.5),0.12,7,v=6); cyl("Base",D,(0,0,0.15),1.0,0.3,v=10); box("Barre",G,(0,0,7),(2.4,0.15,0.15)); [sph("Poche","CFE8F5",(x,0,6.0),0.45,(0.7,0.5,1.2)) for x in (-1,1)]; cyl("Tube","CFE8F5",(1,0,4.2),0.04,3.0,v=4)
def H_ChariotMedical(): box("Corps",W,(0,0,2.2),(3.4,2.0,3.0)); [box("Tiroir",G,(0,-1.02,y),(3.0,0.06,0.8)) for y in (1.4,2.3,3.2)]; box("Dessus",G,(0,0,3.8),(3.6,2.2,0.2)); [cyl("Roue",D,(x,y,0.35),0.35,0.25,(0,math.pi/2,0),8) for x in (-1.4,1.4) for y in (-0.8,0.8)]; box("CroixR",R,(0,-1.04,2.3),(0.8,0.04,0.2)); box("CroixR2",R,(0,-1.04,2.3),(0.2,0.04,0.8))
def H_ArmoireMedicale(): box("Corps",W,(0,0,3.5),(3.4,1.6,7)); box("PorteG",G,(-0.85,-0.82,3.5),(1.6,0.06,6.4)); box("PorteD",G,(0.85,-0.82,3.5),(1.6,0.06,6.4)); [sph("Poignee",D,(x,-0.9,3.5),0.12) for x in (-0.15,0.15)]; box("CroixR",R,(0,-0.87,5.8),(0.9,0.04,0.25)); box("CroixR2",R,(0,-0.87,5.8),(0.25,0.04,0.9))
def H_Casier(): box("Corps","5E7A8C",(0,0,3.5),(2.2,2.2,7)); box("Porte","6E8A9C",(0,-1.12,3.5),(2.0,0.06,6.6)); [box("Fente",D,(0,-1.16,6.0+i*0.25),(1.2,0.04,0.1)) for i in range(3)]; box("Poignee",G,(0.6,-1.2,3.5),(0.14,0.12,0.8))
def H_Lavabo(): box("Meuble",W,(0,0,1.5),(3,1.8,3.0)); box("Vasque","F4F4F4",(0,0,3.1),(2.6,1.5,0.4)); cyl("Robinet",G,(0,0.5,3.8),0.1,1.2,v=6); box("Bec",G,(0,0.2,4.3),(0.14,0.7,0.14)); box("Miroir","9FC7D6",(0,0.85,5.6),(2.4,0.1,2.2))
def H_TableOperation(): box("Plateau",G,(0,0,3.6),(2.6,6.4,0.3)); box("Matelas","7FB7A4",(0,0,3.95),(2.4,6.0,0.4)); cyl("Pied",D,(0,0,1.7),0.5,3.4,v=8); cyl("Base",D,(0,0,0.2),1.6,0.4,v=10)
def H_LampeOperation(): cyl("Bras",G,(0,0,5),0.15,10,v=6); box("Bras2",G,(1.5,0,9.8),(3,0.3,0.3)); cyl("Lampe","F4F4F4",(3,0,9.2),1.6,0.5,v=14); cyl("Verre","FFF3B0",(3,0,8.9),1.3,0.1,v=14)
def H_Rideau(): box("Rail",G,(0,0,7.5),(7,0.2,0.2)); [box("Pli","8FB8C8" if i%2 else "7BA6B6",(-3.1+i*0.62,0,3.7),(0.6,0.12,7.0)) for i in range(11)]
def H_Extincteur(): cyl("Corps",R,(0,0,1.2),0.45,2.2,v=10); sph("Haut",R,(0,0,2.3),0.45); cyl("Valve",D,(0,0,2.8),0.15,0.5,v=6); box("Poignee",D,(0.3,0,3.0),(0.7,0.15,0.12)); cyl("Tuyau",D,(0.5,-0.2,1.8),0.05,1.6,(0.3,0,0),4)
def H_PanneauSortie(): box("Plaque","2E9E4F",(0,0,0.5),(3,0.2,1.2)); box("Fleche","FFFFFF",(0.5,-0.12,0.5),(1.4,0.05,0.25)); cone("Pointe","FFFFFF",(-0.6,-0.12,0.5),0.4,0.0,0.7,(0,math.pi/2,0),3); box("Cadre",D,(0,0,0.5),(3.2,0.15,1.4)) if False else None
def H_Voiture():
    c="C23B3B"; box("Caisse",c,(0,0,1.6),(5.0,10.5,1.6)); box("Cabine",c,(0,-0.5,3.0),(4.4,5.4,1.4)); box("Pare","9FD8F0",(0,-3.25,3.1),(4.0,0.1,1.1)); box("Lunette","9FD8F0",(0,2.25,3.1),(4.0,0.1,1.1)); [box("Vitre","9FD8F0",(x,-0.5,3.1),(0.1,4.2,1.0)) for x in (-2.25,2.25)]
    [cyl("Roue","1A1A1A",(x,y,0.9),0.9,0.7,(0,math.pi/2,0),12) for x in (-2.5,2.5) for y in (-3.3,3.3)]; [box("Phare","FFF3B0",(x,-5.28,1.8),(1.0,0.1,0.5)) for x in (-1.6,1.6)]; [box("Feu","FF3030",(x,5.28,1.8),(1.0,0.1,0.5)) for x in (-1.6,1.6)]; box("Pare-chocs","8A8A92",(0,-5.3,1.0),(5.0,0.3,0.4))
def H_GuidePetit():
    sph("Corps","8FD3FF",(0,0,1.3),0.9,(0.9,0.9,1.1)); sph("Tete","BFE9FF",(0,0,2.5),0.7); [sph("Oeil","111111",(x,-0.58,2.65),0.12) for x in (-0.25,0.25)]; box("Sourire","111111",(0,-0.64,2.35),(0.35,0.04,0.06)); box("Chapeau","FFD23F",(0,0,3.25),(0.9,0.9,0.25)); [sph("Main","BFE9FF",(x,-0.4,1.4),0.25) for x in (-1.0,1.0)]
def H_CarteDepart(): box("Papier","E6D6A8",(0,0,0.05),(3.0,2.2,0.08)); box("Bord","B79A5B",(0,0,0.02),(3.2,2.4,0.04)); box("Route1","B0432E",(-0.4,0.2,0.1),(1.6,0.1,0.02)); box("Route2","B0432E",(0.4,-0.1,0.1),(0.1,1.2,0.02)); sph("Croix","D63A3A",(0.9,-0.6,0.14),0.14); box("Pli","B79A5B",(0,0,0.1),(0.03,2.2,0.02))
def H_MurLabyrinthe(): box("Mur","7C8A94",(0,0,2.0),(8,1.2,4)); box("Sommet","93A1AB",(0,0,4.1),(8.2,1.4,0.3)); [box("Brique","6A7882",(-3+i*2,-0.62,1.5+(i%2)),(1.6,0.04,0.8)) for i in range(4)]
def H_ClePorte(): torus("Anneau","D9B13A",(0,0,1.1),0.4,0.1,(math.pi/2,0,0)); cyl("Tige","D9B13A",(0,0,0.3),0.07,0.6); box("Dent1","D9B13A",(0.12,0,0.0),(0.24,0.1,0.14)); box("Dent2","D9B13A",(0.1,0,0.2),(0.2,0.1,0.14)); box("Etiquette","D63A3A",(0.0,0.1,0.6),(0.3,0.04,0.4))
# ---------- Grenier : supplémentaires ----------
def G_Lustre(): cyl("Chaine","3A3A40",(0,0,3.0),0.05,2.0,v=4); torus("Anneau","B38026",(0,0,1.9),1.1,0.07,(0,0,0)); [(cyl("Bras","B38026",(1.1*math.cos(i*math.pi/3),1.1*math.sin(i*math.pi/3),1.7),0.05,0.5,v=4), cyl("Bougie","F2EBCF",(1.1*math.cos(i*math.pi/3),1.1*math.sin(i*math.pi/3),2.15),0.07,0.4,v=6), cone("Flamme","FFB347",(1.1*math.cos(i*math.pi/3),1.1*math.sin(i*math.pi/3),2.45),0.05,0.0,0.15,v=5)) for i in range(6)]
def G_Cheminee(): box("Corps","6B6560",(0,0,3.5),(6,1.6,7)); box("Ouverture","0E0B0A",(0,-0.82,2.0),(3.2,0.1,3.4)); box("Manteau","4A3A2B",(0,-0.2,4.4),(6.6,2.0,0.5)); [box("Brique","7A726B",(-2.5+i*1.0,-0.82,5.6+(i%2)*0.6),(0.9,0.05,0.4)) for i in range(6)]; [box("Buche","3A2410",(x,-0.4,0.5),(1.0,0.4,0.4),(0,0,0.2)) for x in (-0.6,0.6)]
def G_Etagere(): box("Montant1","4A2B15",(-2,0,3.5),(0.3,1.2,7)); box("Montant2","4A2B15",(2,0,3.5),(0.3,1.2,7)); [box("Planche","5A3317",(0,0,1+i*2),(4.2,1.2,0.2)) for i in range(4)]; [box("Livre",c,(-1.5+j*0.5,-0.1,1.7+i*2),(0.35,0.8,1.0)) for i in range(3) for j,c in enumerate(("7B2A2A","2A4B7B","3A6B3A","6B5A2A","4A2A5A","2A2A2A"))]
def G_TapisRond(): cyl("Tapis","7B2A3A",(0,0,0.05),3.0,0.1,v=24); cyl("Bord","D9B13A",(0,0,0.11),2.8,0.04,v=24); cyl("Centre","4A1A28",(0,0,0.15),1.8,0.04,v=24)
def G_ToileAraignee():
    for i in range(6): a=i*math.pi/3; box("Fil","DADADA",(1.0*math.cos(a),0,1.0*math.sin(a)),(2.0,0.02,0.03),(0,-a,0)) if False else box("Fil","DADADA",(0.9*math.cos(a),0,0.9*math.sin(a)),(1.8,0.02,0.04),(0,-a,0))
    for r in (0.5,1.0,1.5): torus("Spirale","E6E6E6",(0,0,0),r*0.9,0.015,(math.pi/2,0,0))
def G_PorteAncienne(): box("Cadre","3A2410",(0,0,4),(4.6,0.8,8.4)); box("Battant","5A3317",(0,-0.1,3.8),(3.8,0.5,7.6)); [box("Panneau","4A2B15",(0,-0.38,y),(2.8,0.1,2.0)) for y in (2.2,5.2)]; sph("Poignee","B38026",(1.4,-0.45,3.6),0.18); [box("Gond","3A3A40",(-1.9,-0.4,y),(0.3,0.12,0.6)) for y in (1.5,6.0)]
def G_Valise(): box("Corps","6B4A2B",(0,0,1.0),(3.0,0.9,2.0)); box("Bord","3A2410",(0,0,1.0),(3.1,0.95,0.15)); box("Poignee","3A2410",(0,0,2.2),(1.0,0.2,0.3)); [box("Fermoir","B38026",(x,-0.48,1.4),(0.3,0.08,0.3)) for x in (-0.9,0.9)]
def G_Gramophone(): box("Caisse","4A2B15",(0,0,1.0),(2.2,2.2,2.0)); cyl("Disque","111111",(0,0,2.1),0.9,0.1,v=16); cyl("Axe","B38026",(0,0,2.3),0.05,0.4,v=6); box("Bras","B38026",(0.5,0,2.5),(1.0,0.1,0.1)); cone("Pavillon","B38026",(-0.6,0.2,3.6),1.2,0.15,2.2,(0.5,0,-0.5),14)
def G_MachineCoudre(): box("Table","3A2410",(0,0,1.5),(3.4,1.6,0.3)); [box("Pied","3A3A40",(x,0,0.7),(0.2,1.2,1.4)) for x in (-1.5,1.5)]; box("Corps","1E1E24",(0,0,2.1),(2.4,0.8,1.0)); box("Bras","1E1E24",(1.0,0,2.9),(0.6,0.6,1.0)); cyl("Roue","B38026",(-1.3,0,2.3),0.35,0.1,(math.pi/2,0,0),10); cone("Aiguille","C8CCD6",(1.0,-0.2,2.2),0.04,0.0,0.4,(math.pi,0,0),4)
def G_Telephone(): box("Base","141414",(0,0,0.25),(1.4,1.0,0.5)); box("Combine","141414",(0,0,0.7),(1.6,0.3,0.3)); cyl("Cadran","B38026",(0,-0.4,0.35),0.4,0.06,(math.pi/2,0,0),12)
def G_Escalier():
    for i in range(8): box("Marche","6B4A2B",(0,-i*1.0,0.5+i*0.9),(4,1.0,0.4)); box("Contre","4A2B15",(0,-i*1.0+0.5,0.1+i*0.9),(4,0.1,0.9)) if False else None
    for s in (-2.1,2.1): box("Limon","4A2B15",(s,-3.5,3.6),(0.2,8.4,0.3),(math.radians(-42),0,0)); 
    box("Rampe","3A2410",(-2.1,-3.5,5.2),(0.15,8,0.15),(math.radians(-42),0,0))
for name, fn in list(globals().items()):
    if callable(fn) and getattr(fn,"__module__","")=="__main__" and name[:2] in ("H_","G_"): reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1); print("OK", len(M))
