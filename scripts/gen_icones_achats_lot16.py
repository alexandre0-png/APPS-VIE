"""Icônes des achats du lot 16 : 22 produits + 3 passes, 512x512 (version 2, plus claire).

Même style que scripts/gen_icones_achats.py : fonctions de base copiées à
l'identique (ce script n'a pas de garde __main__, l'importer le relancerait),
même fond dégradé, même contour sombre et même cadre arrondi.

Version 2 : œufs de rareté distingués par la forme et le motif + bandeau de
rareté (1 à 5 étoiles), BundleRoyalNoPass avec ruban « passe barré »,
BundleLegend (1 œuf Ultra Rare + 3 œufs Légendaires, badge x4), échelle
Season (bronze -> or +10), et un accessoire différent pour chaque victoire.

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
DARK=(30,30,40)

def txt(d,x,y,s,size,fill=(30,30,40)):
    d.text((x,y),s,fill=fill,font=ImageFont.load_default(size=size),anchor="mm")

def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))

def poly_thick(d,pts,fill,w=8):
    """Polygone rempli avec contour sombre d'épaisseur w."""
    d.polygon(pts,fill=fill)
    n=len(pts)
    for i in range(n): d.line([pts[i],pts[(i+1)%n]],fill=DARK,width=w)

def rot_rect(d,cx,cy,w,h,ang,fill):
    a=math.radians(ang); c,s=math.cos(a),math.sin(a)
    pts=[(cx+x*c-y*s,cy+x*s+y*c) for x,y in ((-w/2,-h/2),(w/2,-h/2),(w/2,h/2),(-w/2,h/2))]
    poly_thick(d,pts,fill,w=4)

def sparkle(d,x,y,r,c=(255,250,210)):
    pts=[(x,y-r),(x+r*0.22,y-r*0.22),(x+r,y),(x+r*0.22,y+r*0.22),(x,y+r),(x-r*0.22,y+r*0.22),(x-r,y),(x-r*0.22,y-r*0.22)]
    d.polygon(pts,fill=c,outline=DARK)

def leaf_poly(bx,by,tx,ty,w,n=24):
    dx,dy=tx-bx,ty-by; L=math.hypot(dx,dy); nx,ny=-dy/L,dx/L
    a=[];b=[]
    for i in range(n+1):
        t=i/n; cx,cy=bx+dx*t,by+dy*t; off=w*math.sin(math.pi*t)
        a.append((cx+nx*off,cy+ny*off)); b.append((cx-nx*off,cy-ny*off))
    return a+b[::-1]

def egg_grad(d,box,c1,c2,steps=28):
    """Coque en dégradé radial (c1 au bord, c2 au reflet), contour sombre."""
    x0,y0,x1,y1=box; cx=(x0+x1)/2; cy=(y0+y1)/2; rx=(x1-x0)/2; ry=(y1-y0)/2
    for i in range(steps):
        t=i/(steps-1); s=1-0.92*t
        ox=-0.28*rx*t; oy=-0.32*ry*t
        d.ellipse((cx+ox-rx*s,cy+oy-ry*s,cx+ox+rx*s,cy+oy+ry*s),fill=lerp(c1,c2,t))
    d.ellipse(box,outline=DARK,width=8)

def egg_box(cx=256,cy=235,rx=100,ry=140): return (cx-rx,cy-ry,cx+rx,cy+ry)

def rarity_band(d,n):
    """Pastille de rareté en bas : n étoiles (1 à 5), sans texte."""
    d.rounded_rectangle((136,420,376,474),26,fill=(40,40,55),outline=(255,255,255),width=6)
    for i in range(n):
        star(d,256+(i-(n-1)/2)*38,447,17,(255,215,60))

def egg_r2(d):
    """Peu commun : coque lisse + 1 feuille."""
    o(d,d.ellipse,egg_box(),fill=(70,200,90))
    pts=leaf_poly(262,104,346,36,26)
    poly_thick(d,pts,(150,235,110),w=7)
    d.line((262,104,346,36),fill=DARK,width=6)
    rarity_band(d,1)

def egg_r3(d):
    """Rare : 2 étoiles + reflet."""
    o(d,d.ellipse,egg_box(),fill=(60,140,255))
    d.arc((180,130,236,240),200,250,fill=(255,255,255),width=18)
    star(d,196,196,26,(255,255,255))
    star(d,322,278,20,(255,255,255))
    rarity_band(d,2)

def egg_r4(d):
    """Épique : 3 cristaux violets + aura."""
    x0,y0,x1,y1=egg_box()
    for e in (22,44):
        d.ellipse((x0-e,y0-e*1.3,x1+e,y1+e*1.3),outline=(225,180,255),width=8)
    for cx,cy,w,h in ((112,240,30,56),(400,240,30,56),(256,58,22,44)):
        poly_thick(d,[(cx,cy-h),(cx+w,cy),(cx,cy+h),(cx-w,cy)],(190,110,255),w=6)
    o(d,d.ellipse,egg_box(),fill=(160,70,230))
    d.arc((180,130,236,240),200,250,fill=(230,200,255),width=14)
    rarity_band(d,3)

def egg_r5(d):
    """Légendaire : couronne + rayons dorés."""
    cx,cy=256,235
    for k in range(10):
        a=math.radians(k*36)
        p=[(cx,cy),(cx+215*math.cos(a-math.radians(5)),cy+215*math.sin(a-math.radians(5))),
           (cx+215*math.cos(a+math.radians(5)),cy+215*math.sin(a+math.radians(5)))]
        d.polygon(p,fill=(255,236,140))
    o(d,d.ellipse,egg_box(),fill=(255,170,40))
    d.arc((180,130,236,240),200,250,fill=(255,240,190),width=14)
    crown_at(d,256,72,0.5)
    rarity_band(d,4)

def egg_r7(d):
    """Ultra Rare : coque dégradé rose-or, anneau doré, étincelles."""
    box=egg_box()
    egg_grad(d,box,(235,100,160),(255,225,130))
    x0,y0,x1,y1=box
    d.ellipse((x0-16,y0+100,x1+16,y0+150),outline=DARK,width=20)
    d.ellipse((x0-16,y0+100,x1+16,y0+150),outline=(255,205,60),width=10)
    sparkle(d,108,130,26); sparkle(d,404,150,32); sparkle(d,112,330,18); sparkle(d,404,330,20)
    rarity_band(d,5)

def pass_ribbon(d):
    """Ruban violet barré d'un trait rouge (passe non inclus)."""
    p1=(360,36); p2=(500,176); w=60
    ux,uy=p2[0]-p1[0],p2[1]-p1[1]; L=math.hypot(ux,uy); ux/=L; uy/=L; nx,ny=-uy,ux
    pts=[(p1[0]+nx*w/2,p1[1]+ny*w/2),(p2[0]+nx*w/2,p2[1]+ny*w/2),(p2[0]-nx*w/2,p2[1]-ny*w/2),(p1[0]-nx*w/2,p1[1]-ny*w/2)]
    poly_thick(d,pts,(140,60,220),w=7)
    C=((p1[0]+p2[0])/2,(p1[1]+p2[1])/2)
    a=(C[0]+nx*56,C[1]+ny*56); b=(C[0]-nx*56,C[1]-ny*56)
    d.line((a,b),fill=DARK,width=22)
    d.line((a,b),fill=(235,40,50),width=11)

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

# Accessoires des victoires : tenus près de la main droite, échelle K.
K=1.4
def _p(cx,cy,x,y): return (cx+x*K,cy+y*K)
def _box(cx,cy,x0,y0,x1,y1): return (cx+x0*K,cy+y0*K,cx+x1*K,cy+y1*K)

def acc_medal(d,cx,cy):
    poly_thick(d,[_p(cx,cy,-28,-64),_p(cx,cy,-8,-64),_p(cx,cy,-2,-20),_p(cx,cy,-22,-20)],(230,50,70),w=7)
    poly_thick(d,[_p(cx,cy,8,-64),_p(cx,cy,28,-64),_p(cx,cy,22,-20),_p(cx,cy,2,-20)],(60,120,255),w=7)
    d.ellipse(_box(cx,cy,-34,-20,34,48),fill=(255,205,60),outline=DARK,width=7)
    star(d,*_p(cx,cy,0,14),int(18*K),(255,240,150))

def acc_cup(d,cx,cy):
    poly_thick(d,[_p(cx,cy,-40,-50),_p(cx,cy,40,-50),_p(cx,cy,28,0),_p(cx,cy,-28,0)],(255,205,60),w=7)
    o(d,d.rectangle,_box(cx,cy,-8,0,8,30),fill=(255,205,60),w=7)
    o(d,d.rectangle,_box(cx,cy,-30,30,30,42),fill=(255,205,60),w=7)

def acc_flag(d,cx,cy):
    o(d,d.rectangle,_box(cx,cy,-30,-62,-20,56),fill=(120,70,30),w=6)
    x0,y0=cx-20*K,cy-62*K; cw,ch=15.5*K,25*K
    d.rectangle((x0,y0,x0+4*cw,y0+2*ch),fill=(255,255,255))
    for col in range(4):
        for row in range(2):
            if (col+row)%2==0:
                d.rectangle((x0+col*cw,y0+row*ch,x0+(col+1)*cw,y0+(row+1)*ch),fill=DARK)
    d.rectangle((x0,y0,x0+4*cw,y0+2*ch),outline=DARK,width=6)

def acc_confetti(d,cx,cy):
    for dx,dy,ang,c in ((-50,-30,30,(255,80,120)),(0,-60,-20,(255,220,60)),(48,-36,70,(90,220,255)),
                        (-30,-8,-40,(120,255,140)),(30,0,10,(255,140,60)),(-60,20,60,(200,120,255)),
                        (60,22,-30,(255,255,255))):
        rot_rect(d,cx+dx*K,cy+dy*K,24*K,13*K,ang,c)

def acc_trophy(d,cx,cy):
    d.arc(_box(cx,cy,-62,-40,-22,6),90,270,fill=DARK,width=20)
    d.arc(_box(cx,cy,22,-40,62,6),-90,90,fill=DARK,width=20)
    d.arc(_box(cx,cy,-62,-40,-22,6),90,270,fill=(255,205,60),width=10)
    d.arc(_box(cx,cy,22,-40,62,6),-90,90,fill=(255,205,60),width=10)
    poly_thick(d,[_p(cx,cy,-36,-52),_p(cx,cy,36,-52),_p(cx,cy,24,-4),_p(cx,cy,-24,-4)],(255,205,60),w=7)
    star(d,*_p(cx,cy,0,-28),int(14*K),(255,255,255))
    o(d,d.rectangle,_box(cx,cy,-7,-4,7,26),fill=(255,205,60),w=7)
    o(d,d.rectangle,_box(cx,cy,-30,26,30,40),fill=(255,205,60),w=7)

def acc_crown(d,cx,cy):
    crown_at(d,cx,cy,0.42*K)

ACC={1:acc_medal,2:acc_cup,3:acc_flag,4:acc_confetti,5:acc_trophy,6:acc_crown}

def arrow(d,x1,y1,x2,y2,w=34,hd=52,fill=(120,255,160)):
    L=math.hypot(x2-x1,y2-y1); ux,uy=(x2-x1)/L,(y2-y1)/L; nx,ny=-uy,ux
    bx,by=x2-ux*hd,y2-uy*hd
    shaft=[(x1+nx*w/2,y1+ny*w/2),(bx+nx*w/2,by+ny*w/2),(bx-nx*w/2,by-ny*w/2),(x1-nx*w/2,y1-ny*w/2)]
    head=[(bx+nx*hd*0.8,by+ny*hd*0.8),(x2,y2),(bx-nx*hd*0.8,by-ny*hd*0.8)]
    poly_thick(d,shaft,fill,w=7)
    poly_thick(d,head,fill,w=7)

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
    ACC[n](d,396,128)

def season_bronze(d):
    star(d,256,200,125,(205,127,50))
    o(d,d.rounded_rectangle,(96,330,416,396),18,fill=(170,60,230))
    o(d,d.polygon,[(140,380),(106,462),(146,452),(176,396)],fill=(120,30,180),w=6)
    o(d,d.polygon,[(372,380),(406,462),(366,452),(336,396)],fill=(120,30,180),w=6)

def season_gold(d):
    star(d,256,200,125,(255,215,60))
    txt(d,256,200,"+10",76,(120,60,0))
    o(d,d.rounded_rectangle,(96,330,416,396),18,fill=(170,60,230))
    o(d,d.polygon,[(140,380),(106,462),(146,452),(176,396)],fill=(120,30,180),w=6)
    o(d,d.polygon,[(372,380),(406,462),(366,452),(336,396)],fill=(120,30,180),w=6)

def season_upgrade(d):
    star(d,150,350,78,(205,127,50))
    arrow(d,214,306,286,242,w=46,hd=66)
    star(d,352,170,100,(255,215,60))
    txt(d,352,170,"+10",64,(120,60,0))

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

def egg_small(d,cx,cy,rx,ry,c,spots=True):
    o(d,d.ellipse,(cx-rx,cy-ry,cx+rx,cy+ry),fill=c)
    if spots:
        for dx,dy in ((-0.35,-0.35),(0.3,0.05),(-0.1,0.35)):
            x=cx+dx*rx; y=cy+dy*ry; r=max(6,int(rx*0.14))
            d.ellipse((x-r,y-r,x+r,y+r),fill=(255,255,255))

def bundle_legend(d):
    """1 œuf Ultra Rare (grand, rose-or) + 3 œufs Légendaires (petits, dorés, couronnés), badge x4."""
    egg_grad(d,(156,40,356,300),(235,100,160),(255,225,130))
    for cx,cy,rx,ry in ((136,360,52,72),(376,360,52,72),(256,388,58,78)):
        o(d,d.ellipse,(cx-rx,cy-ry,cx+rx,cy+ry),fill=(255,200,50))
        d.ellipse((cx-rx*0.5,cy-ry*0.6,cx-rx*0.1,cy-ry*0.2),fill=(255,250,210))
        crown_at(d,cx,cy-ry-6,0.2)
    d.ellipse((370,40,462,132),fill=(255,255,255),outline=DARK,width=6)
    txt(d,416,86,"x4",64,DARK)

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

# ---- Achats : (nom de fichier, fond 1, fond 2, dessin, type, id) ----
ACHATS = [
    ("coinpacks",            (150,90,20),  (255,175,60),  small_bag,                         "product", 3736703557),
    ("eggr2",                (20,110,50),  (110,225,120), egg_r2,                            "product", 3736703563),
    ("eggr3",                (20,60,160),  (90,160,255),  egg_r3,                            "product", 3736703571),
    ("luckpotion_mini",      (20,90,100),  (80,200,200),  potion_mini,                       "product", 3736703579),
    ("eggr4",                (80,20,140),  (170,90,255),  egg_r4,                            "product", 3736703588),
    ("arena_tickets",        (110,25,35),  (230,80,70),   arena_ticket,                      "product", 3736703606),
    ("streak_restore",       (190,50,20),  (255,150,40),  streak,                            "product", 3736703610),
    ("emote_victory_1",      (200,30,60),  (255,110,90),  lambda d: victory(d,1),            "product", 3736703619),
    ("emote_victory_2",      (20,80,200),  (60,170,255),  lambda d: victory(d,2),            "product", 3736703629),
    ("emote_victory_3",      (20,140,80),  (90,220,130),  lambda d: victory(d,3),            "product", 3736703634),
    ("emote_victory_4",      (230,130,20), (255,200,60),  lambda d: victory(d,4),            "product", 3736703641),
    ("emote_victory_5",      (110,30,170), (190,100,255), lambda d: victory(d,5),            "product", 3736703649),
    ("emote_victory_6",      (20,130,140), (80,210,220),  lambda d: victory(d,6),            "product", 3736703657),
    ("eggr5",                (150,60,0),   (255,160,30),  egg_r5,                            "product", 3736703667),
    ("double_luck",          (10,100,45),  (60,200,90),   double_clover,                     "product", 3736703673),
    ("season_premium",       (60,20,120),  (150,70,220),  season_bronze,                     "product", 3736703683),
    ("season_premium_plus",  (60,20,120),  (150,70,220),  season_gold,                       "product", 3736703689),
    ("eggr7",                (200,60,140), (255,190,120), egg_r7,                            "product", 3736703695),
    ("bundle_legend",        (100,30,140), (255,170,60),  bundle_legend,                     "product", 3736703706),
    ("bundle_royal",         (110,40,20),  (220,150,60),  lambda d: chest(d,True),           "product", 3736703714),
    ("season_upgrade_plus",  (10,90,150),  (60,190,230),  season_upgrade,                    "product", 3736704000),
    ("bundle_royal_nopass",  (40,60,90),   (110,140,190), lambda d: (chest(d,False), pass_ribbon(d)), "product", 3736704205),
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
