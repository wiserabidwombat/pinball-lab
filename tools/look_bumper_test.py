import bpy, math, sys
out = sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 48
sc.render.resolution_x = sc.render.resolution_y = 384
sc.render.film_transparent = True
sc.view_settings.view_transform = 'Standard'

def mat(name, rgb, metal=0.0, rough=0.4, emit=None, alpha=1.0, trans=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*rgb, 1)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    if trans: b.inputs['Transmission Weight'].default_value = trans
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = 0.6
    return m

def cyl(r, d, z, m, verts=64, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d, location=(0, 0, z), vertices=verts)
    o = bpy.context.object; o.data.materials.append(m)
    if bevel:
        mod = o.modifiers.new('b', 'BEVEL'); mod.width = bevel; mod.segments = 4
    bpy.ops.object.shade_smooth()
    return o

# floor (catches the shadow, cut out later) -> use a shadow catcher plane
bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, 0))
p = bpy.context.object; p.is_shadow_catcher = True
# bumper: black base, chrome skirt ring, red body, translucent lit cap with a star
cyl(1.0, 0.12, 0.06, mat('base', (0.02, 0.02, 0.02), rough=0.3), bevel=0.03)
cyl(0.92, 0.35, 0.3, mat('skirt', (0.9, 0.9, 0.92), metal=1.0, rough=0.15), bevel=0.04)
cyl(0.78, 0.25, 0.6, mat('body', (0.05, 0.25, 0.22), rough=0.35), bevel=0.05)
cap = cyl(0.84, 0.18, 0.8, mat('cap', (0.25, 0.75, 0.45), rough=0.15, emit=(0.2, 0.8, 0.45), trans=0.0), bevel=0.08)
# little brass bolt on top
cyl(0.1, 0.06, 0.92, mat('bolt', (0.85, 0.65, 0.3), metal=1.0, rough=0.2), bevel=0.02)

# camera straight down, orthographic (the table is drawn top-down)
bpy.ops.object.camera_add(location=(0, -10*math.sin(math.radians(22)), 10*math.cos(math.radians(22))), rotation=(math.radians(22), 0, 0)); cam = bpy.context.object
cam.data.type = 'ORTHO'; cam.data.ortho_scale = 2.8; sc.camera = cam
# key light top-left, soft fill
bpy.ops.object.light_add(type='AREA', location=(-3, 3, 6)); k = bpy.context.object
k.data.energy = 900; k.data.size = 2; k.rotation_euler = (math.radians(35), math.radians(-30), 0)
bpy.ops.object.light_add(type='AREA', location=(3, -2, 5)); f = bpy.context.object
f.data.energy = 200; f.data.size = 4
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.05, 0.06, 0.08, 1)
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
