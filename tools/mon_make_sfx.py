"""Table 04 (Monsoon) juice, round 1: the table's own sound set, mon_sfx_<name>.wav (44.1 kHz, mono, 16-bit).
Mechanical parts use Kenney Impact Sounds (CC0); the storm and the paint (thunder, raindrops, wet brush washes, warm
desert chimes, sand, the helix whir) are synthesized here with numpy (Table 03's building blocks), so they're original
and need no licence. Tuned to A major pentatonic — open and warm, the opposite of Table 03's dark D minor.
Phone speakers barely play below ~250 Hz, so every low sound (thunder) also has a 200–900 Hz band.
Usage: python3 mon_make_sfx.py <kenney impact Audio dir> <out dir>"""
import sys, os, subprocess, wave
import numpy as np
from scipy import signal

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
SR = 44100
rng = np.random.default_rng(4)


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
    """Peak-normalise to level_db (dBFS) and save cth_sfx_<name>.wav."""
    x = np.asarray(x, float); x = x - np.mean(x)
    x = fade(x, 0.001, 0.02)
    pk = np.max(np.abs(x)) or 1
    x = x / pk * 10 ** (level_db / 20)
    with wave.open(os.path.join(OUT, f'mon_sfx_{name}.wav'), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print(f'{name:14s} {len(x) / SR:5.2f}s  peak {level_db} dB')



# A major pentatonic, two octaves
A3, B3, Cs4, E4, Fs4, A4, B4, Cs5, E5, Fs5, A5 = 220.0, 246.94, 277.18, 329.63, 369.99, 440.0, 493.88, 554.37, 659.26, 739.99, 880.0


def thunder(dur, crack=0.6, low=1.0):
    """A thunder clap: a bright crack (noise, falling band) into a rolling rumble with a 200-900 Hz body."""
    n = noise(dur)
    cr = sweep_filter(n, 3500, 500, q=1.5) * env(dur, a=0.004, d=0.35, curve=5) * crack
    roll = bp(noise(dur), 180, 900) * env(dur, a=0.03, curve=2.5)
    roll *= 0.6 + 0.4 * np.abs(signal.lfilter([1], [1, -0.999], rng.standard_normal(len(roll))) / 60).clip(0, 1.5)
    deep = lp(noise(dur), 160) * env(dur, a=0.05, curve=2.0) * 2.5
    return mix(cr, roll * low, deep * low)


def drip(f=1300, dur=0.16):
    """A raindrop: a quick falling sine with a tiny click."""
    t = t_(dur); fr = f * (1 - 0.45 * np.minimum(t / 0.05, 1))
    s = np.sin(2 * np.pi * np.cumsum(fr) / SR) * env(dur, a=0.002, curve=7)
    return mix(s, bp(noise(0.01), 2000, 8000) * 0.3)


def brush(dur=0.5, f0=600, f1=2400):
    """A wet watercolor brush stroke: soft band noise sweeping up, swelling and easing out."""
    x = sweep_filter(noise(dur), f0, f1, q=1.2)
    t = t_(dur); e = np.sin(np.pi * np.minimum(t / dur, 1)) ** 1.5
    return x * e


def chime(notes, gap=0.07, dur=1.0, decay=3.0):
    return mix(*(at(bell(f, dur, decay=decay), k * gap, dur + gap * len(notes)) for k, f in enumerate(notes)))


def sand(dur, f0=2500, f1=6000):
    x = sweep_filter(noise(dur), f0, f1, q=0.8)
    t = t_(dur); grain = (rng.random(len(t)) < 0.02) * rng.uniform(0.5, 1, len(t))
    return (x + bp(grain, 3000, 9000) * 0.6) * np.sin(np.pi * t / dur)


def rain(dur, density=1.0):
    """A burst of rain: many small drips over band noise."""
    out = bp(noise(dur), 1500, 6000) * 0.25 * np.sin(np.pi * t_(dur) / dur)
    for _ in range(int(40 * density * dur)):
        out = mix(out, at(drip(rng.uniform(900, 2400), 0.08) * rng.uniform(0.2, 0.6), rng.uniform(0, dur - 0.1), dur))
    return out


# ------------------------------------------------------------------ mechanical (Kenney Impact, CC0)
write('flipper', kenney('impactPlate_light_000', 0.25), -12)
write('sling', kenney('impactPunch_medium_000', 0.30), -7)
write('gate', kenney('impactMetal_light_002', 0.25), -12)
write('spinner', kenney('impactPlate_light_002', 0.09), -12)
write('scoopIn', kenney('impactWood_heavy_000', 0.6), -5)
write('scoopOut', kenney('impactPunch_heavy_000', 0.5), -6)
write('kickback', mix(kenney('impactPunch_heavy_002', 0.5), at(whoosh(0.45, 300, 2500) * 0.4, 0.03, 0.5)), -4)
write('launch', mix(kenney('impactWood_medium_000', 0.3), at(whoosh(0.5, 400, 3000) * 0.5, 0.02, 0.55)), -6)
write('upKick', mix(kenney('impactMining_000', 0.4), at(whoosh(0.4, 600, 2800) * 0.35, 0.03, 0.45)), -5)
write('standup', mix(kenney('impactWood_light_002', 0.25), at(drip(A5, 0.12) * 0.25, 0.01, 0.25)), -7)
write('captiveKnock', mix(kenney('impactMetal_light_000', 0.3), kenney('impactPlate_light_001', 0.2) * 0.5), -8)
write('diverter', kenney('impactMetal_medium_001', 0.25), -9)

# ------------------------------------------------------------------ the storm and the paint (synthesized)
# pop bumpers are storm clouds: a short thunder crack
write('bumper', mix(thunder(0.45, crack=1.0, low=0.6), kenney('impactPunch_medium_001', 0.2) * 0.5), -5)
# lanes: a raindrop; all three: a little run of drops into a chime
write('lane', drip(1300, 0.18), -9)
write('lanesComplete', mix(drip(1500), at(drip(1200), 0.06, 1.1), at(drip(1800), 0.12, 1.1), at(chime([A4, Cs5, E5], 0.07, 0.9), 0.15, 1.1)), -4)
write('skillShot', mix(chime([E5, A5, Cs5 * 2], 0.08, 0.9, decay=2.5), at(whoosh(0.4, 800, 5000) * 0.3, 0, 0.4)), -3)
write('ramp', mix(whoosh(0.7, 300, 3500, q=2), at(bell(E5, 0.8) * 0.5, 0.45, 1.25)), -4)
write('orbit', mix(whoosh(0.8, 2500, 250, q=2), sand(0.8) * 0.15), -6)
# the helix: a bright metallic whir that winds down as the ball spirals
t = t_(1.4)
whir = np.sin(2 * np.pi * np.cumsum(900 * (1 - 0.45 * t / 1.4) * (1 + 0.04 * np.sin(2 * np.pi * 18 * t))) / SR)
write('helix', mix(whir * np.minimum(t / 0.08, 1) * np.exp(-1.6 * t) * 0.5, bp(noise(1.4), 1500, 5000) * np.exp(-2 * t) * 0.3,
                   at(bell(A5, 0.8) * 0.3, 0.0, 1.4)), -6)
write('saguaros', mix(chime([A4, Cs5, E5, A5], 0.06, 1.1), kenney('impactWood_heavy_001', 0.4) * 0.4), -3)
write('captiveTop', mix(kenney('impactBell_heavy_000', 0.5) * 0.7, at(chime([E5, A5], 0.08, 0.9), 0.05, 1.0)), -4)
write('dustDevil', sand(0.6), -16)
write('ballSave', mix(chime([A5, E5, Cs5 * 2], 0.08, 1.2, decay=2), at(rain(0.6, 0.6) * 0.3, 0, 1.3)), -3)
write('drain', mix(thunder(1.4, crack=0.3, low=1.0) * 0.8, at(mix(*(at(np.sin(2 * np.pi * f * t_(0.5)) * env(0.5, a=0.01, curve=4), k * 0.16, 0.9)
                                                                   for k, f in enumerate((E4, Cs4, A3)))) * 0.4, 0.15, 1.4)), -6)
# painting
write('wash', mix(brush(0.55), at(chime([A4, Cs5], 0.09, 0.7, decay=4) * 0.35, 0.18, 0.8)), -10)
write('regionPainted', mix(brush(0.9, 400, 3000) * 0.6, chime([A4, Cs5, E5, Fs5, A5], 0.07, 1.4)), -3)
write('monsoonLit', mix(thunder(2.0, crack=0.5, low=1.0) * 0.8, at(chime([E4, A4, E5], 0.15, 1.2) * 0.5, 0.3, 2.0)), -4)
write('monsoonStart', mix(thunder(2.8, crack=1.0, low=1.2), at(rain(2.4, 1.6) * 0.8, 0.3, 2.8)), -3)
write('jackpot', mix(thunder(0.8, crack=1.0, low=0.5) * 0.6, chime([A4, E5, A5, Cs5 * 2], 0.06, 1.2, decay=2.2)), -3)
write('stormPasses', mix(thunder(2.0, crack=0.0, low=0.7) * 0.5, at(chime([E5, Cs5, A4], 0.18, 1.0, decay=3) * 0.5, 0.4, 2.0)), -7)
write('superbloomLit', mix(chime([A4, Cs5, E5, A5, Cs5 * 2, E5 * 2], 0.08, 1.6, decay=2.2), brush(1.0) * 0.3), -3)
write('superbloomStart', mix(chime([A3 * 2, Cs5, E5, A5, Cs5 * 2, E5 * 2, A5 * 2], 0.06, 2.0, decay=1.8), brush(1.6, 300, 4000) * 0.4,
                             at(thunder(1.6, crack=0.2, low=0.6) * 0.3, 0, 2.2)), -3)
write('bloom', mix(chime([E5, A5], 0.05, 0.6, decay=3.5), brush(0.35, 1000, 3500) * 0.3), -7)
write('superJackpot', mix(thunder(1.0, crack=1.0, low=0.6) * 0.5, chime([A4, Cs5, E5, A5, Cs5 * 2, E5 * 2, A5 * 2], 0.05, 1.6, decay=1.8)), -2)
write('paintingFinished', mix(*(at(chime([f, f * 1.25, f * 1.5], 0.06, 1.8, decay=1.6), k * 0.35, 3.0) for k, f in enumerate((A4, Cs5, E5)))) , -3)
write('newSketch', mix(brush(0.8, 3000, 500) * 0.6, at(bell(A4, 1.2, decay=3) * 0.4, 0.3, 1.5)), -6)
