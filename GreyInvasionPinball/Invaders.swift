import SpriteKit
import CoreGraphics
import Foundation

/// The invaders you can see (milestone 8 art round 4). Purely visual: no physics, no rules.
/// Every frame `sync` matches what's shown to the campaign's state:
/// - Wave 1: a scout saucer hovers over each lit shot; when a shot goes dark it's shot down
///   (or, if the wave timed out, the scouts fly off).
/// - Wave 3: an abductor hovers over the Abduction scoop and beams a cow up; the cow rises as the
///   beam timer runs down. A save drops the cow back down; a miss whisks it up into the saucer.
/// - The Mothership descends over the top of the table for the finale; its core glows while open,
///   flashes on a core hit, explodes when destroyed and flies off if it escapes.
/// Scouts and the cow sit under the ball (z 8–9); the abductor and Mothership are "in the sky"
/// above the ramps (z 22) but below a ball on a ramp (z 30).
final class InvaderLayer: SKNode {
    private var scouts: [Shot: SKSpriteNode] = [:]
    private var scoutsEscaping = false

    private var abductor: SKSpriteNode?
    private var beam: SKSpriteNode?
    private var cow: SKSpriteNode?
    private var lastCowsSaved = 0

    private var mothership: SKSpriteNode?
    private var core: SKShapeNode?
    private var mothershipDestroyed = false

    private static let abductorAt = CGPoint(x: TableLayout.abductionCenter.x, y: TableLayout.abductionCenter.y + 128)
    private static let mothershipAt = CGPoint(x: 284, y: 1238)

    /// Where a shot's scout hovers: 46 pt past its arrow, toward the shot.
    private static func scoutPosition(for shot: Shot) -> CGPoint? {
        guard let a = TableLayout.shotArrows.first(where: { $0.name == shot.rawValue }) else { return nil }
        let r = a.degrees * .pi / 180
        return CGPoint(x: a.at.x + 46 * cos(r), y: a.at.y + 46 * sin(r))
    }

    func reset() {
        removeAllChildren()
        scouts = [:]
        scoutsEscaping = false
        abductor = nil; beam = nil; cow = nil
        lastCowsSaved = 0
        mothership = nil; core = nil
        mothershipDestroyed = false
    }

    // MARK: - Event hooks (called from the scene's event handler)

    /// Wave 1 timed out: the scouts still up fly away instead of being shot down.
    func scoutsEscape() { scoutsEscaping = true }

    /// A Mothership core hit: a white flash and a shudder.
    func mothershipHit() {
        guard let ship = mothership else { return }
        let flash = SKSpriteNode(color: .white, size: CGSize(width: 260, height: 60))
        flash.blendMode = .add
        flash.alpha = 0.8
        flash.zPosition = 1
        ship.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
        ship.run(.sequence([.moveBy(x: 6, y: 0, duration: 0.04), .moveBy(x: -12, y: 0, duration: 0.08),
                            .moveBy(x: 6, y: 0, duration: 0.04)]))
    }

    /// Third core hit: it blows up (the campaign has already moved on to the next invasion).
    func mothershipBlowsUp() {
        guard let ship = mothership else { return }
        mothershipDestroyed = true
        mothership = nil; core = nil
        ship.removeAllActions()
        let boom = SKShapeNode(circleOfRadius: 40)
        boom.fillColor = SKColor(red: 0.6, green: 1.0, blue: 0.7, alpha: 1)
        boom.strokeColor = .clear
        boom.blendMode = .add
        boom.position = ship.position
        boom.zPosition = 23
        addChild(boom)
        boom.run(.sequence([.group([.scale(to: 5, duration: 0.6), .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
        ship.run(.sequence([.group([.scale(to: 1.4, duration: 0.5), .fadeOut(withDuration: 0.5),
                                    .rotate(byAngle: 0.4, duration: 0.5)]), .removeFromParent()]))
    }

    // MARK: - Per-frame sync

    func sync(with campaign: Campaign) {
        syncScouts(campaign)
        syncAbductor(campaign)
        syncMothership(campaign)
    }

    private func syncScouts(_ campaign: Campaign) {
        let wanted: Set<Shot> = (campaign.phase == .running && campaign.wave == 1) ? campaign.litShots : []
        for shot in wanted where scouts[shot] == nil {
            guard let p = Self.scoutPosition(for: shot) else { continue }
            let s = SKSpriteNode(imageNamed: "scout")
            s.size = CGSize(width: 44, height: 26)
            s.position = CGPoint(x: p.x, y: p.y + 60)
            s.alpha = 0
            s.zPosition = 8
            addChild(s)
            s.run(.sequence([
                .group([.move(to: p, duration: 0.6), .fadeIn(withDuration: 0.6)]),
                .repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.7), .moveBy(x: 0, y: -4, duration: 0.7)])),
            ]))
            s.run(.repeatForever(.sequence([.rotate(toAngle: 0.08, duration: 0.9), .rotate(toAngle: -0.08, duration: 0.9)])),
                  withKey: "wobble")
            scouts[shot] = s
        }
        for (shot, s) in scouts where !wanted.contains(shot) {
            scouts[shot] = nil
            s.removeAllActions()
            if scoutsEscaping {
                s.run(.sequence([.group([.moveBy(x: 0, y: 220, duration: 0.8), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
            } else {
                // shot down: spin, shrink and drop with a little flash
                let pop = SKShapeNode(circleOfRadius: 10)
                pop.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1)
                pop.strokeColor = .clear
                pop.blendMode = .add
                pop.position = s.position
                pop.zPosition = 9
                addChild(pop)
                pop.run(.sequence([.group([.scale(to: 3, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
                s.run(.sequence([.group([.rotate(byAngle: 6, duration: 0.6), .scale(to: 0.2, duration: 0.6),
                                         .moveBy(x: 0, y: -30, duration: 0.6), .fadeOut(withDuration: 0.6)]),
                                 .removeFromParent()]))
            }
        }
        if scouts.isEmpty { scoutsEscaping = false }
    }

    private func syncAbductor(_ campaign: Campaign) {
        let scoop = TableLayout.abductionCenter
        guard campaign.abductorsActive else {
            if let a = abductor {                          // wave over: the abductor leaves
                for node in [a, beam, cow].compactMap({ $0 }) {
                    node.removeAllActions()
                    node.run(.sequence([.group([.moveBy(x: 0, y: 160, duration: 0.8), .fadeOut(withDuration: 0.8)]),
                                        .removeFromParent()]))
                }
                abductor = nil; beam = nil; cow = nil
            }
            lastCowsSaved = 0
            return
        }
        if abductor == nil {
            let a = SKSpriteNode(imageNamed: "scout")
            a.size = CGSize(width: 58, height: 34)
            a.position = CGPoint(x: Self.abductorAt.x, y: Self.abductorAt.y + 100)
            a.alpha = 0
            a.zPosition = 22
            addChild(a)
            a.run(.sequence([.group([.move(to: Self.abductorAt, duration: 0.7), .fadeIn(withDuration: 0.7)]),
                             .repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 0.8), .moveBy(x: 0, y: -3, duration: 0.8)]))]))
            abductor = a

            let b = SKSpriteNode(imageNamed: "beam")
            b.anchorPoint = CGPoint(x: 0.5, y: 1)
            b.position = CGPoint(x: Self.abductorAt.x, y: Self.abductorAt.y - 6)
            b.size = CGSize(width: 64, height: Self.abductorAt.y - 6 - (scoop.y - 14))
            b.zPosition = 9
            b.alpha = 0
            addChild(b)
            b.run(.sequence([.wait(forDuration: 0.5), .fadeAlpha(to: 0.9, duration: 0.3)]))
            beam = b

            let c = SKSpriteNode(imageNamed: "cow")
            c.size = CGSize(width: 34, height: 26)
            c.zPosition = 9
            addChild(c)
            cow = c
            lastCowsSaved = campaign.cowsSaved
        }
        guard let c = cow else { return }
        // A save since last frame: a copy of the cow drops back to the field; the next cow starts low.
        if campaign.cowsSaved > lastCowsSaved {
            lastCowsSaved = campaign.cowsSaved
            let falling = c.copy() as? SKSpriteNode
            if let f = falling {
                addChild(f)
                f.run(.sequence([.group([.moveTo(y: scoop.y - 30, duration: 0.5), .fadeOut(withDuration: 0.6)]),
                                 .removeFromParent()]))
            }
        }
        // The cow rises with the beam timer: at the scoop when it starts, up at the saucer at zero.
        let left = max(0, min(1, campaign.timeLeft / Campaign.beamSeconds))
        let low = scoop.y + 8, high = Self.abductorAt.y - 22
        c.position = CGPoint(x: Self.abductorAt.x + 4 * sin(CGFloat(campaign.timeLeft) * 3), y: high - (high - low) * CGFloat(left))
        c.zRotation = 0.15 * sin(CGFloat(campaign.timeLeft) * 2)
    }

    /// A miss: the cow is whisked up into the saucer (a copy shrinks into it; the next cow starts low).
    func cowTaken() {
        guard let c = cow, let a = abductor else { return }
        if let up = c.copy() as? SKSpriteNode {
            addChild(up)
            up.run(.sequence([.group([.move(to: a.position, duration: 0.4), .scale(to: 0.2, duration: 0.4),
                                      .fadeOut(withDuration: 0.45)]), .removeFromParent()]))
        }
    }

    private func syncMothership(_ campaign: Campaign) {
        if campaign.mothershipActive {
            if mothership == nil {
                let ship = SKSpriteNode(imageNamed: "mothership")
                ship.size = CGSize(width: 300, height: 110)
                ship.position = CGPoint(x: Self.mothershipAt.x, y: Self.mothershipAt.y + 140)
                ship.alpha = 0
                ship.zPosition = 22
                addChild(ship)
                ship.run(.sequence([
                    .group([.move(to: Self.mothershipAt, duration: 2.0), .fadeIn(withDuration: 1.2)]),
                    .repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 1.1), .moveBy(x: 0, y: -3, duration: 1.1)])),
                ]))
                let k = SKShapeNode(circleOfRadius: 8)
                k.position = CGPoint(x: 0, y: -12)
                k.fillColor = SKColor(red: 0.35, green: 0.95, blue: 0.55, alpha: 1)
                k.strokeColor = SKColor(red: 0.92, green: 1.0, blue: 0.94, alpha: 1)
                k.lineWidth = 1.5
                k.zPosition = 0.5
                k.alpha = 0
                ship.addChild(k)
                mothership = ship
                core = k
                mothershipDestroyed = false
            }
            // Core: dark while the shields are up, pulsing green while it's open.
            if let k = core {
                if campaign.coreOpen {
                    if k.action(forKey: "pulse") == nil {
                        k.alpha = 1
                        k.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.25), .fadeAlpha(to: 1, duration: 0.25)])),
                              withKey: "pulse")
                    }
                } else if k.action(forKey: "pulse") != nil {
                    k.removeAction(forKey: "pulse")
                    k.alpha = 0
                }
            }
        } else if let ship = mothership, !mothershipDestroyed {
            // Escaped (multiball ended first): it flies off the top.
            mothership = nil; core = nil
            ship.removeAllActions()
            ship.run(.sequence([.group([.moveBy(x: 0, y: 220, duration: 1.2), .fadeOut(withDuration: 1.2)]), .removeFromParent()]))
        }
    }
}
