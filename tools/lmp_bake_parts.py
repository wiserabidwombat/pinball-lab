"""Table 05 (The Lamplight) M9 v14: the teapot spinner and the plunger, rendered in the table's oblique view and light.

Spinner (across the kettle lane): a thin blade hung from a steel axle between two brass bearings. One face is cream
enamel with a teal teapot, the other polished brass. 24 frames of one turn (frame 0 = hanging), in a 6 × 4 sheet
(lmp_spinner_sheet, row 0 at the top). It's rendered in world orientation (the axle runs 16° up to the right across the
lane; LmpSpinner draws the sprite unrotated) in LmpTableLayout.spinnerArtBox (x -32…32, y -20…28 around the axle's
middle).

Plunger: a cream rubber tip on a brass rod with a dark spring, the lane's plunger seen from above
(lmp_plunger, box LmpTableLayout.plungerArtBox = x -14…14, y -27…35 around the plunger node's centre; the node is the
24 × 50 physics block).

Usage: python3 lmp_bake_parts.py -- out_dir [samples]"""
import bpy, bmesh, math, sys, os
import cairo
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L
from PIL import Image

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
K = L.OBLIQUE
os.makedirs(OUT, exist_ok=True)

# ------------------------------------------------------------------ the spinner's face: a teapot on cream enamel
FACE = os.path.join(OUT, 'spinner_face.png')
fs = cairo.ImageSurface(cairo.FORMAT_RGB24, 460, 100)
c = cairo.Context(fs)
c.set_source_rgb(0.93, 0.89, 0.78); c.paint()
c.set_source_rgb(0.82, 0.64, 0.30); c.set_line_width(5); c.rectangle(6, 6, 448, 88); c.stroke()
c.translate(230, 52); c.scale(1.0, 1.0)
c.set_source_rgb(0.12, 0.38, 0.38)                    # the teapot: body, lid, knob, spout, handle
c.save(); c.scale(46, 30); c.arc(0, 4 / 30, 1, 0, 2 * math.pi); c.restore(); c.fill()
c.rectangle(-26, -32, 52, 8); c.fill()
c.arc(0, -36, 6, 0, 2 * math.pi); c.fill()
c.move_to(40, 0); c.curve_to(62, -4, 70, -18, 82, -30); c.line_to(86, -24); c.curve_to(74, -6, 66, 14, 40, 18)
c.close_path(); c.fill()
c.set_line_width(9); c.arc(-48, 4, 18, math.pi * 0.5, math.pi * 1.5); c.stroke()
c.set_source_rgb(0.93, 0.89, 0.78); c.set_line_width(3)   # a band of little dots round the pot
for i in range(-3, 4):
    c.arc(i * 11, 6, 2.2, 0, 2 * math.pi); c.fill()
fs.write_to_png(FACE)


def setup(box, samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    x0, y0, w, h = box
    sc.render.resolution_x = int(w * L.PX_PER_PT); sc.render.resolution_y = int(h * L.PX_PER_PT)
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.0; sun.angle = math.radians(12)
    sun.color = (1.0, 0.86, 0.66)
    so = bpy.data.objects.new('key', sun); so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.5; fill.angle = math.radians(30)
    fill.color = (0.75, 0.8, 1.0)
    fo = bpy.data.objects.new('fill', fill); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
    sc.collection.objects.link(fo)
    for i, (x, y) in enumerate(((-200, 100), (200, 150), (0, -250))):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x0 + x, y0 + y, 300))
        p = bpy.context.object; p.scale = (300, 300, 1)
        em = bpy.data.materials.new(f'box{i}'); em.use_nodes = True
        nodes = em.node_tree.nodes; nodes.clear()
        o_ = nodes.new('ShaderNodeOutputMaterial'); e_ = nodes.new('ShaderNodeEmission')
        e_.inputs['Strength'].default_value = 1.0; e_.inputs['Color'].default_value = (1.0, 0.85, 0.62, 1)
        em.node_tree.links.new(e_.outputs[0], o_.inputs[0])
        p.data.materials.append(em); p.visible_camera = False; p.visible_shadow = False
    wd = bpy.data.worlds.new('w'); sc.world = wd; wd.use_nodes = True
    wd.node_tree.nodes['Background'].inputs['Color'].default_value = (0.16, 0.11, 0.07, 1)
    wd.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.7
    bpy.ops.mesh.primitive_plane_add(size=1, location=(x0 + w / 2, y0 + h / 2, 0))
    fl = bpy.context.object; fl.scale = (w * 3, h * 3, 1); fl.is_shadow_catcher = True
    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(w, h); cam.clip_end = 3000
    co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co)
    co.location = (x0 + w / 2, y0 + h / 2, 1000); sc.camera = co
    return sc


def mat(name, color, metal=0.0, rough=0.4, coat=0.0, image=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1); b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough; b.inputs['Coat Weight'].default_value = coat
    if image:
        t = m.node_tree.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(image)
        m.node_tree.links.new(t.outputs['Color'], b.inputs['Base Color'])
    return m


def shear_all(names=None):
    """Bakes every mesh's transform and applies the oblique shear (y += z K)."""
    sc = bpy.context.scene
    bpy.ops.object.select_all(action='DESELECT')
    objs = [o for o in sc.objects if o.type in ('MESH', 'CURVE') and not o.is_shadow_catcher
            and (names is None or o.name in names) and o.visible_camera]
    for o in objs: o.select_set(True)
    if not objs: return
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target='MESH')
    for o in bpy.context.selected_objects:
        mw = o.matrix_world.copy(); o.data.transform(mw); o.matrix_world.identity()
        for v in o.data.vertices: v.co.y += v.co.z * K
        for p in o.data.polygons: p.use_smooth = o.get('smooth', False)


# ------------------------------------------------------------------ spinner
a = L.kettle_point(-90, L.KETTLE_HALF_W); b = L.kettle_point(-90, -L.KETTLE_HALF_W)
mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
ax = ((b[0] - a[0]), (b[1] - a[1])); al = math.hypot(*ax); ax = (ax[0] / al, ax[1] / al)       # along the axle
up = L.kettle_axis(); ul = math.hypot(*up); up = (up[0] / ul, up[1] / ul)                    # up the lane
SPIN_BOX = (-32.0, -20.0, 64.0, 48.0)
AXLE_Z, BLADE_HALF, BLADE_DEPTH = 13.0, 23.0, 10.5

frames = []
for i in range(24):
    sc = setup(SPIN_BOX, SAMPLES)
    brass = mat('brass', (0.88, 0.66, 0.32), metal=1.0, rough=0.25)
    steel = mat('steel', (0.75, 0.76, 0.78), metal=1.0, rough=0.3)
    face = mat('face', (1, 1, 1), rough=0.3, coat=0.5, image=FACE)
    th = 2 * math.pi * i / 24
    # blade direction from the axle: hanging straight down at frame 0, swinging up the lane as it turns
    d = (math.sin(th) * up[0], math.sin(th) * up[1], -math.cos(th))
    n = (math.cos(th) * up[0], math.cos(th) * up[1], math.sin(th))          # the face's normal (toward the player at 0)
    n = (-n[0], -n[1], -n[2])
    for side, m_, off in ((1, face, 0.45), (-1, brass, -0.45)):
        bm = bmesh.new(); uvl = bm.loops.layers.uv.new()
        pts = []
        for s_, t_ in ((-1, 0), (1, 0), (1, 1), (-1, 1)):
            x = s_ * BLADE_HALF * ax[0] + t_ * BLADE_DEPTH * d[0] + off * n[0]
            y = s_ * BLADE_HALF * ax[1] + t_ * BLADE_DEPTH * d[1] + off * n[1]
            z = AXLE_Z + t_ * BLADE_DEPTH * d[2] + off * n[2]
            pts.append(bm.verts.new((x, y + z * K, z)))
        f = bm.faces.new(pts if side > 0 else list(reversed(pts)))
        for loop, uv in zip(f.loops, ((0, 1), (1, 1), (1, 0), (0, 0)) if side > 0 else ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop[uvl].uv = uv
        me = bpy.data.meshes.new(f'blade{side}'); bm.to_mesh(me); bm.free(); me.materials.append(m_)
        sc.collection.objects.link(bpy.data.objects.new(f'blade{side}', me))
    # the blade's brass edge and the axle, the bearings at the lane's walls
    cu = bpy.data.curves.new('edge', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = 0.7; cu.bevel_resolution = 2
    sp = cu.splines.new('POLY'); edge = []
    for s_, t_ in ((-1, 0), (-1, 1), (1, 1), (1, 0)):
        edge.append((s_ * BLADE_HALF * ax[0] + t_ * BLADE_DEPTH * d[0], s_ * BLADE_HALF * ax[1] + t_ * BLADE_DEPTH * d[1],
                     AXLE_Z + t_ * BLADE_DEPTH * d[2]))
    sp.points.add(len(edge) - 1)
    for k, (x, y, z) in enumerate(edge): sp.points[k].co = (x, y, z, 1)
    cu.materials.append(brass); o = bpy.data.objects.new('edge', cu); o['smooth'] = True; sc.collection.objects.link(o)
    cu = bpy.data.curves.new('axle', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = 0.9; cu.bevel_resolution = 2
    sp = cu.splines.new('POLY'); sp.points.add(1)
    sp.points[0].co = (-27 * ax[0], -27 * ax[1], AXLE_Z, 1); sp.points[1].co = (27 * ax[0], 27 * ax[1], AXLE_Z, 1)
    cu.materials.append(steel); o = bpy.data.objects.new('axle', cu); o['smooth'] = True; sc.collection.objects.link(o)
    for s_ in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=2.6, location=(s_ * 26.5 * ax[0], s_ * 26.5 * ax[1], AXLE_Z),
                                             segments=24, ring_count=12)
        o = bpy.context.object; o.data.materials.append(brass); o['smooth'] = True
    shear_all({o.name for o in sc.objects if o.name.startswith(('edge', 'axle', 'Sphere'))})
    path = os.path.join(OUT, f'spin_{i:02d}.png'); sc.render.filepath = path
    bpy.ops.render.render(write_still=True); frames.append(path)
    print('frame', i)

cols, rows = 6, 4
fw, fh = Image.open(frames[0]).size
sheet = Image.new('RGBA', (fw * cols, fh * rows), (0, 0, 0, 0))
for i, p in enumerate(frames):
    sheet.paste(Image.open(p), ((i % cols) * fw, (i // cols) * fh))
sheet.save(os.path.join(OUT, 'lmp_spinner_sheet.png'))
print('sheet', sheet.size)

# ------------------------------------------------------------------ plunger
PL_BOX = (-14.0, -27.0, 28.0, 62.0)
sc = setup(PL_BOX, SAMPLES)
brass = mat('brass', (0.88, 0.66, 0.32), metal=1.0, rough=0.25)
rubber = mat('rubber', (0.96, 0.93, 0.85), rough=0.5)
spring = mat('spring', (0.20, 0.18, 0.16), metal=1.0, rough=0.35)
Z = 9.0
bpy.ops.mesh.primitive_cylinder_add(radius=9.0, depth=9.0, location=(0, 20.5, Z), rotation=(math.pi / 2, 0, 0),
                                    vertices=48)
o = bpy.context.object; o.data.materials.append(rubber); o['smooth'] = True
bv = o.modifiers.new('b', 'BEVEL'); bv.width = 2.0; bv.segments = 4
bpy.ops.mesh.primitive_cylinder_add(radius=6.0, depth=2.0, location=(0, 15.0, Z), rotation=(math.pi / 2, 0, 0), vertices=32)
o = bpy.context.object; o.data.materials.append(brass); o['smooth'] = True
bpy.ops.mesh.primitive_cylinder_add(radius=2.6, depth=40.0, location=(0, -6.0, Z), rotation=(math.pi / 2, 0, 0), vertices=24)
o = bpy.context.object; o.data.materials.append(brass); o['smooth'] = True
cu = bpy.data.curves.new('spring', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = 0.9; cu.bevel_resolution = 2
sp = cu.splines.new('POLY'); pts = []
for k in range(0, 9 * 24 + 1):
    t = k / 24 * 2 * math.pi
    pts.append((5.0 * math.cos(t), -24 + 34 * k / (9 * 24), Z + 5.0 * math.sin(t)))
sp.points.add(len(pts) - 1)
for k, (x, y, z) in enumerate(pts): sp.points[k].co = (x, y, z, 1)
cu.materials.append(spring); o = bpy.data.objects.new('spring', cu); o['smooth'] = True; sc.collection.objects.link(o)
shear_all()
sc.render.filepath = os.path.join(OUT, 'lmp_plunger.png')
bpy.ops.render.render(write_still=True)
print('plunger done')
