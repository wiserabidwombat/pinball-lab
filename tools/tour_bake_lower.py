"""Table 06 (Orbit: Grand Tour) M5 v1 (look development): renders the lower table in Blender (Cycles) into one image.
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
FLOOR, OUT = (os.path.abspath(a) for a in argv[:2])
SCALE = float(argv[2]) if len(argv) > 2 else 1.0
SAMPLES = int(argv[3]) if len(argv) > 3 else 64
# M6 v3: `game` as the 5th argument bakes the game art: no stand-in standups / drops (the game draws and drops them).
PREVIEW_PARTS = not (len(argv) > 4 and argv[4] == 'game')
X0, Y0, RW, RH = L.LOWER_RECT
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


# ------------------------------------------------------------------ the table
TOP = Y0 + RH + 60
prism('floor', [(X0, Y0), (X0 + RW, Y0), (X0 + RW, TOP), (X0, TOP)], -2, 0, M_FLOOR, uv=True)

# apron plates (3 pt high) with a chrome lip along each slope
left_apron = [(12, L.APRON_TOP_Y + 3), (L.LEFT_X, L.APRON_TOP_Y), (L.DRAIN_X, L.DRAIN_Y), (L.DRAIN_X, Y0), (12, Y0)]
right_apron = [(L.LANE_X, L.APRON_TOP_Y), (L.MIRROR - L.DRAIN_X, L.DRAIN_Y), (L.MIRROR - L.DRAIN_X, Y0),
               (588, Y0), (588, L.LANE_FLOOR_Y), (L.LANE_X, L.LANE_FLOOR_Y)]
prism('apronL', ccw(left_apron), 0, 3, M_FLOOR, uv=True)
prism('apronR', ccw(right_apron), 0, 3, M_FLOOR, uv=True)
tube('lipL', L.left_apron()[::-1], 4.5, 2.2, M_CHROME)
tube('lipR', L.right_apron(), 4.5, 2.2, M_CHROME)

# cabinet: navy metal-flake side boards and front board with a chrome rail on each inner edge
CAB_H = 34
prism('cabL', [(X0, Y0), (12, Y0), (12, TOP), (X0, TOP)], 0, CAB_H, M_NAVY)
prism('cabR', [(588, Y0), (X0 + RW, Y0), (X0 + RW, TOP), (588, TOP)], 0, CAB_H, M_NAVY)
prism('cabFront', [(X0, Y0 - 40), (X0 + RW, Y0 - 40), (X0 + RW, Y0 - 12), (X0, Y0 - 12)], 0, CAB_H, M_NAVY)
tube('railL', [(10, Y0 - 12), (10, TOP)], CAB_H + 1.5, 3.2, M_CHROME)
tube('railR', [(590, Y0 - 12), (590, TOP)], CAB_H + 1.5, 3.2, M_CHROME)

# playfield side walls between floor and cabinet: navy with a chrome top
prism('sideL', [(12, L.APRON_TOP_Y), (L.LEFT_X, L.APRON_TOP_Y), (L.LEFT_X, TOP), (12, TOP)], 0, 18, M_NAVY_SIDE)
prism('sideR', [(L.RIGHT_X, L.LANE_FLOOR_Y), (588, L.LANE_FLOOR_Y), (588, TOP), (L.RIGHT_X, TOP)], 0, 18, M_NAVY_SIDE)
tube('sideLtop', [(16, L.APRON_TOP_Y), (16, TOP)], 18.5, 2.0, M_CHROME_SOFT)
tube('sideRtop', [(584, L.LANE_FLOOR_Y), (584, TOP)], 18.5, 2.0, M_CHROME_SOFT)

# shooter-lane wall: navy with a chrome top rail; the plunger stop
lane = L.lane_wall()
wall_strip('lanewall', [(x + 2, y) for x, y in lane], 4, 16, M_NAVY_SIDE)
tube('lanewallTop', [(x + 2, y) for x, y in lane], 16.5, 2.0, M_CHROME_SOFT)
prism('laneStop', [(L.LANE_X + 2, L.LANE_FLOOR_Y - 6), (L.RIGHT_X, L.LANE_FLOOR_Y - 6),
                   (L.RIGHT_X, L.LANE_FLOOR_Y), (L.LANE_X + 2, L.LANE_FLOOR_Y)], 0, 10, M_STEEL)

# chrome wire lane guides and outlane walls, both sides, with the outlane post rails
for name, guide in (('guideL', L.left_lane_guide()), ('guideR', L.right_lane_guide()),
                    ('outlaneL', L.left_outlane_wall()), ('outlaneR', L.right_outlane_wall()),
                    ('postRailL', L.left_outlane_post_rail()), ('postRailR', L.right_outlane_post_rail())):
    tube(name, guide, 9, 2.0, M_CHROME)
    tube(name + 'low', guide, 3, 1.5, M_CHROME)
for side, (gx, gy) in (('L', (L.LANE_GUIDE_X, L.LANE_GUIDE_TOP)), ('R', L.mirrored((L.LANE_GUIDE_X, L.LANE_GUIDE_TOP)))):
    post('guideTop' + side, gx, gy, 6.5, h=18)
for side, p in (('L', (L.LANE_GUIDE_X, L.OUTLANE_WALL_BOTTOM)), ('R', L.mirrored((L.LANE_GUIDE_X, L.OUTLANE_WALL_BOTTOM)))):
    cylinder('outlanePost' + side, *p, 3.0, 0, 12, M_CHROME)
ex, ey = L.left_guide_end()
cylinder('guideEndL', ex, ey, 3.0, 0, 12, M_CHROME)
cylinder('guideEndR', *L.mirrored((ex, ey)), 3.0, 0, 12, M_CHROME)

# wire rollovers in the O-R-B-T lanes: a bent chrome wire just proud of the floor
for i, x in enumerate(L.LANE_XS):
    y = L.LANE_ROLLOVER_Y
    tube(f'rollover{i}', [(x, y - 9, 0.5), (x, y - 6, 2.4), (x, y + 6, 2.4), (x, y + 9, 0.5)], 0, 0.8, M_CHROME)
    prism(f'rollslot{i}', [(x - 1.6, y - 10), (x + 1.6, y - 10), (x + 1.6, y + 10), (x - 1.6, y + 10)], 0, 0.2, M_BLACK)

# slingshots: rubber-ringed posts, the white band, a smoky-blue clear plastic held by chrome screws
for side, s in (('L', L.SLING_L), ('R', L.sling_right())):
    top, corner, tip = s['top'], s['corner'], s['tip']
    post('slingTop' + side, *top, L.SLING_TOP_POST_R)
    post('slingTip' + side, *tip, L.SLING_TIP_POST_R)
    post('slingCorner' + side, *corner, L.SLING_CORNER_POST_R)
    tri = ccw([top, corner, tip])
    tube('band' + side, offset_loop(tri, 3.5), 7, 2.4, M_RUBBER, closed=True)
    prism('plastic' + side, offset_loop(tri, 5), 21, 23, M_PLASTIC)
    tube('plasticRim' + side, offset_loop(tri, 4.2), 23.2, 0.9, M_CHROME, closed=True)
    for i, (px, py) in enumerate((top, tip, corner)):
        cylinder(f'screw{side}{i}', px, py, 2.6, 23, 24.8, M_CHROME)

# the rocket post's socket: a chrome ring flush with the floor round a dark hole
cylinder('postSocket', *L.ROCKET_POST, L.ROCKET_POST_R + 2.5, -0.5, 0.6, M_CHROME_SOFT)
cylinder('postHole', *L.ROCKET_POST, L.ROCKET_POST_R + 0.5, -0.4, 0.7, M_BLACK)

# R-O-C: a gunmetal hull block (the '/', backboard and roof outline) with riveted panel seams and a chrome cap
roc = ccw([(20, 530), (86.3, 672.3), (20, 714.3)])
prism('rocHull', roc, 0, 16, M_HULL)
tube('rocCap', [(20, 530), (50, 594.3), (86.3, 672.3), (20, 714.3)], 16.4, 1.6, M_CHROME_SOFT)
for k in range(9):                          # rivets along the '/'
    t = (k + 0.5) / 9; x = 20 + (86.3 - 20) * t; y = 530 + (672.3 - 530) * t
    nx, ny = -0.906, 0.423
    cylinder(f'rivet{k}', x + nx * 5, y + ny * 5, 0.9, 15.8, 16.6, M_CHROME_SOFT, verts=12)
if PREVIEW_PARTS:                            # the R-O-C standups (stand-ins for the look preview; the game draws its own)
    for i, c in enumerate(L.ROCKET_CENTERS):
        prism(f'roc{i}', ccw(L.plate(c, L.ROCKET_NORMAL, L.STANDUP)), 0, 14, M_STANDUP)

# the Mars bunker: rust-red rock walls (the roof and the floor V) with chrome caps, the sample drops, the rover hole
for name, pts in (('bunkerRoof', L.BUNKER_ROOF), ('bunkerFloor', L.BUNKER_FLOOR)):
    wall_strip(name, pts, 6, 14, M_MARS)
    tube(name + 'Cap', pts, 14.5, 1.5, M_CHROME_SOFT)
prism('roofBack', ccw([(489.9, 585.7), (516, 606), (548, 623.3), (548, 640), (500, 640)]), 0, 14, M_MARS)
if PREVIEW_PARTS:                            # the sample drops (stand-ins; in the game they drop, so never baked)
    for i, c in enumerate(L.SAMPLE_CENTERS):
        prism(f'sample{i}', ccw(L.plate(c, L.SAMPLE_NORMAL, L.DROP)), 0, 12, M_DROP)
cylinder('roverRim', *L.ROVER_SCOOP, L.SCOOP_R + 2.5, -0.5, 0.8, M_CHROME_SOFT)
cylinder('roverHole', *L.ROVER_SCOOP, L.SCOOP_R, -0.4, 0.9, M_BLACK)

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
