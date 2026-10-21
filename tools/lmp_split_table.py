"""Table 05 M9 round 2: cuts the full-table bake (L.ART_RECT at 3 px/pt) into the game's two images at y 525
(LmpTableLayout.lowerArtRect / upperArtRect), and writes their asset-catalog imagesets.
Usage: python3 lmp_split_table.py table_full.png out_dir"""
import json, os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lmp_layout as L

SRC, OUT = sys.argv[1], sys.argv[2]
im = Image.open(SRC).convert('RGB')
X0, Y0, W, H = L.ART_RECT
s = im.width / W
assert abs(s - L.PX_PER_PT) < 0.01, s
top = Y0 + H


def crop(rect, name):
    x, y, w, h = rect
    box = (int(round((x - X0) * s)), int(round((top - (y + h)) * s)), int(round((x + w - X0) * s)), int(round((top - y) * s)))
    part = im.crop(box)
    d = os.path.join(OUT, 'LmpArt', name + '.imageset')
    os.makedirs(d, exist_ok=True)
    part.save(os.path.join(d, name + '.png'), optimize=True)
    json.dump({"images": [{"idiom": "universal", "filename": name + ".png"}], "info": {"author": "xcode", "version": 1}},
              open(os.path.join(d, 'Contents.json'), 'w'), indent=2)
    print(name, part.size)


os.makedirs(os.path.join(OUT, 'LmpArt'), exist_ok=True)
json.dump({"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}},
          open(os.path.join(OUT, 'LmpArt', 'Contents.json'), 'w'), indent=2)
crop(L.LOWER_ART_RECT, 'lmp_lower')
crop(L.UPPER_ART_RECT, 'lmp_upper')
