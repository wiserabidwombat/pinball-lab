"""Pinball Lab Table 04 (Monsoon), milestone 8 round 6: game-flow simulator (Monte Carlo).

Plays thousands of games of Monsoon's rules (MonTableScene "Rules": Act 1 washes, Monsoon, Superbloom, and the
carried-over saves) using the Shot Lab's MEASURED aimed-shot outcomes (T4 M6 v2 run, dust devil calm). The player
model, loose-ball rates and save chances are Table 03's simulator's (tools/cth_simulate.py), the same top table; the
Monsoon-only guesses (dust-devil passes, loose arroyo/captive hits) are marked ASSUMPTION.

Usage: python3 mon_simulate.py <shotlab-monsoon.json> [games]
"""
import json, math, random, sys, collections
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
import cth_simulate as C

FLIPPERS = ("left", "right", "upper")
MAIN = ("left", "right")
SHOTS_FROM = {"left": ["mesaRamp", "arroyo", "standup", "lane"],
              "right": ["orbit", "arroyo", "captiveTop", "lane", "standup"],
              "upper": ["arroyo", "lane", "standup"]}
LOOSE_HITS = {"bumper": 0.6, "lane": 0.12, "standup": 0.10, "arroyo": 0.05, "orbit": 0.04, "mesaRamp": 0.03,
              "captiveTop": 0.02}
DEVIL_AIMED = 0.6         # ASSUMPTION from the lab: ~60% of left/right flips cross the dust devil
DEVIL_LOOSE = 0.5         # ASSUMPTION: a loose possession crosses it about every other time
CONTROL_BONUS = {"mesaRamp": 0.25, "arroyo": 0.25}     # the wires return to an inlane
UPPER_FEED = 0.7
SAVE_CHANCE = 0.35
BALL_SAVE = 10
BALLS_PER_GAME = 3
MAX_GAME_SECONDS = 1500
RULES = dict(need=dict(sky=5, mesas=3, saguaros=5, arroyo=6, desert=6), monsoon_at=3, monsoon_again=2,
             monsoon_save=10, wildflowers=4, superbloom_save=25)
SHOT_REGION = {"orbit": "sky", "mesaRamp": "mesas", "standup": "saguaros", "captiveTop": "saguaros", "arroyo": "arroyo"}
MILESTONES = ["first region", "Monsoon lit", "Monsoon started", "all 5 painted", "all wildflowers",
              "Superbloom started", "painting finished"]


def tables_for(results, hz):
    saved = C.SHOTS_FROM, C.FLIPPERS
    C.SHOTS_FROM, C.FLIPPERS = SHOTS_FROM, FLIPPERS
    try:
        return C.aimed_tables(results, hz)
    finally:
        C.SHOTS_FROM, C.FLIPPERS = saved


class Player(C.Player):
    def shoot(self, tables, goals, on):
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


class MonsoonRules:
    def __init__(self, rng):
        self.rng = rng
        self.reached, self.first_region_at = set(), None
        self.units = collections.Counter(); self.painted = set()
        self.lanes, self.standups, self.bumpers = set(), set(), 0
        self.monsoon_lit = self.monsoon_on = self.super_lit = self.super_on = False
        self.monsoon_next, self.wildflowers, self.cycle = RULES['monsoon_at'], 0, 1
        self.kickback = self.outlane_save = False
        self.extra, self.save_until, self.time = 0, 0.0, 0.0
        self.balls_left = BALLS_PER_GAME
        self.monsoon_tries = 0

    def mark(self, m): self.reached.add(m)

    def goals(self):
        if self.super_lit or (self.monsoon_lit and not self.monsoon_on): return ["arroyo"]
        if self.monsoon_on: return ["mesaRamp"]
        if self.super_on: return ["mesaRamp", "orbit", "arroyo", "standup", "captiveTop"]
        g = [s for s, r in SHOT_REGION.items() if r not in self.painted]
        if "sky" not in self.painted: g.append("lane")
        return g or ["arroyo"]

    def wash(self, region, units):
        if region in self.painted: return
        self.units[region] += units
        if self.units[region] < RULES['need'][region] - 1e-9: return
        self.painted.add(region); self.outlane_save = True
        if self.first_region_at is None: self.first_region_at = self.time; self.mark("first region")
        n = len(self.painted)
        if n == 5: self.mark("all 5 painted")
        if self.check_super(): return
        if n >= self.monsoon_next and not self.monsoon_lit and not self.monsoon_on and \
                (n < 5 or self.wildflowers < RULES['wildflowers']):
            self.monsoon_lit = True; self.mark("Monsoon lit")

    def check_super(self):
        if self.super_lit or self.super_on or self.monsoon_on or len(self.painted) < 5 or \
                self.wildflowers < RULES['wildflowers']: return False
        self.super_lit, self.monsoon_lit = True, False
        return True

    def hit(self, what, n=1):
        for _ in range(n): self._hit(what)

    def _hit(self, what):
        if what == "bumper":
            self.bumpers += 1
            self.wash("sky", 0.03)                     # M11 v2: a touch of sky per storm-cloud bumper hit
            if self.bumpers % 10 == 0: self.wash("desert", 1)
        elif what == "devil": self.wash("desert", 0.25)
        elif what == "lane":
            k = self.rng.randrange(3)                  # M11 v2: a quarter wash per lane lit, a quarter more for all three
            if k not in self.lanes: self.wash("sky", 0.25)
            self.lanes.add(k)
            if len(self.lanes) == 3: self.lanes = set(); self.wash("sky", 0.25)
        elif what == "orbit": self.wash("sky", 1)
        elif what == "mesaRamp":
            if self.monsoon_on:
                self.wildflowers += 1
                if self.wildflowers >= RULES['wildflowers']: self.mark("all wildflowers")
            self.wash("mesas", 1); self.wash("arroyo", 0.5)
        elif what == "standup":
            k = self.rng.randrange(3)
            if k not in self.standups:
                self.standups.add(k); self.wash("saguaros", 0.5)
                if len(self.standups) == 3:
                    self.standups = set(); self.kickback = True; self.wash("saguaros", 1)
        elif what == "captiveTop": self.wash("saguaros", 1)
        elif what == "arroyo":
            self.wash("arroyo", 1)
            if not self.monsoon_on and not self.super_on:
                if self.super_lit:
                    self.super_lit, self.super_on = False, True; self.mark("Superbloom started")
                    self.extra = 2; self.save_until = self.time + RULES['superbloom_save']
                elif self.monsoon_lit:
                    self.monsoon_lit, self.monsoon_on = False, True; self.mark("Monsoon started")
                    self.monsoon_tries += 1
                    self.monsoon_next = len(self.painted) + RULES['monsoon_again']
                    self.extra = 1; self.save_until = self.time + RULES['monsoon_save']
            self.wash("arroyo", 0.5)                              # the ride on the low wire

    def multiball_ended(self):
        if self.monsoon_on:
            self.monsoon_on = False
            n = len(self.painted)
            if n == 5:
                if self.wildflowers < RULES['wildflowers']: self.monsoon_lit = True
            elif n >= self.monsoon_next: self.monsoon_lit = True
            self.check_super()
        elif self.super_on:
            self.super_on = False; self.mark("painting finished")
            self.cycle += 1; self.units = collections.Counter(); self.painted = set()
            self.wildflowers, self.monsoon_next, self.monsoon_lit = 0, RULES['monsoon_at'], False


def play_game(player, tables, rng):
    g = MonsoonRules(rng)
    s = player.s
    while g.balls_left > 0 and g.time < MAX_GAME_SECONDS:
        g.balls_left -= 1
        if rng.random() < C.PLUNGE_NEW_LANE[player.skill]: g.hit("lane")
        save_until = g.time + BALL_SAVE
        bonus, on = 0.0, None
        while True:
            multi = g.extra > 0
            caught = rng.random() < min(1.0, s["control"] * (0.7 if multi else 1) + bonus)
            bonus, drained, outcome = 0.0, False, "loose"
            if caught:
                flipper = on or rng.choice(MAIN)
                goals = g.goals()
                if flipper == "upper" and not any(("upper", t, player.skill) in tables for t in goals):
                    flipper = rng.choice(MAIN)
                outcome = player.shoot(tables, goals, flipper)
                if flipper in MAIN and rng.random() < DEVIL_AIMED: g.hit("devil")
            on = None
            if outcome == "loose" or not caught:
                for what, lam in LOOSE_HITS.items(): g.hit(what, C.poisson(rng, lam * (1.5 if multi else 1)))
                if rng.random() < DEVIL_LOOSE: g.hit("devil")
                drained = rng.random() < s["loose_drain"]
            elif outcome == "drain": drained = True
            elif outcome != "none":
                g.hit(outcome)
                bonus = CONTROL_BONUS.get(outcome, 0)
                if outcome == "orbit" and rng.random() < UPPER_FEED: on = "upper"
            g.time += C.POSSESSION_SECONDS
            for _ in range(g.extra):
                for what, lam in LOOSE_HITS.items(): g.hit(what, C.poisson(rng, lam))
                if rng.random() < DEVIL_LOOSE: g.hit("devil")
                if rng.random() < s["loose_drain"] and g.time >= g.save_until: g.extra -= 1
            if g.extra == 0 and (g.monsoon_on or g.super_on): g.multiball_ended()
            if g.time >= MAX_GAME_SECONDS: break
            if not drained: continue
            if g.extra > 0:
                if g.time >= g.save_until:
                    g.extra -= 1
                    if g.extra == 0: g.multiball_ended()
                continue
            if g.time < save_until: save_until = 0; continue
            if g.kickback and rng.random() < SAVE_CHANCE: g.kickback = False; continue
            if g.outlane_save and rng.random() < SAVE_CHANCE: g.outlane_save = False; continue
            break
    return g


def run(results, hz, games, seed=1, **kw):
    t = tables_for(results, hz)
    rep = {}
    for skill in C.SKILLS:
        rng = random.Random(seed)
        pl = Player(skill, t, t, rng, **kw)
        counts, times, firsts, regions = collections.Counter(), [], [], []
        for _ in range(games):
            g = play_game(pl, t, rng)
            counts.update(g.reached); times.append(g.time); regions.append(len(g.painted) + 5 * (g.cycle - 1))
            if g.first_region_at is not None: firsts.append(g.first_region_at)
        times.sort(); firsts.sort(); regions.sort()
        rep[skill] = dict(milestones={m: counts[m] / games for m in MILESTONES},
                          game=times[len(times) // 2] / 60,
                          first=(firsts[len(firsts) // 2] / 60) if firsts else float('nan'),
                          regions=regions[len(regions) // 2])
    return rep


def show(rep, title):
    print(f"\n=== {title}")
    print(f"  {'':24s}" + "".join(f"{s:>10s}" for s in C.SKILLS))
    for m in MILESTONES:
        print(f"  {m:24s}" + "".join(f"{rep[s]['milestones'][m]*100:9.0f}%" for s in C.SKILLS))
    print(f"  {'median game (min)':24s}" + "".join(f"{rep[s]['game']:10.1f}" for s in C.SKILLS))
    print(f"  {'first region at (min)':24s}" + "".join(f"{rep[s]['first']:10.1f}" for s in C.SKILLS))
    print(f"  {'median regions painted':24s}" + "".join(f"{rep[s]['regions']:10d}" for s in C.SKILLS))


if __name__ == "__main__":
    res = json.load(open(sys.argv[1]))
    games = int(sys.argv[2]) if len(sys.argv) > 2 else 5000
    for hz in (120, 60):
        show(run(res, hz, games), f"{hz} Hz phone — share of games reaching each step ({games} per skill)")
