"""Table 03 milestone 8, art round 3: the right ramp and the Library's up-kicker wire as ONE sprite, in the table's light
and 22-degree lean, with their shadows on the playfield baked in (shadow catcher, transparent background).
  Right ramp: a steel entrance flap on the playfield, a clear sea-green plastic floor rising to RAMP_TOP_H, clear
  plastic side walls with bright edges, chrome support posts; after the apex it becomes a steel wire return.
  Library wire: the same wire form in old brass.
Heights follow cth_layout.ramp_height (the game's CthRamp.height(at:) uses the same profile), so the ball, which the
game lifts by height x OBLIQUE, rides exactly on the drawn surface.
The sprite covers a world rectangle (printed and written to <out>.json); the game places it at the origin.
Usage: python3 cth_render_ramps.py -- out.png [samples] [px_per_pt]"""
import bpy, bmesh, math, sys, os, json
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
PX = float(argv[2]) if len(argv) > 2 else L.PX_PER_PT
K = L.OBLIQUE

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.cycles.transparent_max_bounces = 16
sc.render.film_transparent = True
sc.view_settings.view_transform = 'Standard'


def mat(name, color, metal=0.0, rough=0.4, coat=0.0, coat_rough=0.05, spec=0.5, alpha=1.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    b.inputs['Coat Weight'].default_value = coat
    b.inputs['Coat Roughness'].default_value = coat_rough
    b.inputs['Specular IOR Level'].default_value = spec
    b.inputs['Alpha'].default_value = alpha
    return m


M_FLOOR = mat('rampFloor', (0.16, 0.62, 0.54), rough=0.06, coat=1.0, spec=0.6, alpha=0.52)
M_WALL = mat('rampWall', (0.70, 0.95, 0.90), rough=0.05, coat=1.0, spec=0.7, alpha=0.20)
M_EDGE = mat('rampEdge', (0.88, 1.0, 0.97), rough=0.05, coat=1.0, spec=0.8, alpha=0.75)
M_STEEL = mat('steel', (0.70, 0.72, 0.75), metal=1.0, rough=0.25)
M_CHROME = mat('chrome', (0.92, 0.93, 0.95), metal=1.0, rough=0.12)
M_BRASS = mat('brass', (0.86, 0.64, 0.30), metal=1.0, rough=0.22)
M_BLACK = mat('black', (0.02, 0.02, 0.025), rough=0.5)


def link(o):
    sc.collection.objects.link(o); return o


def mesh(name, verts, faces, m, solidify=0.0):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    me.materials.append(m)
    o = link(bpy.data.objects.new(name, me))
    if solidify:
        s = o.modifiers.new('s', 'SOLIDIFY'); s.thickness = solidify; s.offset = 0
    return o


def tube(name, pts3, r, m, res=3):
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = r; cu.bevel_resolution = res; cu.use_fill_caps = True
    sp = cu.splines.new('POLY'); sp.points.add(len(pts3) - 1)
    for i, (x, y, z) in enumerate(pts3): sp.points[i].co = (x, y, z, 1)
    cu.materials.append(m)
    return link(bpy.data.objects.new(name, cu))


def cylinder(name, x, y, r, z0, z1, m, verts=24):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=max(z1 - z0, 0.1), location=(x, y, (z0 + z1) / 2), vertices=verts)
    o = bpy.context.object; o.name = name; o.data.materials.append(m)
    return o


def frange(a, b, step):
    n = max(1, math.ceil((b - a) / step))
    return [a + (b - a) * i / n for i in range(n + 1)]


def at(path, s, off, z):
    (x, y), h = path.sample(max(s, 0)) if s >= 0 else path.sample(0)
    if s < 0:                                        # before the mouth: straight back along the first heading
        x, y = x + s * math.cos(h), y + s * math.sin(h)
    nx, ny = -math.sin(h), math.cos(h)               # left normal
    return (x + off * nx, y + off * ny, z)


# ------------------------------------------------------------------ the right ramp
rp, apex = L.right_ramp_path()
RL = rp.length
H = lambda s: L.ramp_height(s, apex, RL, L.RAMP_END_H)
W = L.ramp_half_width
WALL_H, FLOOR_T = 14, 1.6

# the plastic floor: a strip at the running height, slightly wider than the rails, with a thickness
ss = frange(2, apex + 4, 3)
verts, faces = [], []
for s in ss:
    w = W(s) + 1.5
    verts += [at(rp, s, w, H(s)), at(rp, s, -w, H(s))]
for i in range(len(ss) - 1):
    faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
mesh('rampFloor', verts, faces, M_FLOOR, solidify=FLOOR_T)

# side walls: clear plastic standing on the floor's edges, with a bright rolled top edge
for side in (1, -1):
    verts, faces, edge = [], [], []
    for s in ss:
        w = (W(s) + 1.5) * side
        verts += [at(rp, s, w, H(s) - FLOOR_T / 2), at(rp, s, w, H(s) + WALL_H)]
        edge.append(at(rp, s, w, H(s) + WALL_H))
    for i in range(len(ss) - 1):
        faces.append((2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1))
    mesh('rampWall' + str(side), verts, faces, M_WALL, solidify=1.2)
    tube('rampEdge' + str(side), edge, 0.95, M_EDGE)
    # the low edge where the wall meets the floor
    tube('rampSeam' + str(side), [at(rp, s, (W(s) + 1.5) * side, H(s) + 0.6) for s in ss], 0.6, M_EDGE)

# the entrance flap: a thin steel plate lying on the playfield, its lip lapping onto the plastic
verts, faces = [], []
fs = frange(-8, 5, 1)
for s in fs:
    w = W(0) + 2.5
    z = 0.25 if s <= 0 else 0.25 + H(s) * s / 5
    verts += [at(rp, s, w, z), at(rp, s, -w, z)]
for i in range(len(fs) - 1):
    faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
mesh('flap', verts, faces, M_STEEL, solidify=0.7)
tube('flapEdge', [at(rp, -8, W(0) + 2.5, 0.4), at(rp, -8, -W(0) - 2.5, 0.4)], 0.55, M_CHROME)
for k in (-1, 1):
    x, y, _ = at(rp, -4, k * (W(0) - 3), 0)
    cylinder('rivet' + str(k), x, y, 1.3, 0.3, 1.2, M_CHROME, verts=16)

# support posts: chrome, from the playfield to the ramp's underside, on the outside of each wall at two places,
# with a short bracket under the floor
for s in (150, apex - 40):
    for side in (1, -1):
        w = (W(s) + 4.5) * side
        x, y, _ = at(rp, s, w, 0)
        cylinder(f'post{s}{side}', x, y, 1.9, 0, H(s) + WALL_H * 0.55, M_CHROME)
        tube(f'bracket{s}{side}', [at(rp, s, w, H(s) - FLOOR_T), at(rp, s, 0, H(s) - FLOOR_T)], 0.9, M_STEEL)


def wire(path, s0, s1, height, metal, name, posts):
    """A wire-form return: two lower rails the ball rides between, two upper guide rails, U-hoops tying them,
    and posts down to the playfield."""
    ws = frange(s0, s1, 4)
    for side in (1, -1):
        tube(name + 'Low' + str(side), [at(path, s, 5.5 * side, height(s) + 1.2) for s in ws], 1.05, metal)
        tube(name + 'High' + str(side), [at(path, s, 10.5 * side, height(s) + 8.5) for s in ws], 0.95, metal)
    for s in frange(s0 + 4, s1 - 2, 22):
        hoop = []
        for k in range(13):
            a = math.pi * k / 12
            hoop.append(at(path, s, -10.5 * math.cos(a), height(s) + 8.5 - 9.6 * math.sin(a)))
        tube(name + 'Hoop' + str(int(s)), hoop, 0.7, metal, res=2)
    for s in posts:
        x, y, _ = at(path, s, 0, 0)
        cylinder(name + 'Post' + str(int(s)), x, y, 1.5, 0, height(s) - 1.0, M_STEEL, verts=16)
        cylinder(name + 'Foot' + str(int(s)), x, y, 3.0, 0, 1.2, M_CHROME, verts=20)


# the right ramp's return wire: steel, from the apex (lapping the plastic) to the end
wire(rp, apex - 3, RL - 1, H, M_STEEL, 'ret', posts=(apex + 90, apex + 220, RL - 30))
# a steel end plate where the plastic hands over to the wire
tube('handover', [at(rp, apex + 2, W(apex) + 1.5, H(apex) + 0.5), at(rp, apex + 2, -W(apex) - 1.5, H(apex) + 0.5)],
     1.0, M_STEEL)

# ------------------------------------------------------------------ the Library's up-kicker wire (old brass)
lp, lapex = L.library_wire_path()
LL = lp.length
HL = lambda s: L.ramp_height(s, lapex, LL, L.WIRE_END_H)
wire(lp, 14, LL - 1, HL, M_BRASS, 'lib', posts=(120, lapex + 70, lapex + 200, LL - 25))

# ------------------------------------------------------------------ lean: y += z * K
for o in [o for o in sc.objects if o.type in ('MESH', 'CURVE')]:
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True); bpy.context.view_layer.objects.active = o
    if o.type == 'CURVE': bpy.ops.object.convert(target='MESH')
for o in [o for o in sc.objects if o.type == 'MESH']:
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True); bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=m.name)
    o.data.transform(o.matrix_world); o.matrix_world.identity()
    for v in o.data.vertices: v.co.y += v.co.z * K
    for p in o.data.polygons: p.use_smooth = True

# ------------------------------------------------------------------ light (the table's), shadow catcher, camera
sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.4; sun.angle = math.radians(9)
so = link(bpy.data.objects.new('key', sun)); so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.6; fill.angle = math.radians(30)
fo = link(bpy.data.objects.new('fill', fill)); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
for i, (x, y, w, h, e) in enumerate([(-200, 900, 500, 900, 2.6), (800, 300, 300, 600, 1.1), (284, -400, 900, 200, 1.2),
                                      (-200, 1700, 500, 900, 2.0), (800, 1200, 300, 900, 0.9)]):
    bpy.ops.mesh.primitive_plane_add(size=1, location=(x, y, 700))
    p = bpy.context.object; p.scale = (w, h, 1)
    em = bpy.data.materials.new(f'box{i}'); em.use_nodes = True
    nodes = em.node_tree.nodes; nodes.clear()
    o_ = nodes.new('ShaderNodeOutputMaterial'); e_ = nodes.new('ShaderNodeEmission')
    e_.inputs['Strength'].default_value = e; em.node_tree.links.new(e_.outputs[0], o_.inputs[0])
    p.data.materials.append(em); p.visible_camera = False; p.visible_shadow = False
wd = bpy.data.worlds.new('w'); sc.world = wd; wd.use_nodes = True
wd.node_tree.nodes['Background'].inputs['Color'].default_value = (0.05, 0.07, 0.08, 1)
wd.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6

# the box: every part plus where its shadow falls on the playfield
bpy.context.view_layer.update()
d = so.matrix_world.to_3x3() @ Vector((0, 0, -1))
xs, ys = [], []
for o in [o for o in sc.objects if o.type == 'MESH' and o.visible_camera]:
    for v in o.data.vertices:
        x, y, z = v.co
        xs.append(x); ys.append(y)
        t = z / -d.z                                 # down the light to the floor (in unsheared z)
        xs.append(x + d.x * t); ys.append(y - z * K + d.y * t)
x0, y0 = math.floor(min(xs)) - 4, math.floor(min(ys)) - 4
x1, y1 = math.ceil(max(xs)) + 4, math.ceil(max(ys)) + 4

bpy.ops.mesh.primitive_plane_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, 0))
cat = bpy.context.object; cat.scale = (x1 - x0 + 40, y1 - y0 + 40, 1); cat.is_shadow_catcher = True
bpy.ops.mesh.primitive_plane_add(size=3000, location=(300, 700, -30))
fl = bpy.context.object; fl.data.materials.append(mat('reflect', (0.08, 0.22, 0.21), rough=0.6))
fl.visible_camera = False; fl.visible_shadow = False

cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(x1 - x0, y1 - y0); cam.clip_end = 3000
co = link(bpy.data.objects.new('cam', cam)); co.location = ((x0 + x1) / 2, (y0 + y1) / 2, 1000)
sc.camera = co
sc.render.resolution_x = int(round((x1 - x0) * PX)); sc.render.resolution_y = int(round((y1 - y0) * PX))
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
info = {'box': [x0, y0, x1 - x0, y1 - y0], 'px': [sc.render.resolution_x, sc.render.resolution_y],
        'apex': apex, 'length': RL, 'wireApex': lapex, 'wireLength': LL}
json.dump(info, open(os.path.splitext(OUT)[0] + '.json', 'w'))
print('rendered', OUT, info)
