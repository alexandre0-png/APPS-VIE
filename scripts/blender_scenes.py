import bpy, math, os, re, sys, mathutils
B = os.path.dirname(os.path.abspath(__file__)); OUT = sys.argv[1]; WHICH = sys.argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene; sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 48; sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 1920, 1080; sc.render.resolution_percentage = 100
HEX = re.compile(r"__([0-9A-Fa-f]{6})")
def mat(hexc, emit=0.0, rough=0.55, metal=0.0):
    r,g,b = (int(hexc[i:i+2],16)/255 for i in (0,2,4)); lin = lambda c: c**2.2
    m = bpy.data.materials.new(hexc); m.use_nodes = True; p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (lin(r),lin(g),lin(b),1); p.inputs["Roughness"].default_value = rough; p.inputs["Metallic"].default_value = metal
    if emit: p.inputs["Emission Color"].default_value = (lin(r),lin(g),lin(b),1); p.inputs["Emission Strength"].default_value = emit
    return m
def put(folder, name, loc, rot=0.0, height=None, emit_names=("Flamme","Oeil","Lanterne","Yeux","Abatjour")):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(B, folder, name + ".fbx"))
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.type == "MESH":
            mm = HEX.search(o.name); hexc = mm.group(1) if mm else "AAAAAA"
            e = 6.0 if any(k in o.name for k in emit_names) else 0.0
            o.data.materials.clear(); o.data.materials.append(mat(hexc, e, 0.5, 0.6 if any(k in o.name for k in ("Anneau","Tige","Serrure","Poignee","Fer","Chrome")) else 0.0))
    meshes = [o for o in new if o.type == "MESH"]
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ mathutils.Vector(c) for o in meshes for c in o.bound_box]
    mn = mathutils.Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))); mx = mathutils.Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    h = max(mx.z - mn.z, 1e-6); k = (height / h) if height else 1.0
    root = bpy.data.objects.new("root_"+name, None); sc.collection.objects.link(root)
    cx, cy = (mn.x+mx.x)/2, (mn.y+mx.y)/2
    for o in new:
        if o.parent is None: o.parent = root
    root.matrix_parent_inverse = mathutils.Matrix.Identity(4)
    # recentrer : origine au centre-bas de la boîte
    for o in new:
        if o.parent == root: o.location = o.location - mathutils.Vector((cx, cy, mn.z)) if False else o.location
    root.location = (loc[0]-cx*k*math.cos(rot)+cy*k*math.sin(rot), loc[1]-cx*k*math.sin(rot)-cy*k*math.cos(rot), loc[2]-mn.z*k)
    root.rotation_euler = (0,0,rot); root.scale = (k,k,k)
    bpy.context.view_layer.update(); return root
def box(loc, size, hexc, rough=0.8):
    bpy.ops.mesh.primitive_cube_add(location=loc); o = bpy.context.active_object; o.scale = (size[0]/2,size[1]/2,size[2]/2); o.data.materials.append(mat(hexc, 0, rough)); return o
def light(kind, loc, energy, color, size=0.3, rot=None):
    d = bpy.data.lights.new("l", kind); d.energy = energy; d.color = color
    if kind=="POINT": d.shadow_soft_size = size
    o = bpy.data.objects.new("l", d); o.location = loc; sc.collection.objects.link(o)
    if rot: o.rotation_euler = rot
    return o
def cam(loc, target, lens=35):
    c = bpy.data.cameras.new("c"); c.lens = lens; o = bpy.data.objects.new("c", c); o.location = loc; sc.collection.objects.link(o); sc.camera = o
    o.rotation_euler = (mathutils.Vector(target) - mathutils.Vector(loc)).to_track_quat("-Z","Y").to_euler()
def world(rgb, s):
    w = bpy.data.worlds.new("w"); w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (*rgb,1); w.node_tree.nodes["Background"].inputs[1].default_value = s; sc.world = w
if WHICH == "grenier":
    world((0.03,0.035,0.07), 1.2)
    box((0,6,-0.1),(60,40,0.2),"3A2410",0.6); box((0,16,6),(60,0.4,12),"2A1E20"); box((-14,6,6),(0.4,40,12),"221A1C"); box((0,6,12.2),(60,40,0.4),"1A1315")
    put("outB2","Armoire",(-13,14.5,0),0.0,8.0); put("outB2","HorlogeComtoise",(9,15.2,0),0.0,8.5); put("outB2","Commode",(-5,15.3,0),0.0,3.2)
    put("outB2","CoffretAncien",(-5.5,5.0,0),0.6,2.6); put("outB2","BougieChandelier",(2.2,3.2,0),0,2.4); put("outB2","CleOr",(0.8,2.0,0),0.3,1.8)
    put("outB2","PoupeeAncienne",(-5.5,2.8,0),2.6,3.0); put("outB2","ChevalBascule",(7.5,6.5,0),2.3,4.5); put("outB2","Berceau",(-11,8,0),1.2,3.6)
    put("outB2","OmbreRampante",(1.5,12.0,0),0.0,10.5)
    light("POINT",(2.2,3.2,3.0),900,(1.0,0.58,0.22),0.12); light("POINT",(-1.5,4.5,4.0),500,(1.0,0.6,0.25),0.5); light("POINT",(-10,3,10),3500,(0.45,0.55,1.0),1.5); light("POINT",(4,-3,6),900,(1.0,0.75,0.5),2.0); light("POINT",(6,6,7),700,(0.9,0.55,0.3),1.5)
    light("POINT",(1.5,10.5,9.5),500,(1.0,0.15,0.1),0.3)
    cam((1.0,-7.5,3.2),(1.2,12.0,5.4),30)
else:
    world((0.48,0.7,0.98), 1.3)
    box((0,0,-0.2),(160,160,0.4),"5CA052",0.9)
    put("outB2","Cabane",(-16,30,0),0.6,11); put("outB3","props_mill",(18,34,0),math.pi,20); put("outB2","Fontaine",(0,20,0),0,7)
    for i,(x,y) in enumerate([(-24,16),(-12,24),(12,16),(24,22),(-30,34),(30,32),(-8,38)]): put("outB2","Arbre" if i%2==0 else "Sapin",(x,y,0),i,10+ (i%3))
    put("outB2","Rocher",(12,10,0),0.6,3); put("outB2","Buisson",(-12,9,0),0,3)
    egg=[("OeufCommun",-9),("OeufRare",-4.5),("OeufEpique",0),("OeufLegendaire",4.5),("OeufMythique",9)]
    for k,(n,x) in enumerate(egg): put("outB2","NidOeufs",(x,5,0),0,1.2); put("outB2",n,(x,5,0.4),0.3*k,4.2)
    put("outB2","OeufSecret",(0,1.5,0),0,8.0)
    for n,x,y,r in [("PetRenard",-13,1,0.5),("PetPanda",13,1.5,-0.5),("PetDragonnet",-5.5,-2,0.3),("PetPoussin",5.5,-2.2,-0.3)]: put("outB2",n,(x,y,0),r,5.0)
    put("outB3","guards_dog",(-19,9,0),0.9,4)
    light("SUN",(0,0,10),4.5,(1.0,0.95,0.85)); sc.objects[-1].rotation_euler = (math.radians(48),math.radians(8),math.radians(28))
    cam((0,-26,9.0),(0,12,4.5),30)
sc.render.filepath = os.path.join(OUT, f"{WHICH}.png"); bpy.ops.render.render(write_still=True); print("done", WHICH)
