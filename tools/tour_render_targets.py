"""Table 06 (Orbit: Grand Tour) M6 v6: the targets as rendered sprites, each in its own facing and the table's
oblique (y += z·K), so they are NOT rotated in the game: the R-O-C and K-E-T standups (off and lit), the Mars sample
drops, the blast door and its two wings (drops on a chrome frame round a black slot). Plus a normal map each (_n,
emission of the normal, Raw), so the SKLightNodes light them. Image box symmetric round the target's centre, 6 px/pt;
the BOX lines print the size in points.
Usage: python3 tour_render_targets.py -- out_dir [samples] [only]"""
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'
    return sc


def principled(name, color, metal=0.0, rough=0.4, coat=0.0, coat_rough=0.05, spec=0.5):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    b.inputs['Coat Weight'].default_value = coat
    b.inputs['Coat Roughness'].default_value = coat_rough
    b.inputs['Specular IOR Level'].default_value = spec
    return m


def lights(sc, world=0.6, floor=(0.05, 0.07, 0.16)):
    """The same key sun, fill and soft boxes as the table render."""
    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.4; sun.angle = math.radians(9)
    so = bpy.data.objects.new('key', sun); sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.6; fill.angle = math.radians(30)
    fo = bpy.data.objects.new('fill', fill); sc.collection.objects.link(fo)
    fo.rotation_euler = (math.radians(30), math.radians(25), 0)
    for i, (x, y, w, h, e) in enumerate([(-200, 900, 500, 900, 2.6), (800, 300, 300, 600, 1.1), (284, -400, 900, 200, 1.2)]):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x - 284, y - 300, 700))
        p = bpy.context.object; p.scale = (w, h, 1)
        em = bpy.data.materials.new(f'box{i}'); em.use_nodes = True
        nodes = em.node_tree.nodes; nodes.clear()
        o_ = nodes.new('ShaderNodeOutputMaterial'); e_ = nodes.new('ShaderNodeEmission')
        e_.inputs['Strength'].default_value = e; em.node_tree.links.new(e_.outputs[0], o_.inputs[0])
        p.data.materials.append(em); p.visible_camera = False; p.visible_shadow = False
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.02, 0.03, 0.07, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = world
    # a navy floor (the space table) for the chrome to reflect, unseen by the camera
    bpy.ops.mesh.primitive_plane_add(size=3000, location=(0, 0, -30))
    fl = bpy.context.object
    fl.data.materials.append(principled('reflectfloor', floor, rough=0.6))
    fl.visible_camera = False; fl.visible_shadow = False


def camera(sc, x0, y0, x1, y1, px_per_pt):
    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'
    w, h = x1 - x0, y1 - y0
    cam.ortho_scale = max(w, h)
    co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co)
    co.location = ((x0 + x1) / 2, (y0 + y1) / 2, 500)
    sc.camera = co
    sc.render.resolution_x = int(round(w * px_per_pt))
    sc.render.resolution_y = int(round(h * px_per_pt))


def render(sc, name):
    sc.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)
    print('rendered', name, sc.render.resolution_x, sc.render.resolution_y)


def capsule_outline(length, r0, r1, n=24, direction=1):
    """Flipper outline, pivot at the origin, pointing +x (direction 1) or -x (-1), counter-clockwise."""
    # tangent lines between the two circles
    d = length; a = math.asin((r0 - r1) / d)
    pts = []
    for i in range(n + 1):        # big end, from the top tangent round the back to the bottom tangent
        t = math.pi / 2 + a + (math.pi - 2 * a) * i / n
        pts.append((r0 * math.cos(t), r0 * math.sin(t)))
    for i in range(n + 1):        # tip end
        t = -math.pi / 2 + a + (math.pi - 2 * a) * i / n
        pts.append((d + r1 * math.cos(t), r1 * math.sin(t)))
    pts = [(x * direction, y) for x, y in pts]
    if direction < 0:
        pts.reverse()
    return pts


def prism(name, pts, z0, z1, mat, bevel=0.0):
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, z0)) for x, y in pts]
    face = bm.faces.new(vs)
    if face.normal.z < 0: face.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z = z1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    if bevel:
        b = o.modifiers.new('b', 'BEVEL'); b.width = bevel; b.segments = 4; b.limit_method = 'ANGLE'
    for p in me.polygons: p.use_smooth = True
    return o


def tube_loop(name, pts, z, r, mat):
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = r; cu.bevel_resolution = 4
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for i, (x, y) in enumerate(pts): sp.points[i].co = (x, y, z, 1)
    sp.use_cyclic_u = True
    cu.materials.append(mat)
    o = bpy.data.objects.new(name, cu); bpy.context.scene.collection.objects.link(o)
    return o



def normal_material():
    m = bpy.data.materials.new('normals'); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial'); em = nt.nodes.new('ShaderNodeEmission')
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    mul = nt.nodes.new('ShaderNodeVectorMath'); mul.operation = 'MULTIPLY_ADD'
    mul.inputs[1].default_value = (0.5, 0.5, 0.5); mul.inputs[2].default_value = (0.5, 0.5, 0.5)
    nt.links.new(geo.outputs['Normal'], mul.inputs[0]); nt.links.new(mul.outputs[0], em.inputs['Color'])
    nt.links.new(em.outputs[0], out.inputs[0])
    return m



# ------------------------------------------------------------------ targets (M6 v6)
K = 0.404           # the table's oblique: a point z above the floor draws at y + z·K
PX = 6
import mathutils


def box(name, x0, x1, y0, y1, z0, z1, mat, bevel=0.0):
    pts = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    return prism(name, pts, z0, z1, mat, bevel)


def stripes_mat(name, a, b, period=3.0):
    """Hazard stripes: diagonal bands of a and b in object x+z."""
    m = principled(name, a, rough=0.35, coat=0.4)
    nt = m.node_tree; bsdf = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    add = nt.nodes.new('ShaderNodeMath'); add.operation = 'ADD'
    div = nt.nodes.new('ShaderNodeMath'); div.operation = 'DIVIDE'; div.inputs[1].default_value = period
    fr = nt.nodes.new('ShaderNodeMath'); fr.operation = 'FRACT'
    gt = nt.nodes.new('ShaderNodeMath'); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = 0.5
    mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'
    mix.inputs[6].default_value = (*a, 1); mix.inputs[7].default_value = (*b, 1)
    L = nt.links.new
    L(tc.outputs['Object'], sep.inputs[0]); L(sep.outputs[0], add.inputs[0]); L(sep.outputs[2], add.inputs[1])
    L(add.outputs[0], div.inputs[0]); L(div.outputs[0], fr.inputs[0]); L(fr.outputs[0], gt.inputs[0])
    L(gt.outputs[0], mix.inputs[0]); L(mix.outputs[2], bsdf.inputs['Base Color'])
    return m


def glow(m, color, strength):
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Emission Color'].default_value = (*color, 1)
    b.inputs['Emission Strength'].default_value = strength
    return m


def finish(sc, normal, name):
    """Apply modifiers, turn the plate's +y face to `normal`, shear for the oblique, frame and render art + normals."""
    bpy.ops.object.select_all(action='DESELECT')
    meshes = [o for o in sc.objects if o.type == 'MESH' and o.visible_camera]
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.convert(target='MESH')
    rot = mathutils.Matrix.Rotation(normal - math.pi / 2, 4, 'Z')
    shear = mathutils.Matrix.Identity(4); shear[1][2] = K
    xs, ys = [0.0], [0.0]
    for o in meshes:
        o.data.transform(shear @ rot @ o.matrix_world); o.matrix_world = mathutils.Matrix.Identity(4)
        o.data.update()
        for v in o.data.vertices: xs.append(v.co.x); ys.append(v.co.y)
        for p in o.data.polygons: p.use_smooth = True
    hx = math.ceil(max(abs(min(xs)), abs(max(xs))) + 2); hy = math.ceil(max(abs(min(ys)), abs(max(ys))) + 2)
    camera(sc, -hx, -hy, hx, hy, PX)
    render(sc, name + '.png')
    print('BOX', name, 2 * hx, 2 * hy)
    return hx, hy


def normals(sc, name):
    sc.view_layers[0].material_override = normal_material()
    sc.cycles.samples = 16; sc.cycles.use_denoising = False
    sc.view_settings.view_transform = 'Raw'
    render(sc, name + '_n.png')


def standup(normal, name):
    """26 pt plastic face (3 thick, 14 tall) at the front of the 8 pt footprint, on a chrome bracket and a black foot."""
    for lit in (False, True):
        sc = reset(); lights(sc)
        if lit:
            plastic = glow(principled('lit', (0.20, 0.66, 1.0), rough=0.25, coat=0.8), (0.15, 0.62, 1.0), 1.4)
        else:
            plastic = principled('off', (0.07, 0.20, 0.42), rough=0.25, coat=0.8)
        chrome = principled('chrome', (0.86, 0.87, 0.90), metal=1.0, rough=0.3)
        black = principled('black', (0.03, 0.03, 0.04), rough=0.5)
        white = principled('white', (0.92, 0.93, 0.95), rough=0.3, coat=0.5)
        box('face', -13, 13, 1, 4, 1, 14, plastic, bevel=0.9)
        box('rim', -12, 12, 3.9, 4.25, 11.2, 12.4, white, bevel=0.15)       # a printed stripe across the face
        box('bracket', -4.5, 4.5, -3.5, 1.2, 0, 9, chrome, bevel=0.6)
        box('foot', -7, 7, -4, 4, 0, 1.2, black, bevel=0.4)
        finish(sc, normal, name + ('_lit' if lit else ''))
        if not lit:
            normals(sc, name)


def drop(normal, name, width, height, mat_fn, deco=None):
    sc = reset(); lights(sc)
    black = principled('black', (0.03, 0.03, 0.04), rough=0.5)
    chrome = principled('chrome', (0.86, 0.87, 0.90), metal=1.0, rough=0.3)
    w = width / 2
    box('frame', -w - 1, w + 1, -4, 4, 0, 1.4, chrome, bevel=0.4)
    box('slot', -w, w, -2.5, 2.5, 0.5, 1.5, black)
    box('target', -w + 0.5, w - 0.5, -1.2, 2.6, 1, height, mat_fn(), bevel=0.8)
    if deco: deco(w, height)
    finish(sc, normal, name)
    normals(sc, name)


def sample_mat():
    return principled('mars', (0.80, 0.28, 0.14), rough=0.3, coat=0.8)


def sample_deco(w, h):
    white = principled('white', (0.92, 0.93, 0.95), rough=0.3, coat=0.5)
    box('band', -w + 1.5, w - 1.5, 2.5, 2.9, h - 3.2, h - 1.8, white, bevel=0.15)


def steel_mat():
    return principled('steel', (0.55, 0.58, 0.64), metal=0.85, rough=0.38)


def door_deco(w, h):
    hz = stripes_mat('hazard', (0.95, 0.70, 0.08), (0.04, 0.04, 0.05), period=3.4)
    box('hazard', -w + 1.2, w - 1.2, 2.5, 2.95, h - 4.2, h - 1.2, hz, bevel=0.1)
    dark = principled('dark', (0.20, 0.21, 0.24), metal=0.8, rough=0.35)
    for x in (-w + 2.5, w - 2.5):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.9, depth=0.6, location=(x, 2.9, 3.5), rotation=(math.pi / 2, 0, 0), vertices=16)
        bpy.context.object.data.materials.append(dark)


def wing_deco(w, h):
    dark = principled('dark', (0.20, 0.21, 0.24), metal=0.8, rough=0.35)
    for x in (-w + 3, 0, w - 3):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.8, depth=0.6, location=(x, 2.9, h / 2), rotation=(math.pi / 2, 0, 0), vertices=16)
        bpy.context.object.data.materials.append(dark)


ONLY = argv[2] if len(argv) > 2 else ''
jobs = [
    ('tour_standup_roc', lambda: standup(-0.4363, 'tour_standup_roc')),
    ('tour_standup_ket', lambda: standup(260 * math.pi / 180, 'tour_standup_ket')),
    ('tour_drop_sample', lambda: drop(3.3510, 'tour_drop_sample', 24, 12, sample_mat, sample_deco)),
    ('tour_blastdoor', lambda: drop(-math.pi / 2, 'tour_blastdoor', 34, 13, steel_mat, door_deco)),
    ('tour_wing_l', lambda: drop(-math.pi / 2 - math.pi / 6, 'tour_wing_l', 36, 10, steel_mat, wing_deco)),
    ('tour_wing_r', lambda: drop(-math.pi / 2 + math.pi / 6, 'tour_wing_r', 36, 10, steel_mat, wing_deco)),
]
for n, fn in jobs:
    if not ONLY or ONLY in n:
        fn()
