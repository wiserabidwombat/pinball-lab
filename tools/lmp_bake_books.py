"""Table 05 (The Lamplight) M9 v8: the four book targets of the bookshelf bank, rendered as books standing with their
spines toward the player, each its own colour, plus each one sunk flush in its slot (dropped). Oblique view like the
table (y += z * OBLIQUE), same light, a shadow-catcher floor so the standing books cast their shadow in the image.
Image box = LmpTableLayout.targetArtBox (x -15…15, y -8…16 around the target's centre; the physics plate is 26 × 12).
Writes lmp_target_<i>.png and lmp_target_<i>_down.png, i = 0…3 left to right.
Usage: python3 lmp_bake_books.py -- out_dir [samples]"""
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
BX0, BY0, BW, BH = -15.0, -8.0, 30.0, 24.0
K = L.OBLIQUE
W2, D2, H = 12.0, 5.0, 24.0                     # half width, half depth, height
COLOURS = [(0.36, 0.06, 0.05), (0.08, 0.24, 0.15), (0.07, 0.11, 0.30), (0.62, 0.42, 0.08)]   # oxblood, green, navy, mustard


def build(colour, sunk):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
    sc.render.resolution_x = int(BW * L.PX_PER_PT); sc.render.resolution_y = int(BH * L.PX_PER_PT)
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'

    def mat(name, color, metal=0.0, rough=0.5, coat=0.0):
        m = bpy.data.materials.new(name); m.use_nodes = True
        b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = (*color, 1); b.inputs['Metallic'].default_value = metal
        b.inputs['Roughness'].default_value = rough; b.inputs['Coat Weight'].default_value = coat
        return m

    cloth = mat('cloth', colour, rough=0.65, coat=0.1)
    gold = mat('gold', (0.90, 0.70, 0.34), metal=1.0, rough=0.3)
    pages = mat('pages', (0.84, 0.78, 0.64), rough=0.8)
    label = mat('label', tuple(min(1, c * 0.55) for c in colour), rough=0.6)
    dark = mat('slot', (0.03, 0.02, 0.015), rough=0.9)
    z0 = -H + 1.0 if sunk else 0.0

    def box(name, x0, x1, y0, y1, za, zb, m, bevel=0.0):
        bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (za + zb) / 2))
        o = bpy.context.object; o.name = name; o.scale = (x1 - x0, y1 - y0, zb - za); o.data.materials.append(m)
        bpy.ops.object.transform_apply(scale=True)
        if bevel:
            bv = o.modifiers.new('b', 'BEVEL'); bv.width = bevel; bv.segments = 3
        return o

    box('book', -W2, W2, -D2, D2, z0, z0 + H, cloth, bevel=0.8)
    box('pages', -W2 + 1.8, W2 - 1.8, -D2 + 1.8, D2 - 0.9, z0 + H - 0.4, z0 + H + 0.15, pages)
    for zz in (3.0, H - 3.5):                                     # gilt bands across the spine
        box(f'band{zz}', -W2 + 1.0, W2 - 1.0, -D2 - 0.25, -D2 + 0.4, z0 + zz, z0 + zz + 0.9, gold)
    box('label', -W2 + 3.0, W2 - 3.0, -D2 - 0.2, -D2 + 0.4, z0 + 8.5, z0 + 14.5, label)
    for xx in (-4.5, 0.0, 4.5):                                    # gilt title dashes on the label
        box(f'title{xx}', xx - 1.6, xx + 1.6, -D2 - 0.3, -D2 + 0.3, z0 + 11.2, z0 + 11.8, gold)
    if sunk:                                                       # the slot's dark lip round the sunk book
        bm = bmesh.new()
        outer = [(-W2 - 1.5, -D2 - 1.5), (W2 + 1.5, -D2 - 1.5), (W2 + 1.5, D2 + 1.5), (-W2 - 1.5, D2 + 1.5)]
        inner = [(-W2, -D2), (W2, -D2), (W2, D2), (-W2, D2)]
        vo = [bm.verts.new((x, y, 0.05)) for x, y in outer]; vi = [bm.verts.new((x, y, 0.05)) for x, y in inner]
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new([vo[i], vo[j], vi[j], vi[i]])
        me = bpy.data.meshes.new('lip'); bm.to_mesh(me); bm.free(); me.materials.append(dark)
        sc.collection.objects.link(bpy.data.objects.new('lip', me))

    # oblique shear
    bpy.ops.object.select_all(action='DESELECT')
    for o in sc.objects:
        if o.type == 'MESH': o.select_set(True)
    bpy.context.view_layer.objects.active = next(o for o in sc.objects if o.type == 'MESH')
    bpy.ops.object.convert(target='MESH')
    for o in sc.objects:
        if o.type != 'MESH': continue
        mw = o.matrix_world.copy(); o.data.transform(mw); o.matrix_world.identity()
        for v in o.data.vertices: v.co.y += v.co.z * K

    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
    bpy.context.object.is_shadow_catcher = True

    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.0; sun.angle = math.radians(12); sun.color = (1.0, 0.86, 0.66)
    so = bpy.data.objects.new('key', sun); so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.5; fill.angle = math.radians(30); fill.color = (0.75, 0.8, 1.0)
    fo = bpy.data.objects.new('fill', fill); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
    sc.collection.objects.link(fo)
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.20, 0.14, 0.09, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.8

    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(BW, BH); cam.clip_end = 3000
    co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co)
    co.location = (BX0 + BW / 2, BY0 + BH / 2, 1000); sc.camera = co
    return sc


os.makedirs(OUT, exist_ok=True)
for i, c in enumerate(COLOURS):
    for sunk in (False, True):
        sc = build(c, sunk)
        path = os.path.join(OUT, f'lmp_target_{i}{"_down" if sunk else ""}.png')
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print('rendered', path)
