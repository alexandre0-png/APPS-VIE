import sys, os, math, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
from blender_lib import _fin
OUT = sys.argv[1]; M = {}
R = math.radians
def bbox():
    mn=[1e9]*3; mx=[-1e9]*3
    for o in bpy.context.scene.objects:
        if o.type!="MESH": continue
        for c in o.bound_box:
            w=o.matrix_world@__import__("mathutils").Vector(c)
            for i in range(3): mn[i]=min(mn[i],w[i]); mx[i]=max(mx[i],w[i])
    return [round(mx[i]-mn[i],1) for i in range(3)], [round(mn[i],1) for i in range(3)], [round(mx[i],1) for i in range(3)]
def reg(fn):
    reset(); fn(); n,t = export(os.path.join(OUT, fn.__name__ + ".fbx"))
    s,a,b = bbox(); M[fn.__name__] = {"parts": n, "size": s, "min": a, "max": b}; print(fn.__name__, n, s, a, b)
GL="9FD8F2"
def wf(x,yf,z,w=3,h=3.6,fr="FFFFFF",sh=None,gl=GL):
    box("Cadre",fr,(x,yf-0.1,z),(w+0.8,0.3,h+0.8)); box("Fenetre_Verre",gl,(x,yf-0.28,z),(w,0.2,h))
    if sh:
        for s in (-1,1): box("Volet",sh,(x+s*(w/2+0.85),yf-0.2,z),(0.9,0.25,h+0.8))
def ws(xf,y,z,s,w=3,h=3.6,fr="FFFFFF",gl=GL):
    box("Cadre",fr,(xf+s*0.1,y,z),(0.3,w+0.8,h+0.8)); box("Fenetre_Verre",gl,(xf+s*0.28,y,z),(0.2,w,h))
def door(x,yf,z0,w,h,col,fr="FFFFFF",knob=True):
    box("Cadre",fr,(x,yf-0.08,z0+h/2+0.2),(w+0.8,0.2,h+0.4)); box("Porte",col,(x,yf-0.25,z0+h/2),(w,0.2,h))
    if knob: box("Poignée","E8C547",(x+w/2-0.5,yf-0.45,z0+h*0.45),(0.3,0.25,0.3))
def stairs(x,yf,zt,w,n,col,col2=None):
    for i in range(n):
        h=zt*(n-i)/n; box("Marche",col if i%2==0 or not col2 else col2,(x,yf-0.5-i*1.0,h/2),(w,1.0,h))
def railx(x0,x1,y,z0,h,col,posts=4):
    L=x1-x0; box("Rambarde",col,((x0+x1)/2,y,z0+h),(L,0.25,0.25))
    for i in range(posts): box("Poteau",col,(x0+L*i/(posts-1),y,z0+h/2),(0.25,0.25,h))
def raily(y0,y1,x,z0,h,col,posts=4):
    L=y1-y0; box("Rambarde",col,(x,(y0+y1)/2,z0+h),(0.25,L,0.25))
    for i in range(posts): box("Poteau",col,(x,y0+L*i/(posts-1),z0+h/2),(0.25,0.25,h))
def chimney(x,y,zb,h,col,cap="6B6B73",w=1.6):
    box("Cheminee",col,(x,y,zb+h/2),(w,w,h)); box("Cheminee_Haut",cap,(x,y,zb+h+0.2),(w+0.5,w+0.5,0.4))
def slab(ax,a0,z0,a1,z1,o0,o1,t,col,ov=0.7):
    da,dz=a1-a0,z1-z0; L0=math.hypot(da,dz); ua,uz=da/L0,dz/L0
    sa,sz=a0-ua*ov,z0-uz*ov; L=math.hypot(a1-sa,z1-sz)+0.25
    ca,cz=(sa+a1)/2,(sz+z1)/2+t*0.5; phi=math.atan2(dz,da)
    if ax=="y": box("Toit",col,(ca,(o0+o1)/2,cz),(L,o1-o0,t),(0,-phi,0))
    else: box("Toit",col,((o0+o1)/2,ca,cz),(o1-o0,L,t),(phi,0,0))
def roof(ax,a0,a1,o0,o1,zb,h,col,col2=None,ov=0.8,t=0.45):
    # ax="y": crête le long de y, pentes en x ; ax="x": crête le long de x
    m=(a0+a1)/2; slab(ax,a0,zb,m,zb+h,o0-ov,o1+ov,t,col,ov); slab(ax,a1,zb,m,zb+h,o0-ov,o1+ov,t,col2 or col,ov)
def fill(ax,a0,a1,pos,zb,h,col,th=0.5,n=3):
    half=(a1-a0)/2; m=(a0+a1)/2
    for i in range(n):
        w=2*half*(1-(i+0.6)/n); hh=h/n
        if ax=="y": box("Pignon",col,(m,pos,zb+hh*(i+0.5)),(w,th,hh+0.02))
        else: box("Pignon",col,(pos,m,zb+hh*(i+0.5)),(th,w,hh+0.02))
def bush(x,y,r=1.2,col="4FAE5A"): sph("Buisson",col,(x,y,r*0.8),r,(1,1,1.0),seg=8,rings=5)
def barrel(x,y,col="B5763A"): cyl("Tonneau",col,(x,y,0.9),0.8,1.8,v=8)
def lamp(x,y,z,col="3A3F4B"): box("Support_Lampe",col,(x,y,z),(0.3,0.3,0.5)); sph("Lanterne","FFE9A8",(x,y-0.3,z-0.4),0.35,seg=8,rings=5)
def base(w,d,y0,col="8C8C94",h=0.4): box("Fondation",col,(0,y0+d/2,h/2),(w,d,h))

def house_lvl2():
    wall="F6D79A"; tr="FFFFFF"; wood="C98B4A"; rf="5FA8D3"; rf2="3C7FB0"
    for sx in (-8.5,8.5):
        for y in (3.5,15.5): box("Pilotis","8A5A33",(sx,y,1.2),(0.8,0.8,2.4))
    box("Plancher","A8743A",(0,9.5,2.25),(19,15.5,0.5))
    box("Mur",wall,(0,9.5,6.0),(18,15,7))
    box("Soubassement","D9B26B",(0,9.5,3.0),(18.3,15.3,1.0))
    box("Terrasse",wood,(0,-2,2.3),(24,8,0.4))
    for sx in (-11.5,11.5):
        box("Poteau",tr,(sx,-5.4,5.0),(0.5,0.5,5.4))
    box("Auvent","E0605A",(0,-2.0,7.9),(25,8.6,0.4),(R(-8),0,0))
    for (a,b) in ((-11.5,-2.2),(2.2,11.5)): railx(a,b,-5.7,2.5,1.4,tr,3)
    for sx in (-11.7,11.7): raily(-5.7,1.6,sx,2.5,1.4,tr,3)
    stairs(0,-5.8,2.5,4,5,"D9B26B","C98B4A")
    for sx in (-2.3,2.3): box("Rambarde",tr,(sx,-8.0,2.6),(0.2,5.0,0.2),(R(-27),0,0)) if False else box("Rambarde",tr,(sx,-8.3,2.9),(0.2,5.4,0.2),(R(26),0,0))
    door(0,2.0,2.5,3.2,5.0,"D9534F"); wf(-6,2.0,5.6,3.2,3.6,tr,"3E8E8A"); wf(6,2.0,5.6,3.2,3.6,tr,"3E8E8A")
    ws(-9,9,5.6,-1); ws(9,9,5.6,1); ws(9,13.5,5.6,1)
    roof("y",-9,9,2,17,9.5,0,rf) if False else None
    for sx,sg in ((-1,1),(1,-1)):
        slab("y",sx*9,9.5,sx*6.2,15,1.2,17.8,0.5,rf)
        slab("y",sx*6.2,15,0,18.6,1.2,17.8,0.45,rf2)
    fill("y",-9,9,2.0,9.5,5.5,wall,0.5,2); fill("y",-9,9,17.0,9.5,5.5,wall,0.5,2)
    box("Pignon","F2C14E",(0,1.8,15.9),(5.6,0.5,2.8))
    box("Porte","D9534F",(0,1.5,11.6),(2.6,0.3,3.6))
    box("Balcon",wood,(0,0.4,9.7),(6.5,2.4,0.3)); railx(-3.1,3.1,-0.7,9.7,1.2,tr,4)
    cyl("Fenetre_Verre",GL,(0,1.55,15.9),0.0001,0.0001) if False else None
    chimney(5.5,13,14.2,6.4,"B5523B")
    cyl("Tuyau","8E9AAF",(-6.5,15.5,16.0),0.3,8,v=6)
    barrel(-8.5,-7.5); bush(10.5,-8.5,1.4,"F28CB1"); bush(-13,-2,1.2)
    lamp(-1.8,1.9,8.6)
    box("Marche_Palier",wood,(0,-4.5,2.4),(4,2,0.2))

def house_lvl3():
    # maison haute étroite à balcons
    w1="A7D8E8"; w2="F9E4A8"; w3="F4B6C2"; tr="FFFFFF"; red="E94F4F"
    base(16,14,2.5)
    box("Mur",w1,(0,9.5,3.5),(13,12,7)); box("Mur",w2,(0,9.5,10.0),(13,12,6))
    box("Corniche","7A8CA3",(0,9.5,7.05),(13.6,12.6,0.3))
    box("Mur",w3,(0,8.5,16.0),(16,13,6)); box("Corniche","7A8CA3",(0,8.5,13.1),(16.6,13.6,0.3))
    box("Toit","6C7A89",(0,8.5,19.2),(17.2,14.2,0.5)); box("Toit_Bord","8E9AAF",(0,8.5,19.6),(17.6,14.6,0.3))
    # auvents rayés (2)
    for ax_,wd in ((-3.6,5.0),(3.6,5.0)):
        for i in range(4):
            box("Auvent",red if i%2==0 else "FFFFFF",(ax_-wd/2+wd*(i+0.5)/4,1.7,6.0),(wd/4,2.6,0.2),(R(-24),0,0))
    door(0,3.5,2.5,2.8,4.3,"7B4A2A"); wf(-4.2,3.5,4.8,2.2,2.6,tr); wf(4.2,3.5,4.8,2.2,2.6,tr)
    stairs(0,3.4,2.5,5,4,"B8B8C2","9A9AA6")
    # balcon étage 2
    box("Balcon","C98B4A",(0,1.8,7.25),(9,3.4,0.3)); railx(-4.5,4.5,0.1,7.25,1.3,tr,5); raily(0.1,3.4,-4.5,7.25,1.3,tr,3); raily(0.1,3.4,4.5,7.25,1.3,tr,3)
    wf(-3,3.5,10.3,2.6,3.2,tr,"3E8E8A"); wf(3.2,3.5,10.3,2.6,3.2,tr,"3E8E8A")
    # étage 3
    wf(-4.2,2.0,16.2,3.0,3.2,tr,"7A8CA3"); torus("Cadre",tr,(3.8,1.9,16.4),1.5,0.2,(R(90),0,0)); cyl("Fenetre_Verre",GL,(3.8,2.0,16.4),1.4,0.2,(R(90),0,0),v=12)
    box("Balcon","C98B4A",(11.2,6,13.4),(6,6,0.3)); railx(8.2,14.2,9.0,13.4,1.3,tr,4); raily(3.0,9.0,14.2,13.4,1.3,tr,4); raily(3.0,9.0,8.2,13.4,1.3,tr,3)
    ws(8.0,6,16.4,1,2.6,3.0,tr)
    # porte de cave roulante + escalier
    box("Cadre","6B6B73",(6.55,10,4.0),(0.5,5.0,3.6)); box("Porte_Cave","8E9AAF",(6.7,10,3.9),(0.3,4.4,3.3))
    ws(-6.5,9,10.3,-1); ws(-6.5,9,16.4,-1) if False else None
    box("Clim","D9D9E0",(-8.3,5,15.5),(0.8,2,1.6)); cyl("Fenetre_Verre","FFFFFF",(-8.8,5,15.5),0.6,0.2,(0,R(90),0),v=8)
    # extérieur
    cyl("Poubelle","4FAE5A",(10.5,5,1.2),0.9,2.4,v=8); cyl("Poubelle_Couvercle","3E8E48",(10.5,5,2.5),1.0,0.25,v=8)
    barrel(-9.5,2); box("Caisse","C9A66B",(-8,-1,0.6),(1.6,1.6,1.2)); box("Caisse","B5763A",(-9.4,-2.2,0.5),(1.2,1.2,1.0))
    cyl("Poteau_Lampadaire","4A4F5C",(-12,-1,6.5),0.25,13,v=6); box("Bras","4A4F5C",(-11,-1,12.8),(2.2,0.25,0.25)); sph("Lanterne","FFF2B0",(-10,-1,12.5),0.5,(1,1,0.6),seg=8,rings=5)
    cyl("Tuyau","8E9AAF",(7.5,12.5,21.5),0.4,4,v=6); cyl("Tuyau_Haut","6B6B73",(7.5,12.5,27.2),0.55,0.5,v=6) if False else None
    cyl("Tuyau","8E9AAF",(-6,13.5,21.5),0.35,4,v=6)

def house_lvl4():
    wall="BFE3B4"; tr="FFFFFF"; roofc="E07A5F"; dark="3D8361"
    base(36,12,5)
    box("Mur",wall,(-6,10.5,4.5),(18,11,9)); box("Mur_Haut","F7E8B0",(-6,10.5,10.4),(18,11,2.8))
    box("Corniche","8C6B4A",(-6,10.5,9.1),(18.6,11.6,0.35))
    roof("x",5.0,16.0,-15,3,11.8,5.0,roofc,"C9664D",0.9)
    for sx in (-15,3): pass
    fill("x",5,16,-15.1,11.8,5.0,"F7E8B0",0.5,3); fill("x",5,16,3.1,11.8,5.0,"F7E8B0",0.5,3)
    chimney(-10,12,15,4.5,"B5523B")
    cyl("Fenetre_Verre",GL,(-6,4.7,16.0),1.0,0.2,(R(90),0,0),v=12) if False else None
    # auvent / véranda
    box("Terrasse","C98B4A",(-8,2.4,0.5),(13,4.6,0.4)) if False else None
    box("Auvent","B04A3C",(-8,1.2,8.0),(15,5,0.35),(R(-14),0,0))
    for x in (-14.5,-1.5): box("Poteau",tr,(x,-0.8,4.0),(0.45,0.45,8))
    stairs(-6,3.8,2.2,5,3,"C9C9D2","A8A8B4")
    door(-6,5.0,2.2,2.8,4.4,"7B4A2A"); wf(-11.5,5.0,5.6,3.0,3.0,tr,dark); wf(-0.7,5.0,5.6,2.6,3.0,tr,dark) 
    wf(-6,5.0,12.3,3.4,2.6,tr,dark); ws(-15,10,5.6,-1); ws(-15,10,12.4,-1,3,2.4)
    box("Soubassement","8C8C94",(-6,10.5,1.1),(18.6,11.6,2.2)) if False else None
    for sy in (0,): railx(-14.5,-1.5,-0.8,2.2,1.3,tr,5)
    # caravane
    box("Caravane","FFD166",(12.5,9.5,2.8),(12,8,4.2)); cyl("Caravane_Toit","FFE08A",(12.5,9.5,4.9),4.0,12,(0,R(90),0),v=12)
    box("Bande","E94F4F",(12.5,5.45,2.4),(12.1,0.15,0.7))
    box("Cadre","FFFFFF",(14.5,5.4,3.6),(3.6,0.2,2.4)); box("Fenetre_Verre",GL,(14.5,5.3,3.6),(3.2,0.2,2.0))
    box("Porte","B04A3C",(9.5,5.4,2.6),(1.8,0.2,3.2))
    cyl("Roue","333844",(15.5,5.0,1.5),1.5,0.7,(R(90),0,0),v=12); cyl("Roue_Moyeu","C0C4CC",(15.5,4.6,1.5),0.6,0.3,(R(90),0,0),v=8)
    box("Timon","6B6B73",(6.3,9.5,1.0),(0.5,4.0,0.4))
    box("Echelle","8E9AAF",(18.7,9.5,4.5),(0.2,0.2,5)) if False else None
    # balcon haut
    box("Balcon","C98B4A",(12.5,2.6,6.6),(0.1,0.1,0.1)) if False else None
    # déco
    barrel(-16,3.5); box("Caisse","C9A66B",(3.5,2,0.7),(1.8,1.8,1.4)); box("Caisse","B5763A",(4,0.2,0.5),(1.1,1.1,1.0))
    bush(8.5,1.5,1.2); cyl("Pot","C0623A",(1.8,3,0.6),0.6,1.2,v=8); sph("Plante","4FAE5A",(1.8,3,1.8),0.8,seg=8,rings=5)
    lamp(-9.4,4.9,8.0)

def house_lvl5():
    # maison à terrasse + garage + portail
    wall="FFC8A2"; tr="FFFFFF"; pur="7B6BA8"; blue="5C8FD6"
    base(39.6,16,3)
    box("Mur",wall,(-7,11,5.0),(14,14,10)); box("Mur_Haut","FFE3C2",(-7,11,12.3),(14,14,4.6))
    box("Corniche","8C6B8A",(-7,11,10.15),(14.6,14.6,0.35))
    roof("y",-14,0,4.0,18.0,14.6,4.6,pur,"5E4F8C",0.9)
    fill("y",-14,0,4.0,14.6,4.6,"FFE3C2",0.5,3); fill("y",-14,0,18.0,14.6,4.6,"FFE3C2",0.5,3)
    cyl("Fenetre_Verre",GL,(-7,3.6,16.3),1.1,0.2,(R(90),0,0),v=12); torus("Cadre",tr,(-7,3.7,16.3),1.15,0.2,(R(90),0,0))
    chimney(-12,14,18.5,3.6,"B5523B")
    # garage + terrasse
    box("Garage","FFE3C2",(10,9.5,3.5),(20,13,7)); box("Terrasse_Dalle","C98B4A",(10,9.5,7.2),(20.0,13.6,0.4))
    raily(3,16.3,19.8,7.4,1.3,tr,6); railx(0.2,19.8,2.9,7.4,1.3,tr,8); railx(0.2,19.8,16.3,7.4,1.3,tr,8) if False else None
    box("Cadre_Portail","8C6B8A",(10,3.0,2.9),(10.4,0.5,5.8)); box("Portail",blue,(10,2.7,2.7),(9.6,0.3,5.4))
    for i in range(3): box("Fenetre_Verre",GL,(7.4+i*2.6,2.5,4.7),(1.8,0.2,0.9))
    # accès
    door(-3,4.0,2.0,2.8,4.4,"D9534F"); wf(-10,4.0,5.8,3.0,3.0,tr,"7B6BA8"); wf(-10,4.0,13,3.0,3.0,tr,"7B6BA8"); wf(-2,4.0,13,3.0,3.0,tr,"7B6BA8")
    stairs(-3,3.9,2.0,5,3,"D0C8E0","B0A8CC")
    box("Balcon","C98B4A",(-7,2.2,10.3),(0.1,0.1,0.1)) if False else None
    railx(-13.5,-0.5,2.2,2.0,1.1,tr,5) if False else None
    ws(-14,9,5.8,-1); ws(-14,9,13,-1)
    lamp(-5.8,3.8,6.8); lamp(5.5,2.6,7.0) if False else None
    # déco
    cyl("Pot","C0623A",(-0.2,2,0.6),0.6,1.2,v=8); sph("Plante","4FAE5A",(-0.2,2,1.8),0.7,seg=8,rings=5)
    bush(-16.5,2,1.4); bush(-17.0,4.2,1.1,"7FC96B"); sph("Buisson","F28CB1",(17,0.6,0.9),0.9,seg=8,rings=5); cyl("Tuyau","8E9AAF",(1.2,16,15),0.3,7,v=6)
    box("Caisse","B5763A",(12,0,0.6),(1.4,1.4,1.2))

def house_lvl6():
    # moderne cubique : garage à gauche, volume central, balcon
    wall="7FD1AE"; org="FF9F68"; tr="FFFFFF"
    base(39.6,16,3)
    box("Garage",org,(-12,10,3.2),(15,14,6.4)); box("Toit_Garage","6B6B73",(-12,10,6.6),(15.8,14.8,0.4))
    box("Porte_Garage","E8E8EE",(-12,2.8,2.8),(8,0.3,5.2)) 
    for i in range(6): box("Rainure","C8C8D2",(-12,2.6,0.8+i*0.85),(8.0,0.15,0.2))
    box("Cadre","6B6B73",(-12,3.0,2.9),(8.8,0.3,5.6)) if False else None
    lamp(-17,2.8,5.8)
    box("Volume",wall,(0,11,8.5),(14,14,17)); box("Mur_Haut","B8EBD3",(0,5.9,14.0),(14,0.2,6.0))
    box("Toit","FF6B6B",(0,11,17.3),(15,15,0.6)) if False else None
    slab("y",-8.0,17,8.0,19.5,3,19,0.6,"FF6B6B",0.6)
    box("Toit_Plat","8E9AAF",(0,11,17.2),(15,15,0.4))
    box("Fenetre_Verre",GL,(0,3.9,13.2),(8,0.2,4.2)); box("Cadre","FFFFFF",(0,4.0,13.2),(8.8,0.3,4.8))
    for x in (-2,2): box("Cadre","FFFFFF",(x*0.67,3.8,13.2),(0.25,0.3,4.2)) 
    wf(-4.5,3.9,6.0,2.6,3.0,tr,"FF9F68") 
    door(0,4.0,2.0,2.8,4.4,"FF6B6B"); wf(4.8,4.0,6.0,2.6,2.8,tr)
    stairs(0,3.9,2.0,6,3,"D9D9E0","BEBEC8")
    # aile droite + balcon terrasse
    box("Aile","FFE08A",(12,10,3.9),(14,12,7.8)); box("Toit_Aile","6B6B73",(12,10,8.0),(14.8,12.8,0.4))
    box("Balcon_Dalle","C98B4A",(12,5.4,8.3),(14,2.8,0.3)); 
    box("Vitre","B8E6F5",(12,3.9,9.2),(14,0.2,1.6)); box("Vitre","B8E6F5",(18.9,6.5,9.2),(0.2,5.0,1.6))
    box("Cadre","6B6B73",(12,3.9,10.1),(14,0.3,0.25)); box("Cadre","6B6B73",(18.9,6.5,10.1),(0.3,5,0.25))
    wf(12,4.0,4.2,3.4,3.0,tr,None)
    ws(7.1,8,13,-1) if False else None
    # déco
    cyl("Buisson","4FAE5A",(-19,-2,1.8),1.1,3.6,v=8); sph("Buisson","4FAE5A",(-19,-2,3.6),1.1,seg=8,rings=5)
    cyl("Buisson","4FAE5A",(-17,-1,1.4),0.9,2.8,v=8); sph("Buisson","7FC96B",(-17,-1,2.8),0.9,seg=8,rings=5)
    cyl("Pot","C0623A",(3.2,3,0.6),0.5,1.2,v=8); sph("Plante","4FAE5A",(3.2,3,1.6),0.6,seg=8,rings=5)
    box("Cheminee",org,(5.5,15,19.0),(1.4,1.4,3))
    for x in (-3.2,3.2): lamp(x,3.9,6.6) if False else None

def house_lvl7():
    # grande maison moderne à terrasse et jardinières
    wall="FFE08A"; up="8EC5FC"; tr="FFFFFF"
    base(39.6,17,3)
    box("Rez",wall,(0,11.5,4.5),(36,15,9)); box("Dalle","6B6B73",(0,11.5,9.2),(37,16,0.5))
    box("Etage",up,(-5,12.5,13.5),(24,13,8.8)); box("Dalle_Haut","FF7B6B",(-5,12.5,18.2),(25.4,14.4,0.9))
    # terrasse en façade (toit du rez au-dessus ?)
    box("Terrasse","C98B4A",(14,6.5,9.55),(0.1,0.1,0.1)) if False else None
    box("Terrasse","C98B4A",(-5,6.2,9.65),(24,1.0,0.2)) if False else None
    box("Terrasse_Dalle","C98B4A",(8,4.2,9.6),(22,5.2,0.35)) if False else None
    for i in range(5): box("Rambarde_Vitre","B8E6F5",(-7+i*0,0,0),(0.01,0.01,0.01)) if False else None
    railx(-16,17,2.2,9.4,1.3,tr,0)
    for i in range(6): box("Vitre","B8E6F5",(-16+i*5.5+2.75,2.2,10.0),(5.3,0.15,1.2))
    for i in range(8): box("Poteau",tr,(-16+i*4.7,2.2,9.9),(0.25,0.25,1.2)) if False else None
    box("Terrasse","C98B4A",(0.5,3.6,9.65),(33,2.6,0.2))
    for x in (-16,-5,6,17): box("Poteau",tr,(x,2.2,10.0),(0.3,0.3,1.4))
    # façade étage
    box("Fenetre_Verre",GL,(-6,5.9,13.5),(10,0.2,5.2)); box("Cadre",tr,(-6,6.0,13.5),(10.8,0.3,5.9))
    box("Cadre",tr,(-6,5.85,13.5),(0.3,0.3,5.2)) 
    wf(4.5,6.0,13.5,3.2,3.4,tr,"FF7B6B"); wf(-14.4,6.0,13.5,2.8,3.4,tr,"FF7B6B") if False else None
    # rez
    door(-8,4.0,0.4,3.0,4.6,"3E8E8A"); wf(-14,4.0,5.2,3.0,3.2,tr) ; wf(-2,4.0,5.2,3.4,3.2,tr)
    box("Porte_Garage","DADAE2",(11.5,4.0,3.6),(9,0.3,6.0)); box("Cadre","6B6B73",(11.5,4.1,3.7),(9.8,0.2,6.4)) if False else None
    for i in range(6): box("Rainure","B8B8C4",(11.5,3.8,1.2+i*0.9),(9.0,0.15,0.2))
    stairs(-8,3.9,0.4,5,0,"D9D9E0") if False else None
    # escalier terrasse (rez surélevé) : perron
    box("Perron","D9D9E0",(-8,2.6,0.25),(6,2.4,0.5))
    # jardinières et buissons
    for x in (-17,-11,-4,8):
        box("Jardiniere","8C5A3C",(x,1.6,0.6),(3.0,1.0,1.2)); sph("Buisson","4FAE5A",(x,1.6,1.7),1.1,(1.2,0.9,0.8),seg=8,rings=5)
    cyl("Buisson","4FAE5A",(-19,5,3),1.0,6,v=8); sph("Buisson","7FC96B",(-19,5,6),1.0,seg=8,rings=5)
    cyl("Buisson","4FAE5A",(19,5,2.5),0.9,5,v=8); sph("Buisson","7FC96B",(19,5,5),0.9,seg=8,rings=5)
    for x in (-12.5,3.5): lamp(x,3.9,8.2)
    box("Cheminee","FF7B6B",(6,16,20.4),(1.6,1.6,3.0)); box("Panneau","3A3F4B",(-8,12,19.0),(5,3,0.3),(R(15),0,0))
    box("Auvent","FF7B6B",(-8,2.9,5.4+0.4),(0.1,0.1,0.1)) if False else None

def hub_dome():
    box("Paves","E8E0CC",(0,0,0.1),(60,60,0.2)); box("Paves_Centre","D9CFB4",(0,0,0.22),(46,46,0.05)) if False else None
    cyl("Socle","C9BFA5",(0,0,0.6),19.5,0.8,v=16)
    cyl("Tambour","E8E0CC",(0,0,3.6),18,6.0,v=16)
    cyl("Corniche","8C7B5A",(0,0,6.7),18.6,0.6,v=16)
    pts=[(18*math.cos(R(t)),7.0+15*math.sin(R(t))) for t in range(0,91,15)]
    cols=["2FA7A0","27968F","2FA7A0","27968F","2FA7A0","27968F"]
    for i in range(6):
        (r1,z1),(r2,z2)=pts[i],pts[i+1]
        cone("Dome",cols[i],(0,0,(z1+z2)/2),r1+0.1,max(r2,0.2),z2-z1+0.02,v=16)
    for k in range(8):
        a=R(k*45+22.5)
        for j in range(3):
            ta=R(j*30+0); tb=R(j*30+30+ (30 if j==1 else 0)) if False else R(j*45+45)
            ra,za=18.6*math.cos(R(j*30)),7.0+15.6*math.sin(R(j*30)); rb,zb=18.6*math.cos(R(j*30+30)),7.0+15.6*math.sin(R(j*30+30))
            rm,zm=(ra+rb)/2,(za+zb)/2; L=math.hypot(ra-rb,za-zb)+0.3; tilt=-math.atan2(zb-za,rb-ra)
            # boîte le long de x, inclinée autour de y puis tournée autour de z
            box("Nervure","F2E6C0",(rm*math.cos(a),rm*math.sin(a),zm),(L,0.7,0.5),(0,tilt,a))
    cyl("Lanterneau","F2E6C0",(0,0,22.4),1.6,1.6,v=8); cone("Pointe","E0A92B",(0,0,23.8),1.2,0.0,1.6,v=8)
    for k in range(12):
        a=R(k*30+15)
        if abs(math.degrees(a)-270)<20: continue
        x,y=19.4*math.cos(a),19.4*math.sin(a)
        cyl("Colonne","F5EFDD",(x,y,3.6),0.8,6.4,v=8)
    # porte avant
    box("Cadre","8C7B5A",(0,-18.2,3.2),(5.4,0.8,6.2)); box("Porte","B5763A",(0,-18.5,2.8),(4.4,0.5,5.2))
    box("Poignée","E8C547",(1.4,-18.9,2.6),(0.3,0.3,0.5))
    for k,a in enumerate((-40,-65,-115,-140)): pass
    for x,y,a in ((-10,-15,-125),(10,-15,-55),(-17.5,-5,-165),(17.5,-5,-15),(-17.5,6,170),(17.5,6,10)):
        ar=R(a-90) if False else R(a+90)
        box("Cadre","8C7B5A",(x*0.99,y*0.99,3.6),(3.0,0.4,3.0),(0,0,R(a)+R(90)) if False else (0,0,math.atan2(y,x)+R(90)))
        box("Fenetre_Verre",GL,(x,y,3.6),(2.4,0.3,2.4),(0,0,math.atan2(y,x)+R(90)))
    for x,y in ((-6,-26),(6,-26),(-26,-6),(26,-6)):
        box("Poteau","4A4F5C",(x,y,1.6),(0.3,0.3,3.0)); sph("Lanterne","FFE9A8",(x,y,3.4),0.55,seg=8,rings=5)
    for x in (-3.5,3.5): cyl("Marche","C9BFA5",(x,-21,0.4),0.1,0.1) if False else None
    box("Marche","C9BFA5",(0,-20.2,0.45),(8,2.4,0.5)); box("Marche","D9CFB4",(0,-21.8,0.35),(9,1.6,0.3))

def conveyor_belt():
    for s in (-1,1): box("Cadre_Fer","6E7480",(0,s*1.75,0.6),(12,0.5,1.2))
    box("Cadre_Fer","6E7480",(-5.8,0,0.5),(0.4,3.0,1.0)); box("Cadre_Fer","6E7480",(5.8,0,0.5),(0.4,3.0,1.0))
    box("Tapis","2B2E36",(0,0,0.95),(11.2,3.0,0.18))
    for i in range(7): cyl("Rouleaux","8E96A3",(-5.4+i*1.8,0,0.5),0.28,2.9,(R(90),0,0),v=8)
    for x in (-3.2,0.4,4.0):
        cone("Fleche","F5C400",(x+0.6,0,1.08),0.55,0.0,0.9,(0,R(90),0),v=3); box("Fleche","F5C400",(x-0.4,0,1.06),(1.0,0.35,0.06))
    for s in (-1,1): box("Pied","4A4F5C",(0,s*1.75,0.1),(11.0,0.55,0.2))

def conveyor_end():
    for s in (-1,1):
        box("Cadre_Fer","6E7480",(-1.5,s*1.75,0.6),(9,0.5,1.2)); cyl("Cadre_Fer","6E7480",(3.0,s*1.75,0.6),0.6,0.5,(R(90),0,0),v=10)
    box("Cadre_Fer","6E7480",(-5.8,0,0.5),(0.4,3.0,1.0))
    box("Tapis","2B2E36",(-1.5,0,0.95),(9,3.0,0.18)); cyl("Tapis_Courbe","2B2E36",(3.0,0,0.6),0.37,3.0,(R(90),0,0),v=10)
    cyl("Rouleaux","8E96A3",(3.0,0,0.6),0.3,3.1,(R(90),0,0),v=8)
    for i in range(4): cyl("Rouleaux","8E96A3",(-5.4+i*1.8,0,0.5),0.28,2.9,(R(90),0,0),v=8)
    # rampe de sortie
    box("Rampe","C98B4A",(5.4,0,0.45),(3.6,3.0,0.2),(0,R(18),0))
    for s in (-1,1): box("Rampe_Bord","6E7480",(5.4,s*1.6,0.65),(3.6,0.25,0.5),(0,R(18),0))
    box("Fleche","F5C400",(-2.5,0,1.06),(1.0,0.35,0.06)); cone("Fleche","F5C400",(-1.5,0,1.08),0.55,0.0,0.9,(0,R(90),0),v=3)
    box("Fleche","F5C400",(1.0,0,1.06),(1.0,0.35,0.06)); cone("Fleche","F5C400",(2.0,0,1.08),0.55,0.0,0.9,(0,R(90),0),v=3)
    for s in (-1,1): box("Pied","4A4F5C",(-1.5,s*1.75,0.1),(9,0.55,0.2))
    box("Butee","F5C400",(7.2,0,0.3),(0.3,3.2,0.5))

def grand_oeuf():
    st="9A9AA6"; st2="B8B8C4"
    cyl("Socle",st,(0,0,0.4),6.8,0.8,v=8); cyl("Marche",st2,(0,0,1.0),6.0,0.5,v=8); cyl("Marche",st,(0,0,1.4),5.2,0.4,v=8)
    for k in range(8):
        a=R(k*45+22.5); box("Pilier","7A7A88",(6.5*math.cos(a),6.5*math.sin(a),1.1),(0.8,0.8,0.8),(0,0,a)) if False else None
    sph("Oeuf","C7C2B0",(0,0,7.3),5.0,(1,1,1.15),seg=16,rings=10); sph("Oeuf_Haut","C7C2B0",(0,0,10.1),3.7,(1,1,1.5),seg=16,rings=10)
    def rr(z):
        f=lambda c,rd,sz,zz: rd*math.sqrt(max(0,1-((zz-c)/(rd*sz))**2))
        return max(f(7.3,5.0,1.15,z),f(10.1,3.7,1.5,z))
    zs=[5.5,8.0,10.5,12.5]
    n=0
    for k in range(8):
        a=R(k*45); z=zs[k%4] if False else (7.0 if k%2==0 else 9.6); r=rr(z)+0.02
        x,y=r*math.cos(a),r*math.sin(a); rot=(0,0,a-R(90))
        box("Flamme_RuneA","7FD6FF",(x,y,z),(0.9,0.4,2.6),rot)
        r2=rr(z+0.3)+0.02
        box("Flamme_RuneB","7FD6FF",(r2*math.cos(a),r2*math.sin(a),z+0.3),(2.2,0.4,0.8),rot)
    for k in range(8):
        a=R(k*45+22.5); z=5.0 if k%2==0 else 8.3; r=rr(z)+0.05
        box("Rune_Pierre","5E6A8A",(r*math.cos(a),r*math.sin(a),z),(1.5,0.45,1.6),(0,0,a-R(90)))
    for (a,z,L,t) in ((20,6.2,3.2,-30),(130,8.5,2.6,20),(220,11.5,2.2,-15),(300,5.0,2.8,35),(75,12.4,1.6,10)):
        a=R(a); r=rr(z)+0.04
        box("Fissure","4A4F5C",(r*math.cos(a),r*math.sin(a),z),(0.18,0.3,L),(R(t),0,a-R(90)))
    for k in range(4):
        a=R(k*90+45); sph("Pierre","8E93A0",(7.8*math.cos(a),7.8*math.sin(a),0.5),0.9,(1,0.8,0.6),seg=8,rings=5)

def ring(name,hexc,r0,r1,z0,z1,n=24):
    vs=[];fs=[]
    for k in range(n):
        a=2*math.pi*k/n
        for r,z in ((r0,z0),(r1,z0),(r1,z1),(r0,z1)): vs.append((r*math.cos(a),r*math.sin(a),z))
    for k in range(n):
        b=(k+1)%n; q=lambda i,j: k*4+i if j==0 else b*4+i
        for i in range(4):
            j=(i+1)%4; fs.append((k*4+i,k*4+j,b*4+j,b*4+i))
    me=bpy.data.meshes.new("ring"); me.from_pydata(vs,[],fs); me.update()
    o=bpy.data.objects.new("ring",me); bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active=o; o.select_set(True)
    bpy.ops.object.mode_set(mode="OBJECT") if False else None
    import bmesh
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=bm.faces); bm.to_mesh(me); bm.free()
    return _fin(o,name,hexc)

def arena_colosseum():
    cyl("Sable","E8D08A",(0,0,0.3),17.5,0.6,v=24)
    cols=["D9C7A0","CDB88C","D9C7A0","CDB88C","D9C7A0"]
    for i in range(5): ring("Gradin",cols[i],16.8+i*3.0,19.8+i*3.0,0.0,2.8+i*2.3,24)
    N=24
    for k in range(N):
        a=R(k*15); x,y=34*math.cos(a),34*math.sin(a); tg=a+R(90)
        box("Pilier","E6D9B8",(x,y,8.0),(2.4,2.6,16),(0,0,tg-R(90)) if False else (0,0,a))
        mx,my=34*math.cos(a+R(7.5)),34*math.sin(a+R(7.5))
        gate=(k==17)
        box("Arche","5A4A42" if not gate else "B5763A",(33.4*math.cos(a+R(7.5)),33.4*math.sin(a+R(7.5)),4.4),(0.5,6.3,8.8),(0,0,a+R(7.5)))
        box("Linteau","D2C29A",(mx,my,12.9),(2.2,8.6,6.2) if False else (2.2,8.8,6.2),(0,0,a+R(7.5)))
        if k%4==0:
            cyl("Mat","6B4A2A",(x,y,18.5),0.2,5.0,v=6); box("Drapeau",["E94F4F","3C8DDE","F5C400","4FAE5A","FF8A3D","B05AD6"][k//4],(x+0.9*math.cos(a+R(90)),y+0.9*math.sin(a+R(90)),19.8),(0.15,1.8,1.1),(0,0,a))
    ring("Corniche","8C7B5A",31.6,35.4,16.0,16.6,24)

for fn in (house_lvl2,house_lvl3,house_lvl4,house_lvl5,house_lvl6,house_lvl7,hub_dome,conveyor_belt,conveyor_end,grand_oeuf,arena_colosseum): reg(fn)
json.dump(M,open(os.path.join(OUT,"_info.json"),"w"),indent=1)
