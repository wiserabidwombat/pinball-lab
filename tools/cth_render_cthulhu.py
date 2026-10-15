"""Table 03 milestone 8, art round 4: Cthulhu himself, rendered in the table's light and 22-degree lean with his
shadow baked onto a transparent background (shadow catcher), like the other part sprites.
  cth_cthulhu.png    the head: a tall wet mantle leaning back, a heavy brow, two glowing yellow eyes, a beard of short
                     face tentacles, and two small ribbed wings. Origin = the physics centre (the head circle, r 18).
  cth_tentacle0…4    five big tentacles round him, curling outward, suckers on the inside of the curl: two each side
                     lying out of the water toward the player, and the middle one (2) raised behind his head.
                     Origin = where each leaves the water. The game waves them; the Awakening cuts 0, 1, 3, 4.
Each box is printed and written to <out_dir>/cthulhu.json (x0, y0, w, h in points around the origin).
Usage: python3 cth_render_cthulhu.py -- out_dir [samples] [px_per_pt]"""
import bpy, bmesh, math, sys, os, json
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
PX = float(argv[2]) if len(argv) > 2 else 6
os.makedirs(OUT, exist_ok=True)
K = L.OBLIQUE


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'
    return sc


def mat(name, color, metal=0.0, rough=0.4, coat=0.0, coat_rough=0.05, spec=0.5, emit=None, emit_strength=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    b.inputs['Coat Weight'].default_value = coat
    b.inputs['Coat Roughness'].default_value = coat_rough
    b.inputs['Specular IOR Level'].default_value = spec
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1)
        b.inputs['Emission Strength'].default_value = emit_strength
    return m


def skin(name, dark, light, scale=0.35, bump=0.35):
    """Wet, mottled sea-green skin: noise between two greens, a little bump, a glossy coat."""
    m = mat(name, light, rough=0.5, coat=0.45, coat_rough=0.15, spec=0.5)
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord')
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = scale; noise.inputs['Detail'].default_value = 6
    noise.inputs['Roughness'].default_value = 0.6
    nt.links.new(tc.outputs['Object'], noise.inputs['Vector'])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.40; ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].position = 0.62; ramp.color_ramp.elements[1].color = (*light, 1)
    nt.links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    bp = nt.nodes.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = bump
    n2 = nt.nodes.new('ShaderNodeTexNoise'); n2.inputs['Scale'].default_value = 1.6; n2.inputs['Detail'].default_value = 4
    nt.links.new(tc.outputs['Object'], n2.inputs['Vector'])
    nt.links.new(n2.outputs['Fac'], bp.inputs['Height'])
    nt.links.new(bp.outputs['Normal'], b.inputs['Normal'])
    return m


def link(o):
    bpy.context.scene.collection.objects.link(o); return o


def lights(sc):
    """The table render's key sun, fill and soft boxes, a shadow catcher at z 0 and a sea-green floor to reflect."""
    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.4; sun.angle = math.radians(9)
    so = link(bpy.data.objects.new('key', sun)); so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.6; fill.angle = math.radians(30)
    fo = link(bpy.data.objects.new('fill', fill)); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
    for i, (x, y, w, h, e) in enumerate([(-500, 600, 500, 900, 2.6), (500, 0, 300, 600, 1.1), (0, -700, 900, 200, 1.2)]):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x, y, 700))
        p = bpy.context.object; p.scale = (w, h, 1); p.name = f'softbox{i}'
        em = bpy.data.materials.new(f'box{i}'); em.use_nodes = True
        nodes = em.node_tree.nodes; nodes.clear()
        o_ = nodes.new('ShaderNodeOutputMaterial'); e_ = nodes.new('ShaderNodeEmission')
        e_.inputs['Strength'].default_value = e; em.node_tree.links.new(e_.outputs[0], o_.inputs[0])
        p.data.materials.append(em); p.visible_camera = False; p.visible_shadow = False
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.05, 0.07, 0.08, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6
    return so


def finish(sc, so, name, margin=2):
    """Lean every part (y += z K), fit an ortho camera round the parts and their shadows, render, return the box."""
    parts = [o for o in sc.objects if o.type in ('MESH', 'CURVE') and o.visible_camera]
    for o in parts:
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
        if o.type == 'CURVE': bpy.ops.object.convert(target='MESH')
    parts = [o for o in sc.objects if o.type == 'MESH' and o.visible_camera]
    for o in parts:
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=m.name)
        o.data.transform(o.matrix_world); o.matrix_world.identity()
        for v in o.data.vertices: v.co.y += v.co.z * K
    bpy.context.view_layer.update()
    d = so.matrix_world.to_3x3() @ Vector((0, 0, -1))
    xs, ys = [], []
    for o in parts:
        for v in o.data.vertices:
            x, y, z = v.co
            xs.append(x); ys.append(y)
            if z > 0:
                t = z / -d.z
                xs.append(x + d.x * t); ys.append(y - z * K + d.y * t * 0.6)   # soft shadow: most of its length
    x0, y0 = math.floor(min(xs)) - margin, math.floor(min(ys)) - margin
    x1, y1 = math.ceil(max(xs)) + margin, math.ceil(max(ys)) + margin
    bpy.ops.mesh.primitive_plane_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, 0))
    cat = bpy.context.object; cat.scale = (x1 - x0 + 60, y1 - y0 + 60, 1); cat.is_shadow_catcher = True
    bpy.ops.mesh.primitive_plane_add(size=3000, location=(0, 0, -30))
    fl = bpy.context.object; fl.data.materials.append(mat('reflect', (0.08, 0.22, 0.21), rough=0.6))
    fl.visible_camera = False; fl.visible_shadow = False
    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(x1 - x0, y1 - y0)
    co = link(bpy.data.objects.new('cam', cam)); co.location = ((x0 + x1) / 2, (y0 + y1) / 2, 500)
    sc.camera = co
    sc.render.resolution_x = int(round((x1 - x0) * PX)); sc.render.resolution_y = int(round((y1 - y0) * PX))
    sc.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)
    print('rendered', name, (x0, y0, x1 - x0, y1 - y0), sc.render.resolution_x, sc.render.resolution_y)
    return [x0, y0, x1 - x0, y1 - y0]


def tube(name, pts3, radii, m, res=6):
    """A tapering tube along a 3D polyline (radius per point), via a curve with per-point radius."""
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = 1.0; cu.bevel_resolution = res; cu.use_fill_caps = True
    sp = cu.splines.new('POLY'); sp.points.add(len(pts3) - 1)
    for i, ((x, y, z), r) in enumerate(zip(pts3, radii)):
        sp.points[i].co = (x, y, z, 1); sp.points[i].radius = r
    cu.materials.append(m)
    return link(bpy.data.objects.new(name, cu))


def sphere(name, loc, scale, m, rot=(0, 0, 0), segs=48):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2, radius=1, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; o.scale = scale; o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return o


def curl(length, r0, r1, z0, z1, curl_turn, n=40, side=1.0):
    """Centreline of a tentacle from (0,0,z0) heading -y, rising/settling to z1, curling by curl_turn at the tip."""
    pts, radii = [], []
    x = y = 0.0; h = -math.pi / 2
    ds = length / n
    for i in range(n + 1):
        f = i / n
        z = z0 + (z1 - z0) * min(f * 1.6, 1) + 2.2 * math.sin(f * math.pi) * (1 - f)
        pts.append((x, y, z)); radii.append(r0 + (r1 - r0) * f ** 0.8)
        h += side * curl_turn * (f ** 2.2) * 3.2 / n
        x += ds * math.cos(h); y += ds * math.sin(h)
    return pts, radii


boxes = {}

# ------------------------------------------------------------------ the head
sc = reset(); so = lights(sc)
SKIN = skin('skin', (0.035, 0.13, 0.10), (0.10, 0.30, 0.23), scale=0.22)
SKIN_DARK = skin('skinDark', (0.02, 0.08, 0.07), (0.06, 0.20, 0.16), scale=0.3)
WING = mat('wing', (0.03, 0.09, 0.08), rough=0.5, coat=0.3)
EYE = mat('eye', (1.0, 0.62, 0.12), rough=0.2, emit=(1.0, 0.62, 0.12), emit_strength=2.6)
PUPIL = mat('pupil', (0.0, 0.0, 0.0), rough=0.15, coat=1.0)
SOCKET = mat('socket', (0.01, 0.03, 0.03), rough=0.6)

# the mantle: a tall ovoid leaning back (up the table), sitting in the water at the head circle
sphere('mantle', (0, 3, 14), (15.5, 14.5, 21), SKIN, rot=(math.radians(-24), 0, 0))
# the face: a broad lower bulge on the player's side, and a heavy brow ridge over the eyes
sphere('face', (0, -7.5, 11), (13.5, 9.5, 10), SKIN)
sphere('brow', (0, -10.5, 17.2), (12.5, 4.2, 3.4), SKIN_DARK, rot=(math.radians(-10), 0, 0))
for sx in (-1, 1):                     # deep-set slanted eyes under the brow: dark socket, glowing eye, slit pupil
    sphere('socket' + str(sx), (sx * 5.8, -13.2, 14.6), (3.9, 2.4, 2.7), SOCKET, rot=(0, 0, sx * 0.25), segs=32)
    sphere('eye' + str(sx), (sx * 5.8, -14.2, 14.5), (3.0, 1.6, 1.9), EYE, rot=(0, 0, sx * 0.25), segs=32)
    sphere('pupil' + str(sx), (sx * 5.8, -15.6, 14.5), (0.55, 0.4, 1.7), PUPIL, segs=24)
# the beard: short face tentacles hanging from under the eyes onto the water toward the player
for k, (bx, ang, ln) in enumerate([(-9, -0.75, 14), (-5.5, -0.40, 17), (-2, -0.12, 19),
                                    (2, 0.12, 19), (5.5, 0.40, 17), (9, 0.75, 14)]):
    pts, rad = curl(ln, 2.6, 0.7, 8.5, 1.4, 1.1 * (1 if bx < 0 else -1), n=24)
    ca, sa = math.cos(ang), math.sin(ang)
    pts = [(bx + x * ca - y * sa, -11 + x * sa + y * ca, z) for x, y, z in pts]
    tube(f'beard{k}', pts, rad, SKIN_DARK if k % 2 else SKIN, res=4)
# two small ribbed wings behind the head, raised and swept back
for sx in (-1, 1):
    bm = bmesh.new()
    # a bat-like membrane: three bony fingers from the shoulder, the edge scalloped in between
    root = [(sx * 11, 9, 17), (sx * 10, 12, 9)]
    tips = [(sx * 23, 16, 30), (sx * 27, 14, 20), (sx * 23, 10, 11)]
    edge = [tips[0]]
    for a, b in zip(tips, tips[1:]):
        mx, my, mz = [(a[i] + b[i]) / 2 for i in range(3)]
        edge += [(mx - sx * 3.2, my - 0.5, mz), b]                 # scallop: the membrane sags in between
    vs = [bm.verts.new(p) for p in [root[0]] + edge + [root[1]]]
    bm.faces.new(vs)
    me = bpy.data.meshes.new('wing'); bm.to_mesh(me); bm.free(); me.materials.append(WING)
    o = link(bpy.data.objects.new('wing' + str(sx), me))
    s = o.modifiers.new('s', 'SOLIDIFY'); s.thickness = 0.8
    for t in tips:                                            # bony ribs out to each tip
        tube(f'rib{sx}{t[2]}', [root[0], t], [1.1, 0.4], SKIN_DARK, res=3)
boxes['cthulhu'] = finish(sc, so, 'cth_cthulhu.png')

# ------------------------------------------------------------------ five big tentacles
# Each is rendered in its own place round the head, so the light and shadow stay right (CthCthulhu.tentacleBases).
# (angle deg: 0 = straight down the table toward the player, + = toward +x; base distance from the centre; raised?)
TENTACLES = [(-80, 19, False), (-45, 19, False), (180, 12, True), (45, 19, False), (80, 19, False)]
for k, (deg, dist, raised) in enumerate(TENTACLES):
    sc = reset(); so = lights(sc)
    SKIN = skin('skin', (0.035, 0.13, 0.10), (0.10, 0.30, 0.23), scale=0.22)
    SUCK = mat('sucker', (0.62, 0.55, 0.45), rough=0.35, coat=0.5)
    side = 1 if deg >= 0 else -1                              # curl outward
    if raised:
        pts, rad = curl(36, 4.8, 0.9, 6.0, 26.0, 2.6, n=48, side=side)
    else:
        pts, rad = curl(34, 4.6, 0.9, 6.0, 2.2, 2.4, n=48, side=side)
    th = math.radians(deg); ct, st = math.cos(th), math.sin(th)
    rot = lambda x, y: (x * ct - y * st, x * st + y * ct)      # CCW by th: (0,-1) → (sin th, -cos th)
    pts = [(*rot(x, y), z) for x, y, z in pts]
    tube('tentacle', pts, rad, SKIN)
    for i in range(4, 44, 4):                                 # suckers on the inside of the curl
        (x0_, y0_, z0_), (x1_, y1_, z1_) = pts[i], pts[i + 1]
        hx, hy = x1_ - x0_, y1_ - y0_; hl = math.hypot(hx, hy)
        nx, ny = side * -hy / hl, side * hx / hl
        r = rad[i]
        sphere(f'suck{i}', (x0_ + nx * r * 0.8, y0_ + ny * r * 0.8, z0_ - r * 0.35), (r * 0.32, r * 0.32, r * 0.22), SUCK, segs=16)
    boxes[f'tentacle{k}'] = finish(sc, so, f'cth_tentacle{k}.png')

json.dump(boxes, open(os.path.join(OUT, 'cthulhu.json'), 'w'))
print('boxes', boxes)
