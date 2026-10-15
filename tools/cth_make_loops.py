"""Table 03 juice round 2: the Awakening drone, cth_loop_awakening.wav (44.1 kHz mono 16-bit), a seamless 8-second
loop played under the whole Cthulhu fight. Synthesized (original).
Seamless by construction: every tone has a whole number of cycles in the loop, noise is one loop's worth tiled, and the
filters run over three copies so the middle copy (the one written) starts and ends in the same steady state.
Usage: python3 cth_make_loops.py <out dir>"""
import sys, os, wave
import numpy as np
from scipy import signal

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
SR = 44100
L = 8.0                                   # loop length, seconds
N = int(L * SR)
rng = np.random.default_rng(11)
t3 = np.arange(3 * N) / SR                # three loops' worth of time


def q(f):
    """Snap a frequency to a whole number of cycles per loop, so it repeats seamlessly."""
    return max(1, round(f * L)) / L


def sine(f, ph=0.0): return np.sin(2 * np.pi * q(f) * t3 + ph)


def saw(f, vib_rate=0.0, vib_depth=0.0, ph=0.0):
    """A saw with a periodic vibrato (the phase stays periodic: vibrato rate snapped, depth small)."""
    f = q(f); r = q(vib_rate) if vib_rate else 0.0
    phase = f * t3 + ph
    if r: phase += f * vib_depth / (2 * np.pi * r) * np.sin(2 * np.pi * r * t3)
    return 2 * (phase % 1) - 1


def tiled_noise():
    n = rng.standard_normal(N); return np.tile(n, 3)


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], 'bandpass', fs=SR, output='sos'); return signal.sosfilt(sos, x)


def lp(x, f, order=2):
    sos = signal.butter(order, f, 'lowpass', fs=SR, output='sos'); return signal.sosfilt(sos, x)


def lfo(cycles, ph=0.0, lo=0.0, hi=1.0):
    """A slow periodic swell: `cycles` whole cycles per loop, between lo and hi."""
    return lo + (hi - lo) * (0.5 + 0.5 * np.sin(2 * np.pi * cycles / L * t3 + ph))


D2, A2, D3, F3, A3 = 73.42, 110.0, 146.83, 174.61, 220.0

# 1. The deep drone: D and A, saws and sines, under a low-pass, with a mid band so a phone speaker carries it
drone = 0.7 * sine(D2) + 0.4 * sine(A2) + 0.25 * sine(D3 * 1.003)
buzz = saw(D2, 0.375, 0.004) + 0.7 * saw(A2 * 1.002, 0.5, 0.004, 0.3) + 0.5 * saw(D3 * 0.997, 0.625, 0.003, 0.6)
body = lp(buzz, 700, 2) * 0.5 + bp(buzz, 220, 900, 2) * 0.6
drone = (drone * 0.8 + body) * lfo(1, -np.pi / 2, 0.75, 1.0)

# 2. The chant: a dark vowel ("oh" opening to "ah" and back once a loop) on D minor, swelling twice a loop
voices = sum(saw(f, 4.625 + k * 0.25, 0.006, k * 0.37) for k, f in enumerate((D3, F3 * 1.004, A3 * 0.996, D3 * 2.003)))
oh = bp(voices, 380, 520) + 0.6 * bp(voices, 760, 980) + 0.2 * bp(voices, 2300, 2700)
ah = bp(voices, 650, 850) + 0.6 * bp(voices, 1050, 1300) + 0.2 * bp(voices, 2400, 2900)
morph = lfo(1, 0.0)
chant = (oh * (1 - morph) + ah * morph) * lfo(2, -np.pi / 2, 0.15, 1.0) * 0.55

# 3. The deep: churning water / wind, a band of noise that surges three times a loop
deep = bp(tiled_noise(), 250, 1100, 2) * lfo(3, 0.7, 0.2, 1.0) * 0.9 + lp(tiled_noise(), 120, 2) * 2.0

# 4. His heartbeat: a slow lub-dub every 2 s (4 a loop), a low thump with a click on top for the phone
beat = np.zeros(3 * N)
thump_t = np.arange(int(0.28 * SR)) / SR
thump = (np.sin(2 * np.pi * 52 * thump_t) * np.exp(-thump_t * 14) + 0.5 * np.sin(2 * np.pi * 150 * thump_t) * np.exp(-thump_t * 28))
for k in range(12):                       # 4 per loop × 3 copies
    for off, g in ((0.0, 1.0), (0.24, 0.65)):
        s = int((k * 2.0 + 0.3 + off) * SR)
        if s + len(thump) <= len(beat): beat[s:s + len(thump)] += thump * g

mixed = drone * 0.55 + chant * 0.45 + deep * 0.35 + beat * 0.9
loop = mixed[N:2 * N]                     # the middle copy: steady state at both ends
loop = loop - loop.mean()
loop = loop / np.max(np.abs(loop)) * 10 ** (-6 / 20)

# seam check: the jump from the last sample to the first should be no bigger than a normal step
steps = np.abs(np.diff(loop)); seam = abs(loop[0] - loop[-1])
print(f'seam {seam:.4f}, typical step {np.median(steps):.4f}, max step {steps.max():.4f}')
with wave.open(os.path.join(OUT, 'cth_loop_awakening.wav'), 'w') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((np.clip(loop, -1, 1) * 32767).astype(np.int16).tobytes())
rms = 20 * np.log10(np.sqrt(np.mean(loop ** 2)))
print(f'cth_loop_awakening.wav {L:.0f}s, peak -6 dB, rms {rms:.1f} dB')
