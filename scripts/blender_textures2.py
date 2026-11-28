import numpy as np
from PIL import Image
N=1024; rng=np.random.default_rng(21); yy,xx=np.mgrid[0:N,0:N]
def rgb(h): return np.array([int(h[i:i+2],16) for i in (0,2,4)],float)
def tn(scale,amp):
    base=rng.random((scale,scale)); k=N//scale; 
    img=np.kron(base,np.ones((k,k)));
    # lissage par répétition cyclique (tuilable)
    for _ in range(3): img=(img+np.roll(img,1,0)+np.roll(img,-1,0)+np.roll(img,1,1)+np.roll(img,-1,1))/5
    return (img-0.5)*amp
def multi(amp=40): return tn(8,amp)+tn(32,amp*0.6)+tn(128,amp*0.35)
def save(n,a): Image.fromarray(np.clip(a,0,255).astype(np.uint8)).save(f"tex2/{n}.png")
# herbe
g=rgb("5CA052")[None,None,:]+multi(34)[...,None]*np.array([0.6,1.0,0.5]); 
for _ in range(900):
    x=int(rng.integers(0,N)); y=int(rng.integers(0,N)); g[y%N,x%N]=g[y%N,x%N]*0.85
save("herbe",g)
# terre / chemin
t=rgb("C4B494")[None,None,:]+multi(30)[...,None]
for _ in range(140):
    x=int(rng.integers(0,N)); y=int(rng.integers(0,N)); r=int(rng.integers(4,12)); m=((xx-x)**2+(yy-y)**2)<r*r; t[m]=rgb("8E93A0")*(0.9+rng.random()*0.2)
save("terre_chemin",t)
# pierre chateau (briques)
s=rgb("8E93A0")[None,None,:]+multi(26)[...,None]; bh=64; bw=128
for r in range(0,N,bh):
    off=(r//bh%2)*(bw//2); m=((xx+off)%bw<5); s[(yy>=r)&(yy<r+bh)&m]=rgb("5A5E68")
    s[(yy>=r)&(yy<r+4)]=rgb("5A5E68")
save("pierre_chateau",s)
# dalles chateau
d=rgb("A7ABB5")[None,None,:]+multi(22)[...,None]; q=256
j=((xx%q)<6)|((yy%q)<6); d[j]=rgb("6E7280"); save("dalles_chateau",d)
# bois planches
w=rgb("96622C")[None,None,:]+multi(26)[...,None]*np.array([1,0.8,0.5]); 
for by in range(0,N,128): w[by:by+5]=rgb("4A3220")
for _ in range(14):
    x=int(rng.integers(0,N)); y=int(rng.integers(0,N)); m=((xx-x)**2/3+((yy-y)**2))<60; w[m]=rgb("5A3A1A")
save("bois_planches",w)
# eau
e=rgb("3F8FD0")[None,None,:]+multi(24)[...,None]*np.array([0.5,0.8,1.0]); 
for k in range(6): e+=(np.sin(2*np.pi*(xx*(2+k%3)/N+yy*(3+k)/N)+k)*7)[...,None]
save("eau",e)
# sable
sa=rgb("E3CE94")[None,None,:]+multi(20)[...,None]; save("sable",sa)
# briques cave
b=rgb("8A4B38")[None,None,:]+multi(34)[...,None]; bh=64; bw=128
for r in range(0,N,bh):
    off=(r//bh%2)*(bw//2); b[((xx+off)%bw<6)&(yy>=r)&(yy<r+bh)]=rgb("4A4038"); b[(yy>=r)&(yy<r+5)]=rgb("4A4038")
save("briques_cave",b)
# platre fissure
p=rgb("D8D0C0")[None,None,:]+multi(14)[...,None]
for _ in range(5):
    x=int(rng.integers(0,N)); 
    for y in range(0,N):
        x=(x+int(rng.integers(-2,3)))%N; p[y,x]=rgb("6A6258"); p[y,(x+1)%N]=rgb("8A8278")
save("platre_fissure",p)
# moquette bordeaux / bleue / verte
for n,h in (("moquette_bordeaux","7A2A3A"),("moquette_bleue","2A4A7A"),("moquette_verte","3A6A3A")):
    m=rgb(h)[None,None,:]+ (rng.random((N,N))-0.5)[...,None]*30+multi(16)[...,None]; save(n,m)
# rideau tissu
r=rgb("7A3A3A")[None,None,:]+multi(14)[...,None]; r*= (0.85+0.15*np.sin(2*np.pi*xx/64))[...,None]; save("rideau_tissu",r)
# carreaux bleutes
c=rgb("BFD4DC")[None,None,:]+multi(10)[...,None]; q=128; c[((xx%q)<4)|((yy%q)<4)]=rgb("7A8A92"); save("carreaux_bleutes",c)
print("ok")
