"""Table 04 (Monsoon) M10 v4: the sky's shape as a soft white mask (mon_sky_mask.png, 680x805, alpha = sky) for the
live storm over it (darkening + lightning in the clouds). Usage: python3 mon_sky_mask.py <mon_upper_regions.png> <out.png>"""
import sys
import numpy as np
from PIL import Image, ImageFilter
reg = np.asarray(Image.open(sys.argv[1]).convert('RGBA'))
idx = (reg[..., 0] > 127) * 1 + (reg[..., 1] > 127) * 2 + (reg[..., 2] > 127) * 4
sky = ((idx == 0) & (reg[..., 3] > 0)).astype(np.uint8) * 255
a = Image.fromarray(sky).filter(ImageFilter.GaussianBlur(3))
out = Image.new('RGBA', a.size, (255, 255, 255, 0)); out.putalpha(a)
out.save(sys.argv[2]); ys = np.nonzero(sky)[0]
print('sky rows', ys.min(), ys.max(), 'of', sky.shape[0], 'cover %.0f%%' % (100 * sky.mean() / 255))
