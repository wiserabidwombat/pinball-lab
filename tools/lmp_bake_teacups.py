"""Table 05 (The Lamplight) M9 v9: the three bumpers as bone-china teacups on saucers (oblique view, the table's
light, a shadow-catcher floor). The cup's rim is the bumper's 22 pt radius; a blue band with gold lines round the
cup, a gold rim, tea inside, a handle to the right. lmp_bumper_lit is the same cup with the tea glowing warm and the
gold catching it (the game cross-fades it in on each hit). Image box = LmpTableLayout.bumperArtBox (x -34…48,
y -40…46 around the bumper's centre).
Usage: python3 lmp_bake_teacups.py -- out_dir [samples]"""
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = os.path.abspath(argv[0])
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
BX0, BY0, BW, BH = -34.0, -40.0, 82.0, 86.0
K = L.OBLIQUE
R_TOP, R_FOOT, CUP_Z0, CUP_Z1 = 22.0, 14.0, 2.0, 18.0


def build(lit):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
    sc.render.resolution_x = int(BW * L.PX_PER_PT); sc.render.resolution_y = int(BH * L.PX_PER_PT)
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'

    def mat(name, color, metal=0.0, rough=0.4, coat=0.0, emit=None, strength=0.0):
        m = bpy.data.materials.new(name); m.use_nodes = True
        b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = (*color, 1); b.inputs['Metallic'].default_value = metal
        b.inputs['Roughness'].default_value = rough; b.inputs['Coat Weight'].default_value = coat
        if emit:
            b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = strength
        return m

    gold = mat('gold', (0.92, 0.72, 0.36), metal=1.0, rough=0.25,
               emit=(1.0, 0.75, 0.4) if lit else None, strength=0.6 if lit else 0.0)
    china = mat('china', (0.95, 0.93, 0.88), rough=0.15, coat=0.6)
    # the cup's outside: white china with a blue band between z 8 and 12.5, picked out by the object's height
    nt = china.node_tree; b = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(tc.outputs['Object'], sep.inputs[0])
    gt = nt.nodes.new('ShaderNodeMath'); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = 8.0
    lt = nt.nodes.new('ShaderNodeMath'); lt.operation = 'LESS_THAN'; lt.inputs[1].default_value = 12.5
    nt.links.new(sep.outputs['Z'], gt.inputs[0]); nt.links.new(sep.outputs['Z'], lt.inputs[0])
    band = nt.nodes.new('ShaderNodeMath'); band.operation = 'MULTIPLY'
    nt.links.new(gt.outputs[0], band.inputs[0]); nt.links.new(lt.outputs[0], band.inputs[1])
    vor = nt.nodes.new('ShaderNodeTexVoronoi'); vor.inputs['Scale'].default_value = 0.6     # little flowers in the band
    nt.links.new(tc.outputs['Object'], vor.inputs['Vector'])
    flowers = nt.nodes.new('ShaderNodeMix'); flowers.data_type = 'RGBA'
    flowers.inputs['A'].default_value = (0.12, 0.22, 0.52, 1); flowers.inputs['B'].default_value = (0.93, 0.92, 0.88, 1)
    st = nt.nodes.new('ShaderNodeMath'); st.operation = 'LESS_THAN'; st.inputs[1].default_value = 0.18
    nt.links.new(vor.outputs['Distance'], st.inputs[0]); nt.links.new(st.outputs[0], flowers.inputs['Factor'])
    mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'
    mix.inputs['A'].default_value = (0.95, 0.93, 0.88, 1)
    nt.links.new(band.outputs[0], mix.inputs['Factor']); nt.links.new(flowers.outputs['Result'], mix.inputs['B'])
    nt.links.new(mix.outputs['Result'], b.inputs['Base Color'])
    tea = mat('tea', (0.16, 0.06, 0.015), rough=0.05, coat=1.0,
              emit=(1.0, 0.42, 0.10) if lit else None, strength=1.1 if lit else 0.0)
    blue = mat('blue', (0.12, 0.22, 0.52), rough=0.2, coat=0.6)
    plain = mat('saucer', (0.95, 0.93, 0.88), rough=0.15, coat=0.6)

    def smooth(o):
        for p in o.data.polygons: p.use_smooth = True

    # the cup: an open flared cone, given a wall by Solidify
    bpy.ops.mesh.primitive_cone_add(vertices=96, radius1=R_FOOT, radius2=R_TOP, depth=CUP_Z1 - CUP_Z0,
                                    end_fill_type='NOTHING', location=(0, 0, (CUP_Z0 + CUP_Z1) / 2))
    cup = bpy.context.object; cup.data.materials.append(china); smooth(cup)
    bpy.ops.object.transform_apply(location=True)                 # object coordinates = world, for the band
    sol = cup.modifiers.new('wall', 'SOLIDIFY'); sol.thickness = 1.4; sol.offset = -1
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=R_FOOT, depth=0.6, location=(0, 0, CUP_Z0 + 0.3))
    bpy.context.object.data.materials.append(china)
    tea_r = R_FOOT + (R_TOP - R_FOOT) * (14.5 - CUP_Z0) / (CUP_Z1 - CUP_Z0) - 1.5
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=tea_r, depth=0.4, location=(0, 0, 14.5))
    bpy.context.object.data.materials.append(tea)
    for (r, z, minor, m) in ((R_TOP - 0.6, CUP_Z1, 0.8, gold), (R_FOOT + 8 * 6.0 / 16 + 0.1, 8.0, 0.35, gold),
                             (R_FOOT + 8 * 10.5 / 16 + 0.1, 12.5, 0.35, gold)):
        bpy.ops.mesh.primitive_torus_add(location=(0, 0, z), major_radius=r, minor_radius=minor,
                                         major_segments=96, minor_segments=12)
        o = bpy.context.object; o.data.materials.append(m); smooth(o)
    # the handle: a loop on the right
    cu = bpy.data.curves.new('handle', 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = 1.6; cu.bevel_resolution = 4
    sp = cu.splines.new('BEZIER'); sp.bezier_points.add(2)
    for bp, (co, hl, hr) in zip(sp.bezier_points, [((20.5, 0, 15.5), (18, 0, 16), (25, 0, 16.5)),
                                                    ((28.5, 0, 10.5), (28.5, 0, 14.5), (28.5, 0, 6.5)),
                                                    ((17.5, 0, 6.0), (23, 0, 4.5), (15, 0, 6.5))]):
        bp.co = co; bp.handle_left = hl; bp.handle_right = hr
    cu.materials.append(china)
    sc.collection.objects.link(bpy.data.objects.new('handle', cu))
    # the saucer, with a raised lip and a gold line
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=30, depth=1.6, location=(0, 0, 0.8))
    bpy.context.object.data.materials.append(plain)
    bpy.ops.mesh.primitive_torus_add(location=(0, 0, 1.8), major_radius=29.0, minor_radius=1.3,
                                     major_segments=96, minor_segments=12)
    o = bpy.context.object; o.data.materials.append(plain); smooth(o)
    bpy.ops.mesh.primitive_torus_add(location=(0, 0, 1.75), major_radius=26.0, minor_radius=0.35,
                                     major_segments=96, minor_segments=8)
    bpy.context.object.data.materials.append(gold)
    bpy.ops.mesh.primitive_torus_add(location=(0, 0, 1.62), major_radius=23.0, minor_radius=1.1,
                                     major_segments=96, minor_segments=8)      # a blue band painted on the saucer
    o = bpy.context.object; o.scale = (1, 1, 0.12); o.data.materials.append(blue)

    # oblique shear (after applying modifiers and turning the handle curve into a mesh)
    bpy.ops.object.select_all(action='DESELECT')
    for o in sc.objects:
        if o.type in ('MESH', 'CURVE'): o.select_set(True)
    bpy.context.view_layer.objects.active = cup
    bpy.ops.object.convert(target='MESH')
    for o in sc.objects:
        if o.type != 'MESH': continue
        mw = o.matrix_world.copy(); o.data.transform(mw); o.matrix_world.identity()
        for v in o.data.vertices: v.co.y += v.co.z * K
    bpy.ops.mesh.primitive_plane_add(size=300, location=(0, 0, 0))
    bpy.context.object.is_shadow_catcher = True

    sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 3.0; sun.angle = math.radians(12); sun.color = (1.0, 0.86, 0.66)
    so = bpy.data.objects.new('key', sun); so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new('fill', 'SUN'); fill.energy = 0.5; fill.angle = math.radians(30); fill.color = (0.75, 0.8, 1.0)
    fo = bpy.data.objects.new('fill', fill); fo.rotation_euler = (math.radians(30), math.radians(25), 0)
    sc.collection.objects.link(fo)
    for i, (x, y) in enumerate(((-200, 100), (200, 150), (0, -250))):           # warm soft boxes for the glaze
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

    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = max(BW, BH); cam.clip_end = 3000
    co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co)
    co.location = (BX0 + BW / 2, BY0 + BH / 2, 1000); sc.camera = co
    return sc


os.makedirs(OUT, exist_ok=True)
for lit in (False, True):
    sc = build(lit)
    path = os.path.join(OUT, 'lmp_bumper_lit.png' if lit else 'lmp_bumper.png')
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print('rendered', path)
