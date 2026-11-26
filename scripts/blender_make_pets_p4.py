import sys, json, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_lib import *
from mathutils import Vector
OUT = sys.argv[1]; M = {}
def reg(name, fn):
    reset(); fn(); n, t = export(os.path.join(OUT, name + ".fbx")); M[name] = {"parts": n, "faces": t}
def bar(name, c, base, d, ln, r1, r2, v=8):
    d = Vector(d).normalized(); loc = Vector(base) + d * ln / 2
    cone(name, c, tuple(loc), r1, r2, ln, tuple(d.to_track_quat("Z", "Y").to_euler()), v)
def eyes(z, y, s, r=0.075, eye="1A1A1A", blk=False):
    for k in (-1, 1):
        if blk: box("Oeil", eye, (k*s, y, z), (r*1.3, 0.04, r*1.6))
        else: sph("Oeil", eye, (k*s, y, z), r, (1, 0.6, 1.2), seg=10, rings=6)
        if blk: box("Reflet", "FFFFFF", (k*s*0.9, y-0.025, z+r*0.5), (r*0.5, 0.03, r*0.5))
        else: sph("Reflet", "FFFFFF", (k*s*0.9, y-r*0.6, z+r*0.5), r*0.4, seg=6, rings=4)
def S(k, a, b): return a if k < 0 else b
# 38 Loup gris (B, 22)
def loup():
    c = "7A7F8C"; v = "D6D6DE"; d = "5A5E6A"
    box("Corps", c, (0,0.15,0.55), (0.42,0.8,0.42)); box("Ventre", v, (0,0.1,0.38), (0.3,0.6,0.08))
    for x, y, n in ((-0.15,-0.15,"Patte_AvG"),(0.15,-0.15,"Patte_AvD"),(-0.15,0.45,"Patte_ArG"),(0.15,0.45,"Patte_ArD")):
        box(n, c, (x,y,0.17), (0.14,0.14,0.34)); box("Pied", d, (x,y-0.03,0.03), (0.16,0.2,0.06))
    box("Tete", c, (0,-0.42,0.88), (0.4,0.38,0.36)); box("Museau", v, (0,-0.68,0.8), (0.22,0.22,0.16)); box("Nez", "1E1E1E", (0,-0.8,0.84), (0.08,0.05,0.06))
    for k in (-1,1): box("Oreille", c, (k*0.14,-0.4,1.13), (0.1,0.06,0.2))
    box("Queue", c, (0,0.72,0.55), (0.14,0.5,0.14), (-0.5,0,0)); box("Queue_Bout", d, (0,0.9,0.38), (0.15,0.16,0.15))
    box("Crete", d, (0,0.0,0.78), (0.1,0.6,0.05))
    eyes(0.92, -0.615, 0.12, 0.06, "FFD23F", True)
# 39 Koala (L, 16)
def koala():
    g = "9E9EA8"; l = "D6D6DE"
    sph("Corps", g, (0,0.05,0.38), 0.34, (1,0.9,1.05), seg=12, rings=8); sph("Ventre", l, (0,-0.2,0.36), 0.22, (0.9,0.5,1), seg=10, rings=6)
    sph("Tete", g, (0,-0.08,0.88), 0.3, (1.15,0.95,0.95), seg=14, rings=9); sph("Nez", "2A2A30", (0,-0.34,0.84), 0.08, (1,0.8,1.3), seg=8, rings=5)
    for k in (-1,1):
        sph("Oreille", g, (k*0.3,-0.04,1.08), 0.17, (1,0.5,1), seg=10, rings=6); sph("Oreille_Int", "E6C8D0", (k*0.3,-0.1,1.08), 0.1, (1,0.4,1), seg=8, rings=5)
        sph(S(k,"Jambe_G","Jambe_D"), g, (k*0.22,-0.22,0.12), 0.13, (1,1.5,0.9), seg=8, rings=5)
        sph(S(k,"Bras_G","Bras_D"), g, (k*0.36,-0.12,0.42), 0.1, (0.8,0.8,1.6), seg=8, rings=5)
    eyes(0.92, -0.33, 0.13, 0.05)
# 40 Morse (L, 18)
def morse():
    b = "8B5A44"; l = "A87A62"; t = "F5EBD7"
    sph("Corps", b, (0,0.15,0.36), 0.38, (0.95,1.4,0.9), seg=14, rings=9); sph("Ventre", l, (0,0.0,0.2), 0.25, (1,1.3,0.5), seg=10, rings=6)
    sph("Tete", b, (0,-0.5,0.62), 0.27, (1.1,1,0.95), seg=12, rings=8); sph("Museau", l, (0,-0.7,0.52), 0.2, (1.3,0.8,0.8), seg=10, rings=6)
    sph("Nez", "2A1A1A", (0,-0.83,0.58), 0.05, seg=6, rings=4); sph("Queue", b, (0,0.9,0.2), 0.12, (1.6,1,0.6), seg=8, rings=5)
    for k in (-1,1):
        sph(S(k,"Patte_AvG","Patte_AvD"), b, (k*0.4,-0.18,0.12), 0.13, (1.3,1.6,0.5), seg=8, rings=5)
        sph(S(k,"Patte_ArG","Patte_ArD"), b, (k*0.28,0.75,0.1), 0.13, (1.3,1.5,0.5), seg=8, rings=5)
        bar("Defense", t, (k*0.1,-0.74,0.5), (k*0.08,-0.12,-1), 0.4, 0.05, 0.015, 7); sph("Joue", l, (k*0.17,-0.68,0.55), 0.09, (1,0.9,0.9), seg=8, rings=5)
    eyes(0.7, -0.72, 0.13, 0.05)
# 41 Aigle (B, 20)
def aigle():
    b = "5A3C28"; w = "FAFAFA"; y = "FFB02A"
    box("Corps", b, (0,0.05,0.55), (0.4,0.36,0.5)); box("Ventre", "7A5A40", (0,-0.14,0.5), (0.3,0.05,0.36))
    box("Tete", w, (0,-0.1,0.95), (0.38,0.34,0.32)); box("Bec", y, (0,-0.32,0.9), (0.12,0.16,0.14))
    box("Queue", w, (0,0.36,0.4), (0.22,0.34,0.08), (-0.5,0,0))
    for a in (-0.18, 0.18): box("Plume", b, (a,0.5,0.3), (0.08,0.26,0.05), (-0.5,0,0))
    for k in (-1,1):
        box(S(k,"Jambe_G","Jambe_D"), y, (k*0.12,0,0.14), (0.1,0.1,0.28)); box("Griffe", "2A1A1A", (k*0.12,-0.06,0.03), (0.14,0.12,0.06))
        box(S(k,"Bras_G","Bras_D"), b, (k*0.24,-0.08,0.52), (0.1,0.14,0.3))
        box(S(k,"AileG","AileD"), b, (k*0.62,0.1,0.78), (0.7,0.06,0.5), (0,-k*0.5,0))
    box("Sourcil", "6A4A30", (0,-0.275,1.03), (0.34,0.04,0.05))
    eyes(0.98, -0.275, 0.1, 0.06, "FFD23F", True)
# 42 Anguille électrique (L, 12)
def anguille():
    c = "2E4A5A"; y = "FFE14A"
    sph("Seg1", c, (0,-0.55,0.72), 0.2, (0.95,1.4,0.95), seg=12, rings=8); sph("Seg2", c, (0.12,-0.2,0.36), 0.22, (1,1.5,1), seg=12, rings=8)
    sph("Seg3", c, (-0.12,0.22,0.26), 0.2, (1,1.5,0.95), seg=12, rings=8); sph("Seg4", c, (0.1,0.62,0.17), 0.14, (0.9,1.6,0.8), seg=10, rings=6)
    for p in ((0.12,-0.2,0.6),(-0.12,0.22,0.46),(0.1,0.62,0.3)): sph("Lueur", y, p, 0.06, (1.2,1.2,0.8), seg=6, rings=4)
    sph("Lueur", y, (0,-0.52,0.9), 0.06, seg=6, rings=4)
    eyes(0.76, -0.76, 0.11, 0.045)
# 45 Caméléon (L, 18)
def cameleon():
    g = "5CB256"; y = "FFD23F"
    cyl("Branche", "6A4A2A", (0,0.0,0.07), 0.07, 1.4, (math.pi/2,0,0), 8)
    sph("Corps", g, (0,0.05,0.42), 0.26, (0.8,1.45,1.0), seg=12, rings=8); sph("Ventre", "A8E08A", (0,-0.08,0.34), 0.17, (0.8,1.0,0.6), seg=8, rings=5)
    sph("Tete", g, (0,-0.4,0.62), 0.2, (0.9,1.2,1.0), seg=12, rings=8); sph("Crete", y, (0,-0.35,0.86), 0.1, (0.4,1.3,1.0), seg=8, rings=5)
    for x, y2, n in ((-0.2,-0.12,"Patte_AvG"),(0.2,-0.12,"Patte_AvD"),(-0.2,0.28,"Patte_ArG"),(0.2,0.28,"Patte_ArD")):
        cyl(n, g, (x,y2,0.2), 0.05, 0.3, v=8)
    torus("Queue", g, (0,0.46,0.4), 0.17, 0.045, (0,math.pi/2,0))
    for k in (-1,1):
        sph("Paupiere", g, (k*0.15,-0.46,0.7), 0.09, seg=8, rings=5)
    for yy in (-0.1,0.2): sph("Tache", y, (0,yy,0.66), 0.06, (1,1.2,0.5), seg=6, rings=4)
    eyes(0.71, -0.53, 0.15, 0.06)
    sph("Feuille", "3E8A3A", (0.55,0.0,0.14), 0.11, (1.6,0.9,0.3), seg=6, rings=4)
# 46 Renne (L, 24)
def renne():
    b = "8B6A48"; a = "E3D5B8"; d = "3A2A1E"
    sph("Corps", b, (0,0.15,0.5), 0.26, (0.85,1.5,0.9), seg=14, rings=9)
    for x, y, n in ((-0.13,-0.18,"Patte_AvG"),(0.13,-0.18,"Patte_AvD"),(-0.13,0.5,"Patte_ArG"),(0.13,0.5,"Patte_ArD")):
        cyl(n, b, (x,y,0.2), 0.06, 0.4); cyl("Sabot", d, (x,y,0.035), 0.07, 0.07)
    cyl("Cou", "C9B393", (0,-0.38,0.74), 0.1, 0.32, (0.45,0,0)); sph("Tete", b, (0,-0.52,0.9), 0.17, (0.85,1.3,1), seg=12, rings=8)
    sph("Museau", "C9B393", (0,-0.66,0.84), 0.1, (0.9,1.0,0.8), seg=8, rings=5); sph("Nez", "C23A3A", (0,-0.75,0.85), 0.04, seg=6, rings=4)
    sph("Queue", "F2EAD8", (0,0.66,0.6), 0.07, seg=8, rings=5)
    for k in (-1,1):
        cone("Oreille", b, (k*0.14,-0.48,1.02), 0.05, 0.0, 0.14, (0,k*0.9,0), v=5)
        bar("Bois", a, (k*0.07,-0.5,1.04), (k*0.55,0.25,1), 0.5, 0.03, 0.02, 6); bar("Andouiller", a, (k*0.2,-0.45,1.3), (k*0.3,-1,0.3), 0.22, 0.02, 0.01, 5)
    eyes(0.95, -0.6, 0.11, 0.045)
# 47 Bélier ardent (B, 22)
def belier():
    b = "5A3E28"; o = "FF6A1A"; w = "C9B08A"
    box("Corps", b, (0,0.15,0.55), (0.52,0.8,0.46)); box("Toison", w, (0,-0.2,0.6), (0.5,0.3,0.5))
    for x, y, n in ((-0.17,-0.12,"Patte_AvG"),(0.17,-0.12,"Patte_AvD"),(-0.17,0.45,"Patte_ArG"),(0.17,0.45,"Patte_ArD")): box(n, b, (x,y,0.16), (0.14,0.14,0.32))
    box("Tete", b, (0,-0.55,0.58), (0.36,0.4,0.34), (0.3,0,0)); box("Museau", w, (0,-0.76,0.46), (0.2,0.16,0.14)); box("Nez", "1E1E1E", (0,-0.85,0.45), (0.08,0.04,0.06))
    box("Queue", b, (0,0.58,0.62), (0.12,0.12,0.14))
    for k in (-1,1):
        box("Oreille", b, (k*0.24,-0.5,0.66), (0.1,0.16,0.07), (0,0,k*0.3))
        box("Corne", o, (k*0.26,-0.52,0.72), (0.14,0.3,0.14), (0,0,k*0.3)); box("Corne_Bout", o, (k*0.33,-0.72,0.6), (0.11,0.12,0.18), (0.3,0,k*0.3))
        sph("Flammes", "FFC24A", (k*0.34,-0.78,0.7), 0.06, (0.6,0.6,1.5), seg=6, rings=4)
    eyes(0.62, -0.7, 0.13, 0.05, "FFD23F", True)
# 48 Lynx tonnerre (B, 22)
def lynx():
    c = "C9A27A"; y = "FFE14A"; d = "5A4430"
    box("Corps", c, (0,0.2,0.46), (0.4,0.7,0.36), (-0.12,0,0)); box("Ventre", "EADBC2", (0,0.15,0.3), (0.28,0.5,0.06))
    for x, yy, z, n in ((-0.14,-0.2,0.15,"Patte_AvG"),(0.14,-0.2,0.15,"Patte_AvD"),(-0.14,0.58,0.2,"Patte_ArG"),(0.14,0.58,0.2,"Patte_ArD")): box(n, c, (x,yy,z), (0.13,0.13,z*2))
    box("Tete", c, (0,-0.42,0.66), (0.4,0.36,0.34)); box("Museau", "EADBC2", (0,-0.62,0.6), (0.18,0.12,0.12)); box("Nez", "E89AA8", (0,-0.69,0.63), (0.07,0.04,0.05))
    box("Queue", c, (0,0.72,0.42), (0.12,0.3,0.12)); box("Queue_Bout", d, (0,0.9,0.4), (0.13,0.1,0.13))
    for k in (-1,1):
        box("Oreille", c, (k*0.15,-0.38,0.92), (0.12,0.06,0.18)); box("Pointe", y, (k*0.15,-0.38,1.05), (0.07,0.05,0.12))
        box("Favori", "EADBC2", (k*0.21,-0.52,0.58), (0.08,0.1,0.14)); sph("Eclairs", y, (k*0.24,0.05,0.62), 0.06, (0.5,1,1.5), seg=6, rings=4)
    eyes(0.7, -0.605, 0.11, 0.06, "FFD23F", True)
# 49 Flamant rose (L, 14)
def flamant():
    p = "FF8CB4"
    sph("Corps", p, (0,0.05,0.7), 0.27, (0.8,1.3,0.9), seg=12, rings=8); sph("Tete", p, (0,-0.3,1.0), 0.1, seg=10, rings=6)
    cyl("Cou", p, (0,-0.2,0.86), 0.04, 0.34, (0.5,0,0), 8)
    sph("Bec", "FFB6CE", (0,-0.4,0.98), 0.07, (0.9,1.5,0.8), seg=8, rings=5); sph("Bec_Bout", "1E1E1E", (0,-0.48,0.94), 0.05, (0.9,1.0,0.8), seg=8, rings=5)
    sph("Queue", "FFB6CE", (0,0.38,0.66), 0.1, (0.8,1.4,0.8), seg=8, rings=5)
    cyl("Jambe_G", "FF6A9A", (-0.08,0,0.27), 0.025, 0.54, v=6); cyl("Jambe_D", "FF6A9A", (0.08,-0.1,0.58), 0.025, 0.32, (math.pi/2-0.3,0,0), 6)
    for k in (-1,1): sph(S(k,"Bras_G","Bras_D"), "FFB6CE", (k*0.2,0.08,0.7), 0.12, (0.4,1.3,0.9), seg=8, rings=5)
    eyes(1.02, -0.37, 0.07, 0.035)
# 69 Léviathan (L, 28)
def leviathan():
    b = "1A3A6A"; f = "6FD6FF"
    sph("Seg1", b, (0,-0.75,0.82), 0.24, (1,1.3,1), seg=12, rings=8); sph("Seg2", b, (0,-0.4,0.42), 0.22, (1,1.4,1), seg=12, rings=8)
    sph("Seg3", b, (0,0.0,0.62), 0.26, (1,1.4,1.05), seg=12, rings=8); sph("Seg4", b, (0,0.42,0.3), 0.22, (1,1.4,1), seg=12, rings=8)
    sph("Seg5", b, (0,0.8,0.5), 0.2, (1,1.4,1), seg=12, rings=8); sph("Seg6", b, (0,1.15,0.2), 0.12, (0.9,1.6,0.8), seg=10, rings=6)
    sph("Machoire", "0E2448", (0,-0.9,0.68), 0.15, (1,1.3,0.5), seg=8, rings=5)
    for k in (-1,1):
        sph("Nageoire", f, (k*0.26,-0.4,0.42), 0.12, (0.3,1.4,1.0), seg=6, rings=4); sph("Nageoire", f, (k*0.26,0.42,0.32), 0.1, (0.3,1.4,1.0), seg=6, rings=4)
        cone("Corne", "E6F0FA", (k*0.1,-0.7,1.08), 0.05, 0.0, 0.2, (0,k*0.5,0), v=5); cone("Dent", "FFFFFF", (k*0.09,-1.02,0.74), 0.025, 0.0, 0.1, (math.pi,0,0), v=4)
    for y, z in ((-0.55,0.98),(-0.2,0.6),(0.0,0.9),(0.2,0.78),(0.6,0.6),(0.85,0.68)): bar("Dos", f, (0,y,z), (0,-0.2,1), 0.18, 0.05, 0.0, 4)
    sph("Nageoire_Queue", f, (0,1.3,0.28), 0.1, (1.8,0.4,1.1), seg=6, rings=4); sph("Nageoire_Queue", f, (0,1.3,0.12), 0.1, (1.5,0.4,0.9), seg=6, rings=4)
    torus("Vague", "6FD6FF", (0,0.2,0.04), 0.8, 0.05)
    eyes(0.88, -0.98, 0.14, 0.05, "FFE14A")
# 71 Titan de l'orage (B, 34)
def titan():
    c = "3A3A4A"; l = "4E4E62"; y = "FFE14A"; n = "8A90A8"
    box("Corps", c, (0,0,0.62), (0.52,0.36,0.46)); box("Ceinture", l, (0,0,0.4), (0.54,0.38,0.08))
    box("Tete", c, (0,-0.02,0.98), (0.34,0.32,0.28)); box("Casque", l, (0,0,1.14), (0.36,0.34,0.08))
    for k in (-1,1):
        box(S(k,"Jambe_G","Jambe_D"), c, (k*0.14,0,0.2), (0.18,0.2,0.34)); box("Pied", l, (k*0.14,-0.04,0.04), (0.22,0.3,0.08)); box("Genou", l, (k*0.14,-0.11,0.28), (0.14,0.04,0.1))
        box(S(k,"Bras_G","Bras_D"), c, (k*0.38,-0.02,0.58), (0.14,0.16,0.4)); box("Epaulette", l, (k*0.36,0,0.84), (0.22,0.24,0.1)); box("Poing", l, (k*0.38,-0.02,0.34), (0.18,0.2,0.16))
        box("Pectoral", l, (k*0.12,-0.19,0.72), (0.2,0.04,0.14)); bar("Corne", "E6E6F0", (k*0.12,-0.02,1.12), (k*0.6,0,1), 0.2, 0.04, 0.0, 5)
        bar("Eclairs", y, (k*0.38,-0.1,0.26), (k*0.3,-0.2,-1), 0.14, 0.04, 0.0, 4); bar("Eclairs", y, (k*0.12,-0.2,0.56), (k*0.1,-0.1,-1), 0.16, 0.04, 0.0, 4)
    bar("Eclairs", y, (0,-0.19,0.78), (0.4,0,-0.9), 0.14, 0.05, 0.02, 4); bar("Eclairs", y, (0.05,-0.19,0.66), (-0.4,0,-0.9), 0.14, 0.05, 0.02, 4)
    for i in range(5):
        a = i*2*math.pi/5+0.3; sph("Nuage", n, (math.cos(a)*0.5, math.sin(a)*0.5, 0.1), 0.16, (1,1,0.7), seg=8, rings=5)
    sph("Nuage", n, (0,0,0.04), 0.4, (1,1,0.35), seg=10, rings=6)
    for k in (-1,1): sph("Nuage", "6A6F86", (k*0.25,0.05,1.28), 0.12, (1,1,0.7), seg=8, rings=5)
    eyes(1.0, -0.185, 0.08, 0.05, "FFE14A", True)
for n, f in (("pet_loup_gris",loup),("pet_koala",koala),("pet_morse",morse),("pet_aigle",aigle),("pet_anguille_electrique",anguille),("pet_cameleon",cameleon),("pet_renne",renne),("pet_belier_ardent",belier),("pet_lynx_tonnerre",lynx),("pet_flamant_rose",flamant),("pet_leviathan",leviathan),("pet_titan_de_l_orage",titan)): reg(n, f)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1); print("OK", len(M), {k:(v["parts"],v["faces"]) for k,v in M.items()})
