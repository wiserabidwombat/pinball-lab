"""Pinball Lab Table 03 (Cthulhu Rising), milestone 7 round 5: game-flow simulator (Monte Carlo).

Plays thousands of games of Table 03's rules (CthCampaign.swift + CthTableScene) using the Shot Lab's MEASURED
aimed-shot outcomes from two runs: Cthulhu asleep (every phase but the Awakening) and Cthulhu up (the Awakening,
where the Lagoon is his stage). Everything the lab can't measure is a stated ASSUMPTION, shared with Grey
Invasion's simulator (tools/shotlab_simulate.py) where it applies. Three flippers: the upper flipper is reached
after an orbit (the orbit rolls off the launch gate onto it).

Usage: python3 cth_simulate.py <down.json> <up.json> [games]   (prints 120 Hz and 60 Hz, plus a sensitivity table)
"""
import json, math, random, sys, collections

SKILLS = {
    #               timing σ  catch the ball  loose-ball drain  pass to other flipper
    "beginner": dict(sigma=0.040, control=0.30, loose_drain=0.18, passing=0.55),
    "average":  dict(sigma=0.025, control=0.50, loose_drain=0.12, passing=0.75),
    "expert":   dict(sigma=0.015, control=0.70, loose_drain=0.08, passing=0.90),
}
POSSESSION_SECONDS = 3.0
# What a LOOSE ball hits per possession (expected counts). "cthulhu" only while he's up (the Lagoon otherwise).
LOOSE_HITS = {"bumper": 0.6, "lane": 0.12, "sigil": 0.10, "library": 0.03, "lagoon": 0.03,
              "orbit": 0.04, "rightRamp": 0.04}
LOOSE_CTHULHU = 0.04              # he sways in front of the bumper nest: stray hits while he's up
PLUNGE_NEW_LANE = {"beginner": 0.6, "average": 0.8, "expert": 0.95}
CONTROL_BONUS = {"rightRamp": 0.25, "library": 0.25, "lagoon": 0.10}   # wire returns feed an inlane
UPPER_FEED = 0.7                  # after an orbit, the ball comes to the upper flipper this often
ORBIT_PAGES = 15                  # spinner spins (= Necronomicon pages) from a made orbit (~20 measured on a hard one)
SAVE_CHANCE = 0.35
BALLS_PER_GAME = 3
ELDER_SIGN = 10
MAX_GAME_SECONDS = 1200
# Rule knobs (CthCampaign values; experiments change these).
# M7 v5 (Aaron: "Do the full set"): the recommended package. Before: clues 3, pages 60 in 40 s, tentacle hits 2,
# awaken save 15, escape resets the candles, a failed tome starts over.
RULES = dict(clues=2, pages=40, necro_time=50, glyph_time=30, tentacle_hits=1, eye_hits=3,
             ritual_save=10, awaken_save=25, escape_keeps_candles=True, necro_ramp_pages=10,
             keep_progress=True)
FLIPPERS = ("left", "right", "upper")
MAIN = ("left", "right")
# Which flipper can aim at which shot (lab: a measured window from that flipper).
SHOTS_FROM = {"left": ["rightRamp", "library", "lagoon", "sigil", "cthulhu"],
              "right": ["orbit", "library", "lane"],
              "upper": ["lagoon", "library", "lane", "cthulhu"]}


def phi(x): return 0.5 * (1 + math.erf(x / math.sqrt(2)))


def aimed_tables(results, hz, cthulhu_scale=1.0):
    """{(flipper, target, skill): [(outcome, prob)]} aiming at the best moment (Gaussian timing error)."""
    hzof = lambda t: 120 if t.get("physicsStepMs", 0) < 12 else 60
    out = {}
    for flipper in FLIPPERS:
        trials = [t for t in results["trials"] if t["flipper"] == flipper and hzof(t) == hz and t["outcome"] != "invalid"]
        if not trials: continue
        by = collections.defaultdict(list)
        for t in trials: by[round(t["actualDelay"], 4)].append(t)
        moments = sorted(by)
        gaps = [b - a for a, b in zip(moments, moments[1:])] or [0.004]
        edges = [(m - (gaps[i - 1] if i > 0 else gaps[0]) / 2, m + (gaps[i] if i < len(gaps) else gaps[-1]) / 2)
                 for i, m in enumerate(moments)]
        for target in SHOTS_FROM[flipper]:
            frac = [sum(1 for t in by[m] if t["outcome"] == target) / len(by[m]) for m in moments]
            if not any(frac): continue
            for skill, s in SKILLS.items():
                sig = s["sigma"]
                best, best_aim = -1, moments[0]
                for k in range(int((moments[-1] - moments[0]) / 0.001) + 1):
                    aim = moments[0] + k * 0.001
                    p = sum(f * (phi((hi - aim) / sig) - phi((lo - aim) / sig)) for f, (lo, hi) in zip(frac, edges))
                    if p > best: best, best_aim = p, aim
                dist = collections.defaultdict(float)
                for m, (lo, hi) in zip(moments, edges):
                    w = phi((hi - best_aim) / sig) - phi((lo - best_aim) / sig)
                    for t in by[m]: dist[t["outcome"]] += w / len(by[m])
                if target == "cthulhu" and cthulhu_scale != 1.0 and dist["cthulhu"] > 0:
                    moved = dist["cthulhu"] * (1 - cthulhu_scale)
                    dist["cthulhu"] -= moved; dist["none"] += moved
                total = sum(dist.values())
                out[(flipper, target, skill)] = [(o, p / total) for o, p in dist.items()]
    return out


class Player:
    def __init__(self, skill, down, up, rng, control_scale=1.0, drain_scale=1.0):
        self.skill, self.rng = skill, rng
        s = dict(SKILLS[skill]); s["control"] *= control_scale; s["loose_drain"] *= drain_scale
        self.s, self.down, self.up = s, down, up

    def p(self, tables, target, f):
        return sum(p for o, p in tables.get((f, target, self.skill), []) if o == target)

    def shoot(self, tables, goals, on):
        """Ball cradled on flipper `on`; aim at the best goal from here, or pass across. Returns an outcome."""
        options = [(self.p(tables, g, f), g, f) for g in goals for f in FLIPPERS
                   if (f == on or (on in MAIN and f in MAIN)) and (f, g, self.skill) in tables]
        if not options: return "loose"
        p, goal, f = max(options)
        if p <= 0: return "loose"
        if f != on and self.rng.random() > self.s["passing"]: return "loose"
        r, acc = self.rng.random(), 0
        for o, q in tables[(f, goal, self.skill)]:
            acc += q
            if r <= acc: return o
        return "none"


def poisson(rng, lam):
    k, p, L = 0, 1.0, math.exp(-lam)
    while True:
        p *= rng.random()
        if p <= L: return k
        k += 1


class CthulhuRules:
    """CthCampaign.swift reduced to what decides progress."""
    MILESTONES = ["library lit", "tome I read", "tome II read", "ritual lit", "ritual started",
                  "awakening", "eye open", "banished"]

    def __init__(self, rng):
        self.rng = rng
        self.reached = set()
        self.phase, self.tome = "research", 0
        self.clues, self.lanes, self.sigils = 0, 0, 0
        self.timer, self.pages, self.lit, self.seals = 0.0, 0, set(), False
        self.candles = set(); self.tentacles = [2] * 4; self.eye = 0
        self.kickback = self.outlane_save = False
        self.balls_left = BALLS_PER_GAME
        self.time = 0.0
        self.extra = 0; self.save_until = 0.0          # multiball balls beyond the first, and its ball save
        self.ritual_tries = self.awaken_tries = 0

    def mark(self, m): self.reached.add(m)

    def goals(self):
        ph = self.phase
        if ph == "research": return ["rightRamp", "orbit", "lagoon", "sigil", "lane"]
        if ph in ("libraryLit", "ritualLit"): return ["library"]
        if ph == "tome":
            if self.tome == 0: return ["rightRamp", "orbit"]
            if self.tome == 1: return sorted(self.lit)
            return ["rightRamp"] if self.seals else ["sigil"]
        if ph == "ritual": return [s for s in ("orbit", "rightRamp", "library", "lagoon", "sigil") if s not in self.candles]
        if ph == "awakening":
            return ["cthulhu", "rightRamp", "orbit"] if any(self.tentacles) else ["cthulhu"]
        return []

    def hit(self, what, n=1):
        for _ in range(n): self._hit(what)

    def _clue(self):
        self.clues += 1
        if self.clues >= RULES['clues']: self.phase = "libraryLit"; self.mark("library lit")

    def _hit(self, what):
        ph = self.phase
        if what == "bumper": return
        if what == "lane":
            self.lanes += 1
            if self.lanes >= 3:
                self.lanes = 0
                if ph == "research": self._clue()
            return
        if what == "sigil":
            bank = False
            self.sigils += self.rng.choice([1, 1, 2])
            if self.sigils >= 4: self.sigils = 0; self.kickback = True; bank = True
            if ph == "research" and bank: self._clue()
            elif ph == "tome" and self.tome == 2 and bank: self.seals = True
            elif ph == "tome" and self.tome == 1 and "sigil" in self.lit: self._glyph("sigil")
            elif ph == "ritual": self._candle("sigil")
            return
        if what == "cthulhu":
            if ph == "awakening": self._cthulhu()
            return
        if ph == "research":
            if what in ("rightRamp", "orbit", "lagoon"): self._clue()
        elif ph == "libraryLit" and what == "library":
            resume = RULES['keep_progress'] and getattr(self, "failed", None) == self.tome
            self.phase = "tome"
            if not resume: self.pages, self.seals, self.lit = 0, False, set()
            self.failed = None
            if self.tome == 0: self.timer = RULES['necro_time']
            if self.tome == 1:
                self.timer = RULES['glyph_time']
                if not resume: self.lit = set(self.rng.sample(["rightRamp", "orbit", "library", "lagoon", "sigil"], 2))
        elif ph == "tome":
            if self.tome == 0 and what in ("rightRamp", "orbit"):
                self.pages += RULES['necro_ramp_pages'] if what == "rightRamp" else ORBIT_PAGES
                if self.pages >= RULES['pages']: self._finish()
            elif self.tome == 1 and what in self.lit: self._glyph(what)
            elif self.tome == 2 and self.seals and what == "rightRamp": self._finish()
        elif ph == "ritualLit" and what == "library":
            self.phase = "ritual"; self.mark("ritual started"); self.ritual_tries += 1
            self.extra = max(self.extra, 1); self.save_until = self.time + RULES['ritual_save']
            if len(self.candles) == 5: self.candles.discard("library"); self._candle("library")
        elif ph == "ritual": self._candle(what)
        elif ph == "awakening" and what in ("rightRamp", "orbit"): self._tentacle()

    def _glyph(self, what):
        self.lit.discard(what)
        if not self.lit: self._finish()

    def _finish(self):
        self.mark(["tome I read", "tome II read", "ritual lit"][self.tome])
        self.outlane_save = True
        r = self.rng.randrange(3)
        if r == 0: self.kickback = True
        self.tome += 1; self.clues = 0; self.timer = 0
        self.phase = "ritualLit" if self.tome >= 3 else "research"

    def _candle(self, what):
        if what in ("orbit", "rightRamp", "library", "lagoon", "sigil") and what not in self.candles:
            self.candles.add(what)
            if len(self.candles) == 5:
                self.phase = "awakening"; self.mark("awakening"); self.awaken_tries += 1
                self.tentacles = [RULES['tentacle_hits']] * 4; self.extra = 2; self.save_until = self.time + RULES['awaken_save']

    def _tentacle(self):
        i = max(range(4), key=lambda k: self.tentacles[k])
        if self.tentacles[i] > 0: self.tentacles[i] -= 1
        if not any(self.tentacles): self.mark("eye open")

    def _cthulhu(self):
        if any(self.tentacles): self._tentacle(); return
        self.eye += 1
        if self.eye >= RULES['eye_hits']:
            self.mark("banished")
            self.phase, self.tome, self.clues, self.candles, self.eye = "research", 0, 0, set(), 0

    def multiball_ended(self):
        if self.phase == "ritual": self.phase = "ritualLit"
        elif self.phase == "awakening":
            self.phase = "ritualLit"; self.tentacles = [RULES['tentacle_hits']] * 4
            if not RULES['escape_keeps_candles']: self.candles = set()

    def tick(self, dt):
        self.time += dt
        if self.phase == "tome" and self.tome < 2:
            self.timer -= dt
            if self.timer <= 0:
                self.phase = "libraryLit"; self.failed = self.tome
                if not RULES['keep_progress']: self.lit = set()


def play_game(player, rng):
    g = CthulhuRules(rng)
    s = player.s
    while g.balls_left > 0 and g.time < MAX_GAME_SECONDS:
        g.balls_left -= 1
        if rng.random() < PLUNGE_NEW_LANE[player.skill]: g.hit("lane")
        elder_until = g.time + ELDER_SIGN
        bonus, on = 0.0, None
        while True:
            awake = g.phase == "awakening"
            tables = player.up if awake else player.down
            multi = g.extra > 0
            caught = rng.random() < min(1.0, s["control"] * (0.7 if multi else 1) + bonus)
            bonus, drained = 0.0, False
            outcome = "loose"
            if caught:
                flipper = on or rng.choice(MAIN)
                goals = g.goals()
                if flipper == "upper" and not any((("upper", t, player.skill) in tables) for t in goals):
                    flipper = rng.choice(MAIN)          # nothing to aim at from the upper flipper: let it drop
                outcome = player.shoot(tables, goals, flipper)
            on = None
            if outcome == "loose" or not caught:
                for what, lam in LOOSE_HITS.items():
                    if awake and what == "lagoon": continue
                    g.hit(what, poisson(rng, lam * (1.5 if multi else 1)))
                if awake: g.hit("cthulhu", poisson(rng, LOOSE_CTHULHU))
                drained = rng.random() < s["loose_drain"]
            elif outcome == "drain":
                drained = True
            elif outcome != "none":
                g.hit(outcome)
                bonus = CONTROL_BONUS.get(outcome, 0)
                if outcome == "orbit" and rng.random() < UPPER_FEED: on = "upper"
            g.tick(POSSESSION_SECONDS)
            # the other multiball balls: loose possessions of their own
            for _ in range(g.extra):
                for what, lam in LOOSE_HITS.items():
                    if g.phase == "awakening" and what == "lagoon": continue
                    g.hit(what, poisson(rng, lam))
                if g.phase == "awakening": g.hit("cthulhu", poisson(rng, LOOSE_CTHULHU))
                if rng.random() < s["loose_drain"] and g.time >= g.save_until:
                    g.extra -= 1
            if g.extra == 0 and g.phase in ("ritual", "awakening"): g.multiball_ended()
            if g.time >= MAX_GAME_SECONDS: break
            if not drained: continue
            if g.extra > 0:
                if g.time >= g.save_until:
                    g.extra -= 1
                    if g.extra == 0: g.multiball_ended()
                continue                                                     # another ball plays on
            if g.time < elder_until: elder_until = 0; continue                # Elder Sign, once per ball
            if g.kickback and rng.random() < SAVE_CHANCE: g.kickback = False; continue
            if g.outlane_save and rng.random() < SAVE_CHANCE: g.outlane_save = False; continue
            g.outlane_save = False
            break
    return g


def run(down, up, hz, games, seed=1, **kw):
    cs = kw.pop("cthulhu_scale", 1.0)
    td, tu = aimed_tables(down, hz), aimed_tables(up, hz, cs)
    report = {}
    for skill in SKILLS:
        rng = random.Random(seed)
        pl = Player(skill, td, tu, rng, **kw)
        counts, times = collections.Counter(), []
        rt, at = [], []
        for _ in range(games):
            g = play_game(pl, rng)
            counts.update(g.reached); times.append(g.time)
            if g.ritual_tries: rt.append(g.ritual_tries)
            if g.awaken_tries: at.append(g.awaken_tries)
        times.sort()
        report[skill] = {
            "milestones": {m: counts[m] / games for m in CthulhuRules.MILESTONES},
            "medianGameMinutes": times[len(times) // 2] / 60,
            "ritualTries": sum(rt) / len(rt) if rt else 0,
            "awakeningTries": sum(at) / len(at) if at else 0,
            "shotOdds": {f"{t}<{f}": round(pl.p(tu if t == "cthulhu" else td, t, f), 3)
                         for f in FLIPPERS for t in SHOTS_FROM[f]},
        }
    return report


def show(rep, title):
    print(f"\n=== {title}")
    print(f"  {'':22s}" + "".join(f"{s:>10s}" for s in SKILLS))
    for m in CthulhuRules.MILESTONES:
        print(f"  {m:22s}" + "".join(f"{rep[s]['milestones'][m]*100:9.0f}%" for s in SKILLS))
    print(f"  {'median game (min)':22s}" + "".join(f"{rep[s]['medianGameMinutes']:10.1f}" for s in SKILLS))
    print(f"  {'Ritual attempts':22s}" + "".join(f"{rep[s]['ritualTries']:10.1f}" for s in SKILLS))
    print(f"  {'Awakening attempts':22s}" + "".join(f"{rep[s]['awakeningTries']:10.1f}" for s in SKILLS))


if __name__ == "__main__":
    down, up = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
    games = int(sys.argv[3]) if len(sys.argv) > 3 else 5000
    full = {}
    for hz in (120, 60):
        rep = run(down, up, hz, games)
        full[f"{hz}Hz"] = rep
        show(rep, f"{hz} Hz phone — share of games that reach each step ({games} games per skill)")
    print("\nAimed-shot odds, average player, 120 Hz:")
    print("  " + ", ".join(f"{k} {v*100:.0f}%" for k, v in full["120Hz"]["average"]["shotOdds"].items() if v > 0))
    # Sensitivity (120 Hz, average player's key steps)
    print("\n=== Sensitivity, 120 Hz (average: ritual lit / ritual started / awakening / banished; beginner: library lit / ritual lit)")
    for label, kw in [("as assumed", {}), ("control ×0.75", {"control_scale": 0.75}), ("control ×1.25", {"control_scale": 1.25}),
                      ("drain ×0.75", {"drain_scale": 0.75}), ("drain ×1.3", {"drain_scale": 1.3}),
                      ("Cthulhu odds ×0.5", {"cthulhu_scale": 0.5})]:
        rep = run(down, up, 120, max(1000, games // 3), **kw)
        a, b = rep["average"]["milestones"], rep["beginner"]["milestones"]
        print(f"  {label:18s} avg {a['ritual lit']*100:4.0f}% {a['ritual started']*100:4.0f}% {a['awakening']*100:4.0f}% "
              f"{a['banished']*100:4.0f}%   beg {b['library lit']*100:4.0f}% {b['ritual lit']*100:4.0f}%")
    json.dump(full, open(sys.argv[1].replace(".json", "-cthsim.json"), "w"), indent=1)
