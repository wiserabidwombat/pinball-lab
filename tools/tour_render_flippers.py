"""Table 06 (Orbit: Grand Tour) M6 v5: the flippers as rendered sprites (from tools/mon_render_flippers.py): glossy white
bodies with red rubber rings and a chrome pivot cap, in the baked table's light (navy reflections). Rendered straight down
(they rotate in the game). Also a normal map per flipper (tour_flipper_*_n.png: every material swapped for an emission of
the surface normal, n/2 + 1/2, the camera looking straight down), so SKLightNodes light them (TourLighting).
Image box: x −18…114, y −18…18 around the pivot (mirrored for the right flipper), 6 px/pt — what TourFlipper expects.
Usage: python3 tour_render_flippers.py -- out_dir [samples]"""
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



# ------------------------------------------------------------------ flippers
FLIP_LEN, FLIP_R0, FLIP_R1 = 96, 12, 6                # TourTableLayout.flipperLength / PivotRadius / TipRadius
FLIP_BOX = (-18, -18, 114, 18)
FLIP_PX = 6


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


for side, direction in (('left', 1), ('right', -1)):
    sc = reset(); lights(sc)
    white = principled('white', (0.93, 0.93, 0.95), rough=0.22, coat=0.7)
    rubber = principled('rubber', (0.78, 0.09, 0.07), rough=0.42, spec=0.3)
    chrome = principled('chrome', (0.88, 0.89, 0.92), metal=1.0, rough=0.32)    # brushed: polished read as a black hole
    dark = principled('dark', (0.30, 0.31, 0.35), metal=0.8, rough=0.3)
    inner = capsule_outline(FLIP_LEN, FLIP_R0 - 2.6, FLIP_R1 - 2.4, direction=direction)
    prism('body', inner, 0, 10, white, bevel=1.2)
    tube_loop('rubber', capsule_outline(FLIP_LEN, FLIP_R0 - 1.6, FLIP_R1 - 1.6, direction=direction), 5, 1.8, rubber)
    bpy.ops.mesh.primitive_cylinder_add(radius=5.0, depth=2.4, location=(0, 0, 11), vertices=48)
    cap = bpy.context.object; cap.data.materials.append(chrome)
    b = cap.modifiers.new('b', 'BEVEL'); b.width = 0.9; b.segments = 3
    bpy.ops.mesh.primitive_cylinder_add(radius=1.7, depth=1.0, location=(0, 0, 12.6), vertices=24)
    bpy.context.object.data.materials.append(dark)
    for o in sc.objects:
        if o.type == 'MESH':
            for p in o.data.polygons: p.use_smooth = True
    x0, y0, x1, y1 = FLIP_BOX
    if direction < 0: x0, x1 = -x1, -x0
    camera(sc, x0, y0, x1, y1, FLIP_PX)
    render(sc, f'tour_flipper_{side}.png')
    # the normal map: same scene, every surface an emission of its normal, no lights needed, no denoise
    sc.view_layers[0].material_override = normal_material()
    sc.cycles.samples = 16; sc.cycles.use_denoising = False
    sc.view_settings.view_transform = 'Raw'          # linear: a flat face must read (128, 128, 255), not sRGB-curved
    render(sc, f'tour_flipper_{side}_n.png')
