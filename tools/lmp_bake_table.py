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
import bpy, random, bmesh, math, sys, os
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
# M9 v35 (bookstore round 1): the cabinet sides are bookcases now (built with the arch corners further down); this
# is their carcass base, the books stand on it at CASE_BASE
CASE_BASE = 10.0
prism('cabL', [(X0, Y0), (12, Y0), (12, TOP), (X0, TOP)], 0, CASE_BASE, M_WALNUT)
prism('cabR', [(588, Y0), (X0 + RW, Y0), (X0 + RW, TOP), (588, TOP)], 0, CASE_BASE, M_WALNUT)
for _x0, _x1 in ((X0, X0 + 4), (7, 12), (588, 593), (X0 + RW - 4, X0 + RW)):     # the cases' outer and inner sides
    prism(f'caseSide{_x0}', [(_x0, Y0 - 12), (_x1, Y0 - 12), (_x1, TOP), (_x0, TOP)], 0, 30, M_WALNUT)
prism('cabFront', [(X0, Y0 - 40), (X0 + RW, Y0 - 40), (X0 + RW, Y0 - 12), (X0, Y0 - 12)], 0, CAB_H, M_WALNUT)
tube('railL', [(9.5, Y0 - 12), (9.5, TOP)], 31.2, 2.4, M_BRASS)
tube('railR', [(590.5, Y0 - 12), (590.5, TOP)], 31.2, 2.4, M_BRASS)

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
prism('archFill', ccw(arch + [(588, L.ARCH_START_Y), (588, TOP), (12, TOP), (12, L.ARCH_START_Y)]), 0, CASE_BASE,
      M_WALNUT_SIDE)
# M9 v35: the arch is a walnut wall in front of the corner bookcases, with its brass cap
_arch_out = []
for _x, _y in arch:
    _dx, _dy = _x - 300, _y - L.ARCH_START_Y + 40
    _n = math.hypot(_dx, _dy) or 1
    _arch_out.append((_x + 3 * _dx / _n, _y + 3 * _dy / _n))
wall_strip('archWall', _arch_out, 6, 24, M_WALNUT_SIDE)
tube('archCap', _arch_out, 24.5, 2.0, M_BRASS_DARK)

# ------------------------------------------------------------------ M9 v35: bookcases round the shop
# Aaron: "make the rest of the table feel more like a cozy book store". The cabinet sides and the corners outside the
# arch are bookcases: rows of books standing on walnut shelves, spines toward the player (in the oblique view each row
# shows its spines as a band with the tops behind), a brass genre plate every few shelves, now and then a leaning
# book, a lying stack or a gap, and a rolling library ladder on each side. All outside the playfield. The books are a
# few big meshes (per-corner colour attribute) so thousands of them stay quick.
def _book_material():
    m = bpy.data.materials.new('bookCloth'); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    at = nt.nodes.new('ShaderNodeAttribute'); at.attribute_name = 'bookCol'; at.attribute_type = 'GEOMETRY'
    nt.links.new(at.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.62; b.inputs['Coat Weight'].default_value = 0.12
    return m


M_BOOKCLOTH = _book_material()
M_PAGES = principled('pages', (0.50, 0.43, 0.32), rough=0.85)
M_GILT = principled('gilt', (0.88, 0.68, 0.32), metal=1.0, rough=0.32)
M_OAK_LADDER = principled('ladderOak', (0.42, 0.25, 0.12), rough=0.5, coat=0.2)
CLOTHS = [(0.36, 0.06, 0.05), (0.06, 0.10, 0.24), (0.07, 0.20, 0.12), (0.55, 0.38, 0.08), (0.30, 0.16, 0.07),
          (0.24, 0.09, 0.26), (0.08, 0.26, 0.26), (0.40, 0.33, 0.22), (0.12, 0.08, 0.06), (0.50, 0.14, 0.10),
          (0.20, 0.24, 0.30), (0.42, 0.30, 0.20)]
ROW, BOOK_D = 21.0, 11.0
_br = random.Random(35)
_books = bmesh.new(); _bcol = _books.loops.layers.float_color.new('bookCol')
_pages = bmesh.new(); _gilt = bmesh.new(); _lips = bmesh.new()


def _box(bm, x0, x1, y0, y1, z0, z1, lean=0.0, col=None):
    vs = [bm.verts.new(v) for v in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                     (x0 + lean, y0, z1), (x1 + lean, y0, z1), (x1 + lean, y1, z1), (x0 + lean, y1, z1))]
    fs = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    for f in fs:
        face = bm.faces.new([vs[i] for i in f])
        if col is not None:
            for lp in face.loops: lp[_bcol] = (*col, 1.0)


def _cloth():
    c = _br.choice(CLOTHS); k = _br.uniform(0.7, 1.05)
    return tuple(max(0.0, min(1.0, v * k)) for v in c)


def _row(x0, x1, y, plate):
    z = CASE_BASE
    _box(_lips, x0 - 0.5, x1 + 0.5, y - 1.6, y + 0.6, z - 0.5, z + 2.4)          # the shelf's front lip
    if plate and x1 - x0 > 20:
        cx = (x0 + x1) / 2
        _box(_gilt, cx - 4.5, cx + 4.5, y - 1.9, y - 1.5, z - 0.1, z + 2.1)    # a brass genre plate
    by0, by1 = y + 1.2, y + 1.2 + BOOK_D
    x = x0 + _br.uniform(0, 1.5)
    while x < x1 - 3:
        r = _br.random()
        if r < 0.04:                                                            # a gap
            x += _br.uniform(4, 8); continue
        if r < 0.10 and x1 - x > 14:                                            # a stack lying flat
            w = _br.uniform(10, 13); zz = z
            for k in range(_br.randint(2, 4)):
                j = _br.uniform(-0.8, 0.8); hh = _br.uniform(2.0, 2.8)
                _box(_books, x + j, x + w + j, by0 + 0.5, by1 - 1.0, zz, zz + hh, col=_cloth())
                _box(_pages, x + j + 0.4, x + w + j - 0.4, by0 + 1.5, by1 - 0.4, zz + 0.4, zz + hh - 0.4)
                zz += hh
            x += w + 1.2; continue
        w = _br.uniform(3.4, 5.4); h = _br.uniform(11.5, 16.5)
        if x + w > x1: break
        lean = _br.uniform(2.5, 4.5) if r < 0.15 and x + w + 4 < x1 else 0.0
        col = _cloth()
        _box(_books, x, x + w, by0, by1 - _br.uniform(0, 1.5), z, z + h, lean=lean, col=col)
        if not lean:
            _box(_pages, x + 0.6, x + w - 0.6, by0 + 1.2, by1 - 1.8, z + h - 0.2, z + h + 0.12)
            for zb in ((2.0, h - 2.8) if _br.random() < 0.6 else (h - 2.8,)):
                _box(_gilt, x + 0.35, x + w - 0.35, by0 - 0.18, by0 + 0.2, z + zb, z + zb + 0.5)
        x += w + (lean if lean else 0) + _br.uniform(0.15, 0.5)


def _arch_x_left(y):
    pts = [p for p in arch if p[0] <= 300]
    for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
        if ya <= y <= yb:
            return xa + (xb - xa) * (y - ya) / ((yb - ya) or 1)
    return 300.0


_ri = 0
_y = Y0 + 1.0
while _y < Y0 + RH + 2:
    spans = [(X0 + 5, 6.0), (594.0, X0 + RW - 5)]
    if _y >= L.TOP_Y + 4:
        spans.append((15.0, 585.0))
    elif _y >= L.ARCH_START_Y:
        xl = _arch_x_left(_y) - 7
        if xl - 15 > 10:
            spans += [(15.0, xl), (600 - xl, 585.0)]
    for a_, b_ in spans:
        _row(a_, b_, _y, plate=(_ri % 5 == 2))
    _y += ROW; _ri += 1

for _bm, _name, _m in ((_books, 'caseBooks', M_BOOKCLOTH), (_pages, 'casePages', M_PAGES), (_gilt, 'caseGilt', M_GILT),
                       (_lips, 'caseLips', M_WALNUT)):
    _me = bpy.data.meshes.new(_name); _bm.to_mesh(_me); _bm.free(); _me.materials.append(_m)
    _o = link(bpy.data.objects.new(_name, _me))
    if _name == 'caseBooks':
        _bv = _o.modifiers.new('b', 'BEVEL'); _bv.width = 0.25; _bv.segments = 1
print('bookcases: rows', _ri)


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
# M9 v34 (Aaron: "make the fireplace look a little more 3d"): real coursed brick (UV-mapped per face, mortar sunk with a
# bump), stone caps on the cheeks, square brick pillars with stone caps at the mouth, a two-tier walnut mantel, a raised
# stone hearth, 3D logs with glowing embers on iron andirons, and the fire's own light warming the inside of the brick
# (light-linked, so it lights only the fireplace; the flames themselves are the animated sprite lmp_fire_<i>).
def brick_material(name, c1, c2, mortar):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    uv = nt.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'BrickUV'
    br = nt.nodes.new('ShaderNodeTexBrick')
    br.offset = 0.5; br.offset_frequency = 2
    br.inputs['Color1'].default_value = (*c1, 1); br.inputs['Color2'].default_value = (*c2, 1)
    br.inputs['Mortar'].default_value = (*mortar, 1)
    br.inputs['Scale'].default_value = 1.0; br.inputs['Mortar Size'].default_value = 0.4
    br.inputs['Mortar Smooth'].default_value = 0.2; br.inputs['Bias'].default_value = 0.0
    br.inputs['Brick Width'].default_value = 10.0; br.inputs['Row Height'].default_value = 3.6
    nt.links.new(uv.outputs['UV'], br.inputs['Vector'])
    nt.links.new(br.outputs['Color'], b.inputs['Base Color'])
    bump = nt.nodes.new('ShaderNodeBump'); bump.invert = True
    bump.inputs['Strength'].default_value = 0.6; bump.inputs['Distance'].default_value = 0.3
    nt.links.new(br.outputs['Fac'], bump.inputs['Height'])
    nt.links.new(bump.outputs['Normal'], b.inputs['Normal'])
    b.inputs['Roughness'].default_value = 0.85
    return m


def brick_uv(me):
    """Per-face UVs in pt: tops by (x, y), sides by (distance along the face, height), so courses run level."""
    uv = me.uv_layers.new(name='BrickUV')
    for poly in me.polygons:
        n = poly.normal
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            if abs(n.z) > 0.5:
                uv.data[li].uv = (v.x, v.y)
            else:
                uv.data[li].uv = (v.x * -n.y + v.y * n.x, v.z)


def brick_prism(name, pts, z0, z1, mat):
    o = prism(name, pts, z0, z1, mat)
    brick_uv(o.data)
    FIRE_LIT.append(o.name)
    return o


def brick_strip(name, pts, thick, z0, z1, mat):
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        dx, dy = b[0] - a[0], b[1] - a[1]; ln = math.hypot(dx, dy)
        nx, ny = -dy / ln * thick / 2, dx / ln * thick / 2
        tx, ty = dx / ln * thick / 2, dy / ln * thick / 2           # run past the corners so they close
        quad = [(a[0] + nx - tx, a[1] + ny - ty), (b[0] + nx + tx, b[1] + ny + ty),
                (b[0] - nx + tx, b[1] - ny + ty), (a[0] - nx - tx, a[1] - ny - ty)]
        brick_prism(f'{name}{i}', quad, z0, z1, mat)


def stone_material(name, base):
    m = principled(name, base, rough=0.7)
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    nz = nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 0.35; nz.inputs['Detail'].default_value = 6
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (*(c * 0.8 for c in base), 1)
    ramp.color_ramp.elements[1].color = (*(min(1, c * 1.15) for c in base), 1)
    nt.links.new(nz.outputs['Fac'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    return m


FIRE_LIT = []
M_FP_BRICK = brick_material('fpBrick', (0.46, 0.18, 0.10), (0.34, 0.12, 0.07), (0.52, 0.47, 0.41))
M_HEARTHSTONE = stone_material('hearthStone', (0.31, 0.27, 0.23))
M_FIRE_IRON = principled('fireIron', (0.06, 0.055, 0.05), metal=0.8, rough=0.5)
M_LOG = principled('log', (0.11, 0.065, 0.04), rough=0.9)
_nt = M_LOG.node_tree; _b = _nt.nodes['Principled BSDF']
_nz = _nt.nodes.new('ShaderNodeTexNoise'); _nz.inputs['Scale'].default_value = 0.6; _nz.inputs['Detail'].default_value = 5
_rp = _nt.nodes.new('ShaderNodeValToRGB')
_rp.color_ramp.elements[0].position = 0.60; _rp.color_ramp.elements[0].color = (0, 0, 0, 1)
_rp.color_ramp.elements[1].position = 0.70; _rp.color_ramp.elements[1].color = (1, 1, 1, 1)
_mul = _nt.nodes.new('ShaderNodeMath'); _mul.operation = 'MULTIPLY'; _mul.inputs[1].default_value = 3.0
_nt.links.new(_nz.outputs['Fac'], _rp.inputs['Fac'])
_nt.links.new(_rp.outputs['Color'], _mul.inputs[0])
_nt.links.new(_mul.outputs[0], _b.inputs['Emission Strength'])
_b.inputs['Emission Color'].default_value = (1.0, 0.30, 0.05, 1)

alc = L.alcove_wall()
# taller than before (z 30, was 18): in the oblique view the back wall's face now shows as a band of brick behind the
# fire, the fireback, and the pillars show their brick fronts (the mantel decoration and the cat's perch move up 5 pt)
FP_H = 30.0
brick_strip('alcove', alc, 9, 0, FP_H, M_FP_BRICK)
wall_strip('mantelBase', alc[1:4], 12, FP_H + 2.5, M_WALNUT, z0=FP_H)    # a two-tier walnut mantel shelf
wall_strip('mantel', alc[1:4], 17, FP_H + 5.5, M_WALNUT, z0=FP_H + 2.5)
tube('mantelEdge', alc[1:4], FP_H + 5.8, 1.1, M_BRASS_DARK)
for p in (alc[0], alc[-1]):                                            # square brick pillars at the mouth
    brick_prism('hearthPost' + str(p[0]), [(p[0] - 6, p[1] - 6), (p[0] + 6, p[1] - 6), (p[0] + 6, p[1] + 6),
                                           (p[0] - 6, p[1] + 6)], 0, FP_H + 1, M_FP_BRICK)
    _c = prism('hearthPostCap' + str(p[0]), [(p[0] - 7.2, p[1] - 7.2), (p[0] + 7.2, p[1] - 7.2),
                                              (p[0] + 7.2, p[1] + 7.2), (p[0] - 7.2, p[1] + 7.2)], FP_H + 1, FP_H + 3.5,
               M_HEARTHSTONE)
    _bv = _c.modifiers.new('b', 'BEVEL'); _bv.width = 0.6; _bv.segments = 2
# the raised stone hearth in front: flagstones with gaps (the painted hearth shows through the joints)
_hr = random.Random(34); _x = L.ALCOVE_LEFT_X - 18
while _x < L.ALCOVE_RIGHT_X + 17:
    _w = min(_hr.uniform(20, 30), L.ALCOVE_RIGHT_X + 18 - _x)
    if _w > 4:
        _st = prism('hearthStone' + str(int(_x)), [(_x + 0.5, L.ALCOVE_BOTTOM_Y - 25.5), (_x + _w - 0.5, L.ALCOVE_BOTTOM_Y - 25.5),
                                                  (_x + _w - 0.5, L.ALCOVE_BOTTOM_Y - 1.0), (_x + 0.5, L.ALCOVE_BOTTOM_Y - 1.0)],
                    0, 1.4, M_HEARTHSTONE)
        _bv = _st.modifiers.new('b', 'BEVEL'); _bv.width = 0.5; _bv.segments = 2
    _x += _w
# andirons and the grate, and two logs with embers glowing in their cracks (not fire-lit: the flames sit on them)
for ax in (252, 316):
    cylinder('andiron' + str(ax), ax, 755, 1.3, 0, 9, M_FIRE_IRON, verts=16)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=2.0, location=(ax, 755, 9.5), segments=16, ring_count=8)
    _o = bpy.context.object; _o.name = 'andironKnob' + str(ax); _o.data.materials.append(M_BRASS_DARK); SMOOTH.add(_o.name)
tube3d('grateFront', [(246, 757, 2.6), (322, 757, 2.6)], 0.9, M_FIRE_IRON)
for _i, gx_ in enumerate(range(250, 322, 9)):
    tube3d(f'grateBar{_i}', [(gx_, 757, 2.6), (gx_, 783, 2.6)], 0.7, M_FIRE_IRON)
tube3d('log0', [(250, 764, 6.0), (318, 776, 6.6)], 3.6, M_LOG)
tube3d('log1', [(256, 777, 6.4), (314, 764, 10.2)], 3.3, M_LOG)

# the kettle lane: walnut walls with a brass cap
# M9 v21 (Aaron: the kettle lane ran into the loft's chute, "the stairs"): its rounded top end passes under the sloping
# chute plank, where the chute is only ~7-11 pt up, so the 12 pt walls poked through it. Under the chute (and a few
# points before it) the walls are 3.5 pt low, so the lane tucks under the plank.
_k0, _k1 = L.loft_chute()
def _under_chute(p):
    cy = _k0[1] + (p[0] - _k0[0]) * (_k1[1] - _k0[1]) / (_k1[0] - _k0[0])
    return p[1] > cy - 10
_kw = L.kettle_lane_wall()
_runs, _cur, _low = [], [_kw[0]], _under_chute(_kw[0])
for _p in _kw[1:]:
    _u = _under_chute(_p)
    _cur.append(_p)
    if _u != _low:
        _runs.append((_low, _cur)); _cur = [_p]; _low = _u
_runs.append((_low, _cur))
for _i, (_low, _pts) in enumerate(_runs):
    if len(_pts) > 1: rail(f'kettle{_i}', _pts, h=9 if _low else 12, thick=5)    # v27: the chute is twice as high

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
# M9 v31 (loft round 2): what holds the loft up. A heavy dark beam along the platform's front edge with the ends of the
# floor joists showing under it, diagonal braces from the two posts up to the beam, and a balustrade (balusters and a
# handrail) on top of the loft's right-hand wall, either side of the ramp's door. Drawing only.
M_JOIST = principled('joist', (0.34, 0.19, 0.08), rough=0.6)
for k, (a, b) in enumerate(zip(front, front[1:])):
    dx, dy = b[0] - a[0], b[1] - a[1]; ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    nx, ny = uy, -ux                                            # outward: toward the player (south)
    quad = [(a[0], a[1]), (b[0], b[1]), (b[0] + nx * 2.4, b[1] + ny * 2.4), (a[0] + nx * 2.4, a[1] + ny * 2.4)]
    prism(f'loftBeam{k}', ccw(quad), LOFT_H - 7.0, LOFT_H - 0.6, M_WALNUT_CAP)
    n_j = int(ln // 14)
    for j in range(1, n_j):
        t = j / n_j
        cx_, cy_ = a[0] + dx * t, a[1] + dy * t
        q = [(cx_ - ux * 1.6, cy_ - uy * 1.6), (cx_ + ux * 1.6, cy_ + uy * 1.6),
             (cx_ + ux * 1.6 + nx * 3.8, cy_ + uy * 1.6 + ny * 3.8), (cx_ - ux * 1.6 + nx * 3.8, cy_ - uy * 1.6 + ny * 3.8)]
        prism(f'joist{k}_{j}', ccw(q), LOFT_H - 11.0, LOFT_H - 7.0, M_JOIST)
def _front_y(x):
    for a, b in zip(front, front[1:]):
        if a[0] <= x <= b[0]:
            return a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])
    return front[0][1]
for i, (px, py) in enumerate(((L.LEFT_ORBIT_INNER_X + 5, L.LOFT_BOTTOM_Y - 4), (150, 960))):
    for side in (-1, 1):
        tx = px + side * 10
        if tx < front[0][0] + 2: continue
        tube3d(f'brace{i}{side}', [(px, py, LOFT_H * 0.55), (tx, _front_y(tx) - 1.0, LOFT_H - 7.2)], 1.2, M_WALNUT)
# M9 v32 (loft round 3): furniture in the corner under the loft's slope wall, where no ball goes: a low bookcase along
# the front edge facing the player (two shelves of coloured spines) and a potted fern beside it.
fx0, fy0 = front[0]; fx1, fy1 = front[1]
fl = math.hypot(fx1 - fx0, fy1 - fy0); fu = ((fx1 - fx0) / fl, (fy1 - fy0) / fl); fn = (-fu[1], fu[0])   # fn: into the loft
def _on_front(x, inset):
    t = (x - fx0) / (fx1 - fx0)
    return (fx0 + (fx1 - fx0) * t + fn[0] * inset, fy0 + (fy1 - fy0) * t + fn[1] * inset)
def _quad(xa, xb, d0, d1):
    a0, b0 = _on_front(xa, d0), _on_front(xb, d0)
    return ccw([a0, b0, (b0[0] + fn[0] * (d1 - d0), b0[1] + fn[1] * (d1 - d0)),
                (a0[0] + fn[0] * (d1 - d0), a0[1] + fn[1] * (d1 - d0))])
BK_X0, BK_X1, BK_D0, BK_D1, BK_H = 92.0, 136.0, 3.0, 10.0, 21.0
prism('bookcaseBack', _quad(BK_X0, BK_X1, BK_D1 - 1.5, BK_D1), LOFT_H, LOFT_H + BK_H, M_WALNUT)
prism('bookcaseTop', _quad(BK_X0 - 0.8, BK_X1 + 0.8, BK_D0 - 0.6, BK_D1), LOFT_H + BK_H, LOFT_H + BK_H + 1.4, M_WALNUT_CAP)
for xx in (BK_X0, BK_X1 - 1.4):
    prism(f'bookcaseSide{xx}', _quad(xx, xx + 1.4, BK_D0, BK_D1), LOFT_H, LOFT_H + BK_H, M_WALNUT_CAP)
for zz in (0.0, 10.0):
    prism(f'bookcaseShelf{zz}', _quad(BK_X0, BK_X1, BK_D0, BK_D1), LOFT_H + zz, LOFT_H + zz + 1.2, M_WALNUT_CAP)
rnd_b = __import__('random').Random(5)
cols_b = [(0.40, 0.08, 0.06), (0.08, 0.22, 0.13), (0.09, 0.13, 0.34), (0.62, 0.44, 0.10), (0.30, 0.12, 0.34),
          (0.55, 0.30, 0.12), (0.80, 0.74, 0.60)]
mats_b = [principled(f'shelfBook{i}', c, rough=0.6) for i, c in enumerate(cols_b)]
for zz in (1.2, 11.2):
    xx = BK_X0 + 1.6
    while xx < BK_X1 - 3.4:
        w_ = rnd_b.uniform(1.6, 2.6); h_ = rnd_b.uniform(5.5, 8.2)
        prism(f'shelfBook{zz}_{xx:.1f}', _quad(xx, xx + w_ - 0.2, BK_D0 + 0.6, BK_D1 - 1.6), LOFT_H + zz, LOFT_H + zz + h_,
              rnd_b.choice(mats_b))
        xx += w_
M_POT = principled('pot', (0.66, 0.33, 0.18), rough=0.7)
M_FERN = principled('fern', (0.16, 0.40, 0.14), rough=0.6)
px_, py_ = 79.0, 1006.0
bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=3.6, radius2=5.0, depth=7.0, location=(px_, py_, LOFT_H + 3.5))
bpy.context.object.data.materials.append(M_POT)
for k in range(9):
    a_ = k * 2 * math.pi / 9
    tip = (px_ + math.cos(a_) * 9.5, py_ + math.sin(a_) * 8.0, LOFT_H + 9.0 + (k % 3) * 2.0)
    mid = ((px_ + tip[0]) / 2, (py_ + tip[1]) / 2, LOFT_H + 14.0)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=mid, segments=12, ring_count=6)
    o_ = bpy.context.object
    o_.scale = (5.5, 1.5, 0.5); o_.rotation_euler = (0, -0.5, a_); o_.data.materials.append(M_FERN)
    for pp in o_.data.polygons: pp.use_smooth = True
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
# M9 v30 (Aaron: make the loft feel more like a loft; the chute already read as "the stairs"): the chute is a real
# oak staircase: N_STEPS treads (each a slab of the plank's footprint between two x's, its top at the step's height),
# brass nosings, a stringer along the open (front) side, turned balusters, a walnut handrail and two newel posts.
# Open underneath (the kettle lane runs under it). The ball still rolls down the physics slope; only the drawing steps.
def clip_x(poly, a, b):
    def clip(pts, keep, xc):
        out = []
        for i in range(len(pts)):
            p, q = pts[i], pts[(i + 1) % len(pts)]
            if keep(p): out.append(p)
            if keep(p) != keep(q):
                out.append((xc, p[1] + (q[1] - p[1]) * (xc - p[0]) / (q[0] - p[0])))
        return out
    pts = clip(poly, lambda p: p[0] >= a, a)
    pts = clip(pts, lambda p: p[0] <= b, b) if len(pts) >= 3 else []
    return pts if len(pts) >= 3 else []
N_STEPS = 11
M_RISER = principled('riserShadow', (0.10, 0.05, 0.02), rough=0.9)
step_x = [L.CHUTE_LOW_X + (L.LOFT_RIGHT_X - L.CHUTE_LOW_X) * i / N_STEPS for i in range(N_STEPS + 1)]
for i in range(N_STEPS):
    a, b = step_x[i], step_x[i + 1]
    piece = clip_x(plank, a - (0 if i == 0 else 0.2), b)
    if not piece: continue
    zt = LOFT_H * (i + 1) / N_STEPS
    prism(f'tread{i}', ccw(piece), zt - 2.6, zt, M_OAK)
    lo_y, hi_y = chute_y(a) + 0.5, max(p[1] for p in piece if abs(p[0] - min(q[0] for q in piece)) < 0.01)
    tube3d(f'nosing{i}', [(a + 0.6, lo_y, zt + 0.1), (a + 0.6, hi_y - 0.5, zt + 0.1)], 0.6, M_BRASS)
    if i < N_STEPS - 1:                                         # the shadow of the next step's riser on this tread
        sh = clip_x(piece, b - 3.2, b)
        if sh: prism(f'riserShadow{i}', ccw(sh), zt, zt + 0.15, M_RISER)
# the stringer: a board along the open side, under the treads' front ends
bm = bmesh.new()
sx_ = [L.CHUTE_LOW_X + (L.LOFT_RIGHT_X - L.CHUTE_LOW_X) * i / 40 for i in range(41)]
top_ = [bm.verts.new((x, chute_y(x) - 0.5, chute_z(x) + 1.0)) for x in sx_]
bot_ = [bm.verts.new((x, chute_y(x) - 0.5, max(chute_z(x) - 7.0, 0.0))) for x in sx_]
for i in range(40):
    bm.faces.new([bot_[i], bot_[i + 1], top_[i + 1], top_[i]])
me = bpy.data.meshes.new('stringer'); bm.to_mesh(me); bm.free(); me.materials.append(M_WALNUT)
link(bpy.data.objects.new('stringer', me))
for i in range(N_STEPS):                                       # a baluster on each tread, the handrail along their tops
    x = (step_x[i] + step_x[i + 1]) / 2
    zt = LOFT_H * (i + 1) / N_STEPS
    cylinder(f'baluster{i}', x, chute_y(x) + 2.0, 0.9, zt, zt + 13.0, M_WALNUT_CAP, verts=10)
hx = [L.CHUTE_LOW_X + 3 + (L.LOFT_RIGHT_X - 6 - L.CHUTE_LOW_X) * i / 30 for i in range(31)]
tube3d('handrail', [(x, chute_y(x) + 2.0, chute_z(x) + 14.5) for x in hx], 1.7, M_WALNUT_CAP)
tube3d('handrailCap', [(x, chute_y(x) + 2.0, chute_z(x) + 16.0) for x in hx], 0.6, M_BRASS)
for x, zb in ((L.CHUTE_LOW_X + 3, 0.0), (L.LOFT_RIGHT_X - 3, LOFT_H)):
    cylinder(f'newel{x}', x, chute_y(x) + 2.0, 2.4, zb, chute_z(x) + 17.5, M_WALNUT, verts=16)
    torus(f'newelCap{x}', x, chute_y(x) + 2.0, chute_z(x) + 17.8, 1.6, 1.0, M_BRASS)

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
                          (L.MAIL_SLOT_CENTER, L.SCOOP_R * 0.8, 0.6, M_BRASS)):
    torus(f'scoopRing{cx}', cx, cy, z, r + 1.0, 1.7, m)

# M9 v30 (Aaron: with the hole in the middle of the bench it didn't read as a bench): the window seat's hole is a wicker
# book basket on the loft floor (a woven rim, a few spines poking up at the back), and the bench stands along the loft's
# wall just above it, a walnut base with a red cushion, gold piping and two pillows. Drawing only.
M_WICKER = wood('wicker', (0.40, 0.26, 0.11), (0.70, 0.52, 0.26), scale=14.0, direction='X')
wx, wy = L.WINDOW_SEAT_CENTER
torus('basketRim', wx, wy, LOFT_H + 2.0, L.SCOOP_R + 1.8, 2.4, M_WICKER)
torus('basketRim2', wx, wy, LOFT_H + 0.6, L.SCOOP_R + 2.4, 1.6, M_WICKER)
for k, (dx, w_, h_, col) in enumerate(((-7, 3.4, 7.5, (0.40, 0.08, 0.06)), (-3, 3.0, 9.0, (0.08, 0.20, 0.12)),
                                       (1, 3.8, 8.0, (0.10, 0.12, 0.32)), (5.5, 3.0, 6.5, (0.62, 0.44, 0.10)))):
    m_ = principled(f'basketBook{k}', col, rough=0.6)
    bx_, by_ = wx + dx, wy + L.SCOOP_R - 3.0
    prism(f'basketBook{k}', ccw([(bx_, by_), (bx_ + w_, by_), (bx_ + w_, by_ + 5), (bx_, by_ + 5)]),
          LOFT_H + 1, LOFT_H + h_, m_)
out_ = L.loft_outline()
M_CUSHION = principled('cushion', (0.55, 0.16, 0.12), rough=0.7)
PILLOWS = [principled('pillowGold', (0.86, 0.70, 0.30), rough=0.7), principled('pillowGreen', (0.12, 0.28, 0.20), rough=0.7),
           principled('pillowBlue', (0.14, 0.20, 0.42), rough=0.7)]
def _arc_tools(arc):
    def inward(i, d):
        p = arc[i]; q = arc[min(i + 1, len(arc) - 1)]; o = arc[max(i - 1, 0)]
        tx, ty = q[0] - o[0], q[1] - o[1]; ln = math.hypot(tx, ty) or 1
        nx, ny = ty / ln, -tx / ln                              # rotate the tangent: points into the loft
        return (p[0] + nx * d, p[1] + ny * d)
    return inward
# M9 v33 (Aaron: more benches along the curved wall): three cushioned benches along the loft's curved wall (the one
# above the basket, one lower down, one along the top), each a walnut base, a red cushion with gold piping and pillows.
def wall_bench(tag, keep, n_pillows=2):
    arc = [p for p in out_ if keep(p)]
    inward = _arc_tools(arc)
    seat = ccw([inward(i, 5.0) for i in range(len(arc))] + [inward(i, 17.0) for i in reversed(range(len(arc)))])
    cush = ccw([inward(i, 6.0) for i in range(1, len(arc) - 1)] + [inward(i, 16.0) for i in reversed(range(1, len(arc) - 1))])
    prism(f'benchBase{tag}', seat, LOFT_H, LOFT_H + 5.0, M_WALNUT)
    prism(f'benchCushion{tag}', cush, LOFT_H + 5.0, LOFT_H + 8.0, M_CUSHION)
    tube(f'benchPiping{tag}', [inward(i, 11.0) for i in range(1, len(arc) - 1)], LOFT_H + 8.1, 0.45, M_BRASS)
    for j in range(n_pillows):
        t = (j + 0.5) / n_pillows
        px_, py_ = inward(int(t * (len(arc) - 1)), 8.5)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=4.2, location=(px_, py_, LOFT_H + 11.0), segments=20, ring_count=10)
        o_ = bpy.context.object; o_.scale = (1.0, 0.7, 0.55); o_.data.materials.append(PILLOWS[(j + len(tag)) % 3])
        for pp in o_.data.polygons: pp.use_smooth = True
wall_bench('Low', lambda p: 1036 <= p[1] <= 1090)
wall_bench('Seat', lambda p: 1142 <= p[1] <= 1184)
wall_bench('Top', lambda p: p[1] >= 1193 and p[0] <= 240, 3)
# M9 v33 (Aaron: wall sconces instead of the hanging lamp): brass sconces on top of the curved wall's rail, each a back
# plate, a short arm reaching into the loft and a glowing tulip shade; their pools of light are painted on the floor.
M_SCONCE_GLASS = principled('sconceGlass', (0.95, 0.62, 0.28), emit=(1.0, 0.62, 0.26), emit_strength=1.6)
for k, yy in enumerate(L.LOFT_SCONCE_YS):
    i = min(range(len(out_)), key=lambda j: abs(out_[j][1] - yy))
    inward = _arc_tools(out_)
    wx_, wy_ = out_[i]
    ax_, ay_ = inward(i, 5.0)
    cylinder(f'sconcePlate{k}', wx_, wy_, 2.4, LOFT_H + 11, LOFT_H + 18, M_BRASS, verts=16)
    tube3d(f'sconceArm{k}', [(wx_, wy_, LOFT_H + 16), (ax_, ay_, LOFT_H + 19)], 0.6, M_BRASS)
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=1.4, radius2=3.0, depth=4.0, location=(ax_, ay_, LOFT_H + 21.5))
    bpy.context.object.data.materials.append(M_SCONCE_GLASS)
# M9 v33 (Aaron: bookshelves above and below the entrance to the loft): low open bookshelves standing on the loft's
# right-hand wall either side of the ramp's door; from above you see the books' tops between two walnut boards.
rnd_s = __import__('random').Random(9)
mats_s = [principled(f'wallBook{i}', c, rough=0.6) for i, c in enumerate(
    [(0.40, 0.08, 0.06), (0.08, 0.22, 0.13), (0.09, 0.13, 0.34), (0.62, 0.44, 0.10), (0.30, 0.12, 0.34),
     (0.55, 0.30, 0.12), (0.80, 0.74, 0.60), (0.14, 0.30, 0.32)])]
xs0, xs1 = L.LOFT_RIGHT_X - 6.5, L.LOFT_RIGHT_X + 4.5
for k, (y0, y1) in enumerate(((L.LOFT_BOTTOM_Y + 3, L.LOFT_DOOR_BOTTOM - 2), (L.LOFT_DOOR_TOP + 2, 1213))):
    prism(f'shelfBase{k}', ccw([(xs0, y0), (xs1, y0), (xs1, y1), (xs0, y1)]), LOFT_H, LOFT_H + 1.5, M_WALNUT_CAP)
    for xx in (xs0, xs1 - 1.2):
        prism(f'shelfSide{k}{xx}', ccw([(xx, y0), (xx + 1.2, y0), (xx + 1.2, y1), (xx, y1)]), LOFT_H, LOFT_H + 15, M_WALNUT_CAP)
    for yy in (y0, y1 - 1.4):
        prism(f'shelfEnd{k}{yy}', ccw([(xs0, yy), (xs1, yy), (xs1, yy + 1.4), (xs0, yy + 1.4)]), LOFT_H, LOFT_H + 16, M_WALNUT_CAP)
    yy = y0 + 1.6
    while yy < y1 - 3.5:
        d_ = rnd_s.uniform(1.8, 3.0); h_ = rnd_s.uniform(9.0, 13.5); w_ = rnd_s.uniform(6.0, 8.6)
        prism(f'wallBook{k}_{yy:.1f}', ccw([(xs0 + 1.4, yy), (xs0 + 1.4 + w_, yy), (xs0 + 1.4 + w_, yy + d_ - 0.25),
                                             (xs0 + 1.4, yy + d_ - 0.25)]), LOFT_H + 1.5, LOFT_H + h_, rnd_s.choice(mats_s))
        yy += d_

# a rolling library ladder on each side, resting on the books, brass hooks at the top and brass wheels at the foot
for _cx, _ly0, _ly1 in ((X0 + 23, 395, 480), (X0 + RW - 23, 705, 790)):
    for _sx in (-6.5, 6.5):
        tube3d(f'ladderRail{_cx}{_sx}', [(_cx + _sx, _ly0, 27), (_cx + _sx, _ly1, 40)], 1.1, M_OAK_LADDER)
        tube3d(f'ladderHook{_cx}{_sx}', [(_cx + _sx, _ly1, 40), (_cx + _sx, _ly1 + 3, 41.5), (_cx + _sx, _ly1 + 4, 39)],
               0.6, M_BRASS)
        cylinder(f'ladderWheel{_cx}{_sx}', _cx + _sx, _ly0 - 1, 1.6, 25.4, 27.2, M_BRASS, verts=12)
    _n = 11
    for _k in range(1, _n):
        _t = _k / _n
        tube3d(f'ladderRung{_cx}{_k}', [(_cx - 6.5, _ly0 + (_ly1 - _ly0) * _t, 27 + 13 * _t),
                                        (_cx + 6.5, _ly0 + (_ly1 - _ly0) * _t, 27 + 13 * _t)], 0.7, M_OAK_LADDER)

# ------------------------------------------------------------------ M9 v36 (bookstore round 2): the shop counter
_before_counter = set(o.name for o in sc.objects)
# On the aprons, clear of the lamps: a stack of brown-paper parcels and a chalkboard easel on the left; a brass till
# and a cup of tea on the right (the gilt shop sign and the BOOK RETURNS plate are painted in lmp_floor_table.py).
def _chalk_png(path):
    import cairo as _c
    W_, H_ = 320, 260
    sf = _c.ImageSurface(_c.FORMAT_RGB24, W_, H_); c = _c.Context(sf)
    c.set_source_rgb(0.10, 0.12, 0.11); c.paint()
    rr = random.Random(36)
    for _ in range(260):                                       # old chalk dust
        c.set_source_rgba(0.85, 0.85, 0.8, rr.uniform(0.02, 0.07))
        c.arc(rr.uniform(0, W_), rr.uniform(0, H_), rr.uniform(3, 14), 0, 6.29); c.fill()
    c.set_source_rgba(0.95, 0.95, 0.9, 0.92)
    c.select_font_face('DejaVu Serif', _c.FONT_SLANT_ITALIC, _c.FONT_WEIGHT_BOLD); c.set_font_size(46)
    e = c.text_extents("Today's"); c.move_to(W_ / 2 - e.x_advance / 2, 66); c.show_text("Today's")
    e = c.text_extents('Pick'); c.move_to(W_ / 2 - e.x_advance / 2, 116); c.show_text('Pick')
    c.set_line_width(4); c.move_to(70, 132); c.curve_to(130, 124, 190, 140, 250, 128); c.stroke()
    c.set_source_rgba(0.98, 0.80, 0.55, 0.9)                   # a little open book in orange chalk
    c.set_line_width(5)
    c.move_to(160, 228); c.curve_to(130, 206, 100, 210, 86, 216); c.line_to(86, 168); c.curve_to(110, 160, 140, 166, 160, 184)
    c.close_path(); c.stroke()
    c.move_to(160, 228); c.curve_to(190, 206, 220, 210, 234, 216); c.line_to(234, 168); c.curve_to(210, 160, 180, 166, 160, 184)
    c.close_path(); c.stroke()
    c.set_source_rgba(0.7, 0.9, 0.85, 0.8); c.set_line_width(3)
    for yy in (184, 196, 208):
        c.move_to(102, yy - 6); c.line_to(146, yy + 4); c.stroke()
        c.move_to(174, yy + 4); c.line_to(218, yy - 6); c.stroke()
    sf.write_to_png(path)


_chalk = os.path.join(os.path.dirname(os.path.abspath(OUT)), '_lmp_chalkboard.png'); _chalk_png(_chalk)
M_CHALK = principled('chalkboard', (1, 1, 1), rough=0.9, image=_chalk)
M_PAPER = principled('brownPaper', (0.56, 0.40, 0.24), rough=0.85)
M_TWINE = principled('twine', (0.82, 0.73, 0.55), rough=0.9)
M_WAX = principled('wax', (0.55, 0.05, 0.05), rough=0.35, coat=0.4)
M_CHINA = principled('china', (0.93, 0.90, 0.84), rough=0.25, coat=0.5)
M_TEA = principled('tea', (0.22, 0.10, 0.04), rough=0.08, coat=0.8)
M_KEYCAP = principled('keycap', (0.92, 0.88, 0.78), rough=0.4)


def _bx(name, x0, x1, y0, y1, z0, z1, mat, bevel=0.0):
    o = prism(name, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], z0, z1, mat)
    if bevel:
        b = o.modifiers.new('b', 'BEVEL'); b.width = bevel; b.segments = 2
    return o


# parcels: three brown-paper packets tied with twine, a red wax seal on top
_pz = 3.0
for _i, (_pcx, _pcy, _pw, _pd, _ph) in enumerate(((72, 26, 30, 20, 8), (70, 27, 23, 15, 7), (74, 26, 15, 11, 6))):
    _x0, _x1, _y0, _y1 = _pcx - _pw / 2, _pcx + _pw / 2, _pcy - _pd / 2, _pcy + _pd / 2
    _bx(f'parcel{_i}', _x0, _x1, _y0, _y1, _pz, _pz + _ph, M_PAPER, bevel=0.6)
    _t = _pz + _ph + 0.25
    tube3d(f'twineA{_i}', [(_pcx, _y0 - 0.25, _pz), (_pcx, _y0 - 0.25, _t), (_pcx, _y1 + 0.25, _t), (_pcx, _y1 + 0.25, _pz)],
           0.35, M_TWINE)
    tube3d(f'twineB{_i}', [(_x0 - 0.25, _pcy, _pz), (_x0 - 0.25, _pcy, _t), (_x1 + 0.25, _pcy, _t), (_x1 + 0.25, _pcy, _pz)],
           0.35, M_TWINE)
    _pz += _ph
cylinder('waxSeal', 74, 26, 1.8, _pz, _pz + 0.8, M_WAX, verts=16)
tube3d('twineBow', [(74, 26, _pz + 0.6), (70.5, 29, _pz + 0.9), (71, 31, _pz + 0.4)], 0.35, M_TWINE)
tube3d('twineBow2', [(74, 26, _pz + 0.6), (77.5, 29, _pz + 0.9), (77, 31, _pz + 0.4)], 0.35, M_TWINE)

# the chalkboard easel, leaning back so its face shows in the oblique view
_cx, _cy0, _tilt, _bw, _bh = 165.0, 10.0, math.radians(40), 32.0, 26.0
_cy1, _cz0 = _cy0 + _bh * math.sin(_tilt), 4.0
_cz1 = _cz0 + _bh * math.cos(_tilt)
_bm = bmesh.new(); _uv = _bm.loops.layers.uv.new('UV')
_vs = [_bm.verts.new(v) for v in ((_cx - _bw / 2, _cy0, _cz0), (_cx + _bw / 2, _cy0, _cz0),
                                   (_cx + _bw / 2, _cy1, _cz1), (_cx - _bw / 2, _cy1, _cz1))]
_f = _bm.faces.new(_vs)
for _lp, _uvv in zip(_f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))): _lp[_uv].uv = _uvv
_me = bpy.data.meshes.new('chalkboard'); _bm.to_mesh(_me); _bm.free(); _me.materials.append(M_CHALK)
link(bpy.data.objects.new('chalkboard', _me))
_frame = [(_cx - _bw / 2, _cy0, _cz0), (_cx + _bw / 2, _cy0, _cz0), (_cx + _bw / 2, _cy1, _cz1), (_cx - _bw / 2, _cy1, _cz1),
          (_cx - _bw / 2, _cy0, _cz0)]
tube3d('chalkFrame', _frame, 1.1, M_WALNUT)
for _sx in (-1, 1):
    _lx = _cx + _sx * (_bw / 2 - 1)
    tube3d(f'easelFront{_sx}', [(_lx, _cy1 + 0.5, _cz1 + 2.5), (_lx, _cy0 - 3, 0)], 0.9, M_WALNUT)
    tube3d(f'easelBack{_sx}', [(_lx, _cy1 + 0.5, _cz1 + 2.5), (_lx, _cy1 + 14, 0)], 0.9, M_WALNUT)
tube3d('chalkLedge', [(_cx - _bw / 2, _cy0 - 1.5, _cz0 - 0.5), (_cx + _bw / 2, _cy0 - 1.5, _cz0 - 0.5)], 0.9, M_WALNUT)
_bx('chalkStick', _cx + 6, _cx + 10, _cy0 - 2.2, _cy0 - 1.2, _cz0 + 0.3, _cz0 + 1.1, M_KEYCAP)

# the brass till: a walnut cash drawer, a brass body, three stepped rows of cream keys, a sale flag window, a crank
_tx0, _tx1, _ty0 = 458.0, 492.0, -8.0
_bx('tillDrawer', _tx0, _tx1, _ty0, 20, 3, 9, M_WALNUT, bevel=0.6)
_bx('tillBody', _tx0 + 2, _tx1 - 2, 4, 20, 9, 25, M_BRASS, bevel=0.8)
for _r, (_ky, _kz) in enumerate(((-5.0, 10.5), (-1.0, 13.0), (3.0, 15.5))):
    _bx(f'tillStep{_r}', _tx0 + 2, _tx1 - 2, _ky - 2.2, _ky + 2.2, 9, _kz - 0.6, M_BRASS_DARK, bevel=0.3)
    for _k in range(6):
        _kx = _tx0 + 6 + _k * 4.4
        cylinder(f'tillKey{_r}{_k}', _kx, _ky, 1.5, _kz - 0.6, _kz + 0.7, M_KEYCAP, verts=16)
_bx('tillFlag', _tx0 + 8, _tx1 - 8, 5, 7, 25, 31, M_KEYCAP)
tube3d('tillFlagFrame', [(_tx0 + 8, 4.6, 25), (_tx0 + 8, 4.6, 31.2), (_tx1 - 8, 4.6, 31.2), (_tx1 - 8, 4.6, 25)], 0.6, M_BRASS)
tube3d('tillCrest', [(_tx0 + 3, 12, 25), (_tx0 + 9, 12, 29), (475, 12, 30.5), (_tx1 - 9, 12, 29), (_tx1 - 3, 12, 25)], 1.0,
       M_BRASS)
tube3d('tillCrank', [(_tx1 - 2, 12, 15), (_tx1 + 4, 12, 15), (_tx1 + 4, 8, 15)], 0.7, M_BRASS)
bpy.ops.mesh.primitive_uv_sphere_add(radius=1.4, location=(_tx1 + 4, 7, 15), segments=12, ring_count=8)
_o = bpy.context.object; _o.name = 'tillKnob'; _o.data.materials.append(M_KEYCAP); SMOOTH.add(_o.name)

# a cup of tea on a gold-rimmed saucer, with a teaspoon and a shortbread biscuit
_qx, _qy = 368.0, 18.0
cylinder('saucer', _qx, _qy, 9.0, 3, 4.3, M_CHINA)
torus('saucerRim', _qx, _qy, 4.3, 8.6, 0.35, M_BRASS)
bpy.ops.mesh.primitive_cone_add(radius1=4.0, radius2=5.8, depth=6.5, location=(_qx, _qy, 4.3 + 3.25), vertices=32)
_o = bpy.context.object; _o.name = 'teacup'; _o.data.materials.append(M_CHINA); SMOOTH.add(_o.name)
cylinder('tea', _qx, _qy, 5.3, 10.5, 10.85, M_TEA)
torus('cupRim', _qx, _qy, 10.8, 5.6, 0.4, M_BRASS)
bpy.ops.mesh.primitive_torus_add(location=(_qx + 6.6, _qy, 8.0), rotation=(math.pi / 2, 0, 0), major_radius=1.9,
                                 minor_radius=0.6, major_segments=24, minor_segments=8)
_o = bpy.context.object; _o.name = 'cupHandle'; _o.data.materials.append(M_CHINA); SMOOTH.add(_o.name)
tube3d('teaspoon', [(_qx - 3, _qy - 6.5, 4.6), (_qx + 5, _qy - 4.5, 4.6)], 0.4, M_BRASS)
bpy.ops.mesh.primitive_uv_sphere_add(radius=1.3, location=(_qx + 5.6, _qy - 4.4, 4.6), segments=12, ring_count=8)
_o = bpy.context.object; _o.name = 'spoonBowl'; _o.scale = (1.4, 1, 0.35); _o.data.materials.append(M_BRASS); SMOOTH.add(_o.name)
cylinder('biscuit', _qx - 3.5, _qy + 4.0, 2.4, 4.3, 5.3, principled('shortbread', (0.85, 0.66, 0.38), rough=0.8), verts=20)

# the counter pieces are modelled small; scale each group 1.5x about its spot on the apron so they read on the phone
from mathutils import Matrix as _Mx
_spots = [(72, 26), (165, 20), (475, 8), (368, 18)]
for _o in [o for o in sc.objects if o.name not in _before_counter and o.type in ('MESH', 'CURVE')]:
    _bb = [_o.matrix_world @ __import__('mathutils').Vector(v) for v in _o.bound_box]
    _ccx = sum(v.x for v in _bb) / 8; _ccy = sum(v.y for v in _bb) / 8
    _ax, _ay = min(_spots, key=lambda p: (p[0] - _ccx) ** 2 + (p[1] - _ccy) ** 2)
    _o.matrix_world = (_Mx.Translation((_ax, _ay, 3)) @ _Mx.Scale(1.5, 4) @ _Mx.Translation((-_ax, -_ay, -3))
                       @ _o.matrix_world)

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

# M9 v34: the fire's light, linked to the fireplace's brick, logs and irons only
_fl = bpy.data.collections.new('fireLit')
for o in sc.objects:
    if o.type == 'MESH' and o.name in FIRE_LIT:
        _fl.objects.link(o)
fire_l = bpy.data.lights.new('fireLight', 'POINT'); fire_l.energy = 18000; fire_l.shadow_soft_size = 8
fire_l.color = (1.0, 0.5, 0.18)
fire_o = link(bpy.data.objects.new('fireLight', fire_l)); fire_o.location = (284, 790 + 14 * K, 14)
fire_o.light_linking.receiver_collection = _fl

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
