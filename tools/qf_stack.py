"""Quest & Flipper (Table 09): voxel models for SPRITE STACKING (T9 M2 v7 prototype).

A model is a voxel grid in world points (VOX pt per voxel), palette-locked. It is exported as a horizontal sheet of
top-down slices, bottom slice first: slice k is the model's layer at height k*VOX. The game draws the slices as a stack
of sprites, each raised by its height times the table's lean and tilted by the camera's parallax (QfStack in Swift).

Models:
  gravestone - a grave on the gravestone's exact physics footprint (QfForestLayout.gravestone): a low mossy ledger
               stone, with an arched headstone standing on its back (pointed) end, a cross carved on the headstone's
               front face.

Run: python3 qf_stack.py outdir   (writes qf_stack_<model>.png and prints the slice size and count)
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw
import qf_layout as L
from qf_render_m1 import PAL

VOX = 2.0     # pt per voxel


def footprint_mask(poly, x0, y0, nx, ny):
    """Voxel columns whose centres lie inside the polygon (world pt); row 0 is the FRONT (lowest y)."""
    m = Image.new("L", (nx, ny), 0)
    ImageDraw.Draw(m).polygon([((p[0] - x0) / VOX, (p[1] - y0) / VOX) for p in poly], fill=255)
    return np.asarray(m) > 0          # [iy, ix], iy grows with world y (towards the back)


def gravestone():
    rng = random.Random(4)
    poly = L.GRAVESTONE[:-1] if L.GRAVESTONE[0] == L.GRAVESTONE[-1] else L.GRAVESTONE
    xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
    x0, y0 = min(xs), min(ys)
    nx, ny = int(math.ceil((max(xs) - x0) / VOX)), int(math.ceil((max(ys) - y0) / VOX))
    foot = footprint_mask(poly, x0, y0, nx, ny)
    back_y = 574.0                                   # the headstone stands from here to the pointed back
    hs_front = int((back_y - y0) / VOX)
    nz = 22                                          # 44 pt tall at the headstone's crown
    vox = np.zeros((nz, ny, nx), np.int16) - 1       # palette index, -1 = empty
    names = list(PAL.keys()); idx = {n: i for i, n in enumerate(names)}
    for iy in range(ny):
        for ix in range(nx):
            if not foot[iy, ix]:
                continue
            u = (ix + 0.5) / nx * 2 - 1              # -1..1 across
            if iy >= hs_front:                       # the headstone: arched top
                top = int(16 + 6 * math.sqrt(max(0.0, 1 - u * u)))
            else:                                    # the ledger stone, slightly domed
                top = 3 + (1 if abs(u) < 0.6 else 0)
            for iz in range(top):
                vox[iz, iy, ix] = idx["stone2"]
    # shading: the front faces (toward the player) light, the top caps lighter, the base dark; moss low down
    for iz in range(nz):
        for iy in range(ny):
            for ix in range(nx):
                if vox[iz, iy, ix] < 0:
                    continue
                front = iy == 0 or vox[iz, iy - 1, ix] < 0
                cap = iz == nz - 1 or vox[iz + 1, iy, ix] < 0
                side = ix == 0 or ix == nx - 1 or vox[iz, iy, ix - 1] < 0 or vox[iz, iy, ix + 1] < 0
                # light from the moon at the top left: caps brightest, the front face graded by height (dark at
                # the foot, light near the top), the right side in shade, the left side mid; a dark rim at the edges
                c = "stone2"
                if cap:
                    c = "ghost" if (iz > 12 and ix < nx // 2) else "stone3"
                elif front:
                    c = "stone1" if iz < 2 else ("stone2" if iz < (4 if iy < hs_front else 9) else "stone3")
                elif side:
                    c = "stone1" if ix >= nx // 2 else "stone2"
                if iz == 0: c = "void"
                if iz == 1 and (front or side) and rng.random() < 0.45: c = rng.choice(["moss1", "moss2"])
                if cap and iz < 5 and rng.random() < 0.12: c = "moss2"
                vox[iz, iy, ix] = idx[c]
    # the cross carved on the headstone's front face
    cx = nx // 2
    for iz in range(8, 19):
        if vox[iz, hs_front, cx] >= 0:
            vox[iz, hs_front, cx] = idx["stone1"]
    for ix in (cx - 2, cx - 1, cx + 1, cx + 2):
        if vox[15, hs_front, ix] >= 0:
            vox[15, hs_front, ix] = idx["stone1"]
    centre = ((x0 + nx * VOX / 2), (y0 + ny * VOX / 2))
    return vox, names, centre


def sheet(vox, names):
    nz, ny, nx = vox.shape
    cols = [PAL[n] for n in names]
    out = Image.new("RGBA", (nx * nz, ny), (0, 0, 0, 0))
    px = out.load()
    for iz in range(nz):
        for iy in range(ny):
            for ix in range(nx):
                v = vox[iz, iy, ix]
                if v >= 0:
                    px[iz * nx + ix, ny - 1 - iy] = cols[v] + (255,)     # image rows: back at the top
    return out


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    vox, names, centre = gravestone()
    s = sheet(vox, names)
    s.save(os.path.join(out, "qf_stack_gravestone.png"))
    nz, ny, nx = vox.shape
    print(f"gravestone: {nz} slices of {nx}x{ny} vox ({nx * VOX:.0f}x{ny * VOX:.0f} pt), centre {centre}")
