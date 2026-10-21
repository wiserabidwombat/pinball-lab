"""Table 05 (The Lamplight) M9 v19: the nine cozy pieces as little furniture sprites. Tonight's three stand on the slate
hearth in the closed left pocket (no ball reaches it), one above each cozy lamp. Rendered in the table's oblique view
(y += z * OBLIQUE) and light, with a shadow-catcher floor so each casts its shadow on the slate.
Image box = LmpTableLayout.cozyArtBox (x -32.5…32.5, y -22.5…57.5 around the piece's floor centre) → lmp_cozy_<piece>.png
(piece = LmpCozy's rawValue: shopBell, teapot, readingLamp, ladder, clock, rockingChair, windowSeat, catBed, armchair).
Usage: python3 lmp_bake_cozy.py -- out_dir [samples] [piece,piece…]"""
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
ONLY = argv[2].split(',') if len(argv) > 2 else None
SCALE = 1.25                                   # models are built at 1.0 and scaled up after (v19: fill the pocket)
BX0, BY0, BW, BH = -32.5, -22.5, 65.0, 80.0
K = L.OBLIQUE
PIECES = ['shopBell', 'teapot', 'readingLamp', 'ladder', 'clock', 'rockingChair', 'windowSeat', 'catBed', 'armchair']


def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
    sc.render.resolution_x = int(BW * L.PX_PER_PT); sc.render.resolution_y = int(BH * L.PX_PER_PT)
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
    return sc


MATS = {}


def mat(name, color, metal=0.0, rough=0.45, coat=0.0, emit=None, strength=0.0, sheen=0.0):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1); b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough; b.inputs['Coat Weight'].default_value = coat
    b.inputs['Sheen Weight'].default_value = sheen
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = strength
    MATS[name] = m
    return m


def materials():
    MATS.clear()
    return dict(
        walnut=mat('walnut', (0.20, 0.10, 0.05), rough=0.35, coat=0.5),
        oak=mat('oak', (0.62, 0.40, 0.20), rough=0.4, coat=0.4),
        brass=mat('brass', (0.90, 0.68, 0.33), metal=1.0, rough=0.22),
        cream=mat('cream', (0.93, 0.89, 0.80), rough=0.25, coat=0.6),
        teal=mat('teal', (0.08, 0.40, 0.42), rough=0.2, coat=0.7),
        green=mat('velvet_green', (0.07, 0.26, 0.17), rough=0.7, sheen=0.8),
        oxblood=mat('velvet_red', (0.45, 0.07, 0.06), rough=0.7, sheen=0.8),
        mustard=mat('mustard', (0.72, 0.50, 0.12), rough=0.7, sheen=0.5),
        wicker=mat('wicker', (0.66, 0.48, 0.24), rough=0.8),
        dark=mat('dark', (0.03, 0.025, 0.02), rough=0.6),
        face=mat('clockface', (0.95, 0.92, 0.82), rough=0.3, coat=0.3),
        shade=mat('shade', (0.62, 0.30, 0.10), rough=0.6, emit=(1.0, 0.62, 0.28), strength=0.45),
        glow=mat('bulb', (1.0, 0.85, 0.6), emit=(1.0, 0.82, 0.55), strength=3.0),
        plaid=mat('plaid', (0.50, 0.12, 0.10), rough=0.8, sheen=0.5),
    )


def smooth(o):
    for p in o.data.polygons: p.use_smooth = True


def box(x0, x1, y0, y1, z0, z1, m, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    o = bpy.context.object; o.scale = (x1 - x0, y1 - y0, z1 - z0); o.data.materials.append(m)
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        bv = o.modifiers.new('b', 'BEVEL'); bv.width = bevel; bv.segments = 3
    return o


def cyl(x, y, z0, z1, r, m, verts=32, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=z1 - z0, location=(x, y, (z0 + z1) / 2))
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=z1 - z0, location=(x, y, (z0 + z1) / 2))
    o = bpy.context.object; o.data.materials.append(m); smooth(o)
    return o


def sphere(x, y, z, r, m, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, z), segments=32, ring_count=16)
    o = bpy.context.object; o.scale = scale; o.data.materials.append(m); smooth(o)
    return o


def torus(x, y, z, R, r, m, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(location=(x, y, z), major_radius=R, minor_radius=r, rotation=rot,
                                     major_segments=48, minor_segments=12)
    o = bpy.context.object; o.scale = scale; o.data.materials.append(m); smooth(o)
    return o


def tube(pts, r, m):
    cu = bpy.data.curves.new('t', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = r; cu.bevel_resolution = 3
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts): sp.points[i].co = (*p, 1)
    cu.materials.append(m)
    o = bpy.data.objects.new('t', cu); bpy.context.scene.collection.objects.link(o)
    return o


def arc(cx, cz, R, a0, a1, y, n=16):
    return [(cx + R * math.cos(a0 + (a1 - a0) * i / n), y, cz + R * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


# ------------------------------------------------------------------ the pieces (floor centre at 0,0; front = -y)
def shopBell(M):
    # a little round walnut side table with a brass counter bell on it
    cyl(0, 2, 0, 1.5, 8, M['walnut'])
    cyl(0, 2, 1.5, 16, 1.6, M['walnut'], r2=1.2)
    cyl(0, 2, 16, 18, 13, M['walnut']); torus(0, 2, 18, 13, 0.6, M['brass'])
    cyl(0, 0, 18, 19.2, 6.5, M['dark'])
    sphere(0, 0, 19.2, 6.0, M['brass'], scale=(1, 1, 0.85))
    cyl(0, 0, 24.0, 26.5, 0.9, M['brass']); sphere(0, 0, 26.8, 1.6, M['brass'])
    box(-3, 3, -9.5, -6.5, 18, 18.6, M['cream'])                   # a little card propped by it


def teapot(M):
    # a big cream-and-teal teapot on an iron trivet
    cyl(0, 0, 0, 1.4, 12, M['dark'], verts=6)
    body = sphere(0, 0, 13, 11.5, M['teal'], scale=(1.15, 1.0, 0.95))
    torus(0, 0, 13, 13.0, 1.0, M['cream'], scale=(1.0, 0.88, 1))  # a cream band
    torus(0, 0, 22.5, 6.0, 0.8, M['brass'])
    cyl(0, 0, 22.5, 24.5, 6.0, M['cream']); sphere(0, 0, 25.5, 2.0, M['brass'])
    tube([(11, 0, 9), (16, 0, 13), (19.5, 0, 19)], 1.9, M['teal'])           # spout to the right
    tube([(-11.5, 0, 18), (-17.5, 0, 17), (-18, 0, 11), (-12, 0, 8)], 1.5, M['cream'])   # handle on the left


def readingLamp(M):
    # a brass floor lamp with a warm glowing shade and a pool of light under it (emission only lights; the shadow
    # catcher keeps the pool as darkness elsewhere)
    cyl(0, 2, 0, 1.6, 8, M['brass'])
    cyl(0, 2, 1.6, 33, 0.9, M['brass'])
    sphere(0, 2, 30, 2.2, M['glow'])
    cyl(0, 2, 27, 37, 11, M['shade'], verts=48, r2=6.5)
    torus(0, 2, 27, 11, 0.5, M['brass']); torus(0, 2, 37, 6.5, 0.4, M['brass'])
    pt = bpy.data.lights.new('bulb', 'POINT'); pt.energy = 2500; pt.shadow_soft_size = 3; pt.color = (1.0, 0.75, 0.45)
    po = bpy.data.objects.new('bulb', pt); po.location = (0, 2, 26); bpy.context.scene.collection.objects.link(po)


def ladder(M):
    # library steps: three oak treads on walnut sides with a brass handrail
    for x in (-11, 11):
        bm = bmesh.new()
        prof = [(-9, 0), (9, 0), (9, 30), (3, 30), (3, 20), (-3, 20), (-3, 10), (-9, 10)]   # (y, z) stair profile
        vs = [bm.verts.new((x - 1.2, y, z)) for y, z in prof]
        f = bm.faces.new(vs)
        ext = bmesh.ops.extrude_face_region(bm, geom=[f])
        for v in [e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)]: v.co.x += 2.4
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new('side'); bm.to_mesh(me); bm.free(); me.materials.append(M['walnut'])
        bpy.context.scene.collection.objects.link(bpy.data.objects.new('side', me))
    for (y0, y1, z) in ((-10, -2, 10), (-4, 4, 20), (2, 10, 30)):
        box(-10.5, 10.5, y0, y1, z - 1.6, z, M['oak'], bevel=0.4)
        box(-10.5, 10.5, y0 - 0.3, y0 + 0.5, z - 0.4, z + 0.2, M['brass'])        # brass nosing
    for x in (-12.5, 12.5):
        tube([(x, -9, 12), (x, -9, 26), (x, 9, 44), (x, 9, 31)], 0.7, M['brass'])


def clock(M):
    # a walnut grandfather clock: plinth, trunk with a pendulum window, hood with a cream face and a brass bezel
    box(-10, 10, -6, 6, 0, 6, M['walnut'], bevel=0.6)
    box(-8, 8, -5, 5, 6, 30, M['walnut'], bevel=0.5)
    box(-4, 4, -5.4, -4.9, 12, 26, M['dark'])                                       # the pendulum window
    sphere(0, -5.6, 15, 2.2, M['brass'], scale=(1, 0.3, 1)); box(-0.3, 0.3, -5.7, -5.5, 15, 25, M['brass'])
    box(-10, 10, -6.5, 6.5, 30, 44, M['walnut'], bevel=0.6)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=6.2, depth=0.6, location=(0, -6.8, 37), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.object; o.data.materials.append(M['face'])
    torus(0, -7.0, 37, 6.4, 0.6, M['brass'], rot=(math.pi / 2, 0, 0))
    for a, ln in ((math.radians(60), 3.6), (math.radians(150), 4.8)):                 # the hands
        tube([(0, -7.3, 37), (ln * math.cos(a), -7.3, 37 + ln * math.sin(a))], 0.35, M['dark'])
    box(-11, 11, -7.5, 7.5, 44, 47, M['walnut'], bevel=0.8)                           # the bonnet
    for x in (-6, 0, 6): sphere(x, -1, 48.5, 1.4, M['brass'])                        # finials


def rockingChair(M):
    # an oak rocking chair with spindle back, a red cushion and curved rockers
    for x in (-10, 10):
        tube([(x, -16, 3.0), (x, -8, 0.6), (x, 0, 0.0), (x, 8, 0.6), (x, 16, 3.0)], 1.0, M['oak'])
        for y in (-8, 8): cyl(x, y, 0.6, 14, 1.0, M['oak'])
        cyl(x, 8, 14, 34, 0.9, M['oak'])
        tube([(x, -9, 14), (x, -9, 21), (x, 8, 21)], 0.8, M['oak'])                     # arm rests
    box(-11, 11, -9, 9, 13, 15, M['oak'], bevel=0.5)
    box(-9.5, 9.5, -8, 7.5, 15, 17, M['oxblood'], bevel=1.2)
    for z in (22, 33): box(-11, 11, 7.2, 9, z, z + 2.2, M['oak'], bevel=0.4)
    for x in (-6, -2, 2, 6): cyl(x, 8.1, 16, 33, 0.6, M['oak'])


def windowSeat(M):
    # a cushioned bench with two pillows (the shop's window seat, in miniature)
    box(-20, 20, -8, 8, 0, 10, M['walnut'], bevel=0.8)
    box(-18.5, 18.5, -7, 7, 10, 13.5, M['green'], bevel=1.4)
    box(-20, 20, 6, 9, 10, 22, M['walnut'], bevel=0.6)                                 # low back
    for x, m in ((-11, M['oxblood']), (11, M['mustard'])):
        o = box(x - 5, x + 5, 0, 5, 13.5, 21, m, bevel=2.0)
        o.rotation_euler = (math.radians(-12), 0, math.radians(8 if x < 0 else -8))
    for x in (-17, 17): box(x - 1, x + 1, -8.2, -7.6, 1, 9, M['brass'])


def catBed(M):
    # a round wicker basket with a plaid cushion
    cyl(0, 0, 0, 2, 15, M['wicker'], verts=48)
    torus(0, 0, 6, 14.5, 3.6, M['wicker'], scale=(1, 0.85, 1.2))
    sphere(0, 0, 3.4, 12.5, M['plaid'], scale=(1, 0.82, 0.22))
    torus(0, 0, 9.6, 14.5, 1.0, M['wicker'], scale=(1, 0.85, 1))
    sphere(-4, 3, 4.8, 3.5, M['cream'], scale=(1, 1, 0.6))                            # a little toy mouse
    sphere(-6.5, 2.6, 4.9, 1.0, M['oxblood'])


def armchair(M):
    # a deep green velvet wingback with walnut feet and a brass-studded front
    for x in (-13, 13):
        for y in (-9, 8): cyl(x, y, 0, 3, 1.3, M['walnut'], r2=0.9)
    box(-15, 15, -11, 10, 3, 13, M['green'], bevel=1.8)
    box(-11, 11, -10, 6, 13, 16.5, M['green'], bevel=2.2)                              # seat cushion
    box(-15, 15, 6, 11, 13, 38, M['green'], bevel=2.5)                                 # back
    for x in (-13, 13):
        box(x - 2.5, x + 2.5, -11, 8, 13, 22, M['green'], bevel=2.0)                   # arms
        box(x - 2.5, x + 2.5, 3, 10, 22, 34, M['green'], bevel=2.0)                    # wings
    for i in range(9):
        sphere(-13 + i * 3.25, -11.2, 4.6, 0.55, M['brass'])
    o = box(-6, 6, -2, 3, 16.5, 24, M['oxblood'], bevel=2.0)                           # a cushion
    o.rotation_euler = (math.radians(-18), 0, 0)


BUILD = dict(shopBell=shopBell, teapot=teapot, readingLamp=readingLamp, ladder=ladder, clock=clock,
             rockingChair=rockingChair, windowSeat=windowSeat, catBed=catBed, armchair=armchair)


def finish(sc):
    # convert, flatten transforms, lean (y += z K)
    bpy.ops.object.select_all(action='DESELECT')
    objs = [o for o in sc.objects if o.type in ('MESH', 'CURVE')]
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target='MESH')
    for o in sc.objects:
        if o.type != 'MESH': continue
        mw = o.matrix_world.copy(); o.data.transform(mw); o.matrix_world.identity()
        for v in o.data.vertices:
            v.co *= SCALE
            v.co.y += v.co.z * K
    for o in sc.objects:
        if o.type == 'LIGHT' and o.data.type == 'POINT': o.location *= SCALE
    bpy.ops.mesh.primitive_plane_add(size=300, location=(0, 0, 0))
    bpy.context.object.is_shadow_catcher = True
    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.0; sun.angle = math.radians(12); sun.color = (1.0, 0.86, 0.66)
    so = bpy.data.objects.new('key', sun); so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.6; fill.angle = math.radians(30); fill.color = (0.75, 0.8, 1.0)
    fo = bpy.data.objects.new('fill', fill); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
    sc.collection.objects.link(fo)
    for i, (x, y) in enumerate(((-200, 100), (200, 150), (0, -250))):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x, y, 300))
        p = bpy.context.object; p.scale = (300, 300, 1)
        em = bpy.data.materials.new(f'box{i}'); em.use_nodes = True
        nodes = em.node_tree.nodes; nodes.clear()
        o_ = nodes.new('ShaderNodeOutputMaterial'); e_ = nodes.new('ShaderNodeEmission')
        e_.inputs['Strength'].default_value = 1.0; e_.inputs['Color'].default_value = (1.0, 0.85, 0.62, 1)
        em.node_tree.links.new(e_.outputs[0], o_.inputs[0])
        p.data.materials.append(em); p.visible_camera = False; p.visible_shadow = False
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.16, 0.11, 0.07, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.7
    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(BW, BH); cam.clip_end = 3000
    co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co)
    co.location = (BX0 + BW / 2, BY0 + BH / 2, 1000); sc.camera = co


os.makedirs(OUT, exist_ok=True)
for name in PIECES:
    if ONLY and name not in ONLY: continue
    sc = setup()
    M = materials()
    BUILD[name](M)
    finish(sc)
    sc.render.filepath = os.path.join(OUT, f'lmp_cozy_{name}.png')
    bpy.ops.render.render(write_still=True)
    print('rendered', sc.render.filepath)
