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
# 30 Chauve-souris (B, 14)
def chauve():
    c = "3A2E4A"; w = "4A3C5E"
    box("Corps", c, (0,0,0.46), (0.38,0.3,0.42)); box("Tete", c, (0,-0.03,0.82), (0.42,0.36,0.34))
    for k in (-1,1):
        box("Oreille", c, (k*0.15,0,1.07), (0.11,0.07,0.24)); box("AileG" if k<0 else "AileD", w, (k*0.58,0.1,0.66), (0.7,0.04,0.5), (0,k*0.2,k*0.15))
        box("Bras_G" if k<0 else "Bras_D", c, (k*0.25,-0.05,0.5), (0.1,0.1,0.24)); box("Jambe_G" if k<0 else "Jambe_D", c, (k*0.1,0,0.1), (0.11,0.11,0.22))
    eyes(0.84, -0.21, 0.1, 0.075, "FFE060", True)
# 31 Perroquet (B, 16)
def perroquet():
    box("Perchoir", "8B5A2B", (0,0,0.04), (0.7,0.1,0.08))
    for k in (-1,1):
        box("Jambe_G" if k<0 else "Jambe_D", "FFB02A", (k*0.1,0,0.15), (0.08,0.08,0.18))
        box("AileG" if k<0 else "AileD", "2E8BFF", (k*0.27,0.08,0.55), (0.09,0.36,0.5), (0,0,k*0.08))
        box("Bras_G" if k<0 else "Bras_D", "E83A3A", (k*0.22,-0.1,0.5), (0.08,0.12,0.2))
    box("Corps", "E83A3A", (0,0.04,0.55), (0.4,0.36,0.5)); box("Tete", "E83A3A", (0,-0.08,0.97), (0.38,0.36,0.34))
    box("Bec", "F5F0E0", (0,-0.3,0.92), (0.14,0.18,0.16)); box("Queue", "2E8BFF", (0,0.28,0.34), (0.16,0.14,0.52), (-0.3,0,0)); box("Crete", "FFD23F", (0,-0.06,1.2), (0.1,0.1,0.18))
    eyes(1.0, -0.265, 0.11, 0.07, "1A1A1A", True)
# 32 Salamandre (L, 14)
def salamandre():
    o = "FF7A1A"; sph("Corps", o, (0,0.15,0.3), 0.3, (1,1.5,0.85)); sph("Tete", o, (0,-0.38,0.62), 0.33, (1,0.95,0.9), seg=14, rings=9)
    for k in (-1,1):
        sph("Patte_AvG" if k<0 else "Patte_AvD", o, (k*0.3,-0.12,0.1), 0.1, (1.3,1.2,0.7), seg=8, rings=5)
        sph("Patte_ArG" if k<0 else "Patte_ArD", o, (k*0.3,0.45,0.1), 0.1, (1.3,1.2,0.7), seg=8, rings=5)
    bar("Queue", o, (0,0.5,0.3), (0,1,0.3), 0.85, 0.17, 0.03, 8)
    for y, r in ((-0.05,0.08),(0.2,0.09),(0.45,0.07)): sph("Tache", "1E1E1E", (0,y,0.53), r, (1,1,0.4), seg=8, rings=5)
    eyes(0.7, -0.66, 0.15, 0.075)
# 36 Crocodile (B, 22)
def crocodile():
    g = "4E7A3A"
    box("Corps", g, (0,0.2,0.4), (0.55,1.0,0.36)); box("Ventre", "C9C08A", (0,0.2,0.2), (0.5,0.9,0.12))
    box("Tete", g, (0,-0.55,0.72), (0.54,0.55,0.26)); box("Machoire", "C9C08A", (0,-0.6,0.46), (0.46,0.5,0.1), (0.3,0,0))
    for x, y, n in ((-0.33,-0.15,"Patte_AvG"),(0.33,-0.15,"Patte_AvD"),(-0.33,0.55,"Patte_ArG"),(0.33,0.55,"Patte_ArD")): box(n, g, (x,y,0.1), (0.17,0.17,0.2))
    box("Queue", g, (0,1.0,0.26), (0.22,0.8,0.18))
    for k in (-1,1):
        for y in (-0.75,-0.4): box("Dent", "FFFFFF", (k*0.2,y,0.57), (0.05,0.05,0.08))
    eyes(0.93, -0.45, 0.18, 0.07, "FFD23F", True)
    for i in range(5): box("Dos", "3A5E2A", (0,-0.1+i*0.22,0.62), (0.12,0.12,0.1))
# 37 Cheval (L, 24)
def cheval():
    b = "8B5A2B"; d = "2A1E14"
    sph("Corps", b, (0,0.15,0.5), 0.26, (0.85,1.55,0.9), seg=14, rings=9)
    for x, y, n in ((-0.14,-0.2,"Patte_AvG"),(0.14,-0.2,"Patte_AvD"),(-0.14,0.5,"Patte_ArG"),(0.14,0.5,"Patte_ArD")):
        cyl(n, b, (x,y,0.17), 0.06, 0.3); cyl("Sabot", d, (x,y,0.035), 0.07, 0.07)
    cyl("Cou", b, (0,-0.4,0.78), 0.1, 0.36, (0.45,0,0)); sph("Tete", b, (0,-0.56,0.95), 0.17, (0.85,1.3,1), seg=12, rings=8)
    sph("Museau", b, (0,-0.7,0.89), 0.1, (0.9,1.0,0.8), seg=8, rings=5); sph("Nez", d, (0,-0.79,0.9), 0.035, seg=6, rings=4)
    for k in (-1,1):
        cone("Oreille", b, (k*0.07,-0.5,1.12), 0.04, 0.0, 0.14, v=5)
        sph("Joue", "FF9AA8", (k*0.13,-0.62,0.9), 0.04, (1,0.5,0.8), seg=6, rings=4)
    eyes(0.99, -0.64, 0.11, 0.045)
    sph("Criniere", d, (0,-0.5,1.06), 0.09, (0.6,1.2,1), seg=8, rings=5); sph("Criniere", d, (0,-0.36,0.92), 0.09, (0.6,1.3,1.3), seg=8, rings=5)
    bar("Queue", d, (0,0.6,0.58), (0,0.7,-0.7), 0.5, 0.08, 0.02, 7)
# 43 Ours brun (B, 22)
def ours():
    b = "6B4A2E"; m = "C9A27A"
    box("Corps", b, (0,0.1,0.5), (0.7,0.85,0.55)); box("Ventre", m, (0,-0.33,0.42), (0.36,0.05,0.24))
    for x, y, n in ((-0.24,-0.2,"Patte_AvG"),(0.24,-0.2,"Patte_AvD"),(-0.24,0.45,"Patte_ArG"),(0.24,0.45,"Patte_ArD")):
        box(n, b, (x,y,0.14), (0.24,0.24,0.28)); box("Pied", m, (x,y-0.13,0.05), (0.2,0.05,0.1))
    box("Tete", b, (0,-0.45,0.8), (0.58,0.5,0.46)); box("Museau", m, (0,-0.75,0.72), (0.28,0.2,0.17)); box("Nez", "2A1A1A", (0,-0.86,0.76), (0.11,0.05,0.07))
    box("Queue", b, (0,0.58,0.55), (0.16,0.14,0.16))
    for k in (-1,1):
        box("Oreille", b, (k*0.23,-0.4,1.08), (0.15,0.1,0.15)); box("Joue", "FF9AA8", (k*0.23,-0.71,0.76), (0.08,0.04,0.07))
    eyes(0.88, -0.7, 0.14, 0.07, "1A1A1A", True)
# 44 / 51 Requins (B bipèdes)
def requin_base(c, v, dentc="FFFFFF"):
    box("Corps", c, (0,0.05,0.46), (0.5,0.4,0.44)); box("Tete", c, (0,-0.1,0.86), (0.56,0.5,0.36)); box("Ventre", v, (0,-0.16,0.46), (0.34,0.04,0.36))
    for k in (-1,1):
        box("Jambe_G" if k<0 else "Jambe_D", c, (k*0.14,0,0.12), (0.18,0.22,0.24)); box("Bras_G" if k<0 else "Bras_D", c, (k*0.34,-0.02,0.5), (0.12,0.14,0.34), (0,0,k*0.2))
    box("Aileron", c, (0,0.26,0.8), (0.06,0.3,0.34)); box("Queue", c, (0,0.34,0.36), (0.1,0.2,0.3), (-0.4,0,0))
    eyes(0.92, -0.365, 0.2, 0.07, "1A1A1A", True)
    for x in (-0.22,-0.1,0.1,0.22): box("Dent", dentc, (x,-0.365,0.76), (0.06,0.04,0.08))
def requin():
    requin_base("5A7FA8", "F2F2F2")
    torus("Vague", "8FD0F0", (0,0,0.07), 0.55, 0.08)
    for i in range(6):
        a = i*math.pi/3+0.3; sph("Goutte", "8FD0F0", (math.cos(a)*0.64, math.sin(a)*0.64, 0.2+0.1*(i%3)), 0.07, seg=6, rings=4)
def requin_eclair():
    requin_base("B8C4CC", "E6EEF4")
    c = (0.62,-0.2,0.72); sph("Eclairs", "6FD6FF", c, 0.15, seg=10, rings=6)
    for i in range(7):
        a = i*2*math.pi/7; d = Vector((math.cos(a)*0.8, 0.0, math.sin(a)))
        bar("Eclairs", "6FD6FF", (c[0]+d.x*0.15, c[1], c[2]+d.z*0.15), tuple(d), 0.2, 0.035, 0.0, 4)
    sph("Lueur", "6FD6FF", (0,-0.28,0.64), 0.05, seg=6, rings=4)
# 50 Léopard des neiges (B, 28)
def leopard():
    w = "F2F2F2"; d = "2A2A2A"
    box("Corps", w, (0,0.15,0.5), (0.46,0.7,0.36)); box("Ventre", "E6EEF6", (0,-0.2,0.44), (0.3,0.06,0.22))
    for x, y, z, n in ((-0.16,-0.18,0.2,"Patte_AvG"),(0.16,-0.3,0.15,"Patte_AvD"),(-0.16,0.6,0.15,"Patte_ArG"),(0.16,0.5,0.2,"Patte_ArD")): box(n, w, (x,y,z), (0.14,0.14,0.3 if z<0.18 else 0.24))
    box("Tete", w, (0,-0.35,0.8), (0.46,0.4,0.38)); box("Museau", w, (0,-0.6,0.72), (0.22,0.14,0.14)); box("Nez", "E89AA8", (0,-0.68,0.75), (0.07,0.04,0.05))
    box("Queue", w, (0,0.85,0.58), (0.1,0.7,0.1), (0.25,0,0)); box("Queue_Bout", d, (0,1.18,0.64), (0.12,0.14,0.12))
    for k in (-1,1): box("Oreille", w, (k*0.17,-0.3,1.03), (0.12,0.06,0.12))
    eyes(0.84, -0.555, 0.12, 0.07, "6FD6FF", True)
    for x, y in ((-0.12,-0.05),(0.12,0.2),(-0.12,0.35),(0.12,0.5),(0.0,0.05),(0.0,0.4)): box("Tache", d, (x,y,0.69), (0.09,0.09,0.04))
    for i, y in enumerate((-0.1,0.05,0.2,0.35,0.5)): bar("Cristal", "9FE6FF", (0,y,0.66), (0,0.1*(i-2),1), 0.26+0.06*(i%2), 0.07, 0.0, 4)
# 56 Phénix de feu (B, 34)
def phenix():
    o = "FF6A1A"; y = "FFD24A"
    box("Corps", o, (0,0.05,0.5), (0.46,0.4,0.46)); box("Ventre", y, (0,-0.16,0.48), (0.3,0.04,0.34)); box("Tete", o, (0,-0.1,0.88), (0.42,0.4,0.36))
    box("Bec", y, (0,-0.36,0.86), (0.12,0.16,0.1))
    for k in (-1,1):
        box("Jambe_G" if k<0 else "Jambe_D", "FFB02A", (k*0.12,0,0.13), (0.1,0.1,0.26)); box("Griffe", "2A1A1A", (k*0.12,-0.06,0.03), (0.14,0.1,0.06))
        box("Bras_G" if k<0 else "Bras_D", o, (k*0.26,-0.1,0.5), (0.1,0.12,0.2))
        box("AileG" if k<0 else "AileD", y, (k*0.62,0.1,0.66), (0.78,0.05,0.5), (0,k*0.15,k*0.15))
        box("Joue", "FF9A6A", (k*0.2,-0.31,0.82), (0.08,0.04,0.07)); sph("Lueur", "FFE9A0", (k*1.0,0.1,0.98), 0.06, seg=6, rings=4)
    for i in range(3): box("Crete", y, (0,-0.12+i*0.1,1.1+0.02*(i%2)), (0.08,0.1,0.2))
    box("Queue", o, (0,0.4,0.4), (0.14,0.4,0.14), (-0.3,0,0))
    for i, a in enumerate((-0.4,-0.14,0.14,0.4)): box("Plume", y if i%2 else o, (math.sin(a)*0.3,0.72,0.34), (0.1,0.5,0.05), (-0.2,0,-a))
    for i in range(6):
        a = (i-2.5)*0.28; bar("Flammes", "FFB02A", (math.sin(a)*0.3,0.92,0.36), (math.sin(a),0.4,0.7), 0.25, 0.07, 0.0, 4)
    eyes(0.94, -0.305, 0.11, 0.07, "1A1A1A", True)
# 60 Tigre ailé à runes (L, 34)
def tigre():
    o = "FF8C2A"; r = "FFE680"
    sph("Corps", o, (0,0.1,0.5), 0.3, (0.8,1.3,0.85), seg=14, rings=9); sph("Ventre", "FFF0D8", (0,-0.05,0.4), 0.2, (0.8,1.0,0.6), seg=10, rings=6)
    for x, y, n in ((-0.17,-0.25,"Patte_AvG"),(0.17,-0.25,"Patte_AvD"),(-0.17,0.45,"Patte_ArG"),(0.17,0.45,"Patte_ArD")): cyl(n, o, (x,y,0.17), 0.075, 0.32)
    sph("Tete", o, (0,-0.42,0.78), 0.26, (1,0.95,0.92), seg=14, rings=9); sph("Museau", "FFE0B0", (0,-0.63,0.7), 0.12, (1,0.8,0.8), seg=8, rings=5); sph("Nez", "2A1A1A", (0,-0.73,0.73), 0.035, seg=6, rings=4)
    bar("Queue", o, (0,0.5,0.55), (0,1,0.6), 0.6, 0.07, 0.04, 7); sph("Queue_Bout", "2A1A14", (0,0.86,0.82), 0.07, seg=8, rings=5)
    sph("Criniere", "FFE0B0", (0,-0.28,0.64), 0.17, (1.2,0.7,0.9), seg=8, rings=5)
    for k in (-1,1):
        sph("Oreille", o, (k*0.19,-0.38,1.0), 0.08, (1,0.6,1), seg=8, rings=5); sph("Joue", "FFB08A", (k*0.2,-0.62,0.72), 0.05, (1,0.5,0.8), seg=6, rings=4)
        sph("AileG" if k<0 else "AileD", "FFD98A", (k*0.34,0.15,0.9), 0.3, (0.12,0.7,1.1), seg=9, rings=6)
        for y in (-0.1,0.15,0.4): sph("Lueur", r, (k*0.25,y,0.6), 0.08, (0.3,0.5,1.6), seg=8, rings=5)
    eyes(0.82, -0.655, 0.11, 0.06, "1A1A1A")
    torus("Runes", r, (0,0.05,0.04), 0.8, 0.03)
    for i in range(5):
        a = i*2*math.pi/5+0.4; box("Runes", r, (math.cos(a)*0.8, 0.05+math.sin(a)*0.8, 0.08), (0.14,0.05,0.14), (0,0,a))
# 63 Renard à neuf queues (B, 38)
def renard():
    y = "FFE07A"; w = "FFFFFF"
    box("Corps", y, (0,0.12,0.38), (0.5,0.46,0.5)); box("Ventre", w, (0,-0.12,0.37), (0.3,0.04,0.34))
    for k in (-1,1):
        box("Patte_AvG" if k<0 else "Patte_AvD", y, (k*0.14,-0.18,0.17), (0.12,0.14,0.34)); box("Patte_ArG" if k<0 else "Patte_ArD", y, (k*0.3,0.0,0.07), (0.18,0.3,0.14))
        box("Oreille", y, (k*0.18,-0.06,1.1), (0.14,0.08,0.26)); box("Oreille_Int", "FFB6C8", (k*0.18,-0.1,1.08), (0.07,0.04,0.16))
        box("Joue", "FFB08A", (k*0.2,-0.33,0.75), (0.08,0.04,0.07))
    box("Tete", y, (0,-0.1,0.8), (0.5,0.44,0.4)); box("Museau", w, (0,-0.36,0.74), (0.2,0.18,0.14)); box("Nez", "2A1A1A", (0,-0.46,0.78), (0.07,0.05,0.05)); box("Marque", "FF6A6A", (0,-0.33,0.93), (0.06,0.04,0.08))
    eyes(0.84, -0.33, 0.13, 0.07, "1A1A1A", True)
    names = ["Queue","QueueB","QueueC","QueueD","QueueE","QueueF","QueueG","QueueH","QueueI"]
    for i, n in enumerate(names):
        a = (i-4)*0.36; d = Vector((math.sin(a), 0.55, math.cos(a)*0.8+0.3)); b = Vector((0,0.35,0.38))
        bar(n, w, tuple(b), tuple(d), 0.62, 0.11, 0.04, 6)
        t = b + d.normalized()*0.66; box("Bout", y, tuple(t), (0.09,0.09,0.09))
for n, f in (("pet_chauve_souris",chauve),("pet_perroquet",perroquet),("pet_salamandre",salamandre),("pet_crocodile",crocodile),("pet_cheval",cheval),("pet_ours_brun",ours),("pet_requin",requin),("pet_leopard_des_neiges",leopard),("pet_requin_eclair",requin_eclair),("pet_phenix_de_feu",phenix),("pet_tigre_aile_a_runes",tigre),("pet_renard_a_neuf_queues",renard)): reg(n, f)
json.dump(M, open(os.path.join(OUT, "manifest.json"), "w"), indent=1); print("OK", len(M), {k:(v["parts"],v["faces"]) for k,v in M.items()})
