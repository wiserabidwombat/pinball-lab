"""Table 06 (Orbit: Grand Tour) M6 v4: renders the UPPER table in Blender (Cycles) into one image, the lower bake's twin
(same materials, lights and oblique shear). Geometry is the game's own: build/tour_walls.txt, printed by the DEBUG launch
flag -tourDumpWalls (every addWall polyline + the plunge hook). Over UPPER_RECT (−40, 640, 680, 700).
Usage: python3 tour_bake_upper.py -- floor_upper.png walls.txt out.png [scale] [samples]

The lower bake's notes follow.
The plan's look — realistic space, a dark navy cabinet, chrome: the floor painting (tour_floor_lower.py) under a clear
coat; a navy metal-flake cabinet with chrome side rails; navy side walls with chrome caps; chrome wire lane guides;
chrome posts with white rubber rings; the slingshots' white rubber bands under smoky-blue clear plastics with chrome
screws; the R-O-C bank as a gunmetal hull block (riveted panels, chrome cap) with its three standups; the Mars bunker in
rust-red rock with its sample drops and the rover hole; chrome wire rollovers in the O-R-B-T lanes; the rocket post's
chrome socket. Cool white key light from the upper left, a blue fill, white soft boxes for the chrome.
Oblique view (Tables 03-05): every vertex at height z moves y += z * OBLIQUE before an orthographic top-down render.
1 Blender unit = 1 world point. The standups and drops are stand-ins here; in the game they are part sprites.
Usage: python3 tour_bake_lower.py -- floor.png out.png [scale] [samples]"""
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tour_look_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
FLOOR, WALLS, OUT = (os.path.abspath(a) for a in argv[:3])
SCALE = float(argv[3]) if len(argv) > 3 else 1.0
SAMPLES = int(argv[4]) if len(argv) > 4 else 64
# M6 v3: `game` as the 5th argument bakes the game art: no stand-in standups / drops (the game draws and drops them).
PREVIEW_PARTS = not (len(argv) > 4 and argv[4] == 'game')
X0, Y0, RW, RH = (-40, 640, 680, 700)          # UPPER_RECT
K = L.OBLIQUE

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.render.resolution_x = int(RW * L.PX_PER_PT * SCALE)
sc.render.resolution_y = int(RH * L.PX_PER_PT * SCALE)
sc.render.film_transparent = False
sc.view_settings.view_transform = 'Standard'
sc.view_settings.look = 'None'


# ------------------------------------------------------------------ materials
def principled(name, color, metal=0.0, rough=0.4, coat=0.0, alpha=1.0, trans=0.0, image=None, spec=0.5,
               coat_rough=0.03, emit=None, emit_strength=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    b.inputs['Coat Weight'].default_value = coat
    b.inputs['Coat Roughness'].default_value = coat_rough
    b.inputs['Alpha'].default_value = alpha
    b.inputs['Transmission Weight'].default_value = trans
    b.inputs['Specular IOR Level'].default_value = spec
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1)
        b.inputs['Emission Strength'].default_value = emit_strength
    if image:
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(image)
        tex.interpolation = 'Cubic'
        nt.links.new(tex.outputs['Color'], b.inputs['Base Color'])
    return m


def flake(name, base, rough=0.32):
    """Metal-flake paint: a dark metallic base with fine noise in the roughness and a clear coat."""
    m = principled(name, base, metal=0.25, rough=rough, coat=0.12, coat_rough=0.3, spec=0.15)
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    nz = nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 900; nz.inputs['Detail'].default_value = 1
    mr = nt.nodes.new('ShaderNodeMapRange')
    mr.inputs['To Min'].default_value = rough * 0.6; mr.inputs['To Max'].default_value = rough * 1.4
    nt.links.new(nz.outputs['Fac'], mr.inputs['Value']); nt.links.new(mr.outputs['Result'], b.inputs['Roughness'])
    return m


def rock(name, a, b_, scale=0.25):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    nz = nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = scale; nz.inputs['Detail'].default_value = 8
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (*a, 1); ramp.color_ramp.elements[1].color = (*b_, 1)
    nt.links.new(nz.outputs['Fac'], ramp.inputs['Fac']); nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    bump = nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.6
    nt.links.new(nz.outputs['Fac'], bump.inputs['Height']); nt.links.new(bump.outputs['Normal'], b.inputs['Normal'])
    b.inputs['Roughness'].default_value = 0.85
    return m


M_FLOOR = principled('floor', (1, 1, 1), rough=0.35, coat=0.35, coat_rough=0.05, spec=0.25, image=FLOOR)
M_CHROME = principled('chrome', (0.92, 0.93, 0.95), metal=1.0, rough=0.08)
M_CHROME_SOFT = principled('chromesoft', (0.80, 0.82, 0.86), metal=1.0, rough=0.22)
M_RUBBER = principled('rubber', (0.94, 0.94, 0.92), rough=0.55, spec=0.3)          # white rubbers
M_NAVY = flake('navy', (0.005, 0.009, 0.03), rough=0.45)
M_NAVY_SIDE = flake('navyside', (0.006, 0.01, 0.028), rough=0.5)
M_PLASTIC = principled('plastic', (0.18, 0.42, 0.95), rough=0.03, coat=0.4, coat_rough=0.04, alpha=0.35, trans=0.6)
M_HULL = principled('hull', (0.035, 0.04, 0.055), metal=0.2, rough=0.7, spec=0.12)
M_HULL_DARK = principled('hulldark', (0.16, 0.17, 0.20), metal=0.8, rough=0.45)
M_MARS = rock('mars', (0.16, 0.05, 0.025), (0.42, 0.17, 0.08), scale=0.18)
M_BLACK = principled('black', (0.01, 0.01, 0.015), rough=0.6)
M_STANDUP = principled('standup', (0.10, 0.36, 0.85), rough=0.25, coat=0.5)
M_DROP = principled('drop', (0.80, 0.82, 0.86), rough=0.3, coat=0.4)
M_STEEL = principled('steel', (0.72, 0.72, 0.74), metal=1.0, rough=0.3)


# ------------------------------------------------------------------ geometry helpers (Tables 03-05)
SMOOTH = set()


def link(obj):
    sc.collection.objects.link(obj)
    return obj


def planar_uv(me):
    uv = me.uv_layers.new(name='UV')
    for poly in me.polygons:
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = ((v.x - X0) / RW, (v.y - Y0) / RH)


def prism(name, pts, z0, z1, mat, uv=False):
    bm = bmesh.new()
    bottom = [bm.verts.new((x, y, z0)) for x, y in pts]
    face = bm.faces.new(bottom)
    if face.normal.z < 0: face.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z = z1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    if uv: planar_uv(me)
    me.materials.append(mat)
    return link(bpy.data.objects.new(name, me))


def tube(name, pts, z, r, mat, closed=False):
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = r; cu.bevel_resolution = 3; cu.use_fill_caps = True
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        x, y = p[0], p[1]; zz = p[2] if len(p) > 2 else z
        sp.points[i].co = (x, y, zz, 1)
    sp.use_cyclic_u = closed
    cu.materials.append(mat)
    SMOOTH.add(name)
    return link(bpy.data.objects.new(name, cu))


def cylinder(name, x, y, r, z0, z1, mat, verts=32):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=z1 - z0, location=(x, y, (z0 + z1) / 2), vertices=verts)
    o = bpy.context.object; o.name = name; o.data.materials.append(mat); SMOOTH.add(o.name)
    bev = o.modifiers.new('b', 'BEVEL'); bev.width = min(r * 0.25, 1.2); bev.segments = 3
    return o


def torus(name, x, y, z, major, minor, mat):
    bpy.ops.mesh.primitive_torus_add(location=(x, y, z), major_radius=major, minor_radius=minor,
                                     major_segments=40, minor_segments=12)
    o = bpy.context.object; o.name = name; o.data.materials.append(mat); SMOOTH.add(o.name)
    return o


def wall_strip(name, pts, thick, z1, mat):
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        dx, dy = b[0] - a[0], b[1] - a[1]; ln = math.hypot(dx, dy)
        if ln < 0.01: continue
        nx, ny = -dy / ln * thick / 2, dx / ln * thick / 2
        quad = [(a[0] + nx, a[1] + ny), (b[0] + nx, b[1] + ny), (b[0] - nx, b[1] - ny), (a[0] - nx, a[1] - ny)]
        prism(f'{name}{i}', quad, 0, z1, mat)


def post(name, x, y, ring_r, h=20):
    """Chrome post with a domed cap and a white rubber ring whose outer edge is ring_r."""
    cylinder(name, x, y, 3.2, 0, h, M_CHROME)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=4.4, location=(x, y, h), segments=24, ring_count=12)
    cap = bpy.context.object; cap.scale = (1, 1, 0.55); cap.data.materials.append(M_CHROME); SMOOTH.add(cap.name)
    torus(name + 'ring', x, y, 7, ring_r - 2.0, 2.0, M_RUBBER)


def offset_loop(pts, d):
    n = len(pts); out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        def nrm(a, b):
            dx, dy = b[0] - a[0], b[1] - a[1]; ln = math.hypot(dx, dy)
            return (dy / ln, -dx / ln)
        n1, n2 = nrm(p0, p1), nrm(p1, p2)
        bx, by = n1[0] + n2[0], n1[1] + n2[1]; bl = math.hypot(bx, by)
        bx, by = bx / bl, by / bl
        cosh = bx * n1[0] + by * n1[1]
        out.append((p1[0] + bx * d / cosh, p1[1] + by * d / cosh))
    return out


def ccw(pts):
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))
    return pts if area > 0 else list(reversed(pts))


# ------------------------------------------------------------------ the game's walls (build/tour_walls.txt)
WALL_LINES, HOOK = [], []
for line in open(WALLS):
    kind, *rest = line.split()
    pts = [tuple(map(float, p.split(','))) for p in rest[-1].split(';')]
    if kind == 'TOURHOOK': HOOK = pts
    else: WALL_LINES.append(pts)


def find(pred):
    return [w for w in WALL_LINES if pred(w)]


def clip_y(pts, y_min):
    return [p for p in pts if p[1] >= y_min]


TOP = Y0 + RH + 60
ARCH_Y, TOP_Y = 1000, 1270
prism('floor', [(X0, Y0 - 60), (X0 + RW, Y0 - 60), (X0 + RW, TOP), (X0, TOP)], -2, 0, M_FLOOR, uv=True)

# the outer wall: the arch, from the left wall at y 1000 over the top to the right wall
outer = max(WALL_LINES, key=len)
arch = [p for p in outer if p[1] >= ARCH_Y - 0.01 and 19 < p[0] < 581]
arch = sorted(arch, key=lambda p: math.atan2(p[1] - ARCH_Y, -(p[0] - 300)))      # left → over the top → right
# cabinet: navy metal-flake side boards with chrome rails (continuing the lower bake), and the board beyond the arch
CAB_H = 34
prism('cabL', [(X0, Y0 - 60), (12, Y0 - 60), (12, TOP), (X0, TOP)], 0, CAB_H, M_NAVY)
prism('cabR', [(588, Y0 - 60), (X0 + RW, Y0 - 60), (X0 + RW, TOP), (588, TOP)], 0, CAB_H, M_NAVY)
tube('railL', [(10, Y0 - 60), (10, TOP)], CAB_H + 1.5, 3.2, M_CHROME)
tube('railR', [(590, Y0 - 60), (590, TOP)], CAB_H + 1.5, 3.2, M_CHROME)
prism('sideL', [(12, Y0 - 60), (20, Y0 - 60), (20, ARCH_Y), (12, ARCH_Y)], 0, 18, M_NAVY_SIDE)
prism('sideR', [(580, Y0 - 60), (588, Y0 - 60), (588, ARCH_Y), (580, ARCH_Y)], 0, 18, M_NAVY_SIDE)
tube('sideLtop', [(16, Y0 - 60), (16, ARCH_Y)], 18.5, 2.0, M_CHROME_SOFT)
tube('sideRtop', [(584, Y0 - 60), (584, ARCH_Y)], 18.5, 2.0, M_CHROME_SOFT)
beyond = [(12, ARCH_Y)] + arch + [(588, ARCH_Y), (588, TOP), (12, TOP)]
prism('archBoard', ccw(beyond), 0, 18, M_NAVY_SIDE)
tube('archTop', [(16, ARCH_Y)] + arch + [(584, ARCH_Y)], 18.5, 2.0, M_CHROME_SOFT)

# the shooter lane wall (x 548) up to y 955, as in the lower bake
lane = [p for p in outer if abs(p[0] - 548) < 0.5 and p[1] >= Y0 - 60]
lane = sorted(lane, key=lambda p: p[1])
wall_strip('lanewall', [(x + 2, y) for x, y in lane], 4, 16, M_NAVY_SIDE)
tube('lanewallTop', [(x + 2, y) for x, y in lane], 16.5, 2.0, M_CHROME_SOFT)
cylinder('laneCap', 550, lane[-1][1], 3.0, 0, 17, M_CHROME)

# the orbit lanes' inner walls: navy walls with a chrome top rail and a chrome post at the funnel tip
for name, w in (('orbitL', find(lambda w: w[0] == (85.05, 871.73))[0]), ('orbitR', find(lambda w: w[0] == (477.2, 688.85))[0])):
    w = clip_y(w, Y0 - 60)
    wall_strip(name, w, 4, 16, M_NAVY_SIDE)
    tube(name + 'Top', w, 16.5, 2.0, M_CHROME_SOFT)
    post(name + 'Tip', w[0][0], w[0][1], 6.5, h=18)
    cylinder(name + 'End', w[-1][0], w[-1][1], 3.0, 0, 17, M_CHROME)

# the S-T-A-R lane guides: chrome wire rails between rubber-ringed posts
for i, w in enumerate(find(lambda w: len(w) == 2 and w[0][1] == 1150.0 and w[1][1] == 1200.0)):
    tube(f'star{i}', w, 9, 2.0, M_CHROME); tube(f'star{i}low', w, 3, 1.5, M_CHROME)
    post(f'starPost{i}', w[0][0], w[0][1], 5.5, h=16)
    cylinder(f'starTop{i}', w[1][0], w[1][1], 3.0, 0, 12, M_CHROME)

# the plunge hook: a chrome wire guide hanging off the arch
tube('hook', HOOK, 9, 2.0, M_CHROME); tube('hookLow', HOOK, 3, 1.5, M_CHROME)
cylinder('hookEnd', HOOK[-1][0], HOOK[-1][1], 3.0, 0, 12, M_CHROME)

# the launch pad's chevron and the K-E-T backboard: gunmetal hull with chrome caps and rivets (the R-O-C bank's look)
for name, w in (('pad', find(lambda w: w[0] == (235.8, 892.0))[0]), ('ket', find(lambda w: w[0] == (345.9, 979.1))[0])):
    wall_strip(name, w, 6, 16, M_HULL)
    tube(name + 'Cap', w, 16.4, 1.6, M_CHROME_SOFT)
    for a, b in zip(w, w[1:]):
        n = max(2, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 12))
        for k in range(n):
            t = (k + 0.5) / n
            cylinder(f'{name}rivet{a[0]:.0f}{k}', a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, 0.9, 15.8, 16.6,
                     M_CHROME_SOFT, verts=12)

# ------------------------------------------------------------------ oblique shear: y += z * K
bpy.ops.object.select_all(action='DESELECT')
for o in list(sc.objects):
    if o.type in ('CURVE', 'MESH'):
        o.select_set(True)
bpy.context.view_layer.objects.active = next(o for o in sc.objects if o.type == 'MESH')
bpy.ops.object.convert(target='MESH')
for o in sc.objects:
    if o.type != 'MESH': continue
    mw = o.matrix_world.copy()
    o.data.transform(mw); o.matrix_world.identity()
    for v in o.data.vertices:
        v.co.y += v.co.z * K
for o in sc.objects:
    if o.type == 'MESH' and o.name in SMOOTH:
        for p in o.data.polygons: p.use_smooth = True

# ------------------------------------------------------------------ light: cool starlight
sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.2; sun.angle = math.radians(10)
sun.color = (0.96, 0.97, 1.0)
so = link(bpy.data.objects.new('key', sun))
so.rotation_euler = (math.radians(-38), math.radians(-28), 0)          # from the top left, falling down-right
fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.6; fill.angle = math.radians(30)
fill.color = (0.55, 0.68, 1.0)                                          # a blue fill from the right
fo = link(bpy.data.objects.new('fill', fill)); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
for i, (x, y, w, h, e, col) in enumerate([(-200, 900, 500, 900, 2.6, (0.92, 0.95, 1.0)),
                                           (800, 300, 300, 600, 1.0, (0.75, 0.85, 1.0)),
                                           (284, -400, 900, 200, 1.0, (1.0, 0.95, 0.9))]):
    bpy.ops.mesh.primitive_plane_add(size=1, location=(x, y, 700))
    p = bpy.context.object; p.scale = (w, h, 1)
    em = bpy.data.materials.new(f'box{i}'); em.use_nodes = True
    nodes = em.node_tree.nodes; nodes.clear()
    o_ = nodes.new('ShaderNodeOutputMaterial'); e_ = nodes.new('ShaderNodeEmission')
    e_.inputs['Strength'].default_value = e; e_.inputs['Color'].default_value = (*col, 1)
    em.node_tree.links.new(e_.outputs[0], o_.inputs[0])
    p.data.materials.append(em); p.visible_camera = False; p.visible_shadow = False
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.02, 0.03, 0.07, 1)
w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6

cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(RW, RH)
cam.clip_end = 5000
co = link(bpy.data.objects.new('cam', cam))
co.location = (X0 + RW / 2, Y0 + RH / 2, 1500); co.rotation_euler = (0, 0, 0)
sc.camera = co

sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print('rendered', OUT, sc.render.resolution_x, sc.render.resolution_y)
