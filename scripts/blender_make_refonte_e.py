import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
from mathutils import Vector
OUT = sys.argv[1]; M = {}
def dims():
    mn=[1e9]*3; mx=[-1e9]*3; n=0
    for o in bpy.context.scene.objects:
        if o.type!="MESH": continue
        n+=1
        for c in o.bound_box:
            w=o.matrix_world@Vector(c)
            for i in range(3): mn[i]=min(mn[i],w[i]); mx[i]=max(mx[i],w[i])
    return [round(mx[i]-mn[i],2) for i in range(3)], [round(mn[i],2) for i in range(3)], n
def reg(name, fn):
    reset(); fn(); d, mn, n = dims(); _, t = export(os.path.join(OUT, name + ".fbx")); M[name] = {"parts": n, "faces": t, "size": d, "min": mn}
PI=math.pi

def sofa_corner():
    t="6F8CA0"; t2="5C7A90"; y="F2C94C"; w="4A3524"
    box("Assise_base",t2,(0,3.25,0.8),(14,3.5,1.2)); box("Assise_base",t2,(-5.25,-1.75,0.8),(3.5,6.5,1.2))
    box("Dossier",t,(0,4.55,2.9),(14,0.9,2.8)); box("Dossier",t,(-6.55,-1.75,2.9),(0.9,6.5,2.8))
    box("Accoudoir",t,(6.6,3.25,2.0),(0.8,3.5,2.0)); cyl("Accoudoir_rond",t,(6.6,3.25,3.0),0.4,3.5,(PI/2,0,0),v=10)
    box("Accoudoir",t,(-5.25,-4.6,2.0),(3.5,0.8,2.0)); cyl("Accoudoir_rond",t,(-5.25,-4.6,3.0),0.4,3.5,(0,PI/2,0),v=10)
    for x in (-1.1,3.7): box("Coussin_assise","8CA8BC",(x,2.9,1.75),(4.7,2.7,0.7))
    box("Coussin_assise","8CA8BC",(-5.1,2.9,1.75),(3.1,2.7,0.7))
    for yy in (-3.6,-1.1): box("Coussin_assise","8CA8BC",(-5.1,yy,1.75),(3.1,2.4,0.7))
    box("Coussin_dos",y,(2.0,3.7,2.8),(3.6,0.7,1.6),(-0.25,0,0)); box("Coussin_dos",y,(-5.7,-2.0,2.8),(0.7,3.6,1.6),(0,0.25,0))
    for x in (-6.4,6.4):
        for yy in (-4.6,4.6): box("Pied",w,(x,yy,0.1),(0.6,0.6,0.2))
def kitchen_run():
    w="F2EBDD"; d="4E8F8A"; c="E8E2D0"
    box("Socle","3A3A3A",(0,0,0.2),(15.6,3.4,0.4)); box("Corps",w,(0,0,2.1),(16,3.8,3.4))
    box("Plan_travail","F4F0E6",(0,0,3.95),(16.4,4.0,0.3)); box("Dosseret",c,(0,1.9,4.7),(16.4,0.2,1.2))
    for i in range(8):
        x=-7+2*i; draw=i>=4
        if draw: box("Tiroir",d if i%2 else "5BA39C",(x,-1.95,2.2),(1.9,0.12,2.9)); box("Poignee_Laiton","C9A94B",(x,-2.1,3.2),(0.9,0.1,0.1))
        else: box("Porte",d if i%2 else "5BA39C",(x,-1.95,2.1),(1.9,0.12,3.0)); box("Poignee_Laiton","C9A94B",(x+0.7*(1 if i%2 else -1),-2.1,2.9),(0.1,0.1,0.8))
    box("Evier_Chrome","B8C4CC",(-2,0,4.14),(3.4,2.3,0.12)); box("Cuve","8A959C",(-2,0,4.2),(2.8,1.8,0.08))
    cyl("Robinet_Chrome","B8C4CC",(-2,1.3,4.8),0.14,1.2,v=8); cyl("Bec_Chrome","B8C4CC",(-2,0.8,5.35),0.12,1.2,(PI/2,0,0),v=8); sph("Bouton_Chrome","B8C4CC",(-1.4,1.3,4.25),0.15,seg=8,rings=5)
def kitchen_upper():
    w="C69A63"; f="8A5E34"
    box("Corps","B58A55",(0,0.1,1.6),(16,1.6,3.2)); box("Corniche",f,(0,0,3.15),(16,1.8,0.3)); box("Plinthe",f,(0,0,0.1),(16,1.8,0.2))
    for i in range(8):
        x=-7+2*i; y=-0.8
        if i%2==0: box("Porte",w,(x,y,1.65),(1.9,0.12,2.7)); box("Poignee_Laiton","C9A94B",(x+0.7,y-0.1,1.0),(0.1,0.1,0.8))
        else:
            box("Cadre",f,(x,y,1.65),(1.9,0.14,2.7)); box("Verre","B9E3F2",(x,y-0.02,1.65),(1.4,0.14,2.2)); box("Poignee_Laiton","C9A94B",(x-0.75,y-0.12,1.0),(0.1,0.1,0.8))
def shelf_drawers():
    w="E4C07A"; d="C9965A"
    box("Fond",d,(0,1.4,5.75),(9,0.2,8.5)); box("Cote",w,(-4.35,0,5.75),(0.3,3,8.5)); box("Cote",w,(4.35,0,5.75),(0.3,3,8.5))
    box("Dessus",w,(0,0,9.85),(9,3,0.3)); box("Dessous",w,(0,0,1.65),(9,3,0.3)); box("Separation",w,(0.5,0,5.75),(0.3,3,8.5))
    for z in (9.0,2.3): cyl("Arrondi",w,(-3.7,0,z),0.8,3,(PI/2,0,0),v=10)
    for z in (3.8,5.95,8.1): box("Etagere",w,(-1.9,0,z),(3.7,2.8,0.2))
    for i,c in enumerate(("C0504D","4A7FB5","6AAE5A")): box("Livre",c,(-3.4+i*0.5,0,2.5+0.0),(0.4,1.6,1.4)) 
    box("Livre","D98F3E",(-2.6,0,4.2),(1.6,1.4,0.5)); box("Livre","4A7FB5",(-2.5,0,4.65),(1.3,1.3,0.4),(0,0,0.2))
    sph("Bocal","9ED8E8",(-2.0,0,6.6),0.65,(1,1,1.1),seg=10,rings=6); cyl("Bocal_couvercle","D9534F",(-2.0,0,7.4),0.35,0.2,v=8)
    for i,c in enumerate(("7A5AC0","E0A030","4A9F7A")): box("Livre",c,(-3.3+i*0.45,0,8.9),(0.38,1.5,1.4))
    for i in range(4):
        z=2.9+i*1.95; box("Tiroir",["D9534F","F0B429","4A9F7A","4A7FB5"][i],(2.5,-1.5,z+0.0),(3.7,0.2,1.7)); sph("Poignee_Laiton","C9A94B",(2.5,-1.72,z),0.17,seg=8,rings=5)
    for x in (-3.6,3.6):
        for y in (-0.9,0.9): cone("Pied","5A3E28",(x,y,0.75),0.22,0.12,1.5,v=6)
def tv_unit_stepped():
    w="E8D5B0"; d="B07A3C"
    box("Base",w,(0,-0.2,1.0),(16,3.2,1.6)); box("Dessus",d,(0,-0.2,1.9),(16.2,3.4,0.2))
    for x in (-4.6,0.6): box("Tiroir","7FB6A4",(x,-1.85,1.0),(4.9,0.12,1.2)); box("Poignee_Laiton","C9A94B",(x,-1.97,1.2),(1.4,0.1,0.1))
    box("Niche_dessus",d,(3.5,0.8,4.2),(9,2.8,0.25)); box("Niche_cote",w,(-0.9,0.8,3.15),(0.25,2.8,1.9)); box("Niche_cote",w,(7.9,0.8,3.15),(0.25,2.8,1.9)); box("Niche_fond","D8C090",(3.5,2.1,3.15),(8.6,0.2,1.9))
    box("Boite_deco","E07A5F",(5,0.8,2.45),(1.6,1.2,0.5)); box("Plante_pot","4A9F7A",(2,0.8,2.5),(0.8,0.8,0.6))
    for x in (-7.5,7.5):
        for y in (-1.2,0.8): box("Pied","5A3E28",(x,y,0.05),(0.6,0.6,0.2))
def bed_double():
    w="6B4A32"; b="3F6EA5"
    for x in (-5.6,5.6):
        for y in (-7.6,7.6): box("Pied",w,(x,y,0.3),(0.6,0.6,0.6))
    box("Cadre",w,(0,0,0.95),(12,16,0.9)); box("Matelas","F4F1EA",(0,-0.4,2.0),(11.2,14.4,1.3))
    for i in range(6): box("Couette",b if i%2==0 else "F2C94C",(0,-6.4+i*1.65,2.9),(11.6,1.65,0.6))
    box("Tete_lit",w,(0,7.6,3.5),(12,0.8,7)); box("Pied_lit",w,(0,-7.6,1.6),(12,0.6,1.6))
    for x in (-6,6): box("Montant",w,(x*0.97,7.6,3.5),(0.5,0.9,7.0))
    for x in (-3.8,0,3.8): box("Capitonnage","9A6E8A",(x,7.1,4.4),(3.4,0.4,2.6))
    for x in (-1.9,1.9): sph("Bouton","C9A94B",(x,6.85,4.4),0.15,seg=6,rings=4)
    for x in (-2.9,2.9): sph("Oreiller","FFFFFF",(x,5.6,3.6),1.0,(2.0,1.5,0.6),seg=10,rings=6)
    sph("Coussin","F2C94C",(0,4.3,3.5),0.8,(1.2,0.5,1),seg=8,rings=5)
def wardrobe_tall():
    w="B5834F"; d="9A6B3C"
    for x in (-5.4,5.4):
        for y in (-1.4,1.4): box("Pied",d,(x,y,0.25),(0.8,0.8,0.5))
    box("Corps",d,(0,0,5.9),(12,4,10.8)); box("Corniche","8A5E34",(0,0,11.6),(12,4,0.8)); box("Moulure","7A4E2A",(0,-0.1,11.05),(11.6,3.8,0.3))
    for i,x in enumerate((-3.95,0,3.95)):
        box("Porte",w,(x,-2.05,5.9),(3.8,0.15,9.9)); box("Panneau",d,(x,-2.17,5.9),(2.8,0.1,8.2)); box("Panneau_haut","C69A63",(x,-2.25,5.9),(2.2,0.06,6.8))
        box("Poignee_Laiton","C9A94B",(x+(1.5 if i<2 else -1.5)*(1 if i!=1 else -1)*0.9,-2.3,5.6),(0.2,0.2,1.6))
    box("Joint","5A3E28",(-1.98,-2.15,5.9),(0.05,0.1,9.9)); box("Joint","5A3E28",(1.98,-2.15,5.9),(0.05,0.1,9.9))
def dining_set():
    w="8A5A33"; t="C69A63"; cols=["D9534F","4A7FB5","F0B429","4A9F7A","7A5AC0","E07A5F"]
    box("Plateau",t,(0,0,4.4),(14,8,0.4)); box("Bandeau",w,(0,0,3.95),(13,7,0.5))
    for x in (-6.4,6.4):
        for y in (-3.4,3.4): box("Pied_table",w,(x,y,2.0),(0.7,0.7,4.0))
    k=0
    for yy in (-5.1,5.1):
        for x in (-4.2,0,4.2):
            s=1 if yy>0 else -1; c=cols[k]; k+=1
            box("Assise",c,(x,yy,2.3),(1.9,1.9,0.3))
            for dx in (-0.8,0.8):
                for dy in (-0.8,0.8): box("Pied_chaise",w,(x+dx,yy+dy,1.075),(0.22,0.22,2.15))
            for dx in (-0.8,0.8): box("Montant",w,(x+dx,yy+s*0.8,3.3),(0.22,0.22,2.0))
            box("Traverse",w,(x,yy+s*0.8,4.3),(1.8,0.22,0.35)); box("Barreau",w,(x,yy+s*0.8,3.5),(0.2,0.14,1.2)); box("Barreau",w,(x-0.4,yy+s*0.8,3.5),(0.2,0.14,1.2)) if False else None
def desk_study():
    w="C69A63"; d="8A5E34"
    box("Plateau",w,(0,2.5,3.0),(12,3,0.25)); box("Plateau",w,(-4.5,-1.5,3.0),(3,5,0.25))
    box("Piece",d,(5.8,2.5,1.5),(0.4,2.8,3.0)); box("Piece",d,(-5.8,-1.5,1.5),(0.4,4.8,3.0)); box("Caisson",d,(-3.2,3.0,1.5),(2.2,2.4,3.0)); box("Tiroir","E8D5B0",(-3.2,1.76,2.3),(1.9,0.1,0.8)); box("Poignee_Laiton","C9A94B",(-3.2,1.65,2.3),(0.8,0.1,0.1))
    box("Fond_bureau",d,(0,3.9,2.0),(11.5,0.2,2.0))
    cyl("Pied_ecran","4A4A4A",(2,3.4,3.3),0.15,0.5,v=8); cyl("Base_ecran","4A4A4A",(2,3.2,3.2),0.7,0.1,v=10)
    box("Cadre_ecran","2E2E3A",(2,3.5,4.7),(4.2,0.25,2.5)); box("Verre","6EC6F0",(2,3.35,4.7),(3.8,0.1,2.1))
    box("Clavier","E8E8E8",(2,1.6,3.2),(2.6,0.9,0.15)); sph("Souris","E8E8E8",(3.9,1.6,3.2),0.28,(1,1.4,0.6),seg=8,rings=5)
    cyl("Base_lampe_Fer","3A3A3A",(5.0,3.2,3.2),0.5,0.15,v=10); cyl("Bras_lampe_Fer","3A3A3A",(5.0,3.2,4.2),0.07,2.0,v=6); cyl("Bras_lampe_Fer","3A3A3A",(4.5,3.2,5.1),0.07,1.2,(0,PI/2-0.3,0),v=6)
    cone("Abat_jour","E0575A",(3.95,3.2,5.1),0.6,0.2,0.7,v=10); sph("Ampoule_Lanterne","FFE9A8",(3.95,3.2,4.75),0.2,seg=6,rings=4)
    box("Carnet","4A9F7A",(-4.5,-0.6,3.25),(1.4,1.8,0.25)); box("Crayon","F2C94C",(-4.5,-0.6,3.4),(0.1,1.2,0.1),(0,0,0.3))
    cx=0.5; cy_=-1.4
    box("Assise","4A7FB5",(cx,cy_,1.9),(2.2,2.2,0.35)); box("Dossier","4A7FB5",(cx,cy_-1.1,3.2),(2.0,0.3,2.1)); cyl("Colonne_Fer","3A3A3A",(cx,cy_,1.1),0.15,1.2,v=6)
    for i in range(5):
        a=i*2*PI/5; box("Roulette_Fer","3A3A3A",(cx+0.65*math.cos(a),cy_+0.65*math.sin(a),0.35),(1.3,0.18,0.15),(0,0,a))
        sph("Roue","222222",(cx+1.2*math.cos(a),cy_+1.2*math.sin(a),0.2),0.2,seg=6,rings=4)
def fridge_big():
    box("Corps_Chrome","B8C4CC",(0,0.2,5.65),(5,3.6,10.7)); 
    for x in (-2.3,2.3):
        for y in (-1.2,1.4): box("Pied","3A3A3A",(x,y,0.15),(0.4,0.4,0.3))
    for s in (-1,1): box("Porte_Chrome","D2DCE2",(s*1.22,-1.8,5.6),(2.4,0.4,10.2))
    box("Joint","3A3A3A",(0,-1.95,5.6),(0.08,0.3,10.2)); box("Poignee_Chrome","8A959C",(-0.35,-2.3,6.2),(0.18,0.3,3.2)); box("Poignee_Chrome","8A959C",(0.35,-2.3,6.2),(0.18,0.3,3.2))
    box("Afficheur","2E2E3A",(1.2,-2.02,8.4),(1.2,0.1,0.8)); sph("Voyant_Lanterne","7AE0A0",(1.2,-2.1,8.4),0.12,seg=6,rings=4)
    box("Separation_horiz","3A3A3A",(0,-2.0,3.0),(4.8,0.08,0.1))
for n,f in [("sofa_corner",sofa_corner),("kitchen_run",kitchen_run),("kitchen_upper",kitchen_upper),("shelf_drawers",shelf_drawers),("tv_unit_stepped",tv_unit_stepped),("bed_double",bed_double),("wardrobe_tall",wardrobe_tall),("dining_set",dining_set),("desk_study",desk_study),("fridge_big",fridge_big)]: reg(n,f)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
for k,v in M.items(): print(k, v["parts"], v["size"], v["min"])
