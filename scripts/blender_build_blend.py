import bpy, os, sys, math
B=os.path.dirname(os.path.abspath(__file__))
src, out, spacing = sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv)>3 else 14.0
bpy.ops.wm.read_factory_settings(use_empty=True)
files = sorted(f for f in os.listdir(os.path.join(B,src)) if f.endswith(".fbx"))
cols = 8
for i,f in enumerate(files):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(B,src,f))
    new=[o for o in bpy.data.objects if o not in before]
    name=f[:-4]
    col=bpy.data.collections.new(name); bpy.context.scene.collection.children.link(col)
    root=bpy.data.objects.new(name+"_ROOT",None); col.objects.link(root); root.location=((i%cols)*spacing,(i//cols)*spacing,0)
    for o in new:
        for c in list(o.users_collection): c.objects.unlink(o)
        col.objects.link(o)
        if o.parent is None: o.parent=root
        if o.type=="MESH":
            import re
            m=re.search(r"__([0-9A-Fa-f]{6})",o.name)
            if m:
                h=m.group(1); r,g,b=(int(h[k:k+2],16)/255 for k in (0,2,4))
                mat=bpy.data.materials.new(h); mat.use_nodes=True; mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(r**2.2,g**2.2,b**2.2,1)
                o.data.materials.clear(); o.data.materials.append(mat)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(B,"pc",out)); print("saved",out,len(files))
