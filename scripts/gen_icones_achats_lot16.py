"""Icônes des achats du lot 16 : 22 produits + 3 passes, 512x512.

Même style que scripts/gen_icones_achats.py : fonctions de base copiées à
l'identique (ce script n'a pas de garde __main__, l'importer le relancerait),
même fond dégradé, même contour sombre et même cadre arrondi.

Usage :
  python3 scripts/gen_icones_achats_lot16.py           -> génère les PNG
  python3 scripts/gen_icones_achats_lot16.py --liste   -> fichier, type, id (pour le téléversement)
Sortie : vignettes/icones-achats/lot16/<nom>.png
"""
import math
import os
import sys
from PIL import Image, ImageDraw, ImageFont

S = 512
UNIVERS = 10776613087
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "vignettes", "icones-achats", "lot16"))

# ---- Fonctions de base (copie de scripts/gen_icones_achats.py) ----
def bg(c1,c2):
    im=Image.new("RGB",(S,S)); px=im.load()
    for y in range(S):
        for x in range(S):
            t=(x*0.4+y*0.6)/S; px[x,y]=tuple(int(c1[i]*(1-t)+c2[i]*t) for i in range(3))
    d=ImageDraw.Draw(im); d.rounded_rectangle((8,8,S-8,S-8),60,outline=(255,255,255),width=10); return im,d
def o(d,fn,*a,fill,w=8,**k): fn(*a,fill=fill,outline=(30,30,40),width=w,**k)
def star(d,cx,cy,r,fill):
    pts=[(cx+(r if i%2==0 else r*0.45)*math.sin(i*math.pi/5),cy-(r if i%2==0 else r*0.45)*math.cos(i*math.pi/5)) for i in range(10)]; d.polygon(pts,fill=fill,outline=(30,30,40))
def heart(d,c=(240,80,100)):
    d.polygon([(256,420),(110,270),(150,170),(256,230),(362,170),(402,270)],fill=c,outline=(30,30,40)); d.ellipse((110,130,260,260),fill=c); d.ellipse((252,130,402,260),fill=c)
def coin(d,x=256,y=256,r=130,t="x2"):
    o(d,d.ellipse,(x-r,y-r,x+r,y+r),fill=(255,205,60)); o(d,d.ellipse,(x-r+22,y-r+22,x+r-22,y+r-22),fill=(255,225,110),w=4)
def clover(d):
    for dx,dy in ((-60,-60),(60,-60),(-60,60),(60,60)): o(d,d.ellipse,(256+dx-70,256+dy-70,256+dx+70,256+dy+70),fill=(70,200,90))
    d.line((256,300,310,440),fill=(30,120,50),width=22)
def bolt(d,c=(255,230,70)): d.polygon([(290,80),(150,290),(240,290),(210,440),(370,210),(280,210)],fill=c,outline=(30,30,40))
def crown(d): d.polygon([(110,380),(130,200),(200,290),(256,170),(312,290),(382,200),(402,380)],fill=(255,205,60),outline=(30,30,40)); [o(d,d.ellipse,(x-18,y-18,x+18,y+18),fill=(230,60,90),w=5) for x,y in ((190,350),(256,350),(322,350))]
def egg(d,c=(200,120,255),spots=True):
    o(d,d.ellipse,(150,90,362,430),fill=c)
    if spots:
        for x,y in ((220,200),(300,260),(240,330)): d.ellipse((x-16,y-16,x+16,y+16),fill=(255,255,255))
def bag(d): o(d,d.ellipse,(120,190,392,430),fill=(200,150,70)); o(d,d.polygon,[(200,200),(160,110),(352,110),(312,200)],fill=(220,170,90)); o(d,d.rectangle,(190,190,322,215),fill=(240,60,90)); coin(d,256,330,60)

# ---- Éléments propres au lot 16 ----
def txt(d,x,y,s,size,fill=(30,30,40)):
    d.text((x,y),s,fill=fill,font=ImageFont.load_default(size=size),anchor="mm")

def egg_small(d,cx,cy,rx,ry,c,spots=True):
    o(d,d.ellipse,(cx-rx,cy-ry,cx+rx,cy+ry),fill=c)
    if spots:
        for dx,dy in ((-0.35,-0.35),(0.3,0.05),(-0.1,0.35)):
            x=cx+dx*rx; y=cy+dy*ry; r=max(6,int(rx*0.14))
            d.ellipse((x-r,y-r,x+r,y+r),fill=(255,255,255))

def small_bag(d):
    o(d,d.ellipse,(120,190,392,430),fill=(200,150,70))
    o(d,d.polygon,[(200,200),(160,110),(352,110),(312,200)],fill=(220,170,90))
    o(d,d.rectangle,(190,190,322,215),fill=(240,60,90))
    coin(d,160,405,62)
    coin(d,352,405,62)
    coin(d,256,430,70)

def potion_mini(d):
    o(d,d.ellipse,(160,220,352,430),fill=(90,230,130))
    o(d,d.rectangle,(230,150,282,240),fill=(200,230,240))
    o(d,d.rectangle,(216,120,296,156),fill=(150,100,60))
    for x,y in ((220,340),(292,320),(256,390)): o(d,d.ellipse,(x-14,y-14,x+14,y+14),fill=(220,255,230),w=4)

def sword(d,hx,hy,tx,ty):
    L=math.hypot(tx-hx,ty-hy); ux,uy=(tx-hx)/L,(ty-hy)/L; nx,ny=-uy,ux
    gx,gy=hx+ux*40,hy+uy*40
    d.line((hx-ux*60,hy-uy*60,hx,hy),fill=(30,30,40),width=34)
    d.line((hx-ux*60,hy-uy*60,hx,hy),fill=(120,60,30),width=18)
    d.line((gx+nx*70,gy+ny*70,gx-nx*70,gy-ny*70),fill=(30,30,40),width=34)
    d.line((gx+nx*70,gy+ny*70,gx-nx*70,gy-ny*70),fill=(255,200,60),width=18)
    d.line((gx,gy,tx,ty),fill=(30,30,40),width=40)
    d.line((gx,gy,tx,ty),fill=(225,230,240),width=24)

def arena_ticket(d):
    o(d,d.rounded_rectangle,(60,200,452,330),30,fill=(255,210,80))
    sword(d,120,390,380,130)
    sword(d,392,390,132,130)

def flame(d,cx,cy,s):
    outer=[(0,-150),(70,-40),(95,50),(55,130),(-55,130),(-95,50),(-70,-40),(-25,10)]
    o(d,d.polygon,[(cx+x*s,cy+y*s) for x,y in outer],fill=(255,120,30),w=7)
    inner=[(0,-70),(35,10),(45,60),(25,100),(-25,100),(-45,60),(-35,10)]
    d.polygon([(cx+x*s,cy+y*s) for x,y in inner],fill=(255,240,140))

def streak(d):
    cx,cy,r=256,256,160
    d.arc((cx-r,cy-r,cx+r,cy+r),20,340,fill=(30,30,40),width=46)
    d.arc((cx-r,cy-r,cx+r,cy+r),20,340,fill=(255,255,255),width=30)
    th=math.radians(340); px,py=cx+r*math.cos(th),cy+r*math.sin(th)
    tx,ty=-math.sin(th),math.cos(th); nx,ny=math.cos(th),math.sin(th)
    head=[(px+tx*60,py+ty*60),(px+nx*46,py+ny*46),(px-nx*46,py-ny*46)]
    d.polygon(head,fill=(255,255,255),outline=(30,30,40))
    flame(d,256,262,0.62)

def victory(d,n,fill=(250,250,255)):
    L=(30,30,40)
    for x1,y1,x2,y2 in ((222,200,146,96),(290,200,366,96),(240,320,214,450),(272,320,298,450)):
        d.line((x1,y1,x2,y2),fill=L,width=52)
        d.line((x1,y1,x2,y2),fill=fill,width=34)
    for x,y in ((146,96),(366,96),(214,450),(298,450)): o(d,d.ellipse,(x-24,y-24,x+24,y+24),fill=fill,w=6)
    o(d,d.ellipse,(216,96,296,176),fill=fill)
    o(d,d.rounded_rectangle,(200,180,312,330),44,fill=fill)
    d.ellipse((96-50,400-50,96+50,400+50),fill=(255,255,255),outline=L,width=8)
    txt(d,96,400,str(n),80)

def season(d,plus):
    star(d,256,205,120,(255,230,70))
    o(d,d.rounded_rectangle,(96,330,416,396),18,fill=(170,60,230))
    o(d,d.polygon,[(140,380),(106,462),(146,452),(176,396)],fill=(120,30,180),w=6)
    o(d,d.polygon,[(372,380),(406,462),(366,452),(336,396)],fill=(120,30,180),w=6)
    if plus: txt(d,256,363,"+10",64,(255,255,255))

def upgrade_plus(d):
    o(d,d.polygon,[(220,96),(340,216),(276,216),(276,316),(164,316),(164,216),(100,216)],fill=(120,255,160))
    o(d,d.rounded_rectangle,(290,330,450,450),30,fill=(255,255,255))
    txt(d,370,390,"+10",76,(10,90,150))

def chest(d,ribbon):
    o(d,d.rounded_rectangle,(120,250,392,420),36,fill=(170,90,40))
    o(d,d.rounded_rectangle,(110,190,402,285),60,fill=(200,120,50))
    d.rectangle((222,190,290,420),fill=(255,205,60),outline=(30,30,40),width=6)
    if ribbon:
        o(d,d.rounded_rectangle,(110,330,402,366),14,fill=(160,60,220))
        o(d,d.ellipse,(234,318,278,362),fill=(190,90,250),w=6)
    else:
        o(d,d.ellipse,(232,300,280,348),fill=(255,230,120))
    crown_at(d,256,135,0.5)

def crown_at(d,cx,cy,s):
    P=[(110,380),(130,200),(200,290),(256,170),(312,290),(382,200),(402,380)]
    d.polygon([(cx+(x-256)*s,cy+(y-275)*s) for x,y in P],fill=(255,205,60),outline=(30,30,40))
    for x,y in ((190,350),(256,350),(322,350)):
        X=cx+(x-256)*s; Y=cy+(y-275)*s; r=18*s
        d.ellipse((X-r,Y-r,X+r,Y+r),fill=(230,60,90),outline=(30,30,40),width=3)

def bundle_legend(d):
    egg_small(d,256,200,100,130,(255,160,190))
    egg_small(d,140,380,55,75,(255,205,60))
    egg_small(d,372,380,55,75,(255,205,60))
    egg_small(d,256,400,62,82,(255,215,80))

def egg_bag(d):
    egg_small(d,256,250,64,84,(230,140,255))
    o(d,d.ellipse,(130,230,382,430),fill=(200,150,70))
    o(d,d.polygon,[(210,240),(170,130),(342,130),(302,240)],fill=(220,170,90))
    o(d,d.rectangle,(190,210,322,235),fill=(240,60,90))
    o(d,d.rounded_rectangle,(290,340,450,450),30,fill=(255,255,255))
    txt(d,370,395,"+10",70,(110,60,20))

def collector(d):
    d.rounded_rectangle((100,100,412,412),40,outline=(30,30,40),width=36)
    d.rounded_rectangle((100,100,412,412),40,outline=(255,205,60),width=22)
    o(d,d.ellipse,(120,120,310,310),fill=(170,225,255),w=10)
    d.arc((140,140,240,240),200,260,fill=(255,255,255),width=12)
    d.line((290,290,380,380),fill=(30,30,40),width=56)
    d.line((290,290,380,380),fill=(140,90,40),width=36)

def double_clover(d,label="x2"):
    clover(d)
    o(d,d.ellipse,(330,330,470,470),fill=(255,255,255),w=8)
    txt(d,400,400,label,80)

def egg_gold_sparkles(d):
    star(d,400,120,40,(255,230,70)); star(d,110,380,30,(255,240,160))

def egg_rose(d):
    egg(d,(255,170,190))
    star(d,392,130,44,(255,240,120)); star(d,120,370,34,(255,255,255))

# ---- Achats : (nom de fichier, fond 1, fond 2, dessin, type, id) ----
ACHATS = [
    ("coinpacks",            (150,90,20),  (255,175,60),  small_bag,                         "product", 3736703557),
    ("eggr2",                (20,110,50),  (110,225,120), lambda d: egg(d,(70,200,90)),       "product", 3736703563),
    ("eggr3",                (20,60,160),  (90,160,255),  lambda d: egg(d,(60,140,255)),      "product", 3736703571),
    ("luckpotion_mini",      (20,90,100),  (80,200,200),  potion_mini,                       "product", 3736703579),
    ("eggr4",                (80,20,140),  (170,90,255),  lambda d: egg(d,(160,70,230)),      "product", 3736703588),
    ("arena_tickets",        (110,25,35),  (230,80,70),   arena_ticket,                      "product", 3736703606),
    ("streak_restore",       (190,50,20),  (255,150,40),  streak,                            "product", 3736703610),
    ("emote_victory_1",      (200,30,60),  (255,110,90),  lambda d: victory(d,1),            "product", 3736703619),
    ("emote_victory_2",      (20,80,200),  (60,170,255),  lambda d: victory(d,2),            "product", 3736703629),
    ("emote_victory_3",      (20,140,80),  (90,220,130),  lambda d: victory(d,3),            "product", 3736703634),
    ("emote_victory_4",      (230,130,20), (255,200,60),  lambda d: victory(d,4),            "product", 3736703641),
    ("emote_victory_5",      (110,30,170), (190,100,255), lambda d: victory(d,5),            "product", 3736703649),
    ("emote_victory_6",      (20,130,140), (80,210,220),  lambda d: victory(d,6),            "product", 3736703657),
    ("eggr5",                (150,60,0),   (255,160,30),  lambda d: (egg(d,(255,150,40)), egg_gold_sparkles(d)), "product", 3736703667),
    ("double_luck",          (10,100,45),  (60,200,90),   double_clover,                     "product", 3736703673),
    ("season_premium",       (60,20,120),  (150,70,220),  lambda d: season(d,False),         "product", 3736703683),
    ("season_premium_plus",  (60,20,120),  (150,70,220),  lambda d: season(d,True),          "product", 3736703689),
    ("eggr7",                (200,60,140), (255,190,120), egg_rose,                          "product", 3736703695),
    ("bundle_legend",        (100,30,140), (255,170,60),  bundle_legend,                     "product", 3736703706),
    ("bundle_royal",         (110,40,20),  (220,150,60),  lambda d: chest(d,True),           "product", 3736703714),
    ("season_upgrade_plus",  (10,90,150),  (60,190,230),  upgrade_plus,                      "product", 3736704000),
    ("bundle_royal_nopass",  (40,60,90),   (110,140,190), lambda d: chest(d,False),          "product", 3736704205),
    ("egg_bag_plus",         (110,60,20),  (200,140,60),  egg_bag,                           "pass",    2099454839),
    ("collector",            (40,40,90),   (100,100,190), collector,                         "pass",    2099556764),
    ("lucky2",               (10,100,40),  (60,190,90),   lambda d: double_clover(d,"II"),   "pass",    2102045961),
]

if __name__ == "__main__":
    if sys.argv[1:] == ["--liste"]:
        for nom,_,_,_,typ,ident in ACHATS:
            print(nom, typ, ident)
        sys.exit(0)
    os.makedirs(OUT, exist_ok=True)
    for nom,c1,c2,fn,_,_ in ACHATS:
        im,d=bg(c1,c2); fn(d); im.save(os.path.join(OUT,f"{nom}.png"))
    print(len(ACHATS), "icones ->", OUT)
