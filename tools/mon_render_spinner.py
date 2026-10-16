"""Table 04 (Monsoon) M9 v5, derived from cth_render_parts2.py; run with only=spinner: mon_spinner_sheet.png (24 frames, 6 x 4, bone-gold face, dusky violet back).
Table 03 milestone 8, art round 2b: the upper table's parts as sprites, in the table's light and 22-degree lean,
with their shadows baked onto a transparent background (shadow catcher). The game places each sprite so its
origin (the part's physics centre) sits on the physics shape.
  cth_bumper.png / cth_bumper_lit.png   pop bumper (unlit / lit cap), box BUMPER_BOX
  cth_target.png / cth_target_down.png  Sigil drop target standing / dropped flush, box TARGET_BOX
  mon_spinner_sheet.png                 24 frames of the spinner turning (6 x 4), each SPIN_BOX
  cth_magnet.png                        the magnet's pole piece and coil, box MAGNET_BOX
Usage: python3 cth_render_parts2.py -- out_dir [samples]"""
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L   # Monsoon's lower table and top are Table 03's

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
ONLY = argv[2].split(',') if len(argv) > 2 else None
os.makedirs(OUT, exist_ok=True)
K = L.OBLIQUE
PX = 6

# boxes in points around each part's origin (x0, y0, x1, y1); Swift: size = (x1-x0, y1-y0), anchor = (-x0/w, -y0/h)
BUMPER_BOX = (-40, -48, 56, 52)
TARGET_BOX = (-16, -24, 26, 34)
SPIN_BOX = (-22, -10, 22, 22)
MAGNET_BOX = (-20, -20, 26, 22)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'
    return sc


def mat(name, color, metal=0.0, rough=0.4, coat=0.0, coat_rough=0.05, spec=0.5, alpha=1.0, trans=0.0,
        emit=None, emit_strength=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    b.inputs['Coat Weight'].default_value = coat
    b.inputs['Coat Roughness'].default_value = coat_rough
    b.inputs['Specular IOR Level'].default_value = spec
    b.inputs['Alpha'].default_value = alpha
    b.inputs['Transmission Weight'].default_value = trans
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1)
        b.inputs['Emission Strength'].default_value = emit_strength
    return m


def lights(sc):
    """The table render's key sun, fill and soft boxes (positions relative to the part)."""
    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.4; sun.angle = math.radians(9)
    so = bpy.data.objects.new('key', sun); sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.6; fill.angle = math.radians(30)
    fo = bpy.data.objects.new('fill', fill); sc.collection.objects.link(fo)
    fo.rotation_euler = (math.radians(30), math.radians(25), 0)
    for i, (x, y, w, h, e) in enumerate([(-500, 600, 500, 900, 2.6), (500, 0, 300, 600, 1.1), (0, -700, 900, 200, 1.2)]):
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
    # the shadow catcher: the playfield, invisible except for the shadows the part throws on it
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
    sc_plane = bpy.context.object; sc_plane.name = 'shadowcatcher'; sc_plane.is_shadow_catcher = True
    # a sea-green floor far below for chrome to reflect, unseen by the camera
    bpy.ops.mesh.primitive_plane_add(size=3000, location=(0, 0, -30))
    fl = bpy.context.object; fl.data.materials.append(mat('reflect', (0.22, 0.17, 0.12), rough=0.6))
    fl.visible_camera = False; fl.visible_shadow = False


def camera(sc, box, px=PX):
    x0, y0, x1, y1 = box
    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'
    w, h = x1 - x0, y1 - y0
    cam.ortho_scale = max(w, h)
    co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co)
    co.location = ((x0 + x1) / 2, (y0 + y1) / 2, 500)
    sc.camera = co
    sc.render.resolution_x = int(round(w * px))
    sc.render.resolution_y = int(round(h * px))


def cyl(name, r, z0, z1, m, x=0, y=0, bevel=0.0, verts=64):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=z1 - z0, location=(x, y, (z0 + z1) / 2), vertices=verts)
    o = bpy.context.object; o.name = name; o.data.materials.append(m)
    if bevel:
        b = o.modifiers.new('b', 'BEVEL'); b.width = bevel; b.segments = 4
    return o


def torus(name, major, minor, z, m, x=0, y=0):
    bpy.ops.mesh.primitive_torus_add(location=(x, y, z), major_radius=major, minor_radius=minor,
                                     major_segments=64, minor_segments=16)
    o = bpy.context.object; o.name = name; o.data.materials.append(m)
    return o


def box(name, x0, y0, x1, y1, z0, z1, m, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    o = bpy.context.object; o.name = name; o.scale = (x1 - x0, y1 - y0, z1 - z0); o.data.materials.append(m)
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        b = o.modifiers.new('b', 'BEVEL'); b.width = bevel; b.segments = 3
    return o


def star(name, r_out, r_in, z0, z1, m, x=0, y=0, n=5):
    bm = bmesh.new()
    pts = []
    for i in range(2 * n):
        r = r_out if i % 2 == 0 else r_in
        a = math.pi / 2 + i * math.pi / n
        pts.append((x + r * math.cos(a), y + r * math.sin(a)))
    face = bm.faces.new([bm.verts.new((px, py, z0)) for px, py in pts])
    if face.normal.z < 0: face.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)]: v.co.z = z1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(m)
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o


def lean(sc):
    """Apply modifiers, bake transforms, then shear every visible part y += z * K (the table's oblique view)."""
    for o in [o for o in sc.objects if o.type in ('MESH', 'CURVE') and o.visible_camera and o.name != 'shadowcatcher'
              and not o.name.startswith('box') and o.data.materials and o.data.materials[0].name != 'reflect']:
        bpy.ops.object.select_all(action='DESELECT')
        o.select_set(True); bpy.context.view_layer.objects.active = o
        if o.type == 'CURVE': bpy.ops.object.convert(target='MESH')
        for m in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=m.name)
        o.data.transform(o.matrix_world); o.matrix_world.identity()
        for v in o.data.vertices: v.co.y += v.co.z * K
        for p in o.data.polygons: p.use_smooth = True


def render(sc, name):
    sc.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)
    print('rendered', name, sc.render.resolution_x, sc.render.resolution_y)


def want(k): return ONLY is None or k in ONLY


# ------------------------------------------------------------------ pop bumper (r 28): skirt, body, chrome ring, cap
for lit in ((False, True) if want('bumper') else ()):
    sc = reset(); lights(sc)
    black = mat('skirt', (0.02, 0.02, 0.025), rough=0.35, coat=0.4)
    ivory = mat('body', (0.90, 0.86, 0.76), rough=0.3, coat=0.5)
    chrome = mat('chrome', (0.92, 0.93, 0.95), metal=1.0, rough=0.12)
    gold = mat('gold', (0.86, 0.66, 0.30), metal=1.0, rough=0.25)
    cap = mat('cap', (0.05, 0.40, 0.35), rough=0.12, coat=0.8, coat_rough=0.05, trans=0.25,
              emit=(0.30, 1.0, 0.80), emit_strength=1.1 if lit else 0.06)
    pupil = mat('pupil', (0.01, 0.01, 0.01), rough=0.3,
                emit=(1.0, 0.75, 0.3), emit_strength=0.0)
    R = L.BUMPER_R
    cyl('skirt', R + 2, 0, 3, black, bevel=1.2)
    cyl('body', R - 4, 3, 15, ivory, bevel=1.0)
    torus('ring', R - 1.5, 2.2, 9, chrome)
    for k in range(6):                                   # the ring's support rods
        a = k * math.pi / 3
        cyl(f'rod{k}', 1.0, 3, 9, chrome, x=(R - 1.5) * math.cos(a), y=(R - 1.5) * math.sin(a), verts=16)
    cyl('cap', R - 3, 15, 23, cap, bevel=3.0)
    torus('eyeRing', 9, 0.9, 23.2, gold)                 # an eye on the cap: gold ring, dark pupil
    cyl('pupil', 4, 23.0, 23.6, pupil, bevel=0.5, verts=32)
    cyl('screw', 1.6, 23.4, 24.2, gold, verts=24)
    lean(sc); camera(sc, BUMPER_BOX)
    render(sc, 'cth_bumper_lit.png' if lit else 'cth_bumper.png')

# ------------------------------------------------------------------ Sigil drop target (12 x 24, facing left)
for down in ((False, True) if want('target') else ()):
    sc = reset(); lights(sc)
    teal = mat('plate', (0.05, 0.28, 0.26), rough=0.3, coat=0.6)
    bone = mat('edge', (0.88, 0.83, 0.70), rough=0.35, coat=0.4)
    gold = mat('gold', (0.86, 0.66, 0.30), metal=1.0, rough=0.25)
    slot = mat('slot', (0.01, 0.01, 0.012), rough=0.6)
    if down:
        # T3 M8 v8 (Aaron: dropped targets looked "still there"): an empty dark slot with a thin steel frame,
        # nothing standing in it
        steel = mat('steel', (0.55, 0.57, 0.60), metal=1.0, rough=0.3)
        box('frame', -5.6, -10.6, 5.6, 10.6, -0.2, 0.5, steel, bevel=0.3)
        box('slot', -4.6, -9.6, 4.6, 9.6, -0.2, 0.7, slot, bevel=0.2)
    else:
        # T3 M8 v6 (Aaron: the targets "run together"): 12 tall and 19 long (was 20 and 22), so with the lean
        # each one ends ~5 pt short of the next one up the bank
        box('plate', -4.5, -9.5, 4.5, 9.5, 0, 12, teal, bevel=0.8)
        box('cap', -4.9, -9.9, 4.9, 9.9, 12, 13.5, teal, bevel=0.5)
        torus('sigil', 3.2, 0.6, 13.8, gold)
        star('sigilStar', 2.6, 1.0, 13.5, 14.2, gold)
        box('face', -5.1, -7.5, -4.5, 7.5, 2, 10, bone, bevel=0.2)   # a bone strip down the hit face
    lean(sc); camera(sc, TARGET_BOX)
    render(sc, 'cth_target_down.png' if down else 'cth_target.png')

# ------------------------------------------------------------------ spinner: 24 frames, one turn about its axle
if want('spinner'):
    import numpy as np
    frames = []
    for f in range(24):
        sc = reset(); lights(sc)
        chrome = mat('chrome', (0.92, 0.93, 0.95), metal=1.0, rough=0.15)
        face_m = mat('face', (0.93, 0.84, 0.58), metal=0.6, rough=0.25)      # bone-gold front
        back_m = mat('back', (0.16, 0.12, 0.22), rough=0.4)                  # dark back
        gold = mat('gold', (0.86, 0.66, 0.30), metal=1.0, rough=0.25)
        AX = 14                                                              # axle height
        span = (L.ORBIT_X - L.LEFT_X) - 6                                    # 32: the blade's width
        bpy.ops.mesh.primitive_cylinder_add(radius=1.2, depth=span + 6, location=(0, 0, AX), rotation=(0, math.pi / 2, 0), vertices=24)
        bpy.context.object.data.materials.append(chrome)
        # the blade hangs from the axle (angle 0); it turns about x
        th = 2 * math.pi * f / 24
        bm = bmesh.new()
        d = (0, math.sin(th), -math.cos(th))          # down the blade
        n = (0, math.cos(th), math.sin(th))           # the gold face's normal
        corners = [(-span / 2, 1), (span / 2, 1), (span / 2, 12), (-span / 2, 12)]
        vs = [bm.verts.new((sx, t * d[1], AX + t * d[2])) for sx, t in corners]
        bm.faces.new(vs)
        ext = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
        for v in [e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)]:
            v.co.y += 0.8 * n[1]; v.co.z += 0.8 * n[2]
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new('blade'); bm.to_mesh(me); bm.free()
        me.materials.append(face_m); me.materials.append(back_m)
        for poly in me.polygons:                      # one side gold, the other side and the edges dark
            poly.material_index = 0 if poly.normal.y * n[1] + poly.normal.z * n[2] > 0.5 else 1
        blade = bpy.data.objects.new('blade', me); sc.collection.objects.link(blade)
        lean(sc); camera(sc, SPIN_BOX)
        name = f'_spin{f:02d}.png'
        render(sc, name)
        frames.append(os.path.join(OUT, name))
    # stitch 6 x 4
    from PIL import Image
    ims = [Image.open(fn).convert('RGBA') for fn in frames]
    fw, fh = ims[0].size
    sheet = Image.new('RGBA', (fw * 6, fh * 4), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        sheet.paste(im, ((i % 6) * fw, (i // 6) * fh))
    sheet.save(os.path.join(OUT, 'mon_spinner_sheet.png'))
    for fn in frames: os.remove(fn)
    print('sheet', sheet.size, 'frame', fw, fh)

# ------------------------------------------------------------------ magnet: steel pole piece, copper coil, brass bolt
if want('magnet'):
    sc = reset(); lights(sc)
    steel = mat('steel', (0.30, 0.32, 0.35), metal=1.0, rough=0.35)
    copper = mat('copper', (0.80, 0.42, 0.20), metal=1.0, rough=0.25)
    brass = mat('brass', (0.86, 0.66, 0.30), metal=1.0, rough=0.2)
    dark = mat('dark', (0.03, 0.03, 0.035), rough=0.5)
    cyl('well', 17, -0.5, 0.6, dark, bevel=0.4)
    for k in range(4):
        torus(f'coil{k}', 13.5, 1.4, 1.2 + k * 1.1, copper)
    cyl('pole', 10.5, 0, 4.2, steel, bevel=1.2)
    cyl('bolt', 3.2, 4.2, 5.4, brass, bevel=0.6, verts=6)
    lean(sc); camera(sc, MAGNET_BOX)
    render(sc, 'cth_magnet.png')
