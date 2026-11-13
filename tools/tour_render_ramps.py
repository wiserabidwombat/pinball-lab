"""Table 06 (Orbit: Grand Tour) M6 v9: the Moon and Saturn ramps rendered in Blender (helpers from
tour_render_targets.py), from the game's own ramp geometry: tools/tour_ramps.txt, the TOURRAMP / TOURRP lines the DEBUG
launch flag -tourDumpWalls prints (each path point's distance, running-surface height, centre, heading and both rails).

Same parts and look as TourRamp's drawn ramp: the amber plastic part up to the apex (ribbed floor, clear side walls
14 pt tall with a rolled top, chrome brackets, a steel entrance flap on the floor) and the wire habitrail after it
(running rails, upper side rails 11 pt above and 2 pt out, hoops every 12 pt, chrome support posts every 110 pt).

Two images per ramp, same rect (printed as RECT lines, world pt):
  tour_ramp_<name>.png       the ramp itself, in the table's oblique (y += z·K) — drawn at z 20, over floor balls
  tour_ramp_<name>_lo.png    what lies on the floor: its shadow (a shadow catcher, light from the upper left like the
                             game's: 0.30 right / 0.22 down per pt of height), the entrance flap and the posts' feet
3 px/pt. Usage: python3 tour_render_ramps.py -- tour_ramps.txt out_dir [samples]"""
import bpy, bmesh, math, sys, os
import mathutils

argv = sys.argv[sys.argv.index('--') + 1:]
DATA = os.path.abspath(argv[0])
OUT = os.path.abspath(argv[1])
SAMPLES = int(argv[2]) if len(argv) > 2 else 64
os.makedirs(OUT, exist_ok=True)
K = 0.404
PX = 3
ORIGIN = (284.0, 650.0)          # world → Blender: subtract, so the lights sit round the middle of the table


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'
    return sc


def principled(name, color, metal=0.0, rough=0.4, coat=0.0, coat_rough=0.05, spec=0.5):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    b.inputs['Coat Weight'].default_value = coat
    b.inputs['Coat Roughness'].default_value = coat_rough
    b.inputs['Specular IOR Level'].default_value = spec
    return m


def lights(sc, world=0.6, floor=(0.05, 0.07, 0.16)):
    """The same key sun, fill and soft boxes as the table render."""
    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.4; sun.angle = math.radians(9)
    so = bpy.data.objects.new('key', sun); sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.6; fill.angle = math.radians(30)
    fo = bpy.data.objects.new('fill', fill); sc.collection.objects.link(fo)
    fo.rotation_euler = (math.radians(30), math.radians(25), 0)
    for i, (x, y, w, h, e) in enumerate([(-200, 900, 500, 900, 2.6), (800, 300, 300, 600, 1.1), (284, -400, 900, 200, 1.2)]):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x - 284, y - 300, 700))
        p = bpy.context.object; p.scale = (w, h, 1)
        em = bpy.data.materials.new(f'box{i}'); em.use_nodes = True
        nodes = em.node_tree.nodes; nodes.clear()
        o_ = nodes.new('ShaderNodeOutputMaterial'); e_ = nodes.new('ShaderNodeEmission')
        e_.inputs['Strength'].default_value = e; em.node_tree.links.new(e_.outputs[0], o_.inputs[0])
        p.data.materials.append(em); p.visible_camera = False; p.visible_shadow = False
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.02, 0.03, 0.07, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = world
    # a navy floor (the space table) for the chrome to reflect, unseen by the camera
    bpy.ops.mesh.primitive_plane_add(size=3000, location=(0, 0, -30))
    fl = bpy.context.object
    fl.data.materials.append(principled('reflectfloor', floor, rough=0.6))
    fl.visible_camera = False; fl.visible_shadow = False


def camera(sc, x0, y0, x1, y1, px_per_pt):
    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'
    w, h = x1 - x0, y1 - y0
    cam.ortho_scale = max(w, h)
    co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co)
    co.location = ((x0 + x1) / 2, (y0 + y1) / 2, 500)
    sc.camera = co
    sc.render.resolution_x = int(round(w * px_per_pt))
    sc.render.resolution_y = int(round(h * px_per_pt))


def render(sc, name):
    sc.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)
    print('rendered', name, sc.render.resolution_x, sc.render.resolution_y)



def prism(name, pts, z0, z1, mat, bevel=0.0):
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, z0)) for x, y in pts]
    face = bm.faces.new(vs)
    if face.normal.z < 0: face.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z = z1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    if bevel:
        b = o.modifiers.new('b', 'BEVEL'); b.width = bevel; b.segments = 4; b.limit_method = 'ANGLE'
    for p in me.polygons: p.use_smooth = True
    return o


def load(path):
    ramps = []
    for line in open(path):
        f = line.split()
        if not f: continue
        if f[0] == 'TOURRAMP':
            ramps.append({'apex': float(f[3]), 'length': float(f[5]), 'pts': []})
        elif f[0] == 'TOURRP':
            i, s, h, cx, cy, hd, lx, ly, rx, ry = (float(v) for v in f[1:11])
            ramps[-1]['pts'].append(dict(s=s, h=h, c=(cx, cy), hd=hd, l=(lx, ly), r=(rx, ry)))
    return ramps


def W(p, z=0.0):
    return (p[0] - ORIGIN[0], p[1] - ORIGIN[1], z)


def out_from(p, hd, out, side):
    return (p[0] - side * out * math.sin(hd), p[1] + side * out * math.cos(hd))


def tube(name, pts, r, mat, group):
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = r; cu.bevel_resolution = 3; cu.use_fill_caps = True
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts): sp.points[i].co = (*p, 1)
    cu.materials.append(mat)
    o = bpy.data.objects.new(name, cu); bpy.context.scene.collection.objects.link(o)
    group.append(o)
    return o


def ribbon(name, A, B, mat, group, thick=0.0):
    bm = bmesh.new()
    va = [bm.verts.new(p) for p in A]; vb = [bm.verts.new(p) for p in B]
    for i in range(len(A) - 1):
        bm.faces.new([va[i], va[i + 1], vb[i + 1], vb[i]])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(mat)
    for p in me.polygons: p.use_smooth = True
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    if thick:
        m = o.modifiers.new('s', 'SOLIDIFY'); m.thickness = thick; m.offset = -1
    group.append(o)
    return o


def clear_mat(name, color, alpha, rough=0.12):
    m = principled(name, color, rough=rough, coat=0.6)
    m.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value = alpha
    return m


def build(rp):
    pts = rp['pts']; apex = rp['apex']
    hi, lo = [], []
    amber = clear_mat('amber', (0.93, 0.66, 0.34), 0.50)
    wallm = clear_mat('wall', (0.98, 0.86, 0.66), 0.26)
    rib = clear_mat('rib', (0.62, 0.38, 0.16), 0.55)
    roll = principled('roll', (1.0, 0.78, 0.45), rough=0.18, coat=0.8)
    chrome = principled('chrome', (0.86, 0.87, 0.90), metal=1.0, rough=0.22)
    steel = principled('steel', (0.62, 0.64, 0.70), metal=0.85, rough=0.35)
    dark = principled('dark', (0.20, 0.21, 0.25), metal=0.8, rough=0.4)

    plastic = [p for p in pts if p['s'] <= apex + 1e-6]
    wire = [p for p in pts if p['s'] >= apex - 1e-6]
    # ---- the plastic part
    if len(plastic) > 1:
        L = [W(p['l'], p['h']) for p in plastic]; R = [W(p['r'], p['h']) for p in plastic]
        ribbon('floor', L, R, amber, hi, thick=1.2)
        nxt = plastic[0]['s'] + 8
        for p in plastic:
            if p['s'] >= nxt:
                nxt = p['s'] + 16
                tube('rib', [W(p['l'], p['h'] + 0.3), W(p['r'], p['h'] + 0.3)], 0.35, rib, hi)
        for side, key in ((1, 'l'), (-1, 'r')):
            base = [W(p[key], p['h']) for p in plastic]
            top = [W(out_from(p[key], p['hd'], 1.2, side), p['h'] + 14) for p in plastic]
            ribbon('wall', base, top, wallm, hi)
            tube('rolltop', top, 1.15, roll, hi)
            tube('base', base, 0.45, rib, hi)
        last = plastic[-1]['s']
        for target in (150.0, last - 40):
            p = min(plastic, key=lambda q: abs(q['s'] - target))
            if p['h'] <= 14: continue
            for key in ('l', 'r'):
                tube('bracket', [W(p[key], 0), W(p[key], p['h'] - 1)], 1.1, chrome, hi)
        # the steel entrance flap on the floor, in front of the mouth, with two rivets
        p0 = plastic[0]; hd = p0['hd']
        back = (-math.cos(hd) * 13, -math.sin(hd) * 13); sd = (-math.sin(hd) * 3, math.cos(hd) * 3)
        l0, r0 = p0['l'], p0['r']
        quad = [l0, r0, (r0[0] + back[0] - sd[0], r0[1] + back[1] - sd[1]), (l0[0] + back[0] + sd[0], l0[1] + back[1] + sd[1])]
        lo.append(prism('flap', [W(q)[:2] for q in quad], 0, 0.6, steel, bevel=0.3))
        for f in (0.25, 0.75):
            c = (l0[0] + (r0[0] - l0[0]) * f + back[0] * 0.55, l0[1] + (r0[1] - l0[1]) * f + back[1] * 0.55)
            bpy.ops.mesh.primitive_cylinder_add(radius=1.4, depth=0.6, location=W(c, 0.8), vertices=16)
            bpy.context.object.data.materials.append(dark); lo.append(bpy.context.object)
    # ---- the wire habitrail
    if len(wire) > 1:
        lowL = [W(p['l'], p['h']) for p in wire]; lowR = [W(p['r'], p['h']) for p in wire]
        topL = [W(out_from(p['l'], p['hd'], 2, 1), p['h'] + 11) for p in wire]
        topR = [W(out_from(p['r'], p['hd'], 2, -1), p['h'] + 11) for p in wire]
        for rail, r in ((lowL, 1.15), (lowR, 1.15), (topL, 0.95), (topR, 0.95)):
            tube('rail', rail, r, chrome, hi)
        nxt = wire[0]['s']
        for k, p in enumerate(wire):
            if p['s'] >= nxt:
                nxt = p['s'] + 12
                tube('hoop', [topL[k], lowL[k], lowR[k], topR[k]], 0.5, chrome, hi)
        nxt = wire[0]['s'] + 40
        for p in wire:
            if p['s'] >= nxt:
                nxt = p['s'] + 110
                if p['h'] <= 10: continue
                tube('post', [W(p['c'], 0), W(p['c'], p['h'] - 3)], 1.25, chrome, hi)
                bpy.ops.mesh.primitive_cylinder_add(radius=3.5, depth=0.8, location=W(p['c'], 0.4), vertices=24)
                bpy.context.object.data.materials.append(steel); lo.append(bpy.context.object)
    return hi, lo


def to_mesh(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target='MESH')
    return [o for o in bpy.context.scene.objects if o.select_get()]


def rect_of(rp):
    xs = [q for p in rp['pts'] for q in (p['l'][0], p['r'][0])]
    ys = [q for p in rp['pts'] for q in (p['l'][1], p['r'][1])]
    top = max(p['h'] for p in rp['pts'])
    x0 = math.floor(min(xs) - 8); x1 = math.ceil(max(xs) + 8 + (top + 14) * 0.30)
    y0 = math.floor(min(ys) - 8 - (top + 14) * 0.22); y1 = math.ceil(max(ys) + 8 + (top + 14) * K)
    return x0, y0, x1, y1


SHADOW_ALPHA = 0.32


def compose_lo(name):
    """The floor image: the flap and feet over the shadow, the shadow scaled to the game's ~0.3 darkness."""
    import numpy as np
    from PIL import Image
    sh = np.asarray(Image.open(os.path.join(OUT, f'_shadow_{name}.png')).convert('RGBA')).astype(float) / 255
    pa = np.asarray(Image.open(os.path.join(OUT, f'_parts_{name}.png')).convert('RGBA')).astype(float) / 255
    sa = sh[..., 3] * SHADOW_ALPHA
    a = pa[..., 3] + sa * (1 - pa[..., 3])
    rgb = (pa[..., :3] * pa[..., 3:4]) / np.maximum(a[..., None], 1e-6)    # the shadow is black
    out = np.dstack([rgb, a])
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA').save(os.path.join(OUT, f'tour_ramp_{name}_lo.png'))
    os.remove(os.path.join(OUT, f'_shadow_{name}.png')); os.remove(os.path.join(OUT, f'_parts_{name}.png'))


def render_ramp(rp, name):
    sc = reset(); lights(sc)
    key = bpy.data.objects['key']
    hi, lo = build(rp)
    hi = to_mesh(hi)
    x0, y0, x1, y1 = rect_of(rp)
    camera(sc, x0 - ORIGIN[0], y0 - ORIGIN[1], x1 - ORIGIN[0], y1 - ORIGIN[1], PX)
    print(f'RECT {name} {x0} {y0} {x1 - x0} {y1 - y0}')
    # pass 1, the floor: shadow catcher + flap + feet; the ramp casts shadows only. One sun, the game's shadow angle.
    d = mathutils.Vector((-0.30, 0.22, 1.0)).normalized()          # toward the light
    key.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    key.data.angle = math.radians(6)
    bpy.data.objects['fill'].data.energy = 0.0
    bpy.ops.mesh.primitive_plane_add(size=1, location=((x0 + x1) / 2 - ORIGIN[0], (y0 + y1) / 2 - ORIGIN[1], 0))
    catcher = bpy.context.object; catcher.scale = (x1 - x0 + 40, y1 - y0 + 40, 1)
    catcher.is_shadow_catcher = True
    for o in hi: o.visible_camera = False
    for o in lo: o.hide_render = True
    render(sc, f'_shadow_{name}.png')                 # 1a: the shadow alone
    catcher.hide_render = True
    for o in lo: o.hide_render = False
    for o in hi: o.hide_render = True
    render(sc, f'_parts_{name}.png')                  # 1b: the flap and feet alone
    for o in hi: o.hide_render = False
    compose_lo(name)
    # pass 2, the ramp: sheared into the table's oblique, the floor parts and catcher hidden, the usual lights
    for o in lo: o.hide_render = True
    key.rotation_euler = (math.radians(-38), math.radians(-28), 0); key.data.angle = math.radians(9)
    bpy.data.objects['fill'].data.energy = 0.6
    shear = mathutils.Matrix.Identity(4); shear[1][2] = K
    for o in hi:
        o.visible_camera = True
        o.data.transform(shear @ o.matrix_world); o.matrix_world = mathutils.Matrix.Identity(4)
        o.data.update()
    render(sc, f'tour_ramp_{name}.png')


ramps = load(DATA)
names = ['moon', 'saturn']
ONLY = argv[3] if len(argv) > 3 else ''
for rp, n in zip(ramps, names):
    if not ONLY or ONLY == n:
        render_ramp(rp, n)
