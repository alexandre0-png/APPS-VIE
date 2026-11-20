import bpy, math, os, sys
def reset(): bpy.ops.wm.read_factory_settings(use_empty=True)
def _fin(o, name, hexc):
    o.name = f"{name}__{hexc}"; o.data.name = o.name
    bpy.ops.object.shade_flat()
    return o
def box(name, hexc, loc, size, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(location=loc); o = bpy.context.active_object
    o.scale = (size[0]/2, size[1]/2, size[2]/2); o.rotation_euler = rot; bpy.ops.object.transform_apply(scale=True, rotation=True); return _fin(o, name, hexc)
def cyl(name, hexc, loc, r, h, rot=(0,0,0), v=10):
    bpy.ops.mesh.primitive_cylinder_add(location=loc, vertices=v, radius=r, depth=h); o = bpy.context.active_object
    o.rotation_euler = rot; bpy.ops.object.transform_apply(rotation=True); return _fin(o, name, hexc)
def cone(name, hexc, loc, r1, r2, h, rot=(0,0,0), v=10):
    bpy.ops.mesh.primitive_cone_add(location=loc, vertices=v, radius1=r1, radius2=r2, depth=h); o = bpy.context.active_object
    o.rotation_euler = rot; bpy.ops.object.transform_apply(rotation=True); return _fin(o, name, hexc)
def sph(name, hexc, loc, r, sc=(1,1,1), seg=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(location=loc, segments=seg, ring_count=rings, radius=r); o = bpy.context.active_object
    o.scale = sc; bpy.ops.object.transform_apply(scale=True); return _fin(o, name, hexc)
def torus(name, hexc, loc, R, r, rot=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(location=loc, major_segments=14, minor_segments=6, major_radius=R, minor_radius=r); o = bpy.context.active_object
    o.rotation_euler = rot; bpy.ops.object.transform_apply(rotation=True); return _fin(o, name, hexc)
def export(path):
    bpy.ops.object.select_all(action="SELECT")
    n = len(bpy.context.selected_objects); tris = sum(len(o.data.polygons) for o in bpy.context.selected_objects if o.type=="MESH")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True, mesh_smooth_type="FACE", add_leaf_bones=False, bake_anim=False)
    return n, tris
