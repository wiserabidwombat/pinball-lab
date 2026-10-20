"""Table 05 (The Lamplight) M9 v6: the loft ramp rendered alone as a brass wire ramp, for a sprite over the table art
(LmpTableLayout.rampArtRect, z 16: floor balls at z 10 show through the wires, ramp balls at z 30 ride on top).
Heights follow lmp_layout.ramp_height (= LmpTableLayout.upperHeight): the floor at the mouth, climbing the first
straight to the loft's 20 pt, level round the turn and through the loft's door. Two wires carry the ball, two wires each
side guide it, U hoops tie them every ~28 pt, brass posts on round feet hold the high part, and a brass entry plate
lies on the floor in the mouth's flare. Same light as lmp_bake_table.py; a shadow-catcher floor keeps the ramp's
shadow in the transparent image. Oblique view: y += z * OBLIQUE.
Usage: python3 lmp_bake_ramp.py -- out.png [scale] [samples]"""
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SCALE = float(argv[1]) if len(argv) > 1 else 1.0
SAMPLES = int(argv[2]) if len(argv) > 2 else 64
X0, Y0, RW, RH = L.RAMP_ART_RECT
K = L.OBLIQUE
R = 9.0                                   # ball radius
BOTTOM_OFF = 7.0                          # the two carrying wires, either side of the centreline
BOTTOM_Z = R - math.sqrt(R * R - BOTTOM_OFF * BOTTOM_OFF)    # so a ball on them has its centre at h + R
SIDE_ZS = (8.0, 15.0)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.render.resolution_x = int(RW * L.PX_PER_PT * SCALE)
sc.render.resolution_y = int(RH * L.PX_PER_PT * SCALE)
sc.render.film_transparent = True
sc.view_settings.view_transform = 'Standard'
sc.view_settings.look = 'None'

m = bpy.data.materials.new('brass'); m.use_nodes = True
b = m.node_tree.nodes['Principled BSDF']
b.inputs['Base Color'].default_value = (0.88, 0.66, 0.32, 1); b.inputs['Metallic'].default_value = 1.0
b.inputs['Roughness'].default_value = 0.24
M_BRASS = m
m = bpy.data.materials.new('walnut'); m.use_nodes = True
b = m.node_tree.nodes['Principled BSDF']
b.inputs['Base Color'].default_value = (0.10, 0.05, 0.022, 1); b.inputs['Roughness'].default_value = 0.5
M_WALNUT = m
SMOOTH = set()


def link(o):
    sc.collection.objects.link(o); return o


def tube3d(name, pts, r, mat):
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = r; cu.bevel_resolution = 3; cu.use_fill_caps = True
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for i, (x, y, z) in enumerate(pts):
        sp.points[i].co = (x, y, z, 1)
    cu.materials.append(mat); SMOOTH.add(name)
    return link(bpy.data.objects.new(name, cu))


def cylinder(name, x, y, r, z0, z1, mat, verts=24):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=z1 - z0, location=(x, y, (z0 + z1) / 2), vertices=verts)
    o = bpy.context.object; o.name = name; o.data.materials.append(mat); SMOOTH.add(o.name)
    return o


def lifted(pts, dz):
    return [(x, y, L.ramp_height((x, y)) + dz) for x, y in pts]


# ------------------------------------------------------------------ the wires
cl = L.densify(L.ramp_centerline(), 3.0)
for s in (1, -1):
    tube3d(f'carry{s}', lifted(L.ramp_offset(s * BOTTOM_OFF, cl), BOTTOM_Z), 1.3, M_BRASS)
    rail = L.densify(L.ramp_rail(s * L.RAMP_HALF_W), 3.0)
    for k, dz in enumerate(SIDE_ZS):
        tube3d(f'side{s}{k}', lifted(rail, dz), 1.15, M_BRASS)

# hoops every ~28 pt from the end of the flare to the door
u = (math.cos(L.RAMP_HEADING), math.sin(L.RAMP_HEADING))
along = 0.0
next_hoop = L.RAMP_FLARE_LEN
left_side = L.ramp_offset(L.RAMP_HALF_W, cl); right_side = L.ramp_offset(-L.RAMP_HALF_W, cl)
left_bot = L.ramp_offset(BOTTOM_OFF, cl); right_bot = L.ramp_offset(-BOTTOM_OFF, cl)
for i in range(1, len(cl)):
    along += math.hypot(cl[i][0] - cl[i - 1][0], cl[i][1] - cl[i - 1][1])
    if along >= next_hoop and i < len(cl) - 2:
        next_hoop += 28
        h = L.ramp_height(cl[i])
        pts = [(*left_side[i], h + SIDE_ZS[1]), (*left_side[i], h + 4.5), (*left_bot[i], h + BOTTOM_Z - 1.0),
               (*right_bot[i], h + BOTTOM_Z - 1.0), (*right_side[i], h + 4.5), (*right_side[i], h + SIDE_ZS[1])]
        tube3d(f'hoop{i}', pts, 0.9, M_BRASS)

# posts under the high part: on the outer wires, down to round walnut feet on the floor
post_at = []
acc = 0.0
for i in range(1, len(cl) - 3):
    acc += math.hypot(cl[i][0] - cl[i - 1][0], cl[i][1] - cl[i - 1][1])
    if acc >= 150 and (not post_at or acc - post_at[-1][0] >= 70):
        post_at.append((acc, i))
for _, i in post_at:
    h = L.ramp_height(cl[i])
    for s, side in ((1, left_side), (-1, right_side)):
        x, y = side[i]
        cylinder(f'post{i}{s}', x, y, 1.6, 0, h + SIDE_ZS[0], M_BRASS, verts=16)
        cylinder(f'foot{i}{s}', x, y, 3.6, 0, 1.6, M_WALNUT)

# the entry plate: a thin brass sheet on the floor in the mouth's flare, its far edge rising onto the carry wires
lr, rr = L.ramp_rail(L.RAMP_HALF_W), L.ramp_rail(-L.RAMP_HALF_W)
plate = [lr[0], rr[0], rr[1], lr[1]]
bm = bmesh.new()
top = [bm.verts.new((x, y, 0.3 + L.ramp_height((x, y)) * 0.5)) for x, y in plate]
bot = [bm.verts.new((x, y, 0.0)) for x, y in plate]
bm.faces.new(top); bm.faces.new(list(reversed(bot)))
for i in range(4):
    j = (i + 1) % 4
    bm.faces.new([bot[i], bot[j], top[j], top[i]])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
m = bpy.data.materials.new('satin'); m.use_nodes = True                        # satin brass: catches the soft boxes
b = m.node_tree.nodes['Principled BSDF']
b.inputs['Base Color'].default_value = (0.86, 0.66, 0.34, 1); b.inputs['Metallic'].default_value = 1.0
b.inputs['Roughness'].default_value = 0.5
me = bpy.data.meshes.new('plate'); bm.to_mesh(me); bm.free(); me.materials.append(m)
link(bpy.data.objects.new('plate', me))
tube3d('plateLip', [(*lr[0], 0.6), (*rr[0], 0.6)], 0.8, M_BRASS)

# M9 v27 (Aaron: balls looked like they fell through the ramp): the low part of the climb, where the ramp is lower than
# a ball (and a bit more), is a closed entry: a satin brass floor under the carry wires and walnut side skirts down to
# the table, so nothing looks like it passes under it. Above ENTRY_H the ramp is open wire, high enough to pass under.
ENTRY_H = 24.0
sat = bpy.data.materials.get('satin')
walnut_skirt = bpy.data.materials.new('skirt'); walnut_skirt.use_nodes = True
_b = walnut_skirt.node_tree.nodes['Principled BSDF']
_b.inputs['Base Color'].default_value = (0.16, 0.08, 0.04, 1); _b.inputs['Roughness'].default_value = 0.4
_b.inputs['Coat Weight'].default_value = 0.4
idx = [i for i in range(len(cl)) if L.ramp_height(cl[i]) <= ENTRY_H]
bm = bmesh.new()
fl_l = [bm.verts.new((*left_side[i], L.ramp_height(cl[i]) + BOTTOM_Z - 1.6)) for i in idx]
fl_r = [bm.verts.new((*right_side[i], L.ramp_height(cl[i]) + BOTTOM_Z - 1.6)) for i in idx]
for k in range(len(idx) - 1):
    bm.faces.new([fl_l[k], fl_r[k], fl_r[k + 1], fl_l[k + 1]])
me = bpy.data.meshes.new('entryFloor'); bm.to_mesh(me); bm.free(); me.materials.append(sat)
link(bpy.data.objects.new('entryFloor', me))
for s, side in ((1, left_side), (-1, right_side)):
    bm = bmesh.new()
    lo = [bm.verts.new((*side[i], 0.0)) for i in idx]
    hi = [bm.verts.new((*side[i], L.ramp_height(cl[i]) + SIDE_ZS[0])) for i in idx]
    for k in range(len(idx) - 1):
        bm.faces.new([lo[k], lo[k + 1], hi[k + 1], hi[k]])
    end = idx[-1]
    me = bpy.data.meshes.new(f'skirt{s}'); bm.to_mesh(me); bm.free(); me.materials.append(walnut_skirt)
    link(bpy.data.objects.new(f'skirt{s}', me))
    x, y = side[end]
    cylinder(f'entryPost{s}', x, y, 1.6, 0, L.ramp_height(cl[end]) + SIDE_ZS[0], M_BRASS, verts=16)

# ------------------------------------------------------------------ oblique shear
bpy.ops.object.select_all(action='DESELECT')
for o in list(sc.objects):
    if o.type in ('CURVE', 'MESH'):
        o.select_set(True)
bpy.context.view_layer.objects.active = next(o for o in sc.objects if o.type in ('MESH', 'CURVE'))
bpy.ops.object.convert(target='MESH')
for o in sc.objects:
    if o.type != 'MESH': continue
    mw = o.matrix_world.copy()
    o.data.transform(mw); o.matrix_world.identity()
    for v in o.data.vertices:
        v.co.y += v.co.z * K
    if o.name in SMOOTH:
        for p in o.data.polygons: p.use_smooth = True

# the floor: catches the ramp's shadow only
bpy.ops.mesh.primitive_plane_add(size=1, location=(X0 + RW / 2, Y0 + RH / 2, 0))
fl = bpy.context.object; fl.scale = (RW * 2, RH * 2, 1); fl.is_shadow_catcher = True

# ------------------------------------------------------------------ light (as lmp_bake_table.py)
sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.0; sun.angle = math.radians(12)
sun.color = (1.0, 0.86, 0.66)
so = link(bpy.data.objects.new('key', sun)); so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.5; fill.angle = math.radians(30)
fill.color = (0.75, 0.80, 1.0)
fo = link(bpy.data.objects.new('fill', fill)); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
for i, (x, y, w, h, e, col) in enumerate([(-200, 900, 500, 1400, 2.4, (1.0, 0.82, 0.58)),
                                           (800, 600, 300, 1200, 0.9, (1.0, 0.9, 0.75)),
                                           (284, -400, 900, 200, 1.1, (1.0, 0.78, 0.5))]):
    bpy.ops.mesh.primitive_plane_add(size=1, location=(x, y, 700))
    p = bpy.context.object; p.scale = (w, h, 1)
    em = bpy.data.materials.new(f'box{i}'); em.use_nodes = True
    nodes = em.node_tree.nodes; nodes.clear()
    o_ = nodes.new('ShaderNodeOutputMaterial'); e_ = nodes.new('ShaderNodeEmission')
    e_.inputs['Strength'].default_value = e; e_.inputs['Color'].default_value = (*col, 1)
    em.node_tree.links.new(e_.outputs[0], o_.inputs[0])
    p.data.materials.append(em); p.visible_camera = False; p.visible_shadow = False
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.09, 0.06, 0.04, 1)
w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6

cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(RW, RH); cam.clip_end = 5000
co = link(bpy.data.objects.new('cam', cam))
co.location = (X0 + RW / 2, Y0 + RH / 2, 1500)
sc.camera = co
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print('rendered', OUT, sc.render.resolution_x, sc.render.resolution_y)
