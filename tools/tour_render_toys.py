"""Table 06 (Orbit: Grand Tour) M6 v7: the pop bumpers and the rocket toy as rendered sprites (helpers from
tour_render_targets.py), in the table's oblique (y += z·K, camera straight down) so the sprites are not rotated.
tour_bumper (+_n): black base, chrome skirt ring, white body, glossy red dome cap with a white ring and a chrome screw;
the image is centred on the bumper's floor centre (the cap draws ~8 pt above it). tour_rocket (+_n): white body, red nose
and four fins, black roll band, blue porthole, dark engine bell, 1.5× (v7b); its foot at the image centre (TourTableLayout.rocketToy).
6 px/pt; the BOX lines print the image size in points.
Usage: python3 tour_render_toys.py -- out_dir [samples] [only]"""
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



def ring_cap_mat():
    """Glossy red with a white ring (object radius 12.5–15) painted on."""
    m = principled('cap', (0.78, 0.07, 0.05), rough=0.18, coat=1.0)
    nt = m.node_tree; bsdf = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    comb = nt.nodes.new('ShaderNodeCombineXYZ')
    ln = nt.nodes.new('ShaderNodeVectorMath'); ln.operation = 'LENGTH'
    a = nt.nodes.new('ShaderNodeMath'); a.operation = 'GREATER_THAN'; a.inputs[1].default_value = 12.0
    b = nt.nodes.new('ShaderNodeMath'); b.operation = 'LESS_THAN'; b.inputs[1].default_value = 14.6
    mul = nt.nodes.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'
    mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'
    mix.inputs[6].default_value = (0.78, 0.07, 0.05, 1); mix.inputs[7].default_value = (0.93, 0.92, 0.88, 1)
    L = nt.links.new
    # the mesh is sheared before rendering (y' = y + z·K), so un-shear: y = y' − z·K
    unk = nt.nodes.new('ShaderNodeMath'); unk.operation = 'MULTIPLY_ADD'; unk.inputs[1].default_value = -K
    L(tc.outputs['Object'], sep.inputs[0]); L(sep.outputs[0], comb.inputs[0])
    L(sep.outputs[2], unk.inputs[0]); L(sep.outputs[1], unk.inputs[2]); L(unk.outputs[0], comb.inputs[1])
    L(comb.outputs[0], ln.inputs[0]); L(ln.outputs['Value'], a.inputs[0]); L(ln.outputs['Value'], b.inputs[0])
    L(a.outputs[0], mul.inputs[0]); L(b.outputs[0], mul.inputs[1]); L(mul.outputs[0], mix.inputs[0])
    L(mix.outputs[2], bsdf.inputs['Base Color'])
    return m


def cyl(r, z0, z1, mat, verts=64, bevel=0.0, loc=(0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=z1 - z0, location=(loc[0], loc[1], (z0 + z1) / 2), vertices=verts)
    o = bpy.context.object; o.data.materials.append(mat)
    if bevel:
        b = o.modifiers.new('b', 'BEVEL'); b.width = bevel; b.segments = 3
    return o


def bumper():
    sc = reset(); lights(sc)
    black = principled('black', (0.03, 0.03, 0.04), rough=0.45)
    chrome = principled('chrome', (0.86, 0.87, 0.90), metal=1.0, rough=0.28)
    white = principled('white', (0.90, 0.91, 0.93), rough=0.3, coat=0.6)
    cyl(26.5, 0, 2.0, black, bevel=0.6)                       # base plate
    bpy.ops.mesh.primitive_torus_add(major_radius=24.2, minor_radius=1.3, location=(0, 0, 4.2),
                                     major_segments=96, minor_segments=16)
    bpy.context.object.data.materials.append(chrome)           # the skirt ring
    cyl(20.5, 2.0, 15.0, white, bevel=0.8)                     # body
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=(0, 0, 14.5), segments=96, ring_count=48)
    cap = bpy.context.object; cap.scale = (22, 22, 7.5); cap.data.materials.append(ring_cap_mat())
    bpy.context.view_layer.objects.active = cap
    bpy.ops.object.transform_apply(scale=True)
    cyl(22.2, 13.4, 15.2, chrome, bevel=0.5)                   # the cap's chrome rim
    bpy.ops.mesh.primitive_uv_sphere_add(radius=2.4, location=(0, 0, 21.2), segments=32, ring_count=16)
    bpy.context.object.data.materials.append(chrome)           # centre screw
    finish(sc, math.pi / 2, 'tour_bumper')
    normals(sc, 'tour_bumper')


def fin(angle, mat):
    """A swept fin in the (radial, z) plane at `angle`, 1.6 thick."""
    prof = [(6.5, 2.0), (16.0, -1.0), (16.0, 6.0), (6.5, 24.0)]
    bm = bmesh.new()
    t = 0.8
    ca, sa = math.cos(angle), math.sin(angle)
    def P(r, z, s):  # s = tangent offset
        return (r * ca - s * sa, r * sa + s * ca, z)
    front = [bm.verts.new(P(r, z, t)) for r, z in prof]
    back = [bm.verts.new(P(r, z, -t)) for r, z in prof]
    bm.faces.new(front); bm.faces.new(list(reversed(back)))
    n = len(prof)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([front[i], back[i], back[j], front[j]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('fin'); bm.to_mesh(me); bm.free(); me.materials.append(mat)
    o = bpy.data.objects.new('fin', me); bpy.context.scene.collection.objects.link(o)
    b = o.modifiers.new('b', 'BEVEL'); b.width = 0.4; b.segments = 2
    return o


ROCKET_SCALE = 1.5


def rocket():
    sc = reset(); lights(sc)
    white = principled('white', (0.92, 0.93, 0.95), rough=0.25, coat=0.7)
    red = principled('red', (0.80, 0.08, 0.05), rough=0.2, coat=0.9)
    black = principled('black', (0.04, 0.04, 0.05), rough=0.35, coat=0.5)
    dark = principled('dark', (0.22, 0.23, 0.26), metal=0.9, rough=0.35)
    glass = principled('glass', (0.10, 0.35, 0.75), rough=0.05, coat=1.0)
    chrome = principled('chrome', (0.86, 0.87, 0.90), metal=1.0, rough=0.28)
    # engine bell
    bpy.ops.mesh.primitive_cone_add(radius1=5.0, radius2=3.2, depth=5, location=(0, 0, 2.5), vertices=48)
    bpy.context.object.data.materials.append(dark)
    cyl(7.0, 5.0, 60.0, white, bevel=0.4)
    cyl(7.15, 38.0, 44.0, black)                               # roll band
    cyl(7.25, 5.0, 7.0, chrome)                                # base band
    # nose: half an ellipsoid
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=(0, 0, 60), segments=64, ring_count=32)
    nose = bpy.context.object; nose.scale = (7, 7, 24); nose.data.materials.append(red)
    bpy.context.view_layer.objects.active = nose
    bpy.ops.object.transform_apply(scale=True)
    bm = bmesh.new(); bm.from_mesh(nose.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < 59.9], context='VERTS')
    bm.to_mesh(nose.data); bm.free()
    # porthole on the front (−y, toward the player)
    bpy.ops.mesh.primitive_cylinder_add(radius=2.6, depth=1.2, location=(0, -6.9, 50), rotation=(math.pi / 2, 0, 0), vertices=32)
    bpy.context.object.data.materials.append(chrome)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=2.0, location=(0, -7.1, 50), segments=32, ring_count=16)
    g = bpy.context.object; g.scale = (1, 0.45, 1); g.data.materials.append(glass)
    for k in range(4):
        fin(math.pi / 4 + k * math.pi / 2, red)
    # v7b (Aaron: "Make the rocket bigger"): the whole toy 1.5× about its foot
    for o in sc.objects:
        if o.type == 'MESH' and o.visible_camera:
            o.matrix_world = mathutils.Matrix.Scale(ROCKET_SCALE, 4) @ o.matrix_world
    finish(sc, math.pi / 2, 'tour_rocket')
    normals(sc, 'tour_rocket')


ONLY = argv[2] if len(argv) > 2 else ''
for n, fn in [('tour_bumper', bumper), ('tour_rocket', rocket)]:
    if not ONLY or ONLY in n:
        fn()
