"""Table 05 (The Lamplight) M9 v15: the shop cat, a ginger tabby modelled from metaballs and rendered in the table's
oblique view and light, facing right (LmpCat mirrors her for left). Poses: walk1 / walk2 (legs swapped), sit (on a
perch), nap (curled up, eyes shut, tail round her nose), swat (a front paw out). Each is lmp_cat_<pose>.png in
LmpTableLayout.catArtBox (x -34…34, y -22…40 around the cat's node, whose physics circle is r 15 at the origin).
Usage: python3 lmp_bake_cat.py -- out_dir [samples]"""
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
K = L.OBLIQUE
BOX = (-34.0, -22.0, 68.0, 62.0)


def tail_chain(pts, r0, r1, n=18):
    """Balls along a polyline, thinning from r0 to r1."""
    out = []
    seg = list(zip(pts, pts[1:]))
    for i in range(n):
        t = i / (n - 1) * len(seg); k = min(int(t), len(seg) - 1); f = t - k
        (a, b) = seg[k]
        out.append(((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f), r0 + (r1 - r0) * i / (n - 1)))
    return out


def pose(name):
    """(balls [(co, radius, (sx, sy, sz))], head centre, eyes open)."""
    E = (1, 1, 1)
    if name in ('walk1', 'walk2', 'swat'):
        s = 3.0 if name == 'walk2' else -3.0 if name == 'walk1' else 0.0
        balls = [((0, 0, 13), 9.5, (1.9, 0.9, 0.85)), ((9, 0, 13), 8, E), ((-9, 0, 12), 8, E),
                 ((11 + s, 4, 5.5), 3.3, (1, 1, 2.0)), ((-10 - s, 4, 5.5), 3.4, (1, 1, 2.0)),
                 ((-10 + s, -4, 5.5), 3.4, (1, 1, 2.0)),
                 ((18, 0, 20), 9.0, E), ((23, 0, 18), 4.6, E)]
        balls.append(((11 - s, -4, 5.5), 3.3, (1, 1, 2.0)) if name != 'swat' else ((20, -5, 13), 3.2, (1.6, 1, 1)))
        if name == 'swat':
            balls.append(((26, -6, 14.5), 3.0, E))
        balls += [(c, r, E) for c, r in tail_chain([(-17, 0, 13), (-23, 0, 17), (-25, 0, 25), (-22, 0, 30)], 3.0, 2.2)]
        return balls, (18, 0, 20), True
    if name == 'sit':
        balls = [((-5, 0, 9), 10.5, (1.2, 1, 0.9)), ((4, 0, 15), 8, (1, 1, 1.3)),
                 ((7, 3.5, 5), 3.0, (1, 1, 2.3)), ((7, -3.5, 5), 3.0, (1, 1, 2.3)),
                 ((7, 0, 27), 9.0, E), ((12, 0, 25), 4.6, E)]
        balls += [(c, r, E) for c, r in tail_chain([(-14, 0, 3), (-10, -9, 3), (0, -12, 3), (10, -10, 3)], 3.0, 2.2)]
        return balls, (7, 0, 27), True
    if name == 'nap':
        balls = [((0, 0, 8), 11, (1.35, 1.15, 0.7)), ((-7, 2, 8), 8, E),
                 ((11, -4, 9), 8.5, E), ((16, -5, 8), 4.2, E)]
        balls += [(c, r, E) for c, r in tail_chain([(-14, -3, 4), (-9, -12, 3.5), (2, -14, 3.5), (13, -12, 4)], 3.2, 2.4)]
        return balls, (11, -4, 8), False
    raise ValueError(name)


def render(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
    x0, y0, w, h = BOX
    sc.render.resolution_x = int(w * L.PX_PER_PT); sc.render.resolution_y = int(h * L.PX_PER_PT)
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'

    fur = bpy.data.materials.new('fur'); fur.use_nodes = True
    nt = fur.node_tree; b = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord')
    wave = nt.nodes.new('ShaderNodeTexWave'); wave.wave_type = 'BANDS'; wave.bands_direction = 'X'
    wave.inputs['Scale'].default_value = 0.11; wave.inputs['Distortion'].default_value = 9.0
    wave.inputs['Detail'].default_value = 2
    nt.links.new(tc.outputs['Object'], wave.inputs['Vector'])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.35; ramp.color_ramp.elements[0].color = (0.70, 0.36, 0.13, 1)
    ramp.color_ramp.elements[1].position = 0.70; ramp.color_ramp.elements[1].color = (0.93, 0.58, 0.28, 1)
    nt.links.new(wave.outputs['Fac'], ramp.inputs['Fac']); nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.85
    b.inputs['Sheen Weight'].default_value = 0.6; b.inputs['Sheen Roughness'].default_value = 0.4
    dark = bpy.data.materials.new('eye'); dark.use_nodes = True
    db = dark.node_tree.nodes['Principled BSDF']
    db.inputs['Base Color'].default_value = (0.03, 0.03, 0.02, 1); db.inputs['Roughness'].default_value = 0.1
    pink = bpy.data.materials.new('nose'); pink.use_nodes = True
    pink.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.85, 0.45, 0.45, 1)

    balls, hc, eyes_open = pose(name)
    mb = bpy.data.metaballs.new('cat'); mb.resolution = 0.8; mb.render_resolution = 0.6; mb.threshold = 0.3
    for (x, y, z), r, (sx, sy, sz) in balls:
        el = mb.elements.new(); el.type = 'ELLIPSOID' if (sx, sy, sz) != (1, 1, 1) else 'BALL'
        el.co = (x, y, z); el.radius = r
        if el.type == 'ELLIPSOID':
            el.size_x, el.size_y, el.size_z = sx, sy, sz
    mo = bpy.data.objects.new('cat', mb); sc.collection.objects.link(mo); mb.materials.append(fur)
    hx, hy, hz = hc
    plain = bpy.data.materials.new('ear'); plain.use_nodes = True
    pb = plain.node_tree.nodes['Principled BSDF']
    pb.inputs['Base Color'].default_value = (0.86, 0.50, 0.22, 1); pb.inputs['Roughness'].default_value = 0.85
    # the body as a mesh first, so the face can be put on its actual surface (ray casts)
    bpy.ops.object.select_all(action='DESELECT'); mo.select_set(True); bpy.context.view_layer.objects.active = mo
    bpy.ops.object.convert(target='MESH')
    mo = bpy.context.object
    dg = bpy.context.evaluated_depsgraph_get()

    def surface(origin, direction):
        ok, loc, nrm, _ = mo.ray_cast(origin, direction)
        return (loc, nrm) if ok else (None, None)

    for sgn in (1, -1):                                              # eyes on the front of the head
        loc, nrm = surface((hx + 30, hy + sgn * 3.2, hz + 2.2), (-1, 0, 0))
        if loc is None: continue
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1.35, location=loc - nrm * 0.5, segments=16, ring_count=8)
        e = bpy.context.object; e.data.materials.append(dark)
        if not eyes_open: e.scale = (0.4, 1.3, 0.3)
    loc, nrm = surface((hx + 30, hy, hz - 1.2), (-1, 0, 0))          # nose on the muzzle
    if loc is not None:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1.1, location=loc - nrm * 0.3, segments=16, ring_count=8)
        bpy.context.object.data.materials.append(pink)
    for sgn in (1, -1):                                              # ears standing on the top of the head
        loc, nrm = surface((hx - 0.5, hy + sgn * 2.9, hz + 30), (0, 0, -1))
        if loc is None: continue
        bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=2.9, radius2=0.25, depth=6.0,
                                        location=(loc.x, loc.y + sgn * 0.4, loc.z + 2.0),
                                        rotation=(-sgn * math.radians(8), 0, 0))
        bpy.context.object.data.materials.append(plain)

    # turn everything into a mesh and lean it (y += z K)
    bpy.ops.object.select_all(action='DESELECT')
    for o in sc.objects:
        if o.type == 'MESH': o.select_set(True)
    for o in sc.objects:
        if o.type != 'MESH': continue
        mw = o.matrix_world.copy(); o.data.transform(mw); o.matrix_world.identity()
        for v in o.data.vertices: v.co.y += v.co.z * K
        for p in o.data.polygons: p.use_smooth = True

    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 10, 0))
    fl = bpy.context.object; fl.scale = (200, 200, 1); fl.is_shadow_catcher = True
    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.0; sun.angle = math.radians(12); sun.color = (1.0, 0.86, 0.66)
    so = bpy.data.objects.new('key', sun); so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.6; fill.angle = math.radians(30); fill.color = (0.75, 0.8, 1.0)
    fo = bpy.data.objects.new('fill', fill); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
    sc.collection.objects.link(fo)
    wd = bpy.data.worlds.new('w'); sc.world = wd; wd.use_nodes = True
    wd.node_tree.nodes['Background'].inputs['Color'].default_value = (0.20, 0.14, 0.09, 1)
    wd.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.9
    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(w, h); cam.clip_end = 3000
    co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co)
    co.location = (x0 + w / 2, y0 + h / 2, 1000); sc.camera = co
    path = os.path.join(OUT, f'lmp_cat_{name}.png'); sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print('rendered', path)


os.makedirs(OUT, exist_ok=True)
for n in ('walk1', 'walk2', 'sit', 'nap', 'swat'):
    render(n)
