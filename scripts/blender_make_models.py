import bpy, math, sys, os
OUT = sys.argv[1]
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name, rgb, metal=0.0, rough=0.6):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    return m
def add(kind, loc, scale, material, rot=(0,0,0), **kw):
    if kind == "cube": bpy.ops.mesh.primitive_cube_add(location=loc)
    elif kind == "cyl": bpy.ops.mesh.primitive_cylinder_add(location=loc, vertices=kw.get("v", 12))
    elif kind == "torus": bpy.ops.mesh.primitive_torus_add(location=loc, major_segments=12, minor_segments=6, major_radius=kw.get("R",1), minor_radius=kw.get("r",0.3))
    o = bpy.context.active_object; o.scale = scale; o.rotation_euler = rot
    o.data.materials.append(material); bpy.ops.object.transform_apply(scale=True, rotation=True)
    return o
def export(name):
    for o in bpy.context.scene.objects: o.select_set(True)
    bpy.ops.object.join()
    o = bpy.context.active_object; o.name = name
    tris = len(o.data.polygons)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, name + ".fbx"), use_selection=True, apply_unit_scale=True, global_scale=1.0, mesh_smooth_type="FACE", add_leaf_bones=False)
    print(name, "faces", tris)
def key():
    reset(); g = mat("or", (0.95,0.75,0.15), 0.8, 0.35)
    add("torus", (0,0,1.0), (1,1,1), g, rot=(math.pi/2,0,0), R=0.35, r=0.1)
    add("cyl", (0,0,0.3), (0.07,0.07,0.55), g)
    add("cube", (0.12,0,-0.15), (0.14,0.05,0.07), g); add("cube", (0.12,0,0.05), (0.1,0.05,0.07), g)
    export("CleOr")
def chest():
    reset(); w = mat("bois", (0.28,0.15,0.07)); m = mat("fer", (0.2,0.2,0.22), 0.7, 0.4); g = mat("or", (0.95,0.75,0.15), 0.8, 0.35)
    add("cube", (0,0,0.5), (1.0,0.6,0.5), w); add("cyl", (0,0,1.0), (0.6,1.0,1.0), w, rot=(0,math.pi/2,0), v=16)
    for x in (-0.6,0.6): add("cube", (x,0,0.8), (0.07,0.64,0.9), m)
    add("cube", (0,-0.62,0.9), (0.14,0.05,0.18), g)
    export("CoffretAncien")
def clock():
    reset(); w = mat("bois", (0.22,0.12,0.06)); f = mat("face", (0.9,0.85,0.7)); g = mat("or", (0.95,0.75,0.15), 0.8, 0.35)
    add("cube", (0,0,1.4), (0.5,0.35,1.4), w); add("cyl", (0,-0.37,2.2), (0.35,0.35,0.04), f, rot=(math.pi/2,0,0), v=24)
    add("cube", (0,-0.42,2.3), (0.025,0.01,0.2), g); add("cube", (0.1,-0.42,2.2), (0.15,0.01,0.025), g)
    add("cyl", (0,-0.37,0.9), (0.12,0.12,0.03), g, rot=(math.pi/2,0,0))
    export("HorlogeComtoise")
def doll():
    reset(); sk = mat("peau", (0.9,0.8,0.7)); rb = mat("robe", (0.55,0.08,0.1)); hr = mat("cheveux", (0.08,0.05,0.04))
    add("cyl", (0,0,0.45), (0.25,0.25,0.45), rb, v=10); add("cyl", (0,0,0.95), (0.12,0.12,0.12), sk, v=10)
    add("cube", (0,0,1.2), (0.22,0.22,0.22), sk); add("cube", (0,0.05,1.28), (0.24,0.2,0.12), hr)
    for x in (-0.3,0.3): add("cyl", (x,0,0.85), (0.05,0.05,0.2), sk, rot=(0,math.radians(20*(1 if x>0 else -1)),0), v=8)
    export("PoupeeAncienne")
def candle():
    reset(); c = mat("cire", (0.95,0.92,0.8)); f = mat("flamme", (1.0,0.7,0.2), 0, 0.2); b = mat("laiton", (0.7,0.5,0.15), 0.8, 0.4)
    add("cyl", (0,0,0.05), (0.2,0.2,0.05), b, v=12); add("cyl", (0,0,0.35), (0.06,0.06,0.3), c, v=10); add("cube", (0,0,0.7), (0.025,0.025,0.06), f)
    export("BougieChandelier")
for fn in (key, chest, clock, doll, candle): fn()
