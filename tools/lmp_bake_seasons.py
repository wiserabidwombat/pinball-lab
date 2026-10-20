"""Table 05 (The Lamplight) M9 v25: the seasonal touches, small sprites over the baked table so it isn't baked four times.
lmp_season_mantel_<season>: a decoration draped along the fireplace's gabled mantel (Blender, the table's oblique view and
light): spring a blossom vine and a jar of tulips, summer paper bunting and a sunflower pot, autumn a leaf garland and
two pumpkins, winter a pine garland with berries and a candle lantern. Box LmpTableLayout.seasonMantelArtBox
(x -70…70, y -12…44 round the mantel's left foot centre (284, 850)).
lmp_season_window_<season>: the loft window's light pool recoloured for the season (pycairo, drawn in the loft
platform's floor plane and clipped to it): spring soft pink with falling petals, summer warm gold with dust motes,
autumn amber with falling leaves, winter cool white with snowflakes and a drift along the wall. World rect
LmpTableLayout.seasonWindowRect (55, 1070, 140 × 120); the game lifts it by loftLift like the loft.
Usage: python3 lmp_bake_seasons.py -- out_dir [samples]"""
import bpy, bmesh, math, sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
K = L.OBLIQUE
SEASONS = ['spring', 'summer', 'autumn', 'winter']
MX0, MY0, MW, MH = -70.0, -12.0, 140.0, 56.0
TOP = 23.4                                            # the mantel's top (lmp_bake_table: wall_strip z 18 → 23)
GABLE = [(-60.0, 0.0), (0.0, 22.0), (60.0, 0.0)]      # alcove_wall()[1:4] round (284, 850)


def gable(t):
    """Point along the gable at t in 0…1 (left foot → peak → right foot)."""
    if t <= 0.5:
        u = t / 0.5; a, b = GABLE[0], GABLE[1]
    else:
        u = (t - 0.5) / 0.5; a, b = GABLE[1], GABLE[2]
    return (a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u)


def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
    sc.render.resolution_x = int(MW * L.PX_PER_PT); sc.render.resolution_y = int(MH * L.PX_PER_PT)
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
    return sc


def mat(name, color, metal=0.0, rough=0.5, emit=None, strength=0.0, sheen=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1); b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough; b.inputs['Sheen Weight'].default_value = sheen
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = strength
    return m


def sphere(x, y, z, r, m, scale=(1, 1, 1), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, z), segments=16, ring_count=8, rotation=rot)
    o = bpy.context.object; o.scale = scale; o.data.materials.append(m)
    for p in o.data.polygons: p.use_smooth = True
    return o


def cyl(x, y, z0, z1, r, m, r2=None, verts=20):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=z1 - z0, location=(x, y, (z0 + z1) / 2))
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=z1 - z0, location=(x, y, (z0 + z1) / 2))
    o = bpy.context.object; o.data.materials.append(m)
    for p in o.data.polygons: p.use_smooth = True
    return o


def tube(pts, r, m):
    cu = bpy.data.curves.new('t', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = r; cu.bevel_resolution = 3
    cu.use_fill_caps = True
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts): sp.points[i].co = (*p, 1)
    cu.materials.append(m)
    bpy.context.scene.collection.objects.link(bpy.data.objects.new('t', cu))


def along(n, y=-2.0, z=TOP + 1.0, t0=0.04, t1=0.96, sag=0.0):
    pts = []
    for i in range(n + 1):
        t = t0 + (t1 - t0) * i / n
        x, yy = gable(t)
        s = sag * math.sin(math.pi * ((t * 2) % 1.0))        # sag between the feet and the peak
        pts.append((x, yy + y, z - s))
    return pts


def spring(rnd):
    green = mat('leaf', (0.18, 0.42, 0.14), rough=0.6)
    pinks = [mat('p1', (0.98, 0.70, 0.80), rough=0.5), mat('p2', (1.0, 0.90, 0.94), rough=0.5),
             mat('p3', (0.92, 0.48, 0.64), rough=0.5)]
    tube(along(40, y=-3), 1.0, green)
    for (x, y, z) in along(24, y=-3):
        for _ in range(3):
            sphere(x + rnd.uniform(-2.5, 2.5), y + rnd.uniform(-2.5, 2.0), z + rnd.uniform(0.5, 2.5),
                   rnd.uniform(1.8, 2.5), rnd.choice(pinks))
        sphere(x, y - 2, z + 0.5, 1.6, green, scale=(1.7, 0.7, 0.4), rot=(0, 0, rnd.uniform(-0.6, 0.6)))
    glass = mat('glass', (0.70, 0.86, 0.82), rough=0.1)
    gx, gy = gable(0.86); gy -= 2
    cyl(gx, gy, TOP, TOP + 10, 5.0, glass)
    for i, c in enumerate([(0.85, 0.12, 0.12), (1.0, 0.82, 0.15), (0.95, 0.45, 0.6)]):
        a = -0.6 + i * 0.6
        tx, tz = gx + 4.0 * math.sin(a), TOP + 19
        tube([(gx, gy, TOP + 8), (tx, gy, tz)], 0.6, green)
        sphere(tx, gy, tz + 2.2, 2.6, mat(f'tulip{i}', c, rough=0.4), scale=(1, 1, 1.5))


def summer(rnd):
    string = mat('string', (0.90, 0.85, 0.74), rough=0.8)
    flags = [mat('f1', (0.98, 0.80, 0.20), rough=0.6), mat('f2', (0.10, 0.55, 0.55), rough=0.6),
             mat('f3', (0.95, 0.45, 0.35), rough=0.6), mat('f4', (0.97, 0.96, 0.92), rough=0.6)]
    pts = along(40, y=-8.5, z=TOP + 4, sag=3.0)
    tube(pts, 0.5, string)
    for i, p in enumerate(pts[1:-1:3]):
        bm = bmesh.new()
        v = [bm.verts.new((p[0] - 3.6, p[1], p[2])), bm.verts.new((p[0] + 3.6, p[1], p[2])),
             bm.verts.new((p[0], p[1] - 0.4, p[2] - 9.0))]
        bm.faces.new(v)
        me = bpy.data.meshes.new('flag'); bm.to_mesh(me); bm.free(); me.materials.append(flags[i % 4])
        bpy.context.scene.collection.objects.link(bpy.data.objects.new('flag', me))
    pot = mat('pot', (0.70, 0.36, 0.20), rough=0.7)
    stem = mat('stem', (0.22, 0.45, 0.15), rough=0.6)
    petal = mat('petal', (1.0, 0.78, 0.10), rough=0.5)
    centre = mat('centre', (0.30, 0.16, 0.06), rough=0.8)
    gx, gy = gable(0.86); gy -= 1
    cyl(gx, gy, TOP, TOP + 8, 5.4, pot, r2=4.2)
    for i, (dx, h) in enumerate(((-4.0, 19), (4.0, 16), (0.4, 23))):
        fx, fz = gx + dx, TOP + h
        tube([(gx, gy, TOP + 7), (fx, gy, fz)], 0.6, stem)
        sphere(fx, gy - 1.0, fz + 1.8, 4.4, petal, scale=(1, 0.35, 1))
        sphere(fx, gy - 2.1, fz + 1.8, 1.9, centre, scale=(1, 0.4, 1))


def autumn(rnd):
    twig = mat('twig', (0.30, 0.18, 0.09), rough=0.8)
    leaves = [mat('l1', (0.90, 0.38, 0.08), rough=0.6), mat('l2', (0.75, 0.15, 0.08), rough=0.6),
              mat('l3', (0.90, 0.65, 0.15), rough=0.6), mat('l4', (0.60, 0.32, 0.10), rough=0.6)]
    tube(along(40, y=-3), 0.9, twig)
    for (x, y, z) in along(26, y=-3):
        for _ in range(3):
            sphere(x + rnd.uniform(-3, 3), y + rnd.uniform(-3, 2), z + rnd.uniform(0, 2.0), 3.0, rnd.choice(leaves),
                   scale=(1.4, 0.8, 0.25), rot=(rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), rnd.uniform(0, 3.1)))
    orange = mat('pumpkin', (0.92, 0.45, 0.08), rough=0.45)
    green = mat('stalk', (0.30, 0.35, 0.12), rough=0.7)
    for t, r in ((0.83, 6.5), (0.94, 4.4)):
        px, py = gable(t); py -= 2.5
        for k in range(6):                                          # ribs: six squashed lobes round the middle
            a = k * math.pi / 3
            sphere(px + math.cos(a) * r * 0.35, py + math.sin(a) * r * 0.35, TOP + r * 0.75, r * 0.72, orange,
                   scale=(1, 1, 0.85))
        cyl(px, py, TOP + r * 1.35, TOP + r * 1.35 + 2.4, 0.8, green)


def winter(rnd):
    pine = mat('pine', (0.08, 0.28, 0.15), rough=0.8, sheen=0.6)
    berry = mat('berry', (0.85, 0.06, 0.06), rough=0.3)
    pts = along(40, y=-3)
    tube(pts, 3.4, pine)
    for (x, y, z) in pts:                                          # needles: little sprigs sticking out
        for _ in range(4):
            a = rnd.uniform(0, 2 * math.pi)
            tube([(x, y, z), (x + math.cos(a) * 5.0, y + math.sin(a) * 3.8, z + rnd.uniform(-1, 2.2))], 0.7, pine)
    for (x, y, z) in along(16, y=-3):
        for _ in range(3):
            sphere(x + rnd.uniform(-2.5, 2.5), y + rnd.uniform(-4.5, -1.5), z + rnd.uniform(1.5, 3.5), 1.3, berry)
    brass = mat('brass', (0.90, 0.68, 0.33), metal=1.0, rough=0.25)
    glassl = mat('glow', (1.0, 0.85, 0.6), emit=(1.0, 0.70, 0.35), strength=3.0)
    gx, gy = gable(0.88); gy -= 2.5
    for dx in (-3.8, 3.8):
        for dy in (-3.8, 3.8):
            cyl(gx + dx, gy + dy, TOP, TOP + 13, 0.5, brass)
    cyl(gx, gy, TOP, TOP + 1.2, 5.0, brass, verts=4)
    cyl(gx, gy, TOP + 13, TOP + 17.5, 5.0, brass, r2=0.8, verts=4)
    cyl(gx, gy, TOP + 1.2, TOP + 8, 1.6, mat('candle', (0.95, 0.92, 0.82), rough=0.4))
    sphere(gx, gy, TOP + 9.4, 1.3, glassl, scale=(1, 1, 1.6))
    pt = bpy.data.lights.new('candle', 'POINT'); pt.energy = 250; pt.shadow_soft_size = 1; pt.color = (1.0, 0.7, 0.4)
    po = bpy.data.objects.new('candle', pt); po.location = (gx, gy - 4, TOP + 10); bpy.context.scene.collection.objects.link(po)


def finish(sc):
    for o in sc.objects:
        if o.type in ('MESH', 'CURVE'): o.select_set(True)
    bpy.context.view_layer.objects.active = next(o for o in sc.objects if o.type in ('MESH', 'CURVE'))
    bpy.ops.object.convert(target='MESH')
    for o in sc.objects:
        if o.type != 'MESH': continue
        mw = o.matrix_world.copy(); o.data.transform(mw); o.matrix_world.identity()
        for v in o.data.vertices: v.co.y += v.co.z * K
    for o in sc.objects:
        if o.type == 'LIGHT': o.location.y += o.location.z * K
    # the mantel top as a shadow catcher, so the decoration grounds on it
    bm = bmesh.new()
    for (a, b) in zip(GABLE, GABLE[1:]):
        dx, dy = b[0] - a[0], b[1] - a[1]; ln = math.hypot(dx, dy)
        nx, ny = -dy / ln * 7.5, dx / ln * 7.5
        q = [(a[0] + nx, a[1] + ny), (b[0] + nx, b[1] + ny), (b[0] - nx, b[1] - ny), (a[0] - nx, a[1] - ny)]
        bm.faces.new([bm.verts.new((x, y + TOP * K, TOP)) for x, y in q])
    me = bpy.data.meshes.new('mantelTop'); bm.to_mesh(me); bm.free()
    mt = bpy.data.objects.new('mantelTop', me); sc.collection.objects.link(mt); mt.is_shadow_catcher = True
    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.0; sun.angle = math.radians(12); sun.color = (1.0, 0.86, 0.66)
    so = bpy.data.objects.new('key', sun); so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.6; fill.angle = math.radians(30); fill.color = (0.75, 0.8, 1.0)
    fo = bpy.data.objects.new('fill', fill); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
    sc.collection.objects.link(fo)
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.16, 0.11, 0.07, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.8
    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(MW, MH); cam.clip_end = 3000
    co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co)
    co.location = (MX0 + MW / 2, MY0 + MH / 2, 1000); sc.camera = co


# ------------------------------------------------------------------ the window light (pycairo)
def window(season):
    import cairo
    WX0, WY0, WW, WH = 55.0, 1070.0, 140.0, 120.0
    S = L.PX_PER_PT
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, int(WW * S), int(WH * S))
    cr = cairo.Context(surf)
    cr.translate(-WX0 * S, (WY0 + WH) * S); cr.scale(S, -S)
    rnd = random.Random(7 + SEASONS.index(season))
    area = L.loft_platform()
    cr.move_to(*area[0])
    for p in area[1:]: cr.line_to(*p)
    cr.close_path(); cr.clip()
    wall, inward = (0.37, 0.93), (0.93, -0.37)                  # as lmp_floor_upper.py's pool
    cx_, cy_ = L.WINDOW_SEAT_CENTER
    ox, oy = cx_ + wall[0] * 34 - inward[0] * 22, cy_ + wall[1] * 34 - inward[1] * 22
    cr.translate(ox, oy); cr.rotate(math.atan2(wall[1], wall[0]))

    def pool(grow):
        cr.move_to(-26 - grow, 0); cr.line_to(26 + grow, 0); cr.line_to(34 + grow, -58 - grow); cr.line_to(-14 - grow, -58 - grow)
        cr.close_path()
    tint = {'spring': (1.0, 0.82, 0.88), 'summer': (1.0, 0.86, 0.50), 'autumn': (1.0, 0.66, 0.32),
            'winter': (0.88, 0.94, 1.0)}[season]
    for grow, a in ((7, 0.08), (3, 0.12), (0, 0.22)):
        pool(grow); cr.set_source_rgba(*tint, a); cr.fill()

    def inside():
        while True:
            x, y = rnd.uniform(-22, 32), rnd.uniform(-56, -3)
            if x > -26 + (-y / 58) * 12 and x < 26 + (-y / 58) * 8:
                return x, y
    if season == 'spring':                                      # petals drifting down the light
        for _ in range(16):
            x, y = inside()
            cr.save(); cr.translate(x, y); cr.rotate(rnd.uniform(0, 3.1)); cr.scale(1.0, 0.55)
            cr.arc(0, 0, rnd.uniform(1.4, 2.0), 0, 2 * math.pi); cr.restore()
            cr.set_source_rgba(1.0, rnd.uniform(0.70, 0.85), rnd.uniform(0.80, 0.88), 0.85); cr.fill()
    elif season == 'summer':                                    # dust motes in the evening sun
        for _ in range(22):
            x, y = inside()
            cr.arc(x, y, rnd.uniform(0.3, 0.6), 0, 2 * math.pi)
            cr.set_source_rgba(1.0, 0.95, 0.75, rnd.uniform(0.5, 0.9)); cr.fill()
    elif season == 'autumn':                                    # leaves blown in
        for _ in range(10):
            x, y = inside()
            cr.save(); cr.translate(x, y); cr.rotate(rnd.uniform(0, 3.1))
            cr.move_to(-2.0, 0); cr.curve_to(-1, 1.4, 1, 1.4, 2.0, 0); cr.curve_to(1, -1.4, -1, -1.4, -2.0, 0)
            cr.restore()
            cr.set_source_rgba(*rnd.choice([(0.85, 0.35, 0.08), (0.72, 0.15, 0.08), (0.85, 0.62, 0.15)]), 0.9); cr.fill()
    else:                                                       # snow falling and a drift along the wall
        for _ in range(28):
            x, y = inside()
            cr.arc(x, y, rnd.uniform(0.35, 0.8), 0, 2 * math.pi)
            cr.set_source_rgba(1, 1, 1, rnd.uniform(0.6, 0.95)); cr.fill()
        cr.move_to(-30, 0)
        for i in range(13):
            cr.line_to(-30 + i * 5, -2.5 - 1.5 * math.sin(i * 1.3) - rnd.uniform(0, 1))
        cr.line_to(34, 0); cr.close_path()
        cr.set_source_rgba(0.96, 0.98, 1.0, 0.85); cr.fill()
    path = os.path.join(OUT, f'lmp_season_window_{season}.png')
    surf.write_to_png(path)
    print('painted', path)


os.makedirs(OUT, exist_ok=True)
for s in SEASONS:
    window(s)
for s in SEASONS:
    sc = setup()
    globals()[s](random.Random(11 + SEASONS.index(s)))
    finish(sc)
    sc.render.filepath = os.path.join(OUT, f'lmp_season_mantel_{s}.png')
    bpy.ops.render.render(write_still=True)
    print('rendered', sc.render.filepath)
