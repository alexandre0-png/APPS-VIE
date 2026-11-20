import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
def reg(fn):
    reset(); fn(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx")); M[fn.__name__] = {"parts": n, "faces": t}
# Blender : x = largeur, y = profondeur (devant = -y), z = hauteur
def g_chaise():
    b="5A3E28"; a="7A2E2E"
    box("Assise",a,(0,0,1.1),(1.8,1.8,0.2)); [box("Pied",b,(x,y,0.5),(0.2,0.2,1.0)) for x in (-0.8,0.8) for y in (-0.8,0.8)]
    [box("MontantDossier",b,(x,0.8,1.6),(0.2,0.2,1.0)) for x in (-0.8,0.8)]; box("Traverse",b,(0,0.8,1.95),(1.8,0.2,0.2)); [box("Barreau",b,(x,0.8,1.5),(0.12,0.12,0.8)) for x in (-0.4,0,0.4)]
def g_table_salle():
    p="6B4A2F"; l="4A3220"; box("Plateau",p,(0,0,2.3),(10,2.5,0.4)); box("Rayure",l,(1.5,0.2,2.52),(3,0.06,0.04)); [box("Pied",l,(x,y,1.05),(0.5,0.5,2.1)) for x in (-4.5,4.5) for y in (-0.9,0.9)]; box("Entretoise",l,(0,0.9,0.7),(9,0.2,0.2))
def g_etagere():
    b="5E4630"; [box("Montant",b,(x,0.75,3.5),(0.5,1.5,7)) for x in (-3.75,3.75)]; [box("Planche",b,(0,0.75,0.25+i*1.6),(8,1.5,0.25+0.05*(i%2))) for i in range(5)]; box("Fond",b,(0,1.45,3.5),(7,0.1,7))
def g_caisses():
    l="8A6B45"; c="3A3A3A"
    def caisse(x,y,z,s):
        box("Lattes",l,(x,y,z),(s,s,s)); [box("Cerclage",c,(x+dx,y,z),(0.12,s+0.08,s+0.08)) for dx in (-s*0.35,s*0.35)]
    caisse(-1.6,0,1.5,3); caisse(1.6,0,1.5,3); caisse(0,0.2,4.5,3); caisse(2.6,-0.2,0.9,1.8); box("Couvercle",l,(0.3,-1.2,3.2),(2.8,0.2,1.2),(0.5,0,0.2))
def g_pied_lit(): b="4A3220"; box("Montant",b,(0,0,0.5),(0.3,0.3,1.0)); sph("Boule",b,(0,0,1.15),0.22)
def g_plante():
    cone("Pot","A5603A",(0,0,0.5),0.7,0.55,1.0,v=10); cyl("Terre","3A2A1A",(0,0,1.0),0.55,0.1,v=10)
    for i in range(7): a=i*0.9; box("Feuilles","3F6B3A",(0.4*math.cos(a),0.4*math.sin(a),2.0+0.15*(i%3)),(0.8,0.1,2.0),(0.4*math.sin(a),-0.4*math.cos(a),a))
def g_console():
    b="5A4030"; g="B8A060"; box("Dessus",b,(0,0,2.6),(10,2,0.3)); box("Caisson",b,(0,0,1.9),(8,1.8,1.2)); [box("Tiroir","4A3020",(x,-0.95,1.9),(3.4,0.06,0.9)) for x in (-2,2)]; [sph("Poignees",g,(x,-1.02,1.9),0.12) for x in (-2,2)]; [cyl("Pied",b,(x,y,0.65),0.22,1.3,v=8) for x in (-4.5,4.5) for y in (-0.7,0.7)]
def g_baignoire():
    e="D8D4C8"; p="3A3A3A"; box("Cuve",e,(0,0,1.3),(7,2.5,1.4)); box("Creux","B8B4A8",(0,0,1.8),(6.2,1.9,0.8)); [cyl("Pieds",p,(x,y,0.35),0.25,0.7,v=6) for x in (-3,3) for y in (-0.9,0.9)]; cyl("Robinet","A0A0A0",(-3.2,0.9,2.2),0.1,0.8,v=6)
def g_lavabo():
    e="D8D4C8"; cyl("Colonne",e,(0,0,1.3),0.5,2.6,v=10); box("Vasque",e,(0,0,2.8),(4,3,0.8)); box("Creux","B8B4A8",(0,0,3.05),(3.2,2.2,0.3)); cyl("Robinet","A0A0A0",(0,0.9,3.6),0.1,0.7,v=6); box("Bec","A0A0A0",(0,0.5,3.95),(0.14,0.8,0.14))
def g_wc():
    e="D8D4C8"; box("Cuvette",e,(0,-0.2,1.0),(1.8,2.0,1.2)); box("Siege","C8C4B8",(0,-0.2,1.7),(1.9,2.1,0.15)); box("Reservoir",e,(0,0.9,3.2),(1.6,0.7,1.2)); cyl("Tuyau",e,(0,0.9,2.3),0.15,1.3,v=6); cyl("Chaine","808080",(0.5,0.4,2.6),0.03,1.4,v=4)
def g_armoire_toilette(): box("Cadre","5A4030",(0,0,3),(3,1,6)); box("Miroir","B0C4CC",(0,-0.52,3),(2.5,0.06,5.4)); box("Etagere","5A4030",(0,-0.3,0.3),(3,0.8,0.15))
def g_barrique():
    cyl("Douelles","6B4A2F",(0,0,2),1.5,3.6,v=14); [torus("Cercles","5A4A3A",(0,0,z),1.52,0.08) for z in (0.6,2.0,3.4)]; cyl("Dessus","7B5A3A",(0,0,3.85),1.4,0.1,v=14)
def g_cuve():
    cyl("Metal","6A6E70",(0,0,3),2.0,6,v=14); [torus("Metal",("6A6E70"),(0,0,z),2.02,0.1) for z in (0.8,3,5.2)]; cyl("Metal","6A6E70",(1.9,0,0.6),0.2,0.6,(0,math.pi/2,0),6); [sph("Metal","5A5E60",(2.0*math.cos(i*0.8),2.0*math.sin(i*0.8),5.2),0.12) for i in range(8)]
def g_canape():
    t="6A4A3A"; p="3A2A20"; box("Assise",t,(0,0,1.2),(10,3,1.2)); box("Dossier",t,(0,1.2,2.6),(10,0.8,2.4)); [sph("Accoudoir",t,(x,0,1.9),0.9,(0.8,1.6,1.3)) for x in (-5.0,5.0)]; [box("Coussin",t,(x,-0.2,1.9),(2.9,2.4,0.4)) for x in (-3.3,0,3.3)]; [box("Pieds",p,(x,y,0.3),(0.4,0.4,0.6)) for x in (-4.5,4.5) for y in (-1.2,1.2)]
def g_fauteuil():
    t="6A4A3A"; p="3A2A20"; box("Assise",t,(0,0,1.2),(3.4,3,1.2)); box("Dossier",t,(0,1.2,2.6),(3.4,0.8,2.4)); [sph("Accoudoir",t,(x,0,1.9),0.7,(0.7,1.5,1.2)) for x in (-1.9,1.9)]; box("Coussin",t,(0,-0.2,1.9),(2.4,2.4,0.4)); [box("Pieds",p,(x,y,0.3),(0.4,0.4,0.6)) for x in (-1.4,1.4) for y in (-1.2,1.2)]
def g_cuisiniere():
    e="3A3A3A"; c="B0B0B0"; box("Corps",e,(0,0,1.7),(10,3,3.4)); box("Plan",c,(0,0,3.5),(10,3,0.1)); [cyl("Feux",c,(x,y,3.6),0.5,0.1,v=10) for x in (-2.5,2.5) for y in (-0.6,0.6)]; box("Four","2A2A2A",(0,-1.52,1.7),(7,0.06,2.0)); box("Poignee",c,(0,-1.6,2.8),(6,0.14,0.14))
def g_frigo():
    e="C8C4B0"; c="B0B0B0"; box("Corps",e,(0,0,3.2),(4,4,6.4)); box("Haut",e,(0,0,6.4),(3.6,3.6,0.3)); box("Separation","A8A490",(0,-2.02,4.4),(3.8,0.05,0.05)); box("Poignee1",c,(1.4,-2.12,3.0),(0.14,0.14,1.4)); box("Poignee2",c,(1.4,-2.12,5.2),(0.14,0.14,1.2)); [box("Pieds","3A3A3A",(x,y,0.15),(0.3,0.3,0.3)) for x in (-1.6,1.6) for y in (-1.6,1.6)]
def g_cercueil():
    b="3A2418"; h="8A7A50"; box("Caisse",b,(0,0,0.7),(8,2.4,1.4)); box("Epaules",b,(-3.0,0,0.7),(2.0,2.8,1.4)) if False else None; box("Couvercle",b,(0.6,0.4,1.55),(7.6,2.5,0.2),(0,0,0.12)); box("CroixV","6A4A38",(0.6,0.4,1.7),(0.2,0.1,1.4)); box("CroixH","6A4A38",(0.6,0.4,1.7),(1.0,0.1,0.2)); [box("Poignees",h,(x,-1.25,0.9),(0.8,0.12,0.12)) for x in (-2.5,0.5,3.0)]
def g_coffre_verrouille():
    b="4A3220"; f="4A4A4A"; c="B8A060"; box("Caisse",b,(0,0,1.0),(8,3,2.0)); box("Couvercle",b,(0,0,2.3),(8.2,3.2,0.6)); [box("Fer",f,(x,0,1.4),(0.4,3.3,2.8)) for x in (-3.2,0,3.2)]; box("Cadenas",c,(0,-1.7,1.6),(0.9,0.5,1.0)); torus("Cadenas",c,(0,-1.7,2.3),0.4,0.08,(math.pi/2,0,0))
def g_coffre_jouets():
    b="7A5A8A"; e="D8C060"; box("Caisse",b,(0,0,1.0),(6,2.5,2.0)); cyl("Couvercle",b,(0,0,2.0),1.25,6,(0,math.pi/2,0),12); [cone("Etoiles",e,(x,-1.3,1.2),0.35,0.0,0.1,(math.pi/2,0,0),5) for x in (-1.8,0,1.8)]; box("Bande","5A3A6A",(0,0,0.3),(6.1,2.6,0.25))
def g_vitrine():
    c="4A3220"; v="A8C0C8"; [box("Cadre",c,(x,y,3.5),(0.3,0.3,7)) for x in (-1.85,1.85) for y in (-1.35,1.35)]; box("Fond",c,(0,1.4,3.5),(3.6,0.1,7)); [box("Etagere",c,(0,0,0.3+i*1.8),(3.6,2.6,0.12)) for i in range(4)]; [box("Vitre",v,(0,-1.4,3.5),(3.6,0.05,6.6))]; box("Toit",c,(0,0,7.1),(4.2,3.2,0.3))
def g_portemanteau():
    b="4A3220"; m="3A3A44"; cyl("Pied",b,(0,0,2.8),0.1,5.6,v=6); cyl("Base",b,(0,0,0.1),0.9,0.2,v=8); [box("Crochet",b,(0.35*math.cos(a),0.35*math.sin(a),5.4),(0.6,0.08,0.08),(0,0,a)) for a in (0,1.57,3.14,4.71)]; box("Manteau",m,(0.3,0,4.2),(1.0,0.6,2.4)); sph("Manteau",m,(0.3,0,5.4),0.4)
def g_lampadaire(): cyl("Pied","4A3A2A",(0,0,2.2),0.08,4.4,v=6); cyl("Base","4A3A2A",(0,0,0.1),0.6,0.2,v=8); cone("Abatjour","C8B070",(0,0,4.7),0.8,0.45,1.0,v=10)
def g_lit_double():
    b="4A3220"; d="C8C0A8"; box("Sommier",b,(0,0,0.8),(11,11,0.5)); box("Matelas",d,(0,0.3,1.3),(10.4,10.4,0.8)); box("Tete",b,(0,5.4,3.0),(11,0.5,4.4)); [cyl("Colonne",b,(x,y,3.2),0.25,5.5,v=6) for x in (-5.2,5.2) for y in (-5.2,5.2)]; box("Traine",d,(0,-5.8,0.5),(8,0.8,0.15),(0.3,0,0)); box("Oreiller","D8D0B8",(-2.5,4.2,1.9),(3,1.6,0.5)); box("Oreiller2","D8D0B8",(2.5,4.2,1.9),(3,1.6,0.5))
def g_etabli():
    b="6B4A2F"; e="5A5A5A"; box("Plateau",b,(0,0,2.6),(10,3,0.4)); [box("Pied",b,(x,y,1.2),(0.5,0.5,2.4)) for x in (-4.5,4.5) for y in (-1.2,1.2)]; box("Traverse",b,(0,1.2,0.8),(9,0.3,0.3)); box("EtauBase",e,(3.8,-0.8,3.0),(1.2,1.2,0.8)); box("EtauMachoire",e,(3.8,-1.6,3.5),(1.0,0.3,0.7)); box("Outil","8A8A8A",(-2,-0.2,2.9),(2.0,0.2,0.1)); cyl("Manche","8A5A2B",(-3.4,-0.2,2.9),0.12,1.0,(0,math.pi/2,0),6)
for name, fn in list(globals().items()):
    if callable(fn) and getattr(fn,"__module__","")=="__main__" and name.startswith("g_"): reg(fn)
json.dump(M, open(os.path.join(OUT,"manifest.json"),"w"), indent=1); print("OK", len(M))
