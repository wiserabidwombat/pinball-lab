// Pinball Lab Table 09 (Quest & Flipper): the run's numbers that a region table READS. Later milestones fill them from
// the map, the class, the gear and the boss perks; the table never keeps its own copies (Aaron: "ball strength, HP
// and loot should be values the table reads, not constants"). T9 M1 v1 starts every game as the Knight.
import CoreGraphics
import Foundation

/// One run's state, handed to a region table when a visit starts and handed back (HP, gold, loot) when it ends.
struct QfRunState {
    var className: String
    var maxHP: Int
    var hp: Int
    /// Damage multiplier: damage = impact speed × ball strength (QfDamage).
    var ballStrength: CGFloat
    /// HP taken off each drain's damage (armour gear).
    var armour: Int
    /// What a drain costs before armour.
    var drainDamage: Int
    var gold: Int = 0
    var loot: [String] = []

    /// The Knight (the starting class): the most HP, a hard-hitting ball. Placeholder numbers: 3 drains, like 3 balls.
    nonisolated static let knight = QfRunState(className: "Knight", maxHP: 30, hp: 30, ballStrength: 1.0, armour: 0, drainDamage: 10)

    var damagePerDrain: Int { max(1, drainDamage - armour) }
}

/// How hard a hit lands: impact speed (pt/s) / 100 × ball strength, at least 1. A clean 1,500 pt/s shot = 15.
enum QfDamage {
    static func of(impactSpeed: CGFloat, strength: CGFloat) -> Int {
        max(1, Int((impactSpeed / 100 * strength).rounded()))
    }
}

/// The Haunted Forest's monsters' HP (placeholders until the rules milestone; tougher regions get bigger numbers).
enum QfMonsterHP {
    static let treant = 60
}
