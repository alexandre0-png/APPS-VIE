import numpy as np, os
from PIL import Image
N=1024; rng=np.random.default_rng(7)
def noise(s, amp):
    return (rng.random((N,N))-0.5)*amp
def tile_noise(scale, amp):
    k=N//scale; base=rng.random((scale,scale)); img=np.kron(base,np.ones((k,k)))
    return (img-0.5)*amp
def save(name, arr):
    arr=np.clip(arr,0,255).astype(np.uint8); Image.fromarray(arr).save(f"tex/{name}.png")
def rgb(h): return np.array([int(h[i:i+2],16) for i in (0,2,4)],float)
yy,xx=np.mgrid[0:N,0:N]
# damier cuisine : 8x8 carreaux, joints sales
c=8; s=N//c; chk=((xx//s)+(yy//s))%2; A=rgb("E4DFD2"); B=rgb("232323")
img=np.where(chk[...,None]==0,A,B)+noise(0,14)[...,None]
j=((xx%s)<4)|((yy%s)<4); img[j]=rgb("6A675F"); save("damier_cuisine",img)
# parquet chevrons
img=np.zeros((N,N,3)); w=64; L=256
base=[rgb(h) for h in ("9A6A3A","8A5A2E","A87A44","7E5028")]
for by in range(0,N,w):
    for bx in range(0,N,L//2):
        k=(bx//(L//2)+by//w)%4; col=base[k]*(1+rng.uniform(-0.06,0.06)); img[by:by+w,bx:bx+L//2]=col
img+=tile_noise(256,16)[...,None]; img[(xx%(L//2))<3]=rgb("4A3220"); img[(yy%w)<3]=rgb("4A3220"); save("parquet_chevrons",img)
# lames larges
img=np.zeros((N,N,3)); w=128
for i,by in enumerate(range(0,N,w)):
    col=rgb(("8C6238","7C5430","9A6D40","866036")[i%4]); img[by:by+w]=col
    sh=int(rng.integers(0,N)); img[by:by+w]=np.roll(img[by:by+w],sh,axis=1)*(1+rng.uniform(-0.05,0.05))
img+=tile_noise(128,14)[...,None]; img[(yy%w)<4]=rgb("3A2410")
for _ in range(10):
    x=int(rng.integers(0,N)); y=int(rng.integers(0,N)); img[(xx-x)**2+((yy-y)**2)*3<100]*=0.7
save("lames_plancher",img)
# dalles de cave
img=np.zeros((N,N,3)); s=256
for ty in range(0,N,s):
    for tx in range(0,N,s):
        g=rng.uniform(95,125); img[ty:ty+s,tx:tx+s]=np.array([g,g,g*0.98])
img+=tile_noise(128,22)[...,None]; j=((xx%s)<10)|((yy%s)<10); img[j]=rgb("3B4A33"); img[j]+=noise(0,12)[j][...,None] if False else 0; save("dalles_cave",img)
# marbre veiné
img=np.zeros((N,N,3))+rgb("E8E4DC"); v=np.sin((xx*0.012+yy*0.007)*2*np.pi*3+np.sin(yy*0.02*2*np.pi/3)*3)
vein=(np.abs(v)<0.04); img[vein]=rgb("8A8A92"); img+=tile_noise(64,10)[...,None]; save("marbre_veine",img)
# papier peint fleuri
img=np.zeros((N,N,3))+rgb("E6DCC0")
for cy in range(128,N,256):
    for cx in range(128,N,256):
        for dx,dy in ((0,0),(128,128)):
            X=cx+dx; Y=cy+dy; X%=N; Y%=N
            d=np.minimum(np.abs(xx-X),N-np.abs(xx-X))**2+np.minimum(np.abs(yy-Y),N-np.abs(yy-Y))**2
            img[d<38**2]=rgb("B07A7A"); img[d<14**2]=rgb("E8C06A")
img+=tile_noise(128,10)[...,None]; save("papier_fleuri",img)
# papier enfant
img=np.zeros((N,N,3))+rgb("F4D4DC"); img[(xx//64)%2==0]=rgb("EBBFCB")
for cy in range(64,N,128):
    for cx in range(64,N,128):
        d=(xx-cx)**2+(yy-cy)**2; img[d<14**2]=rgb("F4D87A")
img+=tile_noise(128,8)[...,None]; save("papier_enfant",img)
# faïence murale
img=np.zeros((N,N,3))+rgb("D8E4E8"); s=64; img+=tile_noise(16,12)[...,None]*0+tile_noise(32,8)[...,None]
j=((xx%s)<3)|((yy%s)<3); img[j]=rgb("8A9096"); save("faience_murale",img)
print("ok")
