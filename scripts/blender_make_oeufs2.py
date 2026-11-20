import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
def reg(fn):
    reset(); fn(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx")); M[fn.__name__] = {"parts": n, "faces": t}
def quad(name, body, head, ear, tail_c, dark, eye, h=3.0, L=5.0, floppy=False, long_snout=False):
    s = h/3.0
    box("Corps", body, (0,0,1.7*s), (1.6*s, L*0.6, 1.5*s)); box("Ventre", head if False else body, (0,0,1.35*s), (1.3*s, L*0.55, 0.6*s))
    sph("Tete", body, (0,-L*0.38,2.3*s), 0.85*s, (1,1.1,0.95))
    box("Museau", body if not long_snout else ear, (0,-L*0.5-0.2,2.1*s), (0.7*s, (1.1 if long_snout else 0.7)*s, 0.55*s)); sph("Nez", dark, (0,-L*0.5-0.2-(0.55 if long_snout else 0.35)*s,2.2*s), 0.16*s)
    for sx in (-1,1):
        sph("Oeil", eye, (sx*0.42*s,-L*0.38-0.62*s,2.55*s), 0.15*s)
        if floppy: box("Oreille", ear, (sx*0.8*s,-L*0.35,2.2*s), (0.25*s,0.5*s,0.9*s))
        else: cone("Oreille", ear, (sx*0.5*s,-L*0.33,3.0*s), 0.28*s, 0.0, 0.7*s, v=4)
        for fy in (-L*0.22, L*0.22): box("Patte", body, (sx*0.55*s, fy, 0.65*s), (0.4*s,0.4*s,1.3*s))
    cone("Queue", tail_c, (0,L*0.42,2.0*s), 0.3*s, 0.12*s, 1.4*s, (math.radians(-65),0,0), 6)
def guards_dog(): quad("dog","A07850","A07850","6B4A2B","A07850","1A1A1A","1A1A1A",3.0,5.0,True); box("Collier","D63A3A",(0,-1.9,2.0),(1.3,0.25,0.3)) if False else None
def guards_wolf(): quad("wolf","8C8C99","8C8C99","6E6E7A","6E6E7A","1A1A1A","FFD23F",4.0,7.0,False,True)
def guards_bear():
    b="5A3C28"; a="6E7280"; e="FF5050"
    box("Corps",b,(0,0,2.8),(3.4,2.6,3.6)); sph("Tete",b,(0,-0.3,5.2),1.3); sph("Museau","A68A6A",(0,-1.4,4.9),0.55,(1,1,0.7)); sph("Nez","111111",(0,-1.85,5.0),0.2)
    for s in (-1,1):
        sph("OreilleOurs",b,(s*0.95,-0.1,6.3),0.4); sph("Oeil",e,(s*0.5,-1.2,5.4),0.18); box("Epaulette",a,(s*2.0,0,4.4),(1.0,1.2,0.4)); box("Bras",b,(s*2.1,0,2.8),(0.9,1.0,2.6)); box("Jambe",b,(s*0.9,0,0.9),(1.1,1.2,1.8))
    box("Plastron",a,(0,-1.35,3.2),(2.6,0.2,2.0))
def guards_knight():
    a="7A7F8C"; p="D63A3A"; s="C9A227"
    box("Corps",a,(0,0,2.6),(2.0,1.2,2.8)); sph("Casque",a,(0,0,4.7),0.9); box("Visiere","1A1A22",(0,-0.8,4.7),(1.0,0.1,0.25)); cone("Plume",p,(0,0,5.7),0.25,0.0,1.2,v=4)
    for x in (-1,1): box("Jambe",a,(x*0.5,0,0.9),(0.7,0.8,1.8)); box("Bras",a,(x*1.35,0,2.8),(0.5,0.6,2.2))
    cyl("Lance","785028",(1.9,-0.2,3.0),0.07,6.0); cone("Pointe","C8CCD6",(1.9,-0.2,6.1),0.18,0.0,0.6,v=4); box("Bouclier",s,(-1.6,-0.7,2.8),(0.2,1.5,2.0))
def props_mill():
    b="D8C9A8"; r="B0432E"; w="8A5A2B"
    cyl("Tour",b,(0,0,5),2.2,10,v=10); cone("Toit",r,(0,0,11.6),2.7,0.2,3.2,v=10); box("Porte","4A2B15",(0,-2.1,1.2),(1.2,0.2,2.4)); box("Fenetre","9FD8F0",(0,-2.0,6.5),(0.9,0.2,1.1))
    box("Axe",w,(0,-2.4,9.6),(0.5,1.0,0.5))
    for k in range(4):
        a=k*math.pi/2; box("Pales",w,(2.6*math.cos(a)*0+0, -3.0, 9.6+3.4*math.sin(a)*0+0), (0.01,0.01,0.01)) if False else None
    box("Pales",w,(0,-3.0,9.6),(8.0,0.2,0.7)); box("Pales2",w,(0,-3.0,9.6),(0.7,0.2,8.0))
def castle_wall(): box("Mur","8E93A0",(0,0,3.5),(8,2,7)); [box("Creneaux","8E93A0",(-3.0+i*2.0,0,7.6),(1.0,2.0,1.2)) for i in range(4)]
def castle_tower():
    cyl("Corps","8E93A0",(0,0,5),3.0,10,v=12); cyl("Plateforme","8E93A0",(0,0,10.3),3.3,0.8,v=12)
    for i in range(8): a=i*math.pi/4; box("Creneaux","8E93A0",(3.0*math.cos(a),3.0*math.sin(a),11.2),(1.0,1.0,1.2),(0,0,a))
    cone("Toit","7A2A2A",(0,0,13),3.4,0.1,3.4,v=12)
    for z in (4,7): box("Meurtriere","1A1A22",(0,-3.0,z),(0.3,0.1,1.2))
def props_castle():
    s="8E93A0"; r="7A2A2A"
    box("EnceinteN",s,(0,30,5),(70,3,10)); box("EnceinteS1",s,(-22,-30,5),(26,3,10)); box("EnceinteS2",s,(22,-30,5),(26,3,10)); box("EnceinteE",s,(35,0,5),(3,60,10)); box("EnceinteO",s,(-35,0,5),(3,60,10))
    for x in (-35,35):
        for y in (-30,30): cyl("Tour",s,(x,y,8),4.5,16,v=12); cone("ToitTour",r,(x,y,19),5.2,0.2,6,v=12)
    box("Herse","4A4A52",(0,-30,4),(8,0.6,8)); box("Donjon",s,(0,10,10),(24,18,20)); cone("ToitDonjon",r,(0,10,24),16,0.5,9,(0,0,math.pi/4),4)
    for x in (-8,8): cyl("Mat","785028",(x,10,28),0.2,8,v=6); box("Drapeau","D63A3A",(x+1.6,10,31),(3,0.1,1.6))
def castle_door(): box("Cadre","6B5A3C",(0,0,4),(8,1.2,8)); [box("Herse","4A4A52",(-3.2+i*1.07,0,3.6),(0.3,0.3,7.0)) for i in range(7)]; box("Barre","4A4A52",(0,0,3),(7.4,0.3,0.3)); box("Barre2","4A4A52",(0,0,5.5),(7.4,0.3,0.3))
def castle_floor(): box("Dalle","A7ABB5",(0,0,0.3),(8,8,0.6)); box("Joint1","6E7280",(0,0,0.62),(0.12,8,0.04)); box("Joint2","6E7280",(0,0,0.62),(8,0.12,0.04))
def trap_spikes():
    box("Plaque","55555F",(0,0,0.3),(6,6,0.6))
    for i in range(3):
        for j in range(3): cone("Pics","C8CCD6",(-2+i*2,-2+j*2,1.4),0.35,0.0,1.6,v=4)
def trap_blade(): box("Bras","4A4A52",(0,0,0.5),(1,1,1)); cyl("Lame","D0D4DE",(0,0,0.5),5,0.3,v=16); [cone("Dent","D0D4DE",(5.0*math.cos(i*math.pi/4),5.0*math.sin(i*math.pi/4),0.5),0.5,0.0,1.0,(0,math.pi/2,i*math.pi/4),4) for i in range(8)]
def trap_ball(): sph("Boulet","7A7F8C",(0,0,3),3.0,seg=14,rings=9); torus("Bandes","3A3A42",(0,0,3),3.0,0.15,(math.pi/2,0,0)); torus("Bandes2","3A3A42",(0,0,3),3.0,0.15,(0,0,0))
def props_chest():
    w="96622C"; g="E8B923"
    box("Caisse",w,(0,0,0.8),(3,2,1.6)); cyl("Couvercle",w,(0,0,1.6),1.0,3,(0,math.pi/2,0),14); box("Bande1",g,(-1.0,0,1.1),(0.2,2.1,2.2)); box("Bande2",g,(1.0,0,1.1),(0.2,2.1,2.2)); box("Serrure",g,(0,-1.05,1.3),(0.4,0.1,0.5))
def props_torch(): box("Support","4A4A52",(0,0,1.2),(0.35,0.35,2.4)); cyl("Coupe","4A4A52",(0,0,2.5),0.35,0.3,v=8); cone("Flamme","FF9640",(0,0,3.2),0.3,0.0,1.1,v=6)
def props_flag(): cyl("Mat","785028",(0,0,4),0.15,8,v=6); box("Toile","D63A3A",(1.3,0,6.8),(2.6,0.08,1.8)); sph("Pointe","E8B923",(0,0,8.1),0.22)
def props_sign(): cyl("Poteau","785028",(0,0,2),0.18,4,v=6); box("Planche","785028",(0,-0.1,4),(3.2,0.2,1.4)); box("Flèche","E8B923",(0,-0.22,4),(2.4,0.04,0.4))
def props_pen():
    w="96622C"; g="FFD23F"
    for i in range(11):
        for side in (-20,20): box("Poteau",w,(-20+i*4,side,2),(0.5,0.5,4))
        if i not in (4,5,6): pass
    for side in (-20,20): box("Lisse",w,(0,side,2.6),(40,0.3,0.4)); box("Lisse2",w,(0,side,1.2),(40,0.3,0.4))
    for side in (-20,20): box("Lisse",w,(side,0,2.6),(0.3,40,0.4)); box("Lisse2",w,(side,0,1.2),(0.3,40,0.4))
    for sx in (-20,20):
        for sy in (-20,20): box("Angle",g,(sx,sy,4.3),(0.9,0.9,0.5))
def ground_grass():
    box("Herbe","5CA052",(0,0,0.25),(16,16,0.5))
    for i in range(6): cone("Touffe","6BB85E",(-6+i*2.4,((-1)**i)*3,0.9),0.5,0.0,0.9,v=4)
    for i,c in enumerate(("FFD23F","FF7896","FFD23F","FF7896")): sph("Fleur",c,(-4+i*2.6,-5+(i%2)*9,0.7),0.2)
def ground_path(): box("Terre","C4B494",(0,0,0.15),(8,8,0.3)); [sph("Cailloux","8E93A0",(-2.5+i*1.6,-2+(i%3)*2,0.4),0.25,(1,1,0.6),6,4) for i in range(5)]
def ground_plaza(): [cyl("Paves","C4B8A0",(-4.2+(i%3)*4.2,-4.2+(i//3)*4.2,0.15),2.0,0.3,v=10) for i in range(9)]
def props_lamp(): cyl("Mat","32343C",(0,0,3.5),0.18,7,v=6); box("Support","32343C",(0,0,7.1),(0.9,0.9,0.2)); box("Lanterne","FFEBAA",(0,0,7.7),(0.7,0.7,1.0)); cone("Chapeau","32343C",(0,0,8.5),0.7,0.0,0.6,v=4)
def props_bench(): box("Assise","96622C",(0,0,1.0),(6,1.6,0.3)); box("Dossier","96622C",(0,0.7,1.8),(6,0.25,1.3)); [box("Pieds","96622C",(x,0,0.5),(0.4,1.4,1.0)) for x in (-2.6,2.6)]
# pets (1 stud) 
def PetHamster(): sph("Corps","D9A066",(0,0,0.4),0.38,(1,1.1,0.95)); sph("Tete","D9A066",(0,-0.25,0.62),0.26); sph("Joues","F2D2A8",(0,-0.42,0.52),0.2,(1.2,0.6,0.7)); [sph("Oreille","B07A44",(s*0.17,-0.2,0.88),0.08) for s in (-1,1)]; [sph("Oeil","111111",(s*0.1,-0.45,0.68),0.035) for s in (-1,1)]
def PetChat():
    c="8A8A92"; sph("Corps",c,(0,0,0.38),0.32,(0.8,1.3,1)); sph("Tete",c,(0,-0.38,0.66),0.24); [cone("Oreille",c,(s*0.15,-0.36,0.92),0.09,0.0,0.22,v=4) for s in (-1,1)]; [sph("Oeil","8BE08B",(s*0.09,-0.58,0.7),0.04) for s in (-1,1)]; cone("Queue",c,(0,0.4,0.6),0.06,0.03,0.7,(math.radians(-40),0,0),6)
def PetChienPet():
    c="C98F55"; sph("Corps",c,(0,0,0.38),0.3,(0.85,1.3,1)); sph("Tete",c,(0,-0.4,0.64),0.24); [box("Oreille","7A4A22",(s*0.24,-0.38,0.62),(0.08,0.14,0.3)) for s in (-1,1)]; sph("Nez","111111",(0,-0.62,0.62),0.05); cone("Queue",c,(0,0.42,0.55),0.07,0.03,0.4,(math.radians(-50),0,0),6)
def PetHibou():
    c="8B6B4A"; sph("Corps",c,(0,0,0.45),0.36,(1,0.9,1.3)); sph("Tete",c,(0,-0.05,0.95),0.26); [cone("Oreille",c,(s*0.17,0,1.2),0.07,0.0,0.2,v=4) for s in (-1,1)]; [sph("Oeil","FFD23F",(s*0.1,-0.26,0.98),0.09) for s in (-1,1)]; cone("Bec","E8892B",(0,-0.3,0.88),0.06,0.0,0.16,(math.pi/2,0,0),4)
def PetManchot():
    sph("Corps","1E2230",(0,0,0.45),0.36,(1,0.9,1.4)); sph("Ventre","F2F2F2",(0,-0.18,0.4),0.28,(0.9,0.6,1.2)); sph("Tete","1E2230",(0,0,1.0),0.22); cone("Bec","E8892B",(0,-0.22,0.98),0.06,0.0,0.16,(math.pi/2,0,0),4); [sph("Oeil","FFFFFF",(s*0.09,-0.19,1.05),0.04) for s in (-1,1)]; [box("Patte","E8892B",(s*0.14,-0.05,0.04),(0.16,0.28,0.06)) for s in (-1,1)]
def PetLion():
    c="D9A84F"; sph("Criniere","8A4B1F",(0,-0.3,0.65),0.38); sph("Corps",c,(0,0.1,0.38),0.3,(0.9,1.4,1)); sph("Tete",c,(0,-0.35,0.65),0.24); [sph("Oeil","111111",(s*0.09,-0.56,0.7),0.035) for s in (-1,1)]; cone("Queue",c,(0,0.55,0.4),0.05,0.03,0.6,(math.radians(-30),0,0),6); sph("BoutQueue","8A4B1F",(0,0.8,0.28),0.09)
def PetLicorne():
    c="F6F0FF"; sph("Corps",c,(0,0,0.5),0.3,(0.85,1.5,1)); sph("Tete",c,(0,-0.5,0.85),0.22); cone("Corne","FFD23F",(0,-0.5,1.2),0.07,0.0,0.4,v=5); [sph("Oeil","6B4BD6",(s*0.09,-0.7,0.88),0.04) for s in (-1,1)]; sph("Criniere","FF7ACB",(0,-0.3,0.95),0.18,(0.6,1.2,1)); cone("Queue","FF7ACB",(0,0.5,0.55),0.1,0.03,0.6,(math.radians(-40),0,0),6)
    for sx in (-0.15,0.15):
        for fy in (-0.28,0.28): box("Patte",c,(sx,fy,0.15),(0.1,0.1,0.3))
def PetTRex():
    g="4E9A3F"; sph("Corps",g,(0,0,0.55),0.34,(0.9,1.5,1.2)); sph("Tete",g,(0,-0.55,0.95),0.26,(1,1.3,0.9)); [sph("Oeil","FFD23F",(s*0.12,-0.7,1.05),0.05) for s in (-1,1)]; [box("Bras",g,(s*0.2,-0.3,0.55),(0.06,0.18,0.06)) for s in (-1,1)]; cone("Queue",g,(0,0.6,0.45),0.2,0.03,0.9,(math.radians(-80),0,0),6); [box("Jambe",g,(s*0.16,0.05,0.18),(0.14,0.2,0.36)) for s in (-1,1)]; [cone("Dent","FFFFFF",(s*0.08,-0.8,0.86),0.03,0.0,0.1,(math.pi,0,0),4) for s in (-1,1)]
for name, fn in list(globals().items()):
    if callable(fn) and getattr(fn,"__module__","")=="__main__" and name[0].islower() and (name.startswith(("props_","guards_","castle_","trap_","ground_"))) or name.startswith("Pet") and name in ("PetHamster","PetChat","PetChienPet","PetHibou","PetManchot","PetLion","PetLicorne","PetTRex"): reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1); print("OK", len(M))
