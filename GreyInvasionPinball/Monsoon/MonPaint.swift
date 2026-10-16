// Pinball Lab Table 04 (Monsoon), milestone 2 (look development): color as progress.
// Every piece of table art comes in two versions, a pencil sketch and the watercolor, plus a small region map
// (which part of the painting each pixel belongs to, and a noise value for the ragged watercolor edge). One shader
// per art sprite shows the sketch, and shows the watercolor wherever a wash has reached: each wash is a "drop" of
// color that blooms outward inside its own region, with a slightly darker rim where the wash stops, like wet paint.
// A region can also be filled all over (its base fill), for a finished goal. The rules only call addWash / fill;
// this class owns the numbers and the shader.
//
// Milestone 8 round 1 (Aaron: "make sure it doesn't always paint the table the same way each time… where it starts…
// start in multiple spots at times, have it grow, have it grow towards other spots"):
// - Each drop is a stroke from A toward B (a circle when B = A). B travels out from A over a second or more, so a
//   wash can creep across the table; it only ever grows, so nothing that was painted turns back to pencil.
// - Each wash picks a style at random: a bloom where the shot was, a brush streak, a creep toward a random spot or
//   toward an earlier patch (so patches join up), a scatter of two or three small patches, or a bloom somewhere else
//   in the region. Random spots come from the region map itself, so they're always inside the region.
// - Every game also gets its own noise: the ragged edges and the order a fill reveals the region are different.
import SpriteKit
import UIKit
import Foundation
import simd

/// The painted regions. A region map stores the index in three bits (red = 1, green = 2, blue = 4; each 0 or 255, so
/// colour management and texture formats can't change it) and the edge noise in alpha (0.2…1, never 0, so the
/// premultiplied colour bits survive).
enum MonRegion: Int, CaseIterable {
    case sky = 0, mesas, saguaros, arroyo, desert, frame
}

/// How a wash lays its color (picked at random for each wash).
enum MonWashStyle: String {
    case bloom, streak, creep, join, scatter, elsewhere
}

@MainActor
final class MonPaint {
    /// A wash spreading as a stroke from `a` toward `bTarget` (its far end `b` travels out over time): its region,
    /// how far it has spread (0…), how far it's going, and its width (1 = round, less = a narrower stroke).
    private struct Drop {
        var a: CGPoint
        var b: CGPoint
        var bTarget: CGPoint
        var width: CGFloat
        var region: MonRegion
        var strength: CGFloat
        var target: CGFloat
        /// M9 v4: the area (pt²) this drop is meant to color; its target strength is worked out from it.
        var area: CGFloat
    }

    /// A region map kept on the CPU, to pick random spots inside a region.
    private struct RegionMap {
        let rect: CGRect
        let width: Int
        let height: Int
        let index: [UInt8]                  // region index per pixel, top row first
        let alpha: [UInt8]                  // the noise (alpha channel), top row first
    }

    static let maxDrops = 8
    /// How far (points) a wash of strength 1 spreads, roughly: the noise makes the edge ragged.
    static let reach: CGFloat = 210
    /// A new wash this close to an old one in the same region adds to it instead of starting a new drop (v1: 120).
    static let mergeDistance: CGFloat = 50
    /// How quickly a wash spreads toward its target (per second; it eases out over ~1.5 s).
    static let spreadRate: CGFloat = 2.2
    /// How fast a stroke's far end creeps out (points per second).
    static let creepSpeed: CGFloat = 90

    private var drops: [Drop] = []
    private var fill = [CGFloat](repeating: 0, count: MonRegion.allCases.count)
    private var fillTarget = [CGFloat](repeating: 0, count: MonRegion.allCases.count)
    private var shaders: [SKShader] = []
    private var maps: [RegionMap] = []
    /// Each region's area on the attached art (pt²), counted from the region maps.
    private var regionArea = [CGFloat](repeating: 0, count: MonRegion.allCases.count)
    /// This game's noise: an offset into the region map's noise and a mirror in x and y.
    private var seed = vector_float4(0, 0, 1, 1)
    private var dirty = true

    // M10 v2 (Aaron: one orbit "painted the entire sky"): the CPU keeps a coarse copy of the picture so every wash colors
    // NEW paper. Washes laid near the same shot (the orbit and the lanes are both at the top) used to pile up on one
    // spot: three sky washes showed only ~17% of the sky, so the fourth one (which fills the region) looked like it
    // painted the whole sky at once. Samples every `sampleStep` map pixels: position, region, map uv, noise.
    static let sampleStep = 8
    private var sampleX: [Float] = []
    private var sampleY: [Float] = []
    private var sampleRegion: [UInt8] = []
    private var sampleMap: [Int] = []
    private var sampleU: [Float] = []
    private var sampleV: [Float] = []
    private var sampleNoise: [Float] = []
    /// The samples of each region (indices into the arrays above).
    private var regionSamples = [[Int]](repeating: [], count: MonRegion.allCases.count)

    init() {
        newSeed()
    }

    /// Gives `sprite` (covering world `rect`) the sketch/color shader, if its sketch and region images are in the
    /// app. The sprite's own texture must be the color version. Returns false (and leaves it alone) if not.
    @discardableResult
    func attach(_ sprite: SKSpriteNode, rect: CGRect, sketch: String, regions: String) -> Bool {
        guard UIImage(named: sketch) != nil, let regionImage = UIImage(named: regions) else { return false }
        let regionTexture = SKTexture(imageNamed: regions)
        let shader = SKShader(source: Self.source)
        var uniforms = [
            SKUniform(name: "u_sketch", texture: SKTexture(imageNamed: sketch)),
            SKUniform(name: "u_regions", texture: regionTexture),
            SKUniform(name: "u_rect", vectorFloat4: vector_float4(Float(rect.minX), Float(rect.minY),
                                                                Float(rect.width), Float(rect.height))),
            SKUniform(name: "u_reach", float: Float(Self.reach)),
            SKUniform(name: "u_fillA", vectorFloat4: vector_float4(0, 0, 0, 0)),
            SKUniform(name: "u_fillB", vectorFloat4: vector_float4(0, 0, 0, 0)),
            SKUniform(name: "u_seed", vectorFloat4: seed),
        ]
        for i in 0..<Self.maxDrops {
            uniforms.append(SKUniform(name: "u_d\(i)", vectorFloat4: vector_float4(0, 0, 0, 0)))
            uniforms.append(SKUniform(name: "u_e\(i)", vectorFloat4: vector_float4(0, 0, 1, 0)))
        }
        shader.uniforms = uniforms
        sprite.shader = shader
        shaders.append(shader)
        if let map = Self.readMap(regionImage, rect: rect) {
            maps.append(map)
            let ptPerPx = (rect.width / CGFloat(map.width)) * (rect.height / CGFloat(map.height))
            for v in map.index where Int(v) < regionArea.count { regionArea[Int(v)] += ptPerPx }
            addSamples(map, mapIndex: maps.count - 1)
        }
        dirty = true
        return true
    }

    /// Adds color to `region` near `point` (world, where the goal was made). M9 v4: `amount` is the share of the
    /// region's area this wash should color (0.15 = 15%), so a big region (the sky) and a small one (the arroyo) fill at
    /// the same pace. The style is picked at random (returned, for the debug banner).
    @discardableResult
    func addWash(at point: CGPoint, region: MonRegion, amount: CGFloat) -> MonWashStyle {
        let free = Self.maxDrops - drops.count
        var style: MonWashStyle
        let roll = CGFloat.random(in: 0..<1)
        switch roll {
        case ..<0.28: style = .bloom
        case ..<0.46: style = .streak
        case ..<0.62: style = .creep
        case ..<0.76: style = .join
        case ..<0.90: style = .scatter
        default: style = .elsewhere
        }
        if style == .join, !drops.contains(where: { $0.region == region }) { style = .creep }
        if style == .scatter, free < 3 { style = .bloom }
        if (style == .scatter || style == .elsewhere || style == .creep), randomPoint(in: region) == nil {
            style = style == .creep ? .streak : .bloom     // no map of this region yet (the upper table's art is M9)
        }

        var near = CGPoint(x: point.x + .random(in: -25...25), y: point.y + .random(in: -25...25))
        // M9 v1: a shot far from its region (the orbit is in the sky, the saguaros' standups aren't on a cactus) starts
        // its wash at the nearest part of that region instead, so it's always seen.
        if let r = regionAt(near), r != region, let closest = nearestPoint(in: region, to: near) { near = closest }
        near = freshStart(region, near: near)                  // M10 v2: start on paper, next to the color already there
        switch style {
        case .bloom:
            lay(region, from: near, to: near, width: .random(in: 0.85...1.2), amount: amount)
        case .streak:
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let length = CGFloat.random(in: 60...140)
            let end = CGPoint(x: near.x + length * cos(angle), y: near.y + length * sin(angle))
            lay(region, from: near, to: end, width: .random(in: 0.55...0.8), amount: amount * 0.85)
        case .creep:
            let goal = freshRandomPoint(in: region) ?? near
            lay(region, from: near, to: clipped(goal, from: near, max: 240), width: .random(in: 0.6...0.85), amount: amount * 0.85)
        case .join:
            let others = drops.filter { $0.region == region }
            let other = others.min(by: { hypot($0.a.x - near.x, $0.a.y - near.y) > hypot($1.a.x - near.x, $1.a.y - near.y) })!
            // toward the farthest earlier patch's middle, so two patches link up
            let mid = CGPoint(x: (other.a.x + other.b.x) / 2, y: (other.a.y + other.b.y) / 2)
            lay(region, from: near, to: clipped(mid, from: near, max: 300), width: .random(in: 0.6...0.8), amount: amount * 0.85)
        case .scatter:
            let count = Int.random(in: 2...3)
            for _ in 0..<count {
                let p = freshRandomPoint(in: region) ?? near
                lay(region, from: p, to: p, width: .random(in: 0.8...1.1), amount: amount / CGFloat(count) * 1.2)
            }
        case .elsewhere:
            let p = freshRandomPoint(in: region) ?? near
            lay(region, from: p, to: p, width: .random(in: 0.85...1.2), amount: amount)
        }
        dirty = true
        return style
    }

    /// One stroke of color. Close to an existing round patch of the region it adds to that one instead; with no
    /// free drop left, the nearest patch of the region grows (or the nearest patch of all, if the region has none).
    private func lay(_ region: MonRegion, from a: CGPoint, to b: CGPoint, width: CGFloat, amount: CGFloat) {
        let known = regionArea[region.rawValue]
        let add = amount * (known > 0 ? known : 40_000)
        let before = coverage(region)
        func grow(_ i: Int) {
            drops[i].area += add
            drops[i].target = Self.strength(area: drops[i].area, width: drops[i].width,
                                            length: hypot(drops[i].bTarget.x - drops[i].a.x, drops[i].bTarget.y - drops[i].a.y))
            tune(i, toCover: before + amount)
        }
        if let i = drops.firstIndex(where: {
            $0.region == region && $0.a == $0.bTarget && a == b && hypot($0.a.x - a.x, $0.a.y - a.y) < Self.mergeDistance
        }) {
            grow(i)
        } else if drops.count < Self.maxDrops {
            let s = Self.strength(area: add, width: width, length: hypot(b.x - a.x, b.y - a.y))
            drops.append(Drop(a: a, b: a, bTarget: b, width: width, region: region, strength: 0, target: s, area: add))
            tune(drops.count - 1, toCover: before + amount)
        } else if let i = drops.indices.min(by: { dist(drops[$0], a, region) < dist(drops[$1], a, region) }) {
            grow(i)
        }
    }

    /// M11 v2 (Aaron: "the sky still seems to fill in a big chunk instead of a little at a time"): a small touch of
    /// color (a bumper hit adds a little sky). It grows the region's nearest patch outward by `amount` of the region
    /// (no new drop, so tiny touches never use up the drops); with no patch yet it starts one, if drops are free.
    func addTouch(at point: CGPoint, region: MonRegion, amount: CGFloat) {
        let before = coverage(region)
        let mine = drops.indices.filter { drops[$0].region == region }
        if let i = mine.min(by: { hypot(drops[$0].a.x - point.x, drops[$0].a.y - point.y)
                                    < hypot(drops[$1].a.x - point.x, drops[$1].a.y - point.y) }) {
            let known = regionArea[region.rawValue]
            drops[i].area += amount * (known > 0 ? known : 40_000)
            tune(i, toCover: before + amount)
            dirty = true
        } else if Self.maxDrops - drops.count >= 2 {
            let start = freshStart(region, near: nearestPoint(in: region, to: point) ?? point)
            lay(region, from: start, to: start, width: .random(in: 0.85...1.1), amount: amount)
            dirty = true
        }
    }

    // MARK: The CPU copy of the picture (M10 v2)

    private func addSamples(_ m: RegionMap, mapIndex: Int) {
        let step = Self.sampleStep
        for y in stride(from: step / 2, to: m.height, by: step) {
            for x in stride(from: step / 2, to: m.width, by: step) {
                let r = m.index[y * m.width + x]
                guard Int(r) < MonRegion.frame.rawValue else { continue }       // washes never color the frame
                let u = (Float(x) + 0.5) / Float(m.width), v = 1 - (Float(y) + 0.5) / Float(m.height)
                sampleX.append(Float(m.rect.minX) + u * Float(m.rect.width))
                sampleY.append(Float(m.rect.minY) + v * Float(m.rect.height))
                regionSamples[Int(r)].append(sampleX.count - 1)
                sampleRegion.append(r)
                sampleMap.append(mapIndex)
                sampleU.append(u)
                sampleV.append(v)
                sampleNoise.append(0)
            }
        }
        refreshSampleNoise()
    }

    /// The shader's noise at every sample for this game's seed (offset + mirror, mirrored repeat).
    private func refreshSampleNoise() {
        for i in sampleNoise.indices {
            let m = maps[sampleMap[i]]
            var qx = 0.5 + (sampleU[i] - 0.5) * seed.z + seed.x
            var qy = 0.5 + (sampleV[i] - 0.5) * seed.w + seed.y
            qx = 1 - abs(1 - qx.truncatingRemainder(dividingBy: 2).magnitudeMod2)
            qy = 1 - abs(1 - qy.truncatingRemainder(dividingBy: 2).magnitudeMod2)
            let px = min(m.width - 1, max(0, Int(qx * Float(m.width))))
            let py = min(m.height - 1, max(0, Int((1 - qy) * Float(m.height))))
            sampleNoise[i] = min(1, max(0, (Float(m.alpha[py * m.width + px]) / 255 - 0.2) / 0.8))
        }
    }

    /// The shader's threshold for one drop at one sample (its final shape: target strength, far end at bTarget).
    private func dropT(_ d: Drop, strength: CGFloat, sample i: Int) -> Float {
        let ax = Float(d.a.x), ay = Float(d.a.y)
        let abx = Float(d.bTarget.x) - ax, aby = Float(d.bTarget.y) - ay
        let px = sampleX[i] - ax, py = sampleY[i] - ay
        let k = min(1, max(0, (px * abx + py * aby) / max(abx * abx + aby * aby, 0.0001)))
        let dd = hypot(px - abx * k, py - aby * k)
        return dd / (Float(Self.reach) * Float(d.width)) * 0.75 + sampleNoise[i] * 0.55 - Float(strength) * 1.35
    }

    /// For each sample of `region` (regionSamples order): does it show color once every wash has spread (base fill +
    /// drops)? Drop `skip` is left out.
    private func coveredSamples(_ region: MonRegion, skipping skip: Int? = nil) -> [Bool] {
        let f = Float(fillTarget[region.rawValue])
        let mine = drops.indices.filter { drops[$0].region == region && $0 != skip }
        return regionSamples[region.rawValue].map { i in
            var t: Float = f > 0 ? sampleNoise[i] * 0.55 + 0.5 - f * 1.1 : 9
            for j in mine where t >= 0 { t = min(t, dropT(drops[j], strength: drops[j].target, sample: i)) }
            return t < 0
        }
    }

    /// The share of `region` that shows color once the washes laid so far have spread (0…1).
    private func coverage(_ region: MonRegion) -> CGFloat {
        let c = coveredSamples(region)
        guard !c.isEmpty else { return 0 }
        return CGFloat(c.filter { $0 }.count) / CGFloat(c.count)
    }

    /// Sets drop `i`'s strength so its region's colored share reaches `goal` (never weaker than it already is, at most
    /// 0.8). Each paper sample needs a strength of at least (threshold without strength) / 1.35 to turn color, so the
    /// answer is the right one of those, sorted. Keeps the area estimate when the region has no map.
    private func tune(_ i: Int, toCover goal: CGFloat) {
        let region = drops[i].region
        let others = coveredSamples(region, skipping: i)
        guard !others.isEmpty else { return }
        let ids = regionSamples[region.rawValue]
        let drop = drops[i]
        let done = others.filter { $0 }.count
        let need = Int((min(0.97, goal) * CGFloat(others.count)).rounded(.up)) - done
        guard need > 0 else { return }
        var needs: [Float] = []
        for k in ids.indices where !others[k] {
            let s = (dropT(drop, strength: 0, sample: ids[k])) / 1.35
            if s < 0.8 { needs.append(s) }
        }
        needs.sort()
        let s = needs.count >= need ? CGFloat(needs[need - 1]) + 0.002 : 0.8
        drops[i].target = max(drops[i].strength, min(0.8, s))
    }

    /// Where a wash should start: `p` if that spot is still paper, else the closest spot of `region` that is
    /// (so a region's color grows outward instead of piling up on one spot).
    private func freshStart(_ region: MonRegion, near p: CGPoint) -> CGPoint {
        let covered = coveredSamples(region)
        guard !covered.isEmpty else { return p }
        let ids = regionSamples[region.rawValue]
        var best: Int?
        var bestD = Float.infinity
        var nearestDone = false
        var nearestD = Float.infinity
        for k in ids.indices {
            let i = ids[k]
            let d = hypot(sampleX[i] - Float(p.x), sampleY[i] - Float(p.y))
            if d < nearestD { nearestD = d; nearestDone = covered[k] }
            if !covered[k], d < bestD { bestD = d; best = i }
        }
        if !nearestDone, nearestD < Float(Self.sampleStep * 2) { return p }    // already paper
        guard let b = best else { return p }
        return CGPoint(x: CGFloat(sampleX[b]), y: CGFloat(sampleY[b]))
    }

    /// A random spot of `region` that is still paper (any spot of it if it's all colored; nil if no map has it).
    private func freshRandomPoint(in region: MonRegion) -> CGPoint? {
        let covered = coveredSamples(region)
        let ids = regionSamples[region.rawValue]
        let fresh = ids.indices.filter { !covered[$0] }
        guard let k = fresh.randomElement() else { return randomPoint(in: region) }
        let i = ids[k]
        return CGPoint(x: CGFloat(sampleX[i]), y: CGFloat(sampleY[i]))
    }

    /// The strength that colors about `area` pt² (every region together) with a stroke of this width and length: the
    /// shader colors out to dist ≈ reach × width × (1.8 × strength − 0.37) on average noise (checked in numpy against
    /// the real noise: within ~10%). Capped at 0.8 so no single drop floods the table.
    private static func strength(area: CGFloat, width: CGFloat, length: CGFloat) -> CGFloat {
        // area of a stroke of radius r and length L: 2 r L + π r²  →  r
        let r = (-2 * length + sqrt(4 * length * length + 4 * .pi * area)) / (2 * .pi)
        return min(0.8, (r / (reach * width) + 0.367) / 1.8)
    }

    private func clipped(_ p: CGPoint, from a: CGPoint, max length: CGFloat) -> CGPoint {
        let d = hypot(p.x - a.x, p.y - a.y)
        guard d > length else { return p }
        return CGPoint(x: a.x + (p.x - a.x) * length / d, y: a.y + (p.y - a.y) * length / d)
    }

    /// Fills a whole region toward `level` (0…1), e.g. 1 when its goal is finished.
    func fill(_ region: MonRegion, to level: CGFloat) {
        fillTarget[region.rawValue] = max(0, min(1, level))
        dirty = true
    }

    /// Roughly how far a region is painted, 0…1, from the washes asked for so far (its fill, plus its washes'
    /// strengths over 3: a region takes three to five washes). For the region lamps.
    func progress(_ region: MonRegion) -> CGFloat {
        let washes = drops.filter { $0.region == region }.reduce(0) { $0 + $1.target }
        return min(1, max(fillTarget[region.rawValue], washes / 3))
    }

    /// Back to the sketch (a new game), with new noise.
    func reset() {
        drops.removeAll()
        fill = fill.map { _ in 0 }
        fillTarget = fillTarget.map { _ in 0 }
        newSeed()
        dirty = true
    }

    private func newSeed() {
        seed = vector_float4(Float.random(in: 0..<2), Float.random(in: 0..<2),
                             Bool.random() ? 1 : -1, Bool.random() ? 1 : -1)
        refreshSampleNoise()
        for shader in shaders { shader.uniformNamed("u_seed")?.vectorFloat4Value = seed }
    }

    /// Every frame: washes spread toward their targets and strokes creep out; the shaders get new numbers only when
    /// something moved. A region filled all the way no longer needs its drops, which frees them for other regions.
    func step(dt: CGFloat) {
        let a = min(1, dt * Self.spreadRate)
        for i in drops.indices {
            if abs(drops[i].target - drops[i].strength) > 0.0005 {
                drops[i].strength += (drops[i].target - drops[i].strength) * a
                dirty = true
            }
            let d = drops[i]
            let left = hypot(d.bTarget.x - d.b.x, d.bTarget.y - d.b.y)
            if left > 0.01 {
                let move = min(left, Self.creepSpeed * dt)
                drops[i].b = CGPoint(x: d.b.x + (d.bTarget.x - d.b.x) * move / left,
                                     y: d.b.y + (d.bTarget.y - d.b.y) * move / left)
                dirty = true
            }
        }
        for r in fill.indices where abs(fillTarget[r] - fill[r]) > 0.0005 {
            fill[r] += (fillTarget[r] - fill[r]) * a * 0.6
            dirty = true
        }
        let before = drops.count
        drops.removeAll(where: { fill[$0.region.rawValue] > 0.999 })
        if drops.count != before { dirty = true }
        guard dirty else { return }
        dirty = false
        let fa = vector_float4(Float(fill[0]), Float(fill[1]), Float(fill[2]), Float(fill[3]))
        let fb = vector_float4(Float(fill[4]), Float(fill[5]), 0, 0)
        for shader in shaders {
            shader.uniformNamed("u_fillA")?.vectorFloat4Value = fa
            shader.uniformNamed("u_fillB")?.vectorFloat4Value = fb
            for i in 0..<Self.maxDrops {
                var v = vector_float4(0, 0, 0, 0)
                var e = vector_float4(0, 0, 1, 0)
                if i < drops.count {
                    let d = drops[i]
                    v = vector_float4(Float(d.a.x), Float(d.a.y), Float(d.strength), Float(d.region.rawValue))
                    e = vector_float4(Float(d.b.x), Float(d.b.y), Float(d.width), 0)
                }
                shader.uniformNamed("u_d\(i)")?.vectorFloat4Value = v
                shader.uniformNamed("u_e\(i)")?.vectorFloat4Value = e
            }
        }
    }

    private func dist(_ d: Drop, _ p: CGPoint, _ region: MonRegion) -> CGFloat {
        (d.region == region ? 0 : 100_000) + hypot(d.a.x - p.x, d.a.y - p.y)
    }

    // MARK: Random spots

    /// The region under a world point, or nil off every map.
    func regionAt(_ p: CGPoint) -> MonRegion? {
        for m in maps where m.rect.contains(p) {
            let x = min(m.width - 1, max(0, Int((p.x - m.rect.minX) / m.rect.width * CGFloat(m.width))))
            let y = min(m.height - 1, max(0, Int((m.rect.maxY - p.y) / m.rect.height * CGFloat(m.height))))
            return MonRegion(rawValue: Int(m.index[y * m.width + x]))
        }
        return nil
    }

    /// The closest of a few dozen random points of `region` to `p` (nil if no map has it).
    func nearestPoint(in region: MonRegion, to p: CGPoint) -> CGPoint? {
        var best: CGPoint?
        var bestD = CGFloat.infinity
        for _ in 0..<40 {
            guard let q = randomPoint(in: region) else { break }
            let d = hypot(q.x - p.x, q.y - p.y)
            if d < bestD { bestD = d; best = q }
        }
        return best
    }

    /// A random point of the sky (for the lightning), or nil without the upper art.
    func randomSkyPoint() -> CGPoint? { randomPoint(in: .sky) }

    /// A random point inside `region` on any attached art, or nil if no map has that region.
    func randomPoint(in region: MonRegion) -> CGPoint? {
        guard !maps.isEmpty else { return nil }
        let want = UInt8(region.rawValue)
        for _ in 0..<80 {
            let m = maps[Int.random(in: 0..<maps.count)]
            let x = Int.random(in: 0..<m.width), y = Int.random(in: 0..<m.height)
            guard m.index[y * m.width + x] == want else { continue }
            return CGPoint(x: m.rect.minX + (CGFloat(x) + 0.5) / CGFloat(m.width) * m.rect.width,
                           y: m.rect.maxY - (CGFloat(y) + 0.5) / CGFloat(m.height) * m.rect.height)
        }
        return nil
    }

    /// Reads a region map's indices (premultiplied RGBA: a bit is set where the colour is over half the alpha).
    private static func readMap(_ image: UIImage, rect: CGRect) -> RegionMap? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let ok = bytes.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        var index = [UInt8](repeating: 255, count: w * h)
        for i in 0..<(w * h) {
            let a = Int(bytes[i * 4 + 3])
            guard a > 0 else { continue }
            let r = Int(bytes[i * 4]) * 2 > a ? 1 : 0
            let g = Int(bytes[i * 4 + 1]) * 2 > a ? 2 : 0
            let b = Int(bytes[i * 4 + 2]) * 2 > a ? 4 : 0
            index[i] = UInt8(r + g + b)
        }
        var alpha = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) { alpha[i] = bytes[i * 4 + 3] }
        return RegionMap(rect: rect, width: w, height: h, index: index, alpha: alpha)
    }

    /// The fragment shader (M9 v2: helper functions take everything as parameters; SpriteKit's Metal translation
    /// can't see uniforms from inside them — "Compiler failed to build request" — so the shader never ran before and
    /// the color art showed from the start). Region map: the index in the colour bits, the noise in alpha (read at this game's offset
    /// and mirror, so the ragged edges differ every game). A pixel shows the color where any wash's threshold t < 0:
    /// t = distance to the stroke / (reach × width) × 0.75 + noise × 0.55 − strength × 1.35 (other regions and empty
    /// drops add a large number). A region's base fill uses no distance. The rim darkens near t = 0.
    private static let source = """
    float regionWeight(float ri, float region) {
        return clamp(1.0 - abs(ri - region) * 2.0, 0.0, 1.0);
    }
    float dropT(vec4 d, vec4 e, vec2 p, float ri, float n, float reach) {
        if (d.z <= 0.0) { return 9.0; }
        vec2 ab = e.xy - d.xy;
        float k = clamp(dot(p - d.xy, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
        float dd = length(p - d.xy - ab * k);
        return dd / (reach * e.z) * 0.75 + n * 0.55 - d.z * 1.35 + (1.0 - regionWeight(ri, d.w)) * 4.0;
    }
    void main() {
        vec2 uv = v_tex_coord;
        vec4 col = texture2D(u_texture, uv);
        vec4 sk = texture2D(u_sketch, uv);
        vec4 reg = texture2D(u_regions, uv);
        float ra = max(reg.a, 0.01);
        float ri = step(0.5, reg.r / ra) + 2.0 * step(0.5, reg.g / ra) + 4.0 * step(0.5, reg.b / ra);
        float reach = u_reach;
        vec2 q = vec2(0.5) + (uv - vec2(0.5)) * u_seed.zw + u_seed.xy;
        q = vec2(1.0) - abs(vec2(1.0) - mod(q, 2.0));          // mirrored repeat: no seams
        float n = clamp((texture2D(u_regions, q).a - 0.2) / 0.8, 0.0, 1.0);
        vec2 p = u_rect.xy + uv * u_rect.zw;
        float f = u_fillA.x * regionWeight(ri, 0.0) + u_fillA.y * regionWeight(ri, 1.0)
                + u_fillA.z * regionWeight(ri, 2.0) + u_fillA.w * regionWeight(ri, 3.0)
                + u_fillB.x * regionWeight(ri, 4.0) + u_fillB.y * regionWeight(ri, 5.0);
        float t = (f > 0.0) ? (n * 0.55 + 0.5 - f * 1.1) : 9.0;
        t = min(t, dropT(u_d0, u_e0, p, ri, n, reach));
        t = min(t, dropT(u_d1, u_e1, p, ri, n, reach));
        t = min(t, dropT(u_d2, u_e2, p, ri, n, reach));
        t = min(t, dropT(u_d3, u_e3, p, ri, n, reach));
        t = min(t, dropT(u_d4, u_e4, p, ri, n, reach));
        t = min(t, dropT(u_d5, u_e5, p, ri, n, reach));
        t = min(t, dropT(u_d6, u_e6, p, ri, n, reach));
        t = min(t, dropT(u_d7, u_e7, p, ri, n, reach));
        float m = clamp(-t / 0.06, 0.0, 1.0);
        float rim = (t < 0.04) ? exp(-(t / 0.035) * (t / 0.035)) : 0.0;
        vec4 wet = vec4(col.rgb * (1.0 - 0.12 * rim), col.a);
        gl_FragColor = mix(sk, wet, m);
    }
    """
}

private extension Float {
    /// x mod 2 in 0..<2 (truncatingRemainder keeps the sign).
    var magnitudeMod2: Float { self < 0 ? self + 2 : self }
}
