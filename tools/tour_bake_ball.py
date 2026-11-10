"""Table 06 (Orbit: Grand Tour) M5 v2: a realistic chrome ball (Aaron: "aim for a more realistic metallic ball... maybe
like Crystal Caliburn 2"). A mirror-polished steel sphere rendered top-down on a transparent film, reflecting what a
real ball sees: the table's own floor painting under and around it (navy space, stars, the blue of Earth), the cabinet's
dark sides, and two soft studio lights above (a big window from the upper left — the table's key — and a thin cool strip
from the right), plus a faint warm bounce from the player's end. The floor and lights are invisible to the camera, so
only the ball is in the picture. In the game the sprite is counter-rotated every frame, so the reflections stay put
while the body rolls, as the lighting would.
Usage: python3 tour_bake_ball.py -- floor.png out.png [px] [samples]"""
import bpy, math, sys, os
argv = sys.argv[sys.argv.index('--') + 1:]
FLOOR, OUT = os.path.abspath(argv[0]), os.path.abspath(argv[1])
PX = int(argv[2]) if len(argv) > 2 else 192
SAMPLES = int(argv[3]) if len(argv) > 3 else 256

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
sc.render.resolution_x = sc.render.resolution_y = PX
sc.render.film_transparent = True
sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
sc.cycles.max_bounces = 8; sc.cycles.glossy_bounces = 6


def link(o):
    sc.collection.objects.link(o); return o


def emitter(name, loc, scale, rot, strength, col):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc, rotation=rot)
    p = bpy.context.object; p.name = name; p.scale = scale
    m = bpy.data.materials.new(name); m.use_nodes = True
    n = m.node_tree.nodes; n.clear()
    o = n.new('ShaderNodeOutputMaterial'); e = n.new('ShaderNodeEmission')
    e.inputs['Strength'].default_value = strength; e.inputs['Color'].default_value = (*col, 1)
    m.node_tree.links.new(e.outputs[0], o.inputs[0])
    p.data.materials.append(m); p.visible_camera = False; p.visible_shadow = False
    c = p.constraints.new('TRACK_TO'); c.target = BALL; c.track_axis = 'TRACK_Z'; c.up_axis = 'UP_Y'   # face the ball
    return p


def toward(nx, ny, nz, dist):
    """Where a light must sit so its mirror image appears where the sphere's normal is (nx, ny, nz), seen from above:
    the reflection of the view ray (0, 0, -1) about that normal."""
    l = math.sqrt(nx * nx + ny * ny + nz * nz); nx, ny, nz = nx / l, ny / l, nz / l
    d = (2 * nz * nx, 2 * nz * ny, 2 * nz * nz - 1)
    return (d[0] * dist, d[1] * dist, 1 + d[2] * dist)


# the ball: radius 1, polished steel (slightly warm grey, very low roughness, a whisper of clear coat for the sharp spec)
bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=96, ring_count=48, location=(0, 0, 1))
ball = bpy.context.object
BALL = ball
for p in ball.data.polygons: p.use_smooth = True
m = bpy.data.materials.new('steel'); m.use_nodes = True
b = m.node_tree.nodes['Principled BSDF']
b.inputs['Base Color'].default_value = (0.80, 0.81, 0.83, 1)
b.inputs['Metallic'].default_value = 1.0
b.inputs['Roughness'].default_value = 0.06
b.inputs['Coat Weight'].default_value = 0.15; b.inputs['Coat Roughness'].default_value = 0.01
ball.data.materials.append(m)

# the floor the ball rolls on: the table's painting, big enough to fill the lower half of the reflection (1 unit = 9 pt)
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 4, 0))
fl = bpy.context.object; fl.scale = (75, 86, 1)               # ~680 x 775 pt around the ball
fm = bpy.data.materials.new('floor'); fm.use_nodes = True
fb = fm.node_tree.nodes['Principled BSDF']
tex = fm.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(FLOOR)
fm.node_tree.links.new(tex.outputs['Color'], fb.inputs['Base Color'])
fb.inputs['Roughness'].default_value = 0.3; fb.inputs['Coat Weight'].default_value = 0.3
fl.data.materials.append(fm); fl.visible_camera = False; fl.visible_shadow = False
fl.hide_render = True   # v2b: CC2's rim stays dark; the reflected floor made a bright ring
# the cabinet's dark navy sides, standing up left and right
for x in (-34, 34):
    bpy.ops.mesh.primitive_plane_add(size=1, location=(x, 0, 4), rotation=(0, math.radians(90), 0))
    s = bpy.context.object; s.scale = (8, 90, 1)
    sm = bpy.data.materials.new('side'); sm.use_nodes = True
    sm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.01, 0.015, 0.04, 1)
    s.data.materials.append(sm); s.visible_camera = False; s.visible_shadow = False; s.hide_render = True

# the table's key light, so the reflected floor is as bright as in the bake (the ball itself gets it too)
sun = bpy.data.lights.new('key', 'SUN'); sun.energy = 1.2; sun.angle = math.radians(10); sun.color = (0.96, 0.97, 1.0)
so = link(bpy.data.objects.new('key', sun)); so.rotation_euler = (math.radians(-38), math.radians(-28), 0)
so.visible_glossy = False                    # lights the floor; its disc isn't one of the reflections
# lights the ball reflects: a big soft window up-left (the key), a thin cool strip to the right, a warm low bounce
emitter('window', toward(-0.30, 0.33, 0.895, 30), (23, 18, 1), (0, 0, 0), 24.0, (1.0, 1.0, 1.0))     # big crisp highlight, upper left
# M5 v2b (Aaron, with a Crystal Caliburn 2 screenshot: the ring round a bright centre made the ball look small): dark
# polished steel like CC2's — a dark room overhead, so the ball is near black, one crisp window highlight up-left,
# and a soft grey sheen in the lower half from a dim, broad light low on the player's side.
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
nt = w.node_tree; bg = nt.nodes['Background']
tc = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ')
neg = nt.nodes.new('ShaderNodeMath'); neg.operation = 'MULTIPLY'; neg.inputs[1].default_value = -1.0
ramp = nt.nodes.new('ShaderNodeValToRGB'); el = ramp.color_ramp.elements
el[0].position = 0.15; el[0].color = (0.018, 0.02, 0.028, 1)      # up and away: a dark room
el[1].position = 1.0; el[1].color = (0.34, 0.35, 0.38, 1)         # toward the player, low: a soft grey sheen
nt.links.new(tc.outputs['Generated'], sep.inputs[0]); nt.links.new(sep.outputs['Y'], neg.inputs[0])
nt.links.new(neg.outputs[0], ramp.inputs['Fac'])
# below the horizon (what the rim sees) fades to near black, so the ball's edge stays dark as on CC2's
zr = nt.nodes.new('ShaderNodeMapRange'); zr.inputs['From Min'].default_value = -0.45; zr.inputs['From Max'].default_value = 0.25
zr.inputs['To Min'].default_value = 0.12; zr.inputs['To Max'].default_value = 1.0
nt.links.new(sep.outputs['Z'], zr.inputs['Value'])
mul = nt.nodes.new('ShaderNodeMixRGB'); mul.blend_type = 'MULTIPLY'; mul.inputs['Fac'].default_value = 1.0
nt.links.new(ramp.outputs['Color'], mul.inputs['Color1'])
cmb = nt.nodes.new('ShaderNodeCombineXYZ')
nt.links.new(zr.outputs['Result'], cmb.inputs['X']); nt.links.new(zr.outputs['Result'], cmb.inputs['Y']); nt.links.new(zr.outputs['Result'], cmb.inputs['Z'])
nt.links.new(cmb.outputs[0], mul.inputs['Color2'])
# M5 v2c (Aaron: "harder to see when it's on the dark background"): a cool rim all round the silhouette — what the
# rim sees below the horizon (the lit glass edge and cabinet) is a soft blue-white, so the ball is outlined on dark floor.
rz = nt.nodes.new('ShaderNodeMapRange'); rz.inputs['From Min'].default_value = -0.92; rz.inputs['From Max'].default_value = -0.55
rz.inputs['To Min'].default_value = 1.0; rz.inputs['To Max'].default_value = 0.0
nt.links.new(sep.outputs['Z'], rz.inputs['Value'])
rimc = nt.nodes.new('ShaderNodeMixRGB'); rimc.blend_type = 'MULTIPLY'; rimc.inputs['Fac'].default_value = 1.0
rimc.inputs['Color1'].default_value = (0.20, 0.27, 0.42, 1)
rcmb = nt.nodes.new('ShaderNodeCombineXYZ')
for k in ('X', 'Y', 'Z'): nt.links.new(rz.outputs['Result'], rcmb.inputs[k])
nt.links.new(rcmb.outputs[0], rimc.inputs['Color2'])
add = nt.nodes.new('ShaderNodeMixRGB'); add.blend_type = 'ADD'; add.inputs['Fac'].default_value = 1.0
nt.links.new(mul.outputs[0], add.inputs['Color1']); nt.links.new(rimc.outputs[0], add.inputs['Color2'])
nt.links.new(add.outputs[0], bg.inputs['Color'])
w.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0
cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = 2.0
co = link(bpy.data.objects.new('cam', cam)); co.location = (0, 0, 40); sc.camera = co
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print('rendered', OUT, PX)
