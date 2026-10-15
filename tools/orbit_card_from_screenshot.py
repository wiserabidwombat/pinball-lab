"""Pinball Lab: Orbit Pinball card picture from Aaron's screenshot (1320x2868, iPhone). Removes the HUD (pause button,
"Balls 3  SAVE", the score) by inpainting, redraws the arch's glowing line through those spots from the scene geometry
(screen = scene x 3.385, y offset 5.5), crops y 70..2427 (84:150) and scales to 420x750. Run in a folder holding src.png."""
import numpy as np, cv2
from PIL import Image
im = np.array(Image.open('src.png').convert('RGB'))
H, W = im.shape[:2]
S, OY = 3.385, 5.5
def scr(x, y): return (x * S, OY + (844 - y) * S)
def quad(p0, c, p1, n=64):
    return [((1-t)**2*p0[0]+2*(1-t)*t*c[0]+t*t*p1[0], (1-t)**2*p0[1]+2*(1-t)*t*c[1]+t*t*p1[1]) for t in np.linspace(0,1,n)]
arch = [(16, 600)] + quad((16,700),(16,820),(195,820)) + quad((195,820),(374,820),(374,700)) + [(374, 600)]
pts = np.array([scr(*p) for p in arch])
mask = np.zeros((H, W), np.uint8)
cv2.circle(mask, (100, 251), 60, 255, -1)              # the pause button
cv2.rectangle(mask, (180, 215), (570, 290), 255, -1)   # "Balls 3  SAVE"
cv2.rectangle(mask, (1196, 222), (1262, 284), 255, -1) # the score
# distance to the arch for every pixel near the HUD
region = cv2.dilate(mask, np.ones((41, 41), np.uint8))
ys, xs = np.nonzero(region)
P = np.stack([xs, ys], 1).astype(float)
d = np.full(len(P), 1e9)
for a, b in zip(pts[:-1], pts[1:]):
    ab = b - a
    if ab @ ab < 1e-9: continue
    t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
    d = np.minimum(d, np.linalg.norm(P - (a + t[:, None] * ab), axis=1))
# fill the HUD AND the arch's line band near it from the dark background only, then redraw the line there
band = np.zeros_like(mask); band[ys[d < 16], xs[d < 16]] = 255
clean = cv2.inpaint(im, cv2.bitwise_or(mask, band), 9, cv2.INPAINT_TELEA)
alpha = np.clip((12.5 - d) / 8.0, 0, 1)[:, None]
core = np.array([132, 189, 249], float)
clean[ys, xs] = (clean[ys, xs] * (1 - alpha) + core * alpha).astype(np.uint8)
Image.fromarray(clean).save('clean.png')
card = Image.fromarray(clean).crop((0, 70, 1320, 70 + 2357)).resize((420, 750), Image.LANCZOS)
card.save('orbit_lab_thumb.png')
Image.fromarray(clean).crop((0, 120, 700, 400)).save('check.png')
