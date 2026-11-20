import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
def reg(fn):
    reset(); fn(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx")); M[fn.__name__] = {"parts": n, "faces": t}
# ---------- Grenier : objets d'énigme (par matériau) ----------
def CleOr():
    g="F2BE26"; torus("Anneau",g,(0,0,1.0),0.35,0.1,(math.pi/2,0,0)); cyl("Tige",g,(0,0,0.3),0.07,0.55); box("Dent1",g,(0.12,0,-0.15),(0.24,0.1,0.14)); box("Dent2",g,(0.1,0,0.05),(0.2,0.1,0.14))
def CoffretAncien():
    w="5A3317"; f="3A3A40"; o="F2BE26"
    box("Caisse",w,(0,0,0.45),(2,1.2,0.9)); cyl("Couvercle",w,(0,0,0.9),0.6,2,(0,math.pi/2,0),16)
    for x in (-0.6,0.6): box("Bande",f,(x,0,0.62),(0.14,1.28,1.3))
    box("Serrure",o,(0,-0.64,0.78),(0.28,0.1,0.36)); cyl("Trou",f,(0,-0.7,0.78),0.05,0.06,(math.pi/2,0,0),8)
def HorlogeComtoise():
    w="3F2410"; c="E6D9B8"; o="F2BE26"
    box("Socle",w,(0,0,0.3),(1.1,0.7,0.6)); box("Corps",w,(0,0,1.5),(0.8,0.55,1.8)); box("Tete",w,(0,0,2.75),(1.1,0.7,0.7)); cone("Toit",w,(0,0,3.35),0.62,0.2,0.5,v=4)
    cyl("Cadran",c,(0,-0.3,2.75),0.28,0.05,(math.pi/2,0,0),24); box("Aiguille1",o,(0,-0.34,2.85),(0.04,0.03,0.22)); box("Aiguille2",o,(0.07,-0.34,2.75),(0.16,0.03,0.04))
    box("Vitre","7A5A3A",(0,-0.29,1.5),(0.4,0.03,1.0)); cyl("Pendule",o,(0,-0.3,1.1),0.12,0.04,(math.pi/2,0,0),14)
def PoupeeAncienne():
    r="8C1A24"; p="E3C9B0"; h="140C0A"
    cone("Robe",r,(0,0,0.45),0.34,0.12,0.9,v=10); sph("Tete",p,(0,0,1.1),0.2); sph("Cheveux",h,(0,0.04,1.18),0.21,(1,1,0.7)); 
    for x in (-0.3,0.3): cyl("Bras",p,(x,0,0.8),0.05,0.4,(0,math.radians(25*(1 if x>0 else -1)),0),8)
    sph("Oeil1","0A0A0A",(-0.07,-0.18,1.12),0.03); sph("Oeil2","0A0A0A",(0.07,-0.18,1.12),0.03)
def BougieChandelier():
    b="B38026"; c="F2EBCF"; f="FFB347"
    cyl("Base",b,(0,0,0.05),0.2,0.1,v=14); cyl("Pied",b,(0,0,0.25),0.05,0.3,v=8); cyl("Coupelle",b,(0,0,0.42),0.12,0.05,v=12); cyl("Bougie",c,(0,0,0.65),0.06,0.4,v=10); cone("Flamme",f,(0,0,0.95),0.04,0.0,0.14,v=8)
# ---------- Grenier : mobilier ----------
def Armoire():
    w="4B2C16"; d="35200F"; o="B38026"
    box("Corps",w,(0,0,1.1),(1.8,0.8,2.2)); box("PorteG",d,(-0.45,-0.41,1.1),(0.8,0.04,2.0)); box("PorteD",d,(0.45,-0.41,1.1),(0.8,0.04,2.0)); box("Corniche",w,(0,0,2.3),(2.0,0.9,0.18)); sph("PoigneeG",o,(-0.1,-0.46,1.1),0.05); sph("PoigneeD",o,(0.1,-0.46,1.1),0.05)
def Commode():
    w="5A3317"; o="B38026"
    box("Corps",w,(0,0,0.5),(1.5,0.7,1.0))
    for i,z in enumerate((0.25,0.55,0.85)): box("Tiroir","3B2210",(0,-0.36,z),(1.3,0.04,0.25)); sph("Poignee",o,(0,-0.4,z),0.04)
def Berceau():
    w="E7D8B8"; t="C9B7A0"
    box("Fond",w,(0,0,0.35),(1.0,0.6,0.1)); box("Cote1",w,(-0.5,0,0.55),(0.06,0.6,0.5)); box("Cote2",w,(0.5,0,0.55),(0.06,0.6,0.5)); box("Tete",w,(0,0.3,0.7),(1.0,0.06,0.8)); box("Pied",w,(0,-0.3,0.6),(1.0,0.06,0.6)); box("Couverture",t,(0,0,0.45),(0.9,0.5,0.06))
    cyl("Arc",w,(0,0,0.15),0.5,0.04,(0,math.pi/2,0),16)
def ChevalBascule():
    w="6B4A2B"; r="D9C9A3"
    box("Corps",w,(0,0,0.65),(0.3,0.9,0.4)); box("Cou",w,(0,0.4,0.95),(0.22,0.22,0.5),(0.4,0,0)); sph("Tete",w,(0,0.55,1.25),0.22,(0.8,1.3,0.9)); box("Selle","5A1F1F",(0,0,0.88),(0.34,0.4,0.08))
    for x in (-0.18,0.18): 
        box("Patte",w,(x,0.3,0.3),(0.08,0.08,0.55)); box("Patte2",w,(x,-0.3,0.3),(0.08,0.08,0.55)); torus("Patin",w,(x,0,0.0),0.7,0.05,(math.pi/2,0,math.pi/2))
    box("Crinière",r,(0,0.3,1.1),(0.06,0.14,0.4))
def MiroirAncien():
    o="B38026"; g="9FC7D6"
    box("Cadre",o,(0,0,1.1),(1.0,0.12,2.0)); box("Verre",g,(0,-0.07,1.1),(0.8,0.02,1.8)); box("PiedG",o,(-0.35,0.15,0.1),(0.08,0.4,0.2)); box("PiedD",o,(0.35,0.15,0.1),(0.08,0.4,0.2))
def Malle():
    w="4A2B15"; f="3A3A40"; o="B38026"
    box("Caisse",w,(0,0,0.4),(1.6,0.9,0.8)); box("Couvercle",w,(0,0,0.9),(1.65,0.95,0.2)); 
    for x in (-0.55,0.55): box("Bande",f,(x,0,0.6),(0.1,0.98,1.2))
    box("Serrure",o,(0,-0.5,0.7),(0.2,0.06,0.25))
def Statuette():
    p="9A9A9A"
    box("Socle",p,(0,0,0.1),(0.5,0.5,0.2)); cone("Corps",p,(0,0,0.55),0.2,0.12,0.7,v=8); sph("Tete",p,(0,0,1.0),0.14); box("BrasG",p,(-0.22,0,0.65),(0.08,0.08,0.4)); box("BrasD",p,(0.22,0,0.65),(0.08,0.08,0.4))
def CadrePhoto():
    o="3B2210"; c="D8CFB8"; s="6B6B6B"
    box("Cadre",o,(0,0,0.5),(0.8,0.06,1.0)); box("Papier",c,(0,-0.035,0.5),(0.64,0.02,0.84)); sph("Visage",s,(0,-0.05,0.6),0.12,(1,0.3,1.2)); cone("Epaules",s,(0,-0.05,0.3),0.22,0.1,0.3,v=8)
# ---------- Grenier : monstre ----------
def OmbreRampante():
    k="0E0B14"; w="E8E2D2"; r="B0151F"
    cone("Corps",k,(0,0,1.0),0.35,0.15,2.0,v=8); sph("Tete",k,(0,0,2.15),0.3,(1,0.9,1.15)); box("Masque",w,(0,-0.22,2.15),(0.34,0.06,0.46)); sph("OeilG",r,(-0.1,-0.27,2.2),0.05); sph("OeilD",r,(0.1,-0.27,2.2),0.05); box("Bouche","0A0A0A",(0,-0.27,2.0),(0.2,0.02,0.04))
    for s in (-1,1):
        box("Bras",k,(s*0.45,-0.1,1.4),(0.1,0.1,1.2),(0.3*s,0,0.2*s)); 
        for i in range(3): box("Doigt",w,(s*(0.5+0.04*i),-0.45,0.75),(0.03,0.03,0.35))
    cone("Queue",k,(0,0.35,0.3),0.2,0.02,0.9,(math.radians(-70),0,0),6)
# ---------- Chipe-Œufs : œufs par rareté ----------
def _oeuf(base, tache, dec=None):
    sph("Coque",base,(0,0,0.5),0.4,(1,1,1.28),16,10)
    for i in range(6):
        a=i*1.05; sph("Tache",tache,(0.34*math.cos(a),0.34*math.sin(a),0.35+0.13*i),0.07,(1,1,0.8),8,6)
    if dec: dec()
def OeufCommun(): _oeuf("E8D8B8","B89968")
def OeufRare():
    _oeuf("7FB8E8","FFFFFF")
def OeufEpique():
    _oeuf("9B6FE0","F3D96B", lambda: torus("Anneau","F3D96B",(0,0,0.5),0.46,0.04,(0.3,0,0)))
def OeufLegendaire():
    _oeuf("FFB347","FFF3C2", lambda: [cone("Pointe","FFF3C2",(0,0,1.18+0.0),0.12,0.0,0.3,v=6)] and [torus("Anneau","FFF3C2",(0,0,0.55),0.5,0.05)])
def OeufMythique():
    _oeuf("49E0D0","FFFFFF", lambda: [cone("Cristal","BFFFF7",(0.0,0.0,1.25),0.1,0.0,0.35,v=5), torus("Anneau1","BFFFF7",(0,0,0.5),0.5,0.04,(math.pi/2.2,0,0)), torus("Anneau2","BFFFF7",(0,0,0.5),0.5,0.04,(0,math.pi/2.3,0))])
def OeufSecret():
    _oeuf("2A1646","FF4DD8", lambda: [torus("Anneau","FF4DD8",(0,0,0.5),0.5,0.05,(0.5,0.4,0)), cone("Epine1","FF4DD8",(0,0,1.18),0.1,0.0,0.3,v=5), cone("Epine2","FF4DD8",(0.4,0,0.5),0.09,0.0,0.25,(0,math.pi/2,0),5)])
# ---------- Chipe-Œufs : pets ----------
def PetPoussin():
    y="FFD84D"; o="FF8C2B"; k="111111"
    sph("Corps",y,(0,0,0.3),0.28,(1,1,0.95)); sph("Tete",y,(0,-0.12,0.62),0.2); cone("Bec",o,(0,-0.32,0.6),0.06,0.0,0.14,(math.pi/2,0,0),4)
    sph("OeilG",k,(-0.08,-0.28,0.68),0.03); sph("OeilD",k,(0.08,-0.28,0.68),0.03); box("PatteG",o,(-0.08,0,0.04),(0.05,0.12,0.08)); box("PatteD",o,(0.08,0,0.04),(0.05,0.12,0.08)); cone("Houppe",y,(0,-0.1,0.86),0.04,0.0,0.14,v=4)
def PetRenard():
    o="E8782B"; w="FFFFFF"; k="1A1A1A"
    box("Corps",o,(0,0,0.35),(0.4,0.8,0.35)); sph("Tete",o,(0,-0.5,0.55),0.22,(1,1,0.9)); cone("Museau",w,(0,-0.7,0.5),0.1,0.04,0.2,(math.pi/2,0,0),4)
    cone("OreilleG",o,(-0.12,-0.46,0.82),0.07,0.0,0.2,v=4); cone("OreilleD",o,(0.12,-0.46,0.82),0.07,0.0,0.2,v=4); sph("Nez",k,(0,-0.8,0.5),0.035)
    for x in (-0.14,0.14):
        for y in (-0.25,0.3): box("Patte",k,(x,y,0.1),(0.08,0.08,0.2))
    cone("Queue",o,(0,0.6,0.45),0.14,0.03,0.6,(math.radians(-60),0,0),6); cone("BoutQueue",w,(0,0.85,0.68),0.05,0.02,0.15,(math.radians(-60),0,0),6)
def PetPanda():
    w="F4F4F4"; k="1C1C1C"
    sph("Corps",w,(0,0,0.38),0.34,(1,0.9,1)); sph("Tete",w,(0,-0.08,0.85),0.26); sph("OreilleG",k,(-0.2,-0.05,1.06),0.09); sph("OreilleD",k,(0.2,-0.05,1.06),0.09)
    sph("OeilG",k,(-0.09,-0.3,0.9),0.06,(1,0.5,1.4)); sph("OeilD",k,(0.09,-0.3,0.9),0.06,(1,0.5,1.4)); sph("Nez",k,(0,-0.33,0.82),0.03)
    for x in (-0.25,0.25): sph("Patte",k,(x,-0.1,0.1),0.12); sph("Bras",k,(x*1.3,-0.1,0.45),0.1)
def PetDragonnet():
    g="4CC96B"; b="F3E3A5"; r="D93B3B"
    sph("Corps",g,(0,0,0.38),0.3,(1,1.3,1)); sph("Tete",g,(0,-0.38,0.7),0.2); cone("CorneG",b,(-0.08,-0.38,0.92),0.04,0.0,0.14,v=4); cone("CorneD",b,(0.08,-0.38,0.92),0.04,0.0,0.14,v=4)
    box("AileG",r,(-0.4,0,0.6),(0.5,0.3,0.03),(0,0,0.4)); box("AileD",r,(0.4,0,0.6),(0.5,0.3,0.03),(0,0,-0.4)); cone("Queue",g,(0,0.55,0.25),0.12,0.02,0.6,(math.radians(-80),0,0),6)
    sph("OeilG","111111",(-0.08,-0.54,0.76),0.03); sph("OeilD","111111",(0.08,-0.54,0.76),0.03)
def PetLapin():
    w="F5ECE0"; p="F2A7B8"
    sph("Corps",w,(0,0,0.3),0.28); sph("Tete",w,(0,-0.1,0.65),0.2); cyl("OreilleG",w,(-0.08,-0.08,1.0),0.05,0.4,(0.1,0,0),8); cyl("OreilleD",w,(0.08,-0.08,1.0),0.05,0.4,(0.1,0,0),8)
    sph("Nez",p,(0,-0.3,0.62),0.03); sph("Queue",w,(0,0.28,0.25),0.09); sph("OeilG","111111",(-0.07,-0.27,0.7),0.025); sph("OeilD","111111",(0.07,-0.27,0.7),0.025)
def PetFantome():
    w="E8F3FF"; k="111111"
    cone("Corps",w,(0,0,0.4),0.3,0.18,0.8,v=10); sph("Tete",w,(0,0,0.85),0.26); sph("OeilG",k,(-0.09,-0.22,0.9),0.05,(1,0.5,1.4)); sph("OeilD",k,(0.09,-0.22,0.9),0.05,(1,0.5,1.4)); sph("Bouche",k,(0,-0.24,0.78),0.035)
    for x in (-0.28,0.28): sph("Bras",w,(x,0,0.55),0.07)
# ---------- Chipe-Œufs : décor extérieur ----------
def Arbre():
    cyl("Tronc","6B4423",(0,0,0.6),0.18,1.2,v=8); sph("Feuilles1","3FA34D",(0,0,1.6),0.8,(1,1,0.9)); sph("Feuilles2","56BB5F",(0.35,0.2,2.0),0.5); sph("Feuilles3","2F8A3E",(-0.35,-0.15,1.35),0.45)
def Sapin():
    cyl("Tronc","5A3A22",(0,0,0.3),0.14,0.6,v=8)
    for i,(r,z) in enumerate(((0.8,0.9),(0.62,1.5),(0.42,2.0))): cone("Etage","2E7D4F",(0,0,z),r,0.0,0.9,v=8)
def Rocher():
    sph("Roche1","8A8F98",(0,0,0.3),0.5,(1.1,0.9,0.7),7,5); sph("Roche2","737883",(0.4,0.2,0.2),0.3,(1,1,0.8),7,5)
def Buisson():
    sph("Feuille1","3C9E48",(0,0,0.3),0.42,(1.1,1,0.8)); sph("Feuille2","57B862",(0.3,0.1,0.25),0.3); sph("Baie1","D9322F",(0.1,-0.35,0.4),0.06); sph("Baie2","D9322F",(-0.2,-0.3,0.3),0.06)
def PontBois():
    w="9A6A3A"; d="6B4423"
    for i in range(10): box("Planche",w,(0,-2.0+i*0.44,0.12),(1.6,0.38,0.1))
    for s in (-0.78,0.78):
        box("Rampe",d,(s,0,0.7),(0.08,4.4,0.08)); 
        for i in range(5): box("Poteau",d,(s,-2.0+i*1.0,0.4),(0.12,0.12,0.8))
def Cabane():
    w="B27A45"; r="B0432E"; d="4A2B15"
    box("Murs",w,(0,0,0.9),(2.4,2.0,1.8)); cone("Toit",r,(0,0,2.3),1.9,0.1,1.2,(0,0,math.pi/4),4); box("Porte",d,(0,-1.02,0.7),(0.6,0.05,1.4)); box("Fenetre","9FD8F0",(0.8,-1.02,1.1),(0.5,0.04,0.5)); box("Cheminee","7A5B4B",(0.7,0.4,2.6),(0.3,0.3,0.7))
def Barriere():
    w="A3753F"
    for i in range(4): box("Poteau",w,(-1.5+i*1.0,0,0.45),(0.12,0.12,0.9))
    box("Lisse1",w,(0,0,0.7),(3.1,0.07,0.1)); box("Lisse2",w,(0,0,0.4),(3.1,0.07,0.1))
def Fontaine():
    s="B8BEC6"; e="5DB7E8"
    cyl("Bassin",s,(0,0,0.2),1.3,0.4,v=16); cyl("Eau",e,(0,0,0.42),1.15,0.06,v=16); cyl("Pilier",s,(0,0,0.9),0.18,1.0,v=10); cyl("Vasque",s,(0,0,1.45),0.55,0.14,v=14); sph("Jet",e,(0,0,1.75),0.22,(1,1,1.4))
def NidOeufs():
    p="B88A4E"; d="8A6234"
    torus("Anneau1",p,(0,0,0.1),0.55,0.14,(0,0,0)); torus("Anneau2",d,(0,0,0.22),0.42,0.12); cyl("Fond",d,(0,0,0.05),0.45,0.08,v=12)
    for i in range(10): a=i*0.63; cyl("Brindille",d,(0.58*math.cos(a),0.58*math.sin(a),0.2),0.03,0.5,(math.pi/2,0,a),5)
for name, fn in list(globals().items()):
    if callable(fn) and getattr(fn, "__module__", "") == "__main__" and name[0].isupper() and not name.startswith("_"): reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
print("OK", len(M), "modeles")
