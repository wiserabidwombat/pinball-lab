"""Port The Naturalist's traditional angled inlane feeds (T11 M1 r2) to a kit layout file: Neon Labyrinth's shared cell
kit (tools/nl_kit.py, used by Neon and 9 to Alive) or Quest & Flipper's copy of it (tools/qf_layout.py).

Aaron, 2026-11-24: "The feeds to the flippers, instead of curved can we have the traditional angled feeds? The curved
ones make it very difficult to catch a ball as the ball doesn't slow down." Then: "Let's do the same on those too."

Changes (each anchor must match exactly once, or nothing is written):
  1. SLANT 32 -> 20 deg (the guide's slant from its corner to just above the pivot; the end point doesn't move).
  2. lane_guide_curve() returns just the corner, so the lane guide is [top post, corner, end] (no r 120 bend) and the
     outlane channel wall starts at the corner. GUIDE_BEND_R -> 0.
  3. The sling's corner 352 -> 300 (the lowest y keeping the inlane 50 clear of the angled guide) and its tip
     recomputed from it (corner + 64 along the slant).
pymunk (nat_inlane_sim.py, same kit geometry): balls let go down the inlane at 150-800 pt/s meet a held-up flipper at
a median 342 pt/s (309-364) instead of 622 (423-748). CHOMP!'s Play Lab catches: 91-98 % under 300, 32 % at 300-400,
~1 % over 500.

Usage: python3 port_angled_feeds.py tools/nl_kit.py [--write]      (prints the changed lines; --write saves)
"""
import re, sys

NOTE = ("# T11 M1 r2 port (Aaron 2026-11-24): traditional angled inlane feeds. Straight guide, sharp corner, straight\n"
        "# 20 deg slant to just above the pivot (was 32 deg with an r 120 bend, which let inlane balls reach a held\n"
        "# flipper at ~620 pt/s; now ~340). Sling corner 352 -> 300, tip recomputed along the new slant.\n")


def patch(src):
    out = src
    # 1. the slant
    pat = re.compile(r"^SLANT = math\.radians\(32\)[^\n]*$", re.M)
    assert len(pat.findall(out)) == 1, "SLANT = math.radians(32) line: expected exactly one"
    out = pat.sub(NOTE.rstrip("\n") + "\nSLANT = math.radians(20)            # the guide's slant down to the pivot", out)
    # 2. the bend: lane_guide_curve() -> just the corner
    pat = re.compile(r"^def lane_guide_curve\(\):\n(?:[ \t]+[^\n]*\n)+(\n*)(?=\S)", re.M)
    m = pat.findall(out)
    assert len(m) == 1, f"def lane_guide_curve(): expected exactly one, found {len(m)}"
    out = pat.sub(lambda mm: 'def lane_guide_curve():\n'
                  '    """The guide\'s corner only (T11 M1 r2: no bend curve any more; the guide is top, corner, end)."""\n'
                  '    return [GUIDE_BEND_L]\n' + mm.group(1), out)
    pat = re.compile(r"^GUIDE_BEND_R = 120\.0[^\n]*$", re.M)
    assert len(pat.findall(out)) == 1, "GUIDE_BEND_R = 120.0: expected exactly one"
    out = pat.sub("GUIDE_BEND_R = 0.0                  # T11 M1 r2: a sharp corner (was r 120)", out)
    # 3. the sling corner and tip
    pat = re.compile(r"^SLING_CORNER_L = \(SLING_X, 352\.0\)[^\n]*$", re.M)
    assert len(pat.findall(out)) == 1, "SLING_CORNER_L = (SLING_X, 352.0): expected exactly one"
    out = pat.sub("SLING_CORNER_L = (SLING_X, 300.0)   # T11 M1 r2: the lowest corner keeping the inlane 50 clear\n"
                  "SLING_TIP_L = add(SLING_CORNER_L, _u, 64.0)", out)
    return out


if __name__ == "__main__":
    path = sys.argv[1]
    src = open(path).read()
    new = patch(src)
    a, b = src.splitlines(), new.splitlines()
    import difflib
    sys.stdout.writelines(l + "\n" for l in difflib.unified_diff(a, b, path, path + " (patched)", n=0, lineterm=""))
    if "--write" in sys.argv:
        open(path, "w").write(new)
        print("written", path)
