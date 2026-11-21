import bpy, os, sys, re
B=os.path.dirname(os.path.abspath(__file__)); src=sys.argv[1]; out=sys.argv[2]; size=int(sys.argv[3]) if len(sys.argv)>3 else 256
os.makedirs(out,exist_ok=True)
HEX=re.compile(r"__([0-9A-Fa-f]{6})")
def run(fbx):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc=bpy.context.scene; sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=1
    bpy.ops.import_scene.fbx(filepath=fbx)
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    if not meshes: return False
    for o in meshes:
        mm=HEX.search(o.name); h=mm.group(1) if mm else "AAAAAA"
        r,g,b=(int(h[i:i+2],16)/255 for i in (0,2,4))
        mat=bpy.data.materials.new(h); mat.use_nodes=True; p=mat.node_tree.nodes["Principled BSDF"]
        p.inputs["Base Color"].default_value=(r**2.2,g**2.2,b**2.2,1); p.inputs["Roughness"].default_value=0.7
        o.data.materials.clear(); o.data.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    bpy.ops.object.join(); ob=bpy.context.active_object
    name=os.path.splitext(os.path.basename(fbx))[0]; ob.name=name
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=0.02); bpy.ops.object.mode_set(mode="OBJECT")
    img=bpy.data.images.new(name+"_color",size,size)
    for m in ob.data.materials:
        nt=m.node_tree; node=nt.nodes.new("ShaderNodeTexImage"); node.image=img; nt.nodes.active=node
    bpy.ops.object.bake(type="DIFFUSE",pass_filter={"COLOR"},margin=4)
    img.filepath_raw=os.path.join(out,name+"_ColorMap.png"); img.file_format="PNG"; img.save()
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(out,name+"_UV.fbx"),use_selection=True,apply_unit_scale=True,mesh_smooth_type="FACE",add_leaf_bones=False)
    return True
n=0
for f in sorted(os.listdir(os.path.join(B,src))):
    if f.endswith(".fbx"):
        try: n+= 1 if run(os.path.join(B,src,f)) else 0
        except Exception as e: print("ERR",f,str(e)[:100])
print("baked",n)
