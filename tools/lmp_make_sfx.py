"""Table 05 (The Lamplight) juice, round 1: the table's own sound set, lmp_sfx_<name>.wav (44.1 kHz, mono, 16-bit).
Mechanical parts from Kenney Impact Sounds (CC0); the shop's voice synthesized here with numpy (original, no licence):
the shop door's bell, teacup clinks, the till, pages, the fire, chimes in a warm F major, and the cat (a little meow,
a purr, a swat).
Usage: python3 lmp_make_sfx.py <kenney impact Audio dir> <out dir>"""
import sys, os, subprocess, wave
import numpy as np
from scipy import signal

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
SR = 44100
rng = np.random.default_rng(3)


# ------------------------------------------------------------------ building blocks
def t_(dur): return np.arange(int(dur * SR)) / SR


def env(dur, a=0.005, d=None, curve=4.0):
    """Attack, then an exponential-ish decay to silence over the rest (or `d` seconds)."""
    t = t_(dur); n = len(t)
    e = np.ones(n)
    na = max(1, int(a * SR)); e[:na] = np.linspace(0, 1, na)
    rest = t[na:] - t[na] if n > na else t[:0]
    dd = d if d else max(dur - a, 1e-3)
    e[na:] = np.exp(-curve * rest / dd)
    return e


def fade(x, fin=0.003, fout=0.03):
    x = x.copy(); a = int(fin * SR); b = int(fout * SR)
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b)
    return x


def noise(dur): return rng.standard_normal(int(dur * SR))


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], 'bandpass', fs=SR, output='sos'); return signal.sosfilt(sos, x)


def lp(x, f, order=2):
    sos = signal.butter(order, f, 'lowpass', fs=SR, output='sos'); return signal.sosfilt(sos, x)


def hp(x, f, order=2):
    sos = signal.butter(order, f, 'highpass', fs=SR, output='sos'); return signal.sosfilt(sos, x)


def sweep_filter(x, f0, f1, q=4.0, kind='bp', blocks=64):
    """A filter whose centre slides from f0 to f1 (log), applied block by block with overlap-add."""
    n = len(x); out = np.zeros(n); hop = max(64, n // blocks); win = np.hanning(2 * hop)
    for i, s in enumerate(range(0, n, hop)):
        f = f0 * (f1 / f0) ** (s / max(n - 1, 1))
        lo, hi = f / (1 + 1 / (2 * q)), f * (1 + 1 / (2 * q))
        hi = min(hi, SR / 2 - 100); lo = max(lo, 20)
        seg = x[max(0, s - hop):s + hop]
        y = bp(seg, lo, hi) if kind == 'bp' else lp(seg, min(f, SR / 2 - 100))
        w = np.hanning(len(y)); a = max(0, s - hop)
        out[a:a + len(y)] += y * w
    return out


def bell(f, dur, partials=((1, 1), (2.0, .5), (2.76, .35), (5.4, .2), (8.9, .1)), decay=3.0, detune=0.0):
    """An inharmonic bell: partials (ratio, amplitude), higher ones dying faster."""
    t = t_(dur); x = np.zeros_like(t)
    for r, a in partials:
        ff = f * r * (1 + detune * rng.uniform(-1, 1))
        x += a * np.sin(2 * np.pi * ff * t) * np.exp(-decay * r ** 0.6 * t / dur * 3)
    return x * env(dur, a=0.002, curve=1.0)


def gong(f, dur):
    parts = ((1, 1), (1.47, .6), (2.09, .5), (2.56, .35), (3.39, .25), (4.17, .15), (5.43, .1))
    t = t_(dur); x = np.zeros_like(t)
    for r, a in parts:
        wob = 1 + 0.004 * np.sin(2 * np.pi * (0.7 + r * 0.3) * t)
        x += a * np.sin(2 * np.pi * f * r * wob * t) * np.exp(-(1.2 + r * 0.6) * t / dur * 2)
    swell = np.minimum(t / 0.06, 1)
    return x * swell + 0.15 * bp(noise(dur), 200, 2000) * env(dur, a=0.002, d=0.1)


def saw(f, t):
    ph = np.cumsum(np.broadcast_to(f, t.shape) / SR)
    return 2 * (ph % 1) - 1


def choir(notes, dur, vowel=(700, 1100, 2600), breath=0.08, attack=0.4):
    """A dark chant: detuned saws per note through three vowel formants, slow attack and release."""
    t = t_(dur); x = np.zeros_like(t)
    for f in notes:
        for d in (-0.006, 0, 0.007):
            vib = 1 + 0.004 * np.sin(2 * np.pi * (4.6 + d * 100) * t + rng.uniform(0, 6))
            x += saw(f * (1 + d) * vib, t)
    y = sum(bp(x, fo * 0.85, fo * 1.15) * g for fo, g in zip(vowel, (1, 0.6, 0.25)))
    y += breath * bp(noise(dur), 500, 3000)
    e = np.minimum(t / attack, 1) * np.minimum((dur - t) / 0.5, 1)
    return y * e


def rumble(dur, f=38, a=0.05):
    t = t_(dur)
    x = lp(noise(dur), 120, 4) * 3 + 0.6 * np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 1.5 * t)
    x += bp(noise(dur), 180, 600) * 0.9 * (1 + 0.5 * np.sin(2 * np.pi * 3.3 * t))   # phone speakers: the audible part
    return x * env(dur, a=a, curve=2.5)


def growl(dur, f0=72, f1=55, rough=0.5):
    """A monstrous roar: a jittery low saw through mouth formants plus breath noise."""
    t = t_(dur)
    jitter = 1 + 0.05 * lp(noise(dur), 30) * 4
    f = (f0 + (f1 - f0) * t / dur) * jitter
    src = saw(f, t) + rough * lp(noise(dur), 1500)
    y = bp(src, 250, 450) * 1.0 + bp(src, 600, 900) * 0.8 + bp(src, 1300, 1900) * 0.35 + lp(src, 160) * 0.8
    shape = np.minimum(t / 0.15, 1) * np.exp(-1.6 * np.maximum(t - dur * 0.45, 0) / dur * 3)
    trem = 1 + 0.25 * np.sin(2 * np.pi * 11 * t)
    return y * shape * trem


def whoosh(dur, f0, f1, q=2.5):
    x = sweep_filter(noise(dur), f0, f1, q=q)
    t = t_(dur)
    return x * np.sin(np.pi * np.minimum(t / dur, 1)) ** 1.5


def squelch(dur=0.35, f0=900, f1=120):
    t = t_(dur)
    x = sweep_filter(noise(dur), f0, f1, q=6) * 1.5
    blip = np.sin(2 * np.pi * np.cumsum(f0 * 0.4 * (f1 / f0) ** (t / dur)) / SR)
    pops = np.zeros_like(t)
    for k in range(5):
        i = int(rng.uniform(0.02, dur * 0.8) * SR); pops[i:i + 200] += np.hanning(200) * rng.uniform(.3, .8)
    return (x + 0.5 * blip + bp(pops, 300, 1500) * 3) * env(dur, a=0.004, curve=3)


def page(dur=0.22):
    """A page turning: a few dry flutters of filtered noise."""
    t = t_(dur); x = np.zeros_like(t)
    for k in range(6):
        s = int((0.015 + k * 0.03 + rng.uniform(0, 0.01)) * SR); n = int(0.03 * SR)
        if s + n < len(x): x[s:s + n] += np.hanning(n) * rng.uniform(0.4, 1)
    return bp(noise(dur), 1800, 7000) * x


def mix(*parts):
    n = max(len(p) for p in parts); out = np.zeros(n)
    for p in parts: out[:len(p)] += p
    return out


def at(x, sec, total):
    out = np.zeros(int(total * SR)); s = int(sec * SR); n = min(len(x), len(out) - s)
    out[s:s + n] += x[:n]; return out


def kenney(name, maxlen=None):
    """A Kenney Impact sound as float mono 44.1 kHz."""
    tmp = os.path.join(OUT, '_tmp.wav')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', os.path.join(SRC, name + '.ogg'), '-ac', '1', '-ar', str(SR),
                    '-sample_fmt', 's16', tmp], check=True)
    with wave.open(tmp) as w: x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(float) / 32768
    os.remove(tmp)
    if maxlen: x = fade(x[:int(maxlen * SR)], 0, min(0.05, maxlen / 3))
    return x


def write(name, x, level_db):
    """Peak-normalise to level_db (dBFS) and save lmp_sfx_<name>.wav."""
    x = np.asarray(x, float); x = x - np.mean(x)
    x = fade(x, 0.001, 0.02)
    pk = np.max(np.abs(x)) or 1
    x = x / pk * 10 ** (level_db / 20)
    with wave.open(os.path.join(OUT, f'lmp_sfx_{name}.wav'), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print(f'{name:14s} {len(x) / SR:5.2f}s  peak {level_db} dB')




# ------------------------------------------------------------------ the Lamplight's own building blocks
F4, A4, C5, D5, E5, F5, G5, A5, C6 = 349.23, 440.0, 523.25, 587.33, 659.25, 698.46, 783.99, 880.0, 1046.5
C4, F3, A3, Bb3 = 261.63, 174.61, 220.0, 233.08


def chime(f, dur, decay=2.5):
    """A warm tubular chime: nearly harmonic partials, soft."""
    return bell(f, dur, partials=((1, 1), (2.0, .35), (3.0, .12), (4.2, .05)), decay=decay)


def clink(f=2600, dur=0.35):
    """Bone china: a few high inharmonic partials that ring briefly, a tiny tick on top."""
    t = t_(dur); x = np.zeros_like(t)
    for r, a in ((1, 1), (1.58, .6), (2.31, .4), (3.7, .2)):
        x += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * (14 + 9 * r))
    tick = hp(noise(dur), 4000) * np.exp(-t * 300) * 0.5
    return x + tick


def shop_bell(dur=1.2):
    """The bell over the shop door: a small brass bell struck three times by its clapper as the door swings."""
    hits = ((0.0, 1.0), (0.11, 0.7), (0.26, 0.45), (0.45, 0.25))
    return mix(*(at(bell(1820, dur - s, partials=((1, 1), (2.32, .5), (3.9, .25), (5.1, .12)), decay=2.2) * g, s, dur)
                 for s, g in hits))


def crackle(dur, rate=40, lo=900, hi=5000):
    """Wood in a fire: random dry pops through a band, with a soft breathy roar under them."""
    n = int(dur * SR); x = np.zeros(n)
    for _ in range(int(rate * dur)):
        i = int(rng.uniform(0, max(1, n - 400))); w = int(rng.uniform(40, 300))
        x[i:i + w] += np.hanning(w) * rng.uniform(0.2, 1.0) * rng.choice((-1, 1))
    roar = lp(noise(dur), 500) * 0.6
    return bp(x, lo, hi) * 2.5 + roar


def meow(dur=0.55, f0=520, peak=760, f1=430):
    """A little cat 'mrr-iaow': a pitch arc on a buzzy source through a vowel moving from 'i' to 'au'."""
    t = t_(dur); u = t / dur
    f = np.where(u < 0.35, f0 + (peak - f0) * (u / 0.35), peak + (f1 - peak) * ((u - 0.35) / 0.65))
    f = f * (1 + 0.01 * np.sin(2 * np.pi * 7 * t))
    src = saw(f, t) * 0.6 + np.sin(2 * np.pi * np.cumsum(f) / SR)
    form1 = np.interp(u, (0, 0.4, 1), (400, 900, 700)); form2 = np.interp(u, (0, 0.4, 1), (2300, 1500, 1100))
    y = sweep_like(src, form1, 3) + 0.6 * sweep_like(src, form2, 4)
    return y * np.minimum(u / 0.08, 1) * np.minimum((1 - u) / 0.25, 1)


def sweep_like(x, fc, q, hop=512):
    """Band-pass x with a centre that follows the array fc (per sample), block by block."""
    out = np.zeros(len(x)); win = np.hanning(2 * hop)
    for s in range(0, len(x), hop):
        a, b = max(0, s - hop), min(len(x), s + hop)
        f = float(fc[min(s, len(fc) - 1)])
        y = bp(x[a:b], f / (1 + 1 / (2 * q)), min(f * (1 + 1 / (2 * q)), SR / 2 - 100))
        out[a:b] += y * np.hanning(b - a)
    return out


def purr(dur=1.2):
    """A purr: breathy low noise pulsed ~26 times a second, in on the out-breath and the in-breath."""
    t = t_(dur)
    pulse = (0.5 + 0.5 * np.sin(2 * np.pi * 26 * t)) ** 3
    breath = 0.65 + 0.35 * np.sin(2 * np.pi * 1.6 * t - 1.5)
    body = lp(noise(dur), 260) * 3 + bp(noise(dur), 250, 900) * 0.8
    return body * pulse * breath * np.minimum(t / 0.1, 1) * np.minimum((dur - t) / 0.2, 1)


def swat(dur=0.3):
    """A paw swipe: a quick airy swish and a soft hiss."""
    return mix(whoosh(0.18, 1500, 6000, q=1.5) * 1.2, at(hp(noise(0.25), 3000) * env(0.25, a=0.02, curve=5) * 0.5, 0.05, dur))


# ------------------------------------------------------------------ mechanical (Kenney Impact, CC0)
write('flipper', kenney('impactPlate_light_000', 0.25), -12)
write('sling', kenney('impactPunch_medium_000', 0.30), -7)
write('post', kenney('impactSoft_medium_001', 0.25), -9)                                  # the rubber centre post
write('gate', kenney('impactMetal_light_002', 0.25), -12)
write('spinner', mix(kenney('impactPlate_light_002', 0.09), clink(3400, 0.08) * 0.3), -12)
write('scoopIn', kenney('impactWood_heavy_000', 0.6), -5)
write('scoopOut', kenney('impactPunch_heavy_000', 0.5), -6)
write('launch', mix(kenney('impactWood_medium_000', 0.3), at(whoosh(0.5, 400, 3000) * 0.5, 0.02, 0.55)), -6)
# the teacups: a punch for the kick, the cup's clink and the saucer's rattle
write('teacup', mix(kenney('impactPunch_medium_001', 0.18) * 0.7, clink(2500, 0.4), at(clink(3300, 0.25) * 0.35, 0.03, 0.4)), -6)
# a fire-screen panel: an iron clank
write('screenPanel', mix(kenney('impactMetal_medium_001', 0.4), at(kenney('impactMetal_light_000', 0.2) * 0.4, 0.02, 0.4)), -6)

# ------------------------------------------------------------------ shots
write('ramp', mix(whoosh(0.7, 300, 3500, q=2), at(chime(C6, 0.8) * 0.45, 0.45, 1.25)), -4)
write('orbit', whoosh(0.8, 2500, 250, q=2), -6)
write('loftPlunge', mix(whoosh(0.6, 400, 4500, q=2), at(chime(F5, 1.0), 0.25, 1.3), at(chime(A5, 0.9), 0.35, 1.3),
                        at(chime(C6, 0.9), 0.45, 1.4)), -4)
write('dumbwaiter', mix(kenney('impactMining_000', 0.35),
                        at(sweep_filter(saw(np.full(int(0.5 * SR), 600.0), t_(0.5)), 900, 2400, q=8) * 0.25, 0.05, 0.6),
                        at(bell(2100, 0.6, decay=3) * 0.5, 0.45, 1.05)), -5)              # the rope creaks up, a ding
write('catFlap', mix(kenney('impactPlank_medium_000', 0.3), at(whoosh(0.45, 300, 2500) * 0.45, 0.03, 0.5)), -4)
fire = crackle(0.9, rate=55) * env(0.9, a=0.03, curve=3)
write('fireplace', mix(whoosh(0.6, 200, 1500, q=1.5) * 0.8, fire * 0.7, at(chime(F4, 1.4), 0.15, 1.6),
                       at(chime(A4, 1.3), 0.25, 1.6), at(chime(C5, 1.2), 0.35, 1.6)), -3)
write('fireplaceOpen', mix(kenney('impactMetal_heavy_000', 0.5) * 0.8, at(crackle(0.7, rate=70) * env(0.7, a=0.05, curve=3) * 0.6, 0.05, 0.8),
                           at(chime(C5, 0.9) * 0.6, 0.1, 1.0)), -4)
write('drain', mix(kenney('impactSoft_heavy_001', 0.4) * 0.7,
                   at(chime(A4, 0.7, decay=3) * 0.4, 0.1, 1.0), at(chime(F4, 0.9, decay=3) * 0.4, 0.3, 1.2)), -8)

# ------------------------------------------------------------------ the shop
write('regular', mix(shop_bell(1.2), at(kenney('impactWood_light_001', 0.2) * 0.3, 0.0, 1.2)), -5)       # the door opens
write('find', mix(page(0.25), at(chime(C6, 0.6, decay=3) * 0.35, 0.06, 0.7)), -6)
write('rareFind', mix(page(0.3), at(chime(F5, 1.0), 0.05, 1.3), at(chime(A5, 0.9), 0.13, 1.3), at(chime(C6, 0.9), 0.21, 1.3),
                      at(chime(F5 * 2, 0.8, decay=3) * 0.5, 0.3, 1.3)), -4)
till = mix(kenney('impactMetal_light_003', 0.2) * 0.6, at(kenney('impactWood_medium_002', 0.2) * 0.5, 0.06, 0.3),
           at(bell(2640, 0.9, partials=((1, 1), (2.4, .4), (4.1, .2)), decay=2.5) * 0.8, 0.12, 1.0))
write('thankYou', mix(till, at(chime(F5, 0.9) * 0.5, 0.3, 1.3), at(chime(A5, 0.9) * 0.5, 0.4, 1.3)), -4)
write('rush', mix(shop_bell(1.4), at(chime(F5, 1.0), 0.2, 1.6), at(chime(A5, 1.0), 0.3, 1.6), at(chime(C6, 1.0), 0.4, 1.6),
                  at(chime(F5 * 2, 1.0), 0.5, 1.6)), -3)
write('festival', mix(*(at(chime(f, 2.2, decay=1.6), d, 2.8) for f, d in
                        ((F4, 0), (A4, 0.08), (C5, 0.16), (F5, 0.24), (A5, 0.32), (C6, 0.40), (F5 * 2, 0.5))),
                      at(shop_bell(1.5) * 0.4, 0.6, 2.8)), -3)
write('ballSave', mix(chime(F5, 1.0, decay=2), at(chime(C6, 1.0, decay=2), 0.1, 1.2)), -4)

# ------------------------------------------------------------------ the cat
write('catWake', mix(meow(0.55), at(kenney('impactSoft_medium_002', 0.15) * 0.3, 0, 0.6)), -6)
write('catPet', purr(1.2), -7)
write('catSwat', mix(swat(0.3), at(meow(0.3, 600, 820, 700) * 0.5, 0.05, 0.4)), -5)
write('catGift', mix(meow(0.5, 560, 800, 520), at(chime(A5, 0.9), 0.35, 1.3), at(chime(C6, 0.9), 0.45, 1.4)), -5)
