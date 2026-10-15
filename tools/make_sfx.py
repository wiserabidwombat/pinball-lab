"""M9 round 2: convert Kenney Sci-fi Sounds + Impact Sounds (CC0) OGGs into the game's
sfx_<event>.wav files (44.1 kHz, mono, 16-bit), trimmed with a fade and levelled per event.
Usage: python3 make_sfx.py <unzipped-packs-dir> <out-dir>
Each entry: event: (pack/file, max seconds or None, fade seconds, level dB relative to a -1 dBFS peak)."""
import subprocess, sys, re, os
SRC, OUT = sys.argv[1], sys.argv[2]
MAP = {
    "flipper":     ("impact/impactPlate_light_000", 0.25, 0.08, -12),
    "bumper":      ("scifi/forceField_001",         0.35, 0.12, -5),
    "sling":       ("impact/impactPunch_medium_000", 0.30, 0.10, -7),
    "launch":      ("scifi/thrusterFire_000",       0.70, 0.30, -6),
    "rollover":    ("scifi/laserSmall_000",         None, 0.05, -8),
    "multiplier":  ("scifi/laserRetro_002",         None, 0.05, -3),
    "dropTarget":  ("impact/impactMetal_medium_000", None, 0.05, -5),
    "bank":        ("scifi/explosionCrunch_000",    None, 0.15, -3),
    "scoopIn":     ("scifi/doorClose_000",          None, 0.10, -5),
    "scoopOut":    ("scifi/doorOpen_000",           None, 0.10, -6),
    "ramp":        ("scifi/laserLarge_000",         None, 0.15, -4),
    "orbit":       ("scifi/spaceEngineSmall_000",   0.70, 0.30, -6),
    "drain":       ("scifi/lowFrequency_explosion_001", None, 0.30, -4),
    "ballSave":    ("scifi/forceField_002",         0.80, 0.30, -3),
    "skillShot":   ("scifi/laserRetro_000",         None, 0.05, -2),
    "lock":        ("scifi/forceField_003",         0.90, 0.30, -3),
    "multiball":   ("scifi/spaceEngineLarge_000",   1.50, 0.60, -3),
    "jackpot":     ("scifi/explosionCrunch_002",    None, 0.30, -2),
    "waveStart":   ("scifi/computerNoise_002",      1.00, 0.40, -4),
    "scoutDown":   ("scifi/laserSmall_001",         None, 0.05, -4),
    "waveCleared": ("scifi/explosionCrunch_003",    None, 0.40, -2),
    "cowSaved":    ("scifi/laserRetro_004",         None, 0.05, -3),
    "cowTaken":    ("scifi/slime_000",              None, 0.10, -3),
    "mothership":  ("scifi/spaceEngineLow_000",     2.50, 1.00, -2),
    "coreHit":     ("scifi/explosionCrunch_004",    1.50, 0.50, -2),
    "mothershipBoom": ("scifi/lowFrequency_explosion_000", None, 0.50, -1),
    "extraBall":   ("scifi/laserRetro_003",         None, 0.05, -2),
    "kickback":    ("scifi/thrusterFire_001",       0.50, 0.25, -5),
}
os.makedirs(OUT, exist_ok=True)
def probe(path, what):
    if what == "dur":
        return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                                    capture_output=True, text=True).stdout)
    out = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af", "volumedetect", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    return float(re.search(r"max_volume: (-?[\d.]+) dB", out).group(1))
for event, (src, maxlen, fade, level) in MAP.items():
    pack, name = src.split("/")
    path = os.path.join(SRC, pack, "Audio", name + ".ogg")
    dur = probe(path, "dur"); peak = probe(path, "peak")
    length = min(dur, maxlen) if maxlen else dur
    gain = (-1 + level) - peak
    af = f"afade=t=out:st={max(length - fade, 0):.3f}:d={fade:.3f},volume={gain:.2f}dB"
    dst = os.path.join(OUT, f"sfx_{event}.wav")
    subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", path, "-t", f"{length:.3f}",
                    "-af", af, "-ac", "1", "-ar", "44100", "-sample_fmt", "s16", dst], check=True)
    print(f"sfx_{event}.wav  {length:4.2f}s  from {src}  ({level:+d} dB)")
