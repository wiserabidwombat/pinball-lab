"""Shot Lab part 3: game-flow simulator (Monte Carlo).

Plays thousands of games of a table's rules, using the Shot Lab's MEASURED aimed-shot outcomes
(Shot Lab results JSON) plus stated ASSUMPTIONS for what the lab can't measure (how often a player
catches the ball, how often a loose ball drains, what a loose ball hits). Reports how far beginner,
average and expert players get, and where they stall.

Reusable: the engine (Player, aimed-shot sampling, possessions) is table-agnostic; the rules live in
a Rules class (GreyInvasionRules here). A new table writes its own Rules class and SHOTS_FROM map.

Usage: python3 simulate.py shotlab-results.json [games]
"""
import json, math, random, sys, collections

# ----------------------------------------------------------------------------- assumptions
# Everything the lab can't measure. Each is a guess; calibrate later from real play (telemetry).
SKILLS = {
    #               timing σ  catch the ball  loose-ball drain  pass to other flipper
    "beginner": dict(sigma=0.040, control=0.30, loose_drain=0.18, passing=0.55),
    "average":  dict(sigma=0.025, control=0.50, loose_drain=0.12, passing=0.75),
    "expert":   dict(sigma=0.015, control=0.70, loose_drain=0.08, passing=0.90),
}
POSSESSION_SECONDS = 3.0          # one "possession": the ball comes down to the flippers once
# What a LOOSE ball (not caught, not aimed) hits on its way round, per possession (expected counts).
LOOSE_HITS = {"bumper": 0.6, "lane": 0.12, "fighter": 0.10, "hangar": 0.03, "abduction": 0.03,
              "orbit": 0.04, "leftRamp": 0.04, "rightRamp": 0.04}
PLUNGE_BUMPERS = 1.5              # bumper hits after a plunge (it falls through the lanes into them)
PLUNGE_NEW_LANE = {"beginner": 0.6, "average": 0.8, "expert": 0.95}   # plunge lights an unlit lane (lane change)
CONTROL_BONUS = {"ramp": 0.25, "scoop": 0.15}   # a made ramp feeds an inlane; a scoop kicks out to a flipper
SAVE_CHANCE = 0.35                # share of drains a lit kickback / outlane save would catch (that side's outlane)
BALLS_PER_GAME = 3
WAVE1_SECONDS = 30              # Campaign.scoutSeconds
SCOUTS = 2                      # Campaign.scoutCount (3 before M10 v17)
SHIELD_HITS = 3                 # Campaign.shieldHitsPerGenerator
SHIELD_SHOTS = ("orbit", "hangar", "abduction")   # Campaign.shieldShots (M10 v17; was none)
MAX_GAME_SECONDS = 1200         # stop a simulated game here (experts loop invasions for ever)

# Which flipper can aim at which shot (from the lab: shots with a measured window).
SHOTS_FROM = {"left": ["hangar", "rightRamp", "abduction", "fighter"],
              "right": ["hangar", "leftRamp", "orbit", "abduction"]}


# ----------------------------------------------------------------------------- lab → aimed outcomes
def phi(x): return 0.5 * (1 + math.erf(x / math.sqrt(2)))

def aimed_tables(results, hz):
    """{(flipper, target, skill): [(outcome, prob, bumpers)]} for one phone rate, aiming at the best moment."""
    hzof = lambda t: 120 if t.get("physicsStepMs", 0) < 12 else 60
    out = {}
    for flipper in ("left", "right"):
        trials = [t for t in results["trials"] if t["flipper"] == flipper and hzof(t) == hz and t["outcome"] != "invalid"]
        by = collections.defaultdict(list)
        for t in trials:
            by[round(t["actualDelay"], 4)].append(t)
        moments = sorted(by)
        gaps = [b - a for a, b in zip(moments, moments[1:])]
        edges = []
        for i, m in enumerate(moments):
            lo = m - (gaps[i - 1] / 2 if i > 0 else gaps[0] / 2)
            hi = m + (gaps[i] / 2 if i < len(gaps) else gaps[-1] / 2)
            edges.append((lo, hi))
        for target in SHOTS_FROM[flipper]:
            frac = [sum(1 for t in by[m] if t["outcome"] == target) / len(by[m]) for m in moments]
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
                    for t in by[m]:
                        dist[(t["outcome"], t["events"].count("bumper"))] += w / len(by[m])
                total = sum(dist.values())
                out[(flipper, target, skill)] = [(o, p / total, b) for (o, b), p in dist.items()]
    return out


# ----------------------------------------------------------------------------- engine
class Player:
    def __init__(self, skill, tables, rng):
        self.skill, self.s, self.tables, self.rng = skill, SKILLS[skill], tables, rng

    def p_make(self, target, flipper):
        return sum(p for o, p, _ in self.tables.get((flipper, target, self.skill), []) if o == target)

    def best_flipper(self, target):
        opts = [f for f in ("left", "right") if target in SHOTS_FROM[f]]
        return max(opts, key=lambda f: self.p_make(target, f)) if opts else None

    def aim(self, target, on):
        """The ball is caught on flipper `on`; shoot `target`. Returns (outcome, bumpers) or ('loose', 0)."""
        f = self.best_flipper(target)
        if f is None: return ("loose", 0)
        if f != on and self.rng.random() > self.s["passing"]:
            return ("loose", 0)                       # fumbled the pass to the other flipper
        r, acc = self.rng.random(), 0
        for o, p, b in self.tables[(f, target, self.skill)]:
            acc += p
            if r <= acc: return (o, b)
        return ("none", 0)

    def easiest(self, targets):
        return max(targets, key=lambda t: self.p_make(t, self.best_flipper(t)) if self.best_flipper(t) else 0)


def poisson(rng, lam):
    k, p, L = 0, 1.0, math.exp(-lam)
    while True:
        p *= rng.random()
        if p <= L: return k
        k += 1


class GreyInvasionRules:
    """Campaign.swift + TableScene rules, reduced to what decides progress."""
    MILESTONES = ["hangar lit", "wave 1 started", "wave 1 cleared", "wave 2 cleared", "wave 3 cleared",
                  "mothership started", "mothership destroyed"]

    def __init__(self, player, rng):
        self.pl, self.rng = player, rng
        self.reached = set()
        self.phase, self.wave = "building", 1            # building / ready / running
        self.lanes, self.ramps = 0, 0
        self.lit, self.timer = set(), 0.0
        self.fighters, self.bank_done = 0, False
        self.cows = 0
        self.shields, self.core_open, self.core_hits = [], False, 0
        self.kickback = False; self.outlane_save = False; self.extra_ball_lit = False; self.extra_ball_given = False
        self.balls_left = BALLS_PER_GAME
        self.time = 0.0
        self.mothership_tries = 0

    def mark(self, m): self.reached.add(m)

    # --- what the player aims at next
    def target(self):
        if self.extra_ball_lit: return "hangar"
        if self.phase == "building": return self.pl.easiest(["leftRamp", "rightRamp"])
        if self.phase == "ready": return "hangar"
        if self.wave == 1: return self.pl.easiest(sorted(self.lit))
        if self.wave == 2: return "leftRamp" if self.bank_done else "fighter"
        if self.wave == 3: return "abduction"
        return self.pl.easiest(["leftRamp", "rightRamp"]) if self.core_open else "orbit"   # nothing aims at bumpers

    # --- events
    def hit(self, what, n=1):
        for _ in range(n): self._hit(what)

    def _hit(self, what):
        if what == "lane":
            if self.phase == "building":
                self.lanes += 1
                if self.lanes >= 3: self.lanes = 0; self.light()
            return
        if what == "bumper":
            if self.phase == "running" and self.wave == 4 and not self.core_open and self.shields:
                i = self.rng.randrange(3)
                if self.shields[i] > 0: self.shields[i] -= 1
                if all(s == 0 for s in self.shields): self.core_open = True
            return
        if what == "fighter":
            self.fighters += self.rng.choice([1, 1, 2])          # a shot drops 1–2 of the 4 fighters
            if self.fighters >= 4:
                self.fighters = 0; self.kickback = True
                if self.phase == "running" and self.wave == 2: self.bank_done = True
            return
        if what == "hangar" and self.extra_ball_lit:
            self.extra_ball_lit = False; self.balls_left += 1; return
        if (self.phase == "running" and self.wave == 4 and not self.core_open and what in SHIELD_SHOTS
                and any(self.shields)):
            i = max(range(3), key=lambda k: self.shields[k]); self.shields[i] -= 1     # an aimed shot hits a generator
            if all(x == 0 for x in self.shields): self.core_open = True
            return
        if self.phase == "building" and what in ("leftRamp", "rightRamp"):
            self.ramps += 1
            if self.ramps >= 3: self.light()
        elif self.phase == "ready" and what == "hangar":
            self.start_wave()
        elif self.phase == "running":
            w = self.wave
            if w == 1 and what in self.lit:
                self.lit.discard(what)
                if not self.lit: self.clear()
            elif w == 2 and self.bank_done and what == "leftRamp": self.clear()
            elif w == 3 and what == "abduction":
                self.cows += 1; self.timer = 20
                if self.cows >= 3: self.clear()
            elif w == 4 and self.core_open and what in ("leftRamp", "rightRamp"):
                self.core_hits += 1; self.core_open = False; self.shields = [SHIELD_HITS] * 3
                if self.core_hits >= 3:
                    self.mark("mothership destroyed"); self.phase, self.wave = "building", 1   # invasion 2
                    self.lanes = self.ramps = 0; self.core_hits = 0; self.mb_balls = 0

    def light(self):
        self.phase = "ready"; self.mark("hangar lit")

    def start_wave(self):
        self.phase = "running"
        w = self.wave
        if w == 1: self.mark("wave 1 started"); self.timer = WAVE1_SECONDS; self.lit = set(self.rng.sample(
            ["leftRamp", "rightRamp", "orbit", "hangar", "abduction"], SCOUTS))
        if w == 2: self.bank_done = False
        if w == 3: self.cows = 0; self.timer = 20
        if w == 4:
            self.mark("mothership started"); self.mothership_tries += 1
            self.shields = [SHIELD_HITS] * 3; self.core_open = False
            self.mb_balls, self.mb_save_until = 2, self.time + 15

    def clear(self):
        self.mark(f"wave {self.wave} cleared"); self.outlane_save = True
        if self.wave == 2 and not self.extra_ball_given: self.extra_ball_given = self.extra_ball_lit = True
        self.wave += 1; self.phase = "building"; self.lanes = self.ramps = 0

    def tick(self, dt):
        self.time += dt
        if self.phase == "running" and self.wave == 1:
            self.timer -= dt
            if self.timer <= 0: self.phase = "ready"; self.lit = set()          # scouts escaped, Hangar stays lit
        if self.phase == "running" and self.wave == 3:
            self.timer -= dt
            if self.timer <= 0: self.timer = 20                                 # a cow is taken; the wave goes on


def play_game(rules_cls, player, rng):
    g = rules_cls(player, rng)
    s = player.s
    while g.balls_left > 0 and g.time < MAX_GAME_SECONDS:
        g.balls_left -= 1
        # plunge: maybe a lane, then the bumpers
        if rng.random() < PLUNGE_NEW_LANE[player.skill]: g.hit("lane")
        g.hit("bumper", poisson(rng, PLUNGE_BUMPERS))
        shields_up_until = g.time + 10
        bonus = 0.0
        while True:
            mothership = g.phase == "running" and g.wave == 4
            caught = rng.random() < min(1.0, s["control"] * (0.7 if mothership else 1) + bonus)
            bonus = 0.0
            drained = False
            if caught:
                outcome, bumpers = player.aim(g.target(), rng.choice(["left", "right"]))
                if outcome == "loose": caught = False
                else:
                    g.hit("bumper", bumpers)
                    if outcome == "drain": drained = True
                    elif outcome != "none":
                        g.hit(outcome)
                        bonus = CONTROL_BONUS["ramp"] if "Ramp" in outcome else CONTROL_BONUS["scoop"] if outcome in ("hangar", "abduction") else 0
            if not caught:
                for what, lam in LOOSE_HITS.items():
                    g.hit(what, poisson(rng, lam * (1.5 if mothership else 1)))
                drained = rng.random() < s["loose_drain"]
            g.tick(POSSESSION_SECONDS)
            # the Mothership's second ball: its own loose possession each time
            if g.phase == "running" and g.wave == 4 and getattr(g, "mb_balls", 0) >= 2:
                for what, lam in LOOSE_HITS.items():
                    g.hit(what, poisson(rng, lam * 1.5))
                if rng.random() < s["loose_drain"]:
                    if g.time < g.mb_save_until: pass                       # ball save: back out of the Hangar
                    else: g.mb_balls = 1                                    # down to one ball → it escapes
                if g.mb_balls == 1 and g.phase == "running" and g.wave == 4:
                    g.phase = "ready"; g.shields = []; g.core_open = False   # escaped: core hits kept, Hangar relit
            if g.time >= MAX_GAME_SECONDS: break
            if not drained: continue
            if g.phase == "running" and g.wave == 4 and g.time < getattr(g, "mb_save_until", 0): continue
            if g.time < shields_up_until: shields_up_until = 0; continue     # Shields Up: once per ball
            if g.phase == "running" and g.wave == 4 and g.mb_balls >= 2:
                g.mb_balls = 1; g.phase = "ready"; g.shields = []; g.core_open = False
                continue                                                     # the other ball plays on
            if g.kickback and rng.random() < SAVE_CHANCE: g.kickback = False; continue
            if g.outlane_save and rng.random() < SAVE_CHANCE: g.outlane_save = False; continue
            g.outlane_save = False
            break
    return g


def run(results, hz, games=20000, seed=1):
    tables = aimed_tables(results, hz)
    report = {}
    for skill in SKILLS:
        rng = random.Random(seed)
        pl = Player(skill, tables, rng)
        counts = collections.Counter(); times = []; tries = []
        for _ in range(games):
            g = play_game(GreyInvasionRules, pl, rng)
            counts.update(g.reached); times.append(g.time)
            if "mothership started" in g.reached: tries.append(g.mothership_tries)
        times.sort()
        report[skill] = {
            "milestones": {m: counts[m] / games for m in GreyInvasionRules.MILESTONES},
            "medianGameMinutes": times[len(times) // 2] / 60,
            "mothershipTries": (sum(tries) / len(tries)) if tries else 0,
            "shotOdds": {t: round(pl.p_make(t, pl.best_flipper(t)), 3) for t in
                         ["hangar", "leftRamp", "rightRamp", "orbit", "abduction", "fighter"]},
        }
    return report


if __name__ == "__main__":
    results = json.load(open(sys.argv[1]))
    games = int(sys.argv[2]) if len(sys.argv) > 2 else 20000
    full = {}
    for hz in (120, 60):
        rep = run(results, hz, games)
        full[f"{hz}Hz"] = rep
        print(f"\n=== {hz} Hz phone — share of games that reach each step ({games} games per skill)")
        print(f"  {'':22s}" + "".join(f"{s:>10s}" for s in SKILLS))
        for m in GreyInvasionRules.MILESTONES:
            print(f"  {m:22s}" + "".join(f"{rep[s]['milestones'][m]*100:9.0f}%" for s in SKILLS))
        print(f"  {'median game (min)':22s}" + "".join(f"{rep[s]['medianGameMinutes']:10.1f}" for s in SKILLS))
        print(f"  {'Mothership attempts':22s}" + "".join(f"{rep[s]['mothershipTries']:10.1f}" for s in SKILLS))
    json.dump(full, open(sys.argv[1].replace(".json", "-sim.json"), "w"), indent=1)
