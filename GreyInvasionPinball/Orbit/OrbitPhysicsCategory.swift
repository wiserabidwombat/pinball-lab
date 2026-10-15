// Pinball Lab: Orbit Pinball (table 1, Oct 2026), kept as it was. Moved in from its own app with every type
// prefixed "Orbit" and its images/sounds prefixed "orbit_" (names shared with Grey Invasion). Was PhysicsCategory.swift.
/// Collision bitmasks.
/// rollover and wormhole are sensors: they report contacts but the ball passes through.
enum OrbitPhysicsCategory {
    static let none: UInt32      = 0
    static let ball: UInt32      = 1 << 0
    static let wall: UInt32      = 1 << 1
    static let flipper: UInt32   = 1 << 2
    static let bumper: UInt32    = 1 << 3
    static let target: UInt32    = 1 << 4
    static let drain: UInt32     = 1 << 5
    static let slingshot: UInt32 = 1 << 6
    static let rollover: UInt32  = 1 << 7
    static let wormhole: UInt32  = 1 << 8
}
