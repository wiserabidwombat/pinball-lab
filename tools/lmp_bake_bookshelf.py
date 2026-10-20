"""Table 05 (The Lamplight) M9 v20: the cat's shelf as a walnut bookshelf that fills in with the collection.
lmp_shelf: the plank (walnut, a brass front lip, brass bookends at both ends), centred on the cat's home (370, 1175),
image box LmpTableLayout.shelfArtBox (x -107…107, y -14…26).
lmp_shelf_<g>_<k>: genre g's section (g 0…5 = Mystery, Romance, Adventure, Poetry, Cookbooks, Local history, left to
right) holding its first k spines (k 1…6; the game shows one per quarter of the genre's books found, rounded up, and
the sixth, gilt-labelled, when the genre is complete), each
section 32 pt wide from x 274 + 32 g, image box LmpTableLayout.shelfSectionArtBox (x -1…33, y -14…26) round
(section x, 1175). The books stand along the back of the plank, behind where the cat walks.
Oblique view (y += z * OBLIQUE), the table's light, shadow catchers on the floor and the plank top.
Usage: python3 lmp_bake_bookshelf.py -- out_dir [samples]"""
import bpy, math, sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
K = L.OBLIQUE
# world, relative to the cat's home (370, 1175)
PLANK_X0, PLANK_X1 = -97.0, 97.0          # x 273 … 467
PLANK_Y0, PLANK_Y1 = -8.0, 15.0          # front edge in front of her feet, back edge behind the books
PLANK_Z = 3.0
BOOK_Y0, BOOK_Y1 = 6.0, 14.0              # the books stand along the back
SECTION_X0, SECTION_W = -96.0, 32.0       # section g from x 274 + 32 g (relative -96 + 32 g)
SLOTS = 6
GENRE = [(0.07, 0.11, 0.30), (0.50, 0.12, 0.16), (0.08, 0.26, 0.15), (0.30, 0.12, 0.34), (0.66, 0.46, 0.10),
         (0.36, 0.20, 0.09)]             # navy, rose, forest, plum, mustard, tobacco


def setup(bx0, by0, bw, bh):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
    sc.render.resolution_x = int(round(bw * L.PX_PER_PT)); sc.render.resolution_y = int(round(bh * L.PX_PER_PT))
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(bw, bh); cam.clip_end = 3000
    co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co)
    co.location = (bx0 + bw / 2, by0 + bh / 2, 1000); sc.camera = co
    return sc


def mat(name, color, metal=0.0, rough=0.45, coat=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1); b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough; b.inputs['Coat Weight'].default_value = coat
    return m


def box(x0, x1, y0, y1, z0, z1, m, bevel=0.0, catcher=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    o = bpy.context.object; o.scale = (x1 - x0, y1 - y0, z1 - z0)
    bpy.ops.object.transform_apply(scale=True)
    if m: o.data.materials.append(m)
    if bevel:
        bv = o.modifiers.new('b', 'BEVEL'); bv.width = bevel; bv.segments = 2
    if catcher: o.is_shadow_catcher = True
    return o


def plank(catcher):
    walnut = mat('walnut', (0.13, 0.065, 0.032), rough=0.45, coat=0.25)
    brass = mat('brass', (0.90, 0.68, 0.33), metal=1.0, rough=0.22)
    if catcher:                                                     # books' shadows fall on the plank top
        box(PLANK_X0, PLANK_X1, PLANK_Y0, PLANK_Y1, 0, PLANK_Z, None, catcher=True)
        return
    box(PLANK_X0, PLANK_X1, PLANK_Y0, PLANK_Y1, 0, PLANK_Z, walnut, bevel=0.6)
    box(PLANK_X0 + 0.5, PLANK_X1 - 0.5, PLANK_Y0 - 0.4, PLANK_Y0 + 0.6, PLANK_Z - 0.3, PLANK_Z + 0.5, brass)
    box(PLANK_X0 + 0.5, PLANK_X1 - 0.5, PLANK_Y1 - 1.0, PLANK_Y1, PLANK_Z, PLANK_Z + 4.0, walnut, bevel=0.3)   # back rail
    for x in (PLANK_X0 + 1.2, PLANK_X1 - 2.4):                      # brass bookends at both ends
        box(x, x + 1.2, BOOK_Y0 - 0.5, BOOK_Y1, PLANK_Z, PLANK_Z + 13, brass, bevel=0.3)
        box(x - 1.5 if x < 0 else x - 1.0, x + 2.7 if x < 0 else x + 2.2, BOOK_Y0 - 0.5, BOOK_Y1, PLANK_Z, PLANK_Z + 0.6, brass)
    for i in range(1, 6):                                           # thin walnut dividers between the genres
        x = SECTION_X0 + SECTION_W * i
        box(x - 0.45, x + 0.45, BOOK_Y0 - 1, PLANK_Y1 - 1, PLANK_Z, PLANK_Z + 8, walnut, bevel=0.2)


def books(g, k):
    rnd = random.Random(100 + g)
    gold = mat('gold', (0.90, 0.70, 0.34), metal=1.0, rough=0.3)
    pages = mat('pages', (0.55, 0.47, 0.35), rough=0.85)
    x = SECTION_X0 + SECTION_W * g + 1.4
    for i in range(SLOTS):
        w = rnd.uniform(4.0, 4.8); h = rnd.uniform(12.0, 16.5); j = rnd.uniform(-0.05, 0.05)
        if i < k:
            c = tuple(max(0, min(1, v * rnd.uniform(0.8, 1.2) + j)) for v in GENRE[g])
            cloth = mat(f'cloth{i}', c, rough=0.6, coat=0.15)
            box(x, x + w, BOOK_Y0, BOOK_Y1, PLANK_Z, PLANK_Z + h, cloth, bevel=0.35)
            box(x + 0.9, x + w - 0.9, BOOK_Y0 + 1.6, BOOK_Y1 - 0.4, PLANK_Z + h - 0.2, PLANK_Z + h + 0.1, pages)
            for zz in (2.0, h - 2.6):                               # gilt bands on the spine
                box(x + 0.3, x + w - 0.3, BOOK_Y0 - 0.2, BOOK_Y0 + 0.3, PLANK_Z + zz, PLANK_Z + zz + 0.6, gold)
            if k == SLOTS and i == SLOTS - 1:                         # a complete genre: a gilt label on the last spine
                box(x + 0.6, x + w - 0.6, BOOK_Y0 - 0.25, BOOK_Y0 + 0.3, PLANK_Z + h * 0.42, PLANK_Z + h * 0.62, gold)
        x += w + 0.35


def finish(sc):
    for o in sc.objects:
        if o.type != 'MESH': continue
        bpy.context.view_layer.objects.active = o
        for md in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=md.name)
        for v in o.data.vertices: v.co.y += v.co.z * K
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
    bpy.context.object.is_shadow_catcher = True
    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.0; sun.angle = math.radians(12); sun.color = (1.0, 0.86, 0.66)
    so = bpy.data.objects.new('key', sun); so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.6; fill.angle = math.radians(30); fill.color = (0.75, 0.8, 1.0)
    fo = bpy.data.objects.new('fill', fill); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
    sc.collection.objects.link(fo)
    for i, (x, y) in enumerate(((-200, 100), (200, 150), (0, -250))):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x, y, 300))
        p = bpy.context.object; p.scale = (300, 300, 1)
        em = bpy.data.materials.new(f'box{i}'); em.use_nodes = True
        nodes = em.node_tree.nodes; nodes.clear()
        o_ = nodes.new('ShaderNodeOutputMaterial'); e_ = nodes.new('ShaderNodeEmission')
        e_.inputs['Strength'].default_value = 1.0; e_.inputs['Color'].default_value = (1.0, 0.85, 0.62, 1)
        em.node_tree.links.new(e_.outputs[0], o_.inputs[0])
        p.data.materials.append(em); p.visible_camera = False; p.visible_shadow = False
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.16, 0.11, 0.07, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.7


def render(sc, name):
    sc.render.filepath = os.path.join(OUT, name + '.png')
    bpy.ops.render.render(write_still=True)
    print('rendered', sc.render.filepath)


os.makedirs(OUT, exist_ok=True)
sc = setup(-107, -14, 214, 40)
plank(catcher=False)
finish(sc)
render(sc, 'lmp_shelf')
for g in range(6):
    for k in range(1, SLOTS + 1):
        sx = SECTION_X0 + SECTION_W * g
        sc = setup(sx - 1, -14, 34, 40)
        plank(catcher=True)
        books(g, k)
        finish(sc)
        render(sc, f'lmp_shelf_{g}_{k}')
