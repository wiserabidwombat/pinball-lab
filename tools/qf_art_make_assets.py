"""Quest & Flipper sprites → Assets.xcassets/QfArt (palette-locked, about 1.7 px per table pt for the big sources)."""
import sys, os, json, hashlib
from PIL import Image
sys.path.insert(0, '/home/claude/qf')
import qf_render_m1 as R
PAL = list(R.PAL.values())
def lock(im):
    im = im.convert('RGBA'); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 128: px[x, y] = (0, 0, 0, 0); continue
            px[x, y] = (*min(PAL, key=lambda p: (p[0]-r)**2 + (p[1]-g)**2 + (p[2]-b)**2), 255)
    return im
TARGET_H = {'qf_treant_hurt': 121, 'qf_treant_felled': 121, 'qf_lantern': 45, 'qf_roots': 58}
out = 'art/QfArt'; os.makedirs(out, exist_ok=True)
json.dump({"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}},
          open(f'{out}/Contents.json', 'w'), indent=2)
for f in sorted(os.listdir('art/locked')):
    name = f[:-4]; im = Image.open(f'art/locked/{f}').convert('RGBA')
    if name in TARGET_H:
        src = Image.open(f'art/locked/{f}').convert('RGBA'); h = TARGET_H[name]
        im = lock(src.resize((round(src.width * h / src.height), h), Image.LANCZOS))
        im = im.crop(im.getbbox())
    d = f'{out}/{name}.imageset'; os.makedirs(d, exist_ok=True)
    im.save(f'{d}/{name}.png', optimize=True)
    json.dump({"images": [{"idiom": "universal", "filename": f"{name}.png"}], "info": {"author": "xcode", "version": 1}},
              open(f'{d}/Contents.json', 'w'), indent=2)
    print(name, im.size, hashlib.sha256(open(f'{d}/{name}.png', 'rb').read()).hexdigest()[:12])
