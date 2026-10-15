"""Table 03 milestone 2: renders the lower table in Blender (Cycles) into one baked image.
Floor (printed art from cth_floor_lower.py) + apron plates + cabinet wood + chrome rails, wire lane guides,
posts with rubber rings, slingshot rubbers and plastics, all lit by one sun from the top left.
Oblique view: every vertex at height z is moved y += z * OBLIQUE before an orthographic top-down
render, so the floor lines up exactly with the physics and raised parts show their front (player) side.
1 Blender unit = 1 world point.
Usage: python3 cth_render_lower.py -- floor.png apron.png out.png [scale] [samples]"""
import bpy, bmesh, math, sys, os
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
FLOOR, APRON, OUT = (os.path.abspath(a) for a in argv[:3])
SCALE = float(argv[3]) if len(argv) > 3 else 1.0          # 1.0 = full PX_PER_PT
SAMPLES = int(argv[4]) if len(argv) > 4 else 64
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
def principled(name, color, metal=0.0, rough=0.4, coat=0.0, alpha=1.0, trans=0.0, image=None, spec=0.5, coat_rough=0.03):
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
    if image:
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(image)
        tex.interpolation = 'Cubic'
        nt.links.new(tex.outputs['Color'], b.inputs['Base Color'])
    return m


def wood(name, dark, light):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    wave = nt.nodes.new('ShaderNodeTexWave')
    wave.wave_type = 'BANDS'; wave.bands_direction = 'Y'
    wave.inputs['Scale'].default_value = 0.22
    wave.inputs['Distortion'].default_value = 9
    wave.inputs['Detail'].default_value = 3
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*light, 1)
    nt.links.new(wave.outputs['Fac'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.6
    b.inputs['Coat Weight'].default_value = 0.12
    b.inputs['Coat Roughness'].default_value = 0.35
    return m


M_FLOOR = principled('floor', (1, 1, 1), rough=0.5, coat=0.12, coat_rough=0.45, spec=0.22, image=FLOOR)
M_APRON = principled('apron', (1, 1, 1), rough=0.5, coat=0.1, coat_rough=0.45, spec=0.25, image=APRON)
M_CHROME = principled('chrome', (0.92, 0.93, 0.95), metal=1.0, rough=0.12)
M_STEEL = principled('steel', (0.7, 0.72, 0.75), metal=1.0, rough=0.28)
M_BRASS = principled('brass', (0.86, 0.64, 0.30), metal=1.0, rough=0.22)
M_RUBBER = principled('rubber', (0.93, 0.92, 0.88), rough=0.55, spec=0.3)      # white rubbers
M_RUBBER_DARK = principled('rubberdark', (0.03, 0.03, 0.035), rough=0.5, spec=0.3)
M_WOOD = wood('wood', (0.025, 0.012, 0.006), (0.10, 0.048, 0.022))
M_PLASTIC = principled('plastic', (0.04, 0.30, 0.27), rough=0.12, coat=0.5, coat_rough=0.1, alpha=0.93, trans=0.15)
M_PLASTIC_RIM = principled('plasticrim', (0.85, 0.66, 0.28), metal=0.8, rough=0.25)
M_BLACK = principled('black', (0.01, 0.01, 0.012), rough=0.6)


# ------------------------------------------------------------------ geometry helpers
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
    """A flat polygon (world xy) extruded from z0 to z1."""
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


def tube(name, pts, z, r, mat, closed=False, res=8):
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = r; cu.bevel_resolution = 3; cu.use_fill_caps = True
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for i, (x, y) in enumerate(pts):
        sp.points[i].co = (x, y, z, 1)
    sp.use_cyclic_u = closed
    cu.materials.append(mat)
    return link(bpy.data.objects.new(name, cu))


def cylinder(name, x, y, r, z0, z1, mat, verts=32):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=z1 - z0, location=(x, y, (z0 + z1) / 2), vertices=verts)
    o = bpy.context.object; o.name = name; o.data.materials.append(mat)
    bev = o.modifiers.new('b', 'BEVEL'); bev.width = min(r * 0.25, 1.2); bev.segments = 3
    return o


def torus(name, x, y, z, major, minor, mat):
    bpy.ops.mesh.primitive_torus_add(location=(x, y, z), major_radius=major, minor_radius=minor,
                                     major_segments=40, minor_segments=12)
    o = bpy.context.object; o.name = name; o.data.materials.append(mat)
    return o


def wall_strip(name, pts, thick, z1, mat):
    """A thin upright wall along a polyline (one box per segment)."""
    objs = []
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        dx, dy = b[0] - a[0], b[1] - a[1]; ln = math.hypot(dx, dy)
        if ln < 0.01: continue
        nx, ny = -dy / ln * thick / 2, dx / ln * thick / 2
        quad = [(a[0] + nx, a[1] + ny), (b[0] + nx, b[1] + ny), (b[0] - nx, b[1] - ny), (a[0] - nx, a[1] - ny)]
        objs.append(prism(f'{name}{i}', quad, 0, z1, mat))
    return objs


def post(name, x, y, ring_r, h=20):
    """Chrome post with a brass cap and a white rubber ring whose outer edge is ring_r."""
    cylinder(name, x, y, 3.2, 0, h, M_CHROME)
    cylinder(name + 'cap', x, y, 4.2, h, h + 2.2, M_BRASS)
    torus(name + 'ring', x, y, 7, ring_r - 2.0, 2.0, M_RUBBER)


def offset_loop(pts, d):
    """Offsets a closed counter-clockwise polygon outward by d (miter joins)."""
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
# floor
prism('floor', [(X0, Y0), (X0 + RW, Y0), (X0 + RW, Y0 + RH), (X0, Y0 + RH)], -2, 0, M_FLOOR, uv=True)

# apron plates (3 pt high), below the slopes; the right one also covers under the plunger lane
left_apron = [(12, L.APRON_TOP_Y + 3), (L.LEFT_X, L.APRON_TOP_Y), (L.DRAIN_X, L.DRAIN_Y), (L.DRAIN_X, Y0), (12, Y0)]
right_apron = [(L.LANE_X, L.APRON_TOP_Y), (L.MIRROR - L.DRAIN_X, L.DRAIN_Y), (L.MIRROR - L.DRAIN_X, Y0),
               (588, Y0), (588, L.LANE_FLOOR_Y), (L.LANE_X, L.LANE_FLOOR_Y)]
prism('apronL', ccw(left_apron), 0, 3, M_APRON, uv=True)
prism('apronR', ccw(right_apron), 0, 3, M_APRON, uv=True)
# chrome lip along each slope edge
tube('lipL', [(L.LEFT_X, L.APRON_TOP_Y), (L.DRAIN_X, L.DRAIN_Y), (L.DRAIN_X, L.DRAIN_LIP_Y)], 4.5, 2.4, M_CHROME)
tube('lipR', L.right_apron(), 4.5, 2.4, M_CHROME)

# cabinet: wooden side boards and the front board, with a chrome rail on top of each inner edge
CAB_H = 34
prism('cabL', [(X0, Y0), (12, Y0), (12, Y0 + RH + 40), (X0, Y0 + RH + 40)], 0, CAB_H, M_WOOD)
prism('cabR', [(588, Y0), (X0 + RW, Y0), (X0 + RW, Y0 + RH + 40), (588, Y0 + RH + 40)], 0, CAB_H, M_WOOD)
prism('cabFront', [(X0, Y0 - 40), (X0 + RW, Y0 - 40), (X0 + RW, Y0 - 12), (X0, Y0 - 12)], 0, CAB_H, M_WOOD)
tube('railL', [(10, Y0 - 12), (10, Y0 + RH + 40)], CAB_H + 1.5, 3.2, M_CHROME)
tube('railR', [(590, Y0 - 12), (590, Y0 + RH + 40)], CAB_H + 1.5, 3.2, M_CHROME)

# playfield side walls: the strip between floor and cabinet (x 12..20 and 580..588), painted black with a chrome top
prism('sideL', [(12, L.APRON_TOP_Y), (L.LEFT_X, L.APRON_TOP_Y), (L.LEFT_X, Y0 + RH + 40), (12, Y0 + RH + 40)], 0, 18, M_BLACK)
prism('sideR', [(L.RIGHT_X, L.LANE_FLOOR_Y), (588, L.LANE_FLOOR_Y), (588, Y0 + RH + 40), (L.RIGHT_X, Y0 + RH + 40)], 0, 18, M_BLACK)
tube('sideLtop', [(16, L.APRON_TOP_Y), (16, Y0 + RH + 40)], 18.5, 2.0, M_STEEL)
tube('sideRtop', [(584, L.LANE_FLOOR_Y), (584, Y0 + RH + 40)], 18.5, 2.0, M_STEEL)

# shooter-lane wall (x 548) from the lane floor up: a black wall with a steel top rail
wall_strip('lanewall', [(L.LANE_X + 2, L.LANE_FLOOR_Y), (L.LANE_X + 2, Y0 + RH + 40)], 4, 16, M_BLACK)
tube('lanewallTop', [(L.LANE_X + 2, L.LANE_FLOOR_Y), (L.LANE_X + 2, Y0 + RH + 40)], 16.5, 2.0, M_STEEL)
# shooter-lane floor stop behind the plunger
prism('laneStop', [(L.LANE_X + 2, L.LANE_FLOOR_Y - 6), (L.RIGHT_X, L.LANE_FLOOR_Y - 6),
                   (L.RIGHT_X, L.LANE_FLOOR_Y), (L.LANE_X + 2, L.LANE_FLOOR_Y)], 0, 10, M_STEEL)

# wire lane guides (inlane/outlane separators and the outlane walls): steel wire on short posts
for side, guide in (('L', L.left_lane_guide()), ('R', L.right_lane_guide())):
    tube('guide' + side, guide, 9, 2.2, M_STEEL)
    tube('guideLow' + side, guide, 3, 1.6, M_STEEL)
ol, orr = L.outlane_walls()
tube('outlaneL', ol, 9, 2.2, M_STEEL); tube('outlaneLlow', ol, 3, 1.6, M_STEEL)
tube('outlaneR', orr, 9, 2.2, M_STEEL); tube('outlaneRlow', orr, 3, 1.6, M_STEEL)
for side, (x, y) in [('L', (L.LANE_GUIDE_X, L.LANE_GUIDE_TOP)), ('R', L.mirrored((L.LANE_GUIDE_X, L.LANE_GUIDE_TOP)))]:
    post('guideTop' + side, x, y, 6.5, h=18)
for side, (x, y) in [('L', (L.LANE_GUIDE_X, L.OUTLANE_WALL_BOTTOM)), ('R', L.mirrored((L.LANE_GUIDE_X, L.OUTLANE_WALL_BOTTOM)))]:
    cylinder('outlanePost' + side, x, y, 3.0, 0, 12, M_CHROME)

# slingshots: posts with rubber rings at the top and tip, a plain post at the corner, the rubber
# band round all three, and a translucent sea-green plastic on top held by the posts
for side, s in (('L', L.SLING_L), ('R', L.sling_right())):
    top, corner, tip = s['top'], s['corner'], s['tip']
    post('slingTop' + side, *top, L.SLING_TOP_POST_R)
    post('slingTip' + side, *tip, L.SLING_TIP_POST_R)
    post('slingCorner' + side, *corner, 5.5)
    tri = ccw([top, corner, tip])
    band = offset_loop(tri, 3.5)
    tube('band' + side, band, 7, 2.4, M_RUBBER, closed=True)
    plastic = offset_loop(tri, 5)
    prism('plastic' + side, plastic, 21, 23, M_PLASTIC)
    tube('plasticRim' + side, offset_loop(tri, 4.2), 23.2, 1.0, M_PLASTIC_RIM, closed=True)
    for (px, py) in (top, tip, corner):
        cylinder('screw' + side + str(px), px, py, 2.6, 23, 24.6, M_BRASS)

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
    if o.type == 'MESH':
        for p in o.data.polygons: p.use_smooth = True

# ------------------------------------------------------------------ light, world, camera
sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.4; sun.angle = math.radians(9)
so = link(bpy.data.objects.new('key', sun))
# light from the top left of the table (up-table and left), falling down-right
so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.6; fill.angle = math.radians(30)
fo = link(bpy.data.objects.new('fill', fill)); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
# soft boxes above the table for chrome to reflect (invisible to the camera)
for i, (x, y, w, h, e) in enumerate([(-200, 900, 500, 900, 2.6), (800, 300, 300, 600, 1.1), (284, -400, 900, 200, 1.2)]):
    bpy.ops.mesh.primitive_plane_add(size=1, location=(x, y, 700))
    p = bpy.context.object; p.scale = (w, h, 1)
    em = bpy.data.materials.new(f'box{i}'); em.use_nodes = True
    nodes = em.node_tree.nodes; nodes.clear()
    o_ = nodes.new('ShaderNodeOutputMaterial'); e_ = nodes.new('ShaderNodeEmission')
    e_.inputs['Strength'].default_value = e; em.node_tree.links.new(e_.outputs[0], o_.inputs[0])
    p.data.materials.append(em); p.visible_camera = False; p.visible_shadow = False
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.05, 0.07, 0.08, 1)
w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6

cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(RW, RH)
cam.clip_end = 5000
co = link(bpy.data.objects.new('cam', cam))
co.location = (X0 + RW / 2, Y0 + RH / 2, 1500); co.rotation_euler = (0, 0, 0)
sc.camera = co

sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print('rendered', OUT, sc.render.resolution_x, sc.render.resolution_y)
