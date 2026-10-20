"""Table 05 (The Lamplight) M9 v23: the four drop targets as the panels of a wrought-iron fire screen in front of the
fireplace (Aaron: books in front of the fire felt wrong). Each panel: a black iron frame with an arched crest and a brass
front edge, three uprights and a pair of scrolls, little feet and a brass knob; a fine wire mesh lets the fire painted in
the table art glow through. No shadow catcher (the fire lights it from behind; a cast shadow would be cut by the box). Dropped: sunk into a dark slot in the hearth so only the top bar and knob show.
Oblique view (y += z * OBLIQUE), the table's light, a shadow-catcher floor. Image box = LmpTableLayout.targetArtBox
(x -15…15, y -8…16 round the target). Writes lmp_target_<i>.png and lmp_target_<i>_down.png, i = 0…3 (all four alike;
the game picks them by index, as it did the books).
Usage: python3 lmp_bake_firescreen.py -- out_dir [samples]"""
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
BX0, BY0, BW, BH = -15.0, -8.0, 30.0, 24.0
K = L.OBLIQUE
HW, H = 11.5, 25.0                       # half width, frame height


def build(sunk):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
    sc.render.resolution_x = int(BW * L.PX_PER_PT); sc.render.resolution_y = int(BH * L.PX_PER_PT)
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'

    def mat(name, color, metal=0.0, rough=0.5):
        m = bpy.data.materials.new(name); m.use_nodes = True
        b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = (*color, 1); b.inputs['Metallic'].default_value = metal
        b.inputs['Roughness'].default_value = rough
        return m

    iron = mat('iron', (0.07, 0.065, 0.06), metal=0.6, rough=0.45)
    brass = mat('brass', (0.90, 0.68, 0.33), metal=1.0, rough=0.22)
    dark = mat('slot', (0.03, 0.02, 0.015), rough=0.9)
    z0 = -H + 1.2 if sunk else 0.0

    def tube(pts, r, m):
        cu = bpy.data.curves.new('t', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = r; cu.bevel_resolution = 3
        cu.use_fill_caps = True
        sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
        for i, p in enumerate(pts): sp.points[i].co = (p[0], p[1], p[2] + z0, 1)
        cu.materials.append(m)
        sc.collection.objects.link(bpy.data.objects.new('t', cu))

    def arc(cx, cz, r, a0, a1, y=0.0, n=20):
        return [(cx + r * math.cos(a0 + (a1 - a0) * i / n), y, cz + r * math.sin(a0 + (a1 - a0) * i / n))
                for i in range(n + 1)]

    # the frame: two posts, a bottom rail, a top rail and an arched crest over it
    tube([(-HW, 0, 0), (-HW, 0, H)], 0.9, iron)
    tube([(HW, 0, 0), (HW, 0, H)], 0.9, iron)
    tube([(-HW, 0, 2.0), (HW, 0, 2.0)], 0.7, iron)
    tube([(-HW, 0, H - 3), (HW, 0, H - 3)], 0.7, iron)
    crest = [(x, y, z * 0 + (H - 3) + (z - (H - 3)) * 0.35) for x, y, z in arc(0, H - 3, HW, math.pi, 0, n=28)]
    tube(crest, 0.75, iron)                                          # flattened arch: a low crest
    # brass edge along the front of the posts and crest
    tube([(-HW, -0.95, 0.5), (-HW, -0.95, H - 3)], 0.3, brass)
    tube([(HW, -0.95, 0.5), (HW, -0.95, H - 3)], 0.3, brass)
    tube([(x, -0.95, z) for x, y, z in crest], 0.3, brass)
    # uprights and scrolls inside
    mesh = mat('mesh', (0.05, 0.045, 0.04), metal=0.5, rough=0.6)
    mesh.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value = 0.38
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0.3, (2.0 + H - 3) / 2 + z0), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.object; o.scale = (2 * HW, H - 5, 1); o.data.materials.append(mesh)   # the fine wire mesh
    for x in (-6.0, 0.0, 6.0):
        tube([(x, 0, 2.0), (x, 0, H - 3)], 0.45, iron)
    for sx in (-1, 1):
        tube(arc(sx * 3.0, 11.5, 2.6, 0, 2 * math.pi * 0.85, n=24), 0.4, iron)
        tube(arc(sx * 3.0, 11.5, 1.2, 0, 2 * math.pi * 0.8, n=16), 0.35, iron)
        tube(arc(sx * 8.8, 15.5, 1.6, 0, 2 * math.pi * 0.8, n=16), 0.35, iron)
    # feet and the knob
    for x in (-HW, HW):
        tube([(x - 1.8, 0, 0.4), (x + 1.8, 0, 0.4)], 0.6, iron)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.5, location=(0, 0, H - 3 + HW * 0.35 + 1.4 + z0), segments=24, ring_count=12)
    o = bpy.context.object; o.data.materials.append(brass)
    for p in o.data.polygons: p.use_smooth = True

    if sunk:                                                         # the slot's dark lip in the hearth
        bm = bmesh.new()
        outer = [(-HW - 2, -2.5), (HW + 2, -2.5), (HW + 2, 2.5), (-HW - 2, 2.5)]
        inner = [(-HW - 0.8, -1.2), (HW + 0.8, -1.2), (HW + 0.8, 1.2), (-HW - 0.8, 1.2)]
        vo = [bm.verts.new((x, y, 0.05)) for x, y in outer]; vi = [bm.verts.new((x, y, 0.05)) for x, y in inner]
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new([vo[i], vo[j], vi[j], vi[i]])
        me = bpy.data.meshes.new('lip'); bm.to_mesh(me); bm.free(); me.materials.append(dark)
        sc.collection.objects.link(bpy.data.objects.new('lip', me))
        bm = bmesh.new()                                             # the dark gap the panel sank into
        vs = [bm.verts.new((x, y, 0.04)) for x, y in inner]
        bm.faces.new(vs)
        me = bpy.data.meshes.new('gap'); bm.to_mesh(me); bm.free(); me.materials.append(dark)
        sc.collection.objects.link(bpy.data.objects.new('gap', me))

    # convert, flatten and lean
    bpy.ops.object.select_all(action='DESELECT')
    objs = [o for o in sc.objects if o.type in ('MESH', 'CURVE')]
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target='MESH')
    for o in sc.objects:
        if o.type != 'MESH': continue
        mw = o.matrix_world.copy(); o.data.transform(mw); o.matrix_world.identity()
        for v in o.data.vertices:
            if sunk and v.co.z < 0: v.co.z = 0.0                     # below the hearth: hidden, keep it flat
            v.co.y += v.co.z * K
    if sunk:                                                         # trim what's under the hearth surface
        for o in list(sc.objects):
            if o.type == 'MESH' and o.name not in ('lip', 'gap'):
                bm = bmesh.new(); bm.from_mesh(o.data)
                gone = [f for f in bm.faces if all(v.co.z <= 0.001 for v in f.verts)]
                bmesh.ops.delete(bm, geom=gone, context='FACES')
                bm.to_mesh(o.data); bm.free()

    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.0; sun.angle = math.radians(12); sun.color = (1.0, 0.86, 0.66)
    so = bpy.data.objects.new('key', sun); so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.5; fill.angle = math.radians(30); fill.color = (0.75, 0.8, 1.0)
    fo = bpy.data.objects.new('fill', fill); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
    sc.collection.objects.link(fo)
    fire = bpy.data.lights.new('fire', 'AREA'); fire.energy = 600; fire.size = 30; fire.color = (1.0, 0.55, 0.2)
    fio = bpy.data.objects.new('fire', fire); fio.location = (0, 18, 8); fio.rotation_euler = (math.radians(-90), 0, 0)
    sc.collection.objects.link(fio)                                  # the fire behind, warming the iron's back edges
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.20, 0.14, 0.09, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.8

    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(BW, BH); cam.clip_end = 3000
    co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co)
    co.location = (BX0 + BW / 2, BY0 + BH / 2, 1000); sc.camera = co
    return sc


os.makedirs(OUT, exist_ok=True)
import shutil
for sunk in (False, True):
    sc = build(sunk)
    first = os.path.join(OUT, f'lmp_target_0{"_down" if sunk else ""}.png')
    sc.render.filepath = first
    bpy.ops.render.render(write_still=True)
    for i in range(1, 4):
        shutil.copy(first, os.path.join(OUT, f'lmp_target_{i}{"_down" if sunk else ""}.png'))
    print('rendered', first, 'and copies')
