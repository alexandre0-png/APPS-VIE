from PIL import Image, ImageDraw, ImageFont
import math
S=512
def bg(c1,c2):
    im=Image.new("RGB",(S,S)); px=im.load()
    for y in range(S):
        for x in range(S):
            t=(x*0.4+y*0.6)/S; px[x,y]=tuple(int(c1[i]*(1-t)+c2[i]*t) for i in range(3))
    d=ImageDraw.Draw(im); d.rounded_rectangle((8,8,S-8,S-8),60,outline=(255,255,255),width=10); return im,d
def o(d,fn,*a,fill,w=8,**k): fn(*a,fill=fill,outline=(30,30,40),width=w,**k)
def star(d,cx,cy,r,fill):
    pts=[(cx+(r if i%2==0 else r*0.45)*math.sin(i*math.pi/5),cy-(r if i%2==0 else r*0.45)*math.cos(i*math.pi/5)) for i in range(10)]; d.polygon(pts,fill=fill,outline=(30,30,40))
def lamp(d,gold=False):
    c=(255,215,90) if gold else (240,240,250)
    d.polygon([(256,150),(130,420),(382,420)],fill=(255,240,160,))
    o(d,d.rounded_rectangle,(190,110,322,250),20,fill=c); o(d,d.rectangle,(215,250,297,380),fill=(90,90,110)); o(d,d.ellipse,(200,330,312,420),fill=c)
def battery(d): o(d,d.rounded_rectangle,(150,150,362,420),30,fill=(80,200,110)); o(d,d.rectangle,(220,110,292,150),fill=(220,220,230)); d.polygon([(280,190),(220,300),(260,300),(236,390),(310,265),(268,265)],fill=(255,240,90),outline=(30,30,40))
def stones(d):
    for (x,y,r,c) in ((190,320,70,(150,150,160)),(320,330,60,(120,120,130)),(256,230,64,(170,170,180)),(160,220,44,(130,130,140)),(350,220,46,(160,160,170))): o(d,d.ellipse,(x-r,y-r,x+r,y+r),fill=c)
def heart(d,c=(240,80,100)):
    d.polygon([(256,420),(110,270),(150,170),(256,230),(362,170),(402,270)],fill=c,outline=(30,30,40)); d.ellipse((110,130,260,260),fill=c); d.ellipse((252,130,402,260),fill=c)
def coin(d,x=256,y=256,r=130,t="x2"):
    o(d,d.ellipse,(x-r,y-r,x+r,y+r),fill=(255,205,60)); o(d,d.ellipse,(x-r+22,y-r+22,x+r-22,y+r-22),fill=(255,225,110),w=4)
def clover(d):
    for dx,dy in ((-60,-60),(60,-60),(-60,60),(60,60)): o(d,d.ellipse,(256+dx-70,256+dy-70,256+dx+70,256+dy+70),fill=(70,200,90))
    d.line((256,300,310,440),fill=(30,120,50),width=22)
def bolt(d,c=(255,230,70)): d.polygon([(290,80),(150,290),(240,290),(210,440),(370,210),(280,210)],fill=c,outline=(30,30,40))
def shoe(d): o(d,d.rounded_rectangle,(120,260,400,380),40,fill=(80,150,240)); o(d,d.rounded_rectangle,(120,330,400,400),30,fill=(240,240,250)); o(d,d.rounded_rectangle,(200,170,330,290),30,fill=(100,170,255))
def crown(d): d.polygon([(110,380),(130,200),(200,290),(256,170),(312,290),(382,200),(402,380)],fill=(255,205,60),outline=(30,30,40)); [o(d,d.ellipse,(x-18,y-18,x+18,y+18),fill=(230,60,90),w=5) for x,y in ((190,350),(256,350),(322,350))]
def gift(d): o(d,d.rectangle,(120,230,392,420),fill=(240,90,120)); o(d,d.rectangle,(100,180,412,250),fill=(255,130,150)); d.rectangle((230,180,282,420),fill=(255,220,90)); o(d,d.ellipse,(170,110,262,190),fill=(255,220,90),w=6); o(d,d.ellipse,(250,110,342,190),fill=(255,220,90),w=6)
def egg(d,c=(200,120,255),spots=True):
    o(d,d.ellipse,(150,90,362,430),fill=c)
    if spots:
        for x,y in ((220,200),(300,260),(240,330)): d.ellipse((x-16,y-16,x+16,y+16),fill=(255,255,255))
def potion(d): o(d,d.ellipse,(130,210,382,430),fill=(90,230,130)); o(d,d.rectangle,(220,110,292,250),fill=(200,230,240)); o(d,d.rectangle,(205,90,307,120),fill=(150,100,60)); [o(d,d.ellipse,(x-14,y-14,x+14,y+14),fill=(220,255,230),w=4) for x,y in ((220,330),(290,300),(260,380))]
def bag(d): o(d,d.ellipse,(120,190,392,430),fill=(200,150,70)); o(d,d.polygon,[(200,200),(160,110),(352,110),(312,200)],fill=(220,170,90)); o(d,d.rectangle,(190,190,322,215),fill=(240,60,90)); coin(d,256,330,60)
def vip(d): crown(d)
def support(d): heart(d,(255,110,150))

def raven(d):
    o(d,d.ellipse,(130,200,380,400),fill=(40,40,55)); o(d,d.ellipse,(300,130,420,250),fill=(40,40,55)); d.polygon([(410,185),(470,205),(410,225)],fill=(255,170,40),outline=(30,30,40)); d.ellipse((365,165,385,185),fill=(255,255,255)); d.polygon([(150,280),(60,200),(120,330)],fill=(60,60,80),outline=(30,30,40))
def belt(d,gold=False):
    c=(255,205,60) if gold else (110,110,125)
    o(d,d.rounded_rectangle,(70,300,442,380),30,fill=c)
    for x in (110,200,290,380): o(d,d.ellipse,(x-24,330,x+24,378),fill=(60,60,70),w=5)
    egg(d,(240,240,250) if not gold else (255,240,160),False); 
def slots(d):
    for i,(x,y) in enumerate(((150,150),(300,150),(150,300),(300,300))): o(d,d.rounded_rectangle,(x-55,y-55,x+55,y+55),20,fill=(230,230,245)); o(d,d.ellipse,(x-28,y-38,x+28,y+38),fill=(255,190,90),w=5)
    d.rectangle((236,235,276,275),fill=(60,200,100)); d.rectangle((246,225,266,285),fill=(60,200,100))
def serverluck(d): clover(d); star(d,380,130,50,(255,230,70))

def egg_rare(d,kind):
    if kind=="secret":
        o(d,d.ellipse,(150,90,362,430),fill=(12,12,24)); 
        for i,c in enumerate(((255,60,60),(255,200,40),(60,220,90),(60,140,255),(180,80,255))): d.ellipse((190+i*0,230,322,330),outline=c,width=10-i*1) if False else None
        o(d,d.ellipse,(110,220,402,300),fill=None,w=0) if False else None
        for i,c in enumerate(((255,60,60),(255,200,40),(60,220,90),(60,140,255))): d.arc((110-i*8,170-i*8,402+i*8,350+i*8),20,200,fill=c,width=9)
        star(d,400,120,50,(255,230,70)); star(d,110,380,38,(120,240,255))
    elif kind=="exclusive":
        o(d,d.ellipse,(150,110,362,430),fill=(240,240,240)); 
        for (x,y,r) in ((210,220,26),(300,300,30),(250,370,20),(320,200,16)): d.ellipse((x-r,y-r,x+r,y+r),fill=(20,20,20))
        d.polygon([(170,130),(185,60),(220,100),(256,45),(292,100),(327,60),(342,130)],fill=(25,25,30),outline=(255,255,255))
    else:
        for s in (-1,1): d.polygon([(256+s*60,300),(256+s*230,170),(256+s*210,260),(256+s*250,300),(256+s*190,340),(256+s*60,360)],fill=(255,255,255),outline=(30,30,40))
        o(d,d.ellipse,(170,100,342,420),fill=(255,243,176)); d.ellipse((180,50,332,95),outline=(255,230,128),width=12)
        star(d,256,260,40,(255,255,255))
ITEMS={
 "lampe_renforcee":((60,60,110),(120,120,200),lambda d:lamp(d)),
 "lanterne_doree":((120,80,10),(230,170,40),lambda d:lamp(d,True)),
 "pile":((30,90,50),(80,190,110),battery),
 "cailloux":((70,70,90),(140,140,160),stones),
 "soutien":((140,40,80),(240,110,150),support),
 "coins2x":((160,110,10),(255,200,60),lambda d:(coin(d),d.text((256,256),"x2",fill=(120,70,0),font=ImageFont.load_default(size=150),anchor="mm"))),
 "lucky":((20,100,50),(90,210,120),clover),
 "fast":((30,80,160),(90,170,255),bolt),
 "speed":((20,60,150),(80,140,240),shoe),
 "vipbase":((90,30,140),(190,110,240),vip),
 "starterpack":((140,30,70),(250,110,140),gift),
 "exclusiveegg":((90,30,140),(220,120,255),egg),
 "revive":((140,30,50),(240,90,110),lambda d:heart(d)),
 "instanthatch":((160,110,20),(255,210,90),lambda d:(egg(d,(255,240,200),False),bolt(d))),
 "luckpotion":((20,100,60),(90,220,140),potion),
 "extraslots":((20,60,120),(80,150,230),slots),
 "privatebelt":((60,60,90),(130,130,170),lambda d:belt(d)),
 "serverluck":((20,100,50),(110,220,130),serverluck),
 "goldenbelt":((140,90,10),(255,200,60),lambda d:belt(d,True)),
 "remotesteal":((30,30,50),(90,90,130),raven),
 "remotestealpack":((50,30,70),(140,100,190),raven),
 "oeufsecret":((10,10,30),(90,40,160),lambda d:egg_rare(d,"secret")),
 "oeufexclusif":((30,30,40),(120,120,140),lambda d:egg_rare(d,"exclusive")),
 "oeufdivin":((150,110,10),(255,235,150),lambda d:egg_rare(d,"divine")),
 "coinpack":((120,70,20),(220,160,70),bag),
}
for k,(c1,c2,fn) in ITEMS.items():
    im,d=bg(c1,c2); fn(d); im.save(f"{k}.png")
print(len(ITEMS))
