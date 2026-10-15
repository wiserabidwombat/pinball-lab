"""Table 03 milestone 8, art round 5a: the last code-drawn moving parts as rendered sprites, in the table's light.
  cth_flipper_upper.png  the upper flipper (right-hand, 64 long, pivot r 10, tip r 5), drawn straight like the main
                         flippers (cth_render_parts.py) because it rotates: bone body, sea-green rubber, brass cap.
                         Box FLIP_UP_BOX round the pivot.
  cth_gate_top.png       the top-right lane's one-way gate, and
  cth_gate_launch.png    the launch gate: a brass blade standing on edge from a chrome hinge barrel, rendered in
                         place at its CLOSED angle with the table's lean and its shadow (shadow catcher), origin =
                         the hinge. The game turns it about the hinge only while it swings.
Boxes are printed and written to <out_dir>/parts3.json.
Usage: python3 cth_render_parts3.py -- out_dir [samples]"""
import bpy, math, sys, os, json
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
os.makedirs(OUT, exist_ok=True)
K = L.OBLIQUE
PX = 6


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'
    return sc


def mat(name, color, metal=0.0, rough=0.4, coat=0.0, coat_rough=0.05, spec=0.5):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    b.inputs['Coat Weight'].default_value = coat
    b.inputs['Coat Roughness'].default_value = coat_rough
    b.inputs['Specular IOR Level'].default_value = spec
    return m


def link(o):
    bpy.context.scene.collection.objects.link(o); return o


def lights(sc, center=(0, 0)):
    """The table render's key sun, fill and soft boxes (soft boxes placed as on the table, relative to `center`)."""
    cx, cy = center
    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.4; sun.angle = math.radians(9)
    so = link(bpy.data.objects.new('key', sun)); so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.6; fill.angle = math.radians(30)
    fo = link(bpy.data.objects.new('fill', fill)); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
    for i, (x, y, w, h, e) in enumerate([(-200, 900, 500, 900, 2.6), (800, 300, 300, 600, 1.1), (284, -400, 900, 200, 1.2),
                                          (-200, 1700, 500, 900, 2.0), (800, 1200, 300, 900, 0.9)]):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x - cx, y - cy, 700))
        p = bpy.context.object; p.scale = (w, h, 1)
        em = bpy.data.materials.new(f'box{i}'); em.use_nodes = True
        nodes = em.node_tree.nodes; nodes.clear()
        o_ = nodes.new('ShaderNodeOutputMaterial'); e_ = nodes.new('ShaderNodeEmission')
        e_.inputs['Strength'].default_value = e; em.node_tree.links.new(e_.outputs[0], o_.inputs[0])
        p.data.materials.append(em); p.visible_camera = False; p.visible_shadow = False
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.05, 0.07, 0.08, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6
    bpy.ops.mesh.primitive_plane_add(size=3000, location=(0, 0, -30))
    fl = bpy.context.object; fl.data.materials.append(mat('reflect', (0.08, 0.22, 0.21), rough=0.6))
    fl.visible_camera = False; fl.visible_shadow = False
    return so


def cylinder(name, x, y, r, z0, z1, m, verts=32, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=z1 - z0, location=(x, y, (z0 + z1) / 2), vertices=verts)
    o = bpy.context.object; o.name = name; o.data.materials.append(m)
    if bevel:
        b = o.modifiers.new('b', 'BEVEL'); b.width = bevel; b.segments = 3
    return o


def prism(name, pts, z0, z1, m, bevel=0.0):
    me = bpy.data.meshes.new(name)
    n = len(pts)
    verts = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    faces = [list(range(n))[::-1], list(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    me.from_pydata(verts, [], faces); me.update(); me.materials.append(m)
    o = link(bpy.data.objects.new(name, me))
    if bevel:
        b = o.modifiers.new('b', 'BEVEL'); b.width = bevel; b.segments = 3; b.limit_method = 'ANGLE'
    return o


def tube(name, pts3, r, m, closed=False):
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = r; cu.bevel_resolution = 4; cu.use_fill_caps = not closed
    sp = cu.splines.new('POLY'); sp.points.add(len(pts3) - 1)
    for i, (x, y, z) in enumerate(pts3): sp.points[i].co = (x, y, z, 1)
    sp.use_cyclic_u = closed
    cu.materials.append(m)
    return link(bpy.data.objects.new(name, cu))


def bake(sc, lean):
    """Convert curves, apply modifiers, bake transforms; with `lean`, shear y += z K."""
    for o in [o for o in sc.objects if o.type == 'CURVE']:
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
        bpy.ops.object.convert(target='MESH')
    parts = [o for o in sc.objects if o.type == 'MESH' and o.visible_camera]
    for o in parts:
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=m.name)
        o.data.transform(o.matrix_world); o.matrix_world.identity()
        for v in o.data.vertices:
            if lean: v.co.y += v.co.z * K
        for p in o.data.polygons: p.use_smooth = True
    return parts


def shoot(sc, name, box):
    x0, y0, x1, y1 = box
    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(x1 - x0, y1 - y0)
    co = link(bpy.data.objects.new('cam', cam)); co.location = ((x0 + x1) / 2, (y0 + y1) / 2, 500)
    sc.camera = co
    sc.render.resolution_x = int(round((x1 - x0) * PX)); sc.render.resolution_y = int(round((y1 - y0) * PX))
    sc.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)
    print('rendered', name, box, sc.render.resolution_x, sc.render.resolution_y)


def capsule_outline(length, r0, r1, n=24, direction=1):
    d = length; a = math.asin((r0 - r1) / d)
    pts = []
    for i in range(n + 1):
        t = math.pi / 2 + a + (math.pi - 2 * a) * i / n
        pts.append((r0 * math.cos(t), r0 * math.sin(t)))
    for i in range(n + 1):
        t = -math.pi / 2 + a + (math.pi - 2 * a) * i / n
        pts.append((d + r1 * math.cos(t), r1 * math.sin(t)))
    pts = [(x * direction, y) for x, y in pts]
    if direction < 0: pts.reverse()
    return pts


boxes = {}

# ------------------------------------------------------------------ the upper flipper (right-hand, points -x)
# Same build as the main flippers, scaled to 64 / r 10 / r 5 with the same rubber and cap sizes, so it reads as the
# same family without the stretched look of the scaled main image.
UP_LEN, UP_R0, UP_R1 = 64, 10, 5
FLIP_UP_BOX = (-(UP_LEN + 12), -15, 15, 15)
sc = reset(); lights(sc, center=(528, 800))
bone = mat('bone', (0.93, 0.89, 0.80), rough=0.28, coat=0.6)
rubber = mat('rubber', (0.05, 0.42, 0.34), rough=0.45, spec=0.3)
brass = mat('brass', (0.86, 0.64, 0.30), metal=1.0, rough=0.2)
chrome = mat('chrome', (0.92, 0.93, 0.95), metal=1.0, rough=0.12)
prism('body', capsule_outline(UP_LEN, UP_R0 - 2.6, UP_R1 - 2.4, direction=-1), 0, 9, bone, bevel=1.1)
tube('rubber', [(x, y, 4.6) for x, y in capsule_outline(UP_LEN, UP_R0 - 1.6, UP_R1 - 1.6, direction=-1)], 1.7, rubber, closed=True)
cylinder('cap', 0, 0, 4.0, 9, 11.2, brass, verts=48, bevel=0.7)
cylinder('screw', 0, 0, 1.4, 11.2, 12.1, chrome, verts=24)
bake(sc, lean=False)
shoot(sc, 'cth_flipper_upper.png', FLIP_UP_BOX)
boxes['flipperUpper'] = [FLIP_UP_BOX[0], FLIP_UP_BOX[1], FLIP_UP_BOX[2] - FLIP_UP_BOX[0], FLIP_UP_BOX[3] - FLIP_UP_BOX[1]]


# ------------------------------------------------------------------ the two one-way gates
def gate(name, hinge, end):
    """A brass blade on edge from the hinge toward `end` (in world points), rendered in place, origin = hinge."""
    sc = reset(); so = lights(sc, center=hinge)
    brass = mat('brass', (0.86, 0.64, 0.30), metal=1.0, rough=0.22)
    brassDark = mat('brassDark', (0.55, 0.38, 0.15), metal=1.0, rough=0.35)
    chrome = mat('chrome', (0.92, 0.93, 0.95), metal=1.0, rough=0.12)
    dx, dy = end[0] - hinge[0], end[1] - hinge[1]
    ln = math.hypot(dx, dy); ux, uy = dx / ln, dy / ln; nx, ny = -uy, ux
    t = 0.9                                                    # half the blade's thickness
    s0, s1 = 2.6, ln - 0.5
    quad = [(s0 * ux + t * nx, s0 * uy + t * ny), (s1 * ux + t * nx, s1 * uy + t * ny),
            (s1 * ux - t * nx, s1 * uy - t * ny), (s0 * ux - t * nx, s0 * uy - t * ny)]
    prism('blade', quad, 1.0, 9.0, brass, bevel=0.35)
    tube('bladeTop', [(s0 * ux, s0 * uy, 9.0), (s1 * ux, s1 * uy, 9.0)], 1.1, brass)        # rolled top edge
    for k in (0.35, 0.7):                                                                  # two rivets each side
        for sgn in (1, -1):
            px, py = k * ln * ux + sgn * t * nx, k * ln * uy + sgn * t * ny
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.75, location=(px, py, 5.0), segments=16, ring_count=8)
            bpy.context.object.data.materials.append(brassDark)
    cylinder('barrel', 0, 0, 2.6, 0, 11, chrome, bevel=0.5)                                # the hinge barrel
    cylinder('barrelCap', 0, 0, 3.2, 11, 12.4, brass, bevel=0.5)
    parts = bake(sc, lean=True)
    # the box: the parts and their shadows
    bpy.context.view_layer.update()
    d = so.matrix_world.to_3x3() @ Vector((0, 0, -1))
    xs, ys = [], []
    for o in parts:
        for v in o.data.vertices:
            x, y, z = v.co
            xs.append(x); ys.append(y)
            zz = max(z, 0); tt = zz / -d.z
            xs.append(x + d.x * tt); ys.append(y - zz * K + d.y * tt * 0.7)
    box = (math.floor(min(xs)) - 2, math.floor(min(ys)) - 2, math.ceil(max(xs)) + 2, math.ceil(max(ys)) + 2)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
    cat = bpy.context.object; cat.scale = (200, 200, 1); cat.is_shadow_catcher = True
    shoot(sc, name, box)
    boxes[name.replace('.png', '')] = [box[0], box[1], box[2] - box[0], box[3] - box[1]]


gate('cth_gate_top.png', L.TOP_GATE_HINGE, L.TOP_GATE_END)
gate('cth_gate_launch.png', (L.RIGHT_X, 955 + 28), (548, 955))

json.dump(boxes, open(os.path.join(OUT, 'parts3.json'), 'w'))
print('boxes', boxes)
