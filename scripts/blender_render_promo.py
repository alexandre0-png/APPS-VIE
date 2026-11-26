"""Rendu promo Chipe-Oeufs. Usage: python blender_render_promo.py <scene> <pct> <samples> [out_dir]
scene: vignette|icone|g1|g2|g3 ; FBX dans $BL (defaut scratchpad blender)."""
import bpy, math, sys, re, os, glob
from mathutils import Vector
scn, pct, samples = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
OUT = sys.argv[4] if len(sys.argv) > 4 else "/home/user/APPS-VIE/vignettes"
BL = os.environ.get("BL", "/tmp/claude-0/-home-user-APPS-VIE/c9e841d1-d554-571c-a61d-bf92920d8724/scratchpad/blender")
FRONT = float(os.environ.get("FRONT", "0"))  # decalage d'orientation des modeles (deg)
EMIT = ("lueur", "flamme", "runes", "eclairs", "aureole", "yeux")
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = samples
sc.cycles.use_denoising = True
try: sc.cycles.denoiser = "OPENIMAGEDENOISE"
except Exception: pass
sc.cycles.max_bounces = 4; sc.cycles.diffuse_bounces = 2; sc.cycles.glossy_bounces = 2
sc.view_settings.view_transform = "Filmic" if "Filmic" in bpy.types.ColorManagedViewSettings.bl_rna.properties["view_transform"].enum_items.keys() else "Standard"
try: sc.view_settings.look = "Medium High Contrast"
except Exception: pass
W, H = (512, 512) if scn == "icone" else (1920, 1080)
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = W, H, pct

MATS = {}
def lin(x): return x/12.92 if x <= 0.04045 else ((x+0.055)/1.055)**2.4
def mat(hexs, emit):
    k = (hexs, emit)
    if k in MATS: return MATS[k]
    m = bpy.data.materials.new("m"); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    c = (*[lin(int(hexs[j:j+2], 16)/255) for j in (0, 2, 4)], 1)
    b.inputs["Base Color"].default_value = c; b.inputs["Roughness"].default_value = 0.6
    if emit:
        b.inputs["Emission Color"].default_value = c; b.inputs["Emission Strength"].default_value = 3.0
    MATS[k] = m; return m

def load(path, height=None, width=None, pos=(0, 0, 0), look=None, yaw=0.0, scale=None, lift=None):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new("root", None); bpy.context.collection.objects.link(root)
    for o in new:
        if o.parent is None or o.parent not in new: o.parent = root
        if o.type == "MESH":
            nm = o.name; m = re.search(r"__([0-9A-Fa-f]{6})", nm)
            o.data.materials.clear(); hx = m.group(1) if m else "888888"; em_ = any(e in nm.lower() for e in EMIT)
            if lift:
                r_, g_, b_ = [int(hx[j:j+2], 16) for j in (0, 2, 4)]
                if (r_*0.3+g_*0.6+b_*0.1) < 70 and not em_: hx = lift
                if r_ > 200 and g_ < 130 and b_ < 90: em_ = True
            o.data.materials.append(mat(hx, em_))
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in new if o.type == "MESH" for c in o.bound_box]
    h = max(p.z for p in pts) - min(p.z for p in pts); w = max(max(p.x for p in pts)-min(p.x for p in pts), 0.01)
    s = scale or (height/h if height else (width/w if width else 1))
    root.scale = (s, s, s)
    if look is not None:
        d = Vector(look) - Vector(pos); yaw = math.atan2(d.x, -d.y)  # face -Y => yaw 0
    root.rotation_euler = (0, 0, yaw + math.radians(FRONT))
    root.location = pos
    return root

def P(sub): return f"{BL}/{sub}"
def pet(name):
    g = glob.glob(f"{BL}/out2[0-5]/pet_{name}.fbx") + glob.glob(f"{BL}/out14/{name}.fbx")
    return g[0]

# ---- decor commun
def ground(color=(0.18, 0.42, 0.10), size=600, z=0):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, z)); g = bpy.context.object
    m = bpy.data.materials.new("g"); m.use_nodes = True; nt = m.node_tree
    n = nt.nodes.new("ShaderNodeTexNoise"); n.inputs["Scale"].default_value = 0.15; n.inputs["Detail"].default_value = 3
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
    mix.inputs[6].default_value = (*[lin(c) for c in color], 1); mix.inputs[7].default_value = (*[lin(c*1.35) for c in color], 1)
    nt.links.new(n.outputs["Fac"], mix.inputs[0]); nt.links.new(mix.outputs[2], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    g.data.materials.append(m); return g

def world(top=(0.25, 0.45, 0.85), hor=(1.0, 0.62, 0.35), strength=1.0, sun_col=(1.0, 0.72, 0.45), sun_e=4.0, sun_rot=(1.0, 0, 0.6)):
    w = bpy.data.worlds.new("w"); w.use_nodes = True; nt = w.node_tree; sc.world = w
    bg = nt.nodes["Background"]; bg.inputs["Strength"].default_value = strength
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0; ramp.color_ramp.elements[0].color = (*[lin(c) for c in hor], 1)
    ramp.color_ramp.elements[1].position = 0.45; ramp.color_ramp.elements[1].color = (*[lin(c) for c in top], 1)
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"]); nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bpy.ops.object.light_add(type="SUN"); s = bpy.context.object
    s.data.energy = sun_e; s.data.color = sun_col; s.data.angle = math.radians(4); s.rotation_euler = sun_rot
    return s

def camera(loc, target, lens=35, fstop=None, focus=None):
    bpy.ops.object.camera_add(location=loc); c = bpy.context.object
    d = Vector(target) - Vector(loc); c.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    c.data.lens = lens; sc.camera = c
    if fstop:
        c.data.dof.use_dof = True; c.data.dof.aperture_fstop = fstop
        c.data.dof.focus_distance = focus or d.length
    return c

def area(loc, target, energy, size, color=(1, 1, 1)):
    bpy.ops.object.light_add(type="AREA", location=loc); a = bpy.context.object
    a.data.energy = energy; a.data.size = size; a.data.color = color
    a.rotation_euler = (Vector(target)-Vector(loc)).to_track_quat("-Z", "Y").to_euler(); return a

def render(name):
    os.makedirs(OUT, exist_ok=True)
    sc.render.filepath = f"{OUT}/chipe-oeufs-v2-{name}.png"; sc.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)

# ================= SCENES
if scn == "vignette":
    import random; random.seed(7)
    sc.view_settings.exposure = -0.1
    ground((0.30, 0.60, 0.16))
    world(top=(0.42, 0.28, 0.72), hor=(1.0, 0.55, 0.45), strength=1.7, sun_col=(1.0, 0.62, 0.35), sun_e=9.0,
          sun_rot=(math.radians(-72), 0, math.radians(18)))
    CAM = (0, -34, 1.8); TGT = (0, 10, 6.5)
    load(P("out15/hub_dome.fbx"), height=28, pos=(38, 62, 0))
    load(P("out15/house_lvl4.fbx"), height=14, pos=(-40, 50, 0), look=CAM)
    load(P("out15/house_lvl3.fbx"), height=12, pos=(-64, 58, 0), look=CAM)
    for x, y, f in [(-46, 40, "out17/tree_wide.fbx"), (52, 40, "out11/tree_pine.fbx"), (-12, 55, "out11/tree_round.fbx"), (66, 62, "out11/tree_oak_a.fbx")]:
        load(P(f), height=15, pos=(x, y, 0))
    # collines
    def hill(x, y, r, h):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=(x, y, 0), segments=32, ring_count=16)
        o = bpy.context.object; o.scale = (r, r*0.8, h); bpy.ops.object.shade_smooth()
        o.data.materials.append(mat("5DBB3A", False))
    back = [("PetDragon", -36, 10.5), ("dragondecristal", -19, 10.0), ("dragonceleste", 19, 10.5), ("seraphinlion", 36, 9.5)]
    front = [("PetLapin", -22, -4, 5.6), ("PetRenard", -13, 1, 6.0), ("PetLicorne", 13, 1, 6.8), ("PetPanda", 22, -4, 5.6)]
    for nme, x, h in back:
        hill(x, 21, 9.5, 5.5)
        load(pet(nme.replace("pet_", "")), height=h*1.2, pos=(x, 21, 5.5), look=CAM)
    for nme, x, y, h in front:
        load(pet(nme), height=h, pos=(x, y, 0), look=CAM)
    load(P("out20/egg_r10.fbx"), height=12.5, pos=(0, -9, 0), look=CAM)
    # halo de soleil derriere l'oeuf
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 12, 7), rotation=(math.radians(90), 0, 0)); gl = bpy.context.object
    gm = bpy.data.materials.new("glow"); gm.use_nodes = True; nt = gm.node_tree; nt.nodes.clear()
    tc = nt.nodes.new("ShaderNodeTexCoord"); gr = nt.nodes.new("ShaderNodeTexGradient"); gr.gradient_type = "SPHERICAL"
    mp = nt.nodes.new("ShaderNodeMapping"); mp.inputs["Location"].default_value = (-1.0, -1.0, 0); mp.inputs["Scale"].default_value = (2, 2, 2); nt.links.new(tc.outputs["Generated"], mp.inputs[0]); nt.links.new(mp.outputs[0], gr.inputs[0])
    cr = nt.nodes.new("ShaderNodeValToRGB"); cr.color_ramp.elements[0].position = 0.0; cr.color_ramp.elements[0].color = (0, 0, 0, 1); cr.color_ramp.elements[1].position = 1.0; cr.color_ramp.elements[1].color = (1, 1, 1, 1)
    nt.links.new(gr.outputs["Fac"], cr.inputs["Fac"])
    em = nt.nodes.new("ShaderNodeEmission"); em.inputs["Color"].default_value = (1.0, 0.65, 0.3, 1); em.inputs["Strength"].default_value = 3.0
    tr = nt.nodes.new("ShaderNodeBsdfTransparent"); mx = nt.nodes.new("ShaderNodeMixShader"); out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(cr.outputs["Color"], mx.inputs[0]); nt.links.new(tr.outputs[0], mx.inputs[1]); nt.links.new(em.outputs[0], mx.inputs[2]); nt.links.new(mx.outputs[0], out.inputs[0])
    gl.data.materials.append(gm); gl.visible_shadow = False
    # particules : etoiles et petales
    for i in range(70):
        a = random.uniform(0, 2*math.pi); r = random.uniform(5, 26)
        x = math.cos(a)*r*1.3; z = 2 + abs(math.sin(a))*r*0.9; y = random.uniform(-14, 10)
        star = i % 2 == 0
        if star: bpy.ops.mesh.primitive_ico_sphere_add(radius=random.uniform(0.18, 0.4), subdivisions=1, location=(x, y, z))
        else:
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.3, location=(x, y, z), segments=8, ring_count=6)
            bpy.context.object.scale = (1.5, 0.8, 0.15)
        o = bpy.context.object; o.rotation_euler = (random.random()*3, random.random()*3, random.random()*3)
        o.data.materials.append(mat("FFE066" if star else "FF9EC4", star))
    camera(CAM, TGT, lens=22, fstop=5.5, focus=25)
    area((0, -22, 9), (0, -9, 4), 1100, 14, (1, 0.85, 0.8))
    render("vignette-1920x1080")
elif scn == "icone":
    sc.view_settings.exposure = -0.2
    bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 12, 0), rotation=(math.radians(90), 0, 0)); bg = bpy.context.object
    bg.visible_shadow = False
    m = bpy.data.materials.new("bg"); m.use_nodes = True; nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); r = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0]); nt.links.new(sep.outputs["Y"], r.inputs["Fac"])
    r.color_ramp.elements[0].color = (*[lin(c) for c in (1.0, 0.62, 0.25)], 1); r.color_ramp.elements[1].color = (*[lin(c) for c in (0.55, 0.25, 0.85)], 1)
    for n in list(nt.nodes):
        if n.type == "BSDF_PRINCIPLED": nt.nodes.remove(n)
    em = nt.nodes.new("ShaderNodeEmission"); out = nt.nodes["Material Output"]
    nt.links.new(r.outputs["Color"], em.inputs["Color"]); nt.links.new(em.outputs[0], out.inputs["Surface"]); bg.data.materials.append(m)
    world(top=(0.5, 0.3, 0.8), hor=(1.0, 0.7, 0.4), strength=0.6, sun_rot=(math.radians(55), 0, math.radians(-30)), sun_e=3.0)
    load(P("out20/egg_r5.fbx"), height=12.4, pos=(0, 0, -6.3), look=(0, -30, 0))
    camera((0, -22, 0), (0, 0, 0.2), lens=50)
    area((-6, -14, 8), (0, 0, 0), 1200, 10, (1, 0.9, 0.8))
    render("icone-512")
elif scn == "mobs":
    import random; random.seed(11)
    sc.view_settings.exposure = 0.0
    world(top=(0.05, 0.04, 0.2), hor=(0.28, 0.12, 0.38), strength=0.5, sun_col=(0.6, 0.6, 1.0), sun_e=0.8, sun_rot=(math.radians(-50), 0, math.radians(20)))
    bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, -0.02)); fl = bpy.context.object; fl.data.materials.append(mat("2A2347", False))
    def cyl(x, y, z, r, h, col, emit=False, seg=48):
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=(x, y, z), vertices=seg); o = bpy.context.object
        o.data.materials.append(mat(col, emit)); return o
    # podium 2 niveaux + cercle runique
    cyl(0, 6, 0.5, 25, 1.0, "4A4268"); cyl(0, 10, 1.4, 15, 0.8, "5A5080")
    for rad, col in [(28, "5CE1FF"), (32, "B06CFF")]:
        bpy.ops.mesh.primitive_torus_add(major_radius=rad, minor_radius=0.35, location=(0, 6, 0.05), major_segments=64, minor_segments=8)
        bpy.context.object.data.materials.append(mat(col, True))
    for i in range(36):
        a = i*math.pi/18; rr = 30
        bpy.ops.mesh.primitive_cube_add(location=(rr*math.cos(a), 6+rr*math.sin(a), 0.1)); o = bpy.context.object
        o.scale = (1.4, 0.35, 0.1) if i % 2 else (0.5, 1.3, 0.1); o.rotation_euler = (0, 0, a)
        o.data.materials.append(mat("7DF2FF" if i % 3 else "FFB347", True))
    # colonnes de pierre
    for i in range(9):
        a = math.radians(-70 + i*17.5); x = 70*math.sin(a); y = 30 + 55*math.cos(a)
        cyl(x, y, 14, 3.2, 28, "3C3558", seg=12); cyl(x, y, 28.5, 4.2, 1.5, "4A4268", seg=12)
    # lueurs/rim lights
    def glow(pos, col, e=4000, size=1.0):
        bpy.ops.object.light_add(type="POINT", location=pos); l = bpy.context.object
        l.data.energy = e; l.data.color = col; l.data.shadow_soft_size = 1.5
    FIRE, ICE, ELEC, SHAD, LIGHT, POIS = (1, .45, .1), (.3, .85, 1), (1, .9, .2), (.7, .3, 1), (1, .85, .45), (.4, 1, .3)
    CAM = (0, -46, 4.5)
    team = [  # nom, x, y, z, hauteur, couleur, lift
        ("dragondelave", 0, 13, 2.2, 17, FIRE, "9A3418"),
        ("phenix_de_feu", -17, 14, 2.2, 13, FIRE, None),
        ("dragonceleste", 17, 14, 2.2, 13, LIGHT, None),
        ("hydre_des_marais", -23, 0, 1.0, 8, POIS, None),
        ("loupdeglace", -9, -4, 1.0, 8, ICE, None),
        ("tigre_aile_a_runes", 9, -4, 1.0, 8, ELEC, None),
        ("griffon", 23, 0, 1.0, 9, LIGHT, None),
    ]
    for nme, x, y, z, h, col, lf in team:
        load(pet(nme), height=h, pos=(x, y, z), look=CAM, lift=lf)
        glow((x, y-2, z+h*0.5), col, 5000*h/10)          # eclairage de face colore
        glow((x, y+4, z+h*0.8), col, 9000*h/10)          # rim
    glow((0, 13, 8), FIRE, 30000)
    area((0, -30, 25), (0, 6, 4), 2500, 30, (0.75, 0.8, 1))
    # particules
    cols = [("FFB347", True), ("7DF2FF", True), ("FFE066", True), ("B06CFF", True)]
    for i in range(120):
        a = random.uniform(0, 2*math.pi); r = random.uniform(4, 40)
        x = math.cos(a)*r*1.3; y = 6+math.sin(a)*r*0.8; z = random.uniform(1, 30)
        cc = random.choice(cols)[0]
        if i % 3 == 0: bpy.ops.mesh.primitive_cone_add(radius1=0.35, depth=1.0, location=(x, y, z), vertices=4)
        else: bpy.ops.mesh.primitive_ico_sphere_add(radius=random.uniform(0.1, 0.3), subdivisions=1, location=(x, y, z))
        o = bpy.context.object; o.rotation_euler = (random.random()*3, random.random()*3, 0); o.data.materials.append(mat(cc, True))
    # brume au sol
    for i in range(14):
        x = random.uniform(-35, 35); y = random.uniform(-12, 28)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=(x, y, 0.4)); o = bpy.context.object; o.scale = (9, 6, 0.9); o.visible_shadow = False
        m_ = bpy.data.materials.new("mist"); m_.use_nodes = True; nt = m_.node_tree; nt.nodes.clear()
        tr = nt.nodes.new("ShaderNodeBsdfTransparent"); em = nt.nodes.new("ShaderNodeEmission"); mx = nt.nodes.new("ShaderNodeMixShader"); out = nt.nodes.new("ShaderNodeOutputMaterial")
        em.inputs["Color"].default_value = (0.55, 0.4, 0.9, 1); em.inputs["Strength"].default_value = 0.5; mx.inputs[0].default_value = 0.18
        nt.links.new(tr.outputs[0], mx.inputs[1]); nt.links.new(em.outputs[0], mx.inputs[2]); nt.links.new(mx.outputs[0], out.inputs[0]); o.data.materials.append(m_)
    camera(CAM, (0, 6, 7.5), lens=28, fstop=6, focus=52)
    render("mobs-1920x1080")
elif scn == "g1":
    # podium 2 rangees de 5
    def box(loc, size, col):
        bpy.ops.mesh.primitive_cube_add(location=loc); o = bpy.context.object; o.scale = size
        o.data.materials.append(mat(col, False)); return o
    bpy.ops.mesh.primitive_plane_add(size=2000, location=(0, 0, -0.01)); fl = bpy.context.object; fl.data.materials.append(mat("3B2F4F", False))
    world(top=(0.2, 0.15, 0.4), hor=(0.6, 0.4, 0.6), strength=0.9, sun_rot=(math.radians(60), 0, math.radians(-30)), sun_e=3)
    sp = 4.0
    box((0, 0.0, 0.4), (13.5, 2.8, 0.4), "E8D9B0"); box((0, 6.5, 1.2), (13.5, 2.8, 0.4), "E8D9B0")
    box((0, 0.0, 0.1), (14.5, 3.4, 0.1), "9B7B3A"); box((0, 6.5, 0.9), (14.5, 3.4, 0.1), "9B7B3A")
    for i in range(10):
        row, col = divmod(i, 5)
        x = (col-2)*sp; y = 5.5*row*0 + (0 if row == 0 else 6.5); z = 0.8 if row == 0 else 1.6
        e = load(P(f"out20/egg_r{i+1}.fbx"), height=3.8, pos=(x, y, z), look=(0, -40, 0))
    # rang 1 = raretes 1-5 devant, rang 2 = 6-10 derriere
    area((0, -18, 14), (0, 3, 2), 5000, 22); area((-14, -6, 8), (0, 3, 2), 1500, 8, (0.8, 0.85, 1))
    camera((0, -24, 15), (0, 3.2, 1.6), lens=34, fstop=8, focus=29)
    render("galerie-1")
elif scn == "g2":
    ground((0.22, 0.46, 0.12)); world(sun_e=4.5, sun_rot=(math.radians(55), 0, math.radians(-50)))
    CAM = (0, -30, 9)
    load(P("out15/hub_dome.fbx"), height=30, pos=(0, 52, 0))
    belt = load(P("out15/conveyor_belt.fbx"), width=22, pos=(0, 0, 0), yaw=0)
    bpy.context.view_layer.update()
    for i in range(6):
        load(P(f"out20/egg_r{[1,2,1,3,4,2][i]}.fbx"), height=1.9, pos=(-8+i*3.2, 0, 1.5), look=CAM)
    for x, f in [(-16, "out16/stall_a.fbx"), (16, "out16/stall_b.fbx"), (-26, "out16/stall_b.fbx"), (27, "out16/stall_a.fbx")]:
        load(P(f), height=7.5, pos=(x, 14, 0), look=(0, -30, 0))
    for x in (-12, 12, -32, 32):
        load(P("out16/lantern_post.fbx"), height=10, pos=(x, -9, 0))
    for x, y, f in [(-40, 20, "out17/tree_wide.fbx"), (42, 22, "out11/tree_oak_a.fbx"), (-30, 36, "out11/tree_round.fbx"), (32, 40, "out11/tree_pine.fbx"), (-48, 6, "out11/tree_oak_b.fbx")]:
        load(P(f), height=16, pos=(x, y, 0))
    load(P("out16/well_small.fbx"), height=5, pos=(-6, 24, 0)); load(P("out16/bush_round.fbx"), height=3, pos=(8, -14, 0))
    camera(CAM, (0, 8, 7), lens=30, fstop=8, focus=40)
    render("galerie-2")
elif scn == "g3":
    ground((0.50, 0.42, 0.28))
    world(strength=0.7, sun_e=2.5, sun_rot=(math.radians(55), 0, math.radians(-40)), hor=(1.0, 0.7, 0.45))
    CAM = (0, -50, 26)
    load(P("out15/arena_colosseum.fbx"), scale=1.0, pos=(0, 0, 0))
    load(pet("dragondelave"), height=12, pos=(-9.5, 3, 0.5), look=(9.5, 3, 0.5))
    load(pet("loupdeglace"), height=10, pos=(9.5, 3, 0.5), look=(-9.5, 3, 0.5))
    
    camera(CAM, (0, -2, 6), lens=36, fstop=11, focus=60)
    area((0, -30, 30), (0, 0, 3), 2500, 25, (1, 0.9, 0.8))
    render("galerie-3")
