# Lot 15 Chipe-Oeufs : PNJ (Pip + 4 dresseurs), calendrier, kiosque, decors d'evenements.
# Usage : python scripts/blender_make_lot15.py <dossier_sortie>   (devant = -Y, G = +x, 1 unite = 1 stud)
import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
from mathutils import Vector
OUT = sys.argv[1]; M = {}; PI = math.pi
def dims():
    mn=[1e9]*3; mx=[-1e9]*3; n=0
    for o in bpy.context.scene.objects:
        if o.type!="MESH": continue
        n+=1
        for c in o.bound_box:
            w=o.matrix_world@Vector(c)
            for i in range(3): mn[i]=min(mn[i],w[i]); mx[i]=max(mx[i],w[i])
    return [round(mx[i]-mn[i],2) for i in range(3)], [round(mn[i],2) for i in range(3)], n
def reg(name, fn, limit=40):
    reset(); fn(); d, mn, n = dims(); _, t = export(os.path.join(OUT, name + ".fbx"))
    M[name] = {"parts": n, "faces": t, "size": d, "min": mn}
    if n > limit: print("ATTENTION", name, n, ">", limit)

def humanoid(body, skin, hair, legs, shoes, bw=2.0, bd=1.1, aw=0.55, lx=0.5, lw=0.75, feet=True, sleeve=None, mouth=True):
    """Silhouette R15 simplifiee de 5 studs : jambes 0-1.5, corps 1.5-3.1, tete 3.1-4.9."""
    for s, n in ((1, "G"), (-1, "D")):
        box(f"Jambe_{n}", legs, (s*lx, 0, 0.75), (lw, 0.75, 1.5))
        if feet: box(f"Pied_{n}", shoes, (s*lx, -0.12, 0.17), (lw+0.1, 1.0, 0.34))
        box(f"Bras_{n}", sleeve or body, (s*(bw/2+aw/2+0.05), 0, 2.3), (aw, aw, 1.6))
        sph(f"Main_{n}", skin, (s*(bw/2+aw/2+0.05), 0, 1.45), 0.34, seg=8, rings=6)
        sph("Oeil", "1A1A1A", (s*0.36, -0.82, 4.02), 0.12, seg=6, rings=4)
    box("Corps", body, (0, 0, 2.3), (bw, bd, 1.6))
    sph("Tete", skin, (0, 0, 4.0), 0.9)
    sph("Cheveux", hair, (0, 0.12, 4.3), 0.93, (1, 1, 0.8), seg=10, rings=6)
    if mouth: box("Bouche", "B5453A", (0, -0.86, 3.65), (0.36, 0.1, 0.1))

# ---------------------------------------------------------------- Pip
def pip():
    sk="F2C8A0"
    # Pip : petit marchand rond a gauche (x<0), charrette a droite
    px=-3.3
    for s in (1,-1):
        cyl("Jambe_"+("G" if s>0 else "D"),"5A4636",(px+s*0.55,0,0.55),0.4,1.1,v=8)
        sph("Pied","3A2A1E",(px+s*0.55,-0.2,0.2),0.45,(1,1.4,0.55),seg=8,rings=5)
    sph("Corps","8B5A2B",(px,0,1.9),1.15,(1,0.9,1.0))
    box("Ceinture","3A2A1E",(px,-0.05,2.0),(2.2,1.9,0.22))
    sph("Tete",sk,(px,0,3.45),0.78)
    sph("Nez","E8A27A",(px,-0.75,3.4),0.2,seg=6,rings=4)
    for s in (1,-1): sph("Oeil","1A1A1A",(px+s*0.3,-0.68,3.65),0.1,seg=6,rings=4)
    box("Moustache","6B4F35",(px,-0.74,3.15),(0.95,0.18,0.2))
    cyl("Bord_chapeau","6B4F35",(px,0,4.12),1.1,0.15,v=14)
    cyl("Chapeau","8A6A45",(px,0,4.55),0.65,0.85,v=12)
    cyl("Ruban","C0392B",(px,0,4.3),0.68,0.2,v=12)
    box("Plume","E8B923",(px+0.55,0,4.75),(0.15,0.3,0.9),(0,0.5,0))
    for s,n in ((1,"G"),(-1,"D")):
        box(f"Bras_{n}","D9B27A",(px+s*1.35,-0.3,2.1),(0.5,1.5,0.5),(0,0,0))
        sph(f"Main_{n}",sk,(px+s*1.35,-1.1,2.1),0.3,seg=8,rings=6)
    # charrette
    cx=1.2
    box("Charrette","96622C",(cx,0,1.25),(5.4,2.8,0.35))
    for s in (1,-1): box("Charrette","96622C",(cx,s*1.35,1.85),(5.4,0.2,0.9))
    box("Charrette","96622C",(cx+2.6,0,1.85),(0.2,2.8,0.9))
    box("Charrette","96622C",(cx-2.6,0,1.85),(0.2,2.8,0.9))
    for s in (1,-1): cyl("Roues","3A3A42",(cx+0.2,s*1.55,1.0),1.0,0.3,(PI/2,0,0),v=14)
    for s in (1,-1): box("Timon","6B4F35",(cx-3.45,s*1.0,1.35),(1.9,0.18,0.18))
    for s in (1,-1): cyl("Montant","6B4F35",(cx+2.4,s*1.2,3.0),0.12,2.6,v=6)
    box("Auvent","C0392B",(cx+0.1,0,4.4),(5.6,3.2,0.2),(0,0.0,0))
    box("Auvent","F5EBD7",(cx+0.1,0,4.5),(5.6,0.9,0.2))
    cols=["F5EBD7","E8B923","5AA9E6","E0557A","7ACB6A","9B6FD6","F28C28"]
    k=0
    for i in range(4):
        for j in (-0.55,0.55):
            x=cx-1.8+i*1.2+(0.3 if j>0 else 0)
            sph("Oeufs",cols[k%7],(x,j,2.15),0.5,(0.85,0.85,1.2),seg=10,rings=6); k+=1
reg("npc_pip", pip)

# ---------------------------------------------------------------- Lina
def lina():
    humanoid("F2E6C8","F2C8A0","7A3E1E","5A7A4A","6B4F35")
    box("Cape","2E8B3C",(0,0.75,2.0),(2.5,0.25,2.5),(-0.12,0,0))
    box("Cape_epaulettes","2E8B3C",(0,0.1,3.15),(2.7,1.5,0.3))
    box("Capuche","3FA34D",(0,0.35,3.4),(1.7,1.0,0.5))
    box("Ceinture","8A5A2B",(0,0,1.65),(2.1,1.2,0.25))
    sph("Broche","F2C94C",(0,-0.55,3.05),0.2,seg=6,rings=4)
    sph("Natte","7A3E1E",(0.2,0.95,3.9),0.45,(0.8,0.8,1.6),seg=8,rings=6)
    # koala porte sur le bras gauche
    sph("Accessoire","9AA0A6",(1.05,-1.0,2.0),0.6,(1,0.9,1.15),seg=10,rings=6)
    sph("Koala_ventre","E3E6E8",(1.05,-1.45,1.95),0.35,(1,0.4,1),seg=8,rings=5)
    sph("Koala_tete","9AA0A6",(1.05,-1.0,2.85),0.46,seg=10,rings=6)
    for s in (1,-1): sph("Koala_oreille","B8BEC4",(1.05+s*0.5,-0.98,3.2),0.25,(1,0.5,1),seg=8,rings=5)
    sph("Koala_nez","2B2B2B",(1.05,-1.42,2.85),0.14,(1,0.7,1.2),seg=6,rings=4)
reg("npc_lina", lina, 30)

# ---------------------------------------------------------------- Bruno
def bruno():
    humanoid("C0392B","E0A878","6B3A1E","4A4A55","3A2A1E",bw=2.9,bd=1.4,aw=0.95,lx=0.7,lw=1.1)
    box("Tablier","5A3A22",(0,-0.8,2.0),(2.5,0.3,2.3))
    box("Tablier_bavette","6A472C",(0,-0.95,3.0),(1.5,0.25,0.8))
    box("Bretelle","5A3A22",(-0.8,-0.2,3.15),(0.3,1.5,0.3)); box("Bretelle","5A3A22",(0.8,-0.2,3.15),(0.3,1.5,0.3))
    sph("Barbe","6B3A1E",(0,-0.45,3.55),0.8,(1.05,0.8,0.95),seg=10,rings=6)
    for s in (1,-1): box("Sourcil","6B3A1E",(s*0.38,-0.8,4.28),(0.5,0.15,0.16))
    box("Bandeau","E8B923",(0,0,4.5),(1.9,1.9,0.2))
    # marteau de forgeron dans la main droite (x<0)
    cyl("Accessoire","5A3A22",(-2.05,-0.5,2.2),0.14,2.2,(PI/2,0,0),v=6)
    box("Marteau_Fer","7A8590",(-2.05,-1.5,2.2),(0.9,0.9,0.7))
    box("Gant","3A2A1E",(-1.9,-0.4,1.75),(0.75,0.75,0.5))
    box("Gant","3A2A1E",(1.9,0,1.75),(0.75,0.75,0.5))
reg("npc_bruno", bruno, 30)

# ---------------------------------------------------------------- Kai
def kai():
    humanoid("F4F4F4","F2C8A0","DADADA","F4F4F4","F4F4F4",aw=0.8,feet=False,sleeve="FAFAFA",mouth=False)
    cone("Robe","F4F4F4",(0,0,1.6),1.75,1.25,3.0,v=14)
    cyl("Ceinture","2E5AAC",(0,0,2.1),1.28,0.35,v=14)
    sph("Chignon","DADADA",(0,0.15,5.0),0.4,seg=8,rings=6)
    cone("Barbe","F0F0F0",(0,-0.6,3.0),0.05,0.5,1.2,v=8)
    # renard blanc a neuf queues
    fx=-3.0
    sph("Renard_corps","FAFAFA",(fx,-0.1,0.75),0.65,(0.9,1.4,1.05),seg=10,rings=6)
    sph("Renard_tete","FAFAFA",(fx,-1.0,1.5),0.5,(1,1,0.95),seg=10,rings=6)
    cone("Museau","FAFAFA",(fx,-1.5,1.4),0.28,0.05,0.7,(PI/2+PI,0,0),v=8)
    for s in (1,-1): cone("Renard_oreille","E8E0D0",(fx+s*0.32,-0.95,2.0),0.2,0.03,0.6,v=6)
    for i in range(9):
        th=math.radians(-72+i*18); h=1.9
        px=fx+0.0; pz=0.95; py=0.85
        d=Vector((math.sin(th),0,math.cos(th)))
        c=Vector((px,py,pz))+d*(h/2)
        cone("Queue","FAFAFA" if i%2==0 else "EEF2F8",(c.x,c.y+0.0,c.z),0.3,0.1,h,(0,th,0),v=8)
reg("npc_kai", kai, 30)

# ---------------------------------------------------------------- Nora
def nora():
    humanoid("7B4FC9","F2C8A0","2A2230","3A3A4A","5A3A22")
    sph("Cheveux_coupe","2A2230",(0,0.4,3.95),1.0,(1,0.9,1.0),seg=10,rings=6)
    for s in (1,-1): torus("Lunettes","2B2B2B",(s*0.4,-0.9,4.02),0.3,0.06,(PI/2,0,0))
    box("Lunettes_pont","2B2B2B",(0,-0.9,4.05),(0.25,0.08,0.08))
    cyl("Beret","C0392B",(0.1,0,4.85),0.85,0.25,v=12)
    cyl("Echarpe","F2A03D",(0,0,3.15),0.85,0.3,v=12)
    box("Echarpe","F2A03D",(0.5,-0.65,2.6),(0.5,0.12,1.0))
    box("Sac","C0793A",(1.95,0.2,1.7),(0.6,1.5,1.2))
    box("Sac_rabat","8A5A2B",(1.95,0.2,2.3),(0.7,1.6,0.25))
    box("Sangle","8A5A2B",(0,-0.58,2.4),(0.2,0.08,2.4),(0,-0.0,0.5))
    box("Accessoire","E8B923",(-1.0,-0.8,2.0),(0.95,0.18,1.25),(0.15,0,0.1))
    box("Carnet_pages","F5EBD7",(-1.0,-0.72,2.0),(0.85,0.12,1.15),(0.15,0,0.1))
    box("Carnet_sangle","C0392B",(-0.75,-0.92,2.0),(0.1,0.06,1.2),(0.15,0,0.1))
reg("npc_nora", nora, 30)

# ---------------------------------------------------------------- Calendrier
def calendar():
    w="96622C"
    box("Cadre",w,(0,0,6.8),(8,1,0.4)); box("Cadre",w,(0,0,0.2),(8,1,0.4))
    for s in (1,-1): box("Cadre",w,(s*3.8,0,3.5),(0.4,1,7))
    box("Fond","C9A27A",(0,0.15,3.5),(7.2,0.5,6.2))
    for r in range(5):
        for c in range(6):
            box("Cases","F5EBD7",(-2.75+c*1.1,-0.2,6.1-r*0.95-0.0),(1.0,0.14,0.85))
    box("Coffre","E8B923",(0,-0.15,1.0),(2.8,0.8,1.2))
    cyl("Coffre_couvercle","E8B923",(0,-0.15,1.6),0.4,2.8,(0,PI/2,0),v=10)
    box("Serrure_Laiton","B8860B",(0,-0.58,1.4),(0.4,0.1,0.5))
    box("Ruban","D9534F",(0,-0.58,1.0),(0.3,0.1,1.2))
    box("Ruban","D9534F",(-3.4,-0.55,6.7),(0.5,0.1,1.0),(0,0.3,0))
reg("hub_calendar", calendar, 40)

# ---------------------------------------------------------------- Kiosque
def kiosk():
    cyl("Socle","CFC8B8",(0,0,0.2),7.2,0.4,v=24); cyl("Socle_marche","B8B0A0",(0,0,0.05),7.7,0.2,v=24)
    cyl("Comptoir","8B5A2B",(0,0,0.95),2.4,1.1,v=16); cyl("Comptoir_dessus","D2A86A",(0,0,1.6),2.6,0.2,v=16)
    for i,(x,y) in enumerate(((-0.9,-0.6),(0.6,-1.0),(0.9,0.5))): sph("Oeufs",["E8B923","5AA9E6","E0557A"][i],(x,y,2.05),0.4,(0.85,0.85,1.2),seg=10,rings=6)
    cyl("Cordon","3A2A1E",(0,0,4.1),0.06,2.4,v=6); sph("Lueur","FFD76A",(0,0,2.9),0.5,(1,1,1.2),seg=10,rings=6)
    for k in range(8):
        a=k*PI/4+PI/8; cyl("Poteau","8B5A2B",(6.1*math.cos(a),6.1*math.sin(a),3.2),0.28,5.6,v=8)
    torus("Poutre","6B4F35",(0,0,5.8),6.2,0.28)
    pans=[("PanneauBoutique","F2C94C",-PI/2,0),("PanneauCalendrier","6FB7E9",PI/2,PI),("PanneauProba","9B6FD6",0,-PI/2),("PanneauClassement","5FBF6A",PI,PI/2)]
    for nm,c,ang,rot in pans:
        x=6.2*math.cos(ang); y=6.2*math.sin(ang)
        box(nm,c,(x,y,4.5),(3.2,0.3,2.0),(0,0,ang+PI/2))
        box("Panneau_bord","6B4F35",(x*0.97,y*0.97,4.5),(3.5,0.2,2.3),(0,0,ang+PI/2))
    tiers=[(7.6,5.8,6.0,"C0392B"),(6.0,4.2,7.2,"E0703A"),(4.4,2.4,8.4,"C0392B")]
    for r1,r2,z,c in tiers: cone("Tuiles",c,(0,0,z+0.6),r1,r2,1.2,v=16)
    cone("Toit","E0703A",(0,0,10.9),2.5,0.1,2.6,v=16); sph("Pointe","E8B923",(0,0,12.3),0.4,seg=8,rings=6)
    for k in range(4):
        a=k*PI/2+PI/4; box("Caisse","B5834F",(5.2*math.cos(a),5.2*math.sin(a),0.9),(1.2,1.2,1.0),(0,0,a))
reg("hub_kiosk", kiosk, 40)

# ---------------------------------------------------------------- Evenements
def pumpkin():
    sph("Citrouille","F28C28",(0,0,1.35),1.3,(1.3,1.3,1.0),seg=14,rings=8)
    for k in range(6):
        a=PI/6+k*PI/3; sph("Citrouille","E87A1A" if k%2 else "F28C28",(1.0*math.cos(a),1.0*math.sin(a),1.35),0.95,(0.85,0.85,1.4),seg=10,rings=8)
    cyl("Tige","5A7A2A",(0,0,2.75),0.28,0.5,v=8)
    cyl("Feuille","4A9F3A",(0.5,0,2.75),0.4,0.08,(0,0.4,0),v=6)
    for s in (1,-1): cyl("Lueur_oeil","FFD23F",(s*0.65,-1.78,1.75),0.3,0.2,(PI/2,-PI/2,0),v=3)
    cyl("Lueur_nez","FFD23F",(0,-1.82,1.35),0.17,0.2,(PI/2,-PI/2,0),v=3)
    box("Lueur_bouche","FFD23F",(0,-1.78,0.85),(1.4,0.2,0.35))
    for x in (-0.45,0.45): box("Dent","F28C28",(x,-1.9,0.9),(0.28,0.2,0.3))
reg("event_pumpkin", pumpkin, 40)

def xmas():
    cyl("Tronc","6B4F35",(0,0,0.8),0.8,1.6,v=8)
    tiers=[(1.2,3.2,4.2),(3.4,3.2,3.4),(5.6,3.0,2.6),(7.6,3.4,1.8)]
    def rad(t,z):
        z0,h,r1=t; return r1*(1-(z-z0)/h*0.94)
    for i,t in enumerate(tiers): cone("Sapin","2F8F46" if i%2==0 else "27793B",(0,0,t[0]+t[1]/2),t[2],t[2]*0.06,t[1],v=12)
    ocols=["D9342B","3B82D9","F2C94C","E8B923","D9342B","3B82D9"]
    k=0
    for i,t in enumerate(tiers[:3]):
        for j in range(4):
            a=-PI/2+(j-1.5)*0.9+i*0.35; z=t[0]+0.5; r=rad(t,z)+0.15
            sph("Boule",ocols[k%6],(r*math.cos(a),r*math.sin(a),z),0.35,seg=8,rings=6); k+=1
    for i,t in enumerate(tiers[:3]):
        z=t[0]+t[1]*0.45; torus("Guirlande_Lueur","FFD23F",(0,0,z),rad(t,z)+0.12,0.12)
    sph("Etoile_Lueur","FFE14A",(0,0,11.3),0.5,seg=8,rings=6)
    for s in (0,1,2,3,4): a=s*2*PI/5+PI/2; cone("Etoile_Lueur","FFE14A",(0.7*math.cos(a)*0.0,0,11.3),0.0001,0.0001,0.01) if False else None
    for s in range(5):
        a=s*2*PI/5; cone("Etoile_Lueur","FFE14A",(0.55*math.sin(a),0,11.3+0.55*math.cos(a)),0.22,0.02,0.7,(0,a,0),v=5) 
    for x,y,c,sz in ((-2.2,-3.3,"D9342B",1.2),(2.4,-3.4,"3B82D9",1.0),(0.2,-4.2,"F2C94C",0.9)):
        box("Cadeau",c,(x,y,sz/2),(sz,sz,sz),(0,0,0.3))
reg("event_xmastree", xmas, 40)

def arch():
    R=3.4; zc=5.8; n=9
    for s in (1,-1):
        box("Socle_arche","D8CDB8",(s*R,0,0.25),(1.6,1.6,0.5)); box("Arche","F5EBD7",(s*R,0,zc/2+0.25),(0.9,0.9,zc-0.5))
    for i in range(n):
        t0=PI*i/n; t1=PI*(i+1)/n; tm=(t0+t1)/2
        L=2*R*math.sin((t1-t0)/2)*1.08
        box("Arche","F5EBD7",(R*math.cos(tm),0,zc+R*math.sin(tm)),(L,0.9,0.9),(0,-(tm+PI/2),0))
    for i in range(10):
        t=PI*(i+0.5)/10; sph("Feuillage","5FA84A",(R*math.cos(t),-0.3,zc+R*math.sin(t)),0.5,(1.2,0.8,0.9),seg=8,rings=5)
    fcols=["F28CB1","F2C94C","FFFFFF","B58CE8","F28CB1","F2C94C"]
    for i,t in enumerate([0.1,0.28,0.45,0.62,0.78,0.92,0.18,0.55]):
        a=PI*t; sph("Fleurs",fcols[i%6],(R*math.cos(a),-0.75,zc+R*math.sin(a)+(0.1 if i%2 else -0.1)),0.32,seg=8,rings=5)
    for s in (1,-1):
        for z,c in ((1.2,"F28CB1"),(2.6,"F2C94C"),(4.0,"B58CE8")): sph("Fleurs",c,(s*(R+0.1),-0.55,z),0.32,seg=8,rings=5)
        sph("Feuillage","5FA84A",(s*R,-0.5,0.9),0.6,(1,0.8,1.2),seg=8,rings=5)
reg("event_springarch", arch, 40)

json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
for k,v in M.items(): print(k, v["parts"], v["size"], v["min"])
