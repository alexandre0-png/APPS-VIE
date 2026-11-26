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

def load(path, height=None, width=None, pos=(0, 0, 0), look=None, yaw=0.0, scale=None):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    root = bpy.data.objects.new("root", None); bpy.context.collection.objects.link(root)
    for o in new:
        if o.parent is None or o.parent not in new: o.parent = root
        if o.type == "MESH":
            nm = o.name; m = re.search(r"__([0-9A-Fa-f]{6})", nm)
            o.data.materials.clear(); o.data.materials.append(mat(m.group(1) if m else "888888", any(e in nm.lower() for e in EMIT)))
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
    ground((0.28, 0.55, 0.14)); world(strength=1.6, sun_e=5.0, sun_rot=(math.radians(72), 0, math.radians(-60)))
    CAM = (3, -27, 3.5); TGT = (3, 0, 4.2)
    # fond
    load(P("out15/hub_dome.fbx"), height=26, pos=(-4, 78, 0), yaw=0)
    load(P("out15/house_lvl4.fbx"), height=13, pos=(34, 52, 0), look=CAM)
    for x, y, f in [(-40, 40, "out17/tree_wide.fbx"), (-24, 34, "out11/tree_oak_a.fbx"), (46, 30, "out11/tree_pine.fbx"), (20, 38, "out11/tree_round.fbx"), (-58, 60, "out17/tree_pine_tier.fbx")]:
        load(P(f), height=15, pos=(x, y, 0))
    # arc de creatures
    arc = [("dragondelave", 9.5), ("phenixsolaire", 8.5), ("loupdeglace", 6.2), ("tigre_aile_a_runes", 5.6),
           ("pegase", 7.5), ("renard_a_neuf_queues", 5.0), ("PetLapin", 4.2), ("PetPanda", 4.2)]
    import random; random.seed(3)
    order = ["PetLapin", "tigre_aile_a_runes", "dragondelave", "pegase", "phenixsolaire", "loupdeglace", "renard_a_neuf_queues", "PetPanda"]
    hh = dict(arc)
    R = 17
    for i, nme in enumerate(order):
        a = math.radians(-74 + i*148/7)
        pos = (R*1.15*math.sin(a)+3, 6 + R*0.6*math.cos(a), 0)
        load(pet(nme), height=hh[nme]*1.25, pos=pos, look=CAM)
    load(P("out20/egg_r10.fbx"), height=5.5, pos=(3, -9, 0), look=CAM)
    camera(CAM, TGT, lens=30, fstop=6.0, focus=26)
    area((0, -20, 8), (0, -7, 4), 3000, 20, (1, 0.9, 0.8))
    render("vignette-1920x1080")
elif scn == "icone":
    # fond degrade
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 12, 0), rotation=(math.radians(90), 0, 0)); bg = bpy.context.object
    m = bpy.data.materials.new("bg"); m.use_nodes = True; nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); r = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0]); nt.links.new(sep.outputs["Y"], r.inputs["Fac"])
    r.color_ramp.elements[0].color = (*[lin(c) for c in (1.0, 0.55, 0.2)], 1); r.color_ramp.elements[1].color = (*[lin(c) for c in (0.45, 0.2, 0.75)], 1)
    em = nt.nodes["Principled BSDF"]; nt.links.new(r.outputs["Color"], em.inputs["Emission Color"]); em.inputs["Emission Strength"].default_value = 0.9
    nt.links.new(r.outputs["Color"], em.inputs["Base Color"]); bg.data.materials.append(m)
    world(top=(0.5, 0.3, 0.8), hor=(1.0, 0.7, 0.4), strength=0.8, sun_rot=(math.radians(55), 0, math.radians(-30)), sun_e=3.5)
    load(P("out20/egg_r5.fbx"), height=7, pos=(0, 0, -3.6), look=(0, -30, 0))
    camera((0, -22, 0), (0, 0, 0.2), lens=50)
    area((-6, -14, 8), (0, 0, 0), 1500, 10, (1, 0.9, 0.8))
    render("icone-512")
elif scn == "g1":
    # podium 2 rangees de 5
    def box(loc, size, col):
        bpy.ops.mesh.primitive_cube_add(location=loc); o = bpy.context.object; o.scale = size
        o.data.materials.append(mat(col, False)); return o
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, -0.01)); fl = bpy.context.object; fl.data.materials.append(mat("3B2F4F", False))
    world(top=(0.2, 0.15, 0.4), hor=(0.6, 0.4, 0.6), strength=0.9, sun_rot=(math.radians(60), 0, math.radians(-30)), sun_e=3)
    sp = 4.0
    box((0, 0.0, 0.4), (13.5, 2.8, 0.4), "E8D9B0"); box((0, 5.5, 1.2), (13.5, 2.8, 0.4), "E8D9B0")
    box((0, 0.0, 0.1), (14.5, 3.4, 0.1), "9B7B3A"); box((0, 5.5, 0.9), (14.5, 3.4, 0.1), "9B7B3A")
    for i in range(10):
        row, col = divmod(i, 5)
        x = (col-2)*sp; y = 5.5*row*0 + (0 if row == 0 else 5.5); z = 0.8 if row == 0 else 1.6
        e = load(P(f"out20/egg_r{i+1}.fbx"), height=3.6, pos=(x, y, z), look=(0, -40, 0))
    # rang 1 = raretes 1-5 devant, rang 2 = 6-10 derriere
    area((0, -18, 14), (0, 3, 2), 5000, 22); area((-14, -6, 8), (0, 3, 2), 1500, 8, (0.8, 0.85, 1))
    camera((0, -26, 9.5), (0, 3.2, 2.6), lens=38, fstop=8, focus=29)
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
    world(sun_e=5, sun_rot=(math.radians(62), 0, math.radians(-40)), hor=(1.0, 0.7, 0.45))
    CAM = (0, -46, 6)
    load(P("out15/arena_colosseum.fbx"), height=40, pos=(0, 40, 0))
    load(pet("dragondelave"), height=11, pos=(-11, -2, 0), look=(11, -1, 0))
    load(pet("loupdeglace"), height=9, pos=(11, -1, 0), look=(-11, -2, 0))
    for x in (-30, 30): load(P("out16/flag_banner.fbx"), height=14, pos=(x, 8, 0), look=CAM)
    camera(CAM, (0, 4, 8), lens=34, fstop=8, focus=45)
    area((0, -30, 20), (0, 0, 3), 6000, 25, (1, 0.9, 0.8))
    render("galerie-3")
