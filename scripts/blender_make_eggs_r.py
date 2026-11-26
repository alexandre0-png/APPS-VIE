# 10 oeufs de rarete r1..r10 (Chipe-Oeufs). Usage: blender -b -P blender_make_eggs_r.py -- <dossier>
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
OUT = sys.argv[sys.argv.index("--")+1] if "--" in sys.argv else sys.argv[-1]
os.makedirs(OUT, exist_ok=True)
A, C, ZC = 0.37, 0.5, 0.5          # demi-largeur, demi-hauteur, centre z (hauteur 1, origine au socle)
def tp(z): return 1-0.2*(z-ZC)/C
def rad(z): return A*tp(z)*math.sqrt(max(0.0, 1-((z-ZC)/C)**2))
def pt(az, z, off=0.0):
    r = rad(z)+off; return (r*math.sin(az), -r*math.cos(az), z)
def patch(name, hx, az, z, w, h, tilt=0.0, th=0.03):
    """Plaque posee sur la coque a l'azimut az (0 = devant, -y)."""
    box(name, hx, pt(az, z, 0.004), (w, th, h), (0, tilt, az))
def coque(hx, seg=16, rings=12):
    o = sph("Coque", hx, (0,0,ZC), 0.5, (A/0.5, A/0.5, 1.0), seg, rings)
    for v in o.data.vertices:
        f = tp(v.co.z); v.co.x *= f; v.co.y *= f
    return o
def embleme(c, cols=None, tip=None):
    d = 0.17; zc = 0.5; L = d*1.414; y = -(rad(zc)-0.012)
    cols = cols or [c]*4
    for i,(sx,sz,ang) in enumerate([(1,1,45),(-1,1,-45),(1,-1,-45),(-1,-1,45)]):
        box("Embleme", cols[i], (sx*d/2, y, zc+sz*d/2), (L, 0.06, 0.055), (0, math.radians(ang), 0))
    sph("Embleme", tip or c, (0, y, zc+d), 0.04, (1,0.9,1), 8, 6)   # pointe arrondie
def chaine(c, n=7, a0=-1.1, a1=1.0, z0=0.3, z1=0.66):
    for i in range(n):
        t = i/(n-1); az = a0+(a1-a0)*t; z = z0+(z1-z0)*t
        torus("Chaine", c, pt(az, z, 0.03), 0.065, 0.02, (math.pi/2*(i%2), 0, az))
def couronne(c):
    cyl("Couronne", c, (0,0,0.93), 0.25, 0.12, v=10)
    for i in range(5):
        a = i*2*math.pi/5; cone("Couronne", c, (0.21*math.cos(a), 0.21*math.sin(a), 1.1), 0.07, 0.0, 0.24, v=4)
def cristaux(c, n, R, z0=0.1, h=0.22, r=0.05):
    for i in range(n):
        a = i*2*math.pi/n+0.3; cone("Cristaux", c, (R*math.cos(a), R*math.sin(a), z0+h/2), r, 0.0, h, (0.15*math.sin(a),0.15*math.cos(a),0), v=5)
def pixels(c, n=8):
    for i in range(n):
        az = (i*2.4)%(2*math.pi) - math.pi; z = 0.2+0.6*((i*0.37)%1.0)
        if abs(az) < 0.35 and 0.38 < z < 0.64: z = 0.78
        patch("Motif", c, az, z, 0.09, 0.09)

def r1():
    coque("DCDCE6")
    for az,z,w in [(-0.9,0.7,0.1),(0.8,0.3,0.09),(1.3,0.68,0.08)]: patch("Motif","B4B8C4",az,z,w,w)
    embleme("3A3A42")
def r2():
    coque("3CDC3C"); pixels("2EB82E", 9); embleme("A8FF8C")
def r3():
    coque("2E8BFF"); pixels("1450B4", 6); embleme("8CC8FF")
    torus("Anneau","6FB8FF",(0,0,0.5),0.5,0.02,(math.radians(20),0,0))
def r4():
    coque("4A1A8C")
    for az,z,t in [(-1.0,0.7,0.6),(-0.5,0.3,-0.6),(0.9,0.75,0.6),(1.3,0.4,-0.6),(2.3,0.55,0.6),(-2.2,0.5,-0.6)]:
        patch("Motif","9B4DFF",az,z,0.24,0.045,t)
    embleme("C89BFF"); cristaux("C89BFF", 4, 0.4, 0.12, 0.3, 0.07)
def r5():
    coque("FFC21A")
    for az,z in [(-1.0,0.7),(-0.9,0.25),(1.0,0.35),(1.2,0.7),(2.4,0.5),(-2.4,0.4)]: patch("Motif","E8A800",az,z,0.14,0.12,0.5)
    embleme("FFE27A"); couronne("FFD24A")
    torus("Anneau","FFD24A",(0,0,0.07),0.5,0.02)
def r6():
    coque("1A1014")
    for az,z,t in [(-1.0,0.75,0.8),(-0.7,0.25,-0.7),(0.7,0.8,-0.8),(1.1,0.3,0.7),(2.0,0.6,0.5),(-2.0,0.55,-0.5),(0.0,0.9,0.0)]:
        patch("Fissure","FF3020",az,z,0.2,0.025,t)
    patch("Fissure","FF3020",0.15,0.2,0.025,0.16); patch("Fissure","FF3020",-0.2,0.84,0.025,0.14)
    embleme("D82A1A"); chaine("3A3A42")
def r7():
    coque("6FD6FF", 14, 10)
    for az,z in [(-0.9,0.7),(-1.0,0.3),(1.0,0.35),(1.0,0.72),(2.3,0.5),(-2.3,0.55)]: patch("Motif","4FB0E8",az,z,0.15,0.15,0.5)
    embleme("9FE0FF"); cristaux("BFEFFF", 6, 0.42, 0.12, 0.28, 0.06)
def r8():
    coque("0A0A12")
    for az,z,t in [(-0.9,0.7,0.7),(0.9,0.3,0.7),(2.2,0.6,-0.6)]: patch("Motif","5A2AA0",az,z,0.2,0.04,t)
    embleme("FF3030", ["FF3030","FFD030","30FF60","30A0FF"], "A040FF")
    torus("Anneau","FF40C0",(0,0,0.5),0.52,0.02,(math.radians(65),0,math.radians(20)))
    torus("Anneau","40E0FF",(0,0,0.5),0.52,0.02,(math.radians(-65),0,math.radians(-20)))
    for p,c in [((-0.5,-0.2,0.9),"FFE030"),((0.52,-0.1,0.75),"FF50D0"),((0.4,-0.35,0.1),"50E0FF")]:
        sph("Etoiles", c, p, 0.07, (1,0.3,1.0), 4, 2)
def r9():
    coque("F2F2F2")
    for az,z,t in [(-1.0,0.7,0.5),(-0.9,0.3,-0.4),(1.0,0.75,0.4),(1.3,0.4,-0.5),(2.3,0.5,0.5),(-2.2,0.6,-0.5)]:
        patch("Motif","141414",az,z,0.14,0.11,t)
    embleme("141414"); couronne("141414"); chaine("3A3A42", 7, -0.3, 1.5, 0.22, 0.5)
def r10():
    coque("FFF3B0", 16, 12)
    for az,z in [(-0.9,0.72),(-1.0,0.28),(1.0,0.32),(1.0,0.74),(2.3,0.5),(-2.3,0.5)]: patch("Motif","FFFAD8",az,z,0.14,0.14,0.5)
    embleme("FFFBE0")
    for s in (-1,1):
        for k,ang in enumerate((8,30,52)):
            a = math.radians(ang); L = 0.4-0.04*k
            box("Ailes","FFFFFF",(s*(A+0.03+0.5*L*math.cos(a)),0.04+0.045*k,0.55+0.5*L*math.sin(a)),(L,0.04,0.13),(0,-s*a,0))
    torus("Aureole","FFE680",(0,0,1.18),0.2,0.014)
    torus("Anneau","FFE680",(0,0,0.07),0.5,0.02)

for i,f in enumerate([r1,r2,r3,r4,r5,r6,r7,r8,r9,r10], 1):
    reset(); f(); n,t = export(os.path.join(OUT, f"egg_r{i}.fbx"))
    ds = [o for o in bpy.context.scene.objects if o.type=="MESH"]
    mn = [min((o.matrix_world@v.co)[k] for o in ds for v in o.data.vertices) for k in range(3)]
    mx = [max((o.matrix_world@v.co)[k] for o in ds for v in o.data.vertices) for k in range(3)]
    print(f"EGG egg_r{i} parts={n} tris={t} size={mx[0]-mn[0]:.2f}x{mx[1]-mn[1]:.2f}x{mx[2]-mn[2]:.2f}")
