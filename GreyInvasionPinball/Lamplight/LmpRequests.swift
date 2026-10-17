// Pinball Lab Table 05 (The Lamplight): the regulars and their requests (milestone 8 round 1).
// A regular comes in with something they'd like; the arrows light the shots that make it, in order, and there's no
// clock: they wait patiently until it's done or the evening ends. A finished request pays points, a tip and a step of
// friendship (saved). The Evening Rush, cozy spots, seasons and Festival Nights build on this in later rounds.
import Foundation

/// The shots a request asks for.
nonisolated enum LmpRequestStep: String {
    case bookshelf      // knock all four books down
    case loop           // either loop
    case ramp           // make the ramp
    case kettle         // the kettle
    case mail           // the mail slot
    case loft           // get the ball up to the loft (ramp, dumbwaiter or a full plunge)

    var label: String {
        switch self {
        case .bookshelf: return "the bookshelf"
        case .loop: return "a loop"
        case .ramp: return "the ramp"
        case .kettle: return "the kettle"
        case .mail: return "the mail slot"
        case .loft: return "the loft"
        }
    }
}

/// The four kinds of request (the plan's book, cup of tea, favor and chat).
nonisolated enum LmpRequestKind: CaseIterable {
    case book, tea, favor, chat

    var steps: [LmpRequestStep] {
        switch self {
        case .book: return [.bookshelf, .loop]
        case .tea: return [.ramp, .kettle]
        case .favor: return [.mail]
        case .chat: return [.loft]
        }
    }

    /// What they say as they come in.
    var lines: [String] {
        switch self {
        case .book: return ["Something with a lighthouse in it?", "A good mystery for a rainy night?",
                            "Anything about the old mill?", "Something to read by the fire?"]
        case .tea: return ["A pot of something warm, please.", "Chamomile, if you have it.",
                           "Tea and a slice of something?", "The usual, please."]
        case .favor: return ["Could you post this for me?", "Would you send this letter on its way?"]
        case .chat: return ["I'll be up by the window if you have a minute.", "Come and sit with me upstairs?"]
        }
    }
}

nonisolated struct LmpRegular: Hashable {
    let id: String
    let name: String
    let who: String      // "the retired teacher"
}

/// One request in progress.
nonisolated struct LmpRequest {
    let regular: LmpRegular
    let kind: LmpRequestKind
    let line: String
    var stepIndex = 0

    var step: LmpRequestStep? { stepIndex < kind.steps.count ? kind.steps[stepIndex] : nil }
    var isDone: Bool { step == nil }

    /// "Rosa · the ramp, then the kettle (1/2)"
    var status: String {
        let steps = kind.steps.map(\.label).joined(separator: ", then ")
        let progress = kind.steps.count > 1 ? " (\(stepIndex)/\(kind.steps.count))" : ""
        return "\(regular.name) · \(steps)\(progress)"
    }
}

enum LmpRegulars {
    /// The first eleven regulars (the mysterious winter visitor arrives with the seasons).
    static let all: [LmpRegular] = [
        LmpRegular(id: "teacher", name: "Miss Pemberton", who: "the retired teacher"),
        LmpRegular(id: "fisherman", name: "Old Tom", who: "the fisherman"),
        LmpRegular(id: "baker", name: "Rosa", who: "the baker"),
        LmpRegular(id: "poet", name: "Felix", who: "the shy poet"),
        LmpRegular(id: "twins", name: "The Hartley twins", who: "the twins"),
        LmpRegular(id: "postmistress", name: "Mrs. Ashdown", who: "the postmistress"),
        LmpRegular(id: "artist", name: "Juniper", who: "the traveling artist"),
        LmpRegular(id: "mayor", name: "Mayor Bramble", who: "the mayor"),
        LmpRegular(id: "botanist", name: "Ivy", who: "the young botanist"),
        LmpRegular(id: "grandmother", name: "Granny Moss", who: "the knitting grandmother"),
        LmpRegular(id: "musician", name: "Rook", who: "the stray musician"),
    ]

    /// A new request from someone who isn't the last visitor.
    static func next(after last: LmpRegular?) -> LmpRequest {
        let who = all.filter { $0 != last }.randomElement() ?? all[0]
        let kind = LmpRequestKind.allCases.randomElement() ?? .book
        return LmpRequest(regular: who, kind: kind, line: kind.lines.randomElement() ?? "")
    }
}

extension String {
    /// "the ramp, then the kettle" → "The ramp, then the kettle"
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
