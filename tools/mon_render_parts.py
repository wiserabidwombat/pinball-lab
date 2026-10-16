"""Table 04 (Monsoon) milestone 9 round 3: the bumpers and the saguaro standups as sprites, in the table's light and
22-degree lean, shadows baked onto a transparent background (Table 03's part pipeline, cth_render_parts2.py).
  mon_bumper.png / mon_bumper_lit.png     pop bumper as a storm cloud: chrome ring and dark skirt as before, the cap a
                                          puffy violet-grey cloud with a gold lightning bolt; lit = lightning inside
  mon_standup.png / mon_standup_lit.png   saguaro standup (12 x 24 plate, 10 tall so the bank doesn't run together):
                                          a ribbed green cactus plate on a steel foot, a cactus flower on top; lit = the
                                          flower and the plate glow
Pencil versions (_sketch) are made from these by mon_parts_sketch.py; the game cross-fades sketch → color as the part's
region is painted.
Usage: python3 mon_render_parts.py -- out_dir [samples] [only]"""
import bpy, bmesh, math, sys, os, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
ONLY = argv[2].split(',') if len(argv) > 2 else None
os.makedirs(OUT, exist_ok=True)
K = L.OBLIQUE
PX = 6
BUMPER_BOX = (-40, -48, 56, 52)          # = MonTableLayout.bumperArtBox
STANDUP_BOX = (-14, -18, 16, 24)


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
    fl = bpy.context.object; fl.data.materials.append(mat('reflect', (0.08, 0.22, 0.21), rough=0.6))
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


def prism(name, pts, z0, z1, m):
    bm = bmesh.new()
    face = bm.faces.new([bm.verts.new((px, py, z0)) for px, py in pts])
    if face.normal.z < 0: face.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)]: v.co.z = z1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(m)
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o


def blob(name, x, y, z, rx, ry, rz, m):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=(x, y, z), segments=32, ring_count=16)
    o = bpy.context.object; o.name = name; o.scale = (rx, ry, rz); o.data.materials.append(m)
    bpy.ops.object.transform_apply(scale=True)
    return o


# ------------------------------------------------------------------ storm-cloud pop bumper (r 28)
for lit in ((False, True) if want('bumper') else ()):
    sc = reset(); lights(sc)
    black = mat('skirt', (0.03, 0.025, 0.04), rough=0.35, coat=0.4)
    body_m = mat('body', (0.82, 0.78, 0.72), rough=0.35, coat=0.4)
    chrome = mat('chrome', (0.92, 0.93, 0.95), metal=1.0, rough=0.12)
    cloud = mat('cloud', (0.24, 0.21, 0.30), rough=0.85, coat=0.0, spec=0.15,
                emit=(1.0, 0.86, 0.60), emit_strength=0.40 if lit else 0.0)
    cloud_light = mat('cloudtop', (0.46, 0.42, 0.52), rough=0.85, coat=0.0, spec=0.15,
                      emit=(1.0, 0.92, 0.72), emit_strength=0.55 if lit else 0.0)
    bolt = mat('bolt', (0.95, 0.75, 0.30), metal=0.6, rough=0.25,
               emit=(1.0, 0.85, 0.45), emit_strength=2.0 if lit else 0.15)
    R = L.BUMPER_R
    cyl('skirt', R + 2, 0, 3, black, bevel=1.2)
    cyl('body', R - 4, 3, 13, body_m, bevel=1.0)
    torus('ring', R - 1.5, 2.2, 8, chrome)
    for k in range(6):
        a = k * math.pi / 3
        cyl(f'rod{k}', 1.0, 3, 8, chrome, x=(R - 1.5) * math.cos(a), y=(R - 1.5) * math.sin(a), verts=16)
    # the cloud: a ring of puffs round a bigger middle one, lighter on top
    rnd = random.Random(7)
    blob('puff0', 0, 0, 17, 15, 14, 7, cloud)
    for k in range(11):                                  # irregular puffs, big and small, round the edge
        a = k * 2 * math.pi / 11 + rnd.uniform(-0.15, 0.15)
        rr = R - 10 + rnd.uniform(-3, 1.5)
        rad = rnd.uniform(5.5, 9.5)
        blob(f'puff{k + 1}', rr * math.cos(a), rr * math.sin(a), 14.5 + rnd.uniform(0, 2.5), rad, rad * rnd.uniform(0.85, 1.1),
             rad * 0.6, cloud)
    blob('crown0', -5, 4, 21, 8, 7, 4, cloud_light)
    blob('crown1', 5, 1, 20.5, 7, 6, 3.5, cloud_light)
    # a gold lightning bolt lying on the cloud
    pts = [(-3, 11), (4, 11), (0.5, 2.5), (5.5, 2.5), (-4, -12), (-0.8, -1.5), (-5.5, -1.5)]
    prism('bolt', list(reversed(pts)), 23.5, 25.2, bolt)
    lean(sc); camera(sc, BUMPER_BOX)
    render(sc, 'mon_bumper_lit.png' if lit else 'mon_bumper.png')

# ------------------------------------------------------------------ saguaro standup (12 x 24)
for lit in ((False, True) if want('standup') else ()):
    sc = reset(); lights(sc)
    steel = mat('steel', (0.55, 0.57, 0.60), metal=1.0, rough=0.3)
    green = mat('cactus', (0.11, 0.22, 0.09), rough=0.45, coat=0.5, coat_rough=0.2,
                emit=(0.55, 0.95, 0.45), emit_strength=0.22 if lit else 0.0)
    rib = mat('rib', (0.20, 0.34, 0.15), rough=0.4, coat=0.3,
              emit=(0.75, 1.0, 0.6), emit_strength=0.3 if lit else 0.0)
    spine = mat('spine', (0.92, 0.88, 0.76), rough=0.4)
    petal = mat('flower', (0.98, 0.52, 0.70), rough=0.35, coat=0.4,
                emit=(1.0, 0.60, 0.78), emit_strength=1.1 if lit else 0.0)
    eye = mat('flowerEye', (1.0, 0.85, 0.35), rough=0.4, emit=(1.0, 0.85, 0.4), emit_strength=1.0 if lit else 0.0)
    box('foot', -6.5, -12.5, 6.5, 12.5, 0, 1.2, steel, bevel=0.4)
    box('plate', -5, -11, 5, 11, 1.2, 10, green, bevel=2.2)
    for k, x in enumerate((-2.6, 0, 2.6)):                 # vertical ribs along the plate
        box(f'rib{k}', x - 0.55, -10, x + 0.55, 10, 9.6, 10.4, rib, bevel=0.4)
    for j in range(5):                                      # spines on the ribs
        for x in (-2.6, 0, 2.6):
            cyl(f'sp{j}{x}', 0.28, 10.3, 11.0, spine, x=x, y=-8 + j * 4, verts=8)
    for k in range(6):                                      # a cactus flower at the top end
        a = k * math.pi / 3
        blob(f'petal{k}', 2.0 * math.cos(a), 8 + 2.0 * math.sin(a), 11.2, 1.8, 1.8, 0.8, petal)
    blob('eye', 0, 8, 11.8, 1.0, 1.0, 0.6, eye)
    lean(sc); camera(sc, STANDUP_BOX)
    render(sc, 'mon_standup_lit.png' if lit else 'mon_standup.png')
