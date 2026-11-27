"""Quest & Flipper (Table 09): carve a sprite-stacking voxel model from a SpriteCook orthographic model sheet.

SpriteCook's recipe (spritecook.ai/blog/sprite-stacking-pixel-art): one 2x2 sheet of flat views (top-left TOP, top-right
SIDE with the front pointing left, bottom-left FRONT, bottom-right BACK), generated with gemini-3-pro-image in pixel
art. A voxel is solid where the TOP, SIDE and FRONT silhouettes all agree; each visible face takes its colour from the
view that sees it (caps from TOP, the player-facing faces from FRONT, the flanks from SIDE). The model is fitted to the
prop's PHYSICS footprint (width x length in pt) so the art matches what the ball hits; the height keeps the side view's
proportion, capped. Output: a one-row slice sheet (bottom slice first, 1 pt per voxel), palette-locked, for QfStack.

Run: python3 qf_stack_carve.py sheet.png out.png WIDTH LENGTH [MAX_HEIGHT (negative = exact)] [FRONT_TRIM]
"""
import sys
import numpy as np
from PIL import Image
from qf_art_playfield import lock


def biggest_parts(q, keep=0.12):
    """Clear alpha islands smaller than `keep` x the largest (stray labels such as "TOP" / "SIDE", specks)."""
    a = np.asarray(q).copy()
    solid = a[..., 3] > 128
    lab = np.zeros(solid.shape, np.int32); sizes = [0]; n = 0
    for sy, sx in zip(*np.nonzero(solid)):
        if lab[sy, sx]:
            continue
        n += 1; stack = [(sy, sx)]; lab[sy, sx] = n; cnt = 0
        while stack:
            y, x = stack.pop(); cnt += 1
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < solid.shape[0] and 0 <= xx < solid.shape[1] and solid[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = n; stack.append((yy, xx))
        sizes.append(cnt)
    if n:
        big = max(sizes)
        for k in range(1, n + 1):
            if sizes[k] < keep * big:
                a[lab == k, 3] = 0
    return Image.fromarray(a, "RGBA")


def quadrants(sheet):
    w, h = sheet.size
    boxes = [(0, 0, w // 2, h // 2), (w // 2, 0, w, h // 2), (0, h // 2, w // 2, h), (w // 2, h // 2, w, h)]
    out = []
    for b in boxes:
        q = biggest_parts(sheet.crop(b))
        out.append(q.crop(q.getbbox()))
    return out   # top, side, front, back


def carve(sheet_path, W, Lg, Hmax=56, trim=0.0):
    """`trim`: the fraction of the model's length to cut off its FRONT before fitting (a long slab into a short
    footprint keeps the headstone's size)."""
    sheet = Image.open(sheet_path).convert("RGBA")
    top, side, front, _ = quadrants(sheet)
    if trim > 0:
        top = top.crop((0, 0, top.width, round(top.height * (1 - trim))))      # the front is the bottom rows
        side = side.crop((round(side.width * trim), 0, side.width, side.height))  # the front is the left columns
    # height from the side view's proportion (its width is the length)
    H = min(Hmax, round(side.height * Lg / side.width)) if Hmax > 0 else -Hmax   # a negative MAX_HEIGHT is exact
    top = top.resize((W, Lg), Image.NEAREST)          # rows: back (headstone) at the top of the image
    side = side.resize((Lg, H), Image.NEAREST)         # columns: front (left) to back (right); rows: top to bottom
    front = front.resize((W, H), Image.NEAREST)        # columns: left to right; rows: top to bottom
    T, S, F = (np.asarray(i, np.uint8) for i in (top, side, front))
    a = lambda img: img[..., 3] > 128
    tA, sA, fA = a(T), a(S), a(F)
    # voxel (z, y, x): y = 0 is the FRONT (lowest world y), z = 0 the floor
    solid = np.zeros((H, Lg, W), bool)
    for z in range(H):
        for y in range(Lg):
            if not sA[H - 1 - z, y]:
                continue
            for x in range(W):
                solid[z, y, x] = tA[Lg - 1 - y, x] and fA[H - 1 - z, x]
    col = np.zeros((H, Lg, W, 4), np.uint8)
    for z in range(H):
        for y in range(Lg):
            for x in range(W):
                if not solid[z, y, x]:
                    continue
                cap = z == H - 1 or not solid[z + 1, y, x]
                frontface = y == 0 or not solid[z, y - 1, x]
                flank = x == 0 or x == W - 1 or not solid[z, y, x - 1] or not solid[z, y, x + 1]
                if cap:
                    c = T[Lg - 1 - y, x]
                elif frontface:
                    c = F[H - 1 - z, x]
                elif flank:
                    c = S[H - 1 - z, y]
                else:
                    c = T[Lg - 1 - y, x]
                col[z, y, x] = (c[0], c[1], c[2], 255)
    # the slice sheet: slice z is the layer seen from above (back at the top of each slice)
    out = Image.new("RGBA", (W * H, Lg), (0, 0, 0, 0))
    for z in range(H):
        layer = col[z, ::-1]                              # image row 0 = back
        out.paste(Image.fromarray(layer, "RGBA"), (z * W, 0))
    return lock(out), H


if __name__ == "__main__":
    src, dst, W, Lg = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    Hmax = int(sys.argv[5]) if len(sys.argv) > 5 else 56
    trim = float(sys.argv[6]) if len(sys.argv) > 6 else 0.0
    img, H = carve(src, W, Lg, Hmax, trim)
    img.save(dst)
    print(f"{H} slices of {W}x{Lg}")
