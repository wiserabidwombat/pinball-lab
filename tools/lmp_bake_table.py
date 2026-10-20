"""Table 05 (The Lamplight) M9 round 2: renders the WHOLE fixed table in Blender (Cycles) into one image, which
lmp_split_table.py cuts into lmp_lower.png / lmp_upper.png for the game (z -19, over the grey-box floor and walls).
Round 1 (look development) was the lower table alone (lmp_bake_lower.py); this adds the upper table: the arch and
side walls in walnut with brass caps, walnut orbit rails, the brick fireplace surround with a walnut mantel, the
kettle lane's walls, the loft's rails, fascia and drain chute, the right orbit's deflector and the ramp's mouth post.
Floor painting (lmp_floor_lower.py) + raised apron plates + walnut cabinet with brass rails, brass wire lane guides,
brass posts with cream rubber rings, the slingshot rubbers under amber glass plastics, a slate hearth wall, the
centre post and the plunger lane, lit warm like a lamp-lit shop at night.
Oblique view (Tables 03-04): every vertex at height z moves y += z * OBLIQUE before an orthographic top-down render,
so the floor lines up exactly with the physics and raised parts show their front. 1 Blender unit = 1 world point.
Usage: python3 lmp_bake_table.py -- floor.png out.png [scale] [samples]"""
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
FLOOR, OUT = (os.path.abspath(a) for a in argv[:2])
SCALE = float(argv[2]) if len(argv) > 2 else 1.0
SAMPLES = int(argv[3]) if len(argv) > 3 else 64
X0, Y0, RW, RH = L.ART_RECT
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


def wood(name, dark, light, scale=0.22, direction='Y'):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    wave = nt.nodes.new('ShaderNodeTexWave')
    wave.wave_type = 'BANDS'; wave.bands_direction = direction
    wave.inputs['Scale'].default_value = scale
    wave.inputs['Distortion'].default_value = 9
    wave.inputs['Detail'].default_value = 3
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*light, 1)
    nt.links.new(wave.outputs['Fac'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.45
    b.inputs['Coat Weight'].default_value = 0.35
    b.inputs['Coat Roughness'].default_value = 0.2
    return m


M_FLOOR = principled('floor', (1, 1, 1), rough=0.62, coat=0.08, coat_rough=0.5, spec=0.2, image=FLOOR)
M_BRASS = principled('brass', (0.88, 0.66, 0.32), metal=1.0, rough=0.24)
M_BRASS_DARK = principled('brassdark', (0.62, 0.44, 0.20), metal=1.0, rough=0.35)
M_RUBBER = principled('rubber', (0.92, 0.88, 0.78), rough=0.55, spec=0.3)        # cream rubbers
M_WALNUT = wood('walnut', (0.03, 0.013, 0.006), (0.20, 0.10, 0.045), scale=0.6)
M_WALNUT_SIDE = wood('walnutside', (0.05, 0.024, 0.012), (0.16, 0.08, 0.035), scale=0.35)
M_AMBER = principled('amber', (0.95, 0.58, 0.18), rough=0.05, coat=0.6, coat_rough=0.05, alpha=0.55, trans=0.8)
M_WALNUT_CAP = wood('walnutcap', (0.06, 0.025, 0.01), (0.26, 0.11, 0.045), scale=0.5, direction='X')
_cb = M_WALNUT_CAP.node_tree.nodes['Principled BSDF']
_cb.inputs['Roughness'].default_value = 0.7; _cb.inputs['Coat Weight'].default_value = 0.06
_cb.inputs['Specular IOR Level'].default_value = 0.15
_cb.inputs['Coat Roughness'].default_value = 0.4
M_GREEN = principled('greenlacquer', (0.05, 0.16, 0.11), rough=0.25, coat=0.8, coat_rough=0.05)
M_BRICK = principled('brick', (0.42, 0.17, 0.10), rough=0.8)
M_SLATE = principled('slate', (0.13, 0.13, 0.15), rough=0.7)
M_STEEL = principled('steel', (0.72, 0.72, 0.74), metal=1.0, rough=0.3)
M_BLACK = principled('black', (0.015, 0.012, 0.01), rough=0.6)


# ------------------------------------------------------------------ geometry helpers (Tables 03-04)
SMOOTH = set()          # round parts (tubes, posts, rings) get smooth shading; flat prisms stay faceted


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
    for i, (x, y) in enumerate(pts):
        sp.points[i].co = (x, y, z, 1)
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


def wall_strip(name, pts, thick, z1, mat, z0=0):
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        dx, dy = b[0] - a[0], b[1] - a[1]; ln = math.hypot(dx, dy)
        if ln < 0.01: continue
        nx, ny = -dy / ln * thick / 2, dx / ln * thick / 2
        quad = [(a[0] + nx, a[1] + ny), (b[0] + nx, b[1] + ny), (b[0] - nx, b[1] - ny), (a[0] - nx, a[1] - ny)]
        prism(f'{name}{i}', quad, z0, z1, mat)


def post(name, x, y, ring_r, h=20):
    """Brass post with a domed cap and a cream rubber ring whose outer edge is ring_r."""
    cylinder(name, x, y, 3.2, 0, h, M_BRASS)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=4.4, location=(x, y, h), segments=24, ring_count=12)
    cap = bpy.context.object; cap.scale = (1, 1, 0.55); cap.data.materials.append(M_BRASS); SMOOTH.add(cap.name)
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

# apron plates (3 pt high) with a brass lip along each slope
left_apron = [(12, L.APRON_TOP_Y + 3), (L.LEFT_X, L.APRON_TOP_Y), (L.DRAIN_X, L.DRAIN_Y), (L.DRAIN_X, Y0), (12, Y0)]
right_apron = [(L.LANE_X, L.APRON_TOP_Y), (L.MIRROR - L.DRAIN_X, L.DRAIN_Y), (L.MIRROR - L.DRAIN_X, Y0),
               (588, Y0), (588, L.LANE_FLOOR_Y), (L.LANE_X, L.LANE_FLOOR_Y)]
prism('apronL', ccw(left_apron), 0, 3, M_FLOOR, uv=True)
prism('apronR', ccw(right_apron), 0, 3, M_FLOOR, uv=True)
tube('lipL', [(L.LEFT_X, L.APRON_TOP_Y), (L.DRAIN_X, L.DRAIN_Y), (L.DRAIN_X, L.DRAIN_LIP_Y)], 4.5, 2.2, M_BRASS)
tube('lipR', L.right_apron(), 4.5, 2.2, M_BRASS)

# cabinet: walnut side boards and front board with a brass rail on each inner edge
CAB_H = 34
prism('cabL', [(X0, Y0), (12, Y0), (12, TOP), (X0, TOP)], 0, CAB_H, M_WALNUT)
prism('cabR', [(588, Y0), (X0 + RW, Y0), (X0 + RW, TOP), (588, TOP)], 0, CAB_H, M_WALNUT)
prism('cabFront', [(X0, Y0 - 40), (X0 + RW, Y0 - 40), (X0 + RW, Y0 - 12), (X0, Y0 - 12)], 0, CAB_H, M_WALNUT)
tube('railL', [(10, Y0 - 12), (10, TOP)], CAB_H + 1.5, 3.2, M_BRASS)
tube('railR', [(590, Y0 - 12), (590, TOP)], CAB_H + 1.5, 3.2, M_BRASS)

# playfield side walls between floor and cabinet: dark walnut with a brass top
prism('sideL', [(12, L.APRON_TOP_Y), (L.LEFT_X, L.APRON_TOP_Y), (L.LEFT_X, TOP), (12, TOP)], 0, 18, M_WALNUT_SIDE)
prism('sideR', [(L.RIGHT_X, L.LANE_FLOOR_Y), (588, L.LANE_FLOOR_Y), (588, TOP), (L.RIGHT_X, TOP)], 0, 18, M_WALNUT_SIDE)
tube('sideLtop', [(16, L.APRON_TOP_Y), (16, TOP)], 18.5, 2.0, M_BRASS_DARK)
tube('sideRtop', [(584, L.LANE_FLOOR_Y), (584, TOP)], 18.5, 2.0, M_BRASS_DARK)

# shooter-lane wall (with its bulge) as a walnut wall with a brass top rail; the plunger stop
lane = [p for p in L.lane_wall() if p[1] <= TOP]
wall_strip('lanewall', [(x + 2, y) for x, y in lane], 4, 16, M_WALNUT_SIDE)
tube('lanewallTop', [(x + 2, y) for x, y in lane], 16.5, 2.0, M_BRASS_DARK)
prism('laneStop', [(L.LANE_X + 2, L.LANE_FLOOR_Y - 6), (L.RIGHT_X, L.LANE_FLOOR_Y - 6),
                   (L.RIGHT_X, L.LANE_FLOOR_Y), (L.LANE_X + 2, L.LANE_FLOOR_Y)], 0, 10, M_STEEL)

# the left deflector + closed pocket: a low slate hearth wall with a brass cap along the inlane wall
hearth = L.left_inlane_wall()
wall_strip('hearthWall', hearth, 6, 12, M_SLATE)
tube('hearthCap', hearth, 12.5, 2.2, M_BRASS)

# brass wire lane guides: the right inlane/outlane separator and the right outlane wall
for name, guide in (('guideR', L.right_lane_guide()), ('outlaneR', L.right_outlane_wall())):
    tube(name, guide, 9, 2.0, M_BRASS)
    tube(name + 'low', guide, 3, 1.5, M_BRASS)
post('guideTopL', L.LANE_GUIDE_X, L.LANE_GUIDE_TOP, 6.5, h=18)
gx, gy = L.mirrored((L.LANE_GUIDE_X, L.LANE_GUIDE_TOP))
post('guideTopR', gx, gy, 6.5, h=18)
ox, oy = L.mirrored((L.LANE_GUIDE_X, L.OUTLANE_WALL_BOTTOM))
cylinder('outlanePostR', ox, oy, 3.0, 0, 12, M_BRASS)
ex, ey = L.left_guide_end()
cylinder('guideEndL', ex, ey, 3.0, 0, 12, M_BRASS)
rx, ry = L.mirrored((ex, ey))
cylinder('guideEndR', rx, ry, 3.0, 0, 12, M_BRASS)

# centre post with its rubber
post('centrePost', *L.CENTER_POST, L.CENTER_POST_R, h=18)

# slingshots: rubber-ringed posts, the band, an amber glass plastic held by brass screws
for side, s in (('L', L.SLING_L), ('R', L.sling_right())):
    top, corner, tip = s['top'], s['corner'], s['tip']
    post('slingTop' + side, *top, L.SLING_TOP_POST_R)
    post('slingTip' + side, *tip, L.SLING_TIP_POST_R)
    post('slingCorner' + side, *corner, L.SLING_CORNER_POST_R)
    tri = ccw([top, corner, tip])
    tube('band' + side, offset_loop(tri, 3.5), 7, 3.0, M_RUBBER, closed=True)
    # M9 v16 (Aaron: the slingshots blend in; walnut on oak measured 1.45 : 1): green lacquer caps like the aprons,
    # inset so the cream rubber band shows all round them, with a brass rim and a gold pinstripe.
    prism('plastic' + side, offset_loop(tri, -1.5), 20, 23, M_GREEN)
    tube('plasticRim' + side, offset_loop(tri, -2.2), 23.2, 0.9, M_BRASS, closed=True)
    tube('plasticStripe' + side, offset_loop(tri, -6.0), 23.1, 0.45, M_BRASS, closed=True)
    for i, (px, py) in enumerate((top, tip, corner)):
        cylinder(f'screw{side}{i}', px, py, 2.6, 23, 24.8, M_BRASS)

# ------------------------------------------------------------------ M9 round 2: the upper table
# the arch: walnut fill between the outer wall and the cabinet corners, with a brass cap along the wall
arch = L.arch()
prism('archFill', ccw(arch + [(588, L.ARCH_START_Y), (588, TOP), (12, TOP), (12, L.ARCH_START_Y)]), 0, 18, M_WALNUT_SIDE)
tube('archCap', arch, 18.5, 2.0, M_BRASS_DARK)

def rail(name, pts, h=14, thick=6, mat=None, z0=0):
    """A walnut rail with a brass cap: the orbit walls, the kettle lane, the loft (z0: standing on the loft)."""
    wall_strip(name, pts, thick, z0 + h, mat or M_WALNUT_SIDE, z0=z0)
    tube(name + 'Cap', pts, z0 + h + 0.6, thick * 0.38, M_BRASS)


def tube3d(name, pts, r, mat):
    """A tube through (x, y, z) points (the chute's sloping rails)."""
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = r; cu.bevel_resolution = 3; cu.use_fill_caps = True
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for i, (x, y, z) in enumerate(pts):
        sp.points[i].co = (x, y, z, 1)
    cu.materials.append(mat)
    SMOOTH.add(name)
    return link(bpy.data.objects.new(name, cu))


def slope_slab(name, pts, zf, thick, mat):
    """A slab whose top follows zf(x, y) at each corner (planar when zf is linear), thick deep."""
    bm = bmesh.new()
    top = [bm.verts.new((x, y, zf(x, y))) for x, y in pts]
    bot = [bm.verts.new((x, y, zf(x, y) - thick)) for x, y in pts]
    bm.faces.new(top); bm.faces.new(list(reversed(bot)))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([bot[i], bot[j], top[j], top[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    me.materials.append(mat)
    return link(bpy.data.objects.new(name, me))

rail('orbitL', L.left_orbit_wall())
rail('orbitR', L.right_orbit_wall())
cylinder('orbitLend', *L.left_orbit_wall()[0], 4.2, 0, 16, M_BRASS)
cylinder('orbitRend', *L.right_orbit_wall()[0], 4.2, 0, 16, M_BRASS)

# the fireplace surround: brick walls round the alcove, a walnut mantel shelf on the roof
alc = L.alcove_wall()
wall_strip('alcove', alc, 9, 18, M_BRICK)
wall_strip('mantel', alc[1:4], 15, 23, M_WALNUT, z0=18)
tube('mantelEdge', alc[1:4], 23.4, 1.4, M_BRASS_DARK)
for p in (alc[0], alc[-1]):
    cylinder('hearthPost', p[0], p[1], 5.2, 0, 18, M_BRICK)

# the kettle lane: walnut walls with a brass cap
rail('kettle', L.kettle_lane_wall(), h=12, thick=5)

# M9 v3 (Aaron: "the loft doesn't really feel like a loft"): the loft stands LOFT_H up on a walnut platform (its
# floor painting on top, a brass nosing along its front edge, two turned posts under it), its rails stand on it,
# and the drain chute is an oak plank sloping from the platform's lower right down to the left lane.
LOFT_H = L.LOFT_HEIGHT
blk = L.loft_block()
front = L.loft_front()
platform = ccw(L.loft_platform())
prism('loftBase', platform, 0, LOFT_H - 0.6, M_WALNUT)
prism('loftTop', platform, LOFT_H - 0.6, LOFT_H, M_FLOOR, uv=True)
tube('loftNosing', front, LOFT_H - 0.4, 1.5, M_BRASS_DARK)
for i, (px, py) in enumerate(((L.LEFT_ORBIT_INNER_X + 5, L.LOFT_BOTTOM_Y - 4), (150, 960))):
    cylinder(f'loftPost{i}', px, py, 3.4, 0, LOFT_H - 0.6, M_WALNUT)
    cylinder(f'loftPostRing{i}', px, py, 4.0, LOFT_H * 0.45, LOFT_H * 0.55, M_BRASS)
for i, w in enumerate(L.loft_walls()):
    rail(f'loft{i}', w, h=12, thick=5, z0=LOFT_H)
# a balcony railing along the front edge under the slope (no ball reaches it): turned spindles, a walnut handrail
(bx0, by0), (bx1, by1) = front[0], front[1]
bal = [(bx0 + 4 + (bx1 - bx0 - 8) * t, by0 - 3 + (by1 - by0) * t - 0.0) for t in (0, 1)]
n_sp = 13
for i in range(n_sp + 1):
    t = i / n_sp
    sx, sy = bal[0][0] + (bal[1][0] - bal[0][0]) * t, bal[0][1] + (bal[1][1] - bal[0][1]) * t + (4 if i == 0 else 0) * 0
    cylinder(f'spindle{i}', sx, sy, 1.3 if 0 < i < n_sp else 2.4, LOFT_H, LOFT_H + 11, M_WALNUT_CAP, verts=12)
tube('balRail', bal, LOFT_H + 11.5, 2.0, M_WALNUT_CAP)
tube('balRailCap', bal, LOFT_H + 13.2, 0.9, M_BRASS)
M_OAK = wood('oak', (0.22, 0.11, 0.04), (0.48, 0.28, 0.12), scale=5.0, direction='X')
_w = next(nd for nd in M_OAK.node_tree.nodes if nd.type == 'TEX_WAVE')
_w.inputs['Distortion'].default_value = 1.2; _w.inputs['Scale'].default_value = 9.0     # straight boards
c0, c1 = L.loft_chute()                                  # (255, 975) down to (40, 880)
def chute_z(x, y=0):
    return LOFT_H * min(max((x - L.CHUTE_LOW_X) / (L.LOFT_RIGHT_X - L.CHUTE_LOW_X), 0), 1)
def chute_y(x):
    return c0[1] + (x - c0[0]) * (c1[1] - c0[1]) / (c1[0] - c0[0])
plank = ccw([(L.LOFT_RIGHT_X, L.LOFT_BOTTOM_Y)] + list(reversed(front[:-1])) +
            [(L.LEFT_ORBIT_INNER_X, L.LEFT_ORBIT_MOUTH_Y), (L.CHUTE_LOW_X, chute_y(L.CHUTE_LOW_X))])
slope_slab('chutePlank', plank, chute_z, 2.0, M_OAK)
xs = [L.LOFT_RIGHT_X - i * (L.LOFT_RIGHT_X - c1[0]) / 24 for i in range(25)]
tube3d('chute', [(x, chute_y(x), chute_z(x) + 8) for x in xs], 2.0, M_BRASS)
tube3d('chuteLow', [(x, chute_y(x), chute_z(x) + 3) for x in xs], 1.5, M_BRASS)
for x in (240, 170, 100):
    cylinder(f'chuteStay{x}', x, chute_y(x), 1.6, chute_z(x), chute_z(x) + 8, M_BRASS)

# the right orbit's one-way deflector (a brass wire), the ramp's mouth post
tube('deflector', list(L.RIGHT_DEFLECTOR), 7, 1.8, M_BRASS); tube('deflectorLow', list(L.RIGHT_DEFLECTOR), 3, 1.3, M_BRASS)
for p in L.RIGHT_DEFLECTOR:
    cylinder('deflPost', p[0], p[1], 2.8, 0, 10, M_BRASS)
mx_ = L.RAMP_MOUTH_RIGHT_X
wall_strip('rampPost', [(mx_, L.RAMP_MOUTH[1]), (mx_, L.RAMP_MOUTH[1] - 24)], 6, 14, M_WALNUT_SIDE)
post('rampPostTop', mx_, L.RAMP_MOUTH[1] - 24, 5.5, h=16)

# M9 v13: a ring round each scoop hole: iron for the fireplace and the kettle's stove, brass for the mail slot and the
# window seat (up on the loft); the game's scoops are artBaked now and only flash a ring of light when a ball drops in
M_IRON = principled('iron', (0.10, 0.09, 0.085), metal=1.0, rough=0.45)
for (cx, cy), r, z, m in ((L.FIREPLACE_CENTER, L.SCOOP_R, 0.6, M_IRON), (L.KETTLE_CENTER, L.SCOOP_R, 0.6, M_IRON),
                          (L.MAIL_SLOT_CENTER, L.SCOOP_R * 0.8, 0.6, M_BRASS),
                          (L.WINDOW_SEAT_CENTER, L.SCOOP_R, L.LOFT_HEIGHT + 0.6, M_BRASS)):
    torus(f'scoopRing{cx}', cx, cy, z, r + 1.0, 1.7, m)

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

# ------------------------------------------------------------------ light: a warm lamp-lit shop at night
sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.0; sun.angle = math.radians(12)
sun.color = (1.0, 0.86, 0.66)
so = link(bpy.data.objects.new('key', sun))
so.rotation_euler = (math.radians(-38), math.radians(-28), 0)          # from the top left, falling down-right
fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.5; fill.angle = math.radians(30)
fill.color = (0.75, 0.80, 1.0)                                          # a little cool window light from the right
fo = link(bpy.data.objects.new('fill', fill)); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
# warm soft boxes above the table for the brass to reflect (invisible to the camera)
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

cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(RW, RH)
cam.clip_end = 5000
co = link(bpy.data.objects.new('cam', cam))
co.location = (X0 + RW / 2, Y0 + RH / 2, 1500); co.rotation_euler = (0, 0, 0)
sc.camera = co

sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print('rendered', OUT, sc.render.resolution_x, sc.render.resolution_y)
