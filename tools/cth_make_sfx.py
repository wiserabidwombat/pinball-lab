"""Table 03 (Cthulhu Rising) juice, round 1: the table's own sound set, cth_sfx_<name>.wav (44.1 kHz, mono, 16-bit).
Mechanical parts use Kenney Impact Sounds (CC0); everything themed (bells, gongs, chants, the roar, the squelch, the
pages, the rumble) is synthesized here with numpy, so it's original and needs no licence.
Usage: python3 cth_make_sfx.py <kenney impact Audio dir> <out dir>"""
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
    """Peak-normalise to level_db (dBFS) and save cth_sfx_<name>.wav."""
    x = np.asarray(x, float); x = x - np.mean(x)
    x = fade(x, 0.001, 0.02)
    pk = np.max(np.abs(x)) or 1
    x = x / pk * 10 ** (level_db / 20)
    with wave.open(os.path.join(OUT, f'cth_sfx_{name}.wav'), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print(f'{name:14s} {len(x) / SR:5.2f}s  peak {level_db} dB')


# note frequencies: a dark D minor world
D2, A2, D3, F3, A3, C4, D4, E4, F4, A4, D5 = 73.42, 110.0, 146.83, 174.61, 220.0, 261.63, 293.66, 329.63, 349.23, 440.0, 587.33

# ------------------------------------------------------------------ mechanical (Kenney Impact, CC0)
write('flipper', kenney('impactPlate_light_000', 0.25), -12)
write('bumper', mix(kenney('impactBell_heavy_000', 0.40) * 0.8, kenney('impactPunch_medium_001', 0.2) * 0.6), -6)
write('sling', kenney('impactPunch_medium_000', 0.30), -7)
write('sigilTarget', kenney('impactMetal_medium_000'), -5)
write('gate', kenney('impactMetal_light_002', 0.25), -12)
write('spinner', kenney('impactPlate_light_002', 0.09), -12)
write('scoopIn', kenney('impactWood_heavy_000', 0.6), -5)
write('scoopOut', kenney('impactPunch_heavy_000', 0.5), -6)
write('kickback', mix(kenney('impactPunch_heavy_002', 0.5), at(whoosh(0.45, 300, 2500) * 0.4, 0.03, 0.5)), -4)
write('launch', mix(kenney('impactWood_medium_000', 0.3), at(whoosh(0.5, 400, 3000) * 0.5, 0.02, 0.55)), -6)
write('upKick', mix(kenney('impactMining_000', 0.4), at(whoosh(0.4, 600, 2800) * 0.35, 0.03, 0.45)), -5)

# ------------------------------------------------------------------ the table's own voice (synthesized)
# Candle lane: a flame catching (a soft "fwoomp") with a tiny warm bell
fw = bp(noise(0.35), 200, 1800) * env(0.35, a=0.025, curve=4) * 1.2
write('candleLane', mix(fw, bell(A4, 0.5, decay=4) * 0.25), -9)
# Three candles: a rising minor bell arpeggio
write('lanesComplete', mix(bell(D4, 1.0), at(bell(F4, 0.9), 0.09, 1.1), at(bell(A4, 0.8), 0.18, 1.1)), -4)
write('skillShot', mix(bell(D5, 1.0, decay=2.5), at(bell(A4 * 2, 0.9, decay=2.5), 0.12, 1.1), at(whoosh(0.4, 800, 5000) * 0.3, 0, 0.4)), -3)
write('ramp', mix(whoosh(0.7, 300, 3500, q=2), at(bell(A4, 0.8) * 0.5, 0.45, 1.25)), -4)
write('orbit', whoosh(0.8, 2500, 250, q=2), -6)
write('sigilBank', mix(gong(D3, 1.6) * 0.7, bell(D4, 1.2) * 0.5, at(bell(A4, 1.0) * 0.4, 0.1, 1.6)), -3)
write('ballSave', mix(bell(D5, 1.3, decay=2), at(bell(F4 * 2 ** (4 / 12), 1.2, decay=2), 0.08, 1.4),
                      at(bell(A4 * 2, 1.1, decay=2), 0.16, 1.4)), -3)          # a bright D major: the Elder Sign
write('drain', mix(rumble(1.1, 34, a=0.01) * 0.8, choir([D3, F3 * 0.98], 1.1, attack=0.05) * 0.25), -7)
# the magnet: an electric buzz (a 110 Hz saw, filtered, so a phone speaker carries it) swelling with a quickening throb
write('magnetGrab', (lambda t: (bp(saw(110 * (1 + 0.3 * t), t), 200, 1400) + 0.4 * np.sin(2 * np.pi * 55 * t))
                     * (0.6 + 0.4 * np.sin(2 * np.pi * (6 + 10 * t) * t)) * np.minimum(t / 0.3, 1) * np.minimum((0.9 - t) / 0.15, 1))(t_(0.9)), -9)
write('magnetFling', mix(kenney('impactPunch_heavy_001', 0.4), at(whoosh(0.5, 200, 3000) * 0.6, 0.0, 0.5)), -4)
write('cthulhuHit', mix(kenney('impactSoft_heavy_000', 0.4), growl(0.45, 95, 70) * 0.5), -4)

# Research
write('clue', mix(bell(A4, 0.9, decay=3) * 0.7, page(0.25) * 0.6), -7)
write('page', mix(page(0.25), at(bell(D5, 0.5, decay=4) * 0.25, 0.05, 0.55)), -6)
write('libraryLit', mix(gong(D2 * 2, 1.8), at(bell(A4, 1.0) * 0.3, 0.05, 1.8)), -6)
write('tomeStarted', mix(gong(D2 * 2, 2.0) * 0.8, choir([D3, A3, F4], 2.0, attack=0.5) * 0.5, page(0.3) * 0.4), -5)
write('tomeFinished', mix(bell(D4, 1.6), at(bell(F4, 1.5), 0.1, 1.8), at(bell(A4, 1.4), 0.2, 1.8), at(bell(D5, 1.3), 0.3, 1.8),
                          choir([D3, A3], 1.8, attack=0.2) * 0.3), -4)
failed = mix(*(at(np.sin(2 * np.pi * f * (1 - 0.15 * t_(0.6) / 0.6) * t_(0.6)) * env(0.6, a=0.01, curve=3), k * 0.18, 1.2)
               for k, f in enumerate((A3, F3, D3 * 0.97))))
write('failed', mix(failed, choir([D3 * 0.97, F3], 1.2, attack=0.1) * 0.3), -8)

# Ritual
write('ritualLit', mix(gong(A3, 2.0), at(choir([A2, E4 * 0.5], 1.6, attack=0.3) * 0.4, 0.1, 2.0)), -6)
write('ritualStarted', mix(gong(D3, 2.6) * 0.9, choir([D3, F3, A3, D4], 2.6, attack=0.25) * 0.7, rumble(2.6) * 0.4), -4)
write('candle', mix(fw, bell(D5, 0.9, decay=3) * 0.5, at(choir([D4], 0.8, attack=0.1) * 0.3, 0.05, 0.9)), -4)
write('summoning', mix(gong(D3, 3.0), choir([D3, F3, A3, C4, D4], 3.0, attack=0.6), rumble(3.0) * 0.6,
                       at(bell(D5, 2.0) * 0.4, 0.5, 3.0)), -4)

# The Awakening
write('awakening', mix(rumble(3.2, 30, a=0.4) * 1.2, at(growl(2.4, 70, 48, rough=0.7), 0.5, 3.2),
                       choir([D2 * 2, A2, D3 * 1.06], 3.2, vowel=(400, 800, 2400), attack=1.0) * 0.4), -4)
write('tentacleHit', mix(kenney('impactSoft_medium_000', 0.3), squelch(0.25, 700, 200) * 0.6), -5)
write('tentacleCut', mix(squelch(0.45, 1400, 90), at(growl(0.5, 110, 80) * 0.4, 0.08, 0.6), kenney('impactPunch_heavy_003', 0.3) * 0.5), -3)
write('eyeOpen', (lambda t: (np.sin(2 * np.pi * np.cumsum(220 * 2 ** (t / 0.8) * (1 + 0.012 * np.sin(2 * np.pi * 6 * t))) / SR)
                             + 0.3 * np.sin(2 * np.pi * np.cumsum(330 * 2 ** (t / 0.8)) / SR))
                  * np.minimum(t / 0.3, 1) * np.minimum((1.4 - t) / 0.3, 1))(t_(1.4)), -11)
write('eyeStruck', mix(kenney('impactSoft_heavy_002', 0.4), growl(1.0, 90, 60) * 0.9, at(bell(A4, 1.0) * 0.3, 0.05, 1.1)), -4)
write('banished', mix(rumble(3.5, 32, a=0.01) * 1.2, kenney('impactPunch_heavy_004', 0.6),
                      at(growl(1.2, 80, 40) * 0.6, 0.0, 3.5),
                      at(mix(bell(D4, 2.6, decay=1.5), at(bell(F4 * 2 ** (1 / 12), 2.5, decay=1.5), 0.12, 2.8),
                             at(bell(A4, 2.4, decay=1.5), 0.24, 2.8), at(bell(D5, 2.3, decay=1.5), 0.36, 2.8)) * 0.6, 0.6, 3.5)), -3)
write('escaped', mix(growl(1.6, 70, 40, rough=0.6) * 0.8, rumble(1.8, 30) * 0.7, at(failed * 0.5, 0.3, 1.8)), -6)
