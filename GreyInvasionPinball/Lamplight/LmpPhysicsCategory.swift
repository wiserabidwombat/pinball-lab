// Pinball Lab Table 05 (The Lamplight): copied from Table 03 (Cthulhu Rising) with the "Lmp" prefix; behaviour unchanged.
/// Collision bitmasks (from Orbit Pinball, plus the ramp layer).
/// rollover and wormhole are sensors: they report contacts but the ball passes through.
/// A ball collides with floor walls (`wall`) OR ramp rails (`rampWall`), never both:
/// the scene swaps its collisionBitMask when it moves between layers.
enum LmpPhysicsCategory {
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
    static let rampWall: UInt32  = 1 << 9
    /// The one-way orbit diverter. Each floor ball adds this to its collision mask only
    /// while it moves right, so the diverter is solid per ball (milestone 5).
    static let diverter: UInt32  = 1 << 10
    /// A ball up on a ramp or wire (M5 v4). Collisions push BOTH bodies when either one's
    /// collision mask includes the other, so a ramp ball still counting as `ball` kept knocking
    /// the upper flipper (which sits under the Tractor Beam's wire) even though the ball itself
    /// ignored the flipper. Floor parts collide with `ball` only, so they ignore ramp balls.
    static let rampBall: UInt32  = 1 << 11
    /// Table 03 milestone 4: a moving toy (Cthulhu on Table 03) that bats floor balls.
    static let toy: UInt32       = 1 << 12
    /// T3 M8 v3: the launch gate across the top of the shooter lane. Like the diverter, it's solid per ball:
    /// only for a ball above it moving down (a plunge going up swings the drawn flap and passes).
    static let launchGate: UInt32 = 1 << 13
    /// Table 04 milestone 4 (the habitrails): each wire level has its own rails and its own ball category, so a ball
    /// on one wire never touches another wire's rails or a ball riding it, where they cross. The mesa ramp's high
    /// wire uses rampWall / rampBall; the arroyo's low wire uses these.
    static let lowWireWall: UInt32 = 1 << 14
    static let lowWireBall: UInt32 = 1 << 15
    /// The helix (M4 round 2) is ridden on rails: a ball on it is moved along the path by the scene, with no physics
    /// walls; it takes this category, which nothing collides with.
    static let rideBall: UInt32 = 1 << 16
    static let rideWall: UInt32 = 1 << 17
}
