import sys, json, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cth_simulate as C
d=json.load(open('shotlab-cthulhu-rising-2026-10-13T16-18-01Z.json')); u=json.load(open('shotlab-cthulhu-rising--cthulhu-up--2026-10-13T16-59-44Z.json'))
base=dict(C.RULES)
exps=[("current",{}),
 ("pages 40",{"pages":40}),
 ("pages 40, tentacles 1",{"pages":40,"tentacle_hits":1}),
 ("pages 40, tent 1, keep candles",{"pages":40,"tentacle_hits":1,"escape_keeps_candles":True}),
 ("+ clues 2",{"pages":40,"tentacle_hits":1,"escape_keeps_candles":True,"clues":2}),
 ("+ awaken save 25",{"pages":40,"tentacle_hits":1,"escape_keeps_candles":True,"clues":2,"awaken_save":25}),
 ("pages40 tent1 keep save25 (clues3)",{"pages":40,"tentacle_hits":1,"escape_keeps_candles":True,"awaken_save":25}),
]
print(f"{'':38s} beg: lib  tomeI ritual | avg: tomeI ritual awak  ban | exp ban | min avg")
for name,kw in exps:
    C.RULES.clear(); C.RULES.update(base); C.RULES.update(kw)
    r=C.run(d,u,120,1500)
    b,a,e=r['beginner']['milestones'],r['average']['milestones'],r['expert']['milestones']
    print(f"{name:38s} {b['library lit']*100:4.0f}% {b['tome I read']*100:4.0f}% {b['ritual lit']*100:4.0f}% | {a['tome I read']*100:4.0f}% {a['ritual lit']*100:4.0f}% {a['awakening']*100:4.0f}% {a['banished']*100:4.0f}% | {e['banished']*100:4.0f}% | {r['average']['medianGameMinutes']:.1f}")
