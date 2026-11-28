import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[1]; M = {}
def reg(fn):
    reset(); fn(); n, t = export(os.path.join(OUT, fn.__name__ + ".fbx")); M[fn.__name__] = {"parts": n, "faces": t}
# Style « chibi » : grosse tête, petit corps, grands yeux brillants, joues roses. Hauteur ≈ 1, devant = -y, origine au sol.
def chibi(body, belly=None, head=None, cheeks="FF9AA8", eye="1A1A1A", feet=None, headr=0.36, bodyr=0.30, nose="2A1A1A", mouth=True):
    head = head or body; feet = feet or body
    sph("Corps", body, (0,0.02,0.36), bodyr, (1,1.0,0.95), seg=14, rings=9)
    if belly: sph("Ventre", belly, (0,-0.12,0.34), bodyr*0.78, (0.85,0.55,0.85), seg=12, rings=7)
    sph("Tete", head, (0,-0.04,0.80), headr, (1,0.95,0.92), seg=16, rings=10)
    for s in (-1,1):
        sph("Oeil", eye, (s*0.14,-0.33,0.84), 0.075, (1,0.6,1.2), seg=10, rings=6)
        sph("Reflet", "FFFFFF", (s*0.125,-0.375,0.875), 0.03, seg=6, rings=4)
        sph("Joue", cheeks, (s*0.25,-0.29,0.73), 0.06, (1,0.4,0.8), seg=8, rings=5)
        sph("Pied", feet, (s*0.14,-0.08,0.07), 0.095, (1,1.25,0.7), seg=8, rings=5)
    sph("Nez", nose, (0,-0.375,0.76), 0.035, seg=6, rings=4)
def ears_round(c,inner=None,r=0.13,y=-0.04,s=0.27,z=1.1):
    for k in (-1,1):
        sph("Oreille",c,(k*s,y,z),r,(1,0.6,1),seg=10,rings=6)
        if inner: sph("Oreille_Int",inner,(k*s,y-0.04,z),r*0.6,(1,0.4,1),seg=8,rings=5)
def ears_point(c,inner=None,h=0.26,s=0.2,z=1.12):
    for k in (-1,1):
        cone("Oreille",c,(k*s,-0.02,z),0.12,0.0,h,(0,k*0.25,0),4)
        if inner: cone("Oreille_Int",inner,(k*s,-0.07,z-0.02),0.07,0.0,h*0.7,(0,k*0.25,0),4)
def tail_ball(c,y=0.34,z=0.32,r=0.1): sph("Queue",c,(0,y,z),r,seg=8,rings=5)
def tail_cone(c,y=0.33,z=0.33,r=0.1,h=0.5,rx=-50): cone("Queue",c,(0,y,z),r,0.03,h,(math.radians(rx),0,0),7)
def wings(c,s=0.3,z=0.45,w=0.28,h=0.22):
    for k in (-1,1): sph("Aile",c,(k*s,0.05,z),w,(0.35,0.8,1.0),seg=9,rings=6)
def PetPoussin(): chibi("FFDD57","FFF0A0",cheeks="FF9A7A",feet="FF9A2A",bodyr=0.32); cone("Bec","FF9A2A",(0,-0.4,0.77),0.065,0.0,0.15,(math.pi/2,0,0),5); wings("FFC93A"); cone("Touffe","FFC93A",(0,-0.02,1.2),0.05,0.0,0.18,v=5)
def PetHamster(): chibi("DEB887","FFF1D6",cheeks="FF9AA8"); ears_round("C79A67","FFC2B0"); [sph("Joue","DEB887",(k*0.28,-0.27,0.72),0.11,(1,0.8,1),seg=8,rings=5) for k in (-1,1)]
def PetLapin(): chibi("F5F5F5","FFFFFF",feet="F5F5F5"); [(cone("Oreille","F5F5F5",(k*0.14,0.0,1.38),0.09,0.05,0.55,(0,k*0.12,0),8), cone("Oreille_Int","FFB6C8",(k*0.14,-0.05,1.38),0.05,0.03,0.4,(0,k*0.12,0),6)) for k in (-1,1)]; tail_ball("FFFFFF")
def PetChat(): chibi("969AA6","E8E8F0",cheeks="FFB0BC"); ears_point("969AA6","FFB0BC"); tail_cone("969AA6",rx=-70,h=0.65); [box("Rayure","6A6E7A",(0,-0.3,0.99+i*0.0),(0.06,0.05,0.12)) for i in range(0)]; [cone("Moustache","FFFFFF",(k*0.26,-0.33,0.73),0.012,0.012,0.22,(0,0,k*1.4),4) for k in (-1,1)]
def PetChien(): chibi("A06E46","F0DCC0"); [box("Oreille","6E4A2E",(k*0.33,-0.02,0.82),(0.12,0.2,0.34),(0,0,k*0.2)) for k in (-1,1)]; sph("Museau","F0DCC0",(0,-0.36,0.72),0.13,(1,0.8,0.8),seg=8,rings=5); sph("Langue","FF6A8A",(0,-0.42,0.66),0.05,(0.8,0.5,1),seg=6,rings=4); tail_cone("A06E46",rx=-60,h=0.4)
def PetRenard(): chibi("F08232","FFF2E0",cheeks="FFB08A"); ears_point("F08232","2A1A1A",h=0.3); sph("Museau","FFF2E0",(0,-0.36,0.73),0.11,(1,0.9,0.7),seg=8,rings=5); tail_cone("F08232",rx=-40,h=0.7,r=0.16); sph("Queue_Pointe","FFF2E0",(0,0.62,0.58),0.1,seg=8,rings=5)
def PetPanda(): chibi("FAFAFA","FFFFFF",feet="2A2A2A"); ears_round("2A2A2A",None,r=0.12); [sph("Tache","2A2A2A",(k*0.15,-0.3,0.85),0.1,(1,0.5,1.3),seg=8,rings=5) for k in (-1,1)]; [sph("Bras","2A2A2A",(k*0.3,-0.05,0.4),0.09,(0.8,1,1.3),seg=8,rings=5) for k in (-1,1)]
def PetHibou(): chibi("8B6B4A","D8B890",eye="FFD23F",headr=0.38); ears_point("8B6B4A",None,h=0.2,s=0.22,z=1.12); [sph("Disque","F3E6C8",(k*0.14,-0.31,0.84),0.12,(1,0.4,1),seg=8,rings=5) for k in (-1,1)]; cone("Bec","E8892B",(0,-0.4,0.77),0.06,0.0,0.14,(math.pi/2,0,0),4); wings("6A4E32")
def PetManchot(): chibi("1E2A44","F2F2F2",feet="FF9A2A",cheeks="FF9AA8"); cone("Bec","FF9A2A",(0,-0.4,0.77),0.07,0.0,0.14,(math.pi/2,0,0),5); wings("1E2A44",s=0.31)
def PetLion(): sph("Criniere","8A4B1F",(0,0.0,0.82),0.5,(1,0.6,1),seg=14,rings=9); chibi("E6B450","F5DDA0",cheeks="FFB08A"); ears_round("E6B450","8A4B1F",r=0.1,z=1.1,s=0.3); tail_cone("E6B450",rx=-60,h=0.5); sph("Queue_Touffe","8A4B1F",(0,0.58,0.5),0.1,seg=8,rings=5)
def PetTigre(): chibi("F58C28","FFF2DC"); ears_round("F58C28","FFE0C0",r=0.11); [box("Rayure","2A1A1A",(0,-0.0,0.7+i*0.1),(0.34,0.04,0.045)) for i in range(3)]; [box("Rayure","2A1A1A",(k*0.2,-0.32,0.95),(0.04,0.05,0.12)) for k in (-1,1)]; tail_cone("F58C28",rx=-55,h=0.6); sph("Queue_Bout","2A1A1A",(0,0.6,0.58),0.07,seg=8,rings=5)
def PetLicorne(): chibi("FFF0FA","FFFFFF",cheeks="FFB0D8"); ears_point("FFF0FA","FFB0D8",h=0.22,s=0.2,z=1.06); cone("Corne","FFD23F",(0,-0.08,1.25),0.07,0.0,0.4,v=6); [sph("Criniere",c,(0,0.05+i*0.0,1.1-i*0.2) ,0.18-i*0.02,(0.7,0.7,1.1),seg=8,rings=5) for i,c in enumerate(("FF7ACB","8AA8FF","7AE0C0"))]; tail_cone("FF7ACB",rx=-60,h=0.55,r=0.12)
def PetDragon(): chibi("D23232","F8DCA0",cheeks="FF9A6A",eye="FFD23F"); [cone("Corne","FFE08A",(k*0.2,-0.02,1.2),0.06,0.0,0.24,(0,k*0.3,0),5) for k in (-1,1)]; [sph("Aile","8A1E1E",(k*0.38,0.12,0.62),0.3,(0.12,0.9,1.1),seg=9,rings=6) for k in (-1,1)]; tail_cone("D23232",rx=-70,h=0.7,r=0.13); [cone("Pic","FFE08A",(0,0.05+i*0.1,0.66+0.0),0.05,0.0,0.14,v=4) for i in range(0)]
def PetTRex(): chibi("50AA50","E8F0A0",cheeks="FFB08A",eye="FFD23F",headr=0.4); sph("Museau","50AA50",(0,-0.4,0.74),0.17,(1,0.9,0.7),seg=9,rings=6); [cone("Dent","FFFFFF",(k*0.08,-0.5,0.7),0.025,0.0,0.07,(math.pi,0,0),4) for k in (-1,1)]; [box("Bras","50AA50",(k*0.2,-0.2,0.42),(0.06,0.14,0.06)) for k in (-1,1)]; tail_cone("50AA50",rx=-80,h=0.85,r=0.17)
def PetKraken(): chibi("8C46BE","C8A0E0",cheeks="FFA0C8",feet="8C46BE",headr=0.4); [(cone("Tentacule","8C46BE",(math.cos(i*math.pi/4)*0.27,math.sin(i*math.pi/4)*0.27,0.16),0.07,0.025,0.42,(math.sin(i*math.pi/4)*-0.5,math.cos(i*math.pi/4)*0.5,0),6)) for i in range(8)]; sph("Couronne","FFD23F",(0,-0.04,1.2),0.07,seg=8,rings=5)
def PetAlien(): chibi("78DC6E","C8F0C0",cheeks="A0F0A0",eye="1A1A1A",headr=0.4); [(cyl("Antenne","78DC6E",(k*0.12,-0.04,1.28),0.02,0.28,(0,k*0.2,0),5), sph("Antenne_Orbe","FFE860",(k*0.16,-0.04,1.44),0.06,seg=8,rings=5)) for k in (-1,1)]
def PetCalmar(): chibi("3CBEC8","BFF0F4",cheeks="FFB0D0",headr=0.38); cone("Manteau","3CBEC8",(0,0.05,1.12),0.2,0.0,0.35,v=8); [(cone("Tentacule","3CBEC8",(math.cos(i*0.628)*0.22,math.sin(i*0.628)*0.22,0.15),0.05,0.02,0.38,(math.sin(i*0.628)*-0.4,math.cos(i*0.628)*0.4,0),5)) for i in range(10)]; [sph("Etoile","FFF6A0",(0,0.0+i*0.02,1.22+i*0.04),0.035,seg=6,rings=4) for i in range(3)]
def PetWyrm(): chibi("5096FF","BCDCFF",cheeks="FFB0D0",eye="FFF6A0"); [cone("Corne","FFE08A",(k*0.2,-0.02,1.2),0.05,0.0,0.26,(0,k*0.3,0),5) for k in (-1,1)]; [sph("Aile","BCDCFF",(k*0.4,0.1,0.65),0.3,(0.1,0.9,1.1),seg=9,rings=6) for k in (-1,1)]; [sph("Anneau","5096FF" if i%2==0 else "8CC2FF",(0,0.4+i*0.15,0.3-i*0.025),0.17-i*0.02,seg=9,rings=6) for i in range(5)]; [cone("Dos","FFE08A",(0,0.0+i*0.15,0.64-i*0.02),0.04,0.0,0.12,v=4) for i in range(4)]
for fn in [globals()[k] for k in list(globals()) if k.startswith("Pet")]: reg(fn)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1); print("OK", len(M), {k:(v["parts"],v["faces"]) for k,v in M.items()})
