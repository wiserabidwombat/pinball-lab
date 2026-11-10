"""Table 06 M5 v3: a wispy cloud map for the Earth (Aaron: "the clouds should be a bit more whispy").
Equirectangular 4096 x 2048, values 0..1, wrapping east–west. Fine value noise is smeared along a swirling wind field
(line-integral convolution: average the noise along each point's streamline), which turns it into feathery cirrus
streaks that follow curls and hooks; a broad coverage mask (busy storm belts, clear subtropics) and a breakup field
decide where the wisps are and let them fade out. Usage: python3 tour_cloud_map.py out.npy [seed]  (then save as earthsrc/clouds.png, 8-bit, for tour_floor_lower.py)"""
import numpy as np, sys
from scipy import ndimage as nd
OUT = sys.argv[1]; SEED = int(sys.argv[2]) if len(sys.argv) > 2 else 7
W, H = 4096, 2048
rng = np.random.default_rng(SEED)


def octave(cells):
    g = rng.random((cells // 2 + 1, cells + 3)); g[:, -3:] = g[:, :3]
    return nd.zoom(g, (H / (cells // 2), W / cells), order=3, mode='grid-wrap')[:H, :W]


def fbm(c0, n, gain=0.55):
    out = np.zeros((H, W)); a = 1.0; tot = 0
    for i in range(n):
        out += a * octave(c0 * 2 ** i); tot += a; a *= gain
    out /= tot
    return (out - out.mean()) / out.std()


yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
lat = (0.5 - (yy + 0.5) / H) * np.pi
# wind: a stream function (curls) plus the westerlies / trade winds by latitude
psi = fbm(5, 3) * 1.0
gy, gx = np.gradient(nd.gaussian_filter(psi, 6, mode='wrap'))
u = gy * 900 + np.where(np.abs(lat) > 0.5, 1.0, -0.6) * 1.0       # east–west flow (+ stream function)
v = -gx * 900
n = np.hypot(u, v) + 1e-6; u /= n; v /= n
noise = fbm(256, 2, 0.5) + 0.6 * fbm(96, 2, 0.5)
acc = np.zeros((H, W), np.float32); px, py = xx.copy(), yy.copy()
for sgn in (1, -1):                                              # both ways along the streamline
    px, py = xx.copy(), yy.copy()
    for k in range(22):
        iu = nd.map_coordinates(u, [np.clip(py, 0, H - 1), px % W], order=1, mode='wrap')
        iv = nd.map_coordinates(v, [np.clip(py, 0, H - 1), px % W], order=1, mode='wrap')
        px = px + sgn * 3.0 * iu; py = py - sgn * 3.0 * iv
        acc += nd.map_coordinates(noise, [np.clip(py, 0, H - 1), px % W], order=1, mode='wrap')
lic = acc / 44.0
lic = (lic - lic.mean()) / lic.std()
streaks = np.clip(lic * 0.5 + 0.2, 0, 1) ** 1.9
cover = fbm(5, 4) + 0.5 * np.exp(-(lat / 0.12) ** 2) - 0.7 * np.exp(-((np.abs(lat) - 0.42) / 0.16) ** 2) \
    + 0.35 * np.exp(-((np.abs(lat) - 0.95) / 0.2) ** 2)
cover = np.clip((cover - 0.05) * 0.9, 0, 1)
breakup = np.clip(fbm(24, 3) * 0.6 + 0.6, 0, 1)
cloud = np.clip(streaks * cover * breakup * 1.3 + 0.07 * cover ** 2, 0, 1)
np.save(OUT, cloud.astype(np.float32))
from PIL import Image
Image.fromarray((cloud * 255).astype(np.uint8)).resize((1024, 512)).save(OUT.replace('.npy', '_view.png'))
print('cloud map', cloud.mean(), (cloud > 0.3).mean())
