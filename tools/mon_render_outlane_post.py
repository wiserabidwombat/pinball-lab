"""Table 04 (Monsoon): the left outlane post (2026-10-21), rendered with mon_render_lower.py's materials, lights and
oblique camera so it matches the baked posts, then pasted into the lower art.
The part: two steel wires (z 9, r 2.2 and z 3, r 1.6, like the lane guides) from the guide's top post (54, 470) up and
left to a new post at MonTableLayout.leftOutlanePostTip (44, 482): chrome post, brass cap, white rubber ring. The guide's
own top post and the top of its wires are rendered too, so the two posts overlap correctly. A shadow catcher floor
gives the shadows with a transparent background.
Usage:
  python3 mon_render_outlane_post.py -- render out.png [samples]      (Blender bpy: the RGBA overlay)
  python3 mon_render_outlane_post.py -- paste overlay.png mon_lower.jpg mon_lower_sketch.jpg
     (pastes the overlay into the colour art, and a grey version into the sketch art, in place)"""
import sys, os, math

OBLIQUE = 0.4040
PX = 3                                     # px per point in the lower art
LOWER = (-40, -75, 680, 600)               # MonTableLayout.lowerArtRect
BOX = (22, 455, 52, 64)                    # world x, y, w, h of the overlay (covers both posts, their tops and shadows)
GUIDE_TOP = (54, 470)
TIP = (44, 482)

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
MODE = argv[0]

if MODE == 'render':
    import bpy
    OUT = os.path.abspath(argv[1]); SAMPLES = int(argv[2]) if len(argv) > 2 else 128
    MASK = len(argv) > 3 and argv[3] == 'mask'          # metal white, rubber black (for the sketch's paste)
    bx, by, bw, bh = BOX
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
    sc.render.resolution_x = bw * PX; sc.render.resolution_y = bh * PX
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'

    def principled(name, color, metal=0.0, rough=0.4, spec=0.5):
        m = bpy.data.materials.new(name); m.use_nodes = True
        b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = (*color, 1)
        b.inputs['Metallic'].default_value = metal
        b.inputs['Roughness'].default_value = rough
        b.inputs['Specular IOR Level'].default_value = spec
        return m
    M_CHROME = principled('chrome', (0.92, 0.93, 0.95), metal=1.0, rough=0.12)
    M_STEEL = principled('steel', (0.7, 0.72, 0.75), metal=1.0, rough=0.28)
    M_BRASS = principled('brass', (0.86, 0.64, 0.30), metal=1.0, rough=0.22)
    M_RUBBER = principled('rubber', (0.93, 0.92, 0.88), rough=0.55, spec=0.3)

    def link(o): sc.collection.objects.link(o); return o
    def tube(name, pts, z, r, mat):
        cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'
        cu.bevel_depth = r; cu.bevel_resolution = 3; cu.use_fill_caps = True
        sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
        for i, (x, y) in enumerate(pts): sp.points[i].co = (x, y, z, 1)
        cu.materials.append(mat); return link(bpy.data.objects.new(name, cu))
    def cylinder(name, x, y, r, z0, z1, mat):
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=z1 - z0, location=(x, y, (z0 + z1) / 2), vertices=32)
        o = bpy.context.object; o.name = name; o.data.materials.append(mat)
        bev = o.modifiers.new('b', 'BEVEL'); bev.width = min(r * 0.25, 1.2); bev.segments = 3
        return o
    def torus(name, x, y, z, major, minor, mat):
        bpy.ops.mesh.primitive_torus_add(location=(x, y, z), major_radius=major, minor_radius=minor,
                                         major_segments=40, minor_segments=12)
        o = bpy.context.object; o.name = name; o.data.materials.append(mat); return o
    def post(name, x, y, ring_r, h=18):
        cylinder(name, x, y, 3.2, 0, h, M_CHROME)
        cylinder(name + 'cap', x, y, 4.2, h, h + 2.2, M_BRASS)
        torus(name + 'ring', x, y, 7, ring_r - 2.0, 2.0, M_RUBBER)

    # the existing guide: its top post and the top of its two wires (straight down at x 54)
    guide = [GUIDE_TOP, (GUIDE_TOP[0], by - 20)]
    tube('guide', guide, 9, 2.2, M_STEEL); tube('guideLow', guide, 3, 1.6, M_STEEL)
    post('guideTop', *GUIDE_TOP, 6.5)
    # they're already in the art: holdouts (transparent in the overlay, so the baked pixels stay) that still hide
    # the new rail where they're in front, and cast no second shadow
    for o in sc.objects:
        if o.name.startswith('guide'): o.visible_shadow = False; o.is_holdout = True
    # the new rail and post (a slimmer ring: the physics edge ends at the post's centre)
    rail = [GUIDE_TOP, TIP]
    tube('rail', rail, 9, 2.2, M_STEEL); tube('railLow', rail, 3, 1.6, M_STEEL)
    post('tip', *TIP, 5.0)
    # shadow catcher floor
    bpy.ops.mesh.primitive_plane_add(size=1, location=(bx + bw / 2, by + bh / 2, 0))
    fl = bpy.context.object; fl.scale = (bw * 3, bh * 3, 1); fl.is_shadow_catcher = True

    # oblique shear y += z * K (everything but the floor, which is at z 0 anyway)
    bpy.ops.object.select_all(action='DESELECT')
    for o in list(sc.objects):
        if o.type in ('CURVE', 'MESH'): o.select_set(True)
    bpy.context.view_layer.objects.active = next(o for o in sc.objects if o.type == 'MESH')
    bpy.ops.object.convert(target='MESH')
    for o in sc.objects:
        if o.type != 'MESH': continue
        mw = o.matrix_world.copy(); o.data.transform(mw); o.matrix_world.identity()
        for v in o.data.vertices: v.co.y += v.co.z * OBLIQUE
        for p in o.data.polygons: p.use_smooth = True

    # mon_render_lower.py's lights and world
    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.4; sun.angle = math.radians(9)
    link(bpy.data.objects.new('key', sun)).rotation_euler = (math.radians(-38), math.radians(-28), 0)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.6; fill.angle = math.radians(30)
    link(bpy.data.objects.new('fill', fill)).rotation_euler = (math.radians(30), math.radians(25), 0)
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

    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(bw, bh); cam.clip_end = 5000
    co = link(bpy.data.objects.new('cam', cam)); co.location = (bx + bw / 2, by + bh / 2, 1500)
    sc.camera = co
    if MASK:
        def flat(name, v):
            m = bpy.data.materials.new(name); m.use_nodes = True
            nodes = m.node_tree.nodes; nodes.clear()
            o_ = nodes.new('ShaderNodeOutputMaterial'); e_ = nodes.new('ShaderNodeEmission')
            e_.inputs['Color'].default_value = (v, v, v, 1); e_.inputs['Strength'].default_value = 1
            m.node_tree.links.new(e_.outputs[0], o_.inputs[0]); return m
        WHITE, BLACK = flat('mwhite', 1.0), flat('mblack', 0.0)
        for o in sc.objects:
            if o.type != 'MESH' or o.is_shadow_catcher: continue
            mats = o.data.materials
            for i in range(len(mats)):
                if mats[i] and mats[i].name in ('chrome', 'steel', 'brass', 'rubber'):
                    mats[i] = BLACK if mats[i].name == 'rubber' else WHITE
        sc.cycles.samples = 16; sc.cycles.use_denoising = False
    sc.render.filepath = OUT
    bpy.ops.render.render(write_still=True)
    print('rendered', OUT)

elif MODE == 'paste':
    # paste overlay.png mask.png mon_lower.jpg mon_lower_sketch.jpg
    import numpy as np
    from PIL import Image
    from scipy import ndimage
    rng = np.random.default_rng(7)
    ov = np.asarray(Image.open(argv[1]).convert('RGBA')).astype(np.float32) / 255
    mk = np.asarray(Image.open(argv[2]).convert('RGBA')).astype(np.float32) / 255
    rgb, a = ov[..., :3], ov[..., 3:4]
    metal = np.clip((mk[..., :1] - 0.3) / 0.4, 0, 1) * (mk[..., 3:4] > 0.5)
    part = (mk[..., 3:4] > 0.5).astype(np.float32)           # the part itself (not its shadow)
    rubber = part * (1 - metal)
    H, W = a.shape[:2]
    def lum(x): return (x @ np.array([0.299, 0.587, 0.114], np.float32))[..., None]
    grain = 1 - 0.05 * np.clip(ndimage.gaussian_filter(rng.standard_normal((H, W)), 0.8)[..., None] / 0.2, -2.5, 2.5)
    # colour: the art's watercolor pass softened and grained everything but metal, so the rubber rings read as a
    # slightly greyer, textured white there; do the same here
    soft = np.stack([ndimage.gaussian_filter(rgb[..., c], 0.9) for c in range(3)], -1)
    color = rgb * (1 - rubber) + (soft * 0.9 * grain) * rubber
    # sketch: metal is a grey of the render; the rubber is pencil on cream (a light tone and an outline)
    paper = np.array([0.95, 0.93, 0.88], np.float32)
    L = lum(rgb)
    edges = np.abs(ndimage.gaussian_filter(L[..., 0], 1.2) - ndimage.gaussian_filter(L[..., 0], 3.0))[..., None]
    pencil = np.clip((0.55 + 0.45 * L) * grain - edges * 3.0, 0, 1) * paper
    sketch = lum(rgb) * np.array([0.98, 0.97, 0.94], np.float32) * (1 - rubber) + pencil * rubber
    bx, by, bw, bh = BOX
    x0 = int(round((bx - LOWER[0]) * PX)); y0 = int(round((LOWER[1] + LOWER[3] - (by + bh)) * PX))
    for path, src in ((argv[3], color), (argv[4], sketch)):
        im = np.asarray(Image.open(path).convert('RGB')).astype(np.float32) / 255
        reg = im[y0:y0 + H, x0:x0 + W]
        im[y0:y0 + H, x0:x0 + W] = src * a + reg * (1 - a)   # shadow-catcher pixels (black, part alpha) darken the floor
        Image.fromarray((np.clip(im, 0, 1) * 255 + 0.5).astype(np.uint8)).save(path, quality=93, subsampling=0)
        print('pasted into', path, 'at', x0, y0, W, H)
