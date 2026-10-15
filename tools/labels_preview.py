import cairo, math, sys
from PIL import Image
sys.path.insert(0, '/home/claude/gi-src/tools')
# Label specs mirror TableLabels.swift: text, (x,y), base size, colour, vAlign, maxScale, angle(deg)
SPECS = [
 ("HANGAR", (284, 627), 6, '#e9e6f5', 'top', 2.4, 0),
 ("ABDUCTION", (470, 677), 6, '#e9e6f5', 'top', 2.0, 0),
 ("LOCKS", (470, 747), 4, "#b8ffcc", "bottom", 3.0, 0),
 ("EARTH DEFENSE", (284, 465), 5.5, '#9cc4ff', 'bottom', 2.2, 0),
 ("SHIPS DOWN", (284, 401), 5, '#ffe58a', 'top', 2.4, 0),
 ("SHIELDS UP", (284, 289), 5, '#d7b8ff', 'top', 2.4, 0),
 ("KICKBACK", (37, 300), 3.6, "#ffc9a0", "center", 3.0, 90),
 ("SAVE", (531, 300), 3.6, "#a8fff4", "center", 3.0, 90),
 ("TRACTOR BEAM", (420, 760), 6.5, '#d9ffe3', 'center', 1.9, 70.9),
 ("DEFENSE CANNON", (172, 770), 6.5, '#d9ffe3', 'center', 1.9, -70.9),
]
MIN_SCREEN = 9.0
cam = float(sys.argv[1]) if len(sys.argv) > 1 else 1.66
K_ART = 2.9; PX = 3 / cam          # preview pixels per world point (3x retina)
art = Image.open('/home/claude/gi-src/tools/playfield.png').convert('RGB')
W, H = art.size
art = art.resize((int(W * PX / K_ART), int(H * PX / K_ART)), Image.LANCZOS)
art.save('/tmp/claude-0/prev/base.png')
surf = cairo.ImageSurface.create_from_png('/tmp/claude-0/prev/base.png')
c = cairo.Context(surf)
Hpx = surf.get_height()
def to_px(x, y): return ((x + 40) * PX, Hpx - (y + 75) * PX)
for text, (x, y), base, col, va, mx, ang in SPECS:
    scale = min(mx, max(1, cam * MIN_SCREEN / base))
    size = base * scale
    c.save(); c.translate(*to_px(x, y)); c.rotate(-math.radians(ang)); c.scale(PX, PX)
    c.select_font_face("Orbitron", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD); c.set_font_size(size)
    e = c.text_extents(text); fe = c.font_extents()
    tx = -e.width / 2 - e.x_bearing
    capH = -e.y_bearing
    ty = {'top': capH, 'bottom': 0, 'center': capH / 2}[va]
    h = col.lstrip('#'); rgbv = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    c.set_source_rgba(0, 0, 0, 0.7); c.move_to(tx + 0.06 * size, ty + 0.06 * size); c.show_text(text)
    c.set_source_rgb(*rgbv); c.move_to(tx, ty); c.show_text(text)
    c.restore()
    print("%-15s world %.1f pt  screen %.1f pt" % (text, size, size / cam))
surf.write_to_png('/tmp/claude-0/prev/topdown.png')
