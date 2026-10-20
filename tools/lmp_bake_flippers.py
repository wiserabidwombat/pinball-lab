"""Table 05 (The Lamplight) M9 v7: the flippers, rendered straight top-down (no oblique lean: the sprite rotates with the
physics). A polished walnut arm with a cream rubber band round its edge and a domed brass pivot cap, lit softly from
overhead so the light still looks right at any angle. Left flipper pointing right, pivot at (0, 0), image box
x -18…114, y -18…18 (LmpFlipper: 132 × 36 pt around the pivot, anchor 18/132); the right flipper is its mirror image.
Usage: python3 lmp_bake_flippers.py -- out_dir [samples]"""
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 96
LEN, R0, R1 = 96.0, 12.0, 6.0             # LmpTableLayout.flipperLength / flipperPivotRadius / flipperTipRadius
BX0, BY0, BW, BH = -18.0, -18.0, 132.0, 36.0

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
sc.render.resolution_x = int(BW * L.PX_PER_PT); sc.render.resolution_y = int(BH * L.PX_PER_PT)
sc.render.film_transparent = True
sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'


def principled(name, color, metal=0.0, rough=0.4, coat=0.0, spec=0.5):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1); b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough; b.inputs['Coat Weight'].default_value = coat
    b.inputs['Specular IOR Level'].default_value = spec
    return m


def wood(name, dark, light):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord')
    wave = nt.nodes.new('ShaderNodeTexWave'); wave.wave_type = 'BANDS'; wave.bands_direction = 'Y'
    wave.inputs['Scale'].default_value = 0.22; wave.inputs['Distortion'].default_value = 2.5
    wave.inputs['Detail'].default_value = 3
    nt.links.new(tc.outputs['Object'], wave.inputs['Vector'])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (*dark, 1); ramp.color_ramp.elements[1].color = (*light, 1)
    nt.links.new(wave.outputs['Fac'], ramp.inputs['Fac']); nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.35; b.inputs['Coat Weight'].default_value = 0.5
    b.inputs['Coat Roughness'].default_value = 0.15
    return m


# M9 v16 (Aaron: the flippers blend into the floor; walnut on oak measured 2.1 : 1, 1.15 : 1 by the slate hearth): an
# ivory enamel arm with an oxblood rubber, like a real flipper's white plastic, reads on any part of the floor.
M_WALNUT = principled('ivory', (0.93, 0.89, 0.80), rough=0.3, coat=0.6, spec=0.5)
M_RUBBER = principled('rubber', (0.42, 0.06, 0.05), rough=0.55, spec=0.3)
M_BRASS = principled('brass', (0.88, 0.66, 0.32), metal=1.0, rough=0.22)


def outline(inset, n=40):
    """The tapered capsule (pivot circle r0 at 0, tip circle r1 at LEN), shrunk by `inset`, counter-clockwise."""
    r0, r1 = R0 - inset, R1 - inset
    a = math.asin((R0 - R1) / LEN)                   # the flanks' tilt from horizontal
    pts = []
    for i in range(n + 1):                           # tip cap: from the lower flank round to the upper flank
        t = -math.pi / 2 + a + (math.pi - 2 * a) * i / n
        pts.append((LEN + r1 * math.cos(t), r1 * math.sin(t)))
    for i in range(n + 1):                           # pivot cap: from the upper flank round the back to the lower
        t = math.pi / 2 - a + (math.pi + 2 * a) * i / n
        pts.append((r0 * math.cos(t), r0 * math.sin(t)))
    return pts


def prism(name, pts, z0, z1, mat):
    bm = bmesh.new()
    face = bm.faces.new([bm.verts.new((x, y, z0)) for x, y in pts])
    if face.normal.z < 0: face.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)]: v.co.z = z1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(mat)
    o = bpy.data.objects.new(name, me); sc.collection.objects.link(o)
    bev = o.modifiers.new('b', 'BEVEL'); bev.width = 1.2; bev.segments = 3; bev.limit_method = 'ANGLE'
    return o


body = prism('arm', outline(3.0), 0, 5.0, M_WALNUT)
cu = bpy.data.curves.new('rubber', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = 2.3; cu.bevel_resolution = 4
sp = cu.splines.new('POLY'); ring = outline(2.0)
sp.points.add(len(ring) - 1)
for i, (x, y) in enumerate(ring): sp.points[i].co = (x, y, 4.0, 1)
sp.use_cyclic_u = True; cu.materials.append(M_RUBBER)
sc.collection.objects.link(bpy.data.objects.new('rubber', cu))
bpy.ops.mesh.primitive_cylinder_add(radius=5.2, depth=1.6, location=(0, 0, 5.6), vertices=48)
bpy.context.object.data.materials.append(M_BRASS)
bpy.ops.mesh.primitive_uv_sphere_add(radius=4.4, location=(0, 0, 6.4), segments=48, ring_count=16)
cap = bpy.context.object; cap.scale = (1, 1, 0.45); cap.data.materials.append(M_BRASS)
for o in sc.objects:
    if o.type == 'MESH' and o.name != 'arm':
        for p in o.data.polygons: p.use_smooth = True

# soft light from overhead, a little warm, plus warm soft boxes round about for the brass and the coat to catch
key = bpy.data.lights.new('key', 'AREA'); key.energy = 22000; key.size = 260; key.color = (1.0, 0.9, 0.75)
ko = bpy.data.objects.new('key', key); ko.location = (48, 40, 260); sc.collection.objects.link(ko)
for i, (x, y) in enumerate(((-150, 60), (250, 60), (48, -150), (48, 200))):
    bpy.ops.mesh.primitive_plane_add(size=1, location=(x, y, 120))
    p = bpy.context.object; p.scale = (160, 160, 1)
    em = bpy.data.materials.new(f'box{i}'); em.use_nodes = True
    nodes = em.node_tree.nodes; nodes.clear()
    o_ = nodes.new('ShaderNodeOutputMaterial'); e_ = nodes.new('ShaderNodeEmission')
    e_.inputs['Strength'].default_value = 1.2; e_.inputs['Color'].default_value = (1.0, 0.85, 0.62, 1)
    em.node_tree.links.new(e_.outputs[0], o_.inputs[0])
    p.data.materials.append(em); p.visible_camera = False; p.visible_shadow = False
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.10, 0.07, 0.05, 1)
w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.8

cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = BW; cam.clip_end = 3000
co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co)
co.location = (BX0 + BW / 2, BY0 + BH / 2, 1000); sc.camera = co
os.makedirs(OUT, exist_ok=True)
left = os.path.join(OUT, 'lmp_flipper_left.png')
sc.render.filepath = left
bpy.ops.render.render(write_still=True)
from PIL import Image
Image.open(left).transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(OUT, 'lmp_flipper_right.png'))
print('rendered', left, 'and its mirror')
