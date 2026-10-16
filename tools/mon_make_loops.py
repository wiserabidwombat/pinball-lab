"""Table 04 (Monsoon) juice round 2: the storm bed, four seamless 12-second loops (44.1 kHz mono 16-bit) that the
scene mixes by how the storm is going. Synthesized (original).
  mon_loop_desert.wav   dry desert wind in slow gusts + cicada swells (Act 1, fading as the storm builds)
  mon_loop_thunder.wav  distant rolling thunder, no cracks (grows with each painted region; full in Monsoon)
  mon_loop_rain.wav     steady rain: hiss, patter and drips (Monsoon; lighter in Superbloom)
  mon_loop_birds.wav    after the storm: cactus-wren chatter, a dove, a few last drips (Superbloom and the finished painting)
Seamless: steady noise is filtered over three tiled copies and the middle one kept; every event (a roll of thunder,
a chirp, a drip) is added into the loop with wrap-around, so whatever runs off the end continues at the start.
Usage: python3 mon_make_loops.py <out dir>"""
import sys, os, wave
import numpy as np
from scipy import signal

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
SR = 44100
L = 12.0
N = int(L * SR)
rng = np.random.default_rng(404)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo, hi], 'bandpass', fs=SR, output='sos'), x)


def lp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, 'lowpass', fs=SR, output='sos'), x)


def steady(fn):
    """A filtered steady noise that loops: `fn` runs over three copies of one loop of noise, the middle is kept."""
    n = np.tile(rng.standard_normal(N), 3)
    return fn(n)[N:2 * N]


T = np.arange(N) / SR


def lfo(cycles, ph=0.0, lo=0.0, hi=1.0):
    return lo + (hi - lo) * (0.5 + 0.5 * np.sin(2 * np.pi * cycles / L * T + ph))


def add(buf, x, sec):
    """Adds event x into the loop at `sec`, wrapping past the end."""
    i = int(sec * SR) % N
    idx = (np.arange(len(x)) + i) % N
    np.add.at(buf, idx, x)


def env(n, a, curve):
    t = np.arange(n) / SR
    d = n / SR
    return np.minimum(t / a, 1) * (1 - t / d) ** curve


def finish(name, x, peak_db):
    x = x - x.mean()
    x = x / np.max(np.abs(x)) * 10 ** (peak_db / 20)
    seam = abs(x[0] - x[-1]); step = np.median(np.abs(np.diff(x)))
    rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)))
    with wave.open(os.path.join(OUT, name), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print(f'{name}: {L:.0f}s, peak {peak_db} dB, rms {rms:.1f} dB, seam {seam:.4f} (typical step {step:.4f})')


# 1. Desert: wind in slow gusts (a low body + a whistling mid band) and cicadas swelling twice a loop
wind = steady(lambda n: lp(n, 500, 2) * 1.6 + bp(n, 500, 1400, 2) * 0.6)
gust = lfo(2, 0.4, 0.35, 1.0) * lfo(3, 1.9, 0.7, 1.0)
whistle = steady(lambda n: bp(n, 900, 1100, 2)) * lfo(1, 2.5, 0.0, 1.0) ** 2 * 0.8
cicada = np.zeros(N)
for start, length, f in ((1.0, 5.0, 4600), (7.2, 4.4, 5200)):
    n = int(length * SR)
    t = np.arange(n) / SR
    buzz = bp(rng.standard_normal(n), f - 700, f + 700, 2)
    pulse = (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 52 * t))) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t))
    swell = np.sin(np.pi * t / length) ** 1.5
    add(cicada, buzz * pulse * swell, start)
finish('mon_loop_desert.wav', wind * gust + whistle + cicada * 0.55, -8)

# 2. Distant thunder: three slow rolls a loop (no crack, far away) over a faint continuous grumble
thunder = steady(lambda n: lp(n, 140, 2) * 1.2) * lfo(1, 0.0, 0.3, 0.7)
for start, length, g in ((0.6, 4.2, 1.0), (5.3, 3.4, 0.7), (8.6, 4.6, 0.85)):
    n = int(length * SR)
    noise = rng.standard_normal(n)
    body = bp(noise, 90, 420, 2) + 0.5 * bp(noise, 300, 800, 2)
    # a roll: a few rumbling bursts inside one swell
    t = np.arange(n) / SR
    bursts = sum(np.exp(-((t - c) / w) ** 2) for c, w in
                 zip(rng.uniform(0.3, length * 0.7, 4), rng.uniform(0.25, 0.6, 4)))
    add(thunder, body * env(n, 0.6, 1.5) * (0.4 + bursts) * g * 2.2, start)
finish('mon_loop_thunder.wav', thunder, -7)

# 3. Rain: a broad hiss, a patter band, and ~30 drips a second
rain = steady(lambda n: bp(n, 1800, 7000, 2) * 0.8 + bp(n, 500, 1600, 2) * 0.35) * lfo(3, 0.3, 0.8, 1.0)
for _ in range(int(30 * L)):
    f = rng.uniform(900, 2600)
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    fr = f * (1 - 0.4 * np.minimum(t / 0.03, 1))
    d = np.sin(2 * np.pi * np.cumsum(fr) / SR) * env(n, 0.001, 6)
    add(rain, d * rng.uniform(0.15, 0.6), rng.uniform(0, L))
finish('mon_loop_rain.wav', rain, -8)

# 4. After the storm: a cactus wren's rattling chatter (twice), a mourning dove's coo (once), a few last drips,
# over a whisper of breeze
birds = steady(lambda n: bp(n, 300, 1200, 2)) * 0.08


def wren(count):
    out = []
    for _ in range(count):                       # harsh "chur" notes: noisy, fast-falling chirps
        n = int(0.07 * SR)
        t = np.arange(n) / SR
        f = 3400 - 1600 * t / 0.07
        tone = np.sin(2 * np.pi * np.cumsum(f) / SR)
        rough = 0.6 + 0.4 * np.sin(2 * np.pi * 230 * t)
        out.append(tone * rough * env(n, 0.004, 2))
        out.append(np.zeros(int(0.035 * SR)))
    return np.concatenate(out)


def coo(f0):
    """A mourning dove: coo-OOO-oo-oo, soft hollow tones with a slight lift."""
    parts = []
    for length, rise, g in ((0.35, 1.06, 0.6), (0.7, 1.12, 1.0), (0.45, 1.0, 0.7), (0.45, 1.0, 0.6)):
        n = int(length * SR)
        t = np.arange(n) / SR
        f = f0 * (1 + (rise - 1) * np.sin(np.pi * t / length))
        ph = 2 * np.pi * np.cumsum(f) / SR
        tone = np.sin(ph) + 0.25 * np.sin(2 * ph)
        parts.append(tone * np.sin(np.pi * t / length) ** 1.2 * g)
        parts.append(np.zeros(int(0.12 * SR)))
    return np.concatenate(parts)


add(birds, wren(9) * 0.5, 1.2)
add(birds, wren(7) * 0.42, 6.9)
add(birds, coo(560) * 0.55, 3.6)
add(birds, coo(540) * 0.4, 9.4)
for _ in range(14):                              # quick finch-like tweets
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    f = rng.uniform(2800, 4200) * (1 + 0.25 * np.sin(2 * np.pi * rng.uniform(15, 30) * t))
    add(birds, np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.006, 2) * rng.uniform(0.12, 0.3), rng.uniform(0, L))
for _ in range(10):                              # the last drips off the cacti
    f = rng.uniform(900, 1800)
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    fr = f * (1 - 0.45 * np.minimum(t / 0.05, 1))
    add(birds, np.sin(2 * np.pi * np.cumsum(fr) / SR) * env(n, 0.002, 7) * rng.uniform(0.15, 0.35), rng.uniform(0, L))
finish('mon_loop_birds.wav', birds, -8)
